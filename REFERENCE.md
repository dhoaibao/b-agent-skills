# b-agent-skills — Skill reference

Detailed reference for all skills in the b-agent-skills suite.
For quick overview and installation, see [README.md](README.md).

## Skill reference

### b-plan

Decomposes any non-trivial task into ordered steps, dependencies, and risks before
any implementation begins. Uses `sequential-thinking` to reason through the happy path,
identify blockers, and surface unknowns. For tasks that modify existing code, scans
the codebase first with `jcodemunch` (`suggest_queries` → `get_repo_outline` →
`get_file_outline` batch, `get_file_tree` for scoped dirs) so the plan references real
file paths and respects existing patterns.

**Good triggers:**
```
b-plan: add rate limiting to the API
plan: design the notification system
how should I approach refactoring the auth module?
where do I start with the payment gateway integration?
```

**Output:** Plan file written to `.claude/b-plans/[task-slug].md` in the current
project root — with ordered steps (checkbox format), dependency map, risk flags, and
unknowns marked as `b-docs` or `b-research` calls. b-analyze and b-docs findings are
appended to the same file for use in the execution session.

**Rule:** Never implement in the same session as planning for tasks with 5+ steps.
End session 1 with the plan file, open a new session to execute.

**Execution index refresh:** During plan execution, calls `index_file` on each modified file after each step to keep jcodemunch index fresh for the self-review step.

**English-only plan files:** Plan files are always written in English — regardless of the user's query language. This ensures plan files remain consistent and usable across language-switching sessions.

---

### b-docs

Fetches live, version-accurate documentation from Context7 before implementing anything
that involves a library, SDK, or third-party tool. Prevents hallucinated APIs and
version mismatches from stale training data.

**Good triggers:**
```
b-docs: sendgrid send email with attachments
how do I configure retries in bullmq?
what's the API for aws ses v3?
does zod support async validation?
tra cứu cách dùng thư viện Prisma
hướng dẫn sử dụng Zod
```

**Output:** Accurate method signatures, required parameters, auth setup, error codes,
and deprecation notices for the current version. Routes to implementation or lookup-only
depending on how it was called.

**Fallback chain:** context7 → firecrawl direct scrape (if library has a known official docs URL) → b-research (full research pipeline). The firecrawl fallback tries a single `firecrawl_scrape` on the official docs URL before escalating to the heavier b-research pipeline.

---

### b-research

Deep research workflow: classify query type → search with type-specific tool → scrape
full pages with Firecrawl → synthesize into a structured report with citations. Never
relies on search snippets or training data alone.

**Query type routing:**
- `NEWS` queries → `brave_news_search` with `freshness: "pd"/"pw"` (not `brave_web_search`)
- All other queries → `brave_web_search`
- `HOWTO/API` queries → Context7 first, then Brave

**Good triggers:**
```
b-research: compare bullmq vs bee-queue for job queues
research: best practices for webhook signature verification
compare Prisma vs Drizzle for a TypeScript project
deep dive into Redis Streams
```

**Output:** Summary, key findings, optional comparison table, and cited sources.
Context7 is used automatically when the topic is a library or framework.

**Limits:** Max 5 URLs scraped per session (7 for COMPARE), fetched in parallel. JS-heavy pages: retry with `waitFor: 5000/8000`, then `firecrawl_map` to find correct URL before skipping. If Brave returns fewer than 3 relevant results, falls back to `firecrawl_search`. For deep multi-page documentation: use `firecrawl_crawl` + poll `firecrawl_check_crawl_status` (async — do not proceed until `status: "completed"`).

---

### b-analyze

Deep code analysis using jcodemunch — maps structure, measures complexity, identifies
duplicate logic, dead code, and OOP issues; produces severity-ranked findings with
concrete suggestions. Resolves or indexes the codebase first via `resolve_repo` →
`index_folder` (if needed), then runs `suggest_queries` → `get_repo_outline` →
`get_file_outline` (batch) → `get_dependency_graph` → `search_symbols`. For symbol
inspection: `get_symbol_source` (single or batch via `symbol_ids[]`). For dead code:
`check_references` + `find_importers`. For OOP: `get_class_hierarchy`. For pattern
similarity: `get_related_symbols`. For magic numbers/hardcoded strings: `search_text`.
For dbt/SQL projects: `search_columns`. For High findings matching a named anti-pattern,
calls `brave_web_search`. Uses `sequentialthinking` to produce a sprint-prioritized
action list. Does not fix anything; produces findings only.

**Good triggers:**
```
b-analyze: review the service layer before refactoring
analyze this file for code smells
review the error handling consistency across handlers
```

**Output:** Structure overview (call graph, module map), findings ranked 🔴 High /
🟡 Medium / 🟢 Low, metrics snapshot (complexity, duplication, circular deps),
and recommended next steps.

**Distinction from b-debug:** Use b-analyze when code works but could be better.
Use b-debug when something is broken.

