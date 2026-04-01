---
name: b-gate
description: Mandatory quality gate — stack-aware ordered checks lint → typecheck → tests → security → clean-code. Use after all implementation steps complete or when user says "gate", "check quality", "kiểm tra chất lượng".
mode: subagent
model: github-copilot/claude-haiku-4-5
---

## Tool Mapping (read before following instructions below)

When instructions reference these Claude Code tools, use the OpenCode equivalent:

| Claude Code | OpenCode equivalent |
|---|---|
| `Read` / `Glob` / `Grep` | Read files natively |
| `Edit` / `Write` | Edit files natively |
| `Bash` | Run bash commands natively |
| `Skill tool` → `/b-[name]` | Invoke `@b-[name]` subagent |
| `Agent tool` | Spawn subagent via task tool |
| `TaskCreate` / `TaskUpdate` | Skip — plan file manages state |

---


# b-gate

$ARGUMENTS

Run the mandatory quality gate before declaring implementation complete. Detects stack from
config files and runs only checks that are configured. Blocks on any failure — no partial passes.

If `$ARGUMENTS` is provided, treat it as a space-separated list of file paths or directories to scope the gate to (e.g. `src/auth/ src/middleware/`). If omitted, run against all changed files in the working tree.

## When to use

- After all implementation steps in a b-plan session are complete.
- User says "gate", "b-gate", "check quality", "kiểm tra chất lượng", "validate before done".
- Before opening a PR or handing off to code review.
- Any time the user wants a final quality check on changed code.

## When NOT to use

- During implementation (writing code, making incremental changes) → use **b-tdd** instead.
- Deep code quality analysis or architecture review → use **b-analyze**
- Debugging a broken feature → use **b-debug**

## Tools required

- `Bash` — to run lint, typecheck, test, and security commands.

No MCP tools required.

Graceful degradation: ✅ Possible — b-gate runs whatever tools are present. If no tools are configured, it reports what is missing rather than silently passing.

## Steps

### Step 1 — Detect stack and configured checks

Scan the project root for config files to determine which checks are available:

| Check | Config indicators |
|---|---|
| **Lint** | `.eslintrc*`, `.eslintrc.json`, `eslint.config.*`, `.flake8`, `ruff.toml`, `pyproject.toml [tool.ruff]`, `.golangci.yml` |
| **Typecheck** | `tsconfig.json`, `mypy.ini`, `pyproject.toml [tool.mypy]` |
| **Tests** | `jest.config.*`, `vitest.config.*`, `pytest.ini`, `pyproject.toml [tool.pytest]`, `*_test.go` files, `Makefile` with `test` target |
| **Security** | `npm audit` (if `package-lock.json` exists), `pip-audit` (if `requirements*.txt` exists), `govulncheck` (if Go project) |
| **Clean code** | `prettier --check` (if `.prettierrc*` exists), `black --check` (if `pyproject.toml [tool.black]` or `.black` config exists), `gofmt -l` (Go) |
| **Coverage** | `jest.config.*` or `package.json` jest field with `coverageThreshold`; `setup.cfg` or `pyproject.toml [tool.coverage.report]` with `fail_under`; `.nycrc` or `nyc` field in `package.json`; `*_test.go` files (Go — soft-block only, no native threshold) |
| **Integration/E2E** | Jest files matching `*integration*` or `*e2e*`, pytest `integration` marker in config, `Makefile` with `test-integration` or `test-e2e` target, vitest project named `e2e` |

For each check: if no config file is found, skip the check and note it as "not configured" — do not fail because of missing tooling.

---

### Step 2 — Run checks in order

Run each configured check in this fixed order. **Stop on first failure** (hard stops: 2a–2d). Exception: **2f (Integration/E2E) is a soft block — reports warnings and continues regardless of outcome.**

#### 2a. Lint

```bash
# Node.js
npx eslint . --max-warnings=0

# Python (ruff preferred, flake8 fallback)
ruff check .
# or: flake8 .

# Go
golangci-lint run
```

If lint fails: output the errors, stop. Do not proceed to typecheck.

#### 2b. Typecheck

```bash
# TypeScript
npx tsc --noEmit

# Python
mypy .

# Go — type safety is guaranteed by the compiler; run build instead
go build ./...
```

If typecheck fails: output the errors, stop. Do not proceed to tests.

#### 2c. Tests

```bash
# Node.js
npm test
# or: npx jest --passWithNoTests
# or: npx vitest run

# Python
pytest

# Go
go test ./...
```

If tests fail: output the failure summary, stop. Do not proceed to coverage.

#### 2c.5. Coverage

Run after tests pass. Behavior depends on whether a coverage threshold is configured:

**Hard-block** (fail the gate) if a coverage threshold is explicitly configured AND actual coverage falls below it:

```bash
# Node.js (jest) — reads coverageThreshold from jest.config.* or package.json jest field
npm test -- --coverage

# Node.js (nyc) — reads threshold from .nycrc or package.json nyc field
nyc npm test

# Python (pytest-cov) — reads fail_under from setup.cfg [coverage:report] or pyproject.toml [tool.coverage.report]
pytest --cov --cov-fail-under=$(grep fail_under setup.cfg | awk -F= '{print $2}' | tr -d ' ')
# or: pytest --cov  (pytest-cov reads fail_under automatically from config)
```

