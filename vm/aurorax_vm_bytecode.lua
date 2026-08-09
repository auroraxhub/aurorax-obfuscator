-- Aurora X bytecode VM (Fase 1)
-- Executes a bytecode object serialized as Lua table (decoded from JSON by the obfuscator)

local json = nil
local has_cjson, cjson = pcall(require, "cjson")
if has_cjson then json = cjson.decode else
  json = function(s)
    local lua_s = s:gsub('null', 'nil')
                   :gsub('true', 'true')
                   :gsub('false', 'false')
    local f, err = load("return " .. lua_s)
    if not f then error("JSON decode failed: "..tostring(err)) end
    return f()
  end
end

local function deepcopy(t)
  if type(t) ~= "table" then return t end
  local r = {}
  for k,v in pairs(t) do r[k] = deepcopy(v) end
  return r
end

local function make_proto_func(proto)
  local ops = proto.ops
  local consts = proto.consts or {}
  local strs = proto.strs or {}
  local names = proto.names or {}
  local protos = proto.protos or {}

  local proto_funcs = {}
  for i,p in ipairs(protos) do
    proto_funcs[i] = make_proto_func(p)
  end

  local function run_env(env, ...)
    local regs = {}
    local pc = 1
    local function get_const(idx) return consts[idx+1] end
    local function get_str(idx) return strs[idx+1] end
    local function get_name(idx) return names[idx+1] end

    while pc <= #ops do
      local ins = ops[pc]
      local op = ins[1]
      if op == "LOADK" then
        local dst, cidx = ins[2]+1, ins[3]
        regs[dst] = consts[cidx+1]
      elseif op == "LOADSTR" then
        local dst, sidx = ins[2]+1, ins[3]
        regs[dst] = strs[sidx+1]
      elseif op == "MOVE" then
        local a,b = ins[2]+1, ins[3]+1
        regs[a] = regs[b]
      elseif op == "GETGLOBAL" then
        local dst, nameidx = ins[2]+1, ins[3]
        local nm = names[nameidx+1]
        regs[dst] = env[nm] or _G[nm]
      elseif op == "SETGLOBAL" then
        local nameidx, rsrc = ins[2], ins[3]+1
        local nm = names[nameidx+1]
        env[nm] = regs[rsrc]
      elseif op == "CALL" then
        local rfunc, n_args, n_ret = ins[2]+1, ins[3], ins[4]
        local func = regs[rfunc]
        if type(func) ~= "function" then error("Attempt to call non-function") end
        local args = {}
        for i=1,n_args do args[i] = regs[rfunc + i] end
        local results = { func(table.unpack(args,1,n_args)) }
        for i=1,(n_ret or 0) do regs[rfunc + i] = results[i] end
      elseif op == "RETURN" then
        local rstart, nret = ins[2]+1, ins[3]
        local res = {}
        for i=0,(nret-1) do res[#res+1] = regs[rstart + i] end
        return table.unpack(res)
      elseif op == "ADD" or op == "SUB" or op == "MUL" or op == "DIV" or op == "CONCAT" then
        local dst, a, b = ins[2]+1, ins[3]+1, ins[4]+1
        local A, B = regs[a], regs[b]
        if op == "ADD" then regs[dst] = A + B
        elseif op == "SUB" then regs[dst] = A - B
        elseif op == "MUL" then regs[dst] = A * B
        elseif op == "DIV" then regs[dst] = A / B
        elseif op == "CONCAT" then regs[dst] = tostring(A) .. tostring(B)
        end
      elseif op == "CLOSURE" then
        local dst, proto_idx = ins[2]+1, ins[3]
        local f = proto_funcs[proto_idx+1]
        regs[dst] = function(...)
          local child_env = {}
          setmetatable(child_env, {__index = env})
          return f(child_env, ...)
        end
      elseif op == "NEWTABLE" then
        local dst = ins[2]+1
        regs[dst] = {}
      elseif op == "SETTABLE" then
        local rt, rk, rv = ins[2]+1, ins[3]+1, ins[4]+1
        local tbl = regs[rt]
        local key = regs[rk]
        tbl[key] = regs[rv]
      elseif op == "GETTABLE" then
        local dst, rt, rk = ins[2]+1, ins[3]+1, ins[4]+1
        local tbl = regs[rt] or {}
        local key = regs[rk]
        regs[dst] = tbl[key]
      elseif op == "JMP_IF_FALSE" then
        local rcond, target = ins[2]+1, ins[3]
        local val = regs[rcond]
        if not val then pc = target; goto cont end
      elseif op == "JMP" then
        local target = ins[2]
        pc = target; goto cont
      else
        error("Unknown opcode: "..tostring(op))
      end
      pc = pc + 1
      ::cont::
    end
  end

  return function(env, ...)
    return run_env(env, ...)
  end
end

local function run_bytecode_table(proto_table, global_env)
  local f = make_proto_func(proto_table)
  local env = global_env or {}
  setmetatable(env, { __index = _G })
  return f(env)
end

return {
  run = run_bytecode_table
}
