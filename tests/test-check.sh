#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=tests/test-lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/test-lib.sh"

snapshot_runtime() {
  tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner \
    -C "$TEST_TMP" -cf - home windows | sha256sum | awk '{print $1}'
}

new_test_home
trap cleanup_test_home EXIT

"$TEST_ROOT/install.sh" >/dev/null
"$TEST_ROOT/install.sh" --check >/dev/null

ln -sfn /missing/api-design "$HOME/.agents/skills/api-design"
printf '%s\n' '# unexpected global instructions' >"$HOME/.agents/AGENTS.md"
printf '%s\n' '[' >"$HOME/.kimi-code/config.toml"
printf '%s\n' '{ invalid json' >"$HOME/.config/opencode/opencode.json"
printf '%s\n' '{"hook":"/home/cyril/src/codex-config/scripts/old.sh"}' \
  >"$AGENT_CONFIG_WINDOWS_CODEX_DIR/hooks.json"

before_dry_run="$(snapshot_runtime)"
"$TEST_ROOT/install.sh" --dry-run >"$TEST_TMP/dry-run.out"
after_dry_run="$(snapshot_runtime)"
[ "$before_dry_run" = "$after_dry_run" ] || {
  printf '%s\n' '--dry-run mutated a runtime tree' >&2
  exit 1
}
grep -q '^WOULD ' "$TEST_TMP/dry-run.out"
grep -Fq \
  "WOULD BACKUP $HOME/.kimi-code/config.toml -> $HOME/.kimi-code/backups/" \
  "$TEST_TMP/dry-run.out"

before_check="$(snapshot_runtime)"
if "$TEST_ROOT/install.sh" --check >"$TEST_TMP/check.out" 2>&1; then
  printf '%s\n' '--check accepted a drifted runtime tree' >&2
  exit 1
fi
after_check="$(snapshot_runtime)"
[ "$before_check" = "$after_check" ] || {
  printf '%s\n' '--check mutated a runtime tree' >&2
  exit 1
}

grep -Fq "DRIFT shared $HOME/.agents/skills/api-design link" "$TEST_TMP/check.out"
[ "$(grep -Fc "DRIFT shared $HOME/.agents/skills/api-design link" "$TEST_TMP/check.out")" = 1 ]
grep -Fq "DRIFT shared $HOME/.agents/AGENTS.md unexpected" "$TEST_TMP/check.out"
grep -Fq "DRIFT kimi $HOME/.kimi-code/config.toml invalid-toml" "$TEST_TMP/check.out"
grep -Fq "DRIFT opencode $HOME/.config/opencode/opencode.json invalid-json" "$TEST_TMP/check.out"
grep -Fq \
  "DRIFT windows $AGENT_CONFIG_WINDOWS_CODEX_DIR/hooks.json legacy-reference" \
  "$TEST_TMP/check.out"

printf 'check tests: PASS\n'
