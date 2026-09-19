#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="$ROOT/shared/skills/autoship/scripts/check-candidate.sh"
fixture_dir="$(mktemp -d)"
trap 'rm -rf "$fixture_dir"' EXIT
git init -q "$fixture_dir"
cd "$fixture_dir"
git config user.name Test
git config user.email test@example.invalid
git config core.hooksPath /dev/null
git config commit.gpgsign false
printf 'base\n' > tracked
git add tracked
git commit -qm base
base="$(git rev-parse HEAD)"
printf 'candidate\n' >> tracked
git add tracked
git commit -qm candidate
candidate="$(git rev-parse HEAD)"

reject() {
  local reason="$1"
  shift
  if bash "$CHECK" "$@" > "$fixture_dir/verdict" 2>&1; then
    printf 'unexpected success: %s\n' "$reason" >&2
    exit 1
  fi
  grep -q "$reason" "$fixture_dir/verdict"
}
# Keep evidence outside the repository under review.
mkdir repo
# Move only the fixture Git repository and payload into its child.
mv .git tracked repo/
cd repo
bash "$CHECK" "$base" "$candidate"
reject 'invalid base' missing "$candidate"
reject 'invalid candidate' "$base" missing
reject 'no changes' "$candidate" "$candidate"
printf 'unstaged\n' >> tracked
reject 'dirty worktree' "$base" "$candidate"
git add tracked
reject 'dirty worktree' "$base" "$candidate"
git commit -qm rework
reject 'HEAD changed' "$base" "$candidate"
candidate="$(git rev-parse HEAD)"
printf 'new\n' > new-file
reject 'dirty worktree' "$base" "$candidate"
git add new-file
git commit -qm new-file
candidate="$(git rev-parse HEAD)"
bash "$CHECK" "$base" "$candidate"
printf 'review candidate tests: PASS\n'
