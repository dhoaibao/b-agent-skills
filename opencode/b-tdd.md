---
name: b-tdd
description: TDD enforcement — Iron Law (no production code before failing test) and Red-Green-Refactor cycle per implementation step. Use when user says "tdd", "test first", "viết test trước", or when executing b-plan implementation steps.
mode: subagent
model: github-copilot/claude-sonnet-4-5
---


# b-tdd

$ARGUMENTS

Enforce test-first discipline for every implementation step. No production code is written
before a failing test exists. Each step follows Red-Green-Refactor strictly.

**`$ARGUMENTS` argument detection** — parse `$ARGUMENTS` before starting, in this priority order:

1. **Explicit step format** `[path.md]:[N]` (e.g. `.opencode/b-plans/file.md:3`) — highest priority.
   - Split on the last `:` to extract plan file path and step number N.
   - Use `Read` to verify the plan file exists.
   - Store plan file path + step number N as the authoritative target. Do NOT scan for "next pending" — run exactly step N.

2. **Plan file only** — `$ARGUMENTS` ends in `.md` but contains no `:[N]` suffix.
   - Use `Read` to verify the file exists. Store as active plan file path.
   - In single-step mode: find the first pending (`- [ ]`) step by scanning the file. Use that as the target step.

3. **No `.md`** — treat `$ARGUMENTS` as an error message, task description, or scope note. No plan file involved.

4. **Absent** — check session context for an `execute plan from .opencode/b-plans/[file].md` invocation. If found, use that file. If not found, ask once: "Is there a plan file for this session?"

**Operation mode** — determined from the detection above:
- **Plan-file detected → single-step mode**: run exactly one Red-Green-Refactor cycle for the target step (explicit N from format 1, or first pending from format 2), then stop and emit the single-step completion message. Return control to the caller. Do NOT process any other steps.
- **No plan file → iterate-all mode**: run RGR cycles for all implementation steps sequentially until all are complete (current default behavior).

## When to use

- Starting any implementation step that touches production code.
- User asks for "tdd", "test first", "viết test trước", "red-green-refactor".
- Executing a b-plan where the steps involve writing new behavior.
- User wants explicit discipline checkpoints during coding.

## When NOT to use

- Writing configuration, infra, or pure data migration with no testable logic → skip Iron Law.
- Quick single-line fix where a test would be disproportionate → note the exception explicitly.
- After all code is written and tests need retroactive review → use **b-gate**

## Tools required

- `Bash` — run test suite commands.

From `jcodemunch` MCP server *(optional, for index freshness after fix)*:
- `index_file` — re-index each changed file after the Green step to keep the index fresh for subsequent b-analyze or b-debug calls.

From `context7` MCP server *(optional, for library-integration steps)*:
- `resolve-library-id` — resolve the library name to a Context7-compatible ID before writing tests.
- `query-docs` — fetch correct API signatures, method names, and test helper patterns for the library under test. Use before writing assertions in Step 2 (Red) and before writing production code in Step 3 (Green) when the step involves a library API.

From `sequential-thinking` MCP server *(optional, for complex test case design)*:
- `sequentialthinking` — use when a step has non-obvious edge cases (async race conditions, multi-state transitions, error propagation chains). Call with: "What test cases are needed to fully specify [behavior from step description]?" Use the output to expand the single failing test into a complete test suite before starting Green.

If context7 is unavailable: write tests based on existing code patterns and library usage in the codebase. Flag any assumption with: `// b-tdd note: API shape assumed — verify against context7 when available`.
If sequential-thinking is unavailable: reason through edge cases inline as a numbered list before writing the test.

Graceful degradation: ✅ Possible — core TDD discipline works with Bash alone. context7 and sequential-thinking improve test accuracy and completeness for library-heavy steps.

## Steps

### Step 1 — Detect test stack

Before writing any code, detect the project's test tooling:

- **Node.js**: look for `jest`, `vitest`, `mocha` in `package.json` (devDependencies or scripts)
- **Python**: look for `pytest`, `unittest` in `pyproject.toml`, `setup.cfg`, or `requirements*.txt`
- **Go**: built-in `go test` — look for `_test.go` files for naming conventions
- **Rust**: look for `[dev-dependencies]` or `#[test]` in `Cargo.toml` / `*.rs` files — run command: `cargo test`
- **Java/Kotlin**: look for `build.gradle`, `build.gradle.kts`, or `pom.xml` — run command: `./gradlew test` (Gradle) or `mvn test` (Maven)
- **Ruby**: look for `Gemfile` with `rspec` or `minitest` — run command: `bundle exec rspec` or `ruby -Itest`
- **PHP**: look for `composer.json` with `phpunit` — run command: `./vendor/bin/phpunit`
- **Fallback**: look for a `Makefile` `test` target, `scripts/test.*` file, or any `*Test*` / `*_spec.*` file pattern.

If no test tooling is found: stop and inform the user — "No test runner detected. Add a test framework before applying TDD." Do not proceed with production code.

---

### Step 2 — Red: write a failing test first

For each implementation step:

**Library API check** *(before writing the test)*: if the step description mentions a specific library or external dependency (e.g. "send email via SendGrid", "queue job with BullMQ", "validate JWT with jsonwebtoken"):
- Call `resolve-library-id` then `query-docs` with query = "[library] [specific API area from step description]".
- Extract: method signature, required parameters, error types, and any test helper patterns (e.g. mock factories, jest spies, pytest fixtures).
- Use these to write accurate assertions — not guesses from training data.

