# Audit de la configuration agent-config avec GPT-6 Astra

8 septembre 2026 — pour Cyril. Dépôt audité : `cbbc9b4`, initialement propre.
Codex CLI installé : `0.153.4`, Linux/WSL.

Décision de Cyril après cet audit : appliquer les corrections aux quatre
harnesses, en conservant **Sol xhigh comme défaut Codex** et le choix du modèle
à la volée. Le point 2 est donc requalifié en différence volontaire de sélection,
pas en défaut de choix de modèle. Les recommandations Astra par défaut ci-dessous
appartiennent à l'audit initial et sont remplacées par cette décision.

**Verdict : le socle reste pertinent. Les priorités sont la compatibilité de la
CLI, la cohérence source/runtime et les conflits de procédure. Une refonte de
l'architecture ou l'ajout d'un framework ne sont pas justifiés par les preuves
disponibles.** Astra high constitue une référence de comparaison cohérente avec
ton usage local actuel ; cet audit ne démontre pas que c'est le réglage optimal.

Le périmètre approfondi couvre Codex, les instructions communes, les skills de
processus et leur déploiement. Claude, Kimi et OpenCode ont fait l'objet d'un
contrôle de cohérence transversal. Le corps ci-dessous décrit l'état initial,
avant les corrections autorisées. Le suivi d'application figure en fin de document.

