# Agent Config Consolidation Implementation Plan

> **Statut :** plan initial execute, conserve comme archive de conception. Les
> comptages et choix ci-dessous decrivent la baseline avant la promotion des
> skills Matt Pocock. `README.md` et `docs/deployment-inventory.md` portent la
> reference operationnelle actuelle.

> **Execution rule:** implement inline, in reviewable batches. The complete
> migration is estimated at 6-8 hours, so subagent-driven development is not
> the default. Each batch below has its own verification gate and commit.

**Goal:** remplacer les configurations personnelles Claude Code, Codex, Kimi
Code et OpenCode par un depot declaratif unique, sans perdre leurs differences
legitimes ni les garanties de deploiement WSL/Windows de Codex.

**Architecture:** `agent-config` est un nouveau depot sans historique importe.
La machinerie de `codex-config` sert de base technique et sera importee avec sa
provenance, puis generalisee. Les skills portables vivent dans `shared/skills`
et sont deployes dans le hub standard `~/.agents/skills`, avec un miroir par
skill pour Claude. OpenCode utilise aussi un miroir natif, car sa compatibilite
Claude doit etre desactivee pour ne pas charger les skills Claude-only. Les
instructions sont composees depuis un socle neutre et un overlay par harness,
puis materialisees dans le fichier global natif de chaque outil. Les
configurations mutables, hooks, plugins et MCP restent propres a leur harness.

**Tech stack:** Bash strict (`set -euo pipefail`), Git, symlinks Linux/WSL,
copies Windows, `jq`/`yq` pour les controles structures lorsqu'ils sont
disponibles, tests shell autonomes sous home temporaire.

## Global Constraints

- Le depot Git est l'unique source editable. Ne jamais maintenir un fichier
  deploye directement sous `~/.claude`, `~/.codex`, `~/.kimi-code`,
  `~/.agents` ou `~/.config/opencode`.
- `install.sh` reste idempotent, sauvegarde les fichiers existants avant
  remplacement et ne supprime que les artefacts qu'il gere.
- Les fichiers que les applications reecrivent sont copies ou fusionnes, jamais
  symlinkes vers Git.
- La cible Windows Codex contient de vrais fichiers. Son `config.toml` existant
  est app-owned et ne doit jamais etre ecrase.
- Aucun credential, token, cache, session, trust hash ou etat runtime n'entre
  dans Git.
- Aucun nouveau plugin ou MCP n'est ajoute pendant cette migration.
- Les quatre harnesses doivent pouvoir etre deployes et verifies separement.
- Un skill ne peut pas exister simultanement dans `shared/skills/<name>` et
  `harnesses/*/skills/<name>` pour une meme cible.
- Les overlays d'instructions completent le socle commun; ils ne doivent pas le
  contredire ou l'annuler.
- Toute suppression ou archivage des anciens depots exige une validation
  humaine apres au moins deux cycles de deploiement reels.

---

## Etat de depart verifie le 2026-08-15

Le nouveau depot a ete initialise vide. Les trois anciens depots sont des
sources d'import independantes; aucun de leurs historiques ni changements non
commites n'est embarque automatiquement :

| Depot source                    | Commit de reference                        | Changements locaux exclus de l'import initial                                              |
| ------------------------------- | ------------------------------------------ | ------------------------------------------------------------------------------------------ |
| `/home/cyril/src/codex-config`  | `a6ab99b2748f85caba946cf98953121967a52a1f` | `config.toml`                                                                              |
| `/home/cyril/src/claude-config` | `7ad1a9f40fc747114688bf66383b1a50c549022f` | `RTK.md`, `settings.json`, `skills/lotusim-developer/SKILL.md`, `skills/openclaw/SKILL.md` |
| `/home/cyril/src/kimi-config`   | `852bc1a9b6ef81b9ea734732dee842fa257672b4` | `README.md`, `mcp.json`                                                                    |

Ces changements doivent etre classes, adoptes ou rejetes explicitement avant
leur import. Le depot `agent-config` possede son propre historique, commencant
par ce plan, et n'a volontairement aucun remote tant que la structure et le
contenu n'ont pas ete relus.

