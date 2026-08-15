#!/usr/bin/env bash

set -euo pipefail

# macOS ships bash 3.2, which has neither mapfile nor associative arrays.
if [ "${BASH_VERSINFO[0]:-0}" -lt 4 ]; then
  for candidate in /opt/homebrew/bin/bash /usr/local/bin/bash; do
    candidate_major="$("$candidate" -c 'echo ${BASH_VERSINFO[0]}' 2>/dev/null || echo 0)"
    if [ "${candidate_major:-0}" -ge 4 ]; then
      exec "$candidate" "$0" "$@"
    fi
  done
  printf '%s\n' 'agent-config requires bash >= 4; install it with: brew install bash' >&2
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE=apply
ONLY=""
CHECK_FAILED=0
BACKUP_STAMP="${AGENT_CONFIG_BACKUP_STAMP:-$(date +%Y%m%d-%H%M%S-%N)-$$}"

CLAUDE_DIR="${AGENT_CONFIG_CLAUDE_DIR:-$HOME/.claude}"
CODEX_DIR="${AGENT_CONFIG_CODEX_DIR:-$HOME/.codex}"
KIMI_DIR="${AGENT_CONFIG_KIMI_DIR:-$HOME/.kimi-code}"
OPENCODE_DIR="${AGENT_CONFIG_OPENCODE_DIR:-$HOME/.config/opencode}"
AGENTS_DIR="${AGENT_CONFIG_AGENTS_DIR:-$HOME/.agents}"
STATE_DIR="${AGENT_CONFIG_STATE_DIR:-$HOME/.config/agent-config}"
PROFILE_LOCAL="${AGENT_CONFIG_PROFILE_LOCAL:-$HOME/.profile.local}"
PROFILE_BLOCK_BEGIN='# >>> agent-config: opencode >>>'
PROFILE_BLOCK_END='# <<< agent-config: opencode <<<'

if [ "${AGENT_CONFIG_WINDOWS_CODEX_DIR+x}" = x ]; then
  WINDOWS_CODEX_DIR="$AGENT_CONFIG_WINDOWS_CODEX_DIR"
elif [ "${CODEX_CONFIG_WINDOWS_DIR+x}" = x ]; then
  WINDOWS_CODEX_DIR="$CODEX_CONFIG_WINDOWS_DIR"
elif [ -d "/mnt/c/Users/${USER:-}" ]; then
  WINDOWS_CODEX_DIR="/mnt/c/Users/$USER/.codex"
else
  WINDOWS_CODEX_DIR=""
fi

LEGACY_ROOTS=(
  "$HOME/src/claude-config"
  "$HOME/src/codex-config"
  "$HOME/src/kimi-config"
  "$HOME/src/skills"
)
ANTHROPIC_ALLOWLIST=(
  claude-api
  mcp-builder
  webapp-testing
  doc-coauthoring
  docx
  pdf
  pptx
  xlsx
)
MATT_ROOT="$ROOT/upstreams/mattpocock-skills"
MATT_MANIFEST="$MATT_ROOT/.claude-plugin/plugin.json"
MATT_SKILL_ENTRIES=""
WINDOWS_MANAGED_PATHS=()

usage() {
  cat <<'EOF'
Usage: ./install.sh [--only claude|codex|kimi|opencode] [--check|--dry-run]

  --only NAME  Limit deployment or checks to one harness.
  --check      Report drift without changing files.
  --dry-run    Print planned changes without changing files.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --only)
      [ "$#" -ge 2 ] || {
        printf '%s\n' '--only requires a harness' >&2
        exit 2
      }
      ONLY="$2"
      shift 2
      ;;
    --check)
      [ "$MODE" = apply ] || {
        printf '%s\n' '--check and --dry-run are mutually exclusive' >&2
        exit 2
      }
      MODE=check
      shift
      ;;
    --dry-run)
      [ "$MODE" = apply ] || {
        printf '%s\n' '--check and --dry-run are mutually exclusive' >&2
        exit 2
      }
      MODE=dry-run
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'unknown option: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

case "$ONLY" in
  ""|claude|codex|kimi|opencode) ;;
  *)
    printf 'unknown harness: %s\n' "$ONLY" >&2
    exit 2
    ;;
esac

# macOS ships python 3.9, which predates tomllib.
PYTHON="${AGENT_CONFIG_PYTHON:-}"
if [ -z "$PYTHON" ]; then
  for candidate in python3 python3.14 python3.13 python3.12 python3.11; do
    if "$candidate" -c 'import tomllib' >/dev/null 2>&1; then
      PYTHON="$candidate"
      break
    fi
  done
fi
if [ -z "$PYTHON" ]; then
  printf '%s\n' 'agent-config requires python >= 3.11 (tomllib) on PATH' >&2
  exit 1
fi

# BSD realpath has no -m, and the path is allowed not to exist yet.
normalize_path() {
  "$PYTHON" -c 'import os, sys; print(os.path.normpath(sys.argv[1]))' "$1"
}

# BSD stat spells the octal mode differently from GNU stat.
if stat -c '%a' . >/dev/null 2>&1; then
  path_mode() { stat -c '%a' "$1"; }
else
  path_mode() { stat -f '%OLp' "$1"; }
fi

