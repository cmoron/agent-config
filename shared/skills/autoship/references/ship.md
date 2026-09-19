# Ship — chorégraphie de livraison

Appelé par la phase 4 du skill `autoship`. Hypothèse : candidat capturé,
contrôles requis réussis et revue documentée sur `autoship/<slug>`.
Toutes les commandes `gh` supposent `gh` authentifié
(cf. skill `deployment`).

## 0. Atterrissage : auto ou PR-prête ?

Classer les zones touchées par le diff (branche vs base) :

- **DB** : migrations / schéma (`**/migrations/**`, `*.sql` de schéma, `schema.prisma`, …).
- **Auth/secrets** : auth, permissions, `.env*`, secrets, flux de paiement.
- **CI-CD/infra** : `.github/workflows/**`, `Dockerfile`, `docker-compose*`, scripts de
  déploiement / IaC.

- Publication et merge autorisés, aucune zone sensible, contrôles et comportement
  validés, revue `independent` + `pass` sur le candidat courant →
  **atterrissage auto** : sections 1 → 3 (puis 4 si besoin).
- Zone sensible touchée **ou** preuve manquante/dégradée → **atterrissage PR-prête** : sections 1
  et 2 seulement (commit → PR → CI verte), puis **stop avant merge/deploy** → rapport
  « PR prête, raison : <zone sensible / gate> ». Aucune question.

La **taille du diff** n'influe pas sur l'atterrissage (on va au bout) ; la signaler dans le
rapport comme simple indicateur.

Si la publication n'est pas autorisée, arrêter avant push/création de PR et
rendre le candidat local. Une PR avec défaut connu reste explicitement « à
relire » (draft si non livrable), jamais annoncée conforme parce que la CI passe.

## 1. Commit & PR

1. Le commit conventionnel existe déjà : réexécuter le garde de candidat de
   la phase 2. Toute modification impose de reprendre vérification et revue.
2. `git push -u origin autoship/<slug>`
3. Créer la PR avec `--base <branche-par-défaut>` et `--body-file <rapport>` :
   issue/spec liée, comportement, candidat, contrôles, revue et limites.

## 2. CI de la PR

1. `gh pr checks --watch` (ou `gh run watch <run-id>`) jusqu'à complétion.
2. CI **verte** → atterrissage **auto** : section 3. Atterrissage **PR-prête** : stop ici,
   PR verte laissée pour revue, rapport « PR prête » (pas de merge).
3. CI **rouge** → diagnostiquer via `gh run view <id> --log-failed`, corriger sur la
   branche, reprendre les phases 2 et 3 sur le nouveau commit, repush.
   Consommer le budget commun de trois corrections avant merge, sans le
   réinitialiser. Un contrôle requis absent/pending n'est pas vert.
4. Budget épuisé et CI toujours rouge → **abort** : convertir la PR en draft
   (`gh pr ready --undo`), laisser branche + PR en place, rapport. Pas de merge.

## 3. Merge & surveillance

> N'exécuter qu'en atterrissage **auto** (cf. section 0). En PR-prête : ne rien merger.

1. Revalider le garde local, lire le `headRefOid` de la PR et les contrôles
   requis pour ce SHA. Il doit égaler `candidate_commit`; sinon reprendre les
   phases 2 et 3, sans réutiliser les preuves. Merger avec
   `gh pr merge --squash --delete-branch --match-head-commit <candidate_commit>`.
   Ne jamais contourner les protections avec `--admin`.
2. `gh run watch` sur le run déclenché sur la branche par défaut.
3. Si aucun déploiement n'est prévu, signaler « non applicable ». Sinon,
   **gate staging (obligatoire si un staging existe)** selon
   le skill `deployment` :
   - Si une cible **staging** existe (détectée en Phase 0) : déployer staging d'abord,
     puis vérifier son **healthcheck**. Staging KO → section 4 sans jamais
     toucher prod. Staging OK → promouvoir vers prod, puis vérifier le healthcheck prod.
   - Si **aucun staging n'existe** : déployer prod directement, vérifier le healthcheck —
     et **signaler dans le rapport** que le déploiement s'est fait sans gate staging
     (facteur de risque additionnel assumé par l'utilisateur en lançant autoship).
   - Le déploiement n'est validé que si le service répond.
4. Main CI verte + healthcheck OK (ou déploiement non applicable) → **succès**.
5. Main CI rouge OU healthcheck KO → section 4.

## 4. Auto-correction post-merge

Boucle **bornée à 3 itérations** :

Budget unique post-merge : les vérifications/revues de chaque itération ne
relancent aucune boucle de correction interne. Depuis cette section, utiliser
uniquement les étapes 1 à 3 de la section 3; un échec de surveillance revient
à l'itération courante ci-dessous, jamais à une nouvelle invocation de section 4.

1. Diagnostiquer : `gh run view <id> --log-failed` (CI main) ou les logs du déploiement /
   healthcheck.
2. Créer une branche `autoship/<slug>-fix-<n>`, appliquer le fix (TDD si pertinent).
   Recapturer base/candidat et reprendre les phases 2 et 3; reclasser les zones
   sensibles. Un fix qui ne satisfait plus l'atterrissage auto reste à relire :
   arrêter et signaler l'état du service ainsi que l'action humaine requise.
3. Publier selon les sections 1 et 2 → `gh pr checks --watch`.
4. CI verte et atterrissage auto → merge lié au SHA (section 3) → re-surveiller main + déploiement
   (section 3, étapes 2–3).
5. Sain → **succès** (rapport). Contrôles/revue/CI en échec ou service toujours
   cassé → itération suivante dans le même budget; pas de merge sans preuves.

**Fallback final** (3 itérations de fix-forward épuisées, main/prod toujours cassé) :
**auto-revert** plutôt que laisser prod cassé.

1. Identifier le(s) commit(s) de merge introduit(s) par ce run sur la branche par défaut.
2. `git revert --no-edit <sha-merge>` (du plus récent au plus ancien si plusieurs) sur une
   branche `autoship/<slug>-revert`. Le revert vise le dernier état connu sain — il
   n'efface pas l'historique (compatible historique linéaire, pas de force push).
3. Reprendre les phases 2 et 3 sur le revert, reclasser le risque puis publier
   selon les sections 1 et 2. Le revert doit rendre la CI verte; il ne répare
   pas nécessairement les données ou effets externes d'un déploiement.
4. CI verte et atterrissage auto → merge lié au SHA (section 3, étapes 1 à 3 seulement) → re-surveiller main + redéployer
   (section 3 : staging si présent, puis prod) → vérifier le healthcheck.
5. Sain après revert → **succès dégradé** : la feature n'est PAS livrée mais prod est
   restaurée. Le rapport le dit explicitement (revert appliqué, raison, action manuelle =
   reprendre la feature plus tard).

**Si le revert lui-même échoue ou exige une validation humaine** (revue indisponible,
zone sensible, CI du revert rouge, healthcheck toujours KO, ou conflit
de revert non trivial) : **stop + escalade**. La restauration n'est pas garantie —
le rapport l'indique explicitement avec l'action manuelle urgente requise.
