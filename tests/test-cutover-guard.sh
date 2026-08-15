#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=tests/test-lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/test-lib.sh"

new_test_home
trap cleanup_test_home EXIT

marker="$TEST_TMP/state/active"
export AGENT_CONFIG_ACTIVE_MARKER="$marker"
legacy_log="$TEST_TMP/legacy.log"
export AGENT_CONFIG_LEGACY_LOG="$legacy_log"
cat >"$TEST_TMP/legacy-install.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
source "$TEST_ROOT/scripts/legacy-installer-guard.sh" || exit \$?
printf '%s\n' ran >>"\$AGENT_CONFIG_LEGACY_LOG"
EOF
chmod +x "$TEST_TMP/legacy-install.sh"

"$TEST_ROOT/scripts/legacy-installer-guard.sh"
"$TEST_TMP/legacy-install.sh"
[ "$(wc -l <"$legacy_log")" = 1 ]
if "$TEST_ROOT/scripts/cutover-marker.sh" status >/dev/null 2>&1; then
  printf '%s\n' 'inactive cutover marker reported active' >&2
  exit 1
fi

"$TEST_ROOT/scripts/cutover-marker.sh" activate >/dev/null
assert_file "$marker"
if "$TEST_ROOT/scripts/legacy-installer-guard.sh" >"$TEST_TMP/guard.out" 2>&1; then
  printf '%s\n' 'legacy installer guard accepted an active cutover' >&2
  exit 1
else
  guard_status="$?"
fi
[ "$guard_status" = 78 ]
grep -q 'agent-config is active' "$TEST_TMP/guard.out"
if "$TEST_TMP/legacy-install.sh" >>"$TEST_TMP/guard.out" 2>&1; then
  printf '%s\n' 'sourced legacy guard accepted an active cutover' >&2
  exit 1
else
  sourced_status="$?"
fi
[ "$sourced_status" = 78 ]
[ "$(wc -l <"$legacy_log")" = 1 ]
"$TEST_ROOT/scripts/cutover-marker.sh" status >/dev/null

"$TEST_ROOT/scripts/cutover-marker.sh" deactivate >/dev/null
assert_not_exists "$marker"
"$TEST_ROOT/scripts/legacy-installer-guard.sh"

printf 'cutover guard tests: PASS\n'
