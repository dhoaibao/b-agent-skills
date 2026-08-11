# b-review

Review changed code or b-agentic itself for blockers, regressions, security risk, and missing coverage. Findings first.

Flags: `--skip-tests`, `--baseline=<path|url>`, `--range=<ref>..<ref>`.

## When to use

- The user wants a pre-PR/pre-commit review of changed code.
- A risky implementation milestone needs reviewer scrutiny against a baseline.
- A delegated worker result needs the mandatory actual diff-and-verification review.

## When NOT to use

- A b-agentic repository or design-conformance audit -> use **b-agentic-audit**.
- Something is broken and needs root-cause tracing -> use **b-debug**.
- The task is writing or fixing tests -> use **b-test**.
- The task is external lookup -> use **b-research**.
- The user asks only to run lint, format, or build.

## Tool guidance

- `bash` - `rtk git status`, metadata-only Git path lists, targeted safe-path diffs, logs, and narrow verification; modern discovery routed through `rtk` whenever supported.
- `read` - open changed files directly.
- `codegraph` - only for repository-wide changed flows, impact, and affected tests; initialize an absent local index on first such use.
- `serena` - inspect changed symbols, references, diagnostics, and boundaries.
- `brave-search` - one narrow independent public lookup; use specialized Brave tools only when news/local/image/video/place evidence matters.
- `recall` - recover compacted audit or prior-review memory ids when present.

## Steps

1. Scope the changed-code review: working tree, range, baseline, or checkpoint using Bash with `rtk git status` and metadata-only changed-path lists.
2. Classify protected paths before reading content, then inspect only explicitly named non-protected paths with targeted diffs. Use inspection tools only. If the user wants findings fixed, report them and hand off to **b-implement** after the review.
3. Choose baseline. Without baseline, do a risk review and do not claim requirements coverage.
4. Read repo context only when it materially affects the changed-code review; use recall for compacted prior review ids when present.
5. When changed code needs repository-wide flow, impact, or affected-test evidence, initialize an absent CodeGraph index and use it for that question; use Serena separately for exact references and diagnostics. Use Brave only when public semantics materially affect a finding.
6. Inspect highest-risk changed symbols and boundaries first.
7. Check tests, edge cases, security, operability, evidence quality, hidden assumptions, unnecessary diff, and over-abstraction.
8. Verify evidence proves the intended observable outcome, not only command success (using Brave to look up API semantics if needed).
9. Emit findings ordered by severity. If none, say so and name residual risk.

Do not run the b-agentic repository/design-conformance audit here. Use
**b-agentic-audit** for kernel slimness, source/generated sync, decision-design
traceability, Pi integration safety, installer safety, MCP leverage, validation
evidence, prompt-change evidence, domain-specific behavior, ceremony creep,
and cleanup candidates. `scripts/b-agentic-audit.sh` is an audit entrypoint,
not a substitute for this changed-code review.

Use architecture vocabulary only when design friction is material: interface, seam, adapter, locality, leverage, shallow abstraction, and deletion test. Do not turn every review into an architecture report.

## Output format

Findings, checked-and-clean areas, coverage/verification, and verdict: `READY FOR PR`, `READY WITH FOLLOW-UPS`, or `NEEDS FIXES`.

## Rules

- Findings come first.
- Review is strictly read-only with respect to project files: do not edit files, use mutating symbol tools, apply patches, run fixers, or make any other source, test, configuration, or working-tree changes during review.
- Do not claim `READY FOR PR` without baseline and passing verification evidence.
- Treat unrelated cleanup, speculative flexibility, and unverified success criteria as review risks.
- Treat prompt or kernel changes without a concrete failure mode or validation story as review risks.
- Treat generated, lockfile, snapshot, vendored, and minified changes as derived unless source generation is clear.
