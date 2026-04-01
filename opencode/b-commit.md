---
name: b-commit
description: Generate commit message and PR description text — nothing more. Use when user says "commit", "tạo commit", "viết commit message", "PR description", or after b-review passes.
mode: subagent
model: github-copilot/claude-haiku-4-5
---


# b-commit

$ARGUMENTS

Read the git diff, understand the change, and produce a ready-to-use commit message
and PR description. Does not stage, commit, push, or create a PR — outputs text only.

If `$ARGUMENTS` is provided, treat it as the commit scope or intent
(e.g. `add retry logic to email queue`) — use it to inform the commit message subject.

## When to use

- After b-gate passes and b-review gives READY FOR PR.
- User says "commit", "viết commit message", "tạo commit", "PR description", "tạo PR".
- Finalizing a b-plan execution session.

## When NOT to use

- b-gate has not passed yet → run **b-gate** first.
- b-review has not passed yet → run **b-review** first.

## Tools required

- `Bash` — to read `git diff` and `git log`

No MCP required.

Graceful degradation: ✅ Possible — requires only Bash and git installed.

## Steps

### Step 1 — Read the diff

Run:
```bash
git diff HEAD
git diff --stat HEAD
```

If the output is empty:
1. Try `git diff --staged` (changes staged but not yet committed).
2. If still empty: try `git diff HEAD~1 HEAD` (the most recent commit).
3. If still empty: ask the user — "No uncommitted, staged, or recent changes found. Which changes should I write a commit message for? (Provide a commit hash, branch name, or describe the change.)" Do not proceed with an empty diff.

Understand:
- **What behavior changed** — not just which lines, but what the code now does differently.
- **Why this change was made** — from plan file (`.opencode/b-plans/`) or conversation context.
- **Atomicity** — is this one logical unit, or mixed concerns?

If the diff mixes unrelated changes (e.g. feature + unrelated refactor + formatting fix): **stop and do not produce a single unified commit message**. Instead:
1. List the detected concern groups (e.g. "Group 1: retry logic in queue.ts; Group 2: formatting fixes in utils.ts").
2. Output 2 separate commit message suggestions, one per concern group.
3. Explain: "If this is intentional, use one of the suggestions above. To split: `git add -p` to stage each concern separately, then commit twice."
Do not proceed to Step 2 for a unified message when mixed concerns are detected.

---

### Step 2 — Write commit message

**Format:**
```
<type>(<scope>): <subject>

<body — optional>
```

**Subject line:**
- Imperative mood: "add", "fix", "remove", "update" — not "added", "fixes".
- ≤72 characters.
- No period at end.
- Behavior-level description, not file-level ("add retry logic" not "update queue.ts")

**Types:**
| Type | When |
|---|---|
| `feat` | New behavior added |
| `fix` | Bug fixed |
| `refactor` | Behavior unchanged, structure improved |
| `test` | Tests only |
| `docs` | Documentation only |
| `chore` | Build, config, dependencies |
| `perf` | Performance improvement |

**Body** — include when:
- The *why* is not obvious from the subject.
- A non-trivial design decision was made.
- The fix addresses a subtle root cause worth preserving in history.

Body explains *why*, not *what* — the diff already shows what.

---

### Step 3 — Write PR description

```markdown
## Summary
- [What this PR does — 2-3 bullets]

## Why
[The problem this solves or requirement it fulfills]

## Changes
- [Key file or area]: [what changed and why]

## Test plan
- [ ] [How to verify the change works]
- [ ] [Edge case to check manually if needed]

## Notes *(optional)*
[Trade-offs, follow-ups, or things reviewers should pay attention to]
```

---

## Output format

```
### b-commit

**Commit message:**
\`\`\`
<type>(<scope>): <subject>

<body if present>
\`\`\`

---

**PR description:**
\`\`\`markdown
## Summary
...
\`\`\`

---
⚠️ Mixed concerns detected — producing 2 separate suggestions:

**Concern Group 1**: [description of first group]
**Commit message 1:**
\`\`\`
<type>(<scope>): <subject>
\`\`\`

**Concern Group 2**: [description of second group]
**Commit message 2:**
\`\`\`
<type>(<scope>): <subject>
\`\`\`

If this is intentional, use one of the suggestions above.
To split: `git add -p` to stage each concern separately, then commit twice.
(omit this section if diff is atomic)
```

---

## Rules

- Output text only — never execute git commands, never stage, never push, never create PR.
- Body is for *why*, not *what*
- If diff is unreadable (too large or binary), ask the user to describe the change instead.
- If plan file exists, use it as the primary source for *why* — do not invent reasons.
- On mixed-concern diffs: stop, list concern groups, output 2 separate commit message suggestions, and explain how to split with `git add -p`. Do not produce a single unified message for a mixed diff.
