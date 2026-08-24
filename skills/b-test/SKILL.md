---
name: b-test
description: >
  Test-driven development, test debugging, and test coverage evaluation.
  Use for writing tests, fixing failing tests, evaluating coverage, or
  working TDD-style. Unlike b-debug, which traces runtime bugs, b-test
  owns test-specific failures and simulated-DOM/component-test work: wrong
  assertions, missing mocks, fixture or setup issues, and coverage gaps.
  Real-browser, visual, browser-session, and e2e verification belongs to
  b-browser.
---

<!-- Generated from skills/registry.yaml and skills/b-test/prompt.md. Edit those sources, not this file. -->

# b-test

Own code-level and simulated-DOM tests: add coverage, fix test-only failures, and avoid confusing red tests with product bugs.

## When to use

- The user asks to write tests, fix failing tests, evaluate coverage, or work TDD-style.
- The issue is assertion, mock, fixture, setup, snapshot, or test coverage.
- Non-browser unit, integration, contract, simulated-DOM, and component tests are in scope.

## When NOT to use

- The failing test likely exposes product behavior -> use **b-debug**.
- Real browser, visual, session, or e2e evidence is needed -> use **b-browser**.
- Intended behavior is unclear -> use **b-plan** or **b-debug**.
- A new test framework is needed -> use **b-plan** first.

## Tool guidance

- `bash` - run tests via `rtk` when supported (`rtk pytest`, `rtk vitest`, `rtk jest`, …) and inspect failure output.
- `serena` - after native search/read, use only when a specific test/source
  symbol, reference, or diagnostic materially improves safety or precision; use
  native `read`/`edit`/`write` for routine inspection and edits, and serialize
  requests rather than parallelizing or batching them.
- `read`/`edit` - use Pi native tools for routine and unsupported file work.
- `codegraph` - only for a concrete repository-wide source-to-test impact or affected-test question that native discovery cannot settle; do not initialize an absent local index merely because the change spans files.
- `context7` - versioned test-framework/API semantics only when local tests and contracts do not settle them.

## Steps

1. Find the test framework and narrowest runnable command from manifests, CI, or existing tests (using Bash). Use native inspection and test discovery first. Use CodeGraph only when a concrete repository-wide source-to-test impact question remains; initialize an absent index only for that question, never merely because the change spans files. Use Serena separately only for a specific exact test/source symbol when it materially improves precision.
2. Confirm intended behavior from user intent, product contract, source change, existing passing tests, and materially relevant repo context. Use Context7 only for unresolved versioned framework semantics.
3. For failing tests, run the narrow target, read the test and exercised source, edit tests only after classifying the failure.
4. For new tests, cover requested or changed behavior through the highest practical public interface first; add edge cases only when risk requires them.
5. For explicitly requested TDD, use vertical tracer bullets: add one failing behavior test, make the smallest production change needed to pass it, verify, then continue to the next behavior. Outside explicit TDD, route production changes to **b-implement**.
6. Select affected tests before broad suites: use local search, test discovery, and repository scripts by default. When a current CodeGraph index is already available and a concrete repository-wide impact question remains, ask it for changed-symbol/file impact and affected tests; do not initialize one solely for this selection. Run the narrow affected set first, then expand only when the change or risk requires it.
7. Report the selected tests, whether CodeGraph or fallback discovery supplied them, and any remaining coverage gap. A partial or affected-only run must never be described as full-suite coverage.
8. Run diagnostics when useful, then the narrowest relevant test, and verify the test proves the intended behavior.

## Planner/worker sequencing

Delegated results must report under five fixed headings: "Changed" (paths + brief what), "Verification" (exact commands + outcomes), "Coverage" (acceptance criteria met), "Deviations" (scope changes, assumptions, or "none"), and "Gaps" (unverified/remaining or "none"). Prose may accompany the headings, but every heading must be present.

## Output format

Test scope, changes, verification, and remaining gaps.

## Rules

- Never change production code only because a test is red.
- When an edit anchor (oldText) fails to match, re-read the target region and re-anchor the edit from current content; never blind-retry the same anchor or widen context speculatively.
- Keep production-code changes in **b-implement** unless the user explicitly requested a tightly scoped TDD red-green loop.
- Never update assertions, snapshots, or goldens without confirming intended behavior. If the intended contract is materially unresolved, in planner or solo/Off work use `ask_user_question` with 2–4 concrete intent options (for example, keep the current expectation (`Keep current contract (Recommended)`), adopt the changed behavior, or defer the test change), using the automatic custom-answer row; if unavailable or noninteractive, ask one focused plain-text question. In a two-role worker, ask the assigning planner through Intercom. Planner mode emits exactly one `B_AGENTIC_USER_INPUT_NEEDED` signal; solo/Off workers emit no planner signal. Do not use the questionnaire for routine test-result updates or no-choice confirmations.
- Avoid implementation-coupled tests and mocks derived from buggy implementation instead of the real interface.
- Do not introduce frameworks without approval.
- Keep fixture and mock changes local when practical.
