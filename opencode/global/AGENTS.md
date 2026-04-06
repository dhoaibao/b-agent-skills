# b-agents — OpenCode Rules

This file defines global OpenCode runtime rules. For repo-level agent authoring conventions, see the root `AGENTS.md`.

## OpenCode workflow

All planning and execution happen within OpenCode:
- **Planning**: clarify requirements → `@b-plan` → writes `.opencode/b-plans/*.md`
- **Execution**: reads plan file → runs `@b-execute-plan` pipeline

Plan files live in `.opencode/b-plans/*.md`.

## Invoking the execution pipeline

When asked to execute a plan, use the `b-execute-plan` primary agent:

```
execute plan from .opencode/b-plans/<filename>.md
```

Or simply: `execute plan` — `b-execute-plan` will discover the plan file automatically.

For plans that modify existing code, Step 0 (pre-execution `@b-analyze`) is **conditional, not always-on**. Require it only when scope is ambiguous, the code area is unfamiliar or spans multiple files/layers, the change touches shared/public/high-blast-radius modules, or the existing `## Context` is missing/stale. Small, local, well-scoped changes may skip Step 0.

## Subagents

All agents are available as subagents:

### Orchestration
| Agent | Role |
|---|---|
| `@b-execute-plan` | Full pipeline orchestrator — reads plan file, routes to subagents, tracks state |

### Execution pipeline
| Agent | Role |
|---|---|
| `@b-tdd` | TDD enforcement — Iron Law + Red-Green-Refactor per step |
| `@b-gate` | Quality gate — lint → typecheck → tests → coverage → security → clean-code |
| `@b-review` | Pre-PR review — logic, requirements, edge cases, test adequacy |
| `@b-commit` | Generate commit message and PR description text |
| `@b-debug` | Hypothesis-driven debugging — trace, confirm root cause, fix, and verify by default |
| `@b-analyze` | Deep code analysis — structure, complexity, duplication |

### Planning & research
| Agent | Role |
|---|---|
| `@b-plan` | Decompose tasks into ordered steps before coding |
| `@b-docs` | Fetch live library documentation via Context7 |
| `@b-research` | Deep research — search + scrape + synthesize report |
| `@b-observe` | Static observability audit — missing logs, swallowed errors |

Invoke directly for one-off tasks:
```
@b-gate
@b-debug cannot read property of undefined at line 42
@b-analyze src/services/
@b-plan add retry logic to the email queue
@b-docs how to use Prisma transactions
```

## Plan file state sections

`@b-execute-plan` writes to these sections to bridge state between subagent calls:

| Section | Written by | Read by |
|---|---|---|
| `## Context` | `@b-execute-plan` (after `@b-analyze`) | `@b-tdd` before each implementation step |
| `## Last Gate Failure` | `@b-execute-plan` (when `@b-gate` fails) | `@b-debug` when auto-debug is triggered |
| `## Review Feedback` | `@b-execute-plan` (when `@b-review` returns NEEDS FIXES) | `@b-tdd` on re-entry |

## Post-execution suggestions

When `@b-execute-plan` finishes all plan steps, its suggested next actions must use explicit subagent names whenever a suite agent exists for that action.

- Use: `run @b-review to review the diff before commit`
- Use: `run @b-commit to draft the commit message and PR description`
- Do not use generic phrasing like `review the diff before commit` or `draft a commit message / PR description` without naming the mapped subagent.
- Generic suggestions are allowed only for actions with no corresponding subagent (for example: summarizing exact files changed).

## Mandatory MCP toolset usage

> **Iron rule**: when an MCP is connected and available, its toolset **MUST** be used. Using native tools (Glob/Grep/Read/Bash/webfetch) when the equivalent MCP is available is a violation — not a preference. Native tools are **last-resort fallbacks only**, used exclusively when the MCP is confirmed unavailable.

**How to check MCP availability**: at session start, treat each MCP as available unless a call to it returns a connection error or "MCP not connected" signal. Do not pre-emptively skip MCPs based on assumptions.

---

### Code intelligence — jcodemunch (REQUIRED when available)

When jcodemunch is connected: **never** use Glob, Grep, or Read to explore or understand a codebase. Every code intelligence task routes through jcodemunch first.

**Mandatory substitution table — no exceptions when jcodemunch is available:**

