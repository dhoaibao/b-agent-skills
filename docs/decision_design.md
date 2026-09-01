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
- If a new or tightened kernel rule exceeds either guard and cannot be reduced
  below it without materially weakening accuracy or tightness, stop and present
  the user with a justified suitable new limit for approval; do not dilute the
  rule or silently raise the limit.

### Canonical sources own generated delivery assets

- `skills/registry.yaml` owns skill metadata and routing; each
  `skills/*/prompt.md` owns the canonical skill body.
- `references/kernel.template.md` owns the complete always-loaded kernel, and
  `references/mcp_operations.yaml` owns managed MCP classifications.
- `tooling/generate/registry_sync.py` renders `skills/*/SKILL.md`, the README
  skill table, kernel generated blocks, `pi/extensions/b-agentic-support/role.ts`,
  and the TypeScript MCP runtime sets. Generated files are delivery artifacts
  and must not be edited as sources.
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
- The discovered `pi/extensions/b-agentic-auto-mode.ts` entrypoint owns the
  persisted `b-auto-mode` opt-in.
- Shared helpers under `pi/extensions/b-agentic-support/` are not discovered as
  standalone Pi extensions. This keeps Pi's discovered extension set coherent
  while allowing focused policy modules and test exports.
- The inline Markdown preview ships as a first-party extension installed by
  default through `pi/scripts/install.sh`, sourced from
  `pi/packages/preview-markdown/extensions/b-agentic-preview-markdown.ts`, and
  is separately distributable as the standalone Pi package described by
  `pi/packages/preview-markdown/package.json`, via the version-pinned raw
  installer `pi/scripts/install-preview-markdown.sh` or the npm path
  `npm:@dhoaibao/preview-markdown` documented in
  `pi/packages/preview-markdown/README.md`, without installing the broader
  bundle. The publishing procedure is in `docs/publish-preview-markdown.md`.
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
  Decide (`b-plan`, `b-research`, `b-design`), Build (`b-frontend`, `b-implement`,
  `b-init`, `b-refactor`), Validate (`b-debug`, `b-test`, `b-browser`, `b-review`,
  `b-agentic-audit`), and Ship (`b-commit`, `b-pr-summary`). Evidence:
  `references/kernel.template.md`, `skills/registry.yaml`, `README.md`.
- `b-plan` resolves ambiguity and produces an executable plan without edits;
  `b-research` supplies versioned/external facts with provenance;
  `b-frontend` owns contextual frontend/UI implementation and styling;
  `b-implement` is the scoped non-UI/general implementation fallback; `b-refactor`
  owns named behavior-preserving transforms; `b-debug` confirms runtime causes
  before an authorized fix; `b-test` owns test mechanics/TDD/coverage;
  `b-browser` owns real-browser evidence; `b-review` reviews changed code; and
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

### b-init generates four-section evidence-backed project supplements

- Observed failure: b-init could produce generic AGENTS.md guidance without
  inventorying the local language/package stack, tooling, canonical docs, or
  observable technical risk surfaces. Its seven overlapping top-level sections
  could also duplicate verification (profile bullets plus a separate section)
  and split navigation, canonical ownership, and local edit boundaries across
  redundant headings. Durable project changes could also leave recorded facts
  stale or omit new durable facts, while unrelated edits could cause unnecessary
  AGENTS.md churn. It could therefore invent commands or standards, blur enforced
  conventions with contextual secure-coding advice, and duplicate the always-loaded
  kernel.
- Intended behavior: b-init inventories manifests, lint/format/type/test/CI
  configuration, local docs, and detected request/input/auth, persistence,
  rendering, integration, and infrastructure surfaces before drafting. The
  managed block uses exactly four top-level sections, in order: `Repository
  Purpose`, `Project Profile`, `Project Map and Ownership`, and `Verification`.
  Project Profile owns evidence-backed conventions and non-structural scope
  gaps; Project Map and Ownership is the sole owner of navigation,
  canonical-source/generated-output ownership, and local edit boundaries, so
  each fact appears once; and Verification lists each existing repository
  command once, recording focused TODOs/gaps only when commands are absent.
  Legacy names are forbidden at any Markdown heading depth, while descriptive
  nested headings remain allowed when they do not create duplicate fact
  buckets. Under the `Project Map and Ownership` section's local edit-boundaries
  guidance, when a change makes a recorded project fact stale or introduces a
  durable project purpose, convention, boundary, ownership rule, map entry, or
  verification command, it updates the relevant AGENTS.md fact in the same
  change; otherwise it leaves AGENTS.md unchanged, including for unrelated code
  edits. It includes only narrowly relevant practices, distinguishes config- or
  documentation-backed conventions from contextual security advice, labels
  project-specific bullets with scope and evidence, and does not restate or
  weaken generic kernel workflow, tool, or secret policy.
