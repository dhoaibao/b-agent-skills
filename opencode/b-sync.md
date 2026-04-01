---
name: b-sync
description: Sync, update, or bootstrap Claude skills from the b-agent-skills GitHub repo.
mode: subagent
model: github-copilot/claude-haiku-4-5
---

## Tool Mapping (read before following instructions below)

When instructions reference these Claude Code tools, use the OpenCode equivalent:

| Claude Code | OpenCode equivalent |
|---|---|
| `Read` / `Glob` / `Grep` | Read files natively |
| `Edit` / `Write` | Edit files natively |
| `Bash` | Run bash commands natively |
| `Skill tool` → `/b-[name]` | Invoke `@b-[name]` subagent |
| `Agent tool` | Spawn subagent via task tool |
| `TaskCreate` / `TaskUpdate` | Skip — plan file manages state |

---


# b-sync

Syncs Claude Code skills and/or OpenCode agents from the public `b-agent-skills` GitHub repo using git + HTTPS. No extra tools required — just `git`.

## When to use

- First-time setup of b-skills on a new machine.
- Updating skills after new skills are added or existing ones are changed.
- User says: "sync b-skills", "update b-skills", "đồng bộ skills", "cập nhật skills", "cài skills mới".

## When NOT to use

- User wants to run a specific skill → invoke that skill directly.
- User wants to create a new skill → follow the new skill creation guide in CLAUDE.md.
- User wants to edit an existing skill → edit the SKILL.md file directly.

## How it works

- `~/.b-agent-skills/` — local clone of the repo (source of truth)
- `claude/b-[name]/SKILL.md` — Claude Code skill files (source)
- `opencode/b-[name].md` — OpenCode agent files (source)
- `~/.claude/skills/<skill-name>` — symlinks to Claude Code skills
- `~/.config/opencode/agents/<skill-name>.md` — symlinks to OpenCode agents
- Updating = `git pull` → symlinks stay valid automatically.
- Stale symlinks (skills removed from repo) are cleaned up automatically on each sync.
- `sync.sh` prompts which platform to sync: Claude Code, OpenCode, or both.

## Tools required

- `Bash` tool — to run `git` and `sync.sh` commands (built-in, always available)

Graceful degradation: ✅ Possible — b-sync requires only Bash/git and does not depend on MCP servers.

## Commands

### Bootstrap a new machine (first time only)

```bash
git clone https://github.com/dhoaibao/b-agent-skills.git ~/.b-agent-skills && bash ~/.b-agent-skills/sync.sh
```

If you have forked this repo, replace the URL above with your own fork's HTTPS URL.

### Sync / update skills (everyday use)

```bash
bash ~/.b-agent-skills/sync.sh
```

This will:
1. `git pull` the latest changes from the repo
2. Prompt which platform to sync (Claude Code / OpenCode / both)
3. Re-symlink any new skill/agent files into the appropriate destination
4. Remove symlinks for skills that no longer exist in the repo

## What sync.sh does (for reference)

- Pulls latest from `main`
- Asks: sync Claude Code, OpenCode, or both?
- **Claude Code**: scans `claude/b-[name]/` folders; symlinks those with `SKILL.md` into `~/.claude/skills/`
- **OpenCode**: scans `opencode/b-[name].md` files; symlinks them into `~/.config/opencode/agents/`
- Removes stale symlinks for skills deleted from the repo on each platform.
- Safe to re-run anytime — idempotent.

## Adding a new skill to the repo

1. Create `claude/b-new-skill/SKILL.md` with proper frontmatter
2. Create `opencode/b-new-skill.md` as the paired OpenCode agent file
3. Commit and push
4. Run `~/.b-agent-skills/sync.sh` on any machine to pick it up

## Steps

### Step 1 — Detect mode

Run: `[ -d ~/.b-agent-skills/.git ] && echo "UPDATE" || echo "BOOTSTRAP"`

- If `UPDATE`: tell the user "Updating existing b-skills install...".
- If `BOOTSTRAP`: tell the user "Bootstrapping b-skills on this machine...".

### Step 2 — Snapshot current state

Run: `ls ~/.claude/skills/ 2>/dev/null || echo "(none)"`

Save this output as the "before" skill list — used in Step 5 to diff what changed.

### Step 3 — Run sync

Use the Bash tool to run the appropriate command based on Step 1:

- **BOOTSTRAP**: `git clone https://github.com/dhoaibao/b-agent-skills.git ~/.b-agent-skills && bash ~/.b-agent-skills/sync.sh`
- **UPDATE**: `bash ~/.b-agent-skills/sync.sh`

The script will prompt for platform selection (1=Claude Code, 2=OpenCode, 3=Both). Default is Both.
Output the script's stdout — it contains live progress messages (🔄 Updating, 🔗 Syncing, ✅ per skill).

If sync.sh exits with error: check the output message.
- If "⚠️ Local changes detected" → tell the user to run `cd ~/.b-agent-skills && git stash` first, then retry sync.
- If `git pull` fails with "not possible to fast-forward" → tell the user their local clone has diverged and suggest `git -C ~/.b-agent-skills reset --hard origin/main` (ask for confirmation first, as this discards local changes).

### Step 4 — Verify symlinks

Run both checks:

```bash
ls -la ~/.claude/skills/ | grep "^l"
grep -rL 'name:' ~/.claude/skills/*/SKILL.md 2>/dev/null
```

- First command lists all active symlinks — confirms sync worked.
- Second command flags any skills missing required `name:` frontmatter.
- If any skill is flagged → tell the user which skill has broken frontmatter.

### Step 5 — Report changes

Compare the before list (Step 2) vs current `ls ~/.claude/skills/`:

- **Added**: names in current but not in before.
- **Removed**: names in before but not in current.
- **Total installed**: count of current skills.

Print summary:

```
✅ Sync complete. [N] skills installed.
  Added:   [list or 'none']
  Removed: [list or 'none']
```

---

## Verify after sync

After running `sync.sh`, verify installed skills are valid:

```bash
grep -rL 'name:' ~/.claude/skills/*/SKILL.md 2>/dev/null
```

Any file printed by this command is missing the `name:` frontmatter field — check and fix that skill's SKILL.md before using it.

## Troubleshooting

| Problem | Fix |
|---|---|
| `Permission denied` | Check your network or GitHub token if repo requires auth |
| Skill not showing in Claude Code | Check folder has `SKILL.md` with valid `name` + `description` frontmatter |
| Symlink broken | Re-run `sync.sh` to refresh |

---

## Output format

```
✅ Sync complete. [N] skills installed.
  Added:   [list or 'none']
  Removed: [list or 'none']
```

If bootstrap mode, prefix with: `🆕 Bootstrapped b-skills on this machine.`

---

## Rules

- Always snapshot the before-state (Step 2) so the report can show what changed.
- Never modify skill files during sync — b-sync only installs, it does not edit.
- If `sync.sh` fails, diagnose the error — do not retry blindly.
- Always verify symlinks after sync (Step 4) before reporting success.
