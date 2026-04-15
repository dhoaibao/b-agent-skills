# b-skills

A lean 4-skill suite for **Claude Code**.

The suite is optimized around **symbol-first code analysis (jCodeMunch)** and **selective structured reasoning (Sequential Thinking only when ambiguity or trade-offs justify it)**.
It also hardens jCodeMunch preflight against **stale cached indexes** and **empty-folder false positives** before any skill trusts indexed code context.

## Install & Update

```bash
curl -fsSL https://raw.githubusercontent.com/dhoaibao/b-agents/main/install.sh | bash
```

Then **restart Claude Code** to load the skills.

---

## Overview

Four skills covering the full development cycle:

| Skill | When to use |
|---|---|
| `/b-plan` | Think before coding — task decomposition, approach evaluation, plan file |
| `/b-research` | All external knowledge — library docs, comparisons, multi-source research |
| `/b-debug` | Full-loop debugging — trace, confirm root cause, fix, verify |
| `/b-review` | Pre-PR review — logic, requirements, edge cases, test adequacy |

**Typical flow:**
```
/b-plan [task] → [implement manually] → /b-review → commit
/b-research [question]  (any time you need docs or comparisons)
/b-debug [symptom]      (any time something breaks)
```

See [REFERENCE.md](REFERENCE.md) for full details — triggers, output format, rules, and skill distinctions.

---

### MCP dependencies

| MCP | Role |
|---|---|
| `context7` | Live, version-accurate library docs |
| `brave-search` | Real web search |
| `firecrawl` | Full page scraping |
| `jcodemunch` | Code structure, symbol-first retrieval, impact analysis |
| `sequential-thinking` | Structured reasoning |

Verify all 5 are connected in Claude Code (`/mcp`).