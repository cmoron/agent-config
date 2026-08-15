# Revue du plan de consolidation — Claude Code

**Objet :** `docs/superpowers/plans/2026-08-15-agent-config-consolidation.md`
**Commit relu :** `0bdd9ff` — *docs: define the multi-harness consolidation path*
**Date :** 2026-08-15
**Relecteur :** Claude Code (Opus 5), session d'audit multi-harness

Cette revue est destinée à être consolidée par Codex avant traitement. Chaque
constat porte sa preuve reproductible pour ne pas exiger de confiance.

---

## Verdict

Plan solide, à corriger avant exécution. Il tranche le désaccord ouvert entre
Claude et Codex sur le rendu des instructions par une **troisième voie
meilleure que les deux positions initiales** : rendu uniforme `common + overlay`
vers la cible native des quatre harnesses, sans template à marqueurs, sans
import `@`, sans hub `AGENTS.md`. Un seul mécanisme, testable à l'identique
quatre fois. Position adoptée.

Sont également corrects et à conserver tels quels :

- les portes TDD (test en échec avant implémentation) à chaque tâche ;
- la classification `link` / `copy` / `merge` / `seed-only` / `ignore` ;
- la réconciliation déclarative limitée aux artefacts que l'installateur gère ;
- le refus du round-trip automatique runtime → source ;
- le report de MCP, hooks partagés et plugins jusqu'à dérive mesurée ;
- l'exigence de validation humaine avant déploiement réel et avant archivage.

**Les quatre bloquants relèvent d'une même cause** : le plan décrit bien la
structure cible, mais n'a pas fait l'inventaire exhaustif de ce que les anciens
dépôts déploient réellement. Voir la recommandation de Task 0 en fin de document.

---

## Bloquants — perte de contenu existant

### B1. `RTK.md` n'existe nulle part dans l'arborescence cible

`~/.claude/CLAUDE.md` se termine par `@RTK.md`. L'import se résout aujourd'hui
uniquement parce que `install.sh` symlinke `RTK.md` à côté dans `~/.claude/`.

Le rendu produit `common + overlay` et aucune étape ne déploie ce fichier :
l'import pointera dans le vide, **sans erreur visible**.

```
claude-config/CLAUDE.md:102:@RTK.md
claude-config/install.sh:39:for f in CLAUDE.md RTK.md settings.json; do
```

Ni `codex-config` ni `kimi-config` n'ont de `RTK.md` séparé : Kimi a inliné le
contenu dans son `AGENTS.md`, Codex dans une section `## RTK` de
`global/AGENTS.md`.

**Résolution attendue :** inliner RTK dans `harnesses/claude/instructions.overlay.md`,
cohérent avec le principe « une seule source composée » et avec ce que font déjà
les deux autres harnesses. Alternative acceptable : faire de `RTK.md` un artefact
géré du harness Claude, déployé à côté du rendu.

### B2. Le submodule `upstream/anthropic-skills` disparaît sans décision

`claude-config` déploie huit skills Anthropic dans `~/.claude/skills` par
allowlist explicite depuis un submodule Git :

```
.gitmodules → upstream/anthropic-skills → https://github.com/anthropics/skills.git
allowlist install.sh : claude-api mcp-builder webapp-testing doc-coauthoring
                       docx pdf pptx xlsx
```

Ces huit skills sont absents de l'arborescence cible **et** de la liste
« Différé jusqu'à un besoin mesuré ». Après archivage de `claude-config`, les
liens correspondants pointent dans le vide.

**Résolution attendue :** décision explicite — repris (submodule + allowlist sous
`harnesses/claude/`) ou abandon assumé et documenté. Pas d'omission par défaut.

### B3. Les chemins de hooks en dur pointent vers les anciens dépôts

```
claude-config/settings.json  → $HOME/src/claude-config/scripts/{format-on-save,
                                notify-sound,protect-env,reflect-nudge}.sh   (4×)
kimi-config/config.toml      → $HOME/src/kimi-config/scripts/{format-on-save,
                                protect-env,notify-sound,reflect-nudge}.sh   (5×)
codex-config/hooks.json      → $HOME/.codex/scripts/*.sh                     (4×)
```

Aucune étape du plan ne réécrit ces chemins. Codex utilise déjà le **chemin
déployé** plutôt que le chemin source : c'est le motif robuste, à généraliser
aux trois autres harnesses.

**Criticité particulière :** le symptôme n'apparaît qu'à l'archivage des anciens
dépôts, donc **après** le gate de Task 8, quand tout est réputé validé. Aucun
test sous home temporaire ne le détecte, puisque les chemins source existent
encore pendant toute la migration.

