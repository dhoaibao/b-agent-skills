# b-agents

A lean 4-agent suite for **OpenCode** subagents.

The suite is optimized around **symbol-first code analysis (jCodeMunch)** and **selective structured reasoning (Sequential Thinking only when ambiguity or trade-offs justify it)**.

## Install & Update

```bash
curl -fsSL https://raw.githubusercontent.com/dhoaibao/b-agents/main/install.sh | bash
```

Then **restart OpenCode** to load the agents.

---

## Overview

Four subagents covering the full development cycle:

| Agent | When to use |
|---|---|
| `b-plan` | Think before coding — task decomposition, approach evaluation, plan file |
| `b-research` | All external knowledge — library docs, comparisons, multi-source research |
| `b-debug` | Full-loop debugging — trace, confirm root cause, fix, verify |
| `b-review` | Pre-PR review — logic, requirements, edge cases, test adequacy |

**Typical flow:**
```
@b-plan [task] → [implement manually] → @b-review → commit
@b-research [question]  (any time you need docs or comparisons)
@b-debug [symptom]      (any time something breaks)
```

See [REFERENCE.md](REFERENCE.md) for full details — triggers, output format, rules, and agent distinctions.

---

### MCP dependencies

| MCP | Role |
|---|---|
| `context7` | Live, version-accurate library docs |
| `brave-search` | Real web search |
| `firecrawl` | Full page scraping |
| `jcodemunch` | Code structure, symbol-first retrieval, impact analysis |
| `sequential-thinking` | Structured reasoning |

Verify all 5 are connected in OpenCode.
