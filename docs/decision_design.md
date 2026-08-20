# b-agentic Decision Design

## Scope and evidence

This document records the product, architecture, workflow, safety, tooling,
installation, and verification decisions evidenced by the tracked b-agentic
repository. It is a design record, not a new runtime contract: canonical
behavior remains in the files cited below. The inspection covered tracked
source, configuration, scripts, tests, canonical prompts/references, generated
skill assets, CI, and public/maintainer documentation. It excluded `.git`,
ignored/generated caches, and likely-secret files or credentials.

The product is intentionally small: b-agentic is a personal workflow built
around Pi, and b-agentic and Pi are treated as one integrated product, with Pi
as the shipped runtime. The governing principle is
"slim, strong, usable"; new workflow or prompt behavior needs an observed
failure mode and a narrow regression check. Evidence: `README.md`, `AGENTS.md`,
`CHANGELOG.md`.

## Product boundary and architecture

### Pi is the runtime boundary

- Ship a compact Pi kernel, native skills, first-party Pi extensions, and
  recommended MCP configuration rather than a runtime-neutral adapter layer.
- Keep shared workflow guidance in `references/kernel.template.md`; keep
  Pi-specific integration, extensions, config, and Pi smoke coverage under
  `pi/`.
- Preserve the deliberately slim surface: `references/` contains only the
  kernel template and MCP policy, and the suite audit caps the kernel at 120
  lines/12,000 bytes. Evidence: `AGENTS.md`,
  `tooling/validate/suite_audit.py`, `tooling/validate/shared.py`.

### Canonical sources own generated delivery assets

- `skills/registry.yaml` owns skill metadata and routing; each
  `skills/*/prompt.md` owns the canonical skill body.
- `references/kernel.template.md` owns the complete always-loaded kernel, and
  `references/mcp_operations.yaml` owns managed MCP classifications.
- `tooling/generate/registry_sync.py` renders `skills/*/SKILL.md`, the README
  skill table, kernel generated blocks, and the TypeScript MCP runtime sets.
  Generated files are delivery artifacts and must not be edited as sources.
- The generator uses a JSON-compatible YAML subset so the Python standard
  library can parse registry and policy files without an extra dependency.
  Evidence: `AGENTS.md`, `tooling/generate/registry_sync.py`,
  `scripts/validate-skills.sh`.

### Integration uses shallow seams

- The permission entrypoint is split by concern: local shell/filesystem gates
  live in `pi/extensions/b-agentic-permissions.ts`, MCP/custom-tool approval
  in `pi/extensions/b-agentic-mcp-permissions.ts`, and collaboration roles in
  `pi/extensions/b-agentic-role.ts`, `pi/extensions/b-agentic-planner.ts`, and
  `pi/extensions/b-agentic-worker.ts`.
- Shared helpers under `pi/extensions/b-agentic-support/` are not discovered as
  standalone Pi extensions. This keeps Pi's discovered extension set coherent
  while allowing focused policy modules and test exports.
- `/b-sync` refreshes managed assets; `/b-update` installs or updates RTK,
  Serena, CodeGraph, Bun, Pi, and extensions without pulling b-agentic. Bun-backed
  MCP packages are resolved and cached by `bunx` on first use. Independent
  dependency chains run in bounded stages and failures
  propagate. Evidence:
  `pi/scripts/install.sh`, `pi/extensions/b-agentic-sync.ts`,
  `pi/configs/README.md`.

### First-party extensions preserve policy while scaling cleanly

- Every first-party b-agentic extension—discovered entrypoints and shipped
  support modules under `pi/extensions/`—must follow coding best practices and
  be designed and optimized for performance, maintainability, extensibility,
  and long-term scalability. Optimization or refactoring must leave behavior,
  safety gates, fail-closed semantics, and observable outputs unchanged, with
  focused regression evidence before delivery. Evidence:
  `pi/extensions/b-agentic-permissions.ts`,
  `pi/extensions/b-agentic-mcp-permissions.ts`,
  `pi/extensions/b-agentic-support/shell.ts`,
  `pi/extensions/b-agentic-support/mcp.ts`, and `pi/tests/smoke.sh`.

## Workflow and skill design

### Route one intent to one active phase skill

