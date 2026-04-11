# b-agents — Agent reference

Detailed contract reference for the b-agents suite. For install and overview, see [README.md](README.md).

---

## Agent reference

### b-plan

Think before coding. Decompose tasks into ordered steps, evaluate competing approaches,
surface risks, and produce an execution-ready plan file.

**Core behavior**
- Uses `sequential-thinking` to decompose work and rank approaches.
- For existing-code tasks, uses jcodemunch preflight plus targeted structure reads.
- Evaluates multiple approaches and documents the chosen one in `## Decision`.
- Includes conditional **Step 1 feasibility gate** for uncertain or large-scope tasks.
- Adds deploy-safety annotations (feature flags, migration ordering, external dependencies).

**Good triggers**
```text
use b-plan: add rate limiting to the API
plan: design the notification system
how should I approach refactoring the auth module?
lên kế hoạch thêm rate limiting
```

**Output**
- Writes a plan file to `.claude/b-plans/[task-slug].md`.
- Includes: `## Decision` (approach chosen + alternatives rejected), ordered checkbox steps,
  dependencies, risks, unknowns, and optional `## Feasibility`.
- Plan files are always in English.

**Key rules**
- Do not implement in the same session as planning.
- Step 1 feasibility gate only confirms blockers; it does not replace `b-research` for deep unknowns.
- All unresolved unknowns must be surfaced in the plan — never deferred silently.

---

### b-research

All external knowledge in one agent: library docs lookups and deep multi-source research.

**Core behavior**
- Classifies query into VERSION / COMPARE / NEWS / HOWTO/API.
- For HOWTO/API queries: detects project version from manifests/lockfiles → Context7 first → web search for community context.
- For simple library lookups where Context7 answers the question: stops and presents Library Lookup format directly.
- For broad queries: Brave Search → Firecrawl scrape → quality gate → synthesis report.
- Prefers 3 high-quality sources over 5 mixed-quality ones.

**Good triggers**
```text
use b-research: how do I configure retries in BullMQ?
b-research: compare bullmq vs bee-queue for job queues
b-research: best practices for webhook signature verification
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
- Uses jcodemunch to map execution path, references, blast radius, and suspicious symbols.
- Uses `sequential-thinking` to rank hypotheses.
- Library error shortcut: web search for known issues before verifying hypotheses.
- Dynamic verification loop when static analysis is insufficient (max 3 instrumentation rounds).
- After confirming root cause, implements the minimal fix and states exact verification steps.

**Default contract**: `trace → confirm root cause → fix → verify`
Diagnosis-only is allowed only when the caller explicitly requests it.

**Good triggers**
```text
b-debug: webhook not triggering despite correct URL registration
b-debug: intermittent 500 on /api/send with no error in logs
why is this callback not running?
lỗi này là do gì?
```

**Output**
```
Symptoms → Code path → Ranked hypotheses → Root cause → Fix → Verification
```

**Key rules**
- Never patch before root cause is explicitly confirmed.
- After fixing, refresh changed-file index when jcodemunch is available.

---

### b-review

Human-judgment pre-PR review: correctness, requirements, edge cases, tests, and minimum
observability on new entry points.

**Core behavior**
- Reads git diff and builds requirements baseline from plan file, `$ARGUMENTS`, or user clarification.
- Uses jcodemunch to prioritize review depth by changed symbols and blast radius.
- Always checks **injection vectors**, even on very small diffs.
- Runs observability check only for newly added endpoints/handlers/jobs/consumers.

**Small-change fast path** — if diff is ≤50 lines AND ≤2 files:
- Accepts any non-empty requirements baseline
- Skips vague-response enforcement, observability check, expanded security checklist
- Still checks **injection vectors**

**Good triggers**
```text
review before PR
use b-review
kiểm tra logic trước khi push
```

**Output**
```
Logic findings → Requirements coverage table → Edge cases / test adequacy → Observability
→ Reviewer question → READY FOR PR or NEEDS FIXES
```

**Handoff**
- `READY FOR PR` → implement any non-blocking suggestions, then commit.
- `NEEDS FIXES` → fix blockers, re-run tests, then `b-review` again.

---

## Usage patterns

### Standard feature flow
```
1. b-plan: [task]
2. b-research: [library]     (if needed before implementing)
3. [implement manually, step by step]
4. b-review: [task]
5. commit
```

### Debug flow
```
b-debug: [symptom + expected behavior]
```

### Before touching unfamiliar code
```
b-plan: [task]    (b-plan scans existing code as part of planning)
```

### Library choice / comparison
```
b-research: compare [A] vs [B] for [use case]
```

### Known library, API uncertain
```
b-research: [library] — [feature]
```

---

## Trigger tips

- Prefix with agent name: `b-plan: ...`, `b-debug: ...`, `b-review`, etc.
- Use explicit intent words: `plan`, `debug`, `review`, `research`.
- Mention complexity when relevant: multi-file, unfamiliar module, unclear root cause.

---

## Agent interaction map

```
b-plan ──────────────── writes ─────────────────► plan file in .claude/b-plans/
       └── unknown library/approach ────────────► b-research (before or during planning)

b-review ────────────── READY FOR PR ───────────► commit
         └──────────── NEEDS FIXES ─────────────► fix → b-review again

b-debug ─────────────── bug found during impl ──► fix inline
        └──────────── fix introduces new code ──► b-review (optional)
```
