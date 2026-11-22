#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CODEX_HARNESS="$ROOT/harnesses/codex"

# shellcheck source=tests/test-lib.sh
source "$ROOT/tests/test-lib.sh"
new_test_home
trap cleanup_test_home EXIT

mkdir -p "$TEST_TMP/bin" "$TEST_TMP/no-formatter-bin" "$TEST_TMP/format workspace" \
  "$HOME/.claude/scripts" "$HOME/.codex/scripts"
printf 'foreign\n' >"$HOME/.claude/scripts/foreign-hook.sh"
# Older installs linked the whole source directory. Replacing that link must
# leave a real runtime directory, so individual managed links can coexist with
# third-party scripts.
rmdir "$HOME/.codex/scripts"
ln -s "$CODEX_HARNESS/scripts" "$HOME/.codex/scripts"
for command in bash cat dirname jq sed; do
  ln -s "$(command -v "$command")" "$TEST_TMP/no-formatter-bin/$command"
done
cat >"$TEST_TMP/bin/ruff" <<'EOF'
#!/usr/bin/env bash
printf 'ruff deliberate failure: %s\n' "$*" >&2
printf '%s\n' "$*" >>"$HOOK_LOG"
exit "${RUFF_STATUS:-42}"
EOF
cat >"$TEST_TMP/bin/afplay" <<'EOF'
#!/usr/bin/env bash
sleep "${AUDIO_DELAY:-0}"
printf '%s\n' "$*" >>"$HOOK_LOG"
printf 'audio diagnostic\n' >&2
EOF
chmod +x "$TEST_TMP/bin/ruff" "$TEST_TMP/bin/afplay"
printf 'x=1\n' >"$TEST_TMP/format workspace/example.py"
export HOOK_LOG="$TEST_TMP/ruff.log"

# Run the deployed hooks: source tests can pass while install.sh has linked the
# wrong tree or kept an obsolete runtime script.
for harness in claude codex; do
  "$TEST_ROOT/install.sh" --only "$harness" >/dev/null
done

for runtime in "$HOME/.claude" "$HOME/.codex"; do
  assert_dir "$runtime/scripts"
  [ ! -L "$runtime/scripts" ]
done
assert_file "$HOME/.claude/scripts/foreign-hook.sh"

for harness in claude codex; do
  runtime="$HOME/.${harness}"
  hook="$runtime/scripts/format-on-save.sh"
  if [ "$harness" = codex ]; then
    input="$(jq -cn --arg cwd "$TEST_TMP/format workspace" \
      '{cwd: $cwd, tool_input: {command: "*** Begin Patch\n*** Update File: example.py\n*** End Patch"}}')"
  else
    input="$(jq -cn --arg cwd "$TEST_TMP/format workspace" \
      '{cwd: $cwd, tool_input: {file_path: "example.py"}}')"
  fi
  set +e
  printf '%s' "$input" | PATH="$TEST_TMP/bin:$PATH" "$hook" \
    >"$TEST_TMP/format.out" 2>"$TEST_TMP/format.err"
  status=$?
  set -e
  if [ "$status" -ne 42 ] || [ ! -s "$TEST_TMP/format.err" ]; then
    printf 'formatter error was hidden by deployed %s hook (status %s)\n' \
      "$harness" "$status" >&2
    exit 1
  fi
done

# A successful format receives the cwd-resolved path, including spaces, for
# both ruff actions.  This catches adapters that parse the payload correctly
# but run the tool from the wrong working directory.
export HOOK_LOG="$TEST_TMP/ruff.log"
for harness in claude codex; do
  runtime="$HOME/.${harness}"
  if [ "$harness" = codex ]; then
    input="$(jq -cn --arg cwd "$TEST_TMP/format workspace" '{cwd: $cwd, tool_input: {command: "*** Begin Patch\n*** Update File: example.py\n*** End Patch"}}')"
  else
    input="$(jq -cn --arg cwd "$TEST_TMP/format workspace" '{cwd: $cwd, tool_input: {file_path: "example.py"}}')"
  fi
  : >"$HOOK_LOG"
  printf '%s' "$input" | RUFF_STATUS=0 PATH="$TEST_TMP/bin:$PATH" \
    "$runtime/scripts/format-on-save.sh" >/dev/null
  grep -Fqx "format --quiet $TEST_TMP/format workspace/example.py" "$HOOK_LOG"
  grep -Fqx "check --fix --quiet $TEST_TMP/format workspace/example.py" "$HOOK_LOG"
done

