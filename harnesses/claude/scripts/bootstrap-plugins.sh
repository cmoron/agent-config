#!/usr/bin/env bash
# bootstrap-plugins.sh : enregistre les marketplaces et installe les plugins listés
# dans enabledPlugins de settings.json. Idempotent (claude plugin add/install
# détectent les ressources déjà présentes).

set -euo pipefail

CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v claude >/dev/null 2>&1; then
    echo "✗ claude CLI introuvable — installer Claude Code d'abord"
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "✗ jq introuvable — apt install jq / brew install jq"
    exit 1
fi

# Marketplaces locales (source "directory") absentes de cette machine : ignorées, leurs plugins aussi.
skipped="$(mktemp)"
trap 'rm -f "$skipped"' EXIT

# 1. Marketplaces déclarées dans settings.json (source unique, y compris l'officielle)
echo "→ Marketplaces"
jq -r '.extraKnownMarketplaces | to_entries[]
    | [.key, .value.source.source, (.value.source.repo // .value.source.path)] | @tsv' \
    "$CONFIG_DIR/settings.json" \
| while IFS="$(printf '\t')" read -r name kind where; do
    if [ "$kind" = "directory" ] && [ ! -d "$where" ]; then
        echo "  ⚠ $name : $where absent sur cette machine, marketplace et plugins ignorés"
        echo "$name" >>"$skipped"
        continue
    fi
    claude plugin marketplace add "$where"
done
echo ""

# 2. Plugins activés dans settings.json
echo "→ Plugins"
jq -r '.enabledPlugins | to_entries[] | select(.value == true) | .key' \
    "$CONFIG_DIR/settings.json" \
| while read -r plugin; do
    if grep -qxF "${plugin##*@}" "$skipped"; then
        continue
    fi
    echo "  → $plugin"
    claude plugin install "$plugin"
done
echo ""

echo "✓ Plugins déployés. Redémarrez Claude Code (ou /reload-plugins)."
