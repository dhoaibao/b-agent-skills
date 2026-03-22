---
name: b-plan
description: >
  Decompose non-trivial tasks into ordered steps, dependencies, and risks before coding.
  ALWAYS use when the user says "plan", "lên kế hoạch", "thiết kế", "design",
  "how should I approach", "nên làm thế nào", "before I implement", "trước khi code",
  or describes a task touching 2+ files or multiple moving parts.
  Also trigger proactively for complex tasks without an explicit plan request.
---

# b-plan

Think before coding. Use sequential-thinking to decompose tasks into ordered steps,
surface dependencies, identify risks, and produce a clear execution plan — before any
implementation begins.

## When to use

- Task involves more than 2 files or multiple layers (API, DB, service, UI)
- Task has unclear scope or multiple valid approaches
- User is about to implement something non-trivial and hasn't thought through the order
- Refactoring, architecture changes, or new feature integration
- User says: "plan", "thiết kế", "how should I approach X", "lên kế hoạch", "nên bắt đầu từ đâu"

## Tools required

- `sequentialthinking` — from `sequential-thinking` MCP server
- `suggest_queries`, `get_repo_outline`, `get_file_outline`, `get_file_tree` — from `jcodemunch` MCP server *(optional, for modify-existing-code tasks)*

If sequential-thinking is unavailable: reason through the plan inline step by step,
making the thinking explicit in the response. Do not skip planning — just do it without the tool.
If jcodemunch is unavailable, or `index_folder` returns `file_count = 0`: use Glob/Read to inspect key files manually before Step 2.

Graceful degradation: ✅ Possible — if jcodemunch unavailable, use Glob/Read to inspect key files. If sequential-thinking unavailable, reason inline. Quality is reduced but the skill remains functional.

## Recommended model

**Opus** (`/model opus`) — required for reliable output.

A plan with missing dependencies or wrong step ordering causes cascading failures across all subsequent implementation. Opus produces significantly more complete dependency graphs and risk identification than Sonnet on multi-file tasks. Switch before invoking: `/model opus`.

---

## Steps

### Step 1 — Clarify scope

Before planning, confirm:

- **What is the end state?** What does "done" look like exactly?
- **What already exists?** Is this greenfield or modifying existing code?
- **What are the constraints?** Deadlines, must-not-break areas, tech stack limits?

If the task description is ambiguous, ask one focused question to clarify — not multiple.
Once scope is clear, proceed.

---

### Step 1.5 — Scan existing code *(conditional)*

Run if: task modifies or extends existing code.
Skip if: pure greenfield with no existing modules.

Use jcodemunch to scan the relevant area before decomposing:
- First call `index_folder` with the absolute project root path. Use `use_ai_summaries: false`. Note the `repo` identifier from the response and pass it to all subsequent calls.
- `suggest_queries` — call immediately after indexing to auto-surface entry points, key symbols, and language distribution. Use the output to orient the plan to the most architecturally significant areas.
- `get_file_tree(path_prefix="src/")` — use for a scoped directory view when the task affects a specific subdirectory (faster than scanning the full repo outline)
- `get_repo_outline` — understand overall structure, file layout, module boundaries
- `get_file_outline` (batch: `file_paths=[...]`) — inspect specific files the plan will touch; use batch mode to load multiple files in one call

**Goal**: ensure the plan references real file paths, real function names, and respects existing patterns.
A plan built on wrong assumptions about the codebase fails at Step 1 of execution.

---

### Step 2 — Decompose with sequential-thinking

Use `sequential-thinking` to break the task into atomic steps:

- Each step should be independently executable and verifiable
- Steps should be ordered by dependency — a step cannot start until its prerequisites are done
- Aim for 4–8 steps for most tasks; more than 10 suggests the task should be split into sub-tasks
- Each step should answer: *what to do*, *why at this point*, and *how to verify it's done*

