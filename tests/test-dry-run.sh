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
else
  echo "Dry-run did not produce expected progress messages"
  echo "$OUTPUT"
  exit 3
fi

echo "Running dry-run args parser test..."
OUTPUT2=$(./upgrade-gitlab.sh --dry-run 17.8.7 => 17.11.7 => 18.2.8 2>&1 || true)
if echo "$OUTPUT2" | grep -q "Processing version 17.8.7" && echo "$OUTPUT2" | grep -q "Processing version 18.2.8"; then
  echo "Argument parsing output looks good"
  exit 0
else
  echo "Argument parsing failed for arrow-separated args"
  echo "$OUTPUT2"
  exit 4
fi