Constats techniques qui fondent le plan :

- Codex 0.146 decouvre les skills dans `~/.agents/skills` et
  `~/.codex/skills`, mais ne charge ni `~/.agents/AGENTS.md` ni les imports
  `@...` places dans son `AGENTS.md`.
- Kimi et OpenCode decouvrent nativement le hub de skills. Claude necessite un
  lien dans `~/.claude/skills` pour chaque skill partage. En coexistence,
  OpenCode decouvre aussi les skills Claude-only; sa compatibilite Claude est
  donc desactivee et les skills partages sont miroires dans sa racine native.
- L'intersection stricte Claude/Codex contient 12 skills : 8 identiques et 4
  divergents. Les huit identiques sont `api-design`, `deployment`,
  `grill-with-docs`, `mvp`, `nvim-config`, `stack-python`, `stack-rust` et
  `stack-ts`.
- Les quatre divergents sont `autoship`, `lotusim-developer`, `openclaw` et
  `opensource-contributor`. Ils restent specifiques jusqu'a reconciliation.
- Le conflit de heartbeat OpenClaw (`30 min` contre `4 h`) n'est pas tranche par
  les fichiers. La configuration effective de Nestor est l'oracle.
- L'ancien `install.sh` Codex purge les anciens liens geres dans
  `~/.agents/skills`; ce contrat doit etre remplace en meme temps que ses tests,
  pas simplement supprime.

## Perimetre de cette migration

### Inclus

- depot unique et arborescence cible;
- installateur commun avec `--only`, `--check` et `--dry-run`;
- huit skills immediatement portables;
- skills specifiques par harness;
- socle d'instructions commun et quatre overlays;
- configuration declarative d'OpenCode;
- conservation des comportements Codex WSL/Windows;
- tests d'installation sous homes temporaires;
- documentation de provenance et de deploiement.

### Differe jusqu'a un besoin mesure

- schema ou renderer MCP commun;
- protocole de hooks commun;
- synchronisation des plugins et marketplaces;
- reconciliation automatique des changements faits par une application;
- daemon, watcher ou synchronisation bidirectionnelle;
- import complet des historiques Git Codex, Claude et Kimi.

Les configurations MCP et hooks existantes restent versionnees sous leur
harness. Une extraction vers `shared/` ne sera faite que pour un composant
demontre byte-identique ou pour un coeur sans connaissance du protocole du
harness.

## Arborescence cible

```text
agent-config/
├── AGENTS.md
├── README.md
├── instructions/
│   └── common.md
├── shared/
│   ├── assets/
│   ├── scripts/
│   └── skills/
├── harnesses/
│   ├── claude/
│   │   ├── instructions.overlay.md
│   │   ├── settings.json
│   │   ├── agents/
│   │   ├── commands/
│   │   ├── config/ccstatusline/
│   │   ├── hooks/
│   │   ├── scripts/
│   │   ├── upstream/anthropic-skills/
│   │   └── skills/
│   ├── codex/
│   │   ├── instructions.overlay.md
│   │   ├── config.toml
│   │   ├── hooks.json
│   │   ├── agents/
│   │   ├── assets/
│   │   ├── rules/
│   │   ├── scripts/
│   │   └── skills/
│   ├── kimi/
│   │   ├── instructions.overlay.md
│   │   ├── config.toml
│   │   ├── tui.toml
│   │   ├── mcp.json
│   │   ├── hooks/
│   │   ├── scripts/
│   │   └── skills/
│   └── opencode/
│       ├── instructions.overlay.md
│       ├── opencode.json
│       └── skills/
├── docs/
│   ├── migration-sources.md
│   └── superpowers/plans/
├── tests/
│   ├── fixtures/
│   ├── test-check.sh
│   ├── test-hooks.sh
│   ├── test-install.sh
│   └── test-instructions.sh
├── install.sh
└── update.sh
```

`shared/assets` contient au minimum le son de notification byte-identique des
trois anciens depots. `shared/scripts` peut rester vide : les protocoles de
hooks restent propres aux harnesses.

## Matrice de deploiement

