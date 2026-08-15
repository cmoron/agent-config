---
name: agent-config
description: Use when modifying Cyril's shared Claude Code, Codex, Kimi Code, or OpenCode configuration in ~/src/agent-config.
---

# Agent Config - Codex

`~/src/agent-config` est l'unique source declarative. Ne pas maintenir
directement `~/.claude`, `~/.codex`, `~/.kimi-code`, `~/.agents` ou
`~/.config/opencode`.

## Placement

- `instructions/common.md` : comportement reellement commun.
- `harnesses/<name>/instructions.overlay.md` : capacites propres au harness.
- `shared/skills` et `shared/assets` : artefacts portables.
- `harnesses/codex` : config, hooks, agents, rules, scripts et skills Codex.
- Les fichiers globaux deployes sont generes; ne jamais editer
  `~/.codex/AGENTS.md`.

## Workflow

1. Lire `docs/deployment-inventory.md` et les sources concernees.
2. Modifier le minimum dans ce depot.
3. Ecrire le test qui fixe le contrat, puis observer son echec.
4. Implementer et lancer `bash tests/run-all.sh`.
5. Utiliser `./install.sh --dry-run`, puis `--check`.
6. Demander une validation explicite avant le premier deploiement reel.

## Codex

- Les skills partages vivent uniquement sous `~/.agents/skills`; ne pas les
  dupliquer dans `~/.codex/skills` sous Linux.
- `config.toml` est copie en preservant `[hooks.state]`.
- Les hooks referencent les scripts deployes sous `~/.codex/scripts`.
- La cible Windows recoit de vrais fichiers. Son `config.toml` existant est
  app-owned et reste byte-identique.
- Une auto-amelioration globale cible `instructions/common.md` ou l'overlay
  Codex, pas le fichier genere.

Tout ajout/retrait de skill, hook, plugin, MCP ou cible de copie met a jour dans
le meme commit `README.md`, l'inventaire et les tests correspondants.
