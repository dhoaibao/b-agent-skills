# b-skills

A lean 6-skill suite for **Claude Code**, plus one hidden legacy compatibility alias.

The suite is optimized around **symbol-first code analysis (Serena MCP)** and **selective structured reasoning (Sequential Thinking only when ambiguity or trade-offs justify it)**.
It uses Serena's best-practice flow: **activate project → symbol/file discovery → symbol overview → references → narrow reads → symbolic edits** before any skill trusts code context.

## Install & Update

```bash
curl -fsSL https://raw.githubusercontent.com/dhoaibao/b-skills/main/install.sh | bash
```

Then **restart Claude Code** to load the skills.

---

## Overview

Six primary skills covering the full development cycle. The repo still contains 7 skill files because `b-lookup` remains as a hidden legacy alias to `b-research` quick mode:

| Skill | When to use |
|---|---|
| `/b-plan` | Think before coding — quick/full planning, task decomposition, approach evaluation, plan file when needed |
| `/b-research` | All external knowledge — auto-detects quick lookup vs full research for docs, API facts, comparisons, and reports |
| `/b-debug` | Full-loop debugging — trace, confirm root cause, fix, verify |
| `/b-review` | Pre-PR review — logic, requirements, edge cases, test adequacy |
| `/b-test` | Test-driven development — write tests, fix failing tests, evaluate coverage |
| `/b-refactor` | Code refactoring — impact analysis, safe mechanical transformation, verify |

**Typical flow:**
```
/b-plan [task] → approve plan → implement from plan/protocol → run targeted checks → /b-review → commit
/b-research [question]  (any time you need docs, API facts, quick lookup, or comparisons)
/b-debug [symptom]      (any time something breaks)
/b-test [task]          (write or fix tests)
/b-refactor [target]    (mechanical code transformation)
```

`/b-plan` supports **quick mode** for scoped daily tasks and **full mode** for unclear, high-risk, or multi-layer work. It should also own broad or unclear refactors until they are reduced to concrete mechanical steps, at which point `/b-refactor` becomes the safer executor. After the user approves a plan, implementation may continue in the same session.

See [REFERENCE.md](REFERENCE.md) for full details — triggers, output format, rules, and skill distinctions.

---

### MCP dependencies

| MCP | Role |
|---|---|
| `serena` | Symbol discovery, structure overview, reference tracing, symbol-level edits, and Serena memory — the primary semantic code layer where supported |
| `context7` | Live, version-accurate library docs |
| `brave-search` | Real web search |
| `firecrawl` | Full page scraping, structured data extraction |
| `sequential-thinking` | Structured reasoning for multi-hypothesis decisions |

Verify all 5 are connected in Claude Code (`/mcp`).

### Serena setup (strongly recommended)

Claude Code's dynamic tool loading causes **agent drift** — the agent may forget to use Serena's tools after a few tool calls. Fix this by adding hooks to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "", "hooks": [{ "type": "command", "command": "serena-hooks remind --client=claude-code" }] },
      { "matcher": "mcp__serena__*", "hooks": [{ "type": "command", "command": "serena-hooks auto-approve --client=claude-code" }] }
    ],
    "SessionStart": [
      { "matcher": "", "hooks": [{ "type": "command", "command": "serena-hooks activate --client=claude-code" }] }
    ],
    "Stop": [
      { "matcher": "", "hooks": [{ "type": "command", "command": "serena-hooks cleanup --client=claude-code" }] }
    ]
  }
}
```

Or run `install.sh` — hooks are installed automatically.
