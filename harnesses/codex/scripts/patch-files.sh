#!/usr/bin/env bash
# Codex-only input adapter. Extract paths, including rename destinations.
# This is not a full patch grammar validator; see docs/hooks.md.
read_patch_paths() {
  local patch paths
  patch=$(jq -er '.tool_input.command | select(type == "string" and length > 0)
    | select(contains("\u0000") | not)' <<<"$1") || {
    printf '%s\n' 'hook: expected a nonempty tool_input.command patch' >&2
    return 2
  }
  if [[ "$patch" != '*** Begin Patch'$'\n'* ]] \
    || [[ "$patch" != *$'\n''*** End Patch' ]]; then
    printf '%s\n' 'hook: invalid patch boundaries' >&2
    return 2
  fi
  paths=$(printf '%s\n' "$patch" | sed -nE \
    's/^\*\*\* (Add|Update|Delete) File: //p; s/^\*\*\* Move to: //p')
  if ! jq -eRn --arg paths "$paths" '$paths | split("\n")
    | length > 0 and all(length > 0 and (test("[[:cntrl:]]") | not))' >/dev/null; then
    printf '%s\n' 'hook: patch has no usable file paths' >&2
    return 2
  fi
  printf '%s\n' "$paths"
}
