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

cat >"$fake_bin/git" <<'EOF'
#!/usr/bin/env bash
printf 'git %s\n' "$*" >>"$AGENT_CONFIG_UPDATE_LOG"
EOF
cat >"$update_root/install.sh" <<'EOF'
#!/usr/bin/env bash
printf 'install %s\n' "$*" >>"$AGENT_CONFIG_UPDATE_LOG"
EOF
chmod +x "$fake_bin/git" "$update_root/install.sh" "$update_root/update.sh"

PATH="$fake_bin:$PATH" AGENT_CONFIG_UPDATE_LOG="$log" \
  "$update_root/update.sh" --only kimi --dry-run

grep -Fxq "git -C $update_root pull --ff-only" "$log"
grep -Fxq "git -C $update_root submodule update --init --recursive" "$log"
grep -Fxq 'install --only kimi --dry-run' "$log"

printf 'update tests: PASS\n'
