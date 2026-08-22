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
- `codegraph` - only for a concrete repository-wide architecture, dependency/call-flow, or impact question that native inspection cannot settle; do not initialize an absent local index merely because the task spans files.
- `serena` - after native search/read, inspect a specific exact symbol, reference,
  implementation, or diagnostic only when semantic tooling materially improves
  precision; serialize requests rather than parallelizing or batching them.
- `context7` - one narrow versioned API check when it changes the plan.
- `linear` - when the user supplies a Linear issue ID and the managed Linear server is configured and authenticated, use the `mcp` gateway to retrieve only that issue with `server: "linear"`, `tool: "get_issue"`, and its ID; request `includeRelations: true` only when directly linked context is needed. Cached MCP status, server listing, search, describe, and instructions metadata may establish availability or schema for any server, but are not issue research.
- `firecrawl` - bounded public docs or issue research when exact text changes scope.
- `recall` - recover compacted planning context when observational memory ids are present.

## Steps

1. State the interpreted goal, constraints, and non-goals. Use recall when compacted prior planning ids are available.
2. If multiple interpretations are plausible, present them briefly and choose only when the choice is low-risk; otherwise ask.
3. Inspect only files, symbols, or relevant repo notes needed to avoid guessing. Use bash discovery and Pi native `read` for local evidence. When native inspection leaves a concrete repository-wide architecture or impact question, use an available CodeGraph index for that question. Do not initialize an absent index in planner mode; fall back to native inspection and state the resulting gap. Outside planner mode, initialize an absent index only for that question; do not initialize one merely because the task spans files. Use Serena separately only for a specific exact symbol or reference when it materially improves precision. Use Context7 for versioned API checks and bounded Firecrawl research for public docs or issues when they affect the plan; do not parallelize or batch Serena calls.
4. For an optional Linear issue ID, use only `get_issue` for that exact ID. Treat its issue details and included relations as Linear facts, repository inspection as repo facts, and anything else as an assumption. If authentication, the issue, or linked context is unavailable or truncated, say so; do not list/search Linear issues or invoke other unclassified Linear operations, and do not guess missing context. Cached non-executing gateway metadata discovery is not Linear issue research.
5. When the task is fuzzy, investigate the current code or constraints enough to compare viable paths before choosing one.
6. Choose the smallest safe approach, surface material tradeoffs, and push back if a simpler or safer path exists.
7. Include `Done when` verification for each step that proves the intended observable outcome, not just command success.
8. End with either a plan that is ready for **b-implement** or one focused blocking question that must be answered before implementation. For a user-facing material decision or blocker, use the installed `ask_user_question` tool with 1–4 grouped questions, 2–4 concrete options, and a recommended first option; if unavailable or noninteractive, ask one focused plain-text question. Emit exactly one `B_AGENTIC_USER_INPUT_NEEDED` signal for that planner decision/blocker. Omit both questionnaire and signal for normal planning, discovery, handoffs, and updates.
9. For larger plans, tag steps only when useful: `AFK` for agent-ready work, `HITL` for user decision, approval, external access, or judgment.

For plans spanning more than 3 files, public contracts, dependencies, CI/build, or durable coordination, save a plan under `.b-agentic/b-plan/` only if it will materially help execution. In planner mode, instead keep the approved plan in the handoff or conversation; do not save plan files.

## Planner/worker sequencing

For a two-role task, finish discovery and settle the approach before one bounded handoff. For non-trivial work, concisely include applicable observable behavior, scope/non-goals, constraints/invariants, relevant paths/symbols/evidence, acceptance criteria, validation expectations, and assumptions, pre-existing changes, or gaps. Agree before edits if needed; once editing starts, stop exploration and new implementation requests until the result.

## Output format

Concise scope, recommended path, ordered steps, verification, and explicit blockers. Ask for approval before implementation.

When the response ends with a focused user question requiring a decision or blocker answer, add `B_AGENTIC_USER_INPUT_NEEDED` as its own final line; otherwise omit it. Do not include task or session details in the signal.

## Rules

- Do not implement.
- Keep plans short unless risk requires detail.
- Do not stay in open-ended brainstorming; converge on one recommended path when the evidence is sufficient.
- Do not invent behavior, names, acceptance criteria, or commands.
- Do not require project context docs or HITL/AFK markers for ordinary small plans.
- Surface material assumptions and blockers explicitly.
