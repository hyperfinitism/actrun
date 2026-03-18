#!/usr/bin/env bash
set -euo pipefail

# Verify export snapshots match. Re-exports and compares with golden files.
# Usage: bash scripts/snapshot_export_verify.sh [example...]

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLI_BIN="$REPO_ROOT/_build/native/debug/build/cmd/actrun/actrun.exe"
SNAPSHOT_DIR="$REPO_ROOT/testdata/snapshots/export"
ACTUAL_DIR="$REPO_ROOT/_build/snapshot-verify-export"

if [ ! -x "$CLI_BIN" ]; then
  echo "Building CLI..."
  (cd "$REPO_ROOT" && moon build src/cmd/actrun --target native >/dev/null)
fi

if [ ! -d "$SNAPSHOT_DIR" ]; then
  echo "error: no snapshots in $SNAPSHOT_DIR"
  echo "Run 'just snapshot-export-update' first"
  exit 1
fi

# Collect snapshot files (non-parallel only for listing)
if [ "$#" -gt 0 ]; then
  snapshots=()
  for arg in "$@"; do
    slug="$(basename "${arg%.yml}")"
    snapshots+=("$SNAPSHOT_DIR/$slug.sh")
  done
else
  snapshots=()
  for f in "$SNAPSHOT_DIR"/*.sh; do
    # Skip .parallel.sh files; we'll check them alongside
    case "$f" in *.parallel.sh) continue ;; esac
    snapshots+=("$f")
  done
fi

rm -rf "$ACTUAL_DIR"
mkdir -p "$ACTUAL_DIR"

pass=0
fail=0

for snapshot_file in "${snapshots[@]}"; do
  slug="$(basename "${snapshot_file%.sh}")"
  example="$REPO_ROOT/examples/$slug.yml"

  if [ ! -f "$example" ]; then
    echo "SKIP $slug (example not found)"
    continue
  fi

  # Sequential
  echo -n "VERIFY $slug... "
  "$CLI_BIN" export "$example" > "$ACTUAL_DIR/$slug.sh" 2>/dev/null
  if diff -q "$snapshot_file" "$ACTUAL_DIR/$slug.sh" > /dev/null 2>&1; then
    echo -n "ok"
  else
    echo -n "MISMATCH"
    diff --color=auto "$snapshot_file" "$ACTUAL_DIR/$slug.sh" | head -20
    fail=$((fail + 1))
    echo ""
    continue
  fi

  # Parallel
  parallel_snapshot="$SNAPSHOT_DIR/$slug.parallel.sh"
  if [ -f "$parallel_snapshot" ]; then
    "$CLI_BIN" export "$example" --parallel > "$ACTUAL_DIR/$slug.parallel.sh" 2>/dev/null
    if diff -q "$parallel_snapshot" "$ACTUAL_DIR/$slug.parallel.sh" > /dev/null 2>&1; then
      echo " (parallel ok)"
    else
      echo " (parallel MISMATCH)"
      diff --color=auto "$parallel_snapshot" "$ACTUAL_DIR/$slug.parallel.sh" | head -20
      fail=$((fail + 1))
      continue
    fi
  else
    echo ""
  fi

  pass=$((pass + 1))
done

echo ""
echo "Verify: $pass passed, $fail failed"

[ "$fail" -eq 0 ]
