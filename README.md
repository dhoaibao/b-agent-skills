# b-agentic

**A slim workflow kernel for the Pi coding agent. b-agentic and Pi are one integrated product.**

b-agentic installs a compact Pi kernel, focused phase skills, a permission extension, and recommended MCP configuration. Its job is simple: route work, preserve safety gates, use the right evidence, and verify before claiming done.

## Single-session and two-role workflows

b-agentic defaults to Off for a single-session workflow: it does not automatically promote the first session to planner. For the two-role workflow, explicitly start one session as planner and another as worker with `/b-role planner|worker` or `pi --b-role planner|worker`; `/b-role off` returns to solo work. The planner finishes discovery before one handoff; if needed, planner and worker agree on the approach before edits, then the planner stops exploring or issuing new implementation requests while the worker edits. The planner uses planning, research, review, and PR-summary skills; the worker owns implementation, debugging, refactoring, tests, browser checks, design/init writes, and explicit-user-request commits. Role-aware Intercom discovery coordinates the explicitly selected roles; assignments, review requests, findings, and approval use natural-language `send`, while `ask` is reserved for intentionally waiting for a response or a genuine blocker. After assigning a task, the planner waits for the worker's result rather than repeatedly polling `list-cwd` or `status`; roster/status calls remain for selecting a worker or handling genuine connection needs, not a polling loop. The worker pauses after requesting review and resumes only for findings or a new task, repeating until approval. The planner may mark a task complete only after `b-review` has passed against the actual diff and verification; if a blocker or decision cannot be resolved from scope or repository evidence, the planner asks the user one focused question and keeps the task open. `/b-role` selects only a role; it does not open a model picker. Role model and thinking-level preferences remain user-local for explicit `pi --b-role` startup selections and `/model` changes. See `pi/configs/README.md` for role details and CLI flags.

## Install

Default install for Pi:

```bash
curl -fsSL https://raw.githubusercontent.com/dhoaibao/b-agentic/main/install.sh | bash
```

Default install writes b-agentic files and Pi configuration only. Interactive installs prompt before installing or upgrading the Pi CLI. Non-interactive installs skip Pi CLI changes unless `B_AGENTIC_INSTALL_PI_CLI=Y` explicitly opts in.

For professional or shared environments, pin both the bootstrap script and installed source to a reviewed tag or commit instead of consuming whatever is currently on `main`:

```bash
export B_AGENTIC_REF=<tag-or-commit>
curl -fsSL "https://raw.githubusercontent.com/dhoaibao/b-agentic/${B_AGENTIC_REF}/install.sh" | bash -s -- --ref="${B_AGENTIC_REF}"
```

The same pin is available as `B_AGENTIC_REF=<tag-or-commit>` for scripted installs.

Useful flags:

- `--dry-run` previews changes
- `--replace-memory` replaces an existing managed kernel file
- `--uninstall` removes managed files
- `--ref=<tag-or-commit>` checks out that b-agentic git ref before installing managed files

MCP servers and RTK are installed from their latest available releases. Run `scripts/mcp-doctor.sh` after setting API keys to verify local readiness. Missing credentials or dependencies fail checks by default; use `--allow-degraded` to inspect status without failing.

Requirements: `bash`, `git`, Python 3.11+, and Bun (`bunx`) for MCP entries that use Bun. Pi CLI installation or upgrade is opt-in via the interactive prompt or `B_AGENTIC_INSTALL_PI_CLI=Y`.

