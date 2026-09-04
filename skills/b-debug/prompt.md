# b-debug

Find the real cause of broken behavior, then fix it minimally only when the user authorized a fix. Hand off cleanly if the problem turns out to be planning or external knowledge instead.

## When to use

- The user reports a runtime bug, broken behavior, error, stack trace, race, memory issue, or slowdown.
- A failing test likely exposes a real product bug.

## When NOT to use

- The problem is only a test assertion, mock, fixture, or setup issue -> use **b-test**.
- The task is external docs/API lookup only -> use **b-research**.
- New scoped frontend/UI work -> use **b-frontend**; a clear non-UI change -> use **b-implement**; an unclear change -> use **b-plan**.

## Tool guidance

- `bash` - reproduce errors and run diagnostics/profilers/checks (`rtk` for test runners and other high-noise families).
- `serena` - after native search/read, use only when a concrete exact-symbol,
  reference, implementation, or diagnostic/refactor need remains and semantic
  tooling materially improves safety or precision. Use native
  `read`/`edit`/`write` for routine work; serialize requests rather than
  parallelizing or batching them.
- `lsp_diagnostics` / `lsp_fix` - after reproducing the issue, use diagnostics on changed source when a relevant server is ready; use source actions only with explicit authorization, and fall back to repository checks when unavailable.
- `read`/`edit` - use Pi native tools by default for routine inspection and changes; also use them for unsupported files or as a fallback when Serena precision work fails.
- `codegraph` - only for a concrete repository-wide dependency/call-flow or impact question that native inspection cannot settle; do not initialize an absent local index merely because the suspect spans files.
- `context7` - versioned dependency/API behavior only when a library suspect remains after local evidence.
- `recall` - recover compacted repro or prior-diagnosis memory ids when present.

## Capability activation

Do not call external capabilities merely because the symptom spans files. Use LSP diagnostics for supported changed source when a relevant server is ready, then use repository checks as the fallback. Use Serena for a concrete semantic ownership or diagnostic question after native inspection, CodeGraph only for a concrete repository-wide flow or impact question, and `recall` only for a supplied compacted repro or diagnosis ID. Authentication, Intercom, and usage reporting are unrelated unless explicitly requested.

## Steps

1. Build a feedback loop (using Bash to run commands) that can show the bug: failing test, CLI repro, HTTP script, browser script, trace replay, throwaway harness, fuzz/property loop, or bisect harness.
2. Capture exact symptom, expected vs actual behavior, repro rate, determinism, and environment. Use read for repo context only when it materially affects the diagnosis; use recall when a compacted prior diagnosis id is available.
3. Rank suspects from stack traces, diagnostics, recent changes, config, data shape, call paths, and the feedback loop.
4. When native inspection leaves a concrete repository-wide flow or impact question, initialize an absent CodeGraph index and use it for that question; do not initialize one merely because the suspect spans files. Use Serena separately only for a specific exact symbol or diagnostic when that materially improves precision. Use Context7 only for versioned dependency suspects, and serialize rather than parallelize or batch Serena calls.
5. Confirm root cause before fixing. Use probes only when cheaper evidence is insufficient and remove them.
6. If the user asked only to diagnose, explain, or investigate, report the confirmed cause and stop without editing production code.
7. If the request authorizes a fix, apply the smallest change that addresses the confirmed cause via native `edit`/`write`, or Serena only for a reference-aware symbol refactor.
8. After a fix, run the original feedback loop or narrowest check proving the intended symptom changed. For perf, measure before and after.
9. If the issue is not yet a confirmed bug, say whether the next step belongs in **b-plan**, **b-research**, or **b-test**.

## Planner/worker sequencing

Delegated results must report under five fixed headings: "Changed" (paths + brief what), "Verification" (exact commands + outcomes), "Coverage" (acceptance criteria met), "Deviations" (scope changes, assumptions, or "none"), and "Gaps" (unverified/remaining or "none"). Prose may accompany the headings, but every heading must be present.

## Output format

Symptom, root cause, and evidence. When a fix was authorized, also include the fix, verification, and cleanup state. Include a handoff only when the work should continue in another skill.

## Rules

- Do not patch speculatively.
- When an edit anchor (oldText) fails to match, re-read the target region and re-anchor the edit from current content; never blind-retry the same anchor or widen context speculatively.
- Do not bundle redesign or cleanup.
- If no trustworthy feedback loop can be built, report what you tried and what artifact/access is needed instead of guessing.
- Verify probe removal before reporting success.
