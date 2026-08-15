# agent-config

Configuration personnelle multi-harness pour Claude Code, Codex, Kimi Code et
OpenCode.

Le depot est en cours de migration. Les anciens depots restent autoritatifs
tant que la bascule reelle n'a pas ete explicitement validee. Les premiers lots
sont verifies uniquement sous homes temporaires.

## Principes

- `shared/` contient uniquement les artefacts reellement portables.
- `harnesses/<name>/` contient les configurations et adaptations natives.
- Les instructions sont rendues depuis `instructions/common.md` et un overlay.
- `~/.agents` est reserve au hub de skills lu par Codex et Kimi.
- Les fichiers app-owned sont copies ou fusionnes, jamais symlinkes vers Git.
- Credentials, sessions, caches et etats runtime restent hors Git.

Le plan executable et l'inventaire de migration vivent dans :

- `docs/superpowers/plans/2026-08-15-agent-config-consolidation.md`;
- `docs/deployment-inventory.md`;
- `docs/reviews/2026-08-15-plan-review-claude.md`.

## Etat attendu

Quand la migration sera terminee :

```bash
./install.sh --dry-run
./install.sh --check
./install.sh --only codex
./install.sh
```

Le deploiement reel restera protege par une validation humaine distincte.

## Bascule et rollback

La bascule n'est pas activee par l'installation. Avant le premier deploiement
reel, ajouter cette garde, encore inactive, juste apres `set -euo pipefail`
dans les `install.sh` et `update.sh` historiques :

```bash
source "$HOME/src/agent-config/scripts/legacy-installer-guard.sh" || exit $?
```

Apres validation du diff et des sauvegardes, la sequence de bascule est :

```bash
scripts/cutover-marker.sh activate
./install.sh
./install.sh --check
```

La premiere etape d'un rollback est toujours de reactiver les anciens
installateurs, avant toute restauration :

```bash
scripts/cutover-marker.sh deactivate
```

Le marqueur vit sous `~/.config/agent-config/active`. Cette preparation ne
modifie ni les anciens depots ni les homes tant que ces commandes ne sont pas
executees explicitement.

## Contrats de deploiement

| Surface | Strategie | Proprietaire |
| --- | --- | --- |
| Instructions globales | rendu `common + overlay`, copie | source |
| Skills Linux/WSL | liens par skill | source |
| Skills Codex Windows | copies reelles | source |
| Claude `settings.json` | fusion JSON | cles connues source, cles inconnues runtime |
| Codex `config.toml` Linux | copie + preservation de `[hooks.state]` et `[projects.*]` | source + trust runtime |
| Codex `config.toml` Windows | seed-only | application |
| Kimi `config.toml` | fusion TOML ciblee | permissions/hooks source, modele/providers runtime |
| OpenCode `opencode.json` | copie mode `0600` | source |
| OpenCode `~/.profile.local` | bloc d'environnement fusionne | bloc source, reste runtime |
| Credentials, sessions, caches, memoires | ignore | application |

Pour Claude, `permissions`, `model`, `hooks`, `statusLine`, `enabledPlugins` et
`extraKnownMarketplaces` sont source-owned. Une cle top-level inconnue est
preservee pendant la fusion.

Pour Kimi, `default_permission_mode`, `merge_all_available_skills`,
`[[permission.rules]]` et `[[hooks]]` sont source-owned. La fusion force
`merge_all_available_skills = false` afin que le groupe Kimi et le hub generique
soient charges sans agreger les repertoires Claude/Codex. `default_model`,
providers, modeles et sections runtime restent ceux du fichier deployee
lorsqu'il existe. Le fichier source sert de seed pour une premiere installation.

OpenCode 1.3.13 decouvre sinon tous les skills Claude-only. Le bloc gere dans
`~/.profile.local` exporte `OPENCODE_DISABLE_CLAUDE_CODE_SKILLS=1`; comme cette
version desactive aussi le hub avec ce flag, les skills partages sont miroires
par liens dans `~/.config/opencode/skills`. Le reste de `~/.profile.local` est
preserve et sa sauvegarde reste hors Git dans `~/.config/agent-config/backups`.
Ouvrir un nouveau shell (ou sourcer `~/.profile.local`) apres la premiere
installation pour que le processus OpenCode herite de la variable.

## Dependances externes

Les huit skills Anthropic utilises uniquement par Claude sont conserves dans un
submodule et deployes par allowlist :

```bash
git submodule update --init
```

Les bootstraps de plugins Claude et Codex restent natifs. Les tests les exercent
avec des CLI factices; `AGENT_CONFIG_SKIP_PLUGINS=1` les desactive lors d'un
deploiement de diagnostic.

## MCP natifs

Les MCP ne sont pas rendus depuis un manifeste commun : leurs formats et leurs
modes de lancement restent propres a chaque harness.

| Harness | Source declarative | Serveurs actuellement geres |
| --- | --- | --- |
| Claude | `harnesses/claude/settings.json` | Context7, Linear, Playwright |
| Codex | `harnesses/codex/config.toml` | Context7, Linear, Playwright |
| Kimi | `harnesses/kimi/mcp.json` | Context7, Linear |
| OpenCode | `harnesses/opencode/opencode.json` | aucun |
