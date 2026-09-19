# Scripts de maintenance du depot

Ce dossier contient les outils de mise a jour et de migration du depot. Les
hooks executes par les harnesses vivent dans `shared/scripts/` et
`harnesses/<name>/scripts/` ; leur documentation est dans
[docs/hooks.md](../docs/hooks.md).

| Script                      | Role                                                     | Qui l'appelle ?                               | Effets de bord                                                      |
| --------------------------- | -------------------------------------------------------- | --------------------------------------------- | ------------------------------------------------------------------- |
| `update_upstreams.py`       | Actualiser les skills externes, tester, puis installer   | `update.sh` ou toi via `uv run`               | Modifie les sous-modules et, par defaut, les configurations runtime |
| `cutover-marker.sh`         | Activer ou lever le verrou des anciens installateurs     | Toi, lors d'une bascule ou d'un rollback      | Cree/remplace/supprime un fichier marqueur                          |
| `legacy-installer-guard.sh` | Refuser un ancien installateur quand le verrou est actif | Les scripts des anciens depots, avec `source` | Aucun ; renvoie un refus                                            |
| `merge-kimi-config.awk`     | Fusionner la partie geree de la configuration Kimi       | `install.sh`, en interne                      | Ecrit le resultat sur stdout uniquement                             |

Les exemples suivants se lancent depuis la racine du depot.

## Mettre a jour les skills externes

`update_upstreams.py` gere les deux sous-modules declares dans `UPSTREAMS` :
les skills Anthropic pour Claude et les skills Matt Pocock partages. Il utilise
Git pour suivre les branches configurees dans `.gitmodules` (`main` actuellement).
Les dependances Python sont fournies par `uv` depuis `pyproject.toml`.

Son ordre d'execution est fixe :

1. Refuser les changements locaux dans les sous-modules, fichiers non suivis
   inclus. Les changements du depot principal produisent seulement un avertissement.
2. Synchroniser les URL Git, initialiser et actualiser les sous-modules.
3. Afficher les revisions avant/apres puis lancer `tests/run-all.sh`.
4. Si les tests passent, lancer `install.sh`, sauf avec `--no-install`.

```bash
# Lire l'aide, sans lancer de mise a jour.
uv run scripts/update_upstreams.py --help

# Actualiser les sources et les tester, sans deployer dans les homes runtime.
uv run scripts/update_upstreams.py --no-install

# Actualiser et tester toutes les sources, puis deployer seulement Codex.
uv run scripts/update_upstreams.py --only codex
```

**Sans option, le script installe.** `--dry-run` et `--check` concernent seulement
la derniere etape : les sous-modules sont reellement actualises et les tests
reellement executes avant la simulation ou le controle de derive. Ces deux
options sont exclusives ; comme `--only`, elles exigent que l'installation
reste active. `--verbose` affiche les commandes et leur sortie capturee.

Pour simuler uniquement le deploiement des sources courantes, utiliser
`./install.sh --dry-run`. Pour actualiser aussi le depot principal, `./update.sh`
commence par `git pull --ff-only`, puis appelle ce script avec les memes options.

Le script ne cree aucun commit et ne pousse rien. Un echec interrompt la suite
et conserve les changements deja faits : sous-modules actualises, eventuellement
en partie, ou installation partielle si celle-ci avait commence. Il n'y a pas de
rollback automatique. Le code de sortie d'une commande en echec est propage ;
une erreur d'usage renvoie 2, un sous-module sale renvoie 1.

## Gerer le verrou des anciens depots

Le marqueur par defaut est `~/.config/agent-config/active`. La variable
`AGENT_CONFIG_ACTIVE_MARKER` permet d'utiliser un autre chemin, notamment dans
les tests sous home temporaire. Les deux scripts doivent utiliser le meme chemin.

```bash
scripts/cutover-marker.sh status
scripts/cutover-marker.sh activate
# Seulement lors d'un retour volontaire aux anciens installateurs :
scripts/cutover-marker.sh deactivate
```

`activate` ecrit le chemin du depot dans le marqueur, puis le remplace par
renommage. `deactivate` retire le marqueur : cela autorise les anciens scripts,
mais ne restaure aucun fichier. `status` affiche `ACTIVE` avec le code 0 ou
`INACTIVE` avec le code 1. Les erreurs d'usage renvoient 2 ; une cible qui est
un repertoire est refusee par activation/desactivation avec le code 1.

Dans chaque ancien `install.sh` ou `update.sh`, le garde doit etre charge avant
toute modification :

```bash
source "$HOME/src/agent-config/scripts/legacy-installer-guard.sh" || exit $?
```

`legacy-installer-guard.sh` ne lit pas le contenu du marqueur : sa presence,
meme comme lien casse, suffit. Il renvoie 78 avec un message sur stderr si le
verrou est actif, sinon 0 sans sortie. Execute directement, il quitte avec le
meme code. Il ne protege que les anciens scripts qui le chargent.

## Comprendre la fusion Kimi

`install.sh` appelle `merge-kimi-config.awk` avec deux fichiers dans cet ordre :
la source declarative `harnesses/kimi/config.toml`, puis la configuration runtime
existante. Pour une premiere installation, il passe la source deux fois.

Le helper remplace les cles `default_permission_mode` et
`merge_all_available_skills`, ainsi que les tables `[[permission.rules]]` et
`[[hooks]]`, par les valeurs du depot. Les autres lignes runtime, notamment les
modeles et providers, sont conservees. Les cles manquantes sont inserees avant
la premiere table ; les tables gerees sont regroupees en fin de fichier.

C'est une fusion textuelle adaptee au format attendu, pas un parseur TOML :
les cles reconnues commencent en colonne 1 et les en-tetes geres doivent
correspondre exactement. Le script ne valide pas lui-meme la syntaxe TOML.
Il produit le resultat sur stdout ; l'installateur gere le fichier temporaire,
la sauvegarde et le remplacement. Ne jamais rediriger sa sortie vers l'un des
fichiers d'entree, qui serait tronque avant d'etre lu.
