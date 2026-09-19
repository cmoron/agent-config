# Inventaire de deploiement

Ce document decrit le contrat courant de `install.sh`. Les chemins ci-dessous
sont les cibles par defaut ; les variables `AGENT_CONFIG_*` de l'installateur
permettent de les remplacer. Les plans et releves de migration sont dans
l'historique Git.

## Instructions, skills et hooks

| Source                                        | Cible                                                                                                 | Strategie                                                                 |
| --------------------------------------------- | ----------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| `instructions/common.md` + overlay du harness | `~/.codex/AGENTS.md`, `~/.claude/CLAUDE.md`, `~/.config/opencode/AGENTS.md`, `~/.kimi-code/AGENTS.md` | Rendu avec bandeau genere, copie                                          |
| `shared/skills/` + selection Matt Pocock      | `~/.agents/skills` pour Codex/Kimi ; miroirs `~/.claude/skills` et `~/.config/opencode/skills`        | Liens par skill                                                           |
| Allowlist Anthropic                           | `~/.claude/skills` uniquement                                                                         | Liens vers le sous-module Claude                                          |
| `shared/scripts/*.sh` + scripts natifs        | `~/.{codex,claude,kimi-code}/scripts`                                                                 | Dossier reel, liens par fichier ; le natif remplace le commun de meme nom |
| `shared/assets/`                              | `~/.{codex,claude,kimi-code}/assets`                                                                  | Lien de dossier                                                           |

Chaque skill local vit dans `shared/skills`, meme s'il ne sert qu'a un harness.
macOS et WSL sont des variantes d'environnement, pas des raisons de le dupliquer.
Ses ressources utiles (references et scripts) sont deployees avec lui.
`harnesses/<name>/skills/` reste une echappatoire de l'installateur, actuellement
vide et controlee par `tests/test-structure.sh` ; tout usage exige une
justification ici. Codex et Kimi lisent le hub sans seconde copie des skills
partages dans leur home natif.

La selection Matt Pocock vient de `.claude-plugin/plugin.json` dans le
sous-module, completee par `upstreams/mattpocock-extra-skills.txt`. Les chemins
absents, non surs ou en collision font echouer l'installation. L'allowlist
Anthropic est : `claude-api`, `mcp-builder`, `webapp-testing`, `doc-coauthoring`,
`docx`, `pdf`, `pptx`, `xlsx`. Aucun fork local de ces skills n'est maintenu.

Les scripts tiers d'autres noms sont preserves ; les collisions sont
sauvegardees et seuls les liens geres obsoletes sont purges. Un ancien lien de
dossier `scripts` gere est remplace sans modifier sa source. OpenCode conserve
ses formateurs natifs et ne recoit pas ces hooks shell. Les protocoles et les
limites sont documentes dans [hooks.md](hooks.md).

`--instructions-only` ne touche ni configs, ni skills, ni plugins, ni manifeste
Windows. Les instructions composees definissent le workflow global ; les
surcharges `docs/agents/` des projets sont lues par l'agent, sans ecriture de
l'installateur dans ces projets.

## Configurations natives

### Codex

| Source sous `harnesses/codex/`                                  | Cible sous `~/.codex/` | Strategie                                           |
| --------------------------------------------------------------- | ---------------------- | --------------------------------------------------- |
| `config.toml`                                                   | `config.toml`          | Copie rendue `0600`, avec etats runtime preserves   |
| `terra.config.toml`, `luna.config.toml`, `sol-high.config.toml` | Memes noms             | Copies `0600` ; autres profils personnels preserves |
| `hooks.json`, `rules/default.rules`                             | Memes chemins          | Copies                                              |
| `agents/`                                                       | `agents`               | Lien de dossier                                     |

Le rendu du fichier principal preserve `[hooks.state]`, `[projects.*]` et les
cles `last_updated`/`last_revision` des marketplaces declarees. Le reste suit
la source. Sol xhigh est le defaut ; un choix explicite en session prime.
Les profils s'utilisent avec `codex --profile terra|luna|sol-high` et sont des
fichiers voisins, sans tables `[profiles.*]`. Leur chargement est teste avec la
CLI installee dans un home temporaire, sans appel de modele.

### Claude Code

| Source sous `harnesses/claude/` | Cible                     | Strategie                                    |
| ------------------------------- | ------------------------- | -------------------------------------------- |
| `settings.json`                 | `~/.claude/settings.json` | Fusion JSON, mode `0600`                     |
| `commands/`                     | `~/.claude/commands`      | Liens par fichier                            |
| `agents/` si present            | `~/.claude/agents`        | Liens par fichier, artefacts tiers preserves |
| `config/ccstatusline/`          | `~/.config/ccstatusline`  | Lien de dossier                              |

`permissions`, `model`, `hooks`, `statusLine`, `enabledPlugins` et
`extraKnownMarketplaces` sont entierement source-owned. Les cles top-level
inconnues sont preservees. La comparaison JSON est semantique : le reordonnancement
par l'application ne provoque pas de derive.

### OpenCode

