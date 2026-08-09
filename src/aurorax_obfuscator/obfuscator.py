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

def split_key_obf(key_b64: str):
    # Split key into small fragments and shuffle order, return fragments list and order mapping
    # We'll shuffle and return fragments; VM will reassemble in given order by applying simple rotation offsets.
    import random
    frags = []
    L = len(key_b64)
    # choose fragment sizes (random but deterministic to avoid including RNG seed): use fixed small sizes
    sizes = [3,4,5,3,4]
    i = 0
    for s in sizes:
        if i >= L:
            break
        frags.append(key_b64[i:i+s])
        i += s
    if i < L:
        frags.append(key_b64[i:])
    # shuffle order but record permutation
    order = list(range(len(frags)))
    random.shuffle(order)
    shuffled = [frags[i] for i in order]
    return shuffled, order

def build_output_lua(enc_blob_b64: str, key_b64: str, checksum: int):
    # Inline the VM bytecode loader and embed the b64 blobs + obfuscated key fragments + checksum
    vm_template_path = os.path.join(os.path.dirname(__file__), "..", "vm", "aurorax_vm.lua")
    with open(vm_template_path, 'r', encoding='utf-8') as f:
        vm_code = f.read()
    frags, order = split_key_obf(key_b64)
    out = []
    out.append("-- Aurora X obfuscated bytecode payload (single-file) — hardened")
    out.append("local _AX_blob_b64 = %r" % enc_blob_b64)
    out.append("local _AX_key_frags = %r" % frags)
    out.append("local _AX_key_order = %r" % order)
    out.append("local _AX_checksum = %d" % checksum)
    # Append VM code which will reconstruct key, verify checksum, detect debuggers, and run
    out.append(vm_code)
    return "\n".join(out)


def obfuscate_source_to_bytecode(source: str, key: bytes):
    compiler = Compiler()
    proto_table = compiler.compile(source)
    proto_json = json.dumps(proto_table, ensure_ascii=False)
    enc = xor_bytes(proto_json.encode('utf-8'), key)
    enc_b64 = base64.b64encode(enc).decode('ascii')
    # compute checksum of plaintext proto for integrity (sum of bytes mod 2^32)
    checksum = sum(proto_json.encode('utf-8')) & 0xFFFFFFFF
    return enc_b64, checksum


def obfuscate_file(in_path: str, out_path: str, key: str = None):
    if key is None:
        key_bytes = secrets.token_bytes(16)
    else:
        key_bytes = key.encode('utf-8')
    import base64
    key_b64 = base64.b64encode(key_bytes).decode('ascii')
    with open(in_path, 'r', encoding='utf-8') as f:
        src = f.read()
    enc_blob_b64, checksum = obfuscate_source_to_bytecode(src, key_bytes)
    out_lua = build_output_lua(enc_blob_b64, key_b64, checksum)
    with open(out_path, 'w', encoding='utf-8') as f:
        f.write(out_lua)
    print(f"Obfuscated {in_path} -> {out_path}")
