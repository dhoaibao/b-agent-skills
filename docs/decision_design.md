# b-agentic Decision Design

This is a compact, evidence-backed summary of current b-agentic design decisions.
Canonical sources remain authoritative: this record does not replace the kernel,
skill prompts, policy, installer, or tests. It records durable choices and
boundaries, not a change history or a second runtime contract. Evidence:
`README.md`, `AGENTS.md`, `references/kernel.template.md`,
`tooling/validate/decision_design.py`.

## Scope and evidence

b-agentic and Pi are one integrated personal workflow product with Pi as the shipped runtime; this record summarizes current decisions supported by tracked repository sources.

### Slim, strong, and usable
- **Slim:** choose the smallest evidence-backed fit; remove duplication, ceremony, and speculative complexity.
- **Strong:** preserve explicit safety, evidence, and verification boundaries, with a small observable check when a decision changes.
- **Usable:** retain direct, predictable user paths.
This decision applies to future b-agentic repository source, docs, tooling, and CI changes, including skills, installers, extensions, configuration, validators, and tests; it does not apply to the installed runtime kernel or create a generic runtime policy. Necessary compatibility/security fixes remain in scope, so slimness never demands cosmetic reduction.
Evidence: `AGENTS.md`, `README.md`, `REFERENCE.md`, `tooling/validate/decision_design.py`.

## Product boundary and architecture

### Runtime and ownership

- Ship a compact Pi kernel, native skills, first-party Pi extensions, and
  recommended MCP configuration; do not add a runtime-neutral adapter layer.
- Keep shared guidance in `references/`; keep Pi integration, configuration,
  extensions, scripts, and smoke coverage under `pi/`. Keep the always-loaded
  kernel within its measured line and byte limits; a limit exception requires an
  explicit decision rather than a silent increase or weakened rule.
- `skills/registry.yaml` owns skill metadata, routing, phase, and execution
  ownership; each `skills/*/prompt.md` owns its canonical skill body.
  `references/kernel.template.md` and `references/mcp_operations.yaml` own the
  shared kernel and managed MCP classifications.
- `tooling/generate/registry_sync.py` renders generated skills, README and kernel
  blocks, role prompts, and runtime policy sets. Generated assets are delivery
  outputs, not sources; registry and policy files use the repository's
  dependency-light JSON-compatible YAML subset.

### Extension seams

Local shell/filesystem policy, MCP approval, roles, auto mode, and synchronization
use separate Pi entrypoints; focused support modules are not discovered as extra
standalone extensions. The inline Markdown preview is a default first-party
extension and an independently distributable package under
`pi/packages/preview-markdown/`.

Evidence: `references/kernel.template.md`, `skills/registry.yaml`,
`tooling/generate/registry_sync.py`, `pi/extensions/b-agentic-permissions.ts`,
`pi/extensions/b-agentic-support/mcp.ts`,
`pi/packages/preview-markdown/package.json`.

## Workflow and skill design

### Routing and roles

Route each request to one active phase skill rather than mixing planning,
building, validation, and shipping. The registry groups skills into Decide,
Build, Validate, and Ship. `b-plan` resolves ambiguity; `b-research` supplies
external or versioned facts; `b-frontend` owns UI implementation;
`b-implement` handles scoped non-UI implementation; named refactors, runtime
diagnosis, test mechanics, browser evidence, changed-code review, repository
audit, commits, and PR summaries stay with their respective skills.

Sessions default to `off`; `/b-role` or `pi --b-role` selects explicit planner or
worker roles. The planner owns read-only planning, external research, audit,
review, and release-summary coordination. It delegates worker-owned mutation,
diagnosis, builds, tests, browser or operational verification, and commits. The
worker is the sole worktree writer and does not re-delegate. Handoffs name
expected paths or symbols, scope, invariants, acceptance criteria, and checks;
delegated worktree changes require actual `b-review` before approval.

### Consultation and coordination

- `b_consult` is an optional planner-only one-shot tool. Each call receives
  bounded context in a fresh in-memory session with read-only repository
  inspection and the existing MCP gateway only under normal policy. It has no
  outer history, writes, shell, browser, Intercom, delegation, or worktree
  access. Output is bounded natural language with sanitized failures and no
  retry or model fallback.
- Material handoffs use Intercom `send`; focused blockers use `ask`. Roles check
  `pending` before outbound coordination; an inbound ask is answered immediately,
  otherwise `list-cwd` supplies the current target. The planner waits for a
  delivered worker result, including no-change, blocked, and gap outcomes.
