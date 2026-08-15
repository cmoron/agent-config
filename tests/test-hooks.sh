#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PAYLOAD='{"session_id":"codex-config-test","turn_id":"test","cwd":"/tmp","stop_hook_active":false,"last_assistant_message":"done"}'

output=$(printf '%s' "$PAYLOAD" | "$ROOT/scripts/reflect-nudge.sh")
printf '%s' "$output" | jq -e 'type == "object"' >/dev/null

set +e
printf '%s' '{"tool_input":{"command":"*** Begin Patch\n*** Update File: .env\n@@\n-OLD=1\n+OLD=2\n*** End Patch"}}' \
  | "$ROOT/scripts/protect-env.sh" >/dev/null 2>&1
status=$?
set -e
[ "$status" -eq 2 ]

if command -v rtk >/dev/null && command -v jq >/dev/null; then
  printf '%s' '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git status"}}' \
    | "$ROOT/scripts/rtk-codex-hook.sh" \
    | jq -e '
        .hookSpecificOutput.permissionDecision == "allow"
        and (.hookSpecificOutput.updatedInput.command | startswith("rtk "))
      ' >/dev/null
fi

jq -e '
  [.hooks.Stop[].hooks[].command] as $commands
  | ($commands | length == 1)
    and ($commands[0] | contains("reflect-nudge.sh"))
    and ($commands | all(contains("notify-sound.sh") | not))
    and ([.hooks.PreToolUse[] | select(.matcher == "^Bash$") | .hooks[].command]
         | any(contains("rtk-codex-hook.sh")))
' "$ROOT/hooks.json" >/dev/null

echo "hooks: ok"
