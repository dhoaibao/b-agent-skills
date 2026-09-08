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
4. Bounded read-only research may substantiate a specific finding only. Keep the repository review read-only: do not edit, patch, run generators/fixers, or otherwise mutate the worktree. Before reporting review completion, automatically return the structured disposition and findings for every disposition (`NEEDS FIXES`, `READY FOR PR`, or `READY WITH FOLLOW-UPS`) through `intercom` to the implementer session in the same CWD: use `reply` for the active review request, or `send` to that session when no active request exists. Do not provision a session; report a coordination gap if the implementer session or intercom is unavailable.
5. Report blocking findings with location, evidence, impact, violated baseline, minimal correction, and regression check. Include `NEEDS FIXES` findings in the intercom handback and name the next owner (`b-frontend`, `b-implement`, `b-test`, or `b-refactor`) where applicable. Corrections must return as a reverified, frozen candidate for another review.

## Output format

Findings, checked-and-clean areas, snapshot/verification coverage, and residual risk first. The response must end with exactly one standalone final line, with no text after it:
- `Verdict: READY FOR PR`
- `Verdict: READY WITH FOLLOW-UPS`
- `Verdict: NEEDS FIXES`

`READY WITH FOLLOW-UPS` requires explicit disposition and never waives required safety evidence. A verdict is not task acceptance, commit creation, or shipping.

## Rules

- Review is strictly read-only with respect to project files.
- Do not claim `READY FOR PR` without baseline, unchanged candidate, acceptance, fresh passing required checks, no blockers/material gaps, and valid independent review.
- Keep review read-only with respect to project files; before reporting review completion, returning a structured disposition and findings handback through `intercom` is required for every disposition and is not an implementation mutation.
- Automatically return each disposition (`NEEDS FIXES`, `READY FOR PR`, or `READY WITH FOLLOW-UPS`) and its structured findings through `intercom` to the implementer session in the same CWD before the final verdict, then remain read-only. For actionable findings, name the next owner: frontend/UI production fixes -> **b-frontend**, other production fixes -> **b-implement**, test-only fixes -> **b-test**, and named behavior-preserving transforms -> **b-refactor**.
- Generic review cannot substitute for this loaded skill's actual review gate.
