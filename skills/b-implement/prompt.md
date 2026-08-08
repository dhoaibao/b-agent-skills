# b-implement

Make the scoped change in the smallest coherent step, and hand back to planning or research instead of guessing when new ambiguity appears. When acting as a delegated worker, implement and verify only the assigned task, report the result, and return control to the coordinator.

## When to use

- The user approved a plan or gave a small direct request.
- The next action is an edit within known scope.

## When NOT to use

- Scope or behavior is unclear -> use **b-plan**.
- The primary task is a named refactor -> use **b-refactor**.
- The task is only tests -> use **b-test**.
- Root cause is unknown -> use **b-debug**.
- External lookup blocks the edit -> use **b-research**.

## Tool guidance

- `read`/`edit`/`write` - prefer Pi native file tools for source and config edits.
- `bash` - `rtk git status --short`, verification commands, and modern discovery routed through `rtk` whenever that command family is supported.
- `codegraph` - initialize an absent local index on first relevant use, then map architecture, calls, and affected tests.
- `serena` - symbols, references, diagnostics, and approval-gated symbol edits (`rename_symbol`, `replace_symbol_body`, `insert_before_symbol`, `insert_after_symbol`, `safe_delete_symbol`); ask before onboarding or persistent memory writes.
- `context7` - narrow versioned third-party API checks when needed.
- `recall` - recover compacted observational-memory ids when present instead of guessing prior context.

## Steps

1. Resolve the source of truth: approved plan, approved chat instruction, or small direct request.
2. Run `rtk git status --short` via Bash and preserve unrelated changes.
3. Use read for relevant repo context only when it materially affects the scoped change; use recall when compacted prior plan context is available.
4. State expected files/symbols, invariant behavior, and success criteria; infer narrow criteria only when obvious.
5. For cross-file code work, initialize an absent CodeGraph index; use CodeGraph for impact or affected tests, then Serena for exact symbols, references, and diagnostics. Otherwise use local search.
6. If a material blocker, new uncertainty, missing external fact, or scope drift cannot be resolved from the approved plan, direct request, and repository evidence, stop before the next edit. Explain the blocker and ask one focused user question; after each answer, re-evaluate and ask another only if a blocker remains. Hand back to **b-plan** or **b-research** only when that answer identifies the handoff.
7. Edit the smallest coherent slice and match the existing local style. Prefer Serena symbol mutations for renames/signature-body edits when available (approval-gated); use Pi `edit`/`write` for prose, config, and string-level changes.
8. Run the narrowest useful verification (using Context7 for versioned third-party API checks if the implementation relies on them) that proves the requested observable outcome.
9. If verification exposes an in-scope defect without a material blocker, correct it and rerun the required check. Otherwise stop under step 6.
10. Inspect changed paths with metadata-only Git output, then inspect diffs only for explicit non-protected paths and report changes, verification, and remaining gaps.

## Output format

Changes, verification, and any blockers or follow-up. Recommend **b-review** for non-trivial changes.

## Rules

- Stay within approved scope.
- Every changed line should trace to the approved scope or cleanup made necessary by this change.
- Remove imports or helpers made unused by the change; leave pre-existing dead code and adjacent comments or formatting untouched.
- Ask before dependencies, services, destructive commands, commits, pushes, PRs, or broad refactors.
- Do not add opportunistic cleanup, speculative compatibility, single-use abstractions, or handling for impossible scenarios without repo evidence.
- Do not push through newly discovered ambiguity; route it explicitly.
- Do not ask about details that the approved scope or repository evidence resolves; for each remaining material blocker, ask exactly one focused question and wait for its answer before asking the next.
- Do not claim done when required verification is missing or failed.