- Regression: `skills/b-init/prompt.md` and generated
  `skills/b-init/SKILL.md` carry structural anchors for the inventory, exact
  four-section order, non-redundant headings, profile distinction, ownership
  mapping, command de-duplication, and kernel-boundary rules.
  `tests/behavior/init-guidance.json` provides human-scored TypeScript/web and
  minimal-repository scenarios that must require the common four-section
  structure, one owner per fact category, rejection of legacy headings at
  any depth, and the bounded stale-guidance rule under Project Map and
  Ownership's local edit-boundaries guidance rather than as a standalone
  instruction; `tooling/validate/shared.py` records the observed
  failure/intended behavior, validates the canonical prompt/generated anchors
  and fixture contract, and structurally checks this repository's managed
  `AGENTS.md` markers, section order, heading exclusions, and unique inline-code
  commands within `## Verification`, while `tooling/validate/run.sh` runs the
  fixture's non-network `--validate-inputs` check. The narrow checks are
  `python3 tooling/generate/registry_sync.py --check` and
  `python3 pi/tests/prompt_effectiveness.py --fixtures
  tests/behavior/init-guidance.json --skill skills/b-init/SKILL.md
  --validate-inputs`.

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
  `b-frontend`, `b-implement`, `b-init`, `b-refactor`, `b-debug`, `b-test`,
  `b-browser`, and `b-commit` and its planner delegation list. Ownership is
  execution-only, so
  either role may inspect skills; direct user wording or no ready worker never
  permits planner implementation. Planner ownership is limited to read-only
  decision/planning, external research, audit/review, or release-summary
  coordination; implementation or mutation, runtime diagnosis, builds/tests,
  browser/operational verification, commits, mixed, and uncertain work belong
  to the worker. Unknown ownership defaults to worker while generation rejects
  missing or invalid owners. The planner boundary forbids worktree mutation,
  including edits, patches, commits, builds, tests, formatters, generators, and
  commands that write—including building or initializing local indexes/caches
  such as CodeGraph—but permits non-mutating audit/validation scripts and
  read-only Git. Worker mode is the sole worktree writer and the assigned worker
  executes its worker-owned task itself; it never re-delegates or hands that
  task to another worker. Independent shared policies still block
  dangerous commands, protected paths, unclassified or unmanaged MCP execution,
  and local or external mutations. Evidence: `skills/registry.yaml`,
  `tooling/generate/registry_sync.py`, `pi/extensions/b-agentic-planner.ts`,
  `pi/extensions/b-agentic-role.ts`, `pi/extensions/b-agentic-support/role.ts`,
  `pi/extensions/b-agentic-support/mcp.ts`.
- Tool-level guidance alone did not give the planner a reliable selection criterion
  for `b_consult`, and the original structured response contract made occasional
  independent advice unavailable when the provider returned incomplete or
  non-JSON text. The replacement keeps `b_consult` planner-only and optional for
  hard decisions or plan reviews after bounded local discovery; each call starts a
  fresh in-memory session that independently inspects the current repository with
  `read`, `grep`, `find`, and `ls`, and may use the existing `mcp` research gateway
  only under normal adapter authentication, approval, and managed-operation policy.
  It receives bounded caller text but no outer conversation history, and has no
  write, shell, browser, Intercom, delegation, or worktree-writing capability.
  Output is bounded natural-language advice that distinguishes observed evidence
  from inference and recommendation. Evidence and regression check:
  `pi/extensions/b-agentic-consult.ts`, `pi/extensions/b-agentic-role.ts`,
  `pi/extensions/b-agentic-support/role-models.ts`, `pi/tests/smoke.sh`.
