---
name: b-feature
description: >
  Full-cycle feature orchestrator: plan → docs → research → implement → self-review.
  ALWAYS use when the user prefixes with "b-feature:", or describes building something
  non-trivial from scratch, integrating a new service, or making changes spanning
  multiple files and layers. Best triggered explicitly: "b-feature: [description]".
  Not for bug fixes (use b-debug) or quick single-file edits.
---

# b-feature

Orchestrator for complete feature development. Chains b-plan → b-docs → b-research
→ implement → b-analyze in a single workflow, skipping steps that don't apply.
Each step gates the next — never skip ahead.

## When to use

- Building a new feature from scratch
- Integrating a third-party service or SDK
- Changes that span multiple files, layers, or services
- Any task where you'd normally invoke 2+ skills manually
- Explicitly triggered with: `b-feature: [description]`

**Not needed for**: bug fixes (use `b-debug`), quick edits to a single function,
or one-off questions. Those are faster without the full pipeline.

## Skills required

This skill orchestrates the full b-skill suite. All must be available:

| Skill | MCP | Role |
|---|---|---|
| `b-plan` | sequential-thinking | Decompose and sequence the work |
| `b-docs` | context7 | Fetch live library/SDK docs |
| `b-research` | brave-search + firecrawl | Research tools, patterns, comparisons |
| `b-analyze` | jcodemunch | Understand existing code + self-review |

If a required MCP is missing, note it and skip that step — do not abort the entire pipeline.

Graceful degradation: ⚠️ Partial — if a required MCP is unavailable, the corresponding phase is logged as skipped in the plan file (see Step 0 Preflight). The pipeline continues with available phases.

## Recommended model

Use **Opus** to start Session 1, then switch models per phase in Session 2:

| Phase | Model | Reason |
|---|---|---|
| Phase 1 — b-plan | **Opus** | Decomposition + dependency graph — reasoning-heavy |
| Phase 2 — b-analyze (existing code) | **Opus** | Structural scan informs all implementation choices |
| Phase 3a — b-docs | **Sonnet** | Retrieval task — bottleneck is docs quality, not reasoning |
| Phase 3b — b-research | **Sonnet** | Search + synthesis — no deep reasoning chain needed |
| Phase 4 — implement | **Sonnet** (default) / **Opus** for steps marked `[complex]` in plan | Plan already did the reasoning; follow the plan |
| Phase 5 — b-analyze (review) | **Opus** | Quality gate — catching subtle issues requires strong reasoning |

**Session 1**: start with `/model opus` — covers Phase 1 and 2 which are the most reasoning-intensive.

**Session 2**: start with `/model sonnet`, then switch to `/model opus` only for steps the plan file marks as `[complex]` or that touch security/DB schema/async logic. Switch back to Sonnet after those steps.

---

## Step 0 — Preflight

Check MCP availability before starting (run `/mcp` to verify connected servers). Required MCPs per phase:
- Phase 1 (b-plan): sequential-thinking
- Phase 2 (b-analyze): jcodemunch
- Phase 3a (b-docs): context7
- Phase 3b (b-research): brave-search + firecrawl
- Phase 5 (b-analyze): jcodemunch

If a required MCP is unavailable, log it in the plan file header as `⚠️ [MCP] unavailable — Phase [N] will be skipped`. Do not abort — continue with available phases.

---

## Two-session model

b-feature runs across **two sessions** to keep planning context separate from
execution context. Session 1 produces a plan file. Session 2 executes it.

```
Session 1: PLAN → UNDERSTAND → GATHER → write .claude/b-plans/[slug].md
Session 2: read plan file → IMPLEMENT → REVIEW
```

**Before detecting session type**: use `Glob` to check if `.claude/b-plans/*.md` contains any existing plan files relevant to this task (matching keywords in the task name). If a relevant plan file exists: show the file path to the user and ask: 'A plan for this task already exists at `[path]`. Continue from this plan (Session 2), or start fresh (Session 1)?' Wait for user response before proceeding. If no relevant plan exists: apply the session detection logic below.

Detect which session you are in:
- **No plan file referenced** → Session 1 (planning mode)
- **User says "execute plan from ..."** or references a plan file → Session 2 (execution mode)

---

## Session 1 — Planning

### Phase 1 — PLAN `(b-plan)`

Always run. No exceptions.

Invoke `b-plan` to decompose the feature into ordered steps, surface dependencies,
and identify unknowns. Write the plan to `.claude/b-plans/[task-slug].md` in the
current project root.

