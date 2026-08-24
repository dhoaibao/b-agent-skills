# Changelog

All notable shipped revisions of b-agentic are recorded here. Released version headings match immutable Git tags of the form `vYYYY.MM.DD` (or `vYYYY.MM.DD.N` for same-day revisions).

## Unreleased

### Changed

- Robust structured `b_consult` response parsing:
  - Observed failure: complete consultant JSON wrapped in a JSON Markdown fence or omitting empty advisory list fields was rejected as malformed, while malformed/truncated output still needed to remain rejected without exposing raw consultant text.
  - Intended behavior: accept only one complete JSON object, optionally wrapped solely in a JSON Markdown fence; normalize absent optional `alternatives`, `risks`, `missingEvidence`, and `findings` fields to empty arrays while preserving strict recommendation, supplied-field type, malformed-alternative, invalid-JSON, and truncation rejection, isolation, and no-retry behavior.
  - Regression: `pi/extensions/b-agentic-consult.ts` implements the bounded parser and compact output contract; `pi/tests/smoke.sh` covers fenced advice, omitted-list normalization, malformed/truncated JSON, wrong-typed supplied lists, malformed alternatives, and sanitized failures; `docs/decision_design.md` records the structured-advice boundary.

- Four-dimension b-agentic audit:
  - Observed failure: `b-agentic-audit` focused on source/design conformance and did not explicitly assess whole-project and first-party-extension health, canonical skill/kernel quality, or currentness/MCP compatibility.
  - Intended behavior: keep audits strictly read-only across all four dimensions; require concrete evidence for defects and integration gaps, measured or explicitly algorithmic/safety/complexity evidence for performance findings, local pin/installed-version resolution plus bounded primary upstream evidence for currentness, approval-gated live MCP probing, and verdicts of `NEEDS FIXES` for actual source/safety/semantic drift, `READY WITH FOLLOW-UPS` when required evidence is unavailable, or `READY FOR PR` only when all required dimensions are verified.
  - Regression: `skills/b-agentic-audit/prompt.md` carries the contract anchors, `tooling/validate/shared.py` checks the distinctive prompt behavior, `tests/behavior/routing.json` covers full currentness audit routing, `python3 tooling/generate/registry_sync.py --check` checks generated surfaces, and `scripts/b-agentic-audit.sh` remains deterministic structural/traceability coverage.

- Planner prompt addendum deduplication:
  - Observed failure: the always-loaded kernel preceded the planner role addendum, but the addendum repeated generated ownership lists and criterion plus the generic questionnaire contract, increasing every planner start without adding planner-specific behavior.
  - Intended behavior: keep shared ownership mapping/criterion and the generic questionnaire contract authoritative in the kernel while retaining the planner-specific read-only delegation boundary, external b-research ownership, handoff/Intercom/review mechanics, planner-only signals, and questionnaire fallback; do not alter the worker prompt, kernel rules, or runtime policy.
  - Regression: `pi/tests/smoke.sh` measures the planner addendum below its measured pre-deduplication byte count and checks kernel ownership plus planner behavior anchors; `python3 tooling/generate/registry_sync.py --check`, `scripts/validate-skills.sh`, and `rtk git diff --check` provide synchronization and structural coverage.

- Pi usage package source:
  - Observed failure: The installer sourced Pi usage reporting from `@narumitw/pi-usage`; this directed vendor/package-source change redirects that source rather than addressing a discovered defect.
  - Intended behavior: source Pi usage reporting from `@sreetej510/pi-usage`, preserving its unpinned status and the existing version pins for pi-lsp and rpiv-ask-user-question.
  - Regression: `scripts/smoke-install.sh` exercises Pi smoke cases whose install assertions in `pi/tests/smoke.sh` and fake installer handling in `tests/smoke/lib.sh` require `npm:@sreetej510/pi-usage`.

- Shared command citation traceability:
  - Observed failure: `decision_design.py` skipped every code citation containing whitespace, so the command reference `bash pi/scripts/validate-preview-markdown-package.sh` was not checked against tracked repository paths.
  - Intended behavior: share citation tokenization, path resolution, wildcard handling, command-prefix parsing, and unique bare-filename resolution between the decision-design and CHANGELOG validators without changing either consumer's scope or error policy.
  - Regression: `scripts/b-agentic-audit.sh` now reports 65 tracked source references instead of 64; a temporary whitespace-bearing nonexistent command citation made the audit fail naming that path, restoration passed, and `tooling/validate/changelog.py` retained its 21-entry, 19-citation, 2-uncovered, 40-resolved summary.

