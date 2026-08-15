#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

required_paths=(
  AGENTS.md
  README.md
  install.sh
  update.sh
  instructions/common.md
  shared/assets/warcraft-3-paysan-travail-termine.mp3
  shared/skills/api-design/SKILL.md
  shared/skills/deployment/SKILL.md
  shared/skills/grill-with-docs/ADR-FORMAT.md
  shared/skills/grill-with-docs/CONTEXT-FORMAT.md
  shared/skills/grill-with-docs/SKILL.md
  shared/skills/mvp/SKILL.md
  shared/skills/nvim-config/SKILL.md
  shared/skills/stack-python/SKILL.md
  shared/skills/stack-rust/SKILL.md
  shared/skills/stack-ts/SKILL.md
  harnesses/claude/instructions.overlay.md
  harnesses/claude/settings.json
  harnesses/claude/config/ccstatusline/settings.json
  harnesses/claude/commands/autoship.md
  harnesses/claude/commands/commit.md
  harnesses/codex/instructions.overlay.md
  harnesses/codex/config.toml
  harnesses/codex/hooks.json
  harnesses/codex/rules/default.rules
  harnesses/kimi/instructions.overlay.md
  harnesses/kimi/config.toml
  harnesses/kimi/mcp.json
  harnesses/kimi/tui.toml
  harnesses/opencode/instructions.overlay.md
  harnesses/opencode/opencode.json
)

for path in "${required_paths[@]}"; do
  if [ ! -e "$ROOT/$path" ]; then
    printf 'missing required path: %s\n' "$path" >&2
    exit 1
  fi
done

if [ -e "$ROOT/global/AGENTS.md" ]; then
  printf 'legacy path must not exist: global/AGENTS.md\n' >&2
  exit 1
fi

portable_skills=(
  api-design
  deployment
  grill-with-docs
  mvp
  nvim-config
  stack-python
  stack-rust
  stack-ts
)

for skill in "${portable_skills[@]}"; do
  diff -qr "$ROOT/shared/skills/$skill" "/home/cyril/src/codex-config/skills/$skill" >/dev/null || {
    printf 'portable skill differs from audited source: %s\n' "$skill" >&2
    exit 1
  }
done

expected_asset_hash="c5809450ce3b1b7fc1e7ea659335e6d3330ad41cbcdccee7ff7d7dd06890bcd1"
actual_asset_hash="$(sha256sum "$ROOT/shared/assets/warcraft-3-paysan-travail-termine.mp3" | awk '{print $1}')"
[ "$actual_asset_hash" = "$expected_asset_hash" ] || {
  printf 'shared notification asset hash mismatch\n' >&2
  exit 1
}

printf 'structure tests: PASS\n'
