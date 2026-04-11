# b-agents

A lean 4-agent suite for **Claude Code**.

## Install & Update

```bash
curl -fsSL https://raw.githubusercontent.com/dhoaibao/b-agents/main/install.sh | bash
```

Then **restart Claude Code** to load the agents.

---

## Overview

Four agents covering the full development cycle:

| Agent | When to use |
|---|---|
| `b-plan` | Think before coding — task decomposition, approach evaluation, plan file |
| `b-research` | All external knowledge — library docs, comparisons, multi-source research |
| `b-debug` | Full-loop debugging — trace, confirm root cause, fix, verify |
| `b-review` | Pre-PR review — logic, requirements, edge cases, test adequacy |

**Typical flow:**
```
b-plan → [implement manually] → b-review → commit
b-research  (any time you need docs or comparisons)
b-debug     (any time something breaks)
```

See [REFERENCE.md](REFERENCE.md) for full details — triggers, output format, rules, and agent distinctions.

---

### MCP dependencies

| MCP | Role |
|---|---|
| `context7` | Live, version-accurate library docs |
| `brave-search` | Real web search |
| `firecrawl` | Full page scraping |
| `jcodemunch` | Code structure & call graph analysis |
| `sequential-thinking` | Structured reasoning |

Verify all 5 are connected in Claude Code (`/mcp`).
