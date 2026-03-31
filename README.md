# b-agent-skills

A personal skill suite for Claude Code, organized into two groups:

- **Development skills** — a tightly integrated pipeline for software development work, leveraging all 5 MCPs
- **Personal / daily skills** — standalone utilities for everyday personal use

The development skills form a linear pipeline: **b-plan → b-tdd → b-gate → b-review → b-commit**, with b-analyze, b-debug, b-docs, and b-research as supporting tools. The `b-execute-plan` skill orchestrates this pipeline with explicit checkpoints and state tracking.

All development skills enforce a **git-safety guardrail**: destructive git commands (`git push`, `git commit`, `git reset`, `git revert`, `git clean -f`, `git checkout -- <file>`, `git branch -D`) are prohibited except in `b-commit`, which owns all git write operations. b-execute-plan may offer rollback to the user but never auto-executes it.

Formatting note: bullet style is standardized across all `SKILL.md` files for consistent readability and maintenance.

---

## MCP dependencies

| MCP | Role |
|---|---|
| `context7` | Fetch live, version-accurate docs for any library or SDK |
| `brave-search` | Real web search beyond training data cutoff |
| `firecrawl` | Scrape full page content, not just search snippets |
| `jcodemunch` | Analyze code structure, call graphs, and complexity |
| `sequential-thinking` | Structured reasoning and task decomposition |

All 5 MCPs must be connected. Verify with `/mcp` in Claude Code.

---

## Skills overview

### Development skills

| Skill | MCP(s) | Use when |
|---|---|---|
| [`b-plan`](#b-plan) | sequential-thinking, jcodemunch* | Before non-trivial coding; conditional feasibility gate (Step 0); Step 1 skips duplicate questions when Step 0 ran |
| [`b-execute-plan`](#b-execute-plan) | — (Bash + Skill only) | Orchestrating the full pipeline with auto-advance on success; pauses only on failure, ambiguous routing, manual steps, or NEEDS FIXES |
| [`b-tdd`](#b-tdd) | — (Bash only) | During implementation — Iron Law + Red-Green-Refactor; 7-language stack detection (Node/Python/Go/Rust/Java/Ruby/PHP) |
| [`b-gate`](#b-gate) | — (Bash only) | After implementation — lint → typecheck → tests → security → clean-code → integration/e2e (soft block) |
| [`b-review`](#b-review) | sequential-thinking, jcodemunch* | After b-gate — logic, requirements, edge cases, test adequacy; small-change fast path (≤50 lines, ≤2 files) |
| [`b-commit`](#b-commit) | — (Bash only) | After b-review — generate commit message and PR description text (no git execution) |
| [`b-docs`](#b-docs) | context7, firecrawl* | Before using any library or SDK |
| [`b-research`](#b-research) | brave-search (web+news), firecrawl, context7*, sequential-thinking*, Agent* | Deep research, tool comparison, synthesis — optimized for token efficiency (3 URLs smart selection, strict post-scrape gate) |
| [`b-analyze`](#b-analyze) | jcodemunch (12 tools), sequential-thinking*, brave-search* | Understand or review code before changing it; `quick` mode (structure map only) or full deep analysis |
| [`b-debug`](#b-debug) | jcodemunch (9 tools), sequential-thinking, brave-search*, firecrawl* | Trace bugs that have no obvious cause |
| [`b-observe`](#b-observe) | jcodemunch (6 tools), sequential-thinking* | Static observability audit — missing logs, swallowed errors, metrics gaps, tracing coverage |

*optional — used conditionally

### Personal / daily skills

| Skill | MCP(s) | Use when |
|---|---|---|
| [`b-quick-search`](#b-quick-search) | brave-search (web+news) | Quick one-call web lookup for current info |
| [`b-news`](#b-news) | brave-search, firecrawl* | Daily news digest on any user-specified topic |
| [`b-sync`](#b-sync) | — | Sync skills from GitHub repo to any machine |

---

## Skill reference

See [REFERENCE.md](REFERENCE.md) for detailed reference on each skill — triggers,
output format, rules, and distinctions between similar skills.

---

## Installation

Copy each skill folder into your Claude Code skills directory:

```bash
# Option A — manual copy
cp -r b-plan b-tdd b-gate b-review b-commit b-docs b-research b-analyze b-debug b-observe b-quick-search b-news b-sync ~/.claude/skills/

# Option B — use b-sync (recommended, keeps skills up to date automatically)
git clone https://github.com/dhoaibao/b-agent-skills.git ~/.b-agent-skills && bash ~/.b-agent-skills/sync.sh
```

Verify all MCPs are connected:
```
/mcp
```

All 5 must show `✓ Connected`:
`context7`, `brave-search`, `firecrawl`, `jcodemunch`, `sequential-thinking`

---