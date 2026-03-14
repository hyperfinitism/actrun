#!/usr/bin/env sh
# Wrapper to run MoonBit wasm modules via wasmtime with spectest shim
# Usage: ACTRUN_WASM_BIN=moonbit-wasmtime.sh actrun workflow run ci.yml
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SHIM="$SCRIPT_DIR/moonbit_spectest_shim.wat"
exec wasmtime --preload "spectest=$SHIM" "$@"
