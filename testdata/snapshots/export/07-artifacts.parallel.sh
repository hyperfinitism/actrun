#!/usr/bin/env bash
set -eo pipefail

# Generated from workflow: artifacts
# This is an experimental approximation — review before running
# Requires: bash, jq

_TMPDIR=$(mktemp -d)
trap 'rm -rf "$_TMPDIR"' EXIT

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

  # --- Step 1 ---
  mkdir -p dist
  echo "built at $(date)" > dist/output.txt

  # --- Step 2 ---
  # Upload artifact: build-output
  mkdir -p "${ACTRUN_ARTIFACT_DIR:-.artifacts}/build-output"
  cp -r dist/ "${ACTRUN_ARTIFACT_DIR:-.artifacts}/build-output/"

}

# ============================================================
# Job: verify
# ============================================================
job_VERIFY() {
  # depends on: build

  # --- Step 1 ---
  # Download artifact: build-output
  cp -r "${ACTRUN_ARTIFACT_DIR:-.artifacts}/build-output/." downloaded/

  # --- Step 2 ---
  cat downloaded/output.txt

}

# ============================================================
# Run jobs
# ============================================================

# --- Layer 0 ---
job_BUILD && _rc=0 || _rc=$?
if [ "$_rc" -eq 0 ]; then _NEEDS_BUILD_RESULT=success; else _NEEDS_BUILD_RESULT=failure; fi
[ -f "$_TMPDIR/build.env" ] && source "$_TMPDIR/build.env" || true

# --- Layer 1 ---
job_VERIFY && _rc=0 || _rc=$?
if [ "$_rc" -eq 0 ]; then _NEEDS_VERIFY_RESULT=success; else _NEEDS_VERIFY_RESULT=failure; fi
[ -f "$_TMPDIR/verify.env" ] && source "$_TMPDIR/verify.env" || true

