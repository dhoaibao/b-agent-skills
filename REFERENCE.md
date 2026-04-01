# b-agent-skills — Skill reference

Detailed reference for all skills in the b-agent-skills suite.
For quick overview and installation, see [README.md](README.md).
Formatting note: bullet style is standardized across all skill specs for consistent readability.

## Skill reference

### b-plan

Decomposes non-trivial tasks into ordered steps, dependencies, and risks before
implementation. Includes a conditional **feasibility gate (Step 0)** for uncertain scope
to confirm Understanding Lock, blockers, and effort. Uses `sequential-thinking` for
decomposition and unknown/risk surfacing. For modify-existing-code tasks, scans with
`jcodemunch` (`suggest_queries` → `get_repo_outline` → `get_file_outline` batch, optional
`get_file_tree`) so plans reference real paths/symbols and follow existing patterns.
Includes an explicit **architecture trade-off checkpoint**, a **deploy safety checkpoint** (new routes/endpoints/UI → suggest feature flag; DB schema changes → document migration ordering — additive before deploy, destructive after; new external service calls/queues → flag availability verification), and a plan-file handoff for execution in a fresh session. Deploy safety findings are appended to the plan's `## Risks` section.

**Good triggers:**
```
b-plan: add rate limiting to the API
plan: design the notification system
how should I approach refactoring the auth module?
where do I start with the payment gateway integration?
```

**Output:** Plan file written to `.opencode/b-plans/[task-slug].md` in the current
project root — with ordered steps (checkbox format), dependency map, risk flags, unknowns
marked as `b-docs` or `b-research` calls, and an optional `## Feasibility` section when
Step 0 ran. b-analyze and b-docs findings are appended to the same file for use in
the execution session. Two additional sections are always included for OpenCode execution:
`## Last Gate Failure` (written by b-execute-plan when b-gate fails) and
`## Review Feedback` (written when b-review returns NEEDS FIXES).

**Feasibility gate (Step 0):** Runs when task scope is uncertain or decision is not
yet made. Confirms the Understanding Lock (one-sentence feature description + success
criteria), quick architecture scan for blockers, and effort estimate. Skip if task is
clearly scoped, user has already decided to proceed, or it is ≤3 steps / single-file.

**Step 0/1 de-duplication:** If Step 0 ran, Step 1 skips the scope/end-state questions (already locked in Understanding Lock) and only verifies: (a) greenfield vs existing code, and (b) any hard constraints not yet captured. Avoids asking the same questions twice.

**Issue/ticket field:** Step 1 asks (optional) for an issue/ticket URL or ID. If provided, writes `**Issue**: [value]` to the plan file header after `**Created**`. Accepts full URLs (`https://linear.app/…`, `https://github.com/…/issues/123`), short ticket IDs (`PROJ-456`, `#123`), or free-text references. b-review reads this field to enrich the requirements baseline.

**Rule:** Never execute in the same session as planning — always save to a plan file and open a new session with b-execute-plan.

**Git safety:** Never triggers destructive git commands. If a commit is needed, delegates to b-commit.

**Execution:** After all steps complete, runs **b-gate** (not b-analyze) as the final
quality check. Index refresh: calls `index_file` on each modified file after each step.

**English-only plan files:** Plan files are always written in English — regardless of the user's query language.

---

### b-execute-plan

Orchestrates the full development pipeline (b-analyze → b-tdd → b-gate → b-review → b-commit) by
reading plan files, tracking step completion, and auto-advancing through successful stages. Reads
`.opencode/b-plans/*.md` files, parses checkbox state, displays progress, invokes each skill
automatically, and moves to the next stage on success. Pauses only on failure, ambiguous routing,
manual steps, NEEDS FIXES verdicts, or parallel step choices.

**Good triggers:**
```
execute plan
run plan: implement-b-execute-plan.md
/b-execute-plan
orchestrate the pipeline
```

