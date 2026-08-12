---
name: b-design
description: >
  Frontend design-standard authoring for creating or refreshing
  `docs/DESIGN.md` from user descriptions, attached images or mockups,
  existing frontend files, or current design docs. Use when the agent
  needs to extract, normalize, or rewrite shared UI style guidance for
  future frontend implementation. Unlike b-implement, it writes design
  guidance rather than UI code; unlike b-browser, it does not collect
  final browser evidence.
---

<!-- Generated from skills/registry.yaml and skills/b-design/prompt.md. Edit those sources, not this file. -->

# b-design

Create or refresh `docs/DESIGN.md`, the repo-local frontend design standard. Do not implement UI code.

## When to use

- The user asks to create, rewrite, extract, or normalize frontend design guidance.
- The requested output is `docs/DESIGN.md` or a shared frontend style standard.
- The user provides screenshots, mockups, existing UI files, or prose describing a desired product style.

## When NOT to use

- The user wants frontend code changed now -> use **b-implement** after design guidance exists or is unnecessary.
- The user wants live visual/browser evidence -> use **b-browser**.
- The user wants a broader implementation plan -> use **b-plan**.
- The repo already has sufficient design-system docs and the task is only to follow them -> use the relevant build or validation skill.

## Tool guidance

- `bash` - `rtk git status --short`, diffs, and modern discovery (`rg`, `fdfind`, `eza`).
- `read`/`edit`/`write` - inspect sources and update only `docs/DESIGN.md` unless broader docs were approved.
- `serena` - after native search/read, inspect a specific exact symbol or
  reference only when it materially improves precision about code ownership or
  component patterns; use native `read`/`edit`/`write` for routine file work and
  serialize requests.

## Steps

1. Confirm the source mode: user description, attached image/mockup, existing `docs/DESIGN.md`, design-token source, current frontend code, or a mix.
2. Run `rtk git status --short` via Bash for repo work and preserve unrelated changes.
3. Inspect the lightest useful evidence: existing design docs, frontend components, tokens, CSS, layout files, screenshots, and repo conventions. Use native `read` first; use Serena only after native search/read when a specific exact symbol or reference materially improves the code-structure evidence, and do not parallelize or batch Serena calls. Do not invent a design system when evidence is thin.
4. If analyzing images, separate observed facts from inferred rules. Treat exact dimensions, counts, colors, and spatial alignment as approximate unless supported by source files or browser evidence.
5. Create or update only `docs/DESIGN.md` with edit/write unless the user explicitly approved a broader documentation change. Preserve useful existing content, remove generic filler, and mark unresolved product choices as open questions.
6. Keep the document implementation-facing and concise. Prefer rules an agent can apply while coding over design theory.
7. Include exact tokens only when supported by repo evidence. Include a short verification checklist that later **b-implement** and **b-browser** work can use.
8. Verify referenced paths exist where possible, then inspect the diff for unsupported claims and ceremony.

## Structure guidance

Do not force a long default skeleton when evidence is sparse. Cover only the durable standards the evidence supports.

Use the following as an adaptable checklist, not a required document outline:

- Product character, audience, and workflows
- Visual principles and layout system
- Color, typography, spacing, density, and radius
- Components and interaction states
- Responsive behavior and accessibility
- Implementation rules, do's/don'ts, and verification checklist
- Source evidence and open questions

Omit YAML front matter when exact token values are not evidenced or when the repo already has a better token source.

## Content Rules

- State durable standards for the product, not page-specific implementation notes.
- Make rules concrete: density, radius, spacing scale, component usage, icon usage, color roles, typography scale, empty/loading/error states, and responsive behavior.
- Keep prose primary. Tokens capture exact values; prose explains visual intent, tradeoffs, scarcity rules, and negative constraints.
- Prefer current repo tokens, components, and CSS variables over newly invented values.
- Keep image-derived guidance honest: use language like "appears", "inferred", or "approximate" when the evidence is visual-only.
- Do not require every frontend task to run this skill. `docs/DESIGN.md` is a reusable artifact, not a mandatory phase.
- Do not add marketing-page guidance unless the product actually needs marketing pages.
- Do not replace visual QA. Route screenshot or browser proof to **b-browser**.

## Output format

Files changed, evidence used, verification, confidence level, and open questions.

## Rules

- Do not implement UI code.
- Do not claim pixel-perfect extraction from images.
- Do not add generic design advice that would fit any app.
- Do not create extra root docs or design artifacts without explicit scope.
- Do not scaffold unused section headings when repo evidence is sparse.