If the plan reveals the task is actually a bug fix → stop and switch to `b-debug`.

---

### Phase 2 — UNDERSTAND `(b-analyze)` *(conditional)*

Run if: the feature modifies or extends existing code.
Skip if: purely greenfield.

Invoke `b-analyze` on the relevant existing modules. Append findings as a
`## Context` section to the plan file — they will inform implementation in Session 2.

---

### Phase 3 — GATHER *(conditional)*

Run based on unknowns flagged in Phase 1:

**3a — `b-docs`** *(if any library/SDK is involved)*
Fetch live docs for every external library the feature will use.
Append a `## Docs` section to the plan file with key API notes.

**3b — `b-research`** *(if plan flagged an open tool/approach decision)*
Research open questions. Append a `## Research` section to the plan file.

Phase 3b is **required** (not optional) if the plan's Unknowns or Dependencies section contains any of: `compare`, `decide between`, `which library`, `evaluate`, `best approach for`, or any item ending with `?`. If these keywords appear, run b-research — do not skip — apply this rule only for architecture or tool selection decisions, not for trivial implementation choices (e.g. 'decide between `map` and `forEach`' does NOT trigger b-research).

Both can run in the same phase. 3a is far more common.

---

### End of Session 1

After Phases 1–3, the plan file contains everything needed for clean execution.
Print:

```
✅ Plan ready: .claude/b-plans/[task-slug].md

Open a new session and run:
  execute plan from .claude/b-plans/[task-slug].md
```

Do not implement anything in Session 1.

---

## Session 2 — Execution

Triggered by: `execute plan from .claude/b-plans/[file].md`

### Phase 4 — IMPLEMENT

Read the plan file. Execute steps in order:
- Check off each step `- [ ]` → `- [x]` in the file as it completes
- Use the `## Context` section (b-analyze findings) to match existing patterns
- Use the `## Docs` section for accurate library API calls
- If a tool fails mid-execution → (a) document the failure in the plan file as `- [❌] Phase N — [brief reason]`; (b) assess whether remaining phases depend on this output; (c) if a blocking dependency exists, pause and inform the user before continuing.

Do not implement all steps in one pass without checkpoints.

---

### Phase 5 — REVIEW `(b-analyze)`

Always run. After implementation is complete, invoke `b-analyze` on the newly
written code:

- Does the new code follow the patterns found in Phase 2?
- Any complexity hotspots introduced?
- Any duplication with existing code?

If findings are 🔴 High → fix before presenting to user.
If findings are 🟡 Medium or 🟢 Low → present alongside the implementation as known follow-ups.

Mark the plan file as complete:

```markdown
**Status**: ✅ Done — [date]
```

---

## Output format

**Session 1:**
```
── b-feature: [task name] — planning ───────

▶ Phase 1 — Plan
  → written to .claude/b-plans/[slug].md

▶ Phase 2 — Understand existing code       [SKIP if greenfield]
  → findings appended to plan file

▶ Phase 3 — Gather
  3a. Docs: [libraries]                    [SKIP if none]
  3b. Research: [topic]                    [SKIP if not needed]
  → notes appended to plan file

✅ Plan ready: .claude/b-plans/[slug].md
Open a new session and run:
  execute plan from .claude/b-plans/[slug].md
```

**Session 2:**
```
── b-feature: [task name] — executing ──────

▶ Reading plan: .claude/b-plans/[slug].md
▶ Phase 4 — Implement
  [x] Step 1 — done
  [x] Step 2 — done
  [ ] Step 3 — in progress...

▶ Phase 5 — Self-review
  [b-analyze findings]
  [🔴 fixed / 🟡🟢 noted as follow-ups]

── Done ─────────────────────────────────
```

---

## Rules

- **Never skip Phase 1** — a plan, even a short one, prevents wrong-direction work
- **Never skip Phase 5** — shipping unreviewed code defeats the purpose of the pipeline
- **Never implement in Session 1** — planning and execution must be in separate sessions
- Phase order is fixed within each session. Never reorder.
- All b-analyze findings from Phase 2 must be written to the plan file, not just kept in context
- If a MCP tool fails mid-pipeline, note it in the plan file, skip that phase, continue
- If the task grows significantly during execution, pause and update the plan file before continuing
- b-feature is for complex tasks. If the task turns out to be simple (one file, ≤4 steps),
  run the full pipeline in a single session without writing a plan file.