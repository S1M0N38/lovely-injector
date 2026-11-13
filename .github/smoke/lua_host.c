/*
 * Minimal stand-in for a LÖVE runtime, used by the container smoke test.
 *
 * It opens the shared LuaJIT (the same soname lovely dlopens), then loads and
 * runs a chunk named "@main.lua" through luaL_loadbufferx -- the exact function
 * lovely hooks. If the lovely patch in the fixture mod is applied, the chunk
 * prints LOVELY_SMOKE_OK.
 *
 * Everything is resolved with dlsym so the file compiles anywhere with a bare
 * gcc (no lua headers, no link-time dependency on luajit).
 */
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct lua_State lua_State;

static const char *CHUNK =
    "SMOKE_BASE = 1\n"
    "print('HOST_RAN')\n";

int main(void) {
    void *lib = dlopen("libluajit-5.1.so.2", RTLD_NOW | RTLD_GLOBAL);
    if (lib == NULL) {
        fprintf(stderr, "lua_host: dlopen(libluajit-5.1.so.2): %s\n", dlerror());
        return 10;
    }

    lua_State *(*luaL_newstate)(void) = dlsym(lib, "luaL_newstate");
    void (*luaL_openlibs)(lua_State *) = dlsym(lib, "luaL_openlibs");
    int (*luaL_loadbufferx)(lua_State *, const char *, size_t, const char *,
                            const char *) = dlsym(lib, "luaL_loadbufferx");
    int (*lua_pcall)(lua_State *, int, int, int) = dlsym(lib, "lua_pcall");
    const char *(*lua_tolstring)(lua_State *, int, size_t *) =
        dlsym(lib, "lua_tolstring");
    void (*lua_close)(lua_State *) = dlsym(lib, "lua_close");

    if (luaL_newstate == NULL || luaL_openlibs == NULL ||
        luaL_loadbufferx == NULL || lua_pcall == NULL ||
        lua_tolstring == NULL || lua_close == NULL) {
        fprintf(stderr, "lua_host: shared luajit is missing a required symbol\n");
        return 11;
    }

    lua_State *L = luaL_newstate();
    luaL_openlibs(L);

    if (luaL_loadbufferx(L, CHUNK, strlen(CHUNK), "@main.lua", NULL) != 0) {
        size_t len = 0;
        const char *err = lua_tolstring(L, -1, &len);
        fprintf(stderr, "lua_host: load error: %.*s\n", (int)len, err ? err : "?");
        return 12;
    }
    if (lua_pcall(L, 0, 0, 0) != 0) {
        size_t len = 0;
        const char *err = lua_tolstring(L, -1, &len);
        fprintf(stderr, "lua_host: run error: %.*s\n", (int)len, err ? err : "?");
        return 13;
    }

    lua_close(L);
    return 0;
}
