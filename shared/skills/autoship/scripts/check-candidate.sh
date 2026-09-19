#!/usr/bin/env bash
# Read-only guard; validates identity/cleanliness, not test or review quality.
set -euo pipefail
fail() { printf '%s\n' "$1" >&2; exit 1; }
[ "$#" -eq 2 ] || fail 'usage: bash check-candidate.sh BASE CANDIDATE'
base=$(git rev-parse --verify --end-of-options "$1^{commit}" 2>/dev/null) || fail 'invalid base'
candidate=$(git rev-parse --verify --end-of-options "$2^{commit}" 2>/dev/null) || fail 'invalid candidate'
[ "$(git rev-parse HEAD)" = "$candidate" ] || fail 'HEAD changed'
[ -z "$(git status --porcelain --untracked-files=all)" ] || fail 'dirty worktree'
git merge-base --is-ancestor "$base" "$candidate" || fail 'base is not an ancestor'
if git diff --quiet "$base" "$candidate"; then
  fail 'no changes'
else
  result=$?
  [ "$result" -eq 1 ] || fail 'diff failed'
fi
printf 'candidate OK: %s..%s\n' "$base" "$candidate"
