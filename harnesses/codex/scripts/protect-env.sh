#!/usr/bin/env bash
# Codex PreToolUse: apply_patch JSON -> shared file policy. docs/hooks.md.
set -euo pipefail
# shellcheck source=shared/scripts/file-actions.sh
source "$(dirname "${BASH_SOURCE[0]}")/file-actions.sh"
# shellcheck source=harnesses/codex/scripts/patch-files.sh
source "$(dirname "${BASH_SOURCE[0]}")/patch-files.sh"

INPUT=$(read_hook_input)
FILES=$(read_patch_paths "$INPUT")
change_hook_directory "$INPUT"
while IFS= read -r file; do
  protect_files "$file"
done <<<"$FILES"
printf '{}\n'
