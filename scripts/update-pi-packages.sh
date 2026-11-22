#!/usr/bin/env bash
# Compare chaque paquet epingle a la derniere version publiee.
# Usage : scripts/update-pi-packages.sh           liste les mises a jour disponibles
#         scripts/update-pi-packages.sh --apply   reecrit les epingles dans harnesses/pi/settings.json
#
# Une version npm n'est proposee qu'apres PI_CONFIG_MIN_AGE_DAYS jours (7 par
# defaut) : les extensions tournent avec tous les droits, et ce delai laisse le
# temps a une version compromise d'etre retiree. Les versions de pre-release sont
# ignorees.
# shortcut: pas de delai pour les paquets git, epingles sur le commit du dernier
# tag ; pi lui-meme est seulement signale, sa mise a jour reste manuelle.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SETTINGS="$ROOT/harnesses/pi/settings.json"
MIN_AGE_DAYS="${PI_CONFIG_MIN_AGE_DAYS:-7}"

apply=0
case "${1:-}" in
  "") ;;
  --apply) apply=1 ;;
  *)
    echo "usage: $0 [--apply]" >&2
    exit 2
    ;;
esac

# Derniere version stable publiee depuis au moins MIN_AGE_DAYS jours. Jamais de
# retour en arriere : une epingle plus recente que ce delai est gardee.
npm_candidate() {
  curl -fsS "https://registry.npmjs.org/$1" | jq -r --argjson days "$MIN_AGE_DAYS" --arg current "$2" '
    (now - $days * 86400) as $cutoff
    | .time as $time
    | [$time | to_entries[]
       | select(.key | test("^[0-9]+\\.[0-9]+\\.[0-9]+$"))
       | select((.value | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601) <= $cutoff)]
    | max_by(.value)
    | if . == null or ($time[$current] != null and .value <= $time[$current]) then $current else .key end'
}

# Commit du tag de version le plus eleve.
git_candidate() {
  local url="https://$1" tag
  tag="$(git ls-remote --tags --refs --sort=-v:refname "$url" 'v[0-9]*' | head -1 | sed 's#.*refs/tags/##')"
  [ -n "$tag" ] || return 1
  # Tag annote : le commit est sur la ligne pelee `^{}` ; tag leger : sur la ligne nue.
  git ls-remote "$url" "refs/tags/$tag^{}" "refs/tags/$tag" | sort -k2 -r | head -1 | cut -f1
}

changed=0
new_packages="$(jq -c '.packages' "$SETTINGS")"
while IFS= read -r entry; do
  kind="${entry%%:*}"
  rest="${entry#*:}"
  name="${rest%@*}"
  current="${rest##*@}"
  case "$kind" in
    npm) candidate="$(npm_candidate "$name" "$current")" ;;
    git) candidate="$(git_candidate "$name")" ;;
    *)
      echo "ignore : $entry (source non geree)" >&2
      continue
      ;;
  esac
  if [ -z "$candidate" ]; then
    echo "echec  : $name (aucune version candidate)" >&2
    exit 1
  fi
  if [ "$candidate" = "$current" ]; then
    echo "a jour : $name $current"
    continue
  fi
  echo "maj    : $name $current -> $candidate"
  changed=1
  new_packages="$(jq -c --arg old "$entry" --arg new "$kind:$name@$candidate" 'map(if . == $old then $new else . end)' <<<"$new_packages")"
done < <(jq -r '.packages[]' "$SETTINGS")

if command -v pi >/dev/null; then
  pi_current="$(pi --version 2>/dev/null | tail -1)"
  pi_latest="$(npm_candidate @earendil-works/pi-coding-agent "$pi_current")"
  [ "$pi_latest" = "$pi_current" ] || echo "pi     : $pi_current -> $pi_latest (bun add -g --ignore-scripts @earendil-works/pi-coding-agent@$pi_latest)"
fi

if [ "$changed" = 0 ]; then
  echo "rien a mettre a jour"
elif [ "$apply" = 1 ]; then
  tmp="$(mktemp)"
  jq --argjson packages "$new_packages" '.packages = $packages' "$SETTINGS" >"$tmp"
  cat "$tmp" >"$SETTINGS"
  rm -f "$tmp"
  echo "epingles reecrites. Ensuite : pi update --extensions && ./install.sh --only pi && bash scripts/pi-smoke.sh"
else
  echo "relancer avec --apply pour reecrire les epingles"
fi
