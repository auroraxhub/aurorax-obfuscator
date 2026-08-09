-- Aurora X VM-ish loader (Hardened)
-- Expects embedded variables:
--   _AX_blob_b64 (base64 of XOR-encrypted JSON proto table)
--   _AX_key_frags (table of string fragments, shuffled)
--   _AX_key_order (permutation array used to shuffle fragments)
--   _AX_checksum (uint32 checksum of plaintext proto JSON)

local function try_require(name)
  local ok, m = pcall(require, name)
  if ok then return m end
  return nil
end

-- minimal base64 decode (works for typical data)
local base64 = (function()
  local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
  local s = {}
  for i=1, #b do s[string.sub(b,i,i)] = i-1 end
  return {
    dec = function(data)
      data = string.gsub(data, '[^'..b..'=]', '')
      return (data:gsub('.', function(x)
        if x == '=' then return '' end
        local r = ''
        local c = s[x]
        for i=6,1,-1 do
          r = r .. (math.floor(c / 2^(i-1)) % 2)
        end
        return r
      end):gsub('%d%d%d%d%d%d%d%d', function(x)
        local c = 0
        for i=1,8 do c = c*2 + (x:sub(i,i) == '1' and 1 or 0) end
        return string.char(c)
      end))
    end
  }
end)()

local function b64decode(s)
  return base64.dec(s)
end

local function xor_bytes(data, key)
  local res = {}
  local klen = #key
  for i = 1, #data do
    local b = string.byte(data, i)
    local kb = string.byte(key, ((i-1) % klen) + 1)
    -- use bit32.bxor if available to be explicit
    local xb = nil
    if bit32 and bit32.bxor then xb = bit32.bxor(b, kb) else
      -- LuaJIT supports bit.bxor but we avoid requiring bit
      xb = (b ~ kb)
    end
    res[i] = string.char(xb)
  end
  return table.concat(res)
end

-- reconstruct key from fragments and obfuscated order
local function reconstruct_key(frags, order)
  -- order is array of indices showing original positions; we invert to rebuild
  local parts = {}
  for i=1,#order do
    parts[order[i]+1] = frags[i]
  end
  return table.concat(parts)
end

local function sum_bytes(s)
  local acc = 0
  for i=1,#s do
    acc = (acc + string.byte(s,i)) % 4294967296
  end
  return acc
end

-- Environment checks (anti-analysis)
local function detect_debugger()
  -- 1) debug.getinfo presence
  if type(debug) == 'table' and type(debug.getinfo) == 'function' then
    -- try to inspect callstack depth; many analyzers set hooks
    local ok, info = pcall(debug.getinfo, 2, 'S')
    if ok and info and info.source then
      -- heuristics: if source refers to known analysis names, flag
      if string.find(info.source, 'IDA') or string.find(info.source, 'frida') then
        return true
      end
    else
      -- debug.getinfo failed unexpectedly -> suspicious
      return true
    end
  end
  -- 2) presence of frida-related modules
  if try_require('frida') or package.preload['frida'] then return true end
  -- 3) check /proc self cmdline for common analyzer names (best-effort)
  local function scan_proc()
    local paths = {"/proc/self/cmdline","/proc/self/maps"}
    for _,p in ipairs(paths) do
      local f = io.open(p, 'r')
      if f then
        local content = f:read('*a')
        f:close()
        if content and (string.find(content, 'frida') or string.find(content, 'gdb') or string.find(content, 'ida')) then
          return true
        end
      end
    end
    return false
  end
  local ok, res = pcall(scan_proc)
  if ok and res then return true end
  -- 4) Termux detection via PREFIX env
  local prefix = os.getenv('PREFIX') or ''
  if string.find(prefix, 'com.termux') then return true end
  -- 5) JIT OS detection (LuaJIT on Android)
  if rawget(_G, 'jit') and type(jit.os) == 'string' and string.lower(jit.os) == 'android' then
    return true
  end
  return false
end

-- If suspicious environment detected, take action
local function handle_suspicious()
  -- Hardened response: we'll waste time and then error to frustrate automated analysis
  for i=1,3 do
    -- costly loop to slow down analysis
    local x = 0
    for j=1,500000 do x = x + j end
  end
  error('Execution aborted: security policy')
end

local function decode_and_decrypt(b64blob, key_b64)
  local enc = b64decode(b64blob)
  local key = b64decode(key_b64)
  local ok = xor_bytes(enc, key)
  return ok
end

local function run_obfuscated()
  assert(_AX_blob_b64 and _AX_key_frags and _AX_key_order and _AX_checksum, "Missing obfuscated payload metadata")
  if detect_debugger() then
    handle_suspicious()
  end
  local key_b64 = reconstruct_key(_AX_key_frags, _AX_key_order)
  local proto_json = decode_and_decrypt(_AX_blob_b64, key_b64)
  -- verify checksum
  local cs = sum_bytes(proto_json)
  if cs ~= (_AX_checksum % 4294967296) then
    -- integrity failure; possible tampering
    handle_suspicious()
  end
  -- decode proto JSON into table
  local f, err = load("return " .. proto_json)
  if not f then error("Failed to parse proto JSON: "..tostring(err)) end
  local proto_table = f()
  -- require bytecode VM module (should be packaged as aurorax_vm_bytecode)
  local ok, bc_vm = pcall(require, 'aurorax_vm_bytecode')
  if not ok or type(bc_vm) ~= 'table' or type(bc_vm.run) ~= 'function' then
    error('Runtime VM missing')
  end
  return bc_vm.run(proto_table, {})
end

-- Execute on require / run
return run_obfuscated()
