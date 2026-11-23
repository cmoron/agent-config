# Inventaire de deploiement

Ce document decrit le contrat courant de `install.sh`. Les chemins ci-dessous
sont les cibles par defaut ; les variables `AGENT_CONFIG_*` de l'installateur
permettent de les remplacer. Les plans et releves de migration sont dans
l'historique Git.

## Instructions, skills et hooks

| Source                                        | Cible                                                                                                | Strategie                                                                 |
| --------------------------------------------- | ---------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| `instructions/common.md` + overlay du harness | `~/.codex/AGENTS.md`, `~/.claude/CLAUDE.md`, `~/.config/opencode/AGENTS.md`, `~/.pi/agent/AGENTS.md` | Rendu avec bandeau genere, copie                                          |
| `shared/skills/`, skills prives + Matt Pocock | `~/.agents/skills` pour Codex et Pi ; miroirs `~/.claude/skills` et `~/.config/opencode/skills`      | Liens par skill                                                           |
| Allowlist Anthropic                           | `~/.claude/skills` uniquement                                                                        | Liens vers le sous-module Claude                                          |
| `shared/scripts/*.sh` + scripts natifs        | `~/.{codex,claude}/scripts`                                                                          | Dossier reel, liens par fichier ; le natif remplace le commun de meme nom |
| `shared/assets/`                              | `~/.{codex,claude}/assets`                                                                           | Lien de dossier                                                           |

Chaque skill local vit dans `shared/skills`, meme s'il ne sert qu'a un harness.
macOS et WSL sont des variantes d'environnement, pas des raisons de le dupliquer.
Ses ressources utiles (references et scripts) sont deployees avec lui.
`harnesses/<name>/skills/` reste une echappatoire de l'installateur, actuellement
vide et controlee par `tests/test-structure.sh` ; tout usage exige une
justification ici. Codex lit le hub sans seconde copie des skills partages
dans son home natif.

Les skills prives vivent hors de ce depot public, par defaut dans
`~/src/agent-skills-private/skills` (depot prive `cmoron/agent-skills-private`),
autrement dans `AGENT_CONFIG_PRIVATE_SKILLS`. Present, ce dossier est deploye comme
`shared/skills` (hub, miroirs, copie Windows) ; absent, il est ignore et ses anciens
liens sont purges. Un nom deja pris par un skill d'agent-config fait echouer
l'installation.

La selection Matt Pocock vient de `.claude-plugin/plugin.json` dans le
sous-module, completee par `upstreams/mattpocock-extra-skills.txt`. Les chemins
absents, non surs ou en collision font echouer l'installation. L'allowlist
Anthropic se reduit a `webapp-testing` : les autres skills n'ont jamais servi et
les skills Office sont deja fournis par la synchronisation claude.ai. Aucun fork
local n'est maintenu.

Les scripts tiers d'autres noms sont preserves ; les collisions sont
sauvegardees et seuls les liens geres obsoletes sont purges. Un ancien lien de
dossier `scripts` gere est remplace sans modifier sa source. OpenCode conserve
ses formateurs natifs et ne recoit pas ces hooks shell. Les protocoles et les
limites sont documentes dans [hooks.md](hooks.md).

Le tronc commun reste court : le contexte tracker, labels et domaine des skills
Pocock vit dans le skill `github-tracker`, deploye partout, et le tronc n'en
garde que le pointeur.

`--instructions-only` ne touche ni configs, ni skills, ni plugins, ni manifeste
Windows. Les instructions composees definissent la facon de travailler ; le
flow de chaque projet et les surcharges `docs/agents/` sont lus par l'agent,
sans ecriture de l'installateur dans ces projets.

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
| `agents/` si present            | `~/.claude/agents`        | Liens par fichier, artefacts tiers preserves |

`permissions`, `autoMode`, `model`, `hooks`, `statusLine`, `enabledPlugins`,
`extraKnownMarketplaces` et `env` sont entierement source-owned. Le mode par
defaut est `auto` : le classifieur refuse puis laisse l'agent continuer, sans
prompt ; les regles `deny` restent appliquees avant lui. `autoMode` n'est lu que
depuis `~/.claude/settings.json` ; une entree ajoutee via `/permissions` ou
`/auto-mode-setup` se reporte ici, sinon `--check` la signale. Les cles
top-level inconnues sont preservees.