**b-debug handoff:** If analysis reveals a bug (broken logic, not just poor style) → state: 'Root cause analysis needed. Run: `b-debug: [symptom] in [entry point]` to trace the execution path.'

---

### b-debug

Systematic, hypothesis-driven bug tracing. Resolves or indexes the codebase first via
`resolve_repo` → `index_folder` (if needed), then optionally calls `suggest_queries`
(unfamiliar codebases), then maps the full execution path with jcodemunch
(`get_context_bundle` → `find_references` → `get_blast_radius` → `get_symbol_source`).
For suspicious functions, uses `get_related_symbols`
to find similar patterns elsewhere. For regression detection: `get_symbol_diff`. For
error string origin: `search_text`. Forms ranked hypotheses with sequential-thinking,
confirms root cause, then fixes. For library errors: `brave_web_search` → `firecrawl_scrape`
(with `firecrawl_map` fallback when scrape returns empty) → `b-docs`. Never patches
before root cause is confirmed.

**Good triggers:**
```
b-debug: webhook not triggering despite correct URL registration
b-debug: intermittent 500 on /api/send with no error in logs
why is this callback not running?
fix: email queue jobs disappearing silently
```

**Output:** Symptoms summary, execution path map, ranked hypotheses, confirmed root cause,
minimal fix, and verification instructions.

**Rule:** No patch is written until root cause is explicitly confirmed. Library errors
trigger a web lookup and `b-docs` call before hypothesis verification.

**Post-fix index refresh:** After applying a fix, calls `index_file` on each changed file to keep jcodemunch index fresh for subsequent b-analyze calls.

**Post-fix review:** If the fix introduced new code (new function, new module) → optionally run `b-analyze: [fixed module]` to verify no new complexity or duplication was introduced.

---

### b-sync

Syncs Claude skills from the `b-agent-skills` GitHub repo to `~/.claude/skills/` using git + `sync.sh`. No MCP required — only the Bash tool.

**Good triggers:**
```
sync b-skills
update b-skills
install b-skills on new machine
đồng bộ skills
cập nhật skills
cài skills mới
```

**Modes:** BOOTSTRAP (first install: `git clone` + `sync.sh`) vs UPDATE (existing: `git pull` via `sync.sh`). Auto-detected by checking for `~/.b-agent-skills/.git`.

**Output:** Before/after skill list diff — lists added and removed skills, total count. Validates symlinks and frontmatter after sync.

**Distinction from other skills:** b-sync only manages skill installation — it does not invoke any other skill.

---

## Usage patterns

### Pattern 1 — New feature
For any non-trivial feature, use the manual pipeline:
```
1. b-plan: [task]          → confirm plan
2. b-analyze: [module]     → understand existing code (skip if greenfield)
3. b-docs: [library]       → fetch accurate API (skip if no libraries)
4. [implement]             → execute plan steps
5. b-analyze: [new code]   → self-review before shipping
```
b-plan now handles this automatically during execution — see its execution section.

### Pattern 2 — Debug session
When something is broken:
```
b-debug: [symptom + what was expected]
```
Paste the full error message or stack trace if available.

### Pattern 3 — Before touching unfamiliar code
Before modifying a module you haven't worked with recently:
```
b-analyze: [module or layer name]
```
Then hand off to b-plan to sequence the changes safely.

### Pattern 4 — Choosing a library
Before committing to a new dependency:
```
b-research: compare [option A] vs [option B] for [use case]
```

### Pattern 5 — Integrating a known library
When the library is chosen but the API needs verification:
```
b-docs: [library name] — [specific feature]
```
Always run this before writing integration code, even for familiar libraries.

### Pattern 6 — Manual pipeline
For full control over each step:
```
1. b-plan: [task]          → confirm plan
2. b-analyze: [module]     → understand existing code
3. b-docs: [library]       → fetch accurate API
4. [implement]             → execute plan steps
5. b-analyze: [new code]   → self-review before shipping
```
You control the pace at each step. b-plan's execution section automates steps 2 and 5.

---

## Trigger tips

Claude Code may skip skills on tasks that appear simple. To guarantee activation:

- **Prefix with the skill name**: `b-debug: ...`, `b-plan: ...`, `b-research: ...`
- **Use explicit keywords**: "plan", "analyze", "research", "debug" trigger reliably
- **Describe complexity**: mentioning "multiple files", "new integration", "not sure why" increases trigger rate

When in doubt, call the skill by name.

---

## Skill interaction map

