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
# Formateurs natifs actives (objet vide : conserve les reglages herites).
jq -e '.formatter | type == "object"' "$HOME/.config/opencode/opencode.json" >/dev/null
# Format natif 2.x : regles ordonnees, la derniere qui matche gagne. Les cles
# 1.x `permission` et `provider` y sont depreciees.
jq -e '
  ((has("permission") or has("provider")) | not)
  and (.permissions | type == "array")
  and all(.permissions[]; (keys | sort) == ["action", "effect", "resource"])
  and any(.permissions[]; . == {action: "shell", resource: "sudo *", effect: "deny"})
  and any(.permissions[]; . == {action: "edit", resource: "*.env", effect: "deny"})
  and ((.permissions | index({action: "read", resource: "*.env.example", effect: "allow"}))
       > (.permissions | index({action: "read", resource: "*.env.*", effect: "deny"})))
' "$HOME/.config/opencode/opencode.json" >/dev/null
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
  mkdir -p "$HOME/.cache" "$HOME/.local/share" "$HOME/.local/state" "$TEST_TMP/oc-project"
  # OpenCode 2.x n'a plus `debug skill` : son serveur liste les skills, derriere
  # un mot de passe genere, et les decouvre juste apres le debut de l'ecoute.
  oc_port="$("$TEST_PYTHON" -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')"
  XDG_CONFIG_HOME="$HOME/.config" \
    XDG_CACHE_HOME="$HOME/.cache" \
    XDG_DATA_HOME="$HOME/.local/share" \
    XDG_STATE_HOME="$HOME/.local/state" \
    sh -c '. "$HOME/.profile.local"; exec opencode serve --port "$1"' sh "$oc_port" \
    >"$TEST_TMP/opencode-serve.log" 2>&1 &
  oc_pid=$!
  oc_count=-1
  for _ in $(seq 1 40); do
    sleep 0.5
    oc_password="$(sed -n 's/^server password //p' "$TEST_TMP/opencode-serve.log")"
    [ -n "$oc_password" ] || continue
    curl -fsS -g -u "opencode:$oc_password" --get \
      --data-urlencode "location[directory]=$TEST_TMP/oc-project" \
      "http://127.0.0.1:$oc_port/api/skill" >"$TEST_TMP/opencode-skills.json" 2>/dev/null || continue
    oc_new="$(jq '[.data[] | select(.path | contains("/.config/opencode/skills/"))] | length' \
      "$TEST_TMP/opencode-skills.json" 2>/dev/null || echo -1)"
    if [ "$oc_new" -gt 0 ] && [ "$oc_new" = "$oc_count" ]; then
      break
    fi
    oc_count="$oc_new"
  done
  kill "$oc_pid" 2>/dev/null || true
  wait "$oc_pid" 2>/dev/null || true
  jq -e 'any(.data[]; .id == "api-design")' "$TEST_TMP/opencode-skills.json" >/dev/null
  jq -e 'any(.data[]; .id == "ask-matt")' "$TEST_TMP/opencode-skills.json" >/dev/null
  local_skill_count="$(find "$TEST_ROOT/shared/skills" -mindepth 1 -maxdepth 1 -type d | wc -l)"
  matt_skill_count="$(jq '.skills | length' \
    "$TEST_ROOT/upstreams/mattpocock-skills/.claude-plugin/plugin.json")"
  matt_extra_count="$(awk '!/^[[:space:]]*(#|$)/' \
    "$TEST_ROOT/upstreams/mattpocock-extra-skills.txt" | wc -l)"
  expected_skill_count="$((local_skill_count + matt_skill_count + matt_extra_count))"
  # Les skills integres a OpenCode s'ajoutent a ceux du miroir : ne compter que lui.
  jq -e --argjson expected "$expected_skill_count" \
    '[.data[] | select(.path | contains("/.config/opencode/skills/"))] | length == $expected' \
    "$TEST_TMP/opencode-skills.json" >/dev/null
fi

printf 'opencode tests: PASS\n'
