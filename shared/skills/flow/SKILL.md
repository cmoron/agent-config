---
name: flow
description: "Déclare le flow de travail d'un projet : default, superpowers ou pocock."
disable-model-invocation: true
---

# Flow

Pose dans le projet courant le flow que Cyril a choisi. Trois valeurs :

- `default` : un seul jet, pour un projet jetable.
- `superpowers` : le plugin Superpowers conduit cadrage, plan et exécution.
- `pocock` : interview, `GLOSSARY.md` et ADR, puis spec, tickets et
  implémentation en parallèle.

Le déroulé de chaque flow est décrit dans `docs/flows.md` du dépôt
`agent-config`.

## Étapes

1. Prendre le flow donné en argument. Sans argument, ou avec une autre valeur,
   demander lequel des trois.
2. Écrire la ligne `Flow : <valeur>` dans `AGENTS.md`, en le créant s'il
   n'existe pas : c'est le seul fichier que tous les harnesses lisent. Si le
   projet a aussi un `CLAUDE.md`, y écrire la même ligne, car Claude Code ne lit
   alors plus `AGENTS.md`. Une ligne `Flow :` déjà présente est remplacée,
   jamais doublée.
3. Régler le plugin Superpowers, désactivé dans les réglages globaux, dans
   `.claude/settings.json` du projet :
   - `superpowers` : poser `enabledPlugins["superpowers@claude-plugins-official"]`
     à `true`, en fusionnant avec le contenu existant. Si `claude plugin list`
     ne montre pas le plugin, l'installer avec
     `claude plugin install superpowers@claude-plugins-official --scope project`.
   - `default` ou `pocock` : retirer cette clé si elle est présente.
4. Pour `pocock`, dire à Cyril de lancer `/setup-matt-pocock-skills` si le
   projet n'utilise pas GitHub Issues avec les labels canoniques. Sinon le skill
   `github-tracker` suffit.
5. Rendre compte : la ligne écrite, le fichier touché, l'état du plugin. Rappeler
   qu'une session Claude Code déjà ouverte garde son état jusqu'au redémarrage.

Terminé quand la ligne existe une seule fois dans le projet et que l'état du
plugin correspond au flow.

Sous Pi, ce skill se lance par `/skill:flow`. L'activation par projet ne vaut
que pour Claude Code. Sous Pi et Codex,
Superpowers est installé globalement : seule la ligne `Flow :` y oriente
l'agent.
