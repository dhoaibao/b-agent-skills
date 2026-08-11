# b-agentic operational reference

[Back to the public overview](README.md)

This document contains the detailed installation, configuration, lifecycle,
safety, MCP, and verification guidance behind the concise [README.md](README.md).

## Install

Default install for Pi:

```bash
curl -fsSL https://raw.githubusercontent.com/dhoaibao/b-agentic/main/install.sh | bash
```

Default install writes b-agentic files and Pi configuration only. Interactive
installs prompt before installing or upgrading the Pi CLI. Non-interactive
installs skip Pi CLI changes unless `B_AGENTIC_INSTALL_PI_CLI=Y` explicitly opts
in.

For professional or shared environments, pin both the bootstrap script and
installed source to a reviewed tag or commit instead of consuming whatever is
currently on `main`:

```bash
export B_AGENTIC_REF=<tag-or-commit>
curl -fsSL "https://raw.githubusercontent.com/dhoaibao/b-agentic/${B_AGENTIC_REF}/install.sh" | bash -s -- --ref="${B_AGENTIC_REF}"
```

Useful flags:

- `--dry-run` previews changes.
- `--replace-memory` replaces an existing managed kernel file.
- `--uninstall` removes managed files.
- `--ref=<tag-or-commit>` checks out that b-agentic ref before installing managed files.
- `--sync` pulls the installed checkout and syncs managed Pi skills, kernel, and first-party extensions only.
- `--update` updates already-installed RTK, Serena, CodeGraph, Pi, and Pi extensions without pulling b-agentic or installing missing components.

Requirements: `bash`, `git`, Python 3.11+, and Bun (`bunx`) for MCP entries
that use Bun. Pi CLI installation or upgrade is opt-in via the interactive
prompt or `B_AGENTIC_INSTALL_PI_CLI=Y`.

