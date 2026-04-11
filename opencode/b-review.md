---
name: b-review
description: Pre-PR code review — verify logic correctness, requirements fulfillment, edge case coverage, and test adequacy before opening a pull request. Use when user says "review before PR", "kiểm tra logic", or after b-gate passes.
mode: subagent
model: github-copilot/gpt-5.3-codex
---


# b-review

$ARGUMENTS

Review changed code from a reviewer's perspective before it becomes a PR. Checks logic
correctness, requirements coverage, edge cases, and test adequacy — the things automated
tooling cannot catch.

If `$ARGUMENTS` is provided, treat it as a pointer to the plan file or a description of
the original requirements (e.g. `add retry logic to email queue`). Use it as the
requirements baseline for Step 2.

## When to use

- After b-gate passes, before committing or opening a PR.
- User says "review before PR", "kiểm tra logic trước khi push", "what would a reviewer flag".
- Validating that the implementation actually fulfills the original requirements.
- Checking if test coverage is adequate for the behavior that was changed.

## When NOT to use

- Structural quality review (complexity, duplication, coupling) → use **b-analyze**
- Automated checks (lint, typecheck, tests, security) → use **b-gate**
- Something is broken → use **b-debug**
- Pre-implementation understanding → use **b-analyze**

## Tools required

- `Bash` — to read git diff and changed file list.
- `sequentialthinking` — from `sequential-thinking` MCP server — structured review reasoning.
- `resolve_repo`, `suggest_queries`, `get_ranked_context`, `get_changed_symbols`, `get_blast_radius`, `get_impact_preview`, `get_symbol_source`, `get_context_bundle` — from `jcodemunch` MCP server *(required when the repo is locally indexed or indexable; use fallback only if jcodemunch is unavailable or indexing fails)*
- `firecrawl_scrape` — from `firecrawl` MCP server *(optional, for fetching issue/ticket URL content when an `**Issue**:` URL is present in the plan file)*

If sequential-thinking is unavailable: reason through review dimensions inline, document each explicitly.
If jcodemunch is unavailable, or `index_folder` returns `file_count = 0` or `is_stale: true`: use Read tool to inspect changed files directly and explicitly note that blast-radius / changed-symbol prioritization / transitive impact review were skipped. Always note: "⚠️ jcodemunch unavailable — blast-radius analysis unavailable."
If firecrawl is unavailable: skip Issue URL fetch; display ticket ID or URL as a context reference only.

Graceful degradation: ✅ Possible — core review works with Bash + Read. sequential-thinking improves structure of findings; jcodemunch improves symbol context; firecrawl enriches issue context. All optional.

## Steps

### Step 1 — Get the diff

Run:
```bash
git diff HEAD
```

If the output is empty: try `git diff --staged` (staged but not committed). If still empty: try `git diff HEAD~1 HEAD` (last commit). If still empty: ask the user — "No uncommitted, staged, or recent changes found. Which changes should I review? (Provide a commit hash, branch name, or describe the change.)" Do not proceed with an empty diff.

Extract:
- **Files changed**: list of modified, added, deleted files.
- **Changed lines**: what was added (+) and removed (-)
- **Scope**: how wide is the change? (1 file vs 10 files is a different review depth)

If the diff is large (>500 lines changed), ask the user which area to focus on first rather than reviewing everything at once.

---

### Step 2 — Establish requirements baseline

**Small-change fast path** — check diff scope from Step 1 first:
- If diff is **≤50 lines AND ≤2 files** → small-change mode: accept any non-empty requirements baseline (one sentence is sufficient). Skip the vague-response enforcement loop below. Proceed directly with whatever context the user provides.
- If diff is **>50 lines OR >2 files** → full enforcement applies (continue with the standard process below).

Determine what the code was *supposed* to do:

1. **Check for plan file** — look for `.opencode/b-plans/[task-slug].md`. If found, read the `## Steps` section and the original scope statement. This is the primary requirements source.

   1b. **Issue enrichment** *(runs only when a plan file was found in step 1)*: scan the plan file header for an `**Issue**:` field.
   - If the value starts with `http`: call `firecrawl_scrape` with `url=[value]` and `formats: ["markdown"]`. Trim the result to 500 words and append to the requirements baseline as: `**Issue context** (from [URL]):
[scraped content]`. If the scrape returns <200 characters or an HTTP auth/403 error: skip silently and note in output: "Issue URL requires authentication — using URL as context reference only: [value]."
   - If the value is a ticket ID (does not start with `http`): display it in the review output header as: `**Issue reference**: [value]`. No fetch attempted.
   - If the `**Issue**:` field is absent or empty: skip this sub-step entirely.