**Workflow:**
0. **Pre-execution (conditional)**: if the plan modifies existing code and no `## Context` section exists → extract explicit file paths from plan Steps, run b-analyze scoped to only those paths, append as `## Context`. Ask user if scope is ambiguous — never run unconstrained full-repo analysis.
1. Locate plan file: from argument if provided; if none, Glob `.opencode/b-plans/*.md` — if multiple exist, list with timestamps and ask (never auto-select). **Session resume**: completed (`[x]`) steps are skipped automatically.
   - **Context window warning**: if pending steps > 6, warn once and suggest splitting at step 5.
   - **Two-tier context threshold**: session step counter threshold = 3 if plan file contains `## Context` section (analysis-heavy — context fills faster), 5 otherwise. Derived from file content at load time — survives context compression. Fires at 3/6/9… or 5/8/11… respectively.
2. Parse step checkboxes (`- [ ] Step N` / `- [x]` / `- [❌] Step N — reason`).
3. Display state (✓ / ❌ / ○). Detect skill from keywords — **non-production keywords (delete/remove/config/migrate/document/rename) are checked first (Priority 1)** to prevent "create migration" or "create config" routing to b-tdd despite containing "create". Only "create X" with no Priority 1 keyword falls through to Priority 5 (b-tdd). Routing table now includes concrete examples per row. Invocation format is skill-specific: b-tdd → `[plan-file]:[N]`; b-review → `[plan-file]`; b-gate/b-commit → no plan args. Check `## Dependencies` for blocking failures and parallel declarations (offer parallel for b-tdd steps only).
4. Invoke skill and detect outcome. **On success**: auto-advance to step 5 (no user input needed). **b-gate failure shortcut**: if b-gate failed, extract failing check name + first ~10 error lines and offer two options: (1) auto-launch `@b-debug [failing-check]: [key error lines]`, or (2) fix manually. If user picks (1), invokes b-debug immediately, then re-runs b-gate; if passes, auto-advances. **On failure (non-gate or user picks manual)**: pause, capture reason, write `- [❌] N — reason`, run `git diff HEAD --stat` for partial changes, offer `git checkout -- .` rollback before retrying. **Manual steps (Priority 1)**: instruct user, then wait for `done`/`next`/`continue` — the only required pause in the happy path.
5. Update plan checkbox (`[ ]` → `[x]`). Re-read file to recompute session step counter (`current [x] − baseline [x] at session start` — file-based, survives context compression).
6. Loop until done. **NEEDS FIXES re-entry**: user signals fix → run `git diff HEAD --stat` to confirm real changes → ask "cosmetic or new behavior?" → cosmetic: reset b-gate and re-run; new behavior: route through b-tdd first, then b-gate, then b-review. Iron Law is never bypassed.

**Output:**
```
📋 Plan: Implement b-execute-plan
Status: 3 of 6 steps complete ✓

✓ Step 1 — Create b-execute-plan agent file
✓ Step 2 — Design skill workflow
✓ Step 3 — Define Tools required
○ Step 4 — Write Output format
○ Step 5 — Update README.md
○ Step 6 — Update REFERENCE.md

→ Invoking Step 4 — Write Output format and Rules sections via @b-tdd (keyword match: 'write')
[@b-tdd invoked automatically with: @b-tdd .opencode/b-plans/implement-b-execute-plan.md:4]
```

**State tracking:** Parses plan file dynamically. If user manually edits the plan,
b-execute-plan re-reads it on the next loop. Checkpoint updates happen automatically
on success; no user signal required for unambiguous skill routes.

**Scope:** Orchestrates Step 0 (b-analyze, conditional) + production pipeline (b-tdd → b-gate → b-review → b-commit). b-plan is out of scope — use b-plan to create plans, b-execute-plan to run them.

**Git safety:** Never autonomously triggers destructive git commands. Rollback (`git checkout -- .`) is offered to the user, never auto-executed. Commits are always delegated to b-commit.

**Distinction from manual pipeline:** b-execute-plan auto-advances through successful
stages, handling skill invocation and state tracking automatically. Users can still run
pipeline skills manually; b-execute-plan eliminates the step-by-step confirmation overhead
while preserving human control on failures, ambiguity, and NEEDS FIXES.

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

