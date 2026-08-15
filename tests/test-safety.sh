#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=tests/test-lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/test-lib.sh"

new_test_home
trap cleanup_test_home EXIT

unsafe_roots=(
  AGENT_CONFIG_CLAUDE_DIR
  AGENT_CONFIG_CODEX_DIR
  AGENT_CONFIG_KIMI_DIR
  AGENT_CONFIG_OPENCODE_DIR
  AGENT_CONFIG_AGENTS_DIR
  AGENT_CONFIG_STATE_DIR
  AGENT_CONFIG_PROFILE_LOCAL
  AGENT_CONFIG_WINDOWS_CODEX_DIR
)

for variable in "${unsafe_roots[@]}"; do
  if env "$variable=/" "$TEST_ROOT/install.sh" --dry-run \
    >"$TEST_TMP/unsafe-$variable.out" 2>&1; then
    printf 'installer accepted unsafe root: %s=/\n' "$variable" >&2
    exit 1
  fi
  grep -Fq 'unsafe path override' "$TEST_TMP/unsafe-$variable.out"
done

mkdir -p "$HOME/.config/opencode"
printf '%s\n' '{"first":1}' >"$HOME/.config/opencode/opencode.json"
AGENT_CONFIG_BACKUP_STAMP=fixed \
  "$TEST_ROOT/install.sh" --only opencode >/dev/null
printf '%s\n' '{"second":2}' >"$HOME/.config/opencode/opencode.json"
AGENT_CONFIG_BACKUP_STAMP=fixed \
  "$TEST_ROOT/install.sh" --only opencode >/dev/null

first_backup="$HOME/.config/opencode/backups/fixed/opencode.json"
second_backup="$first_backup.1"
grep -Fq '"first":1' "$first_backup"
grep -Fq '"second":2' "$second_backup"

printf 'safety tests: PASS\n'