2. **Check $ARGUMENTS** — if provided:
   - If `$ARGUMENTS` ends in `.md` → use `Read` to verify the file exists. If it exists, treat it as the primary requirements source (same as a plan file found in `.opencode/b-plans/`).
   - If `$ARGUMENTS` does not end in `.md` → treat it as a text description of requirements.
3. **Ask the user** — if neither is available, ask: "What was this change supposed to accomplish? What does 'done' look like?" Initial ask, then one re-prompt if vague — two questions maximum.

**Vague response enforcement**: if the user's answer is fewer than 2 sentences or lacks specific behavior or acceptance criteria, ask once more with a concrete example prompt:
> "Please be more specific. For example: 'The retry logic should attempt 3 times with exponential backoff, and log each failure. It should not retry on 4xx errors.' What specific behavior should this code exhibit, and how would you verify it works?"

If the response is still vague after the second prompt, pause with:
> "Cannot review without a clear requirements baseline. Please answer: What specific behavior should the changed code exhibit, and how would you verify it works?"
Do not proceed to Step 3 until a concrete answer is provided.

The review is only as good as the requirements baseline. Do not review without it.

---

### Step 3 — Logic correctness review

Run the standard jcodemunch preflight (see `global/AGENTS.md § jcodemunch preflight`) with query = "[diff scope + requirements baseline summary]". Then call `get_changed_symbols` to map the diff to named symbols, `get_blast_radius` on the top changed symbols to understand downstream impact, and `get_impact_preview` when a changed symbol sits on a service boundary or shared helper. Use the returned context as the primary review read set. If jcodemunch is unavailable, or `index_folder` returns `file_count = 0` or `is_stale: true`, fall back to direct Read on changed files. Always note: "⚠️ jcodemunch unavailable — blast-radius analysis unavailable."

**Impact-first review rule**: when `get_changed_symbols` returns named symbols, prioritize review depth on (a) symbols with the largest blast radius, (b) symbols at service boundaries, and (c) symbols implementing explicit requirements from Step 2. Raw line-count alone should not determine review depth.

Read the changed code (use `get_symbol_source` or Read tool) and check:

**Control flow**
- Are all branches of conditionals handled? (if/else, switch cases, error paths)
- Are there unreachable branches or always-true conditions?
- Are loops bounded? Can they run forever?

**Data handling**
- Are null/undefined/empty inputs handled?
- Are type coercions or implicit conversions safe?
- Are array/object accesses guarded against out-of-bounds or missing keys?

**Async correctness** *(if applicable)*
- Are all async paths awaited?
- Are errors from async operations caught?
- Are there race conditions between parallel operations?

**Side effects**
- Does the code modify shared state unexpectedly?
- Are there unintended writes to external systems (DB, cache, queue) in non-obvious paths?

**Security review**

**Always check** (no fast-path exception):
- **Injection vectors** — is dynamic SQL, shell commands, or HTML constructed with unsanitized input? Check every user-facing input path regardless of diff size.

**Skip if diff ≤50 lines AND ≤2 files** (fast-path threshold — same as Step 2):
1. **Auth/authz** — do new endpoints or handlers require authentication? Is it enforced? Are role/permission checks correct?
2. **Input validation** — is untrusted input sanitized before use in DB queries, filesystem paths, or `eval`/exec calls?
3. **Sensitive data** — are passwords, tokens, or PII logged or returned in responses where they should not be?
4. **Rate limiting** — do new publicly accessible endpoints have rate limiting in place?

For each issue found: state the file, line range, what the problem is, and what the correct behavior should be.

---

### Step 4 — Requirements coverage check

Map each requirement from Step 2 against the changed code:

| Requirement | Covered? | Where |
|---|---|---|
| [Requirement 1] | ✅ / ❌ / ⚠️ Partial | [file:line or "not found"] |

**✅ Covered**: code explicitly implements this behavior
**❌ Missing**: no code implements this requirement
**⚠️ Partial**: partially implemented — describe what's missing

Flag any requirement that is ❌ or ⚠️ as a blocker before PR.

---

### Step 5 — Edge case and test adequacy check

**Edge cases to check** (based on the type of change):
- Empty input, zero values, negative numbers.
- Maximum/minimum boundary values.
- Concurrent or repeated invocations.
- Failure of downstream dependencies (DB down, API timeout)
- Unexpected input types.

