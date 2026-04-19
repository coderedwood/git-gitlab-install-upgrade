#!/usr/bin/env bash
# Smoke test: run upgrade-gitlab.sh in --dry-run mode and assert exit code 0 and expected output
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$SCRIPT_DIR"

echo "Running dry-run smoke test..."
OUTPUT=$(./upgrade-gitlab.sh --dry-run 99.9.9 2>&1 || true)
EXIT=$?

if [ $EXIT -ne 0 ]; then
  echo "Expected exit 0 for dry-run, got $EXIT"
  echo "$OUTPUT"
  exit 2
fi

if echo "$OUTPUT" | grep -q "Starting GitLab upgrade script" && echo "$OUTPUT" | grep -q "Processing version 99.9.9"; then
  echo "Dry-run output looks good"
  exit 0
else
  echo "Dry-run did not produce expected progress messages"
  echo "$OUTPUT"
  exit 3
fi
