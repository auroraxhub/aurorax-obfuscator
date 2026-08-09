-- Minified hardened aurorax loader (variable names obfuscated)
local function _req(n)local ok,m=pcall(require,n) if ok then return m end return nil end
local _b64=(function()
 local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
 local s={} for i=1,#b do s[string.sub(b,i,i)]=i-1 end
 return {dec=function(d) d=string.gsub(d,'[^'..b..'=]','') return (d:gsub('.',function(x) if x=='=' then return '' end local r=''; local c=s[x]; for i=6,1,-1 do r=r..(math.floor(c/2^(i-1))%2) end return r end):gsub('%d%d%d%d%d%d%d%d',function(x)local c=0; for i=1,8 do c=c*2 + (x:sub(i,i)=='1' and 1 or 0) end return string.char(c) end)) end}
end)()
local function _b64d(s) return _b64.dec(s) end
local function _xor(d,k)local r={}; local kl=#k for i=1,#d do local b=string.byte(d,i); local kb=string.byte(k,((i-1)%kl)+1); local xb=nil; if bit32 and bit32.bxor then xb=bit32.bxor(b,kb) else xb=(b~kb) end; r[i]=string.char(xb) end; return table.concat(r) end
local function _recon(fr,ord)local parts={} for i=1,#ord do parts[ord[i]+1]=fr[i] end; return table.concat(parts) end
local function _sum(s)local a=0 for i=1,#s do a=(a+string.byte(s,i))%4294967296 end return a end
local function _scan_proc()
 local paths={'/proc/self/cmdline','/proc/self/maps'} for _,p in ipairs(paths) do local f=io.open(p,'r') if f then local c=f:read('*a'); f:close(); if c and (string.find(c,'frida') or string.find(c,'gdb') or string.find(c,'ida')) then return true end end end return false end
local function _detect()
 if type(debug)=='table' and type(debug.getinfo)=='function' then local ok,info=pcall(debug.getinfo,2,'S') if ok and info and info.source then if string.find(info.source,'IDA') or string.find(info.source,'frida') then return true end else return true end end
 if _req('frida') or package.preload['frida'] then return true end
 local ok,rs=pcall(_scan_proc); if ok and rs then return true end
 local pref=os.getenv('PREFIX') or '' if string.find(pref,'com.termux') then return true end
 if rawget(_G,'jit') and type(jit.os)=='string' and string.lower(jit.os)=='android' then return true end
 return false end
local function _waste() for i=1,2 do local x=0 for j=1,500000 do x=x+j end end end
local function _decode_and_run(blob_b64, frags, ord, chk)
 if _detect() then _waste(); error('Execution aborted: security policy') end
 local k64=_recon(frags,ord)
 local proto_json=_xor(_b64d(blob_b64), _b64d(k64))
 if _sum(proto_json)~=(chk%4294967296) then _waste(); error('Execution aborted: integrity fail') end
 local f,err=load('return '..proto_json)
 if not f then error('Failed to parse proto JSON:'..tostring(err)) end
 local proto_tbl=f()
 local ok,vm=pcall(require,'aurorax_vm_bytecode') if not ok or type(vm)~='table' or type(vm.run)~='function' then error('VM missing') end
 return vm.run(proto_tbl,{}) end
return (function() assert(_AX_blob_b64 and _AX_key_frags and _AX_key_order and _AX_checksum, 'Missing metadata') return _decode_and_run(_AX_blob_b64,_AX_key_frags,_AX_key_order,_AX_checksum) end)()
