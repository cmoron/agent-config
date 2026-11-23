## Codex

### Modèles

- Principal : `gpt-6.2-sol` à effort `xhigh` par défaut. Astra uniquement sur
  demande.
- Exécutant : `terra` à effort `high`, agent `worker`.
- Mécanique : `luna` à effort `high`, agent `explore`.
- Relecteur : agent `relecteur`. Implémentation critique : agent `critical`.
- Effort `max` : escalade ponctuelle pour un problème profond et indivisible.
  `super-joker` (Sol `ultra`) : uniquement après un blocage concret, pour un
  fan-out borné.
- `fast_mode` reste désactivé.
- Superpowers est installé pour tous les projets : hors flow `superpowers`,
  ignorer ses skills.

### Délégation

- Toujours passer `fork_turns="none"` avec un brief autonome : objectif,
  fichiers possédés, contraintes, contrôles, résultat attendu. Historique
  partagé : exception motivée, avec le minimum de tours utile.
- Recherche autonome sur plusieurs fichiers : `explore`. Lectures nécessaires à
  l'arbitrage et à l'intégration : agent principal. Réutiliser les conclusions
  sourcées, sauf contradiction ou changement du code concerné.
- Une mission = un lot. Même lot : même agent. Périmètre changé : brief neuf.
  Revue relancée sur les seuls points modifiés.

### Outils

`ast-grep`/`sg` pour la structure, `fd` pour les fichiers, `context7` pour la
documentation de bibliothèque, `jq`/`yq` pour JSON/YAML, et le skill
`wsl-windows-gui` pour une application Windows depuis WSL.

### Contexte et mémoire

- À chaque frontière de lot : faire le point sur le contexte et la consommation
  disponible, tokens en cache et hors cache. Résumer les sorties volumineuses
  par script.
- Préparer un relais court (décisions, fichiers, preuves, reste à faire) avant
  `/compact Keep: ...` ou un nouveau fil. Annoncer un compactage seulement une
  fois exécuté.
- Mémoire native : `~/.codex/memories`.
