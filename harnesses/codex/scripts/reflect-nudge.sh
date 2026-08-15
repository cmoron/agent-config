#!/usr/bin/env bash

set -euo pipefail

noop() {
  printf '{}\n'
  exit 0
}

INPUT=$(cat)
SESSION=$(printf '%s' "$INPUT" | jq -r '.session_id // ""' 2>/dev/null || true)
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // ""' 2>/dev/null || true)
ACTIVE=$(printf '%s' "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null || true)

[ "$ACTIVE" = "true" ] && noop
[ -n "$SESSION" ] || noop
[ -n "$CWD" ] || CWD=$PWD

MARKER="${TMPDIR:-/tmp}/codex-reflect-${SESSION}"
[ -e "$MARKER" ] && noop
git -C "$CWD" rev-parse --is-inside-work-tree >/dev/null 2>&1 || noop
[ -n "$(git -C "$CWD" status --porcelain 2>/dev/null)" ] || noop

: >"$MARKER"

jq -n --arg reason \
  "Backstop auto-amelioration (une fois par session). Si une procedure s'est repetee ou si une correction recurrente a emerge, propose en diff un skill ou une instruction adaptee, sans ecrire ni committer automatiquement. Sinon, indique-le en une ligne et termine." \
  '{decision: "block", reason: $reason}'
