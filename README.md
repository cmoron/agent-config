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
- `~/.agents` est reserve au hub de skills.
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

## Contrats de deploiement

| Surface | Strategie | Proprietaire |
| --- | --- | --- |
| Instructions globales | rendu `common + overlay`, copie | source |
| Skills Linux/WSL | liens par skill | source |
| Skills Codex Windows | copies reelles | source |
| Claude `settings.json` | fusion JSON | cles connues source, cles inconnues runtime |
| Codex `config.toml` Linux | copie + preservation de `[hooks.state]` | source + trust runtime |
| Codex `config.toml` Windows | seed-only | application |
| Kimi `config.toml` | fusion TOML ciblee | permissions/hooks source, modele/providers runtime |
| OpenCode `opencode.json` | copie mode `0600` | source |
| Credentials, sessions, caches, memoires | ignore | application |

Pour Claude, `permissions`, `model`, `hooks`, `statusLine`, `enabledPlugins` et
`extraKnownMarketplaces` sont source-owned. Une cle top-level inconnue est
preservee pendant la fusion.

Pour Kimi, `default_permission_mode`, `[[permission.rules]]` et `[[hooks]]` sont
source-owned. `default_model`, providers, modeles et sections runtime restent
ceux du fichier deployee lorsqu'il existe. Le fichier source sert de seed pour
une premiere installation.

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
