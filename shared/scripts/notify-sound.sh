#!/usr/bin/env bash
# All harnesses: optional asynchronous audio, no hook payload required.
# Resolve the asset from the deployed entrypoint, not the symlink's source.
set -euo pipefail
SOUND="$(dirname "$0")/../assets/warcraft-3-paysan-travail-termine.mp3"

if [ ! -r "$SOUND" ]; then
  printf 'hook: sound asset unavailable: %s\n' "$SOUND" >&2
  exit 0
fi

# Keep detached players off the hook's pipes without losing their diagnostics.
# This last-run log lives outside the installer-managed scripts/assets trees.
LOG="$(dirname "$0")/../notify-sound.log"
umask 077
: >"$LOG"

if command -v afplay >/dev/null 2>&1; then
  afplay "$SOUND" </dev/null >>"$LOG" 2>&1 &
elif command -v powershell.exe >/dev/null 2>&1 \
  && command -v wslpath >/dev/null 2>&1; then
  WIN_PATH=$(wslpath -w "$SOUND")
  # PowerShell single-quoted literals escape apostrophes by doubling them.
  WIN_PATH=${WIN_PATH//\'/\'\'}
  setsid nohup powershell.exe -NoProfile -Command "
    Add-Type -AssemblyName presentationCore
    \$mp = New-Object System.Windows.Media.MediaPlayer
    \$mp.Open([Uri]'$WIN_PATH')
    \$mp.Play()
    Start-Sleep -Seconds 3
  " </dev/null >>"$LOG" 2>&1 &
elif command -v paplay >/dev/null 2>&1; then
  paplay "$SOUND" </dev/null >>"$LOG" 2>&1 &
elif command -v ffplay >/dev/null 2>&1; then
  ffplay -nodisp -autoexit "$SOUND" </dev/null >>"$LOG" 2>&1 &
else
  printf '\a'
fi