- Route the current intent to one skill and sequence phases rather than mixing
  planning, building, validation, and shipping. The registry groups skills as
  Decide (`b-plan`, `b-research`, `b-design`), Build (`b-implement`, `b-init`,
  `b-refactor`), Validate (`b-debug`, `b-test`, `b-browser`, `b-review`,
  `b-agentic-audit`), and Ship (`b-commit`, `b-pr-summary`). Evidence:
  `references/kernel.template.md`, `skills/registry.yaml`, `README.md`.
- `b-plan` resolves ambiguity and produces an executable plan without edits;
  `b-research` supplies versioned/external facts with provenance;
  `b-implement` makes the smallest approved change; `b-refactor` owns named
  behavior-preserving transforms; `b-debug` confirms runtime causes before an
  authorized fix; `b-test` owns test mechanics/TDD/coverage; `b-browser`
  owns real-browser evidence; `b-review` reviews changed code; and
  `b-agentic-audit` compares the repository and design record for conformance
  drift. Evidence: the corresponding `skills/*/prompt.md` files.
- Keep shipping intent explicit: `b-commit` stages/commits only after the
  interactive exact-proposal confirmation, and `b-pr-summary` reads only local
  commit history/cached origin refs without contacting remotes. Evidence:
  `skills/b-commit/prompt.md`, `skills/b-pr-summary/prompt.md`,
  `pi/extensions/b-agentic-permissions.ts`.

### Resolve ambiguity before editing

- Prefer repository evidence and the smallest safe interpretation. If a
  material blocker remains, ask one focused question, wait, and re-evaluate;
  do not guess or add speculative infrastructure, compatibility paths, or
  impossible-state handling.
- Verification is part of execution: define the observable success condition,
  run the narrowest useful check, correct a clear in-scope failure, and stop
  when a failure exposes new ambiguity or scope drift.
- Keep prompts task-specific and avoid mandatory status blocks, state machines,
  subagent profiles, or other ceremony unsupported by evidence. Evidence:
  `references/kernel.template.md`, `skills/b-plan/prompt.md`,
  `skills/b-implement/prompt.md`, `tests/behavior/principles.json`,
  `tooling/validate/shared.py`.

### Planner/worker collaboration is explicit and single-writer

- Solo sessions default to `off`; the first session is not automatically a
  planner. Explicit `planner` and `worker` roles are selected by `/b-role` or
  `pi --b-role`. Evidence: `README.md`, `pi/configs/README.md`,
  `pi/extensions/b-agentic-role.ts`.
- Planner and worker roles are prompt-governed collaboration profiles, not
  role-specific tool gates: role selection preserves normal active tools and the
  shared shell, filesystem, MCP, and approval policies. The registry explicitly
  assigns all skills: the planner prompt enumerates in-scope `b-plan`, external
  `b-research`, `b-agentic-audit`, `b-review`, and `b-pr-summary` skills and its
  worker delegation list; the worker prompt likewise enumerates `b-design`,
  `b-implement`, `b-init`, `b-refactor`, `b-debug`, `b-test`, `b-browser`, and
  `b-commit` and its planner delegation list. Ownership is execution-only, so
  either role may inspect skills; direct user wording or no ready worker never
  permits planner implementation. Planner ownership is limited to read-only
  decision/planning, external research, audit/review, or release-summary
  coordination; implementation or mutation, runtime diagnosis, builds/tests,
  browser/operational verification, commits, mixed, and uncertain work belong
  to the worker. Unknown ownership defaults to worker while generation rejects
  missing or invalid owners. Worker mode is the sole worktree writer and the
  assigned worker executes its worker-owned task itself; it never re-delegates
  or hands that task to another worker. Independent shared policies still block
  dangerous commands, protected paths, unclassified or unmanaged MCP execution,
  and local or external mutations. Evidence: `skills/registry.yaml`,
  `tooling/generate/registry_sync.py`, `pi/extensions/b-agentic-planner.ts`,
  `pi/extensions/b-agentic-role.ts`, `pi/extensions/b-agentic-support/role.ts`,
  `pi/extensions/b-agentic-support/mcp.ts`.
- The planner settles a context-complete, bounded natural-language handoff before
  the worker edits. Both roles use `pending` before `send`/`reply`; an inbound
  ask requires `reply`, otherwise a fresh `list-cwd` supplies the verbatim
  target. The short ID displayed by that authoritative output is valid; guessed,
  reconstructed, extended, further-abbreviated, stale, display-name, and alias
  targets are not. Delivery is required, failed sends revalidate once without
  polling, and the planner waits for worker `send`. In delegated work, a
  blocker checks `pending`, replies if inbound, otherwise refreshes `list-cwd`
  and asks the assigning planner using its verbatim returned token; solo/Off
  blockers go to the user. External research stays with the planner. Every
  terminal worker result goes to the same assigning planner before pausing,
  including no-change and reported-gap outcomes.
