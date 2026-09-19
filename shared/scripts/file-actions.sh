#!/usr/bin/env bash
# Shared file policy. Sourced by deployed adapters; see docs/hooks.md.

read_hook_input() {
  jq -ces 'select(length == 1) | .[0] | select(type == "object")' || {
    printf '%s\n' 'hook: expected one JSON object on stdin' >&2
    return 2
  }
}

read_file_path() {
  jq -er '.tool_input.file_path | select(type == "string" and length > 0)
    | select(test("[[:cntrl:]]") | not)' <<<"$1" || {
    printf '%s\n' 'hook: expected a nonempty tool_input.file_path without control characters' >&2
    return 2
  }
}

change_hook_directory() {
  local directory
  directory=$(jq -er '(if has("cwd") then .cwd else "." end)
    | select(type == "string" and length > 0)
    | select(test("[[:cntrl:]]") | not)' <<<"$1") || {
    printf '%s\n' 'hook: invalid cwd' >&2
    return 2
  }
  cd -- "$directory" || return 2
}

protect_files() {
  local file
  for file in "$@"; do
    case "${file##*/}" in
      .env|.env.*)
        printf 'Fichier protege : %s\nModifie-le manuellement si necessaire.\n' "$file" >&2
        return 2
        ;;
    esac
  done
}

format_files() {
  local file extension
  local -a formatter
  for file in "$@"; do
    [ -f "$file" ] || continue
    # Absolute paths also keep leading '-' filenames out of CLI option parsing.
    case "$file" in /*) ;; *) file="$PWD/$file" ;; esac
    extension="${file##*.}"
    case "$extension" in
      py) formatter=(ruff format --quiet) ;;
      rs) formatter=(rustfmt --edition 2021) ;;
      ts|tsx|js|jsx|json|jsonc|css) formatter=(biome format --write) ;;
      html|md|yaml|yml) formatter=(prettier --write --log-level silent) ;;
      *) continue ;;
    esac
    if ! command -v "${formatter[0]}" >/dev/null 2>&1; then
      printf 'hook: %s unavailable; skipped %s\n' "${formatter[0]}" "$file" >&2
      continue
    fi
    "${formatter[@]}" "$file" >&2 || return $?
    if [ "$extension" = py ]; then
      ruff check --fix --quiet "$file" >&2 || return $?
    fi
  done
}
