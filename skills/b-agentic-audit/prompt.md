# b-agentic-audit

Run a source-based b-agentic repository and design-conformance audit, reporting
structural failures and drift between documented decisions and canonical sources.
This audit supplements the automated checks; it does not mechanically prove all prose semantics and it never substitutes for changed-code `b-review`.

## When to use

- The user requests a b-agentic repository audit, suite audit, maintainer audit,
  or design-conformance audit.
- The repository decision record may have drifted from the implementation,
  generated assets, workflow, safety, install, or verification behavior.
- A maintainer needs evidence-backed conformance findings before a release.

## When NOT to use

- Reviewing a working-tree, staged, checkpoint, or commit-range code diff -> use
  **b-review**.
- Implementing an audit finding -> use **b-implement** after the audit.
- Planning an ambiguous audit scope -> use **b-plan**.
- General UI/design review or external research -> use **b-browser**,
  **b-design**, or **b-research** as appropriate.

## Tool guidance

- `bash` - run `rtk git status --short`, the existing
  `scripts/b-agentic-audit.sh` entrypoint, and narrow repository checks.
- `read` - inspect `docs/decision_design.md` and the canonical source files it
  cites; prefer sources over generated assets when comparing behavior.
- `codegraph` - use only for repository-wide architecture, impact, or affected
  test questions that the decision record makes relevant.
- `serena` - after native search/read, use only when a concrete exact-symbol,
  reference, implementation, diagnostic, or boundary question materially
  improves safety or precision; use native `read`/`edit`/`write` for routine file
  work and serialize requests rather than parallelizing or batching them.

## Steps

1. Define the audit surface from the user request and run `rtk git status --short`;
   preserve unrelated changes and classify protected paths before reading them.
2. Read the decision record and identify its relevant decisions, evidence
   markers, referenced sources, generated surfaces, and explicit non-goals.
3. Use `bash` to run `scripts/b-agentic-audit.sh` and record structural,
   generated-sync, behavioral, and decision-design traceability results. Treat a
   passing script as evidence for those checks only.
4. Perform the source-based comparison: read the cited canonical sources and
   compare the documented behavior, routing, safety, install, tooling, and
   verification statements against current repository behavior. Report drift,
   stale references, unsupported claims, and material omissions with paths.
5. Use native inspection first. Use CodeGraph only for a distinct concrete
   repository-wide architecture or impact question the record or a finding
   requires; do not initialize it merely because the audit spans files. Use
   Serena only for a distinct exact-symbol or diagnostic question that materially
   improves precision; do not duplicate ownership queries or parallelize/batch
   Serena calls.
6. Separate automated traceability/structural results from human semantic
   findings. State what was not mechanically proven, then report findings first,
   checked-and-clean areas, verification, residual risk, and follow-up scope.
7. If findings need code or documentation changes, report them and hand off to
   **b-implement**; do not edit during this audit. A changed-code diff still
   requires the actual **b-review** gate afterward.

## Output format

Findings (ordered by severity), source-based comparison, automated checks,
checked-and-clean areas, residual limitations, and follow-up. Verdict:
`READY FOR PR`, `READY WITH FOLLOW-UPS`, or `NEEDS FIXES`.

## Rules

- Keep the audit read-only: do not edit, stage, commit, push, or apply fixes.
- Prefer repository evidence over assumptions and cite repository-relative paths.
- Do not claim that passing structural or traceability checks proves all prose
  semantics, production readiness, or the absence of drift.
- Do not treat generated assets as canonical when a source file exists.
- Do not use this skill as a generic code-diff review; changed diffs belong to
  **b-review**, including the mandatory delegated-task review gate.
