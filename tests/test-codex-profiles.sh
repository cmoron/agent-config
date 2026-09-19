#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/test-lib.sh"

new_test_home
trap cleanup_test_home EXIT

mkdir -p "$HOME/.codex"
printf 'model = "personal"\n' >"$HOME/.codex/terra.config.toml"
printf 'model = "foreign"\n' >"$HOME/.codex/personal.config.toml"
cp "$TEST_ROOT/tests/fixtures/windows-config.toml" "$AGENT_CONFIG_WINDOWS_CODEX_DIR/config.toml"
windows_hash="$(sha256sum <"$AGENT_CONFIG_WINDOWS_CODEX_DIR/config.toml")"
AGENT_CONFIG_BACKUP_STAMP=profiles "$TEST_ROOT/install.sh" --only codex >/dev/null

# Exercise the installed CLI, not the plugin-bootstrap stub. No model request
# or MCP connection is made by listing configured servers in this temporary home.
if command -v codex >/dev/null 2>&1; then
  codex --version
  for profile in terra luna sol-high; do
    (
      cd "$TEST_TMP"
      env CODEX_HOME="$HOME/.codex" codex --profile "$profile" mcp list --json
    ) >"$TEST_TMP/$profile.json"
    jq -e 'type == "array"' "$TEST_TMP/$profile.json" >/dev/null
  done
else
  printf '%s\n' 'SKIP native Codex profile probe: codex is not installed'
fi

"$TEST_PYTHON" - "$HOME/.codex" "$AGENT_CONFIG_WINDOWS_CODEX_DIR" <<'PY'
import sys
import tomllib
from pathlib import Path

linux, windows = map(Path, sys.argv[1:])
base = tomllib.loads((linux / "config.toml").read_text())
assert base["model"] == "gpt-5.6-sol"
assert base["model_reasoning_effort"] == "xhigh"
assert "profiles" not in base and "profile" not in base
for name, model in {"terra": "gpt-5.6-terra", "luna": "gpt-5.6-luna", "sol-high": "gpt-5.6-sol"}.items():
    source = linux / f"{name}.config.toml"
    target = windows / source.name
    assert source.is_file() and not source.is_symlink()
    assert target.is_file() and not target.is_symlink()
    assert tomllib.loads(source.read_text()) == {"model": model, "model_reasoning_effort": "high"}
    assert target.read_bytes() == source.read_bytes()
PY

grep -q 'personal' "$HOME/.codex/backups/profiles/terra.config.toml"
grep -q 'foreign' "$HOME/.codex/personal.config.toml"
[ "$windows_hash" = "$(sha256sum <"$AGENT_CONFIG_WINDOWS_CODEX_DIR/config.toml")" ]
"$TEST_ROOT/install.sh" --only codex --check >/dev/null

# Profile drift must be detected, repaired with a backup, and then stay clean.
printf 'model = "drift"\n' >"$HOME/.codex/luna.config.toml"
if "$TEST_ROOT/install.sh" --only codex --check >"$TEST_TMP/drift.log"; then
  printf '%s\n' 'check accepted Codex profile drift' >&2
  exit 1
fi
grep -Fq 'luna.config.toml' "$TEST_TMP/drift.log"
"$TEST_ROOT/install.sh" --only codex >/dev/null
"$TEST_ROOT/install.sh" --only codex --check >/dev/null

printf 'codex profile tests: PASS\n'
