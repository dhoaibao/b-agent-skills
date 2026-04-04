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

**Execution guardrail**: in `b-execute-plan`, greenfield plans auto-skip pre-execution analysis, but plans that modify existing code always ask whether to run `b-analyze` first. Existing `## Context` is reused only when it still matches the current plan scope.

**OpenCode workflow**: planning (`@b-plan`) and execution (`@b-execute-plan`) both happen within OpenCode. Plan files in `.opencode/b-plans/*.md` track step state.

**Codebase understanding workflow**: jcodemunch-backed agents now use a shared preflight: `resolve_repo` (cached repo map) → `get_repo_outline` health check / re-index if coverage is implausibly low → `suggest_queries` (entrypoint discovery) → `get_ranked_context` (bounded relevant context) before deeper symbol/file reads.

**Structured reasoning workflow**: for non-trivial debugging, planning, trade-off analysis, and prioritization, agents must call `sequential-thinking` and surface the ordered result explicitly rather than hiding it behind free-form prose.

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

---

## Agent reference

See [REFERENCE.md](REFERENCE.md) for full details — triggers, output format, rules, and agent distinctions.