**Fallback chain:** context7 → firecrawl direct scrape (if library has a known official docs URL) → b-research (full research pipeline).

**Git safety:** Never triggers destructive git commands. If a commit is needed, delegates to b-commit. The firecrawl fallback tries a single `firecrawl_scrape` on the official docs URL. If the scrape fails or returns <300 words, b-docs notifies the user and actively invokes b-research with the original library and topic query — it does not ask the user to run b-research manually.

---

### b-research

Deep research workflow: classify query type → search with type-specific tool → scrape
full pages with Firecrawl → synthesize into a structured report with citations. Never
relies on search snippets or training data alone. **Token-optimized**: picks 3 highest-quality URLs, strict post-scrape gate, aggressive source filtering.

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

**Limits:** Max 3 URLs scraped per session (5 for COMPARE queries), selected via strict source hierarchy (Tier 1 official > community > neutral). Pre-scrape filtering eliminates homepages, login pages, aggregators. Post-scrape gate discards <300 words OR topic not mentioned; stops if <2 usable sources remain (no blind rescaping). If Brave returns fewer than 3 relevant results, falls back to `firecrawl_search`. For deep multi-page documentation: use `firecrawl_crawl` + poll `firecrawl_check_crawl_status` (async — do not proceed until `status: "completed"`).

**Context isolation (Step 4):** when ≥ 6 URLs need scraping, spawns a single Explore subagent with the URL list and original research question. The subagent runs all `firecrawl_scrape` calls in parallel, applies the post-scrape quality gate, and returns a compact digest (max 500 words per source with URL). Main context receives only the filtered digest — raw scraped content never floods the main context. When < 6 URLs, scrapes directly in main context. If Agent tool unavailable: falls back to direct parallel scraping in main context.

**Git safety:** Never triggers destructive git commands. If a commit is needed, delegates to b-commit.

---


### b-tdd

Enforces TDD discipline during implementation: detects test stack, enforces the Iron
Law (no production code before a failing test exists), and drives each implementation
step through a full Red-Green-Refactor cycle. No MCP required — uses Bash to run tests.
Stack auto-detected across 7 languages: **Node.js** (`package.json`), **Python** (`pyproject.toml`/`setup.cfg`), **Go** (`_test.go` files), **Rust** (`Cargo.toml` + `#[test]` → `cargo test`), **Java/Kotlin** (`build.gradle`/`pom.xml` → `./gradlew test` or `mvn test`), **Ruby** (`Gemfile` with rspec/minitest → `bundle exec rspec`), **PHP** (`composer.json` with phpunit → `./vendor/bin/phpunit`). Fallback: `Makefile` `test` target, `scripts/test.*`, or any `*Test*`/`*_spec.*` file pattern.

**Good triggers:**
```
b-tdd
test first
viết test trước
red-green-refactor
```

**Argument format:**
- `b-tdd .opencode/b-plans/file.md:3` — single-step mode, runs exactly step 3 (used by b-execute-plan)
- `b-tdd .opencode/b-plans/file.md` — single-step mode, auto-detects first pending step
- `b-tdd` (no args) — iterate-all mode, runs all steps sequentially

**Output:** Per-step RGR checkpoint log (🔴 Red → 🟢 Green → ✅ Refactor). Single-step completion message when called with plan file; full summary + b-gate handoff when iterating all.

**Iron Law:** Never writes production code before a failing test. Documents any
exception with `// b-tdd exception: [reason]`.

**Regression handling:** If a previously passing test breaks during Green, b-tdd determines whether it was caused by the current change (fix production code) or was a pre-existing latent bug (document inline and ask user to decide). Never silently ignores regressions.

**Index refresh:** After each Refactor step, calls `index_file` on all modified files if jcodemunch is available.

**Distinction from b-gate:** b-tdd governs discipline during coding. b-gate validates
the finished result.

**Git safety:** Never triggers destructive git commands. If a commit is needed, delegates to b-commit.

---

### b-gate

