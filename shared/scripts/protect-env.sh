#!/usr/bin/env bash
# Claude/Kimi PreToolUse: JSON file_path -> shared protection. docs/hooks.md.
set -euo pipefail
# shellcheck source=shared/scripts/file-actions.sh
source "$(dirname "${BASH_SOURCE[0]}")/file-actions.sh"

INPUT=$(read_hook_input)
FILE=$(read_file_path "$INPUT")
change_hook_directory "$INPUT"
protect_files "$FILE"
