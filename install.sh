#!/usr/bin/env bash
# install.sh — Bootstrap or update b-skills on any machine
# Usage:
#   First time : curl -fsSL https://raw.githubusercontent.com/dhoaibao/b-skills/main/install.sh | bash
#   Update     : curl -fsSL https://raw.githubusercontent.com/dhoaibao/b-skills/main/install.sh | bash

set -euo pipefail

REPO="https://github.com/dhoaibao/b-skills.git"
LOCAL_REPO="$HOME/.b-skills"
SKILLS_SRC="$LOCAL_REPO/skills"
CLAUDE_SKILLS_DST="$HOME/.claude/skills"
CLAUDE_GLOBAL_SRC="$LOCAL_REPO/skills/global/CLAUDE.md"
CLAUDE_GLOBAL_DST="$HOME/.claude/CLAUDE.md"

_prompt_yes_no() {
  local prompt="$1"
  local reply

  read -rp "$prompt" reply </dev/tty
  printf '%s' "${reply:-N}"
}

_sync_directory() {
  local source_dir="$1"
  local target_dir="$2"

  rm -rf "$target_dir"
  mkdir -p "$target_dir"
  cp -a "$source_dir"/. "$target_dir"/
}

_merge_settings_json() {
  local merge_payload="$1"
  local merge_kind="$2"
  local config_file="$HOME/.claude/settings.json"
  mkdir -p "$(dirname "$config_file")"

  local existing
  existing=$(cat "$config_file" 2>/dev/null || echo "{}")

  local merged
  if ! merged=$(MERGE_PAYLOAD="$merge_payload" MERGE_KIND="$merge_kind" EXISTING="$existing" python3 - <<'PYEOF'
import json, os, sys
from datetime import datetime
from pathlib import Path

config_file = Path(os.path.expanduser("~/.claude/settings.json"))
existing_raw = os.environ.get("EXISTING", "{}")
merge_payload = json.loads(os.environ.get("MERGE_PAYLOAD", "{}"))
merge_kind = os.environ.get("MERGE_KIND")

try:
    existing = json.loads(existing_raw) if existing_raw.strip() else {}
except json.JSONDecodeError:
    backup = config_file.with_suffix(f".json.invalid-{datetime.now().strftime('%Y%m%d%H%M%S')}")
    if config_file.exists():
        backup.write_text(config_file.read_text())
    print(f"Invalid JSON in {config_file}. Backed it up to {backup}.", file=sys.stderr)
    existing = {}

if merge_kind == "hooks":
    hooks_new = merge_payload.get("hooks", {})
    hooks_existing = existing.setdefault("hooks", {})

    def hook_commands(entry):
        return {
            hook.get("command")
            for hook in entry.get("hooks", [])
            if hook.get("type") == "command" and hook.get("command")
        }

    for hook_type, hook_entries in hooks_new.items():
        existing_entries = hooks_existing.setdefault(hook_type, [])
        existing_cmds = set()
        for entry in existing_entries:
            existing_cmds.update(hook_commands(entry))

        for entry in hook_entries:
            new_cmds = hook_commands(entry)
            if new_cmds and new_cmds.issubset(existing_cmds):
                continue
            existing_entries.append(entry)
            existing_cmds.update(new_cmds)
elif merge_kind == "permissions":
    permissions_new = merge_payload.get("permissions", {})
    permissions_existing = existing.setdefault("permissions", {})
    allow = permissions_existing.setdefault("allow", [])

    for pattern in permissions_new.get("allow", []):
        if pattern not in allow:
            allow.append(pattern)
else:
    raise SystemExit(f"Unsupported MERGE_KIND: {merge_kind}")

print(json.dumps(existing, indent=2))
PYEOF
  ); then
    return 1
  fi

  printf '%s\n' "$merged" > "$config_file"
}

# ── 1. Clone or update the repo ──────────────────────────────────────────────
if [ -d "$LOCAL_REPO/.git" ]; then
  if [ -n "$(git -C "$LOCAL_REPO" status --porcelain)" ]; then
    echo "⚠️  Local changes detected in $LOCAL_REPO"
    echo "   Please commit or stash your changes before syncing."
    echo "   Run: cd $LOCAL_REPO && git stash"
    exit 1
  fi
  echo "🔄 Updating b-skills..."
  git -C "$LOCAL_REPO" pull --ff-only
else
  echo "📦 Cloning b-skills..."
  git clone "$REPO" "$LOCAL_REPO"
fi

# ── 2. Sync skills to ~/.claude/skills/ ────────────────────────────────────────
if [ -d "$SKILLS_SRC" ]; then
  mkdir -p "$CLAUDE_SKILLS_DST"

  stale_count=0
  for existing in "$CLAUDE_SKILLS_DST"/*/SKILL.md; do
    [ -f "$existing" ] || continue
    skill_dir=$(basename "$(dirname "$existing")")
    if [ ! -d "$SKILLS_SRC/$skill_dir" ]; then
      rm -rf "$(dirname "$existing")"
      stale_count=$((stale_count + 1))
    fi
  done

  synced_count=0
  for skill_dir in "$SKILLS_SRC"/*/; do
    [ -d "$skill_dir" ] || continue
    skill_name=$(basename "$skill_dir")
    [ "$skill_name" = "global" ] && continue
    [ -f "$skill_dir/SKILL.md" ] || continue
    target_dir="$CLAUDE_SKILLS_DST/$skill_name"
    _sync_directory "$skill_dir" "$target_dir"
    synced_count=$((synced_count + 1))
  done

  removed_summary=""
  if [ "$stale_count" -gt 0 ]; then
    removed_summary=", $stale_count removed"
  fi
  echo "✅ Skills: $synced_count synced$removed_summary → $CLAUDE_SKILLS_DST"
