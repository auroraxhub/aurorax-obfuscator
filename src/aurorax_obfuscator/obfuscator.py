import os
import json
import base64
import secrets
from .tokenize_lua import tokenize
from .renamer import find_locals, make_mapping, apply_renames
from .strings import extract_strings
from .compiler import Compiler

def xor_bytes(data: bytes, key: bytes) -> bytes:
    return bytes(b ^ key[i % len(key)] for i, b in enumerate(data))

def pack_output(enc_json_b64: str, key_b64: str):
    # For bytecode path we only need the encoded blob and key
    return enc_json_b64

def build_output_lua(enc_blob_b64: str, key_b64: str):
    # Inline the VM bytecode loader
    vm_template_path = os.path.join(os.path.dirname(__file__), "..", "vm", "aurorax_vm_bytecode.lua")
    with open(vm_template_path, 'r', encoding='utf-8') as f:
        vm_code = f.read()
    out = []
    out.append("-- Aurora X obfuscated bytecode payload (single-file)")
    out.append("local _AX_blob_b64 = %r" % enc_blob_b64)
    out.append("local _AX_key_b64 = %r" % key_b64)
    out.append(vm_code)
    return "\n".join(out)

def obfuscate_source_to_bytecode(source: str, key: bytes):
    compiler = Compiler()
    proto_table = compiler.compile(source)
    proto_json = json.dumps(proto_table, ensure_ascii=False)
    enc = xor_bytes(proto_json.encode('utf-8'), key)
    enc_b64 = base64.b64encode(enc).decode('ascii')
    return enc_b64

def obfuscate_file(in_path: str, out_path: str, key: str = None):
    if key is None:
        key_bytes = secrets.token_bytes(16)
    else:
        key_bytes = key.encode('utf-8')
    import base64
    key_b64 = base64.b64encode(key_bytes).decode('ascii')
    with open(in_path, 'r', encoding='utf-8') as f:
        src = f.read()
    enc_blob_b64 = obfuscate_source_to_bytecode(src, key_bytes)
    out_lua = build_output_lua(enc_blob_b64, key_b64)
    with open(out_path, 'w', encoding='utf-8') as f:
        f.write(out_lua)
    print(f"Obfuscated {in_path} -> {out_path}")
