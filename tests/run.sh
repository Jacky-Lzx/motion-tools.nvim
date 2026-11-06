#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
nvim --headless -u NONE -i NONE --noplugin -l tests/command_ownership.lua
test_root=$(mktemp -d "${TMPDIR:-/tmp}/motion-tools-tests.XXXXXX")
trap 'rm -rf "$test_root"' EXIT HUP INT TERM
export XDG_STATE_HOME="$test_root/state" XDG_CACHE_HOME="$test_root/cache"
export NVIM_LOG_FILE="$test_root/nvim.log" PYTHONDONTWRITEBYTECODE=1
"${NVIM_BIN:-nvim}" --headless -n -u NONE -i NONE --noplugin -l tests/core.lua
"${NVIM_BIN:-nvim}" --headless -n -u NONE -i NONE --noplugin -l tests/search_ui.lua
python3 tests/tui.py
stylua --check lua plugin tests
