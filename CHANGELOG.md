# Changelog

All notable shipped revisions of b-agentic are recorded here. Released version headings match immutable Git tags of the form `vYYYY.MM.DD` (or `vYYYY.MM.DD.N` for same-day revisions).

## Unreleased

### Changed

- Kernel/headroom deduplication:
  - Observed failure: the always-loaded kernel spent roughly 40% of its 12,000-byte cap on two-role delegation mechanics duplicated in the injected planner and worker prompts, even though b-agentic defaults to Off.
  - Intended behavior: keep Off/solo role selection, the sole-writer and same-CWD roster boundary, generated skill ownership, and the questionnaire contract in the kernel; keep handoff, Intercom, blocker, delivery, review, and post-approval commit mechanics in the role-specific prompts without weakening active-role behavior.
  - Regression: kernel size guards, role-prompt marker assertions, planner/worker smoke prompt coverage, generated-sync checks, and role behavior fixtures retain the moved rules and detect kernel/prompt drift.

- Preview-Markdown package and standalone installer (commits 31c4c17,
  87ac5aa, faf1f4b, 510dcdc, 875a683):
  - Observed failure: users wanting only the inline Markdown preview had to
    install the full b-agentic bundle, and the extension had no independently
    distributable Pi package.
  - Intended behavior: ship the preview as a standalone Pi package rooted at
    `pi/packages/preview-markdown/package.json`, installable via
    `npm:@dhoaibao/preview-markdown` or the version-pinned raw installer
    `pi/scripts/install-preview-markdown.sh`, while it remains a default
    first-party extension in the b-agentic bundle.
  - Regression: `pi/scripts/validate-preview-markdown-package.sh` checks the
    exact package contents and `pi/tests/smoke.sh` covers the Pi preview
    extension and integration behavior.

- Structured interactive user questions:
  - Observed failure: focused planner decisions and blockers relied on a fixed desktop notification rather than presenting actionable choices in Pi, while worker-facing material decisions still prescribed plain chat despite the questionnaire extension being installed.
  - Intended behavior: install and track `npm:@juicesharp/rpiv-ask-user-question@2.6.2`; use `ask_user_question` for any interactive, user-facing material decision or blocker in planner or solo/Off work with 1–4 grouped questions, 2–4 concrete options with concise trade-offs, a recommended first option, and the extension's automatic custom-answer row. Retain the focused plain-text fallback when unavailable/noninteractive; emit exactly one privacy-safe user-input signal only for planner decisions/blockers; keep worker→planner questions in Intercom and native permission prompts for browser/external/privileged actions.
  - Regression: generated planner/worker guidance and b-commit structured approval wording are checked by `tooling/validate/shared.py`; `pi/tests/smoke.sh` covers retained task-complete/user-input notification behavior and package install/manifest state; installer package lifecycle is covered by `tests/smoke/lib.sh`.

- Trusted local diagnostics and questions:
  - Observed failure: the kernel-mandated `ask_user_question` tool incurred generic custom-tool approval friction, while the default-installed `lsp_diagnostics` capability was unusable without UI approval even for safe repository-local checks.
  - Intended behavior: trust `ask_user_question` by name and auto-approve `lsp_diagnostics` only for validated project-confined, unprotected arguments; retain approval for malformed, outside-project, protected, or unknown-key diagnostics calls and every `lsp_fix` form.
  - Regression: table-driven `pi/tests/smoke.sh` assertions cover trusted and gated local-tool shapes, including no-UI fail-closed behavior; `scripts/b-agentic-audit.sh`, `scripts/validate-skills.sh`, generated-sync checks, and `rtk git diff --check` cover repository conformance.

- Planner read-only command policy:
  - Observed failure: the planner's command allowlist blocked harmless inspection utilities such as `printf`, creating approval friction during discovery.
  - Intended behavior: inherit shared-policy-safe read-only commands while retaining operation-specific Git, CodeGraph, and discovery checks; block write/redirection and execution forms, explicit denies, protected paths, dangerous commands, and outside-project access.
  - Regression: planner role assertions in `pi/tests/smoke.sh` cover `printf`, ordinary repository reads, shell writes, explicit denies, and existing MCP task-retrieval/review policy coverage.
- Separate repository/design-conformance audits from changed-code review:
  - Observed failure: `b-review` mixed changed-code review with b-agentic suite audits, leaving documented-decision drift without a distinct source-comparison owner.
  - Intended behavior: `b-agentic-audit` runs structural and decision-design traceability checks, compares the decision record with canonical sources, and reports drift; `b-review` remains changed-code-only and the mandatory delegated-diff gate is unchanged.
  - Regression: `tooling/validate/decision_design.py`, routing fixtures, generated-sync validation, and `scripts/b-agentic-audit.sh`.
