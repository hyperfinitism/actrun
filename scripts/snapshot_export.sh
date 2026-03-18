#!/usr/bin/env bash
set -euo pipefail

# Generate export snapshots for examples.
# Usage: bash scripts/snapshot_export.sh [example...]

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLI_BIN="$REPO_ROOT/_build/native/debug/build/cmd/actrun/actrun.exe"
SNAPSHOT_DIR="$REPO_ROOT/testdata/snapshots/export"

if [ ! -x "$CLI_BIN" ]; then
  echo "Building CLI..."
  (cd "$REPO_ROOT" && moon build src/cmd/actrun --target native >/dev/null)
fi

EXAMPLES=(
  examples/01-hello.yml
  examples/02-env-and-outputs.yml
  examples/04-multi-job.yml
  examples/05-secrets.yml
  examples/07-artifacts.yml
  examples/09-conditional.yml
  examples/22-working-directory.yml
  examples/24-multiline-run.yml
  examples/25-continue-on-error.yml
  examples/26-step-outputs.yml
  examples/27-github-env.yml
  examples/28-job-outputs.yml
  examples/29-expressions.yml
  examples/33-deep-dependencies.yml
  examples/34-diamond-failure.yml
  examples/35-matrix-fan-in.yml
)

if [ "$#" -gt 0 ]; then
  examples=("$@")
else
  examples=("${EXAMPLES[@]}")
fi

mkdir -p "$SNAPSHOT_DIR"
pass=0

for example in "${examples[@]}"; do
  slug="$(basename "${example%.yml}")"
  example_path="$REPO_ROOT/$example"

  if [ ! -f "$example_path" ]; then
    echo "SKIP $slug (not found)"
    continue
  fi

  echo -n "EXPORT $slug... "
  "$CLI_BIN" export "$example_path" > "$SNAPSHOT_DIR/$slug.sh" 2>/dev/null
  # Also generate parallel variant
  "$CLI_BIN" export "$example_path" --parallel > "$SNAPSHOT_DIR/$slug.parallel.sh" 2>/dev/null
  echo "ok"
  pass=$((pass + 1))
done

echo ""
echo "Export snapshots: $pass saved"
echo "Saved to: $SNAPSHOT_DIR/"
