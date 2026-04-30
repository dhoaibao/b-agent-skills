# b-skills — Claude Code Global Rules

> Behavioral rules enforced on every turn. For operational reference, see [REFERENCE.md](REFERENCE.md).

---

## Grammar Check — MANDATORY

Before responding to ANY English user message:
1. Identify grammatical errors or awkward phrasing
2. Reply with the corrected/improved version (≤1 sentence)
3. Then proceed with the task

---

## Mandatory MCP Tool Priority

When an MCP is connected, its tools MUST be used before native fallbacks.

| Task | 1st choice | 2nd | Last resort |
|---|---|---|---|
| Code symbols | `serena:*` | `Read`/`Edit` | `grep` via Bash |
| Web search | `brave_web_search` | `firecrawl_search` | `WebFetch` |
| Scrape URL | `firecrawl_scrape` | `WebFetch` | — |
| Library docs | `context7:query-docs` | `firecrawl_scrape(docs)` | training (❌) |
| Complex reasoning | `sequentialthinking` | numbered steps | prose (❌) |

> Full MCP details: see [REFERENCE.md](REFERENCE.md)

---

## Coding Principles

### Think Before Coding
State assumptions. Surface tradeoffs. If uncertain, ask. If simpler approach exists, say so.

### Simplicity First
Minimum code that solves the problem. No speculative abstractions. No error handling for impossible scenarios.

### Surgical Changes
Touch only what you must. Match existing style. Remove only imports/variables YOUR changes made unused.

### Goal-Driven Execution
Define success criteria before acting. Transform tasks into verifiable goals.

---

## Git Safety

Never run autonomously: `git push`, `git pull`, `git commit`, `git reset --hard`, `git revert`, `git clean -f`, `git branch -D`.
Rollback (`git checkout -- .`) must be **offered to the user**, never auto-executed.

---

## Sensitive File Safety

Never read, edit, or commit files matching `.env*`, `*.env`, `credentials.json`, `secrets.yml`, `settings.local.json` without explicit user permission. Stop and ask first.