Le hook `protect-env` porte `onFailure: block` : s'il ne demarre pas ou expire,
l'ecriture est refusee. La deny list bloque aussi la lecture des `.env` du
projet courant, sauf `.env.example`, `.env.sample` et `.env.template`, et celle
des cles privees `~/.ssh/id_*`, par les outils de fichiers ; une lecture par
`cat` en shell n'est pas couverte. Elle refuse `--no-verify` sur `git commit`
et `git push`.

Le code mode n'est pas active par defaut : il rend Remote Control indisponible,
et un `0` dans ce fichier bloquerait aussi son activation par session. L'activer
ponctuellement avec `CLAUDE_CODE_EXPERIMENTAL_CODE_MODE=1 claude`.

`statusLine` lance `scripts/statusline.sh`, qui ne lit que le JSON de stdin,
jamais le transcript : ccstatusline le relisait a chaque affichage (1,3 Go sur
un transcript de 311 Mo, 01/11/2026). ccstatusline n'est plus deploye : son
ancien lien `~/.config/ccstatusline` est purge.

`agents/relecteur.md` definit le relecteur en lecture seule (outils `Read`,
`Grep`, `Glob`, modele Opus). La comparaison JSON est semantique : le
reordonnancement par l'application ne provoque pas de derive.

### OpenCode

`harnesses/opencode/opencode.json` est copie en mode `0600` sous
`~/.config/opencode/opencode.json`, au format natif OpenCode 2.x. Ollama y est
detecte automatiquement, sans bloc de provider. `"formatter": {}` active les
formateurs natifs.

`permissions` est une liste ordonnee ou la derniere regle qui matche gagne, par
dessus la politique de base qui autorise tout. Elle porte la deny list shell et
refuse la lecture et l'edition des `.env`, sauf la lecture de `.env.example`.
Les commandes composees sont decoupees avant comparaison : une regle contenant
un pipe ne peut pas matcher. La config est validee contre le schema publie et
chargee sans avertissement par OpenCode 2.3.2 ; aucune requete modele n'a ete
lancee.

`harnesses/opencode/env.sh` est insere dans un bloc gere de `~/.profile.local` ;
le reste du fichier est preserve. Le flag `OPENCODE_DISABLE_CLAUDE_CODE_SKILLS=1`
isole les skills Claude-only. OpenCode 2.3.2 decouvre aussi les skills du hub
`~/.agents/skills` sans le miroir natif `~/.config/opencode/skills` ; ce miroir,
de priorite superieure, est conserve et couvert par `tests/test-opencode.sh`,
qui interroge le serveur local (`opencode serve`) quand le binaire est present.
Ouvrir un nouveau shell ou sourcer `~/.profile.local` apres installation pour
que le processus herite du flag. Les tests de decouverte ne valident pas une
requete au modele Ollama.

### Pi

La cible est `~/.pi/agent`, remplacee par `PI_CODING_AGENT_DIR` (variable de pi)
puis par `AGENT_CONFIG_PI_DIR`, prioritaire.

| Source sous `harnesses/pi/` | Cible sous `~/.pi/agent/`    | Strategie                                        |
| --------------------------- | ---------------------------- | ------------------------------------------------ |
| `settings.json`             | `settings.json`              | Fusion JSON, mode `0600`, comparaison semantique |
| cles de `settings.json`     | `.agent-config-managed.json` | Manifeste des cles de premier niveau gerees      |
| `extensions/*.ts`           | `extensions/`                | Copies de vrais fichiers ; autres noms preserves |

Les cles de la source gagnent ; celles que pi ecrit (`deviceId`,
`lastChangelogVersion`) sont preservees. Un tableau source remplace celui de la
cible : un paquet installe a la main avec `pi install` doit etre reporte dans
`packages`, sinon `--check` le signale et l'installation le retire. Une cle
geree par l'installation precedente puis retiree de la source est supprimee,
grace au manifeste. L'ancien manifeste `.pi-config-managed.json` du depot
d'essai `pi-config` sert de manifeste precedent s'il est seul, puis il est
supprime. Pi charge tout le dossier `extensions/` : une extension tierce
d'un autre nom n'est pas une derive, une extension geree modifiee en est une.
Une extension retiree de la source n'est pas purgee de la cible.

