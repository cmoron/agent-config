## Kimi Code

### Planification et delegation

- Pour une tache M qui necessite un arbitrage, utiliser le mode Plan puis
  executer inline apres validation.
- Pour une tache L+, suivre le Workflow commun et chiffrer la delegation.
  Utiliser seulement les capacites exposees; `/goal` sur demande explicite.
- Le modele principal garde architecture, arbitrages et debug difficile.
  Utiliser `explore` pour la lecture, ou `coder` sur le modele secondaire pour
  un travail mecanique lorsqu'il est configure.
- Le modele secondaire est experimental. S'il manque, les sous-agents heritent
  du modele principal.

### Outils

| Besoin               | Preference           | Fallback                  |
| -------------------- | -------------------- | ------------------------- |
| Recherche contenu    | `rg`                 | Grep integre              |
| Recherche structure  | `ast-grep` / `sg`    | lecture ciblee            |
| Recherche fichiers   | `fd`                 | Glob integre              |
| Gros fichier inconnu | sous-agent `explore` | lecture par sections      |
| Web                  | WebSearch / FetchURL | source officielle directe |
| JSON/YAML            | `jq` / `yq`          | parseur structure         |
| Sortie verbeuse      | `rtk` explicite      | commande directe          |

### RTK

Kimi n'a pas de hook RTK automatique. Utiliser explicitement `rtk read`,
`rtk err`, `rtk log`, `rtk json`, `rtk summary` ou `rtk proxy`. Si `rtk gain`
echoue, verifier qu'il ne s'agit pas du binaire Rust Type Kit homonyme.

### Contexte et memoire

- `/new` entre deux taches sans lien et `/compact <ce qui compte>` avant
  saturation.
- Kimi n'a pas de memoire native durable; cristalliser ce qui doit survivre dans
  les skills ou les instructions source.
- Les instructions globales deployees sont generees. Pour une auto-amelioration
  globale, proposer le diff dans `agent-config/instructions/common.md` ou cet
  overlay, jamais dans `~/.kimi-code/AGENTS.md`.

Le Stop hook `scripts/reflect-nudge.sh` rappelle l'auto-amelioration une fois par
session si du travail a eu lieu.
