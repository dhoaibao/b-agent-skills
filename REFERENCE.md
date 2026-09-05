# b-agentic operational reference

[Back to the public overview](README.md)

This is the operational source of truth for installation, lifecycle, safety,
MCP, package, role, and verification behavior behind the concise
[README.md](README.md). The installed path map and managed-versus-user-owned
boundary live in [pi/configs/README.md](pi/configs/README.md); this reference
owns the operations performed on those paths.

## Install

Default install for Pi:

```bash
curl -fsSL https://raw.githubusercontent.com/dhoaibao/b-agentic/main/install.sh | bash
```

Default install writes b-agentic files and Pi configuration only. Pi CLI installation and upgrade run automatically without prompts.

### Standalone Markdown preview install

After the public immutable `v0.1.2` tag has been published, a user who wants
only the inline Markdown preview can run:

```bash
curl -fsSL https://raw.githubusercontent.com/dhoaibao/b-agentic/v0.1.2/pi/scripts/install-preview-markdown.sh | bash -s -- v0.1.2
```

The trailing `v0.1.2` argument must match the bootstrap URL tag; the
installer accepts only `vX.Y.Z` release refs. This exact future command fetches
only `pi/packages/preview-markdown/extensions/b-agentic-preview-markdown.ts` from the `v0.1.2` tag,
validates it, and atomically installs it as
`${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}/extensions/b-agentic-preview-markdown.ts`.
It preserves unrelated extension files and Pi configuration and does not
install any other b-agentic extension or dependency. Run `/reload` in the
current Pi session after installation. The tag is not claimed to be published
or executable from this repository state; wait until `v0.1.2` exists publicly.

After the package is published, the same canonical extension can also be
installed through Pi:

```bash
pi install npm:@dhoaibao/preview-markdown
```

The npm package contains only the preview extension and package-facing
documentation; the raw GitHub installer remains the version-pinned alternative
and does not install the broader b-agentic bundle. Maintainers should use the
[standalone preview package publishing procedure](docs/publish-preview-markdown.md)
for validation and release steps.

No `AGENTS.md` entry is required because the extension self-registers its
`preview_markdown` tool and prompt metadata. An optional local `AGENTS.md` note
may remind future sessions to prefer `preview_markdown` when appropriate.

The preview defaults to Tokyo Night Moon. In a TUI session,
`/preview-markdown:theme` opens a native Moon/Day selector and immediately refreshes existing visible previews; restored previews use the current global theme without mutating stored session entries. `/preview-markdown:render <prompt>` requests a one-response preview, and `/preview-markdown:list` lists the 20 most recent successful previews on the active branch for source copying. This cap affects only the selectable list and does not delete session history. The selected theme is persisted globally in
`<Pi agent dir>/b-agentic/preview-theme.json`, not in a project file or Pi
`settings.json`. Escape cancels without changing the preference. A malformed
or missing preference safely falls back to Moon, and a persistence failure is
reported without changing the active behavior. Preview entries do not retain a
stored palette.

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
- `--update` installs or updates RTK, CodeGraph, Bun, Pi, Dracula theme, and Pi extensions without pulling b-agentic.

Requirements: `bash`, `git`, and Python 3.11+. Bun, Pi, RTK, and CodeGraph
are installed or updated automatically without dependency opt-in variables or
prompts. Bun-backed MCP servers use `bunx`, which resolves and
caches their packages on first use. Modern shell tools are not
installed or updated automatically because they generally require sudo; the
readiness report provides a platform-specific install hint.

Installer output stays newline-based for redirected and CI runs. On an interactive
TTY it uses a dependency-free ASCII stage indicator (disabled for `TERM=dumb`),
then prints a concise success and attention summary.

## RTK (Rust Token Killer)

The installer downloads and runs the RTK install script from its `master`
branch when RTK is missing and reruns it to refresh an existing installation.
This is a remote shell script; only use it if you
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

## CodeGraph MCP agent