Interactive installs prepare Pi and RTK; Serena and CodeGraph remain optional
installs. When modern shell tools are missing, interactive installs prompt to
install them: `rg` over `grep`, `fd` or `fdfind` over `find`, `bat` (or Debian /
Ubuntu's `batcat`) over `cat`, `eza` or `exa` over `ls`, `sd` over `sed` or
`awk`, and `jq` over `python -m json.tool` for JSON when they improve the task.
Set `B_AGENTIC_INSTALL_SHELL_TOOLS=Y` to install them non-interactively.

## RTK (Rust Token Killer)

During interactive installs, the installer can prompt to download and run the
RTK install script from its `master` branch. If `rtk` is already installed,
the installer asks separately before upgrading it; the existing installation
satisfies the prerequisite. Scripted upgrades require
`B_AGENTIC_INSTALL_RTK=Y`. This is a remote shell script; only use it if you
trust the RTK repository. RTK is required for b-agentic sessions; installation
fails if it cannot be installed.

Once installed, agents use RTK for every command family it supports, including
local discovery. For unsupported command families, they prefer modern shell
tools (`rg`, `fd`/`fdfind`, `eza`/`exa`, `bat`/`batcat`, `sd`, `jq`) and fall back
only when the replacement is missing or a worse fit. Regular repository-local
commands are auto-allowed regardless of that recommendation, including routine
build, test, package, dependency, and script automation; RTK does not bypass
protections for explicit destructive or privileged commands, external/shared
mutations, protected paths, outside-project paths, or unscoped Git content
reads. Explicit destructive commands are denied. Build and test tools can
execute code from the current repository, so this permission layer is not a
process sandbox. Use Pi's sandbox integration or an isolated environment when
running genuinely untrusted code.

Examples:

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
rtk --help          # Supported command families
rtk proxy <cmd>     # Optional raw execution with RTK tracking
```

RTK also provides an optional rewrite-only Pi extension:

```bash
rtk init --agent pi --global
```

This improves transparent command rewriting but does not replace b-agentic's
permission extension or approval policy. b-agentic does not install it
automatically.

Verification: `rtk --version`, `rtk gain`, `which rtk`.

## Serena MCP agent

Interactive installs can prompt to install the Serena MCP agent. If `serena` is
already installed, the installer asks before running `uv tool upgrade
serena-agent`; scripted upgrades require `B_AGENTIC_INSTALL_SERENA=Y`.

If `uv` is already installed, the installer runs:

```bash
uv tool install -p 3.13 serena-agent
```

If `uv` is missing, the installer prompts to install it from
`https://astral.sh/uv/install.sh` before proceeding with Serena. Only use a
remote install script when you trust its source.

## CodeGraph MCP agent

b-agentic writes a default [CodeGraph](https://github.com/colbymchenry/codegraph)
entry that runs `codegraph serve --mcp` with `CODEGRAPH_TELEMETRY=0`. Interactive
sessions can prompt to install CodeGraph with:

```bash
curl -fsSL https://raw.githubusercontent.com/colbymchenry/codegraph/main/install.sh | sh
```

If CodeGraph is already installed, the installer asks before running
`codegraph upgrade`. Scripted upgrades require
`B_AGENTIC_INSTALL_CODEGRAPH=Y`. Run `codegraph init` in each repository where
you want a local pre-indexed code graph.

## Managed MCPs

The installer writes recommended entries for Serena, CodeGraph, Context7,
Firecrawl, Brave Search, and Playwright. Servers use lazy lifecycle through the
adapter's proxy tool, so they are not eagerly started or injected into context.
The template sets a global `settings.requestTimeoutMs` of 30000 milliseconds
(30 seconds). API keys are user-supplied and are written only to user config,
never tracked templates.

| MCP | Use | Local readiness |
|---|---|---|
| Serena | Symbols, references, diagnostics, and semantic edits | `serena` CLI; onboarding only when useful |
| CodeGraph | Architecture, dependency/call flows, impact, and affected tests | `codegraph` CLI; initialize on first relevant task |
| Context7 | Versioned framework and API facts | `CONTEXT7_API_KEY` |
| Firecrawl | Primary public research, bounded extraction, papers, and GitHub lookup | Bun (`bunx`) and `FIRECRAWL_API_KEY` |
| Brave Search | Independent corroboration and specialized current search | Bun (`bunx`) and `BRAVE_API_KEY` |
| Playwright | Live browser, visual, console/network, and e2e evidence | Bun (`bunx`) |

The installer does not eagerly start MCP servers, install `bunx` packages, or
initialize repositories. b-agentic initializes CodeGraph only for the first
repository-wide architecture or impact task when its local index is absent;
Serena onboarding runs only when repository onboarding is useful. Missing CLIs
are not installed automatically. Use `scripts/mcp-doctor.sh --session-tools`
to verify the active session has RTK. Use `--allow-degraded` to inspect status
without failing.

When live network/process activity is approved,
`scripts/mcp-doctor.sh --probe-schemas` explicitly starts or connects to each
configured server and compares its current tool inventory with the canonical
operation policy. Run it after MCP package updates and before release
candidates. Add `--suggestions` for human-readable review records and
`--suggestions-json=<path>` for a machine-readable report; suggestion mode
never edits policy or configuration.

## Pi integration and packages

Pi discovers native skills from `~/.pi/agent/skills/` and MCP configuration from
`~/.pi/agent/mcp.json` through `pi-mcp-adapter`. b-agentic preserves user-owned
configuration and reports every managed change.

Pi does not provide native MCP. b-agentic installs MCP server entries into
`~/.pi/agent/mcp.json` and expects the community package `pi-mcp-adapter` to load
them. Interactive installs prompt before running
`pi install npm:pi-mcp-adapter`; noninteractive installs do so only when
`B_AGENTIC_INSTALL_PI_MCP_ADAPTER=Y` is set.

For long-session compaction continuity, b-agentic can install the optional
`pi-observational-memory` package. Interactive installs prompt before running
`pi install npm:pi-observational-memory`; noninteractive installs require
`B_AGENTIC_INSTALL_PI_OBSERVATIONAL_MEMORY=Y`. Use it as the sole automatic
memory/compaction layer rather than combining it with another such extension.
Its V3 model does not read V2 settings or memory entries; after upgrading from
V2, migrate the settings and start a clean Pi session.

b-agentic can install the optional `@narumitw/pi-usage` extension. Interactive
installs prompt before running `pi install npm:@narumitw/pi-usage`;
noninteractive installs require `B_AGENTIC_INSTALL_PI_USAGE=Y`.

b-agentic installs `pi-intercom` by default for its two-role workflow;
`B_AGENTIC_INSTALL_PI_INTERCOM=N` explicitly disables it and leaves
collaboration unavailable. After checking `pi list`, the installer runs
`pi update --extensions` when Pi extensions are installed. Uninstall removes
managed config and extension files but not any package.

Pi has no native permission model, so b-agentic installs a first-party set of
purpose-specific `tool_call` extensions under `~/.pi/agent/extensions/`:

- `b-agentic-permissions.ts` for shell/filesystem policy.
- `b-agentic-mcp-permissions.ts` for managed MCP and custom-tool approval.
- `b-agentic-role.ts` for role selection and persistence.
- `b-agentic-planner.ts` and `b-agentic-worker.ts` for collaboration profiles.
- `b-agentic-sync.ts` for in-session refresh commands.

Helpers under `pi/extensions/b-agentic-support/` are not discovered as
standalone Pi extensions. Pi enforces managed MCP and RTK policy from
`references/mcp_operations.yaml` and `references/kernel.template.md`.

## Install layout

- Kernel memory: `~/.pi/agent/AGENTS.md`
- Skills: `~/.pi/agent/skills/<skill-name>/SKILL.md`
- Shared references: `~/.pi/agent/b-agentic/references/kernel.template.md` and `mcp_operations.yaml`
- MCP template: `~/.pi/agent/b-agentic/templates/mcp.user.template.json`
- User MCP config: `~/.pi/agent/mcp.json`
- Permission extensions: `~/.pi/agent/extensions/` (managed files listed above)
- Extension snapshots and backups: `~/.pi/agent/b-agentic/extensions/` and `backups/`

Installers merge MCP configuration rather than replace it: unrelated user
servers survive, prompted secrets use a private input pipe, and API-key
placeholders remain in the tracked template. Uninstall removes only unchanged
managed content, restores recorded user backups, preserves modified or
symlinked files, and never removes installed packages.

## Roles and coordination

b-agentic defaults to Off for a single-session workflow; the first same-CWD
session is not automatically promoted to planner. Explicitly start two sessions
with `/b-role planner` and `/b-role worker`, or `pi --b-role planner|worker`.
Use `/b-role off` to return to solo work. Role selection does not open a model
picker; explicit startup selections and `/model` changes can update per-role
preferences under `~/.pi/agent/b-agentic/role-models.json` without credentials.

Planner mode is analysis-only: it permits `read`, `recall`, Intercom, safe local
discovery commands, and classified read-only MCP calls. It blocks edits,
writes, builds/tests, commits, arbitrary shell commands, arbitrary MCP scripts,
and mutating MCP calls. Worker mode retains normal repository-local automation
and is the sole worktree writer.

The planner finishes discovery and settles one bounded handoff. If agreement is
needed, roles resolve it before edits; once the worker starts, the planner stops
exploring and issuing implementation requests. The planner sequences
`b-plan`, `b-research`, and `b-agentic-audit` as needed, delegates to the
explicitly selected same-directory worker, and reviews changed code with
`b-review`.

Before every planner/worker Intercom `send` or `reply`, call `pending`; an
inbound ask uses `reply`, otherwise `list-cwd` retrieves the exact target ID
before `send`. After assigning a task, the planner waits for the worker's
result rather than polling. The worker reports changed paths, verification
outcomes, and gaps, then pauses. Every delegated task must pass the actual
`b-review` skill against the actual diff and verification before it is complete.
Findings return to the same worker for a verified fix and another review.

## In-session refresh

`/b-sync` confirms, pulls the installed b-agentic checkout, and syncs only
managed Pi skills, kernel, and first-party extensions before reloading Pi. It
does not install packages or change MCP configuration. `/b-update` confirms and
updates already-installed RTK, Serena, CodeGraph, Pi, and Pi extensions without
pulling b-agentic or installing missing components, then reloads Pi. Both
commands require an interactive session and take no arguments.

## Safety and approvals

The permission extension:

- auto-allows regular repository-local commands, including routine build, test, package, dependency, and script automation
- asks before external/shared mutations, dangerous-but-approvable actions, protected reads, and unclassified or unsafe MCP operations
- blocks prohibited destructive Git and Docker families and protected native writes/edits
- inspects compound shell segments and strips `env`/`sudo`/`rtk` wrappers and `git -C` option prefixes before matching
- fails closed for ambiguous expansion, opaque interpreters, outside-project executables, protected paths, and approval-required actions without UI
- auto-allows classified Serena and CodeGraph operations, plus classified read-only and safe conditional-read MCP operations; other custom tools require approval

This is a command-policy guard, not a process sandbox: approved build and test
tools may execute repository-controlled code. Use Pi sandboxing or an isolated
environment for genuinely untrusted code. b-agentic never pushes changes.

Native `read`/`edit`/`write` is preferred for routine repository work. Serena is
reserved for exact symbols, references, implementations, diagnostics,
reference-aware refactors, relevant onboarding, and durable project memories;
serialize Serena requests because concurrent calls can hang or time out.
CodeGraph owns repository-wide architecture, dependency/call flows, impact,
route-to-handler discovery, and affected-test discovery. Do not query both for
the same question.

## Validation

Run the narrowest applicable checks from the repository root:

```bash
python3 tooling/generate/registry_sync.py --check
scripts/validate-skills.sh
scripts/validate-skills.sh --release
scripts/b-agentic-audit.sh
scripts/smoke-install.sh
scripts/mcp-doctor.sh
scripts/mcp-doctor.sh --allow-degraded
scripts/skill-doctor.sh
```

The validation suite proves generated sync, install safety, Pi config shape,
skill payloads, MCP operation policy regression, and local MCP readiness
blockers. The default routing check is static. The opt-in `--routing`
effectiveness lane and prompt-effectiveness runner make model calls and require
human review against their included rubrics.

Prompt effectiveness is opt-in and human-scored because it makes potentially
billable model calls and is nondeterministic. Validate inputs without model
calls, then pin provider, model, and thinking level for comparisons:

```bash
python3 pi/tests/prompt_effectiveness.py --validate-inputs
python3 pi/tests/prompt_effectiveness.py --allow-model-calls --provider=<provider> --model=<model> --thinking=<level> --label=baseline > baseline.json
python3 pi/tests/prompt_effectiveness.py --routing --validate-inputs
python3 pi/tests/prompt_effectiveness.py --routing --allow-model-calls --provider=<provider> --model=<model> --thinking=<level> --label=baseline-routing > baseline-routing.json
```

Browser evidence is opt-in. When requested, b-browser writes only under an
explicitly approved local evidence directory and never claims screenshot
coverage unless a screenshot was collected. Live MCP schema probing is also
opt-in because it starts processes and network activity.

## Repository map

- `skills/` — canonical prompts, registry metadata, and generated skill assets.
- `pi/` — Pi integration, configuration, extensions, and Pi smoke tests.
- `references/` — kernel and canonical MCP policy.
- `tooling/generate/` — registry synchronization and renderers.
- `tooling/install/` — shared installer implementation.
- `tooling/validate/` — validation harness.
- `tests/smoke/` — installer and Pi smoke coverage.
- `scripts/` — validation, doctor, smoke, and acceptance entrypoints.
- `docs/decision_design.md` — evidence-backed repository decisions.