`harnesses/opencode/opencode.json` est copie en mode `0600` sous
`~/.config/opencode/opencode.json`. Il conserve le provider Ollama et la forme
`"formatter": {}` acceptee par la CLI testee, pour les formateurs natifs.

`harnesses/opencode/env.sh` est insere dans un bloc gere de `~/.profile.local` ;
le reste du fichier est preserve. Le flag `OPENCODE_DISABLE_CLAUDE_CODE_SKILLS=1`
isole les skills Claude-only. Le binaire 1.3.13 teste masquait aussi le hub avec
ce flag, d'ou le miroir natif couvert par `tests/test-opencode.sh`.
Ouvrir un nouveau shell ou sourcer `~/.profile.local` apres installation pour
que le processus herite du flag. Les tests de decouverte ne valident pas une
requete au modele Ollama.

### Kimi Code

`harnesses/kimi/config.toml` est fusionne vers `~/.kimi-code/config.toml` en
mode `0600`. Seuls `default_permission_mode`, `merge_all_available_skills`,
`[[permission.rules]]` et `[[hooks]]` sont imposes par le depot. La source fixe
`merge_all_available_skills = false` ; modeles, providers et autres sections
runtime sont preserves. La source sert de seed lors de la premiere installation.
La comparaison TOML est semantique ; les limites du mergeur textuel sont dans
le [guide des scripts](../scripts/README.md#comprendre-la-fusion-kimi).

`tui.toml` et `mcp.json` sont copies depuis le meme dossier source dans
`~/.kimi-code/`, respectivement en modes `0644` et `0600`.

## Codex Windows

La cible autodetectee sous WSL est `/mnt/c/Users/$USER/.codex` si le profil
Windows existe ; `AGENT_CONFIG_WINDOWS_CODEX_DIR` permet de la definir, ou de
desactiver la copie avec une valeur vide.

Instructions, profils, hooks, rules, scripts assembles, assets, agents et skills
sont de vrais fichiers, geres par `.agent-config-managed`. Un fichier ou arbre
tiers est sauvegarde lors de sa premiere prise en charge ; un arbre deja gere
est remplace. Les chemins obsoletes du manifeste sont purges. Le manifeste
legacy `.codex-config-managed` est reconnu puis remplace.

Un `config.toml` existant sous forme de fichier regulier reste app-owned et
est conserve. Une cible absente ou symbolique recoit une copie de la source ;
un lien tiers est sauvegarde avant remplacement. S'il contient encore des tables de profils legacy,
l'ajout des nouveaux fichiers ne suffit pas : leur migration dans ce fichier
reste distincte. Les copies Windows sont testees sous Linux ; cela ne prouve
pas leur fonctionnement natif sur Windows.

## Plugins et MCP

Les bootstraps Claude et Codex restent natifs et ne tournent qu'en mode apply,
si la CLI est disponible et `AGENT_CONFIG_SKIP_PLUGINS` n'est pas `1`. Ils
peuvent installer/actualiser les plugins declares. Les tests utilisent des CLI
factices ; un test de copie n'etablit pas l'activation d'un plugin.

| Harness  | Source declarative                 | MCP declares                                     |
| -------- | ---------------------------------- | ------------------------------------------------ |
| Codex    | `harnesses/codex/config.toml`      | Playwright, Linear, Unity (desactive par defaut) |
| Claude   | `harnesses/claude/settings.json`   | Linear                                           |
| OpenCode | `harnesses/opencode/opencode.json` | Aucun                                            |
| Kimi     | `harnesses/kimi/mcp.json`          | Context7, Linear                                 |

Les MCP de plugins ne figurent pas dans ce tableau. Unity s'active par session
avec `codex -c mcp_servers.unityMCP.enabled=true` quand l'editeur expose son
endpoint. Les protocoles restent declares nativement, sans manifeste commun.

## Sauvegardes et limites de gestion

Les sauvegardes sont sous `<racine-runtime>/backups/<horodatage>/`. Celles de
`~/.profile.local` vont sous `~/.config/agent-config/backups/` ; celles de
ccstatusline sous `~/.config/backups/`. Aucune sauvegarde ne va dans Git.

L'installateur reconnait ses liens et ceux des anciennes racines
`$HOME/src/{claude-config,codex-config,kimi-config,skills}` pour leur remplacement
ou purge. Les autres artefacts tiers en collision sont sauvegardes. Le garde
legacy reste actif tant que les anciens installateurs doivent etre neutralises ;
voir le [guide des scripts](../scripts/README.md#gerer-le-verrou-des-anciens-depots).
Leur archivage exige une validation explicite apres deux cycles reels suivis
d'un `./install.sh --check` propre.

`--check` signale un `~/.agents/AGENTS.md` concurrent sans le supprimer, et les
anciens chemins source dans les fichiers geres. Credentials, sessions, caches,
historiques, memoires, bases SQLite, logs, locks, telemetry, OAuth et etats
applicatifs hors contrat ne sont ni importes ni purges. Le journal sonore
`<home-du-harness>/notify-sound.log` reste hors des arbres geres.
`~/.claude/rules`, la memoire Claude par projet et les instructions locales
restent des sources externes assumees.
