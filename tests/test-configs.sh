#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=tests/test-lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/test-lib.sh"

new_test_home
trap cleanup_test_home EXIT

mkdir -p "$HOME/.claude" "$HOME/.codex" "$HOME/.kimi-code" "$HOME/.config/opencode"

cat >"$HOME/.claude/settings.json" <<'EOF'
{
  "model": "runtime-model",
  "runtimeState": {"keep": true},
  "enabledPlugins": {"runtime-only@example": true}
}
EOF

cat >"$HOME/.codex/config.toml" <<'EOF'
model = "runtime-model"

[marketplaces.ponytail]
last_updated = "2026-01-01T00:00:00Z"
last_revision = "deadbeef"
source_type = "git"
source = "https://github.com/DietrichGebert/ponytail.git"

[hooks.state."keep-me"]
trusted_hash = "runtime-hash"

[projects."/home/cyril/src/runtime-project"]
trust_level = "trusted"
EOF

cat >"$HOME/.kimi-code/config.toml" <<'EOF'
default_model = "runtime/model"
default_permission_mode = "ask"
merge_all_available_skills = true

[providers.runtime]
type = "runtime"
api_key = ""

[runtime.extra]
keep = true

[[permission.rules]]
decision = "allow"
scope = "user"
pattern = "Bash(echo old)"

[[hooks]]
event = "Stop"
command = "/old/hook.sh"
timeout = 1
EOF

cp "$TEST_ROOT/harnesses/opencode/opencode.json" "$HOME/.config/opencode/opencode.json"
chmod 644 "$HOME/.config/opencode/opencode.json"

cp "$TEST_ROOT/tests/fixtures/windows-config.toml" "$AGENT_CONFIG_WINDOWS_CODEX_DIR/config.toml"
windows_config_hash="$(sha256sum "$AGENT_CONFIG_WINDOWS_CODEX_DIR/config.toml" | awk '{print $1}')"

