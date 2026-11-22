---
name: github-tracker
description: "Contexte GitHub par défaut : tracker, labels, wayfinder et domaine. Charger avant de lire ou publier une issue, un label ou une PR, ou quand un skill Pocock cherche `docs/agents/`."
---

# GitHub tracker

L'absence de `docs/agents/` n'impose ni setup ni création de fichiers : utiliser
les valeurs ci-dessous. S'ils existent, `docs/agents/issue-tracker.md`,
`triage-labels.md` et `domain.md` remplacent chacun le défaut correspondant.
`setup-matt-pocock-skills` sert à personnaliser un projet, sur demande.

## Tracker

GitHub Issues, specs dans une issue parente, opérations via `gh`. Résoudre le
dépôt avec les remotes et `gh repo view` ; sur un fork, distinguer cible upstream
et fork. Plusieurs cibles plausibles ou aucun remote GitHub : demander le
tracker ; en autonomie, rester local et signaler le blocage plutôt que basculer
sur un tracker Markdown.

## Lecture et publication

Lire issue et commentaires via `gh issue view` ; chercher les doublons avant de
publier. Corps multilignes via `--body-file`. Publier uniquement dans le
périmètre demandé : une simple analyse ne crée ni issue, ni label, ni PR. Lier
PR et issue ; fermer les seules exigences livrées, pas une issue parente sur une
livraison partielle.

## Labels

Canoniques : `needs-triage`, `needs-info`, `ready-for-agent`,
`ready-for-human`, `wontfix`. Respecter un mapping local et vérifier les labels
existants avant usage ; créer un label manquant seulement pendant une publication
autorisée. Les PR externes ne se trient pas par défaut.

## Wayfinder

Carte = issue parente, tickets = sous-issues, dépendances natives si
disponibles, sinon liens `Part of #N` et `Blocked by #N`. Prendre un ticket
sans bloqueur ouvert ; garder décisions et liens vers les preuves dans la carte.

## Domaine

Lire `GLOSSARY.md` ou les contextes pertinents de `GLOSSARY-MAP.md` (anciens
noms : `CONTEXT.md`, `CONTEXT-MAP.md`) et les ADR applicables de `docs/adr/`,
s'ils existent. Leur absence est normale ; les créer seulement quand une décision
le justifie.
