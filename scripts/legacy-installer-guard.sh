#!/usr/bin/env bash

# Garde en lecture seule a charger AVANT toute mutation d'un ancien installateur :
# source "$HOME/src/agent-config/scripts/legacy-installer-guard.sh" || exit $?
# Consulte AGENT_CONFIG_ACTIVE_MARKER, sinon ~/.config/agent-config/active.
# Sa presence suffit, meme pour un lien casse ; son contenu n'est pas lu.
# Marqueur absent : succes (0), aucune sortie. Present : diagnostic sur stderr
# et return 78 si source, exit 78 si execute. N'installe ni ne restaure rien.
# Les anciens scripts qui ne chargent pas ce garde ne sont pas proteges.
# Pas de set -e/-u : un fichier source ne doit pas changer les options du shell.

marker="${AGENT_CONFIG_ACTIVE_MARKER:-$HOME/.config/agent-config/active}"

if [ -e "$marker" ] || [ -L "$marker" ]; then
  printf '%s\n' \
    'legacy installer disabled: agent-config is active; deactivate the cutover marker before rollback' \
    >&2
  if [ "${BASH_SOURCE[0]}" != "$0" ]; then
    return 78
  fi
  exit 78
fi
