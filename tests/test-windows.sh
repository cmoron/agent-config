#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=tests/test-lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/test-lib.sh"

new_test_home
trap cleanup_test_home EXIT

mkdir -p \
  "$AGENT_CONFIG_WINDOWS_CODEX_DIR/scripts" \
  "$AGENT_CONFIG_WINDOWS_CODEX_DIR/skills/removed" \
  "$AGENT_CONFIG_WINDOWS_CODEX_DIR/skills/foreign"
printf '%s\n' 'legacy managed script' >"$AGENT_CONFIG_WINDOWS_CODEX_DIR/scripts/legacy.sh"
printf '%s\n' 'remove me' >"$AGENT_CONFIG_WINDOWS_CODEX_DIR/skills/removed/SKILL.md"
printf '%s\n' 'preserve me' >"$AGENT_CONFIG_WINDOWS_CODEX_DIR/skills/foreign/SKILL.md"
printf '%s\n' scripts skills/removed >"$AGENT_CONFIG_WINDOWS_CODEX_DIR/.codex-config-managed"
cp "$TEST_ROOT/tests/fixtures/windows-config.toml" \
  "$AGENT_CONFIG_WINDOWS_CODEX_DIR/config.toml"
config_hash="$(sha256sum "$AGENT_CONFIG_WINDOWS_CODEX_DIR/config.toml" | awk '{print $1}')"

"$TEST_ROOT/install.sh" --only codex >/dev/null

assert_not_exists "$AGENT_CONFIG_WINDOWS_CODEX_DIR/skills/removed"
assert_file "$AGENT_CONFIG_WINDOWS_CODEX_DIR/skills/foreign/SKILL.md"
assert_not_exists "$AGENT_CONFIG_WINDOWS_CODEX_DIR/.codex-config-managed"
assert_file "$AGENT_CONFIG_WINDOWS_CODEX_DIR/.agent-config-managed"
grep -Fxq scripts "$AGENT_CONFIG_WINDOWS_CODEX_DIR/.agent-config-managed"
grep -Fxq skills/api-design "$AGENT_CONFIG_WINDOWS_CODEX_DIR/.agent-config-managed"
[ ! -d "$AGENT_CONFIG_WINDOWS_CODEX_DIR/backups" ] || {
  printf '%s\n' 'known Windows managed paths were backed up during replacement' >&2
  exit 1
}

after_config_hash="$(sha256sum "$AGENT_CONFIG_WINDOWS_CODEX_DIR/config.toml" | awk '{print $1}')"
[ "$config_hash" = "$after_config_hash" ] || {
  printf '%s\n' 'existing Windows config.toml was modified' >&2
  exit 1
}

snapshot_before="$(tree_fingerprint "$AGENT_CONFIG_WINDOWS_CODEX_DIR")"
"$TEST_ROOT/install.sh" --only codex >/dev/null
snapshot_after="$(tree_fingerprint "$AGENT_CONFIG_WINDOWS_CODEX_DIR")"
[ "$snapshot_before" = "$snapshot_after" ] || {
  printf '%s\n' 'second Windows deployment changed the managed tree' >&2
  exit 1
}

# DrvFS exposes Windows files with synthetic POSIX modes (commonly 777). Those
# modes must not make an otherwise identical Windows deployment drift forever.
find "$AGENT_CONFIG_WINDOWS_CODEX_DIR" -type f -exec chmod 777 {} +
find "$AGENT_CONFIG_WINDOWS_CODEX_DIR" -type d -exec chmod 777 {} +
"$TEST_ROOT/install.sh" --only codex --check >/dev/null

printf 'windows tests: PASS\n'
