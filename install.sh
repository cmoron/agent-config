#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE=apply
ONLY=""
CHECK_FAILED=0
BACKUP_STAMP="$(date +%Y%m%d-%H%M%S)"

CLAUDE_DIR="${AGENT_CONFIG_CLAUDE_DIR:-$HOME/.claude}"
CODEX_DIR="${AGENT_CONFIG_CODEX_DIR:-$HOME/.codex}"
KIMI_DIR="${AGENT_CONFIG_KIMI_DIR:-$HOME/.kimi-code}"
OPENCODE_DIR="${AGENT_CONFIG_OPENCODE_DIR:-$HOME/.config/opencode}"
AGENTS_DIR="${AGENT_CONFIG_AGENTS_DIR:-$HOME/.agents}"

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
  /home/cyril/src/claude-config
  /home/cyril/src/codex-config
  /home/cyril/src/kimi-config
)

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

ensure_parent() {
  local target="$1"

  if [ "$MODE" = apply ]; then
    mkdir -p "$(dirname "$target")"
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
    dry-run) printf 'WOULD MKDIR %s\n' "$target" ;;
    apply)
      if [ -e "$target" ] || [ -L "$target" ]; then
        backup_existing "$target" "$(runtime_root_for "$harness")"
      fi
      mkdir -p "$target"
      printf 'MKDIR %s\n' "$target"
      ;;
  esac
}

backup_existing() {
  local target="$1"
  local root="$2"
  local relative
  local backup

  [ -e "$target" ] || [ -L "$target" ] || return 0
  if managed_link "$target"; then
    rm -f "$target"
    return 0
  fi

  relative="${target#"$root"/}"
  if [ "$relative" = "$target" ]; then
    relative="$(basename "$target")"
  fi
  backup="$root/backups/$BACKUP_STAMP/$relative"
  mkdir -p "$(dirname "$backup")"
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

copy_tree() {
  local harness="$1"
  local source="$2"
  local target="$3"
  local root="$4"

  if [ -d "$target" ] && [ ! -L "$target" ] && diff -qr "$source" "$target" >/dev/null; then
    return 0
  fi

  case "$MODE" in
    check)
      report_drift "$harness" "$target" content
      ;;
    dry-run)
      printf 'WOULD COPY_TREE %s -> %s\n' "$source" "$target"
      ;;
    apply)
      ensure_parent "$target"
      backup_existing "$target" "$root"
      cp -a "$source" "$target"
      printf 'COPY_TREE %s -> %s\n' "$source" "$target"
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
  rendered="$(mktemp)"
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

check_skill_collisions() {
  local harness="$1"
  local specific="$ROOT/harnesses/$harness/skills"
  local shared
  local name

  for shared in "$ROOT/shared/skills"/*; do
    [ -d "$shared" ] || continue
    name="$(basename "$shared")"
    if [ -d "$specific/$name" ]; then
      printf 'skill collision for %s: %s\n' "$harness" "$name" >&2
      return 1
    fi
  done
}

deploy_shared_hub() {
  local harness="$1"
  local names=()
  local source
  local name

  while IFS= read -r name; do
    [ -n "$name" ] && names+=("$name")
  done < <(directory_names "$ROOT/shared/skills")

  prune_skill_links shared "$AGENTS_DIR/skills" "${names[@]}"
  for name in "${names[@]}"; do
    source="$ROOT/shared/skills/$name"
    deploy_link shared "$source" "$AGENTS_DIR/skills/$name" "$AGENTS_DIR"
  done
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
    while IFS= read -r name; do
      [ -n "$name" ] && names+=("$name")
    done < <(directory_names "$ROOT/shared/skills")
  fi
  while IFS= read -r name; do
    [ -n "$name" ] && names+=("$name")
  done < <(directory_names "$ROOT/harnesses/$harness/skills")

  prune_skill_links "$harness" "$target_dir" "${names[@]}"

  if [ "$mirror_shared" = yes ]; then
    while IFS= read -r name; do
      [ -n "$name" ] || continue
      deploy_link "$harness" "$ROOT/shared/skills/$name" "$target_dir/$name" "$root"
    done < <(directory_names "$ROOT/shared/skills")
  fi
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    source="$ROOT/harnesses/$harness/skills/$name"
    deploy_link "$harness" "$source" "$target_dir/$name" "$root"
  done < <(directory_names "$ROOT/harnesses/$harness/skills")
}

deploy_windows_core() {
  local name

  [ -n "$WINDOWS_CODEX_DIR" ] || return 0
  deploy_instructions_windows
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    copy_tree windows "$ROOT/shared/skills/$name" "$WINDOWS_CODEX_DIR/skills/$name" "$WINDOWS_CODEX_DIR"
  done < <(directory_names "$ROOT/shared/skills")
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    copy_tree windows "$ROOT/harnesses/codex/skills/$name" "$WINDOWS_CODEX_DIR/skills/$name" "$WINDOWS_CODEX_DIR"
  done < <(directory_names "$ROOT/harnesses/codex/skills")
}

deploy_instructions_windows() {
  local rendered
  local target="$WINDOWS_CODEX_DIR/AGENTS.md"

  rendered="$(mktemp)"
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

  deploy_instructions "$harness"
  case "$harness" in
    claude)
      deploy_specific_skills claude "$CLAUDE_DIR/skills" "$CLAUDE_DIR" yes
      ;;
    codex)
      deploy_shared_hub codex
      deploy_specific_skills codex "$CODEX_DIR/skills" "$CODEX_DIR" no
      deploy_windows_core
      ;;
    kimi)
      deploy_shared_hub kimi
      deploy_specific_skills kimi "$KIMI_DIR/skills" "$KIMI_DIR" no
      ;;
    opencode)
      deploy_shared_hub opencode
      deploy_specific_skills opencode "$OPENCODE_DIR/skills" "$OPENCODE_DIR" no
      ;;
  esac
}

mapfile -t HARNESSES < <(selected_harnesses)
for harness in "${HARNESSES[@]}"; do
  check_skill_collisions "$harness"
done

for harness in "${HARNESSES[@]}"; do
  deploy_harness_core "$harness"
done

if [ "$MODE" = check ] && [ -e "$AGENTS_DIR/AGENTS.md" ]; then
  report_drift shared "$AGENTS_DIR/AGENTS.md" unexpected
fi

if [ "$MODE" = check ] && [ "$CHECK_FAILED" -ne 0 ]; then
  exit 1
fi
