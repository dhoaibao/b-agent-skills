---
name: b-sync
description: Sync, update, or bootstrap Claude skills from the b-agent-skills GitHub repo. Use this skill whenever the user says "sync b-skills", "update b-skills", "install b-skills on new machine", "pull latest b-skills", or anything related to keeping ~/.claude/skills up to date from the b-agent-skills repository.
---

# b-sync

Syncs Claude skills from the public `b-agent-skills` GitHub repo to `~/.claude/skills/` using git + HTTPS. No extra tools required — just `git`.

## How it works

- `~/.b-agent-skills/` — local clone of the repo (source of truth)
- `~/.claude/skills/<skill-name>` — symlinks pointing into the clone
- Updating = `git pull` → symlinks stay valid automatically
- Stale symlinks (skills removed from repo) are cleaned up automatically on each sync

## Tools required

- `Bash` tool — to run `git` and `sync.sh` commands (built-in, always available)

Graceful degradation: ✅ Not applicable — b-sync requires only Bash/git, no MCP server needed.

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
2. Re-symlink any new skill folders into `~/.claude/skills/`
3. Remove symlinks for skills that no longer exist in the repo

## What sync.sh does (for reference)

- Pulls latest from `main`
- Scans all root-level folders in the repo
- Symlinks folders that contain a `SKILL.md` into `~/.claude/skills/`
- Removes stale symlinks for skills deleted from the repo
- Skips anything without a `SKILL.md` (e.g. `sync.sh` itself, `README.md`)
- Safe to re-run anytime — idempotent

## Adding a new skill to the repo

1. Create a folder at the root of `b-agent-skills/`: `mkdir my-skill`
2. Add `my-skill/SKILL.md` with proper frontmatter
3. Commit and push
4. Run `~/.b-agent-skills/sync.sh` on any machine to pick it up

## Steps

### Step 1 — Detect mode

Run: `[ -d ~/.b-agent-skills/.git ] && echo "UPDATE" || echo "BOOTSTRAP"`

- If `UPDATE`: tell the user "Updating existing b-skills install..."
- If `BOOTSTRAP`: tell the user "Bootstrapping b-skills on this machine..."

### Step 2 — Snapshot current state

Run: `ls ~/.claude/skills/ 2>/dev/null || echo "(none)"`

Save this output as the "before" skill list — used in Step 5 to diff what changed.

### Step 3 — Run sync

Use the Bash tool to run the appropriate command based on Step 1:

- **BOOTSTRAP**: `git clone https://github.com/dhoaibao/b-agent-skills.git ~/.b-agent-skills && bash ~/.b-agent-skills/sync.sh`
- **UPDATE**: `bash ~/.b-agent-skills/sync.sh`

Output the script's stdout — it contains live progress messages (🔄 Updating, 🔗 Syncing, ✅ per skill).

### Step 4 — Verify symlinks

Run both checks:

```bash
ls -la ~/.claude/skills/ | grep "^l"
grep -rL 'name:' ~/.claude/skills/*/SKILL.md 2>/dev/null
```

- First command lists all active symlinks — confirms sync worked
- Second command flags any skills missing required `name:` frontmatter
- If any skill is flagged → tell the user which skill has broken frontmatter

### Step 5 — Report changes

Compare the before list (Step 2) vs current `ls ~/.claude/skills/`:

- **Added**: names in current but not in before
- **Removed**: names in before but not in current
- **Total installed**: count of current skills

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