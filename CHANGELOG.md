# Changelog

All notable shipped revisions of b-agentic are recorded here. Released version headings match immutable Git tags of the form `vYYYY.MM.DD` (or `vYYYY.MM.DD.N` for same-day revisions).

## Unreleased

### Changed

- Planner/worker Pi profiles:
  - Observed failure: prose-only handoffs could not enforce a read-only coordinator, a sole writer, or the worker's assigned skill across Intercom sessions.
  - Intended behavior: `/b-role planner|worker|off` persists a Pi role overlay; planner mode hard-blocks mutations, worker mode requires a structured assignment and exact skill read, and `send` drives repeated result/review iterations.
  - Regression: role-mode behavioral fixtures in `pi/tests/smoke.sh`; kernel/extension markers in `pi/scripts/validate.sh`, `tooling/validate/behavior.py`, and `tooling/validate/shared.py`.
- Intercom delegation protocol:
  - Observed failure: workers did not reliably activate the handoff skill, delegation duplicated serial work and ran slower than one session, and `reply` failed when neither side had a unique pending `ask`.
  - Intended behavior: delegate only beneficial parallel work, activate one named worker skill, use `send` for handoff/completion, and reserve `ask`/`reply` for blocking questions.
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
