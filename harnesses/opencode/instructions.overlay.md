## OpenCode

### Execution

- Utiliser uniquement les capacites effectivement exposees par OpenCode et son
  provider courant; ne pas supposer la presence de hooks ou de sous-agents.
- Garder les taches XS a M inline. Pour une migration L+, produire un plan puis
  avancer par lots verifies.
- Les instructions globales deployees sont generees. Pour une auto-amelioration
  globale, proposer le diff dans `agent-config/instructions/common.md` ou cet
  overlay, jamais dans `~/.config/opencode/AGENTS.md`.

### Outils

Privilegier `rg`, `fd`, `ast-grep`, `jq` et `yq` lorsqu'ils sont disponibles,
avec lecture ciblee comme fallback. Aucun hook de formatage global n'est suppose
actif : executer les controles declares par chaque projet.
