#!/bin/sh
# Run syntax checks, lint, and every regression test from the repository root.
set -eu
cd "$(dirname "$0")/.."

if command -v lua5.1 >/dev/null 2>&1; then
    luac5.1 -p YardsToKm.lua tests/*.lua
    run() { lua5.1 "$1"; }
else
    echo "lua5.1 not found; running tests with fengari (no syntax check)"
    run() { npm exec --yes --package=fengari-node-cli -- fengari "$1"; }
fi

if command -v luacheck >/dev/null 2>&1; then
    luacheck YardsToKm.lua tests
else
    echo "luacheck not found; skipping lint"
fi

for test in tests/*.lua; do
    run "$test"
done