Pi lit directement le hub `~/.agents/skills`, deploye des que pi est
selectionne ; il n'a pas de miroir natif. Aucun bootstrap : pi installe
lui-meme les paquets epingles de `packages` au demarrage. Leur mise a jour passe
par `scripts/update-pi-packages.sh` (voir le [guide des scripts](../scripts/README.md)).

Pi n'a ni mode plan ni prompt de permission. Le paquet `cc-safety-net` est le
garde-fou : il bloque les commandes destructrices connues et l'acces aux
secrets, sans etre une sandbox. `scripts/pi-smoke.sh` verifie qu'il bloque
`git reset --hard`.

`pi-formatter` lance ruff, rustfmt et prettier sur chaque fichier edite (cle
`formatter`). **Risque assume avec prettier** : il charge la configuration du
depot, et un `.prettierrc.js` ou `prettier.config.*` est du code. Editer un
`.md`, `.yaml` ou `.html` dans un depot hostile execute ce code, hors du
garde-fou. `--no-config` fermerait la breche mais ignorerait le style des
depots de Cyril. Ne pas lancer pi dans un depot clone sans avoir regarde sa
configuration prettier ; le hook `format-on-save` de Claude Code a la meme
exposition.

Les modeles `claude-bridge/...` passent par Claude Code (`pi-claude-bridge`) et
le forfait ; les modeles `anthropic/...` de pi sont factures au token.
L'extension `claude-clean-home.ts` pointe `CLAUDE_CONFIG_DIR` vers
`~/.pi/agent/claude-home` : le Claude Code du bridge ne charge ni les hooks ni
les plugins de `~/.claude`. Ce dossier a son propre login, pose a la main :
`CLAUDE_CONFIG_DIR=~/.pi/agent/claude-home claude auth login`, pas le `/login`
de pi. Ce dossier, `auth.json`, les sessions et les caches de paquets
(`npm/`, `git/`) restent hors contrat.

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

Pi n'a pas de bootstrap (voir sa section). Les bootstraps Claude et Codex restent natifs et ne tournent qu'en mode apply,
si la CLI est disponible et `AGENT_CONFIG_SKIP_PLUGINS` n'est pas `1`. Ils
peuvent installer/actualiser les plugins declares. Les tests utilisent des CLI
factices ; un test de copie n'etablit pas l'activation d'un plugin.

Superpowers est declare a `false` : il ne s'active que dans les projets dont
le flow est `superpowers`, par leur `.claude/settings.json`, que le skill
`/flow` ecrit. Sous Pi et Codex il reste global. Les trois flows et leur
deroule sont decrits dans [flows.md](flows.md).

Les marketplaces `github` s'enregistrent par leur depot. Une marketplace
`directory` s'enregistre par son chemin, et seulement si ce dossier existe :
sinon le bootstrap la signale et saute ses plugins. `goblin-hood`
(`/home/cyril/src/goblin-hood/ops/claude`, plugin `goblin-alertes`, canal des
alertes de Goblin Hood) n'existe que sur la devbox.
Le canal ne s'ouvre qu'avec `--channels` et une entree `allowedChannelPlugins`
des reglages geres du systeme, poses a la main hors de ce depot.

| Harness  | Source declarative                 | MCP declares                                     |
| -------- | ---------------------------------- | ------------------------------------------------ |
| Codex    | `harnesses/codex/config.toml`      | Playwright, Linear, Unity (desactive par defaut) |
| Claude   | aucune                             | Linear passe par le connecteur claude.ai         |
| OpenCode | `harnesses/opencode/opencode.json` | Aucun                                            |
| Pi       | `harnesses/pi/settings.json`       | Aucun ; Context7 vient du paquet `context7-pi`   |

Les MCP de plugins ne figurent pas dans ce tableau. Unity s'active par session
avec `codex -c mcp_servers.unityMCP.enabled=true` quand l'editeur expose son
endpoint. Les protocoles restent declares nativement, sans manifeste commun.

## Sauvegardes et limites de gestion

Les sauvegardes sont sous `<racine-runtime>/backups/<horodatage>/`. Celles de
`~/.profile.local` vont sous `~/.config/agent-config/backups/`. Aucune
sauvegarde ne va dans Git.

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
Kimi Code n'est plus gere : l'installateur ne supprime pas un `~/.kimi-code`
deja deploye, qui contient des donnees de l'application ; son retrait est manuel.
`~/.claude/rules`, la memoire Claude par projet et les instructions locales
restent des sources externes assumees.
