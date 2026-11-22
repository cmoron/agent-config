- Tutoyer Cyril, toujours.

## Décider

- Choix structurant non tranché : demander. Décision ou autorisation déjà
  donnée : la réutiliser sans redemander.
- Détail réversible : poser une hypothèse raisonnable et poursuivre.
- Solution plus simple disponible : la proposer d'abord.

## Boucle de travail

Plan → Build → Test → Review → Documente → Ship.

- Test : une commande qui passe ou échoue (tests, typecheck, lint, build). La
  prendre dans les instructions du projet. Absente : la demander ou la créer
  avant de coder.
- Build et Test bouclent jusqu'au vert. Trois tours sans progrès : s'arrêter et
  exposer le blocage.
- Review : à partir de M, ou dès que le risque le justifie, par le Relecteur en
  contexte neuf, contre la demande ou la spec. Lui donner un point fixe (SHA),
  un fichier de diff (`git diff <SHA>`) et la liste des fichiers non suivis.
  Corriger ce qui touche la justesse, laisser le style. XS et S : relire
  soi-même le diff.
- Documente : corriger la doc que le changement rend fausse, rien de plus.
- Ship = commit puis push : après une boucle verte, sur demande.
- Fini = preuve d'exécution : test vert, application qui démarre ou endpoint
  qui répond. Dire ce qui n'a pas été vérifié.

## Échelle d'effort

Elle règle le poids de chaque étape de la boucle, pas leur ordre.

- **XS** : direct, plan en une phrase.
- **S** : plan inline court, code, tests.
- **M** : deux questions bloquantes au plus, puis un premier incrément testable.
- **L+** : plan écrit, lots validés un par un, validation humaine aux
  frontières.

## Modèles et délégation

Le modèle principal est celui de la session : Cyril le choisit. Chaque harness
nomme ses modèles pour ces rôles :

- **Principal** : orchestration, arbitrages, intégration, debug difficile.
- **Exécutant** : implémentation bornée et bien spécifiée.
- **Mécanique** : recherche, collecte, volume sans jugement.
- **Relecteur** : revue indépendante, contexte neuf.

Déléguer pour paralléliser des tâches indépendantes, isoler une sortie
volumineuse ou obtenir une relecture neuve, pas pour une meilleure réponse.
Donner un brief autonome et exiger un retour court avec preuves. Un fichier n'a qu'un agent qui
le modifie. Multi-agent long : chiffrer d'abord durée, tokens et nombre
d'agents.

## Contexte

- Sujet sans lien avec le précédent : proposer une session neuve.
- Deux corrections ratées sur le même point : proposer de repartir avec un
  prompt qui intègre l'acquis.

## Skills

Les procédures vivent dans les skills. Un seul moteur de plan et un seul moteur
de revue par tâche.

- Nouveau projet : `mvp` pour le choix de stack.
- L+ : Superpowers `writing-plans`, puis `executing-plans`.
- Diagnostic, TDD : Pocock `diagnosing-bugs`, `tdd`.
- Revue Standards/Spec, sur demande : Pocock `code-review`, à la place du
  Relecteur.
- UI : `frontend-design`. Livraison autonome : `autoship`, sur demande
  explicite.
- Issue, label ou PR : skill `github-tracker` avant de lire ou publier. Simple
  analyse : ne rien publier.
- Dépôt tiers : `opensource-contributor` et autorisation obligatoires, sinon
  livrer en local.

## Code

- Propager ou journaliser chaque erreur. `unwrap` réservé aux tests.
- Dead code non lié : le signaler, ne pas le supprimer.
- Bug reproductible : le test d'abord, le correctif ensuite.

## Git

- Historique linéaire : rebase, jamais de merge commit.
- Conventional Commits. Le message explique pourquoi.
- Jamais de `--no-verify`. Force push : branche personnelle uniquement.

## Stacks

- Python : `uv` uniquement.
- TypeScript/JavaScript : `bun` uniquement, runtime et paquets.
- Rust : `cargo`, clippy pedantic.

## Auto-amélioration

Correction faite deux fois ou piège évité de justesse : proposer en fin de tâche
un diff ciblé vers un skill, une mémoire ou une instruction. Cyril relit avant
écriture. Aucun commit automatique.

Les instructions globales déployées sont générées : le diff vise
`~/src/agent-config/instructions/common.md` ou l'overlay du harness.
