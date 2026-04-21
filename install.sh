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
    [ "$skill_name" = "global" ] && continue  # skip global/ — handled separately
    [ -f "$skill_dir/SKILL.md" ] || continue  # skip dirs without SKILL.md
    target_dir="$CLAUDE_SKILLS_DST/$skill_name"
    mkdir -p "$target_dir"
    # Copy SKILL.md (and any other files in the skill directory)
    cp -r "$skill_dir"* "$target_dir/"
    synced_count=$((synced_count + 1))
  done

  echo "✅ Skills: $synced_count synced${stale_count:+, $stale_count removed} → $CLAUDE_SKILLS_DST"

  # ── 2.5. Remove stale global symlink from old OpenCode install ────────────
  old_agents_link="$HOME/.config/opencode/AGENTS.md"
  if [ -L "$old_agents_link" ]; then
    echo "🧹 Found old OpenCode AGENTS.md symlink — removing it."
    rm "$old_agents_link"
  fi

  # Remove old OpenCode agent symlinks if they exist
  if [ -d "$HOME/.config/opencode/agents" ]; then
    echo "🧹 Found old OpenCode agents directory — removing it."
    rm -rf "$HOME/.config/opencode/agents"
  fi

else
  echo "ℹ️  No skills/ folder found — skipping skill sync"
fi

# ── 3. Sync global CLAUDE.md to ~/.claude/CLAUDE.md ──────────────────────────
if [ -f "$CLAUDE_GLOBAL_SRC" ]; then
  mkdir -p "$(dirname "$CLAUDE_GLOBAL_DST")"

  # Remove old symlink or file if it exists
  [ -L "$CLAUDE_GLOBAL_DST" ] && rm "$CLAUDE_GLOBAL_DST"
  [ -f "$CLAUDE_GLOBAL_DST" ] && rm "$CLAUDE_GLOBAL_DST"

  # Create symlink to global CLAUDE.md
  ln -s "$CLAUDE_GLOBAL_SRC" "$CLAUDE_GLOBAL_DST"
  echo "🔗 Global CLAUDE.md → $CLAUDE_GLOBAL_DST"

  # ── 3.5. Remove old global AGENTS.md symlink if present ──────────────────
  old_claude_agents="$HOME/.claude/AGENTS.md"
  if [ -L "$old_claude_agents" ]; then
    echo "🧹 Found old ~/.claude/AGENTS.md symlink — removing it."
    rm "$old_claude_agents"
  fi
fi

# ── 4. Install / update MCP servers ──────────────────────────────────────────
echo ""
echo "Do you want to install / update MCP servers?"
echo "  (Adds context7, brave-search, firecrawl, serena, sequential-thinking)"
echo ""
read -rp "Install MCPs? [y/N] (default: N): " install_mcps </dev/tty
install_mcps="${install_mcps:-N}"

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
  echo "   (If uv is not installed: curl -LsSf https://astral.sh/uv/install.sh | sh)"
fi

# ── 6. Auto-setup Claude Code hooks for Serena ───────────────────────────────
_HOOKS_CONFIG='{
  "hooks": {
    "PreToolUse": [
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
      },
      {
        "matcher": "",
        "hooks": [
          { "type": "command", "command": "serena-hooks remind --client=claude-code" }
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
  local config_file="$HOME/.claude/settings.json"
  mkdir -p "$(dirname "$config_file")"

  if [ -f "$config_file" ]; then
    local existing
    existing=$(cat "$config_file")
    # Merge hooks into existing config (don't overwrite other hooks)
    local merged
    merged=$(python3 - <<'PYEOF'
import json, sys, os

existing_raw = os.environ.get("EXISTING", "{}")
try:
    existing = json.loads(existing_raw)
except json.JSONDecodeError:
    existing = {}

hooks_new = json.loads(os.environ.get("HOOKS_CONFIG", "{}")).get("hooks", {})

if "hooks" not in existing:
    existing["hooks"] = {}

for hook_type, hook_entries in hooks_new.items():
    if hook_type not in existing["hooks"]:
        existing["hooks"][hook_type] = []
    # Deduplicate by command — don't add if already present
    existing_cmds = {h.get("command", "") for h in existing["hooks"][hook_type]}
    for entry in hook_entries:
        if entry.get("command", "") not in existing_cmds:
            existing["hooks"][hook_type].append(entry)

print(json.dumps(existing, indent=2))
PYEOF
)
    echo "$merged" > "$config_file"
  else
    echo "$_HOOKS_CONFIG" > "$config_file"
  fi
  echo "✅ Serena hooks written to $config_file"
}

read -rp "Install Claude Code hooks for Serena (recommended)? [Y/n]: " install_hooks </dev/tty
install_hooks="${install_hooks:-Y}"
if [[ "$install_hooks" =~ ^[Yy]$ ]]; then
  EXISTING=$(cat "$HOME/.claude/settings.json" 2>/dev/null || echo "{}")
  HOOKS_CONFIG="$_HOOKS_CONFIG" EXISTING="$EXISTING" _install_hooks
  echo "✅ Serena hooks installed — restart Claude Code for them to take effect."
fi

# ── 5. Done ──────────────────────────────────────────────────────────────────
echo ""
echo "✅ b-skills installed successfully."
echo "   Skills:    $CLAUDE_SKILLS_DST/"
echo "   Global:    $CLAUDE_GLOBAL_DST"
echo ""
echo "   Restart Claude Code to load the skills."
