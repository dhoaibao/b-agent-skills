<!-- b-init-managed:start -->
# b-agentic Maintainer Guide

## Repository purpose

b-agentic is a slim Claude Code workflow kernel. It ships the always-loaded kernel, Claude-native skills, custom planner/worker agents, fail-closed hooks, direct MCP configuration, and install/validation tooling. Keep the product slim, evidence-backed, and focused on safe, verifiable Claude Code workflows.

## Working rules

- `README.md` is the public overview; `REFERENCE.md` is the operational guide; `docs/decision_design.md` records evidence-backed design decisions.
- Edit canonical sources, not generated delivery assets. Keep shared workflow guidance in `references/`; Claude plugin components, hooks, configuration, and plugin smoke tests under `plugin/`; installer smoke coverage under `tests/smoke/`.
- Preserve user-owned Claude configuration and unrelated working-tree changes in installers and maintenance work.
- Keep `skills/registry.yaml` and `references/mcp_operations.yaml` in the JSON-compatible YAML subset required by the Python standard library.
- `tooling/generate/registry_sync.py` renders generated skill payloads, README tables, kernel blocks, and the plugin MCP policy snapshot. Run it without `--check` only after changing a canonical source; use `--check` to verify synchronization.
- Record an observed failure, intended behavior change, and narrow regression fixture for behavior-shaping prompt or hook changes.

## Sources and generated assets

- `skills/registry.yaml` owns skill metadata, routing, ownership, and generated frontmatter; each `skills/*/prompt.md` owns its skill body.
- `references/kernel.template.md` owns the generated always-loaded Claude kernel; `references/mcp_operations.yaml` owns managed MCP classifications.
- `plugin/` is the Claude-native delivery package. Only `.claude-plugin/plugin.json` belongs in that directory; skills, agents, hooks, settings, and `.mcp.json` stay at plugin root.
- Do not reintroduce another runtime's packages, extensions, themes, installer paths, or compatibility terminology.

## Verification

Run the narrowest applicable checks from the repository root:

```bash
python3 tooling/generate/registry_sync.py --check
scripts/validate-skills.sh
scripts/b-agentic-audit.sh
```

For install or release-readiness changes, also run `scripts/validate-skills.sh --release` and `scripts/smoke-install.sh`. Live MCP schema probing, named-session messaging, and browser evidence are separate opt-in checks.

## Codebase map

- `skills/` — canonical prompts, registry metadata, and generated payloads
- `references/` — kernel template and managed MCP policy
- `plugin/` — Claude Code plugin manifest, skills, agents, hooks, settings, and MCP config
- `tooling/generate/` — source synchronization and renderers
- `tooling/install/` — Claude configuration lifecycle helpers
- `tooling/validate/` — validation harness and policy checks
- `scripts/` — validation, doctor, smoke, and audit entrypoints
- `tests/` — hook, workflow, and isolated installer smoke coverage
- `README.md` / `REFERENCE.md` — public and operational documentation
- `docs/decision_design.md` — evidence-backed product and architecture

## Handoff review

Before handing off a change, confirm it uses the correct source layer, generated assets are synchronized, Claude-specific details remain under `plugin/`, and validation evidence matches the scope.
<!-- b-init-managed:end -->
