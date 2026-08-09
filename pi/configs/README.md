# Pi Configuration Layout

Adapter-owned layout for Pi.

## Install Layout

- Kernel memory: `~/.pi/agent/AGENTS.md`
- Skills: `~/.pi/agent/skills/<skill-name>/SKILL.md`
- Shared references: `~/.pi/agent/b-agentic/references/kernel.template.md` and `mcp_operations.yaml`
- MCP template: `~/.pi/agent/b-agentic/templates/mcp.user.template.json`
- User MCP config: `~/.pi/agent/mcp.json` (Pi-owned override read by `pi-mcp-adapter`)
- Permission extension: `~/.pi/agent/extensions/b-agentic-permissions.ts`
- Extension snapshot: `~/.pi/agent/b-agentic/extensions/b-agentic-permissions.ts`

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

b-agentic can optionally install `pi-intercom`; set `B_AGENTIC_INSTALL_PI_INTERCOM=Y` or accept its prompt. Set `B_AGENTIC_ENABLE_INTERCOM_DELEGATION=Y` together with `B_AGENTIC_INTERCOM_TRUSTED_PEERS` (comma-separated stable IDs); enabling without nonempty IDs stays disabled. The installer persists a versioned `intercom-delegation.json` with only `trustedPeers`; that configuration is used solely for automatic delegation semantics. The permission extension auto-allows `list-cwd`, `status`, and `pending`, plus plain-text `send`/`ask`/`reply` to any explicit local session target; attachments, `list`, `cancel`, unknown actions/fields, and other custom tools remain approval-gated. When the Intercom tool and trusted-peer configuration are present, before each eligible user-originated execution task main must call `list-cwd`; it must delegate the bounded task to exactly one idle same-cwd peer with a unique stable trusted ID, otherwise main handles it. Delegated work must not re-delegate, replies require explicit `to`, and planning, design, init, review, commit, and PR-summary remain coordinator-owned. Single-writer ownership and all approval/secret rules remain in force.
After checking `pi list`, the installer runs `pi update --extensions` when
Pi extensions are installed.

`pi-observational-memory` V3 does not read V2 settings or memory entries. After
upgrading from V2, migrate its settings and start a clean Pi session. RTK's
optional `rtk init --agent pi --global` integration is rewrite-only and does
not replace b-agentic's permission extension; b-agentic does not install it
automatically.

Uninstall removes b-agentic-managed MCP config and the permission extension; it
does not remove any of these packages.

Servers default to lazy lifecycle through the adapter's proxy tool so schemas
are not eagerly injected into context. Optional adapter-specific `directTools`
settings can expose selected tools individually when needed.

## Safety

Pi has no native permission model. b-agentic installs a first-party extension
that listens for `tool_call` events and:

- auto-allows regular repository-local commands and asks before dependency
  execution, external/shared mutations, destructive Git worktree/stash
  operations, and other dangerous-but-approvable actions
- blocks prohibited git/Docker families and protected native writes/edits;
  protected native reads require explicit UI approval and fail closed without UI
- inspects compound shell segments (`&&`, `;`, `|`), approval-gates literal or
  symlink-resolved protected paths (including `rtk`-wrapped variants), and strips
  `env`/`sudo`/`rtk` wrappers and `git -C` style option prefixes before matching
- recursively classifies commands executed by RTK proxy/filter wrappers and
  requires approval for unbalanced quotes, shell expansions, `rtk run -c`,
  interpreter modules/script files (`bash script.sh`, `node app.js`,
  `python -m package`, …), and relative executable paths whose code is opaque
  to static matching
- recommends RTK for supported native command families, including local discovery;
  `rtk proxy` is unwrapped for the same safety classification as its effective
  command; auto-allows classified read-only and safe conditional-read managed
  MCP operations through the adapter and through an unambiguous top-level
  gateway call with an explicit managed server, matching tool name, and validated
  arguments; direct adapter tool names remain approval-gated because they share
  Pi's custom-tool namespace
- confines autonomous Serena symbol reads to the current repository and asks for Serena onboarding, memory writes, and other local mutations; asks for Firecrawl external-mutation or
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
