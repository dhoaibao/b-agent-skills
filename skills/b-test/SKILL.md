---
name: b-test
description: >
  Test-driven development, test debugging, and test coverage evaluation. ALWAYS invoke
  when the user asks about writing tests, fixing failing tests, test coverage gaps,
  or TDD: "test", "viết test", "failing test", "test đang fail", "bắt đầu bằng test",
  "test coverage", "missing test".
  Unlike b-debug (traces runtime bugs), b-test focuses on test-specific failures:
  wrong assertions, missing mocks, setup issues, coverage gaps.
effort: medium
---

# b-test

$ARGUMENTS

Dedicated skill for test-driven development, test debugging, and coverage evaluation.
Failing CI test and runtime bug have different patterns — this skill owns the test path.

If `$ARGUMENTS` is provided, treat it as the test task or failing test symptom.
Proceed directly. Do not ask "what test do you want to write?" unless `$ARGUMENTS`
is empty.

## When to use

- User asks to write tests for new or existing code.
- A test is failing and the issue is assertion, mock, or setup — not runtime logic.
- Evaluating whether test coverage is adequate for a behavior change.
- User says: "test", "viết test", "test case", "failing test", "test coverage",
  "TDD", "unit test", "integration test", "test đang fail", "bắt đầu bằng test",
  "missing test".

## When NOT to use

- Runtime bug in production code → use **b-debug**
- Need a plan for a feature → use **b-plan**
- Review code before PR → use **b-review**
- Quick library API lookup → use **b-research**

## Tools required

- `Bash` — run test commands, inspect test output
- `check_onboarding_performed`, `onboarding`, `find_symbol`, `get_symbols_overview`, `find_referencing_symbols` — from `serena` MCP server *(required for discovering test files and mapping tests to source symbols)*
- `resolve-library-id`, `query-docs` — from `context7` MCP server *(optional, for verifying testing framework API — jest, vitest, pytest, etc.)*
- `sequentialthinking` — from `sequential-thinking` MCP server *(optional, for choosing test strategy: unit vs integration vs e2e)*

If Serena is unavailable: use Bash to find test files (`find`, `ls`) and `Read` for inspection. Note: "⚠️ Serena unavailable — test discovery via file listing."
If sequential-thinking is unavailable: choose test strategy inline with explicit pros/cons list.

Graceful degradation: ✅ Possible — core test debugging works with Bash + Read.

## Steps

### Step 1 — Discover test structure

Find test files and understand the test setup:

1. Use Bash to locate test files and identify the testing framework:
   ```bash
   # Common patterns
   find . -name "*.test.*" -o -name "*.spec.*" | head -20
   cat package.json | grep -A2 '"test"'
   ```
   (Adapt pattern for Python, Go, Java, Rust — `find` test files with language conventions.)

2. Call `check_onboarding_performed`. If false, call `onboarding`.

3. Call `get_symbols_overview` on relevant test files to see test structure
   (describe blocks, test functions, setup/teardown, shared fixtures).

4. Call `find_symbol` on the test name or describe block if the user mentioned a specific test.

5. If the user mentions "missing test" or "write tests for X": call `find_symbol`
   on the source code symbol that needs tests, then `find_referencing_symbols`
   to see if it already has tests.

**Goal**: know the framework, the test file structure, and the relationship between
tests and source code.

---

### Step 2 — Analyze the problem

**Branch A: Failing test**

1. Read the failing test output via Bash:
   ```bash
   npm test 2>&1 | tail -50
   # or
   pytest -x 2>&1 | tail -30
   ```
2. Read the failing test code with `Read` (narrow section, not full file).
3. Read the source code under test (the function/class being tested).
4. Identify the gap between expected and actual:
   - Wrong assertion? (expected value is wrong)
   - Missing mock? (dependency not stubbed → real call fails)
   - Setup/teardown issue? (state leaking between tests)
   - Async timing? (missing await, promise not resolved)
   - Wrong test data? (input does not match realistic scenario)

