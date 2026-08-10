# Pi Configuration Layout

Adapter-owned layout for Pi.

## Install Layout

- Kernel memory: `~/.pi/agent/AGENTS.md`
- Skills: `~/.pi/agent/skills/<skill-name>/SKILL.md`
- Shared references: `~/.pi/agent/b-agentic/references/kernel.template.md` and `mcp_operations.yaml`
- MCP template: `~/.pi/agent/b-agentic/templates/mcp.user.template.json`
- User MCP config: `~/.pi/agent/mcp.json` (Pi-owned override read by `pi-mcp-adapter`)
- Permission extensions: `~/.pi/agent/extensions/b-agentic-permissions.ts`,
  `b-agentic-mcp-permissions.ts`, `b-agentic-role.ts`,
  `b-agentic-planner.ts`, `b-agentic-worker.ts`, and `b-agentic-sync.ts`
- Extension snapshots: `~/.pi/agent/b-agentic/extensions/` (one snapshot per
  installed extension; legacy manifests with only `permissionsExtension` remain supported)
- Shared extension helpers live under the non-discovered
  `pi/extensions/b-agentic-support/` source directory

## Optional Pi Packages

Pi does not provide native MCP. b-agentic installs MCP server entries into
`~/.pi/agent/mcp.json` and expects the community package
`pi-mcp-adapter` to load them. Interactive installs prompt before running
`pi install npm:pi-mcp-adapter`. Noninteractive installs run that only when
`B_AGENTIC_INSTALL_PI_MCP_ADAPTER=Y` is set.

For long-session compaction continuity, b-agentic can install the optional
`pi-observational-memory` package. Interactive installs prompt before running
`pi install npm:pi-observational-memory`; noninteractive installs require
`B_AGENTIC_INSTALL_PI_OBSERVATIONAL_MEMORY=Y`. Use it as the sole automatic
memory/compaction layer rather than combining it with another such extension.

b-agentic can also install the optional `@narumitw/pi-usage` extension.
Interactive installs prompt before running `pi install npm:@narumitw/pi-usage`;
noninteractive installs require `B_AGENTIC_INSTALL_PI_USAGE=Y`.

b-agentic installs `pi-intercom` by default for its two-role workflow; `B_AGENTIC_INSTALL_PI_INTERCOM=N` explicitly disables it and leaves collaboration unavailable. The permission extension auto-approves schema-valid Intercom actions (`list`, `list-cwd`, `status`, `pending`, `send`, `ask`, `reply`, and `cancel`), including supported optional string fields and attachment arrays; invalid actions, unknown fields, and malformed optional values remain approval-gated.

b-agentic defaults to Off for a single-session workflow; the first same-CWD session is not automatically promoted to planner. For the two-role workflow, explicitly run `/b-role planner` and `/b-role worker` in the two sessions, or start them with `pi --b-role planner|worker`. Run `/b-role off` to return to solo work; tab completion supports all three role names. The role persists with the session and appears in Pi's status bar. `/b-role` selects only a role and does not open a model picker. Explicit `pi --b-role` startup selections and later `/model` changes can update the per-role provider, model, and thinking-level preference under `~/.pi/agent/b-agentic/role-models.json` without credentials.

Planner mode is enforced as analysis-only: it permits `read`, `recall`, Intercom, safe local discovery commands, and classified read-only MCP gateway calls (including Serena and CodeGraph). It blocks edits, writes, builds/tests, commits, arbitrary shell commands, arbitrary MCP scripts, and mutating MCP calls. The planner discovers a ready worker through the injected role-aware roster and never falls back to implementation. The normal permission extension continues to protect sensitive paths, dangerous commands, and outside-project or external/shared actions. Worker mode retains normal repository-local automation.

In the two-role workflow, the planner finishes discovery and settles the approach before one bounded handoff. If agreement is needed, planner and worker resolve it before edits; once the worker starts, the planner stops exploring and issuing implementation requests. The planner sequences `b-plan` and `b-research` as needed, delegates to the explicitly selected same-directory worker, and reviews with `b-review`. It must send implementation, verification, and fixes to the worker; every finding goes back to that worker. In the single-session Off workflow, no planner/worker coordination is active.