- The latest approved plan, handoff, and clarifications form the delegated review
  baseline. Only delegated worktree-changing tasks require actual `b-review` of
  diff and verification; findings name location, evidence, impact, violated
  baseline, smallest correction, and regression check. Planner-owned audit or
  review requests bounded worker evidence instead of scripts/tests. After
  approval, the same worker may commit an unchanged reviewed snapshot only on
  explicit user request; content changes reopen review. There are no required
  protocol fields or parsed state machines. Evidence:
  `references/kernel.template.md`, `pi/configs/README.md`,
  `pi/extensions/b-agentic-support/role.ts`, `tests/behavior/roles.json`,
  `pi/tests/smoke.sh`.
- Planner attention is signaled through privacy-safe fixed text. The planner may
  end a response with exactly one of `B_AGENTIC_TASK_COMPLETE` (task complete
  and all delegated b-review gates passed; in b-review it sits on its own
  standalone line immediately before the final verdict line) or
  `B_AGENTIC_USER_INPUT_NEEDED` (paired with the installed `ask_user_question`
  tool for a focused user decision or blocker), never both. Questionnaire calls
  group 1–4 related questions, provide 2–4 concrete options with concise
  trade-offs, suffix the first recommended label with ` (Recommended)`, and
  leave the extension's automatic custom-answer row available; reserved labels
  `Other`, `Type something.`, and `Next` are not authored. If the package or
  interactive UI is unavailable, the fallback is one focused plain-text
  question plus the user-input signal. Both signals are omitted for normal
  planning, discovery, handoffs, intermediate updates, and reviews needing
  fixes. The planner-notify extension surfaces these signals as desktop
  notifications (`notify-send` on Linux, `osascript` on macOS, bounded timeout,
  notifier failures ignored) only while the planner role is active; the signal
  text never carries task or session content. Evidence:
  `pi/extensions/b-agentic-planner-notify.ts`,
  `pi/extensions/b-agentic-support/role.ts`, `references/kernel.template.md`,
  `pi/tests/smoke.sh`.
- Role-specific provider/model/thinking preferences are user-local and stored
  atomically under Pi agent state; role selection itself does not open a model
  picker. Evidence: `pi/extensions/b-agentic-role.ts`,
  `pi/extensions/b-agentic-support/role-models.ts`.

## Safety and approval design

### Command policy is allow, ask, or deny

- Routine repository-local commands, including build/test/package/script
  automation, may run automatically. External/shared mutations and dangerous
  but approvable actions require UI approval; prohibited destructive Git and
  Docker families are denied. No UI means approval-required actions fail
  closed. Evidence: `references/kernel.template.md`,
  `pi/extensions/b-agentic-support/shell.ts`,
  `pi/extensions/b-agentic-permissions.ts`.
- Parse compound shell segments and normalize wrappers (`rtk`, `env`, `sudo`,
  `git -C`, and related forms) before matching policy. Ambiguous expansion,
  control syntax, opaque interpreters, inline aliases, execution proxies,
  unknown package options, and outside-project executables fail closed to ask.
  Evidence: `pi/extensions/b-agentic-support/shell.ts`,
  `pi/tests/smoke.sh`.
- RTK is required for every command family it supports, including discovery;
  modern tools are direct fallbacks only where RTK has no native family. RTK
  improves command output but never bypasses approval or denial. Evidence:
  `references/kernel.template.md`,
  `pi/extensions/b-agentic-support/shell.ts`,
  `tooling/validate/session_readiness.py`.

### Protected paths and locality are first-class

- Protect dotenv/credential/key/certificate files, SSH/cloud config, Git
  internals, and secret-like paths. Public `.env.example` is allowed only
  outside protected parents; compound source filenames such as
  'provider-secrets.service.ts' are not blanket-blocked.
- Native reads of protected paths ask; native writes/edits are denied. Shell
  access and symlink-resolved paths are approval-gated or denied according to
  the same boundary. Outside-project native access asks, while project-confined
  paths are autonomous.
- Serena repository edits and memory operations are trusted only for safe,
  project-confined arguments. Directory-wide reads/edits inspect descendants
  and fail closed if protected or external descendants could be reached.
  Evidence: `pi/extensions/b-agentic-support/shell.ts`,
  `pi/extensions/b-agentic-support/mcp.ts`, `pi/tests/smoke.sh`.

