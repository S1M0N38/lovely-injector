#!/usr/bin/env bash
# Runs *inside* the container: installs the runtime bits a real game host needs
# (a C compiler for the stub host + the shared LuaJIT that lovely dlopens), then
# loads liblovely.so into the stub host and checks the fixture patch was applied.
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

apt-get update -qq
apt-get install -y -qq --no-install-recommends gcc libc6-dev libluajit-5.1-2 >/dev/null

# _GNU_SOURCE: RTLD_DEFAULT is only visible with __USE_GNU on older glibc
gcc -O1 -D_GNU_SOURCE -o /tmp/lua_host /smoke/lua_host.c -ldl

mkdir -p /mods
cp -r /smoke/mods/. /mods/

# LD_PRELOAD is scoped to the single process under test on purpose: lovely must
# only inject into the "game", never into gcc/grep/apt in this script.
out=$(LD_PRELOAD=/dist/liblovely.so LOVELY_MOD_DIR=/mods /tmp/lua_host 2>&1 || true)
printf '%s\n' "$out"

if ! grep -q HOST_RAN <<<"$out"; then
    echo "FAIL: host chunk never ran"
    echo "--- /mods ---"
    find /mods -maxdepth 4 | sort
    exit 1
fi
if ! grep -q LOVELY_SMOKE_OK <<<"$out"; then
    echo "FAIL: lovely did not apply the fixture patch"
    echo "--- /mods ---"
    find /mods -maxdepth 4 | sort
    echo "--- lovely log ---"
    cat /mods/lovely/log/*.log 2>/dev/null || true
    exit 1
fi

echo "PASS: liblovely.so loaded and patched inside $(. /etc/os-release && echo "$PRETTY_NAME") with glibc $(ldd --version | head -1 | awk '{print $NF}')"
