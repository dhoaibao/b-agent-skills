---
name: b-tdd
policy:
  allow_implicit_invocation: true
description: >
  TDD enforcement — Iron Law (no production code before failing test) and Red-Green-Refactor
  cycle per implementation step. ALWAYS use when the user says "tdd", "test first",
  "viết test trước", "red-green-refactor", or when executing b-plan steps that touch
  production code without first writing a failing test. Distinct from b-gate: b-tdd
  governs discipline before and during coding; b-gate validates after.
---

# b-tdd

Enforce test-first discipline for every implementation step. No production code is written
before a failing test exists. Each step follows Red-Green-Refactor strictly.

> ⚠️ **Codex cloud sandbox note**: b-tdd runs shell commands to execute test suites. In Codex
> cloud mode, some test runners or system tools may be unavailable or behave differently from
> a local dev environment. Run Codex locally for full b-tdd support.

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

No MCP tools required. Uses `Bash` for running tests.

Graceful degradation: ✅ Possible — this skill is pure discipline enforced via process, no external tools needed.

## Steps

### Step 1 — Detect test stack

Before writing any code, detect the project's test tooling:

- **Node.js**: look for `jest`, `vitest`, `mocha` in `package.json` (devDependencies or scripts)
- **Python**: look for `pytest`, `unittest` in `pyproject.toml`, `setup.cfg`, or `requirements*.txt`
- **Go**: built-in `go test` — look for `_test.go` files for naming conventions.
- **Other**: look for a `Makefile` `test` target or `scripts/test.*` file.

If no test tooling is found: stop and inform the user — "No test runner detected. Add a test framework before applying TDD." Do not proceed with production code.

---

### Step 2 — Red: write a failing test first

For each implementation step:

1. Write a test that describes the exact behavior to implement.
2. Run the test suite: `npm test`, `pytest`, `go test ./...`, or the project-specific command.
3. **Verify the test fails** — if it passes without any production code change, the test is wrong. Fix the test first.
4. Do not write any production code until the test is confirmed to fail for the right reason.

**Iron Law**: if the test cannot be run (syntax error, missing import), fix the test until it runs and fails — never write production code first.

---

### Step 3 — Green: write the minimum production code

Write the smallest amount of production code that makes the failing test pass:

- Do not add behavior not covered by the current test.
- Do not optimize yet — correctness first.
- Run the test suite again and confirm the target test now passes.
- Confirm no previously passing tests regressed.

If the test still fails: read the error message carefully. Fix production code only — do not weaken the test to make it pass.

---

### Step 4 — Refactor

With the test green, clean up:

- Remove duplication introduced in the Green step.
- Apply naming improvements.
- Extract helper functions if logic exceeds one clear responsibility.
- Run tests again after every refactor change — keep them green throughout.

**Rule**: refactor ends when the code is as clean as it needs to be, not when it is perfect. Move to the next step.

**Plan file update**: after refactor is confirmed green, check off the current step in the plan file. Use the `Edit` tool to change `- [ ] N.` → `- [x] N.` in `.agents/plans/[task-slug].md`. If the plan file path is not known, check the current session context (the session was opened with `execute plan from .agents/plans/[file].md`). If still unknown, ask the user once.

---

### Step 5 — Repeat per plan step

For each remaining implementation step in the plan:

- Return to Step 2 (Red) for the next behavior.
- Each b-plan step = one Red-Green-Refactor cycle minimum.
- Some plan steps may require multiple RGR cycles for edge cases — that is expected.
- Check off the plan file step after each RGR cycle completes (see Step 4)

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
  ☑ Plan step [N] checked off in .agents/plans/[file].md
  → Next step: [next plan step]
```

At completion:
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