**Test adequacy check**:
- Does a test exist for each requirement from Step 2?
- Do tests cover the unhappy path (errors, empty results, invalid input)?
- Are tests testing behavior or implementation details? (behavior tests survive refactors; implementation tests don't)
- Is there a test that would catch a regression if this code was accidentally reverted?

If tests are missing for a requirement or critical edge case: flag as a finding, not just a suggestion.

---

### Step 5.5 — Observability check *(conditional)*

**Skip entirely if**: diff is ≤50 lines AND ≤2 files (same fast-path threshold as Step 2).

**Skip entirely if**: the diff does not add new endpoints, route handlers, background jobs, or queue consumers. If the change only modifies existing behavior or is a pure fix, skip this step.

**When triggered** — check *changed code only* for minimum instrumentation:

1. **Entry-point logging** — is there at least one structured log call at the handler entry point? (e.g. `logger.info(...)`, `log.Printf(...)`, structured JSON log.) A single log at entry is sufficient; this is not a coverage audit.
2. **Error capture** — are errors caught and logged or re-raised? Check for try/catch/except blocks that swallow errors silently (no log, no re-raise). A swallowed error is an observability black hole.
3. **Metric emission** — if the new code implies a metric (new endpoint → request count/latency, new background job → job duration/success rate), is a metric emitted? This check is advisory — flag missing metrics as a suggestion, not a blocker.

**Note**: this is not a full observability audit — only minimum instrumentation on new code. For a complete instrumentation review → run `b-observe` separately.

**Handoff rule**: if Step 5.5 finds missing entry logs, swallowed errors, or broader instrumentation uncertainty in newly added handlers/endpoints/jobs, end the review with an explicit follow-up suggestion: `run b-observe: [changed module or entry-point scope]` for a full observability audit. Use this as a suggestion when the gap is non-blocking, or as part of NEEDS FIXES when the gap leaves a new critical path effectively opaque.

---

### Step 6 — Use sequential-thinking to consolidate

Call `sequentialthinking` with:
> "Given these review findings [list from Steps 3–5.5], which issues must be fixed before this PR can be merged, which are suggestions, and what specific question would a senior engineer ask about this code?"

Use the output to produce the final report.

---

## Output format

```
### b-review: [task / PR title]

**Diff scope**: [N files changed, +X -Y lines]
**Requirements baseline**: [plan file / $ARGUMENTS / user-stated]

---

#### Logic correctness
✅ No issues found
— or —
❌ [Issue]: [file:line] — [what's wrong] → [what it should do]

---

#### Requirements coverage
| Requirement | Status | Notes |
|---|---|---|
| [req] | ✅ / ❌ / ⚠️ | [detail] |

---

#### Edge cases & test adequacy
✅ Covered
— or —
⚠️ Missing test: [behavior] — [why it matters]
❌ Missing test: [critical behavior] — [risk if untested]

---

#### Observability
*(skipped — diff ≤50 lines / ≤2 files, or no new handlers/endpoints/jobs)*
— or —
✅ Entry-point logging present, errors captured
⚠️ [issue]: [file:line] — [missing instrumentation] → [suggestion]

---

#### Reviewer questions
> [Question a senior engineer would ask about this code]

---

#### Verdict
**[READY FOR PR / NEEDS FIXES]**

Blockers (must fix before PR):
- [item]

Suggestions (non-blocking):
- [item]
- [If observability follow-up is warranted] Run `b-observe: [scope]` for a full instrumentation audit.
```

---

## Rules

- Never review without a requirements baseline — a review without knowing what was intended produces noise, not signal.
- Blocker = anything that would cause a reviewer to request changes before merge.
- Suggestion = improvement that does not block correctness or requirement fulfillment.
- Do not re-run automated checks (lint, tests) — b-gate owns that; b-review owns human judgment.
- If the review uncovers observability uncertainty on new entry points, recommend `b-observe` explicitly instead of stretching b-review into a full instrumentation audit.
- If logic is too complex to understand without running it, say so — do not guess.
- Keep the diff scope in mind: a 3-line fix needs a lighter review than a 200-line feature.
- If requirements are not fulfillable with the current implementation, state clearly: "Requirement X is not met — the implementation does Y instead of Z".
- Never trigger destructive git commands — no `git push`, `git pull`, `git commit`, `git reset`, `git revert`, `git clean -f`, `git checkout -- <file>`, or `git branch -D`. If a commit is needed after completing work, delegate to b-commit.
