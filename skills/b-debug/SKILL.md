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
- New scoped frontend/UI work -> use **b-frontend**; a clear non-UI change -> use **b-implement**; an unclear change -> use **b-plan**.

## Tool guidance

- `bash` - reproduce errors and run diagnostics/profilers/checks (`rtk` for test runners and other high-noise families).

- `read`/`edit` - use Pi native tools by default for routine inspection and changes.
- `codegraph` - select when a concrete repository-wide dependency/call-flow or impact question is central to the diagnosis and likely valuable; use an available index for that question and initialize an absent index only for that qualifying question. Spanning files alone never justifies it.
- `context7` - versioned dependency/API behavior only when a library suspect remains after local evidence.
- `recall` - recover compacted repro or prior-diagnosis memory ids when present.

## Capability activation

Do not call external capabilities merely because the symptom spans files. Use repository checks as the fallback when specialized evidence is unavailable. Select CodeGraph when a concrete repository-wide flow or impact question is central to the diagnosis, and use `recall` only for a supplied compacted repro or diagnosis ID. Authentication, Intercom, and usage reporting are unrelated unless explicitly requested.

## Steps

1. Build a feedback loop (using Bash to run commands) that can show the bug: failing test, CLI repro, HTTP script, browser script, trace replay, throwaway harness, fuzz/property loop, or bisect harness.
2. Capture exact symptom, expected vs actual behavior, repro rate, determinism, and environment. Use read for repo context only when it materially affects the diagnosis; use recall when a compacted prior diagnosis id is available.
3. Rank suspects from stack traces, diagnostics, recent changes, config, data shape, call paths, and the feedback loop.
4. Select CodeGraph when a concrete repository-wide flow or impact question is central to the diagnosis and likely valuable; use an available index for that question and initialize an absent index only for that qualifying question. Spanning files alone never justifies initialization. Use Context7 only for versioned dependency suspects.
5. Confirm root cause before fixing. Use probes only when cheaper evidence is insufficient and remove them.
6. If the user asked only to diagnose, explain, or investigate, report the confirmed cause and stop without editing production code.
7. If the request authorizes a fix, apply the smallest change that addresses the confirmed cause via native `edit`/`write`.
8. After a fix, run the original feedback loop or narrowest check proving the intended symptom changed. For perf, measure before and after.
9. If the issue is not yet a confirmed bug, say whether the next step belongs in **b-plan**, **b-research**, or **b-test**.

## Output format

Symptom, root cause, and evidence. When a fix was authorized, also include the fix, verification, and cleanup state. Include a handoff only when the work should continue in another skill.

## Rules

- Do not patch speculatively.
- When an edit anchor (oldText) fails to match, re-read the target region and re-anchor the edit from current content; never blind-retry the same anchor or widen context speculatively.
- Do not bundle redesign or cleanup.
- If no trustworthy feedback loop can be built, report what you tried and what artifact/access is needed instead of guessing.
- Verify probe removal before reporting success.