### B4. `harnesses/codex/assets/` duplique `shared/assets/`

```
a194c4cc479b59ba13746b08bca634b9  claude-config/assets/warcraft-3-paysan-travail-termine.mp3
a194c4cc479b59ba13746b08bca634b9  codex-config/assets/warcraft-3-paysan-travail-termine.mp3
a194c4cc479b59ba13746b08bca634b9  kimi-config/assets/warcraft-3-paysan-travail-termine.mp3
```

Cas byte-identique que le plan réserve explicitement à `shared/`. Seul endroit de
l'arborescence cible qui reconduit la duplication éliminée partout ailleurs.

---

## Ordonnancement

### O1. Fenêtre dangereuse entre Task 8 Step 3 et Step 6

Le plan pose que les anciens installateurs « restent autoritatifs jusqu'au gate
de déploiement réel de Task 8 ». C'est correct pendant les Tasks 1 à 7, qui ne
touchent que des homes temporaires.

Mais après le premier déploiement réel (Task 8 Step 3), `~/.agents/skills` est
peuplé pour de vrai — et `codex-config/install.sh:134` contient :

```bash
prune_managed_links "$HOME/.agents/skills"
```

Pendant toute la fenêtre d'observation « deux cycles réels » (Step 4) jusqu'à
l'archivage (Step 6), un `./update.sh` réflexe dans l'ancien dépôt efface les
skills partagés des **quatre** harnesses simultanément.

**Résolution attendue :** la neutralisation des anciens installateurs (garde en
tête de script, ou retrait du bit exécutable) appartient au Step 3, pas au
Step 6.

---

## Mineurs

### M1. `--check` doit asserter l'absence de `~/.agents/AGENTS.md`

Le plan réserve le hub aux skills. Mais Kimi et OpenCode lisent
`~/.agents/AGENTS.md` nativement — cumul vérifié chez Kimi (marqueur déposé dans
le hub, restitué par `kimi -p` alors que `~/.kimi-code/AGENTS.md` était présent).
Un fichier résiduel ajouterait une source d'instructions invisible sur deux
harnesses. Deux exemplaires ont été créés puis retirés pendant l'audit du
2026-08-15 : le cas n'est pas théorique.

### M2. Dépendance de test sur un chemin app-owned

Task 3 Step 5 appelle :

```
/home/cyril/.codex/skills/.system/skill-creator/scripts/quick_validate.py
```

`.system` est réinstallé par les mises à jour de Codex. Dépendance fragile pour
une porte de vérification versionnée. Vendorer le validateur ou rendre l'étape
tolérante à son absence.

### M3. Task 2 Step 1 contient un test qui ne peut pas échouer

`test ! -e global/AGENTS.md` est trivialement vrai dans un dépôt neuf. Il ne
satisfait pas la porte « écrire un test en échec » qu'il est censé servir.

### M4. `~/.claude/CLAUDE.md` devient un fichier généré

Conséquence non documentée du rendu uniforme : la boucle d'auto-amélioration de
l'utilisateur (`revise-claude-md`, nudge du Stop hook `reflect-nudge.sh`) propose
des éditions de `CLAUDE.md`. Elles doivent désormais viser `instructions/common.md`
ou l'overlay, faute de quoi elles sont écrasées au prochain `install.sh`.
`--check` le détectera après coup ; une ligne de README et un en-tête « fichier
généré — ne pas éditer » dans le rendu l'éviteront avant.

---

## Réponses aux six questions du plan

**1. Le rendu uniforme évite-t-il toute dépendance cachée aux précédences ?**

Oui, à une dépendance résiduelle près : il faut garantir l'absence de
`~/.agents/AGENTS.md` (cf. M1). Hors périmètre mais non couvert par `--check` :
Claude charge également `~/.claude/rules/*.md` et sa mémoire automatique
(`~/.claude/projects/<repo>/memory/`), qui restent des sources d'instructions
concurrentes non gérées par l'installateur.

**2. Une politique commune cite-t-elle implicitement une capacité de harness ?**

Oui, plusieurs, dans les fichiers actuels : « sous-agent `Explore` » ; `/clear`
et `/compact` (Kimi utilise `/new` et une syntaxe de compact différente) ; la
syntaxe d'import `@RTK.md` ; « mémoire native … `MEMORY.md` » ; toute l'échelle
Haiku / Sonnet / Opus / Fable.

