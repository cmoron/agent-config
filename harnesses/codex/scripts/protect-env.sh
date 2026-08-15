#!/usr/bin/env bash

set -euo pipefail

INPUT=$(cat)
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || true)

while IFS= read -r file; do
  case "$(basename "$file")" in
    .env|.env.*)
      echo "Fichier protege : $file" >&2
      echo "Modifie-le manuellement si necessaire." >&2
      exit 2
      ;;
  esac
done < <(printf '%s\n' "$COMMAND" | sed -nE 's/^\*\*\* (Add|Update|Delete) File: //p')

printf '{}\n'