Interactive installs prepare Pi and RTK; Serena and CodeGraph remain optional installs. When modern shell tools are missing, interactive installs prompt to install them: `rg` over `grep`, `fd` or `fdfind` over `find`, `bat` (or Debian/Ubuntu's `batcat`) over `cat`, `eza` or `exa` over `ls`, `sd` over `sed` or `awk`, and `jq` over `python -m json.tool` for JSON when they improve the task. Set `B_AGENTIC_INSTALL_SHELL_TOOLS=Y` to install them non-interactively.

## RTK (Rust Token Killer)

During interactive installs, the installer can prompt to download and run the RTK install script from its `master` branch. If `rtk` is already installed, the installer asks separately before upgrading it; the existing installation satisfies the prerequisite. Scripted upgrades require `B_AGENTIC_INSTALL_RTK=Y`. This is a remote shell script; only use it if you trust the RTK repository. RTK is required for b-agentic sessions; installation fails if it cannot be installed.

Once installed, agents use RTK for every command family it supports, including local discovery. For unsupported command families, they prefer modern shell tools (`rg`, `fd`/`fdfind`, `eza`/`exa`, `bat`/`batcat`, `sd`, `jq`) and fall back only when the replacement is missing or a worse fit. Regular repository-local commands are auto-allowed regardless of that recommendation, including routine build, test, package, and script automation; RTK does not bypass protections for explicit destructive or privileged commands, dependency writes, external/shared mutations, protected paths, outside-project paths, or unscoped Git content reads. Explicit destructive commands are denied. Build and test tools can execute code from the current repository, so this permission layer is not a process sandbox. Use Pi's sandbox integration or an isolated environment when running genuinely untrusted code. Examples:

```bash
rtk rg pattern src
fd -t f '.ts$'
eza -la
rtk git status
rtk cargo test
rtk pytest -q
```

Meta commands:

```bash
rtk gain            # Token savings analytics
rtk gain --history  # Recent command savings history
rtk --help           # Supported command families
rtk proxy <cmd>     # Optional raw execution with RTK tracking
```

RTK also provides an optional rewrite-only Pi extension:

```bash
rtk init --agent pi --global
```

This improves transparent command rewriting but does not replace b-agentic's permission extension or approval policy. b-agentic does not install it automatically.

Verification: `rtk --version`, `rtk gain`, `which rtk`.

## Serena MCP agent

Interactive installs can prompt to install the Serena MCP agent, which provides symbol discovery, references, diagnostics, and symbol edits. If `serena` is already installed, the installer asks before running `uv tool upgrade serena-agent`. Scripted upgrades require `B_AGENTIC_INSTALL_SERENA=Y`.

If `uv` is already installed, the installer runs:

```bash
uv tool install -p 3.13 serena-agent
```

If `uv` is missing, the installer prompts to install it from `https://astral.sh/uv/install.sh` before proceeding with Serena. As with any remote install script, only proceed if you trust the source.

## CodeGraph MCP agent

b-agentic writes a default [CodeGraph](https://github.com/colbymchenry/codegraph) MCP entry that runs `codegraph serve --mcp` with `CODEGRAPH_TELEMETRY=0`. In interactive sessions, the installer can prompt to install CodeGraph with `curl -fsSL https://raw.githubusercontent.com/colbymchenry/codegraph/main/install.sh | sh`; if CodeGraph is already installed, the installer asks before running `codegraph upgrade`. Scripted upgrades require `B_AGENTIC_INSTALL_CODEGRAPH=Y`. Run `codegraph init` in each repository where you want a local pre-indexed code graph.

b-agentic initializes CodeGraph for the first repository-wide architecture or impact task when the local index is absent, then uses it for architecture, dependency and call flows, impact radius, route-to-handler discovery, and affected-test discovery. Serena owns semantic code work: symbol discovery, declarations, references, implementations, diagnostics, precise edits and refactors, onboarding, and durable project memories. Do not query both tools for the same question. When their read calls answer distinct, independent questions, run them concurrently in one bounded `mcpScript` rather than sequentially. Every classified Serena tool is auto-approved for safe intended inputs: use onboarding for unfamiliar repositories, memory tools only for durable project facts, and the dashboard only for Serena troubleshooting; sensitive and outside-project paths remain gated. Missing CLIs are not installed automatically.

## Pi integration

Pi discovers native skills from `~/.pi/agent/skills/` and MCP configuration from `~/.pi/agent/mcp.json` through `pi-mcp-adapter`. b-agentic preserves user-owned configuration and reports every managed change.

Pi has no native permission model, so b-agentic installs a first-party set of purpose-specific `tool_call` extensions at `~/.pi/agent/extensions/`: `b-agentic-permissions.ts` for shell/filesystem policy, `b-agentic-mcp-permissions.ts` for managed MCP and custom-tool approval, `b-agentic-role.ts` for role selection and persistence, and `b-agentic-planner.ts`/`b-agentic-worker.ts` for prompt-only collaboration profiles. The extension auto-allows every classified Serena operation, plus classified managed read-only and safe conditional-read MCP operations, through direct Serena names, the adapter, and unambiguous top-level gateway calls with an explicit managed server and matching tool name. The trusted `mcpScript` container also auto-runs and permits read-only `tools.search`/`tools.describe` metadata discovery, while each nested `tools.call` retains the same policy. Top-level metadata selectors, non-Serena direct adapter tool names, and ambiguous gateway calls stay behind the approval gate because Pi shares that namespace with custom tools. Non-Serena managed mutations, local uploads, lifecycle actions, auth, user/unknown MCP servers, and other custom tools require approval and fail closed without UI. Protected paths, ambiguous shell and interpreter inputs, and outside-project executable paths remain approval-gated; explicit destructive shell commands are denied. The extension is a command-policy guard, not a process sandbox: approved build and test tools may execute repository-controlled code. Pi MCP requires the community adapter `pi-mcp-adapter` (prompted interactively, or `B_AGENTIC_INSTALL_PI_MCP_ADAPTER=Y` noninteractively). The optional `pi-observational-memory` package provides long-session compaction continuity; it is prompted interactively or installed noninteractively with `B_AGENTIC_INSTALL_PI_OBSERVATIONAL_MEMORY=Y`, and should be the sole automatic memory/compaction layer. Its current V3 model does not read V2 settings or memory format; after upgrading from V2, migrate the settings and start a clean Pi session. The optional `@narumitw/pi-usage` extension is also prompted interactively and can be installed noninteractively with `B_AGENTIC_INSTALL_PI_USAGE=Y`. After checking `pi list`, the installer runs `pi update --extensions` when Pi extensions are installed. Uninstall removes managed config/extension files but not any package. Pi enforces managed MCP and RTK policy from `references/mcp_operations.yaml` and `references/kernel.template.md`.

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
| `b-review` | Validate | Review changed code or run a b-agentic suite self-audit |
| `b-commit` | Ship | Split working-tree changes into approved cohesive commits |
| `b-pr-summary` | Ship | Write general PR copy for recent commits or commits ahead of cached origin |
<!-- generated:skills-table:end -->

Pi can route natural-language requests to these skills automatically. To invoke one explicitly, use Pi's native `/skill:<name>` command:

```text
/skill:b-plan [goal] -> approve -> /skill:b-implement -> /skill:b-test -> /skill:b-review
/skill:b-commit
/skill:b-pr-summary [commit-count]
/skill:b-research [external facts]
/skill:b-design [frontend design standard]
/skill:b-debug [runtime bug]
/skill:b-browser [UI/e2e evidence]
/skill:b-refactor [behavior-preserving transform]
```

## MCPs

The installer writes recommended MCP entries for:

- Serena: symbol discovery, references, diagnostics, and symbol edits.
- CodeGraph: local pre-indexed code structure, flows, impact radius, and affected tests.
- Context7: versioned library/framework docs.
- Firecrawl: primary public web search, bounded extraction, arXiv/paper and GitHub issue/discussion lookup, and approved deeper research.
- Brave Search: secondary public/current discovery and alternate source finding.
- Playwright: live browser, visual, console/network, and e2e evidence.

The installer does not eagerly start MCP servers, install `bunx` packages, or initialize repositories. b-agentic runs `codegraph init` only for repository-wide architecture or impact work when its local index is absent; Serena onboarding is auto-approved but runs only when repository onboarding is useful. It does not install missing CLIs. It reports local MCP readiness blockers such as missing binaries or API keys. Use `scripts/mcp-doctor.sh --session-tools` to verify the active session has RTK. When live network/process activity is approved, `scripts/mcp-doctor.sh --probe-schemas` explicitly starts or connects to each configured server and compares its current tool inventory with the canonical operation policy. Run it after MCP package updates and before release candidates; normal readiness output states that live schema verification was not run. Add `--suggestions` for human-readable review records and `--suggestions-json=<path>` for a machine-readable report; suggestion mode never edits the policy or configuration.

## Repository Layout

```text
b-agentic/
├── skills/                # Skill sources and generated delivery assets
├── pi/                    # Pi integration, config, extension, and smoke lanes
├── references/            # Pi kernel and MCP policy
├── tooling/generate/      # Registry and generated asset sync
├── tooling/install/       # Shared installer core
├── tooling/validate/      # Validation harness
├── tests/smoke/           # Installer smoke tests
├── install.sh             # Bootstrap installer entrypoint
└── scripts/               # Validation and smoke wrappers
```

Validation:

```bash
scripts/validate-skills.sh
scripts/validate-skills.sh --release
scripts/b-agentic-audit.sh
scripts/smoke-install.sh
scripts/mcp-doctor.sh
scripts/mcp-doctor.sh --allow-degraded
scripts/mcp-doctor.sh --probe-schemas  # explicit live server/network probe
scripts/mcp-doctor.sh --probe-schemas --suggestions --suggestions-json=/tmp/mcp-policy-suggestions.json
scripts/skill-doctor.sh
```

Browser evidence is opt-in. When requested, b-browser writes only under an explicitly approved local evidence directory, records the requested UI state and collected browser evidence, and never claims screenshot coverage unless a screenshot was collected.

Prompt effectiveness is an opt-in, human-scored check because it makes potentially billable model calls and is nondeterministic. Validate its default inputs without model calls, then pin the provider, model, and thinking level when comparing a baseline with a candidate:

```bash
python3 pi/tests/prompt_effectiveness.py --validate-inputs
python3 pi/tests/prompt_effectiveness.py --allow-model-calls --provider=<provider> --model=<model> --thinking=<level> --label=baseline > baseline.json
python3 pi/tests/prompt_effectiveness.py --routing --validate-inputs
python3 pi/tests/prompt_effectiveness.py --routing --allow-model-calls --provider=<provider> --model=<model> --thinking=<level> --label=baseline-routing > baseline-routing.json
```

The validation suite and doctors prove generated sync, install safety, Pi config shape, skill payloads, MCP operation policy regression, and local MCP readiness blockers. The default routing check is a static heuristic over skill registry metadata. The opt-in `--routing` effectiveness lane loads every native skill with read-only tools and records the model's reported selection; both effectiveness modes require human review against their included rubrics.

## Docs

- `README.md` is the repository overview.
- `AGENTS.md` is maintainer guidance.
- `CHANGELOG.md` records shipped revisions.
- `references/` contains the Pi kernel and canonical `mcp_operations.yaml` shipped to the Pi integration.
