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

Agents are organized into one integrated development suite:

- **Development agents** — a tightly integrated pipeline: `b-plan → b-tdd → b-gate → b-review → b-commit`, with `b-analyze`, `b-debug`, `b-docs`, `b-research`, and `b-observe` as supporting tools. `b-execute-plan` orchestrates the full pipeline.
- **Model allocation** — `b-plan`, `b-gate`, `b-review`, and `b-analyze` use `anthropic/claude-sonnet-4-6`; execution-oriented agents remain on `hdwebsoft/gpt-5.4` unless specified otherwise.

Quick lookups and news requests should call `brave_web_search` / `brave_news_search` directly instead of routing through separate utility agents.

**Execution guardrail**: in `b-execute-plan`, greenfield plans auto-skip pre-execution analysis. For existing-code plans, Step 0 (`b-analyze`) is risk-based: require it only for ambiguous scope, unfamiliar or multi-file/multi-layer work, shared/public/high-blast-radius modules, or stale/missing `## Context`. Small, local, well-scoped changes may skip it.

**Post-execution suggestion guardrail**: when `b-execute-plan` finishes a plan, it must suggest follow-up actions with explicit subagent names when applicable — e.g. `@b-review` for diff review and `@b-commit` for commit / PR text — rather than generic wording.

**OpenCode workflow**: planning (`@b-plan`) and execution (`@b-execute-plan`) both happen within OpenCode. Plan files must always be written inside the current project root at `.opencode/b-plans/*.md` and track step state there.

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