```
b-plan ──── modify existing code ────────► jcodemunch (resolve_repo → scan structure first)
       ──── flags unknowns ──────────────► b-docs     (library API needed, resolved inline)
                                         ► b-research  (decision needed)
       ──── execution: file modified ────► jcodemunch (index_file to keep index fresh)

b-docs ──── context7 has no index ──────► firecrawl   (direct scrape of official docs URL, single page)
       ──── firecrawl insufficient ────► b-research  (full multi-source research)

b-debug ─── trace execution path ────────► jcodemunch (resolve_repo → suggest_queries → get_context_bundle → find_references → get_blast_radius → get_symbol_source → get_related_symbols)
        ─── regression detection ────────► jcodemunch (get_symbol_diff)
        ─── error string lookup ─────────► jcodemunch (search_text)
        ─── post-fix index refresh ──────► jcodemunch (index_file on changed files)
        ─── library error detected ──────► brave-search (lookup known issues)
                                         ► firecrawl_scrape (top 1–2 pages, optional)
                                         ► firecrawl_map (if scrape empty, optional)
                                         ► b-docs      (verify API behavior)

b-analyze ── index or resolve ────────────► jcodemunch (resolve_repo → index_folder if needed)
          ── unfamiliar codebase ─────────► jcodemunch (suggest_queries first)
          ── symbol inspection ───────────► jcodemunch (get_symbol_source, single or batch)
          ── dead code ─────────────────── ► jcodemunch (check_references + find_importers)
          ── dbt/SQL columns ─────────────► jcodemunch (search_columns)
          ── OOP hierarchy ──────────────► jcodemunch (get_class_hierarchy)
          ── pattern similarity ──────────► jcodemunch (get_related_symbols)
          ── magic numbers/strings ───────► jcodemunch (search_text)
          ── findings need refactor ──────► b-plan    (sequence it safely)
          ── named anti-pattern found ────► brave-search (refactoring solution lookup, optional)
          ── prioritize sprint items ─────► sequential-thinking (ordered ROI action list, optional)

b-research ── news query ─────────────────► brave_news_search (freshness: pd/pw)
           ── scrape returns empty ────────► firecrawl_map (discover correct URL, then retry)
           ── deep multi-page docs ────────► firecrawl_crawl + check_crawl_status (async)
           ── sources conflict ───────────► sequential-thinking (structured conflict resolution, optional)

b-quick-search ── news/current-events ────► brave_news_search (freshness: pd/pw)
               ── general lookup ─────────► brave_web_search

```

---

---

## Personal / daily skill reference

### b-quick-search

Single-call web lookup via Brave Search. Returns a fast, cited answer from the live
web — no scraping, no deep synthesis. Routes to `brave_news_search` for news/current-events
queries, `brave_web_search` for everything else.

**Good triggers:**
```
b-quick-search: latest version of Node.js
what's the current price of M4 MacBook Pro?
latest release of Fedora?
recent CVE for OpenSSL?
latest news about OpenAI?
```

**Output:** Direct answer with source citations. Multi-point queries get a short "Key findings" list.

**Query routing:** News/current-events → `brave_news_search` (`freshness: "pd"/"pw"`). Versions, prices, docs, CVEs → `brave_web_search`.

**Distinction from b-research:** If one search can answer it → b-quick-search.
If you need to read multiple full pages → b-research.

**Fallback:** If results are insufficient, says so and suggests b-research.

---

### b-news

Aggregates today's top news on any user-specified topic from a domain-matched trusted
source map. Parses user input to extract topics, maps them to authoritative sources
(e.g., finance → reuters/bloomberg/ft, security → bleepingcomputer/krebsonsecurity,
science → nature/sciencedaily), generates 3–5 focused queries, runs them in parallel
via `brave_news_search` with `freshness: "pd"`, then groups results into dynamic
categories derived from the actual topics found. Falls back to `freshness: "pw"` if
fewer than 10 stories are returned. Outputs a bilingual digest (English + Vietnamese)
when the query is in Vietnamese.

**Good triggers:**
```
b-news
b-news AI crypto
b-news tài chính thị trường
b-news khoa học vũ trụ
b-news chính trị thế giới
tin tức hôm nay
có gì mới hôm nay?
điểm tin
```

**No topic specified:** Defaults to tech news (backward compatible with all existing triggers).

**Output:** Grouped digest with dynamically derived categories (emoji + label per sub-topic).
Each story has an English headline + summary + source link, with Vietnamese translation
when the query is in Vietnamese. Header reflects the actual topic(s), not a generic "Tech News" label.
Max 3 stories per category. Footer lists the actual source domains used.

**Source map:** 12 domain tiers — Universal (reuters, apnews, bbc), Tech, AI/ML,
Security, Mobile, Linux, Finance, Crypto, Science, Health, Politics, Startups.
Queries are matched to the relevant tiers; Universal sources are always included as fallback.

**On-demand detail:** Follow up with "đọc thêm về [story]" / "tell me more about [story]"
to scrape the full article via `firecrawl_scrape`. Not called during initial digest generation.

**Distinction from b-research:** b-news gives a fast, grouped digest of today's headlines.
Use b-research when you need deep synthesis, comparison, or a multi-source report on a topic.

---