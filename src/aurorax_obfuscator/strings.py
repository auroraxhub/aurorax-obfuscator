import base64

def unquote_string(s):
    # Remove surrounding quotes or long-bracket
    if s.startswith('"') or s.startswith("'"):
        return bytes(s[1:-1], "utf-8").decode("unicode_escape")
    if s.startswith('[[') and s.endswith(']]'):
        return s[2:-2]
    return s

def extract_strings(tokens):
    """
    Replace STRING tokens with call expression __AX_STR(n)
    and collect strings in order.
    """
    strings = []
    idx = 0
    for i, tok in enumerate(tokens):
        if tok['type'] == 'STRING':
            val = unquote_string(tok['value'])
            strings.append(val)
            # replace token text with __AX_STR(n)
            tok['type'] = 'OTHER'
            tok['value'] = "__AX_STR(%d)" % (idx + 1)
            idx += 1
    return strings, tokens