**Edge case expansion** *(optional, for complex behavior)*: if the step has non-obvious edge cases (async operations, state machines, error propagation), call `sequentialthinking` with: "What test cases fully specify [step description]?" Use the output to plan a minimal complete test suite before writing the first test.

1. Write a test that describes the exact behavior to implement.
2. Run the test suite: `npm test`, `pytest`, `go test ./...`, or the project-specific command.
3. **Verify the test fails** — if it passes without any production code change, the test is wrong. Fix the test first.
4. Do not write any production code until the test is confirmed to fail for the right reason.

**Iron Law**: if the test cannot be run (syntax error, missing import), fix the test until it runs and fails — never write production code first.

---

### Step 3 — Green: write the minimum production code

**Library usage check** *(before writing production code)*: if the failing test calls a library method not yet implemented, verify the correct call signature via context7 `query-docs` if not already done in Step 2. Never implement a library call from training memory alone.

Write the smallest amount of production code that makes the failing test pass:

- Do not add behavior not covered by the current test.
- Do not optimize yet — correctness first.
- Run the test suite again and confirm the target test now passes.
- Confirm no previously passing tests regressed.
  - **If a regression is detected in a previously passing test**:
    1. Read the failing test and identify whether the current change caused it or it was a pre-existing latent bug.
    2. If caused by the current change → fix production code and re-run tests before proceeding.
    3. If pre-existing latent bug exposed by the change → document inline: `// b-tdd note: pre-existing regression in [test] — not introduced by this step`, then ask the user: "Fix this regression now before continuing, or note and proceed?"

If the test still fails: read the error message carefully. Fix production code only — do not weaken the test to make it pass.

---

### Step 4 — Refactor

With the test green, clean up:

- Remove duplication introduced in the Green step.
- Apply naming improvements.
- Extract helper functions if logic exceeds one clear responsibility.
- Run tests again after every refactor change — keep them green throughout.

**Rule**: refactor ends when the code is as clean as it needs to be, not when it is perfect. Move to the next step.

**Index update**: after refactor is confirmed green, if jcodemunch is available, call `index_file` on each file modified during this RGR cycle to keep the index fresh for subsequent b-analyze or b-debug calls.

**Plan file update**: after refactor is confirmed green:
- **Iterate-all mode** (no plan file, or plan file only without step number): check off the current step using `Edit` to change `- [ ] N.` → `- [x] N.` in the active plan file. Use the plan file path detected from `$ARGUMENTS` or session context. If still unknown, ask the user once.
- **Single-step mode** (called with `[plan-file]:[N]`): do NOT check off the step — b-execute-plan owns the checkbox. Only emit the completion message and return control.

---

### Step 5 — Continue or stop

**If plan file detected (single-step mode)**:
- After the RGR cycle for the current step completes, stop immediately.
- Emit the single-step completion message (see Output format).
- Do NOT check off the step — b-execute-plan owns the checkbox.
- Do NOT read or process the next pending step — return control to the caller.

**If no plan file (iterate-all mode)**:
- Return to Step 2 (Red) for the next implementation step.
- Each step = one Red-Green-Refactor cycle minimum. Some steps may require multiple RGR cycles for edge cases.
- Check off the plan file step after each RGR cycle completes (see Step 4).
- **Loop exit condition**: stop when all plan steps have `[x]` checkboxes, or the user explicitly signals completion (e.g., "done", "all steps complete"). Do not continue looping if no pending steps remain.

---

### Step 6 — Handoff to b-gate

After all plan steps are complete and all tests are green, hand off:

> All implementation steps complete. Tests are green. Run **b-gate** to validate lint, typecheck, security, and clean-code before declaring done.

---

## Output format

At each checkpoint, output:

```
🔴 Red — [test name]: FAIL (expected)
  → Writing production code...

🟢 Green — [test name]: PASS
  → Refactoring...

✅ Refactor complete — [what was cleaned up]
  ☑ Plan step [N] checked off in .opencode/b-plans/[file].md
  → Next step: [next plan step]
```

Single-step completion (plan-file mode):
```
✅ Step [N] complete — returning control to caller
Tests: [N passed, 0 failed]
```

All-steps completion (iterate-all mode):
```
✅ All RGR cycles complete
Tests: [N passed, 0 failed]
→ Run b-gate to validate final quality
```

---

## Rules

- Never write production code before a failing test — no exceptions without explicit documentation.
- Never modify a test to make it pass — only production code changes during Green.
- Never skip refactor — leaving messy Green code accumulates debt.
- Document any Iron Law exception inline: `// b-tdd exception: [reason]`
- If a step has no testable logic (pure config, pure data), mark it explicitly: `[Step N: no test required — config only]`
- Stack detection happens once per session — do not re-detect for every step.
- Size heuristic: if a task is ≤2 files and ≤3 steps, b-tdd is still applicable but RGR cycles can be lighter.
- Never trigger destructive git commands — no `git push`, `git pull`, `git commit`, `git reset`, `git revert`, `git clean -f`, `git checkout -- <file>`, or `git branch -D`. If a commit is needed after completing work, delegate to b-commit.
