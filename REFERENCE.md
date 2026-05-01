# b-skills — Skill reference

Detailed contract reference for the b-skills suite. For install and overview, see [README.md](README.md).

---

## Skill reference

### b-plan

Think before coding. Decompose tasks into ordered steps, evaluate competing approaches,
surface risks, and produce an execution-ready plan file.

**Core behavior**
- Supports **quick mode** for scoped daily tasks: concise chat plan, approval, then same-session implementation may proceed.
- Supports **full mode** for unclear, high-risk, multi-layer, or broad-impact tasks: write an execution-ready plan file before implementation.
- Chooses quick vs full automatically from task complexity, announces the selected mode and why, and asks the user only when speed vs durable handoff is a genuine preference trade-off.
- Escalates quick → full when discovery reveals broad references, unclear requirements, structural decisions, external API uncertainty, or deployment risk.
- Uses `sequential-thinking` to decompose work and rank approaches when available; otherwise reasons inline with the same structure.
- If Serena is unavailable, falls back to Bash/Read for narrow code inspection with reduced cross-file confidence.
- For existing-code tasks, follows a strict supported-Serena read-order: onboarding check → symbol discovery → overview → references → narrow native reads only when needed.
- Uses `get_symbols_overview` before opening source bodies, then reads only the exact sections needed.
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
- Quick mode: returns a concise 2–5 step chat plan with a verification step.
- Full mode: writes a plan file to `.claude/b-plans/[task-slug].md`.
- Full-mode plans include: `## Decision` (approach chosen + alternatives rejected), ordered checkbox steps,
  dependencies, risks, unknowns, and optional `## Feasibility`.
- Final plans must be self-contained enough that a fresh agent can execute them without clarifying questions.
- Saved plan files are always in English.

**Key rules**
- Do not implement until the user approves the plan; after approval, implementation may proceed in the same session.
- Full mode must write to `.claude/b-plans/`; quick mode may stay in chat unless the user asks for a saved plan.
- The feasibility gate only confirms blockers and scope; it does not replace `/b-research` for deep unknowns.
- All unresolved unknowns must be surfaced in the plan — never deferred silently.

---

### b-research

All external knowledge in one skill: auto-detects quick lookup vs full multi-source research.

**Core behavior**
- Starts with mode detection: quick lookup for single-fact questions, full mode for comparisons, cited reports, recency, or page-reading.
- For library/framework API questions: Context7 first.
- In quick mode: answers in 1–3 sentences with a minimal example, capped at 2 tool calls, and never scrapes.
- Starts with quick mode when plausible, then escalates automatically to full mode if the answer needs more than 2 tool calls, more than 1 source, or any page scraping.
- If quick mode is insufficient, escalates automatically to full mode instead of asking the user to switch skills.
- In full mode: classifies query into VERSION / COMPARE / NEWS / HOWTO/API → Brave Search → Firecrawl scrape/extract → quality gate → synthesis report.
- Uses `sequential-thinking` only when conflicting sources materially change the recommendation.
- Prefers 3 high-quality sources over 5 mixed-quality ones.

**Good triggers**
```text
/b-research how do I configure retries in BullMQ?
/b-research what's the signature of Array.prototype.flatMap?
/b-research compare bullmq vs bee-queue for job queues
/b-research best practices for webhook signature verification
tra cứu cách dùng thư viện Prisma
```

**Output**
- **Quick lookup**: concise 1–3 sentence answer with minimal example and source.
- **Research report**: structured report with summary, findings, optional comparison table, limitations, and cited sources.

**Key limits**
- Quick mode caps at 2 tool calls before escalating or answering.
- Default scrape cap in full mode: 3 URLs per session; 5 for COMPARE queries.
- Never fill factual gaps from training data in full mode when sources do not support them.

---

### b-debug

Systematic, hypothesis-driven debugging with full-loop execution by default.

**Core behavior**
- Uses supported Serena tools to map execution path, references, suspicious symbols, and file structure.
- If Serena is unavailable, falls back to Bash/Read with reduced cross-file confidence.
- Initializes Serena project knowledge with onboarding check before tracing when needed.
- Follows a strict read-order: find symbol → overview → references → native exact-string search/read only when needed → symbolic fix. Never jumps to full-file reads without narrowing first.
- Narrows with `get_symbols_overview` before opening source where possible.
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
- Uses supported Serena tools to prioritize review depth by changed symbols, references, and affected files.
- Initializes Serena project knowledge with onboarding check before reviewing changed symbols when needed.
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

### b-test

Test-driven development, test debugging, and test coverage evaluation.

