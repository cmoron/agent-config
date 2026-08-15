#!/usr/bin/env bash

set -euo pipefail

TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export TEST_ROOT

# macOS ships python 3.9, which predates tomllib.
TEST_PYTHON=""
for candidate in python3 python3.14 python3.13 python3.12 python3.11; do
  if "$candidate" -c 'import tomllib' >/dev/null 2>&1; then
    TEST_PYTHON="$candidate"
    break
  fi
done
export TEST_PYTHON

# BSD stat spells the octal mode differently from GNU stat.
if stat -c '%a' . >/dev/null 2>&1; then
  path_mode() { stat -c '%a' "$1"; }
else
  path_mode() { stat -f '%OLp' "$1"; }
fi

# GNU tar's deterministic flags are unavailable on BSD tar, so fingerprint each
# tree from path, type, mode, symlink target and content instead.
tree_fingerprint() {
  local root
  local path

  for root in "$@"; do
    find "$root" | LC_ALL=C sort | while IFS= read -r path; do
      if [ -L "$path" ]; then
        printf 'l %s %s\n' "$path" "$(readlink "$path")"
      elif [ -d "$path" ]; then
        printf 'd %s %s\n' "$path" "$(path_mode "$path")"
      else
        printf 'f %s %s %s\n' \
          "$path" "$(path_mode "$path")" "$(sha256sum <"$path" | awk '{print $1}')"
      fi
    done
  done | sha256sum | awk '{print $1}'
}

new_test_home() {
  TEST_TMP="$(mktemp -d)"
  export TEST_TMP
  export HOME="$TEST_TMP/home"
  export AGENT_CONFIG_WINDOWS_CODEX_DIR="$TEST_TMP/windows/.codex"
  export AGENT_CONFIG_SKIP_PLUGINS=1
  mkdir -p "$HOME" "$AGENT_CONFIG_WINDOWS_CODEX_DIR"
}

cleanup_test_home() {
  if [ -n "${TEST_TMP:-}" ] && [ -d "$TEST_TMP" ]; then
    rm -rf "$TEST_TMP"
  fi
}

assert_file() {
  [ -f "$1" ] || {
    printf 'expected file: %s\n' "$1" >&2
    return 1
  }
}

assert_dir() {
  [ -d "$1" ] || {
    printf 'expected directory: %s\n' "$1" >&2
    return 1
  }
}

assert_link_to() {
  local target="$1"
  local expected="$2"

  [ -L "$target" ] || {
    printf 'expected symlink: %s\n' "$target" >&2
    return 1
  }
  [ "$(readlink "$target")" = "$expected" ] || {
    printf 'unexpected symlink target: %s -> %s (expected %s)\n' \
      "$target" "$(readlink "$target")" "$expected" >&2
    return 1
  }
}

# macOS creates $HOME/Library on demand; install.sh never wrote it.
assert_home_untouched() {
  local leftover

  leftover="$(find "$1" -mindepth 1 -maxdepth 1 ! -name Library -print -quit)"
  [ -z "$leftover" ] || {
    printf 'expected an untouched home, found: %s\n' "$leftover" >&2
    return 1
  }
}

assert_not_exists() {
  if [ -e "$1" ] || [ -L "$1" ]; then
    printf 'expected path to be absent: %s\n' "$1" >&2
    return 1
  fi
}
