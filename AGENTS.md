<!-- b-init-managed:start -->
# b-agentic Maintainer Guide

## Repository Purpose

b-agentic is a slim workflow kernel built around Pi. It ships the always-loaded kernel, native skills, first-party Pi extensions, recommended MCP configuration, and installer/validation tooling; keep changes slim, evidence-backed, and verifiable.

## Project Profile

### Enforced local conventions

- **Pi TypeScript integration (`pi/`):** strict TypeScript is enabled for the first-party extensions, and the standalone preview package extends the same configuration. **Evidence:** `pi/tsconfig.json`, `pi/packages/preview-markdown/tsconfig.json`, `pi/package.json`.
- **Repository validation (`tooling/validate/`, `scripts/`, `pi/scripts/`, and `tests/`):** the CI lane provisions Python 3.12 and Node 22 and runs the repository's synchronization, TypeScript, validation, and audit commands. **Evidence:** `.github/workflows/validate.yml`, `tooling/validate/run.sh`, `pi/scripts/validate.sh`.

### Contextual boundaries and gaps

- **Installer and MCP configuration (`install.sh`, `tooling/install/`, `pi/configs/`, and Pi policy extensions):** CLI/environment inputs, user-configuration merges, remote install/update paths, and lazy MCP entries are observable boundaries; preserve the template's lazy/read-only constraints and user-owned configuration behavior when changing them. **Evidence:** `install.sh`, `tooling/install/common.sh`, `pi/configs/mcp.user.template.json`, `tests/smoke/install.sh`.
- **Unavailable local conventions:** no root package manifest, lint/format configuration, database or migration files, infrastructure/deployment manifests, or external-service client source was found beyond the installer/MCP integration. Do not invent guidance for those areas; reassess when new evidence appears. **Evidence:** tracked-file inventory, `pi/package.json`, `.github/workflows/validate.yml`.

## Project Map and Ownership

### Navigation and local edit boundaries

- `README.md` is the public overview; `REFERENCE.md` is the operational guide; `docs/decision_design.md` records evidence-backed design decisions; `docs/publish-preview-markdown.md` documents the standalone Pi package procedure.
- Edit canonical sources, not generated delivery assets. Keep prompts task-specific, avoid speculative workflow ceremony, and do not add root documentation surfaces without repository evidence.
- Keep shared workflow guidance in `references/`; Pi integration, configuration, extensions, packages, scripts, and Pi smoke tests in `pi/`; installer smoke coverage in `tests/smoke/`.
- Preserve user-owned Pi configuration and unrelated working-tree changes in installer and maintenance work.
- `install.sh` guards both CodeGraph upgrade paths with `CODEGRAPH_NO_INSTALL_REFRESH=1` and reports that guard in dry runs; keep this behavior covered by installer smoke tests.
- Keep `skills/registry.yaml` and `references/mcp_operations.yaml` in the JSON-compatible YAML subset required by the Python standard library.
- Record an observed failure, intended behavior change, and narrow regression check for behavior-shaping prompt changes.
- Before handing off a change, confirm it uses the correct source layer, generated assets are synchronized, Pi-specific details remain under `pi/`, and validation evidence matches the scope.

### Canonical sources and generated outputs

- `skills/registry.yaml` owns skill metadata, routing, and generated frontmatter; each `skills/*/prompt.md` owns the canonical skill body.
- `references/kernel.template.md` owns the generated Pi kernel; `references/mcp_operations.yaml` owns managed MCP classifications.
- `tooling/generate/registry_sync.py` renders `skills/*/SKILL.md`, the README skills table, kernel generated blocks, `pi/extensions/b-agentic-support/{role.ts,mcp.ts}`, `tooling/validate/{shared.py,behavior.py}`, `pi/scripts/validate.sh`, and `pi/tests/smoke.sh`. Run the generator after changing a canonical source; generated files are delivery artifacts and must not be edited as sources.
- The standalone preview package is canonical under `pi/packages/preview-markdown/`; its extension source is `pi/packages/preview-markdown/extensions/b-agentic-preview-markdown.ts`, and `pi/scripts/validate-preview-markdown-package.sh` validates its package contents.
- `references/kernel.template.md` is the compact runtime kernel and must remain within the validator's 120-line/12,000-byte limit. Keep `references/` limited to `kernel.template.md` and `mcp_operations.yaml`.

### Repository map

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

## Verification

- `python3 tooling/generate/registry_sync.py` — refresh generated delivery assets after canonical sources change.
- `python3 tooling/generate/registry_sync.py --check` — confirm generated outputs are synchronized.
- `scripts/validate-skills.sh` — run default repository synchronization, validation, behavior, policy, readiness, and Pi integration checks.
- `scripts/validate-skills.sh --release` — add RTK compatibility and isolated installer smoke coverage for release validation.
- `bash pi/scripts/validate.sh` — run Pi extension validation and generated role-prompt checks.
- `scripts/b-agentic-audit.sh` — run the repository/design-conformance audit checks.
- `scripts/smoke-install.sh` — run isolated installer smoke coverage.
- `bash pi/scripts/validate-preview-markdown-package.sh` — validate standalone preview package contents.
- `bash -n install.sh tests/smoke/install.sh` — syntax-check installer smoke entrypoints.
- `bash -n pi/scripts/install-preview-markdown.sh` — syntax-check the standalone preview installer.
- `rtk git diff --check` — check changed paths for whitespace errors.
- `python3 pi/tests/prompt_effectiveness.py --fixtures tests/behavior/init-guidance.json --skill skills/b-init/SKILL.md --validate-inputs` — validate the b-init behavior fixture inputs without model calls.
- `scripts/skill-doctor.sh` — check installed Pi skill payloads and kernel discovery.
- `scripts/mcp-doctor.sh --probe-schemas` — opt-in live MCP schema probing; it reports drift without editing policy and does not acquire OAuth tokens.
- `npm ci --prefix pi --no-fund --no-audit` — provision Pi dependencies for dependency-backed checks.
- `npm install --prefix pi` — install Pi dependencies before TypeScript checking when using the documented development path.
- `bash pi/scripts/typecheck.sh` — type-check the root Pi extensions and standalone preview package.
- `bash pi/scripts/typecheck-preview-markdown.sh` — type-check the standalone preview package alone.

<!-- b-init-managed:end -->