b-agentic writes a default [CodeGraph](https://github.com/colbymchenry/codegraph)
entry that runs `codegraph serve --mcp` with `CODEGRAPH_TELEMETRY=0`. Interactive
the installer installs CodeGraph with:

```bash
curl -fsSL https://raw.githubusercontent.com/colbymchenry/codegraph/main/install.sh | sh
```

Existing CodeGraph installations are refreshed with `codegraph upgrade`. Select CodeGraph when repository-wide architecture, dependency/call-flow, route-to-handler, impact, or affected-test analysis is central to the task and likely valuable; use an available index for that question and initialize an absent index only for that concrete qualifying question. Do not select or initialize CodeGraph merely because a task spans files.

## Managed MCPs

The installer writes recommended entries for CodeGraph, Context7, Brave Search,
Firecrawl, and Playwright. Servers use lazy lifecycle through the
adapter's proxy tool, so they are not eagerly started or injected into context.
The template sets a global `settings.requestTimeoutMs` of 30000 milliseconds
(30 seconds). API keys are user-supplied and are written only to user config,
never tracked templates.

| MCP          | Use                                                                    | Local readiness                                                                                                                                                    |
| ------------ | ---------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| CodeGraph    | Architecture, dependency/call flows, impact, and affected tests        | `codegraph` CLI; initialize only for a concrete qualifying repository-wide architecture, dependency/call-flow, route-to-handler, impact, or affected-test question |
| Context7     | Versioned framework and API facts                                      | `CONTEXT7_API_KEY`                                                                                                                                                 |
| Firecrawl    | Primary public research, bounded extraction, papers, and GitHub lookup | Bun (`bunx`) and `FIRECRAWL_API_KEY`                                                                                                                               |
| Brave Search | Independent corroboration and specialized current search               | Bun (`bunx`) and `BRAVE_API_KEY`                                                                                                                                   |
| Playwright   | Live browser, visual, console/network, and e2e evidence                | Bun (`bunx`)                                                                                                                                                       |

The installer does not eagerly start MCP servers or initialize repositories;
Bun is installed or refreshed automatically, while Bun-backed MCP packages are
resolved and cached by `bunx` on first use. b-agentic selects CodeGraph when
repository-wide architecture, dependency/call-flow, route-to-handler, impact,
or affected-test analysis is central to the task and likely valuable; it uses
an available index for that question and initializes an absent index only for
that concrete qualifying question. It does not select or initialize CodeGraph
merely because a task spans files. b-agentic automatically installs or updates
RTK, CodeGraph, and Bun; modern shell tools remain user-installed. Use `scripts/mcp-doctor.sh --session-tools` to verify the active
session has RTK. Use `--allow-degraded` to inspect status without failing.

When live network/process activity is approved,
`scripts/mcp-doctor.sh --probe-schemas` explicitly starts or connects to each
configured server and compares its current tool inventory with the canonical
operation policy. The doctor never acquires OAuth tokens. Run it after MCP package updates and before release candidates. Add `--suggestions` for human-readable review records and
`--suggestions-json=<path>` for a machine-readable report; suggestion mode
never edits policy or configuration.

## Capability contract and local status

The installed [`~/.pi/agent/b-agentic/references/capabilities.yaml`](references/capabilities.yaml)
contract records activation triggers, prerequisites, local readiness, fallbacks,
and non-sensitive status signals for every managed package, MCP server, and
first-party extension. `/b-status` renders a local, read-only snapshot from
that contract using only package-listing, extension-file, MCP-config-file
existence, and non-sensitive launcher metadata. It does not parse `mcp.json`,
inspect environment/API-key values, start MCP servers, authenticate providers,
run browser probes, or persist prompts, code, URLs, secrets, or usage telemetry.
Managed MCP configuration and credentials remain unknown or unverified in this
snapshot; use `mcp-doctor` or an explicitly approved operation for readiness
that requires config content or authentication. Pi LSP package presence is
reported separately from operational diagnostics readiness, which requires a
relevant configured language-server executable. The snapshot complements
`mcp-doctor` and approved live/browser evidence rather than replacing them.

## Pi integration and packages

Pi discovers native skills from `~/.pi/agent/skills/` and MCP configuration from
`~/.pi/agent/mcp.json` through `pi-mcp-adapter`. b-agentic preserves user-owned
configuration and reports every managed change.

Pi does not provide native MCP. b-agentic installs MCP server entries into
`~/.pi/agent/mcp.json` and expects the community package `pi-mcp-adapter` to load
them. The installer runs `pi install npm:pi-mcp-adapter` automatically.

For long-session compaction continuity, b-agentic can install the optional
`pi-observational-memory` package. The installer runs `pi install npm:pi-observational-memory` automatically. Use it as the sole automatic
memory/compaction layer rather than combining it with another such extension.
Its V3 model does not read V2 settings or memory entries; after upgrading from
V2, migrate the settings and start a clean Pi session.

b-agentic installs the `@sreetej510/pi-usage` extension automatically.

b-agentic installs `@gotgenes/pi-anthropic-auth` automatically for Anthropic authentication support.

b-agentic installs `@narumitw/pi-lsp` automatically at the latest release for optional, on-demand
`lsp_diagnostics` and `lsp_fix` capabilities and source-action previews. pi-lsp
ships a built-in default server map for roughly 28 languages (including Biome for
JavaScript/TypeScript/JSON/CSS, ty and Ruff for Python, bash-language-server for
shell, and yaml-language-server for YAML), so no configuration is required for
those defaults. It starts servers only when its tools are called and does not
install their binaries: the actual prerequisite is that the relevant
language-server command is already on `PATH`; without one, diagnostics have no
server to route the repository's file types to. Package installation alone does
not establish operational LSP readiness: `/b-status` reports the package as
unknown until a relevant route can be safely verified. Custom configuration
replaces, rather than merges with, that default map. Resolution is
`PI_LSP_CONFIG` (inline
JSON or a JSON-file path), then `<workspace>/.pi/pi-lsp.json`, then
`~/.pi/agent/pi-lsp.json`; the installer writes none of these files and leaves
user and trusted-project configuration owner-controlled. Validated
`lsp_diagnostics` calls with project-confined, unprotected paths bypass generic
custom-tool approval; for directory arguments and the project-root default,
`.git`, `node_modules`, and `.venv` are not scanned, while protected files
elsewhere still fail closed. The LSP path check remains bounded and fail-closed. `lsp_fix` actions (including read-only-looking calls), malformed or
unsafe diagnostics calls, and other custom LSP calls retain the generic
custom-tool approval behavior, and authoritative repository validation remains
required.

b-agentic installs `@juicesharp/rpiv-todo` automatically at the latest release. This Pi package provides the todo tool, `/todos` command, and persistent overlay; the kernel guides lightweight task tracking for non-trivial multi-step work when available, without requiring it for small or routine tasks or imposing workflow orchestration, persistence, or telemetry.

b-agentic installs `pi-intercom` automatically for its planner/worker workflow and installs
`@juicesharp/rpiv-ask-user-question` at the latest release for structured planner decisions and blockers.
Planner questions group 1–4 related questions, offer 2–4 concrete options with
concise trade-offs, suffix the first recommended option with ` (Recommended)`,
and rely on the extension's automatic custom-answer row. Do not author `Other`,
`Type something.`, or `Next`. If the package or interactive UI is unavailable,
fall back to one focused plain-text question and retain the user-input attention
signal. After checking `pi list`, the installer runs `pi update --extensions`
after reconciling required Pi packages. Uninstall removes managed config and
extension files but not any package.

Pi has no native permission model, so b-agentic installs a first-party set of
purpose-specific `tool_call` extensions under `~/.pi/agent/extensions/`:

- `b-agentic-permissions.ts` for shell/filesystem policy.
- `b-agentic-mcp-permissions.ts` for managed MCP and custom-tool approval.
- `b-agentic-auto-mode.ts` for confirmed automatic approval with explicit-deny protection.
- `b-agentic-role.ts` for role selection and persistence.
- `b-agentic-planner.ts`, `b-agentic-worker.ts`, and `b-agentic-consult.ts` for planner collaboration and on-demand consultation.
- `b-agentic-planner-notify.ts` for privacy-safe desktop notifications from explicit planner task-complete and user-input attention signals.
- `b-agentic-sync.ts` for in-session refresh commands.

Planner desktop notifications remain fixed and privacy-safe by default. To opt in to
repository context, set `B_AGENTIC_NOTIFICATION_CONTEXT=1`. On Linux and macOS,
this adds only a sanitized basename of the current working directory to planner
notifications; in interactive Pi sessions it also sets the terminal title to
`pi — <repo>`. Absolute paths, session details, task text, and unusable basenames
are never included.

Helpers under `pi/extensions/b-agentic-support/` are not discovered as
standalone Pi extensions. Pi enforces managed MCP and RTK policy from
`references/mcp_operations.yaml` and `references/kernel.template.md`.

## Installed configuration layout

See [Pi Configuration Layout](pi/configs/README.md) for the installed path
map and managed-versus-user-owned boundary. This reference owns the lifecycle
that acts on those paths: merge, preservation, backup, restore, and uninstall
behavior is documented in the installation and package sections above and
below.

Installers merge MCP configuration rather than replace it: unrelated user
servers survive, prompted secrets use a private input pipe, and API-key
placeholders remain in the tracked template. On normal install/upgrade and
`--update` (not `--sync`), b-agentic shallow-clones the Dracula Pi theme
repository, validates `dracula.json`, copies it to the theme cache, and links
`~/.pi/agent/themes/dracula.json` to that cached copy without changing Pi theme
settings or selection. User files and unrelated symlinks at the theme destination
are preserved with a warning. Uninstall removes only unchanged managed content
and symlinks, restores recorded user backups, preserves modified or
symlinked files, and never removes installed packages, including `@gotgenes/pi-anthropic-auth`, `@narumitw/pi-lsp`, and `@juicesharp/rpiv-todo`.

## Roles and coordination

b-agentic defaults to Off for a single-session workflow; the first same-CWD
session is not automatically promoted to planner. Explicitly start a planner or worker session with `/b-role planner|worker`,
or `pi --b-role planner|worker`. Use `/b-role off` to return to solo work. Role
selection does not open a model picker; explicit startup selections and `/model`
changes update planner/worker preferences under
`~/.pi/agent/b-agentic/role-models.json` without credentials. Use the planner-only
`b_consult` tool for a hard decision or plan review when independent advice is
useful; choose its provider, model, and thinking level with `/b-consult-model`.
The command accepts an exact `provider/model [thinking-level]`, or a fuzzy model
search query with an optional thinking level; with UI it opens a searchable model picker with a visible
input and filtered model options. Model completions follow Pi's provider/model search shape, mark the
current active model, and the selected consultant preference is stored in the
shared `role-models.json` file. Each isolated call starts a fresh in-memory session, independently inspects the current repository with bounded read-only tools, and may use the managed MCP research gateway only under normal approval/auth and operation policy. It receives no outer conversation history and has no write, shell, Intercom, delegation, or worktree access. It returns bounded natural-language advice; repository findings inform that advice but do not replace authoritative review. An existing legacy `~/.pi/agent/b-agentic/consult-model.json` file is
left untouched and is not migrated or read.

`/b-auto-mode` is an explicit opt-in that warns and requires an interactive Y/N
confirmation before enabling. While enabled it auto-allows every `ask` decision,
while retaining every explicit `deny`; the user choice persists across Pi restarts
and `/new` sessions under `~/.pi/agent/b-agentic/auto-mode.json`, while legacy
session entries remain compatible. It displays red `b-auto-mode` in Pi's footer.
`pi --b-auto-mode` requests one-session startup enablement, but enabling still
fails closed without an interactive UI.

Planner mode is prompt-governed: it preserves the normal active tools and shared
shell, filesystem, MCP, and approval policies. Its injected profile assigns only
planning, research, audit/review, and release-summary skills to the planner and
directs implementation or operational work to the worker. The normal permission
extensions still protect sensitive paths, dangerous commands, unclassified MCP
calls, and local or external mutations regardless of role. Worker mode retains
normal repository-local automation and is the sole worktree writer.

The planner finishes discovery and settles one bounded handoff that identifies
expected paths/symbols, scope/non-goals, invariants, and checks. If agreement is
needed, roles resolve it before edits. Once the worker starts, planner work is limited to independent read-only work
outside that expected set, such as independent research, acceptance drafting,
or a hard unrelated decision: it must not mutate, revise in-flight scope, issue
another implementation task, or review the in-flight diff before the worker's
terminal result. After that result, the planner re-reads the actual changed paths before
review. Its generated ownership mapping permits read-only execution only of
`b-plan`, external `b-research`, `b-agentic-audit`, `b-review`, and
`b-pr-summary`; it delegates `b-design`, `b-frontend`, `b-implement`, `b-init`,
`b-refactor`, `b-debug`, `b-test`, `b-browser`, and `b-commit` to the explicitly selected
same-directory worker. Ownership governs execution, not inspection, so the
planner may read any skill for planning, delegation, audit, or review. Planner
ownership is limited to read-only decision/planning, external research,
audit/review, or release-summary coordination; implementation or mutation,
runtime diagnosis, builds/tests, browser/operational verification, commits,
mixed, and uncertain work belong to the worker. Direct user wording and an
unavailable worker do not permit planner implementation; unknown ownership
fails closed to worker ownership, while registry validation rejects missing or
invalid owners. The assigned worker executes its worker-owned task itself and
never re-delegates or hands it off to another worker.

Before every outbound Intercom `send` or `ask`, call `pending` first. If it
reports an inbound ask, reply to that ask immediately—do not call `send`, `ask`,
`list-cwd`, or another `pending` first. Otherwise immediately call `list-cwd`;
use only the identifier token returned verbatim by that authoritative output for
the intended `send` or `ask`. An authoritative short ID is valid; never guess,
reconstruct, extend, further abbreviate, or use a stale token, display name, or
alias. Treat a handoff, terminal result, finding, or approval as sent only after
Intercom reports successful delivery. If delivery fails, do not retry the stale
target or continue, commit, or close: call `pending`; if it reports an inbound
ask, reply immediately under the same rule; otherwise fresh `list-cwd`; retry
exactly once only if the intended peer remains live, otherwise pause and surface
the unavailable peer as the blocker. After assigning a task, the planner waits
for the worker's `send` result rather than polling.
The worker sends every terminal outcome for any assigned task—completed,
no-change, blocked, or reported gap—to the same assigning planner before
pausing, with changed paths, verification outcomes, acceptance coverage, and
gaps. Use `send` for task delegation, terminal results, review requests/findings,
and any question/request needing material work. Use `ask` only for one focused
question whose answer needs no substantial investigation, implementation, or
waiting; never use it to wait for a delegated result. A quick worker scope or
blocker question follows the pending-first target sequence; a material request
uses `send` instead. Every delegated worktree-changing task must pass the actual
`b-review` skill against the actual diff and verification before it is complete.
Findings return to the same worker for a verified fix and another review.

## In-session refresh

`/b-sync` confirms, pulls the installed b-agentic checkout, and syncs only
managed Pi skills, kernel, and first-party extensions before reloading Pi. It
does not install packages or change MCP configuration. `/b-update` runs without
an additional confirmation and updates RTK, CodeGraph, Bun, and Pi extensions without pulling b-agentic;
Bun-backed MCP packages are resolved by `bunx` on first use. It then reloads Pi.
Both commands require an interactive session and take no arguments.

## Safety and approvals

The permission extension:

- auto-allows regular repository-local commands, including routine build, test, package, dependency, and script automation
- asks before external/shared mutations, dangerous-but-approvable actions, protected reads, and unclassified or unsafe MCP operations
- blocks prohibited destructive Git and Docker families and protected native writes/edits
- inspects compound shell segments and strips `env`/`sudo`/`rtk` wrappers and `git -C` option prefixes before matching
- fails closed for ambiguous expansion, opaque interpreters, outside-project executables, protected paths, and approval-required actions without UI; b-auto-mode is the only opt-in exception for `ask` decisions and never overrides `deny`
- auto-allows classified CodeGraph operations, plus classified read-only and safe conditional-read MCP operations; other custom tools require approval

This is a command-policy guard, not a process sandbox: approved build and test
tools may execute repository-controlled code. Use Pi sandboxing or an isolated
environment for genuinely untrusted code. b-agentic never pushes changes.

Native `read`/`edit`/`write` is preferred for routine repository work. Select
CodeGraph when repository-wide architecture, dependency/call-flow,
route-to-handler, impact, or affected-test analysis is central to the task and
likely valuable. Use an available index for that question and initialize an
absent index only for that concrete qualifying question; do not initialize it
merely because work spans files.

## Repository quality checks

Repository-development tooling is separate from the installed runtime. From the
repository root, install the locked Node tools and pinned Python quality tools:

```bash
npm ci --no-fund --no-audit
python3 -m pip install -r requirements-dev-quality.txt
npm ci --prefix pi --no-fund --no-audit
```

`npm run quality` (or `bash scripts/quality-check.sh`) enumerates tracked files
with `git ls-files` and runs check-only ESLint, Prettier, Ruff lint and format
checks, ShellCheck, Markdownlint, and strict Pi TypeScript checks. It never
rewrites files. The tracked `.husky/pre-commit` hook is enabled by `npm ci`'s
`prepare` script and uses lint-staged to run the same applicable checks only on
staged files; it does not run the behavioral or installer suite and does not
rewrite the commit.

The quality check intentionally leaves generator-owned delivery outputs and the
JSON-compatible YAML registries to their existing synchronization and structural
validators. CI runs the complete quality check on Ubuntu and macOS before the
release validation and b-agentic audit lanes.

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
