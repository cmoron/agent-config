# agent-config

Ce depot est la source declarative unique des configurations Claude
Code, Codex, Kimi Code et OpenCode de Cyril.

## Regles projet

- Ne jamais modifier les homes runtime pour implementer une fonctionnalite;
  travailler dans ce depot puis deployer avec `install.sh`.
- Les tests s'executent sous des homes temporaires; seul `./install.sh` touche
  les homes reels.
- Conserver les differences propres aux harnesses dans `harnesses/`.
- Ne promouvoir dans `shared/` qu'un artefact dont tout l'arbre est portable et
  semantiquement identique.
- Un fichier app-owned est copie, fusionne ou initialise une fois; il n'est
  jamais symlinke vers Git.
- L'installateur sauvegarde avant remplacement et ne purge que ses propres
  artefacts.
- Ne pas ajouter de plugin ou MCP sans demande explicite.
- Toute modification du contrat de deploiement doit mettre a jour les tests et
  `docs/deployment-inventory.md`.
- La cible Codex Windows contient de vrais fichiers et preserve son
  `config.toml` existant.
- Aucun archivage des depots legacy sans validation explicite.

## Verification minimale

```bash
bash tests/test-structure.sh
bash tests/test-python.sh
bash -n install.sh update.sh tests/*.sh harnesses/*/scripts/*.sh
git diff --check
```
