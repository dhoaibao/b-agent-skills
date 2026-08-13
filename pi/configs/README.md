# Pi Configuration Layout

Adapter-owned layout for Pi.

## Install Layout

- Kernel memory: `~/.pi/agent/AGENTS.md`
- Skills: `~/.pi/agent/skills/<skill-name>/SKILL.md`
- Shared references: `~/.pi/agent/b-agentic/references/kernel.template.md` and `mcp_operations.yaml`
- MCP template: `~/.pi/agent/b-agentic/templates/mcp.user.template.json`
- User MCP config: `~/.pi/agent/mcp.json` (Pi-owned override read by `pi-mcp-adapter`)
- Permission extensions: `~/.pi/agent/extensions/b-agentic-permissions.ts`,
  `b-agentic-mcp-permissions.ts`, `b-agentic-auto-mode.ts`,
  `b-agentic-role.ts`, `b-agentic-planner.ts`, `b-agentic-worker.ts`, and
  `b-agentic-sync.ts`
- Extension snapshots: `~/.pi/agent/b-agentic/extensions/` (one snapshot per
  installed extension; legacy manifests with only `permissionsExtension` remain supported)
- Shared extension helpers live under the non-discovered
  `pi/extensions/b-agentic-support/` source directory

## Optional Pi Packages

Pi does not provide native MCP. b-agentic installs MCP server entries into
`~/.pi/agent/mcp.json` and expects the community package
`pi-mcp-adapter` to load them. `pi install npm:pi-mcp-adapter`.

For long-session compaction continuity, b-agentic can install the optional
`pi-observational-memory` package. `pi install npm:pi-observational-memory`;  Use it as the sole automatic
memory/compaction layer rather than combining it with another such extension.

b-agentic can also install the optional `@narumitw/pi-usage` extension.
`pi install npm:@narumitw/pi-usage`;


b-agentic installs `pi-intercom` by default for its two-role workflow;  The permission extension auto-approves schema-valid Intercom actions (`list`, `list-cwd`, `status`, `pending`, `send`, `ask`, `reply`, and `cancel`), including supported optional string fields and attachment arrays; invalid actions, unknown fields, and malformed optional values remain approval-gated.

b-agentic defaults to Off for a single-session workflow; the first same-CWD session is not automatically promoted to planner. For the two-role workflow, explicitly run `/b-role planner` and `/b-role worker` in the two sessions, or start them with `pi --b-role planner|worker`. Run `/b-role off` to return to solo work; tab completion supports all three role names. The role persists with the session and appears in Pi's status bar. `/b-role` selects only a role and does not open a model picker. Explicit `pi --b-role` startup selections and later `/model` changes can update the per-role provider, model, and thinking-level preference under `~/.pi/agent/b-agentic/role-models.json` without credentials.

`/b-auto-mode` enables an explicit opt-in automatic approval mode. Enabling it always shows a warning and requires an interactive Y/N confirmation; disabling it does not. While enabled, every `ask` decision is auto-allowed, but explicit `deny` decisions remain blocked. User changes persist across Pi restarts and `/new` sessions in `~/.pi/agent/b-agentic/auto-mode.json`; legacy session entries remain compatible. `pi --b-auto-mode` requests one-session startup enablement and still requires confirmation. The setting appears as red `b-auto-mode` in Pi's footer. If no interactive UI is available, enabling fails closed.

Planner mode is enforced as analysis-only: it permits `read`, `recall`, Intercom, shared-policy-safe read-only shell commands and repository inspection, cached non-executing MCP status, server listing, search, describe, and instructions metadata, plus policy-classified managed read-only or validated conditional-read MCP calls (including scoped Linear task retrieval and direct namespaced Serena/CodeGraph aliases, but never Playwright). It blocks `mcpScript`: adapter session approvals are checked before its broker, so nested safety cannot be guaranteed after a role change. Git, CodeGraph, and discovery commands retain operation-specific read-only checks; other safe inspection utilities do not need a planner allowlist. It blocks edits, writes (including shell redirection), commands that execute repository code or mutate state, commits, browser/operational work, auth/lifecycle/UI MCP actions, unclassified or unmanaged MCP execution, and local or external mutations. The planner discovers a ready worker through the injected role-aware roster and never falls back to implementation. The normal permission extension continues to protect sensitive paths, dangerous commands, and outside-project or external/shared actions. Worker mode retains normal repository-local automation.