| Surface              | Claude                        | Codex                                   | Kimi                     | OpenCode                               |
| -------------------- | ----------------------------- | --------------------------------------- | ------------------------ | -------------------------------------- |
| Instructions rendues | `~/.claude/CLAUDE.md`         | `~/.codex/AGENTS.md`                    | `~/.kimi-code/AGENTS.md` | `~/.config/opencode/AGENTS.md`         |
| Skills partages      | liens dans `~/.claude/skills` | `~/.agents/skills` natif                | `~/.agents/skills` natif | liens dans `~/.config/opencode/skills` |
| Skills specifiques   | `~/.claude/skills`            | `~/.codex/skills`                       | `~/.kimi-code/skills`    | `~/.config/opencode/skills`            |
| Config principale    | copie/fusion native           | copie/fusion native                     | copie/fusion native      | copie/fusion native                    |
| Windows Codex        | sans objet                    | copies dans `/mnt/c/Users/cyril/.codex` | sans objet               | sans objet                             |

Le hub `~/.agents` est utilise pour les skills Codex et Kimi seulement.
OpenCode 1.3.13 charge aussi les skills Claude par defaut; son environnement
desactive cette compatibilite et son miroir natif evite toute fuite. Les
instructions sont toujours rendues vers la cible native afin d'avoir un
mecanisme identique et verifiable pour les quatre harnesses.

---

### Task 0: Inventorier la surface de deploiement reelle

**Files:**

- Create: `docs/deployment-inventory.md`
- Modify: `docs/superpowers/plans/2026-08-15-agent-config-consolidation.md`

**Interfaces:**

- Consumes: les trois installateurs historiques, leurs worktrees sales et les
  cinq racines runtime Linux/WSL plus la cible Codex Windows.
- Produces: pour chaque artefact, source, cible, type, proprietaire, decision
  `repris`/`abandonne`/`differe`, nouvelle cible et preuve attendue.

- [x] **Step 1: Enumerer statiquement chaque installateur**

  Relever fichiers, repertoires, submodules, allowlists, chemins de hooks,
  bootstrap plugins, cibles externes comme `~/.config/ccstatusline` et copies
  Windows. Rechercher aussi les anciens noms de depot dans les scripts et
  configurations.

- [x] **Step 2: Comparer avec les arbres runtime**

  Inspecter les types de chaque entree avec `find`, `stat` et `readlink`, sans
  lire ni copier credentials, sessions, caches, memoires, bases, logs ou etats
  de trust.

- [x] **Step 3: Classer les changements locaux**

  Consigner les diffs adoptes, ignores ou differes. Un fichier divergent reste
  specifique tant que sa verite externe n'est pas prouvee.

- [x] **Step 4: Verifier la couverture**

  Chaque cible produite par les anciens installateurs doit avoir une ligne dans
  l'inventaire. Le meme inventaire sera rejoue avant et apres la bascule pour
  detecter toute perte.

- [x] **Step 5: Verifier et committer**

  ```bash
  git diff --check
  git add docs/deployment-inventory.md \
    docs/reviews/2026-08-15-plan-review-claude.md \
    docs/superpowers/plans/2026-08-15-agent-config-consolidation.md
  git commit -m "docs: inventory the legacy deployment surface"
  ```

### Task 1: Figer la provenance et la classification des donnees

**Files:**

- Create: `docs/migration-sources.md`
- Create: `README.md`

**Interfaces:**

- Consumes: les trois commits et listes de changements locaux consignes dans
  l'etat de depart ci-dessus.
- Produces: une decision `adopt`, `ignore` ou `defer` pour chaque changement
  local; aucun import ulterieur ne peut commencer sans cette classification.

- [x] **Step 1: Capturer un inventaire reproductible**

  Executer pour chaque depot source :

  ```bash
  git -C <repo> rev-parse HEAD
  git -C <repo> status --short
  git -C <repo> remote -v
  ```

  Reporter les sorties dans `docs/migration-sources.md`, avec la date et le
  chemin source. Ne copier aucune valeur de credential ou de fichier runtime.

