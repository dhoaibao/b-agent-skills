---
name: b-debug
description: >
  Systematic hypothesis-driven debugging: trace execution paths, form ranked hypotheses, confirm root cause, then fix.
  ALWAYS use when the user says "debug", "tại sao lỗi này", "bug", "không chạy", "lỗi",
  "fix this", "why is X not working", "unexpected behavior", "không hoạt động",
  or when an error message is pasted. Never guess-and-patch — always trace systematically.
  Distinct from b-analyze: b-debug fixes confirmed breakages; b-analyze reviews healthy code quality.
model: sonnet
---

# b-debug

$ARGUMENTS

Systematic, hypothesis-driven bug tracing: understand code structure first, form
ranked hypotheses, locate root cause, then fix. Never jump straight to patching.

If `$ARGUMENTS` is provided, treat it as the error message or symptom — skip asking for symptoms in Step 1 and proceed directly with what was given.

## When to use

- User pastes an error message or stack trace.
- Something "should work" but doesn't, with no clear error.
- Bug appears in one place but root cause may be elsewhere (middleware, config, async)
- Previous fix attempts didn't work.
- User says: "debug", "lỗi", "tại sao", "không hoạt động", "fix bug", "why is X not working".

## When NOT to use

- Code works but could be better (quality, patterns, complexity) → use **b-analyze**
- Building a new feature or multi-file change → use **b-plan**
- Need to understand unfamiliar code before changes → use **b-analyze**

## Tools required

From `jcodemunch` MCP server:
- `suggest_queries` — auto-surface entry points and key symbols for unfamiliar codebases (use before Step 2 when codebase is new)
- `get_context_bundle` — get full context from an entry point (file or function)
- `find_references` — trace all callers and callees of a function.
- `get_blast_radius` — understand what depends on a suspected module.
- `get_symbol_source` — inspect a specific function or class in detail (supports single `symbol_id` or batch `symbol_ids[]`)
- `get_related_symbols` — discover functions closely associated with a suspicious symbol.
- `get_symbol_diff` — detect regressions by diffing a symbol between two indexed states.
- `search_text` — search for error strings or regex patterns across the codebase.
- `index_file` — re-index a single changed file after applying a fix (keeps jcodemunch index fresh for subsequent b-analyze calls)
- `get_session_stats` — from `jcodemunch` MCP server *(optional, for stale index detection — verify index freshness before mapping code structure)*

From `sequential-thinking` MCP server:
- `sequentialthinking` — structured reasoning to form and rank hypotheses.

From `brave-search` MCP server *(optional)*:
- `brave_web_search` — look up known library errors, GitHub issues, changelogs.

From `firecrawl` MCP server *(optional)*:
- `firecrawl_scrape` — scrape full content of relevant GitHub issue pages, Stack Overflow answers, or changelogs found via web search.
- `firecrawl_map` — map all URLs on a site when `firecrawl_scrape` returns empty content (JS-rendered or incorrect URL); use to discover the correct URL before retrying scrape.

If jcodemunch is unavailable, or `index_folder` returns `file_count = 0`: use Glob/Grep/Read to map files manually, proceed with Steps 2.1–2.4.
If sequential-thinking is unavailable: reason through hypotheses inline, document steps explicitly in response.

Graceful degradation: ✅ Possible — if jcodemunch unavailable, use Glob/Grep/Read for file analysis. Quality is reduced but the skill remains functional.

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

> **Session optimization**: If b-analyze has already run for the same codebase in this session, skip step 2.0 (index/resolve) and reuse the existing repo identifier — the jcodemunch index is still current. Proceed directly to `get_context_bundle` on the relevant entry point.

Use `jcodemunch` to trace the execution path in this order:

0. **Index or resolve** — first call `resolve_repo(path="/absolute/project/root")`. If it returns a repo identifier, use it directly (index already exists). If it returns no match, call `index_folder` with the absolute path to the project root and `use_ai_summaries: false`. Note the `repo` identifier from the response (format: `local/[name]-[hash]`) — pass this as `repo` to every subsequent jcodemunch call. If `file_count` is 0, jcodemunch can't parse this codebase → use Glob/Grep to map files manually instead.
   - **Stale index check** (only when `resolve_repo` returned an existing index — skip when `index_folder` was just called): call `get_session_stats(repo=[identifier])` and read the `files_indexed` count. Use `Glob("**/*.{ts,tsx,js,jsx,py,go,rs,java,rb,php,kt,swift}")` to count actual source files. If `|files_indexed − actual_count| / actual_count > 0.10` (more than 10% drift), call `index_folder` to re-index before proceeding — the index is stale and debug tracing will miss recently added or deleted files. If `get_session_stats` is unavailable or returns no file count metric, skip the check and note in output: "⚠️ Could not verify index freshness — analysis may miss recently added/deleted files."
