#!/usr/bin/env bash

set -euo pipefail

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
  bash "$ROOT/tests/$test_file"
done

printf '\nall tests: PASS\n'
