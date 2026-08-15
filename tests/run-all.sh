#!/usr/bin/env bash

set -euo pipefail

# macOS ships bash 3.2, which has neither mapfile nor associative arrays.
if [ "${BASH_VERSINFO[0]:-0}" -lt 4 ]; then
  for candidate in /opt/homebrew/bin/bash /usr/local/bin/bash; do
    candidate_major="$("$candidate" -c 'echo ${BASH_VERSINFO[0]}' 2>/dev/null || echo 0)"
    if [ "${candidate_major:-0}" -ge 4 ]; then
      exec "$candidate" "$0" "$@"
    fi
  done
  printf '%s\n' 'agent-config requires bash >= 4; install it with: brew install bash' >&2
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tests=(
  test-structure.sh
  test-validate-skills.sh
  test-python.sh
  test-install.sh
  test-instructions.sh
  test-configs.sh
  test-windows.sh
  test-safety.sh
  test-check.sh
  test-hooks.sh
  test-claude-extras.sh
  test-codex-plugins.sh
  test-update.sh
  test-cutover-guard.sh
  test-opencode.sh
)

for test_file in "${tests[@]}"; do
  printf '\n==> %s\n' "$test_file"
  "$BASH" "$ROOT/tests/$test_file"
done

printf '\nall tests: PASS\n'
