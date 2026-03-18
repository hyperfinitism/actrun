#!/usr/bin/env bash
set -eo pipefail

# Generated from workflow: matrix-fan-in
# This is an experimental approximation — review before running
# Requires: bash, jq

# --- GitHub Actions expression helpers ---
gha_contains() { [[ "$1" == *"$2"* ]]; }
gha_startsWith() { [[ "$1" == "$2"* ]]; }
gha_endsWith() { [[ "$1" == *"$2" ]]; }
gha_format() { local fmt="$1"; shift; printf "$fmt" "$@"; }
gha_join() { local IFS="${2:-,}"; echo "${1[*]}"; }
gha_toJSON() { jq -n --argjson v "$(printenv | jq -Rs 'split("\n") | map(select(length > 0) | split("=") | {(.[0]): (.[1:] | join("="))}) | add // {}')" '$v'; }
gha_fromJSON() { echo "$1" | jq -r '.'; }
gha_hashFiles() { cat "$@" 2>/dev/null | sha256sum | cut -d' ' -f1; }
gha_success() { [ "${_NEEDS_LAST_RESULT:-success}" = "success" ]; }
gha_failure() { [ "${_NEEDS_LAST_RESULT:-success}" = "failure" ]; }
gha_always() { true; }
gha_cancelled() { false; }

# ============================================================
# Job: build
# ============================================================
job_BUILD() {
  # matrix — defaulting to first combination:
  : "${MATRIX_TARGET:=linux}"

  # --- Step 1 ---
  echo "building $MATRIX_TARGET"  # ← echo "building ${{ matrix.target }}"

}

# ============================================================
# Job: deploy
# ============================================================
job_DEPLOY() {
  # depends on: build

  # --- Step 1 ---
  echo "all 3 builds done, deploying"

}

# ============================================================
# Run jobs
# ============================================================

job_BUILD && _rc=0 || _rc=$?
if [ "$_rc" -eq 0 ]; then _NEEDS_BUILD_RESULT=success; else _NEEDS_BUILD_RESULT=failure; fi

job_DEPLOY && _rc=0 || _rc=$?
if [ "$_rc" -eq 0 ]; then _NEEDS_DEPLOY_RESULT=success; else _NEEDS_DEPLOY_RESULT=failure; fi

