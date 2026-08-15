#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=tests/test-lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/test-lib.sh"

new_test_home
trap cleanup_test_home EXIT

mkdir -p "$HOME/.agents/skills" "$HOME/.codex/skills"
mkdir -p "$HOME/foreign-skill"
ln -s "$HOME/foreign-skill" "$HOME/.agents/skills/foreign"
ln -s /missing/foreign-skill "$HOME/.agents/skills/foreign-broken"
ln -s /home/cyril/src/codex-config/skills/removed "$HOME/.agents/skills/legacy-removed"

"$TEST_ROOT/install.sh" --only codex

assert_link_to \
  "$HOME/.agents/skills/api-design" \
  "$TEST_ROOT/shared/skills/api-design"
assert_link_to \
  "$HOME/.codex/skills/wsl-windows-gui" \
  "$TEST_ROOT/harnesses/codex/skills/wsl-windows-gui"
assert_not_exists "$HOME/.codex/skills/api-design"
assert_link_to "$HOME/.agents/skills/foreign" "$HOME/foreign-skill"
assert_link_to "$HOME/.agents/skills/foreign-broken" /missing/foreign-skill
assert_not_exists "$HOME/.agents/skills/legacy-removed"

assert_file "$AGENT_CONFIG_WINDOWS_CODEX_DIR/skills/api-design/SKILL.md"
assert_file "$AGENT_CONFIG_WINDOWS_CODEX_DIR/skills/wsl-windows-gui/SKILL.md"
[ ! -L "$AGENT_CONFIG_WINDOWS_CODEX_DIR/skills/api-design" ]

backup_count_before=0
if [ -d "$HOME/.codex/backups" ]; then
  backup_count_before="$(find "$HOME/.codex/backups" -type f | wc -l)"
fi
"$TEST_ROOT/install.sh" --only codex >/dev/null
backup_count_after=0
if [ -d "$HOME/.codex/backups" ]; then
  backup_count_after="$(find "$HOME/.codex/backups" -type f | wc -l)"
fi
[ "$backup_count_before" = "$backup_count_after" ] || {
  printf '%s\n' 'idempotent install created an extra backup' >&2
  exit 1
}

"$TEST_ROOT/install.sh" --only claude
assert_link_to \
  "$HOME/.claude/skills/api-design" \
  "$TEST_ROOT/shared/skills/api-design"
assert_link_to \
  "$HOME/.claude/skills/linear" \
  "$TEST_ROOT/harnesses/claude/skills/linear"

"$TEST_ROOT/install.sh" --only kimi
assert_link_to \
  "$HOME/.kimi-code/skills/commit" \
  "$TEST_ROOT/harnesses/kimi/skills/commit"

"$TEST_ROOT/install.sh" --only opencode
assert_dir "$HOME/.config/opencode/skills"

collision_root="$TEST_TMP/collision-source"
mkdir -p \
  "$collision_root/shared/skills/api-design" \
  "$collision_root/harnesses/codex/skills/api-design"
cp "$TEST_ROOT/install.sh" "$collision_root/install.sh"
chmod +x "$collision_root/install.sh"
collision_home="$TEST_TMP/collision-home"
mkdir -p "$collision_home"
if HOME="$collision_home" AGENT_CONFIG_WINDOWS_CODEX_DIR='' \
  "$collision_root/install.sh" --dry-run --only codex >"$TEST_TMP/collision.out" 2>&1; then
  printf '%s\n' 'shared/specific skill collision was accepted' >&2
  exit 1
fi
grep -q 'skill collision for codex: api-design' "$TEST_TMP/collision.out"
[ -z "$(find "$collision_home" -mindepth 1 -print -quit)" ]

printf 'install tests: PASS\n'