**Core behavior**
- Discovers test files and framework via Bash, then inspects structure with Serena symbol tools.
- For failing tests: reads test + source, identifies assertion/mock/setup/async issue.
- For new tests: maps source symbols, lists branches and edge cases, and adds tests in existing files or creates a new test file with supported repo tools when needed.
- Runs tests via Bash after every change to confirm fix or coverage improvement.
- Distinguishes test-specific failures from runtime bugs (test failure != production bug).
- Uses `sequentialthinking` for test strategy only when unit vs integration is ambiguous.

**Branches**
- **Write tests**: map source symbol → list edge cases → write behavior tests → run suite
- **Fix failing test**: read error → inspect test + source → identify gap → fix → re-run
- **Evaluate coverage**: run coverage report → identify uncovered branches → write tests

**Good triggers**
```text
/b-test write tests for the auth module
/b-test fix failing login test
/b-test evaluate coverage for the API layer
```

**Output**
```
Test type → Test structure → Issue/Requirements → Fix/Implementation → Verification
```

**Key rules**
- Never modify production code to make a test pass unless the production code is actually buggy.
- Write behavior tests (assert on output), not implementation tests (assert on internal state).
- Keep test fixes minimal — one assertion at a time.

---

### b-lookup

Legacy compatibility alias for `b-research` quick mode.

**Core behavior**
- Hidden from normal invocation and not auto-triggered.
- Exists only so older habits or explicit `/b-lookup` calls still work.
- Uses the same quick-mode behavior as `b-research`: Context7 first for library questions, one Brave fallback, no scraping.
- Carries its own minimal tool contract and graceful-degradation behavior, but remains compatibility-only.
- If the answer needs multiple sources or page reads, escalate to `b-research` full mode.

**Recommended entry point**: use `/b-research` for both quick lookups and deep research.

**Good triggers**
```text
/b-lookup what's the signature of Array.prototype.flatMap?
/b-lookup config key for retry in BullMQ
/b-lookup does Prisma support native upsert?
```

**Output**
```
Library — topic
[1–3 sentence answer]
Example:
```lang
// minimal code
```
Source: Context7(library-id) / Brave Search
```

**Key rules**
- Do not auto-invoke this skill.
- Do not present this as the preferred user-facing choice.
- Never scrape or crawl here; escalate to /b-research full mode if needed.
- Output stays in the same quick-answer format as b-research quick mode.

---

### b-refactor

Code refactoring with impact analysis and safe mechanical transformation.

**Core behavior**
- Maps full impact radius with find_referencing_symbols before touching any code.
- Requires green test baseline before refactoring — warns if tests are already failing.
- Uses Serena's symbol-aware tools (rename_symbol, safe_delete_symbol, replace_symbol_body) for cross-file safe edits.
- Executes in dependency order (inner helpers first, outer callers last).
- Verifies after every step: compilation → tests → git diff.
- For large refactors (>3 files or crossing package boundaries): uses sequentialthinking to plan phases.

**Transformations supported**
- Rename symbol/file/directory
- Extract method/function
- Inline variable/function
- Move code between files
- Delete dead code
- Split large function

**Good triggers**
```text
/b-refactor rename UserService to UserRepository
/b-refactor extract validation logic from handleSubmit
/b-refactor delete the unused legacyAuth module
```

**Output**
```
Target → Impact → Risk → Transformation plan → Changes → Verification
```

**Key rules**
- Never refactor without a green test baseline.
- Always use find_referencing_symbols before renaming or deleting.
- Prefer rename_symbol over manual Edit for renames — it updates all references atomically.
- Prefer safe_delete_symbol over manual deletion — it prevents accidental removal of still-used code.
- Run compilation check after every mechanical step.
- One commit per logical transformation.

---

## Usage patterns

### Standard feature flow
```
1. /b-plan [task]
2. Approve the quick chat plan or full saved plan
3. Implement from the approved plan/protocol, step by step
4. Run the targeted checks from each step's "Done when"
5. /b-review [task]
6. commit
```

### Implementation protocol
```
1. Read the approved chat plan or .claude/b-plans/[task].md
2. Follow confirmed decisions and planned touch points
3. Execute steps in dependency order
4. Verify each step with its "Done when" check or the narrowest relevant test/typecheck
5. Stop and ask if a new product/behavior decision appears
6. Run /b-review for non-trivial changes before committing
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

- Invoke skills with `/` prefix: `/b-plan`, `/b-debug`, `/b-review`, `/b-research`, `/b-test`, `/b-refactor`
- Use explicit intent words: `plan`, `debug`, `review`, `research`, `lookup`, `test`, `refactor`
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

/b-test ──────────────── test fails ────────────► /b-debug (if failure reveals runtime bug)
        └──────────── coverage gap ─────────────► write tests → run suite

/b-refactor ───────────── rename/move/extract ──► /b-review (after transformation)
            └──────────── test fails ─────────────► /b-test or /b-debug

/b-research ──────────── quick lookup or full research, auto-routes internally
/b-lookup ────────────── legacy alias to /b-research quick mode
```
