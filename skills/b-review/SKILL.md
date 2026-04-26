---
name: b-review
description: >
  Pre-PR code review — verify logic correctness, requirements fulfillment, edge case coverage,
  and test adequacy before opening a pull request. Use when the user says "review before PR",
  "kiểm tra logic", or after implementation is done.
  Unlike b-debug (fix broken) or b-research (lookup info), b-review validates what was built
  against what was intended.
effort: medium
---

# b-review

$ARGUMENTS

Review changed code from a reviewer's perspective before it becomes a PR. Checks logic
correctness, requirements coverage, edge cases, and test adequacy — the things automated
tooling cannot catch.

If `$ARGUMENTS` is provided, parse flags first, then treat the remainder as a pointer to the plan file or a description of the original requirements (e.g. `add retry logic to email queue`). Use it as the requirements baseline for Step 2.

**Flags** (strip before processing requirements baseline):
- `--skip-test` — skip the **Test adequacy check** sub-section in Step 5 and skip Step 5.5 entirely. Focus on code review, logic correctness, requirements coverage, and edge cases only.

## When to use

- After implementation is done, before committing or opening a PR.
- User says "review before PR", "kiểm tra logic trước khi push", "what would a reviewer flag".
- Validating that the implementation actually fulfills the original requirements.
- Checking if test coverage is adequate for the behavior that was changed.

## When NOT to use

- Something is broken → use **b-debug**
- Need library API details before writing code → use **b-research**

## Tools required

- `Bash` — to read git diff and changed file list.
- `sequentialthinking` — from `sequential-thinking` MCP server — structured review reasoning.
- `check_onboarding_performed`, `onboarding`, `find_symbol`, `get_symbols_overview`, `find_referencing_symbols` — from `serena` MCP server *(preferred for symbol-aware review; use native Read/Bash search for unsupported file and exact-string operations)*
- `firecrawl_scrape` — from `firecrawl` MCP server *(optional, for fetching issue/ticket URL content when an `**Issue**:` URL is present in the plan file)*
- `resolve-library-id` + `query-docs` — from `context7` MCP server *(optional, for verifying library API calls in changed code — catches wrong method signatures, deprecated APIs, misused parameters)*
- `brave_web_search` — from `brave-search` MCP server *(optional, for CVE/known-vulnerability lookup when a risky security pattern is found in changed code)*

If sequential-thinking is unavailable: reason through review dimensions inline, document each explicitly. Format fallback as: `Finding → Severity → Why blocker/not blocker → Suggested action`.
If Serena is unavailable: use Read tool to inspect changed files directly. Note: "⚠️ Serena unavailable — symbol-aware impact analysis unavailable."
If firecrawl is unavailable: skip Issue URL fetch; display ticket ID or URL as a context reference only.
If context7 is unavailable: skip API verification step; note any suspicious library calls manually.
If brave-search is unavailable: skip CVE lookup; flag the pattern as a manual security review item.

Graceful degradation: ✅ Possible — core review works with Bash + Read. Each MCP adds a specific review dimension; none is strictly required.

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

1. **Check for plan file** — look for `.claude/b-plans/[task-slug].md`. If found, read the `## Steps` section and the original scope statement. This is the primary requirements source.

   1b. **Issue enrichment** *(runs only when a plan file was found in step 1)*: scan the plan file header for an `**Issue**:` field.
    - If the value starts with `http`: call `firecrawl_scrape` with `url=[value]` and `formats: ["markdown"]`. Trim the result to 500 words and append to the requirements baseline as: `**Issue context** (from [URL]):
[scraped content]`. If the scrape returns <200 characters or an HTTP auth/403 error: skip silently and note in output: "Issue URL requires authentication — using URL as context reference only: [value]."
    - If the value is a ticket ID (does not start with `http`): display it in the review output header as: `**Issue reference**: [value]`. No fetch attempted.
    - If the `**Issue**:` field is absent or empty: skip this sub-step entirely.

2. **Check $ARGUMENTS** — if provided:
   - If `$ARGUMENTS` ends in `.md` → use `Read` to verify the file exists. If it exists, treat it as the primary requirements source (same as a plan file found in `.claude/b-plans/`).
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

Initialize Serena project knowledge first: call `check_onboarding_performed`; if onboarding has not been performed, run `onboarding`. Then follow this exact read-order — never jump straight from `git diff` to full-file reads for code-symbol changes:

1. `find_symbol` on changed names — map them to real symbols in the codebase.
2. `find_referencing_symbols` on top changed symbols — understand downstream impact.
3. `get_symbols_overview` on changed files before opening source — inspect structure first.
4. Native `Read` only for the highest-risk symbol bodies or file sections — narrow reads, not full files.
5. Native Bash search when the diff changes a shared helper, exported boundary, exact string, config key, or repeated pattern.

