# b-refactor

Run concrete behavior-preserving transforms: rename, extract, move, inline, simplify, or delete.

## When to use

- The user names a specific behavior-preserving transform.
- The target is clear enough to change without product decisions.

## When NOT to use

- The request is vague cleanup or changes behavior -> use **b-plan**.
- The work adds behavior -> use **b-implement**.
- The work fixes a bug -> use **b-debug**.
- The work is test-only -> use **b-test**.

## Tool guidance

- `bash` - `rtk git status --short`, checks, and modern discovery routed through `rtk` whenever supported.
- `codegraph` - only for a concrete repository-wide impact or dependency-structure question that native inspection cannot settle; do not initialize an absent local index merely because the transform spans files.
- `serena` - after native search/read, use only for a specific exact
  declaration/reference/implementation, diagnostic, or reference-aware refactor
  when it materially improves safety or precision; serialize requests and never
  parallelize or batch them.
- `read`/`edit` - routine file work, prose, comments, config keys, and Serena
  fallbacks. Prefer native edits unless a reference-aware Serena refactor is
  materially safer.
- `lsp_diagnostics` / `lsp_fix` - use diagnostics for changed source when the relevant server is ready; use source actions only with explicit authorization, then fall back to repository checks if the route is unavailable.

## Capability activation

Use only the semantic capability required by the named transform: Serena is for exact symbol/reference precision after native discovery, while LSP is for diagnostics on supported changed source. `recall` is optional and requires a supplied compacted-memory ID. Intercom, authentication, and usage reporting are not part of a mechanical refactor unless their explicit task trigger is present.

## Steps

1. Lock the exact target and state the behavior that must remain unchanged.
2. Use read for relevant repo context only when it materially affects the transform.
3. When native inspection leaves a concrete repository-wide impact question, initialize an absent CodeGraph index and map that impact; do not initialize one merely because the transform spans files. Use native search for routine discovery and Serena separately only for a specific exact declaration/reference when it materially improves precision. Use bash with `rg`/`fdfind` for exports, routes, config keys, docs, and generated consumers Serena cannot see.
4. When practical, run the narrowest risk-appropriate check to establish a passing behavioral baseline.
5. Apply the smallest matching transform via Pi native `edit` for routine changes; use Serena symbol ops only for a reference-aware refactor when they materially improve safety or precision.
6. Re-check references with native search, use Serena diagnostics or reference checks only when materially useful, and rerun the baseline check or equivalent narrow verification.
7. Inspect the diff for unintended behavior changes.

When the refactor target is architectural, use concise design vocabulary: interface, seam, adapter, locality, leverage, shallow abstraction, and deletion test. Stop if the work becomes redesign.

## Planner/worker sequencing

Delegated results must report under five fixed headings: "Changed" (paths + brief what), "Verification" (exact commands + outcomes), "Coverage" (acceptance criteria met), "Deviations" (scope changes, assumptions, or "none"), and "Gaps" (unverified/remaining or "none"). Prose may accompany the headings, but every heading must be present.

## Output format

Target, impact, changes, verification, and follow-up risk.

## Rules

- Preserve behavior.
- When an edit anchor (oldText) fails to match, re-read the target region and re-anchor the edit from current content; never blind-retry the same anchor or widen context speculatively.
- Use symbol-aware tools only when a concrete precision or safety benefit remains after native inspection.
- Ask before broad moves or cascading ecosystem changes when they are an unresolved material user-facing choice. In planner or solo/Off work, use `ask_user_question` with 2–4 concrete options, the recommended option first, and the automatic custom-answer row; if unavailable or noninteractive, ask one focused plain-text question. In a two-role worker, ask the assigning planner through Intercom. In planner mode, an actual `ask_user_question` tool call triggers a fixed privacy-safe desktop notification; solo/Off workers emit no planner notifications. Do not use the questionnaire for routine updates or no-choice confirmations.
- Stop if redesign or behavior change appears.
