import re

IDENT_RE = re.compile(r'[A-Za-z_][A-Za-z0-9_]*')
NUM_RE = re.compile(r'\d+(\.\d+)?([eE][+-]?\d+)?')
WHITESPACE = ' \t\r\n'

def tokenize(code: str):
    tokens = []
    i = 0
    L = len(code)
    while i < L:
        ch = code[i]
        # whitespace
        if ch in WHITESPACE:
            j = i + 1
            while j < L and code[j] in WHITESPACE:
                j += 1
            tokens.append({'type': 'OTHER', 'value': code[i:j]})
            i = j
            continue
        # comments
        if ch == '-' and i+1 < L and code[i+1] == '-':
            # long comment --[[...]]
            if i+4 < L and code[i+2:i+4] == '[[':
                j = code.find(']]', i+4)
                if j == -1:
                    j = L
                else:
                    j += 2
                tokens.append({'type': 'COMMENT', 'value': code[i:j]})
                i = j
                continue
            else:
                j = i+2
                while j < L and code[j] != '\n':
                    j += 1
                tokens.append({'type': 'COMMENT', 'value': code[i:j]})
                i = j
                continue
        # long bracket string [[...]]
        if ch == '[' and i+1 < L and code[i+1] == '[':
            j = code.find(']]', i+2)
            if j == -1:
                j = L
            else:
                j += 2
            tokens.append({'type': 'STRING', 'value': code[i:j]})
            i = j
            continue
        # strings '...' or "..."
        if ch == '"' or ch == "'":
            q = ch
            j = i+1
            escaped = False
            while j < L:
                c = code[j]
                if c == '\\' and not escaped:
                    escaped = True
                    j += 1
                    continue
                if c == q and not escaped:
                    j += 1
                    break
                escaped = False
                j += 1
            tokens.append({'type': 'STRING', 'value': code[i:j]})
            i = j
            continue
        # identifiers / keywords
        m = IDENT_RE.match(code, i)
        if m:
            tokens.append({'type': 'IDENT', 'value': m.group(0)})
            i = m.end()
            continue
        # numbers
        m = NUM_RE.match(code, i)
        if m:
            tokens.append({'type': 'OTHER', 'value': m.group(0)})
            i = m.end()
            continue
        # two-char operators
        two = code[i:i+2]
        if two in ('<=', '>=', '==', '~=', '..', '::'):
            tokens.append({'type': 'OTHER', 'value': two})
            i += 2
            continue
        # single char
        tokens.append({'type': 'OTHER', 'value': ch})
        i += 1
    return tokens
