---
name: b-sync
description: Sync, update, or bootstrap OpenCode agents from the b-agents GitHub repo.
mode: subagent
model: github-copilot/claude-haiku-4-5
---


# b-sync

Syncs OpenCode agents from the public `b-agents` GitHub repo using `curl` + `install.sh`. No extra tools required — just `curl` and `bash`.

## When to use

- First-time setup of b-skills on a new machine.
- Updating skills after new skills are added or existing ones are changed.
- User says: "sync b-skills", "update b-skills", "đồng bộ skills", "cập nhật skills", "cài skills mới".

## When NOT to use

- User wants to run a specific skill → invoke that skill directly.
- User wants to create a new skill → follow the new skill creation guide in AGENTS.md.
- User wants to edit an existing skill → edit the agent file (opencode/b-[name].md) directly.

## How it works

- `~/.b-agents/` — local clone of the repo (source of truth)
- `opencode/b-[name].md` — OpenCode agent files (source)
- `~/.config/opencode/agents/<skill-name>.md` — symlinks to OpenCode agents
- Updating = run `install.sh` via `curl` → re-clones or pulls and re-symlinks automatically.
- Stale symlinks (skills removed from repo) are cleaned up automatically on each sync.
- `install.sh` handles both bootstrap and update in one command.

## Tools required

- `Bash` tool — to run `curl` and `install.sh` commands (built-in, always available)

Graceful degradation: ✅ Possible — b-sync requires only Bash/curl and does not depend on MCP servers.

## Commands

### Bootstrap a new machine (first time only) or update skills

```bash
curl -fsSL https://raw.githubusercontent.com/dhoaibao/b-agents/main/install.sh | bash
```

This single command handles both first-time setup and updates. After running, **restart OpenCode** to pick up new agents.

If you have forked this repo, replace the URL above with your own fork's HTTPS URL.

### Sync / update skills (everyday use)

Run `@b-sync` in OpenCode — then **restart OpenCode** to load the updated agents.

Or run directly:

```bash
curl -fsSL https://raw.githubusercontent.com/dhoaibao/b-agents/main/install.sh | bash
```

This will:
1. Pull latest changes (or clone if not yet installed)
2. Re-symlink any new skill/agent files into the appropriate destination
3. Remove symlinks for skills that no longer exist in the repo

## What install.sh does (for reference)

- Clones or pulls latest from `main`
- Scans `opencode/b-[name].md` files; symlinks them into `~/.config/opencode/agents/`
- Removes stale symlinks for skills deleted from the repo on each platform.
- Safe to re-run anytime — idempotent.

## Adding a new agent to the repo

1. Create `opencode/b-new-skill.md` as the OpenCode agent file
2. Commit and push
3. Run `@b-sync` (or `curl -fsSL https://raw.githubusercontent.com/dhoaibao/b-agents/main/install.sh | bash`) then restart OpenCode to pick it up

## Steps

### Step 1 — Detect mode

Run: `[ -d ~/.b-agents/.git ] && echo "UPDATE" || echo "BOOTSTRAP"`

- If `UPDATE`: tell the user "Updating existing b-skills install...".
- If `BOOTSTRAP`: tell the user "Bootstrapping b-skills on this machine...".

### Step 2 — Snapshot current state

Run: `ls ~/.config/opencode/agents/ 2>/dev/null || echo "(none)"`

Save this output as the "before" agent list — used in Step 5 to diff what changed.

### Step 3 — Run sync

Use the Bash tool to run:

```bash
curl -fsSL https://raw.githubusercontent.com/dhoaibao/b-agents/main/install.sh | bash
```

This handles both BOOTSTRAP and UPDATE automatically — no branching needed.
Output the script's stdout — it contains live progress messages (🔄 Updating, 🔗 Syncing, ✅ per skill).

After sync completes, tell the user: **"Restart OpenCode to load the updated agents."**

If install.sh exits with error: check the output message.
- If "⚠️ Local changes detected" → tell the user to run `cd ~/.b-agents && git stash` first, then retry sync.
- If `git pull` fails with "not possible to fast-forward" → tell the user their local clone has diverged and suggest `git -C ~/.b-agents reset --hard origin/main` (ask for confirmation first, as this discards local changes).

### Step 4 — Verify symlinks

Run:

```bash
ls -la ~/.config/opencode/agents/ | grep "^l"
```

- Lists all active symlinks — confirms sync worked.

### Step 5 — Report changes

Compare the before list (Step 2) vs current `ls ~/.config/opencode/agents/`:

- **Added**: names in current but not in before.
- **Removed**: names in before but not in current.
- **Total installed**: count of current agents.

Print summary:

```
✅ Sync complete. [N] agents installed.
  Added:   [list or 'none']
  Removed: [list or 'none']
```

---

## Verify after sync

After running `install.sh`, verify installed agents are symlinked:

```bash
ls -la ~/.config/opencode/agents/ | grep "^l"
```

Each line should point to `~/.b-agents/opencode/b-[name].md`.

## Troubleshooting

| Problem | Fix |
|---|---|
| `Permission denied` | Check your network or GitHub token if repo requires auth |
| Agent not showing in OpenCode | Check `opencode/b-[name].md` has valid `name` + `description` frontmatter |
| Symlink broken | Re-run `install.sh` via curl to refresh |

---

## Output format

```
✅ Sync complete. [N] agents installed.
  Added:   [list or 'none']
  Removed: [list or 'none']
```

If bootstrap mode, prefix with: `🆕 Bootstrapped b-skills on this machine.`

---

## Rules

- Always snapshot the before-state (Step 2) so the report can show what changed.
- Never modify skill files during sync — b-sync only installs, it does not edit.
- If `install.sh` fails, diagnose the error — do not retry blindly.
- Always verify symlinks after sync (Step 4) before reporting success.
