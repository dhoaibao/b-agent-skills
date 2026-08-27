# b-init

Initialize or refresh repo-local agent instruction docs. `AGENTS.md` is canonical. `CLAUDE.md` is a thin redirect shim.

## When to use

- The user wants a project-level `/init` equivalent for agent guidance.
- `AGENTS.md` or `CLAUDE.md` is missing, stale, or inconsistent.
- A repo needs a concise maintainer guide grounded in its actual structure.

## When NOT to use

- The task is runtime-home installation or adapter config -> use repo docs or installer flow.
- The user wants a broader plan before writing docs -> use **b-plan**.
- The user wants code or product behavior changes -> use **b-implement**.

## Tool guidance

- `bash` - repo layout via `eza` and `fdfind`, commands, and `rtk git` diffs/status.
- `read`/`edit`/`write` - create or refresh `AGENTS.md` / `CLAUDE.md`.
- `serena` - after native search/read, inspect a specific exact symbol or
  reference only when it materially improves precision about file ownership or
  code layout; use native `read` first and serialize requests rather than
  parallelizing or batching them.

## Steps

1. Confirm scope: repository root or a specific subtree, and whether the task is create, refresh, or reconcile.
2. Run `rtk git status --short` via Bash before inspecting or changing the repository; preserve unrelated changes.
3. Before drafting, first inventory only the repo evidence needed to avoid boilerplate: language/package manifests and lockfiles; lint, format, type, test, and CI configuration or scripts (recording only commands that exist); local canonical docs; and observable technical risk surfaces such as request/input/auth boundaries, persistence/migrations, rendering/templates/HTML, external integrations, and infrastructure/deployment. Treat absent evidence as absence rather than inferring a stack or surface. Use native `read` first; use Serena only after native search/read for a specific exact ownership symbol or reference when it materially improves precision about file ownership or code layout. Do not use it for routine reads or parallelize/batch its requests.
4. Prefer `AGENTS.md` as the only authoritative instruction file. Keep `CLAUDE.md` short and route the reader to `AGENTS.md` using the exact shim pattern:
   ```markdown
   # Claude Code Instructions

   Read `./AGENTS.md` first. It is the source of truth for this repository's agent instructions and maintainer guidance.
   ```
5. Wrap the generated content in managed markers so later refreshes can update only the managed section:
   ```markdown
   <!-- b-init-managed:start -->
   ...
   <!-- b-init-managed:end -->
   ```
6. If the target file contains these markers, update only the managed block with edit/write. Preserve user-owned notes above or below it. If it contains substantial unmarked content, treat replacement as a material user-facing choice: in planner or solo/Off work use `ask_user_question` with 2–4 concrete options such as preserve the unmarked content (`Preserve (Recommended)`), replace it wholesale, or stop; if unavailable or noninteractive, ask one focused plain-text question. In a two-role worker, ask the assigning planner through Intercom instead. Planner mode emits exactly one `B_AGENTIC_USER_INPUT_NEEDED` signal for the decision; solo/Off workers emit no planner signal.
7. Write a concise managed `AGENTS.md` block with exactly these four top-level sections, in this order:
   - `## Repository Purpose`: one short paragraph on what the repo ships or maintains.
   - `## Project Profile`: retain evidence-backed conventions and non-structural scope gaps. Distinguish enforced local conventions (backed by config, docs, or scripts) from contextual secure-coding practices (scope-conditional advice, not claims of enforcement). Every project-specific bullet names its applicable scope and `Evidence:` source. Use established, narrowly relevant language or area practices only for detected stacks and surfaces; do not fabricate commands, owners, policies, or security coverage; do not repeat verification commands in the profile.
   - `## Project Map and Ownership`: is the sole owner of navigation, canonical-source/generated-output ownership, and local edit boundaries, so each fact appears once. Identify the top-level directories or packages that matter, the registries/templates/docs that own generated outputs, and where edits belong. Under its local edit-boundaries guidance, keep durable guidance current: when a change makes a recorded project fact stale or introduces a durable project purpose, convention, boundary, ownership rule, map entry, or verification command, update the relevant `AGENTS.md` fact in the same change; otherwise leave it unchanged. Do not update `AGENTS.md` for unrelated code edits.
   - `## Verification`: list each existing repository command once. Record only focused TODOs/gaps when an applicable command is absent; do not invent replacement commands.
   Do not use headings named `Working Rules`, `Safety Rules`, `Maintainer Guide`, `Sources and Generated Assets`, or `Codebase Map` at any Markdown heading depth; fold supported facts into the four required sections instead. Descriptive nested headings are allowed when they organize content without creating duplicate fact buckets.
8. If evidence is insufficient, write a bounded profile and focused TODO/gap instead of inventing standards. The always-loaded kernel owns generic workflow, tool, and secret policy; do not restate, weaken, or replace it in `AGENTS.md`.
9. Avoid runtime-home paths, agent-vendor policy dumps, speculative architecture summaries, and extra root docs.
10. Verify that referenced paths and commands exist (using Bash to run checks), then inspect the diff for noise or invented detail.

## Output format

Files changed, repo evidence used, verification, and any TODOs left intentionally unresolved.

## Rules

- Keep `AGENTS.md` primary and `CLAUDE.md` minimal.
- Prefer repo facts over generic policy text.
- Use explicit TODOs instead of guessing commands, owners, or workflows.
- Preserve user-owned content outside managed blocks.
- Keep the docs slim; do not turn initialization into a governance dump.
