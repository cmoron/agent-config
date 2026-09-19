# agent-config

Source declarative unique des configurations Codex, Claude Code, OpenCode et
Kimi Code de Cyril. Les homes runtime sont produits par `install.sh` ; les
modifications se font ici.

## Organisation

| Chemin                                | Contenu                                                          |
| ------------------------------------- | ---------------------------------------------------------------- |
| `instructions/`                       | Socle comportemental commun, compose avec un overlay par harness |
| `harnesses/<name>/`                   | Configurations et adaptations natives                            |
| `shared/skills/`                      | Skills locaux, chacun en un seul exemplaire                      |
| `shared/scripts/` et `shared/assets/` | Actions de hooks et son communs                                  |
| `upstreams/`                          | Skills Matt Pocock en sous-module et selection complementaire    |
| `scripts/`                            | Outils de maintenance du depot                                   |
| `tests/`                              | Controles sous homes temporaires                                 |

Les skills Anthropic sont un sous-module sous `harnesses/claude/upstream/`.
Les credentials, sessions, caches et memoires natives restent hors Git.

## Installer et verifier

Prerequis : Bash >= 4, Python >= 3.11 avec `tomllib`, Git et `jq`.
Sur macOS, l'installateur cherche Bash dans les emplacements Homebrew et un
Python compatible sur le PATH ; `AGENT_CONFIG_PYTHON` force cet interpreteur.
La mise a jour et les controles Python utilisent `uv` et `pyproject.toml`.

```bash
# Initialiser les revisions de skills epinglees par Git.
git submodule update --init --recursive

# Examiner les changements, appliquer, puis verifier la derive.
./install.sh --dry-run
./install.sh
./install.sh --check
```

`--only codex|claude|opencode|kimi` limite la cible.
`--instructions-only` ne rend que les instructions ; il se combine avec
`--only`, `--dry-run` et `--check`. Son controle ne couvre que ces fichiers.
`AGENT_CONFIG_SKIP_PLUGINS=1` desactive les bootstraps de plugins pendant une
installation. Les sauvegardes precedent le remplacement des fichiers tiers.

Les fichiers reecrits par les applications sont copies ou fusionnes, jamais
symlinkes vers Git. Codex Windows recoit de vrais fichiers et conserve son
`config.toml` existant s'il est un fichier regulier, sans lien symbolique.
Les contrats precis et les chemins de sauvegarde sont
dans l'[inventaire de deploiement](docs/deployment-inventory.md).

## Mettre a jour

```bash
# Actualiser les sous-modules et tester, sans deployer.
uv run scripts/update_upstreams.py --no-install

# Actualiser aussi le depot principal, tester puis installer.
./update.sh
```

La mise a jour installe par defaut. Ses options `--dry-run` et `--check`
concernent uniquement l'installation : elles n'empechent pas la mise a jour Git.
Le [guide des scripts](scripts/README.md) detaille les options et les echecs.

## Contribuer

Lire [AGENTS.md](AGENTS.md), modifier les sources, puis executer :

```bash
bash tests/run-all.sh
git diff --check
```

La [procedure de validation](docs/configuration-validation.md) precise les
controles CLI, la portabilite et les comparaisons de comportement avec modele.
Les tests ne deploient pas dans les homes reels.

`instructions/common.md` et les overlays definissent aussi le workflow global
Pocock/Superpowers/autoship. Les fichiers `docs/agents/*.md` d'un projet peuvent
le completer ; l'installateur ne cree rien dans ces projets.

## Documentation operationnelle

- [Inventaire de deploiement](docs/deployment-inventory.md) : sources, cibles,
  proprietaires et invariants.
- [Hooks](docs/hooks.md) : protocoles, erreurs, dependances et limites.
- [Scripts de maintenance](scripts/README.md) : mise a jour, verrou legacy et
  fusion Kimi.
- [Validation](docs/configuration-validation.md) : preuves et limites des tests.

Les anciens depots `claude-config`, `codex-config` et `kimi-config` restent
inactifs derriere le marqueur `~/.config/agent-config/active`. Le
[guide des scripts](scripts/README.md#gerer-le-verrou-des-anciens-depots) explique
sa gestion ; le retirer ne restaure aucune configuration. Leur archivage reste
soumis a validation explicite. Les plans et audits termines sont conserves dans
l'historique Git, sans copie dans la documentation courante.
