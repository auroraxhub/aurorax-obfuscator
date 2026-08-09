"""
Compilador simple a un bytecode propio (Fase 1).
- Recibe código fuente Lua (limitado) y genera una estructura:
  { ops: [ (OP, args...), ... ], consts: [...], strs: [...], protos: [...] }
"""
from typing import List, Tuple, Dict, Any
from .tokenize_lua import tokenize, IDENT_RE
import json

# Instrucciones
OPS = [
    "LOADK",    # LOADK r, const_idx
    "LOADSTR",  # LOADSTR r, str_idx
    "MOVE",     # MOVE r_dst, r_src
    "SETGLOBAL",# SETGLOBAL name_idx, r_src
    "GETGLOBAL",# GETGLOBAL r_dst, name_idx
    "CALL",     # CALL r_func, n_args, n_ret -> pushes n_ret results into consecutive regs starting r_func
    "RETURN",   # RETURN r_start, n_ret
    "ADD","SUB","MUL","DIV","CONCAT",
    "CLOSURE",  # CLOSURE r_dst, proto_idx
    "NEWTABLE",
    "SETTABLE",
    "GETTABLE",
    "JMP_IF_FALSE",
    "JMP",
]

class Proto:
    def __init__(self, name="<main>"):
        self.name = name
        self.ops: List[Tuple] = []
        self.consts: List[Any] = []  # numbers
        self.strs: List[str] = []
        self.names: List[str] = []   # global names / identifiers referenced
        self.protos: List['Proto'] = []

    def add_const(self, v):
        if v in self.consts:
            return self.consts.index(v)
        self.consts.append(v)
        return len(self.consts)-1

    def add_str(self, s):
        if s in self.strs:
            return self.strs.index(s)
        self.strs.append(s)
        return len(self.strs)-1

    def add_name(self, n):
        if n in self.names:
            return self.names.index(n)
        self.names.append(n)
        return len(self.names)-1

    def add_proto(self, p: 'Proto'):
        self.protos.append(p)
        return len(self.protos)-1

    def emit(self, *args):
        self.ops.append(tuple(args))
        return len(self.ops)-1

    def to_dict(self):
        return {
            "name": self.name,
            "ops": self.ops,
            "consts": self.consts,
            "strs": self.strs,
            "names": self.names,
            "protos": [p.to_dict() for p in self.protos],
        }

from .tokenize_lua import tokenize
class Parser:
    def __init__(self, tokens):
        self.tokens = tokens
        self.i = 0
        self.L = len(tokens)

    def peek(self):
        if self.i < self.L:
            return self.tokens[self.i]
        return None

    def next(self):
        t = self.peek()
        self.i += 1
        return t

    def expect_ident(self):
        t = self.next()
        if not t or t['type'] != 'IDENT':
            raise SyntaxError("Expected identifier")
        return t['value']

    def skip_whitespace_comments(self):
        while self.peek() and self.peek()['type'] in ('OTHER','COMMENT') and self.peek()['value'].isspace():
            self.next()

    def at_newline(self):
        t = self.peek()
        return t is not None and t['type'] == 'OTHER' and '\n' in t['value']

