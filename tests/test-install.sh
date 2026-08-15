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
ln -s "$HOME/src/codex-config/skills/removed" "$HOME/.agents/skills/legacy-removed"
ln -s "$HOME/src/skills/skills/personal/removed" "$HOME/.agents/skills/legacy-matt-removed"

"$TEST_ROOT/install.sh" --only codex

assert_link_to \
  "$HOME/.agents/skills/api-design" \
  "$TEST_ROOT/shared/skills/api-design"
assert_link_to \
  "$HOME/.agents/skills/ask-matt" \
  "$TEST_ROOT/upstreams/mattpocock-skills/skills/engineering/ask-matt"
assert_link_to \
  "$HOME/.agents/skills/grill-with-docs" \
  "$TEST_ROOT/upstreams/mattpocock-skills/skills/engineering/grill-with-docs"
# Tous les skills sont partages : le home Codex n'en contient aucun, le hub les a tous.
assert_link_to \
  "$HOME/.agents/skills/wsl-windows-gui" \
  "$TEST_ROOT/shared/skills/wsl-windows-gui"
assert_not_exists "$HOME/.codex/skills/api-design"
assert_not_exists "$HOME/.codex/skills/wsl-windows-gui"
assert_link_to "$HOME/.agents/skills/foreign" "$HOME/foreign-skill"
assert_link_to "$HOME/.agents/skills/foreign-broken" /missing/foreign-skill
assert_not_exists "$HOME/.agents/skills/legacy-removed"
assert_not_exists "$HOME/.agents/skills/legacy-matt-removed"

assert_file "$AGENT_CONFIG_WINDOWS_CODEX_DIR/skills/api-design/SKILL.md"
assert_file "$AGENT_CONFIG_WINDOWS_CODEX_DIR/skills/ask-matt/SKILL.md"
assert_file "$AGENT_CONFIG_WINDOWS_CODEX_DIR/skills/wsl-windows-gui/SKILL.md"
assert_file "$AGENT_CONFIG_WINDOWS_CODEX_DIR/config.toml"
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
  "$HOME/.claude/skills/ask-matt" \
  "$TEST_ROOT/upstreams/mattpocock-skills/skills/engineering/ask-matt"
assert_link_to \
  "$HOME/.claude/skills/linear" \
  "$TEST_ROOT/shared/skills/linear"
assert_link_to \
  "$HOME/.claude/skills/wsl-windows-gui" \
  "$TEST_ROOT/shared/skills/wsl-windows-gui"

"$TEST_ROOT/install.sh" --only kimi
assert_link_to \
  "$HOME/.agents/skills/commit" \
  "$TEST_ROOT/shared/skills/commit"
assert_not_exists "$HOME/.kimi-code/skills/commit"

"$TEST_ROOT/install.sh" --only opencode
assert_dir "$HOME/.config/opencode/skills"
assert_link_to \
  "$HOME/.config/opencode/skills/ask-matt" \
  "$TEST_ROOT/upstreams/mattpocock-skills/skills/engineering/ask-matt"

missing_root="$TEST_TMP/missing-upstream-source"
missing_home="$TEST_TMP/missing-upstream-home"
mkdir -p "$missing_root" "$missing_home"
cp "$TEST_ROOT/install.sh" "$missing_root/install.sh"
chmod +x "$missing_root/install.sh"
if HOME="$missing_home" AGENT_CONFIG_WINDOWS_CODEX_DIR='' \
  "$missing_root/install.sh" --dry-run --only codex \
  >"$TEST_TMP/missing-upstream.out" 2>&1; then
  printf '%s\n' 'installer accepted a missing Matt Pocock submodule' >&2
  exit 1
fi
grep -Fq "git submodule update --init --recursive" "$TEST_TMP/missing-upstream.out"
grep -Fq "uv run scripts/update_upstreams.py --no-install" "$TEST_TMP/missing-upstream.out"
assert_home_untouched "$missing_home"

collision_root="$TEST_TMP/collision-source"
mkdir -p \
  "$collision_root/shared/skills/api-design" \
  "$collision_root/harnesses/codex/skills/api-design" \
  "$collision_root/upstreams/mattpocock-skills/.claude-plugin" \
  "$collision_root/upstreams/mattpocock-skills/skills/future-category/ask-matt/agents"
cat >"$collision_root/upstreams/mattpocock-skills/.claude-plugin/plugin.json" <<'EOF'
{"skills":["./skills/future-category/ask-matt"]}
EOF
cat >"$collision_root/upstreams/mattpocock-skills/skills/future-category/ask-matt/SKILL.md" <<'EOF'
---
name: ask-matt
description: Test fixture.
---
EOF
: >"$collision_root/upstreams/mattpocock-skills/skills/future-category/ask-matt/agents/openai.yaml"
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
assert_home_untouched "$collision_home"

printf 'install tests: PASS\n'
