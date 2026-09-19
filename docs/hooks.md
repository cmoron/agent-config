# Hooks shell

Les hooks s'executent depuis le dossier `scripts` deploye du harness. Ils
necessitent Bash et, pour les hooks de fichiers, `jq`. Les tests utilisent
des homes temporaires et des outils factices, sans son ni appel de modele.

## Sources et deploiement

`shared/scripts` contient les actions communes et les entrees Claude/Kimi.
`harnesses/codex/scripts` adapte les patches `apply_patch` au meme traitement
de fichiers. Une entree native remplace l'entree commune du meme nom.
Les chemins des commandes dans les configurations ne changent pas.

Sur macOS/WSL, `scripts` est un dossier reel avec des liens par fichier vers
ces sources. L'installateur remplace l'ancien lien de dossier gere, sauvegarde
les fichiers tiers en collision et preserve les fichiers tiers d'autres noms.
Windows recoit des fichiers reels combines dans son dossier `scripts` gere
par le manifeste ; aucune dependance a un lien vers le depot.

OpenCode conserve ses formateurs natifs et ne recoit pas ces hooks shell.
Kimi reutilise les entrees communes ; aucun abonnement n'est necessaire aux tests.

## Formatage et protection

Les entrees lisent un objet JSON sur stdin. Claude/Kimi fournissent
`tool_input.file_path`, chaine non vide. Codex fournit `tool_input.command`,
un patch encadre par `*** Begin Patch` et `*** End Patch`. L'adaptateur extrait
les chemins Add/Update/Delete et les destinations `*** Move to:`. Il ne valide
pas toute la grammaire des hunks ; le moteur `apply_patch` reste responsable
de leur interpretation.

Les chemins relatifs sont resolus depuis `cwd` si fourni, sinon depuis le
repertoire courant. Les espaces sont acceptes ; les caracteres de controle
dans les chemins sont refuses. Une entree invalide ou sans chemin exploitable
produit un diagnostic sur stderr et le code 2. Codex renvoie `{}` sur stdout
apres succes ; les entrees Claude/Kimi restent muettes sur stdout.

| Entree                            | Action                                                            | Resultat                                                                      |
| --------------------------------- | ----------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| `protect-env.sh` (PreToolUse)     | Refuse tout basename `.env` ou `.env.*`, y compris `.env.example` | 2 avec diagnostic si protege, 0 sinon                                         |
| `format-on-save.sh` (PostToolUse) | Traite les fichiers existants selon leur extension                | 0 si traite ou ignore ; erreur du formateur propagee sur stderr avec son code |

La protection porte sur les noms fournis par ces outils. Elle ne couvre pas
les ecritures par shell, les autres outils ni la resolution des liens symboliques.
Elle ne constitue pas une sandbox.

Le formatage utilise `ruff format` puis **`ruff check --fix`** pour Python,
`rustfmt --edition 2021` pour Rust, `biome format --write` pour TS/JS/JSON/JSONC/CSS,
et `prettier --write` pour HTML/Markdown/YAML. Ruff peut donc corriger du code,
au-dela de sa mise en forme. Un outil absent est ignore avec un diagnostic ;
un outil present qui echoue ne produit pas un faux succes. Aucun outil n'est
installe par le hook. Ces actions ne remplacent ni lint, ni typage, ni tests
du projet et ne garantissent pas le respect de versions epinglees au projet.

## Notification sonore

`notify-sound.sh` cherche l'asset dans `../assets` par rapport a son chemin
deployee. Il utilise, dans l'ordre, `afplay`, PowerShell via WSL, `paplay`,
`ffplay`, puis la cloche du terminal. La lecture est lancee en arriere-plan ;
son lancement ne prouve pas qu'un son a effectivement ete entendu. Un asset
absent est signale sans bloquer la session. Aucun contenu du tour n'est traite.
Les diagnostics du lecteur vont dans `notify-sound.log` a la racine du home
du harness, hors des arbres geres par l'installateur. Le fichier est tronque
a chaque lancement : c'est une aide au diagnostic du dernier son, pas un
historique. Les lecteurs detaches ne gardent pas les pipes du hook ouverts.

## Rappel de fin de session

Ces adaptateurs restent natifs : les codes de retour ont des effets differents.
Ils necessitent `python3` et Git. En leur absence, le rappel se degrade en
no-op. Ils lisent `session_id` et `cwd`, puis regardent les changements Git. Un marqueur
sous `${TMPDIR:-/tmp}` limite le rappel a une fois par session.

- Claude prend aussi `stop_hook_active` en compte et emet du contexte JSON
  avec le code 0.
- Kimi renvoie le rappel sur stderr avec le code 2 : il provoque un tour
  supplementaire, puis le marqueur empeche une nouvelle relance.
- Codex n'a pas de hook Stop : son ancien rappel bloquait les tours termines.

Ces rappels n'ecrivent ni skill ni memoire. Les tests couvrent le declenchement
sur un depot temporaire modifie et l'absence de second rappel.

## Verification

`bash tests/test-hooks.sh` teste les entrees deployees avec des fichiers et
executables factices. `bash tests/run-all.sh` ajoute les controles de migration,
de preservation, d'idempotence et des copies Windows. Une execution sous WSL
ne remplace pas une verification native macOS/Windows ou une session reelle
dans chaque harness.
