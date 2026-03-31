---
name: b-execute-plan
description: >
  Orchestrates the full development pipeline (b-tdd → b-gate → b-review → b-commit) by reading plan files, tracking step completion, and prompting for each stage. ALWAYS use for: "execute plan", "chạy plan", "thực thi kế hoạch", "run plan", "guided pipeline". Differs from b-plan (which creates plans) and individual skills (which run isolated stages).
---

# b-execute-plan

Reads `.claude/b-plans/*.md` files, parses step state, and guides users through the production development pipeline with explicit checkpoints and state tracking.

## When to use
- User says "execute plan" or provides a plan file path
- Running b-tdd → b-gate → b-review → b-commit pipeline with guided orchestration
- Need step-by-step state management and checkpoint verification
- Want one skill to drive the full pipeline rather than invoking each skill manually

## When NOT to use *(optional but recommended)*
- User wants to create a plan (use `b-plan` instead)
- Running a single skill in isolation (use `b-tdd`, `b-gate`, etc. directly)
- Plan file is malformed or in non-standard format (manually fix plan first)

## Tools required
- `Glob` — discover `.claude/b-plans/*.md` files
- `Read` — load and parse plan file content
- `Edit` — update checkbox state as steps complete (e.g., `- [ ]` → `- [x]`)
- `Skill` — invoke downstream skills (b-tdd, b-gate, b-review, b-commit, b-analyze) via `/` commands
- `Bash` — run `git diff HEAD --stat` for rollback detection and NEEDS FIXES verification

If `b-analyze` skill is unavailable: skip Step 0 entirely and note: "⚠️ b-analyze not available — skipping pre-execution analysis. Ensure you understand the existing code structure before proceeding."
If `Skill` tool is unavailable: prompt user to run each skill manually; checkpoint tracking still works via Read/Edit.

Graceful degradation: ✅ Possible — core pipeline (Read/Edit/Skill) always works. b-analyze Step 0 and git-diff checks degrade gracefully if tools are absent.

## Steps

### Step 0 — Pre-execution analysis *(conditional)*

Run if: the plan modifies existing code AND no `## Context` section exists in the plan file.
Skip if: the plan is greenfield (no existing modules are changed) OR a `## Context` section is already present.

**Determine scope before invoking b-analyze — never run unconstrained:**
1. Scan the plan's `## Steps` section for explicit file paths (patterns: `src/`, `path/to/file.ts`, directory names like `services/`, module names in backticks).
2. If explicit paths found → invoke b-analyze scoped to exactly those files/directories.
3. If no explicit paths → parse the plan's **Scope** statement for module or layer names (e.g., "auth module", "notification service") and scope to those directories.
4. If scope is still ambiguous after steps 1–3 → ask: "Which module or directory should I analyze before starting? (e.g., `src/services/`, `src/api/`)" — do not run a full-repo analysis.

Append b-analyze output as a `## Context` section to the plan file using `Edit`.

### Step 1 — Locate and load plan file
Detect plan file from:
1. Argument passed by user (e.g., `/b-execute-plan path/to/plan.md`)
2. If no argument: use `Glob` to discover all `.claude/b-plans/*.md` files.
   - If exactly one file exists → use it automatically.
   - If multiple files exist → list all files with their last-modified timestamps and ask: "Which plan should I execute? (Reply with the filename or number.)" Do not auto-select silently.
3. If no files found in `.claude/b-plans/` → ask the user to provide the plan file path.

Use `Read` to load the selected plan file content.

**Session resume**: if the plan file already has completed steps (`[x]`), b-execute-plan automatically resumes from the first pending (`[ ]`) step — no manual state restoration needed. Re-invoke with the same file path to continue.

**Context window warning**: after loading the plan, count total pending (`[ ]`) steps. If pending steps > 6, warn once:
> "⚠️ This plan has N pending steps. To prevent context overflow mid-execution, consider running steps 1–5 in this session, then opening a fresh session for the remainder. Resume anytime with: `execute plan from .claude/b-plans/[file].md`"

**Session step counter (file-based, context-safe)**: at Step 1 load time, count the existing `[x]` checkboxes in the plan file — store this as `baseline_completed`. After each Step 5 check-off, re-read the file and count total `[x]` checkboxes again. `session_steps = current_completed − baseline_completed`. When `session_steps` reaches 5, remind:
> "5 steps completed this session. If context feels heavy, open a fresh session and re-invoke with the same plan file to continue."

This counter is derived from the file on every loop — it survives context compression.

### Step 2 — Parse plan structure and extract step checkboxes
Extract all lines matching either checkbox pattern used by b-plan:
- `- [ ] N. [description]` or `- [x] N. [description]` (numbered dot format, e.g. `- [ ] 1. Create SKILL.md`)
- `- [ ] Step N — [description]` or `- [x] Step N — [description]` (labeled format)
- `- [❌] N. [description]` or `- [❌] Step N — [description]` (failed state — step attempted but did not complete)