In the two-role workflow, the generated ownership mapping gives the planner read-only execution of `b-plan`, external `b-research`, `b-agentic-audit`, `b-review`, and `b-pr-summary`; it delegates `b-design`, `b-implement`, `b-init`, `b-refactor`, `b-debug`, `b-test`, `b-browser`, and `b-commit` to the worker. The planner may still read any skill for planning, delegation, audit, or review: ownership governs execution, not inspection. Planner ownership is limited to read-only decision/planning, external research, audit/review, or release-summary coordination; implementation or mutation, runtime diagnosis, builds/tests, browser/operational verification, commits, mixed, and uncertain work belong to the worker. Direct user wording or no ready worker never permits planner implementation; unknown ownership fails closed to worker ownership and registry validation rejects missing or invalid owners. The planner finishes discovery and settles one bounded handoff before the worker edits; it then waits for the worker result and reviews with `b-review`. The worker is the sole worktree writer; in solo/Off work no coordination applies. Planner-owned audit/review gets blocked verification through bounded worker evidence, never planner scripts/tests.

Coordination is concise natural language, not `B_AGENTIC_*` fields or a state machine. Before every `send` or `reply`, call `pending`: an inbound ask requires `reply`, not `send` or `list-cwd`; otherwise refresh `list-cwd` and use the identifier token returned verbatim by that immediately preceding authoritative output. An authoritative short ID is valid. Never guess, reconstruct, extend, further abbreviate, or use a stale target, display name, or alias. A message is sent only after delivery succeeds. On failure, do not continue, commit, or close: `pending`, reply if required, otherwise fresh `list-cwd`, then one retry only if the intended peer remains live; otherwise pause with an unavailable-peer blocker. The refresh is the exception to no polling; after delegation the planner ends the turn and waits for worker `send`.

For non-trivial work, the handoff concisely includes applicable observable behavior, scope/non-goals, constraints/invariants, relevant paths/symbols/evidence, acceptance criteria, validation expectations, and assumptions, pre-existing changes, or gaps. The worker result includes implemented behavior, changed paths, acceptance coverage, exact checks/outcomes, and deviations, assumptions, or gaps; it requests actual `b-review` and pauses edits. The latest approved plan, handoff, and clarifications are its review baseline. Only delegated worktree-changing tasks need actual `b-review` of the diff and verification before approval; generic review cannot substitute. Findings give location, evidence, impact, violated baseline, smallest correction, and regression check. For a two-role blocker, the worker calls `pending`; it replies without `list-cwd`, `send`, or `ask` if inbound, otherwise refreshes `list-cwd` and uses `ask` to the assigning planner with that returned identifier token verbatim. In solo/Off, it asks the user. The planner replies when evidence resolves it or asks the user one focused question. After approval, the same worker may `b-commit` only on explicit user request and only for the unchanged reviewed snapshot; changed content reopens review.
After reconciling required Pi packages, the installer runs
`pi update --extensions`.

## In-session refresh

`/b-sync` confirms, pulls the installed b-agentic checkout, and syncs only
managed Pi skills, kernel, and first-party extensions before reloading Pi. It
does not install packages or change MCP configuration. `/b-update` runs without an additional confirmation and updates RTK, Serena, CodeGraph, Bun, Pi, and Pi extensions without pulling b-agentic; Bun-backed MCP packages are resolved by `bunx` on first use, then Pi reloads.
Both commands require an interactive session and take no arguments.

`pi-observational-memory` V3 does not read V2 settings or memory entries. After
upgrading from V2, migrate its settings and start a clean Pi session. RTK's
optional `rtk init --agent pi --global` integration is rewrite-only and does
not replace b-agentic's permission extension; b-agentic does not install it
automatically.

Uninstall removes b-agentic-managed MCP config and unchanged permission
extensions. Modified files and symlinks are preserved; legacy manifests with
only `permissionsExtension` are restored using the original compatibility path.
It does not remove any of these packages.

Servers default to lazy lifecycle through the adapter's proxy tool so schemas
are not eagerly injected into context. Linear is configured for deferred OAuth and exposes only `get_issue`; it does not authenticate during install, and its authentication state remains unverified until the adapter needs it. The template sets the adapter's global
`settings.requestTimeoutMs` to 30000 milliseconds (30 seconds), giving every
MCP request a finite deadline. Optional adapter-specific `directTools` settings
can expose selected tools individually when needed.

