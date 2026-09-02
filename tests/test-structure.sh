#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

required_paths=(
  AGENTS.md
  README.md
  install.sh
  pyproject.toml
  scripts/update_upstreams.py
  update.sh
  uv.lock
  instructions/common.md
  shared/assets/warcraft-3-paysan-travail-termine.mp3
  shared/skills/api-design/SKILL.md
  shared/skills/deployment/SKILL.md
  shared/skills/mvp/SKILL.md
  shared/skills/nvim-config/SKILL.md
  shared/skills/stack-python/SKILL.md
  shared/skills/stack-rust/SKILL.md
  shared/skills/stack-ts/SKILL.md
  shared/skills/agent-config/SKILL.md
  shared/skills/autoship/SKILL.md
  shared/skills/commit/SKILL.md
  shared/skills/linear/SKILL.md
  shared/skills/lotusim-developer/SKILL.md
  shared/skills/macos-control/SKILL.md
  shared/skills/openclaw/SKILL.md
  shared/skills/opensource-contributor/SKILL.md
  shared/skills/wsl-windows-gui/SKILL.md
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
  harnesses/opencode/env.sh
  harnesses/opencode/opencode.json
  upstreams/mattpocock-skills/.claude-plugin/plugin.json
  upstreams/mattpocock-extra-skills.txt
)

for path in "${required_paths[@]}"; do
  if [ ! -e "$ROOT/$path" ]; then
    printf 'missing required path: %s\n' "$path" >&2
    exit 1
  fi
done

# Source unique : un skill vit dans shared/skills, jamais duplique par harness.
for harness in claude codex kimi opencode; do
  harness_skills="$ROOT/harnesses/$harness/skills"
  [ -d "$harness_skills" ] || continue
  if [ -n "$(find "$harness_skills" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
    printf 'harness-specific skill must live in shared/skills: %s\n' "$harness_skills" >&2
    exit 1
  fi
done

if [ -e "$ROOT/shared/skills/grill-with-docs" ]; then
  printf '%s\n' 'local grill-with-docs must follow the Matt Pocock upstream' >&2
  exit 1
fi

git config -f "$ROOT/.gitmodules" --get \
  submodule.upstreams/mattpocock-skills.url \
  | grep -qx 'https://github.com/mattpocock/skills.git'
git config -f "$ROOT/.gitmodules" --get \
  submodule.upstreams/mattpocock-skills.branch \
  | grep -qx main
git config -f "$ROOT/.gitmodules" --get \
  submodule.harnesses/claude/upstream/anthropic-skills.branch \
  | grep -qx main

if [ -e "$ROOT/global/AGENTS.md" ]; then
  printf 'legacy path must not exist: global/AGENTS.md\n' >&2
  exit 1
fi

expected_asset_hash="c5809450ce3b1b7fc1e7ea659335e6d3330ad41cbcdccee7ff7d7dd06890bcd1"
actual_asset_hash="$(sha256sum "$ROOT/shared/assets/warcraft-3-paysan-travail-termine.mp3" | awk '{print $1}')"
[ "$actual_asset_hash" = "$expected_asset_hash" ] || {
  printf 'shared notification asset hash mismatch\n' >&2
  exit 1
}

if rg -n \
  'src/(claude-config|codex-config|kimi-config)|name: (claude-config|codex-config)' \
  "$ROOT/harnesses" "$ROOT/shared"; then
  printf '%s\n' 'legacy repository identity remains in deployable content' >&2
  exit 1
fi

printf 'structure tests: PASS\n'
