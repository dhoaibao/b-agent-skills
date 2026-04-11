#!/usr/bin/env bash
# install.sh — Bootstrap or update b-agents for Claude Code
# Usage:
#   First time : curl -fsSL https://raw.githubusercontent.com/dhoaibao/b-agents/main/install.sh | bash
#   Update     : curl -fsSL https://raw.githubusercontent.com/dhoaibao/b-agents/main/install.sh | bash

set -euo pipefail

REPO="https://github.com/dhoaibao/b-agents.git"
LOCAL_REPO="$HOME/.b-agents"
CLAUDE_AGENTS_SRC="$LOCAL_REPO/claude/agents"
CLAUDE_AGENTS_DST="$HOME/.claude/agents"
CLAUDE_GLOBAL_SRC="$LOCAL_REPO/claude/CLAUDE.md"
CLAUDE_GLOBAL_DST="$HOME/.claude/CLAUDE.md"

# ── 1. Clone or update the repo ──────────────────────────────────────────────
if [ -d "$LOCAL_REPO/.git" ]; then
  if [ -n "$(git -C "$LOCAL_REPO" status --porcelain)" ]; then
    echo "⚠️  Local changes detected in $LOCAL_REPO"
    echo "   Please commit or stash your changes before syncing."
    echo "   Run: cd $LOCAL_REPO && git stash"
    exit 1
  fi
  echo "🔄 Updating b-agents..."
  git -C "$LOCAL_REPO" pull --ff-only
else
  echo "📦 Cloning b-agents..."
  git clone "$REPO" "$LOCAL_REPO"
fi

# ── 2. Sync Claude Code agents ────────────────────────────────────────────────
if [ -d "$CLAUDE_AGENTS_SRC" ]; then
  mkdir -p "$CLAUDE_AGENTS_DST"

  stale_count=0
  for existing in "$CLAUDE_AGENTS_DST"/*.md; do
    [ -e "$existing" ] || continue
    if [ -L "$existing" ] && [ ! -f "$CLAUDE_AGENTS_SRC/$(basename "$existing")" ]; then
      rm "$existing"
      stale_count=$((stale_count + 1))
    fi
  done

  synced_count=0
  for agent_file in "$CLAUDE_AGENTS_SRC"/*.md; do
    [ -f "$agent_file" ] || continue
    target="$CLAUDE_AGENTS_DST/$(basename "$agent_file")"
    { [ -L "$target" ] || [ -f "$target" ]; } && rm "$target"
    ln -s "$agent_file" "$target"
    synced_count=$((synced_count + 1))
  done

  echo "✅ Claude Code: $synced_count agents synced${stale_count:+, $stale_count removed} → $CLAUDE_AGENTS_DST"
else
  echo "ℹ️  No claude/agents/ folder found — skipping agent sync"
fi

# ── 3. Sync global CLAUDE.md ──────────────────────────────────────────────────
if [ -f "$CLAUDE_GLOBAL_SRC" ]; then
  mkdir -p "$HOME/.claude"
  { [ -L "$CLAUDE_GLOBAL_DST" ] || [ -f "$CLAUDE_GLOBAL_DST" ]; } && rm "$CLAUDE_GLOBAL_DST"
  ln -s "$CLAUDE_GLOBAL_SRC" "$CLAUDE_GLOBAL_DST"
  echo "🔗 Global CLAUDE.md → $CLAUDE_GLOBAL_DST"
fi

# ── 4. Install / update MCP servers ──────────────────────────────────────────
echo ""
echo "Do you want to install / update MCP servers?"
echo "  (Adds context7, brave-search, firecrawl, jcodemunch, sequential-thinking)"
echo ""
read -rp "Install MCPs? [y/N] (default: N): " install_mcps </dev/tty
install_mcps="${install_mcps:-N}"

if [[ "$install_mcps" =~ ^[Yy]$ ]]; then
  echo ""
  echo "Enter API keys (leave blank to skip / keep existing):"
  read -rsp "  BRAVE_API_KEY: " brave_key </dev/tty; echo ""
  read -rsp "  FIRECRAWL_API_KEY: " firecrawl_key </dev/tty; echo ""
  read -rp  "  FIRECRAWL_API_URL (default: https://api.firecrawl.dev/): " firecrawl_url </dev/tty
  firecrawl_url="${firecrawl_url:-https://api.firecrawl.dev/}"

  CONFIG_FILE="$HOME/.claude/settings.json"
  mkdir -p "$HOME/.claude"

  existing="{}"
  if [ -f "$CONFIG_FILE" ]; then
    existing=$(cat "$CONFIG_FILE")
  fi

  new_config=$(
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

mcp = existing.get("mcpServers", {})

# sequential-thinking — no key needed
mcp["sequential-thinking"] = {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"]
}

# context7 — remote HTTP MCP, no key needed
mcp["context7"] = {
    "url": "https://mcp.context7.com/mcp"
}

# jcodemunch — no key needed
mcp["jcodemunch"] = {
    "command": "uvx",
    "args": ["jcodemunch-mcp"]
}

# brave-search — update key only if provided
if "brave-search" not in mcp:
    mcp["brave-search"] = {
        "command": "npx",
        "args": ["-y", "@modelcontextprotocol/server-brave-search"],
        "env": {"BRAVE_API_KEY": brave_key or "YOUR_API_KEY"}
    }
elif brave_key:
    mcp["brave-search"].setdefault("env", {})["BRAVE_API_KEY"] = brave_key

# firecrawl — update keys only if provided
if "firecrawl" not in mcp:
    mcp["firecrawl"] = {
        "command": "npx",
        "args": ["-y", "firecrawl-mcp"],
        "env": {
            "FIRECRAWL_API_KEY": firecrawl_key or "YOUR_API_KEY",
            "FIRECRAWL_API_URL": firecrawl_url
        }
    }
else:
    env = mcp["firecrawl"].setdefault("env", {})
    if firecrawl_key:
        env["FIRECRAWL_API_KEY"] = firecrawl_key
    if firecrawl_url:
        env["FIRECRAWL_API_URL"] = firecrawl_url

existing["mcpServers"] = mcp
print(json.dumps(existing, indent=2))
PYEOF
  )

  if [ -n "$new_config" ]; then
    echo "$new_config" > "$CONFIG_FILE"
    echo "✅ MCP config written to $CONFIG_FILE"
  else
    echo "⚠️  Failed to generate MCP config — skipping"
  fi

  echo ""
  echo "⚠️  Remember to set any missing API keys in $CONFIG_FILE before using the MCPs."
  echo "⚠️  Restart Claude Code to load the new MCP configuration."
fi

echo ""
echo "✅ Done! Restart Claude Code to load the updated agents."
