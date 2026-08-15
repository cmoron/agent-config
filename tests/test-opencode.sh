#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=tests/test-lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/test-lib.sh"

new_test_home
trap cleanup_test_home EXIT

cat >"$HOME/.profile.local" <<'EOF'
# Preserve machine-local environment.
export UNRELATED_RUNTIME_VALUE="keep-me"
EOF
chmod 600 "$HOME/.profile.local"

"$TEST_ROOT/install.sh" >/dev/null

grep -Fxq 'export UNRELATED_RUNTIME_VALUE="keep-me"' "$HOME/.profile.local"
grep -Fxq 'export OPENCODE_DISABLE_CLAUDE_CODE_SKILLS=1' "$HOME/.profile.local"
[ "$(grep -Fc 'export OPENCODE_DISABLE_CLAUDE_CODE_SKILLS=1' "$HOME/.profile.local")" = 1 ]
[ "$(path_mode "$HOME/.profile.local")" = 600 ]
assert_link_to \
  "$HOME/.config/opencode/skills/api-design" \
  "$TEST_ROOT/shared/skills/api-design"

profile_hash="$(sha256sum "$HOME/.profile.local" | awk '{print $1}')"
"$TEST_ROOT/install.sh" --only opencode >/dev/null
[ "$profile_hash" = "$(sha256sum "$HOME/.profile.local" | awk '{print $1}')" ]

cat >"$HOME/.profile.local" <<'EOF'
# >>> agent-config: opencode >>>
export SHOULD_NOT_EAT_THIS="preserve-me"
EOF
malformed_hash="$(sha256sum "$HOME/.profile.local" | awk '{print $1}')"
if "$TEST_ROOT/install.sh" --only opencode >"$TEST_TMP/malformed.out" 2>&1; then
  printf '%s\n' 'installer accepted an unterminated profile block' >&2
  exit 1
fi
[ "$malformed_hash" = "$(sha256sum "$HOME/.profile.local" | awk '{print $1}')" ]
grep -Fq 'malformed managed block' "$TEST_TMP/malformed.out"

# Restore a valid profile for the optional native OpenCode discovery probe.
cat >"$HOME/.profile.local" <<'EOF'
# Preserve machine-local environment.
export UNRELATED_RUNTIME_VALUE="keep-me"
# >>> agent-config: opencode >>>
export OPENCODE_DISABLE_CLAUDE_CODE_SKILLS=1
# <<< agent-config: opencode <<<
EOF
chmod 600 "$HOME/.profile.local"

if command -v opencode >/dev/null 2>&1; then
  mkdir -p "$HOME/.cache" "$HOME/.local/share" "$HOME/.local/state"
  XDG_CONFIG_HOME="$HOME/.config" \
    XDG_CACHE_HOME="$HOME/.cache" \
    XDG_DATA_HOME="$HOME/.local/share" \
    XDG_STATE_HOME="$HOME/.local/state" \
    sh -c '. "$HOME/.profile.local"; exec opencode debug skill --pure' \
    >"$TEST_TMP/opencode-skills.json"
  jq -e 'any(.[]; .name == "api-design")' "$TEST_TMP/opencode-skills.json" >/dev/null
  jq -e 'any(.[]; .name == "ask-matt")' "$TEST_TMP/opencode-skills.json" >/dev/null
  local_skill_count="$(find "$TEST_ROOT/shared/skills" -mindepth 1 -maxdepth 1 -type d | wc -l)"
  matt_skill_count="$(jq '.skills | length' \
    "$TEST_ROOT/upstreams/mattpocock-skills/.claude-plugin/plugin.json")"
  expected_skill_count="$((local_skill_count + matt_skill_count))"
  jq -e --argjson expected "$expected_skill_count" \
    'length == $expected' "$TEST_TMP/opencode-skills.json" >/dev/null
  jq -e \
    'all(.[]; .location | contains("/.config/opencode/skills/"))' \
    "$TEST_TMP/opencode-skills.json" >/dev/null
fi

printf 'opencode tests: PASS\n'