### Pi permissions are policy guards, not a sandbox

- Approved repository build and test tools can execute repository-controlled
  code. The extension protects command intent and paths; it is not a process
  isolation boundary. Use Pi sandboxing or an isolated environment for
  genuinely untrusted code. Evidence: `REFERENCE.md`,
  `references/kernel.template.md`.
- Commit creation requires presenting an exact proposal and receiving explicit
  user approval in chat before staging or committing, as specified by
  `skills/b-commit/prompt.md`. Pushes are not performed by b-agentic. Role
  application preserves normal active tools; planner write/commit limits are
  governed by prompt-level skill ownership and shared policy, not role-specific
  tool exclusion. Regression evidence for role preservation is limited to the
  planner-active-tools and stale-planner-to-worker assertions in
  `pi/tests/smoke.sh`. Evidence: `skills/b-commit/prompt.md`,
  `pi/extensions/b-agentic-role.ts`, `pi/tests/smoke.sh`.

## MCP and external-evidence design

### One canonical operation policy drives runtime enforcement

- `references/mcp_operations.yaml` defines managed servers, operation classes,
  conditional argument keys, and runtime enforcement. Generated sets in
  `pi/extensions/b-agentic-support/mcp.ts` are checked against that source by
  `tooling/validate/mcp_policy.py` and `pi/scripts/validate_mcp_policy.py`.
