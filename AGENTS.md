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

## Project Profile

### Enforced local conventions

- **Pi TypeScript integration (`pi/`):** strict TypeScript is enabled for the first-party extensions, and the standalone preview package extends the same configuration. **Evidence:** `pi/tsconfig.json`, `pi/packages/preview-markdown/tsconfig.json`, `pi/package.json`. **Verify:** `npm ci --prefix pi --no-fund --no-audit` followed by `bash pi/scripts/typecheck.sh`, and `bash pi/scripts/validate-preview-markdown-package.sh`.
- **Generated delivery assets (`skills/`, `references/`, and generated README/Pi surfaces):** edit the canonical registry, prompt, template, or policy sources rather than generated outputs. **Evidence:** `tooling/generate/registry_sync.py`, `README.md`, `docs/decision_design.md`. **Verify:** `python3 tooling/generate/registry_sync.py --check`.
- **Repository validation (`tooling/validate/`, `scripts/`, `pi/scripts/`, and `tests/`):** the CI lane provisions Python 3.12 and Node 22 and runs the repository's synchronization, TypeScript, validation, and audit commands. **Evidence:** `.github/workflows/validate.yml`, `tooling/validate/run.sh`, `pi/scripts/validate.sh`. **Verify:** `bash scripts/validate-skills.sh --release`.

### Contextual boundaries and gaps

- **Installer and MCP configuration (`install.sh`, `tooling/install/`, `pi/configs/`, and Pi policy extensions):** CLI/environment inputs, user-configuration merges, remote install/update paths, and lazy MCP entries are observable boundaries; preserve the template's lazy/read-only constraints and user-owned configuration behavior when changing them. **Evidence:** `install.sh`, `tooling/install/common.sh`, `pi/configs/mcp.user.template.json`, `tests/smoke/install.sh`. **Verify:** `bash scripts/smoke-install.sh`; live schema probing remains opt-in with `scripts/mcp-doctor.sh --probe-schemas`.
- **Unavailable local conventions:** no root package manifest, lint/format configuration, database or migration files, infrastructure/deployment manifests, or external-service client source was found beyond the installer/MCP integration. Do not invent guidance for those areas; reassess when new evidence appears. **Evidence:** tracked-file inventory, `pi/package.json`, `.github/workflows/validate.yml`. **Verify:** TODO—add focused commands or area guidance only when the repository gains the corresponding files.

## Sources and Generated Assets

- `skills/registry.yaml` owns skill metadata, routing, and generated frontmatter; each `skills/*/prompt.md` owns its canonical skill body.
- `references/kernel.template.md` owns the generated Pi kernel; `references/mcp_operations.yaml` owns managed MCP classifications.
- `tooling/generate/registry_sync.py` renders `skills/*/SKILL.md`, the README skills table, kernel blocks, role ownership, prompt-marker blocks, and MCP runtime policy into `README.md`, `references/kernel.template.md`, `pi/extensions/b-agentic-support/{role.ts,mcp.ts}`, `tooling/validate/{shared.py,behavior.py}`, `pi/scripts/validate.sh`, and `pi/tests/smoke.sh`. Run it without `--check` only after changing a canonical source; use `--check` to verify synchronization.
- The standalone preview package is canonical under `pi/packages/preview-markdown/`; its extension source is `pi/packages/preview-markdown/extensions/b-agentic-preview-markdown.ts`, and `pi/scripts/validate-preview-markdown-package.sh` validates its package contents.
- `references/kernel.template.md` is the compact runtime kernel and must remain within the validator's 120-line/12,000-byte limit. Keep `references/` limited to `kernel.template.md` and `mcp_operations.yaml`.

## Verification

Run the narrowest applicable checks from the repository root:

```bash
python3 tooling/generate/registry_sync.py --check
scripts/validate-skills.sh
bash pi/scripts/validate.sh
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

This command runs both the root Pi extension check and the standalone Preview Markdown package check. It is intentionally not part of the offline validation suites; `bash pi/scripts/typecheck-preview-markdown.sh` is also available for the package check alone.

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
