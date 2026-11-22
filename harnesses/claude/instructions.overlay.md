## Claude Code

### Modèles

- Principal : Fable par défaut.
- Exécutant : Opus. Relecteur : agent `relecteur` (Opus, lecture seule).
- Mécanique : Sonnet, Haiku pour le volume pur.
- XS et S : inline, sans sous-agent.
- Bug dans du code étranger, test instable, changement de schéma : proposer
  `/effort high`.

### Outils

`ast-grep`/`sg` pour la structure, `fd` pour les fichiers, `jq`/`yq` pour
JSON/YAML.

Sortie tronquée ou accompagnée d'un avertissement : elle ne prouve rien.
Relancer la commande brute avant de conclure.
