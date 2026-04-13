# b-agents — OpenCode Rules

This file defines global OpenCode runtime rules. For repo-level agent authoring conventions, see the root `AGENTS.md`.

## OpenCode workflow

Four agents covering the full development cycle:

| Agent | Role |
|---|---|
| `@b-plan` | Think before coding — decompose tasks, evaluate approaches, produce plan file |
| `@b-research` | All external knowledge — library docs, comparisons, multi-source research |
| `@b-debug` | Full-loop debugging — trace, confirm root cause, fix, verify |
| `@b-review` | Pre-PR review — logic correctness, requirements, edge cases, test adequacy |

**Typical flow:**
```
b-plan → [implement manually] → b-review → commit
b-research (any time you need docs or comparisons)
b-debug (any time something breaks)
```

## Invoking agents

All agents are configured with `mode: subagent` — invoke them via **@ mention**:

```
@b-plan add rate limiting to the API
@b-research how to use Prisma transactions
@b-research compare BullMQ vs Bee-Queue
@b-debug webhook not triggering despite correct URL
@b-review
```

## Mandatory MCP toolset usage

> **Iron rule**: when an MCP is connected and available, its toolset **MUST** be used. Using native tools (Glob/Grep/Read/Bash/webfetch) when the equivalent MCP is available is a violation — not a preference. Native tools are **last-resort fallbacks only**.

**How to check MCP availability**: treat each MCP as available unless a call returns a connection error. Do not pre-emptively skip MCPs based on assumptions.

---

### Code intelligence — jcodemunch (REQUIRED when available)

When jcodemunch is connected: **never** use Glob, Grep, or Read to explore or understand a codebase.

**Working style rule**: use jcodemunch to narrow first, then read narrowly.
- Start with repo/file/symbol discovery tools.
- Prefer `get_file_outline` before `get_symbol_source`.
- Prefer `get_symbol_source` before `get_file_content`.
- Use `get_file_content` only when symbol boundaries are insufficient (file-level state, long procedural flow, config/text files, or exact line-range review).
- Before risky edits, run impact tools (`find_references`, `get_blast_radius`, `get_impact_preview`, `plan_refactoring`) before reading more code.

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
   - **Check `is_stale` flag**: if `is_stale: true` → re-index with `index_folder(path=<root>, incremental=true, use_ai_summaries=false)`.
   - After re-indexing due to staleness, call `get_repo_outline(repo=<id>)` again before proceeding.
   - If outline shows implausibly low coverage (`file_count = 0`, `symbol_count = 0`) → re-index.
   - If no match: call `index_folder(path=<root>, incremental=true, use_ai_summaries=false)`.
   - If re-index still returns `file_count = 0` → fall back to Glob/Grep/Read.
2. `suggest_queries(repo=<id>)` — surface entry points, key symbols, and language distribution.
3. `get_ranked_context(repo=<id>, query="<agent-specific task query>", token_budget=4000)` — pack the most relevant symbols/files into a bounded context window.

**Read-order heuristic**:
1. `search_symbols` / `search_text`
2. `get_file_outline`
3. `get_symbol_source` or `get_context_bundle`
4. `get_file_content` only if still necessary

**Token-efficiency rule**:
- Do not open full files by default.
- Batch symbol reads when possible (`get_symbol_source(symbol_ids[])`, `get_context_bundle`).
- Use `search_text` for strings/config/errors; use `search_symbols` for code entities.

**Session reuse**: if another agent already ran this preflight in this session, reuse the repo identifier — do not re-index.

**Always use `incremental=true`**: ensures file deletion detection and reduces re-index time.

**Fallback** *(only when jcodemunch is unavailable or returns `file_count = 0`)*: use `Glob` + `Grep` + `Read`. Always note: "⚠️ jcodemunch unavailable — analysis based on Glob/Grep/Read; cross-file tracking incomplete."

---

### Web search — Brave Search + Firecrawl (REQUIRED when available)

