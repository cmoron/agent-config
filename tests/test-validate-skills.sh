#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p \
  "$TMP/valid" \
  "$TMP/multiline-description" \
  "$TMP/wrong-name" \
  "$TMP/missing-description"

cat >"$TMP/valid/SKILL.md" <<'EOF'
---
name: valid
description: A valid test skill.
---

# Valid
EOF

cat >"$TMP/multiline-description/SKILL.md" <<'EOF'
---
name: multiline-description
description: |-
  A valid description
  spanning multiple lines.
---

# Valid multiline YAML
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
uv run "$ROOT/tests/validate-skills.py" "$TMP/multiline-description"

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

local_skill_roots=()
for harness in claude codex kimi opencode; do
  if [ -d "$ROOT/harnesses/$harness/skills" ]; then
    local_skill_roots+=("$ROOT/harnesses/$harness/skills")
  fi
done
uv run "$ROOT/tests/validate-skills.py" "${local_skill_roots[@]}"

anthropic_skills=(
  claude-api
  mcp-builder
  webapp-testing
  doc-coauthoring
  docx
  pdf
  pptx
  xlsx
)
anthropic_paths=()
for skill in "${anthropic_skills[@]}"; do
  anthropic_paths+=(
    "$ROOT/harnesses/claude/upstream/anthropic-skills/skills/$skill"
  )
done
uv run "$ROOT/tests/validate-skills.py" "${anthropic_paths[@]}"

matt_manifest="$ROOT/upstreams/mattpocock-skills/.claude-plugin/plugin.json"
[ -f "$matt_manifest" ] || {
  printf 'missing Matt Pocock skill manifest: %s\n' "$matt_manifest" >&2
  exit 1
}
mapfile -t matt_skills < <(jq -r '.skills[]' "$matt_manifest")
matt_paths=()
for skill in "${matt_skills[@]}"; do
  matt_paths+=("$ROOT/upstreams/mattpocock-skills/${skill#./}")
done
uv run "$ROOT/tests/validate-skills.py" "${matt_paths[@]}"

printf 'skill validator tests: PASS\n'