- User-facing material decisions use `ask_user_question` with grouped questions,
  concrete options, a recommended first option, and the automatic custom-answer
  row. A focused plain-text question is the fallback when unavailable. Native
  permission prompts remain for browser, external, and privileged actions.
- Provider, model, and thinking preferences are user-local state; role selection
  does not open a model picker.

Evidence: `references/kernel.template.md`, `skills/registry.yaml`,
`skills/b-plan/prompt.md`, `skills/b-review/prompt.md`,
`pi/extensions/b-agentic-consult.ts`,
`pi/extensions/b-agentic-support/role.ts`, `pi/tests/smoke.sh`.

## Safety and approval design

### Command and path boundaries

- Routine repository-local commands, including build, test, package, and script
  automation, run automatically. External/shared mutations and dangerous but
  approvable actions require approval; destructive Git and Docker families are
  denied, and approval-required actions fail closed without UI.
- RTK is required for every supported command family. Modern tools are direct
  fallbacks only where RTK has no native family; RTK never bypasses approval.
  Compound shell segments and wrappers such as `rtk`, `env`, `sudo`, and `git -C`
  are normalized before policy matching. Ambiguous expansion, opaque execution,
  unknown package options, and outside-project executables fail closed to ask.
- Protect dotenv, credential, key, certificate, SSH/cloud configuration, Git
  internals, and other secret-like paths. Protected native reads ask; native
  writes and edits are denied. Symlink-resolved paths, directory-wide
  operations, outside-project paths, and Serena writes retain the same
  project-confined, fail-closed boundary.

Approval is a policy guard, not a process sandbox: repository-controlled build
and test tools can execute code. Use Pi sandboxing or an isolated environment for
untrusted code. Commit creation requires an exact proposal and explicit
approval; b-agentic never pushes.

Evidence: `references/kernel.template.md`,
`pi/extensions/b-agentic-support/shell.ts`,
`pi/extensions/b-agentic-support/mcp.ts`,
`pi/extensions/b-agentic-permissions.ts`, `skills/b-commit/prompt.md`,
`pi/tests/smoke.sh`.

## MCP and external-evidence design

### Canonical policy and tool ownership

`references/mcp_operations.yaml` is the canonical classification for managed
servers, operation classes, conditional arguments, and runtime enforcement.
Generated runtime sets are checked against it. The managed servers are Serena,
CodeGraph, Context7, Linear, Mobbin, Brave Search, Firecrawl, and Playwright;
roles do not change active tools or MCP approval policy. Gateway calls require an
explicit managed server and matching tool, and nested `mcpScript` calls retain
the same policy. Read-only/trusted lifecycle operations may be automatic; safe
conditional reads and project-local conditional operations require validated
arguments. Unsafe or unclassified operations, uploads, auth, and external
mutations require approval or remain blocked. Linear is read-scoped with an
exact `get_issue` allowlist, and Mobbin has an exact read-only search allowlist.
Persisted `b-auto-mode` may auto-allow approval requests, but explicit denies
remain effective.

Native `read`/`edit`/`write` is preferred for routine work. Serena is reserved
for concrete exact-symbol, reference, implementation, diagnostic, or
reference-aware refactor questions where it materially improves precision, and
requests are serialized. CodeGraph is for concrete repository-wide architecture,
dependency, impact, route, or affected-test questions native inspection cannot
settle. Context7 is first for versioned API facts; Firecrawl provides bounded
primary public research and Brave provides corroboration. Private repository
material is never sent to public search.

### Browser and UI evidence

Browser work prefers existing checks, approved navigation/interactions,
snapshot/find, focused console or network evidence, requested screenshots, and
cleanup in that order. Evidence bundles stay below an explicitly approved
directory and record requested state and cleanup; screenshots are reported only
when collected. Unsafe browser mutations remain approval-gated.

UI direction is contextual rather than a generic preset. `b-design` and
`b-frontend` make a task-conditional design read using repository and product
evidence; `b-browser` performs visual assessment only when an approved brief,
design guidance, or supplied reference provides concrete criteria.

Evidence: `references/mcp_operations.yaml`,
`pi/extensions/b-agentic-support/mcp.ts`,
`pi/extensions/b-agentic-mcp-permissions.ts`, `skills/b-research/prompt.md`,
`skills/b-browser/prompt.md`, `tooling/validate/mcp_policy.py`,
`tooling/validate/browser_evidence.py`.

## Installation, configuration, and lifecycle

### Source-backed installation

- Root `install.sh` bootstraps or updates a local source checkout and delegates
  managed Pi assets to `pi/scripts/install.sh`. `--ref` supports reviewed pins;
  `--sync` refreshes managed assets; `--update` reconciles RTK, Pi, and configured
  tooling without pulling b-agentic into the source checkout.