# An unavailable formatter is not an error, but it must leave a diagnostic so
# an agent does not mistake an unformatted file for a formatted one.
for harness in claude codex; do
  runtime="$HOME/.${harness}"
  if [ "$harness" = codex ]; then
    input="$(jq -cn --arg cwd "$TEST_TMP/format workspace" '{cwd: $cwd, tool_input: {command: "*** Begin Patch\n*** Update File: example.py\n*** End Patch"}}')"
  else
    input="$(jq -cn --arg cwd "$TEST_TMP/format workspace" '{cwd: $cwd, tool_input: {file_path: "example.py"}}')"
  fi
  set +e
  printf '%s' "$input" | PATH="$TEST_TMP/no-formatter-bin" "$runtime/scripts/format-on-save.sh" \
    >"$TEST_TMP/missing.out" 2>"$TEST_TMP/missing.err"
  status=$?
  set -e
  if [ "$status" -ne 0 ] || [ ! -s "$TEST_TMP/missing.err" ]; then
    printf 'missing formatter was silent or failed for %s\n' "$harness" >&2
    exit 1
  fi
done

reject_protect() {
  local hook="$1"
  local input="$2"
  set +e
  printf '%s' "$input" | "$hook" >"$TEST_TMP/protect.out" 2>"$TEST_TMP/protect.err"
  status=$?
  set -e
  if [ "$status" -ne 2 ] || [ ! -s "$TEST_TMP/protect.err" ]; then
    printf 'protection hook accepted invalid or protected input: %s\n' "$hook" >&2
    exit 1
  fi
}

hook="$HOME/.claude/scripts/protect-env.sh"
for file in .env .env.test .env.example; do
  input="$(jq -cn --arg cwd "$TEST_TMP/format workspace" --arg file "$file" '{cwd: $cwd, tool_input: {file_path: $file}}')"
  reject_protect "$hook" "$input"
done
reject_protect "$hook" '{'
reject_protect "$hook" '{"tool_input":{"file_path":false}}'
reject_protect "$hook" '{"tool_input":{}}'
reject_protect "$hook" '{"tool_input":{"file_path":"safe.py"}} {}'
reject_protect "$hook" '{"cwd":false,"tool_input":{"file_path":"safe.py"}}'
reject_protect "$hook" '{"tool_input":{"file_path":"safe\u0000.py"}}'
printf '%s' '{"tool_input":{"file_path":"safe.py"}}' | "$hook" >"$TEST_TMP/protect.out"
[ ! -s "$TEST_TMP/protect.out" ]

codex_protect="$HOME/.codex/scripts/protect-env.sh"
input="$(jq -cn --arg cwd "$TEST_TMP/format workspace" '{cwd: $cwd, tool_input: {command: "*** Begin Patch\n*** Update File: .env.example\n*** End Patch"}}')"
reject_protect "$codex_protect" "$input"
input="$(jq -cn --arg cwd "$TEST_TMP/format workspace" '{cwd: $cwd, tool_input: {command: "*** Begin Patch\n*** Update File: source.txt\n*** Move to: .env\n*** End Patch"}}')"
reject_protect "$codex_protect" "$input"
reject_protect "$codex_protect" '{'
reject_protect "$codex_protect" '{"tool_input":{"command":false}}'
reject_protect "$codex_protect" '{"tool_input":{"command":"*** Begin Patch\n*** End Patch"}}'
reject_protect "$codex_protect" '{"tool_input":{"command":"*** Begin Patch\n*** Update File: safe.py\n*** End Patch"}} {}'
reject_protect "$codex_protect" '{"cwd":false,"tool_input":{"command":"*** Begin Patch\n*** Update File: safe.py\n*** End Patch"}}'
for operation in Add Update Delete; do
  input="$(jq -cn --arg op "$operation" \
    '{tool_input: {command: ("*** Begin Patch\n*** " + $op + " File: .env.test\n*** End Patch")}}')"
  reject_protect "$codex_protect" "$input"
done
printf '%s' '{"tool_input":{"command":"*** Begin Patch\n*** Update File: safe.py\n*** End Patch"}}' \
  | "$codex_protect" | jq -e '. == {}' >/dev/null

# Le nudge Stop d'auto-amelioration est retire : il partait sur un working tree
# deja sale, avant toute repetition, et remplacait la reponse finale en headless.
[ ! -e "$ROOT/harnesses/claude/scripts/reflect-nudge.sh" ] || {
  printf '%s\n' 'claude reflect-nudge.sh must stay removed' >&2
  exit 1
}
if grep -n 'reflect-nudge' "$ROOT/harnesses/claude/settings.json"; then
  printf '%s\n' 'a Stop hook still references reflect-nudge.sh' >&2
  exit 1
fi

