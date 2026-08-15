# agent-config

Configuration personnelle multi-harness pour Claude Code, Codex, Kimi Code et
OpenCode.

Le depot est en cours de migration. Les anciens depots restent autoritatifs
tant que la bascule reelle n'a pas ete explicitement validee. L'installateur de
ce depot refuse actuellement tout deploiement; les premiers lots sont verifies
uniquement sous homes temporaires.

## Principes

- `shared/` contient uniquement les artefacts reellement portables.
- `harnesses/<name>/` contient les configurations et adaptations natives.
- Les instructions sont rendues depuis `instructions/common.md` et un overlay.
- `~/.agents` est reserve au hub de skills.
- Les fichiers app-owned sont copies ou fusionnes, jamais symlinkes vers Git.
- Credentials, sessions, caches et etats runtime restent hors Git.

Le plan executable et l'inventaire de migration vivent dans :

- `docs/superpowers/plans/2026-08-15-agent-config-consolidation.md`;
- `docs/deployment-inventory.md`;
- `docs/reviews/2026-08-15-plan-review-claude.md`.

## Etat attendu

Quand la migration sera terminee :

```bash
./install.sh --dry-run
./install.sh --check
./install.sh --only codex
./install.sh
```

Le deploiement reel restera protege par une validation humaine distincte.
