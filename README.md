# b-agent-skills

A personal skill suite for Claude Code, organized into two groups:

- **Development skills** — a tightly integrated pipeline for software development work, leveraging all 5 MCPs
- **Personal / daily skills** — standalone utilities for everyday personal use

The development skills form a linear pipeline: **b-plan → b-tdd → b-gate → b-review → b-commit**, with b-analyze, b-debug, b-docs, and b-research as supporting tools.

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
| [`b-plan`](#b-plan) | sequential-thinking, jcodemunch* | Before non-trivial coding; includes conditional feasibility gate and plan-file handoff |
| [`b-tdd`](#b-tdd) | — (Bash only) | During implementation — enforce Iron Law and Red-Green-Refactor per step |
| [`b-gate`](#b-gate) | — (Bash only) | After implementation — lint → typecheck → tests → security → clean-code |
| [`b-review`](#b-review) | sequential-thinking, jcodemunch* | After b-gate — logic, requirements, edge cases, test adequacy |
| [`b-commit`](#b-commit) | — (Bash only) | After b-review — generate commit message and PR description text (no git execution) |
| [`b-docs`](#b-docs) | context7, firecrawl* | Before using any library or SDK |
| [`b-research`](#b-research) | brave-search (web+news), firecrawl, context7*, sequential-thinking*, Agent* | Deep research, tool comparison, synthesis |
| [`b-analyze`](#b-analyze) | jcodemunch (12 tools), sequential-thinking*, brave-search* | Understand or review code before changing it (pre-implementation only) |
| [`b-debug`](#b-debug) | jcodemunch (9 tools), sequential-thinking, brave-search*, firecrawl* | Trace bugs that have no obvious cause |

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
cp -r b-plan b-tdd b-gate b-review b-commit b-docs b-research b-analyze b-debug b-quick-search b-news b-sync ~/.claude/skills/

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

## Codex compatibility

A fully Codex-compatible version of all 12 skills is available in the [`codex/`](codex/) folder.

The Codex edition adapts each skill for OpenAI Codex: skills install to `~/.agents/skills/`, use `policy.allow_implicit_invocation: true` for auto-triggering, declare MCP dependencies in frontmatter, and replace Claude Code-specific references (`CLAUDE.md` → `AGENTS.md`, `.claude/b-plans/` → `.agents/plans/`, `/mcp` → `codex mcp list`).

**Quick install:**
```bash
git clone https://github.com/dhoaibao/b-agent-skills.git ~/.b-agent-skills
bash ~/.b-agent-skills/codex/codex-sync.sh
```

See [`codex/README.md`](codex/README.md) for full setup instructions, MCP configuration, and known limitations.