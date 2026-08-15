#!/usr/bin/env bash

set -euo pipefail

INPUT=$(cat)
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || true)

while IFS= read -r file; do
  [ -f "$file" ] || continue

  case "${file##*.}" in
    py)
      command -v ruff >/dev/null || continue
      ruff format --quiet "$file"
      ruff check --fix --quiet "$file"
      ;;
    rs)
      command -v rustfmt >/dev/null || continue
      rustfmt --edition 2021 "$file"
      ;;
    ts|tsx|js|jsx|json|css|html|md|yaml|yml)
      command -v prettier >/dev/null || continue
      prettier --write --log-level silent "$file"
      ;;
  esac
done < <(printf '%s\n' "$COMMAND" | sed -nE 's/^\*\*\* (Add|Update) File: //p')

printf '{}\n'
