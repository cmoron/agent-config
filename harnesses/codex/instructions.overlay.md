## Codex

### Modeles et effort

- Defaut : `gpt-5.6-sol` a effort `xhigh` pour l'orchestration, l'architecture,
  les demandes ambigues et les implementations critiques.
- `terra` a effort `high` convient aux implementations bornees, non critiques
  et clairement specifiees.
- `luna` a effort `high` convient a l'exploration read-only et au volume
  mecanique.
- `max` est une escalade ponctuelle pour un probleme profond et indivisible.
- `super-joker` utilise Sol `ultra` uniquement apres un blocage concret et pour
  un fan-out borne.

### Delegation

- XS : direct. Une S bornee et non critique peut etre confiee a `worker` si le
  brief suffit.
- Une implementation critique reste dans l'agent principal ou utilise
  `critical`; une exploration read-only bornee utilise `explore`.
- Ne paralleliser que des taches independantes et ne jamais faire modifier les
  memes fichiers par plusieurs agents.
- L'agent principal arbitre l'architecture, integre et verifie.
- `fast_mode` reste desactive. Deterministe signifie script ou commande sans
  modele.

### Outils

| Besoin                         | Preference                  | Fallback                  |
| ------------------------------ | --------------------------- | ------------------------- |
| Recherche contenu              | `rg`                        | recherche integree        |
| Recherche structure            | `ast-grep` / `sg`           | lecture ciblee            |
| Recherche fichiers             | `fd`                        | `rg --files`              |
| Gros fichier inconnu           | lecture ciblee par sections | `rtk read`                |
| Web                            | recherche web ciblee        | source officielle directe |
| Documentation de bibliotheque  | `context7`                  | source officielle         |
| JSON/YAML                      | `jq` / `yq`                 | parseur structure         |
| Application Windows depuis WSL | skill `wsl-windows-gui`     | PowerShell/UI Automation  |

### RTK

Le hook PreToolUse `scripts/rtk-codex-hook.sh` reecrit automatiquement les
commandes supportees. Pour les bytes exacts, utiliser `rtk proxy <cmd>` ou une
sortie fichier. Utiliser directement `rtk read`, `rtk err`, `rtk log`,
`rtk json` ou `rtk summary` lorsque leur sortie filtree suffit. Ne pas relancer
`rtk init` : il ecrit dans la config generee par agent-config, qui l'ecraserait.

### Contexte et memoire

- `/clear` entre deux taches sans lien et `/compact Keep: ...` avant saturation.
- La memoire native Codex vit sous `~/.codex/memories`.
- Les instructions globales deployees sont generees. Pour une auto-amelioration
  globale, proposer le diff dans `agent-config/instructions/common.md` ou cet
  overlay, jamais dans `~/.codex/AGENTS.md`.

Codex n'a pas de Stop hook de rappel : faire le point d'auto-amelioration aux
frontieres de tache.
