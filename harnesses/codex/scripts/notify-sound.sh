#!/usr/bin/env bash
# Plays the Warcraft 3 "travail termine" sound.
# Compatible with macOS, WSL2 and terminal bell fallback.

set -euo pipefail

SOUND="$HOME/.codex/assets/warcraft-3-paysan-travail-termine.mp3"

if [[ "$(uname -s)" == "Darwin" ]]; then
  afplay "$SOUND" &
elif command -v powershell.exe >/dev/null 2>&1; then
  WIN_PATH="$(wslpath -w "$SOUND")"
  setsid nohup powershell.exe -NoProfile -Command "
    Add-Type -AssemblyName presentationCore
    \$mp = New-Object System.Windows.Media.MediaPlayer
    \$mp.Open([Uri]'$WIN_PATH')
    \$mp.Play()
    Start-Sleep -Seconds 3
  " >/dev/null 2>&1 &
elif command -v paplay >/dev/null 2>&1; then
  paplay "$SOUND" >/dev/null 2>&1 &
elif command -v ffplay >/dev/null 2>&1; then
  ffplay -nodisp -autoexit "$SOUND" >/dev/null 2>&1 &
else
  printf '\a'
fi

exit 0