Mandatory quality gate — runs after all implementation steps are done. Detects stack
from config files and runs only checks that are present: **lint → typecheck → tests → coverage → security → clean-code → integration/e2e (soft block)**. Hard stops on lint failures, typecheck failures, test failures, coverage threshold violations (when threshold explicitly configured), and high/critical security findings. Soft blocks (warn, continue) on: coverage tool present but no threshold configured, medium/low security, formatting issues, and integration/e2e test failures (integration tests often require external services). Uses Bash only — no MCP required.

**Coverage enforcement (Step 2c.5):** Runs after tests pass. Three-tier behavior: (1) **hard-block** when a threshold is explicitly configured (`coverageThreshold` in jest, `fail_under` in pytest-cov/nyc) and actual coverage falls below it; (2) **soft-warn** when a coverage tool is detected but no threshold is set; (3) **skip** when no coverage tool is detected. Go exception: always soft-warn only (no native threshold enforcement) — reports coverage percentage from `go test -coverprofile` without hard-blocking.

**Good triggers:**
```
b-gate
check quality
kiểm tra chất lượng
validate before done
```

**Stack detection:** checks for `.eslintrc*`, `tsconfig.json`, `pytest.ini`, `package-lock.json`, `.prettierrc*`, `.golangci.yml`, etc. Also detects integration/e2e test configuration: Jest files matching `*integration*`/`*e2e*`, pytest `integration` marker, `Makefile` `test-integration`/`test-e2e` targets, vitest `e2e` project. Skips any check with no config — does not fail because of missing tooling.

**Output:** Gate report listing each check with status (✅ PASSED / ❌ FAILED / ⚠️ not configured).
Clear failure message with specific action when any hard stop occurs.

**Rule:** Never passes with unresolved hard failures. On failure, fix the failing check
and re-run that check only before running the full gate again.

**Distinction from b-tdd:** b-gate validates the finished result. b-tdd enforces
discipline before and during coding.

**Distinction from b-analyze:** b-gate runs automated tooling (lint, tests, security).
b-analyze does deep structural analysis — call graphs, complexity, duplication.

**Git safety:** Never triggers destructive git commands. If a commit is needed, delegates to b-commit.

---

### b-review

Pre-PR human-judgment review on changed code. Reads the git diff, establishes requirements
baseline from the plan file (`.opencode/b-plans/`) or `$ARGUMENTS`, then checks five
dimensions: logic correctness (control flow, null handling, async safety, side effects, plus **security review** — auth/authz enforcement, input validation, sensitive data exposure, injection vectors, rate limiting on new public endpoints), requirements coverage (maps each requirement to changed code — ✅/❌/⚠️ Partial), test adequacy (behavior coverage, unhappy paths, regression safety), and an **observability check** on new handlers/endpoints/jobs (entry-point logging present, errors not swallowed, metric emitted if implied). Uses
`sequentialthinking` to consolidate findings and surface what a senior engineer would
flag. Does not run automated tooling — that is b-gate's role.

**Small-change fast path:** If diff is ≤50 lines AND ≤2 files, accepts any non-empty requirements baseline (one sentence is sufficient), skips the vague-response enforcement loop, and skips both the security review sub-section and the observability check. Full enforcement applies for diffs >50 lines or >2 files.

**Issue enrichment:** After reading the plan file, checks for an `**Issue**:` field. If value starts with `http` → calls `firecrawl_scrape`, trims to 500 words, appends to requirements baseline as `**Issue context** (from [URL]): …`. If scrape returns <200 chars or HTTP 403 → skips silently: "Issue URL requires authentication — using URL as context reference only." If value is a ticket ID (not a URL) → displays as `**Issue reference**: [value]` in review output. If field absent → skips entirely.

**Good triggers:**
```
b-review
b-review: add retry logic to email queue
review before PR
kiểm tra logic trước khi push
what would a reviewer flag?
```

**Output:** Structured checklist — logic findings, requirements coverage table,
edge case / test adequacy notes, reviewer questions, and a READY FOR PR / NEEDS FIXES
verdict with blockers vs suggestions clearly separated.