class Compiler:
    def __init__(self):
        self.proto = Proto("<main>")
        self.reg_next = 0
        self.locals: Dict[str,int] = {}

    def new_reg(self):
        r = self.reg_next
        self.reg_next += 1
        return r

    def compile(self, source: str) -> Dict:
        tokens = tokenize(source)
        stmts = self.split_statements(tokens)
        for s in stmts:
            self.compile_stmt(s)
        self.proto.emit("RETURN", 0, 0)
        return self.proto.to_dict()

    def split_statements(self, tokens):
        stmts = []
        cur = []
        for t in tokens:
            cur.append(t)
            if t['type'] == 'OTHER' and '\n' in t['value']:
                stmts.append(cur)
                cur = []
        if cur:
            stmts.append(cur)
        return stmts

    def tokens_to_str(self, toks):
        return "".join(t['value'] for t in toks)

    def compile_stmt(self, toks):
        while toks and toks[0]['type'] == 'OTHER' and toks[0]['value'].isspace():
            toks = toks[1:]
        if not toks:
            return
        if len(toks) >= 2 and toks[0]['type']=='IDENT' and toks[0]['value']=='local' and toks[1]['type']=='IDENT' and toks[1]['value']=='function':
            s = self.tokens_to_str(toks)
            import re
            m = re.match(r'\s*local\s+function\s+([A-Za-z_][A-Za-z0-9_]*)\s*\((.*?)\)\s*(.*)\s*end\s*', s, re.S)
            if not m:
                return
            name = m.group(1)
            body = m.group(3)
            subc = Compiler()
            p = subc.compile(body)
            subp = Proto(name)
            subp.ops = p['ops']
            subp.consts = p['consts']
            subp.strs = p['strs']
            subp.names = p['names']
            subp.protos = []
            proto_idx = self.proto.add_proto(subp)
            r = self.new_reg()
            self.proto.emit("CLOSURE", r, proto_idx)
            self.locals[name] = r
            return
        if toks[0]['type']=='IDENT' and toks[0]['value']=='local':
            ids = []
            i = 1
            while i < len(toks):
                tok = toks[i]
                if tok['type']=='IDENT':
                    ids.append(tok['value'])
                elif tok['type']=='OTHER' and tok['value'] in (',',' '):
                    pass
                elif tok['type']=='OTHER' and tok['value']=='=':
                    expr_str = self.tokens_to_str(toks[i+1:])
                    r = self.compile_expr(expr_str)
                    if ids:
                        self.locals[ids[0]] = r
                    break
                i += 1
            return
        if toks[0]['type']=='IDENT' and len(toks)>1 and toks[1]['type']=='OTHER' and toks[1]['value']=='(':
            name = toks[0]['value']
            args_text = self.tokens_to_str(toks[2:-1])
            r_func = self.new_reg()
            name_idx = self.proto.add_name(name)
            self.proto.emit("GETGLOBAL", r_func, name_idx)
            args_regs = []
            if args_text.strip():
                arg_parts = self.split_args(args_text)
                for a in arg_parts:
                    ra = self.compile_expr(a)
                    args_regs.append(ra)
            for k, ra in enumerate(args_regs):
                self.proto.emit("MOVE", r_func+1+k, ra)
            self.proto.emit("CALL", r_func, len(args_regs), 0)
            return
        return

    def split_args(self, s):
        parts = []
        cur = ""
        depth=0
        for ch in s:
            if ch=='(':
                depth+=1
            elif ch==')':
                depth=max(0,depth-1)
            if ch==',' and depth==0:
                parts.append(cur.strip())
                cur=""
            else:
                cur+=ch
        if cur.strip():
            parts.append(cur.strip())
        return parts

    def compile_expr(self, expr_text: str):
        s = expr_text.strip()
        if (s.startswith('"') and s.endswith('"')) or (s.startswith("'") and s.endswith("'")) or (s.startswith('[[') and s.endswith(']]')):
            if s.startswith('[['):
                val = s[2:-2]
            else:
                val = s[1:-1].encode('utf-8').decode('unicode_escape')
            idx = self.proto.add_str(val)
            r = self.new_reg()
            self.proto.emit("LOADSTR", r, idx)
            return r
        import re
        if re.match(r'^[0-9]+(\.[0-9]+)?$', s):
            v = float(s) if '.' in s else int(s)
            idx = self.proto.add_const(v)
            r = self.new_reg()
            self.proto.emit("LOADK", r, idx)
            return r
        for op_sym, opname in [("..","CONCAT"),("+","ADD"),("-","SUB"),("*","MUL"),("/","DIV")]:
            if op_sym in s:
                left, right = s.split(op_sym,1)
                r1 = self.compile_expr(left)
                r2 = self.compile_expr(right)
                rd = self.new_reg()
                self.proto.emit(opname, rd, r1, r2)
                return rd
        if IDENT_RE.match(s):
            name = s
            if name in self.locals:
                return self.locals[name]
            else:
                r = self.new_reg()
                idx = self.proto.add_name(name)
                self.proto.emit("GETGLOBAL", r, idx)
                return r
        idx = self.proto.add_str(s)
        r = self.new_reg()
        self.proto.emit("LOADSTR", r, idx)
        rl = self.new_reg()
        idx_load = self.proto.add_name("load")
        self.proto.emit("GETGLOBAL", rl, idx_load)
        self.proto.emit("MOVE", rl+1, r)
        self.proto.emit("CALL", rl, 1, 1)
        return rl
