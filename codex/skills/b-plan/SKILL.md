---
name: b-plan
policy:
  allow_implicit_invocation: true
dependencies:
  tools:
    - name: sequential-thinking
      description: "Required — structured task decomposition and step ordering via sequentialthinking"
    - name: jcodemunch
      description: "Optional — code structure analysis for modify-existing-code tasks (suggest_queries, get_repo_outline, get_file_outline, get_file_tree, index_file)"
description: >
  Decompose non-trivial tasks into ordered steps, dependencies, and risks before coding.
  ALWAYS use when the user says "plan", "lên kế hoạch", "thiết kế", "design",
  "how should I approach", "nên làm thế nào", "before I implement", "trước khi code",
  or describes a task touching 2+ files or multiple moving parts,
  or when the task clearly touches 2+ files without an explicit plan request.
  Distinct from b-analyze: b-plan sequences execution steps; b-analyze evaluates code quality and structure.
---

# b-plan

Think before coding. Use sequential-thinking to decompose tasks into ordered steps,
surface dependencies, identify risks, and produce a clear execution plan — before any
implementation begins.

## When to use

- Task involves more than 2 files or multiple layers (API, DB, service, UI).
- Task has unclear scope or multiple valid approaches.
- User is about to implement something non-trivial and hasn't thought through the order.
- Refactoring, architecture changes, or new feature integration.
- User says: "plan", "thiết kế", "how should I approach X", "lên kế hoạch", "nên bắt đầu từ đâu".

## When NOT to use

- Simple single-file edit or ≤2-step task → do it directly.
- Something is broken and needs debugging → use **b-debug**.
- Quick fact lookup or library API question → use **b-quick-search** or **b-docs**.

## Tools required

- `sequentialthinking` — from `sequential-thinking` MCP server.
- `suggest_queries`, `get_repo_outline`, `get_file_outline`, `get_file_tree`, `index_file` — from `jcodemunch` MCP server *(optional, for modify-existing-code tasks)*.

If sequential-thinking is unavailable: reason through the plan inline step by step,
making the thinking explicit in the response. Do not skip planning — just do it without the tool.
If jcodemunch is unavailable, or `index_folder` returns `file_count = 0`: use Glob/Read to inspect key files manually before Step 2.

Graceful degradation: ✅ Possible — if jcodemunch unavailable, use Glob/Read to inspect key files. If sequential-thinking unavailable, reason inline. Quality is reduced but the skill remains functional.

## Steps

### Step 0 — Feasibility gate *(conditional)*

Run if the task introduces significant behavior, touches unfamiliar code, or the user has not decided to proceed.
Skip if the task is clearly scoped, already approved, or ≤3 steps/single-file.

**Understanding Lock** — before scanning code, confirm:
- **What does the user want?** State the feature in one sentence. Ask the user to confirm.
- **What does "done" look like?** List 2–4 concrete success criteria.
- **Any hard constraints?** (Performance, compatibility, tech stack limits, deadline.)
- **Is the decision already made?** If yes, skip this step entirely — move to Step 1.

If the user corrects scope, update and re-confirm once. If still unclear, ask one focused clarifying question.

**Quick feasibility scan** — once scope is locked, check:
1. Does the current architecture support this? Use jcodemunch (`get_repo_outline`, `get_dependency_graph`) or Glob/Read if jcodemunch is unavailable.
2. Are there blockers? (Missing infrastructure, incompatible dependencies, fundamental architectural gaps.)
3. Effort estimate: S (hours) / M (1–2 days) / L (3–5 days) / XL (1–2 weeks) / XXL (weeks+).

**Scope of Step 0:** lightweight gate only (architecture fit, blockers, effort). It does not replace deep docs/research work (`b-docs`, `b-research`) for uncertain external constraints.

**Gate outcome:**
- No blockers, effort S–L → proceed to Step 1.
- No blockers, effort XL–XXL AND any of the following apply → **stop and run a dedicated research session before planning**: unfamiliar architectural pattern (event sourcing, CQRS, real-time sync), unverified library capability, large blast radius, third-party service constraints unknown. Use `b-docs` or `b-research` to resolve these, then return to b-plan.
- No blockers, effort XL–XXL, constraints known → surface scope to user, confirm, then proceed to Step 1.
- Blocker found → state it clearly with a workaround (if any) or recommend descoping; do not plan around an unresolved blocker.

Append a `## Feasibility` section to the plan file (optional — only if Step 0 was run):
```markdown
## Feasibility
**Effort**: [S/M/L/XL/XXL]
**Blockers**: [none / description]
**Assumptions confirmed**: [list]
```

---

### Step 1 — Clarify scope

Confirm:

- **What is the end state?** What does "done" look like exactly?
- **What already exists?** Is this greenfield or modifying existing code?
- **What are the constraints?** Deadlines, must-not-break areas, tech stack limits?

If ambiguous, ask one focused clarifying question. Once clear, proceed.

---

### Step 1.5 — Scan existing code *(conditional)*

Run if: task modifies or extends existing code.
Skip if: pure greenfield with no existing modules.

Use jcodemunch to scan before decomposition:
- First call `resolve_repo(path="/absolute/project/root")`. If it returns a repo identifier, use it directly (index already exists). If it returns no match, call `index_folder` with the absolute project root path and `use_ai_summaries: false`. Note the `repo` identifier from the response and pass it to all subsequent calls.
- `suggest_queries` — call immediately after indexing to auto-surface entry points, key symbols, and language distribution. Use the output to orient the plan to the most architecturally significant areas.
- `get_file_tree(path_prefix="src/")` — scoped directory view when the task targets a subdirectory.
- `get_repo_outline` — understand overall structure, file layout, module boundaries.
- `get_file_outline` (batch: `file_paths=[...]`) — inspect specific files the plan will touch; use batch mode to load multiple files in one call.

