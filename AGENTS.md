<!-- b-init-managed:start -->
# b-agentic Maintainer Guide

## Repository Purpose

b-agentic is a slim workflow kernel built around Pi. It ships the always-loaded kernel, native skills, first-party Pi extensions, recommended MCP configuration, and installer/validation tooling; keep changes slim, evidence-backed, and verifiable.

## Working Rules

- `README.md` is the public overview; `REFERENCE.md` is the operational guide; `docs/decision_design.md` records evidence-backed design decisions; `docs/publish-preview-markdown.md` documents the standalone Pi package procedure.
- Edit canonical sources, not generated delivery assets. Keep prompts task-specific, avoid speculative workflow ceremony, and do not add root documentation surfaces without repository evidence.
- Keep shared workflow guidance in `references/`; Pi integration, configuration, extensions, packages, scripts, and Pi smoke tests in `pi/`; installer smoke coverage in `tests/smoke/`.
- Preserve user-owned Pi configuration and unrelated working-tree changes in installer and maintenance work.
- `install.sh` guards both CodeGraph upgrade paths with `CODEGRAPH_NO_INSTALL_REFRESH=1` and reports that guard in dry runs; keep this behavior covered by installer smoke tests.
- Keep `skills/registry.yaml` and `references/mcp_operations.yaml` in the JSON-compatible YAML subset required by the Python standard library.
- Record an observed failure, intended behavior change, and narrow regression check for behavior-shaping prompt changes.

## Sources and Generated Assets

- `skills/registry.yaml` owns skill metadata, routing, and generated frontmatter; each `skills/*/prompt.md` owns its canonical skill body.
- `references/kernel.template.md` owns the generated Pi kernel; `references/mcp_operations.yaml` owns managed MCP classifications.
- `tooling/generate/registry_sync.py` renders `skills/*/SKILL.md`, the README skills table, kernel generated blocks, `pi/extensions/b-agentic-support/role.ts`, and generated MCP runtime sets. Run it without `--check` only after changing a canonical source; use `--check` to verify synchronization.
- The standalone preview package is canonical under `pi/packages/preview-markdown/`; its extension source is `extensions/b-agentic-preview-markdown.ts`, and `pi/scripts/validate-preview-markdown-package.sh` validates its package contents.
- `references/kernel.template.md` is the compact runtime kernel and must remain within the validator's 120-line/12,000-byte limit. Keep `references/` limited to `kernel.template.md` and `mcp_operations.yaml`.

## Verification

Run the narrowest applicable checks from the repository root:

```bash
python3 tooling/generate/registry_sync.py --check
scripts/validate-skills.sh
scripts/b-agentic-audit.sh
scripts/smoke-install.sh
bash pi/scripts/validate-preview-markdown-package.sh
rtk git diff --check
```

For install, Pi integration, or release-readiness changes, also run `scripts/validate-skills.sh --release` and the relevant `scripts/skill-doctor.sh` or `scripts/mcp-doctor.sh` checks. Installer syntax checks use `bash -n install.sh tests/smoke/install.sh`; the standalone preview installer is checked by `bash -n pi/scripts/install-preview-markdown.sh`. Prompt-effectiveness model calls are opt-in; `pi/tests/prompt_effectiveness.py --validate-inputs` is the non-networked alternative. Live MCP schema probing and browser evidence are separate opt-in checks. The Pi extension TypeScript check is also opt-in and dependency-backed; run it with:

```bash
npm install --prefix pi
bash pi/scripts/typecheck.sh
```

It is intentionally not part of the offline validation suites.

## Codebase Map

- `skills/` — canonical skill prompts, registry metadata, and generated delivery assets
- `references/` — kernel template and managed MCP policy
- `pi/configs/` — Pi/MCP configuration templates and layout guidance
- `pi/extensions/` — first-party Pi extensions and non-discovered support helpers
- `pi/packages/` — standalone Pi packages, including preview Markdown
- `pi/scripts/` — Pi installers and integration validators
- `pi/tests/` — Pi smoke and prompt-effectiveness tests
- `tooling/generate/` — registry synchronization and renderers
- `tooling/install/` — shared installer and uninstall implementation
- `tooling/validate/` — validation harness and policy checks
- `scripts/` — validation, doctor, smoke, and audit entrypoints
- `tests/behavior/` and `tests/smoke/` — behavior fixtures and isolated installer smoke coverage
- `install.sh` — bootstrap, update, sync, and uninstall entrypoint
- `README.md` / `REFERENCE.md` — public and operational documentation
- `docs/decision_design.md` — evidence-backed repository decisions

## Maintainer Guide

Before handing off a change, confirm it uses the correct source layer, generated assets are synchronized, Pi-specific details remain under `pi/`, and validation evidence matches the scope.
<!-- b-init-managed:end -->
