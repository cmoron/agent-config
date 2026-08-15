---
name: agent-config
description: Use when modifying Cyril's shared Claude Code, Codex, Kimi Code, or OpenCode configuration in ~/src/agent-config.
---

# Agent Config - Claude Code

`~/src/agent-config` est l'unique source declarative. Ne pas maintenir
directement `~/.claude`, `~/.codex`, `~/.kimi-code`, `~/.agents` ou
`~/.config/opencode`.

## Placement

- `instructions/common.md` : comportement reellement commun.
- `harnesses/<name>/instructions.overlay.md` : capacites propres au harness.
- `shared/skills` et `shared/assets` : artefacts portables.
- `harnesses/claude` : settings, hooks, commands, skills et ccstatusline Claude.
- Les fichiers globaux deployes sont generes; ne jamais editer
  `~/.claude/CLAUDE.md`.

## Workflow

1. Lire `docs/deployment-inventory.md` et les sources concernees.
2. Modifier le minimum dans ce depot.
3. Ajouter ou ajuster le test du contrat de deploiement.
4. Tester sous home temporaire avec `bash tests/run-all.sh`.
5. Utiliser `./install.sh --dry-run`, puis `--check`.
6. Demander une validation explicite avant le premier deploiement reel.

## Claude Code

- Les skills partages sont miroires dans `~/.claude/skills`; Claude ne lit pas
  le hub directement.
- `settings.json` est fusionne car Claude le reecrit. Les cles declaratives
  restent source-owned; les cles runtime inconnues sont preservees.
- Les hooks referencent `~/.claude/scripts`, jamais le chemin du depot.
- Les huit skills Anthropic allowlistes restent un submodule Claude-only.
- Une auto-amelioration globale cible `instructions/common.md` ou l'overlay
  Claude, pas le fichier genere.

Tout ajout/retrait de skill, hook, plugin, MCP ou cible de copie met a jour dans
le meme commit `README.md`, l'inventaire et les tests correspondants.
