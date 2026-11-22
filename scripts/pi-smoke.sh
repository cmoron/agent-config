#!/usr/bin/env bash
# Verification reelle de l'installation deployee : deux appels a un modele
# (Haiku via le bridge), donc du quota. A lancer apres une mise a jour.
# Ne remplace pas tests/test-pi.sh, qui verifie l'installateur sans reseau.
set -euo pipefail

MODEL="${PI_SMOKE_MODEL:-claude-bridge/claude-haiku-5-5}"
# Noms tels que codemode les expose aux scripts (identifiants JavaScript). Les
# outils interactifs comme ask_user_question n'y figurent pas.
EXPECTED_TOOLS="bash read edit write subagent_launch web_search fetch_content todo query_docs resolve_library_id agent_send"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cd "$tmp"
git init -q
echo v1 >f.txt
git add f.txt
git -c user.name=smoke -c user.email=smoke@invalid commit -q -m init
echo modifie >f.txt

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

# Sorties des outils d'un tour, une par ligne : "<outil>\t<erreur>\t<texte>".
# Borne par PI_SMOKE_TIMEOUT : un `pi -p` qui ne rend pas la main a deja ete
# observe une fois (cause non identifiee) ; il doit echouer vite, pas bloquer.
tool_results() {
  local events="$tmp/events.jsonl" waited=0 pid
  pi -p --mode json --no-session --model "$MODEL" "$1" >"$events" 2>/dev/null &
  pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$waited" -ge "${PI_SMOKE_TIMEOUT:-120}" ]; then
      kill "$pid" 2>/dev/null || true
      fail "pi n'a pas rendu la main en ${waited}s"
    fi
    sleep 1
    waited=$((waited + 1))
  done
  jq -r 'select(.type == "tool_execution_end")
         | [.toolName, (.isError | tostring), ([.result.content[]?.text] | join(" "))] | @tsv' "$events"
}

# 1. Les outils attendus sont charges. codemode les enumere sans passer par ce
#    que le modele croit savoir de lui-meme.
listing="$(tool_results 'Call the codemode tool exactly once with this script and nothing else: return ALL_TOOLS.map((t) => t.name).join(",")')"
names="$(printf '%s\n' "$listing" | awk -F'\t' '$1 == "codemode" { print $3 }' | sed 's/\\n/,/g' | tr -d ' ')"
[ -n "$names" ] || fail "codemode n'a rien renvoye : $listing"
for tool in $EXPECTED_TOOLS; do
  printf '%s' "$names" | tr ',' '\n' | grep -qx -- "$tool" || fail "outil absent : $tool"
done
echo "ok : outils charges"

# 2. Le garde-fou bloque une commande destructrice, et le fichier survit.
blocked="$(tool_results 'Run exactly this bash command and report its raw output, do not try alternatives: git reset --hard HEAD')"
printf '%s\n' "$blocked" | grep -q "BLOCKED by CC Safety Net" || fail "git reset --hard non bloque : $blocked"
[ "$(cat f.txt)" = "modifie" ] || fail "le fichier a ete ecrase"
echo "ok : garde-fou actif"

echo "OK"
