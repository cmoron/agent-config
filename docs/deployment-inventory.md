# Inventaire de migration multi-harness

Date de mesure : 2026-08-15.

Cet inventaire est la porte d'entree de la migration. Une surface absente de ce
document ne peut pas etre supprimee ou remplacee pendant la bascule.

## Sources et changements locaux

| Source          | Commit mesure                              | Changement local                                                            | Decision                                                                |
| --------------- | ------------------------------------------ | --------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| `codex-config`  | `a6ab99b2748f85caba946cf98953121967a52a1f` | `config.toml`: MCP Playwright via `bunx --bun`, plugin Playwright desactive | reprendre                                                               |
| `claude-config` | `7ad1a9f40fc747114688bf66383b1a50c549022f` | `RTK.md`: `rtk hook check`                                                  | reprendre dans l'overlay Claude                                         |
| `claude-config` | idem                                       | `settings.json`: mode `auto`, modele `opus[1m]`                             | **corrige** : `auto` etait un etat local transitoire; l'etat declare est `bypassPermissions`, comme le commit de reference |
| `claude-config` | idem                                       | `lotusim-developer`: nettoyage robuste des processus Gazebo                 | **revise** : promu dans `shared/skills` (cf. Partagee)                  |
| `claude-config` | idem                                       | `openclaw`: documentation Nestor/Hermes et heartbeat 30 min                 | **revise** : promu dans `shared/skills` (cf. Partagee)                  |
| `kimi-config`   | `852bc1a9b6ef81b9ea734732dee842fa257672b4` | `mcp.json`: retrait de Peekaboo et Unity                                    | reprendre; la cible contient Linear et Context7                         |
| `kimi-config`   | idem                                       | `README.md`: liste MCP encore incoherente                                   | ne pas importer; reecrire le README consolide depuis la cible effective |
| runtime Kimi    | hors Git                                   | `config.toml`: `scope = "user"`, `loop_control`, `mcp.client`               | reprendre semantiquement; classer le fichier `merge`                    |

Les contenus divergents ne sont pas resolus par choix implicite. Ils restent
dans le harness qui les possede jusqu'a une verification dediee.

## Surface actuelle et cible

### Partagee

| Artefact                     | Source actuelle                   | Cible actuelle                                       | Decision cible                                                                                           |
| ---------------------------- | --------------------------------- | ---------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| 16 skills locaux             | forkes par harness dans les depots legacy | homes Claude/Codex/Kimi                      | source unique `shared/skills`; hub `~/.agents/skills`; miroirs Claude et OpenCode                        |
| 25 skills Matt Pocock promus | `mattpocock/skills`               | plugin/skills externes                               | submodule sur `main`; selection dynamique par le manifest upstream; memes cibles que les skills partages |
| son de notification          | trois copies byte-identiques      | chemins sous les anciens depots ou `~/.codex/assets` | source unique `shared/assets`; copie/lien dans l'assets dir natif de chaque harness                      |
| instructions communes        | trois fichiers divergents         | fichiers globaux natifs                              | `instructions/common.md` + overlay rendu dans chaque home natif                                          |

`shared/skills` contient **tous** les skills locaux, en un seul exemplaire :
`agent-config`, `api-design`, `autoship`, `commit`, `deployment`, `linear`,
`lotusim-developer`, `macos-control`, `mvp`, `nvim-config`, `openclaw`,
`opensource-contributor`, `stack-python`, `stack-rust`, `stack-ts` et
`wsl-windows-gui`.

macOS contre WSL est un axe environnement, pas un axe harness : les quatre
harnais tournent sur les deux machines. Un skill n'est donc jamais duplique par
harness, meme s'il ne sert qu'a l'un d'eux. La portion qui depend reellement du
harness s'ecrit dans le fichier unique — une phrase, un tableau, une section
« selon le harness ». `harnesses/<name>/skills/` reste supporte par
l'installateur mais doit rester vide; `tests/test-structure.sh` le verifie.

Cette regle revient sur la decision initiale « reprendre dans la variante
Claude, sans promouvoir vers `shared/` » pour `openclaw` et `lotusim-developer`.
Les forks avaient diverge : la copie Codex d'`opensource-contributor` avait
perdu une etape obligatoire entiere, celle d'`openclaw` annoncait un heartbeat
de 4 h contre 30 min, celle de `lotusim-developer` ignorait le piege du process
gz orphelin. Les versions Claude, plus completes, ont ete retenues comme base.