- Checkable CHANGELOG regression claims:
  - Observed failure: Unreleased entries relied on convention for their three-part shape, repository citations could name missing paths, and regression prose could claim coverage without a concrete artifact or an explicit uncovered status.
  - Intended behavior: validate colon-terminated structured entries under `## Unreleased` for the exact sub-bullet order, resolve cited tracked paths, and require either a concrete citation or `no automated coverage:`. Released history and legacy bullets remain untouched; this cannot verify that a cited check semantically covers the change it claims to cover.
  - Regression: `tooling/validate/run.sh` invokes the check through `scripts/validate-skills.sh`; temporary nonexistent-path, missing-sub-bullet, citation-without-artifact-or-`no automated coverage:`, and bare-`no automated coverage:` mutations each fail by naming the affected entry, and the full offline acceptance suite passes.

- Canonical role-prompt assertion markers:
  - Observed failure: planner and worker rule strings were hand-copied across four validators and smoke assertions, so one wording change required synchronized edits and could leave coverage stale or self-matched.
  - Intended behavior: keep one marker mapping in `tooling/generate/registry_sync.py`, generate consumer blocks for each existing target and role split, preserve all per-consumer marker sets, and leave `role.ts` prompt wording unchanged.
  - Regression: the three negative tests passed—an unregenerated canonical edit made `registry_sync.py --check` fail, regeneration made `scripts/validate-skills.sh` fail on the missing role marker, and deleting a `role.ts` sentence made the suite name that marker—followed by the full offline acceptance suite.

- Preview release tag parity:
  - Observed failure: the preview package manifest declared `0.1.2` while the README, reference, and package README documented raw-installer tags and arguments as `v0.1.0`, allowing a future tag to disagree with the shipped package version.
  - Intended behavior: treat the package manifest as authoritative, document the unreleased raw-installer tag as `v0.1.2` without creating or claiming the tag, and validate every bounded preview bootstrap URL and trailing installer argument against that manifest version.
  - Regression: `scripts/validate-skills.sh` now performs the offline parity check; changing the manifest temporarily to `0.1.3` made it fail with per-document mismatch messages, restoring `0.1.2` made it pass, and the full offline acceptance suite passed afterward.

- Preview Markdown type coverage:
  - Observed failure: the standalone preview package was outside the root Pi TypeScript include, its first package check found five source diagnostics, and `pi-tui` was only available nested under the coding-agent dependency rather than resolvable from the package.
  - Intended behavior: reuse one Pi install with a direct dev-only `pi-tui` pin, add an unpublished package-local check, keep schema and result literal narrowing type-only and erased from emitted JavaScript, normalize the theme handler to the host's `Promise<void>` contract with observational equivalence under that contract, and have the documented root command run both checks.
  - Regression: both `bash pi/scripts/typecheck.sh` and `bash pi/scripts/typecheck-preview-markdown.sh` report zero diagnostics after installation; the npm package validator and preview smoke fixture pass, while offline suites skip cleanly without dependencies.

- Diagnostics directory trust skips dependency trees:
  - Observed failure: project-root and directory-scoped `lsp_diagnostics` trust was rejected when `node_modules` contained protected-looking dependency filenames such as `credentials.d.ts`, making the trusted read-only path unusable after installing dependencies.
  - Intended behavior: skip `.git`, `node_modules`, and `.venv` while scanning diagnostics directories, keep protected files elsewhere fail-closed, and leave Serena's write-side descendant guard exhaustive.
  - Regression: `pi/tests/smoke.sh` covers dependency `credentials.d.ts` and `.env` as trusted, top-level and nested `.env` as gated, and the accepted dependency-tree dotenv trade-off; real installed-dependency verification remains an explicit phase check.

