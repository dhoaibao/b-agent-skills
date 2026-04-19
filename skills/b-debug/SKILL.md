---
name: b-debug
description: >
  Systematic hypothesis-driven debugging — trace execution paths, form ranked hypotheses,
  confirm root cause, then fix and verify by default. Use when the user says "debug", "bug",
  "lỗi", "không chạy", "fix this", or pastes an error message.
  Unlike b-plan (decide approach) or b-research (lookup info), b-debug traces, confirms, and
  fixes broken code.
effort: high
---

# b-debug

$ARGUMENTS

Systematic, hypothesis-driven bug tracing: understand code structure first, form
ranked hypotheses, locate root cause, then fix and verify. Never jump straight to patching.

Default contract: when invoked, `b-debug` must complete the full loop
**trace → confirm root cause → fix → verify** unless the user explicitly asks for
diagnosis-only, root-cause-only, or investigation-only output.
Do not stop after reporting the cause if a safe, minimal fix is available.

If `$ARGUMENTS` is provided, treat it as the error message or symptom — skip asking for symptoms in Step 1 and proceed directly with what was given.
If `$ARGUMENTS` explicitly limits scope to investigation-only, honor that limit and stop after Step 4.

## When to use

- User pastes an error message or stack trace.
- Something "should work" but doesn't, with no clear error.
- Bug appears in one place but root cause may be elsewhere (middleware, config, async)
- Previous fix attempts didn't work.
- User says: "debug", "lỗi", "tại sao", "không hoạt động", "fix bug", "why is X not working".

## When NOT to use

- Building a new feature or multi-file change → use **b-plan**
- Need library API details before writing code → use **b-research**

## Tools required

From `serena` MCP server:
- `activate_project` — activate the current project before tracing code.
- `check_onboarding_performed` / `onboarding` — initialize project knowledge when needed.
- `find_symbol` — locate the entry point or suspicious symbol.
- `get_symbols_overview` — inspect file structure before opening bodies.
- `find_referencing_symbols` — trace callers/usages of a function or class.
- `search_for_pattern` — search for exact error strings or suspicious patterns across the codebase.
- `read_file` — inspect the exact file chunk when symbolic tools are insufficient.
- `replace_symbol_body`, `replace_content`, `insert_before_symbol`, `insert_after_symbol`, `rename_symbol` — apply the minimal fix once root cause is confirmed.

From `sequential-thinking` MCP server:
- `sequentialthinking` — structured reasoning to form and rank hypotheses.

From `context7` MCP server *(optional)*:
- `resolve-library-id` + `query-docs` — verify correct library API behavior when a hypothesis points to API misuse or version mismatch. Faster than invoking full /b-research for a single API question.

From `brave-search` MCP server *(optional)*:
- `brave_web_search` — look up known library errors, GitHub issues, changelogs.

From `firecrawl` MCP server *(optional)*:
- `firecrawl_scrape` — scrape full content of relevant GitHub issue pages, Stack Overflow answers, or changelogs found via web search.
- `firecrawl_map` — map all URLs on a site when `firecrawl_scrape` returns empty content (JS-rendered or incorrect URL); use to discover the correct URL before retrying scrape.

If Serena is unavailable: use Glob/Grep/Read to map files manually, proceed with Steps 2.1–2.4. Always note: "⚠️ Serena unavailable — analysis based on Glob/Grep/Read; cross-file tracking incomplete."
If sequential-thinking is unavailable: reason through hypotheses inline, document steps explicitly in response. Format fallback as: `Hypothesis N → Evidence for → Evidence against → Cheapest verification → Confirmed/Rejected`.
If context7 is unavailable: invoke /b-research for library API questions instead.

Graceful degradation: ✅ Possible — if Serena unavailable, use Glob/Grep/Read for file analysis. Quality is reduced but the skill remains functional.

## Steps

### Step 1 — Gather symptoms

Before touching any code, collect:

- **Error message / stack trace**: exact text, not paraphrased.
- **Expected behavior**: what should happen.
- **Actual behavior**: what actually happens.
- **Reproduction**: consistent or intermittent? Under what conditions?
- **Recent changes**: anything changed before the bug appeared?

