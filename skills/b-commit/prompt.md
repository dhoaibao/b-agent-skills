# b-commit

Create approved, cohesive commits from the current working tree, or draft one message for an existing staged change, without pushing.

## When to use

- The user wants working-tree changes split, staged, and committed on the current branch.
- The user wants a commit message only for one cohesive staged change.
- The user wants PR copy for staged changes and needs a clear next step.

## When NOT to use

- The user wants PR copy for commits -> use **b-pr-summary**.
- The user wants PR copy for staged changes -> commit those changes first, then use **b-pr-summary**.
- The changes cannot be grouped confidently -> use **b-plan**.
- The user wants a review before committing -> use **b-review**.
- In an approved two-role workflow, the reviewed snapshot changed -> return to the worker and **b-review**.

## Tool guidance

- `bash` - `rtk git status --short`, metadata-only Git path lists, targeted safe-path diffs, exact staging, and approved commit creation.

## Two-role workflow

`b-commit` remains worker-owned. In planner mode, an explicit user commit request starts a read-only proposal phase; the planner may inspect and capture state for handoff but never stage, commit, or run a mutating command.

- The planner records the initial index and working-tree snapshot, classifies protected paths, and forms exact ordered commit groups with exact paths and proposed messages. It presents that unchanged proposal in exactly one user approval question, using `ask_user_question` with `Approve (Recommended)` and `Decline` or the focused plain-text fallback when unavailable or noninteractive. It must not ask once per group or regroup after approval.
- After approval, the planner delegates the unchanged proposal to the same worker with the original explicit user request, captured snapshot, exact ordered groups/paths/messages, and approval. The worker remains the sole writer.
- The worker treats the original explicit user request plus the planner-relayed exact approval as satisfying the b-commit request/approval gate. A worker receiving the complete, unchanged planner handoff resumes at step 9 and does not repeat steps 3–8; it still performs the existing snapshot/proposal, protected-path, targeted-staging, and targeted pre-commit diff checks required by steps 9–10. It then stages and commits exactly that proposal without re-proposing or re-asking. If the snapshot or proposal differs, stop and report—not regroup or reuse approval—and do not stage or commit.
- Preserve the protected-path and user-curated pre-existing staged-index rules, targeted staging, no broad staging/history rewrite/push, and the reviewed-snapshot/b-review rules.

## Steps

1. If the user asks for PR copy for staged changes, return `BLOCKED: commit staged changes before generating PR copy` and stop. Do not inspect commit history or stage or commit changes.
2. If the user asks only for a commit message, list staged paths with `rtk git diff --cached --name-only`, then inspect only the targeted staged diff for non-protected paths. Block if it is empty, protected, or mixes unrelated concerns; otherwise apply step 7, output the message, and stop without staging or committing.
3. Using Bash, run `rtk git status --short` and metadata-only path lists for staged and unstaged changes. Classify protected paths before reading any content; inspect untracked files only when their paths are not likely-secret files.
4. Read diffs only for explicit non-protected paths, using `rtk git diff -- <paths>` or `rtk git diff --cached -- <paths>`. Record the initial index and working-tree snapshot. Do not read, stage, or commit likely-secret files without explicit permission.
5. Propose the smallest set of cohesive commit groups. Treat a pre-existing staged set as user-curated: preserve it as one group and do not reset or reorganize it without explicit approval.
6. Block if a group mixes unrelated concerns, a protected file needs permission, or a file cannot be assigned confidently.
7. For each group, choose the narrowest accurate type: `feat`, `fix`, `refactor`, `perf`, `docs`, `test`, `chore`, or `style`; write an imperative subject of at most 50 characters with no trailing punctuation.
8. Present the groups, exact file paths, and proposed commit messages. This is a material user-facing approval: when `ask_user_question` is available in planner or solo/Off work, ask one structured question with `Approve (Recommended)` and `Decline` options, preserving the exact proposal and the extension's custom-answer row. In a two-role worker, keep worker→planner coordination in Intercom and let the planner obtain the user decision. If the questionnaire is unavailable or noninteractive, ask one focused plain-text confirmation in chat. In every case, require explicit approval before staging or committing; stop on a decline or any non-approval.
9. After the user approval (or the exact planner-relayed approval in a two-role worker), verify the snapshot and proposal are unchanged. Stage only the approved paths for each unstaged group; do not use broad staging commands that can capture unrelated files.
10. Reinspect each staged group immediately before committing with a targeted non-protected-path diff. Create its commit on the current branch, then continue to the next approved group. Stop on the first Git error; do not amend, reset, push, or retry by changing history.
11. Report commit hashes, messages, remaining changes, and any blockers. Recommend `b-pr-summary <commit-count>` for PR copy.

## Output format

Before confirmation:

```markdown
Proposed commits:
1. <type>: <subject>
   Files: <paths>

When interactive, choose `Approve (Recommended)` or `Decline` through `ask_user_question`; otherwise reply with explicit approval in chat to stage and create these commits, or decline to stop.
```

For a message-only request:

```markdown
Commit message:
<type>: <subject>
```

After completion:

```markdown
Created commits:
- <short-hash> <type>: <subject>

Remaining changes:
- <paths or None>
```

When blocked, state the specific uncommitted concern without exposing protected file contents. For staged PR-copy requests, output exactly:

```text
BLOCKED: commit staged changes before generating PR copy
```

## Rules

- Preserve unrelated worktree changes and the user-curated index.
- Evidence-only messages; do not invent behavior, verification, or impact.
- Ask before staging or committing; do not push or create a PR.
- After a delegated approval, the same worker may commit only on explicit user request and only if the reviewed snapshot is unchanged; any content change reopens **b-review**.
- Never use `git add -A`, `git add .`, `git commit --amend`, reset, or history-rewriting commands.
