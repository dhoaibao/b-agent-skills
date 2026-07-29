# b-refactor

Run concrete behavior-preserving transforms: rename, extract, move, inline, simplify, or delete.

## When to use

- The user names a specific behavior-preserving transform.
- The target is clear enough to change without product decisions.

## When NOT to use

- The request is vague cleanup or changes behavior -> use **b-plan**.
- The work adds behavior -> use **b-implement**.
- The work fixes a bug -> use **b-debug**.
- The work is test-only -> use **b-test**.

## Tool guidance

- `bash` - `rtk git status --short`, checks, and modern discovery (`rg`, `fd`/`fdfind`).
- `codegraph` - initialize an absent local index on first relevant use, then map impact and cross-file structure.
- `serena` - lock targets and references; prefer approval-gated `rename_symbol`, `replace_symbol_body`, `insert_before_symbol`, `insert_after_symbol`, and `safe_delete_symbol` over text patches when reliable; ask before onboarding or persistent memory writes.
- `read`/`edit` - prose, comments, config keys, and non-symbol renames.

## Steps

1. Lock the exact target and state the behavior that must remain unchanged.
2. Use read for relevant repo context only when it materially affects the transform.
3. For code structure, initialize an absent CodeGraph index; map impact with CodeGraph, then declarations/references with Serena. Use bash with `rg`/`fd` for exports, routes, config keys, docs, and generated consumers Serena cannot see.
4. When practical, run the narrowest risk-appropriate check to establish a passing behavioral baseline.
5. Apply the smallest matching transform via Serena symbol ops when they fit; otherwise Pi `edit`.
6. Re-check references (`rg` and Serena), run diagnostics, and rerun the baseline check or equivalent narrow verification.
7. Inspect the diff for unintended behavior changes.

When the refactor target is architectural, use concise design vocabulary: interface, seam, adapter, locality, leverage, shallow abstraction, and deletion test. Stop if the work becomes redesign.

## Output format

Target, impact, changes, verification, and follow-up risk.

## Rules

- Preserve behavior.
- Prefer symbol-aware tools when reliable.
- Ask before broad moves or cascading ecosystem changes.
- Stop if redesign or behavior change appears.
