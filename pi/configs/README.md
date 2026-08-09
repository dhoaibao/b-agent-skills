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
  `b-agentic-planner.ts`, and `b-agentic-worker.ts`
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

b-agentic can optionally install `pi-intercom`; set `B_AGENTIC_INSTALL_PI_INTERCOM=Y` or accept its prompt. The permission extension auto-approves schema-valid Intercom actions (`list`, `list-cwd`, `status`, `pending`, `send`, `ask`, `reply`, and `cancel`), including supported optional string fields and attachment arrays; invalid actions, unknown fields, and malformed optional values remain approval-gated.

b-agentic provides opt-in planner and worker collaboration profiles through the role, planner, and worker extensions. Run `/b-role` to choose `planner`, `worker`, or `off`; tab completion also supports `/b-role planner`, `/b-role worker`, and `/b-role off`. `pi --b-role planner|worker` selects a startup role. The role persists with the session and appears in Pi's status bar.

Roles do not change Pi's active tools and do not add skill, shell, MCP, or message-format gates. The normal permission extension continues to auto-run repository-local work while protecting sensitive paths, dangerous commands, and outside-project or external/shared actions. Upgrading from an older release also performs a one-time restoration of tools that a persisted read-only planner role had hidden.

The planner sequences `b-plan` and `b-research` as needed, delegates to one same-directory worker, reviews with `b-review`, and owns PR summaries or an explicit `b-commit` after approval. During delegated work it may inspect files and run review checks, but it never performs implementation edits or fixes; every finding goes back to the worker.

The worker is the sole worktree writer. It sequences `b-implement`, `b-debug`, `b-refactor`, `b-test`, `b-browser`, `b-research`, `b-design`, or `b-init` as the task requires, switching skills when intent changes and running normal repository-local automation without a structured assignment.

Coordination is deliberately lightweight:

1. The planner uses Intercom `send` for a natural-language task with goal, scope or invariants, and useful success checks.
2. The worker implements and verifies, then uses `send` to the assigning planner for changed paths, verification outcomes, and gaps before pausing all edits.
3. The planner reviews and uses `send` for actionable findings or approval. Findings resume worker edits; the worker fixes, verifies, and requests review again until approved.
4. After approval the worker remains idle; the planner performs explicit commit or release work only when normally authorized.

There are no required `B_AGENTIC_TASK`, `B_AGENTIC_RESULT`, or `B_AGENTIC_REVIEW` markers, fields, counters, or target checks. `send` is the non-blocking default; `ask` is only for a genuine blocker when waiting is intentional, and `reply` remains supported. Users never relay internal messages. This single-writer lifecycle is a collaboration contract, not a tool or permission gate, so role-appropriate skills and local automation remain available without protocol blocks.
After checking `pi list`, the installer runs `pi update --extensions` when
Pi extensions are installed.

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
  classified read-only and validated conditional-read operations. Non-Serena direct
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
