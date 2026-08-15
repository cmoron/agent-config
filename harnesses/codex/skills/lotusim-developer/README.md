# Using the lotusim-developer skill

This Codex config ships a coding-agent skill at
`skills/lotusim-developer/` (`SKILL.md` + `references/`). The skill adds a
deeper, task-oriented map for LOTUSim work and opens with 6 field-tested
pitfalls.

`SKILL.md` follows the open agent-skill format (name/description frontmatter +
markdown), so it works with any harness that supports skills.

## Codex

`~/src/codex-config/install.sh` deploys this skill to `~/.codex/skills/` and,
when present, to the Windows Codex config directory.

## Universal installer (optional)

```bash
npx skills@latest add naval-group/LOTUSim
```

Fans the skill out to the agents you select. Third-party tool — review before use.

## Other harnesses

They all read `AGENTS.md` at the repo root with no setup. For first-class skill
support, see your harness's own skills documentation.