else
  echo "ℹ️  No skills/ folder found — skipping skill sync"
fi

# ── 3. Sync global CLAUDE.md to ~/.claude/CLAUDE.md ──────────────────────────
if [ -f "$CLAUDE_GLOBAL_SRC" ]; then
  mkdir -p "$(dirname "$CLAUDE_GLOBAL_DST")"
  ln -sfn "$CLAUDE_GLOBAL_SRC" "$CLAUDE_GLOBAL_DST"
  echo "🔗 Global CLAUDE.md → $CLAUDE_GLOBAL_DST"
fi

# ── 4. Auto-setup Claude Code hooks for Serena ───────────────────────────────
_HOOKS_CONFIG='{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "",
        "hooks": [
          { "type": "command", "command": "serena-hooks remind --client=claude-code" }
        ]
      },
      {
        "matcher": "mcp__serena__*",
        "hooks": [
          { "type": "command", "command": "serena-hooks auto-approve --client=claude-code" }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          { "type": "command", "command": "serena-hooks activate --client=claude-code" }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          { "type": "command", "command": "serena-hooks cleanup --client=claude-code" }
        ]
      }
    ]
  }
}'

_install_hooks() {
  if ! _merge_settings_json "$_HOOKS_CONFIG" hooks; then
    echo "⚠️  Failed to merge Serena hooks into $HOME/.claude/settings.json" >&2
    return 1
  fi

  echo "✅ Serena hooks written to $HOME/.claude/settings.json"
}

_install_hooks
echo "✅ Serena hooks installed — restart Claude Code for them to take effect."

# ── 5. Auto-setup MCP tool permissions ──────────────────────────────────────
_PERMISSIONS_CONFIG='{
  "permissions": {
    "allow": [
      "mcp__serena__*",
      "mcp__context7__*",
      "mcp__brave-search__*",
      "mcp__firecrawl__*",
      "mcp__sequential-thinking__*"
    ]
  }
}'

_install_permissions() {
  if ! _merge_settings_json "$_PERMISSIONS_CONFIG" permissions; then
    echo "⚠️  Failed to merge MCP permissions into $HOME/.claude/settings.json" >&2
    return 1
  fi

  echo "✅ MCP permissions written to $HOME/.claude/settings.json"
}

_install_permissions

# ── 6. Install / update MCP servers ──────────────────────────────────────────
echo ""
echo "Do you want to install / update MCP servers?"
echo "  (Adds context7, brave-search, firecrawl, serena, sequential-thinking)"
echo ""
install_mcps=$(_prompt_yes_no "Install MCPs? [y/N] (default: N): ")

if [[ "$install_mcps" =~ ^[Yy]$ ]]; then
  echo ""
  echo "Enter API keys (leave blank to skip):"
  read -rsp "  BRAVE_API_KEY: " brave_key </dev/tty; echo ""
  read -rp  "  FIRECRAWL_API_URL (default: https://api.firecrawl.dev/): " firecrawl_url </dev/tty
  firecrawl_url="${firecrawl_url:-https://api.firecrawl.dev/}"
  read -rsp "  FIRECRAWL_API_KEY: " firecrawl_key </dev/tty; echo ""

  echo ""

  # sequential-thinking
  echo "➕ Adding sequential-thinking..."
  claude mcp add -s user sequential-thinking npx -- -y @modelcontextprotocol/server-sequential-thinking \
    && echo "✅ sequential-thinking added" || echo "⚠️  Failed to add sequential-thinking"

  # brave-search
  if [ -n "$brave_key" ]; then
    echo "➕ Adding brave-search..."
    claude mcp add brave-search -s user -e BRAVE_API_KEY="$brave_key" -- npx -y @brave/brave-search-mcp-server \
      && echo "✅ brave-search added" || echo "⚠️  Failed to add brave-search"
  else
    echo "⏭️  Skipping brave-search (no API key provided)"
  fi

  # firecrawl
  if [ -n "$firecrawl_key" ]; then
    echo "➕ Adding firecrawl..."
    claude mcp add firecrawl -s user \
      -e FIRECRAWL_API_URL="$firecrawl_url" \
      -e FIRECRAWL_API_KEY="$firecrawl_key" \
      -- npx -y firecrawl-mcp \
      && echo "✅ firecrawl added" || echo "⚠️  Failed to add firecrawl"
  else
    echo "⏭️  Skipping firecrawl (no API key provided)"
  fi

  # context7
  echo ""
  echo "ℹ️  Context7: run the following command to set it up interactively:"
  echo "   npx ctx7@latest setup"

  # serena
  echo ""
  echo "ℹ️  Serena: run the following commands to install and initialize:"
  echo "   uv tool install -p 3.13 serena-agent@latest --prerelease=allow"
  echo "   serena init"
  echo "   claude mcp add --scope user serena -- serena start-mcp-server --context claude-code --project-from-cwd"
  echo "   (If uv is not installed: curl -LsSf https://astral.sh/uv/install.sh | sh)"
fi

# ── 7. Done ──────────────────────────────────────────────────────────────────
echo ""
echo "✅ b-skills installed successfully."
echo "   Skills:    $CLAUDE_SKILLS_DST/"
echo "   Global:    $CLAUDE_GLOBAL_DST"
echo ""
echo "   Restart Claude Code to load the skills."
