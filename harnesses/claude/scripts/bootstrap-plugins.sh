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

# 1. Marketplaces déclarées dans settings.json (source unique, y compris l'officielle)
echo "→ Marketplaces"
jq -r '.extraKnownMarketplaces[].source.repo' "$CONFIG_DIR/settings.json" \
| while read -r repo; do
    claude plugin marketplace add "$repo"
done
echo ""

# 2. Plugins activés dans settings.json
echo "→ Plugins"
jq -r '.enabledPlugins | to_entries[] | select(.value == true) | .key' \
    "$CONFIG_DIR/settings.json" \
| while read -r plugin; do
    echo "  → $plugin"
    claude plugin install "$plugin"
done
echo ""

echo "✓ Plugins déployés. Redémarrez Claude Code (ou /reload-plugins)."
