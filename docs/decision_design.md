# b-agentic decision design

This is the evidence-backed design record for b-agentic. It defines the Claude Code product boundary, source-of-truth rules, safety model, workflow, installation lifecycle, and verification expectations. It is not a second runtime contract.

## Claude Code is the runtime boundary

- Ship a compact Claude Code plugin with native skills, custom `b-planner`/`b-worker` agents, hooks, direct MCP configuration, and an always-loaded managed kernel.
- Do not retain compatibility assets for another coding runtime. Claude Code configuration and plugin schemas are the only supported delivery boundary.
- Keep canonical prompts in `skills/*/prompt.md`, metadata and generated routing in `skills/registry.yaml`, the kernel in `references/kernel.template.md`, and MCP classifications in `references/mcp_operations.yaml`.
- Generated assets are delivery outputs. `tooling/generate/registry_sync.py` owns synchronization and must be run with `--check` in validation.

## Source layers and generated delivery

The registry drives Claude skill frontmatter, the README skill table, kernel routing and ownership blocks, and the generated plugin MCP policy snapshot. The plugin root contains only Claude-native components: `.claude-plugin/plugin.json`, `skills/`, `agents/`, `hooks/`, `settings.json`, and `.mcp.json`. Do not introduce a permanent runtime-neutral adapter layer.

## Safety is fail-closed and fixture-backed

- The `PreToolUse` hook in `plugin/hooks/b-agentic-policy.py` ports the path, shell, and managed-MCP classification behavior into Claude `allow`, `ask`, and `deny` decisions.
- Protected paths include secret-like files and credential directories. Protected reads ask; protected writes deny. Outside-project paths ask; unknown tools and malformed events deny.
- Dangerous commands such as force pushes, hard resets, forced cleans, force branch deletion, and destructive Docker pruning are hard-denied. Ambiguous shell syntax, external/shared mutations, recursive removal, and dangerous system commands require approval.
- Direct MCP tools are checked against `references/mcp_operations.yaml`. Safe and validated conditional operations may allow; classified mutations ask; unknown servers, operations, arguments, auth, lifecycle, and unclassified local/external operations deny.
- `permissions.deny` duplicates the highest-risk command denials. Claude's automatic permission behavior must not weaken hook denials.
- Every behavior change needs a fixture covering the observed failure, intended decision, and narrow regression check. Do not claim policy parity without fixture evidence.

## Solo first; named coordination is explicit

Solo Claude Code remains the default. Optional independent named sessions use `b-planner` and `b-worker` custom agents. The planner has a read-only tool boundary and owns planning, research, audit, review, and release-summary decisions. The worker is the sole worktree writer and owns implementation, tests, browser verification, runtime diagnosis, and explicit commits.

Cross-session messaging follows Claude Code's current `ListAgents` and `SendMessage` facilities. Before each handoff, discover the current named peer freshly; send plain text describing observable behavior, scope/non-goals, constraints, and invariants. Use a focused message for blockers and terminal results. Do not copy a pending/verbatim-ID protocol from another runtime. Claude Code 2.1.224+ on macOS/Linux is required; local same-machine delivery uses Claude's local transport. Inbound messages are accepted deliberately where the version exposes `crossSessionInbound`.

## Claude-native lifecycle facilities

The plugin uses Claude permissions, hooks, status-line, compaction, and usage/session facilities. Status and notification hooks are best-effort and never block work. No separate memory or usage package is installed. The installer does not update the Claude Code executable, merges only b-agentic-owned settings, and preserves unrelated user configuration.

## Installer preservation

The `install.sh` lifecycle copies the plugin to the Claude configuration root and appends a marked kernel block to `CLAUDE.md`. It records managed paths and snapshots in a manifest. Uninstall removes only unchanged b-agentic-owned content; modified files, symlinks, user instructions, and unrelated settings remain. Source refresh and plugin sync are separate from Claude executable lifecycle.

## Verification lanes

- Generator synchronization: registry, canonical prompts, kernel, README, and plugin policy snapshot.
- Plugin validation: manifest, root component layout, hooks schema, custom agent boundaries, direct MCP configuration, and executable hook scripts.
- Hook fixtures: representative allow/ask/deny decisions for protected paths, dangerous commands, external mutations, malformed events, and managed/unknown MCP operations.
- Installer smoke: isolated install, preservation of user `CLAUDE.md`/settings/skills, repeated sync, and manifest-only uninstall.
- Solo workflow input validation and named-session messaging configuration checks where Claude is available.
- Live MCP and browser checks remain opt-in and are never implied by static validation.