- [x] **Step 2: Classer les modifications locales**

  Examiner les diffs cibles avec `git diff -- <path>`. Pour chaque fichier,
  consigner une des decisions suivantes et sa justification :

  - `adopt`: importer ce contenu dans `agent-config`;
  - `ignore`: conserver seulement la version commitee de reference;
  - `defer`: laisser le fichier specifique jusqu'a obtention d'une preuve
    runtime.

  `skills/openclaw/SKILL.md` doit rester `defer` tant que la VM Nestor n'a pas
  prouve la valeur effective du heartbeat.

- [x] **Step 3: Verifier l'absence de secrets dans les sources candidates**

  Lister les noms de champs sensibles, sans afficher leurs valeurs :

  ```bash
  rg -n --glob '*.json' --glob '*.toml' --glob '*.yaml' --glob '*.yml' \
    'token|secret|password|credential|api[_-]?key' \
    /home/cyril/src/{claude-config,codex-config,kimi-config}
  ```

  Toute occurrence reelle doit etre exclue ou remplacee par une reference a une
  variable d'environnement avant import.

- [x] **Step 4: Documenter le statut transitoire du depot**

  Ajouter au `README.md` que `agent-config` est en migration, qu'il n'a pas de
  remote et que les anciens installateurs restent autoritatifs jusqu'au gate de
  deploiement reel de Task 8.

- [x] **Step 5: Verifier et committer**

  ```bash
  git diff --check
  git status --short
  git add README.md docs/migration-sources.md
  git commit -m "docs: preserve migration provenance before consolidation"
  ```

### Task 2: Creer le squelette multi-harness sans changer le runtime

**Files:**

- Create: `instructions/common.md`
- Create: `harnesses/{claude,codex,kimi,opencode}/instructions.overlay.md`
- Create: `shared/{assets,scripts,skills}/.gitkeep`
- Create: les fichiers de `harnesses/codex/` par import du commit Codex de reference
- Create: `AGENTS.md`
- Modify: `README.md`

**Interfaces:**

- Consumes: la classification de Task 1.
- Produces: l'arborescence cible et des chemins stables pour l'installateur;
  aucun fichier sous les homes utilisateur n'est modifie.

- [x] **Step 1: Ecrire un test de structure en echec**

  Ajouter a `tests/test-install.sh` des assertions `test -e` pour chaque racine
  de l'arborescence cible et `test ! -e global/AGENTS.md` apres migration.

- [x] **Step 2: Verifier l'echec du test**

  ```bash
  bash tests/test-install.sh
  ```

  Attendu : echec sur la premiere racine cible absente, avant tout deploiement.

- [x] **Step 3: Importer la configuration Codex**

  Importer depuis le commit Codex de reference les fichiers classes `adopt`, y
  compris `install.sh`, `update.sh` et les tests existants. Les ajouter comme de
  nouveaux fichiers dans l'historique propre a `agent-config`, puis ajuster
  leurs chemins vers `harnesses/codex/` sans changer les destinations runtime.
  Consigner le commit source dans `docs/migration-sources.md`.

- [x] **Step 4: Creer les racines Claude, Kimi et OpenCode**

  Importer seulement les fichiers classes `adopt`. Pour chaque ancien depot,
  utiliser un ajout Git normal et consigner le commit source dans
  `docs/migration-sources.md`; ne pas presenter cet import comme un `git mv`
  inter-repositories.

- [x] **Step 5: Verifier et committer**

  ```bash
  bash -n install.sh update.sh tests/*.sh harnesses/codex/scripts/*.sh
  bash tests/test-install.sh
  bash tests/test-hooks.sh
  git diff --check
  git add -A
  git commit -m "refactor: establish explicit harness ownership"
  ```

### Task 3: Deployer les huit skills portables depuis le hub

**Files:**

- Move: les huit skills identiques de `harnesses/codex/skills/` vers
  `shared/skills/`
- Modify: `install.sh`
- Modify: `tests/test-install.sh`

**Interfaces:**

- Consumes: `shared/skills/<name>` et `harnesses/<harness>/skills/<name>`.
- Produces: `deploy_shared_skills`, qui reconcilie les liens Linux/WSL et les
  copies Windows; erreur avant mutation sur tout doublon shared/specific.

