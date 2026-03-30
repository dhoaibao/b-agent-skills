---
name: b-gate
policy:
  allow_implicit_invocation: true
description: >
  Mandatory quality gate — stack-aware ordered checks: lint → typecheck → tests → basic security →
  clean-code. ALWAYS use when the user says "gate", "check quality", "kiểm tra chất lượng",
  "b-gate", or after completing all implementation steps in a b-plan session. Distinct
  from b-tdd (which enforces test discipline during coding): b-gate validates the final
  result before declaring work done.
---

# b-gate

$ARGUMENTS

Run the mandatory quality gate before declaring implementation complete. Detects stack from
config files and runs only checks that are configured. Blocks on any failure — no partial passes.

If `$ARGUMENTS` is provided, treat it as a space-separated list of file paths or directories to scope the gate to (e.g. `src/auth/ src/middleware/`). If omitted, run against all changed files in the working tree.

> ⚠️ **Codex cloud sandbox note**: b-gate runs shell commands (lint, tests, security tools) that
> assume a local development environment. In Codex cloud mode, some commands may be unavailable
> or behave differently. Run Codex locally for full b-gate support. If a tool is absent, b-gate
> will note "not installed" and skip it rather than failing.

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

For each check: if no config file is found, skip the check and note it as "not configured" — do not fail because of missing tooling.

---

### Step 2 — Run checks in order

Run each configured check in this fixed order. **Stop on first failure.**

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

If tests fail: output the failure summary, stop. Do not proceed to security.

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
  ✅ Security      — no high/critical vulnerabilities
  ✅ Clean code    — [tool] — PASSED

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
```

On pass → next step: run **b-review** to verify logic correctness and requirements coverage before opening a PR.

---

## Rules

- Checks run in fixed order: lint → typecheck → tests → security → clean-code. Never reorder. **Why**: lint and typecheck catch syntax/type errors that would cause false test failures — running tests against broken code produces misleading output. Fix the foundation first.
- Hard stop on: lint failure, typecheck failure, test failure, high/critical security finding. **Why**: these indicate the code is not shippable. Soft failures (formatting, medium security) do not block shipping but should be tracked.
- Soft block (warn, continue) on: medium/low security findings, formatting failures.
- If a check is not configured, skip it and note it — do not fail because tooling is absent.
- Do not install missing tools — if a tool is absent, note "not installed" and skip.
- Never pass the gate with unresolved hard failures, even if the user asks to proceed.
- If the gate fails, do not rerun the full suite after partial fixes — run only the failing check to confirm the fix before re-running the full gate.
- Security check scope: only the project's direct and transitive dependencies. Do not scan external infrastructure.
