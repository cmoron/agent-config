#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CODEX_HARNESS="$ROOT/harnesses/codex"
PAYLOAD='{"session_id":"agent-config-test","turn_id":"test","cwd":"/tmp","stop_hook_active":false,"last_assistant_message":"done"}'

# Hors depot git, le Stop hook Claude degrade en no-op muet.
output=$(printf '%s' "$PAYLOAD" | "$ROOT/harnesses/claude/scripts/reflect-nudge.sh")
[ -z "$output" ]

set +e
printf '%s' '{"tool_input":{"command":"*** Begin Patch\n*** Update File: .env\n@@\n-OLD=1\n+OLD=2\n*** End Patch"}}' \
  | "$CODEX_HARNESS/scripts/protect-env.sh" >/dev/null 2>&1
hook_exit=$?
set -e
[ "$hook_exit" -eq 2 ]

if command -v rtk >/dev/null && command -v jq >/dev/null; then
  printf '%s' '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git status"}}' \
    | "$CODEX_HARNESS/scripts/rtk-codex-hook.sh" \
    | jq -e '
        .hookSpecificOutput.permissionDecision == "allow"
        and (.hookSpecificOutput.updatedInput.command | startswith("rtk "))
      ' >/dev/null
fi

# Codex n'a pas de hook Stop : celui-ci bloquait les tours termines.
jq -e '
  (.hooks | has("Stop") | not)
  and ([.hooks.PreToolUse[] | select(.matcher == "^Bash$") | .hooks[].command]
       | any(contains("rtk-codex-hook.sh")))
' "$CODEX_HARNESS/hooks.json" >/dev/null

[ ! -e "$CODEX_HARNESS/scripts/reflect-nudge.sh" ] || {
  printf '%s\n' 'codex reflect-nudge.sh blocks completed turns; it must stay removed' >&2
  exit 1
}

jq -e '
  [.hooks[][]?.hooks[]?.command? // empty]
  | all(contains("$HOME/src/claude-config") | not)
' "$ROOT/harnesses/claude/settings.json" >/dev/null

# Assert the literal portable $HOME reference.
# shellcheck disable=SC2016
grep -q 'command = "$HOME/.kimi-code/scripts/format-on-save.sh"' \
  "$ROOT/harnesses/kimi/config.toml"

if rg -n 'src/(claude-config|codex-config|kimi-config)' \
  "$ROOT/harnesses/claude/settings.json" \
  "$ROOT/harnesses/claude/scripts" \
  "$ROOT/harnesses/codex/hooks.json" \
  "$ROOT/harnesses/codex/scripts" \
  "$ROOT/harnesses/kimi/config.toml" \
  "$ROOT/harnesses/kimi/scripts"; then
  printf '%s\n' 'legacy source path remains in hook configuration' >&2
  exit 1
fi

echo "hooks: ok"
