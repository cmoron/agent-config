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
grep -q '^plugin add context7@claude-plugins-official$' "$AGENT_CONFIG_CODEX_LOG"
grep -q '^plugin add ponytail@ponytail$' "$AGENT_CONFIG_CODEX_LOG"

printf 'codex plugin tests: PASS\n'
