#!/usr/bin/env bash
# install.sh — Bootstrap or update b-agents on any machine
# Usage:
#   First time : curl -fsSL https://raw.githubusercontent.com/dhoaibao/b-agents/main/install.sh | bash
#   Update     : curl -fsSL https://raw.githubusercontent.com/dhoaibao/b-agents/main/install.sh | bash

set -euo pipefail

REPO="https://github.com/dhoaibao/b-agents.git"
LOCAL_REPO="$HOME/.b-agents"
OPENCODE_AGENTS_SRC="$LOCAL_REPO/opencode"
OPENCODE_AGENTS_DST="$HOME/.config/opencode/agents"
HDCODE_AGENTS_DST="$HOME/.config/hdcode/agents"

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

# ── 2. Platform selection ─────────────────────────────────────────────────────
echo ""
echo "Which platform do you want to sync?"
echo "  1) OpenCode"
echo "  2) HDCode"
echo "  3) All"
echo ""

_normalize_choice() {
  local choice="${1:-}"
  choice="${choice//$'\r'/}"
  choice="${choice//[[:space:]]/}"
  printf '%s' "$choice"
}

if [ -z "${B_AGENT_PLATFORM:-}" ]; then
  read -rp "Enter choice [1/2/3] (default: 3): " platform_choice </dev/tty || platform_choice=""
  platform_choice="$(_normalize_choice "$platform_choice")"
  [ -n "$platform_choice" ] || platform_choice="3"
else
  platform_choice="$(_normalize_choice "${B_AGENT_PLATFORM:-3}")"
  [ -n "$platform_choice" ] || platform_choice="3"
fi

case "$platform_choice" in
  1) sync_opencode=true;  sync_hdcode=false ;;
  2) sync_opencode=false; sync_hdcode=true  ;;
  3) sync_opencode=true;  sync_hdcode=true  ;;
  *)
    echo "❌ Invalid choice. Exiting."
    exit 1
    ;;
esac

