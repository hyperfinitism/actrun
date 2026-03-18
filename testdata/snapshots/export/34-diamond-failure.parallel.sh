#!/usr/bin/env bash
set -eo pipefail

# Generated from workflow: diamond-failure
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
# Job: start
# ============================================================
job_START() {

  # --- Step 1 ---
  echo "start"

}

# ============================================================
# Job: left
# ============================================================
job_LEFT() {
  # depends on: start

  # --- Step 1 ---
  echo "left succeeds"

}

# ============================================================
# Job: right
# ============================================================
job_RIGHT() {
  # depends on: start

  # --- Step 1 ---
  echo "right fails" && exit 1

}

# ============================================================
# Job: merge
# ============================================================
job_MERGE() {
  # depends on: left, right

  # --- Step 1 ---
  echo "left: $_NEEDS_LEFT_RESULT"  # ← echo "left: ${{ needs.left.result }}"
  echo "right: $_NEEDS_RIGHT_RESULT"  # ← echo "right: ${{ needs.right.result }}"
  echo "merge runs despite right failure"

}

# ============================================================
# Job: final
# ============================================================
job_FINAL() {
  # depends on: merge

  # --- Step 1 ---
  echo "final always runs"

}

# ============================================================
# Run jobs
# ============================================================

# --- Layer 0 ---
job_START && _rc=0 || _rc=$?
if [ "$_rc" -eq 0 ]; then _NEEDS_START_RESULT=success; else _NEEDS_START_RESULT=failure; fi
[ -f "$_TMPDIR/start.env" ] && source "$_TMPDIR/start.env" || true

# --- Layer 1 ---
( job_LEFT && echo success > "$_TMPDIR/left.result" || echo failure > "$_TMPDIR/left.result" ) &
( job_RIGHT && echo success > "$_TMPDIR/right.result" || echo failure > "$_TMPDIR/right.result" ) &
wait

_NEEDS_LEFT_RESULT=$(cat "$_TMPDIR/left.result")
[ -f "$_TMPDIR/left.env" ] && source "$_TMPDIR/left.env"
_NEEDS_RIGHT_RESULT=$(cat "$_TMPDIR/right.result")
[ -f "$_TMPDIR/right.env" ] && source "$_TMPDIR/right.env"

# --- Layer 2 ---
job_MERGE && _rc=0 || _rc=$?
if [ "$_rc" -eq 0 ]; then _NEEDS_MERGE_RESULT=success; else _NEEDS_MERGE_RESULT=failure; fi
[ -f "$_TMPDIR/merge.env" ] && source "$_TMPDIR/merge.env" || true

# --- Layer 3 ---
job_FINAL && _rc=0 || _rc=$?
if [ "$_rc" -eq 0 ]; then _NEEDS_FINAL_RESULT=success; else _NEEDS_FINAL_RESULT=failure; fi
[ -f "$_TMPDIR/final.env" ] && source "$_TMPDIR/final.env" || true

