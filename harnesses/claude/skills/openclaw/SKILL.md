---
name: openclaw
description: Pour travailler sur Nestor/openclaw : VM NAS locale (openclaw-vm), configuration du service, workspace de l'agent, mémoire, heartbeat et cron, skills, déploiement via Ansible. Couvre aussi la cohabitation avec Hermes sur la même VM (~/.hermes), à ne pas confondre.
---

# Openclaw — Nestor

Nestor est un assistant IA personnel tournant sur une VM KVM locale (NAS), accessible via Telegram.
Ce skill fournit le contexte nécessaire pour le maintenir et le faire évoluer.

## Qu'est-ce qu'OpenClaw

[OpenClaw](https://github.com/openclaw/openclaw) (MIT, ex-Clawdbot/Moltbot, créé par
Peter Steinberger) est une plateforme open-source **auto-hébergée** qui transforme un
LLM en agent personnel persistant et autonome, accessible via messagerie.
**Nestor est une instance d'OpenClaw** — l'agent IA personnel de Cyril. Modifier Nestor,
c'est configurer une instance de ce projet ; les concepts ci-dessous sont ceux d'OpenClaw.

### Architecture (hub-and-spoke)

Un processus **Gateway** unique au centre, en 4 couches :

1. **Channel adapters** — normalisent les entrées des canaux de messagerie (Telegram,
   WhatsApp, Slack, Discord…). Nestor n'utilise que **Telegram**.
2. **Gateway / control plane** — serveur WebSocket Node.js : routage des messages,
   gestion des sessions, mapping canal → workspace → modèle.
3. **Agent runtime** — assemble le contexte (historique, prompts, skills) et exécute la
   **boucle agentique** : recevoir le contexte → appeler le LLM → exécuter les tools →
   observer le résultat → répondre.
4. **Tools & exécution** — shell, fichiers, navigateur, emails ; optionnellement isolés
   en sandbox Docker pour limiter le blast radius.

Model-agnostic : on fournit ses propres clés API (cf. § Modèles IA).

### Concepts clés

- **Workspace** — répertoire de fichiers Markdown, source de vérité de l'agent. À chaque
  tour, le runtime compose le system prompt à partir de `SOUL.md` (personnalité),
  `AGENTS.md` (manuel opératoire / règles), l'historique de session et les skills pertinents.
