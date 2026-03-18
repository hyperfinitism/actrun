#!/usr/bin/env bash
set -eo pipefail

# Generated from workflow: job-outputs
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
# Job: producer
# ============================================================
job_PRODUCER() {

  # --- Compute ---
  _STEP_COMPUTE_VALUE=from-producer

  # Job outputs
  _NEEDS_PRODUCER_OUT_RESULT=$_STEP_COMPUTE_VALUE  # ← ${{ steps.compute.outputs.value }}

}

# ============================================================
# Job: consumer
# ============================================================
job_CONSUMER() {
  # depends on: producer

  # --- Use job output ---
  echo "Got: $_NEEDS_PRODUCER_OUT_RESULT"  # ← echo "Got: ${{ needs.producer.outputs.result }}"

}

# ============================================================
# Run jobs
# ============================================================

job_PRODUCER && _rc=0 || _rc=$?
if [ "$_rc" -eq 0 ]; then _NEEDS_PRODUCER_RESULT=success; else _NEEDS_PRODUCER_RESULT=failure; fi

job_CONSUMER && _rc=0 || _rc=$?
if [ "$_rc" -eq 0 ]; then _NEEDS_CONSUMER_RESULT=success; else _NEEDS_CONSUMER_RESULT=failure; fi