**Distinction from b-analyze:** b-analyze is pre-implementation structural review
(complexity, duplication, coupling). b-review is post-implementation correctness review
(logic, requirements, tests). Different timing, different questions.

**Distinction from b-gate:** b-gate runs lint/typecheck/tests/security automatically.
b-review checks whether the code does the right thing — automated tools cannot answer that.

**Handoff:** READY FOR PR → run `b-commit`. NEEDS FIXES → fix blockers, re-run b-gate if
code changed, then b-review again.

**Git safety:** Never triggers destructive git commands. If a commit is needed, delegates to b-commit.

---

### b-commit

Reads `git diff HEAD` to understand the change, then outputs a ready-to-use commit
message and PR description — nothing more. Does not stage, commit, push, or create a
PR. Commit message follows conventional commits format: `<type>(<scope>): <subject>`
(imperative, ≤72 chars, behavior-level). Body explains *why*, not *what*. PR
description uses structured sections: Summary, Why, Changes, Test plan, Notes.
Flags mixed-concern diffs and suggests splitting, but does not refuse to produce output.

**Good triggers:**
```
b-commit
b-commit: add retry logic to email queue
tạo commit
viết commit message
PR description
```

**Output:** Commit message block + PR description block, ready to copy-paste.
On mixed-concern diffs: stops and outputs 2 separate commit message suggestions (one per concern group) with instructions to split via `git add -p`. Does not produce a single unified message for a mixed diff.

**Distinction from b-gate:** b-gate runs automated checks. b-commit produces text only.

**Prerequisite:** b-gate should have passed before running b-commit.

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

**Stale index detection:** When `resolve_repo` returns an existing index, calls `get_session_stats` and compares `files_indexed` against a Glob count of source files (`**/*.{ts,tsx,js,jsx,py,go,rs,java,rb,php,kt,swift}`). If drift >10%, calls `index_folder` to re-index before proceeding. If `get_session_stats` unavailable: notes "⚠️ Could not verify index freshness" and continues.

**Quick/deep mode:** Pass `quick` as `$ARGUMENTS` to run Steps 1–2 only (structure map — no quality analysis, no sequential-thinking). Allowed calls in quick mode: `resolve_repo`, `suggest_queries`, `get_repo_outline`, `get_file_outline`. Quick mode output is structure overview only (no findings, no severity ratings). Default (no args or `deep`) runs full Steps 1–5.

**Role:** Pre-implementation understanding and standalone code review only. Not called
as a post-implementation self-review — use **b-gate** for that.

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

**Distinction from b-gate:** Use b-gate for post-implementation quality validation
(lint, tests, security). Use b-analyze for structural understanding and code review.

**b-debug handoff:** If analysis reveals a bug (broken logic, not just poor style) → state: 'Root cause analysis needed. Run: `b-debug: [symptom] in [entry point]` to trace the execution path.'

**Git safety:** Never triggers destructive git commands. If a commit is needed, delegates to b-commit.

---

### b-observe

Static observability audit — finds missing log statements, silently swallowed errors,
missing metrics instrumentation, and absent tracing context propagation in source code.
Does **not** do runtime profiling or APM configuration — static analysis only.
Uses jcodemunch to map instrumented vs uninstrumented call sites: `search_text` for
log/trace/metric patterns, `find_references` on logger/tracer symbols to identify files
with zero instrumentation, `get_symbol_source` to read error handler bodies,
`get_file_outline` (batch) to enumerate all handlers. Uses `sequentialthinking`
to rank findings by on-call impact.

**Good triggers:**
```
b-observe: the payment service
observability audit
find missing logs in background workers
kiểm tra log trong service xử lý đơn hàng
tìm lỗi bị nuốt trong error handlers
tracing coverage audit
```

**Output:** Grouped findings by gap type — missing logs (🔴/🟡/🟢), missing metrics,
missing tracing spans. Metrics snapshot (handlers audited, % uninstrumented).
Ordered remediation list ranked by "which gap causes the most confusion during an outage".

**Scope:** Static analysis only — no runtime profiling, no APM config, no log format
validation. `console.log` flagged as Medium (observable but unstructured), not High.
If no instrumentation library detected at all → 🔴 High at the top of the report.

