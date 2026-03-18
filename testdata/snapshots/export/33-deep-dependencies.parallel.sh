#!/usr/bin/env bash
set -eo pipefail

# Generated from workflow: deep-dependencies
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
# Job: lint
# ============================================================
job_LINT() {

  # --- Step 1 ---
  echo "lint done"

}

# ============================================================
# Job: build-a
# ============================================================
job_BUILD_A() {
  # depends on: lint

  # --- ver ---
  _STEP_VER_VERSION=1.0.0

  # --- Step 2 ---
  echo "build-a done"

  # Export outputs to temp file for cross-job access
  {
    echo _NEEDS_BUILD_A_OUT_VERSION=$_STEP_VER_VERSION  # ← ${{ steps.ver.outputs.version }}
  } > "$_TMPDIR/build-a.env"

}

# ============================================================
# Job: build-b
# ============================================================
job_BUILD_B() {
  # depends on: lint

  # --- h ---
  _STEP_H_HASH=abc123

  # --- Step 2 ---
  echo "build-b done"

  # Export outputs to temp file for cross-job access
  {
    echo _NEEDS_BUILD_B_OUT_HASH=$_STEP_H_HASH  # ← ${{ steps.h.outputs.hash }}
  } > "$_TMPDIR/build-b.env"

}

# ============================================================
# Job: integration
# ============================================================
job_INTEGRATION() {
  # depends on: build-a, build-b

  # --- Step 1 ---
  echo "version: $_NEEDS_BUILD_A_OUT_VERSION"  # ← echo "version: ${{ needs.build-a.outputs.version }}"
  echo "hash: $_NEEDS_BUILD_B_OUT_HASH"  # ← echo "hash: ${{ needs.build-b.outputs.hash }}"
  echo "integration done"

}

# ============================================================
# Job: deploy
# ============================================================
job_DEPLOY() {
  # depends on: integration

  # --- Step 1 ---
  echo "deploy done"

}

# ============================================================
# Run jobs
# ============================================================

# --- Layer 0 ---
job_LINT && _rc=0 || _rc=$?
if [ "$_rc" -eq 0 ]; then _NEEDS_LINT_RESULT=success; else _NEEDS_LINT_RESULT=failure; fi
[ -f "$_TMPDIR/lint.env" ] && source "$_TMPDIR/lint.env" || true

# --- Layer 1 ---
( job_BUILD_A && echo success > "$_TMPDIR/build-a.result" || echo failure > "$_TMPDIR/build-a.result" ) &
( job_BUILD_B && echo success > "$_TMPDIR/build-b.result" || echo failure > "$_TMPDIR/build-b.result" ) &
wait

_NEEDS_BUILD_A_RESULT=$(cat "$_TMPDIR/build-a.result")
[ -f "$_TMPDIR/build-a.env" ] && source "$_TMPDIR/build-a.env"
_NEEDS_BUILD_B_RESULT=$(cat "$_TMPDIR/build-b.result")
[ -f "$_TMPDIR/build-b.env" ] && source "$_TMPDIR/build-b.env"

# --- Layer 2 ---
job_INTEGRATION && _rc=0 || _rc=$?
if [ "$_rc" -eq 0 ]; then _NEEDS_INTEGRATION_RESULT=success; else _NEEDS_INTEGRATION_RESULT=failure; fi
[ -f "$_TMPDIR/integration.env" ] && source "$_TMPDIR/integration.env" || true

# --- Layer 3 ---
job_DEPLOY && _rc=0 || _rc=$?
if [ "$_rc" -eq 0 ]; then _NEEDS_DEPLOY_RESULT=success; else _NEEDS_DEPLOY_RESULT=failure; fi
[ -f "$_TMPDIR/deploy.env" ] && source "$_TMPDIR/deploy.env" || true

