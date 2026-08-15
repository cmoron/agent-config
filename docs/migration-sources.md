# Migration sources and verification

Snapshot captured on 2026-08-15. The repositories below remain untouched by
the implementation; their dirty files still belong to their original
worktrees.

| Source | Reference commit | Remote | Local changes at capture |
| --- | --- | --- | --- |
| `/home/cyril/src/codex-config` | `a6ab99b2748f85caba946cf98953121967a52a1f` | `https://github.com/cmoron/codex-config.git` | `config.toml` |
| `/home/cyril/src/claude-config` | `7ad1a9f40fc747114688bf66383b1a50c549022f` | `git@github.com:cmoron/claude-config.git` | `RTK.md`, `settings.json`, `skills/lotusim-developer/SKILL.md`, `skills/openclaw/SKILL.md` |
| `/home/cyril/src/kimi-config` | `852bc1a9b6ef81b9ea734732dee842fa257672b4` | `git@github.com:cmoron/kimi-config.git` | `README.md`, `mcp.json` |

## Classification

| Change | Decision | Rationale |
| --- | --- | --- |
| Codex `config.toml` | adopt | preserve the current Playwright launcher and disabled plugin state |
| Claude `RTK.md` | adopt | inline the current RTK behavior in the Claude overlay |
| Claude `settings.json` | adopt | retain the current model, hooks and plugin declarations through a targeted merge |
| Claude `lotusim-developer` | adopt as Claude-specific | the richer local variant remains native to Claude |
| Claude `openclaw` | adopt as Claude-specific, semantic reconciliation deferred | the current 30-minute heartbeat claim still conflicts with the 4-hour Codex variant; neither is promoted to shared without a runtime oracle |
| Kimi `mcp.json` | adopt | the runtime/source pair is Linear plus Context7; the removed third server is not reintroduced |
| Kimi `README.md` | ignore | superseded by this repository's README and deployment inventory |

The deployable sources contain only empty API-key placeholders or environment
variable references. Credentials, sessions, caches, trust state and OAuth data
were not imported or inspected for content.

## Binary-backed checks under temporary homes

All commands below used an isolated `HOME`, disabled plugin bootstraps and made
no model call. The installed versions were:

| Harness | Version | Command | Result |
| --- | --- | --- | --- |
| Codex | `0.146.0` | `codex debug prompt-input 'agent-config probe'` | one generated instruction block and 14 configured skills discovered (8 shared, 6 Codex-specific) |
| Claude Code | `2.1.233` | `claude doctor` | native binary healthy enough to run; the temporary home caused expected install-path/auth warnings; this command does not expose instruction or skill discovery |
| Kimi Code | `0.31.1` | `kimi doctor config <path>` and `kimi doctor tui <path>` | both rendered TOML files valid |
| OpenCode | `1.3.13` | `opencode debug skill --pure` | exactly 8 native mirrored skills, zero skill loaded from `~/.claude/skills` |

OpenCode officially supports
`OPENCODE_DISABLE_CLAUDE_CODE_SKILLS=1` to disable its Claude compatibility
layer: <https://opencode.ai/docs/rules/#claude-code-compatibility>. On the
installed 1.3.13 binary this also hides `~/.agents/skills`, so the installer
exports the flag through a managed block in `~/.profile.local` and mirrors the
shared skills into OpenCode's native skills directory. This empirical behavior
is covered by `tests/test-opencode.sh` and can be simplified if a later binary
honors the documented narrower scope.

Kimi exposes model-free config validation but no equivalent skill-discovery
dump. Claude Code exposes `doctor` but no model-free prompt-input command. Their
remaining discovery checks therefore stay structural until the authorized real
deployment is exercised interactively.
