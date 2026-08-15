#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=tests/test-lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/test-lib.sh"

new_test_home
trap cleanup_test_home EXIT

mkdir -p "$TEST_TMP/bin"
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
  claude-api
  mcp-builder
  webapp-testing
  doc-coauthoring
  docx
  pdf
  pptx
  xlsx
)

for skill in "${anthropic_skills[@]}"; do
  assert_link_to \
    "$HOME/.claude/skills/$skill" \
    "$TEST_ROOT/harnesses/claude/upstream/anthropic-skills/skills/$skill"
done

grep -q '^plugin marketplace add anthropics/claude-plugins-official$' "$AGENT_CONFIG_CLAUDE_LOG"
grep -q '^plugin marketplace add DietrichGebert/ponytail$' "$AGENT_CONFIG_CLAUDE_LOG"
grep -q '^plugin install context7@claude-plugins-official$' "$AGENT_CONFIG_CLAUDE_LOG"

git config -f "$TEST_ROOT/.gitmodules" --get \
  submodule.harnesses/claude/upstream/anthropic-skills.url \
  | grep -qx 'https://github.com/anthropics/skills.git'

printf 'claude extras tests: PASS\n'
