# b-review

Independently review a frozen changed-code candidate for blockers, regressions, security risk, and missing evidence. Findings first.

Flags: `--skip-tests`, `--baseline=<path|url>`, `--range=<ref>..<ref>`.

## When to use

- The user requests changed-code review.
- An implementer froze a candidate that needs its independent gate.

## When NOT to use

- PR title/description prose review or rewriting without changed-code review -> **b-pr-summary**.
- A b-agentic repository/design-conformance audit -> **b-agentic-audit**.
- Root-cause diagnosis -> **b-debug**.
- Writing or fixing tests -> **b-test**.

## Tool guidance

- Use `rtk git status --short`, metadata-only path lists, targeted safe diffs, and Pi native `read`. Select CodeGraph only for a central repository-wide review question; bounded specialized Brave tools may substantiate public semantics.

## Steps

1. Confirm the baseline, compatible reviewer identity, and exact candidate snapshot. It must cover tracked plus relevant untracked/derived content; do not claim requirements coverage without a baseline. When an implementer sends this candidate handoff through `intercom`, treat it as the review trigger and begin **b-review** automatically rather than waiting for another prompt.
2. Use `rtk git status --short`, metadata-only path lists, and targeted non-protected diffs. Read repository context only when it materially affects a finding.
3. Independently assess the actual diff, acceptance, required check outcomes and freshness, edge cases, security, operability, and residual risk. Check that the solution choice is proportionate to the plan's quality criteria and project conventions; do not turn every review into an architecture report. A skipped or failed required check, changed snapshot, wrong reviewer, or material gap cannot be ready.
4. Bounded read-only research may substantiate a specific finding only. Keep the repository review read-only: do not edit, patch, run generators/fixers, or otherwise mutate the worktree. When the disposition is `NEEDS FIXES`, first use `b_agentic_review_peer` with role `implementer`; it must validate exactly one compatible same-CWD origin from the current `B_AGENTIC_REVIEW_HANDOFF`. Only after that selector succeeds, automatically delegate the structured findings back through `intercom`: use `reply` for the active review request with `to` set to the selector's returned session ID (use its structured `returnTarget.to` value verbatim), or `send` to that same exact origin ID when no active request exists. Do not delegate to an unknown, Off, wrong-role, non-origin, or ambiguous peer, and do not provision a session; report a coordination gap if validation fails.
5. Report blocking findings with location, evidence, impact, violated baseline, minimal correction, and regression check. For `NEEDS FIXES`, include those findings in the intercom handback and name the next owner (`b-frontend`, `b-implement`, `b-test`, or `b-refactor`) where applicable. Corrections must return as a reverified, frozen candidate for another review.

## Output format

Findings, checked-and-clean areas, snapshot/verification coverage, and residual risk first. The response must end with exactly one standalone final line, with no text after it:
- `Verdict: READY FOR PR`
- `Verdict: READY WITH FOLLOW-UPS`
- `Verdict: NEEDS FIXES`

For either ready disposition, emit `B_AGENTIC_REVIEW_COMPLETE` on its own line immediately before the final verdict. `READY WITH FOLLOW-UPS` requires explicit disposition and never waives required safety evidence. A verdict is not task acceptance, commit creation, or shipping.

## Rules

- Review is strictly read-only with respect to project files.
- Do not claim `READY FOR PR` without baseline, unchanged candidate, acceptance, fresh passing required checks, no blockers/material gaps, and valid independent review.
- Keep review read-only with respect to project files; returning a structured findings handoff through `intercom` is required for `NEEDS FIXES` and is not an implementation mutation.
- Before either `intercom reply` or `intercom send`, use `b_agentic_review_peer` to validate the exact `B_AGENTIC_REVIEW_HANDOFF` origin; pass its returned session ID as the reply/send target, then automatically delegate `NEEDS FIXES` back to that compatible same-CWD implementer. For actionable findings, name the next owner: frontend/UI production fixes -> **b-frontend**, other production fixes -> **b-implement**, test-only fixes -> **b-test**, and named behavior-preserving transforms -> **b-refactor**.
- Generic review cannot substitute for this loaded skill's actual review gate.