Build an in-memory state map: `{step_number: {description, status: "pending" | "completed" | "failed"}}`.
Identify which steps are pending, completed, or failed.

### Step 3 — Display current state and next action
Show user:
- Plan title and summary
- List of completed steps (with ✓ marks)
- List of failed steps (with ❌ marks) — show these prominently above pending steps
- List of pending steps (with ○ marks)
- Next step to run (if any)

**Skill routing** — match keywords in the next step's description. **Check rows top-to-bottom and stop at the first match** — earlier rows take precedence:

| Priority | Keyword(s) | Suggested skill | Examples |
|---|---|---|---|
| 1 (first) | "delete", "remove", "config", "migrate", "migration", "document", "update docs", "rename", "move" | No skill — non-production step. Instruct user to perform manually, then signal `done`. Check off directly. | "create migration file", "remove deprecated route", "rename auth module", "update README" |
| 2 | "test", "validate", "quality", "lint", "check quality" | `/b-gate` | "validate quality before PR", "run lint and tests" |
| 3 | "review", "verify logic", "requirements coverage" | `/b-review` | "review implementation", "verify logic correctness" |
| 4 | "commit", "PR description", "push" | `/b-commit` | "commit and push", "write PR description" |
| 5 (last) | "implement", "write", "code", "add", "create", "refactor", "build", "extend" | `/b-tdd` | "implement retry logic", "add user service", "create auth middleware", "write notification handler" |
| — | (no keyword match) | Ask: "Which skill for this step? (b-tdd / b-gate / b-review / b-commit / manual)" | — |

**Priority 1 is checked first** — "create migration file" matches Priority 1 via "migration", not Priority 5 via "create". Similarly, "create config" matches Priority 1 via "config". Only "create auth middleware" (no Priority 1 keyword) falls through to Priority 5.

**Invocation format varies by skill** — each skill has different $ARGUMENTS expectations. Use the correct format per skill or you will silently break downstream behavior:

| Skill | Invocation format | Reason |
|---|---|---|
| `/b-tdd` | `[plan-file]:[N]` | Must run exactly step N, not auto-detect next pending |
| `/b-gate` | no args (or `src/ path/` to scope) | Runs on working tree; plan file irrelevant |
| `/b-review` | `[plan-file]` (no step number) | Needs requirements baseline from plan; step number meaningless |
| `/b-commit` | no args | Reads `git diff HEAD` directly; plan context not needed |

Show detected skill and ask for confirmation:
```
→ Next: Step N — [description]
Detected skill: /b-[skill] (keyword match: '[keyword]'). Confirm? [y/n]
Run `/b-tdd .claude/b-plans/[plan-filename].md:N`   ← for b-tdd
Run `/b-gate`                                         ← for b-gate
Run `/b-review .claude/b-plans/[plan-filename].md`   ← for b-review
Run `/b-commit`                                       ← for b-commit
```

**Dependency blocking** — before routing, check the plan's `## Dependencies` section for sequential dependency declarations (e.g., "Step N requires Step M to be complete"). If a prerequisite step M is `[❌]`:
```
⛔ Step N depends on Step M which failed ([❌] reason).
   Resolve Step M before continuing, or type `override` to bypass this check.
```
Do not auto-proceed past a blocking failed dependency.

**Parallel step detection** — after identifying next pending step N, check `## Dependencies` for "Steps N and M can run in parallel." If found, step M is also pending, **and both steps route to b-tdd** (implementation steps only — never offer parallel for b-gate, b-review, or b-commit):
```
⚡ Steps N and M are declared independent implementation steps. Run in parallel?
  y = invoke both simultaneously (requires Agent tool — faster)
  n = run sequentially
```
- If parallel confirmed: invoke both as `/b-tdd [file.md]:[N]` and `/b-tdd [file.md]:[M]` in a single message. Wait for both to complete before Step 5.
- If one fails and one succeeds: mark the failed step `[❌]`, mark succeeded `[x]`, surface failure before continuing.
- If Agent tool unavailable or user declines: proceed sequentially.

**Failed step handling** — if the next step has status `failed`:
```
⚠️ Step N previously failed: [brief reason from ❌ marker]. Retry or skip?
- Retry: run `/b-[skill] .claude/b-plans/[plan-filename].md:N`
- Skip: type `skip` to leave the step as-is and advance to the next pending step
```

### Step 4 — Wait for user signal
Pause and wait for the user to reply. Accept any of these signals as "step complete":
- User replies `done`, `next`, `continue`, or equivalent
- User explicitly invokes the next skill in the pipeline

Do not advance automatically. When the user signals completion, proceed to Step 5.

