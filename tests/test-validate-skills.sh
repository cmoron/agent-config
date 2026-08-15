#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/valid" "$TMP/wrong-name" "$TMP/missing-description"

cat >"$TMP/valid/SKILL.md" <<'EOF'
---
name: valid
description: A valid test skill.
---

# Valid
EOF

cat >"$TMP/wrong-name/SKILL.md" <<'EOF'
---
name: another-name
description: The directory and frontmatter differ.
---
EOF

cat >"$TMP/missing-description/SKILL.md" <<'EOF'
---
name: missing-description
---
EOF

uv run "$ROOT/tests/validate-skills.py" "$TMP/valid"

if uv run "$ROOT/tests/validate-skills.py" "$TMP/wrong-name" >"$TMP/wrong.out" 2>&1; then
  printf '%s\n' 'validator accepted a mismatched skill name' >&2
  exit 1
fi
grep -q 'name must match directory' "$TMP/wrong.out"

if uv run "$ROOT/tests/validate-skills.py" "$TMP/missing-description" >"$TMP/missing.out" 2>&1; then
  printf '%s\n' 'validator accepted a missing description' >&2
  exit 1
fi
grep -q 'missing frontmatter key: description' "$TMP/missing.out"

uv run "$ROOT/tests/validate-skills.py" "$ROOT/shared/skills"

printf 'skill validator tests: PASS\n'
