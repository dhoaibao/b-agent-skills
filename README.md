# b-agent-skills

A personal skill suite for **Claude Code** and **OpenCode**.

## Install & Update

```bash
curl -fsSL https://raw.githubusercontent.com/dhoaibao/b-agent-skills/main/install.sh | bash
```

Then **restart Claude Code or OpenCode** to load the skills.

> **To update skills later**: run `/b-sync` in Claude Code (or `@b-sync` in OpenCode), then restart Claude Code / OpenCode.

---

## Overview

Skills are organized into two groups:

- **Development skills** — a tightly integrated pipeline: `b-plan → b-tdd → b-gate → b-review → b-commit`, with `b-analyze`, `b-debug`, `b-docs`, `b-research`, and `b-observe` as supporting tools. `b-execute-plan` orchestrates the full pipeline.
- **Personal / daily skills** — standalone utilities: `b-quick-search`, `b-news`, `b-sync`.

**Hybrid workflow**: Claude Code handles planning (`b-plan`), OpenCode handles execution (`b-execute-plan`). Plan files in `.claude/b-plans/*.md` are the shared contract.

**Git-safety guardrail**: destructive git commands are prohibited in all skills except `b-commit`, which owns all git write operations.

### MCP dependencies

| MCP | Role |
|---|---|
| `context7` | Live, version-accurate library docs |
| `brave-search` | Real web search |
| `firecrawl` | Full page scraping |
| `jcodemunch` | Code structure & call graph analysis |
| `sequential-thinking` | Structured reasoning |

Verify all 5 are connected with `/mcp` in Claude Code.

### Model assignments

| Skill | Claude Code model | OpenCode model |
|---|---|---|
| `b-analyze` | `sonnet` | `hdwebsoft/gpt-5.4` |
| `b-commit` | `haiku` | `github-copilot/claude-haiku-4-5` |
| `b-debug` | `sonnet` | `hdwebsoft/gpt-5.4` |
| `b-docs` | `haiku` | `hdwebsoft/gpt-5.4` |
| `b-execute-plan` | `sonnet` | `hdwebsoft/claude-sonnet-4-6` |
| `b-gate` | `haiku` | `github-copilot/claude-haiku-4-5` |
| `b-news` | `haiku` | `github-copilot/claude-haiku-4-5` |
| `b-observe` | `sonnet` | `hdwebsoft/gpt-5.4` |
| `b-plan` | `sonnet` | `hdwebsoft/claude-sonnet-4-6` |
| `b-quick-search` | `haiku` | `github-copilot/claude-haiku-4-5` |
| `b-research` | `sonnet` | `hdwebsoft/gpt-5.4` |
| `b-review` | `sonnet` | `hdwebsoft/gpt-5.4` |
| `b-sync` | `haiku` | `github-copilot/claude-haiku-4-5` |
| `b-tdd` | `sonnet` | `hdwebsoft/gpt-5.4` |

---

## Skill reference

See [REFERENCE.md](REFERENCE.md) for full details — triggers, output format, rules, and skill distinctions.
