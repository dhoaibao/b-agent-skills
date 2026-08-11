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

- `bash` - `rtk git status --short`, checks, and modern discovery routed through `rtk` whenever supported.
- `codegraph` - only for repository-wide impact and dependency structure; initialize an absent local index on first such use.
- `serena` - use only for exact declarations/references/implementations,
  diagnostics, or reference-aware refactors when it materially improves safety
  or precision; serialize requests and never parallelize or batch them.
- `read`/`edit` - routine file work, prose, comments, config keys, and Serena
  fallbacks. Prefer native edits unless a reference-aware Serena refactor is
  materially safer.

## Steps

1. Lock the exact target and state the behavior that must remain unchanged.
2. Use read for relevant repo context only when it materially affects the transform.
3. When the transform needs repository-wide impact evidence, initialize an absent CodeGraph index and map that impact; use native search for routine discovery and Serena separately only for exact declarations/references when they materially improve precision. Use bash with `rg`/`fdfind` for exports, routes, config keys, docs, and generated consumers Serena cannot see.
4. When practical, run the narrowest risk-appropriate check to establish a passing behavioral baseline.
5. Apply the smallest matching transform via Pi native `edit` for routine changes; use Serena symbol ops only for a reference-aware refactor when they materially improve safety or precision.
6. Re-check references with native search, use Serena diagnostics or reference checks only when materially useful, and rerun the baseline check or equivalent narrow verification.
7. Inspect the diff for unintended behavior changes.

When the refactor target is architectural, use concise design vocabulary: interface, seam, adapter, locality, leverage, shallow abstraction, and deletion test. Stop if the work becomes redesign.

## Output format

Target, impact, changes, verification, and follow-up risk.

## Rules

- Preserve behavior.
- Prefer symbol-aware tools when reliable.
- Ask before broad moves or cascading ecosystem changes.
- Stop if redesign or behavior change appears.
