---
name: codex-config
description: Modifier la configuration Codex personnelle de Cyril dans ~/src/codex-config, puis redeployer via install.sh. Utiliser pour AGENTS.md, config.toml, skills, rules et scripts Codex.
---

# Codex Config — ~/src/codex-config

Ce repo centralise la configuration personnelle Codex. Modifier la source ici,
jamais directement dans `~/.codex`.

## Structure

```text
~/src/codex-config/
├── AGENTS.md              # Instructions propres a ce repo
├── global/AGENTS.md       # Instructions globales deployees dans ~/.codex/AGENTS.md
├── config.toml            # Modele, sandbox, TUI, plugins, MCPs
├── agents/                # Custom agents (modele/effort pinnes par sous-agent)
├── rules/default.rules    # Regles persistantes d'approbation
├── skills/                # Skills personnels Codex
├── scripts/               # Helpers de notification
├── assets/                # Assets utilitaires
├── install.sh             # Symlinks WSL + copies Windows idempotents
└── update.sh              # Pull fast-forward + install
```

## Workflow

1. Lire les fichiers existants avant modification.
2. Garder les changements scopes a la demande.
3. Ne pas ajouter de plugin ou MCP sans demande explicite.
4. Relancer `./install.sh` apres modification pour remettre les symlinks/copies en place.
5. Verifier avec au minimum `bash -n install.sh update.sh scripts/*.sh`.
6. Si un skill est ajoute/supprime/renomme, tenir `global/AGENTS.md` et `README.md`
   synchronises.

## Hooks — pièges et débogage

- Côté hooks, le tool shell s'appelle `Bash` (matcher `^Bash$`), payload stdin
  compatible Claude (`{tool_input: {command}}`). Mais la REPONSE diffère :
  Codex n'applique `updatedInput` que si `permissionDecision: "allow"` est
  présent — le schéma Claude seul donne `hook: PreToolUse Failed` et la
  commande originale part telle quelle (cf. `scripts/rtk-codex-hook.sh`).
- `hook: … Failed` ne dit pas pourquoi. Trois causes à discriminer : sortie
  au mauvais schéma, trust périmé (toute modif de la définition dans
  `hooks.json` invalide le hash → re-trust via `/hooks`), ou hook qui pend.
- Débogage sans brûler le quota : CODEX_HOME jetable + hook de capture, puis
  `codex exec --skip-git-repo-check --dangerously-bypass-hook-trust \
   -c model=gpt-5.6-luna -c model_reasoning_effort=low '...'` (~4k tokens).
  Le hook de capture (`cat` du stdin vers un fichier) donne payload et
  tool_name exacts ; le rollout dans `$CODEX_HOME/sessions/` prouve si la
  réécriture a été appliquée.

## Conventions

- Instructions globales en francais, concises et actionnables.
- Preferer ASCII dans les fichiers de config sauf besoin explicite.
- Conventional commits.
- Ne jamais modifier ou supprimer les skills systeme dans `~/.codex/skills/.system`.
- `install.sh` purge les symlinks de skills geres par ce repo qui ont disparu de
  la source; ne pas contourner ce deploiement declaratif.
- Sous WSL2, `install.sh` copie aussi les fichiers geres vers
  `/mnt/c/Users/$USER/.codex` si ce dossier existe. Ne pas symlinker cette cible :
  l'application Windows doit lire des fichiers reels. Son `config.toml` est
  preserve s'il existe, car l'application native y ajoute des sections runtime,
  desktop, plugins Chrome et Computer Use.