- [x] **Step 1: Ecrire les tests de routage en echec**

  Dans un home temporaire, verifier :

  - lien partage sous `~/.agents/skills/api-design`;
  - lien miroir sous `~/.claude/skills/api-design`;
  - absence de `~/.codex/skills/api-design`;
  - maintien d'un skill Codex specifique sous `~/.codex/skills/codex-config`;
  - preservation d'un repertoire etranger non gere dans le hub;
  - purge d'un ancien lien gere retire de la source;
  - echec sans mutation si un meme nom est shared et specifique;
  - copie reelle, non symlink, dans le home Codex Windows temporaire.
  - parite de l'arbre complet de chaque skill promu, pas seulement de
    `SKILL.md`.
  - miroir natif OpenCode sans skill provenant de `~/.claude/skills` lorsque
    son environnement gere est charge.

- [x] **Step 2: Verifier l'echec cible**

  ```bash
  bash tests/test-install.sh
  ```

  Attendu : les assertions du hub et du miroir Claude echouent avec
  l'installateur actuel.

- [x] **Step 3: Implementer la reconciliation declarative**

  Remplacer le prune historique du hub par un calcul de l'ensemble desire.
  Supprimer uniquement les symlinks casses ou pointant dans `agent-config` dont
  le nom n'est plus desire. Preserver les fichiers, repertoires et liens tiers.
  Creer ensuite les liens/copies manquants.

- [x] **Step 4: Deplacer uniquement les skills prouves identiques**

  Deplacer `api-design`, `deployment`, `grill-with-docs`, `mvp`,
  `nvim-config`, `stack-python`, `stack-rust` et `stack-ts`. Garder les quatre
  skills divergents dans les racines specifiques, sans arbitrage implicite.

- [x] **Step 5: Verifier et committer**

  ```bash
  bash tests/test-install.sh
  bash -n install.sh tests/*.sh
  uv run tests/validate-skills.py shared/skills
  git diff --check
  git commit -am "refactor: make portable skills single-source"
  ```

### Task 4: Composer les instructions communes et les overlays

**Files:**

- Modify: `instructions/common.md`
- Modify: `harnesses/*/instructions.overlay.md`
- Modify: `install.sh`
- Create: `tests/test-instructions.sh`

**Interfaces:**

- Consumes: un fichier commun et exactement un overlay.
- Produces: `render_instructions HARNESS TARGET`, qui ecrit atomiquement
  `common + newline + overlay` vers la cible native.

- [x] **Step 1: Ecrire les tests du renderer en echec**

  Verifier sous home temporaire :

  - ordre exact socle puis overlay;
  - une seule occurrence du titre global;
  - absence de marqueur de template;
  - sortie inchangee lors d'un second rendu;
  - echec sans ecrasement si le harness est inconnu;
  - `--check` non-zero apres modification manuelle du fichier deploye.
  - bandeau `Fichier genere - modifier agent-config` dans chaque rendu;
  - echec de `--check` si `~/.agents/AGENTS.md` existe, sans suppression.

- [x] **Step 2: Extraire conservativement le socle**

  Placer dans `common.md` seulement les politiques semantiquement identiques :
  exploration, question en cas d'ambiguite, minimalisme, tests, preuve
  d'execution, Git et stacks. Deplacer entierement dans les overlays les
  sections qui nomment des commandes, modeles, sous-agents, outils, mecanismes
  de contexte, memoire, RTK ou auto-amelioration propres au harness.
  Inliner le contenu actuel de `RTK.md` dans l'overlay Claude et retirer
  l'import `@RTK.md`.

- [x] **Step 3: Interdire les contradictions**

  Reformuler une politique commune en terme neutre si un harness doit la
  specialiser. Ne jamais conserver une regle dans `common.md` puis ajouter son
  contraire dans un overlay. Ajouter au test une liste des titres qui ne
  doivent apparaitre qu'une fois dans chaque rendu.

