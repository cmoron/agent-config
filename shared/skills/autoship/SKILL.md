---
name: autoship
description: "Livrer une petite feature/fix en autonomie sur demande explicite : implementation, preuves sur un candidat Git, revue independante et livraison ou PR a relire. Utiliser pour autoship ou fire-and-forget, pas pour une implementation interactive ordinaire."
---

# Autoship

L'utilisateur autorise l'execution autonome d'une petite tache et sa livraison
dans le perimetre demande. Suivre le Workflow commun pour tracker, domaine et
priorite des instructions. Une decision deja approuvee n'est pas redemandee.
Une autorisation manquante ne s'invente pas : terminer localement avec un rapport.
Pour un upstream tiers, appliquer `opensource-contributor` avant publication.

Utiliser les capacites effectivement exposees dans la session, quel que soit
le harness. Claude fournit `/autoship`; ailleurs le nom du skill suffit.
Une revue inline reste une auto-revue et n'autorise pas l'auto-merge.

## 0. Preflight

1. Lire instructions projet, demande originale, issue/spec et criteres
   d'acceptation. Le contexte GitHub global suffit sans setup Pocock local.
2. Identifier commandes de test, lint, typage et build du projet, CI requise,
   cible de publication et deploiement, proprietaire du depot. Justifier les
   controles non applicables; test introuvable = arret avant implementation.
3. Examiner l'etat Git. Creer `autoship/<slug>` depuis la branche par defaut
   a jour, dans un worktree isole si des changements etrangers sont presents.
   Garder son SHA comme `base_commit` fixe pour le run.
4. Fixer les interfaces de test depuis le brief et les conventions existantes.
   Si une decision produit indispensable manque, rapport de blocage local.

## 1. Comprendre et implementer

Tracer les chemins concernes et les tests. Plan court inline, puis Pocock `tdd`
pour la boucle test rouge / implementation. Diagnostic via `diagnosing-bugs`
si necessaire. Mettre a jour la documentation pertinente avant la revue.

Autoship conduit un seul parcours inline pour cette petite tache; ne pas
imbriquer `implement`, Superpowers SDD, `writing-plans` ou un menu de fin de
branche. Si un plan complexe est necessaire, terminer avec le cadrage et la
limite : ce skill n'est pas le moteur d'un grand chantier.

## 2. Capturer et verifier

1. Formater, examiner diff, nouveaux fichiers et index; indexer seulement les
   fichiers de la tache et committer localement. Aucun `git add -A` aveugle.
   `candidate_commit` = SHA complet de HEAD; absence de diff = « aucun changement »,
   jamais « revue reussie ».
2. Depuis le depot cible, executer :

   ```bash
   bash <skill-dir>/scripts/check-candidate.sh <base_commit> <candidate_commit>
   ```

   Remplacer skill-dir par le dossier de ce skill. Le garde refuse references
   invalides, HEAD different, arbre sale et diff vide. Il ne publie rien.

3. Executer explicitement les controles identifies au preflight. Pour chacun,
   conserver commande, cwd, code retour et sortie utile avec le candidat :
   `pass`, `fail`, `not_run` ou `not_applicable` motive. Un hook de confort ne
   remplace aucun controle. Controle requis absent/non execute = non valide.
4. Observer le comportement demande (test d'integration, application, endpoint
   ou rendu UI selon la tache), sans effets de bord externes non autorises.
5. Relancer le garde de candidat : un outil qui modifie les fichiers impose un
   nouveau commit et de nouvelles preuves. Stocker les rapports hors du working
   tree ou dans un emplacement ignore pour ne pas salir le candidat.

## 3. Revue independante unique

Si Superpowers `requesting-code-review` est disponible, reutiliser son template
`code-reviewer.md` avec un agent generique frais. Sinon utiliser Pocock
`code-review`, avec ses deux axes Standards/Spec et sa propre orchestration.
Ne lancer qu'une de ces voies; ne pas ajouter un spec-gate apres une revue qui
inclut deja la demande. Ne pas precharger un orchestrateur dans un reviewer.

Fournir : demande originale, criteres d'acceptation, conventions pertinentes,
`base_commit`, `candidate_commit`, commandes/resultats de verification.
Demander les constats et leurs preuves fichier/ligne, verdict et limites.
Le reviewer n'edite pas le candidat; les entrees manquantes reviennent au parent.
Le rapport de l'auteur ne remplace pas les exigences originales.

En l'absence de procedure disponible ou de delegation, faire une auto-revue et
la nommer. Enregistrer separement le mode (`independent`, `self_review`,
`unavailable`) et le verdict (`pass`, `fail`, `unverified`). Seul
`independent` + `pass` satisfait le prerequis d'auto-merge.

Budget commun de trois corrections avant merge (tests, comportement, revue et
CI compris), sans remise a zero entre phases. Chaque correction produit un nouveau candidat :
reprendre la phase 2 puis la revue. Echec persistant : WIP ou PR a relire, jamais
merge. Reexecuter le garde juste avant la publication.

## 4. Livrer

Suivre `references/ship.md` : PR et CI sur le meme candidat, puis auto-merge
seulement si autorise, sans zone sensible, avec toutes les preuves valides.
Sinon laisser une PR a relire; si publier n'est pas autorise, rester local.
Les corrections CI suivent les memes phases 2 et 3 et consomment ce budget.
Apres merge, les trois iterations de `ship.md` constituent un budget distinct :
chaque iteration effectue une seule verification/revue, sans boucle interne.

## Rapport

Rendre : tache, statut (`livre`, `PR a relire`, `WIP local`, `bloque post-merge`),
base/candidat, commandes et resultats, mode/verdict de revue, limites,
branche/PR et action humaine restante. Sans deploiement applicable, « livre »
signifie merge et CI verte; ne pas inventer de healthcheck.

Les preuves de revue restent des jugements de modele. Le garde de candidat
controle Git uniquement : ce n'est ni une sandbox ni le gate de livraison
complet de l'issue #6. Les protections serveur et CI requises restent distinctes.
