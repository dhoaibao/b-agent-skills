# b-review

Review changed code or b-agentic itself for blockers, regressions, security risk, and missing coverage. Findings first.

Flags: `--skip-tests`, `--baseline=<path|url>`, `--range=<ref>..<ref>`, `--audit-suite`.

## When to use

- The user wants a pre-PR/pre-commit changed-code review.
- A risky milestone needs reviewer scrutiny.
- The user requests a b-agentic suite audit.

## When NOT to use

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

1. Scope the review: working tree, range, baseline, or suite-audit surface using Bash with `rtk git status` and metadata-only changed-path lists.
2. Classify protected paths before reading content, then inspect only explicitly named non-protected paths with targeted diffs. Use inspection tools only. If the user wants findings fixed, report them and hand off to **b-implement** after the review.
3. Choose baseline. Without baseline, do a risk review and do not claim requirements coverage.
4. Read repo context only when it materially affects the review; use recall for compacted prior review ids when present.
5. When changed code needs repository-wide flow, impact, or affected-test evidence, initialize an absent CodeGraph index and use it for that question; use Serena separately for exact references and diagnostics. Use Brave only when public semantics materially affect a finding.
6. Inspect highest-risk changed symbols and boundaries first.
7. Check tests, edge cases, security, operability, evidence quality, hidden assumptions, unnecessary diff, and over-abstraction.
8. Verify evidence proves the intended observable outcome, not only command success (using Brave to look up API semantics if needed).
9. Emit findings ordered by severity. If none, say so and name residual risk.

For `--audit-suite` or explicit b-agentic audits, check kernel slimness, real problem statement, source/generated sync, Pi integration safety, installer safety, MCP leverage, validation evidence, prompt-change evidence, domain-specific behavior in core, ceremony creep, and cleanup candidates. Run `scripts/b-agentic-audit.sh` from the b-agentic checkout for structural checks only. Supplement it with repo inspection for the criteria the script does not automate, and do not treat a passing script as production-readiness proof. Prefer source files over generated assets and lower confidence when Pi behavior is only install-validated.

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
