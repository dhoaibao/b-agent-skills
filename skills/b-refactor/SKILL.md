---
name: b-refactor
description: >
  Code refactoring: impact analysis, mechanical transformation, and verification.
  ALWAYS invoke when the user asks to refactor, tái cấu trúc, rename, extract method,
  move, inline, simplify, or clean up code. Unlike b-plan (decides what to build),
  b-refactor owns the mechanical workflow: impact analysis → safe edits → verify.
  Uses Serena's symbol-aware tools for cross-file impact and safe renaming.
effort: medium
---

# b-refactor

$ARGUMENTS

Refactor code with impact analysis and safe mechanical transformation. Owns the full
workflow: map references → plan transformation → apply symbol-aware edits → verify
nothing broke.

If `$ARGUMENTS` is provided, treat it as the refactoring instruction. Proceed directly.

## When to use

- User asks to refactor, rename, extract method, move a function, inline a variable.
- User says: "refactor", "tái cấu trúc", "extract method", "rename", "move", "inline",
  "simplify", "clean up", "tách hàm", "đổi tên".
- Mechanical code transformation that preserves behavior.
- Improving code structure without changing functionality.

## When NOT to use

- New feature or unclear scope → use **b-plan**
- Runtime bug or test failure → use **b-debug**
- Review after implementation → use **b-review**
- Quick library API lookup → use **b-lookup**
- Open-ended research → use **b-research**

## Tools required

- `Bash` — run tests, check compilation, inspect git diff
- `check_onboarding_performed`, `onboarding`, `find_symbol`, `get_symbols_overview`, `find_referencing_symbols`, `replace_symbol_body`, `insert_before_symbol`, `insert_after_symbol`, `rename_symbol`, `safe_delete_symbol` — from `serena` MCP server *(required for impact analysis and safe symbol-level edits)*
- `sequentialthinking` — from `sequential-thinking` MCP server *(optional, for evaluating trade-offs on large refactors)*

If Serena is unavailable: use native `Read` + `Edit` + Bash search for manual refactoring. Note: "⚠️ Serena unavailable — cross-file renames and safe deletes require manual verification."
If sequential-thinking is unavailable: evaluate trade-offs inline with explicit pros/cons.

Graceful degradation: ⚠️ Partial — mechanical refactoring still possible with native Edit, but cross-file renames and safe deletes require manual impact checks.

## Steps

### Step 1 — Impact analysis

1. Call `check_onboarding_performed`. If false, call `onboarding`.

2. Identify the target symbol:
   - If the user names a function/class: call `find_symbol` with that name.
   - If the user references a file: call `get_symbols_overview` to inspect top-level symbols.
   - If the instruction is vague ("clean up the auth module"): call `get_symbols_overview`
     on the file, then ask the user for a specific target.

3. Call `find_referencing_symbols` on the target symbol to map every call site and usage.
   Record: how many files reference it, whether it's exported/public, and whether any
   references are in tests.

4. Run tests via Bash to establish a baseline (must pass before refactoring).
   ```bash
   # Run the test suite — adjust for the project's framework
   npm test || pytest || go test ./... || cargo test
   ```
   If tests fail before refactoring: warn the user and ask whether to proceed.
   Refactoring on a red test suite makes it impossible to verify behavior was preserved.

**Goal**: know the full impact radius before touching any code.

---

### Step 2 — Plan transformation

Map the mechanical steps for the requested transformation:

| Transformation | Typical steps |
|---|---|
| **Rename** | 1. `rename_symbol` on the target. 2. Run tests. 3. Verify. |
| **Extract method** | 1. `replace_symbol_body` on the caller to call the new function. 2. `insert_before_symbol` to add the new function. 3. Run tests. |
| **Inline variable** | 1. `replace_symbol_body` on the using function to substitute the expression. 2. `safe_delete_symbol` on the variable. 3. Run tests. |
| **Move to new file** | 1. `replace_symbol_body` or `insert_after_symbol` to declare in the new file. 2. Update imports. 3. `safe_delete_symbol` from the old file. 4. Run tests. |
| **Delete dead code** | 1. `find_referencing_symbols` to confirm zero usages. 2. `safe_delete_symbol`. 3. Run tests. |
| **Split large function** | 1. `insert_before_symbol` to add helper functions. 2. `replace_symbol_body` to call helpers. 3. Run tests. |

