-- Minified Aurora X bytecode VM (obfuscated identifiers)
local f_has_cjson, cjson = pcall(require, "cjson")
local _d = f_has_cjson and cjson.decode or function(s)
  local ls = s:gsub('null','nil'):gsub('true','true'):gsub('false','false')
  local fn,err = load("return "..ls)
  if not fn then error("JSON decode failed:"..tostring(err)) end
  return fn()
end
local function _dc(t) if type(t)~='table' then return t end local r={} for k,v in pairs(t) do r[k]=_dc(v) end return r end
local function _mk(p)
  local ops=p.ops; local K=p.consts or {}; local S=p.strs or {}; local N=p.names or {}; local P=p.protos or {}
  local PF={}
  for i=1,#P do PF[i]=_mk(P[i]) end
  local function _run(env,...)
    local R={}; local pc=1
    while pc<=#ops do
      local ins=ops[pc]; local op=ins[1]
      if op=="LOADK" then local d,c=ins[2]+1,ins[3]; R[d]=K[c+1]
      elseif op=="LOADSTR" then local d,s=ins[2]+1,ins[3]; R[d]=S[s+1]
      elseif op=="MOVE" then R[ins[2]+1]=R[ins[3]+1]
      elseif op=="GETGLOBAL" then R[ins[2]+1]= (env[N[ins[3]+1]] or _G[N[ins[3]+1]])
      elseif op=="SETGLOBAL" then env[N[ins[2]+1]] = R[ins[3]+1]
      elseif op=="CALL" then
        local rfunc, na, nr = ins[2]+1, ins[3], ins[4]
        local fn=R[rfunc]
        if type(fn)~='function' then error('call non-function') end
        local a={}
        for i=1,na do a[i]=R[rfunc+i] end
        local res={fn(table.unpack(a,1,na))}
        for i=1,(nr or 0) do R[rfunc+i]=res[i] end
      elseif op=="RETURN" then local rs, n=ins[2]+1, ins[3]; local out={}; for i=0,n-1 do out[#out+1]=R[rs+i] end; return table.unpack(out)
      elseif op=="ADD" or op=="SUB" or op=="MUL" or op=="DIV" or op=="CONCAT" then
        local d,a,b=ins[2]+1,ins[3]+1,ins[4]+1; local A,B=R[a],R[b]
        if op=="ADD" then R[d]=A+B elseif op=="SUB" then R[d]=A-B elseif op=="MUL" then R[d]=A*B elseif op=="DIV" then R[d]=A/B else R[d]=tostring(A)..tostring(B) end
      elseif op=="CLOSURE" then local d,pi=ins[2]+1,ins[3]; local fn=PF[pi+1]; R[d]=function(...) local e={} setmetatable(e,{__index=env}) return fn(e,...) end
      elseif op=="NEWTABLE" then R[ins[2]+1]={}
      elseif op=="SETTABLE" then local rt,rk,rv=ins[2]+1,ins[3]+1,ins[4]+1; local t=R[rt]; t[R[rk]]=R[rv]
      elseif op=="GETTABLE" then local d,rt,rk=ins[2]+1,ins[3]+1,ins[4]+1; local t=R[rt] or {}; R[d]=t[R[rk]]
      elseif op=="JMP_IF_FALSE" then local rc,tp=ins[2]+1,ins[3]; if not R[rc] then pc=tp; goto CONT end
      elseif op=="JMP" then pc=ins[2]; goto CONT
      else error('badop:'..tostring(op)) end
      pc=pc+1
      ::CONT::
    end
  end
  return function(env,...) return _run(env,...) end
end
local function run_tab(pt, g)
  local fn=_mk(pt); local e=g or {}; setmetatable(e,{__index=_G}); return fn(e) end
return { run=run_tab }
