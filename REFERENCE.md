# b-skills — Skill reference

Detailed contract reference for the b-skills suite. For install and overview, see [README.md](README.md).

---

## Skill reference

### b-plan

Think before coding. Decompose tasks into ordered steps, evaluate competing approaches,
surface risks, and produce an execution-ready plan file.

**Core behavior**
- Uses `sequential-thinking` to decompose work and rank approaches.
- For existing-code tasks, follows a strict symbol-first read-order: activate → discover → overview → references → narrow reads.
- Uses `get_symbols_overview` before opening symbol bodies, then reads only the exact symbols needed.
- Uses sequential-thinking for both approach selection and ordered execution steps, with action-oriented output.
- Evaluates multiple approaches and documents the chosen one in `## Decision`.
- Includes a feasibility gate for uncertain or large-scope tasks.
- Adds deploy-safety annotations (feature flags, migration ordering, external dependencies).

**Good triggers**
```text
/b-plan add rate limiting to the API
plan: design the notification system
how should I approach refactoring the auth module?
```

**Output**
- Writes a plan file to `.claude/b-plans/[task-slug].md`.
- Includes: `## Decision` (approach chosen + alternatives rejected), ordered checkbox steps,
  dependencies, risks, unknowns, and optional `## Feasibility`.
- Plan files are always in English.

**Key rules**
- Do not implement in the same session as planning.
- The feasibility gate only confirms blockers and scope; it does not replace `/b-research` for deep unknowns.
- All unresolved unknowns must be surfaced in the plan — never deferred silently.

---

### b-research

All external knowledge in one skill: library docs lookups and deep multi-source research.

**Core behavior**
- Classifies query into VERSION / COMPARE / NEWS / HOWTO/API.
- For HOWTO/API queries: detects project version from manifests/lockfiles → Context7 first → web search for community context.
- For simple library lookups where Context7 answers the question: stops and presents Library Lookup format directly.
- For broad queries: Brave Search → Firecrawl scrape → structured data extraction (when query asks about specific fields) → quality gate → synthesis report.
- Uses `sequential-thinking` only when conflicting sources materially change the recommendation.
- Prefers 3 high-quality sources over 5 mixed-quality ones.

**Good triggers**
```text
/b-research how do I configure retries in BullMQ?
/b-research compare bullmq vs bee-queue for job queues
/b-research best practices for webhook signature verification
tra cứu cách dùng thư viện Prisma
```

**Output**
- **Library lookup**: concise API summary with key methods, example, and version notes.
- **Research report**: structured report with summary, findings, optional comparison table, limitations, and cited sources.

**Key limits**
- Default scrape cap: 3 URLs per session; 5 for COMPARE queries.
- Never fill factual gaps from training data when sources do not support them.

---

### b-debug

Systematic, hypothesis-driven debugging with full-loop execution by default.

**Core behavior**
- Uses Serena to map execution path, references, suspicious symbols, and exact files.
- Activates the current project before tracing the code path.
- Follows a strict read-order: activate → find symbol → overview → references/patterns → narrow reads → symbolic fix. Never jumps to full-file reads without narrowing first.
- Narrows with `get_symbols_overview` before opening full symbol source where possible.
- Uses `sequential-thinking` to rank hypotheses.
- Requires each hypothesis to include evidence for/against and the cheapest verification step.
- Library error shortcut: web search for known issues before verifying hypotheses.
- Dynamic verification loop when static analysis is insufficient (max 3 instrumentation rounds).
- After confirming root cause, implements the minimal fix using symbol-aware tools and states exact verification steps.

**Default contract**: `trace → confirm root cause → fix → verify`
Diagnosis-only is allowed only when the caller explicitly requests it.

**Good triggers**
```text
/b-debug webhook not triggering despite correct URL registration
/b-debug intermittent 500 on /api/send with no error in logs
why is this callback not running?
```

**Output**
```
Symptoms → Code path → Ranked hypotheses → Root cause → Fix → Verification
```

**Key rules**
- Never patch before root cause is explicitly confirmed.
- After fixing, keep Serena-aware edits focused on the changed symbols/files only.

---

### b-review

Human-judgment pre-PR review: correctness, requirements, edge cases, tests, and minimum
observability on new entry points.

**Core behavior**
- Reads git diff and builds requirements baseline from plan file, `$ARGUMENTS`, or user clarification.
- Uses Serena to prioritize review depth by changed symbols, references, and affected files.
- Activates the current project before reviewing changed symbols.
- Follows a strict read-order: find symbol → find referencing symbols → overview → narrow reads. Never jumps straight from diff to full file reads.
- Reviews changed files outline-first, then opens only high-risk symbols/source paths.
- Uses `sequential-thinking` only when blocker/suggestion classification is genuinely ambiguous, not by default.
- Always checks **injection vectors**, even on very small diffs.
- Runs observability check only for newly added endpoints/handlers/jobs/consumers.

**Small-change fast path** — if diff is ≤50 lines AND ≤2 files:
- Accepts any non-empty requirements baseline
- Skips vague-response enforcement, observability check, expanded security checklist
- Still checks **injection vectors**

**Good triggers**
```text
/b-review
review before PR
kiểm tra logic trước khi push
```

**Output**
```
Logic findings → Requirements coverage table → Edge cases / test adequacy → Observability
→ Reviewer question → READY FOR PR or NEEDS FIXES
```

**Handoff**
- `READY FOR PR` → implement any non-blocking suggestions, then commit.
- `NEEDS FIXES` → fix blockers, re-run tests, then `/b-review` again.

---

## Usage patterns

### Standard feature flow
```
1. /b-plan [task]
2. /b-research [library]     (if needed before implementing)
3. [implement manually, step by step]
4. /b-review [task]
5. commit
```

### Debug flow
```
/b-debug [symptom + expected behavior]
```

### Before touching unfamiliar code
```
/b-plan [task]    (b-plan scans existing code as part of planning)
```

### Library choice / comparison
```
/b-research compare [A] vs [B] for [use case]
```

### Known library, API uncertain
```
/b-research [library] — [feature]
```

---

## Trigger tips

- Invoke skills with `/` prefix: `/b-plan`, `/b-debug`, `/b-review`, `/b-research`
- Use explicit intent words: `plan`, `debug`, `review`, `research`
- Mention complexity when relevant: multi-file, unfamiliar module, unclear root cause.

---

## Skill interaction map

```
/b-plan ──────────────── writes ─────────────────► plan file in .claude/b-plans/
        └── unknown library/approach ────────────► /b-research (before or during planning)

/b-review ────────────── READY FOR PR ───────────► commit
          └──────────── NEEDS FIXES ─────────────► fix → /b-review again

/b-debug ─────────────── bug found during impl ──► fix inline
         └──────────── fix introduces new code ──► /b-review (optional)
```
