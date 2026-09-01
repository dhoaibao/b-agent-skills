<!-- b-init-managed:start -->

## Repository Purpose

b-agentic is a slim personal workflow kernel integrated with Pi. It ships the always-loaded kernel, native skills, first-party Pi extensions, recommended MCP configuration, and installer/validation tooling. See the [public overview](README.md) and [operational reference](REFERENCE.md).

## Project Operating Guide

### Architecture and change map

- `skills/` holds skill metadata, canonical prompts, and generated skill files; `references/` holds shared kernel and MCP policy; `pi/` holds Pi extensions, configuration, packages, scripts, and smoke coverage; `tooling/` holds generation, installation, and validation; `tests/` holds behavior and installer smoke coverage.
- Change shared guidance in `references/`, Pi behavior in `pi/`, installer behavior in `install.sh` or `tooling/install/`, and validation in `tooling/validate/` or `scripts/`. Use the [decision record](docs/decision_design.md) when a change crosses these boundaries.

### Canonical sources and change flows

- `skills/registry.yaml` owns skill metadata, routing, phase, and execution ownership; each `skills/*/prompt.md` owns its canonical skill body. `tooling/generate/registry_sync.py` renders `SKILL.md` files and other generated delivery blocks, so edit the sources and regenerate rather than hand-editing outputs.
- `references/kernel.template.md` and `references/mcp_operations.yaml` own shared runtime guidance and managed MCP classifications. Generated Pi policy and validation assets follow those sources; the [operational reference](REFERENCE.md) documents their runtime boundaries.
- The standalone preview package is owned by `pi/packages/preview-markdown/`; use its [package guide](pi/packages/preview-markdown/README.md) and [publishing procedure](docs/publish-preview-markdown.md) for package-specific changes.

### Project constraints and boundaries

- Keep this supplement slim, strong, and usable: retain evidence-backed orientation, ownership, boundaries, and required flows, and link to deeper docs instead of copying setup, release, readiness, or diagnostic catalogs. This is the repository's b-init output quality standard; see [decision design](docs/decision_design.md).
- `skills/registry.yaml` and `references/mcp_operations.yaml` use the JSON-compatible YAML subset consumed by the generator and validators. Do not treat generated assets as canonical sources.
- Installer and Pi configuration changes cross a user-owned boundary: `tooling/install/` merges user configuration and preserves unrelated content, while templates do not prove live MCP readiness. See [Pi configuration layout](pi/configs/README.md) and the [operational reference](REFERENCE.md).
- No database or migration files, infrastructure/deployment manifests, or external-service client source beyond installer/MCP integration is present. Do not invent conventions for absent surfaces; reassess when evidence appears.

## Verification

- `python3 tooling/generate/registry_sync.py --check` — confirm generated delivery assets match canonical sources.
- `scripts/validate-skills.sh` — run the default synchronization, behavior, policy, readiness, and Pi integration checks.
- `python3 pi/tests/prompt_effectiveness.py --fixtures tests/behavior/init-guidance.json --skill skills/b-init/SKILL.md --validate-inputs` — validate b-init fixture inputs without model calls.
- `npm run quality` — run tracked source quality checks and strict Pi TypeScript checks when dependencies are installed.
- `rtk git diff --check` — check changed paths for whitespace errors.

<!-- b-init-managed:end -->

## Project Rules

This section is developer-owned. b-init refreshes must preserve it verbatim and never regenerate, move, or delete it.

- **Scope: changelog maintenance (enforced local convention).** Agents preparing a commit—including b-commit work—must update `CHANGELOG.md` before committing. Retain `## [Unreleased]` before dated releases; create or locate that commit date's single `## [vYYYY.MM.DD] - YYYY-MM-DD` section, never a separate ordinal release for another same-day commit, and append a cohesive human-facing entry under the appropriate standard Keep a Changelog category (`Added`, `Changed`, `Deprecated`, `Removed`, `Fixed`, or `Security`). Keep dated sections one per date and newest-first. Never copy or mechanically reuse raw commit-subject text as the entry. This is agent-maintained policy, not Git-hook or other commit automation; do not create a release entry merely for an uncommitted change. **Evidence:** `CHANGELOG.md`, `tooling/validate/changelog.py`.
