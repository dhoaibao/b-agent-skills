# b-implement

Make the scoped non-UI change in the smallest coherent step, and hand back to planning or research instead of guessing when new ambiguity appears.

## When to use

- The user approved a plan or gave a small direct request.
- The next action is a scoped non-UI code or repository change.

## When NOT to use

- Scope or behavior is unclear -> use **b-plan**.
- The primary requested change is frontend/UI code—pages, layouts, components, styling, responsive behavior, interactions, or a visual refresh -> use **b-frontend**, the sole implementation skill for that UI slice.
- The primary task is a named refactor -> use **b-refactor**.
- The task is only tests -> use **b-test**.
- Root cause is unknown -> use **b-debug**.
- External lookup blocks the edit -> use **b-research**.

## Tool guidance

- `serena` - after native search/read, use only when a concrete exact-symbol,
  reference, implementation, or diagnostic/refactor need remains and semantic
  tooling materially improves safety or precision. Prefer native
  `read`/`edit`/`write` for routine file work. Relevant onboarding and durable
  project memories are explicit exceptions; serialize requests and never
  parallelize or batch them.
- `read`/`edit`/`write` - use Pi native file tools by default for routine inspection and changes; also use them for unsupported files or as a fallback when Serena precision work fails.
- `bash` - `rtk git status --short`, verification commands, and modern discovery routed through `rtk` whenever that command family is supported.
- `codegraph` - only for a concrete repository-wide architecture, dependency/call flows, impact, or affected-test question that native inspection cannot settle; do not initialize an absent local index merely because the task spans files.
- `lsp_diagnostics` / `lsp_fix` - use diagnostics on changed source when Pi LSP and a relevant language server are ready; use source actions only when explicitly authorized, and fall back to repository checks when unsupported or unavailable.
- `context7` - narrow versioned third-party API checks when needed.
- `recall` - recover compacted observational-memory ids when present instead of guessing prior context.

## Capability activation

Use the capability contract by trigger rather than by availability: use LSP diagnostics on supported changed source when its server is ready, then fall back to repository checks; use Serena only for concrete semantic precision after native inspection, CodeGraph only for the repository-wide questions above, and `recall` only when a supplied compacted-memory ID materially helps. In a two-role workflow use Intercom only for the explicit worker/planner handoff; use `ask_user_question` only for a material user-facing choice. Do not invoke usage reporting or authentication for unrelated implementation, and do not persist telemetry or session content.

## Steps

1. Resolve the source of truth: approved plan, approved chat instruction, or small direct request.
2. Run `rtk git status --short` via Bash and preserve unrelated changes.
3. Use read for relevant repo context only when it materially affects the scoped change; use recall when compacted prior plan context is available. Before edits, consult applicable project standards, architecture boundaries, and relevant failure modes. For small obvious work, consult only the evidence needed and do not create ceremony.
4. State expected files/symbols, invariant behavior, and success criteria. Success criteria and verification must establish intended behavior plus relevant quality constraints, not merely command success. If material framework/API best-practice uncertainty remains after repository evidence, stop and route that specific question to targeted **b-research** rather than guessing.
5. When native inspection leaves a concrete repository-wide architecture, impact, or affected-test question, initialize an absent CodeGraph index and use it for that question; do not initialize one merely because the task spans files. Use native tools or local search for routine work; use Serena separately only for a specific exact symbol, reference, diagnostic, or reference-aware refactor when that materially improves precision.
6. If a material blocker, new uncertainty, missing external fact, or scope drift cannot be resolved from the approved plan, direct request, and repository evidence, stop before the next edit. In delegated worker work, ask the assigning planner one focused question through Intercom and wait; keep worker→planner questions as Intercom coordination. In planner or solo/Off work, use the installed `ask_user_question` tool for the interactive, user-facing material decision or blocker: group 1–4 related questions, provide 2–4 concrete options with concise trade-offs, put the recommended option first with ` (Recommended)`, and rely on the automatic custom-answer row. If unavailable or noninteractive, ask one focused plain-text question; in planner mode, an actual `ask_user_question` tool call triggers a fixed privacy-safe desktop notification, while solo/Off workers emit no planner notifications. Do not use the questionnaire for normal updates or no-choice confirmations. Native tool-permission prompts remain for browser, external, or privileged actions. The planner owns external research and scope decisions. Re-evaluate each answer; hand back to **b-plan** or **b-research** only when it identifies that handoff.
7. Edit the smallest coherent slice and match the existing local style. Use Pi native `edit`/`write` for routine changes; use Serena only for a reference-aware symbol refactor or another listed precision task, and keep its requests serialized.
8. Run the narrowest useful verification (using Context7 for versioned third-party API checks if the implementation relies on them) that establishes the intended behavior and relevant quality constraints, not only command success.
9. If verification exposes an in-scope defect without a material blocker, correct it and rerun the required check. Otherwise stop under step 6.
10. Inspect changed paths with metadata-only Git output, then inspect diffs only for explicit non-protected paths and report changes, verification, and remaining gaps.

## Planner/worker sequencing

For planner-assigned work, treat the handoff as bounded. Resolve ambiguity and agree on the final approach with the planner before editing; once editing starts, do not expand scope from exploratory requests. Delegated results must report under five fixed headings: "Changed" (paths + brief what), "Verification" (exact commands + outcomes), "Coverage" (acceptance criteria met), "Deviations" (scope changes, assumptions, or "none"), and "Gaps" (unverified/remaining or "none"). Every outcome—completed, no-change, blocked, or reported gap—must be successfully sent to the same assigning planner under those headings before pausing; no outcome is a silent exception. Workers must never invoke, load, or execute planner-owned **b-review** themselves; a terminal report/review request is coordination only, and a worktree-changing result must ask the assigning planner to run actual **b-review** against the approved baseline. Prose may accompany the headings, but every heading must be present. Ask the planner to invoke actual **b-review** and pause all edits. Only delegated worktree-changing tasks require this review gate; its baseline is the latest approved plan, handoff, and clarifications.

## Output format

Changes, verification, acceptance coverage, and deviations, assumptions, or gaps. For delegated worktree-changing changes, explicitly ask the planner to invoke actual **b-review** and pause.

## Rules

- Stay within approved scope.
- When an edit anchor (oldText) fails to match, re-read the target region and re-anchor the edit from current content; never blind-retry the same anchor or widen context speculatively.
- Every changed line should trace to the approved scope or cleanup made necessary by this change.
- Remove imports or helpers made unused by the change; leave pre-existing dead code and adjacent comments or formatting untouched.
- Auto-run regular repository-local commands, including routine build, test, package, dependency, and script automation; ask before explicit destructive or privileged commands, ambiguous shell syntax, protected or outside-project paths, external/shared mutations, PRs, or broad refactors.
- Do not add opportunistic cleanup, speculative compatibility, single-use abstractions, or handling for impossible scenarios without repo evidence.
- Do not push through newly discovered ambiguity; route it explicitly.
- Do not ask about details that the approved scope or repository evidence resolves; for each remaining material blocker, ask exactly one focused question and wait for its answer before asking the next.
- Do not claim done when required verification is missing or failed.
