# b-agentic operational reference

This document describes the Claude Code-only runtime, installer, safety policy, and verification lanes behind [README.md](README.md).

## Installation lifecycle

Default install:

```bash
bash install.sh
```

The bootstrap keeps its source checkout at `~/.b-agentic` (override with `B_AGENTIC_DIR`), then copies the Claude plugin to `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/b-agentic` and merges the managed kernel into `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/CLAUDE.md`. Set `B_AGENTIC_CLAUDE_CONFIG_DIR` when an isolated or alternate Claude configuration root is required. `--dry-run` performs no configuration writes.

Supported lifecycle flags:

- `--sync` redeploys the current verified plugin, kernel, and managed settings from the selected source without fetching new source.
- `--update` refreshes b-agentic source and plugin assets; it never installs or updates the Claude Code executable.
- `--uninstall` removes only files and managed instruction blocks recorded in the b-agentic manifest, preserving modified or user-owned files.
- `--ref=<tag-or-sha>` pins the source checkout for an install.
- `--replace-kernel` replaces a previously managed kernel snapshot after explicit review; the default is to preserve an existing user-owned `CLAUDE.md`.

The installer does not install npm packages, themes, a second memory system, or a second usage reporter. It merges only b-agentic-owned settings and preserves unrelated user-owned Claude settings, MCP configuration, skills, agents, and hooks.

## Plugin layout

Only `.claude-plugin/plugin.json` belongs inside `.claude-plugin/`; all other plugin components are at the plugin root:

```text
plugin/
├── .claude-plugin/plugin.json  # declares skills, agents, hooks, and mcpServers
├── skills/<name>/SKILL.md
├── agents/b-planner.md
├── agents/b-worker.md
├── hooks/hooks.json
├── hooks/b-agentic-policy.py
├── hooks/b-agentic-status.py
├── hooks/b-agentic-status-line.py
├── hooks/mcp_policy.json
├── settings.json
└── .mcp.json
```

Claude discovers the plugin components when the installed plugin is enabled. Local testing can load the source directly with `claude --plugin-dir ./plugin`. Restart Claude Code or reload plugins after changing hooks, agents, MCP config, or settings.

## Kernel and routing

`references/kernel.template.md` is the always-loaded managed instruction source. It contains safety, tool-selection, MCP, solo, and optional named-session rules plus generated skill ownership and routing. `skills/registry.yaml` owns names, phase, routing triggers, and planner/worker ownership; each `skills/*/prompt.md` owns its body. Run the generator after canonical changes:

```bash
python3 tooling/generate/registry_sync.py
python3 tooling/generate/registry_sync.py --check
```

The planner/worker workflow is optional. In solo mode, the main session remains responsible for routing and execution. In coordinated mode, use fresh `ListAgents` discovery and plain-text `SendMessage`; do not rely on stale session identifiers or a copied pending-message protocol. The plugin settings set `crossSessionInbound` to `accept` deliberately; Claude versions that do not expose this setting ignore the unknown key and retain their documented inbound policy.

## Safety hook

`plugin/hooks/b-agentic-policy.py` reads the Claude `PreToolUse` JSON event from stdin and emits a JSON `hookSpecificOutput` decision:

```json
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow|ask|deny","permissionDecisionReason":"..."}}
```

The hook covers:

- hard denials for force pushes, hard resets, forced cleans, force branch deletion, and destructive Docker pruning;
- approval for external/shared mutations, recursive removal, dangerous system commands, ambiguous shell syntax, protected reads, and outside-project paths;
- denial for protected writes and unclassified tools;
- direct MCP server/tool/argument classification from the canonical policy, with unknown operations failing closed.

`permissions.deny` in the plugin settings provides a second hard boundary for the highest-risk shell commands. Claude's native permission behavior remains responsible for interactive approval; enabling automatic permission behavior cannot bypass hook denials.

The policy is intentionally fixture-driven. Do not claim behavioral parity when a new command/path/MCP rule lacks a regression fixture.

## Managed MCP configuration

The plugin's `.mcp.json` uses Claude's direct `mcpServers` schema. It includes Serena, CodeGraph, Context7, Linear read-only, Brave Search, Firecrawl, and Playwright. Credentials remain environment-driven; the installer never prints or stores secret values. `references/mcp_operations.yaml` is the only policy source, and `plugin/hooks/mcp_policy.json` is generated from it.

## Validation

Run the narrowest applicable checks from the repository root:

```bash
python3 tooling/generate/registry_sync.py --check
scripts/validate-skills.sh
scripts/b-agentic-audit.sh
```

Release checks add:

```bash
scripts/validate-skills.sh --release
scripts/smoke-install.sh
```

The release lane validates source/generated synchronization, plugin shape, isolated install/uninstall preservation, hook allow/ask/deny fixtures, direct-MCP classification, solo workflow input, and named-session messaging configuration when a Claude executable is available. Live MCP and browser evidence remain opt-in.
