#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MARKER="${AGENT_CONFIG_ACTIVE_MARKER:-$HOME/.config/agent-config/active}"

usage() {
  printf '%s\n' 'Usage: scripts/cutover-marker.sh activate|deactivate|status'
}

if [ -z "$MARKER" ] || [ "$MARKER" = / ]; then
  printf 'unsafe cutover marker path: %s\n' "$MARKER" >&2
  exit 2
fi

case "${1:-}" in
  activate)
    [ "$#" -eq 1 ] || {
      usage >&2
      exit 2
    }
    if [ -d "$MARKER" ] && [ ! -L "$MARKER" ]; then
      printf 'cutover marker is a directory: %s\n' "$MARKER" >&2
      exit 1
    fi
    mkdir -p "$(dirname "$MARKER")"
    marker_tmp="$(mktemp "${MARKER}.tmp.XXXXXX")"
    printf 'agent-config=%s\n' "$ROOT" >"$marker_tmp"
    chmod 644 "$marker_tmp"
    mv "$marker_tmp" "$MARKER"
    printf 'ACTIVE %s\n' "$MARKER"
    ;;
  deactivate)
    [ "$#" -eq 1 ] || {
      usage >&2
      exit 2
    }
    if [ -d "$MARKER" ] && [ ! -L "$MARKER" ]; then
      printf 'cutover marker is a directory: %s\n' "$MARKER" >&2
      exit 1
    fi
    rm -f -- "$MARKER"
    printf 'INACTIVE %s\n' "$MARKER"
    ;;
  status)
    [ "$#" -eq 1 ] || {
      usage >&2
      exit 2
    }
    if [ -e "$MARKER" ] || [ -L "$MARKER" ]; then
      printf 'ACTIVE %s\n' "$MARKER"
    else
      printf 'INACTIVE %s\n' "$MARKER"
      exit 1
    fi
    ;;
  -h|--help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
