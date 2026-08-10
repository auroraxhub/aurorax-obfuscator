# Build script for aurorax_dec native module

set -e
LUA_INC=${LUA_INC:-/usr/include/lua5.1}
LUA_LIB=${LUA_LIB:-/usr/lib}
OUT=aurorax_dec.so

echo "Building aurorax_dec.so using LUA_INC=${LUA_INC} LUA_LIB=${LUA_LIB}"

gcc -O2 -fPIC -shared -I"${LUA_INC}" native/decmod.c -o "${OUT}" -L"${LUA_LIB}" -llua5.1 || \
gcc -O2 -fPIC -shared -I"${LUA_INC}" native/decmod.c -o "${OUT}" -L"${LUA_LIB}" -llua || \
clang -O2 -fPIC -shared -I"${LUA_INC}" native/decmod.c -o "${OUT}"

echo "Built ${OUT}"