**Goal**: reference real paths/symbols and follow existing patterns. Wrong assumptions here cause execution failure later.

---

### Step 2 — Decompose with sequential-thinking

Use `sequential-thinking` to create atomic steps:

- Independently executable and verifiable.
- Ordered by dependency.
- Usually 4–8 steps (split into phases if >10).
- Each step answers: *what*, *why now*, *done when*.
- Explicitly capture happy path, dependencies, and key risks/fallbacks.

**Architecture trade-off checkpoint** — if the task involves a structural decision (e.g., new module vs extending existing, sync vs async, REST vs event-driven), surface it explicitly:
- State the 2–3 viable approaches and the key trade-offs (complexity, performance, coupling).
- Pick one and document the reason.
- Do not leave architecture decisions implicit inside a step description.

---

### Step 3 — Identify unknowns

Flag anything that must be resolved before or during execution:

- **Docs needed**: library/API behavior that needs verification → mark as `b-docs` call.
- **Research needed**: tool or approach comparison → mark as `b-research` call.
- **Decisions needed**: choices that depend on user preference or business logic.
- **Assumptions**: things the plan assumes to be true — state them explicitly.

If a "Docs needed" unknown affects plan decisions (e.g., "does BullMQ support X?"), resolve it now with `b-docs` and append `→ Confirmed: [finding]`. Do not defer verifiable library assumptions to Session 2.

If the plan has open tool/approach decisions (`compare`, `decide between`, `which library`, `evaluate`, or `?`), resolve with `b-research` inline and append findings to Unknowns. Do not defer tool selection to execution.

An unresolved unknown is a risk. Surface it now, not halfway through implementation.

---

### Step 4 — Write plan to file

Write the plan to `.agents/plans/[task-slug].md` in the **current project root**.

- `task-slug` = kebab-case of the task name, e.g. `add-retry-logic`, `refactor-auth-module`.
- Create `.agents/plans/` if it doesn't exist.
- Show the file path to the user after writing.

Then present a short summary in chat (scope + step count) and ask for confirmation.

If the user requests changes → update the file, then confirm again.
If the user confirms → do NOT execute in this session. Instead, print:

```
✅ Plan saved to .agents/plans/[task-slug].md

Open a new session and run:
  execute plan from .agents/plans/[task-slug].md
```

`new session` means a fresh context (`codex` in a new terminal or starting a new chat).

**Exception — simple tasks (≤4 steps, single file):** plan and execute inline in the same session.

---

## Plan file format

Language: always English — write plan files in English regardless of the user's query language.

```markdown
# Plan: [task name]

**Scope**: [one sentence — what this plan covers]
**End state**: [what "done" looks like]
**Created**: [date]

---

## Steps

- [ ] 1. [Step name]
  - What: ...
  - Why now: ...
  - Done when: ...

- [ ] 2. [Step name]
  - What: ...
  - Why now: ...
  - Done when: ...

...

## Dependencies
- Step 3 requires Step 1 to be complete
- Steps 4 and 5 can run in parallel

## Risks
- [Risk]: [mitigation or fallback]

## Unknowns *(resolve before starting)*
- Need b-docs: [library] — [what to verify]
- Need decision: [question for user]
- Assuming: [assumption that may not hold]

## Feasibility *(optional — only if Step 0 was run)*
**Effort**: [S/M/L/XL/XXL]
**Blockers**: [none / description]
**Assumptions confirmed**: [list]
```

## Execution (in a new session)

Plan files are always in English. When a new session opens with `execute plan from .agents/plans/[file].md`:

1. Read the plan file
2. If the plan modifies existing code and no `## Context` section exists → run `b-analyze` on the relevant modules first, append findings as `## Context` to the plan file
3. Execute steps in order:
   - Production-code steps: apply **b-tdd** (failing test → implement → refactor). b-tdd checks off the step after each RGR cycle.
   - Non-production-code steps (config/migration/docs/deletion): check off `- [ ]` → `- [x]` directly when done.
   - After each modified file: call `index_file` to keep jcodemunch index fresh.
4. Re-evaluate remaining steps if something unexpected happens mid-execution
5. **If a step fails**: change `- [ ]` to `- [❌] Step N — [brief reason]`, check downstream dependencies, and pause/inform the user if blockers exist. Never silently skip failed steps.
6. After all steps complete → run **b-gate** on the changed files. Fix any hard failures (lint, typecheck, test, high-severity security) before proceeding. Note soft warnings as follow-ups.
7. After b-gate passes → run **b-review** to verify logic correctness and requirements coverage. Fix any blockers b-review surfaces.
8. After b-review gives READY FOR PR → run **b-commit** to generate commit message and PR description.
9. Update the plan file with final status when done.

---

## Rules

- Always write to `.agents/plans/` — never output the plan only in chat for non-trivial tasks.
- Always write plan files in English — regardless of the user's query language.
- Never execute in the same session as planning for tasks with 5+ steps — keep contexts clean.
- Steps must be ordered by dependency — wrong order causes cascading failures.
- Keep steps atomic — one clear action per step, not "implement the whole service layer.".
- If a step requires a b-docs or b-research call, mark it explicitly in the Unknowns section.
- Surface risks and assumptions proactively — a wrong assumption found at Step 1 is free; found at Step 7 it costs a rewrite.
- If the task turns out to require 10+ steps, split it into phases — one plan file per phase.
- During execution, check off steps as completed and update the file in real time.
