# b-agents

A personal agent suite for **OpenCode**.

## Install & Update

```bash
curl -fsSL https://raw.githubusercontent.com/dhoaibao/b-agents/main/install.sh | bash
```

Then **restart OpenCode** to load the agents.

> **To update agents later**: rerun the install command above, then restart OpenCode.

---

## Overview

Agents are organized into two groups:

- **Development agents** — a tightly integrated pipeline: `b-plan → b-tdd → b-gate → b-review → b-commit`, with `b-analyze`, `b-debug`, `b-docs`, `b-research`, and `b-observe` as supporting tools. `b-execute-plan` orchestrates the full pipeline.
- **Personal / daily agents** — standalone utilities: `b-quick-search`, `b-news`.

**OpenCode workflow**: planning (`@b-plan`) and execution (`@b-execute-plan`) both happen within OpenCode. Plan files in `.opencode/b-plans/*.md` track step state.

**Codebase understanding workflow**: jcodemunch-backed agents now use a shared preflight: `resolve_repo` (cached repo map) → `suggest_queries` (entrypoint discovery) → `get_ranked_context` (bounded relevant context) before deeper symbol/file reads.

**Git-safety guardrail**: destructive git commands are prohibited in all agents except `b-commit`, which owns all git write operations.

### MCP dependencies

| MCP | Role |
|---|---|
| `context7` | Live, version-accurate library docs |
| `brave-search` | Real web search |
| `firecrawl` | Full page scraping |
| `jcodemunch` | Code structure & call graph analysis |
| `sequential-thinking` | Structured reasoning |

Verify all 5 are connected in OpenCode.

### Model assignments

| Agent | OpenCode model |
|---|---|
| `b-analyze` | `hdwebsoft/gpt-5.4` |
| `b-commit` | `github-copilot/claude-haiku-4-5` |
| `b-debug` | `hdwebsoft/gpt-5.4` |
| `b-docs` | `hdwebsoft/gpt-5.4` |
| `b-execute-plan` | `hdwebsoft/claude-sonnet-4-6` |
| `b-gate` | `hdwebsoft/gpt-5.4` |
| `b-news` | `github-copilot/claude-haiku-4-5` |
| `b-observe` | `hdwebsoft/gpt-5.4` |
| `b-plan` | `hdwebsoft/claude-sonnet-4-6` |
| `b-quick-search` | `github-copilot/claude-haiku-4-5` |
| `b-research` | `hdwebsoft/gpt-5.4` |
| `b-review` | `hdwebsoft/gpt-5.4` |
| `b-tdd` | `hdwebsoft/gpt-5.4` |

---

## Agent reference

See [REFERENCE.md](REFERENCE.md) for full details — triggers, output format, rules, and agent distinctions.
