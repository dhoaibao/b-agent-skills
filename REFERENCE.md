# b-agentic operational reference

[Back to the public overview](README.md)

This document contains the detailed installation, configuration, lifecycle,
safety, MCP, and verification guidance behind the concise [README.md](README.md).

## Install

Default install for Pi:

```bash
curl -fsSL https://raw.githubusercontent.com/dhoaibao/b-agentic/main/install.sh | bash
```

Default install writes b-agentic files and Pi configuration only. Pi CLI installation and upgrade run automatically without prompts.

### Standalone Markdown preview install

After the public immutable `v0.1.0` tag has been published, a user who wants
only the inline Markdown preview can run:

```bash
curl -fsSL https://raw.githubusercontent.com/dhoaibao/b-agentic/v0.1.0/pi/scripts/install-preview-markdown.sh | bash -s -- v0.1.0
```

The trailing `v0.1.0` argument must match the bootstrap URL tag; the
installer accepts only `vX.Y.Z` release refs. This exact future command fetches
only `pi/extensions/b-agentic-preview-markdown.ts` from the `v0.1.0` tag,
validates it, and atomically installs it as
`${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}/extensions/b-agentic-preview-markdown.ts`.
It preserves unrelated extension files and Pi configuration and does not
install any other b-agentic extension or dependency. Run `/reload` in the
current Pi session after installation. The tag is not claimed to be published
or executable from this repository state; wait until `v0.1.0` exists publicly.

No `AGENTS.md` entry is required because the extension self-registers its
`preview_markdown` tool and prompt metadata. An optional local `AGENTS.md` note
may remind future sessions to prefer `preview_markdown` when appropriate.

The preview defaults to Tokyo Night Moon. In a TUI session,
`/preview-markdown:theme` opens a native Moon/Day selector; `/preview-markdown:render <prompt>` requests a one-response preview, and `/preview-markdown:list` lists previews on the active branch for source copying. The selected theme is persisted globally in
`<Pi agent dir>/b-agentic/preview-theme.json`, not in a project file or Pi
`settings.json`. Escape cancels without changing the preference. A malformed
or missing preference safely falls back to Moon, and a persistence failure is
reported without changing the active behavior. Existing rendered entries keep
their stored palette while later previews use the current global selection.

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
- `--update` installs or updates RTK, Serena, CodeGraph, Bun, Pi, Dracula theme, and Pi extensions without pulling b-agentic.

Requirements: `bash`, `git`, and Python 3.11+. Bun, Pi, RTK, Serena, and
CodeGraph are installed or updated automatically without dependency opt-in
variables or prompts. Bun-backed MCP servers use `bunx`, which resolves and
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

## Serena MCP agent

The installer installs or upgrades the Serena MCP agent automatically with uv.

If `uv` is already installed, the installer runs:

```bash
uv tool install -p 3.13 serena-agent
```

If `uv` is missing, the installer installs it from
`https://astral.sh/uv/install.sh` before proceeding with Serena. Only use a
remote install script when you trust its source.

## CodeGraph MCP agent

