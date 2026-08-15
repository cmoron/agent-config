Guidelines comportementales communes a tout projet. A completer avec les
instructions specifiques du projet.

- Toujours tutoyer Cyril, jamais le vouvoyer.

## Avant de coder

- Explorer le contexte du projet : README, documentation et sources pertinentes.
- En cas d'ambiguite ou de choix structurant, demander avant d'implementer.
- Proposer une solution plus simple lorsqu'elle existe et signaler les
  anti-patterns avant de les introduire.
- Evaluer l'effort pour calibrer le processus.

## Echelle d'effort

Sur-processer une petite tache gaspille du temps et des tokens.

- **XS** : modification directe, sans plan ni delegation.
- **S** : plan inline court, implementation, tests et commit.
- **M** : cadrage inline avec au plus deux questions bloquantes, puis premier
  increment testable. Pas de spec fichier par defaut.
- **L+** : plan explicite, lots valides sequentiellement et validation humaine
  aux frontieres importantes.

Avant une execution multi-agent longue, chiffrer le wallclock, les tokens et le
nombre de sous-agents. Sous huit heures estimees, l'execution inline est le
defaut. Pour une UI ou un MVP, presenter un parcours executable avant d'etendre
le perimetre.

## Pendant que tu codes

- Faire le minimum qui resout le probleme, sans abstraction speculative.
- Ne jamais avaler une erreur : pas de `catch` silencieux ni de `unwrap` hors
  tests.
- Garder les editions chirurgicales et signaler le dead code non lie sans le
  supprimer.
- Ecrire le test qui reproduit un bug avant de le corriger. Ajouter les tests
  avec le code, pas apres.
- Utiliser les controles et formateurs fournis par le projet; ne pas inventer un
  workflow de formatage global.

## Avant de dire que c'est fait

Fournir une preuve d'execution : tests qui passent, application qui demarre ou
endpoint qui repond. Dire explicitement ce qui n'a pas pu etre verifie. Les
controles locaux pertinents doivent passer; une compilation seule ne remplace
pas tests, lint ou qualimetrie.

## Git

- Historique lineaire : rebase, pas de merge commit.
- Conventional Commits; le message explique pourquoi.
- Pas de `--no-verify` ni de force push hors branche personnelle.

## Stacks

- Python : `uv`, jamais `pip` ou `poetry`.
- TypeScript/JavaScript : `bun`, jamais `npm`, `yarn`, `pnpm` ou `node` direct.
- Rust : `cargo` et clippy pedantic.

## Auto-amelioration

Quand une procedure se repete deux ou trois fois, qu'une correction revient ou
qu'un piege est evite de justesse, proposer en fin de tache un diff cible vers
un skill, une memoire ou une instruction. Cyril relit avant ecriture; aucun
commit automatique. Ne pas creer un skill pour une intuition ponctuelle.

Ces regles fonctionnent si les questions arrivent avant le code, si les diffs
restent scopes et si la verification precede toute affirmation de reussite.