- The consultation response is intentionally not parsed as strict JSON or split into
  response modes. Natural-language output is truncated to a bounded size and
  returned with an explicit advisory-not-evidence frame. Timeout, caller abort,
  missing configuration, unavailable model/provider, authentication, empty output,
  and provider failures return clear sanitized errors without model fallback or
  retry. A successful consultation may be cited only when it materially changes a
  hard decision, as one optional minimal `Consultation` note covering the question,
  recommendation or trade-off, risks or missing evidence, and how repository
  evidence was weighed. Evidence and narrow regression checks:
  `pi/extensions/b-agentic-role.ts`, `pi/extensions/b-agentic-support/role-models.ts`,
  and `pi/tests/smoke.sh`.
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
  diff and verification; actual review loads `skills/b-review/SKILL.md` and
  follows its output contract, ending with its standalone `Verdict:` line.
  Findings name location, evidence, impact, violated baseline, smallest
  correction, and regression check. Planner-owned audit or review may run
  non-mutating audit/validation scripts, but requests bounded worker evidence
  for builds, tests, formatters, generators, or verification that writes. After
  approval, the same worker may commit an unchanged reviewed snapshot only on
  explicit user request; content changes reopen review. There are no required
  protocol fields or parsed state machines. Evidence:
  `references/kernel.template.md`, `pi/configs/README.md`,
  `pi/extensions/b-agentic-support/role.ts`, `tests/behavior/roles.json`,
  `pi/tests/smoke.sh`.
- The always-loaded kernel carries only role-neutral role selection and Off
  default, the sole-writer and same-CWD roster boundary, generated skill
  ownership, and the questionnaire contract. Two-role handoff, Intercom
  targeting, delivery, blocker, review-gate, and post-approval commit mechanics
  live in the injected planner and worker prompts, preserving active-role
  behavior while keeping the kernel within its byte and line caps. Evidence:
  `references/kernel.template.md`, `pi/extensions/b-agentic-support/role.ts`,
  `tooling/validate/shared.py`, `tooling/validate/behavior.py`,
  `pi/scripts/validate.sh`, `pi/tests/smoke.sh`, `tests/behavior/roles.json`.
- Planner prompt addendum de-duplication keeps the always-loaded kernel
  authoritative for shared ownership and generic questionnaire guidance. The
  injected planner prompt retains only planner-specific application of those
  rules: read-only execution/delegation, external b-research ownership,
  bounded handoff, Intercom delivery and targeting, review gating,
  planner-only attention timing, and the unavailable/noninteractive question
  fallback. Evidence and regression check: `pi/extensions/b-agentic-support/role.ts`,
  `tooling/generate/registry_sync.py`, `tooling/validate/shared.py`,
  `pi/tests/smoke.sh`.
- Interactive, user-facing material decisions and blockers use the installed
  `ask_user_question` tool in planner or solo/Off work. Calls group 1–4 related
  questions, provide 2–4 concrete options with concise trade-offs, suffix the
  first recommended label with ` (Recommended)`, and leave the extension's
  automatic custom-answer row available; reserved labels `Other`, `Type
  something.`, and `Next` are not authored. If the package or interactive UI is
  unavailable, the fallback is one focused plain-text question. Planner
  actual `ask_user_question` tool calls trigger a fixed privacy-safe desktop
  `User input needed` notification in planner mode; solo/Off workers emit no
  planner notifications. Worker→planner material blockers remain Intercom
  `ask`/`reply`, and native tool-permission prompts remain for browser,
  external, or privileged actions rather than being replaced by questionnaire
  calls. A completed task that passed all delegated b-review gates uses
  `B_AGENTIC_TASK_COMPLETE`; task-complete notifications are omitted for normal
  planning, discovery, handoffs, intermediate updates, and reviews needing
  fixes. The planner-notify extension surfaces task-complete signals and actual
  planner `ask_user_question` tool calls as fixed desktop notifications
  (`notify-send` on Linux, `osascript` on macOS, bounded timeout, notifier
  failures ignored) only while the planner role is active; task/session and
  question data never enter the notification. Evidence:
  `pi/extensions/b-agentic-planner-notify.ts`,
  `pi/extensions/b-agentic-support/role.ts`, `references/kernel.template.md`,
  `pi/configs/README.md`, `pi/tests/smoke.sh`.
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
  approval before staging or committing. When the interactive questionnaire is
  available in planner or solo/Off work, b-commit presents structured
  `Approve (Recommended)` and `Decline` options; unavailable/noninteractive
  sessions use the focused plain-text fallback. In a two-role worker,
  worker→planner coordination remains Intercom. Pushes are not performed by
  b-agentic. Role application preserves normal active tools; planner
  write/commit limits are governed by prompt-level skill ownership and shared
  policy, not role-specific tool exclusion. Regression evidence for role
  preservation and generated universal questionnaire/commit guidance is in
  `tooling/validate/shared.py` and `pi/tests/smoke.sh`. Evidence:
  `skills/b-commit/prompt.md`, `pi/extensions/b-agentic-role.ts`,
  `pi/tests/smoke.sh`.

