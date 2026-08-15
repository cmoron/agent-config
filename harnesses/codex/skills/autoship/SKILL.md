---
name: autoship
description: Produit une petite feature/fix en autonomie totale : map, plan, build, review, spec-gate, verification comportementale, doc et ship. Utiliser seulement quand l'utilisateur demande explicitement autoship, fire-and-forget, ou une livraison autonome a faible risque.
---

# Autoship

Production autonome d'une petite feature ou d'un fix a faible risque de
regression. Mode fire-and-forget : aucune pause pour validation humaine apres le
lancement explicite par l'utilisateur.

L'etat terminal est toujours explicite :

- **livre** : merge/deploiement faits et verifies ;
- **PR prete** : branche poussee, PR verte, stop avant merge/deploy ;
- **WIP** : build ou tests toujours KO apres retries bornes ;
- **bloque** : cause externe precise.

## Principe

Orchestrer les briques existantes, pas reecrire le workflow du projet. Retries
bornes a 3 par phase/boucle ; jamais de boucle infinie. Toute condition qui rend
le merge auto risqué degrade vers PR prete ou WIP documente, jamais vers une
question en plein run.

## Phase 0 - Preflight

1. Resoudre les conventions du projet, dans l'ordre :
   - `AGENTS.md` du projet, puis `CLAUDE.md` si c'est le seul fichier local ;
   - skills `stack-*`, `deployment` et skills domaine applicables ;
   - manifestes : `pyproject.toml`, `package.json`, `Cargo.toml` ;
   - `.github/workflows/*` pour le workflow CI et la cible de deploiement.
2. Etablir explicitement : commande de test, commande de lint, commande de build,
   workflow CI, cible de deploiement staging/prod si elle existe.
3. Verifier l'etat git. Si le worktree contient des changements non lies,
   travailler autour ; si l'isolement est impossible, stopper avant modification
   avec rapport.
4. Creer une branche `autoship/<slug>` depuis la branche par defaut a jour.
5. Si aucune commande de test fiable n'existe, ne pas modifier le code ; produire
   un rapport.

Suivre l'avancement avec le plan de tache Codex quand il est disponible.

## Phase 1 - Map

Comprendre le code pertinent a la tache : zones impactees, contrats, tests
existants, chemins d'execution. Utiliser l'exploration locale ; ne dispatcher un
sous-agent Codex que si le travail est assez volumineux pour amortir le cout et
que le resultat est simple a verifier.

## Phase 2 - Plan

Produire un plan court et interne, calibre pour une petite feature/fix. Le plan
sert a executer, pas a demander validation.

## Phase 3 - Build Loop

Pour chaque tranche :

1. Ajouter ou ajuster le test qui couvre le comportement quand c'est praticable.
2. Implementer le minimum.
3. Lancer lint/tests/build pertinents.
4. Corriger jusqu'a vert ou jusqu'a 3 tentatives.

Faire ensuite une review du diff complet : bugs, regressions, erreurs de contrat,
tests manquants, simplification possible. Utiliser un reviewer independant si
les outils multi-agent Codex sont disponibles et justifies ; sinon faire une
passe fraiche inline. Corriger puis re-verifier.

Si apres retries le build ou les tests ne passent pas, commit du WIP sur la
branche de travail si utile, puis rapport. Pas de merge.

## Phase 3bis - Spec Gate

Comparer le diff a la demande initiale. Verifier que les criteres d'acceptation
et edge cases evidents sont couverts.

- Conforme : continuer.
- Ecart : rework borne a 3 tentatives, puis degradation PR prete avec raison
  `spec-gate`.

## Phase 3ter - Verification Comportementale

Les tests verts ne suffisent pas. Observer le comportement reel attendu :
lancer l'app si necessaire, appeler l'endpoint, executer le flux CLI, ou verifier
l'UI avec Playwright quand le projet s'y prete.

- OK : continuer.
- KO : rework borne a 3 tentatives, puis degradation PR prete avec raison
  `verify`.

## Phase 4 - Doc

Mettre a jour README, docs ou changelog seulement si le changement le justifie.
Pas de documentation decorative.

## Phase 5 - Ship

Suivre `references/ship.md`. La choregraphie choisit l'atterrissage selon les
zones touchees par le diff :

- **auto** : aucune zone sensible, aucun gate amont degrade ;
- **PR prete** : DB, auth/secrets, CI-CD/infra, gate degrade ou doute
  significatif.

## Phase 5bis - Auto-Correction Post-Merge

Atterrissage auto uniquement. Si, apres merge sur la branche par defaut, le CI
main est rouge ou le healthcheck de deploiement est KO, suivre la procedure
post-merge de `references/ship.md` : fix-forward borne a 3 iterations, puis PR
de revert si l'etat sain n'est toujours pas restaure.

## Garde-Fous

- Retries bornes a 3 ; jamais de boucle infinie.
- Pas de `--no-verify`, pas de force push.
- Historique lineaire : rebase/squash.
- Conventional Commits.
- Etat laisse explicite : branche, PR, commit, verification, cause d'arret.

## Rapport Final

Toujours produire :

- Tache.
- Statut : livre, PR prete, WIP, bloque.
- Fait : phases franchies, branche, PR, commits.
- Verifications lancees et resultat.
- Cause precise si degrade.
- Action manuelle requise, le cas echeant.

La notification de fin de tour est geree par la configuration Codex `notify`
quand elle est active ; ne pas supposer de canal push dedie.