The worker is the sole worktree writer. It sequences `b-implement`, `b-debug`, `b-refactor`, `b-test`, `b-browser`, `b-research`, `b-design`, or `b-init` as the task requires, switching skills when intent changes and running normal repository-local automation without a structured assignment.

Coordination is deliberately lightweight:

1. The planner uses Intercom `send` for a natural-language task with goal, scope or invariants, and useful success checks. After assigning a task, the planner waits for the worker's result instead of repeatedly polling `list-cwd` or `status`; `ask` is for intentionally waiting for a response. Roster/status calls remain for selecting a worker or handling genuine connection needs, not a polling loop.
2. The worker implements and verifies, then uses `send` to the assigning planner for changed paths, verification outcomes, and gaps before pausing all edits.
3. The planner reviews and uses `send` for actionable findings or approval. The planner may mark the task complete only after `b-review` has passed against the actual diff and verification. Findings resume worker edits; the worker fixes, verifies, and requests review again until approved. If a blocker or decision cannot be resolved from scope or repository evidence, ask the user one focused question and keep the task open.
4. After approval the worker remains idle; leave planner mode before an explicit `b-commit` or release action when normally authorized.

There are no required `B_AGENTIC_TASK`, `B_AGENTIC_RESULT`, or `B_AGENTIC_REVIEW` markers, fields, counters, or target checks. `send` is the non-blocking default; `ask` is for intentionally waiting for a response, including a genuine blocker, and `reply` remains supported. Users never relay internal messages. This single-writer lifecycle has an enforced planner analysis-only gate; worker-local automation remains available without protocol blocks.
After checking `pi list`, the installer runs `pi update --extensions` when
Pi extensions are installed.

## In-session refresh

`/b-sync` confirms, pulls the installed b-agentic checkout, and syncs only
managed Pi skills, kernel, and first-party extensions before reloading Pi. It
does not install packages or change MCP configuration. `/b-update` confirms
and updates already-installed RTK, Serena, CodeGraph, Pi, and Pi extensions
without pulling b-agentic or installing missing components, then reloads Pi.
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
are not eagerly injected into context. Optional adapter-specific `directTools`
settings can expose selected tools individually when needed.

## Safety

Pi has no native permission model. b-agentic installs a first-party extension
that listens for `tool_call` events and:

- auto-allows regular repository-local commands, including routine build, test,
  package, and script automation; asks before dependency writes, external/shared
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
  command; auto-allows every classified Serena operation through direct Serena
  names, the adapter, and explicit managed-server gateway calls. Also auto-allows
  classified read-only and validated conditional-read operations. Explicitly
  targeted `mcp` proxy tool executions use b-agentic's adapter broker: safe managed
  calls auto-allow, while unsafe or unmanaged calls prompt there. Metadata and
  lifecycle selectors remain behind the generic approval gate. Non-Serena direct
  adapter names remain gated because they share Pi's custom-tool namespace
- uses Serena for semantic code navigation, diagnostics, precise edits/refactors,
  onboarding for unfamiliar repositories, memory tools for durable project facts,
  and the dashboard for Serena troubleshooting; sensitive and outside-project paths
  remain gated; uses CodeGraph only for repository-wide architecture, dependency/call
  flows, impact, and affected tests; avoids querying both tools for the same
  question; fans out distinct, independent read calls to both concurrently through
  one bounded auto-run `mcpScript`; read-only `tools.search`/`tools.describe` metadata
  discovery is trusted there, while each nested `tools.call` retains normal policy;
  asks for Firecrawl external-mutation or
  local-upload tools (agent/crawl/interact/monitor/feedback/parse), Playwright
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
checks and reports current tool IDs that are new or absent relative to policy. Run it after MCP
package updates and before release candidates; normal readiness does not verify live schemas.