## MCP and external-evidence design

### One canonical operation policy drives runtime enforcement

- `references/mcp_operations.yaml` defines managed servers, operation classes,
  conditional argument keys, and runtime enforcement. Generated sets in
  `pi/extensions/b-agentic-support/mcp.ts` are checked against that source by
  `tooling/validate/mcp_policy.py` and `pi/scripts/validate_mcp_policy.py`.
- The managed set is Serena, CodeGraph, Context7, Linear, Mobbin, Brave Search, Firecrawl,
  and Playwright. Configured servers use lazy lifecycle, proxy execution by
  default, and a 30-second request timeout. Linear uses the hosted read-only endpoint,
  OAuth `read` scope, and an exact `get_issue` allowlist; Mobbin uses its official
  OAuth endpoint and an exact allowlist of `mobbin_search_screens`,
  `mobbin_search_flows`, and `mobbin_search_sections`. Shared managed-MCP
  classifications—not the selected role—govern gateway, direct-tool, and
  `mcpScript` use. The capability matrix permits cached non-executing
  status/server-list/search/describe/instructions metadata for any server and
  policy-classified managed retrieval/research with existing direct
  Serena/CodeGraph or explicit `mcp__` aliases and concrete safe arguments.
  It blocks or gates unsafe Playwright actions (such as navigation and
  interaction) while permitting policy-classified safe Playwright retrieval;
  safe project-local Serena edits and memory operations use the
  `conditional-local` class, and trusted Serena lifecycle operations such as
  onboarding are auto-approved. Outside-project, protected, unsafe, or
  unclassified Serena operations, selector mixtures, unclassified or unmanaged
  execution, and local/external mutation remain blocked or gated under normal
  policy; the explicit persisted `b-auto-mode` opt-in is the exception,
  auto-allowing approval requests while explicit deny decisions remain blocked.
  With auto mode off, approval-required actions retain normal UI/fail-closed
  behavior, and roles do not alter this policy. Narrow
  deterministic regression
  evidence is table-driven classifier, broker, active-tool, shell, Git, and
  CodeGraph allow/deny coverage in `pi/tests/smoke.sh`. Public tool evidence is Linear issues
  [#1028](https://github.com/linear/linear/issues/1028), [#1060](https://github.com/linear/linear/issues/1060), and [#747](https://github.com/linear/linear/issues/747); no authenticated live inventory was available for this change. Separately, the observed routing failure was that a bare Linear-style ID could be treated as generic implementation or research rather than planning; the intended behavior routes it to `b-plan`. Regression evidence is the human-scored `linear-issue-plan-routing` scenario in `tests/behavior/routing.json`, structurally validated with `python3 pi/tests/prompt_effectiveness.py --routing --validate-inputs --scenario=linear-issue-plan-routing`. Evidence:
  `references/mcp_operations.yaml`, `pi/configs/mcp.user.template.json`,
  `pi/scripts/validate.sh`.
- First-party local tools receive the same exact, least-privilege treatment as
  preview Markdown: `ask_user_question` is trusted by name because it has no
  filesystem, network, or mutation surface, while `lsp_diagnostics` is trusted
  only when its known schema contains project-confined, unprotected paths;
  directory arguments and the project-root default skip `.git`, `node_modules`,
  and `.venv` while scanning, but protected or external descendants elsewhere
  still fail closed. Serena's write-side descendant guard remains exhaustive.
  Unknown keys, invalid types, outside-project or protected paths retain the
  generic approval gate, and `lsp_fix` remains gated in every form because
  source actions can write. Evidence:
  `references/kernel.template.md`,
  `pi/extensions/b-agentic-support/shell.ts`,
  `pi/extensions/b-agentic-support/mcp.ts`,
  `pi/extensions/b-agentic-mcp-permissions.ts`, `pi/scripts/install.sh`,
  `pi/tests/smoke.sh`.
- Auto-approval is exact and least-privilege: read-only/trusted operations are
  allowed; conditional operations require known keys and safe argument values;
  safe project-local Serena operations use `conditional-local`, and trusted
  Serena lifecycle operations such as onboarding are auto-approved. Outside-
  project, protected, unsafe, or unclassified operations, external mutation,
  uploads, auth, screenshots, navigation, and other unsafe actions require
  approval under normal policy. The explicit persisted `b-auto-mode` opt-in
  auto-allows those approval requests while explicit denies remain blocked.
  Unmanaged servers and ambiguous gateway selectors are not trusted. Evidence:
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
  inspection cannot settle a concrete question. In planner mode, use an
  available index for that question but do not initialize an absent one; fall
  back to native inspection and state the resulting gap. Outside planner mode,
  initialize an absent index only for that question, never merely because work
  spans files.
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

### UI direction and visual assessment are contextual

- Observed failure: UI guidance could let recognizable generic AI defaults stand
  in for a product decision, while browser checks could stop at recording a
  screenshot without comparing the requested result with an approved brief or
  design reference.
- Intended behavior: `b-design` and `b-frontend` make an explicit,
  task-conditional design read covering surface, audience, brand/repository
  evidence, hierarchy, density, layout variance, and motion posture. They state
  a product-appropriate art direction with anti-default constraints and
  self-audit typography, palette, composition/layout repetition, surface/card
  restraint, meaningful interactions, truthful copy/assets, responsive behavior,
  and accessibility. Marketing pages, product apps, dashboards, and
  trust/regulated surfaces remain context-specific; existing tokens, components,
  stack, and assets remain authoritative. `b-browser` performs visual assessment
  only for an explicit request with an approved brief, an approved design
  guidance document, or supplied reference, comparing hierarchy, clipping/overflow, responsive
  composition, contrast/focus/interaction affordance, and adherence to the
  specified design guidance. It reports observations and gaps rather than
  claiming aesthetic proof from a generic load or screenshot.
- Regression: `skills/b-design/prompt.md`, `skills/b-frontend/prompt.md`,
  `skills/b-browser/prompt.md`, `tooling/validate/shared.py`, and the wired
  `pi/tests/prompt_effectiveness.py --validate-inputs` check in
  `tooling/validate/run.sh`; generated synchronization remains required.

## Installation, configuration, and lifecycle

### Install is source-backed, opt-in where state changes are external

- `install.sh` clones or updates a local source checkout, supports reviewed
  `--ref` pins, then sources the shared Pi installer. `--sync` updates only
  managed assets; `--update` reconciles RTK, uv/Serena, CodeGraph, Bun, Pi,
  and Pi extensions, installing missing components without pulling b-agentic.
  Both CodeGraph upgrade paths set `CODEGRAPH_NO_INSTALL_REFRESH=1` and
  report that guard in dry runs; `tests/smoke/install.sh` covers the dry-run
  marker and propagated guard. Evidence: `install.sh`, `pi/scripts/install.sh`,
  `tests/smoke/install.sh`, `REFERENCE.md`.
- The shipped Pi package set is `npm:pi-mcp-adapter`, `npm:pi-intercom`,
  `npm:pi-observational-memory`, `npm:@sreetej510/pi-usage`,
  `npm:@gotgenes/pi-anthropic-auth`,
  `npm:@juicesharp/rpiv-ask-user-question`, and
  `npm:@narumitw/pi-lsp`; both optional packages resolve the latest release. Evidence:
  `pi/scripts/install.sh`.
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
  `~/.pi/agent/b-agentic`, and keeps user-owned kernel/config/skill changes
  rather than overwriting or deleting them silently. When a managed Pi
  extension collides with an existing file, installation backs it up and
  replaces it; uninstall restores that backup only when the installed
  extension is unchanged, while modified or symlinked extensions are
  preserved. Evidence: `pi/scripts/install.sh`, `tooling/install/common.sh`,
  `tooling/install/manifest_uninstall.py`.
- MCP configuration is merged rather than replaced: unrelated user servers
  survive, prompted secrets are written only to user config through a private
  input pipe, and config uses lazy servers with API-key placeholders or deferred OAuth. Linear and Mobbin
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
  missing launchers/credentials, configured OAuth-authentication-unverified state, and ready servers. Valid Linear and Mobbin configurations are nonblocking because the doctor cannot observe adapter OAuth state. Live MCP schema probing is
  opt-in and reports drift/suggestions without editing policy; it does not acquire OAuth tokens, so OAuth-backed servers are not live-probed until an authenticated adapter path is available.
- `scripts/skill-doctor.sh` checks installed Pi skill payloads and kernel
  discovery. Install reports expose readiness and next steps instead of hiding
  missing optional infrastructure. Evidence: `tooling/validate/mcp_doctor.py`,
  `tooling/validate/mcp_probe.py`, `tooling/validate/skill_doctor.py`,
  `tooling/install/common.sh`.

## Verification and change discipline

- Generator/source synchronization: `python3 tooling/generate/registry_sync.py
  --check` (or the refresh command when canonical sources change).
- The standalone preview package contents are checked with
  `bash pi/scripts/validate-preview-markdown-package.sh`.
- Default validation is local and dependency-light: `scripts/validate-skills.sh`
  runs shared prompt/generated checks, CHANGELOG regression-claim validation,
  routing and behavior fixtures, MCP policy/probe self-tests,
  session-readiness self-tests, prompt input construction, browser evidence
  path checks, and Pi integration markers. The CHANGELOG check runs from
  `tooling/validate/run.sh` and shares citation helpers from
  `tooling/validate/citations.py`.
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
- Dependency-backed Pi TypeScript checking is opt-in: after `npm install
  --prefix pi`, `bash pi/scripts/typecheck.sh` runs the root Pi extension
  check and the standalone Preview Markdown package check;
  `bash pi/scripts/typecheck-preview-markdown.sh` runs the package check
  alone. Both checks are intentionally excluded from the offline suites;
  `pi/scripts/validate.sh` syntax-checks their entrypoints there. Evidence:
  `pi/scripts/typecheck.sh`, `pi/scripts/typecheck-preview-markdown.sh`,
  `pi/package.json`, `pi/scripts/validate.sh`.
- Live MCP schema probing and browser evidence are opt-in because they start
  processes/network activity or write approved evidence artifacts. Neither
  lane is implied by static validation. Evidence:
  `tooling/validate/mcp_doctor.py`, `skills/b-browser/prompt.md`,
  `REFERENCE.md`.
- Repository/design-conformance auditing is separate from changed-code review:
  `b-agentic-audit` remains strictly read-only and assesses four dimensions—source
  and design conformance; whole-project and first-party-extension health;
  canonical skill/kernel quality; and currentness/MCP compatibility. Health
  findings require concrete evidence, and performance findings require a measured
  hotspot or explicit algorithmic, safety, or complexity evidence rather than
  file size or export count. Currentness resolves local pins and installed
  versions, uses bounded primary upstream evidence, and treats live MCP schema
  probing as approval-gated; unavailable required evidence yields follow-up
  rather than a clean PR verdict. Actual source, safety, or semantic drift is
  `NEEDS FIXES`; `READY FOR PR` requires all dimensions to be verified.
  `scripts/b-agentic-audit.sh` remains deterministic structural and traceability
  coverage only. Evidence: `skills/b-agentic-audit/prompt.md`,
  `tooling/validate/shared.py`, `tests/behavior/routing.json`,
  `scripts/b-agentic-audit.sh`, `scripts/mcp-doctor.sh`.

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

### Lesson distillation

- Recurring recall-backed lessons should be promoted into canonical skill
  prompts during maintenance; memory stays volatile context, skills stay the
  durable capability store, and no new automation is added. Evidence: oh-my-pi's
  `learn`/`manage_skill` pattern (external inspiration,
  https://github.com/can1357/oh-my-pi); b-agentic uses prompt-governed promotion
  through b-implement plus `registry_sync` instead of runtime skill management.

## Superseding decision: one-shot consultant tool replacement

- Observed failure: a separately provisioned consultant session was an operational
  dependency; when no independent session was available, occasional consultation
  was unavailable or added friction to ordinary planner work. The earlier strict
  JSON response contract also made some provider replies unusable.
- Intended behavior: keep the planner-only one-shot `b_consult` tool, but rebuild
  each call as an isolated nested Pi session using the selected provider/model and
  shared consultant preference store. The session uses `SessionManager.inMemory`,
  no discovered context files/skills/prompts/extensions, and an explicit allowlist
  of `read`, `grep`, `find`, `ls`, plus the existing `mcp` gateway when the adapter
  is installed. The local tools are read-only; MCP calls use the normal adapter
  authentication, approval, and managed-operation policy rather than a bypass.
  The session receives only the bounded question/context/plan prompt, never outer
  conversation history, and has no write, shell, browser, Intercom, delegation, or
  worktree-writing route. `/b-consult-model` selects and persists provider, model,
  and thinking level. Existing legacy consultant configuration remains untouched,
  unread, and unmanaged. The caller `AbortSignal`, bounded timeout, disabled retry,
  no model fallback, bounded natural-language output, and sanitized timeout, abort,
  auth, configuration, and provider errors remain part of the contract; repository
  findings are advisory evidence for the decision, not a substitute for review.
- Regression: `pi/extensions/b-agentic-consult.ts`,
  `pi/extensions/b-agentic-role.ts`, `pi/extensions/b-agentic-support/role-models.ts`,
  `pi/tests/smoke.sh`, `pi/scripts/install.sh`, and `pi/scripts/validate.sh` cover
  the tool surface, planner-only gate, shared model preference/default/error paths,
  isolated read-only session tool allowlisting, no outer-history/cwd prompt leakage,
  normal MCP approval/auth policy preservation, bounded timeout/no retry behavior,
  legacy config non-revival, and removal of consultant role/status/roster/prompt
  behavior; generated synchronization and the offline validation suite remain
  required.

## Superseding decision: adaptive bounded concurrency and Intercom sequencing

- Observed failure: the adaptive planner/worker workflow described
  one writer but left the worker's expected edit surface, in-flight read-only
  boundary, quick-versus-material `ask` choice, and terminal reporting edge
  cases implicit. Prompts could therefore allow scope revision, a second
  implementation request, or in-flight review, and a worker could pause after
  a no-change, blocked, or gap outcome without delivering the result.
- Intended behavior: a bounded worker handoff names expected paths/symbols,
  scope, invariants, and checks. While edits are in flight, the planner may do
  only independent read-only work outside that set; it does not mutate, revise
  scope, issue another implementation task, or review the in-flight diff. After the worker terminal result, the planner re-reads actual
  changed paths before review. Before every outbound Intercom `send` or `ask`,
  every role calls `pending`; if it reports an inbound ask, the role replies
  immediately without `send`, `ask`, `list-cwd`, or another `pending` first,
  otherwise an immediate `list-cwd` supplies the verbatim target. `ask` is reserved for one
  focused question needing no substantial investigation, implementation, or
  waiting; material requests use `send`. Every worker terminal outcome,
  including completed, no-change, blocked, and reported-gap outcomes, is
  successfully sent to the assigning planner before pausing. This remains
  prompt-and-fixture guidance only: no runtime blocking, state store, lock, or
  new configuration is introduced.
- Regression: `pi/extensions/b-agentic-support/role.ts`, generated role-prompt
  assertions from `tooling/generate/registry_sync.py`, `tests/behavior/roles.json`,
  `pi/tests/prompt_effectiveness.py`, `REFERENCE.md`, and generated
  `pi/tests/smoke.sh` cover planner/worker pending-first sequencing, immediate
  inbound-ask replies without a second `pending`, quick-versus-material `ask`
  routing, bounded in-flight scope, post-terminal changed-path rereads,
  optional `b_consult` advice, and worker terminal reporting. Run the
  registry synchronization and offline skill/audit checks, plus the focused
  behavior fixture validation and diff check.
