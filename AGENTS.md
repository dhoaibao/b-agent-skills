<!-- b-init-managed:start -->
# b-agentic Maintainer Guide

## Repository Purpose

b-agentic is a slim workflow kernel built around Pi: it ships the always-loaded kernel, native skills, first-party Pi extensions, recommended MCP configuration, and install/validation tooling. Keep the product slim, evidence-backed, and focused on safe, verifiable Pi workflows.

## Working Rules

- `README.md` is the public overview; `REFERENCE.md` is the operational guide; `docs/decision_design.md` records the evidence-backed design decisions.
- Edit canonical sources, not generated delivery assets. Keep prompts task-specific and avoid speculative workflow ceremony or new root documentation surfaces.
- Keep shared workflow guidance in `references/`; Pi integration, extensions, configuration, and Pi smoke tests in `pi/`; installer smoke coverage in `tests/smoke/`.
- Preserve user-owned Pi configuration and unrelated working-tree changes in installers and maintenance work.
- Keep `skills/registry.yaml` and `references/mcp_operations.yaml` in the JSON-compatible YAML subset required by the Python standard library.
- Record an observed failure, intended behavior change, and narrow regression check for behavior-shaping prompt changes.

## Sources and Generated Assets

- `skills/registry.yaml` owns skill metadata, routing, and generated frontmatter; each `skills/*/prompt.md` owns its skill body.
- `references/kernel.template.md` owns the generated Pi kernel; `references/mcp_operations.yaml` owns managed MCP classifications.
- `tooling/generate/registry_sync.py` renders `skills/*/SKILL.md`, README tables, kernel blocks, and generated MCP runtime sets. Run it without `--check` only after changing a canonical source; use `--check` to verify synchronization.
- Keep `references/` limited to `kernel.template.md` and `mcp_operations.yaml` unless repository evidence justifies otherwise.

## Verification

Run the narrowest applicable checks from the repository root:

```bash
python3 tooling/generate/registry_sync.py --check
scripts/validate-skills.sh
scripts/b-agentic-audit.sh
```

For install, Pi integration, or release-readiness changes, also run `scripts/validate-skills.sh --release` and the relevant `scripts/smoke-install.sh`, `scripts/skill-doctor.sh`, or `scripts/mcp-doctor.sh` checks. Prompt-effectiveness model calls are opt-in; `pi/tests/prompt_effectiveness.py --validate-inputs` is the non-networked alternative for that lane. Live MCP schema probing and browser evidence are separate opt-in checks.

## Codebase Map

- `skills/` — canonical skill prompts, registry metadata, and generated delivery assets
- `references/` — kernel template and managed MCP policy
- `pi/` — Pi configuration, extensions, scripts, and smoke tests
- `tooling/generate/` — source synchronization and renderers
- `tooling/install/` — shared installer implementation
- `tooling/validate/` — validation harness and policy checks
- `scripts/` — validation, doctor, smoke, and audit entrypoints
- `tests/smoke/` — isolated installer smoke coverage
- `README.md` / `REFERENCE.md` — public and operational documentation
- `docs/decision_design.md` — evidence-backed product and architecture decisions

## Handoff Review

Before handing off a change, confirm it uses the correct source layer, generated assets are synchronized, Pi-specific details remain under `pi/`, and validation evidence matches the scope.
<!-- b-init-managed:end -->