b-agentic writes a default [CodeGraph](https://github.com/colbymchenry/codegraph)
entry that runs `codegraph serve --mcp` with `CODEGRAPH_TELEMETRY=0`. Interactive
the installer installs CodeGraph with:

```bash
curl -fsSL https://raw.githubusercontent.com/colbymchenry/codegraph/main/install.sh | sh
```

Existing CodeGraph installations are refreshed with `codegraph upgrade`. Run `codegraph init` only when a concrete repository-wide architecture or impact question requires it and the local index is absent; do not initialize merely because a task spans files.

## Managed MCPs

The installer writes recommended entries for Serena, CodeGraph, Context7,
Linear, Firecrawl, Brave Search, and Playwright. Servers use lazy lifecycle through the
adapter's proxy tool, so they are not eagerly started or injected into context.
The template sets a global `settings.requestTimeoutMs` of 30000 milliseconds
(30 seconds). API keys are user-supplied and are written only to user config,
never tracked templates.

| MCP | Use | Local readiness |
|---|---|---|
| Serena | Symbols, references, diagnostics, and semantic edits | `serena` CLI; onboarding only when useful |
| CodeGraph | Architecture, dependency/call flows, impact, and affected tests | `codegraph` CLI; initialize only for a concrete repository-wide architecture or impact question |
| Context7 | Versioned framework and API facts | `CONTEXT7_API_KEY` |
| Linear | Exact issue and linked-relation planning context | Configured read-only; authentication state is unverified, so run `/mcp-auth linear` if needed |
| Firecrawl | Primary public research, bounded extraction, papers, and GitHub lookup | Bun (`bunx`) and `FIRECRAWL_API_KEY` |
| Brave Search | Independent corroboration and specialized current search | Bun (`bunx`) and `BRAVE_API_KEY` |
| Playwright | Live browser, visual, console/network, and e2e evidence | Bun (`bunx`) |

The installer does not eagerly start MCP servers or initialize repositories;
Bun is installed or refreshed automatically, while Bun-backed MCP packages are
resolved and cached by `bunx` on first use. b-agentic initializes CodeGraph only when native inspection leaves a concrete
repository-wide architecture or impact question and its local index is absent;
it does not initialize merely because work spans files. Serena onboarding runs
only when repository onboarding is useful. b-agentic automatically installs
or updates RTK, Serena, CodeGraph, and Bun; modern shell tools remain
user-installed. Use `scripts/mcp-doctor.sh --session-tools` to verify the active
session has RTK. Use `--allow-degraded` to inspect status without failing.

When live network/process activity is approved,
`scripts/mcp-doctor.sh --probe-schemas` explicitly starts or connects to each
configured server and compares its current tool inventory with the canonical
operation policy. Linear is skipped until an authenticated adapter probe path
exists; the doctor never acquires OAuth tokens. Run it after MCP package updates and before release candidates. Add `--suggestions` for human-readable review records and
`--suggestions-json=<path>` for a machine-readable report; suggestion mode
never edits policy or configuration.

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

b-agentic installs the `@narumitw/pi-usage` extension automatically.

b-agentic installs `@narumitw/pi-lsp@0.32.0` automatically for optional, on-demand
`lsp_diagnostics` and `lsp_fix` capabilities and source-action previews. pi-lsp
starts language servers only when its tools are called and does not install their
binaries; the language-server commands must already be on `PATH`. The installer
writes no pi-lsp configuration: user `~/.pi/agent/pi-lsp.json` and trusted project
`.pi/pi-lsp.json` remain owner-controlled. `lsp_fix` write actions and custom LSP
calls retain the generic custom-tool approval behavior, and authoritative
repository validation remains required.

b-agentic installs `pi-intercom` automatically for its two-role workflow and installs
`@juicesharp/rpiv-ask-user-question@2.6.2` for structured planner decisions and blockers.
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
- `b-agentic-planner.ts` and `b-agentic-worker.ts` for collaboration profiles.
- `b-agentic-planner-notify.ts` for privacy-safe desktop notifications from explicit planner task-complete and user-input attention signals.
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
- Dracula theme: `~/.pi/agent/themes/dracula.json` (symlink to cached copy)
- Theme cache: `~/.pi/agent/b-agentic/themes/dracula.json`
- Permission extensions: `~/.pi/agent/extensions/` (managed files listed above)
- Extension snapshots and backups: `~/.pi/agent/b-agentic/extensions/` and `backups/`

Installers merge MCP configuration rather than replace it: unrelated user
servers survive, prompted secrets use a private input pipe, and API-key
placeholders remain in the tracked template. On normal install/upgrade and
`--update` (not `--sync`), b-agentic shallow-clones the Dracula Pi theme
repository, validates `dracula.json`, copies it to the theme cache, and links
`~/.pi/agent/themes/dracula.json` to that cached copy without changing Pi theme
settings or selection. User files and unrelated symlinks at the theme destination
are preserved with a warning. Uninstall removes only unchanged managed content
and symlinks, restores recorded user backups, preserves modified or
symlinked files, and never removes installed packages, including `@narumitw/pi-lsp`.

## Roles and coordination

b-agentic defaults to Off for a single-session workflow; the first same-CWD
session is not automatically promoted to planner. Explicitly start two sessions
with `/b-role planner` and `/b-role worker`, or `pi --b-role planner|worker`.
Use `/b-role off` to return to solo work. Role selection does not open a model
picker; explicit startup selections and `/model` changes can update per-role
preferences under `~/.pi/agent/b-agentic/role-models.json` without credentials.

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

The planner finishes discovery and settles one bounded handoff. If agreement is
needed, roles resolve it before edits; once the worker starts, the planner stops
exploring and issuing implementation requests. Its generated ownership mapping
permits read-only execution only of `b-plan`, external `b-research`,
`b-agentic-audit`, `b-review`, and `b-pr-summary`; it delegates `b-design`,
`b-implement`, `b-init`, `b-refactor`, `b-debug`, `b-test`, `b-browser`, and
`b-commit` to the explicitly selected same-directory worker. Ownership governs
execution, not inspection, so the planner may read any skill for planning,
delegation, audit, or review. Planner ownership is limited to read-only
decision/planning, external research, audit/review, or release-summary
coordination; implementation or mutation, runtime diagnosis, builds/tests,
browser/operational verification, commits, mixed, and uncertain work belong to
the worker. Direct user wording and an unavailable worker do not permit planner
implementation; unknown ownership fails closed to worker ownership, while
registry validation rejects missing or invalid owners. The assigned worker
executes its worker-owned task itself and never re-delegates or hands it off to
another worker; it may ask the assigning planner only about blockers, scope, or
external-research decisions.

Before every planner/worker Intercom `send` or `reply`, call `pending` first;
if `pending` reports an inbound ask, the response must use `reply` for that ask
and must not call `send` or `list-cwd`; only when `pending` reports no inbound
ask may `list-cwd` retrieve the exact target ID before `send`. The `to` value must be
the identifier token returned verbatim by the immediately preceding
authoritative `list-cwd` output. An authoritative short ID is valid; never guess,
reconstruct, extend, further abbreviate, or use a stale token, display name, or
alias. Treat a handoff, result, finding, or approval as sent only
after Intercom reports successful delivery. If `send` delivery fails, do not
retry the stale target or continue, commit, or close: call `pending` first; if
an inbound ask exists, use `reply` and do not call `send` or `list-cwd`; otherwise
call a fresh `list-cwd`; retry exactly once only if the intended peer is still live,
otherwise pause and surface the unavailable peer as the blocker. After
assigning a task, the planner waits for the worker's `send` result rather than
polling. The worker sends every terminal result to the same assigning planner
before pausing, including no-change and reported-gap outcomes; it reports
changed paths, verification outcomes, and gaps with `send`. Use `send` for task
delegation and worker result/review reporting. Reserve `ask` for a worker's
blocker or clarification question to the planner, or a planner's quick-answer
need from the worker; never use it to
wait for a delegated result. If the worker encounters an unresolved issue or
blocker, after `pending` reports no inbound ask it uses `list-cwd` to retrieve the
assigning planner's identifier token returned verbatim by the immediately
preceding authoritative `list-cwd` output and uses Intercom `ask` addressed to
that token with one focused question and waits; if `pending` reports an
inbound ask, it uses `reply` for it and does not call `send` or `list-cwd`. It
must not ask the user directly, stop midway, or send a premature
completion/review message while the planner waits. The planner resolves the
blocker via `reply` when possible; otherwise it escalates to the user and keeps
the task open. Every delegated worktree-changing task must pass the actual
`b-review` skill against the actual diff and verification before it is complete. Findings return to the
same worker for a verified fix and another review.

## In-session refresh

`/b-sync` confirms, pulls the installed b-agentic checkout, and syncs only
managed Pi skills, kernel, and first-party extensions before reloading Pi. It
does not install packages or change MCP configuration. `/b-update` runs without
an additional confirmation and updates RTK, Serena, CodeGraph, Bun, and Pi
extensions without pulling b-agentic; Bun-backed MCP packages are resolved by
`bunx` on first use. It then reloads Pi.
Both commands require an interactive session and take no arguments.

## Safety and approvals

The permission extension:

- auto-allows regular repository-local commands, including routine build, test, package, dependency, and script automation
- asks before external/shared mutations, dangerous-but-approvable actions, protected reads, and unclassified or unsafe MCP operations
- blocks prohibited destructive Git and Docker families and protected native writes/edits
- inspects compound shell segments and strips `env`/`sudo`/`rtk` wrappers and `git -C` option prefixes before matching
- fails closed for ambiguous expansion, opaque interpreters, outside-project executables, protected paths, and approval-required actions without UI; b-auto-mode is the only opt-in exception for `ask` decisions and never overrides `deny`
- auto-allows classified Serena and CodeGraph operations, plus classified read-only and safe conditional-read MCP operations; other custom tools require approval

This is a command-policy guard, not a process sandbox: approved build and test
tools may execute repository-controlled code. Use Pi sandboxing or an isolated
environment for genuinely untrusted code. b-agentic never pushes changes.

Native `read`/`edit`/`write` is preferred for routine repository work. Serena
starts after native search/read and is reserved for concrete exact-symbol,
reference, implementation, diagnostic, or reference-aware refactor needs;
relevant onboarding and durable project memories remain explicit exceptions.
Serialize Serena requests because concurrent calls can hang or time out.
CodeGraph owns repository-wide architecture, dependency/call flows, impact,
route-to-handler discovery, and affected-test discovery only for concrete
questions native inspection cannot settle. Do not initialize it merely because
work spans files, and do not query both tools for the same question.

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
