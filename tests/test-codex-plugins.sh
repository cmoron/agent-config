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
  'printf "%s\n" "$*" >>"$AGENT_CONFIG_CODEX_LOG"' \
  >"$TEST_TMP/bin/codex"
chmod +x "$TEST_TMP/bin/codex"
export AGENT_CONFIG_CODEX_LOG="$TEST_TMP/codex.log"
export PATH="$TEST_TMP/bin:$PATH"
export AGENT_CONFIG_SKIP_PLUGINS=0
export AGENT_CONFIG_WINDOWS_CODEX_DIR=''

"$TEST_ROOT/install.sh" --only codex >/dev/null

grep -q '^plugin marketplace upgrade claude-plugins-official$' "$AGENT_CONFIG_CODEX_LOG"
grep -q '^plugin marketplace upgrade ponytail$' "$AGENT_CONFIG_CODEX_LOG"

"$TEST_PYTHON" - "$TEST_ROOT/harnesses/codex/config.toml" <<'PY' >"$TEST_TMP/expected-plugins"
import sys
import tomllib

with open(sys.argv[1], "rb") as config_file:
    config = tomllib.load(config_file)
for name, values in sorted(config["plugins"].items()):
    if values.get("enabled") is True:
        print(f"plugin add {name}")
PY

grep '^plugin add ' "$AGENT_CONFIG_CODEX_LOG" | sort >"$TEST_TMP/actual-plugins"
cmp "$TEST_TMP/expected-plugins" "$TEST_TMP/actual-plugins"
if grep -q '^plugin add playwright@claude-plugins-official$' "$AGENT_CONFIG_CODEX_LOG"; then
  printf '%s\n' 'disabled Codex plugin was installed' >&2
  exit 1
fi

printf 'codex plugin tests: PASS\n'