- [x] **Step 4: Implementer le rendu atomique**

  Rendre dans un fichier temporaire place pres de la cible, comparer avec la
  cible existante, sauvegarder une cible non geree si necessaire, puis utiliser
  `mv` pour l'installation finale. En mode `--check`, ne rien ecrire.

- [x] **Step 5: Verifier les quatre rendus et committer**

  ```bash
  bash tests/test-instructions.sh
  bash tests/test-install.sh
  bash -n install.sh tests/*.sh
  git diff --check
  git commit -am "refactor: compose global instructions without templates"
  ```

### Task 5: Ajouter les adaptateurs Claude, Kimi et OpenCode

**Files:**

- Modify: `install.sh`
- Modify: `harnesses/claude/settings.json`
- Modify: `harnesses/kimi/config.toml`
- Modify: `harnesses/kimi/tui.toml`
- Modify: `harnesses/kimi/mcp.json`
- Create: `harnesses/opencode/opencode.json`
- Modify: `tests/test-install.sh`

**Interfaces:**

- Consumes: `install_harness claude|codex|kimi|opencode`.
- Produces: quatre deploiements independants selectionnables par
  `./install.sh --only <harness>`.

- [x] **Step 1: Classifier la mutabilite de chaque fichier**

  Pour chaque fichier, documenter dans `README.md` une strategie parmi :

  - `link`: l'application ne le reecrit pas;
  - `copy`: la source remplace la cible apres sauvegarde;
  - `merge`: seules les cles declaratives gerees sont remplacees;
  - `seed-only`: creer uniquement si la cible n'existe pas.

  Les credentials, caches, sessions et etats de trust sont toujours `ignore`.
  `settings.json` Claude et `config.toml` Kimi sont `merge`, car les
  applications les reecrivent. Documenter explicitement les cles source-owned
  et runtime-owned avant d'implementer la fusion.

- [x] **Step 2: Ecrire les tests de selection en echec**

  Executer chaque `--only` dans un home temporaire et verifier qu'aucun fichier
  d'un autre harness n'est cree ou modifie. Ajouter une fixture de fichier
  mutable contenant une cle runtime inconnue et verifier sa preservation pour
  toute strategie `merge`.

- [x] **Step 3: Implementer le dispatcher**

  Le parseur accepte exactement `--only`, `--check`, `--dry-run` et `--help`.
  Une valeur ou option inconnue termine non-zero avant mutation. Sans `--only`,
  deployer les quatre harnesses dans un ordre fixe documente.
  Deployer les scripts Claude et Kimi sous leurs homes natifs et remplacer dans
  les configurations tous les chemins vers les anciens depots. Les scripts de
  notification utilisent l'asset deploye, jamais son ancien chemin source.

- [x] **Step 4: Conserver les surfaces Claude externes**

  Reprendre `ccstatusline`, commands, agents et le submodule Anthropic avec son
  allowlist de huit skills. Ne supprimer aucune capacite existante sans decision
  explicite dans `docs/deployment-inventory.md`.

- [x] **Step 5: Mettre OpenCode sous gestion declarative**

  Importer `~/.config/opencode/opencode.json` seulement apres comparaison avec
  la documentation et exclusion de tout secret. Sauvegarder le fichier runtime
  existant lors du premier deploiement; ne pas le modifier pendant les tests
  sous home temporaire. Desactiver la compatibilite des skills Claude via le
  bloc gere de `~/.profile.local`, puis verifier avec le binaire reel que seuls
  les huit miroirs natifs sont exposes.

- [x] **Step 6: Verifier et committer**

  ```bash
  bash tests/test-install.sh
  bash tests/test-instructions.sh
  bash tests/test-hooks.sh
  bash -n install.sh update.sh tests/*.sh harnesses/*/scripts/*.sh
  git diff --check
  git commit -am "feat: deploy four harnesses from one repository"
  ```

### Task 6: Preserver le contrat Codex Windows et les fichiers mutables

**Files:**

- Modify: `install.sh`
- Modify: `tests/test-install.sh`
- Create: `tests/fixtures/windows-config.toml`

**Interfaces:**

