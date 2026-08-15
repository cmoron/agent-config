#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=tests/test-lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/test-lib.sh"

new_test_home
trap cleanup_test_home EXIT

update_root="$TEST_TMP/update-repo"
fake_bin="$TEST_TMP/bin"
log="$TEST_TMP/update.log"
mkdir -p "$update_root" "$fake_bin"
cp "$TEST_ROOT/update.sh" "$update_root/update.sh"
mkdir -p "$update_root/scripts"
cp "$TEST_ROOT/scripts/update_upstreams.py" "$update_root/scripts/update_upstreams.py"

cat >"$fake_bin/git" <<'EOF'
#!/usr/bin/env bash
printf 'git %s\n' "$*" >>"$AGENT_CONFIG_UPDATE_LOG"
EOF
cat >"$fake_bin/uv" <<'EOF'
#!/usr/bin/env bash
printf 'uv %s\n' "$*" >>"$AGENT_CONFIG_UPDATE_LOG"
EOF
chmod +x "$fake_bin/git" "$fake_bin/uv" "$update_root/update.sh"

PATH="$fake_bin:$PATH" AGENT_CONFIG_UPDATE_LOG="$log" \
  "$update_root/update.sh" --only kimi --dry-run

grep -Fxq "git -C $update_root pull --ff-only" "$log"
grep -Fxq "uv run $update_root/scripts/update_upstreams.py --only kimi --dry-run" "$log"

printf 'update tests: PASS\n'
