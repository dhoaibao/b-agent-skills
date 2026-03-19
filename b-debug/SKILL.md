---
name: b-debug
description: >
  Systematically trace and fix bugs using structured hypothesis-driven debugging.
  ALWAYS use this skill when the user says "debug", "tại sao lỗi này", "bug",
  "không chạy", "lỗi", "fix this", "why is X not working", "unexpected behavior",
  "không hoạt động", or when an error message is pasted into the conversation.
  Use this especially when the bug is non-obvious, spans multiple layers, or has
  no clear error message. Never guess-and-patch — always trace systematically.
---

# b-debug

Systematic, hypothesis-driven bug tracing: understand code structure first, form
ranked hypotheses, locate root cause, then fix. Never jump straight to patching.

## When to use

- User pastes an error message or stack trace
- Something "should work" but doesn't, with no clear error
- Bug appears in one place but root cause may be elsewhere (middleware, config, async)
- Previous fix attempts didn't work
- User says: "debug", "lỗi", "tại sao", "không hoạt động", "fix bug", "why is X not working"

## Tools required

From `jcodemunch` MCP server:
- `get_context_bundle` — get full context from an entry point (file or function)
- `find_references` — trace all callers and callees of a function
- `get_blast_radius` — understand what depends on a suspected module
- `get_symbol` — inspect a specific function or class in detail

From `sequential-thinking` MCP server:
- `sequentialthinking` — structured reasoning to form and rank hypotheses

From `brave-search` MCP server *(optional)*:
- `brave_web_search` — look up known library errors, GitHub issues, changelogs

From `firecrawl` MCP server *(optional)*:
- `firecrawl_scrape` — scrape full content of relevant GitHub issue pages, Stack Overflow answers, or changelogs found via web search

If jcodemunch is unavailable, or `index_folder` returns `file_count = 0`: use Glob/Grep/Read to map files manually, proceed with Steps 2.1–2.4.
If sequential-thinking is unavailable: reason through hypotheses inline, document steps explicitly in response.

Graceful degradation: ✅ Possible — if jcodemunch unavailable, use Glob/Grep/Read for file analysis. Quality is reduced but the skill remains functional.

---

## Steps

### Step 1 — Gather symptoms

Before touching any code, collect:

- **Error message / stack trace**: exact text, not paraphrased
- **Expected behavior**: what should happen
- **Actual behavior**: what actually happens
- **Reproduction**: consistent or intermittent? Under what conditions?
- **Recent changes**: anything changed before the bug appeared?

If any of these are missing, ask the user before proceeding. A missing "expected behavior"
or "recent changes" is often the fastest path to root cause.

---

### Step 2 — Map the code structure

Use `jcodemunch` to trace the execution path in this order:

0. **Index first** — call `index_folder` with the absolute path to the project root. Use `use_ai_summaries: false` for speed. Note the `repo` identifier from the response (format: `local/[name]-[hash]`) — pass this as `repo` to every subsequent jcodemunch call. If `file_count` is 0, jcodemunch can't parse this codebase → use Glob/Grep to map files manually instead.
1. `get_context_bundle` on the entry point (route handler, CLI command, event listener) — get full context of the starting point
2. `find_references` on the relevant function — trace all callers and callees across files
3. `get_blast_radius` on the suspected module — understand what depends on it
4. `get_symbol` on any function that looks suspicious — inspect its full implementation

From this, identify:
- All layers the request/data passes through (middleware, validators, handlers, services, DB)
- Any async boundaries, error handlers, or silent failure points (try/catch that swallows errors, `.catch(() => {})`)
- Hidden choke points: auth middleware, rate limiters, interceptors, event listeners

**Goal**: understand the full execution path, not just the file where the error surfaces.
The bug is often one layer above or below where it appears.

---

### Step 3 — Form hypotheses

Use `sequential-thinking` to reason through possible causes:

- Generate 3–5 hypotheses ranked by likelihood
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
- Use `brave_web_search` with the exact error message in quotes to find known issues, GitHub issues, or changelog entries
- If results include a GitHub issue page, Stack Overflow answer, or changelog URL that looks relevant → call `firecrawl_scrape` on the top 1–2 most relevant URLs before verifying hypotheses. Use `formats: ["markdown"]`. Cap at 2 URLs. If the page returns empty content, skip and proceed with snippets only.
- If results point to an API misuse, invoke `b-docs` to verify the correct behavior for that library version
- Do this before verifying hypotheses — it may eliminate wrong hypotheses immediately and save significant time

---

### Step 4 — Verify root cause

Test hypotheses starting from the most likely:

- Add targeted logging at the suspected choke point (not scattered everywhere)
- Check config/env values if hypothesis points there
- Use `get_symbol` or `get_context_bundle` (jcodemunch) to re-examine a specific function if the call graph revealed something suspicious
- If the codebase uses a library: invoke `b-docs` to verify the correct API behavior for that library version

**Stop when root cause is confirmed** — don't continue investigating other hypotheses once found.

State clearly: *"Root cause: [X] because [Y]"* before writing any fix.

---

### Step 5 — Fix

Now that root cause is confirmed:

- Write the minimal fix — don't refactor unrelated code in the same change
- If the fix touches a non-obvious API or behavior, add a comment explaining why
- If the bug reveals a broader pattern (e.g. same silent-catch pattern exists in 3 other places), flag it to the user as a separate follow-up — don't fix everything at once

---

### Step 6 — Verify fix

After applying the fix:

- State what behavior should now change and how to confirm it
- Suggest the minimal test to verify (a specific request, a unit test, a log line to check)
- If the fix involved a config/env change, remind the user to restart the process

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

- Never patch before confirming root cause — a wrong fix wastes time and introduces new bugs
- Always map the full execution path first — the bug is often not where it surfaces
- If 2+ hypotheses seem equally likely, verify the cheaper one first
- Silent failure points (swallowed exceptions, missing logs) are the most common cause of "no error but not working" bugs — check these first
- If the fix requires understanding a library's behavior, use `b-docs` to verify — don't assume
- Keep fixes minimal — one bug, one fix