**Distinction from b-analyze:** b-analyze covers structural quality (complexity,
coupling, duplication). b-observe covers instrumentation completeness — orthogonal concern.

**Distinction from b-debug:** b-debug traces live failures. b-observe prevents
the silence that makes future failures invisible.

**Git safety:** Never triggers destructive git commands. If a commit is needed, delegates to b-commit.

---

### b-debug

Systematic, hypothesis-driven bug tracing. Resolves or indexes the codebase first via
`resolve_repo` → `index_folder` (if needed), then optionally calls `suggest_queries`
(unfamiliar codebases), then maps the full execution path with jcodemunch
(`get_context_bundle` → `find_references` → `get_blast_radius` → `get_symbol_source`).
For suspicious functions, uses `get_related_symbols`
to find similar patterns elsewhere. For regression detection: `get_symbol_diff`. For
error string origin: `search_text`. Forms ranked hypotheses with sequential-thinking.
When static analysis is insufficient to confirm root cause, uses a **dynamic verification loop**: add 1–2 targeted log statements at the suspected choke point → instruct user to run the failing scenario and paste output → analyze output to confirm or eliminate hypothesis → remove debug logging after confirmation. Hard cap of 3 iterations; after 3 unconfirmed rounds, surfaces all gathered evidence and escalates (APM/profiler, isolation, or escalation). Confirms root cause, then fixes. For library errors: `brave_web_search` → `firecrawl_scrape`
(with `firecrawl_map` fallback when scrape returns empty) → `b-docs`. Never patches
before root cause is confirmed.

**Stale index detection:** When `resolve_repo` returns an existing index, calls `get_session_stats` and compares `files_indexed` against a Glob count of source files (`**/*.{ts,tsx,js,jsx,py,go,rs,java,rb,php,kt,swift}`). If drift >10%, calls `index_folder` to re-index before proceeding. If `get_session_stats` unavailable: notes "⚠️ Could not verify index freshness" and continues.

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

**Git safety:** Never triggers destructive git commands. If a commit is needed, delegates to b-commit.

---

### b-sync

Syncs OpenCode agents from the `b-agent-skills` GitHub repo to `~/.config/opencode/agents/` using `curl` + `install.sh`. No MCP required — only the Bash tool.

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

**Distinction from other skills:** b-sync only manages skill installation — it does not invoke other skills.

---

## Usage patterns

### Pattern 1 — New feature
For any non-trivial feature, use the standard pipeline:
```
1. b-plan: [task]          → feasibility gate (Step 0, conditional) + confirm plan
2. b-analyze: [module]     → understand existing code (skip if greenfield)
3. b-docs: [library]       → fetch accurate API (skip if no libraries)
4. b-tdd                   → implement with Iron Law + Red-Green-Refactor per step
5. b-gate                  → lint → typecheck → tests → security → clean-code
6. b-review: [task]        → logic, requirements coverage, edge cases, test adequacy
7. b-commit: [task]        → commit message + PR description text
```
b-plan's execution section automates steps 2 and 5 (b-analyze at start, b-gate at end).

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
1. b-plan: [task]          → feasibility gate (Step 0, optional) + confirm plan
2. b-analyze: [module]     → understand existing code
3. b-docs: [library]       → fetch accurate API
4. b-tdd                   → implement with Red-Green-Refactor discipline
5. b-gate                  → automated quality validation
6. b-review: [task]        → human-judgment review (logic, requirements, tests)
7. b-commit: [task]        → commit message + PR description text
```
You control the pace at each step. b-plan's execution section automates steps 2 and 5.

---

## Trigger tips

OpenCode may skip skills on tasks that appear simple. To guarantee activation:

- **Prefix with the skill name**: `b-plan: ...`, `b-tdd`, `b-gate`, `b-debug: ...`, `b-research: ...`
- **Use explicit keywords**: "plan", "tdd", "gate", "analyze", "research", "debug" trigger reliably
- **Describe complexity**: mentioning "multiple files", "new integration", "not sure why" increases trigger rate

When in doubt, call the skill by name.

---

## Skill interaction map

```
b-plan ──── Step 0 (conditional) ────────► jcodemunch (resolve_repo → get_repo_outline → get_dependency_graph)
       ──── modify existing code ─────────► jcodemunch (resolve_repo → scan structure first)
       ──── flags unknowns ──────────────► b-docs     (library API needed, resolved inline)
                                         ► b-research  (decision needed)
       ──── execution: file modified ────► jcodemunch (index_file to keep index fresh)
       ──── execution: all steps done ──► b-gate     (final quality check)