- **Skills** — playbooks `SKILL.md` à frontmatter YAML, **lazy-loaded** : seul le metadata
  est lu en permanence, le contenu complet n'est chargé que si la tâche matche le skill
  (même principe d'économie de tokens que les skills Claude Code).
- **Heartbeat** — tours d'agent **périodiques** déclenchés sans message utilisateur, pour
  vérifier proactivement des tâches (Nestor : toutes les 30 min, 08h-22h30). Checklist
  dans `HEARTBEAT.md`.
- **Mémoire** — hybride : fichiers Markdown durables, indexés en SQLite à la fois en
  plein-texte et en vectoriel (cf. § Mémoire).
- **MCP** — OpenClaw peut se connecter à des services externes via Model Context Protocol.

Le mapping concret de ces concepts sur l'instance Nestor est détaillé ci-dessous.

## Accès

- **VM** : `cyril@192.168.122.100` via ProxyJump `nas` — ou `ssh -J nas cyril@192.168.122.100`
- **Ansible** : `~/src/openclaw/ansible/` (inventaire + playbooks de déploiement)
- **Config sur VM** : `~/.openclaw/`
- **Service** : `systemctl --user status openclaw-gateway`
- **VNC** : `vnc-openclaw.home.moron.at` (pour Chrome manuel si besoin)

## ⚠️ La VM héberge deux agents, pas un

`~/.openclaw` (Nestor) et `~/.hermes` (Hermes) cohabitent sur la même VM et n'ont **rien
en commun**. Tout le reste de ce skill vaut pour Nestor uniquement.

| | Nestor | Hermes |
|---|---|---|
| Conf | `~/.openclaw/openclaw.json` + `workspace/` | `~/.hermes/config.yaml` + `SOUL.md`, `memories/`, `skills/`, `cron/jobs.json` |
| Runtime | Node — `openclaw update`, plugins npm | venv Python — `hermes-agent/venv/bin/python -m hermes_cli.main gateway run` |
| Services | `openclaw-gateway` | `hermes-gateway`, `hermes-webui`, `hermes-backup.timer` |
| Autonomie | heartbeat 30 min + cron | cron uniquement (`cron/jobs.json`) |
| Mémoire | md + index **FTS et vectoriel** par agent | md bornés + **FTS seul** (standard + trigramme) |
| Rôle | assistant personnel | opérateur DecaSaaS / MyPacer |

**N'applique jamais `openclaw update` / `openclaw plugins` à Hermes** — runtime différent.

⚠️ `hermes-backup.timer` committe et pousse `~/.hermes` chaque nuit à 02:30. Une édition
manuelle de la conf part au prochain tick, y compris une édition ratée.

Autres services sur la VM, hors périmètre de ce skill : `openclaw-studio`,
`openclaw-admin-test`, `paperclip`, `obsidian-sync-cyril`.

## Architecture du service

```
~/.openclaw/
├── openclaw.json          # Config principale (modèles, agents, canaux, heartbeat)
├── .env                   # Clefs API, tokens (ne jamais committer)
├── state/openclaw.sqlite  # État du gateway : cron_jobs, audit, sessions ACP…
├── agents/<id>/           # Un dossier par agent (main, ops, veille, cron, …)
│   ├── agent/openclaw-agent.sqlite   # Index mémoire de CET agent
│   └── sessions/          # Transcripts (11 k+ fichiers pour `main`)
└── workspace/             # Contexte injecté dans l'agent
    ├── SOUL.md            # Personnalité et règles de base
    ├── AGENTS.md          # Instructions de comportement et d'autonomie
    ├── BOOT.md            # Amorçage de session
    ├── IDENTITY.md        # Identité de l'agent
    ├── STYLE.md           # Conventions de rédaction
    ├── HEARTBEAT.md       # Tâches des checks périodiques
    ├── TOOLS.md           # Infos setup : comptes, profils, CLIs disponibles
    ├── USER.md            # Profil Cyril + contacts autorisés (Estelle)
    ├── MEMORY.md          # Mémoire persistante de Nestor
    ├── memory/            # Journaux quotidiens + long-term.md
    └── skills/            # 17 skills maison (cf. § Skills workspace)
```

Les agents `main`, `ops`, `veille`, `cron`, `mypacer-ceo` et `model-lab` partagent le
gateway mais ont chacun leur base mémoire. `agents/claude` et `agents/default` sont des
reliquats sans entrée dans `openclaw.json`.

## Mémoire

Trois couches, à ne pas confondre :

1. **Fichiers markdown** — `MEMORY.md`, `USER.md`, `SOUL.md`, `memory/long-term.md` et
   ~157 journaux `memory/AAAA-MM-JJ.md`. C'est la source de vérité éditable.
2. **Index hybride** (`agents/<id>/agent/openclaw-agent.sqlite`) — les fichiers sont
   découpés en chunks de 400 tokens (overlap 80) puis indexés **deux fois** : FTS5
   `unicode61` (lexical) **et** vectoriel (`text-embedding-3-small`, 1536 dims).
   C'est ce qui donne le rappel sémantique — Hermes, lui, n'a que du lexical.
3. **Transcripts de sessions** — fichiers dans `agents/<id>/sessions/`.

Le cron *Consolidation Mémoire* (23h) relit les journaux récents et réinjecte les
apprentissages stables dans `USER.md`, `SOUL.md` et `memory/long-term.md`.

## Modèles IA

- **Principal** : `openai/gpt-5.6-sol`, exécuté via le **runtime `codex`** (plugin openclaw)
- **Fallbacks** : `openai/gpt-5.6-luna`, `openrouter/free`
- **Heartbeat** : `openrouter/deepseek/deepseek-v4-flash` (modèle dédié, contexte léger)
- **`model-lab`** : `openai/gpt-5.5`, avec un runtime `ollama/glm-5.2:cloud`
- **Providers déclarés** : `ollama`, `nvidia`, `openrouter` (+ OpenAI via le runtime codex)

⚠️ Historique : Nestor a tourné sur Gemini. Si tu y reviens un jour, **ne pas prendre un
modèle « lite » comme principal** — il confond outils natifs et skills.

## Canaux

- **Telegram** — activé, canal réel. Cyril ID `1595199898`, Estelle ID `1344871168`
  (paired, accès limité — pas de tools).
- **WhatsApp** — `enabled: true` mais aucun `allowFrom` ni groupe : activé sans être utilisé.
- **Discord** — désactivé.

## Skills workspace

Les skills du registre intégré sont **tous désactivés** : tout passe par les 17 skills
maison de `workspace/skills/`.

| Domaine | Skills | Notes |
|---------|--------|-------|
| Google | `gog` (gmail, calendar), `gkeep` | `gog` = API, pas de browser ; `gkeep` = browser |
| Santé & sport | `strava`, `coros`, `withings`, `yazio`, `health-manager` | |
| Courses | `carrefour-shopping` | Browser CDP + Xvfb DISPLAY:1 requis |
| Musique | `tidal-cli`, `kapellmeister-playlist` | |
| Veille | `tech-veille`, `reddit-veille`, `x-bookmarks-watcher`, `ddg-search` | `tech-veille` **publie dans Docmost** |
| Rapports | `rapport-matinal` | |
| Divers | `brainstorm-team`, `command-center` | |

## Automatismes

- **Heartbeat** : toutes les **30 min**, 08:00–22:30 Europe/Paris, session isolée et
  contexte léger, sur son propre modèle. Checklist dans `workspace/HEARTBEAT.md`.
- **Cron** (stocké dans `state/openclaw.sqlite`, table `cron_jobs`) :

| Job | Quand | Agent | Livraison |
|-----|-------|-------|-----------|
| Rapport Matinal | 08:00 tous les jours | `cron` | Telegram |
| Tech Veille | 21:15 tous les jours | `veille` | Docmost + Telegram |
| Consolidation Mémoire | 23:00 tous les jours | `cron` | — (silencieux) |
| Bilan Hebdo Santé | dimanche 18:00 | `cron` | Telegram |
| Résumé Hebdo Estelle | lundi 08:00 | `cron` | Telegram |
| X Bookmarks Watcher | 21:00 | `veille` | **désactivé** |
| Reddit Veille | 21:30 | `veille` | **désactivé** |

## Chrome sur la VM NAS

Chrome tourne en service systemd permanent sur la VM (Ryzen 5 5600GT, 14 GB RAM, 3 vCPUs) :
- Xvfb + Chrome démarrent au boot, redémarrés automatiquement par systemd si crash
- Sessions Carrefour / Google Keep persistées dans le profil Chrome (`~/.openclaw/browser/chrome-profile`)
- Debug port : `9222` — display : `:1`
- En cas de problème de session : accès VNC via `vnc-openclaw.home.moron.at`

## Workflow de modification

1. Modifier les fichiers dans `~/src/openclaw/` (local)
2. Déployer via Ansible : `ansible-playbook -i ansible/inventory.yml ansible/playbooks/03-openclaw.yml`
3. Redémarrer si besoin : `ssh -J nas cyril@192.168.122.100 'systemctl --user restart openclaw-gateway'`
4. Vérifier : status + tester via Telegram

Pour les fichiers workspace (SOUL.md, AGENTS.md, etc.), les changements sont lus au prochain message sans redémarrage.

## Montées de version openclaw

**On NE met PAS à jour openclaw via `npm i -g openclaw`.** Le mécanisme canonique est la commande CLI **`openclaw update`** (l'historique de la VM est plein de `openclaw update`).

⚠️ Le `openclaw` du PATH interactif tape un **Node v18** → erreur *"Node v22+ required"*. Invoquer via Node v24 :
```bash
NODE=~/.nvm/versions/node/v24.13.1/bin/node
DIST=~/.nvm/versions/node/v24.13.1/lib/node_modules/openclaw
$NODE $DIST/dist/index.js update --dry-run        # prévisualiser
```

- **Canaux** : `--channel stable|beta|dev` (persisté dans `openclaw.json` → bloc `update`, vide = stable par défaut).
  - `stable` / `beta` → install **mode npm package** : `openclaw update` résout via le package manager, donc **limité à ce qui est publié** (la beta dist-tag peut pointer = stable). Notre install est en mode package (pas de `.git` dans le dist).
  - `dev` → **bascule en git checkout** (build depuis les sources GitHub) : seul moyen d'avoir du code pas encore packagé, mais bleeding-edge + rebuild à chaque update.
- `--tag <version|dist-tag|spec>` cible une version précise ; `--dry-run` prévisualise (montre `Target version` + l'action) ; `--no-restart`, `--yes`, `--timeout <s>`.
- `openclaw update status` (canal + versions) ; `openclaw update wizard` (interactif).
- **Plugins versionnés séparément** via `openclaw plugins install/update/uninstall` (codex, discord, whatsapp sont des plugins npm externes dans `~/.openclaw/npm/projects/`). Un plugin peut **exiger un runtime ≥ version** : ex. codex 0.139 vit dans `@openclaw/codex@2026.6.6-beta.1` qui exige openclaw runtime ≥2026.6.6-beta.1 — installer le plugin sur un runtime trop vieux est rejeté.
- Toujours redémarrer après via `openclaw gateway restart` (cf. règle restart), puis vérifier `gateway ready` + heartbeat/telegram dans les logs.

## Re-auth OAuth codex/OpenAI sur la VM headless (tunnel SSH)

La VM **n'a pas de navigateur utilisable** (Chrome sur Xvfb:1 via VNC seulement, pas de copier-coller). Le flow OAuth **par défaut** de codex (`codex login` / `openclaw models auth login --provider openai`) ouvre un serveur de callback sur **`localhost:<port>` de la VM** et y redirige après sign-in → il faut un navigateur qui « revient » sur la VM. Le flow **device** (`--device-code`) est censé éviter ça mais en pratique a posé souci (URL `https://auth.openai.com/codex/device` sans flux de code clair).

**Méthode fiable = forwarder le port de callback via SSH, ouvrir l'URL sur SON navigateur local :**
```bash
# 1. Depuis le laptop, ouvrir une session avec le port de callback forwardé
#    (codex écoute historiquement sur 1455 ; confirmer via le redirect_uri de l'URL affichée)
ssh -J nas -L 1455:localhost:1455 cyril@192.168.122.100

# 2. Dans cette session, lancer le login SANS --device-code (force le flow navigateur)
openclaw models auth login --provider openai --force        # --force vire le profil bloqué

# 3. Copier l'URL affichée, l'ouvrir dans le navigateur DU LAPTOP, se connecter
#    (cyril.moron@gmail.com), approuver.
# 4. La redirection part vers localhost:1455 → le tunnel la renvoie à la VM →
#    le terminal capte le callback et finit le login tout seul.
```
- Si l'URL contient `redirect_uri=http://localhost:XXXX` avec un **autre port**, refaire le `ssh -L XXXX:localhost:XXXX`.
- Codex 0.139 expose aussi `codex login --with-access-token` / `--with-api-key` (lecture sur stdin) si on récupère un token par un autre canal.
- Le flow par défaut imprime l'URL **et** écoute le port même sans navigateur sur la VM — donc le tunnel suffit, aucun navigateur VM requis.
- ⚠️ **`--force` SUPPRIME les autres profils du provider** : pour AJOUTER un 2e compte (ex. backup), login **SANS `--force`**. Pour repartir propre (token bloqué), `--force`.
- ⚠️ **Si le terminal ne rend pas la main** après "Authentication successful" navigateur (callback `localhost:port` qui n'atteint pas le listener) : l'auth est souvent **déjà persistée quand même** → `Ctrl-C` et vérifier avec un run test. Sinon, livrer le callback à la main : `curl "<url-de-redirection-copiée>"` **depuis la VM** (le listener tourne sur la VM:localhost:port).
- **Plusieurs profils valides = round-robin** par défaut. Pour forcer un ordre déterministe (ex. compte principal d'abord, backup en secours) : `openclaw models auth order set --agent <id> --provider openai <profil1> <profil2>` (persisté dans `auth-state.json`, `… order clear` pour revenir au round-robin).
- **Pourquoi re-auth** : la rotation des refresh-tokens OpenAI invalide les tokens (`token_invalidated` / `refresh_token_reused`) → seuls les comptes re-signés récemment marchent. Cf. `project_codex_oauth_warmup.md` dans la mémoire.
