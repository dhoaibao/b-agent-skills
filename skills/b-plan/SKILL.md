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

- The request is small and clear -> use **b-implement**.
- The request is a concrete behavior-preserving transform -> use **b-refactor**.
- External facts are the blocker -> use **b-research**.
- Something is broken -> use **b-debug**.

## Tool guidance

- `bash` - light repo discovery with modern tools, routed through `rtk` whenever that command family is supported, and `rtk git status --short` when needed.
- `read` - open only the files required to avoid guessing.
- `codegraph` - only for repository-wide architecture, dependency flows, and impact evidence; initialize an absent local index on first such use.
- `serena` - inspect exact symbol declarations, references, or implementations
  only when they materially improve precision; use native `read` for routine
  discovery and serialize requests rather than parallelizing or batching them.
- `context7` - one narrow versioned API check when it changes the plan.
- `firecrawl` - bounded public docs or issue research when exact text changes scope.
- `recall` - recover compacted planning context when observational memory ids are present.

## Steps

1. State the interpreted goal, constraints, and non-goals. Use recall when compacted prior planning ids are available.
2. If multiple interpretations are plausible, present them briefly and choose only when the choice is low-risk; otherwise ask.
3. Inspect only files, symbols, or relevant repo notes needed to avoid guessing. Use bash discovery and Pi native `read` for local evidence. When the plan needs repository-wide architecture or impact, initialize an absent CodeGraph index and use it for that question; use Serena separately only for exact symbols and references when they materially improve precision. Use Context7 for versioned API checks and bounded Firecrawl research for public docs or issues when they affect the plan; do not parallelize or batch Serena calls.
4. When the task is fuzzy, investigate the current code or constraints enough to compare viable paths before choosing one.
5. Choose the smallest safe approach, surface material tradeoffs, and push back if a simpler or safer path exists.
6. Include `Done when` verification for each step that proves the intended observable outcome, not just command success.
7. End with either a plan that is ready for **b-implement** or one focused blocking question that must be answered before implementation.
8. For larger plans, tag steps only when useful: `AFK` for agent-ready work, `HITL` for user decision, approval, external access, or judgment.

For plans spanning more than 3 files, public contracts, dependencies, CI/build, or durable coordination, save a plan under `.b-agentic/b-plan/` only if it will materially help execution.

## Planner/worker sequencing

For a two-role task, finish discovery and settle the approach before one bounded implementation handoff. If the worker needs clarification, agree on the final approach together before edits begin. Once the worker starts editing, stop exploration and do not issue new implementation requests; wait for the result and review it.

## Output format

Concise scope, recommended path, ordered steps, verification, and explicit blockers. Ask for approval before implementation.

## Rules

- Do not implement.
- Keep plans short unless risk requires detail.
- Do not stay in open-ended brainstorming; converge on one recommended path when the evidence is sufficient.
- Do not invent behavior, names, acceptance criteria, or commands.
- Do not require project context docs or HITL/AFK markers for ordinary small plans.
- Surface material assumptions and blockers explicitly.
