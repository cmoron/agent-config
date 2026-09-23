Guidelines comportementales communes a tout projet. A completer avec les
instructions specifiques du projet.

- Toujours tutoyer Cyril, jamais le vouvoyer.

## Avant de coder

- Explorer le contexte du projet : README, documentation et sources pertinentes.
- Demander avant un choix structurant non tranche; reutiliser les decisions et
  autorisations deja donnees sans redemander validation.
  Pour un detail reversible, formuler une hypothese raisonnable et poursuivre.
- Proposer une solution plus simple lorsqu'elle existe et signaler les
  anti-patterns avant de les introduire.
- Evaluer l'effort pour calibrer le processus.

## Echelle d'effort

Sur-processer une petite tache gaspille du temps et des tokens.

- **XS** : production directe, sans plan; revue selon le risque.
- **S** : plan inline court, implementation, tests et commit.
- **M** : cadrage inline avec au plus deux questions bloquantes, puis premier
  increment testable. Pas de spec fichier par defaut.
- **L+** : plan explicite, lots valides sequentiellement et validation humaine
  aux frontieres importantes.

Avant une execution multi-agent longue, chiffrer le wallclock, les tokens et le
nombre de sous-agents. Deleguer la production seulement si les taches sont
independantes et le gain justifie la coordination. Une revue independante se
justifie par le risque, meme sur une petite tache. Le parent garde les
arbitrages d'architecture, l'integration et la verification. Pour une UI ou un MVP,
presenter un parcours executable avant d'etendre le perimetre.

## Workflow commun

Ces choix de composition s'appliquent par defaut a tous les projets; les
instructions du projet et les demandes explicites les specialisent. Choisir
un seul parcours pour la tache, annoncer ce choix en une phrase. Un skill
indisponible implique un fallback inline explicite, pas une capacite inventee.

- **Borne (XS a M)** : execution inline, diagnostic `diagnosing-bugs` et TDD
  `tdd` de Pocock quand pertinents. Pour cadrer une decision, utiliser Pocock
  `grill-with-docs` si invoque; ne pas ajouter un brainstorming concurrent.
  Une issue suffit pour un petit changement; spec et tickets pour un besoin
  transverse. Les commandes manuelles `to-spec`, `to-tickets`, `implement`
  restent disponibles sur invocation, pas declenchees de force.
- **Plan complexe (L+)** : Superpowers `writing-plans`, puis `executing-plans`
  ou `subagent-driven-development` selon l'independance et les capacites.
  Son TDD, son diagnostic et ses reviewers conduisent ce parcours. Le besoin
  deja cadre dans une issue/spec est fourni directement; brainstorming sert
  seulement aux decisions encore ouvertes. Le plan detaille la spec, ne la
  remplace pas. Sans Superpowers, avancer inline par lots verifies.
- **Revue** : Pocock `code-review` pour une revue autonome Standards/Spec;
  Superpowers pour ses plans. Reutiliser ses templates et agents generiques,
  sans nouveaux personas ni revue Pocock dans un worker Superpowers. Une
  demande explicite d'un autre parcours remplace le defaut, elle ne l'empile pas.
- **UI** : `frontend-design` pour la direction visuelle et l'inspection du rendu;
  le parcours choisi conserve la planification, les tests et la livraison.
- **Livraison** : interactive par defaut. `autoship` uniquement sur demande
  explicite; il conduit alors la livraison et remplace les menus de fin de
  branche. Il ne lance pas un second moteur d'implementation/revue.

Appliquer une seule procedure TDD par parcours, notamment pour la place du
refactoring. Les interfaces de test deja validees dans le brief ou la spec
sont acquises. Une auto-revue n'est jamais une revue independante. Si une
revue independante requise est indisponible, rendre la limite et rester avant
merge. L'autonomie ne vaut pas permission de publier sur un depot tiers :
appliquer `opensource-contributor`; sans autorisation, livrer un resultat local.