## Safety

Pi has no native permission model. b-agentic installs a first-party extension
that listens for `tool_call` events and:

- auto-allows regular repository-local commands, including routine build, test,
  package, dependency, and script automation; asks before external/shared
  mutations, destructive Git worktree/stash operations, and other dangerous-
  but-approvable actions
- blocks prohibited git/Docker families and protected native writes/edits;
  protected native reads require explicit UI approval and fail closed without UI;
  auto-allows reads of installed b-agentic `SKILL.md` files under the configured
  Pi skill root while other outside-project reads remain approval-gated
- inspects compound shell segments (`&&`, `;`, `|`), approval-gates literal or
  symlink-resolved protected paths (including `rtk`-wrapped variants), and strips
  `env`/`sudo`/`rtk` wrappers and `git -C` style option prefixes before matching
- recursively classifies commands executed by RTK proxy/filter wrappers and
  requires approval for unbalanced quotes, shell expansions, `rtk run -c`,
  inline interpreter code, non-project modules, and outside-project executable
  paths; existing project-local scripts remain routine automation
- recommends RTK for supported native command families, including local discovery;
  `rtk proxy` is unwrapped for the same safety classification as its effective
  command; auto-allows every classified Serena and CodeGraph operation through
  matching direct or `mcp__`-prefixed names, the adapter, and explicit
  managed-server gateway calls. Also auto-allows classified read-only and
  validated conditional-read operations. Explicitly targeted `mcp` proxy tool
  executions use b-agentic's adapter broker: safe managed calls auto-allow, while
  unsafe or unmanaged calls prompt there. Outside planner mode, metadata and
  lifecycle selectors remain behind the generic approval gate; planner mode permits
  only cached global status, server listing, search, describe, and instructions
  metadata, while its broker hard-denies non-classified nested/direct/script/resource
  execution regardless of UI or auto mode. Other direct adapter names remain gated
  because they share Pi's custom-tool namespace
- prefers native `read`/`edit`/`write` for routine repository work; after native
  search/read, uses Serena only for a concrete exact-symbol, reference,
  implementation, diagnostic, or reference-aware refactor need where it materially
  improves safety or precision; relevant onboarding and durable project memories
  remain explicit exceptions; routine Serena reads, searches, and edits are
  prohibited, and Serena requests are serialized rather than parallelized or
  batched because concurrency can hang or time out; sensitive and outside-project
  Serena paths remain gated; uses CodeGraph only when native inspection leaves a
  concrete repository-wide architecture, dependency/call-flow, impact, or
  affected-test question; does not initialize it merely because work spans files;
  avoids querying both tools for the same question; read-only
  cached MCP status/list/search/describe/instructions metadata is planner-safe;
  planner mode blocks `mcpScript`, because adapter session approvals can bypass
  its nested-call broker after a role change;
  asks for Firecrawl external-mutation or
  local-upload tools (agent/crawl/interact/monitor/feedback/parse), Linear OAuth bootstrap and every Linear operation other than `get_issue`, Playwright
  page-mutating tools (click/type/upload/evaluate/…), screenshots (the server
  persists a default file even without a filename), MCP auth bootstrap,
  Playwright navigation (including public URLs that may redirect or DNS-rebind),
  unclassified managed operations, user/unknown MCP servers, and any other
  non-built-in custom tool
- fails closed when MCP selectors are mixed (e.g. `connect` + `tool`), when an explicit MCP `server` disagrees with the tool-name origin, or when an approval-required action has no UI confirmation

## Validation

Use `scripts/validate-skills.sh` and `scripts/validate-skills.sh --release`
from the repository root. MCP readiness must distinguish missing adapter,
missing config, missing local prerequisites, and ready servers. The opt-in
`scripts/mcp-doctor.sh --probe-schemas` lane performs approved live startup/network
checks and reports current tool IDs that are new or absent relative to policy. It does not acquire OAuth tokens, so Linear schema probing remains blocked until an authenticated adapter probe path is available; normal readiness reports its authentication state as unverified. Run it after MCP
package updates and before release candidates; normal readiness does not verify live schemas.