- The managed set is Serena, CodeGraph, Context7, Linear, Brave Search, Firecrawl, and
  Playwright. Configured servers use lazy lifecycle, proxy execution by
  default, and a 30-second request timeout. Linear uses the hosted read-only endpoint,
  OAuth `read` scope, and an exact `get_issue` allowlist. Shared managed-MCP
  classifications—not the selected role—govern gateway, direct-tool, and
  `mcpScript` use. The capability matrix permits cached non-executing
  status/server-list/search/describe/instructions metadata for any server and
  policy-classified managed retrieval/research with existing direct
  Serena/CodeGraph or explicit `mcp__` aliases and concrete safe arguments.
  It blocks or gates unsafe Playwright actions (such as navigation and
  interaction) while permitting policy-classified safe Playwright retrieval;
  it blocks or gates Serena mutations/lifecycle, auth/connect/UI actions,
  selector mixtures, unclassified or unmanaged execution, and local/external
  mutation under normal policy; the explicit persisted `b-auto-mode` opt-in is
  the exception, auto-allowing approval requests while explicit deny decisions
  remain blocked. With auto mode off, approval-required actions retain normal
  UI/fail-closed behavior, and roles do not alter this policy. Narrow
  deterministic regression
  evidence is table-driven classifier, broker, active-tool, shell, Git, and
  CodeGraph allow/deny coverage in `pi/tests/smoke.sh`. Public tool evidence is Linear issues
  [#1028](https://github.com/linear/linear/issues/1028), [#1060](https://github.com/linear/linear/issues/1060), and [#747](https://github.com/linear/linear/issues/747); no authenticated live inventory was available for this change. Separately, the observed routing failure was that a bare Linear-style ID could be treated as generic implementation or research rather than planning; the intended behavior routes it to `b-plan`. Regression evidence is the human-scored `linear-issue-plan-routing` scenario in `tests/behavior/routing.json`, structurally validated with `python3 pi/tests/prompt_effectiveness.py --routing --validate-inputs --scenario=linear-issue-plan-routing`. Evidence:
  `references/mcp_operations.yaml`, `pi/configs/mcp.user.template.json`,
  `pi/scripts/validate.sh`.
- Auto-approval is exact and least-privilege: read-only/trusted operations are
  allowed; conditional operations require known keys and safe argument values;
  external mutation, uploads, lifecycle, auth, screenshots, navigation, and
  other unsafe operations require approval under normal policy. The explicit
  persisted `b-auto-mode` opt-in auto-allows those approval requests while
  explicit denies remain blocked. Unmanaged servers and ambiguous
  gateway selectors are not trusted. Evidence:
  `references/mcp_operations.yaml`,
  `pi/extensions/b-agentic-support/mcp.ts`,
  `pi/extensions/b-agentic-mcp-permissions.ts`.

### Tool ownership prevents duplicate architecture queries

- Pi native `read`/`edit`/`write` is preferred for routine repository work. Serena
  starts after native search/read and is reserved for a concrete exact-symbol,
  reference, implementation, diagnostic, or reference-aware refactor question
  where it materially improves safety or precision; relevant onboarding and
  durable project memories remain explicit exceptions. Routine Serena reads,
  searches, and edits are prohibited; serialize Serena requests rather than
  parallelizing or batching them because concurrency can hang or time out.
- CodeGraph owns repository-wide architecture, dependency/call flows, impact,
  route-to-handler discovery, and affected-test discovery only when native
  inspection cannot settle a concrete question; do not initialize its local
  index merely because work spans files, and initialize it only for that
  question when absent.
- Context7 is first for versioned framework/API facts. Firecrawl provides
  bounded primary public research (including `research_*` and developer
  search), and Brave provides independent corroboration or specialized search
  modalities. Private repository material is never sent to public search.
- Research uses direct policy-classified calls and cached metadata; `mcpScript`
  follows the same shared approval policy in every role. Serena requests remain
  serialized and are not included in parallel or batched calls. Evidence:
  `REFERENCE.md`,
  `references/kernel.template.md`, `skills/b-research/prompt.md`,
  `skills/b-plan/prompt.md`, `skills/b-test/prompt.md`.

### Browser evidence is ordered and honest

- Prefer existing CI/script evidence, then approved navigation/interactions,
  snapshot/find, focused console/network evidence, requested screenshot, and
  cleanup. A generic page load is not proof of a requested UI state.
- Evidence bundles live only below an explicitly approved directory and record
  requested state, URL, snapshot, console, network, screenshot (null unless
  collected), and cleanup result. Screenshot coverage is never claimed without
  an actual screenshot. Evidence: `skills/b-browser/prompt.md`,
  `tooling/validate/browser_evidence.py`, `tests/behavior/browser-evidence.json`.

## Installation, configuration, and lifecycle

### Install is source-backed, opt-in where state changes are external

- `install.sh` clones or updates a local source checkout, supports reviewed
  `--ref` pins, then sources the shared Pi installer. `--sync` updates only
  managed assets; `--update` reconciles RTK, uv/Serena, CodeGraph, Bun, Pi,
  and Pi extensions, installing missing components without
  pulling b-agentic. Evidence: `install.sh`, `pi/scripts/install.sh`,
  `REFERENCE.md`.
- RTK is required; Pi CLI, Serena, CodeGraph, Bun, and Pi packages reconcile
  automatically without prompts or opt-outs. Bun-backed MCP packages are
  resolved and cached by `bunx` on first use. Modern shell tools remain
  user-installed because they generally require sudo; readiness
  reports provide install hints. Installer progress is dependency-free ASCII on
  interactive non-dumb TTYs and newline-based in redirected/CI output. Evidence:
  `install.sh`, `pi/scripts/install.sh`, `tooling/install/common.sh`,
  `tests/smoke/install.sh`.
- The template installs managed assets under `~/.pi/agent`, stores snapshots,
  backups, references, templates, and an install manifest under
  `~/.pi/agent/b-agentic`, and keeps user-owned kernel/config/extension/skill
  changes rather than overwriting or deleting them silently. Evidence:
  `pi/scripts/install.sh`, `tooling/install/common.sh`,
  `tooling/install/manifest_uninstall.py`.
- MCP configuration is merged rather than replaced: unrelated user servers
  survive, prompted secrets are written only to user config through a private
  input pipe, and config uses lazy servers with API-key placeholders or deferred OAuth. Linear
  authentication happens only through the adapter's normal flow when needed; readiness does not infer or claim its OAuth state. Evidence:
  `pi/configs/mcp.user.template.json`, `tooling/install/common.sh`,
  `tooling/install/json_cleanup.py`, `tests/smoke/install.sh`.
- Uninstall can use the manifest without the source checkout, but removes only
  unchanged managed content, restores recorded user backups, preserves
  modified/symlinked files, constrains manifest paths under the home directory,
  and never removes installed packages. Evidence:
  `tooling/install/manifest_uninstall.py`, `tests/smoke/install.sh`.

### Readiness is explicit and degraded states are visible

- `scripts/mcp-doctor.sh` distinguishes missing adapter, malformed config,
  missing launchers/credentials, configured OAuth-authentication-unverified state, and ready servers. A valid Linear configuration is nonblocking because the doctor cannot observe adapter OAuth state. Live MCP schema probing is
  opt-in and reports drift/suggestions without editing policy; it does not acquire OAuth tokens, so Linear is not live-probed until an authenticated adapter path is available.
- `scripts/skill-doctor.sh` checks installed Pi skill payloads and kernel
  discovery. Install reports expose readiness and next steps instead of hiding
  missing optional infrastructure. Evidence: `tooling/validate/mcp_doctor.py`,
  `tooling/validate/mcp_probe.py`, `tooling/validate/skill_doctor.py`,
  `tooling/install/common.sh`.

## Verification and change discipline

- Generator/source synchronization: `python3 tooling/generate/registry_sync.py
  --check` (or the refresh command when canonical sources change).
- Default validation is local and dependency-light: `scripts/validate-skills.sh`
  runs shared prompt/generated checks, routing and behavior fixtures, MCP
  policy/probe self-tests, session-readiness self-tests, prompt input
  construction, browser evidence path checks, and Pi integration markers.
- Release validation adds RTK compatibility and the isolated installer smoke
  matrix: `scripts/validate-skills.sh --release`. CI runs this on Ubuntu and
  macOS and also runs `scripts/b-agentic-audit.sh`. Evidence:
  `.github/workflows/validate.yml`, `tooling/validate/run.sh`,
  `scripts/b-agentic-audit.sh`.
- Pi extension behavior is exercised with Node's strip-types harness rather
  than requiring a full Pi runtime. Installer smoke tests use isolated homes,
  mocked CLIs, TTY prompts, merge/uninstall cases, collision/symlink safety,
  optional tooling/package lifecycle, and doctor readiness. Evidence:
  `pi/tests/smoke.sh`, `tests/smoke/lib.sh`, `tests/smoke/install.sh`.
- Prompt effectiveness is intentionally opt-in, potentially billable, and
  human-scored. Inputs and command construction are validated without model
  calls; model comparisons require pinned provider/model/thinking settings and
  include rubric-backed fixtures. Evidence:
  `pi/tests/prompt_effectiveness.py`, `tests/behavior/principles.json`,
  `tests/behavior/roles.json`, `tests/behavior/routing.json`.
- Live MCP schema probing and browser evidence are opt-in because they start
  processes/network activity or write approved evidence artifacts. Neither
  lane is implied by static validation. Evidence:
  `tooling/validate/mcp_doctor.py`, `skills/b-browser/prompt.md`,
  `REFERENCE.md`.
- Repository/design-conformance auditing is separate from changed-code review:
  `scripts/b-agentic-audit.sh` runs structural and decision-design traceability
  checks, while `b-agentic-audit` reads canonical sources and reports semantic
  drift. The automated traceability check does not mechanically prove all
  prose semantics. Evidence: `AGENTS.md`, `CHANGELOG.md`,
  `scripts/b-agentic-audit.sh`.

## Intentional non-goals

- No runtime-neutral adapters, Cursor/Claude/Codex integration, or extra
  runtime registry: the shipped boundary is Pi. Evidence: `CHANGELOG.md`,
  `README.md`, repository layout.
- No process sandbox, blanket protection from repository-controlled test/build
  code, or claim that command approval is isolation. Evidence: `REFERENCE.md`,
  `references/kernel.template.md`.
- No automatic external/shared mutation, MCP auth bootstrap, broad crawling,
  Firecrawl feedback/agent/crawl/monitor actions, Playwright navigation or
  screenshot persistence, or public research using private local material.
  These remain approval-gated or explicitly opt-in. Evidence:
  `references/mcp_operations.yaml`,
  `pi/extensions/b-agentic-support/mcp.ts`, `skills/b-research/prompt.md`,
  `skills/b-browser/prompt.md`.
- No mandatory planner/worker protocol fields, delegation chains, repeated
  roster polling, or planner-side implementation. No completion claim before
  the actual `b-review` gate for delegated work. Evidence:
  `references/kernel.template.md`, `tests/behavior/roles.json`,
  `pi/tests/smoke.sh`.
- No automatic prompt-effectiveness model calls, live MCP schema checks, or
  screenshot claims from simulated/unit tests. Evidence:
  `pi/tests/prompt_effectiveness.py`, `tooling/validate/mcp_doctor.py`,
  `tests/behavior/browser-evidence.json`.
- No broad cleanup or speculative compatibility work when changing one scoped
  behavior; prompts and maintainer guidance require the smallest coherent
  change and evidence-backed follow-up only. Evidence: `AGENTS.md`,
  `skills/b-implement/prompt.md`, `tests/behavior/principles.json`.
