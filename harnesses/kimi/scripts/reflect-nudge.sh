#!/usr/bin/env bash
# Hook Stop (kimi-code) : backstop d'auto-amélioration (cf. AGENTS.md § Auto-amélioration).
# Une fois par session, et seulement si du travail réel a eu lieu (working tree
# git modifié), bloque le Stop avec un rappel : PROPOSER — en diff, jamais en
# commit auto — un skill neuf ou l'évolution d'un skill quand un pattern
# récurrent a émergé.
# Reçoit du JSON sur stdin : hook_event_name, session_id, cwd.
# Dégrade en no-op (exit 0) à la moindre incertitude : ne bloque jamais à tort.

set -euo pipefail

INPUT=$(cat)

# Parse en un appel ; délimiteur tab (un cwd peut contenir des espaces).
PARSED=$(printf '%s' "$INPUT" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    d = {}
print('\t'.join([
    str(d.get('session_id', '')),
    str(d.get('cwd', '')),
]))
" 2>/dev/null || printf '\t')

IFS=$'\t' read -r SESSION CWD <<<"$PARSED" || true

[ -n "${SESSION:-}" ] || exit 0
[ -n "${CWD:-}" ] || CWD="$PWD"

# Une seule fois par session.
MARKER="${TMPDIR:-/tmp}/kimi-reflect-${SESSION}"
[ -e "$MARKER" ] && exit 0

# Ne déclenche que si du travail réel a eu lieu (working tree modifié).
git -C "$CWD" rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
[ -n "$(git -C "$CWD" status --porcelain 2>/dev/null)" ] || exit 0

# Marque AVANT de bloquer : ne nudge qu'une fois quoi qu'il arrive ensuite
# (le marker casse la boucle Stop → blocage → Stop).
: > "$MARKER"

# exit 2 = blocage du Stop : stderr est renvoyé au modèle, qui enchaîne un tour.
cat >&2 <<'EOF'
🔁 Backstop auto-amélioration (1×/session, cf. AGENTS.md § Auto-amélioration).
- Une procédure répétée (≥2-3×) ou une correction récurrente a-t-elle émergé cette session ? Si OUI → propose EN DIFF un skill neuf ou l'évolution d'un skill existant (jamais de commit auto ; revue avant écriture).
- Sinon (mid-tâche ou rien à cristalliser) → dis-le en une ligne et termine.
EOF
exit 2