**Ce qu'Astra change réellement.** OpenAI signale une sensibilité accrue aux
instructions des skills, davantage de demandes de clarification, une délégation
parfois insuffisante et des vérifications trop étendues pour certaines petites
tâches. Cela rend utile un audit des consignes contradictoires. La recommandation
de migration conserve d'abord l'effort effectif existant, puis mesure les
résultats. Elle ne prescrit pas `max` ou `ultra` par défaut.
[OpenAI, guide GPT-6 Astra, consulté le 8 septembre 2026](https://developers.openai.com/api/docs/guides/latest-model?model=gpt-6-astra).

**Ce que les sources communautaires permettent de conclure.** Il existe plusieurs
écoles, et aucune comparaison contrôlée Astra/Sol sur ces configurations n'a été
trouvée dans les sources consultées.

| Source primaire                                                                                                                | Pratique ou résultat                                                                                                                                                                                                 | Portée pour notre configuration                                                                                                                                           |
| ------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [Peter Steinberger, agent-scripts](https://github.com/steipete/agent-scripts)                                                  | Source commune, skills opérationnels courts, helpers pour les commandes répétables, validation des skills.                                                                                                           | Précédent concret favorable à notre architecture déclarative. Aucune mesure comparative de performance dans le README consulté.                                           |
| [Pi, site du projet](https://pi.dev/)                                                                                          | Cœur minimal et extensible ; plan mode et sous-agents sont optionnels.                                                                                                                                               | Le processus peut être ajouté selon le besoin. Ce choix de conception ne prouve pas la supériorité d'un agent minimal.                                                    |
| [Jesse Vincent et contributeurs, Superpowers](https://github.com/obra/superpowers)                                             | Méthodologie prescriptive : design, plan, TDD, sous-agents/revues et intégration.                                                                                                                                    | C'est un choix de workflow, pas seulement une bibliothèque de compétences. Le README mentionne des évaluations de skills, sans établir un gain comparatif propre à Astra. |
| [Gloaguen et al., Evaluating AGENTS.md, version du 23 juin 2026](https://arxiv.org/abs/2602.11988v2)                           | Les fichiers de contexte n'améliorent pas généralement la résolution dans les expériences étudiées et augmentent le coût d'inférence de plus de 20 % en moyenne. Les consignes particulières sont néanmoins suivies. | Garder les conventions non évidentes et les contraintes utiles ; évaluer les ajouts. Étude antérieure à Astra, qui ne mesure pas notre configuration personnelle.         |
| [Fu et al., Do More Agents Help?, 4 juin 2026](https://arxiv.org/abs/2606.05670)                                               | Sous protocole contrôlé avec GPT-4.1, cinq des six architectures multi-agent restent derrière l'agent unique comparable.                                                                                             | Davantage d'agents n'est pas un objectif de qualité. Résultat limité aux systèmes et modèles étudiés.                                                                     |
| [Anthropic, système de recherche multi-agent, 13 juin 2025](https://www.anthropic.com/engineering/multi-agent-research-system) | Gains sur une évaluation interne de recherche à plusieurs axes indépendants ; forte consommation de tokens et limites pour le code interdépendant.                                                                   | Délégation pertinente pour recherche, exploration et revues indépendantes. Pas de justification d'une délégation systématique des modifications.                          |

Ces sources ont toutes été consultées le 8 septembre 2026. Les témoignages Astra
les plus directement pertinents trouvés sont des signalements de pauses de
sécurité et de compaction bloquée. Ils ne permettent pas d'attribuer ces problèmes
à notre configuration, ni de proposer un contournement général.
[Issue Codex #43042, antons, 5 septembre](https://github.com/openai/codex/issues/43042),
[issue #43062, asdesign2026, 5 septembre](https://github.com/openai/codex/issues/43062).

**Constats prioritaires.** P1 désigne un défaut concret ou un risque direct pour
le workflow ; P2 une amélioration à valider. Aucun incident destructif n'a été
constaté pendant cet audit.

**1. P1 — Les profils utilisent un format refusé par la CLI actuelle.**

[harnesses/codex/config.toml](../../harnesses/codex/config.toml), lignes 44–57,
déclare `terra`, `luna` et `sol-high` sous `[profiles.*]`. Le contrôle suivant,
sans génération par un modèle, échoue avec le vrai binaire installé :

```text
codex --profile terra mcp list --json
Error: failed to load configuration
--profile `terra` cannot be used while .../config.toml contains legacy
`profile = "terra"` or `[profiles.terra]` config
```

La documentation confirme que depuis Codex 0.134.0 les profils résident dans
`~/.codex/<nom>.config.toml`. Les trois profils sources ont le même ancien format ;
l'échec a été reproduit directement pour `terra`.
[OpenAI, profils de configuration, consulté le 8 septembre](https://learn.chatgpt.com/docs/config-file/config-advanced#profiles).

Correction proposée : créer les trois fichiers de profil dans les sources du
dépôt et les déployer avec l'installateur. Ajouter un contrôle d'acceptation par
la CLI réelle, sous home temporaire, et actualiser l'inventaire. La copie des
profils vers Windows doit suivre un contrat explicite sans écraser son
`config.toml` app-owned. Ce défaut relève de l'évolution de Codex, pas d'Astra.

**2. P1 — Le prochain déploiement ne préserverait pas ton défaut Astra actuel.**

| Surface                                                            | Modèle / effort constaté                             |
| ------------------------------------------------------------------ | ---------------------------------------------------- |
| Source Git, `harnesses/codex/config.toml:7–8`                      | `gpt-5.6-sol` / `xhigh`                              |
| Fichier local `~/.codex/config.toml:7–8`                           | `gpt-6-astra` / `high`                               |
| Instructions Codex, `harnesses/codex/instructions.overlay.md:5–13` | Orchestration Sol xhigh ; escalade Sol ultra         |
| Rôle `critical`                                                    | Sol xhigh                                            |
| Rôle `explore`                                                     | Luna high, avec `sandbox_mode = "read-only"` déclaré |
| Rôle `super-joker`                                                 | Sol ultra                                            |

[install.sh](../../install.sh), lignes 608–630, repart de la configuration source
et ne préserve que certains états runtime. `--dry-run --only codex` annonce bien
la réécriture du fichier. Un déploiement tel quel remettrait donc Sol xhigh comme
défaut du fichier ; cela ne prédit pas le modèle d'une conversation déjà ouverte.

Correction proposée : réconcilier le choix quotidien avec Git et l'overlay avant
le prochain déploiement. Conserver les modèles 5.6 comme options spécialisées est
valide. Sol ultra n'est toutefois plus une escalade évidente de capacité par
rapport à un parent Astra : le présenter comme une seconde analyse spécialisée
tant qu'une évaluation locale ne justifie pas davantage.

Les rôles natifs `worker` et `explorer` existent ; leur absence du dossier
`agents/` n'est pas un défaut. Le format des trois agents personnalisés est
conforme au mécanisme documenté. Les paramètres de session peuvent également
modifier les valeurs héritées, notamment les permissions : le mot « read-only »
dans une description ne suffit pas à prouver une isolation effective.
[OpenAI, agents personnalisés et héritage, consulté le 8 septembre](https://learn.chatgpt.com/docs/agent-configuration/subagents).

**3. P1 — Les procédures se donnent des consignes opposées sur les petits travaux.**

[instructions/common.md](../../instructions/common.md), lignes 18–23, prévoit
XS direct, S avec plan court et M sans fichier de spécification par défaut.
Dans le cache Superpowers 6.3.0 proposé à cette session, le skill `brainstorming`
demande une validation préalable même pour le chemin « bounded »
(`skills/brainstorming/SKILL.md:14–20,35–44,54–61`). `using-superpowers` demande
une invocation dès qu'un skill semble potentiellement pertinent
(`skills/using-superpowers/SKILL.md:10–24`).

Ponytail 4.9.0 demande à l'inverse de poursuivre lorsqu'un choix raisonnable
suffit (`skills/ponytail/SKILL.md:62`). Son principe d'un contrôle minimal ne
remplace pas non plus les vérifications explicitement requises par un projet.

Ces tensions sont vérifiables dans les textes. Elles ne prouvent pas un blocage
systématique : les instructions explicites de Cyril et celles de priorité
supérieure restent déterminantes. La session actuelle contient déjà des
consignes fortes d'autonomie ; les recopier intégralement dans le dépôt
ajouterait encore une couche.

Correction proposée : expliciter une seule règle d'arbitrage dans le socle,
puis réserver le workflow complet de conception aux choix structurants.
Conserver les procédures utiles de diagnostic, test et revue sans obliger leur
enchaînement sur toute retouche. Les recouvrements TDD/revue entre Matt Pocock,
Superpowers et `autoship` doivent être arbitrés par tâche, pas tous cumulés.

**4. P2 — Le seuil de huit heures est un mauvais critère de délégation.**

Le défaut inline sous huit heures vient de
[instructions/common.md](../../instructions/common.md), lignes 25–28.
L'[overlay Codex](../../harnesses/codex/instructions.overlay.md), lignes 17–23,
permet une petite tâche S déléguée et préconise un rôle d'exploration. Ce n'est
pas une interdiction absolue, mais le critère temporel masque les critères
utiles : indépendance, volume de contexte, coût de coordination et intérêt
d'un regard distinct.

Cette session comporte aussi une instruction du harness qui limite les spawns
aux demandes explicites de l'utilisateur ou des instructions/skills applicables.
Son origine exacte n'est pas établie par le dépôt. Modifier un feature flag ou
le seul seuil de huit heures ne garantit donc pas une délégation proactive.

Correction proposée : conserver XS direct, scripts pour les transformations
déterministes, et permettre une délégation bornée pour un lot autonome ou une
revue indépendante lorsque le bénéfice attendu dépasse la coordination.
Conserver la décision d'architecture, l'intégration et la vérification au parent.
Les deux sous-agents utilisés pour cet audit établissent la disponibilité de la
capacité dans cette session, pas son efficacité pour toutes les tâches.

**5. P1 — `autoship` surestime la couverture du lint par les hooks.**

[shared/skills/autoship/SKILL.md](../../shared/skills/autoship/SKILL.md), lignes
75–78, prescrit le lint via les hooks et demande de ne pas le relancer
manuellement. Or
[harnesses/codex/scripts/format-on-save.sh](../../harnesses/codex/scripts/format-on-save.sh),
lignes 11–28, exécute Ruff sur les fichiers Python, `rustfmt` sur Rust,
`biome format` sur JS/TS et Prettier sur d'autres formats.

Même lorsqu'il est déclenché, ce hook n'assure ni le typage du projet, ni Clippy,
ni un lint TypeScript complet. Il saute aussi un outil absent. L'automatisation
du formatage reste utile ; la conclusion « lint du projet exécuté » n'en découle
pas. La preuve manquante concerne la couverture, sans présumer ici que chaque
édition active effectivement le hook.

Correction proposée : faire exécuter à `autoship` les commandes projet
identifiées dans sa phase initiale, sauf si une preuve montre que le même
contrôle vient déjà de passer. Garder le hook comme commodité d'édition.

**6. P2 — La reproductibilité couvre mieux les sources que le comportement complet.**

Les submodules sont ancrés à des SHA dans Git et testés avant installation.
C'est un point fort ; être en retrait de `main` n'est pas en soi un défaut.
À l'inverse, le bootstrap Codex met à jour les marketplaces lors de
l'installation ([install.sh](../../install.sh), lignes 1003–1027), Playwright
utilise `@latest`, et Superpowers vient du catalogue distant. Le cache exposé
ici est en 6.3.0, Ponytail en 4.9.0 ; ces états ne sont pas entièrement définis
par le commit audité.

Correction proposée : pour les comparaisons de comportement, enregistrer la
version CLI, les versions/révisions de plugins, le modèle/effort et les règles
actives. Tester les mises à jour sur quelques cas connus. Aucune installation
ou suppression de plugin supplémentaire n'est nécessaire pour commencer.

Le hub contient 16 skills locaux et 32 skills Matt Pocock validés par la suite.
Ce nombre ne mesure ni les tokens effectivement chargés ni les skills visibles
dans toute session. Le standard distingue métadonnées de découverte, corps
chargé au déclenchement et ressources chargées au besoin. Réduire les
déclenchements inutiles importe davantage que supprimer des dossiers sur la
seule base d'un comptage.
[Agent Skills, spécification, consultée le 8 septembre](https://agentskills.io/specification).

**7. P1 — Il manque un contrôle de compatibilité du workflow réel.**

Les tests actuels vérifient correctement copies, fusions, liens, sauvegardes et
invariants. Le test des plugins emploie une CLI factice
([tests/test-codex-plugins.sh](../../tests/test-codex-plugins.sh), lignes 12–25).
Un TOML accepté par son parseur peut donc conserver des paramètres qu'une
nouvelle CLI refuse dans un workflow particulier, comme les profils.

Correction proposée : ajouter un petit test d'acceptation du profil déployé par
la CLI réelle, isolé du home de production. Garder les tests déterministes
existants. Les évaluations avec modèle sont une couche distincte, à exécuter
lors d'un changement de modèle ou de politique, pas à chaque modification.

**Configuration de référence proposée pour la prochaine comparaison.**

| Élément                           | Proposition                                               | Justification                                                                              |
| --------------------------------- | --------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| Parent quotidien                  | Astra high                                                | Reprendre l'effort effectif local pour établir une référence stable.                       |
| Alternative parent                | Sol, effort explicite dans un profil valide               | Garder une option comparable et un repli connu.                                            |
| Implémentation autonome et bornée | Terra high                                                | Conserver le routage existant ; mesurer la qualité sur les tâches déléguées.               |
| Exploration ciblée                | Luna high                                                 | Conserver le rôle spécialisé ; vérifier ses permissions effectives si l'isolation importe. |
| Travail critique                  | Parent Astra, revue distincte selon le besoin             | Ne pas confondre effort élevé et supériorité d'un modèle moins récent.                     |
| Efforts max/ultra                 | Ponctuels                                                 | Aucun résultat local ne justifie leur coût systématique.                                   |
| Fast mode                         | Conserver désactivé                                       | Aucun besoin de changement établi dans cet audit.                                          |
| Instructions                      | Socle court, contraintes projet, skills métier déclenchés | Conserver les conventions utiles, réduire les arbitrages contradictoires.                  |

La séparation source/runtime, les sauvegardes, les homes de test temporaires,
la protection de la configuration Windows, les contrôles exécutables et les
skills métier sont à conserver. L'usage actuel de `approval_policy = "never"`
avec `danger-full-access` est un choix d'autonomie, pas une optimisation Astra
ni une garantie d'isolation. Cet audit ne propose pas de le changer implicitement.

**Proposition ciblée de consignes, non appliquée.** Après arbitrage, remplacer
les formulations trop larges de `instructions/common.md:9,25–28` par :

```text
Demander avant un choix structurant ou une ambiguite qui change le resultat.
Pour un detail reversible, formuler une hypothese raisonnable et poursuivre.
Les workflows de skills respectent l'echelle XS/S/M/L+ et les autorisations
deja donnees ; ils n'ajoutent pas de validation humaine par simple rituel.

XS : direct. Utiliser un script pour les transformations deterministes.
Deleguer un lot autonome ou une revue independante si le gain attendu justifie
la coordination, dans les limites du harness. Le parent integre et verifie.
```

Dans `autoship:75–78`, remplacer la présomption de lint par hook par :

```text
Executer les controles projet identifies en phase initiale. Ne pas repeter un
controle identique deja passe sur le meme etat. Un hook de formatage ne vaut
pas preuve du lint ou du typage du projet.
```

**Vérifications exécutées et limites.**

| Contrôle                                                           | Résultat                                                                          |
| ------------------------------------------------------------------ | --------------------------------------------------------------------------------- |
| `bash tests/run-all.sh`                                            | PASS, 15 suites shell ; Ruff, mypy et 7 tests Python inclus.                      |
| `bash -n install.sh update.sh tests/*.sh harnesses/*/scripts/*.sh` | PASS.                                                                             |
| `git diff --check`                                                 | PASS.                                                                             |
| `codex doctor --summary --ascii --no-color`                        | 19 OK, 0 warn, 0 fail ; configuration de base chargée et connectivité disponible. |
| `codex features list`                                              | Multi-agent, multi-agent v2 et plugins distants actifs ; Fast désactivé.          |
| `codex --profile terra mcp list --json`                            | ÉCHEC reproduit : ancien format de profil refusé.                                 |
| `./install.sh --only codex --dry-run`                              | Réécriture prévue de `config.toml` et `AGENTS.md`, sans application.              |
| `./install.sh --check`                                             | ÉCHEC : six fichiers divergents, détaillés ci-dessous.                            |

Les divergences signalées concernent Claude (`settings.json`, `CLAUDE.md`),
Codex (`config.toml`, `AGENTS.md`), Kimi (`config.toml`) et OpenCode
(`opencode.json`). Elles n'ont pas toutes la même importance : modèle et endpoint
Linear diffèrent côté Claude ; modèle et effort diffèrent côté Codex ; les
écarts du `AGENTS.md` Codex portent seulement sur les formulations RTK/Stop ;
l'objet `formatter` est absent du runtime OpenCode. Les deux TOML Kimi parsés
sont sémantiquement égaux, malgré le signal de dérive. Le détail du rendu Kimi
et du document Claude reste à réconcilier avant tout déploiement global.

La base CLI se charge donc correctement, mais cela ne valide pas les profils.
Les tests de copie Windows passent sous environnement temporaire Linux ; aucune
exécution native Windows/macOS ni validation interactive de chaque MCP n'a été
faite. Aucun benchmark de résolution avec les variantes de configuration n'a
été lancé. Les gains de temps, coût, délégation ou qualité restent à mesurer.

**Comment trancher les réglages sans extrapoler.** Après les corrections
déterministes, comparer la référence Astra high avec une seule variation à la
fois : consignes de processus allégées, effort, puis politique de délégation.
Utiliser six tâches représentatives : retouche XS, bug avec reproduction,
feature bornée, revue indépendante, exploration multi-module et tâche longue
avec reprise. Garder les mêmes commits de départ et critères d'acceptation.

Mesurer achèvement, régressions, respect des contraintes, interventions humaines,
temps total, tokens cumulés parent/enfants et vérifications inutiles. Répéter les
cas où la différence semble utile ; six tâches constituent un pilote, pas une
preuve statistique. Une variante ne doit pas gagner seulement en temps en
abandonnant un contrôle requis. Pour les coûts, distinguer consommation de
tokens, facturation API et limites de l'abonnement.

La recherche a couvert les recommandations officielles Astra/Codex, les auteurs
de configurations et frameworks, les études de fichiers de contexte et de
multi-agent, puis les premiers signalements Astra. Elle s'arrête ici car les
défauts prioritaires disposent de preuves locales, et les sources supplémentaires
consultées ne lèvent pas l'absence d'évaluation contrôlée de notre configuration
avec Astra.

## Suivi d'application — 8 septembre 2026

Après accord de Cyril, les corrections sont appliquées au socle et aux overlays
Claude, Codex, Kimi et OpenCode. Les modèles et efforts déclarés restent inchangés :
Sol xhigh demeure le défaut Codex, avec priorité au choix explicite en session.

- Profils Codex migrés dans trois fichiers natifs, déployés sous Linux et copiés
  vers Windows. Le chargement des trois profils passe avec Codex 0.153.4 dans un
  home temporaire, sans appel de modèle.
- Arbitrage commun des petits travaux et des autorisations, délégation selon
  l'indépendance et le coût de coordination ; suppression du seuil de huit heures.
- Autoship exige les contrôles projet réels et distingue les axes de revue.
- Comparaison sémantique du TOML Kimi : une différence de mise en forme seule
  n'entraîne plus de réécriture.
- [Procédure de validation](../configuration-validation.md) ajoutée pour relever
  les versions effectives et comparer les comportements sans attribuer au modèle
  les effets d'un changement de plugin ou d'instructions.

Validation locale : **16 suites shell passent**, avec Ruff, mypy et 7 tests Python,
ainsi que la syntaxe shell et `git diff --check`. Le déploiement a utilisé
`AGENT_CONFIG_SKIP_PLUGINS=1 ./install.sh`, après simulation, avec sauvegardes
datées `20260908-083216-839724667-22385`. Les plugins n'ont pas été mis à jour.
Après installation, `./install.sh --check` passe sans dérive et les trois
commandes `codex --profile <nom> mcp list --json` passent aussi sous le home Linux
réel. Le défaut effectif du fichier est vérifié : Sol xhigh, sans table legacy.

Versions CLI relevées : Codex **0.153.4**, Claude **2.1.261**, Kimi **0.31.1**,
OpenCode **1.3.13**. Révision de départ `cbbc9b4`, avec modifications locales non
commitées. Submodules inchangés : Anthropic
`f6656c1256d5a8adfa37db9110046ef20bac644c`, Matt Pocock
`8b78b531ab965735c5dc74f6f7a219e1e37326df`. Le catalogue de cette session expose
Superpowers 6.3.0 et Ponytail 4.9.0 ; cela ne constitue pas un inventaire complet
des plugins effectivement utilisés par chaque harness.

**Limite Windows constatée :** son `config.toml` existant contient encore les
tables legacy `terra`, `luna` et `sol-high`. Le contrat seed-only impose de le
préserver ; son empreinte est identique après installation. Les nouveaux fichiers
sont copiés, mais ces tables doivent encore être migrées avant utilisation des
profils sur une CLI récente. Un contrôle de conformité de l'installateur ne
garantit pas la compatibilité de cette configuration app-owned. Aucune exécution
native Windows/macOS ni comparaison de résolution avec modèle n'a été réalisée.
