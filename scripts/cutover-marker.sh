#!/usr/bin/env bash

# Active/desactive le verrou des anciens installateurs, sans deployer de config.
# Usage : scripts/cutover-marker.sh activate|deactivate|status
# Marqueur : AGENT_CONFIG_ACTIVE_MARKER, sinon ~/.config/agent-config/active.
# Sa presence bloque les scripts qui chargent legacy-installer-guard.sh ; son
# contenu indique le depot d'origine mais n'est pas interprete par le garde.
# stdout : ACTIVE/INACTIVE et chemin ; stderr : erreurs d'usage ou d'ecriture.
# Codes : 0 succes, 1 statut inactif ou marqueur repertoire, 2 usage invalide
# ou chemin dangereux ; les erreurs des utilitaires conservent leur code.
# deactivate retire seulement le verrou : il ne restaure aucune configuration.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MARKER="${AGENT_CONFIG_ACTIVE_MARKER:-$HOME/.config/agent-config/active}"

# Affiche la syntaxe sur stdout ; l'appelant redirige vers stderr si necessaire.
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
    # Ecrire a cote puis renommer pour ne jamais exposer un marqueur incomplet.
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
