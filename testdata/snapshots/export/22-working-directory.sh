#!/usr/bin/env bash
set -eo pipefail

# Generated from workflow: working-directory
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
# Job: step-level
# ============================================================
job_STEP_LEVEL() {

  # --- Step 1 ---
  mkdir -p subdir && echo "content" > subdir/file.txt

  # --- Read from subdirectory ---
  pushd subdir > /dev/null
  cat file.txt
  popd > /dev/null

}

# ============================================================
# Job: defaults-level
# ============================================================
job_DEFAULTS_LEVEL() {

  # --- Step 1 ---
  pushd . > /dev/null
  mkdir -p src && echo "from defaults" > src/output.txt
  popd > /dev/null

  # --- Read in default directory ---
  cat output.txt

  # --- Write and read ---
  echo "hello" > test.txt
  cat test.txt

}

# ============================================================
# Run jobs
# ============================================================

job_STEP_LEVEL && _rc=0 || _rc=$?
if [ "$_rc" -eq 0 ]; then _NEEDS_STEP_LEVEL_RESULT=success; else _NEEDS_STEP_LEVEL_RESULT=failure; fi

job_DEFAULTS_LEVEL && _rc=0 || _rc=$?
if [ "$_rc" -eq 0 ]; then _NEEDS_DEFAULTS_LEVEL_RESULT=success; else _NEEDS_DEFAULTS_LEVEL_RESULT=failure; fi

