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

- `bash` - reproduce errors and run diagnostics/profilers/checks (`rtk` for test runners and other high-noise families).
- `read`/`edit` - inspect and apply minimal authorized fixes.
- `codegraph` - initialize an absent local index on first relevant use, then trace call paths, flows, and impact.
- `serena` - symbols, call sites, implementations, diagnostics, and approval-gated symbol edits when a fix is authorized; ask before onboarding or persistent memory writes.
- `context7` - versioned dependency/API behavior only when a library suspect remains after local evidence.
- `recall` - recover compacted repro or prior-diagnosis memory ids when present.

## Steps

1. Build a feedback loop (using Bash to run commands) that can show the bug: failing test, CLI repro, HTTP script, browser script, trace replay, throwaway harness, fuzz/property loop, or bisect harness.
2. Capture exact symptom, expected vs actual behavior, repro rate, determinism, and environment. Use read for repo context only when it materially affects the diagnosis; use recall when a compacted prior diagnosis id is available.
3. Rank suspects from stack traces, diagnostics, recent changes, config, data shape, call paths, and the feedback loop.
4. For cross-file code suspects, initialize an absent CodeGraph index; use CodeGraph for call paths or impact, then Serena for exact symbols and diagnostics. Use Context7 only for versioned dependency suspects.
5. Confirm root cause before fixing. Use probes only when cheaper evidence is insufficient and remove them.
6. If the user asked only to diagnose, explain, or investigate, report the confirmed cause and stop without editing production code.
7. If the request authorizes a fix, apply the smallest change that addresses the confirmed cause via edit or Serena symbol ops.
8. After a fix, run the original feedback loop or narrowest check proving the intended symptom changed. For perf, measure before and after.
9. If the issue is not yet a confirmed bug, say whether the next step belongs in **b-plan**, **b-research**, or **b-test**.

## Output format

Symptom, root cause, and evidence. When a fix was authorized, also include the fix, verification, and cleanup state. Include a handoff only when the work should continue in another skill.

## Rules

- Do not patch speculatively.
- Do not bundle redesign or cleanup.
- If no trustworthy feedback loop can be built, report what you tried and what artifact/access is needed instead of guessing.
- Verify probe removal before reporting success.