Think through:
- **Happy path**: the sequence of steps assuming everything works
- **Dependencies**: which steps block others, which can run in parallel
- **Risks**: where things are most likely to go wrong, and what the fallback is

---

### Step 3 — Identify unknowns

Flag anything that needs to be resolved before or during execution:

- **Docs needed**: library/API behavior that needs verification → mark as `b-docs` call
- **Research needed**: tool or approach comparison → mark as `b-research` call
- **Decisions needed**: choices that depend on user preference or business logic
- **Assumptions**: things the plan assumes to be true — state them explicitly

If any "Docs needed" unknown involves a specific library behavior that will affect plan decisions (e.g., "does BullMQ support X?", "what's the retry API for Axios?") → resolve it now by calling `b-docs` inline, before writing the plan file. Append the finding as a note under the unknown: `→ Confirmed: [finding]`. Do not defer verifiable library assumptions to Session 2.

An unresolved unknown is a risk. Surface it now, not halfway through implementation.

---

### Step 4 — Write plan to file

Once the plan is ready, write it to `.claude/b-plans/[task-slug].md` inside the **current project root** — not `~/.claude`. Each project has its own plans directory.

- `task-slug` = kebab-case of the task name, e.g. `add-retry-logic`, `refactor-auth-module`
- Create `.claude/b-plans/` if it doesn't exist
- Show the file path to the user after writing

Then present a short summary in chat (scope + step count) and ask for confirmation.

If the user requests changes → update the file, then confirm again.
If the user confirms → do NOT execute in this session. Instead, print:

```
✅ Plan saved to .claude/b-plans/[task-slug].md

Open a new session and run:
  execute plan from .claude/b-plans/[task-slug].md
```

Note: 'new session' means running `claude` in a new terminal, or using `/clear` in the current terminal to reset context.

**Model for the execution session:** Include this note in the printed output above so the user knows what model to start the next session with:

```
💡 Recommended model for execution:
  - Most steps (multi-file implementation): /model sonnet
  - Steps marked [complex] or touching security/DB schema/async: /model opus
  - Single-file, spec is fully defined: /model haiku
  Rationale: this plan already did the heavy reasoning. Execution follows the plan — model tier can drop one level.
```

When writing the plan file, add a `## Model hint` section at the top (below frontmatter) listing any steps that require Opus due to complexity, so the executing session knows upfront:

```markdown
## Model hint
- Default execution model: sonnet
- Upgrade to opus for: [list specific step names/numbers, or "none"]
```

**Exception — simple tasks (≤4 steps, single file):** skip the file, plan and execute
inline in the same session. Not worth the overhead.

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
```

## Execution (in a new session)

Plan files are always in English. When a new session opens with `execute plan from .claude/b-plans/[file].md`:

1. Read the plan file
2. Execute steps in order, checking off each `- [ ]` → `- [x]` as it completes
3. Re-evaluate remaining steps if something unexpected happens mid-execution
3.5. **If a step fails**: (a) document the failure in the plan file by changing `- [ ]` to `- [❌] Step N — [brief failure reason]`; (b) evaluate whether subsequent steps that depend on this step are now blocked; (c) if any blocking dependency exists, pause and inform the user before continuing. Do not silently skip failed steps.
4. Update the file with final status when done

---

## Rules

- Always write to `.claude/b-plans/` — never output the plan only in chat for non-trivial tasks
- Always write plan files in English — regardless of the user's query language
- Never execute in the same session as planning for tasks with 5+ steps — keep contexts clean
- Steps must be ordered by dependency — wrong order causes cascading failures
- Keep steps atomic — one clear action per step, not "implement the whole service layer"
- If a step requires a b-docs or b-research call, mark it explicitly in the Unknowns section
- Surface risks and assumptions proactively — a wrong assumption found at Step 1 is free; found at Step 7 it costs a rewrite
- If the task turns out to require 10+ steps, split it into phases — one plan file per phase
- During execution, check off steps as completed and update the file in real time
