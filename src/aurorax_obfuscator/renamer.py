import random
import string

KEY_PREFIX = "_ax"

def mkname(n=8):
    return KEY_PREFIX + ''.join(random.choice(string.ascii_lowercase) for _ in range(n))

def find_locals(tokens):
    """
    Very heuristic: find names declared after 'local' and local function names.
    Returns a set of identifier strings.
    """
    names = set()
    i = 0
    L = len(tokens)
    while i < L:
        t = tokens[i]
        if t['type'] == 'IDENT' and t['value'] == 'local':
            j = i + 1
            # skip whitespace/comments represented as OTHER tokens with whitespace
            while j < L and tokens[j]['type'] == 'OTHER' and tokens[j]['value'].isspace():
                j += 1
            # local function name
            if j < L and tokens[j]['type'] == 'IDENT' and tokens[j]['value'] == 'function':
                k = j + 1
                while k < L and tokens[k]['type'] == 'OTHER' and tokens[k]['value'].isspace():
                    k += 1
                if k < L and tokens[k]['type'] == 'IDENT':
                    names.add(tokens[k]['value'])
                    i = k
            else:
                # local a, b = ...
                k = j
                while k < L:
                    if tokens[k]['type'] == 'IDENT':
                        names.add(tokens[k]['value'])
                        k += 1
                    elif tokens[k]['type'] == 'OTHER' and tokens[k]['value'] == ',':
                        k += 1
                        continue
                    else:
                        break
                i = k
        i += 1
    return names

def apply_renames(tokens, mapping):
    for tok in tokens:
        if tok['type'] == 'IDENT' and tok['value'] in mapping:
            tok['value'] = mapping[tok['value']]
    return tokens

def make_mapping(names):
    return {n: mkname() for n in names}
