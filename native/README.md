# Native decoder module for Aurora X Obfuscator

This directory contains a small C module that implements native decryption of the
base64+XOR-encrypted bytecode blob. Building and loading this module greatly
increases resistance against static analysis in environments like Termux
and typical Linux targets.

Features
- base64 decode implemented in C
- recomposition of shuffled key fragments and XOR decryption in C
- exposes a single Lua function: decrypt_blob(blob_b64, frags_table, order_table)
  which returns the decrypted JSON string on success or (nil, errmsg) on error.

Build
- Linux x86_64 (Debian/Ubuntu with lua5.1 dev):

  export LUA_INC=/usr/include/lua5.1
  export LUA_LIB=/usr/lib
  ./build.sh

  This produces aurorax_dec.so which you can place next to the loader or in
  package.cpath locations so `require('aurorax_dec')` works.

- Termux/Android
  Use clang and Termux headers; typical paths in Termux are
  /data/data/com.termux/files/usr/include and /data/data/com.termux/files/usr/lib.
  You can adjust LUA_INC/LUA_LIB environment variables and run build.sh there.

Notes
- The module is intentionally small and uses only standard libc + Lua C API.
- You may need to adjust linking depending on your Lua installation (lua5.1 vs lua5.3).