Le piège le moins visible : **« Le formatage passe par hooks
(ruff/rustfmt/prettier) — ne relance pas manuellement » est faux pour OpenCode**,
qui n'a aujourd'hui aucun hook déployé. Une règle commune qui décrit une
infrastructure absente sur un harness est plus nuisible qu'une règle spécifique.

**3. La classification de mutabilité couvre-t-elle tous les fichiers réécrits ?**

Presque — il manque le cas principal. `~/.claude/settings.json` est aujourd'hui
un **symlink vers le dépôt**, et Claude Code y écrit (activation et désactivation
de plugins). Preuve à date : `git status` de `claude-config` montre
`M settings.json` sans édition manuelle.

Il ne peut donc pas être classé `link`. Il faut `merge`, avec `enabledPlugins` et
`extraKnownMarketplaces` soit explicitement possédés par la source, soit
explicitement préservés. C'est le même phénomène que le `config.toml` Codex
symlinké, déjà connu et documenté.

**4. Un skill supposé identique diffère-t-il hors de `SKILL.md` ?**

Oui, un seul : `grill-with-docs` porte `ADR-FORMAT.md` et `CONTEXT-FORMAT.md`.
Vérifié : les deux fichiers sont identiques entre Claude et Codex, donc la
promotion vers `shared/` reste valide. Les sept autres skills portables n'ont
aucun fichier annexe.

**Conséquence pour Task 3 :** le test de parité ne doit pas se limiter à
`SKILL.md`, sinon un fichier annexe divergent passerait inaperçu.

**5. Une étape peut-elle supprimer un artefact non géré ?**

Oui, une : la fenêtre O1 ci-dessus. Pour le reste, la règle « ne supprimer que
les symlinks cassés ou pointant dans `agent-config` » protège correctement le hub
partagé et les homes Windows.

**6. Quelle preuve runtime manque-t-il encore ?**

Trois :

- **OpenCode** — le mécanisme d'overlay n'a pas pu être testé : son provider
  configuré (`ollama/gemma4`) ne répond pas. Il faut un modèle fonctionnel avant
  de valider ce harness ; le support des chemins `~/` dans la clé `instructions`
  reste non vérifié.
- **Stratégie `merge`** — une fixture prouve le code, pas le comportement de
  l'application. Il faut observer une réécriture réelle (Kimi réécrit
  `config.toml` au `/login`) pour valider la préservation des clés runtime.
- **Heartbeat Nestor** — l'oracle est la VM, comme le plan l'identifie déjà
  correctement.

---

## Recommandation structurelle

Les quatre bloquants sont quatre instances d'une même classe : *artefact déployé
aujourd'hui, absent de l'inventaire cible*. Les corriger un par un laisse la
classe ouverte.

**Ajouter une Task 0 : inventaire de la surface de déploiement réelle.**

Énumérer ce que chaque ancien installateur produit effectivement sous
`~/.claude`, `~/.codex`, `~/.kimi-code`, `~/.config/opencode`, `~/.agents` et le
home Codex Windows — fichiers, liens, cibles, provenance — puis exiger que
chaque entrée soit classée `repris`, `abandonné` ou `différé` avant Task 2.

La même énumération, rejouée après le premier déploiement réel, devient le
diff de bascule attendu par Task 8 Step 3 : elle sert deux fois.

---

## Base de preuves

Constats issus de tests exécutés le 2026-08-15, pas de documentation :

| Fait | Méthode |
| --- | --- |
| Codex 0.146 découvre `~/.agents/skills` | sonde déposée dans le hub, présente dans `codex debug prompt-input` |
| Codex ne lit pas `~/.agents/AGENTS.md` | marqueur déposé, 0 occurrence dans le prompt rendu |
| Codex ne résout pas les imports `@` | `@/path/shared.md` reste du texte littéral dans le prompt |
| Kimi cumule hub + home | marqueur du hub restitué par `kimi -p`, fichier kimi présent |
| Claude : import officiel `@AGENTS.md` | documentation Claude Code, section AGENTS.md |
| 12 skills partagés, 8 identiques, 4 divergents | `diff` par skill entre `claude-config` et `codex-config` |
| 4/4 scripts de hooks divergent claude ↔ codex | `diff -q` par script |
| Assets identiques sur les trois dépôts | `md5sum` |

Versions au moment de l'audit : Claude Code 2.1.233, Codex 0.146.0,
OpenCode 1.3.13, Kimi Code 0.31.1.

Aucun fichier de configuration n'a été modifié : toutes les sondes ont été
retirées et `~/.config/opencode/opencode.json` restauré.