validate_safe_path() {
  local variable="$1"
  local path="$2"
  local normalized

  if [ -z "$path" ] || [[ "$path" != /* ]]; then
    printf 'unsafe path override: %s=%s (expected an absolute path)\n' \
      "$variable" "$path" >&2
    return 1
  fi
  normalized="$(normalize_path "$path")"
  if [ "$normalized" = / ]; then
    printf 'unsafe path override: %s=%s (filesystem root is forbidden)\n' \
      "$variable" "$path" >&2
    return 1
  fi
}

validate_runtime_paths() {
  validate_safe_path AGENT_CONFIG_CLAUDE_DIR "$CLAUDE_DIR"
  validate_safe_path AGENT_CONFIG_CODEX_DIR "$CODEX_DIR"
  validate_safe_path AGENT_CONFIG_KIMI_DIR "$KIMI_DIR"
  validate_safe_path AGENT_CONFIG_OPENCODE_DIR "$OPENCODE_DIR"
  validate_safe_path AGENT_CONFIG_AGENTS_DIR "$AGENTS_DIR"
  validate_safe_path AGENT_CONFIG_STATE_DIR "$STATE_DIR"
  validate_safe_path AGENT_CONFIG_PROFILE_LOCAL "$PROFILE_LOCAL"
  if [ -n "$WINDOWS_CODEX_DIR" ]; then
    validate_safe_path AGENT_CONFIG_WINDOWS_CODEX_DIR "$WINDOWS_CODEX_DIR"
  fi
}

validate_runtime_paths

selected_harnesses() {
  if [ -n "$ONLY" ]; then
    printf '%s\n' "$ONLY"
  else
    printf '%s\n' claude codex kimi opencode
  fi
}

runtime_root_for() {
  case "$1" in
    claude) printf '%s\n' "$CLAUDE_DIR" ;;
    codex) printf '%s\n' "$CODEX_DIR" ;;
    kimi) printf '%s\n' "$KIMI_DIR" ;;
    opencode) printf '%s\n' "$OPENCODE_DIR" ;;
  esac
}

instruction_target_for() {
  case "$1" in
    claude) printf '%s/CLAUDE.md\n' "$CLAUDE_DIR" ;;
    codex) printf '%s/AGENTS.md\n' "$CODEX_DIR" ;;
    kimi) printf '%s/AGENTS.md\n' "$KIMI_DIR" ;;
    opencode) printf '%s/AGENTS.md\n' "$OPENCODE_DIR" ;;
  esac
}

managed_link() {
  local link="$1"
  local destination
  local legacy

  [ -L "$link" ] || return 1
  destination="$(readlink "$link")"
  case "$destination" in
    "$ROOT"|"$ROOT"/*) return 0 ;;
  esac
  for legacy in "${LEGACY_ROOTS[@]}"; do
    case "$destination" in
      "$legacy"|"$legacy"/*) return 0 ;;
    esac
  done
  return 1
}

report_drift() {
  local harness="$1"
  local target="$2"
  local reason="$3"

  printf 'DRIFT %s %s %s\n' "$harness" "$target" "$reason"
  CHECK_FAILED=1
}

json_is_valid() {
  jq empty "$1" >/dev/null 2>&1
}

toml_is_valid() {
  "$PYTHON" -c \
    'import sys, tomllib; tomllib.load(open(sys.argv[1], "rb"))' \
    "$1" >/dev/null 2>&1
}

validate_harness_sources() {
  local harness="$1"
  local source

  case "$harness" in
    claude)
      source="$ROOT/harnesses/claude/settings.json"
      json_is_valid "$source" || {
        printf 'invalid source JSON: %s\n' "$source" >&2
        return 1
      }
      ;;
    codex)
      source="$ROOT/harnesses/codex/config.toml"
      toml_is_valid "$source" || {
        printf 'invalid source TOML: %s\n' "$source" >&2
        return 1
      }
      source="$ROOT/harnesses/codex/hooks.json"
      json_is_valid "$source" || {
        printf 'invalid source JSON: %s\n' "$source" >&2
        return 1
      }
      ;;
    kimi)
      for source in \
        "$ROOT/harnesses/kimi/config.toml" \
        "$ROOT/harnesses/kimi/tui.toml"; do
        toml_is_valid "$source" || {
          printf 'invalid source TOML: %s\n' "$source" >&2
          return 1
        }
      done
      source="$ROOT/harnesses/kimi/mcp.json"
      json_is_valid "$source" || {
        printf 'invalid source JSON: %s\n' "$source" >&2
        return 1
      }
      ;;
    opencode)
      source="$ROOT/harnesses/opencode/opencode.json"
      json_is_valid "$source" || {
        printf 'invalid source JSON: %s\n' "$source" >&2
        return 1
      }
      if [ -f "$PROFILE_LOCAL" ] && [ ! -L "$PROFILE_LOCAL" ]; then
        awk \
          -v begin_marker="$PROFILE_BLOCK_BEGIN" \
          -v end_marker="$PROFILE_BLOCK_END" '
            $0 == begin_marker {
              begins++
              if (state != 0) bad = 1
              state = 1
            }
            $0 == end_marker {
              ends++
              if (state != 1) bad = 1
              state = 2
            }
            END {
              clean = begins == 0 && ends == 0
              managed = !bad && begins == 1 && ends == 1 && state == 2
              exit !(clean || managed)
            }
          ' "$PROFILE_LOCAL" || {
          printf 'malformed managed block in %s\n' "$PROFILE_LOCAL" >&2
          return 1
        }
      fi
      ;;
  esac
}

ensure_parent() {
  local target="$1"

  if [ "$MODE" = apply ]; then
    mkdir -p "$(dirname "$target")"
  fi
}

render_temp_for() {
  local target="$1"

  if [ "$MODE" = apply ]; then
    ensure_parent "$target"
    mktemp "$(dirname "$target")/.agent-config.tmp.XXXXXX"
  else
    mktemp
  fi
}

ensure_directory() {
  local harness="$1"
  local target="$2"

  if [ -d "$target" ] && [ ! -L "$target" ]; then
    return 0
  fi
  case "$MODE" in
    check) report_drift "$harness" "$target" directory ;;
    dry-run)
      plan_backup_existing "$target" "$(runtime_root_for "$harness")"
      printf 'WOULD MKDIR %s\n' "$target"
      ;;
    apply)
      if [ -e "$target" ] || [ -L "$target" ]; then
        backup_existing "$target" "$(runtime_root_for "$harness")"
      fi
      mkdir -p "$target"
      printf 'MKDIR %s\n' "$target"
      ;;
  esac
}

backup_path_for() {
  local target="$1"
  local root="$2"
  local relative
  local base
  local candidate
  local suffix=0

  relative="${target#"$root"/}"
  if [ "$relative" = "$target" ]; then
    relative="$(basename "$target")"
  fi
  base="$root/backups/$BACKUP_STAMP/$relative"
  candidate="$base"
  while [ -e "$candidate" ] || [ -L "$candidate" ]; do
    suffix=$((suffix + 1))
    candidate="$base.$suffix"
  done
  printf '%s\n' "$candidate"
}

plan_backup_existing() {
  local target="$1"
  local root="$2"
  local backup

  [ -e "$target" ] || [ -L "$target" ] || return 0
  managed_link "$target" && return 0
  backup="$(backup_path_for "$target" "$root")"
  printf 'WOULD BACKUP %s -> %s\n' "$target" "$backup"
}

backup_existing() {
  local target="$1"
  local root="$2"
  local backup

  [ -e "$target" ] || [ -L "$target" ] || return 0
  if managed_link "$target"; then
    rm -f "$target"
    return 0
  fi

  backup="$(backup_path_for "$target" "$root")"
  mkdir -p "$(dirname "$backup")"
  chmod 700 "$root/backups" "$root/backups/$BACKUP_STAMP"
  mv "$target" "$backup"
  printf 'BACKUP %s %s\n' "$target" "$backup"
}

deploy_link() {
  local harness="$1"
  local source="$2"
  local target="$3"
  local root="$4"

  if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
    return 0
  fi

  case "$MODE" in
    check)
      report_drift "$harness" "$target" link
      ;;
    dry-run)
      plan_backup_existing "$target" "$root"
      printf 'WOULD LINK %s -> %s\n' "$target" "$source"
      ;;
    apply)
      ensure_parent "$target"
      backup_existing "$target" "$root"
      ln -s "$source" "$target"
      printf 'LINK %s -> %s\n' "$target" "$source"
      ;;
  esac
}

deploy_copy_file() {
  local harness="$1"
  local source="$2"
  local target="$3"
  local root="$4"
  local required_mode="${5:-644}"
  local current_mode=""

  if [ -f "$target" ] && [ ! -L "$target" ]; then
    current_mode="$(path_mode "$target")"
    if cmp -s "$source" "$target" && [ "$current_mode" = "$required_mode" ]; then
      return 0
    fi
  fi

  case "$MODE" in
    check)
      report_drift "$harness" "$target" content
      ;;
    dry-run)
      plan_backup_existing "$target" "$root"
      printf 'WOULD COPY %s -> %s\n' "$source" "$target"
      ;;
    apply)
      ensure_parent "$target"
      backup_existing "$target" "$root"
      cp "$source" "$target"
      chmod "$required_mode" "$target"
      printf 'COPY %s -> %s\n' "$source" "$target"
      ;;
  esac
}

# Applications rewrite the files they own in their own key order. Comparing an
# app-owned JSON byte-for-byte against a `jq -S` rendering reports drift forever.
rendered_matches() {
  local rendered="$1"
  local target="$2"

  case "$3" in
    json) jq -S . "$target" 2>/dev/null | cmp -s "$rendered" - ;;
    *) cmp -s "$rendered" "$target" ;;
  esac
}

deploy_rendered_file() {
  local harness="$1"
  local rendered="$2"
  local target="$3"
  local root="$4"
  local required_mode="${5:-644}"
  local compare_as="${6:-raw}"
  local current_mode=""

  if [ -f "$target" ] && [ ! -L "$target" ]; then
    current_mode="$(path_mode "$target")"
    if rendered_matches "$rendered" "$target" "$compare_as" \
      && [ "$current_mode" = "$required_mode" ]; then
      rm -f "$rendered"
      return 0
    fi
  fi

  case "$MODE" in
    check)
      report_drift "$harness" "$target" content
      rm -f "$rendered"
      ;;
    dry-run)
      plan_backup_existing "$target" "$root"
      printf 'WOULD WRITE %s\n' "$target"
      rm -f "$rendered"
      ;;
    apply)
      ensure_parent "$target"
      backup_existing "$target" "$root"
      mv "$rendered" "$target"
      chmod "$required_mode" "$target"
      printf 'WRITE %s\n' "$target"
      ;;
  esac
}

deploy_seed_file() {
  local harness="$1"
  local source="$2"
  local target="$3"
  local root="$4"
  local required_mode="${5:-644}"

  if [ -f "$target" ] && [ ! -L "$target" ]; then
    return 0
  fi
  case "$MODE" in
    check) report_drift "$harness" "$target" missing ;;
    dry-run)
      plan_backup_existing "$target" "$root"
      printf 'WOULD SEED %s -> %s\n' "$source" "$target"
      ;;
    apply)
      ensure_parent "$target"
      backup_existing "$target" "$root"
      cp "$source" "$target"
      chmod "$required_mode" "$target"
      printf 'SEED %s -> %s\n' "$source" "$target"
      ;;
  esac
}

render_claude_settings() {
  local output="$1"
  local source="$ROOT/harnesses/claude/settings.json"
  local target="$CLAUDE_DIR/settings.json"

  command -v jq >/dev/null 2>&1 || {
    printf '%s\n' 'jq is required to merge Claude settings' >&2
    return 1
  }
  if [ -f "$target" ]; then
    jq -S -s '
      .[0] as $runtime
      | .[1] as $source
      | ($runtime * $source)
      | .permissions = $source.permissions
      | .model = $source.model
      | .hooks = $source.hooks
      | .statusLine = $source.statusLine
      | .enabledPlugins = $source.enabledPlugins
      | .extraKnownMarketplaces = $source.extraKnownMarketplaces
    ' "$target" "$source" >"$output"
  else
    jq -S . "$source" >"$output"
  fi
}

# Codex stamps refresh metadata into the source-owned [marketplaces.*] sections.
# Dropping it makes --check drift again after every marketplace upgrade.
preserve_codex_marketplace_state() {
  "$PYTHON" - "$1" "$2" <<'PY'
import sys

output_path, target_path = sys.argv[1], sys.argv[2]
runtime_keys = ("last_updated", "last_revision")


def collect(lines):
    preserved, section = {}, None
    for line in lines:
        if line.startswith("["):
            section = line.strip() if line.startswith("[marketplaces.") else None
        elif section and line.split("=", 1)[0].strip() in runtime_keys:
            preserved.setdefault(section, []).append(line)
    return preserved


with open(target_path, encoding="utf-8") as handle:
    preserved = collect(handle.read().splitlines())
if not preserved:
    raise SystemExit(0)

with open(output_path, encoding="utf-8") as handle:
    lines = handle.read().splitlines()

merged = []
for line in lines:
    merged.append(line)
    merged.extend(preserved.get(line.strip(), []))

with open(output_path, "w", encoding="utf-8") as handle:
    handle.write("\n".join(merged) + "\n")
PY
}

render_codex_config() {
  local output="$1"
  local source="$ROOT/harnesses/codex/config.toml"
  local target="$CODEX_DIR/config.toml"
  local runtime_state

  cp "$source" "$output"
  [ -f "$target" ] || return 0
  preserve_codex_marketplace_state "$output" "$target"

  runtime_state="$(mktemp)"
  awk '
    /^\[hooks\.state(\]|\.")/ || /^\[projects(\]|\.")/ { keep = 1 }
    /^\[/ && $0 !~ /^\[hooks\.state(\]|\.")/ && $0 !~ /^\[projects(\]|\.")/ {
      keep = 0
    }
    keep
  ' "$target" >"$runtime_state"
  if [ -s "$runtime_state" ]; then
    printf '\n' >>"$output"
    cat "$runtime_state" >>"$output"
  fi
  rm -f "$runtime_state"
}

render_kimi_config() {
  local output="$1"
  local source="$ROOT/harnesses/kimi/config.toml"
  local target="$KIMI_DIR/config.toml"

  if [ -f "$target" ]; then
    awk -f "$ROOT/scripts/merge-kimi-config.awk" "$source" "$target" >"$output"
  else
    awk -f "$ROOT/scripts/merge-kimi-config.awk" "$source" "$source" >"$output"
  fi
}

render_profile_local() {
  local output="$1"

  if [ -f "$PROFILE_LOCAL" ] && [ ! -L "$PROFILE_LOCAL" ]; then
    awk \
      -v begin_marker="$PROFILE_BLOCK_BEGIN" \
      -v end_marker="$PROFILE_BLOCK_END" '
        $0 == begin_marker { skip = 1; next }
        $0 == end_marker { skip = 0; next }
        !skip { print }
      ' "$PROFILE_LOCAL" >"$output"
  else
    : >"$output"
  fi
  {
    printf '%s\n' "$PROFILE_BLOCK_BEGIN"
    cat "$ROOT/harnesses/opencode/env.sh"
    printf '%s\n' "$PROFILE_BLOCK_END"
  } >>"$output"
}

deploy_named_files() {
  local harness="$1"
  local source_dir="$2"
  local target_dir="$3"
  local root="$4"
  local names=()
  local source
  local name

  ensure_directory "$harness" "$target_dir"
  [ -d "$source_dir" ] || return 0
  for source in "$source_dir"/*; do
    [ -f "$source" ] || continue
    name="$(basename "$source")"
    names+=("$name")
  done
  prune_skill_links "$harness" "$target_dir" "${names[@]}"
  for name in "${names[@]}"; do
    deploy_link "$harness" "$source_dir/$name" "$target_dir/$name" "$root"
  done
}

deploy_harness_config() {
  local harness="$1"
  local rendered

  case "$harness" in
    claude)
      rendered="$(render_temp_for "$CLAUDE_DIR/settings.json")"
      render_claude_settings "$rendered"
      deploy_rendered_file claude "$rendered" "$CLAUDE_DIR/settings.json" "$CLAUDE_DIR" 600 json
      deploy_link claude "$ROOT/harnesses/claude/scripts" "$CLAUDE_DIR/scripts" "$CLAUDE_DIR"
      deploy_link claude "$ROOT/shared/assets" "$CLAUDE_DIR/assets" "$CLAUDE_DIR"
      deploy_named_files claude "$ROOT/harnesses/claude/commands" "$CLAUDE_DIR/commands" "$CLAUDE_DIR"
      deploy_named_files claude "$ROOT/harnesses/claude/agents" "$CLAUDE_DIR/agents" "$CLAUDE_DIR"
      deploy_link claude "$ROOT/harnesses/claude/config/ccstatusline" "$HOME/.config/ccstatusline" "$HOME/.config"
      ;;
    codex)
      rendered="$(render_temp_for "$CODEX_DIR/config.toml")"
      render_codex_config "$rendered"
      deploy_rendered_file codex "$rendered" "$CODEX_DIR/config.toml" "$CODEX_DIR" 600
      deploy_copy_file codex "$ROOT/harnesses/codex/hooks.json" "$CODEX_DIR/hooks.json" "$CODEX_DIR" 644
      deploy_copy_file codex "$ROOT/harnesses/codex/rules/default.rules" "$CODEX_DIR/rules/default.rules" "$CODEX_DIR" 644
      deploy_link codex "$ROOT/harnesses/codex/scripts" "$CODEX_DIR/scripts" "$CODEX_DIR"
      deploy_link codex "$ROOT/shared/assets" "$CODEX_DIR/assets" "$CODEX_DIR"
      deploy_link codex "$ROOT/harnesses/codex/agents" "$CODEX_DIR/agents" "$CODEX_DIR"
      ;;
    kimi)
      rendered="$(render_temp_for "$KIMI_DIR/config.toml")"
      render_kimi_config "$rendered"
      deploy_rendered_file kimi "$rendered" "$KIMI_DIR/config.toml" "$KIMI_DIR" 600
      deploy_copy_file kimi "$ROOT/harnesses/kimi/tui.toml" "$KIMI_DIR/tui.toml" "$KIMI_DIR" 644
      deploy_copy_file kimi "$ROOT/harnesses/kimi/mcp.json" "$KIMI_DIR/mcp.json" "$KIMI_DIR" 600
      deploy_link kimi "$ROOT/harnesses/kimi/scripts" "$KIMI_DIR/scripts" "$KIMI_DIR"
      deploy_link kimi "$ROOT/shared/assets" "$KIMI_DIR/assets" "$KIMI_DIR"
      ;;
    opencode)
      deploy_copy_file opencode "$ROOT/harnesses/opencode/opencode.json" "$OPENCODE_DIR/opencode.json" "$OPENCODE_DIR" 600
      rendered="$(render_temp_for "$PROFILE_LOCAL")"
      render_profile_local "$rendered"
      deploy_rendered_file opencode "$rendered" "$PROFILE_LOCAL" "$STATE_DIR" 600
      ;;
  esac
}

render_instructions_to() {
  local harness="$1"
  local output="$2"

  {
    printf '%s\n\n' '<!-- Generated by agent-config; edit instructions/common.md or the harness overlay. -->'
    cat "$ROOT/instructions/common.md"
    printf '\n'
    cat "$ROOT/harnesses/$harness/instructions.overlay.md"
  } >"$output"
}

deploy_instructions() {
  local harness="$1"
  local target
  local root
  local rendered

  target="$(instruction_target_for "$harness")"
  root="$(runtime_root_for "$harness")"
  rendered="$(render_temp_for "$target")"
  render_instructions_to "$harness" "$rendered"

  if [ -f "$target" ] && [ ! -L "$target" ] && cmp -s "$rendered" "$target"; then
    rm -f "$rendered"
    return 0
  fi

  case "$MODE" in
    check)
      report_drift "$harness" "$target" content
      rm -f "$rendered"
      ;;
    dry-run)
      plan_backup_existing "$target" "$root"
      printf 'WOULD RENDER %s\n' "$target"
      rm -f "$rendered"
      ;;
    apply)
      ensure_parent "$target"
      backup_existing "$target" "$root"
      mv "$rendered" "$target"
      chmod 644 "$target"
      printf 'RENDER %s\n' "$target"
      ;;
  esac
}

skill_name_desired() {
  local needle="$1"
  shift
  local candidate

  for candidate in "$@"; do
    [ "$candidate" = "$needle" ] && return 0
  done
  return 1
}

prune_skill_links() {
  local harness="$1"
  local target_dir="$2"
  shift 2
  local desired=("$@")
  local link
  local name

  [ -d "$target_dir" ] || return 0
  for link in "$target_dir"/*; do
    [ -L "$link" ] || continue
    managed_link "$link" || continue
    name="$(basename "$link")"
    skill_name_desired "$name" "${desired[@]}" && continue
    case "$MODE" in
      check) report_drift "$harness" "$link" stale ;;
      dry-run) printf 'WOULD PRUNE %s\n' "$link" ;;
      apply)
        rm -f "$link"
        printf 'PRUNE %s\n' "$link"
        ;;
    esac
  done
}

directory_names() {
  local parent="$1"
  local path

  [ -d "$parent" ] || return 0
  for path in "$parent"/*; do
    [ -d "$path" ] || continue
    basename "$path"
  done
}

load_matt_skill_entries() {
  "$PYTHON" - "$MATT_ROOT" "$MATT_MANIFEST" <<'PY'
import json
import re
import sys
from pathlib import Path, PurePosixPath

root = Path(sys.argv[1])
manifest_path = Path(sys.argv[2])
if not manifest_path.is_file():
    raise SystemExit(
        "Matt Pocock skills submodule is missing; run "
        "'git submodule update --init --recursive' for pinned revisions or "
        "'uv run scripts/update_upstreams.py --no-install' to align with main"
    )

manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
paths = manifest.get("skills")
if not isinstance(paths, list) or not paths:
    raise SystemExit(f"invalid Matt Pocock skill manifest: {manifest_path}")

component = re.compile(r"^[a-z0-9-]+$")
skills_root = (root / "skills").resolve()
seen = set()
for relative in paths:
    if not isinstance(relative, str) or not relative.startswith("./"):
        raise SystemExit(f"unsafe Matt Pocock skill path: {relative!r}")
    parts = PurePosixPath(relative.removeprefix("./")).parts
    if len(parts) < 3 or parts[0] != "skills" or any(
        component.fullmatch(part) is None for part in parts
    ):
        raise SystemExit(f"unsafe Matt Pocock skill path: {relative!r}")
    name = parts[-1]
    if name in seen:
        raise SystemExit(f"duplicate Matt Pocock skill name: {name}")
    seen.add(name)
    skill_dir = root.joinpath(*parts)
    if not skill_dir.resolve().is_relative_to(skills_root):
        raise SystemExit(f"unsafe Matt Pocock skill path: {relative!r}")
    for required in (skill_dir / "SKILL.md", skill_dir / "agents/openai.yaml"):
        if not required.is_file():
            raise SystemExit(f"missing Matt Pocock skill file: {required}")
    print(f"{name}\t{skill_dir}")
PY
}

shared_skill_entries() {
  local source
  local name

  for source in "$ROOT/shared/skills"/*; do
    [ -d "$source" ] || continue
    name="$(basename "$source")"
    printf '%s\t%s\n' "$name" "$source"
  done
  [ -z "$MATT_SKILL_ENTRIES" ] || printf '%s\n' "$MATT_SKILL_ENTRIES"
}

check_skill_collisions() {
  local harness="$1"
  local specific="$ROOT/harnesses/$harness/skills"
  local source
  local name
  local seen_source
  declare -A seen=()

  while IFS=$'\t' read -r name source; do
    [ -n "$name" ] || continue
    if [ "${seen[$name]+present}" = present ]; then
      seen_source="${seen[$name]}"
      printf 'shared skill collision: %s (%s and %s)\n' \
        "$name" "$seen_source" "$source" >&2
      return 1
    fi
    seen[$name]="$source"
    if [ -d "$specific/$name" ]; then
      printf 'skill collision for %s: %s\n' "$harness" "$name" >&2
      return 1
    fi
  done < <(shared_skill_entries)

  if [ "$harness" = claude ]; then
    local external_root="$ROOT/harnesses/claude/upstream/anthropic-skills/skills"
    [ -d "$external_root" ] || {
      printf '%s\n' 'Claude Anthropic skills submodule is missing; run git submodule update --init' >&2
      return 1
    }
    for name in "${ANTHROPIC_ALLOWLIST[@]}"; do
      [ -d "$external_root/$name" ] || {
        printf 'missing allowlisted Anthropic skill: %s\n' "$name" >&2
        return 1
      }
      if [ "${seen[$name]+present}" = present ] || [ -d "$specific/$name" ]; then
        printf 'skill collision for claude: %s\n' "$name" >&2
        return 1
      fi
    done
  fi
}

deploy_shared_hub() {
  local names=()
  local source
  local name

  while IFS=$'\t' read -r name source; do
    [ -n "$name" ] && names+=("$name")
  done < <(shared_skill_entries)

  prune_skill_links shared "$AGENTS_DIR/skills" "${names[@]}"
  while IFS=$'\t' read -r name source; do
    [ -n "$name" ] || continue
    deploy_link shared "$source" "$AGENTS_DIR/skills/$name" "$AGENTS_DIR"
  done < <(shared_skill_entries)
}

deploy_specific_skills() {
  local harness="$1"
  local target_dir="$2"
  local root="$3"
  local mirror_shared="$4"
  local names=()
  local name
  local source

  ensure_directory "$harness" "$target_dir"

  if [ "$mirror_shared" = yes ]; then
    while IFS=$'\t' read -r name source; do
      [ -n "$name" ] && names+=("$name")
    done < <(shared_skill_entries)
  fi
  while IFS= read -r name; do
    [ -n "$name" ] && names+=("$name")
  done < <(directory_names "$ROOT/harnesses/$harness/skills")
  if [ "$harness" = claude ]; then
    names+=("${ANTHROPIC_ALLOWLIST[@]}")
  fi

  prune_skill_links "$harness" "$target_dir" "${names[@]}"

  if [ "$mirror_shared" = yes ]; then
    while IFS=$'\t' read -r name source; do
      [ -n "$name" ] || continue
      deploy_link "$harness" "$source" "$target_dir/$name" "$root"
    done < <(shared_skill_entries)
  fi
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    source="$ROOT/harnesses/$harness/skills/$name"
    deploy_link "$harness" "$source" "$target_dir/$name" "$root"
  done < <(directory_names "$ROOT/harnesses/$harness/skills")
  if [ "$harness" = claude ]; then
    for name in "${ANTHROPIC_ALLOWLIST[@]}"; do
      source="$ROOT/harnesses/claude/upstream/anthropic-skills/skills/$name"
      deploy_link claude "$source" "$target_dir/$name" "$root"
    done
  fi
}

bootstrap_claude_plugins() {
  [ "$MODE" = apply ] || return 0
  [ "${AGENT_CONFIG_SKIP_PLUGINS:-0}" != 1 ] || return 0
  command -v claude >/dev/null 2>&1 || return 0
  "$ROOT/harnesses/claude/scripts/bootstrap-plugins.sh"
}

bootstrap_codex_plugins() {
  [ "$MODE" = apply ] || return 0
  [ "${AGENT_CONFIG_SKIP_PLUGINS:-0}" != 1 ] || return 0
  command -v codex >/dev/null 2>&1 || return 0

  (
    local bootstrap_home
    bootstrap_home="$(mktemp -d)"
    trap 'rm -rf "$bootstrap_home"' EXIT

    mkdir -p "$CODEX_DIR/.tmp" "$CODEX_DIR/plugins"
    ln -s "$CODEX_DIR/.tmp" "$bootstrap_home/.tmp"
    ln -s "$CODEX_DIR/plugins" "$bootstrap_home/plugins"
    cp "$ROOT/harnesses/codex/config.toml" "$bootstrap_home/config.toml"
    export CODEX_HOME="$bootstrap_home"

    codex plugin marketplace upgrade claude-plugins-official >/dev/null
    codex plugin marketplace upgrade ponytail >/dev/null

    local plugin
    while IFS= read -r plugin; do
      [ -n "$plugin" ] || continue
      codex plugin add "$plugin" >/dev/null
    done < <(
      "$PYTHON" - "$ROOT/harnesses/codex/config.toml" <<'PY'
import sys
import tomllib

with open(sys.argv[1], "rb") as config_file:
    config = tomllib.load(config_file)
for name, values in sorted(config.get("plugins", {}).items()):
    if values.get("enabled") is True:
        print(name)
PY
    )
  )
}

validate_windows_relative_path() {
  local relative="$1"

  case "$relative" in
    ""|/*|..|../*|*/..|*/../*)
      printf 'invalid Windows managed path: %s\n' "$relative" >&2
      return 1
      ;;
  esac
}

windows_path_was_managed() {
  local relative="$1"
  local marker

  for marker in \
    "$WINDOWS_CODEX_DIR/.agent-config-managed" \
    "$WINDOWS_CODEX_DIR/.codex-config-managed"; do
    grep -Fxq "$relative" "$marker" 2>/dev/null && return 0
  done
  return 1
}

windows_path_is_desired() {
  local relative="$1"
  local desired

  for desired in "${WINDOWS_MANAGED_PATHS[@]}"; do
    [ "$desired" = "$relative" ] && return 0
  done
  return 1
}

remove_windows_managed_path() {
  local relative="$1"
  local target

  validate_windows_relative_path "$relative"
  target="$WINDOWS_CODEX_DIR/$relative"
  if [ -d "$target" ] && [ ! -L "$target" ]; then
    rm -rf -- "$target"
  else
    rm -f -- "$target"
  fi
}

prepare_windows_replacement() {
  local relative="$1"
  local target="$WINDOWS_CODEX_DIR/$relative"

  [ -e "$target" ] || [ -L "$target" ] || return 0
  if windows_path_was_managed "$relative"; then
    remove_windows_managed_path "$relative"
  else
    backup_existing "$target" "$WINDOWS_CODEX_DIR"
  fi
}

plan_windows_replacement() {
  local relative="$1"
  local target="$WINDOWS_CODEX_DIR/$relative"

  [ -e "$target" ] || [ -L "$target" ] || return 0
  windows_path_was_managed "$relative" && return 0
  plan_backup_existing "$target" "$WINDOWS_CODEX_DIR"
}

deploy_windows_file() {
  local source="$1"
  local relative="$2"
  local required_mode="${3:-644}"
  local target="$WINDOWS_CODEX_DIR/$relative"

  validate_windows_relative_path "$relative"
  WINDOWS_MANAGED_PATHS+=("$relative")
  if [ -f "$target" ] && [ ! -L "$target" ]; then
    if cmp -s "$source" "$target"; then
      return 0
    fi
  fi

  case "$MODE" in
    check) report_drift windows "$target" content ;;
    dry-run)
      plan_windows_replacement "$relative"
      printf 'WOULD COPY %s -> %s\n' "$source" "$target"
      ;;
    apply)
      ensure_parent "$target"
      prepare_windows_replacement "$relative"
      cp "$source" "$target"
      chmod "$required_mode" "$target"
      printf 'COPY %s -> %s\n' "$source" "$target"
      ;;
  esac
}

deploy_windows_tree() {
  local source="$1"
  local relative="$2"
  local target="$WINDOWS_CODEX_DIR/$relative"

  validate_windows_relative_path "$relative"
  WINDOWS_MANAGED_PATHS+=("$relative")
  if [ -d "$target" ] && [ ! -L "$target" ] \
    && diff -qr "$source" "$target" >/dev/null; then
    return 0
  fi

  case "$MODE" in
    check) report_drift windows "$target" content ;;
    dry-run)
      plan_windows_replacement "$relative"
      printf 'WOULD COPY_TREE %s -> %s\n' "$source" "$target"
      ;;
    apply)
      ensure_parent "$target"
      prepare_windows_replacement "$relative"
      cp -a "$source" "$target"
      printf 'COPY_TREE %s -> %s\n' "$source" "$target"
      ;;
  esac
}

reconcile_windows_manifest() {
  local marker="$WINDOWS_CODEX_DIR/.agent-config-managed"
  local legacy_marker="$WINDOWS_CODEX_DIR/.codex-config-managed"
  local desired_file
  local previous_marker
  local relative

  for previous_marker in "$marker" "$legacy_marker"; do
    [ -f "$previous_marker" ] || continue
    while IFS= read -r relative; do
      [ -n "$relative" ] || continue
      validate_windows_relative_path "$relative"
      windows_path_is_desired "$relative" && continue
      [ -e "$WINDOWS_CODEX_DIR/$relative" ] || [ -L "$WINDOWS_CODEX_DIR/$relative" ] || continue
      case "$MODE" in
        check) report_drift windows "$WINDOWS_CODEX_DIR/$relative" stale ;;
        dry-run) printf 'WOULD PRUNE %s\n' "$WINDOWS_CODEX_DIR/$relative" ;;
        apply)
          remove_windows_managed_path "$relative"
          printf 'PRUNE %s\n' "$WINDOWS_CODEX_DIR/$relative"
          ;;
      esac
    done <"$previous_marker"
  done

  desired_file="$(render_temp_for "$marker")"
  printf '%s\n' "${WINDOWS_MANAGED_PATHS[@]}" | sort -u >"$desired_file"
  case "$MODE" in
    check)
      if [ ! -f "$marker" ] || ! cmp -s "$desired_file" "$marker"; then
        report_drift windows "$marker" manifest
      fi
      if [ -e "$legacy_marker" ]; then
        report_drift windows "$legacy_marker" legacy-manifest
      fi
      ;;
    dry-run)
      if [ ! -f "$marker" ] || ! cmp -s "$desired_file" "$marker" || [ -e "$legacy_marker" ]; then
        printf 'WOULD WRITE %s\n' "$marker"
      fi
      if [ -e "$legacy_marker" ] || [ -L "$legacy_marker" ]; then
        printf 'WOULD REMOVE %s\n' "$legacy_marker"
      fi
      ;;
    apply)
      if [ ! -f "$marker" ] || ! cmp -s "$desired_file" "$marker"; then
        ensure_parent "$marker"
        mv "$desired_file" "$marker"
        desired_file=""
        chmod 644 "$marker"
        printf 'WRITE %s\n' "$marker"
      fi
      if [ -e "$legacy_marker" ] || [ -L "$legacy_marker" ]; then
        rm -f "$legacy_marker"
        printf 'REMOVE %s\n' "$legacy_marker"
      fi
      ;;
  esac
  [ -z "$desired_file" ] || rm -f "$desired_file"
}

deploy_windows_core() {
  local name
  local source

  [ -n "$WINDOWS_CODEX_DIR" ] || return 0
  WINDOWS_MANAGED_PATHS=()
  deploy_instructions_windows
  deploy_seed_file windows "$ROOT/harnesses/codex/config.toml" "$WINDOWS_CODEX_DIR/config.toml" "$WINDOWS_CODEX_DIR" 600
  deploy_windows_file "$ROOT/harnesses/codex/hooks.json" hooks.json 644
  deploy_windows_file "$ROOT/harnesses/codex/rules/default.rules" rules/default.rules 644
  deploy_windows_tree "$ROOT/harnesses/codex/scripts" scripts
  deploy_windows_tree "$ROOT/shared/assets" assets
  deploy_windows_tree "$ROOT/harnesses/codex/agents" agents
  while IFS=$'\t' read -r name source; do
    [ -n "$name" ] || continue
    deploy_windows_tree "$source" "skills/$name"
  done < <(shared_skill_entries)
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    deploy_windows_tree "$ROOT/harnesses/codex/skills/$name" "skills/$name"
  done < <(directory_names "$ROOT/harnesses/codex/skills")
  reconcile_windows_manifest
}

deploy_instructions_windows() {
  local rendered
  local target="$WINDOWS_CODEX_DIR/AGENTS.md"

  WINDOWS_MANAGED_PATHS+=(AGENTS.md)
  rendered="$(render_temp_for "$target")"
  render_instructions_to codex "$rendered"
  if [ -f "$target" ] && [ ! -L "$target" ] && cmp -s "$rendered" "$target"; then
    rm -f "$rendered"
    return 0
  fi
  case "$MODE" in
    check)
      report_drift windows "$target" content
      rm -f "$rendered"
      ;;
    dry-run)
      plan_windows_replacement AGENTS.md
      printf 'WOULD RENDER %s\n' "$target"
      rm -f "$rendered"
      ;;
    apply)
      ensure_parent "$target"
      backup_existing "$target" "$WINDOWS_CODEX_DIR"
      mv "$rendered" "$target"
      chmod 644 "$target"
      printf 'RENDER %s\n' "$target"
      ;;
  esac
}

deploy_harness_core() {
  local harness="$1"

  deploy_harness_config "$harness"
  deploy_instructions "$harness"
  case "$harness" in
    claude)
      deploy_specific_skills claude "$CLAUDE_DIR/skills" "$CLAUDE_DIR" yes
      bootstrap_claude_plugins
      ;;
    codex)
      deploy_specific_skills codex "$CODEX_DIR/skills" "$CODEX_DIR" no
      deploy_windows_core
      bootstrap_codex_plugins
      ;;
    kimi)
      deploy_specific_skills kimi "$KIMI_DIR/skills" "$KIMI_DIR" no
      ;;
    opencode)
      deploy_specific_skills opencode "$OPENCODE_DIR/skills" "$OPENCODE_DIR" yes
      ;;
  esac
}

check_runtime_file() {
  local harness="$1"
  local target="$2"
  local format="$3"

  [ -f "$target" ] || return 0
  case "$format" in
    json)
      json_is_valid "$target" || report_drift "$harness" "$target" invalid-json
      ;;
    toml)
      toml_is_valid "$target" || report_drift "$harness" "$target" invalid-toml
      ;;
  esac
}

check_executable_scripts() {
  local harness="$1"
  local directory="$2"
  local script

  [ -e "$directory" ] || [ -L "$directory" ] || return 0
  while IFS= read -r script; do
    [ -n "$script" ] || continue
    report_drift "$harness" "$script" non-executable
  done < <(find -L "$directory" -type f -name '*.sh' ! -perm -u+x -print 2>/dev/null)
}

check_legacy_references() {
  local harness="$1"
  shift
  local file

  while IFS= read -r file; do
    [ -n "$file" ] || continue
    report_drift "$harness" "$file" legacy-reference
  done < <(
    # Also match a literal runtime $HOME.
    # shellcheck disable=SC2016
    grep -RIlE \
      '(~|/home/[^/]+|/Users/[^/]+|\$HOME)/src/(claude-config|codex-config|kimi-config)' \
      -- "$@" 2>/dev/null | sort -u || true
  )
}

check_harness_runtime() {
  local harness="$1"

  case "$harness" in
    claude)
      check_runtime_file claude "$CLAUDE_DIR/settings.json" json
      check_executable_scripts claude "$CLAUDE_DIR/scripts"
      check_legacy_references claude \
        "$CLAUDE_DIR/settings.json" "$CLAUDE_DIR/CLAUDE.md" "$CLAUDE_DIR/scripts"
      ;;
    codex)
      check_runtime_file codex "$CODEX_DIR/config.toml" toml
      check_runtime_file codex "$CODEX_DIR/hooks.json" json
      check_executable_scripts codex "$CODEX_DIR/scripts"
      check_legacy_references codex \
        "$CODEX_DIR/config.toml" "$CODEX_DIR/hooks.json" "$CODEX_DIR/AGENTS.md" "$CODEX_DIR/scripts"
      if [ -n "$WINDOWS_CODEX_DIR" ]; then
        check_runtime_file windows "$WINDOWS_CODEX_DIR/config.toml" toml
        check_runtime_file windows "$WINDOWS_CODEX_DIR/hooks.json" json
        check_legacy_references windows \
          "$WINDOWS_CODEX_DIR/AGENTS.md" \
          "$WINDOWS_CODEX_DIR/hooks.json" \
          "$WINDOWS_CODEX_DIR/scripts" \
          "$WINDOWS_CODEX_DIR/agents" \
          "$WINDOWS_CODEX_DIR/skills"
      fi
      ;;
    kimi)
      check_runtime_file kimi "$KIMI_DIR/config.toml" toml
      check_runtime_file kimi "$KIMI_DIR/tui.toml" toml
      check_runtime_file kimi "$KIMI_DIR/mcp.json" json
      check_executable_scripts kimi "$KIMI_DIR/scripts"
      check_legacy_references kimi \
        "$KIMI_DIR/config.toml" "$KIMI_DIR/AGENTS.md" "$KIMI_DIR/scripts"
      ;;
    opencode)
      check_runtime_file opencode "$OPENCODE_DIR/opencode.json" json
      check_legacy_references opencode \
        "$OPENCODE_DIR/opencode.json" "$OPENCODE_DIR/AGENTS.md"
      ;;
  esac
}

MATT_SKILL_ENTRIES="$(load_matt_skill_entries)"
mapfile -t HARNESSES < <(selected_harnesses)
for harness in "${HARNESSES[@]}"; do
  check_skill_collisions "$harness"
  validate_harness_sources "$harness"
done

for harness in "${HARNESSES[@]}"; do
  case "$harness" in
    codex|kimi)
      deploy_shared_hub
      break
      ;;
  esac
done

for harness in "${HARNESSES[@]}"; do
  deploy_harness_core "$harness"
done

if [ "$MODE" = check ] && [ -e "$AGENTS_DIR/AGENTS.md" ]; then
  report_drift shared "$AGENTS_DIR/AGENTS.md" unexpected
fi

if [ "$MODE" = check ]; then
  for harness in "${HARNESSES[@]}"; do
    check_harness_runtime "$harness"
  done
fi

if [ "$MODE" = check ] && [ "$CHECK_FAILED" -ne 0 ]; then
  exit 1
fi