**Branch B: Write tests (TDD or coverage gap)**

1. Identify what behavior needs testing:
   - If from a plan file: read the plan's acceptance criteria
   - If from `$ARGUMENTS`: parse the behavior description
   - If from source code: read the source symbol, list its branches and edge cases
2. Use `sequentialthinking` to choose test strategy:
   - Pure function → unit test
   - DB interaction → integration test
   - User workflow → e2e or integration test
   - Existing tests → determine what gaps remain

---

### Step 3 — Fix or write the test

**Branch A: Fix failing test**

Apply the minimal fix:

| Symptom | Fix |
|---|---|
| Wrong expected value | Update assertion to match correct output |
| Missing mock | Add mock/stub for the dependency |
| Leaking state | Reset state in `beforeEach` or `afterEach` |
| Async timing | Add `await`, return promise, or use `waitFor` |
| Wrong test data | Provide realistic input matching the scenario |

Prefer symbol-aware edits (`replace_symbol_body` for test functions) over line-level
`Edit` when changing whole test functions. Use `insert_before_symbol` to add new tests
in a describe block.

**Branch B: Write new tests**

Write tests that cover:
- Happy path (normal input → expected output)
- Edge cases (empty input, boundary values, null/undefined)
- Error path (invalid input → error thrown/rejected)
- Regression prevention (would catch a revert of the current change)

Use `insert_before_symbol` or `insert_after_symbol` to add tests within existing describe
blocks. Use the repo's supported file-writing tools to create a new test file when no suitable file exists.

**Framework-specific conventions**:
- Jest/Vitest: `describe/it`, `beforeEach`, `mock()`
- Pytest: `def test_*`, fixtures, `monkeypatch`
- Go: `Test*` with `t.Run`, `assert.Equal`
- Rust: `#[test]`, `assert_eq!`

---

### Step 4 — Run and verify

1. Run the specific test(s) via Bash:
   ```bash
   npm test -- --testNamePattern="test name"
   pytest path/to/test.py::test_function
   go test -run TestFunction ./pkg
   cargo test test_function
   ```
2. Confirm the test passes.
3. For new tests: run the full suite via Bash to confirm no regressions.
4. For coverage evaluation: run coverage report via Bash.
   ```bash
   npm test -- --coverage
   pytest --cov=.
   go test -cover ./...
   ```
5. If tests fail: go back to Step 2. Maximum 3 iterations.

---

## Output format

```
### b-test: [test task]

**Type**: [write tests / fix failing test / evaluate coverage]
**Framework**: [jest / vitest / pytest / go test / cargo test]
**Test scope**: [unit / integration / e2e]

#### Test structure
- [test file path] — [describe blocks or test functions found]

#### Issue / Requirements
[what was wrong or what behavior needs testing]

#### Fix / Implementation
[code change — exact assertion, mock, or test added]

#### Verification
```bash
[test command and result]
```
✅ Test passes / ❌ Test still failing — [next step]

---

#### Coverage
*(skip if not evaluating coverage)*
- Before: [X%] lines
- After: [Y%] lines
- Gaps: [what is still not covered]
```

---

## Rules

- Never modify production code to make a test pass unless the production code is actually buggy.
- A failing test often reveals a bug in production code → if analysis confirms a real bug,
  fix production code via symbol-aware edits, then re-run the test.
- Keep test fixes minimal — if one assertion is wrong, fix that assertion; do not rewrite
  the entire test suite.
- Write behavior tests (assert on output), not implementation tests (assert on internal state).
- Use `sequentialthinking` for test strategy decisions (unit vs integration) only if the
  choice is genuinely ambiguous.
- Never trigger destructive git commands.
- If the test output is truncated in the terminal: increase verbosity or pipe to a file
  then `Read` the file.
- Prefer running specific tests over the full suite during debugging — faster feedback loop.