- Pi extension typecheck diagnostics resolved:
  - Observed failure: the first dependency-backed strict check reported five project diagnostics—one missing host-type import and four unnarrowed Firecrawl limit comparisons—and also exposed an assertion-cast gap in the Serena write-memory bound.
  - Intended behavior: type-check the existing Firecrawl and Serena approval predicates without changing their runtime guards, while importing the host context type as erased type-only metadata and replacing the write-side cast with proof-based narrowing.
  - Regression: after `npm install --prefix pi`, `bash pi/scripts/typecheck.sh` reports zero diagnostics; `pi/tests/smoke.sh` covers Firecrawl limit boundaries and optional, positive, zero, negative, and string Serena write-memory bounds. The check remains opt-in and is not run by the offline suites.

- Opt-in TypeScript checking for Pi extensions:
  - Observed failure: Pi extensions ran through `node --experimental-strip-types` without compiler checking, leaving annotations in approval-brokering code effectively decorative.
  - Intended behavior: provide a strict TypeScript check under `pi/` without changing runtime behavior or requiring dependencies for the offline validation suites.
  - Regression: after `npm install --prefix pi`, `bash pi/scripts/typecheck.sh` reports zero diagnostics; the check remains opt-in and is not run by the offline suites, while `pi/scripts/validate.sh` syntax-checks its entrypoint.

- Kernel/headroom deduplication:
  - Observed failure: the always-loaded kernel spent roughly 40% of its 12,000-byte cap on two-role delegation mechanics duplicated in the injected planner and worker prompts, even though b-agentic defaults to Off.
  - Intended behavior: keep Off/solo role selection, the sole-writer and same-CWD roster boundary, generated skill ownership, and the questionnaire contract in the kernel; keep handoff, Intercom, blocker, delivery, review, and post-approval commit mechanics in the role-specific prompts without weakening active-role behavior.
  - Regression: no automated coverage: no single check proves the moved rules end-to-end; kernel size guards, role-prompt marker assertions, planner/worker smoke prompt coverage, generated-sync checks, and role behavior fixtures retain the moved rules and detect kernel/prompt drift.

- Optional PR Markdown preview:
  - Observed failure: `b-pr-summary` ended with plain PR copy even though the installed preview capability could provide a formatted read-and-copy workflow.
  - Intended behavior: after producing a non-BLOCKED PR title and description, optionally offer or render the original Markdown source with `preview_markdown` using only string `markdown` and optional string `title` arguments; keep the preview skippable.
  - Regression: the `b-pr-summary` prompt regression contract in `tooling/validate/shared.py` asserts the preview guidance, while `python3 tooling/generate/registry_sync.py --check` verifies the generated skill remains synchronized.

- Accurate pi-lsp prerequisites:
  - Observed failure: the reference treated language-server binaries on `PATH` as a footnote and omitted pi-lsp's built-in default map, replacement semantics for custom configuration, and configuration resolution order, making a fresh install's empty diagnostics unclear.
  - Intended behavior: document the default server map, the binary-on-`PATH` prerequisite, replacement rather than merge behavior, and the `PI_LSP_CONFIG`/workspace/user resolution order without writing user-owned configuration.
  - Regression: no automated coverage: documentation-only; no installer or configuration behavior changed, and no automated assertion covers this prose. Accuracy depends on the upstream `@narumitw/pi-lsp@0.32.0` README.

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
  - Observed failure: the current installer and documentation still described the structured-question package as 2.6.2, so the approved 2.7.0 upgrade was not represented consistently across fresh installs and support guidance.
  - Intended behavior: install and track `npm:@juicesharp/rpiv-ask-user-question@2.7.0`; use `ask_user_question` for any interactive, user-facing material decision or blocker in planner or solo/Off work with 1–4 grouped questions, 2–4 concrete options with concise trade-offs, a recommended first option, and the extension's automatic custom-answer row. Retain the focused plain-text fallback when unavailable/noninteractive; emit exactly one privacy-safe user-input signal only for planner decisions/blockers; keep worker→planner questions in Intercom and native permission prompts for browser/external/privileged actions.
  - Regression: generated planner/worker guidance and b-commit structured approval wording are checked by `tooling/validate/shared.py`; `pi/tests/smoke.sh` covers retained task-complete/user-input notification behavior and package install/manifest state; installer package lifecycle is covered by `tests/smoke/lib.sh`; current package references in `README.md`, `REFERENCE.md`, `pi/configs/README.md`, and `docs/decision_design.md` stay aligned.

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
