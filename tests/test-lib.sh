#!/usr/bin/env bash

set -euo pipefail

TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export TEST_ROOT

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

assert_not_exists() {
  if [ -e "$1" ] || [ -L "$1" ]; then
    printf 'expected path to be absent: %s\n' "$1" >&2
    return 1
  fi
}
