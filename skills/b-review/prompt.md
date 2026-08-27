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
- `codegraph` - only for a concrete repository-wide changed-flow, impact, or
  affected-test question that native inspection cannot settle; use an available
  index for that question. In planner mode, do not initialize an absent index;
  fall back to native inspection and state the resulting gap. Outside planner
  mode, initialize one only for that question.
- `serena` - after native search/read, inspect a specific changed symbol,
  reference, or diagnostic only when it materially improves review precision;
  use native `read`/`edit`/`write` for routine file work and serialize requests
  rather than parallelizing or batching them.
- `brave-search` - one narrow independent public lookup; use specialized Brave tools only when news/local/image/video/place evidence matters.
- `recall` - recover compacted audit or prior-review memory ids when present.

## Steps

1. Scope the changed-code review: working tree, range, baseline, or checkpoint using Bash with `rtk git status` and metadata-only changed-path lists.
2. Classify protected paths before reading content, then inspect only explicitly named non-protected paths with targeted diffs. Use inspection tools only. If the user wants findings fixed, report them and hand off to **b-implement** after the review.
3. Choose baseline. For delegated work, the latest approved plan, handoff, and clarifications are the baseline; otherwise, without a baseline, do a risk review and do not claim requirements coverage.
4. Read repo context only when it materially affects the changed-code review; use recall for compacted prior review ids when present.
5. When native inspection leaves a concrete repository-wide flow, impact, or affected-test question, use an available CodeGraph index for that question. Do not initialize an absent index in planner mode; fall back to native inspection and state the resulting gap. Outside planner mode, initialize an absent index only for that question; do not initialize one merely because the diff spans files. Use native inspection first and Serena separately only for a specific exact reference or diagnostic when it materially improves precision. Use Brave only when public semantics materially affect a finding, and do not parallelize or batch Serena calls.
6. Inspect highest-risk changed symbols and boundaries first.
7. Check tests, edge cases, security, operability, evidence quality, hidden assumptions, unnecessary diff, and over-abstraction. Assess whether the solution choice is proportionate to the request, the plan's quality criteria, and project conventions; do not turn every review into an architecture report.
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

Findings, checked-and-clean areas, and coverage/verification come first. Each blocking finding must give location, evidence, impact, violated baseline, smallest correction, and regression check so the worker can act without a follow-up.

The response must end with exactly one standalone final line. Emit one of these exact lines as that final line, without backticks, bullets, bold, headings, or other Markdown decoration, and with no additional text after it:
- `Verdict: READY FOR PR`
- `Verdict: READY WITH FOLLOW-UPS`
- `Verdict: NEEDS FIXES`

For passing completion outcomes (`READY FOR PR` or `READY WITH FOLLOW-UPS`), emit `B_AGENTIC_TASK_COMPLETE` on its own standalone line immediately before the final verdict line. Do not emit that signal for `NEEDS FIXES`; the signal is planner attention metadata and must not contain task or review details.

## Rules

- Findings come first.
- Review is strictly read-only with respect to project files: do not edit files, use mutating symbol tools, apply patches, run fixers, or make any other source, test, configuration, or working-tree changes during review.
- Do not claim `READY FOR PR` without baseline and passing verification evidence.
- Treat unrelated cleanup, speculative flexibility, and unverified success criteria as review risks.
- Treat prompt or kernel changes without a concrete failure mode or validation story as review risks.
- For delegated worktree-changing tasks, actual `b-review` means this `SKILL.md` was loaded and its steps and output contract were followed for the diff and verification; it is mandatory before approval, and a generic review cannot substitute.
- Treat generated, lockfile, snapshot, vendored, and minified changes as derived unless source generation is clear.
