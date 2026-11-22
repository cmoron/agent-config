## OpenCode

### Modèles

- Principal : le modèle de session.
- Exécutant : sous-agent `general`. Mécanique : sous-agent `explore`.
- Relecteur : `general` en contexte neuf.
- Pas de hooks shell en 2.x.

### Outils

`rg`, `fd`, `ast-grep`, `jq` et `yq` quand ils sont disponibles, lecture
ciblée sinon. Les formateurs natifs ne tournent que si le projet les fournit.