| Native tool / action | ✅ MUST use instead (jcodemunch) |
|---|---|
| `Glob("**/*.ts")` to find files | `get_file_tree(repo, path_prefix=...)` |
| `Read("src/foo.ts")` to read a file | `get_file_content(repo, "src/foo.ts")` |
| `Grep("functionName")` to find a symbol | `search_symbols(repo, "functionName")` |
| `Grep("import.*foo")` to trace imports | `get_dependency_graph(repo, file, direction="imports")` |
| `Grep("foo(")` to find usages | `find_references(repo, "foo")` |
| Manual dead-code tracing | `get_dead_code_v2(repo)` |
| Reading file structure by hand | `get_repo_outline(repo)` |
| Checking if a symbol is used | `check_references(repo, "symbolName")` |
| Understanding a class hierarchy | `get_class_hierarchy(repo, "ClassName")` |
| Finding related code | `get_related_symbols(repo, symbol_id)` |

**jcodemunch preflight** — run at the start of any agent that needs to understand existing code:

1. `resolve_repo(path="<absolute project root>")` — look up the cached repo map.
   - If a repo identifier is returned: reuse it. Verify index health with `get_repo_outline(repo=<id>)`.
   - If the outline shows implausibly low coverage for the task (for example: `file_count = 0`, `symbol_count = 0`, only one language/file for a clearly larger repo, or the target directory/files are missing from the tree) → re-index with `index_folder(path=<root>, use_ai_summaries=false)`.
   - If no match: call `index_folder(path=<root>, use_ai_summaries=false)`. Note the `repo` identifier from the response.
   - If re-index still returns `file_count = 0` or `symbol_count = 0`: jcodemunch cannot parse this codebase → fall back to Glob/Grep/Read.
2. `suggest_queries(repo=<id>)` — surface entry points, key symbols, and language distribution.
3. `get_ranked_context(repo=<id>, query="<agent-specific task query>", token_budget=4000)` — pack the most relevant symbols/files into a bounded context window.

**Session reuse**: if another agent already ran this preflight in the same session, reuse the repo identifier — do not re-index.

**Fallback** *(only when jcodemunch is unavailable or returns `file_count=0`)*: use `Glob` to map file structure, `Grep` for pattern search, `Read` for file inspection. Always note: "⚠️ jcodemunch unavailable — analysis based on Glob/Grep/Read; cross-file tracking incomplete."

**Compliance note**: when an agent falls back from jcodemunch, it must state both (a) why fallback was necessary, and (b) which MCP capability is now missing (for example: blast radius, call graph, dead code detection, symbol diff, or ranked context).

---

### Web search — Brave Search + Firecrawl (REQUIRED when available)

When brave-search or firecrawl is connected: **never** use `webfetch` directly. Never guess URLs and fetch them manually.

**Mandatory substitution table — no exceptions when MCPs are available:**

| Native tool / action | ✅ MUST use instead |
|---|---|
| `webfetch(url)` to search for info | `brave_web_search(query)` → then `firecrawl_scrape(url)` |
| `webfetch(url)` to read a known page | `firecrawl_scrape(url, formats=["markdown"])` |
| Manually guessing and fetching URLs | `firecrawl_map(url, search=...)` to discover the right URL first |
| Repeated `webfetch` for multi-page coverage | `firecrawl_crawl(url, limit=N)` |
| Extracting structured fields from a page | `firecrawl_extract(urls, schema=...)` |
| Open-ended multi-site research | `firecrawl_agent(prompt=...)` |
| News / current events lookup | `brave_news_search(query, freshness=...)` |

**Search-first rule**: always call `brave_web_search` first to identify the best URLs, then `firecrawl_scrape` on the top 1–3 results. Never scrape blindly without a search step unless the URL is already known and authoritative.

**Fallback chain** *(only when MCPs are unavailable)*:
- brave-search unavailable → use `firecrawl_search` (combined search+scrape).
- firecrawl unavailable → use `webfetch` as last resort.
- Both unavailable → use `webfetch`. Note: "⚠️ brave-search and firecrawl unavailable — using webfetch; content quality may be reduced."

---

### Library documentation — Context7 (REQUIRED when available)

When context7 is connected: **never** rely on training knowledge for library APIs, method signatures, or framework behavior. Never guess or assume an API is unchanged from what was seen in training data.

