#!/usr/bin/env bash

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
