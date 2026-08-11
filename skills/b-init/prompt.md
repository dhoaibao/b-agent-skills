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
- `serena` - inspect exact symbols or references only when they materially improve
  precision about file ownership or code layout; use native `read` first and
  serialize requests rather than parallelizing or batching them.

## Steps

1. Confirm scope: repository root or a specific subtree, and whether the task is create, refresh, or reconcile.
2. Run `rtk git status --short` via Bash before inspecting or changing the repository; preserve unrelated changes.
3. Inspect only the repo evidence needed to avoid boilerplate: existing docs, manifests, validation scripts, top-level directories, and source-of-truth files. Use native `read` first; use Serena only for exact ownership symbols or references when they materially improve the codebase-map evidence. Do not use it for routine reads or parallelize/batch its requests.
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
6. If the target file contains these markers, update only the managed block with edit/write. Preserve user-owned notes above or below it. If it contains substantial unmarked content, ask before replacing it wholesale.
7. Write concise `AGENTS.md` sections grounded in repo evidence:
   - Repository purpose: one short paragraph on what the repo ships or maintains.
   - Working rules: local conventions, edit boundaries, and approval expectations.
   - Verification commands: only list commands that exist in the repo.
   - Codebase map: top-level directories or packages that matter for navigation.
   - Safety rules: constraints on migrations, secrets, or generated-vs-source invariants.
   - Maintainer guide: edit guidelines (e.g. sync scripts) when the repo has generated files.
   - Source-of-truth files: registries, templates, or docs that own generated outputs.
8. Avoid runtime-home paths, agent-vendor policy dumps, speculative architecture summaries, and extra root docs.
9. Verify that referenced paths and commands exist (using Bash to run checks), then inspect the diff for noise or invented detail.

## Output format

Files changed, repo evidence used, verification, and any TODOs left intentionally unresolved.

## Rules

- Keep `AGENTS.md` primary and `CLAUDE.md` minimal.
- Prefer repo facts over generic policy text.
- Use explicit TODOs instead of guessing commands, owners, or workflows.
- Preserve user-owned content outside managed blocks.
- Keep the docs slim; do not turn initialization into a governance dump.
