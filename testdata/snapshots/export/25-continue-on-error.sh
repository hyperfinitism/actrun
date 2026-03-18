#!/usr/bin/env bash
set -eo pipefail

# Generated from workflow: continue-on-error
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
# Job: test
# ============================================================
job_TEST() {

  # --- This fails but continues ---
  exit 1

  # --- This should still run ---
  echo "still running"

  # --- Check previous outcome ---
  echo "previous step continued despite error"

}

# ============================================================
# Run jobs
# ============================================================

job_TEST && _rc=0 || _rc=$?
if [ "$_rc" -eq 0 ]; then _NEEDS_TEST_RESULT=success; else _NEEDS_TEST_RESULT=failure; fi

