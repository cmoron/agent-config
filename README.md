# agent-config

Configuration personnelle multi-harness pour Claude Code, Codex, Kimi Code et
OpenCode.

La bascule est faite : ce depot est la source declarative unique. Les anciens
depots `claude-config`, `codex-config` et `kimi-config` sont geles derriere la
garde legacy et ne sont plus autoritatifs; leur archivage attend une validation
explicite.

## Principes

- `shared/` contient uniquement les artefacts reellement portables.
- `harnesses/<name>/` contient les configurations et adaptations natives.
- Les instructions sont rendues depuis `instructions/common.md` et un overlay.
- `~/.agents` est reserve au hub de skills lu par Codex et Kimi.
- Les fichiers app-owned sont copies ou fusionnes, jamais symlinkes vers Git.
- Credentials, sessions, caches et etats runtime restent hors Git.

La reference operationnelle et les archives de conception vivent dans :

- `docs/deployment-inventory.md` pour l'inventaire courant;
- `docs/superpowers/plans/2026-08-15-agent-config-consolidation.md` pour le
  plan initial, desormais historique;
- `docs/reviews/2026-08-15-plan-review-claude.md` pour la review historique de
  ce plan.

## Prerequis

`install.sh` a besoin de `bash >= 4`, `python >= 3.11` (pour `tomllib`) et `jq`.
macOS livre bash 3.2 et python 3.9 : l'installateur se re-execute sous le bash
de Homebrew et choisit le premier `python3.x` qui expose `tomllib`.
`AGENT_CONFIG_PYTHON` force cet interpreteur.

## Initialisation

Un clone neuf peut soit initialiser les revisions epinglees par le superprojet,
soit s'aligner immediatement sur les branches `main` suivies :

```bash
git submodule update --init --recursive
# ou, pour suivre main et valider sans deployer :
uv run scripts/update_upstreams.py --no-install
```

## Deploiement

Les tests s'executent sous des homes temporaires; seul `./install.sh` touche
les homes reels :

```bash
./install.sh --dry-run
./install.sh --check
./install.sh --only codex
./install.sh
```

Un deploiement reel se lance explicitement; il n'est jamais un effet de bord
des tests.

## Bascule et rollback

La bascule est active : le marqueur `~/.config/agent-config/active` rend
inoperants les `install.sh` et `update.sh` historiques, qui sourcent cette garde
juste apres `set -euo pipefail` :

```bash
source "$HOME/src/agent-config/scripts/legacy-installer-guard.sh" || exit $?
```

La premiere etape d'un rollback est toujours de reactiver les anciens
installateurs, avant toute restauration :

```bash
scripts/cutover-marker.sh deactivate
```

Pour rebasculer ensuite : `scripts/cutover-marker.sh activate`, `./install.sh`,
puis `./install.sh --check`.

## Contrats de deploiement

| Surface                                 | Strategie                                                 | Proprietaire                                       |
| --------------------------------------- | --------------------------------------------------------- | -------------------------------------------------- |
| Instructions globales                   | rendu `common + overlay`, copie                           | source                                             |
| Skills Linux/WSL                        | liens par skill                                           | source                                             |
| Skills Codex Windows                    | copies reelles                                            | source                                             |
| Claude `settings.json`                  | fusion JSON                                               | cles connues source, cles inconnues runtime        |
| Codex `config.toml` Linux               | copie + preservation de `[hooks.state]` et `[projects.*]` | source + trust runtime                             |
| Codex `config.toml` Windows             | seed-only                                                 | application                                        |
| Kimi `config.toml`                      | fusion TOML ciblee                                        | permissions/hooks source, modele/providers runtime |
| OpenCode `opencode.json`                | copie mode `0600`                                         | source                                             |
| OpenCode `~/.profile.local`             | bloc d'environnement fusionne                             | bloc source, reste runtime                         |
| Credentials, sessions, caches, memoires | ignore                                                    | application                                        |

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

`opencode.json` declare `"formatter": {}` : la forme objet active les formateurs
natifs (prettier, Biome, ruff, gofmt...) selon ce que le projet contient, et reste
acceptee par OpenCode 1.3.13, qui refuse le booleen `true` du schema recent.

## Dependances externes

Deux submodules suivent explicitement leur branche `main` :

- les huit skills Anthropic deployes uniquement pour Claude;
- les skills promus par le manifest `.claude-plugin/plugin.json` de Matt
  Pocock, deployes comme skills partages dans le hub et les miroirs natifs.

`grill-with-docs` suit directement Matt Pocock avec `grilling` et
`domain-modeling`; aucune adaptation locale n'est maintenue.

Le manifest amont ne promeut que `engineering/` et `productivity/`.
`upstreams/mattpocock-extra-skills.txt` ajoute les skills utilises hors de ces
buckets — aujourd'hui `misc/` et `in-progress/`. Ils sont valides et deployes
comme ceux du manifest, toujours depuis le submodule et jamais forkes; un
chemin retire en amont fait echouer l'installation au lieu de disparaitre en
silence.

La CLI de mise a jour aligne les deux submodules sur `origin/main`, lance toute
la suite de tests, puis installe par defaut :

```bash
uv run scripts/update_upstreams.py --help
uv run scripts/update_upstreams.py --no-install
uv run scripts/update_upstreams.py --install --dry-run
uv run scripts/update_upstreams.py --install
```

Elle refuse de continuer si un submodule contient des modifications locales.
Le pointeur Git du superprojet conserve le SHA exact du candidat. Si les tests
echouent, ce candidat reste dans le worktree pour inspection mais rien n'est
deploye; apres succes, le meme SHA est installe.
`update.sh` tire d'abord le depot en fast-forward puis delegue a cette CLI.

Les bootstraps de plugins Claude et Codex restent natifs. Les tests les exercent
avec des CLI factices; `AGENT_CONFIG_SKIP_PLUGINS=1` les desactive lors d'un
deploiement de diagnostic.

## MCP declares nativement

Les MCP ne sont pas rendus depuis un manifeste commun : leurs formats et leurs
modes de lancement restent propres a chaque harness. Le tableau recense
uniquement les serveurs declares dans les fichiers de ce depot; les MCP fournis
par des plugins n'y figurent pas. Le serveur Unity de Codex reste
`enabled = false`: son endpoint n'existe que pendant que l'editeur tourne, et il
s'active par session avec `codex -c mcp_servers.unityMCP.enabled=true`.

| Harness  | Source declarative                 | Serveurs declares         |
| -------- | ---------------------------------- | ------------------------- |
| Claude   | `harnesses/claude/settings.json`   | Linear                    |
| Codex    | `harnesses/codex/config.toml`      | Playwright, Linear, Unity |
| Kimi     | `harnesses/kimi/mcp.json`          | Context7, Linear          |
| OpenCode | `harnesses/opencode/opencode.json` | aucun                     |