If Serena is unavailable: use `Read` tool to inspect changed files directly. Always note: "⚠️ Serena unavailable — symbol-aware impact analysis unavailable."

**Impact-first review rule**: prioritize review depth on (a) symbols with the broadest references, (b) symbols at service boundaries, and (c) symbols implementing explicit requirements from Step 2. Raw line-count alone should not determine review depth.

Read the changed code (prefer `get_symbols_overview` → targeted native `Read`; use full-file Read only as fallback) and check:

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

**Library API correctness** *(when changed code calls external libraries)*
- Identify third-party library calls in the diff (SDK methods, ORM queries, queue clients, HTTP clients). Skip stdlib calls (`JSON.parse`, `Array.map`, etc.).
- Pick the **top 2–3 most suspicious calls**: prioritize (a) unfamiliar or less common libraries, (b) calls with complex parameter patterns, (c) anything involving auth, crypto, or serialization.
- For each selected call: `resolve-library-id` + `query-docs` with the specific method to verify signature, parameter order, required fields, and deprecation status.
- Flag if: wrong parameter order, deprecated method, missing required field, or behavior differs from what the code assumes.
- Cap at 3 context7 calls per review — don't verify every import.

**Security review**

**Always check** (no fast-path exception):
- **Injection vectors** — is dynamic SQL, shell commands, or HTML constructed with unsanitized input? Check every user-facing input path regardless of diff size.
- **CVE lookup** — if an injection vector or known-risky pattern is found (e.g. `eval`, `exec`, `deserialize`, raw SQL concatenation, `innerHTML`): call `brave_web_search` with `"[pattern or library] CVE [year]"` to check for known vulnerabilities. Cap at 1 search query. Add findings to the security section.

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

**Test adequacy check** *(skip if `--skip-test` was passed)*:
- Does a test exist for each requirement from Step 2?
- Do tests cover the unhappy path (errors, empty results, invalid input)?
- Are tests testing behavior or implementation details? (behavior tests survive refactors; implementation tests don't)
- Is there a test that would catch a regression if this code was accidentally reverted?

If tests are missing for a requirement or critical edge case: flag as a finding, not just a suggestion.

---

### Step 5.5 — Observability check *(conditional)*

**Skip entirely if**: `--skip-test` was passed.

**Skip entirely if**: diff is ≤50 lines AND ≤2 files (same fast-path threshold as Step 2).

**Skip entirely if**: the diff does not add new endpoints, route handlers, background jobs, or queue consumers.

**When triggered** — check *changed code only* for minimum instrumentation:

1. **Entry-point logging** — is there at least one structured log call at the handler entry point? A single log at entry is sufficient.
2. **Error capture** — are errors caught and logged or re-raised? Check for try/catch/except blocks that swallow errors silently (no log, no re-raise).
3. **Metric emission** — if the new code implies a metric (new endpoint → request count/latency), is a metric emitted? Advisory — flag as suggestion, not a blocker.

Flag any gaps as findings in the review output. Non-blocking gaps go under Suggestions; a new critical path left completely opaque goes under Blockers.

---

### Step 6 — Consolidate findings

**If Steps 3–5.5 found 3 or more issues**, or there is genuine ambiguity about which issues are blockers vs suggestions: call `sequentialthinking` with:
> "Given these review findings [list] and this blocker rubric [correctness, requirement miss, security risk, data loss, regression risk], classify each item into blocker, non-blocking risk, or suggestion; explain why; and give one senior-reviewer question."

**If fewer than 3 findings**, or all findings clearly classify as blocker/suggestion: consolidate inline without calling sequentialthinking — it adds no value when the classification is obvious.

Use the output (or inline reasoning) to produce the final report.

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
```

---

## Rules

- Never review without a requirements baseline — a review without knowing what was intended produces noise, not signal.
- Blocker = anything that would cause a reviewer to request changes before merge.
- Suggestion = improvement that does not block correctness or requirement fulfillment.
- Do not re-run automated checks (lint, tests) — those are the user's responsibility; b-review owns human judgment.
- If logic is too complex to understand without running it, say so — do not guess.
- Keep the diff scope in mind: a 3-line fix needs a lighter review than a 200-line feature.
- If requirements are not fulfillable with the current implementation, state clearly: "Requirement X is not met — the implementation does Y instead of Z".
- Never trigger destructive git commands — no `git push`, `git pull`, `git commit`, `git reset`, `git revert`, `git clean -f`, or `git checkout -- <file>`.