**Failure handling**: if the user signals failure (e.g., "failed", "it didn't work", "error"), before halting:
1. Ask the user for a brief reason (one sentence).
2. Use `Edit` to write `- [❌] N — [brief reason from user]` in the plan file, replacing the `- [ ]` line for the current step.
3. Check if the step was partially implemented (files modified but step not complete): run `git diff HEAD --stat`. If output shows modified files, present the rollback option:
   > "Step N left uncommitted changes. Roll back to a clean state before retrying? (`git checkout -- .` resets all modified tracked files to last commit.)"
   - If user confirms rollback: instruct them to run `git checkout -- .`, then confirm the repo is clean before retrying.
   - If user declines: note the partial state explicitly — "Proceeding with current modified state. Ensure the next retry accounts for existing partial changes."
4. Surface the failure prominently and halt until the user resolves it or requests a skip.

### Step 5 — Update plan state
Once step completes, use `Edit` to update the corresponding checkbox: `- [ ]` → `- [x]`. Re-read the file after editing to recompute the session step counter (see Step 1).

### Step 6 — Loop or finish
Check if all steps in the production pipeline (b-tdd, b-gate, b-review, b-commit) are complete or skipped.
If done: Show summary, congratulate user, exit. Note any failed/skipped steps in the summary.
If pending: Increment to next step and return to Step 3.
If remaining steps are all `failed` with no pending steps: surface the blocked state to the user — do not loop indefinitely.

**NEEDS FIXES re-entry path**: if b-review returns a NEEDS FIXES verdict and the user subsequently signals code was changed:
1. Do NOT reset automatically on the first NEEDS FIXES signal — wait for user to signal a code fix.
2. After user signals a fix: run `git diff HEAD --stat` to verify actual file changes exist.
   - If output is empty: do NOT reset b-gate. Inform the user: "No code changes detected (`git diff` is empty). Please modify and save the relevant files before re-entering b-gate."
   - If output shows modified files: proceed to step 3.
3. Ask: **"Did this fix add new behavior, or was it cosmetic (null check, rename, guard clause, typo)?"**
   - **Cosmetic fix** → reset b-gate `[x]` to `[ ]`, re-route to `/b-gate`. Iron Law does not apply — no new behavior was added.
   - **New behavior** → route to `/b-tdd [plan-file]:[N]` for the affected implementation step first. Iron Law applies — the new behavior needs a failing test before production code. After b-tdd completes, reset b-gate `[x]` to `[ ]` and proceed through b-gate → b-review again.
4. Return to Step 3 with the correct routing from step 3 above.

This prevents both ghost resets (git diff required) and Iron Law bypasses (new behavior must go through b-tdd).

---

## Output format

```
📋 Plan: Implement b-execute-plan
Status: 3 of 6 steps complete ✓

✓ Step 1 — Create b-execute-plan/SKILL.md with skill definition
✓ Step 2 — Design skill workflow in SKILL.md Steps section
✓ Step 3 — Define Tools required and Graceful degradation
○ Step 4 — Write Output format and Rules sections
○ Step 5 — Update README.md to document b-execute-plan
○ Step 6 — Update REFERENCE.md with b-execute-plan reference section

→ Next: Step 4 — Write Output format and Rules sections
Detected skill: /b-tdd (keyword match: 'write'). Confirm? [y/n]
Run `/b-tdd .claude/b-plans/implement-b-execute-plan.md:4` to proceed, or type a different skill to override.
```

---

## Rules
- **Only update plan with user approval**: Never auto-commit plan changes without explicit user signal (e.g., "done", "next").
- **Warn on skipped steps**: If user requests jumping to a later step, warn that earlier steps will be marked incomplete and require explicit approval.
- **Preserve plan file integrity**: Always validate checkbox syntax before editing; skip malformed lines and log a warning.
- **Stop on missing skill**: If a downstream skill is unavailable (not installed, `/skill` fails), prompt user to install it and pause orchestration.
- **Read before write**: Always re-read plan file before editing to avoid lost updates if user manually modifies it.
- **Invocation format is skill-specific**: b-tdd gets `[plan-file]:[N]`; b-review gets `[plan-file]` (no step); b-gate and b-commit get no plan args. Never pass `[plan-file]:[N]` to b-gate or b-commit — they don't parse it and it will break their $ARGUMENTS handling.
- **Rollback on partial failure**: if a step fails after modifying files, always check `git diff HEAD --stat` and offer `git checkout -- .` before the user retries. Never leave the repo in an undocumented partial state.
- **NEEDS FIXES requires git evidence**: reset b-gate checkpoint only after `git diff HEAD --stat` confirms actual file changes — never on natural-language signal alone.
- **Pipeline scope**: Orchestrate Step 0 (b-analyze, conditional) → b-tdd → b-gate → b-review → b-commit. b-plan is out of scope (use b-plan to create plans; use b-execute-plan to run them).
