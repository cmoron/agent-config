#!/usr/bin/env bash
# statusLine de Claude Code : modele, contexte, branche, depot, forfait.
# Ne lit que le JSON de stdin, jamais le transcript : ccstatusline relisait tout le
# transcript a chaque affichage (1,3 Go et 2,3 s sur 311 Mo, 01/11/2026).

exec python3 -I -c '
import json
import os
import subprocess
import sys
import time

try:
    d = json.load(sys.stdin)
except ValueError:
    print("statusline: JSON illisible")
    sys.exit(0)

parts = ["\033[38;5;11m" + ((d.get("model") or {}).get("display_name") or "?") + "\033[0m"]

ctx = d.get("context_window") or {}
tokens, pct = ctx.get("total_input_tokens"), ctx.get("used_percentage")
if isinstance(tokens, (int, float)):
    parts.append("Ctx: %.1fk" % (tokens / 1000) + (" (%.0f%%)" % pct if isinstance(pct, (int, float)) else ""))

ws = d.get("workspace") or {}
cwd = ws.get("current_dir") or d.get("cwd")
if cwd:
    try:
        git = subprocess.run(
            ["git", "-C", cwd, "rev-parse", "--show-toplevel", "--abbrev-ref", "HEAD"],
            capture_output=True, text=True, timeout=1,
        ).stdout.split()
    except (OSError, subprocess.TimeoutExpired):
        git = []  # pas de git ou depot lent : la barre se passe de branche
    if len(git) == 2:
        parts += ["⎇ " + git[1], os.path.basename(git[0])]
    else:
        parts.append(os.path.basename(ws.get("project_dir") or cwd))

limits = d.get("rate_limits") or {}
for key, label in (("five_hour", "5h"), ("seven_day", "7j")):
    window = limits.get(key) or {}
    used = window.get("used_percentage")
    if not isinstance(used, (int, float)):
        continue
    text = "%s %.0f%%" % (label, used)
    resets = window.get("resets_at")
    if key == "five_hour" and isinstance(resets, (int, float)):
        left = max(0, int(resets - time.time()))
        text += " (%dh%02d)" % (left // 3600, left % 3600 // 60)
    parts.append(text)

print("\U0001f47f " + " | ".join(parts))
'
