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
  echo "Enter API keys (leave blank to skip / keep existing):"
  read -rsp "  BRAVE_API_KEY: " brave_key </dev/tty; echo ""
  read -rp  "  FIRECRAWL_API_URL (default: https:/firecrawl-api.dhbao.dev/): " firecrawl_url </dev/tty
  firecrawl_url="${firecrawl_url:-https:/firecrawl-api.dhbao.dev/}"
  firecrawl_key="SELF_HOST"

  _merge_mcp_config() {
    local config_file="$1"
    local brave_key="$2"
    local firecrawl_key="$3"
    local firecrawl_url="$4"

    mkdir -p "$(dirname "$config_file")"

    local existing="{}"
    if [ -f "$config_file" ]; then
      existing=$(cat "$config_file")
    fi

    _MCP_BRAVE_KEY="$brave_key" \
    _MCP_FIRECRAWL_KEY="$firecrawl_key" \
    _MCP_FIRECRAWL_URL="$firecrawl_url" \
    _MCP_EXISTING="$existing" \
    python3 - <<'PYEOF'
import json, os

existing = json.loads(os.environ["_MCP_EXISTING"])
brave_key = os.environ.get("_MCP_BRAVE_KEY", "")
firecrawl_key = os.environ.get("_MCP_FIRECRAWL_KEY", "")
firecrawl_url = os.environ.get("_MCP_FIRECRAWL_URL", "")

mcpServers = existing.get("mcpServers", {})

# sequential-thinking — no key needed
mcpServers["sequential-thinking"] = {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"]
}

# context7 — remote, no key needed
mcpServers["context7"] = {
    "type": "url",
    "url": "https://mcp.context7.com/mcp"
}

# serena — no key needed
mcpServers["serena"] = {
    "command": "uvx",
    "args": [
        "-p", "3.13",
        "--from", "git+https://github.com/oraios/serena",
        "serena", "start-mcp-server",
        "--context", "claude-code",
        "--project-from-cwd"
    ]
}

# brave-search — update key only if provided
if "brave-search" not in mcpServers:
    mcpServers["brave-search"] = {
        "command": "npx",
        "args": ["-y", "@modelcontextprotocol/server-brave-search"],
        "env": {"BRAVE_API_KEY": brave_key or "YOUR_API_KEY"}
    }
elif brave_key:
    mcpServers["brave-search"].setdefault("env", {})["BRAVE_API_KEY"] = brave_key

# firecrawl — update keys only if provided
if "firecrawl" not in mcpServers:
    mcpServers["firecrawl"] = {
        "command": "npx",
        "args": ["-y", "firecrawl-mcp"],
        "env": {
            "FIRECRAWL_API_KEY": firecrawl_key or "YOUR_API_KEY",
            "FIRECRAWL_API_URL": firecrawl_url
        }
    }
else:
    env = mcpServers["firecrawl"].setdefault("env", {})
    if firecrawl_key:
        env["FIRECRAWL_API_KEY"] = firecrawl_key
    if firecrawl_url:
        env["FIRECRAWL_API_URL"] = firecrawl_url

existing["mcpServers"] = mcpServers
print(json.dumps(existing, indent=2))
PYEOF
  }

  _write_mcp_config() {
    local config_file="$1"
    local new_config
    if new_config=$(_merge_mcp_config "$config_file" "$brave_key" "$firecrawl_key" "$firecrawl_url") && [ -n "$new_config" ]; then
      echo "$new_config" > "$config_file"
      echo "✅ MCP config written to $config_file"
    else
      echo "⚠️  Failed to update $config_file — skipping"
    fi
  }

  _write_mcp_config "$HOME/.claude/settings.json"

  echo ""
  echo "⚠️  Remember to set any missing API keys in the config file before using the MCPs."
fi

# ── 5. Done ──────────────────────────────────────────────────────────────────
echo ""
echo "✅ b-skills installed successfully."
echo "   Skills:    $CLAUDE_SKILLS_DST/"
echo "   Global:    $CLAUDE_GLOBAL_DST"
echo ""
echo "   Restart Claude Code to load the skills."
