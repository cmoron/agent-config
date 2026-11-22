---
name: agent-config
description: Use when modifying Cyril's shared Claude Code, Codex, OpenCode, or Pi configuration in ~/src/agent-config.
---

# Agent Config

`~/src/agent-config` est l'unique source declarative. Ne pas maintenir
directement `~/.claude`, `~/.codex`, `~/.agents`, `~/.config/opencode` ou
`~/.pi/agent`.

## Placement

- `instructions/common.md` : comportement reellement commun.
- `harnesses/<name>/instructions.overlay.md` : capacites propres au harness.
- `shared/skills` et `shared/assets` : **tous** les skills et assets. Un skill
  vit ici, en un seul exemplaire, meme s'il ne sert qu'a un harness.
- `harnesses/<name>/` : config, hooks, commands, agents et scripts natifs.
- Les fichiers globaux deployes sont generes; ne jamais editer le rendu.

## Un seul exemplaire par skill

macOS contre WSL est un axe **environnement**, pas un axe harness : les quatre
harnais tournent sur les deux machines. Un skill n'est donc jamais duplique par
harness. Quand une portion depend reellement du harness, elle s'ecrit **dans le
fichier unique** — une phrase, un tableau, une section « selon le harness » —
jamais par un fork de fichier.

Le fork est la panne, pas la solution : trois copies d'`opensource-contributor`
avaient diverge au point que l'une avait perdu une etape obligatoire entiere.

`harnesses/<name>/skills/` reste supporte par l'installateur comme echappatoire,
mais doit rester vide. Y deposer un skill demande une justification ecrite dans
`docs/deployment-inventory.md`.

## Workflow

1. Lire `docs/deployment-inventory.md` et les sources concernees.
2. Modifier le minimum dans ce depot.
3. Ecrire le test qui fixe le contrat, puis observer son echec. Une assertion
   par ligne : sous `set -e`, `[ A ] && [ B ]` ne fait pas echouer le script
   quand `A` est faux, seul le dernier maillon de la liste compte. Un test qui
   passe avant l'implementation est une assertion sans effet, pas un succes.
4. Implementer et lancer `bash tests/run-all.sh`.
5. Utiliser `./install.sh --dry-run`, puis `--check`.
6. La bascule est faite : le marqueur `~/.config/agent-config/active` desactive
   les installateurs legacy. Rollback = `scripts/cutover-marker.sh deactivate`
   avant toute restauration.

## Portabilite

Le depot est deploye sur WSL **et** macOS. Un outil GNU dans `install.sh` ou les
tests casse le Mac en silence : `stat -c`, `realpath -m`, `tar --sort`, `wc -l`
compare avec `=`, `mapfile`, `declare -A`, `tomllib` sous python 3.9. Choisir le
fallback par probe, jamais par `uname`. `bash tests/run-all.sh` sur macOS est la
seule preuve.

Un fichier app-owned se compare **semantiquement**, pas octet a octet, et les
cles que l'application ecrit dans une section source-owned se preservent
explicitement. Sans ca `--check` derive a chaque execution : Claude reordonne
`settings.json`, Codex tamponne `last_updated`/`last_revision` dans
`[marketplaces.*]`.

## Diffusion des skills

| Harness  | Lit                                    | Consequence                                   |
| -------- | -------------------------------------- | --------------------------------------------- |
| Claude   | `~/.claude/skills` uniquement          | les skills partages y sont miroires par liens |
| Codex    | `~/.agents/skills` + `~/.codex/skills` | le hub suffit; ne rien dupliquer              |
| OpenCode | `~/.config/opencode/skills`            | miroir natif; la 2.x lit aussi le hub         |
| Pi       | `~/.agents/skills`                     | le hub, deploye avec `--only pi`              |

Le skill Anthropic allowliste (`webapp-testing`) reste un submodule Claude-only.

## Par harness

| Harness  | Instructions rendues           | Config                             | Particularite                                                   |
| -------- | ------------------------------ | ---------------------------------- | --------------------------------------------------------------- |
| Claude   | `~/.claude/CLAUDE.md`          | `settings.json` fusion JSON        | cles declaratives source-owned, cles runtime preservees         |
| Codex    | `~/.codex/AGENTS.md`           | `config.toml` copie                | preserve `[hooks.state]`, `[projects]` et l'etat marketplace    |
| OpenCode | `~/.config/opencode/AGENTS.md` | `opencode.json` copie `0600`       | bloc d'env gere dans `~/.profile.local`                         |
| Pi       | `~/.pi/agent/AGENTS.md`        | `settings.json` fusion JSON `0600` | manifeste de cles, extensions copiees, paquets installes par pi |

Les hooks referencent toujours les scripts deployes sous le home du harness,
jamais un chemin du depot. La cible Codex Windows recoit de vrais fichiers et son
`config.toml` existant est app-owned.

Une auto-amelioration globale cible `instructions/common.md` ou l'overlay du
harness, jamais le fichier genere.

Tout ajout/retrait de skill, hook, plugin, MCP ou cible de copie met a jour dans
le meme commit `README.md`, l'inventaire et les tests correspondants.
