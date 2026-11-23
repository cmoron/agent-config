#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=tests/test-lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/test-lib.sh"

new_test_home
trap cleanup_test_home EXIT

mkdir -p "$HOME/.claude" "$HOME/.codex" "$HOME/.config/opencode"

cat >"$HOME/.claude/settings.json" <<'EOF'
{
  "model": "runtime-model",
  "runtimeState": {"keep": true},
  "env": {"CLAUDE_CODE_EXPERIMENTAL_CODE_MODE": "1"},
  "mcpServers": {"linear": {"type": "http", "url": "https://mcp.linear.app/mcp"}},
  "autoMode": {"allow": ["runtime-only rule"]},
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

cp "$TEST_ROOT/harnesses/opencode/opencode.json" "$HOME/.config/opencode/opencode.json"
chmod 644 "$HOME/.config/opencode/opencode.json"

cp "$TEST_ROOT/tests/fixtures/windows-config.toml" "$AGENT_CONFIG_WINDOWS_CODEX_DIR/config.toml"
windows_config_hash="$(sha256sum "$AGENT_CONFIG_WINDOWS_CODEX_DIR/config.toml" | awk '{print $1}')"

mkdir -p "$HOME/.claude/commands" "$HOME/.config"
# ccstatusline n'est plus deploye : son ancien lien gere doit disparaitre.
ln -s "$TEST_ROOT/harnesses/claude/config/ccstatusline" "$HOME/.config/ccstatusline"
ln -s "$TEST_ROOT/harnesses/claude/commands/commit.md" "$HOME/.claude/commands/commit.md"

"$TEST_ROOT/install.sh" --only claude >/dev/null
jq -e '
  .model == "fable"
  and .effortLevel == "medium"
  and .runtimeState.keep == true
  and .permissions.defaultMode == "auto"
  and has("env") == false
  and (.permissions.deny | index("Read(.env)") != null)
  and ((.permissions.deny | index("Read(!.env.example)")) > (.permissions.deny | index("Read(.env.*)")))
  and (.permissions.deny | index("Bash(git commit * --no-verify*)") != null)
  and (.permissions.deny | index("Bash(git push * --force)") != null)
  and (.permissions.deny | any(contains("| sh")) | not)
  and ([.hooks.PreToolUse[] | select(.matcher | test("Write")) | .hooks[].onFailure] == ["block"])
  and ([.hooks.PreToolUse[].matcher] | index("Skill") == null)
  and ([.hooks[][]?.hooks[]?.command? // empty] | any(contains("rtk")) | not)
  and ([.enabledPlugins | to_entries[] | select(.value == false) | .key | split("@")[0]] | sort
       == ["claude-code-setup", "claude-md-management", "skill-creator", "superpowers"])
  and (.hooks.Notification[0].matcher | test("permission_prompt"))
  and .statusLine.command == "$HOME/.claude/scripts/statusline.sh"
  and has("mcpServers") == false
  and has("includeCoAuthoredBy") == false
  and .attribution == {"commit": "", "pr": ""}
  and (.permissions.deny | index("Bash(prisma migrate reset *)") != null)
  and has("skipDangerousModePermissionPrompt") == false
  and .autoMode.environment[0] == "$defaults"
  and .autoMode.allow[0] == "$defaults"
  and (.autoMode.allow | index("runtime-only rule") == null)
  and (.enabledPlugins["runtime-only@example"] == null)
  and ([.hooks[][]?.hooks[]?.command? // empty]
       | all(contains("/src/claude-config") | not))
' "$HOME/.claude/settings.json" >/dev/null
[ ! -L "$HOME/.claude/settings.json" ]
# Le relecteur en lecture seule est impose par le harness, pas demande en prose.
assert_link_to "$HOME/.claude/agents/relecteur.md" \
  "$TEST_ROOT/harnesses/claude/agents/relecteur.md"
grep -q '^tools: Read, Grep, Glob$' "$HOME/.claude/agents/relecteur.md"
assert_dir "$HOME/.claude/scripts"
assert_link_to "$HOME/.claude/scripts/format-on-save.sh" \
  "$TEST_ROOT/shared/scripts/format-on-save.sh"
assert_link_to "$HOME/.claude/scripts/protect-env.sh" \
  "$TEST_ROOT/shared/scripts/protect-env.sh"
assert_link_to "$HOME/.claude/scripts/notify-sound.sh" \
  "$TEST_ROOT/shared/scripts/notify-sound.sh"
[ ! -e "$HOME/.claude/scripts/reflect-nudge.sh" ]
[ ! -L "$HOME/.claude/scripts/reflect-nudge.sh" ]
assert_link_to "$HOME/.claude/assets" "$TEST_ROOT/shared/assets"
# Commands were merged into skills: stale managed links must be pruned.
[ ! -e "$HOME/.claude/commands/commit.md" ]
[ ! -L "$HOME/.claude/commands/commit.md" ]
[ ! -e "$HOME/.config/ccstatusline" ]
[ ! -L "$HOME/.config/ccstatusline" ]
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
assert_dir "$HOME/.codex/scripts"
assert_link_to "$HOME/.codex/scripts/format-on-save.sh" \
  "$TEST_ROOT/harnesses/codex/scripts/format-on-save.sh"
assert_link_to "$HOME/.codex/scripts/protect-env.sh" \
  "$TEST_ROOT/harnesses/codex/scripts/protect-env.sh"
assert_link_to "$HOME/.codex/scripts/notify-sound.sh" \
  "$TEST_ROOT/shared/scripts/notify-sound.sh"
assert_link_to "$HOME/.codex/scripts/patch-files.sh" \
  "$TEST_ROOT/harnesses/codex/scripts/patch-files.sh"
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

"$TEST_ROOT/install.sh" --only opencode >/dev/null
jq -S . "$TEST_ROOT/harnesses/opencode/opencode.json" >"$TEST_TMP/source-opencode.json"
jq -S . "$HOME/.config/opencode/opencode.json" >"$TEST_TMP/runtime-opencode.json"
cmp "$TEST_TMP/source-opencode.json" "$TEST_TMP/runtime-opencode.json"
# Zero-prompt goal on 2.x: the base policy allows everything and only asks for
# .env reads, which the rules settle; no rule may ask, deny rules are kept.
jq -e '(.permissions | any(.effect == "ask") | not)
  and any(.permissions[]; . == {action: "read", resource: "*.env", effect: "deny"})
  and any(.permissions[]; . == {action: "shell", resource: "git reset --hard*", effect: "deny"})
  and all(.permissions[]; .resource | test("--force\\*") | not)
  and any(.permissions[]; . == {action: "shell", resource: "git push --force", effect: "deny"})
  and any(.permissions[]; . == {action: "shell", resource: "git push * --force", effect: "deny"})' \
  "$HOME/.config/opencode/opencode.json" >/dev/null
[ "$(path_mode "$HOME/.config/opencode/opencode.json")" = 600 ]

"$TEST_ROOT/install.sh" --only pi >/dev/null

if ! "$TEST_ROOT/install.sh" --check >"$TEST_TMP/check.out" 2>&1; then
  printf '%s\n' 'expected a clean consolidated check:' >&2
  sed -n '1,160p' "$TEST_TMP/check.out" >&2
  exit 1
fi

printf 'config tests: PASS\n'
