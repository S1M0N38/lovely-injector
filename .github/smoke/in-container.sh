#!/usr/bin/env bash
# Runs *inside* the container: installs the runtime bits a real game host needs
# (glibc dev headers for the stub host + shared LuaJIT), then loads liblovely.so
# and checks that the fixture patch was applied.
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

apt-get update -qq
apt-get install -y -qq --no-install-recommends gcc libc6-dev libluajit-5.1-2 >/dev/null

gcc -O1 -o /tmp/lua_host /smoke/lua_host.c -ldl

mkdir -p /mods
cp -r /smoke/mods/. /mods/

export LOVELY_MOD_DIR=/mods
export LD_PRELOAD=/dist/liblovely.so

out=$(/tmp/lua_host 2>&1 || true)
printf '%s\n' "$out"

grep -q HOST_RAN <<<"$out" || { echo "FAIL: host chunk never ran"; exit 1; }
grep -q LOVELY_SMOKE_OK <<<"$out" || { echo "FAIL: lovely did not apply the fixture patch"; exit 1; }

echo "PASS: liblovely.so loaded and patched inside $(. /etc/os-release && echo "$PRETTY_NAME") with glibc $(ldd --version | head -1 | awk '{print $NF}')"
