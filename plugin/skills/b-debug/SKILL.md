---
name: b-debug
description: >
  Systematic hypothesis-driven debugging for runtime bugs, errors, broken
  behavior, slow paths, memory issues, and stack traces. Traces execution
  and confirms root cause, then fixes minimally only when the user
  authorized a fix. Diagnosis-only requests stop after reporting the cause
  and evidence. When the issue is not yet a confirmed product bug, it
  should hand off cleanly instead of guessing. Unlike b-test, b-debug owns
  runtime behavior failures, not test-mechanic issues such as wrong
  assertions, mocks, or fixtures.
---

<!-- Generated from skills/registry.yaml and skills/b-debug/prompt.md. Edit those sources, not this file. -->

# b-debug

Find the real cause of broken behavior, then fix it minimally only when the user authorized a fix. Hand off cleanly if the problem turns out to be planning or external knowledge instead.

## When to use

- The user reports a runtime bug, broken behavior, error, stack trace, race, memory issue, or slowdown.
- A failing test likely exposes a real product bug.

## When NOT to use

- The problem is only a test assertion, mock, fixture, or setup issue -> use **b-test**.
- The task is external docs/API lookup only -> use **b-research**.
- The task is new scoped work -> use **b-plan** or **b-implement**.

## Tool guidance

- `Bash` - reproduce errors and run diagnostics/profilers/checks (`rtk` for test runners and other high-noise families).
- `serena` - after native search/Read, use only when a concrete exact-symbol,
  reference, implementation, or diagnostic/refactor need remains and semantic
  tooling materially improves safety or precision. Use native
  `Read`/`Edit`/`Write` for routine work; serialize requests rather than
  parallelizing or batching them.
- `Read`/`Edit` - use Claude Code native tools by default for routine inspection and changes; also use them for unsupported files or as a fallback when Serena precision work fails.
- `codegraph` - only for a concrete repository-wide dependency/call-flow or impact question that native inspection cannot settle; do not initialize an absent local index merely because the suspect spans files.
- `context7` - versioned dependency/API behavior only when a library suspect remains after local evidence.
- Claude Code compaction and session context - recover prior diagnosis context when present.

## Steps

1. Build a feedback loop (using Bash to run commands) that can show the bug: failing test, CLI repro, HTTP script, browser script, trace replay, throwaway harness, fuzz/property loop, or bisect harness.
2. Capture exact symptom, expected vs actual behavior, repro rate, determinism, and environment. Use Read for repo context only when it materially affects the diagnosis; use Claude Code compaction/session context when prior diagnosis details are available.
3. Rank suspects from stack traces, diagnostics, recent changes, config, data shape, call paths, and the feedback loop.
4. When native inspection leaves a concrete repository-wide flow or impact question, initialize an absent CodeGraph index and use it for that question; do not initialize one merely because the suspect spans files. Use Serena separately only for a specific exact symbol or diagnostic when that materially improves precision. Use Context7 only for versioned dependency suspects, and serialize rather than parallelize or batch Serena calls.
5. Confirm root cause before fixing. Use probes only when cheaper evidence is insufficient and remove them.
6. If the user asked only to diagnose, explain, or investigate, report the confirmed cause and stop without editing production code.
7. If the request authorizes a fix, apply the smallest change that addresses the confirmed cause via native `Edit`/`write`, or Serena only for a reference-aware symbol refactor.
8. After a fix, run the original feedback loop or narrowest check proving the intended symptom changed. For perf, measure before and after.
9. If the issue is not yet a confirmed bug, say whether the next step belongs in **b-plan**, **b-research**, or **b-test**.

## Output format

Symptom, root cause, and evidence. When a fix was authorized, also include the fix, verification, and cleanup state. Include a handoff only when the work should continue in another skill.

## Rules

- Do not patch speculatively.
- Do not bundle redesign or cleanup.
- If no trustworthy feedback loop can be built, report what you tried and what artifact/access is needed instead of guessing.
- Verify probe removal before reporting success.