If the refactor affects >3 files or crosses package boundaries:
- Use `sequentialthinking` to evaluate the rollback risk and plan the safest order.
- Consider splitting into phases (Step 1: rename; Step 2: move; Step 3: extract).

---

### Step 3 — Execute safely

Apply edits in dependency order. Prefer Serena's symbol-aware tools over native `Edit`:

1. **`rename_symbol`** — for renaming functions, classes, variables, files, or directories.
   This is the safest option for cross-file renames because Serena updates all references
   through the language server.

2. **`safe_delete_symbol`** — for removing dead code. Serena checks for remaining usages
   before deleting. If usages exist, the tool returns a list — address them before retrying.

3. **`replace_symbol_body`** — for changing the full body of a function or method.
   Use this when the signature stays the same but the implementation changes.

4. **`insert_before_symbol` / `insert_after_symbol`** — for adding new functions or moving
   declarations. Use these to add helper methods, extract classes, or reorganize modules.

5. **Native `Edit`** — use only for line-level import updates, config changes, or prose
   modifications that are not symbol-relative. Avoid using `Edit` for structural code changes
   when a Serena tool is available.

**Execution order rule**: apply changes from the inside out — inner helpers first, then
outer callers. This prevents broken references during the intermediate state.

**Import update rule**: if the refactor moves code across files, update imports manually
via native `Edit` after the symbol-level changes are done.

---

### Step 4 — Verify

After every mechanical step, run the relevant tests:

1. **Compilation check**: if the language is compiled (TypeScript, Go, Rust, Java),
   run the compiler first to catch type errors:
   ```bash
   npx tsc --noEmit || go build ./... || cargo check
   ```

2. **Test check**: run the full test suite or the subset affected by the refactor:
   ```bash
   npm test || pytest || go test ./... || cargo test
   ```

3. **Git diff inspection**: run `git diff` to confirm only intended changes were made.
   Look for accidental deletions, wrong import paths, or unintended formatting changes.

4. **Impact re-check**: if the refactor changed a public/exported symbol, re-run
   `find_referencing_symbols` to confirm all references still resolve correctly.

**Iteration rule**: if tests fail or compilation errors appear, fix them before proceeding.
   Do not continue to the next transformation step while the previous step is broken.
   Maximum 2 fix iterations per step.

---

## Output format

```
### b-refactor: [transformation name]

**Target**: `[symbol name]` in `[file]`
**Impact**: [N references across M files]
**Risk**: [low / medium / high]

#### Transformation plan
- [Step 1 description]
- [Step 2 description]
- ...

#### Changes
- `[file:line]` — [what changed]

#### Verification
```bash
[test command and result]
```
✅ Tests pass / ❌ [N failures] — [fix status]

#### Next steps
- [any remaining cleanup, import fixes, or follow-up refactors]
```

---

## Rules

- Never refactor without a green test baseline — if tests are failing before the refactor,
  warn the user and ask whether to proceed.
- Always use `find_referencing_symbols` before renaming or deleting — cross-file impact
  is the most common source of refactoring bugs.
- Prefer `rename_symbol` over manual `Edit` for renames — it updates all references atomically.
- Prefer `safe_delete_symbol` over manual deletion — it prevents accidental removal of still-used code.
- Do not refactor and add new features in the same session — split into two tasks.
- If the refactor affects >5 files: use `sequentialthinking` to evaluate rollback strategy.
- Run compilation check after every mechanical step — do not wait until the end.
- Run the full test suite after the last step, not just the unit test for the changed function.
- Never trigger destructive git commands.
- Keep git history clean — one commit per logical transformation (rename, extract, move).
- If the refactor is too large to verify in one session: stop after a safe checkpoint,
  run tests, and tell the user: "Safe checkpoint reached. Remaining transformations: [list]."