`grill-with-docs` suit desormais directement le manifest Matt Pocock, avec `grilling` et
`domain-modeling`; les anciens fichiers annexes locaux ont ete retires.

### Claude Code

| Artefact actuel        | Cible runtime                                | Type actuel                         | Decision cible                                                            |
| ---------------------- | -------------------------------------------- | ----------------------------------- | ------------------------------------------------------------------------- |
| `CLAUDE.md` + `RTK.md` | `~/.claude/`                                 | symlinks                            | rendu unique `CLAUDE.md`; RTK inline dans l'overlay; bandeau genere       |
| `settings.json`        | `~/.claude/settings.json`                    | symlink reecrit par l'application   | `merge`; source-owned et runtime-owned documentes                         |
| hooks shell            | commandes vers `~/src/claude-config/scripts` | chemin source en dur                | deployer sous `~/.claude/scripts`; commandes vers la cible deployee       |
| asset audio            | `~/src/claude-config/assets`                 | chemin source en dur dans le script | deployer sous `~/.claude/assets`; script sans ancien chemin source        |
| commands               | `~/.claude/commands`                         | liens par fichier                   | reprendre declarativement                                                 |
| agents                 | `~/.claude/agents`                           | dossier gere, actuellement vide     | reprendre le contrat; preserver les artefacts tiers                       |
| skills personnels      | `~/.claude/skills`                           | liens par skill                     | miroir de `shared/skills`; Claude ne lit pas le hub                       |
| skills Anthropic       | submodule `main` + allowlist de 8            | liens dans `~/.claude/skills`       | conserver sous `harnesses/claude/upstream`; meme allowlist                |
| ccstatusline           | `~/.config/ccstatusline`                     | lien de dossier                     | reprendre declarativement sans supprimer un dossier tiers sans sauvegarde |
| plugins/marketplaces   | `settings.json` + bootstrap CLI              | etat applicatif                     | conserver le bootstrap Claude natif; ne pas partager                      |

Allowlist Anthropic conservee : `claude-api`, `mcp-builder`,
`webapp-testing`, `doc-coauthoring`, `docx`, `pdf`, `pptx`, `xlsx`.

Le submodule `upstreams/mattpocock-skills` suit `main`. Son manifest Claude est
la seule liste des skills promus : aucun duplicat local ni allowlist parallele.

### Codex

| Artefact actuel       | Cible runtime                  | Type actuel                       | Decision cible                                                      |
| --------------------- | ------------------------------ | --------------------------------- | ------------------------------------------------------------------- |
| instructions          | `~/.codex/AGENTS.md`           | copie                             | rendu compose avec bandeau genere                                   |
| `config.toml`         | `~/.codex/config.toml`         | copie + reinjection `hooks.state` | conserver la fusion ciblee Linux; Windows reste app-owned/seed-only |
| hooks                 | `~/.codex/hooks.json`          | copie                             | reprendre; commandes vers `~/.codex/scripts`                        |
| scripts/assets/agents | `~/.codex/*`                   | liens de dossier                  | reprendre, asset source depuis `shared/assets`                      |
| rules                 | `~/.codex/rules/default.rules` | copie                             | reprendre                                                           |
| skills specifiques    | `~/.codex/skills`              | liens par skill                   | vide : Codex lit le hub `~/.agents/skills`                          |
| plugins/marketplaces  | bootstrap CLI                  | etat applicatif                   | conserver le bootstrap Codex natif; ne pas partager                 |
| copie Windows         | `/mnt/c/Users/cyril/.codex`    | fichiers reels + manifeste        | reprendre; ne jamais ecraser un `config.toml` existant              |

La section projet de l'ancien `config.toml` qui nomme `codex-config` doit etre
supprimee ou remplacee par `agent-config` apres classification; aucun ancien
chemin de depot ne doit rester dans une sortie deployee.

### Kimi Code

