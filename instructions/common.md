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
- Review : contre la demande ou la spec, par un contexte neuf, celui du
  flow ou le Relecteur. Lui donner un point fixe (SHA), un fichier de diff
  (`git diff <SHA>`) et la liste des fichiers non suivis. Corriger ce qui touche
  la justesse, laisser le style. XS, S et flow `default` : relire soi-même le
  diff.
- Documente : corriger la doc que le changement rend fausse, rien de plus.
- Ship = commit puis push : après une boucle verte, sur demande.
- Fini = preuve d'exécution : test vert, application qui démarre ou endpoint
  qui répond. Dire ce qui n'a pas été vérifié.

## Flow et effort

Chaque projet déclare son flow dans ses instructions : `Flow : default`,
`superpowers` ou `pocock`. Sans déclaration : `default`. Un seul flow par tâche.
Le déroulé de chacun est dans `docs/flows.md` du dépôt `agent-config`.

Estimer la taille du diff attendu après un premier regard au code et l'annoncer
en une phrase. XS (quelques lignes, un fichier) et S (un comportement, quelques
fichiers) : un seul jet, dans tous les flows. Au-delà, c'est-à-dire M
(plusieurs fichiers ou un choix de conception) et L+ (plusieurs sessions) :

- **default** : un seul jet aussi, sans cadrage ni sous-agent. Signaler une
  tâche L+ en une phrase, puis avancer.
- **superpowers** : le plugin Superpowers conduit le cadrage, le plan et
  l'exécution.
- **pocock** : cadrer avec `grilling` et `domain-modeling`, même si une spec
  existe déjà. M : coder en TDD dans la session, puis `code-review`. L+ :
  s'arrêter et demander à Cyril de taper `/to-spec`, puis `/to-tickets`, puis
  `/implement-spec` ; ne pas découper ni publier de tickets soi-même. Intégrer
  les tickets par rebase, sans merge commit ni sous-agent de fusion. Après la
  PR, proposer `/retro`.

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

Les procédures vivent dans les skills.

- Nouveau projet : `/flow` pour déclarer le flow.
- Bug qui résiste : `diagnosing-bugs`. UI : `frontend-design`.
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
- TypeScript/JavaScript : `bun` uniquement, runtime et paquets, dans nos
  projets. Node reste installé pour les outils tiers (plugins, MCP via `npx`).
- Rust : `cargo`, clippy pedantic.

## Auto-amélioration

Correction faite deux fois ou piège évité de justesse : proposer en fin de tâche
un diff ciblé vers un skill, une mémoire ou une instruction. Cyril relit avant
écriture. Aucun commit automatique.

Les instructions globales déployées sont générées : le diff vise
`instructions/common.md` ou l'overlay du harness, dans le dépôt `agent-config`.