# ── 3. Sync OpenCode agents ───────────────────────────────────────────────────
if [ "$sync_opencode" = true ]; then
  if [ -d "$OPENCODE_AGENTS_SRC" ]; then
    mkdir -p "$OPENCODE_AGENTS_DST"

    stale_count=0
    for existing in "$OPENCODE_AGENTS_DST"/*.md; do
      [ -e "$existing" ] || continue
      if [ -L "$existing" ] && [ ! -f "$OPENCODE_AGENTS_SRC/$(basename "$existing")" ]; then
        rm "$existing"
        stale_count=$((stale_count + 1))
      fi
    done

    synced_count=0
    for agent_file in "$OPENCODE_AGENTS_SRC"/*.md; do
      [ -f "$agent_file" ] || continue
      target="$OPENCODE_AGENTS_DST/$(basename "$agent_file")"
      { [ -L "$target" ] || [ -f "$target" ]; } && rm "$target"
      ln -s "$agent_file" "$target"
      synced_count=$((synced_count + 1))
    done

    echo "✅ OpenCode: $synced_count agents synced${stale_count:+, $stale_count removed} → $OPENCODE_AGENTS_DST"

  else
    echo "ℹ️  No opencode/ folder found — skipping OpenCode agent sync"
  fi
fi

# ── 4. Sync HDCode agents ─────────────────────────────────────────────────────
if [ "$sync_hdcode" = true ]; then
  if [ -d "$OPENCODE_AGENTS_SRC" ]; then
    mkdir -p "$HDCODE_AGENTS_DST"

    stale_count=0
    for existing in "$HDCODE_AGENTS_DST"/*.md; do
      [ -e "$existing" ] || continue
      if [ -L "$existing" ] && [ ! -f "$OPENCODE_AGENTS_SRC/$(basename "$existing")" ]; then
        rm "$existing"
        stale_count=$((stale_count + 1))
      fi
    done

    synced_count=0
    for agent_file in "$OPENCODE_AGENTS_SRC"/*.md; do
      [ -f "$agent_file" ] || continue
      target="$HDCODE_AGENTS_DST/$(basename "$agent_file")"
      { [ -L "$target" ] || [ -f "$target" ]; } && rm "$target"
      ln -s "$agent_file" "$target"
      synced_count=$((synced_count + 1))
    done

    echo "✅ HDCode: $synced_count agents synced${stale_count:+, $stale_count removed} → $HDCODE_AGENTS_DST"

  else
    echo "ℹ️  No opencode/ folder found — skipping HDCode agent sync"
  fi
fi

# ── 5. Install / update MCP servers ──────────────────────────────────────────
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

  _merge_mcp_config() {
    local config_file="$1"
    local brave_key="$2"
    local firecrawl_key="$3"
    local firecrawl_url="$4"

    mkdir -p "$(dirname "$config_file")"

    # Read existing config or start fresh
    local existing="{}"
    if [ -f "$config_file" ]; then
      existing=$(cat "$config_file")
    fi

    # Pass keys via env vars — never interpolated into script source
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

mcp = existing.get("mcp", {})

# sequential-thinking — no key needed
mcp["sequential-thinking"] = {
    "type": "local",
    "command": ["npx", "-y", "@modelcontextprotocol/server-sequential-thinking"]
}

# context7 — remote, no key needed
mcp["context7"] = {
    "enabled": True,
    "type": "remote",
    "url": "https://mcp.context7.com/mcp"
}

# jcodemunch — no key needed
mcp["jcodemunch"] = {
    "enabled": True,
    "type": "local",
    "command": ["uvx", "jcodemunch-mcp"]
}

# brave-search — update key only if provided
if "brave-search" not in mcp:
    mcp["brave-search"] = {
        "enabled": True,
        "type": "local",
        "command": ["npx", "-y", "@modelcontextprotocol/server-brave-search"],
        "environment": {"BRAVE_API_KEY": brave_key or "YOUR_API_KEY"}
    }
elif brave_key:
    mcp["brave-search"].setdefault("environment", {})["BRAVE_API_KEY"] = brave_key

# firecrawl — update keys only if provided
if "firecrawl" not in mcp:
    mcp["firecrawl"] = {
        "type": "local",
        "command": ["npx", "-y", "firecrawl-mcp"],
        "environment": {
            "FIRECRAWL_API_KEY": firecrawl_key or "YOUR_API_KEY",
            "FIRECRAWL_API_URL": firecrawl_url
        }
    }
else:
    env = mcp["firecrawl"].setdefault("environment", {})
    if firecrawl_key:
        env["FIRECRAWL_API_KEY"] = firecrawl_key
    if firecrawl_url:
        env["FIRECRAWL_API_URL"] = firecrawl_url

existing["mcp"] = mcp
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

  [ "$sync_opencode" = true ] && _write_mcp_config "$HOME/.config/opencode/opencode.json"
  [ "$sync_hdcode"   = true ] && _write_mcp_config "$HOME/.config/hdcode/opencode.json"

  echo ""
  echo "⚠️  Remember to set any missing API keys in the config files before using the MCPs."
fi

# ── 6. Sync global AGENTS.md ─────────────────────────────────────────────────
GLOBAL_AGENTS_FILE="$OPENCODE_AGENTS_SRC/global/AGENTS.md"
if [ -f "$GLOBAL_AGENTS_FILE" ]; then
  if [ "$sync_opencode" = true ]; then
    mkdir -p "$HOME/.config/opencode"
    target="$HOME/.config/opencode/AGENTS.md"
    [ -L "$target" ] || [ -f "$target" ] && rm "$target"
    ln -s "$GLOBAL_AGENTS_FILE" "$target"
    echo "🔗 Global AGENTS.md → $target"
  fi

  if [ "$sync_hdcode" = true ]; then
    mkdir -p "$HOME/.config/hdcode"
    target="$HOME/.config/hdcode/AGENTS.md"
    [ -L "$target" ] || [ -f "$target" ] && rm "$target"
    ln -s "$GLOBAL_AGENTS_FILE" "$target"
    echo "🔗 Global AGENTS.md → $target"
  fi
fi