| Artefact actuel    | Cible runtime                              | Type actuel                         | Decision cible                                                                                                               |
| ------------------ | ------------------------------------------ | ----------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| instructions       | `~/.kimi-code/AGENTS.md`                   | symlink                             | rendu compose avec bandeau genere                                                                                            |
| `config.toml`      | `~/.kimi-code/config.toml`                 | symlink remplace par l'application  | `merge`; preserver les sections runtime inconnues; isoler le groupe de skills Kimi avec `merge_all_available_skills = false` |
| `tui.toml`         | `~/.kimi-code/tui.toml`                    | symlink                             | copie apres sauvegarde                                                                                                       |
| `mcp.json`         | `~/.kimi-code/mcp.json`                    | symlink                             | copie apres sauvegarde; Linear + Context7                                                                                    |
| hooks shell        | commandes vers `~/src/kimi-config/scripts` | chemin source en dur                | deployer sous `~/.kimi-code/scripts`; commandes vers la cible deployee                                                       |
| asset audio        | `~/src/kimi-config/assets`                 | chemin source en dur dans le script | deployer sous `~/.kimi-code/assets`; script sans ancien chemin source                                                        |
| skills specifiques | `~/.kimi-code/skills`                      | liens par skill                     | vide : Kimi lit le hub `~/.agents/skills`                                                                                    |
| credentials OAuth  | `~/.kimi-code/credentials`                 | app-owned                           | ignorer strictement                                                                                                          |

### OpenCode

| Artefact actuel    | Cible runtime                      | Type actuel                           | Decision cible                                                                                                    |
| ------------------ | ---------------------------------- | ------------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| `opencode.json`    | `~/.config/opencode/opencode.json` | fichier mode `0600`, non gere         | importer sans secret; copie mode `0600` apres sauvegarde                                                          |
| instructions       | absentes                           | aucune                                | rendu compose vers `~/.config/opencode/AGENTS.md`                                                                 |
| skills partages    | hub Claude/agents lu nativement    | fuite des skills Claude-only observee | desactiver la compatibilite Claude et miroiter les liens dans `~/.config/opencode/skills`                         |
| environnement      | `~/.profile.local` hors gestion    | aucune isolation de discovery         | fusionner un bloc qui exporte `OPENCODE_DISABLE_CLAUDE_CODE_SKILLS=1`; preserver et sauvegarder le reste hors Git |
| skills specifiques | absents                            | aucun                                 | vide : `~/.config/opencode/skills` est un miroir complet de `shared/skills`                                       |
| provider Ollama    | dans `opencode.json`               | app/runtime                           | conserver; smoke modele differe tant que le provider ne repond pas                                                |

Le plan n'utilise pas la cle `instructions[]`; le support de `~/` dans cette cle
n'est donc pas un prerequis. OpenCode 1.3.13 masque aussi le hub lorsque la
compatibilite Claude est desactivee; le miroir natif est donc teste avec le
binaire reel, pas deduit de la documentation.

## Hors perimetre de gestion

Les chemins suivants sont app-owned et ne doivent jamais etre purges, copies
vers Git ou compares byte-a-byte : credentials, sessions, caches, historiques,
memoires natives, bases SQLite, logs, locks, telemetry, OAuth, trust state,
plugins installes et marketplaces telechargees.

`~/.claude/rules`, la memoire Claude par projet et les instructions locales des
repositories restent des sources d'instructions externes assumees.

## Invariants de bascule

- `~/.agents/AGENTS.md` doit etre absent. `--check` signale sa presence mais ne
  le supprime pas.
- Aucun fichier gere ou script deploye ne contient `claude-config`,
  `codex-config` ou `kimi-config` comme chemin source. La detection couvre les
  formes `/home/<user>`, `/Users/<user>`, `$HOME` et `~`; un commentaire
  d'en-tete recupere par une fusion compte comme une reference.
- Un fichier rendu au format JSON est compare semantiquement, pas octet a
  octet. Claude Code reecrit `settings.json` dans son propre ordre de cles des
  que l'installateur amorce les plugins; sans cela `--check` signalerait une
  derive de contenu a chaque execution.
- Un skill partage n'existe pas simultanement dans le hub et dans le home Codex.
- Les racines legacy sont derivees de `$HOME` et couvrent `src/claude-config`,
  `src/codex-config`, `src/kimi-config` et `src/skills`. Un lien deploye vers
  l'une d'elles est purge sans sauvegarde; les autres liens tiers sont
  sauvegardes, jamais supprimes. `src/skills` est l'ancien clone manuel des
  skills Matt Pocock, remplace par le submodule.
- Les anciens installateurs restent actifs avant la bascule. Un marqueur de
  migration les rend inoperants atomiquement pendant la bascule; le rollback
  retire ce marqueur avant de les reutiliser.
- L'archivage des anciens depots n'est autorise qu'apres deux cycles reels suivis
  d'un `./install.sh --check` propre.
