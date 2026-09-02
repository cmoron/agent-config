## Claude Code

### Planification et delegation

- Utiliser `superpowers:brainstorming` lorsqu'une tache M contient une vraie
  decision de design; sinon rester inline.
- Pour une tache L+, utiliser `superpowers:writing-plans`. Ne lancer
  `superpowers:subagent-driven-development` qu'apres chiffrage et confirmation
  explicite si l'estimation reste sous huit heures.
- Garder l'orchestration, les arbitrages et le debug difficile dans le modele
  principal. Deleguer le volume mecanique a Haiku, une implementation bien
  specifiee a Sonnet et un sous-probleme complexe a Opus. Fable est une escalade
  ponctuelle si Opus bloque.
- XS et S restent inline; deterministic signifie script ou commande, sans
  modele.

### Outils

| Besoin | Preference | Fallback |
| --- | --- | --- |
| Recherche contenu | `rg` | Grep integre |
| Recherche structure | `ast-grep` / `sg` | lecture ciblee |
| Recherche fichiers | `fd` | Glob integre |
| Gros fichier inconnu | sous-agent `Explore` | lecture par sections |
| Web | WebSearch | source officielle directe |
| Documentation de bibliotheque | `context7` | WebSearch ciblee |
| JSON/YAML | `jq` / `yq` | parseur structure |

Une sortie tronquee ou accompagnee d'un avertissement ne prouve rien. Relancer
avec la commande brute avant de conclure.

### Contexte et memoire

- `/clear` entre deux taches sans lien et `/compact Keep: ...` avant saturation.
- Pour un gros perimetre, utiliser `Explore`, puis garder un resume cible dans le
  contexte principal.
- La memoire native vit sous `~/.claude/projects/<repo>/memory/`.
- Les instructions globales deployees sont generees. Pour une auto-amelioration
  globale, proposer le diff dans `agent-config/instructions/common.md` ou cet
  overlay, jamais dans `~/.claude/CLAUDE.md`.

### RTK

Le hook PreToolUse reecrit automatiquement les commandes supportees lorsque
`rtk` est installe.

```bash
rtk read <file>
rtk err <command>
rtk log <file>
rtk json <file>
rtk summary <command>
rtk gain
rtk gain --history
rtk discover
rtk proxy <command>
rtk hook check "<command>"
```

Utiliser `rtk proxy` lorsqu'un programme exige les bytes exacts, par exemple
pour appliquer un patch ou calculer un checksum. Ne pas relancer `rtk init` :
il ecrit dans la config generee par agent-config, qui l'ecraserait.

Le Stop hook `scripts/reflect-nudge.sh` rappelle l'auto-amelioration une fois par
session si du travail a eu lieu.