"$TEST_ROOT/install.sh" --only claude >/dev/null
jq -e '
  .model == "opus[1m]"
  and .runtimeState.keep == true
  and (.enabledPlugins["runtime-only@example"] == null)
  and ([.hooks[][]?.hooks[]?.command? // empty]
       | all(contains("/src/claude-config") | not))
' "$HOME/.claude/settings.json" >/dev/null
[ ! -L "$HOME/.claude/settings.json" ]
assert_link_to "$HOME/.claude/scripts" "$TEST_ROOT/harnesses/claude/scripts"
assert_link_to "$HOME/.claude/assets" "$TEST_ROOT/shared/assets"
assert_link_to \
  "$HOME/.claude/commands/autoship.md" \
  "$TEST_ROOT/harnesses/claude/commands/autoship.md"
assert_link_to \
  "$HOME/.claude/commands/commit.md" \
  "$TEST_ROOT/harnesses/claude/commands/commit.md"
assert_link_to "$HOME/.config/ccstatusline" "$TEST_ROOT/harnesses/claude/config/ccstatusline"
if rg -n 'src/(claude-config|codex-config|kimi-config)' \
  "$HOME/.claude/settings.json" "$HOME/.claude/scripts/notify-sound.sh"; then
  exit 1
fi

# Claude Code rewrites settings.json in its own key order; that is not drift.
jq 'to_entries | reverse | from_entries' \
  "$HOME/.claude/settings.json" >"$TEST_TMP/unsorted-settings.json"
mv "$TEST_TMP/unsorted-settings.json" "$HOME/.claude/settings.json"
chmod 600 "$HOME/.claude/settings.json"
settings_hash="$(sha256sum "$HOME/.claude/settings.json" | awk '{print $1}')"
"$TEST_ROOT/install.sh" --only claude --check >/dev/null
"$TEST_ROOT/install.sh" --only claude >/dev/null
[ "$settings_hash" = "$(sha256sum "$HOME/.claude/settings.json" | awk '{print $1}')" ] || {
  printf '%s\n' 'reordered settings.json was rewritten' >&2
  exit 1
}

"$TEST_ROOT/install.sh" --only codex >/dev/null
grep -q '^\[hooks.state."keep-me"\]$' "$HOME/.codex/config.toml"
grep -q '^trusted_hash = "runtime-hash"$' "$HOME/.codex/config.toml"
grep -q '^\[projects."/home/cyril/src/runtime-project"\]$' "$HOME/.codex/config.toml"
grep -q '^trust_level = "trusted"$' "$HOME/.codex/config.toml"
grep -q '^\[mcp_servers.playwright\]$' "$HOME/.codex/config.toml"
grep -q '^\[mcp_servers.linear\]$' "$HOME/.codex/config.toml"
grep -q '^url = "https://mcp.linear.app/mcp"$' "$HOME/.codex/config.toml"
# Codex stamps these into a source-owned section; keep them, exactly once.
[ "$(grep -c '^last_revision = "deadbeef"$' "$HOME/.codex/config.toml")" -eq 1 ]
[ "$(grep -c '^last_updated = "2026-01-01T00:00:00Z"$' "$HOME/.codex/config.toml")" -eq 1 ]
"$TEST_ROOT/install.sh" --only codex --check >/dev/null
if rg -n '^trust_level\s*=' "$TEST_ROOT/harnesses/codex/config.toml"; then
  printf '%s\n' 'Codex source must not version machine-local project trust' >&2
  exit 1
fi
[ ! -L "$HOME/.codex/config.toml" ]
assert_file "$HOME/.codex/hooks.json"
assert_file "$HOME/.codex/rules/default.rules"
assert_link_to "$HOME/.codex/scripts" "$TEST_ROOT/harnesses/codex/scripts"
assert_link_to "$HOME/.codex/assets" "$TEST_ROOT/shared/assets"
assert_link_to "$HOME/.codex/agents" "$TEST_ROOT/harnesses/codex/agents"
if rg -n 'src/(claude-config|codex-config|kimi-config)' \
  "$HOME/.codex/config.toml" "$HOME/.codex/hooks.json" "$HOME/.codex/scripts"; then
  exit 1
fi

after_windows_hash="$(sha256sum "$AGENT_CONFIG_WINDOWS_CODEX_DIR/config.toml" | awk '{print $1}')"
[ "$windows_config_hash" = "$after_windows_hash" ] || {
  printf '%s\n' 'existing Windows config.toml was modified' >&2
  exit 1
}
assert_file "$AGENT_CONFIG_WINDOWS_CODEX_DIR/hooks.json"
assert_file "$AGENT_CONFIG_WINDOWS_CODEX_DIR/rules/default.rules"
assert_dir "$AGENT_CONFIG_WINDOWS_CODEX_DIR/scripts"
assert_dir "$AGENT_CONFIG_WINDOWS_CODEX_DIR/assets"
assert_dir "$AGENT_CONFIG_WINDOWS_CODEX_DIR/agents"
[ ! -L "$AGENT_CONFIG_WINDOWS_CODEX_DIR/scripts" ]

"$TEST_ROOT/install.sh" --only kimi >/dev/null
grep -q '^default_model = "runtime/model"$' "$HOME/.kimi-code/config.toml"
grep -q '^default_permission_mode = "yolo"$' "$HOME/.kimi-code/config.toml"
grep -q '^merge_all_available_skills = false$' "$HOME/.kimi-code/config.toml"
grep -q '^\[providers.runtime\]$' "$HOME/.kimi-code/config.toml"
grep -q '^\[runtime.extra\]$' "$HOME/.kimi-code/config.toml"
grep -q '^pattern = "Bash(rm -rf /)"$' "$HOME/.kimi-code/config.toml"
# Assert the literal portable $HOME reference.
# shellcheck disable=SC2016
grep -q 'command = "$HOME/.kimi-code/scripts/format-on-save.sh"' "$HOME/.kimi-code/config.toml"
if grep -q 'command = "/old/hook.sh"' "$HOME/.kimi-code/config.toml"; then
  printf '%s\n' 'old Kimi hook survived managed-section replacement' >&2
  exit 1
fi
uv run python -c 'import sys, tomllib; tomllib.load(open(sys.argv[1], "rb"))' \
  "$HOME/.kimi-code/config.toml"
[ ! -L "$HOME/.kimi-code/config.toml" ]
# Comments/formatting in app-owned TOML are not configuration drift.
printf '\n# Runtime annotation in the last managed section.\n' >>"$HOME/.kimi-code/config.toml"
kimi_hash="$(sha256sum <"$HOME/.kimi-code/config.toml")"
"$TEST_ROOT/install.sh" --only kimi --check >/dev/null
"$TEST_ROOT/install.sh" --only kimi >/dev/null
[ "$kimi_hash" = "$(sha256sum <"$HOME/.kimi-code/config.toml")" ]
assert_file "$HOME/.kimi-code/tui.toml"
assert_file "$HOME/.kimi-code/mcp.json"
assert_link_to "$HOME/.kimi-code/scripts" "$TEST_ROOT/harnesses/kimi/scripts"
assert_link_to "$HOME/.kimi-code/assets" "$TEST_ROOT/shared/assets"
if rg -n 'src/(claude-config|codex-config|kimi-config)' \
  "$HOME/.kimi-code/config.toml" "$HOME/.kimi-code/scripts/notify-sound.sh"; then
  exit 1
fi

"$TEST_ROOT/install.sh" --only opencode >/dev/null
jq -S . "$TEST_ROOT/harnesses/opencode/opencode.json" >"$TEST_TMP/source-opencode.json"
jq -S . "$HOME/.config/opencode/opencode.json" >"$TEST_TMP/runtime-opencode.json"
cmp "$TEST_TMP/source-opencode.json" "$TEST_TMP/runtime-opencode.json"
[ "$(path_mode "$HOME/.config/opencode/opencode.json")" = 600 ]

if ! "$TEST_ROOT/install.sh" --check >"$TEST_TMP/check.out" 2>&1; then
  printf '%s\n' 'expected a clean consolidated check:' >&2
  sed -n '1,160p' "$TEST_TMP/check.out" >&2
  exit 1
fi

printf 'config tests: PASS\n'
