#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=tests/test-lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/test-lib.sh"

new_test_home
trap cleanup_test_home EXIT

mkdir -p "$TEST_TMP/bin"
# The generated fake CLI expands these variables.
# shellcheck disable=SC2016
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf "%s\n" "$*" >>"$AGENT_CONFIG_CLAUDE_LOG"' \
  >"$TEST_TMP/bin/claude"
chmod +x "$TEST_TMP/bin/claude"
export AGENT_CONFIG_CLAUDE_LOG="$TEST_TMP/claude.log"
export PATH="$TEST_TMP/bin:$PATH"
export AGENT_CONFIG_SKIP_PLUGINS=0

"$TEST_ROOT/install.sh" --only claude >/dev/null

anthropic_skills=(
  webapp-testing
)
# Jamais utilises et doublonnes par les skills synchronises depuis claude.ai.
for skill in claude-api mcp-builder doc-coauthoring docx pdf pptx xlsx; do
  [ ! -e "$HOME/.claude/skills/$skill" ]
  [ ! -L "$HOME/.claude/skills/$skill" ]
done

for skill in "${anthropic_skills[@]}"; do
  assert_link_to \
    "$HOME/.claude/skills/$skill" \
    "$TEST_ROOT/harnesses/claude/upstream/anthropic-skills/skills/$skill"
done

grep -q '^plugin marketplace add anthropics/claude-plugins-official$' "$AGENT_CONFIG_CLAUDE_LOG"
grep -q '^plugin marketplace add DietrichGebert/ponytail$' "$AGENT_CONFIG_CLAUDE_LOG"
grep -q '^plugin marketplace add openai/codex-plugin-cc$' "$AGENT_CONFIG_CLAUDE_LOG"
grep -q '^plugin install context7@claude-plugins-official$' "$AGENT_CONFIG_CLAUDE_LOG"

# A local marketplace (source "directory"): added by its path when present, skipped with its
# plugins when absent (the goblin-hood checkout lives on the devbox only, not on the Mac).
fixture="$TEST_TMP/bootstrap"
mkdir -p "$fixture/scripts" "$TEST_TMP/present"
cp "$TEST_ROOT/harnesses/claude/scripts/bootstrap-plugins.sh" "$fixture/scripts/"
cat >"$fixture/settings.json" <<EOF
{
  "extraKnownMarketplaces": {
    "here": {"source": {"source": "directory", "path": "$TEST_TMP/present"}},
    "gone": {"source": {"source": "directory", "path": "$TEST_TMP/absent"}},
    "official": {"source": {"source": "github", "repo": "anthropics/claude-plugins-official"}}
  },
  "enabledPlugins": {"a@here": true, "b@gone": true, "c@official": true}
}
EOF
: >"$AGENT_CONFIG_CLAUDE_LOG"
bash "$fixture/scripts/bootstrap-plugins.sh" >"$TEST_TMP/bootstrap.out"
grep -qxF "plugin marketplace add $TEST_TMP/present" "$AGENT_CONFIG_CLAUDE_LOG"
grep -qx 'plugin marketplace add anthropics/claude-plugins-official' "$AGENT_CONFIG_CLAUDE_LOG"
grep -qx 'plugin install a@here' "$AGENT_CONFIG_CLAUDE_LOG"
grep -qx 'plugin install c@official' "$AGENT_CONFIG_CLAUDE_LOG"
if grep -qE 'absent|b@gone' "$AGENT_CONFIG_CLAUDE_LOG"; then
  printf 'an absent local marketplace was added or installed\n' >&2
  exit 1
fi
grep -q 'gone : .* absent sur cette machine' "$TEST_TMP/bootstrap.out"

git config -f "$TEST_ROOT/.gitmodules" --get \
  submodule.harnesses/claude/upstream/anthropic-skills.url \
  | grep -qx 'https://github.com/anthropics/skills.git'

printf 'claude extras tests: PASS\n'
