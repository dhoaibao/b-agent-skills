<!-- b-init-managed:start -->
## Repository Purpose

b-agentic is a slim workflow kernel built around Pi. It ships the always-loaded kernel, native skills, first-party Pi extensions, recommended MCP configuration, and installer/validation tooling. **Evidence:** `README.md`, `REFERENCE.md`.

## Project Profile

- **Scope: Pi TypeScript integration (enforced local convention).** Root Pi extensions and the standalone preview package use strict TypeScript configuration; CI installs locked dependencies before running the Pi checks. **Evidence:** `pi/tsconfig.json`, `pi/packages/preview-markdown/tsconfig.json`, `pi/package.json`, `.github/workflows/validate.yml`.
- **Scope: skill and MCP policy sources (enforced local convention).** `skills/registry.yaml` and `references/mcp_operations.yaml` use the JSON-compatible YAML subset consumed by the Python generator and validators. **Evidence:** `skills/registry.yaml`, `references/mcp_operations.yaml`, `tooling/generate/registry_sync.py`, `tooling/validate/shared.py`.
- **Scope: repository validation (enforced local convention).** CI provisions Python 3.12 and Node 22, installs the locked Pi dependencies, checks generated outputs, runs release validation, and runs the suite audit on Ubuntu and macOS. **Evidence:** `.github/workflows/validate.yml`, `tooling/validate/run.sh`, `scripts/validate-skills.sh`, `scripts/b-agentic-audit.sh`.
- **Scope: installer and Pi configuration boundaries (contextual secure-coding practice).** `install.sh` accepts command-line and environment inputs; `tooling/install/` merges user-owned configuration and tracks managed content; `pi/configs/` defines lazy MCP entries and deferred key/OAuth values. Review changes as input, configuration, and authentication/readiness boundaries rather than inferring live readiness from templates. **Evidence:** `install.sh`, `tooling/install/common.sh`, `pi/configs/mcp.user.template.json`, `tests/smoke/install.sh`.
- **Scope: managed MCP integrations (contextual boundary).** The repository configures Serena, CodeGraph, Context7, Linear, Mobbin, Brave Search, Firecrawl, and Playwright; Linear and Mobbin use read-scoped/allowlisted configuration, while other readiness depends on local tools or user credentials. **Evidence:** `pi/configs/mcp.user.template.json`, `references/mcp_operations.yaml`, `REFERENCE.md`, `scripts/mcp-doctor.sh`.
- **Scope: inline Markdown preview (contextual rendering boundary).** The standalone package renders terminal Markdown, persists a global theme preference, retains selectable preview history, and supports exact source copying; its package manifest contains no bundled runtime dependencies. **Evidence:** `pi/packages/preview-markdown/README.md`, `pi/packages/preview-markdown/package.json`, `REFERENCE.md`.
- **Scope: repository-wide gaps.** No root package manifest, standalone lint/format/test configuration, database or migration files, infrastructure/deployment manifests, or external-service client source beyond the installer/MCP integration was found. Do not invent conventions for those areas; reassess when evidence appears. **Evidence:** tracked-file inventory, `pi/package.json`, `.github/workflows/validate.yml`.

## Project Map and Ownership

- **Scope: documentation navigation.** `README.md` is the public overview; `REFERENCE.md` is the operational guide; `docs/decision_design.md` records evidence-backed decisions; `docs/publish-preview-markdown.md` documents the standalone package procedure; `pi/configs/README.md` documents Pi configuration layout. **Evidence:** those tracked documentation paths.
- **Scope: canonical sources and generated outputs.** `skills/registry.yaml` owns skill metadata and routing, each `skills/*/prompt.md` owns a canonical skill body, `references/kernel.template.md` owns the Pi kernel, and `references/mcp_operations.yaml` owns managed MCP classifications. `tooling/generate/registry_sync.py` renders generated skill files, README/kernel blocks, role and MCP policy helpers, validation markers, and Pi smoke markers; generated assets are delivery outputs, not sources. **Evidence:** `tooling/generate/registry_sync.py`, `skills/registry.yaml`, `references/kernel.template.md`, `references/mcp_operations.yaml`.
- **Scope: Pi package ownership.** The canonical preview package is `pi/packages/preview-markdown/`, with extension source `pi/packages/preview-markdown/extensions/b-agentic-preview-markdown.ts`; its package validator and publishing procedure are `pi/scripts/validate-preview-markdown-package.sh` and `docs/publish-preview-markdown.md`. **Evidence:** `pi/packages/preview-markdown/package.json`, `pi/packages/preview-markdown/README.md`, those validator/procedure paths.
- **Scope: local edit boundaries.** Keep shared kernel and MCP guidance in `references/`; Pi configuration, extensions, packages, scripts, and Pi smoke coverage in `pi/`; installer implementation in `tooling/install/`; repository validation in `tooling/validate/` and `scripts/`; behavior and installer smoke coverage in `tests/`. Root `install.sh` is the bootstrap entrypoint. **Evidence:** tracked-file inventory, `install.sh`, `.github/workflows/validate.yml`.
- Keep durable guidance current: when a change makes a recorded project fact stale or introduces a durable project purpose, convention, boundary, ownership rule, map entry, or verification command, update the relevant `AGENTS.md` fact in the same change; otherwise leave it unchanged. Do not update `AGENTS.md` for unrelated code edits.