0.5. **suggest_queries** — if the codebase is unfamiliar, call `suggest_queries` immediately after indexing. Use the output to identify entry points, key symbols, and language distribution before tracing the execution path.
1. `get_context_bundle` on the entry point (route handler, CLI command, event listener) — get full context of the starting point
2. `find_references` on the relevant function — trace all callers and callees across files
3. `get_blast_radius` on the suspected module — understand what depends on it
4. `get_symbol_source` on any function that looks suspicious — inspect its full implementation

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
- Bias toward the simplest explanation first (Occam's razor)
- Common categories to consider:
  - **Wrong layer**: error surfaces in A but is caused by B upstream
  - **Silent failure**: exception caught and swallowed without logging
  - **State/order issue**: async race, middleware order, initialization timing
  - **Config/env**: wrong env var, missing secret, wrong port/host
  - **Version mismatch**: library API changed between versions
  - **Data shape**: unexpected null, wrong type, missing field

Present the ranked hypotheses to the user briefly before investigating.

**Library error shortcut**: If the error message or stack trace references a specific library or framework:
- Use `brave_web_search` with the exact error message in quotes to find known issues, GitHub issues, or changelog entries.
- If results include a GitHub issue page, Stack Overflow answer, or changelog URL that looks relevant → call `firecrawl_scrape` on the top 1–2 most relevant URLs before verifying hypotheses. Use `formats: ["markdown"]`. Cap at 2 URLs. If the page returns empty or <200 words → call `firecrawl_map` on the domain root to find the correct URL, then retry scrape on the mapped URL. If still empty, proceed with snippets only.
- If results point to an API misuse, invoke `b-docs` to verify the correct behavior for that library version.
- Do this before verifying hypotheses — it may eliminate wrong hypotheses immediately and save significant time.

**Error string search**: If the error message text is short and specific → call `search_text(is_regex=false, pattern="[exact error string]")` to find all places in the codebase that produce or handle this error. This often reveals the true origin faster than tracing the call graph.

---

### Step 4 — Verify root cause

Test hypotheses starting from the most likely:

- Add targeted logging at the suspected choke point (not scattered everywhere)
- Check config/env values if hypothesis points there.
- Use `get_symbol_source` or `get_context_bundle` (jcodemunch) to re-examine a specific function if the call graph revealed something suspicious.
- Use `get_related_symbols` on a suspicious function to discover other functions with similar logic — useful when the bug pattern may exist in multiple places.
- If the codebase uses a library: invoke `b-docs` to verify the correct API behavior for that library version.
- **Regression detection**: if the bug appeared after a recent change, use `get_symbol_diff` to compare the current symbol against an older indexed state (requires two index snapshots)

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

Now that root cause is confirmed:

- Write the minimal fix — don't refactor unrelated code in the same change.
- If the fix touches a non-obvious API or behavior, add a comment explaining why.
- If the bug reveals a broader pattern (e.g. same silent-catch pattern exists in 3 other places), flag it to the user as a separate follow-up — don't fix everything at once.
- After applying the fix, call `index_file` on each changed file to keep the jcodemunch index fresh — this ensures any subsequent b-analyze call sees the current code, not the pre-fix state.

---

### Step 6 — Verify fix

After applying the fix:

- State what behavior should now change and how to confirm it.
- Suggest the minimal test to verify (a specific request, a unit test, a log line to check)
- If the fix involved a config/env change, remind the user to restart the process.
- If the fix introduced new code (new function, new module) → run **b-gate** on the changed files to validate lint, tests, and security before closing the bug. For structural review of the new code → run `b-analyze: [fixed module]` separately.

---

## Output format

```
### Debug report: [short description of bug]

**Symptoms**
- Error: `[exact error or "no error — silent failure"]`
- Expected: ...
- Actual: ...

**Code path** *(from [jcodemunch / manual analysis])*
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

**Verify by**: [how to confirm it works]
```

---

## Rules

- Never patch before confirming root cause — a wrong fix wastes time and introduces new bugs.
- Always map the full execution path first — the bug is often not where it surfaces.
- If 2+ hypotheses seem equally likely, verify the cheaper one first.
- Silent failure points (swallowed exceptions, missing logs) are the most common cause of "no error but not working" bugs — check these first.
- If the fix requires understanding a library's behavior, use `b-docs` to verify — don't assume.
- Keep fixes minimal — one bug, one fix.
- Never trigger destructive git commands — no `git push`, `git pull`, `git commit`, `git reset`, `git revert`, `git clean -f`, `git checkout -- <file>`, or `git branch -D`. If a commit is needed after completing work, delegate to b-commit.