- Managed snapshots, backups, references, templates, and the manifest live under
  `~/.pi/agent/b-agentic`. User-owned kernel, configuration, and skill changes
  are preserved; extension collisions are backed up before replacement and
  restored only when installed content is unchanged. Optional tooling readiness
  is reported rather than inferred from a template or hidden behind file copy.

### Configuration, uninstall, and readiness

MCP configuration is merged rather than replaced: unrelated user servers
survive, prompted secrets use the installer's private input path, and managed
entries use lazy launchers, placeholders, or deferred OAuth. Linear and Mobbin
readiness does not claim OAuth authentication the adapter cannot observe.

Manifest-only uninstall is constrained to the user's home directory. It removes
unchanged managed content, restores recorded backups, preserves modified or
symlinked content, and never removes installed packages or unrelated user data.

`scripts/mcp-doctor.sh` distinguishes missing adapters, malformed configuration,
missing launchers or credentials, configured-but-unverified OAuth, and ready
servers. `scripts/skill-doctor.sh` checks installed skill payloads and kernel
discovery. Live MCP schema probing is opt-in, reports drift without editing
policy, and does not acquire OAuth tokens.

Evidence: `install.sh`, `pi/scripts/install.sh`, `tooling/install/common.sh`,
`tooling/install/manifest_uninstall.py`, `pi/configs/mcp.user.template.json`,
`tooling/validate/mcp_doctor.py`, `tooling/validate/skill_doctor.py`,
`scripts/mcp-doctor.sh`.

## Verification and change discipline

- Source and generated synchronization uses
  `python3 tooling/generate/registry_sync.py --check`. Local validation is
  dependency-light: `scripts/validate-skills.sh` runs generated, skill,
  CHANGELOG, routing, behavior, policy, readiness, prompt-input,
  browser-evidence, and Pi integration checks. `scripts/b-agentic-audit.sh`
  checks the decision record and suite structure.
- Release validation adds RTK compatibility and isolated installer smoke
  coverage. CI runs the release path on Ubuntu and macOS and also runs the
  deterministic b-agentic audit.
- `bash pi/scripts/typecheck.sh` is dependency-backed and opt-in; after Pi
  dependencies are installed it checks root extensions and the standalone
  preview package. Prompt-effectiveness model calls, live MCP probing, and
  browser evidence that starts processes, uses the network, or writes artifacts
  are opt-in; static validation does not imply live readiness or visual proof.
- `b-agentic-audit` is read-only and distinct from changed-code `b-review`. It
  covers source/design conformance, whole-project and first-party-extension
  health, canonical skill/kernel quality, and currentness/MCP compatibility.
  Actual drift is `NEEDS FIXES`; unavailable required evidence is a follow-up;
  `READY FOR PR` requires all required dimensions to be verified.
- Canonical source changes regenerate delivery assets and run the narrowest
  useful checks. Documentation and validator changes remain evidence-backed and
  do not silently alter runtime policy. Review findings identify location,
  evidence, impact, violated baseline, smallest correction, and a check.

Evidence: `tooling/generate/registry_sync.py`,
`tooling/validate/decision_design.py`, `tooling/validate/run.sh`,
`scripts/validate-skills.sh`, `scripts/b-agentic-audit.sh`,
`.github/workflows/validate.yml`, `pi/scripts/typecheck.sh`,
`pi/tests/prompt_effectiveness.py`.

## Intentional non-goals

- No runtime-neutral adapters, non-Pi runtime integrations, or extra runtime
  registry; Pi is the shipped boundary.
- No process-sandbox claim, blanket protection from repository-controlled build
  or test code, or approval shortcut that replaces isolation.
- No automatic external/shared mutation, MCP authentication bootstrap, broad
  crawling, unsafe Firecrawl actions, Playwright navigation, screenshot
  persistence, or public research using private local material.
- No mandatory planner/worker state machine, protocol-field parser, delegation
  chain, repeated roster polling, planner-side implementation, or completion
  claim before delegated `b-review`.
- No automatic prompt-effectiveness model calls, live MCP checks, screenshot
  claims from simulated or unit tests, broad cleanup, or speculative
  compatibility work when a smaller evidence-backed change is sufficient.

Evidence: `README.md`, `REFERENCE.md`, `references/kernel.template.md`,
`references/mcp_operations.yaml`, `skills/b-browser/prompt.md`,
`skills/b-research/prompt.md`, `tests/behavior/roles.json`,
`tests/behavior/browser-evidence.json`.