- Consumes: `CODEX_CONFIG_WINDOWS_DIR` et la classification de mutabilite.
- Produces: copies reelles des artefacts geres; preservation stricte d'un
  `config.toml` Windows existant.

- [x] **Step 1: Etendre la fixture Windows**

  Inclure dans la fixture des sections runtime representatives : `[desktop]`,
  un plugin Chrome, Computer Use et une section inconnue. Le test doit comparer
  le hash du fichier avant et apres installation.

- [x] **Step 2: Tester la premiere installation et la mise a jour**

  Verifier que les instructions, skills, agents, rules, scripts et assets sont
  des fichiers/repertoires reels cote Windows. Verifier que `config.toml` est
  cree en seed-only lorsqu'il manque et laisse byte-identique lorsqu'il existe.

- [x] **Step 3: Executer deux installations consecutives**

  Comparer l'arbre, les types de fichiers et les hashes apres chaque execution.
  La seconde execution ne doit creer aucune sauvegarde supplementaire ni
  changer le resultat.

- [x] **Step 4: Verifier et committer**

  ```bash
  bash tests/test-install.sh
  bash -n install.sh tests/*.sh
  git diff --check
  git commit -am "fix: preserve native Windows runtime ownership"
  ```

### Task 7: Implementer les modes de controle sans mutation

**Files:**

- Modify: `install.sh`
- Create: `tests/test-check.sh`
- Modify: `README.md`

**Interfaces:**

- Consumes: le meme graphe source-cible que l'installation normale.
- Produces: `--dry-run`, qui affiche les actions sans ecrire, et `--check`, qui
  retourne zero uniquement lorsque toutes les cibles classees sont conformes.

- [x] **Step 1: Ecrire les tests de non-mutation en echec**

  Capturer les hashes et types de l'arbre temporaire avant et apres `--dry-run`
  puis `--check`. Les deux modes doivent laisser l'arbre byte-identique.

- [x] **Step 2: Definir les controles de `--check`**

  Verifier : rendus d'instructions, destinations et types des skills, absence de
  doublons, liens casses, fichiers copies, JSON/TOML parsables, executabilite
  des hooks, matrice MCP documentee et preservation des fichiers app-owned.
  Chaque divergence imprime une ligne `DRIFT <harness> <target> <reason>`.
  Verifier aussi l'absence de `~/.agents/AGENTS.md` et des anciens noms de depot
  dans tout artefact gere ou script deploye.

- [x] **Step 3: Implementer un plan d'actions partage**

  Construire les actions une seule fois, puis utiliser un backend `apply`,
  `print` ou `compare`. Ne pas maintenir trois parcours independants qui
  pourraient diverger.

- [x] **Step 4: Verifier et committer**

  ```bash
  bash tests/test-check.sh
  bash tests/test-install.sh
  bash tests/test-instructions.sh
  bash tests/test-hooks.sh
  bash -n install.sh update.sh tests/*.sh harnesses/*/scripts/*.sh
  git diff --check
  git commit -am "feat: detect configuration drift without mutation"
  ```

### Task 8: Valider la bascule puis preparer l'archivage

**Files:**

- Modify: `README.md`
- Modify: `docs/migration-sources.md`

**Interfaces:**

- Consumes: un depot propre, tous les tests verts et quatre installations
  temporaires conformes.
- Produces: preuve de validation reelle et une decision humaine separee pour
  l'archivage; aucune suppression automatique.

- [ ] **Step 1: Executer le gate local complet**

  ```bash
  bash tests/test-install.sh
  bash tests/test-instructions.sh
  bash tests/test-hooks.sh
  bash tests/test-check.sh
  bash -n install.sh update.sh tests/*.sh harnesses/*/scripts/*.sh
  git diff --check
  ```

- [ ] **Step 2: Tester les homes temporaires avec les binaires reels**

  Pour chaque harness installe, verifier la decouverte des instructions et des
  skills sans appel modele lorsque le CLI offre une commande de debug. Consigner
  la version du binaire et la commande exacte dans `docs/migration-sources.md`.

- [ ] **Step 3: Demander l'autorisation de deploiement reel**

  Presenter le diff, les sauvegardes prevues et les quatre destinations. Ne pas
  executer `./install.sh` sur les homes reels sans validation explicite.