## Verification

- `python3 tooling/generate/registry_sync.py` — refresh generated delivery assets after canonical source changes. **Evidence:** tooling/generate/registry_sync.py.
- `python3 tooling/generate/registry_sync.py --check` — confirm generated assets are synchronized. **Evidence:** .github/workflows/validate.yml, tooling/validate/run.sh.
- `npm ci --prefix pi --no-fund --no-audit` — install the locked Pi dependency set used by CI. **Evidence:** .github/workflows/validate.yml, pi/package-lock.json.
- `npm install --prefix pi` — provision Pi dependencies for the documented development path. **Evidence:** REFERENCE.md, pi/package.json.
- `bash pi/scripts/typecheck.sh` — type-check root Pi extensions and the preview package when dependencies are available. **Evidence:** .github/workflows/validate.yml, pi/scripts/typecheck.sh.
- `bash pi/scripts/typecheck-preview-markdown.sh` — type-check the standalone preview package alone. **Evidence:** pi/scripts/typecheck-preview-markdown.sh.
- `bash pi/scripts/validate.sh` — run Pi extension and generated role-prompt validation. **Evidence:** tooling/validate/run.sh, pi/scripts/validate.sh.
- `scripts/validate-skills.sh` — run the default synchronization, validation, behavior, policy, readiness, and Pi integration checks. **Evidence:** scripts/validate-skills.sh, tooling/validate/run.sh.
- `scripts/validate-skills.sh --release` — add RTK compatibility and isolated installer smoke coverage. **Evidence:** tooling/validate/run.sh, .github/workflows/validate.yml.
- `scripts/b-agentic-audit.sh` — run decision-design and suite-audit checks. **Evidence:** scripts/b-agentic-audit.sh.
- `scripts/smoke-install.sh` — run isolated installer smoke coverage. **Evidence:** scripts/smoke-install.sh, tests/smoke/install.sh.
- `bash pi/scripts/validate-preview-markdown-package.sh` — validate the standalone package manifest and packed contents. **Evidence:** pi/scripts/validate-preview-markdown-package.sh, docs/publish-preview-markdown.md.
- `bash -n install.sh tests/smoke/install.sh` — syntax-check installer entrypoints. **Evidence:** install.sh, tests/smoke/install.sh.
- `bash -n pi/scripts/install-preview-markdown.sh` — syntax-check the standalone preview installer. **Evidence:** pi/scripts/install-preview-markdown.sh.
- `python3 pi/tests/prompt_effectiveness.py --fixtures tests/behavior/init-guidance.json --skill skills/b-init/SKILL.md --validate-inputs` — validate b-init fixture inputs without model calls. **Evidence:** tests/behavior/init-guidance.json, pi/tests/prompt_effectiveness.py, tooling/validate/run.sh.
- `scripts/skill-doctor.sh` — check installed Pi skill payloads and kernel discovery. **Evidence:** scripts/skill-doctor.sh, tooling/validate/skill_doctor.py.
- `scripts/mcp-doctor.sh` — inspect local MCP readiness; add its opt-in schema-probe option only when live process/network checks are intended. **Evidence:** scripts/mcp-doctor.sh, REFERENCE.md.
- `rtk git diff --check` — check changed paths for whitespace errors. **Evidence:** repository maintainer guidance and the installed RTK command family.

<!-- b-init-managed:end -->
