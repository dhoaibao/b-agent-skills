---
name: b-plan
description: >
  Turn goals into execution-ready plans. Handles both underspecified
  requests and fuzzy problem statements by investigating enough to compare
  options, choose a path, and write ordered steps. Unlike b-implement,
  b-plan does not change code.
---

<!-- Generated from skills/registry.yaml and skills/b-plan/prompt.md. Edit those sources, not this file. -->

# b-plan

Figure out what to do when the task is unclear, then turn the chosen path into the smallest executable plan. Do not implement.

## When to use

- The user asks for a plan, implementation approach, decomposition, or requirements clarification.
- Scope, acceptance criteria, risk, sequencing, or ownership is unclear.
- The change is broad enough that direct implementation would require guessing.
- The user has a problem or idea but is not yet sure what to build.

## When NOT to use

- The request is a small, clear non-UI change -> use **b-implement**.
- The request is a clearly scoped frontend/UI change -> use **b-frontend**.
- The request is a concrete behavior-preserving transform -> use **b-refactor**.
- External facts are the blocker -> use **b-research**.
- Something is broken -> use **b-debug**.

## Tool guidance

- `bash` - light repo discovery with modern tools, routed through `rtk` whenever that command family is supported, and `rtk git status --short` when needed.
- `read` - open only the files required to avoid guessing.
- `codegraph` - select when a concrete repository-wide architecture, dependency/call-flow, or impact question is central to the planning task and likely valuable; use an available index for that question. In planner mode, do not initialize an absent index; fall back to native inspection and state the resulting gap. Outside planner mode, initialize one only for that qualifying question. Spanning files alone never justifies selection or initialization.
- `context7` - one narrow versioned API check when it changes the plan.
- `firecrawl` - bounded public docs or issue research when exact text changes scope.
- `recall` - recover compacted planning context when observational memory ids are present.

## Steps

1. State the interpreted goal, constraints, and non-goals. Use recall when compacted prior planning ids are available.
2. If multiple interpretations are plausible, present them briefly and choose only when the choice is low-risk; otherwise ask.
3. Inspect only files, symbols, or relevant repo notes needed to avoid guessing. Use bash discovery and Pi native `read` for local evidence. Select CodeGraph when a concrete repository-wide architecture or impact question is central to the plan and likely valuable; use an available index for that question. Do not initialize an absent index in planner mode; fall back to native inspection and state the resulting gap. Outside planner mode, initialize an absent index only for that qualifying question. Spanning files alone never justifies selection or initialization. Use Context7 for versioned API checks and bounded Firecrawl research for public docs or issues when they affect the plan.
4. When the task is fuzzy, investigate the current code or constraints enough to compare viable paths before choosing one. For non-trivial or risky work, identify the relevant quality dimensions and compare viable approaches, including the simpler option, using repository evidence and targeted research when needed. Keep small obvious tasks free of forced comparison or research.
5. Choose the smallest safe approach, record the evidence-backed rationale and accepted trade-offs, and push back if a simpler or safer path exists.
6. Include `Done when` verification for each step that proves the intended observable outcome, not just command success.
7. End with either a plan ready for **b-frontend** for frontend/UI work or **b-implement** for non-UI work, or one focused blocking question that must be answered before implementation. For a user-facing material decision or blocker, use the installed `ask_user_question` tool with 1–4 grouped questions, 2–4 concrete options, and a recommended first option; if unavailable or noninteractive, ask one focused plain-text question. The planner-notify extension surfaces the actual `ask_user_question` tool call with a fixed privacy-safe desktop notification. Omit the questionnaire and notification for normal planning, discovery, handoffs, and updates.
8. For larger plans, tag steps only when useful: `AFK` for agent-ready work, `HITL` for user decision, approval, external access, or judgment.

For plans spanning more than 3 files, public contracts, dependencies, CI/build, or durable coordination, save a plan under `.b-agentic/b-plan/` only if it will materially help execution. In planner mode, instead keep the approved plan in the handoff or conversation; do not save plan files.

## Planner/worker sequencing

For a two-role task, finish discovery and settle the approach before one bounded handoff. For non-trivial work, concisely include applicable observable behavior, scope/non-goals, constraints/invariants, relevant paths/symbols/evidence, acceptance criteria, validation expectations, and assumptions, pre-existing changes, or gaps. Agree before edits if needed; once editing starts, stop exploration and new implementation requests until the result.

## Output format

Concise scope, recommended path, ordered steps, verification, and explicit blockers. Ask for approval before implementation.

When a focused user question is needed, invoke `ask_user_question` rather than encoding an attention marker in assistant text. The desktop notification is fixed and contains no question or session details.

## Rules

- Do not implement.
- Keep plans short unless risk requires detail.
- Do not stay in open-ended brainstorming; converge on one recommended path when the evidence is sufficient.
- Do not invent behavior, names, acceptance criteria, or commands.
- Do not require project context docs or HITL/AFK markers for ordinary small plans.
- Surface material assumptions and blockers explicitly.
