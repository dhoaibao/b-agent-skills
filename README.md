# b-agentic

**A slim personal workflow kernel for Claude Code.** b-agentic routes work to focused skills, preserves hard safety gates, and packages the workflow as a Claude Code plugin.

- Solo Claude Code is the default.
- Skills route planning, research, implementation, debugging, tests, browser evidence, review, and shipping.
- The optional named `b-planner` / `b-worker` workflow uses Claude Code `ListAgents` and `SendMessage`; the planner is read-only and the worker is the sole writer.
- Managed MCP policy, protected paths, dangerous-command denials, and approval boundaries are enforced by a fail-closed `PreToolUse` hook.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/dhoaibao/b-agentic/main/install.sh | bash
```

Pin the bootstrap and source to a reviewed tag or commit with `B_AGENTIC_REF=<tag-or-sha>`. The installer preserves unrelated files under `~/.claude`, merges only b-agentic-owned settings, and never updates the Claude Code executable. Use `--dry-run` to inspect the plan and `--uninstall` to remove only b-agentic-owned content.

The plugin is installed at `~/.claude/plugins/b-agentic`; the managed kernel is appended to `~/.claude/CLAUDE.md` using a marker. Existing user content remains intact.

## Workflow

### Skills

<!-- generated:skills-table:start -->
| Skill | Phase | Use |
|---|---|---|
| `b-plan` | Decide | Figure out what to do when scope or approach is fuzzy, then produce an execution-ready plan |
| `b-research` | Decide | Fetch outside truth: docs, API facts, comparisons, or recent evidence |
| `b-design` | Decide | Create or refresh docs/DESIGN.md as a frontend design standard |
| `b-implement` | Build | Make the scoped change from an approved plan or a small direct request |
| `b-init` | Build | Initialize or refresh repo-local agent instruction docs |
| `b-refactor` | Build | Rename, extract, move, inline, simplify, or delete behavior-preserving code |
| `b-debug` | Validate | Find the real runtime root cause and fix it only when authorized |
| `b-test` | Validate | Write or fix unit, integration, contract, and simulated-DOM tests |
| `b-browser` | Validate | Collect real-browser, visual, screenshot, live UI, or e2e evidence |
| `b-agentic-audit` | Validate | Audit b-agentic repository and design conformance, reporting source drift |
| `b-review` | Validate | Review changed code |
| `b-commit` | Ship | Split working-tree changes into approved cohesive commits |
| `b-pr-summary` | Ship | Write general PR copy for recent commits or commits ahead of cached origin |
<!-- generated:skills-table:end -->

Invoke a skill explicitly with Claude Code's `/b-agentic:<skill>` command, or let the always-loaded kernel route the request. Skills are generated from `skills/registry.yaml` and `skills/*/prompt.md`; edit those canonical sources rather than generated delivery files.

### Optional planner/worker sessions

Start independent named Claude Code sessions as `b-planner` and `b-worker` when coordination is useful. The planner discovers the worker freshly with `ListAgents`, sends a bounded plain-text handoff with `SendMessage`, and remains read-only. The worker owns all edits and verification, sends blocker/result messages to the planner, requests actual review, and pauses. Claude Code 2.1.224+ on macOS/Linux is required for cross-session messaging.

## Safety and managed MCPs

The plugin hook emits Claude `allow`, `ask`, or `deny` decisions for `PreToolUse`. Protected paths and outside-project access require approval (protected writes are denied); dangerous commands remain hard-denied; unknown tools, servers, operations, arguments, auth, and lifecycle actions fail closed. `permissions.deny` duplicates the highest-risk command denials.

The plugin ships direct `.mcp.json` entries for the recommended managed servers:

| MCP | Role | Default |
|---|---|---|
| Serena | Exact-symbol semantic coding and diagnostics | Optional per task |
| CodeGraph | Repository architecture and impact questions | Optional per task |
| Context7 | Versioned library and framework documentation | Optional per task |
| Linear | Read-only issue context | Optional per task |
| Brave Search | Independent current discovery | Optional per task |
| Firecrawl | Bounded public research and extraction | Optional per task |
| Playwright | Real-browser evidence | Optional per task |

Canonical classes live in `references/mcp_operations.yaml`; the generated `plugin/hooks/mcp_policy.json` is validated against that source.

## Repository map

```text
plugin/                 # Claude Code plugin manifest, skills, agents, hooks, MCP config
skills/                 # Canonical registry, prompts, and generated skill payloads
references/             # Kernel template and managed MCP policy
tooling/generate/       # Source synchronization and renderers
tooling/install/        # Claude configuration lifecycle helpers
tooling/validate/       # Validation and fixture harnesses
tests/                  # Behavior and isolated install/hook fixtures
scripts/                # Validation, doctor, smoke, and audit entrypoints
```

## Verify

```bash
python3 tooling/generate/registry_sync.py --check
scripts/validate-skills.sh
scripts/b-agentic-audit.sh
```

Release validation additionally runs isolated Claude install/uninstall preservation, hook JSON decision fixtures, direct-MCP policy checks, and solo workflow input checks.
