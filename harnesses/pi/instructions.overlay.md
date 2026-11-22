## Pi

### Modèles

- Principal : `claude-bridge/claude-fable-5-2` par défaut.
- Exécutant : `claude-bridge/claude-opus-5-5`. Relecteur : un sous-agent neuf
  sur Opus.
- Mécanique : `claude-bridge/claude-sonnet-5-5`, `claude-bridge/claude-haiku-5-5`
  pour le volume pur.
- Déléguer avec l'outil `subagent` en nommant le modèle. XS et S : inline.
- `claude-bridge/...` passe par le forfait Claude Code. `anthropic/...` est
  facturé au token.

### Garde-fous

- Pas de mode plan ni de prompt de permission. `cc-safety-net` bloque les
  commandes destructrices connues et l'accès aux secrets : rapporter un blocage,
  ne pas le contourner.
- Ce n'est pas une sandbox : annoncer une commande destructrice ou irréversible
  et attendre l'accord de Cyril.

### Outils

- Tâche à plusieurs étapes : outil `todo`. Choix structurant : `ask_user_question`
  avec des options concrètes.
- Documentation de bibliothèque : Context7 (`resolve-library-id`, puis
  `query-docs`). Web : `web_search`, puis `fetch_content` sur la source
  officielle.
- Sortie volumineuse ou appels indépendants : `codemode`, en ne renvoyant que
  l'extrait utile.
- Les fichiers édités sont formatés automatiquement (ruff, rustfmt, prettier) :
  relire un fichier avant de le rééditer.
- Skills : lire leur `SKILL.md` dans `~/.agents/skills` (`/skill:<nom>` côté
  utilisateur). Superpowers est installé comme paquet.
- Pas de mémoire native durable : ce qui doit survivre va dans un skill ou une
  instruction source.