b-tdd ───── called with [file.md]:[N] ────► single-step mode: run exactly step N, return control
      ───── called with [file.md] only ────► single-step mode: auto-detect first pending step
      ───── called with no args ───────────► iterate-all mode: run all steps sequentially
      [NOTE: b-gate and b-commit do NOT accept [file.md]:[N] — pass no plan args to them]
      ───── detect test stack ─────────────► Bash (read package.json / pyproject.toml / Makefile)
      ───── run tests ─────────────────────► Bash (npm test / pytest / go test ./...)
      ───── refactor complete ─────────────► jcodemunch (index_file on modified files, optional)
      ───── all steps complete ────────────► b-gate (handoff for final validation)

b-gate ──── GATE PASSED ──────────────────► b-review (human-judgment review before PR)

b-review ── read diff ────────────────────► Bash (git diff HEAD)
         ── requirements baseline ─────────► plan file (.opencode/b-plans/) or $ARGUMENTS
         ── Issue URL enrichment ──────────► firecrawl_scrape (optional, when **Issue**: URL present in plan)
         ── symbol context ────────────────► jcodemunch (get_symbol_source, get_context_bundle, optional)
         ── consolidate findings ──────────► sequential-thinking
         ── READY FOR PR ─────────────────► b-commit

b-commit ── read diff ────────────────────► Bash (git diff HEAD, git diff --stat)
         ── output text only ──────────────► commit message + PR description (no git execution)

b-docs ──── context7 has no index ──────► firecrawl   (direct scrape of official docs URL, single page)
       ──── firecrawl insufficient ─────► b-research  (full multi-source research, active invoke)
       ──── context7 unavailable ───────► b-research  (active invoke — notify user then escalate directly)

b-debug ─── trace execution path ────────► jcodemunch (resolve_repo → stale index check → suggest_queries → get_context_bundle → find_references → get_blast_radius → get_symbol_source → get_related_symbols)
        ─── stale index check ────────────► jcodemunch (get_session_stats → Glob count → index_folder if >10% drift, optional)
        ─── regression detection ────────► jcodemunch (get_symbol_diff)
        ─── error string lookup ─────────► jcodemunch (search_text)
        ─── post-fix index refresh ──────► jcodemunch (index_file on changed files)
        ─── library error detected ──────► brave-search (lookup known issues)
                                         ► firecrawl_scrape (top 1–2 pages, optional)
                                         ► firecrawl_map (if scrape empty, optional)
                                         ► b-docs      (verify API behavior)

b-analyze ── quick mode ($ARGS=quick) ─────► jcodemunch (resolve_repo + suggest_queries + get_repo_outline + get_file_outline only)
          ── full/deep mode (default) ────► jcodemunch (full 13-tool suite)
          ── index or resolve ────────────► jcodemunch (resolve_repo → index_folder if needed)
          ── stale index check ───────────► jcodemunch (get_session_stats → Glob count → index_folder if >10% drift, optional)
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

b-observe ── detect libraries ──────────► jcodemunch (search_text for log/trace/metric patterns)
          ── map instrumented files ──────► jcodemunch (find_references on logger/tracer symbols)
          ── read error handlers ─────────► jcodemunch (get_symbol_source)
          ── enumerate handlers ──────────► jcodemunch (get_file_outline batch)
          ── rank by on-call impact ──────► sequential-thinking (ordered remediation list, optional)
          ── findings need fixes ─────────► b-plan (sequence remediation safely)

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