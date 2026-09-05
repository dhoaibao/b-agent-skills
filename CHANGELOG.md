# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog 2.0.0](https://keepachangelog.com/en/2.0.0/),
and this project adheres to Calendar Versioning: `vYYYY.MM.DD`, with one release
section per date and same-day changes aggregated in that section.

## [v2026.09.05] - 2026-09-05

### Removed

- Retire Serena, Linear, and Mobbin from the default managed MCP portfolio and its installer, policy, readiness, and guidance surfaces while preserving pre-existing user-owned configuration.
- Retire managed Pi LSP lifecycle/defaults/guidance, the legacy rule-guard extension, and built-in b_consult support while preserving user-owned configurations, packages, and modified legacy artifacts.

### Changed

- Clarify sequential blocker handling, in-scope verification loops, review-finding handoffs, and canonical Firecrawl bounds; recover kernel headroom while preserving MCP and safety guidance.
- Require affirmative CodeGraph selection for central repository-wide architecture, dependency/call-flow, route-to-handler, impact, or affected-test analysis, without initializing it merely because work spans multiple paths.
- Bound MCP scripting guidance and fixtures to distinguish one-call `mcp` from multi-call `mcpScript` workflows, preserve nested approval/authentication/output safeguards, and cap sources, results, normalized records, and primary scrapes.
- Replace legacy planner/worker coordination with explicit implementer and reviewer roles, guarded legacy compatibility, frozen candidate review evidence, and matching installer and validation coverage.

### Fixed

- Apply native Pi path resolution before permissions decisions, preserving protected and outside-project safeguards for URL, Unicode, and read-fallback paths.
- Preserve symlinked MCP configuration during manifest-only cleanup while confining cleanup inputs to safe local paths.
- Recognize Bun, Bunx, and Deno in RTK policy readiness without weakening approval for opaque execution.
- Keep the full Pi behavioral smoke suite runnable when the linked Pi SDK lacks its undeclared `@earendil-works/pi-server` runtime dependency, using a reviewed test-only, fail-closed fallback that bypasses itself when the real dependency is available.
- Bring the Pi workflow kernel back within enforced slimness limits while preserving bounded-MCP safeguards, fixing the Validate workflow failure.
- Restore macOS Validate smoke compatibility by safely handling symlinked temporary paths and Bash 3 argument expansion.
- Allow manifest-only cleanup to handle canonical defaults through symlinked HOME aliases without weakening symlink safeguards.
- Use the repository-pinned Pi 0.84.4 runtime in Validate workflow checks instead of an untested global 0.84.2 install.

## [v2026.09.04] - 2026-09-04

### Changed

- Clarify explicit frontend/UI versus non-UI implementation handoffs across canonical skills, and restore kernel headroom without weakening policy.

### Fixed

- Gate shared user/system Git configuration behind approval and add deterministic coverage for Serena's fail-closed traversal bound.

## [v2026.09.03] - 2026-09-03

### Added

- Add opt-in repository-aware planner notifications and interactive Pi titles while preserving privacy-safe defaults.

### Changed

- Align Pi development tooling to 0.84.4 and extend RTK policy coverage to CTest, Maven Daemon, and PHPT command families.

### Fixed

- Keep planner-notification repository labels free of control characters without triggering ESLint's control-regex rule.

## [v2026.09.02] - 2026-09-02

### Changed

- Guide `b-implement` and `b-frontend` toward evidence-backed minimal implementations—reusing repository or native capabilities before dependencies or bespoke code—while preserving product/design authority, accessibility, trust-boundary safeguards, error/data-loss handling, compatibility, security, and verification; add behavior scenarios covering these choices.
- Optimize Playwright MCP evidence collection with a headless isolated launcher, faster targeted browser guidance, and installer/validation migration coverage.

## [v2026.09.01] - 2026-09-01

### Added

- Initial release of b-agentic, providing a Pi workflow kernel, skills, extensions, validation, and installer tooling.
- Add a canonical managed-capability activation contract with trigger, prerequisite, readiness, and fallback guidance, plus a privacy-preserving `/b-status` snapshot that reports local metadata without inspecting MCP credentials or claiming operational LSP readiness.
- Integrate the installer-managed Pi todo extension with unpinned package lifecycle reconciliation, capability/status tracking, installer smoke coverage, and lightweight guidance for tracking non-trivial multi-step work.

### Changed

- Require workers to send reliable terminal results to the assigning planner and defer worktree-changing reviews to planner-owned b-review.
- Document agent-maintained daily changelog updates, including same-day release aggregation and human-facing entries.
- Redesign b-init repository guidance around a concise, evidence-backed operating guide with explicit migration and developer-rule preservation.
- Streamline two-role b-commit execution: the planner makes one exact, user-approved read-only proposal; the same worker resumes the unchanged approved handoff without duplicate approval, and snapshot or proposal mismatches stop the commit.
- Limit root `AGENTS.md` verification guidance to a concise set of normal repository checks.
- Make b-pr-summary render completed PR descriptions with the Markdown preview tool instead of offering an optional preview.