When brave-search or firecrawl is connected: **never** use `webfetch` directly.

**Mandatory substitution table:**

| Native tool / action | ✅ MUST use instead |
|---|---|
| `webfetch(url)` to search for info | `brave_web_search(query)` → then `firecrawl_scrape(url)` |
| `webfetch(url)` to read a known page | `firecrawl_scrape(url, formats=["markdown"])` |
| Manually guessing and fetching URLs | `firecrawl_map(url, search=...)` to discover the right URL first |
| Repeated `webfetch` for multi-page coverage | `firecrawl_crawl(url, limit=N)` |
| News / current events lookup | `brave_news_search(query, freshness=...)` |

**Search-first rule**: always call `brave_web_search` first, then `firecrawl_scrape` on the top 1–3 results.

**Fallback chain** *(only when MCPs are unavailable)*:
- brave-search unavailable → use `firecrawl_search` (combined search+scrape).
- firecrawl unavailable → use `webfetch` as last resort.

---

### Library documentation — Context7 (REQUIRED when available)

When context7 is connected: **never** rely on training knowledge for library APIs, method signatures, or framework behavior.

**Mandatory substitution table:**

| Native action | ✅ MUST use instead (context7) |
|---|---|
| Recalling a library method from memory | `resolve-library-id` → `query-docs(topic="method name")` |
| Assuming an API signature is correct | `query-docs` to verify before writing code |
| Guessing config options | `query-docs(topic="configuration options")` |
| Writing integration code without checking | `resolve-library-id` → `query-docs` first, always |

**Call order**: always `resolve-library-id` first (get exact library ID), then `query-docs` with a focused topic.

**Fallback** *(only when context7 is unavailable)*:
1. Try `firecrawl_scrape` on the official docs URL.
2. If scrape fails: invoke `b-research` to retrieve docs.
3. Never fall back to training-data assumptions.

---

### Reasoning — Sequential Thinking (REQUIRED when available for complex problems)

When sequential-thinking is connected: **never** reason through a complex multi-step problem with free-form prose alone.

**Mandatory trigger conditions — MUST call `sequentialthinking` when:**

| Situation | Why sequentialthinking is required |
|---|---|
| Debugging with >2 hypotheses | Tracks ranked hypotheses, eliminates ruled-out paths explicitly |
| Architecture or data-flow design | Surfaces trade-offs and dependency ordering that prose misses |
| Decomposing a vague requirement into steps | Produces atomic, ordered, dependency-aware steps |
| Trade-off analysis between approaches | Forces structured comparison, prevents anchoring bias |
| Prioritizing a list of findings by impact | Produces an evidence-based ordering, not intuition |

**Fallback** *(only when sequential-thinking is unavailable)*: structure reasoning as an explicit numbered list with `Hypothesis N → Evidence → Confirmed/Rejected` format.

---

### MCP priority order (global rule — enforced, not advisory)

```
MCP toolset  >  specialized native tool  >  general native tool  >  Bash command
```

| Task | 1st choice (MUST) | 2nd choice | Last resort |
|---|---|---|---|
| Read a source file | `jcodemunch:get_symbol_source` / `get_file_outline` | `jcodemunch:get_file_content` / `Read` tool | `cat` via Bash |
| Find a function | `jcodemunch:search_symbols` | `Grep` tool | `grep` via Bash |
| Search the web | `brave_web_search` | `firecrawl_search` | `webfetch` |
| Scrape a URL | `firecrawl_scrape` | `webfetch` | — |
| Library API lookup | `context7:query-docs` | `firecrawl_scrape(docs URL)` | training knowledge (❌ avoid) |
| Complex reasoning | `sequentialthinking` | numbered prose with explicit steps | inline prose (❌ avoid) |

---

## Git safety

Never run these commands autonomously:
- `git push`, `git pull`, `git commit`, `git reset --hard`
- `git revert`, `git clean -f`, `git branch -D`

Rollback (`git checkout -- .`) must be **offered to the user**, never auto-executed.