If any of these are missing, ask the user before proceeding. A missing "expected behavior"
or "recent changes" is often the fastest path to root cause.

---

### Step 2 — Map the code structure

> **Session optimization**: If Serena has already activated the current project in this session, reuse that project context — but confirm you are still in the correct workspace before tracing further.

Use `serena` to trace the execution path in this order:

0. **Serena preflight** — activate the current project. If onboarding has not been performed, call `onboarding` before tracing. Reuse existing project context if already activated in this session, but confirm the workspace is still correct.
1. `find_symbol` on the chosen entry point (route handler, CLI command, event listener) — locate the best starting symbol.
2. `get_symbols_overview` on the relevant file — confirm which symbols are worth reading.
3. `find_referencing_symbols` on the relevant function — trace callers/usages across files.
4. `search_for_pattern` on the error string, config key, or suspicious behavior — expose parallel failure points faster than manual tracing.
5. `read_file` on any function or file section that still looks suspicious — inspect the exact implementation.

**Read-order rule**: never jump to `read_file` before completing steps 1–4. Narrowing with symbols and references first typically eliminates 80% of what you'd get from a full-file read — and it's more accurate.

From this, identify:
- All layers the request/data passes through (middleware, validators, handlers, services, DB)
- Any async boundaries, error handlers, or silent failure points (try/catch that swallows errors, `.catch(() => {})`)
- Hidden choke points: auth middleware, rate limiters, interceptors, event listeners.

**Goal**: understand the full execution path, not just the file where the error surfaces.
The bug is often one layer above or below where it appears.

---

### Step 3 — Form hypotheses

Use `sequential-thinking` to reason through possible causes:

- Generate 3–5 hypotheses ranked by likelihood.
- For each hypothesis, state: *what would cause this symptom* and *how to verify it*
- For each hypothesis, also state: *evidence for*, *evidence against*, and *cheapest verification step*.
- Bias toward the simplest explanation first (Occam's razor)
- Common categories to consider:
  - **Wrong layer**: error surfaces in A but is caused by B upstream
  - **Silent failure**: exception caught and swallowed without logging
  - **State/order issue**: async race, middleware order, initialization timing
  - **Config/env**: wrong env var, missing secret, wrong port/host
  - **Version mismatch**: library API changed between versions
  - **Data shape**: unexpected null, wrong type, missing field

Present the ranked hypotheses to the user briefly before investigating.

Do **not** call `sequentialthinking` if the stack trace or code path already identifies one clear root cause with no meaningful competing hypothesis.

**Library error shortcut**: If the error message or stack trace references a specific library or framework:
- Use `brave_web_search` with the exact error message in quotes to find known issues, GitHub issues, or changelog entries.
- If results include a GitHub issue page, Stack Overflow answer, or changelog URL that looks relevant → call `firecrawl_scrape` on the top 1–2 most relevant URLs before verifying hypotheses. Use `formats: ["markdown"]`. Cap at 2 URLs. If the page returns empty or <200 words → call `firecrawl_map` on the domain root to find the correct URL, then retry scrape on the mapped URL. If still empty, proceed with snippets only.
- If results point to an API misuse → call `resolve-library-id` + `query-docs` with the specific method/behavior in question. This is faster than /b-research for a single API question. Escalate to /b-research only if context7 has no index for the library.
- Do this before verifying hypotheses — it may eliminate wrong hypotheses immediately and save significant time.

**Error string search**: If the error message text is short and specific → call `search_for_pattern` with the exact error string to find all places in the codebase that produce or handle this error. This often reveals the true origin faster than tracing the call graph.

---

### Step 4 — Verify root cause

Test hypotheses starting from the most likely:

- Add targeted logging at the suspected choke point (not scattered everywhere)
- Check config/env values if hypothesis points there.
- Use `get_symbols_overview` first when narrowing within a large file; then `read_file` to re-examine the exact suspicious function.
- Use `find_referencing_symbols` or `search_for_pattern` when the bug pattern may exist in multiple places.
- If the hypothesis points to library API misuse: call `resolve-library-id` + `query-docs` directly to verify the correct method signature, parameter order, or behavior. Escalate to /b-research only if context7 has no index.
- **Regression detection**: if the bug appeared after a recent change, compare the current symbol/file content against the recent git diff before changing code.

**Dynamic verification** — if static analysis is insufficient to confirm root cause (plausible hypothesis but not provable from code alone):

1. Add one or two targeted log statements at the suspected choke point — not scattered across files.
2. Instruct the user to run the failing scenario and paste the output.
3. Analyze the output: does it confirm or eliminate the hypothesis?
4. If confirmed → proceed to Step 5 (Fix). If eliminated → mark hypothesis as ruled out, advance to the next ranked hypothesis, restart from sub-step 1.
5. After root cause is confirmed, remove all debug logging added during this loop.

Cap at **3 iterations** — if root cause is not confirmed after 3 instrumentation rounds, surface current evidence to the user:

> "Root cause unconfirmed after 3 instrumentation rounds — here's what we know: [evidence gathered]. Consider: adding APM/profiler, reproducing in isolation, or escalating."

**Stop when root cause is confirmed** — don't continue investigating other hypotheses once found.

State clearly: *"Root cause: [X] because [Y]"* before writing any fix.

---

### Step 5 — Fix

Now that root cause is confirmed, the default behavior is to implement the minimal safe fix immediately — not to hand the fix back to the caller as a separate follow-up.

- Write the minimal fix — don't refactor unrelated code in the same change.
- Prefer Serena symbolic edits in this order: `replace_symbol_body` → `insert_before_symbol` / `insert_after_symbol` → `rename_symbol`; use `replace_content` only when symbolic edits cannot express the exact patch safely.
- If the fix touches a non-obvious API or behavior, add a comment explaining why.
- If the bug reveals a broader pattern (e.g. same silent-catch pattern exists in 3 other places), flag it to the user as a separate follow-up — don't fix everything at once.
- After applying the fix, keep the change scoped to the confirmed symbol/file only.

---

### Step 6 — Verify fix

After applying the fix:

- State what behavior should now change and how to confirm it.
- **Detect test command** from the project: check `package.json` scripts, `pytest.ini`, `Makefile`, `Cargo.toml`, or equivalent. Suggest the specific command scoped to the affected module — e.g. `npm test -- --testPathPattern=auth`, `pytest tests/test_auth.py`, `go test ./internal/auth/...`. Do not just say "run your tests".
- If the fix involved a config/env change, remind the user to restart the process.
- If the fix changed more than 2 files or introduced new functions/modules → suggest running `/b-review` before committing to catch any logic or requirements gaps the fix may have introduced.
- Do not end at "root cause found". Close the loop by stating the applied fix and the exact verification step unless the caller explicitly requested diagnosis-only mode.

---

## Output format

```
### Debug report: [short description of bug]

**Symptoms**
- Error: `[exact error or "no error — silent failure"]`
- Expected: ...
- Actual: ...

**Code path** *(from [Serena / manual analysis])*
[Entry point] → [Layer 1] → [Layer 2] → [Failure point]
Note any silent catch blocks or unexpected stops in the path.

**Hypotheses** *(ranked)*
1. [Most likely] — [how to verify]
2. ...
3. ...

**Root cause**
[Confirmed cause — one clear sentence]

**Fix**
\`\`\`[lang]
// the fix
\`\`\`

**Verification result / Verify by**: [what was checked, or exact steps to confirm it works]
```

---

## Rules

- Never patch before confirming root cause — a wrong fix wastes time and introduces new bugs.
- Default to full execution: trace → confirm root cause → fix → verify. Only stop at diagnosis when the caller explicitly requests that narrower scope.
- Always map the full execution path first — the bug is often not where it surfaces.
- If 2+ hypotheses seem equally likely, verify the cheaper one first.
- Silent failure points (swallowed exceptions, missing logs) are the most common cause of "no error but not working" bugs — check these first.
- If the fix requires understanding a library's behavior: use context7 first (`resolve-library-id` + `query-docs`); escalate to /b-research only if context7 has no index for that library.
- Keep fixes minimal — one bug, one fix.
- Never trigger destructive git commands — no `git push`, `git pull`, `git commit`, `git reset`, `git revert`, `git clean -f`, or `git checkout -- <file>`.
