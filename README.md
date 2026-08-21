# b-agentic

**A slim personal workflow kernel for the Pi coding agent. b-agentic and Pi are one integrated product.**

b-agentic routes work to focused skills, preserves safety gates, uses the right evidence, and verifies before claiming completion. It installs a compact Pi kernel, native skills, first-party extensions, and recommended MCP configuration, while reconciling bundled non-privileged dependencies.

Benefits:

- less ceremony for routine work, with planning and review when scope needs it
- safer local automation with explicit approval for risky or external actions
- evidence-backed workflows across code, documentation, tests, browsers, and MCPs

- **[Read the full operational reference](REFERENCE.md)** for installation details, package lifecycle, MCP readiness, safety behavior, and validation.
- Maintainer and project history: [AGENTS.md](AGENTS.md), [CHANGELOG.md](CHANGELOG.md), and [docs/decision_design.md](docs/decision_design.md).

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/dhoaibao/b-agentic/main/install.sh | bash
```

To install only the inline Markdown preview extension, use this standalone path after the public immutable `v0.1.0` tag has been published (the tag is not published by this repository state yet):

```bash
curl -fsSL https://raw.githubusercontent.com/dhoaibao/b-agentic/v0.1.0/pi/scripts/install-preview-markdown.sh | bash -s -- v0.1.0
```

The trailing `v0.1.0` argument must match the tag in the bootstrap URL; the installer accepts only `vX.Y.Z` release refs. That command fetches only the version-pinned preview extension, installs it atomically under `${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}/extensions`, preserves unrelated Pi files, and installs no other b-agentic extensions or dependencies. Run `/reload` in Pi afterward. An `AGENTS.md` entry is optional because the extension self-registers its `preview_markdown` tool and prompt metadata; add a local note only if you want an extra workflow reminder. Do not run this command until `v0.1.0` exists publicly.

After the standalone package is published, the same canonical extension can instead be installed through Pi's package manager:

```bash
pi install npm:@dhoaibao/preview-markdown
```

The npm package is limited to this preview extension and package-facing documentation; the raw GitHub installer remains the version-pinned alternative and does not install the broader b-agentic bundle.

The preview defaults to Tokyo Night Moon. In TUI, use `/preview-markdown:theme` to choose the globally persisted Tokyo Night Moon or Tokyo Night Day palette; changing it immediately refreshes existing visible previews, and restored previews use the current global theme without mutating stored session entries. Use `/preview-markdown:render <prompt>` to request a one-response preview, or `/preview-markdown:list` to copy one of the 20 most recent successful preview sources from the active branch; this cap affects only the selectable list and does not delete session history. Escape cancels, and no `AGENTS.md` entry or Pi `settings.json` change is required. See [REFERENCE.md](REFERENCE.md) for the preference path and fallback behavior.

Pin the bootstrap and source to a reviewed tag or commit with `B_AGENTIC_REF=<tag-or-commit>` and `--ref=<tag-or-commit>`. Use `--dry-run`, `--replace-memory`, `--uninstall`, `--sync`, or `--update` as needed. See [REFERENCE.md](REFERENCE.md) for flags, requirements, readiness checks, and safety details.

## How b-agentic works

| Phase | Skills | Purpose |
|---|---|---|
| **Decide** | `b-plan`, `b-research`, `b-design` | Resolve ambiguity, gather outside facts, or define a frontend standard. |
| **Build** | `b-implement`, `b-init`, `b-refactor` | Make the smallest approved change. |
| **Validate** | `b-debug`, `b-test`, `b-browser`, `b-agentic-audit`, `b-review` | Confirm runtime behavior, tests, browser evidence, repository conformance, and changed-code quality. |
| **Ship** | `b-commit`, `b-pr-summary` | Create explicitly approved local commits or write PR copy from local history. |

In a solo session, workflow is **Off**: one session routes and executes the needed phases. An optional planner/worker setup uses explicitly selected roles: the planner executes read-only `b-plan`, external `b-research`, `b-agentic-audit`, `b-review`, and `b-pr-summary`; the worker executes `b-design`, `b-implement`, `b-init`, `b-refactor`, `b-debug`, `b-test`, `b-browser`, and `b-commit` as the sole worktree writer. Ownership controls execution, not reading: the planner may inspect any skill, but delegates worker-owned work. Planner ownership is limited to read-only decision/planning, external research, audit/review, or release-summary coordination; implementation, mutation, runtime diagnosis, builds/tests, browser/operational verification, commits, mixed, and uncertain work belong to the worker. Unknown ownership fails closed to the worker. The worker pauses for the actual `b-review` gate before delegated work is complete.

## Skills

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

Invoke a skill explicitly with Pi's native `/skill:<name>` command. The usual path is:

```text
/skill:b-plan [goal] -> approve -> /skill:b-implement -> /skill:b-test -> /skill:b-review
```

## Managed MCPs

The installer writes all seven recommended entries to Pi's MCP configuration with lazy startup. **Configured** means an entry exists; it does not mean the server is installed, authenticated, or ready. **Required** means required for the stated capability, not for every b-agentic session.

| MCP | Role | Required | Default/configured state |
|---|---|---|---|
| Serena | Symbols, references, diagnostics, and precise semantic edits | Optional per task; CLI optional | Configured lazily; no key |
| CodeGraph | Repository architecture, flows, impact, and affected tests | Optional per task; CLI optional | Configured lazily; initialized only for a concrete architecture or impact question |
| Context7 | Versioned library and framework documentation | Optional per task; API key required when used | Configured lazily; `CONTEXT7_API_KEY` is user-supplied |
| Linear | Exact issue and linked-relation planning context | Optional per task; OAuth may be required when used | Configured lazily and restricted to `get_issue`; authentication state is unverified, so run `/mcp-auth linear` if needed |
| Firecrawl | Bounded public research, extraction, papers, and GitHub lookup | Optional per task; Bun and API key required when used | Configured lazily; `FIRECRAWL_API_KEY` is user-supplied |
| Brave Search | Independent current discovery and alternate search modalities | Optional per task; Bun and API key required when used | Configured lazily; `BRAVE_API_KEY` is user-supplied |
| Playwright | Real-browser, visual, console/network, and e2e evidence | Optional per task; Bun required when used | Configured lazily; no key |

## Core tools

| Tool | Role | Required/default/optional | Configuration |
|---|---|---|---|
| `bash` | Repository-local commands and automation | Required; Pi native default | Available in Pi sessions |
| `read`, `edit`, `write` | Routine file reads and edits | Required; Pi native default | Available in Pi sessions |
| `recall` | Optional observational-memory continuity | Optional | Available when the memory layer supplies it |
| `mcp` / `mcpScript` | Managed MCP gateway and bounded metadata/read orchestration | Optional; MCP adapter required to use configured servers | Configured through Pi MCP entries and policy |
| `intercom` | Explicit planner/worker coordination | Optional workflow; package default | Enabled by `pi-intercom` unless disabled |

## Pi packages

| Package | Purpose | Status | Installer behavior |
|---|---|---|---|
| `pi-mcp-adapter` | Loads Pi MCP configuration | Required for MCP use | Installed automatically |
| `pi-intercom` | Provides planner/worker coordination | Default for the optional two-role workflow | Installed automatically |
| `@juicesharp/rpiv-ask-user-question` | Structured interactive user decisions and blockers | Required for planner questions | Installed automatically at v2.6.2 |
| `pi-observational-memory` | Long-session compaction continuity | Optional | Installed automatically |
| `@narumitw/pi-usage` | Pi usage reporting | Optional | Installed automatically |
| `@narumitw/pi-lsp@0.32.0` | On-demand LSP diagnostics and source-action previews | Optional | Installed automatically at v0.32.0 |

Pi CLI, RTK, Serena, CodeGraph, Bun, and Pi packages install or refresh automatically without prompts. Bun-backed MCP servers use `bunx`, which resolves and caches their packages on first use. Modern shell tools are reported with an install hint because they generally require sudo.

`pi-lsp` provides optional, on-demand `lsp_diagnostics` and `lsp_fix` capabilities and source-action previews. It does not install language-server binaries: the commands for the language servers you use must already be on `PATH`. b-agentic writes no pi-lsp configuration; user `~/.pi/agent/pi-lsp.json` and trusted project `.pi/pi-lsp.json` remain owner-controlled. `lsp_fix` write actions and custom LSP calls retain the generic custom-tool approval behavior, and authoritative repository validation remains required.

## First-party extensions

| Extension | Purpose | Status |
|---|---|---|
| `b-agentic-preview-markdown.ts` | Inline Tokyo Night Moon/Day cards with `/preview-markdown:render`, `:theme`, `:list`, and `ctrl+shift+m` source copying | Default; installed and configured by b-agentic |
| `b-agentic-permissions.ts` | Shell, filesystem, and dangerous-command policy | Default; installed and configured by b-agentic |
| `b-agentic-mcp-permissions.ts` | Managed MCP and custom-tool approval | Default; installed and configured by b-agentic |
| `b-agentic-auto-mode.ts` | Confirmed automatic approval mode with explicit-deny protection | Default; installed and configured by b-agentic |
| `b-agentic-role.ts` | Explicit solo/planner/worker role selection | Default; installed and configured by b-agentic |
| `b-agentic-planner.ts` | Planner prompt-governed collaboration profile | Default; installed and configured by b-agentic |
| `b-agentic-planner-notify.ts` | Privacy-safe desktop notifications for explicit planner task-complete and user-input attention signals | Default; installed and configured by b-agentic |
| `b-agentic-worker.ts` | Worker collaboration profile | Default; installed and configured by b-agentic |
| `b-agentic-sync.ts` | In-session `/b-sync` and `/b-update` refresh commands | Default; installed and configured by b-agentic |

Policy helpers under `pi/extensions/b-agentic-support/` are shipped with the bundle but are not standalone discovered extensions.

## Repository layout

```text
b-agentic/
├── skills/                # Skill sources and generated delivery assets
├── pi/                    # Pi integration, config, extensions, and smoke lanes
├── references/            # Pi kernel and MCP policy
├── tooling/               # Generation, installation, and validation
├── tests/smoke/           # Installer smoke coverage
├── install.sh             # Bootstrap installer entrypoint
└── scripts/               # Validation and doctor wrappers
```

Validation entrypoints include `scripts/validate-skills.sh`, `scripts/validate-skills.sh --release`, and `scripts/b-agentic-audit.sh`. Browser evidence, live MCP schema probing, and prompt-effectiveness model calls are opt-in.
