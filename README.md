# b-agent-skills

A personal skill suite for Claude Code, organized into two groups:

- **Development skills** — a tightly integrated pipeline for software development work, leveraging all 5 MCPs
- **Personal / daily skills** — standalone utilities for everyday personal use

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
| [`b-plan`](#b-plan) | sequential-thinking | Before writing code for any non-trivial task |
| [`b-docs`](#b-docs) | context7 | Before using any library or SDK |
| [`b-research`](#b-research) | brave-search, firecrawl, context7 | Deep research, tool comparison, synthesis |
| [`b-analyze`](#b-analyze) | jcodemunch | Understand or review code before changing it |
| [`b-debug`](#b-debug) | jcodemunch, sequential-thinking | Trace bugs that have no obvious cause |
| [`b-feature`](#b-feature) | all of the above | Full pipeline for complex feature development |

### Personal / daily skills

| Skill | MCP(s) | Use when |
|---|---|---|
| [`b-quick-search`](#b-quick-search) | brave-search | Quick one-call web lookup for current info |
| [`b-news`](#b-news) | brave-search, firecrawl | Daily tech news digest |

---

## Skill reference

### b-plan

Decomposes any non-trivial task into ordered steps, dependencies, and risks before
any implementation begins. Uses `sequential-thinking` to reason through the happy path,
identify blockers, and surface unknowns that need resolution first.

**Good triggers:**
```
b-plan: add rate limiting to the API
plan: design the notification system
how should I approach refactoring the auth module?
where do I start with the payment gateway integration?
```

**Output:** Ordered step list with "done when" criteria, dependency map, risk flags,
and explicit unknowns marked as `b-docs` or `b-research` calls.

**Rule:** User must confirm the plan before implementation begins.

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
```

**Output:** Accurate method signatures, required parameters, auth setup, error codes,
and deprecation notices for the current version. Followed by implementation if requested.

**Fallback:** If context7 has no index for the library → escalates to `b-research`
to scrape official docs directly.

---

### b-research

Deep research workflow: search with Brave → scrape full pages with Firecrawl → fetch
versioned docs with Context7 (for library topics) → synthesize into a structured report
with citations. Never relies on search snippets or training data alone.

**Good triggers:**
```
b-research: compare bullmq vs bee-queue for job queues
research: best practices for webhook signature verification
compare Prisma vs Drizzle for a TypeScript project
deep dive into Redis Streams
```

**Output:** Summary, key findings, optional comparison table, and cited sources.
Context7 is used automatically when the topic is a library or framework.

**Limits:** Max 5 URLs scraped per session. JS-heavy pages get one retry with
`waitFor: 3000` before being skipped.

---

### b-analyze

Deep code analysis using jcodemunch — maps structure, measures complexity, identifies
duplicate logic, and produces severity-ranked findings with concrete suggestions.
Does not fix anything; produces findings only.

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

---

### b-debug

Systematic, hypothesis-driven bug tracing. Maps the full execution path with jcodemunch,
forms ranked hypotheses with sequential-thinking, confirms root cause, then fixes.
Never patches before root cause is confirmed.

**Good triggers:**
```
b-debug: webhook not triggering despite correct URL registration
b-debug: intermittent 500 on /api/send with no error in logs
why is this callback not running?
fix: email queue jobs disappearing silently
```

**Output:** Symptoms summary, execution path map, ranked hypotheses, confirmed root cause,
minimal fix, and verification instructions.

**Rule:** No patch is written until root cause is explicitly confirmed. If the bug
involves a library's behavior, `b-docs` is invoked to verify the correct API.

---

### b-feature

Full-cycle orchestrator. Chains all other skills in a fixed pipeline:

```
PLAN → UNDERSTAND → GATHER → IMPLEMENT → REVIEW
```

Each phase gates the next. Some phases are conditional based on task context.

| Phase | Skill | Conditional? |
|---|---|---|
| Plan | b-plan | Always |
| Understand existing code | b-analyze | Skip if greenfield |
| Fetch library docs | b-docs | Skip if no libraries involved |
| Research unknowns | b-research | Skip if no open decisions |
| Implement | — | Always |
| Self-review new code | b-analyze | Always |

**Good triggers:**
```
b-feature: add Amazon SES as a fourth email provider
b-feature: implement exponential backoff retry for all providers
b-feature: add webhook signature verification
```

**Rule:** Always prefix with `b-feature:` to guarantee trigger. Without the prefix,
Claude may implement directly and skip the pipeline.

**Not for:** Simple one-file edits, bug fixes, or quick questions. Use individual
skills for those — they're faster.

---

## Usage patterns

### Pattern 1 — New feature
For any non-trivial feature, use the full pipeline:
```
b-feature: [describe the feature]
```
Claude runs Plan → Understand → Docs → Implement → Review automatically.

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
Same as b-feature but you control the pace at each step.

---

## Trigger tips

Claude Code may skip skills on tasks that appear simple. To guarantee activation:

- **Prefix with the skill name**: `b-debug: ...`, `b-feature: ...`, `b-plan: ...`
- **Use explicit keywords**: "plan", "analyze", "research", "debug" trigger reliably
- **Describe complexity**: mentioning "multiple files", "new integration", "not sure why" increases trigger rate

When in doubt, call the skill by name.

---

## Skill interaction map

```
b-plan ──── flags unknowns ──────────────► b-docs     (library API needed)
                                         ► b-research  (decision needed)

b-debug ─── root cause is library-related ► b-docs    (verify API behavior)

b-analyze ── findings need refactor ──────► b-plan    (sequence it safely)

b-feature ── orchestrates all ────────────► b-plan
                                          ► b-analyze  (understand existing)
                                          ► b-docs     (gather API)
                                          ► b-research (gather knowledge)
                                          ► implement
                                          ► b-analyze  (self-review)
```

---

---

## Personal / daily skill reference

### b-quick-search

Single-call web lookup via Brave Search. Returns a fast, cited answer from the live
web — no scraping, no deep synthesis. The rule: one search call, one clean answer.

**Good triggers:**
```
b-quick-search: latest version of Node.js
what's the current price of M4 MacBook Pro?
latest release of Fedora?
recent CVE for OpenSSL?
```

**Output:** Direct answer with source citations. Single-fact queries get an inline
citation; multi-point queries get a short "Key findings" list.

**Distinction from b-research:** If one search can answer it → b-quick-search.
If you need to read multiple full pages → b-research.

**Fallback:** If results are insufficient, says so and suggests b-research.

---

### b-news

Aggregates today's top tech news from 8 curated sources (Ars Technica, 9to5Google,
9to5Mac, 9to5Linux, BleepingComputer, The Register, How-To Geek, Hacker News),
groups by topic, and outputs a bilingual digest (English + Vietnamese).

**Good triggers:**
```
b-news
tin tức hôm nay
có gì mới hôm nay?
tech news
điểm tin
```

**Output:** Grouped digest with categories — 🤖 AI, 🔒 Security, 📱 Mobile,
💻 Software, 🐧 Linux, 🏢 Big Tech, 📌 Other. Each story has an English headline
+ summary + source link, followed by Vietnamese translation. Max 3 stories per category.

**On-demand detail:** Follow up with "đọc thêm về [story]" to scrape the full article
via firecrawl.

---


## Installation

Copy each skill folder into your Claude Code skills directory:

```bash
cp -r b-plan b-docs b-research b-analyze b-debug b-feature b-quick-search b-news ~/.claude/skills/
```

Verify all MCPs are connected:
```
/mcp
```

All 5 must show `✓ Connected`:
`context7`, `brave-search`, `firecrawl`, `jcodemunch`, `sequential-thinking`