**Mandatory substitution table — no exceptions when context7 is available:**

| Native action | ✅ MUST use instead (context7) |
|---|---|
| Recalling a library method from memory | `resolve-library-id` → `query-docs(topic="method name")` |
| Assuming an API signature is correct | `query-docs` to verify before writing code |
| Guessing config options | `query-docs(topic="configuration options")` |
| Assuming framework behavior from training | `query-docs` with specific feature query |
| Writing integration code without checking | `resolve-library-id` → `query-docs` first, always |

**Call order**: always `resolve-library-id` first (get exact library ID), then `query-docs` with a focused topic. One call per distinct API area.

**Fallback** *(only when context7 is unavailable)*:
1. Try `firecrawl_scrape` on the official docs URL for the library.
2. If scrape fails: invoke `b-docs` or `b-research` to retrieve docs.
3. Never fall back to training-data assumptions. Note: "⚠️ Context7 unavailable — docs fetched via firecrawl_scrape."

---

### Reasoning — Sequential Thinking (REQUIRED when available for complex problems)

When sequential-thinking is connected: **never** reason through a complex multi-step problem with free-form prose alone. Use `sequentialthinking` whenever the problem is non-trivial.

**Mandatory trigger conditions — MUST call `sequentialthinking` when:**

| Situation | Why sequentialthinking is required |
|---|---|
| Debugging with >2 hypotheses | Tracks ranked hypotheses, eliminates ruled-out paths explicitly |
| Architecture or data-flow design | Surfaces trade-offs and dependency ordering that prose misses |
| Decomposing a vague requirement into steps | Produces atomic, ordered, dependency-aware steps |
| Trade-off analysis between approaches | Forces structured comparison, prevents anchoring bias |
| Complex test case design (edge cases) | Generates a complete case set before writing the first test |
| Prioritizing a list of findings by impact | Produces an evidence-based ordering, not intuition |

**Mandatory substitution table:**

| Native action | ✅ MUST use instead |
|---|---|
| Bullet-list of hypotheses in prose | `sequentialthinking` with ranked hypotheses + verification steps |
| "Here's my plan:" paragraph | `sequentialthinking` for decomposition before writing plan |
| "I think the issue is..." reasoning | `sequentialthinking` to form and test hypotheses explicitly |
| Inline trade-off comparison | `sequentialthinking` with structured criteria |

**Fallback** *(only when sequential-thinking is unavailable)*: structure reasoning as an explicit numbered list with `Hypothesis N → Evidence → Confirmed/Rejected` format. Never skip structured reasoning — just do it in plain text if the MCP is down.

**Compliance note**: for any task that matches the trigger table above, the agent's output must show the structured reasoning result explicitly (ranked hypotheses, ordered plan, trade-off table, or prioritized findings). Do not hide the reasoning step behind a generic summary.

---

### MCP priority order (global rule — enforced, not advisory)

When multiple tools can perform the same task, this order is **mandatory**:

```
MCP toolset  >  specialized native tool  >  general native tool  >  Bash command
```

Concrete enforcement examples:

| Task | 1st choice (MUST) | 2nd choice (if 1st unavailable) | Last resort |
|---|---|---|---|
| Read a source file | `jcodemunch:get_file_content` | `Read` tool | `cat` via Bash |
| Find a function | `jcodemunch:search_symbols` | `Grep` tool | `grep` via Bash |
| Search the web | `brave_web_search` | `firecrawl_search` | `webfetch` |
| Scrape a URL | `firecrawl_scrape` | `webfetch` | — |
| Library API lookup | `context7:query-docs` | `firecrawl_scrape(docs URL)` | training knowledge (❌ avoid) |
| Complex reasoning | `sequentialthinking` | numbered prose with explicit steps | inline prose (❌ avoid) |

**Violation detection**: if you find yourself reaching for Glob, Grep, Read, or webfetch, stop and ask: "Is the equivalent MCP connected?" If yes — use the MCP. Only proceed with the native tool after confirming the MCP is unavailable.

---

## Git safety

Never run these commands autonomously:
- `git push`, `git pull`, `git commit`, `git reset --hard`
- `git revert`, `git clean -f`, `git branch -D`

Rollback (`git checkout -- .`) must be **offered to the user**, never auto-executed.

All commits are delegated to `@b-commit` — it generates message text only, never executes git.