- [ ] **Step 4: Neutraliser les anciens installateurs pendant la bascule**

  Ajouter avant la bascule une garde inactive aux anciens `install.sh` et
  `update.sh`. Activer atomiquement un marqueur de migration juste avant le
  premier deploiement reel. Le simple retrait du bit executable est insuffisant,
  car `bash install.sh` le contourne. Documenter le retrait du marqueur comme
  premiere etape du rollback.

- [ ] **Step 5: Observer deux cycles reels**

  Apres chaque deploiement autorise, utiliser normalement les quatre harnesses,
  puis executer `./install.sh --check`. Toute derive non classee bloque
  l'archivage et doit etre comprise avant modification.

- [ ] **Step 6: Publier le nouveau depot**

  Creer ou selectionner le remote seulement apres validation du nom et de la
  visibilite. Verifier que le remote ne pointe pas vers `codex-config`, puis
  pousser sans force.

- [ ] **Step 7: Proposer l'archivage separement**

  Fournir les derniers SHA, remotes et changements locaux de `claude-config`,
  `codex-config` et `kimi-config`. Attendre une nouvelle autorisation avant de
  les rendre read-only, de les deplacer ou de les supprimer.

- [ ] **Step 8: Commit de documentation final**

  ```bash
  git add README.md docs/migration-sources.md
  git commit -m "docs: record verified multi-harness cutover"
  ```

---

## Reconciliations ulterieures

Les quatre skills divergents forment des decisions independantes. Pour chacun :

1. comparer les variantes et identifier les differences semantiques;
2. verifier la verite externe ou runtime lorsqu'elle existe;
3. produire une version portable sans noms de commandes propres au harness, ou
   conserver des variantes si cette neutralisation rend le skill moins clair;
4. lancer le validateur de skill sur chaque destination;
5. promouvoir vers `shared/skills` seulement lorsque les variantes sont
   semantiquement equivalentes.

Pour `openclaw`, la VM Nestor et son deploiement Ansible ont priorite sur les
deux documents actuels. Ni `30 min` ni `4 h` ne doit etre choisi par majorite de
fichiers.

MCP et hooks restent natifs tant que leur duplication n'a pas produit une
seconde derive significative. A partir d'environ six serveurs MCP ou d'une
procedure de reconciliation repetee, reevaluer un manifeste commun. Pour les
hooks, partager uniquement un coeur deterministe et garder un adaptateur de
payload/reponse par harness.

## Estimation et checkpoints

| Lot | Contenu                                          |               Estimation | Gate de revue                                     |
| --- | ------------------------------------------------ | -----------------------: | ------------------------------------------------- |
| A   | provenance, squelette, huit skills, instructions |                    2-3 h | aucun deploiement reel                            |
| B   | adaptateurs, OpenCode, Windows, controles        |                    3-4 h | homes temporaires conformes                       |
| C   | bascule reelle et observation                    | 1 h active + observation | validation humaine avant deploiement et archivage |

L'execution reste inline par defaut. Les Tasks 3, 4 et 5 ne doivent pas etre
parallellisees car elles modifient toutes `install.sh`; le plan est donc
sequentiel par construction.

## Questions explicites pour la relecture Claude

1. Le rendu uniforme `common + overlay` evite-t-il bien toute dependance cachee
   aux precedences d'instructions des quatre harnesses ?
2. Une politique actuellement commune devrait-elle rester specifique parce que
   sa formulation cite implicitement une capacite d'un harness ?
3. La classification `link`, `copy`, `merge`, `seed-only`, `ignore` couvre-t-elle
   tous les fichiers que Claude Code ou Kimi reecrivent actuellement ?
4. Existe-t-il un skill suppose identique dont les assets, scripts ou references
   relatives different hors de `SKILL.md` ?
5. Une etape du plan pourrait-elle supprimer ou ecraser un artefact non gere,
   notamment dans `~/.agents/skills` ou les homes Windows ?
6. Quelle preuve runtime manque encore avant de considerer les deux premiers
   cycles de deploiement comme valides ?
