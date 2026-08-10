/* aurorax_dec native module
 * Exposes: decrypt_blob(blob_b64, frags_table, order_table) -> decrypted_string | nil, errmsg
 * Compatible with Lua 5.1/5.2/5.3 (uses standard Lua C API)
 */

#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

/* Minimal base64 decoder */
static unsigned char *b64_decode(const char *data, size_t len, size_t *out_len) {
    if (!data) return NULL;
    const char *b64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    unsigned char dtable[256];
    memset(dtable, 0x80, 256);
    for (size_t i = 0; i < 64; i++) dtable[(unsigned char)b64[i]] = i;
    dtable['='] = 0;

    unsigned char *out = malloc(len);
    if (!out) return NULL;
    size_t outi = 0;
    uint32_t buf = 0;
    int bufbits = 0;
    for (size_t i = 0; i < len; i++) {
        unsigned char c = data[i];
        if (dtable[c] & 0x80) continue; /* skip non-base64 */
        buf = (buf << 6) | dtable[c];
        bufbits += 6;
        if (bufbits >= 8) {
            bufbits -= 8;
            out[outi++] = (unsigned char)((buf >> bufbits) & 0xFF);
        }
    }
    *out_len = outi;
    return out;
}

static int l_decrypt_blob(lua_State *L) {
    size_t blob_len = 0;
    const char *blob_b64 = luaL_checklstring(L, 1, &blob_len);
    if (!blob_b64) { lua_pushnil(L); lua_pushstring(L, "bad blob"); return 2; }

    if (!lua_istable(L, 2)) { lua_pushnil(L); lua_pushstring(L, "fragments must be table"); return 2; }
    if (!lua_istable(L, 3)) { lua_pushnil(L); lua_pushstring(L, "order must be table"); return 2; }

    /* Read fragments into C array */
    /* Determine count by iterating until nil */
    lua_pushnil(L); /* for iteration */
    int frag_count = 0;
    /* We'll use lua_rawlen when available by calling lua_rawlen if present */
#if LUA_VERSION_NUM >= 502
    frag_count = (int)lua_rawlen(L, 2);
#else
    /* fallback: iterate */
    lua_pushnil(L);
    while (lua_next(L, 2) != 0) {
        lua_pop(L, 1);
        frag_count++;
    }
#endif
    if (frag_count <= 0) { lua_pushnil(L); lua_pushstring(L, "no fragments"); return 2; }

    char **frags = (char **)malloc(sizeof(char*) * frag_count);
    if (!frags) { lua_pushnil(L); lua_pushstring(L, "alloc fail"); return 2; }
    for (int i = 0; i < frag_count; i++) {
        lua_rawgeti(L, 2, i+1);
        size_t s_len = 0;
        const char *s = luaL_checklstring(L, -1, &s_len);
        frags[i] = (char*)malloc(s_len+1);
        memcpy(frags[i], s, s_len);
        frags[i][s_len] = '\0';
        lua_pop(L, 1);
    }

    /* Read order table */
    int ord_count = 0;
#if LUA_VERSION_NUM >= 502
    ord_count = (int)lua_rawlen(L, 3);
#else
    lua_pushnil(L);
    while (lua_next(L, 3) != 0) { lua_pop(L, 1); ord_count++; }
#endif
    if (ord_count != frag_count) {
        /* If mismatch, tolerate but proceed using min(ord_count, frag_count) */
        /* continue */
    }

    int *order = (int*)malloc(sizeof(int) * ord_count);
    for (int i = 0; i < ord_count; i++) {
        lua_rawgeti(L, 3, i+1);
        if (!lua_isnumber(L, -1)) { order[i] = i; } else { order[i] = (int)lua_tointeger(L, -1); }
        lua_pop(L, 1);
    }

    /* Reconstruct key_b64 string */
    /* parts[order[i]+1] = frags[i] */
    /* Determine how many parts we need: find max index in order */
    int maxidx = -1;
    for (int i = 0; i < ord_count; i++) if (order[i] > maxidx) maxidx = order[i];
    int parts_count = maxidx + 1;
    char **parts = (char**)calloc(parts_count, sizeof(char*));
    for (int i = 0; i < ord_count; i++) {
        int pos = order[i];
        if (pos >= 0 && pos < parts_count) {
            parts[pos] = frags[i];
            frags[i] = NULL; /* transferred */
        }
    }

    /* Concatenate parts into key_b64 */
    size_t key_b64_len = 0;
    for (int i = 0; i < parts_count; i++) if (parts[i]) key_b64_len += strlen(parts[i]);
    char *key_b64 = (char*)malloc(key_b64_len+1);
    key_b64[0] = '\0';
    for (int i = 0; i < parts_count; i++) if (parts[i]) strcat(key_b64, parts[i]);

    /* base64 decode key */
    size_t key_bin_len = 0;
    unsigned char *key_bin = b64_decode(key_b64, strlen(key_b64), &key_bin_len);
    if (!key_bin) { lua_pushnil(L); lua_pushstring(L, "key decode failed"); goto cleanup; }

    /* base64 decode blob */
    size_t enc_len = 0;
    unsigned char *enc = b64_decode(blob_b64, blob_len, &enc_len);
    if (!enc) { lua_pushnil(L); lua_pushstring(L, "blob decode failed"); free(key_bin); goto cleanup; }

    /* XOR decrypt */
    unsigned char *plain = (unsigned char*)malloc(enc_len + 1);
    if (!plain) { lua_pushnil(L); lua_pushstring(L, "alloc fail"); free(key_bin); free(enc); goto cleanup; }
    for (size_t i = 0; i < enc_len; i++) {
        plain[i] = enc[i] ^ key_bin[i % key_bin_len];
    }
    plain[enc_len] = '\0';

    lua_pushlstring(L, (const char*)plain, enc_len);

    /* cleanup */
    free(plain);
    free(key_bin);
    free(enc);
    free(key_b64);
    for (int i = 0; i < frag_count; i++) if (frags[i]) free(frags[i]);
    free(frags);
    free(order);
    free(parts);
    return 1;

cleanup:
    /* free allocated memory */
    if (key_b64) free(key_b64);
    for (int i = 0; i < frag_count; i++) if (frags[i]) free(frags[i]);
    free(frags);
    if (order) free(order);
    if (parts) free(parts);
    return 2;
}

int luaopen_aurorax_dec(lua_State *L) {
    lua_newtable(L);
    lua_pushcfunction(L, l_decrypt_blob);
    lua_setfield(L, -2, "decrypt_blob");
    return 1;
}
