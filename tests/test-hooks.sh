#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CODEX_HARNESS="$ROOT/harnesses/codex"

# shellcheck source=tests/test-lib.sh
source "$ROOT/tests/test-lib.sh"
new_test_home
trap cleanup_test_home EXIT

mkdir -p "$TEST_TMP/bin" "$TEST_TMP/no-formatter-bin" "$TEST_TMP/format workspace" \
  "$HOME/.claude/scripts" "$HOME/.codex/scripts" "$HOME/.kimi-code/scripts"
for runtime in "$HOME/.claude" "$HOME/.kimi-code"; do
  printf 'foreign\n' >"$runtime/scripts/foreign-hook.sh"
done
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
for harness in claude codex kimi; do
  "$TEST_ROOT/install.sh" --only "$harness" >/dev/null
done

for runtime in "$HOME/.claude" "$HOME/.codex" "$HOME/.kimi-code"; do
  assert_dir "$runtime/scripts"
  [ ! -L "$runtime/scripts" ]
done
assert_file "$HOME/.claude/scripts/foreign-hook.sh"
assert_file "$HOME/.kimi-code/scripts/foreign-hook.sh"

for harness in claude codex kimi; do
  runtime="$HOME/.${harness}"
  [ "$harness" != kimi ] || runtime="$HOME/.kimi-code"
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
for harness in claude codex kimi; do
  runtime="$HOME/.${harness}"
  [ "$harness" != kimi ] || runtime="$HOME/.kimi-code"
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
for harness in claude codex kimi; do
  runtime="$HOME/.${harness}"
  [ "$harness" != kimi ] || runtime="$HOME/.kimi-code"
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

for harness in claude kimi; do
  runtime="$HOME/.${harness}"
  [ "$harness" != kimi ] || runtime="$HOME/.kimi-code"
  hook="$runtime/scripts/protect-env.sh"
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
done

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

# Stop nudge behaviour deliberately differs by harness. Markers stay in the
# test TMPDIR, never below the real /tmp.
reflect_workspace="$TEST_TMP/reflect-repo"
mkdir -p "$reflect_workspace"
git -C "$reflect_workspace" init -q
printf dirty >"$reflect_workspace/dirty"
export TMPDIR="$TEST_TMP/markers"
mkdir -p "$TMPDIR"
claude_reflect="$(jq -cn --arg cwd "$reflect_workspace" '{session_id: "claude-test", cwd: $cwd, stop_hook_active: false}')"
printf '%s' "$claude_reflect" | "$HOME/.claude/scripts/reflect-nudge.sh" >"$TEST_TMP/reflect.out"
jq -e '.hookSpecificOutput.hookEventName == "Stop"' "$TEST_TMP/reflect.out" >/dev/null
printf '%s' "$claude_reflect" | "$HOME/.claude/scripts/reflect-nudge.sh" >"$TEST_TMP/reflect.out"
[ ! -s "$TEST_TMP/reflect.out" ]

kimi_reflect="$(jq -cn --arg cwd "$reflect_workspace" '{session_id: "kimi-test", cwd: $cwd}')"
set +e
printf '%s' "$kimi_reflect" | "$HOME/.kimi-code/scripts/reflect-nudge.sh" >"$TEST_TMP/reflect.out" 2>"$TEST_TMP/reflect.err"
status=$?
set -e
[ "$status" -eq 2 ] && [ -s "$TEST_TMP/reflect.err" ]
set +e
printf '%s' "$kimi_reflect" | "$HOME/.kimi-code/scripts/reflect-nudge.sh" >"$TEST_TMP/reflect.out" 2>"$TEST_TMP/reflect.err"
status=$?
set -e
[ "$status" -eq 0 ] && [ ! -s "$TEST_TMP/reflect.err" ]
[ -f "$TMPDIR/kimi-reflect-kimi-test" ]
[ ! -e /tmp/kimi-reflect-kimi-test ]

# The shared player receives its asset path from the deployed harness script.
export HOOK_LOG="$TEST_TMP/sound.log"
for runtime in "$HOME/.claude" "$HOME/.codex" "$HOME/.kimi-code"; do
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