# The shared player receives its asset path from the deployed harness script.
export HOOK_LOG="$TEST_TMP/sound.log"
for runtime in "$HOME/.claude" "$HOME/.codex"; do
  : >"$HOOK_LOG"
  PATH="$TEST_TMP/bin:$PATH" "$runtime/scripts/notify-sound.sh"
  for _ in 1 2 3; do
    [ -s "$HOOK_LOG" ] && break
    sleep 0.1
  done
  grep -Fqx "$runtime/scripts/../assets/warcraft-3-paysan-travail-termine.mp3" "$HOOK_LOG"
  grep -q 'audio diagnostic' "$runtime/notify-sound.log"
done
assert_file "$AGENT_CONFIG_WINDOWS_CODEX_DIR/scripts/notify-sound.sh"
[ ! -L "$AGENT_CONFIG_WINDOWS_CODEX_DIR/scripts/notify-sound.sh" ]

# A captured hook must finish before its player; inheriting a pipe delays EOF.
PATH="$TEST_TMP/bin:$PATH" AUDIO_DELAY=1 "$TEST_PYTHON" - "$HOME/.codex/scripts/notify-sound.sh" <<'PY'
import subprocess
import sys

subprocess.run([sys.argv[1]], capture_output=True, timeout=0.5, check=True)
PY
# Let the fake player finish before removing its temporary log directory.
sleep 1.1

# Codex n'a pas de hook Stop : celui-ci bloquait les tours termines.
jq -e '
  (.hooks | has("Stop") | not)
  and ([.hooks[][]?.hooks[]?.command? // empty] | any(contains("rtk")) | not)
' "$CODEX_HARNESS/hooks.json" >/dev/null

# rtk est retire de tous les harnesses : son gain mesure (0,3 % de la depense)
# ne couvre pas les relances que ses sorties tronquees provoquent.
[ ! -e "$CODEX_HARNESS/scripts/rtk-codex-hook.sh" ]
if grep -rniw 'rtk' "$ROOT/harnesses"/*/instructions.overlay.md "$ROOT/instructions/common.md"; then
  printf '%s\n' 'instructions still mention rtk' >&2
  exit 1
fi

[ ! -e "$CODEX_HARNESS/scripts/reflect-nudge.sh" ] || {
  printf '%s\n' 'codex reflect-nudge.sh blocks completed turns; it must stay removed' >&2
  exit 1
}

jq -e '
  [.hooks[][]?.hooks[]?.command? // empty]
  | all(contains("$HOME/src/claude-config") | not)
' "$ROOT/harnesses/claude/settings.json" >/dev/null

if rg -n 'src/(claude-config|codex-config|kimi-config)' \
  "$ROOT/harnesses/claude/settings.json" \
  "$ROOT/harnesses/claude/scripts" \
  "$ROOT/harnesses/codex/hooks.json" \
  "$ROOT/harnesses/codex/scripts"; then
  printf '%s\n' 'legacy source path remains in hook configuration' >&2
  exit 1
fi

# Barre d'etat : le JSON de stdin seul, jamais le transcript. ccstatusline relisait
# tout le transcript a chaque affichage (1,3 Go et 2,3 s sur 311 Mo, 01/11/2026).
jq -e '
  .statusLine.command == "$HOME/.claude/scripts/statusline.sh"
  and ([.. | strings] | all(contains("ccstatusline") | not))
' "$ROOT/harnesses/claude/settings.json" >/dev/null
# Un transcript en fifo bloque toute lecture : la barre doit repondre sans l'ouvrir.
mkfifo "$TEST_TMP/transcript.fifo"
status_line="$("$TEST_PYTHON" - "$ROOT/harnesses/claude/scripts/statusline.sh" "$TEST_TMP/transcript.fifo" "$ROOT" <<'PY2'
import json
import subprocess
import sys
import time

script, fifo, root = sys.argv[1:]
payload = {
    "transcript_path": fifo,
    "model": {"display_name": "Opus"},
    "workspace": {"current_dir": root, "project_dir": root},
    "context_window": {"total_input_tokens": 298000, "used_percentage": 29.8},
    "rate_limits": {
        "five_hour": {"used_percentage": 42, "resets_at": int(time.time()) + 5430},
        "seven_day": {"used_percentage": 61, "resets_at": int(time.time()) + 86400},
    },
}
out = subprocess.run(
    [script], input=json.dumps(payload), capture_output=True, text=True, timeout=5, check=True
)
print(out.stdout, end="")
PY2
)"
case "$status_line" in
  *Opus*"Ctx: 298.0k (30%)"*"5h 42% (1h30)"*"7j 61%"*) ;;
  *)
    printf 'unexpected statusline: %s\n' "$status_line" >&2
    exit 1
    ;;
esac

echo "hooks: ok"
