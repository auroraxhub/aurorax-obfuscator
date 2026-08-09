-- Aurora X VM-ish loader (MVP)
-- Expects:
--   _AX_blob_b64 (base64 of XOR-encrypted JSON proto table)
--   _AX_key_b64 (base64 of XOR key)

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
    res[i] = string.char(bit32 and bit32.bxor(b, kb) or ( (b ~ kb) ))
  end
  return table.concat(res)
end

if not bit32 then
  if bit then
    bit32 = { bxor = bit.bxor }
  end
end

local function decode_and_decrypt(b64blob, key_b64)
  local enc = b64decode(b64blob)
  local key = b64decode(key_b64)
  local ok = xor_bytes(enc, key)
  return ok
end

local function run_obfuscated()
  assert(_AX_blob_b64 and _AX_key_b64, "Missing obfuscated payload metadata")
  local proto_json = decode_and_decrypt(_AX_blob_b64, _AX_key_b64)
  -- decode JSON into table using load trick
  local f, err = load("return " .. proto_json)
  if not f then error("Failed to parse proto JSON: "..tostring(err)) end
  local proto_table = f()
  -- require bytecode VM
  local bc_vm = require("aurorax_vm_bytecode")
  return bc_vm.run(proto_table, {})
end

return run_obfuscated()