## GitHub et contexte Pocock

Ce bloc fournit le contexte tracker/labels/domaine aux skills Pocock dans
tous les depots, meme sans `docs/agents/`. L'absence de ces fichiers n'impose
ni setup ni creation de fichiers : utiliser ces valeurs deja fournies.
S'ils existent, `docs/agents/issue-tracker.md`, `triage-labels.md` et `domain.md`
remplacent chacun le defaut correspondant. `setup-matt-pocock-skills` sert
uniquement a personnaliser le projet sur demande.

- Tracker par defaut : GitHub Issues, specs dans une issue parente, operations
  via `gh`. Resoudre le depot avec les remotes et `gh repo view`; sur un fork,
  distinguer cible upstream et fork. Plusieurs cibles plausibles ou aucun
  remote GitHub : demander le tracker; en autonomie, rester local et signaler
  le blocage. Aucun fallback silencieux vers un tracker Markdown.
- Lire issue et commentaires via `gh issue view`; chercher les doublons avant
  publication. Pour les corps multilignes, utiliser `--body-file`. Publier
  uniquement dans le perimetre demande; cette configuration n'autorise pas a
  creer des issues, labels ou PR pendant une simple analyse.
- Labels canoniques : `needs-triage`, `needs-info`, `ready-for-agent`,
  `ready-for-human`, `wontfix`. Respecter un mapping local; verifier les labels
  existants avant usage, creer un label manquant seulement dans une operation
  de publication autorisee. Les PR externes ne sont pas une surface de triage
  par defaut. Lier PR et issue; fermer seulement les exigences effectivement
  livrees, pas une issue parente sur une livraison partielle.
- Pour `wayfinder`, carte = issue parente, tickets = sous-issues, dependances
  natives si disponibles; sinon liens `Part of #N` et `Blocked by #N` dans les
  issues GitHub. Ne prendre qu'un ticket sans bloqueur ouvert; garder decisions
  et liens vers les preuves dans la carte.
- Domaine : lire `CONTEXT.md` ou les contextes pertinents de `CONTEXT-MAP.md`,
  et les ADR applicables dans `docs/adr/`, s'ils existent. Leur absence est
  normale; creer ces documents seulement lorsqu'une decision le justifie.

## Candidat et preuves

Avant toute revue sur HEAD (y compris Pocock `implement`), capturer un commit
local de travail, sans push requis : `base_commit` fixe et `candidate_commit`
exact, diff non vide. Examiner les nouveaux fichiers, l'index et le working
tree; indexer uniquement les changements de la tache. Isoler le travail si des
changements etrangers empechent de capturer proprement le candidat. Avec
Superpowers, reutiliser son commit et son paquet de revue existants.

Executer les commandes test/lint/typecheck/build pertinentes du projet sur ce
candidat. Un hook de formatage est une aide, pas une preuve de validation.
Enregistrer commande, repertoire, code retour et sortie utile avec le SHA;
un controle absent ou non execute n'est pas un succes (non applicable doit
etre justifie). Toute modification, y compris formatage, doc ou correction CI,
produit un nouveau candidat et invalide les preuves precedentes. Revalider
avant livraison; ne jamais reutiliser un verdict pour un autre SHA.
Une revue independante qui compile ou lance des tests utilise un
repertoire de build distinct de celui du candidat (ex. `CARGO_TARGET_DIR`) :
sinon l'outil de build peut executer les artefacts du reviewer a la place des
sources.

## Pendant que tu codes

- Faire le minimum qui resout le probleme, sans abstraction speculative.
- Ne jamais avaler une erreur : pas de `catch` silencieux ni de `unwrap` hors
  tests.
- Garder les editions chirurgicales et signaler le dead code non lie sans le
  supprimer.
- Pour un bug reproductible, ecrire le test avant de le corriger. Ajouter les
  tests avec le code, pas apres.
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
