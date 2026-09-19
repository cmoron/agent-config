#!/usr/bin/env bash
# Claude/Kimi PostToolUse: JSON file_path -> shared formatter. docs/hooks.md.
set -euo pipefail
# shellcheck source=shared/scripts/file-actions.sh
source "$(dirname "${BASH_SOURCE[0]}")/file-actions.sh"

INPUT=$(read_hook_input)
FILE=$(read_file_path "$INPUT")
change_hook_directory "$INPUT"
format_files "$FILE"
