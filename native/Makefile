CC=gcc
CFLAGS=-O2 -fPIC
LUA_INC=/usr/include/lua5.1
LUA_LIB=/usr/lib
OUT=aurorax_dec.so

all:
	$(CC) $(CFLAGS) -shared -I$(LUA_INC) native/decmod.c -o $(OUT) -L$(LUA_LIB) -llua5.1 || $(CC) $(CFLAGS) -shared -I$(LUA_INC) native/decmod.c -o $(OUT) -L$(LUA_LIB) -llua

clean:
	rm -f $(OUT)