- Planner/worker Pi profiles:
  - Observed failure: prose-only handoffs could not reliably coordinate a planner and a sole worktree writer across Intercom sessions.
  - Intended behavior: `/b-role planner|worker|off` persists prompt-governed collaboration profiles; role selection preserves normal active tools and shared shell, filesystem, MCP, and approval policies. In two-role workflows, the planner delegates worker-owned execution and the worker is the procedural sole worktree writer; natural-language delegation, results, and review use `send`, while `ask`/`reply` are for blockers and clarifications.
  - Regression: role-mode behavioral fixtures in `pi/tests/smoke.sh`; kernel/extension markers in `pi/scripts/validate.sh`, `tooling/validate/behavior.py`, and `tooling/validate/shared.py`.
- Intercom delegation protocol:
  - Observed failure: workers did not reliably receive handoffs, delegation duplicated serial work and ran slower than one session, and `reply` failed when neither side had a unique pending `ask`.
  - Intended behavior: delegate worker-owned execution, use `send` for natural-language task delegation and worker result/review reporting, and reserve `ask`/`reply` for blockers and clarifications.
  - Regression: `INTERCOM_DELEGATION_REGRESSION` in `tooling/validate/behavior.py`; Pi integration marker checks in `pi/scripts/validate.sh` and `tooling/validate/shared.py`.
- Shell/RTK policy (Option B):
  - Observed failure: kernel guidance and permission policy diverged on RTK coverage, while approval guidance implied RTK bypassed asks.
  - Intended behavior: require RTK for every supported command family; use modern replacements only where RTK has no native family; RTK never bypasses approvals.
  - Regression: `SHELL_POLICY_REGRESSION` in `tooling/validate/behavior.py`; shared kernel clause checks; `pi/tests/smoke.sh` bare discovery allow + `RTK_OPTIONAL_COMMANDS`; `session_readiness` required-vs-optional drift.
- Safety holes from suite audit:
  - Observed failure: Pi `recall` fell through custom-tool approval; Firecrawl scrape could auto-approve with `skipTlsVerification: true`.
  - Intended behavior: `recall` is first-party specialized; TLS-disabled scrapes require approval.
  - Regression: `pi/tests/smoke.sh` recall specialized + Firecrawl TLS rejection fixtures.
- Skill tool leverage:
  - Observed failure: skills under-specified Pi `read`/`edit`/`write`/`recall` and specialized MCP surfaces already classified by policy.
  - Intended behavior: teach native file tools, optional recall, Serena symbol mutations, Firecrawl `research_*`, specialized Brave modalities, ordered Playwright evidence, and consistent `rtk git` where git is primary.
  - Regression: `PROMPT_TOOL_LEVERAGE_REGRESSION` anchors in `tooling/validate/shared.py` (with existing `MCP_WORKFLOW_REGRESSION`).
- Routing trigger tightening:
  - Observed failure: bare triggers such as `add`/`build`/`error`/`docs` over-routed unrelated requests.
  - Intended behavior: prefer multi-word intent phrases; drop bare `docs`.
  - Regression: trigger-tightening fixtures in `tooling/validate/behavior.py` (finish/make/build-the-feature, runtime error, product bug, README approach stays plan, external documentation stays research).

### Removed

- Remove the unused Python package metadata in `pyproject.toml`; immutable Git tags remain the release version source.
- Remove the Cursor runtime adapter and all Cursor-specific install, doctor, acceptance, policy, and docs surfaces.
- Remove `references/contract/shell-tools.md`; the required shell-tool and RTK preferences now live in the always-loaded kernel template.
- Remove the Claude Code and Codex runtime adapters (folders, registry entries, install/uninstall, doctors, acceptance probes, policy checks, and docs), leaving Pi as the shipped runtime.
- Consolidate b-agentic around Pi by removing the runtime registry and template
  scaffold, promoting Pi integration assets to `pi/`, and simplifying installation
  and validation accordingly.

### Changed

- Expand simulated acceptance coverage to Pi harness command construction.
- Add outcome-focused skill routing fixtures for high-risk phase boundaries.
- Simplify `b-pr-summary` and make `b-design` structure an adaptable checklist rather than a forced skeleton.
- Add opt-in, human-scored prompt-effectiveness scenarios for ambiguity, simplicity, surgical changes, and verified execution.
- Harden Pi permission handling for mixed MCP selectors, external session cleanup, and RTK-proxied legacy shell tools.
- Gate RTK-wrapped external/shared mutations, opaque package execution, and executables outside trusted system paths.
- Inject actual kernel and skill contents into prompt-effectiveness runs and validate command construction without model calls.
- Validate prompt-effectiveness inputs without model calls and detect RTK command-policy drift in session readiness checks.
- Classify MCP gateway operations canonically and require approval for managed connect/server-scoping lifecycle actions.
- Require Node-backed Pi permission-handler smoke coverage and add opt-in native routing and live MCP schema-drift evidence lanes.
- Detect newly added, unclassified RTK command families instead of checking compatibility in only one direction.

## 2026.06.24

- Baseline package version aligned with the 2026-06-24 development snapshot.
