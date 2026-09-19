# Validation de la configuration multi-harness

Cette procedure distingue la compatibilite des fichiers deployes du comportement
d'un modele. Elle s'applique apres une modification de politique, de skill ou de
plugin, et lors d'une comparaison de modeles. Les petites editions sans changement
de comportement utilisent seulement les controles locaux pertinents.

## Compatibilite et deploiement

```bash
bash tests/run-all.sh
(
  for script in install.sh update.sh tests/*.sh harnesses/*/scripts/*.sh shared/scripts/*.sh; do
    bash -n "$script" || exit 1
  done
)
git diff --check
./install.sh --dry-run
```

Les tests travaillent sous homes temporaires. Le test Codex selectionne les
profils `terra`, `luna` et `sol-high` avec la vraie CLI et `mcp list --json` :
ni appel de modele, ni connexion aux serveurs MCP. Si Codex est absent, le test
annonce SKIP ; ce n'est pas une preuve de compatibilite. Le test OpenCode utilise
deja `debug skill --pure` pour verifier la decouverte des skills.

Apres installation autorisee avec `./install.sh`, executer `./install.sh --check`.
Pour installer uniquement les changements de sources sans mettre a jour les
plugins existants : `AGENT_CONFIG_SKIP_PLUGINS=1 ./install.sh`.
Une validation Linux des copies Windows ne remplace pas une execution native
sur Windows ou macOS. Redemarrer les sessions pour charger les instructions
nouvellement rendues.

## Etat a relever pour une comparaison

Relever les versions avec les CLI presentes :

```bash
git rev-parse HEAD
git status --short
git submodule status
codex --version
claude --version
kimi --version
opencode --version
```

Pour chaque run, noter dans son compte rendu :

| Champ          | Valeur a relever                                                                         |
| -------------- | ---------------------------------------------------------------------------------------- |
| Environnement  | OS, version CLI et revision des sources, diff local s'il existe                          |
| Modele         | Modele/effort effectifs du parent et des enfants, pas seulement le defaut du fichier     |
| Instructions   | Socle et overlay rendus, consignes de session qui modifient le comportement              |
| Skills/plugins | Versions ou revisions effectivement chargees ; distinguer catalogue, cache et activation |
| Outils         | MCP utilises et leur version lorsqu'elle est exposee, permissions effectives             |
| Tache          | Commit de depart, demande exacte, criteres d'acceptation et commandes de verification    |

Les submodules fournissent leurs SHA. Pour les plugins, utiliser l'inventaire natif
du harness et les manifests des versions chargees. Un nom de cache ou une entree
du catalogue ne prouve pas l'activation. Quand une version manque, noter
« inconnue » ; une mise a jour non identifiee empeche d'attribuer le changement
au seul modele. Ne pas copier les fichiers d'authentification, configs completes
ou contenus de sessions prives dans Git pour constituer ce releve.

## Cas de comportement

Sol xhigh reste le defaut Codex. Un modele choisi en session prime sur ce defaut.
Comparer une seule variable a la fois : politique, version de skill/plugin,
modele/effort ou delegation. Garder un checkout temporaire par variante et les
memes demandes/criteres ; aucun deploiement de production pour un essai.

| Cas                                               | Critere attendu                                                                             |
| ------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| XS deja autorise, skill suggerant une approbation | Execute la retouche et son controle pertinent sans nouvelle validation de pure procedure    |
| Bug avec reproduction                             | Observe l'echec, corrige la cause, verifie la regression sans suite ajoutee par automatisme |
| Feature bornee avec hook de formatage             | Execute les vrais lint/typage/tests du projet ; le hook ne tient pas lieu de preuve         |
| Revue independante                                | Couvre standard et spec sans rejouer un axe deja valide sur le meme diff                    |
| Deux explorations independantes de courte duree   | Delegation bornee si utile et disponible ; ne bloque pas sur un seuil de huit heures        |
| Tache longue avec reprise                         | Conserve decisions, limites et prochain controle, puis reprend le travail autorise          |

Un choix structurant non tranche doit toujours remonter a Cyril. Une autorisation
de processus n'accorde pas de nouveaux droits sur les outils ni une publication.

Relever achevement, erreurs/regressions, interventions humaines, controles
manquants ou repetes, temps total et tokens parent + enfants. Distinguer tokens,
cout API et quota d'abonnement. Repeter les differences utiles avant de conclure :
ces six cas constituent un pilote, pas un benchmark statistique. Rejeter un gain
de vitesse obtenu par omission d'un controle requis.