**Soft-warn** (report warning, continue) if a coverage tool is detected but no explicit threshold is configured:

```bash
# Run coverage and report the percentage — do not fail
npm test -- --coverage --coverageThreshold='{}'
# or: pytest --cov
```

**Skip entirely** if no coverage tool is detected for the stack.

**Go note**: Go has no native coverage threshold enforcement. If `*_test.go` files are present, run `go test -coverprofile=coverage.out ./...` and report the total coverage percentage as a soft warning only — never hard-block.

If coverage hard-blocks: output the coverage report showing which files/lines are below threshold. Stop. Do not proceed to security.

#### 2d. Security

```bash
# Node.js
npm audit --audit-level=high

# Python
pip-audit

# Go
govulncheck ./...
```

If high/critical vulnerabilities found: output them, stop. Do not proceed to clean-code.

Only block on **high** or **critical** severity. Report medium/low as warnings and continue.

#### 2e. Clean code

```bash
# JS/TS
npx prettier --check .

# Python
black --check .

# Go
gofmt -l .
# (non-empty output = unformatted files)
```

If formatting check fails: output the files that need formatting. This is a soft block — report as a warning rather than stopping (formatting can be auto-fixed without logic risk).

#### 2f. Integration/E2E tests *(soft block)*

Run if any of the following are detected:
- Jest test files matching `*integration*` or `*e2e*` pattern
- pytest `integration` marker defined in config (`markers = integration`)
- `Makefile` `test-integration` or `test-e2e` target
- vitest project configured as `e2e`

```bash
# Node.js (Jest)
npx jest --testPathPattern=integration

# Node.js (Vitest)
npx vitest run --project=e2e

# Python (pytest)
pytest -m integration

# Makefile
make test-integration
# or: make test-e2e
```

**Soft block**: if integration tests fail, report failures as a warning and continue — do not stop the gate. Integration tests often require external services (database, queue, third-party API) that may not be available in CI or local environments. Note the failure prominently in the gate report and recommend the user investigate before opening a PR.

---

### Step 3 — Report result

After all checks complete (or after the first hard failure), output a gate report.

**On full pass**: declare the gate passed and list all checks run.

**On failure**: clearly identify which check failed, what the error was, and what action to take.

---

## Output format

```
### b-gate: [project or changed files]

Stack detected: [Node.js / Python / Go / unknown]

Checks run:
  ✅ Lint          — [tool] — PASSED
  ✅ Typecheck     — [tool] — PASSED
  ✅ Tests         — [N passed, 0 failed]
  ✅ Coverage      — [N%] — above threshold ([configured threshold]%)
  — or —
  ❌ Coverage      — [N%] — below threshold ([configured threshold]%) — HARD BLOCK
  — or —
  ⚠️  Coverage     — [N%] — no threshold configured (soft warn)
  — or —
  ⚠️  Coverage     — not configured (skipped)
  ✅ Security      — no high/critical vulnerabilities
  ✅ Clean code    — [tool] — PASSED
  ✅ Integration   — [N passed] (soft block — passed)
  — or —
  ⚠️  Integration  — [N failed] (soft block — external services may be unavailable)

  ⚠️  [check]      — not configured (skipped)

---
[GATE PASSED / GATE FAILED]
```

On failure:
```
### b-gate: FAILED at [check name]

[Error output from the failing check]

Fix required before proceeding:
  → [specific action to take]

Re-run this check only: [specific command, e.g. `npx eslint .` / `npx tsc --noEmit` / `npm test`]
If it passes, re-run full gate from Step 1 to confirm no regressions introduced by the fix.
```

On pass → next step: run **b-review** to verify logic correctness and requirements coverage before opening a PR.

---

## Rules

- Checks run in fixed order: lint → typecheck → tests → coverage → security → clean-code. Never reorder. **Why**: lint and typecheck catch syntax/type errors that would cause false test failures — running tests against broken code produces misleading output. Coverage runs after tests so it uses the same test run. Fix the foundation first.
- Hard stop on: lint failure, typecheck failure, test failure, coverage threshold violation (when threshold is explicitly configured), high/critical security finding. **Why**: these indicate the code is not shippable. Soft failures (no-threshold coverage, formatting, medium security) do not block shipping but should be tracked.
- Soft block (warn, continue) on: medium/low security findings, formatting failures.
- If a check is not configured, skip it and note it — do not fail because tooling is absent.
- Do not install missing tools — if a tool is absent, note "not installed" and skip.
- Never pass the gate with unresolved hard failures, even if the user asks to proceed.
- If the gate fails, do not rerun the full suite after partial fixes — run only the failing check to confirm the fix before re-running the full gate.
- Security check scope: only the project's direct and transitive dependencies. Do not scan external infrastructure.
- Never trigger destructive git commands — no `git push`, `git pull`, `git commit`, `git reset`, `git revert`, `git clean -f`, `git checkout -- <file>`, or `git branch -D`. If a commit is needed after completing work, delegate to b-commit.
