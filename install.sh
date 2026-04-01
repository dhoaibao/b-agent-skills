#!/usr/bin/env bash
# install.sh — Bootstrap or update b-agent-skills on any machine
# Usage:
#   First time : curl -fsSL https://raw.githubusercontent.com/dhoaibao/b-agent-skills/main/install.sh | bash
#   Update     : curl -fsSL https://raw.githubusercontent.com/dhoaibao/b-agent-skills/main/install.sh | bash

set -euo pipefail

REPO="https://github.com/dhoaibao/b-agent-skills.git"
LOCAL_REPO="$HOME/.b-agent-skills"
OPENCODE_AGENTS_SRC="$LOCAL_REPO/opencode"
OPENCODE_AGENTS_DST="$HOME/.config/opencode/agents"
HDCODE_AGENTS_DST="$HOME/.config/hdcode/agents"
GLOBAL_AGENTS_DST="$HOME/.agents"

# ── 1. Clone or update the repo ──────────────────────────────────────────────
if [ -d "$LOCAL_REPO/.git" ]; then
  if [ -n "$(git -C "$LOCAL_REPO" status --porcelain)" ]; then
    echo "⚠️  Local changes detected in $LOCAL_REPO"
    echo "   Please commit or stash your changes before syncing."
    echo "   Run: cd $LOCAL_REPO && git stash"
    exit 1
  fi
  echo "🔄 Updating b-agent-skills..."
  git -C "$LOCAL_REPO" pull --ff-only
else
  echo "📦 Cloning b-agent-skills..."
  git clone "$REPO" "$LOCAL_REPO"
fi

# ── 2. Platform selection ─────────────────────────────────────────────────────
echo ""
echo "Which platform do you want to sync?"
echo "  1) OpenCode"
echo "  2) HDCode"
echo "  3) All"
echo ""
if [ -z "${B_AGENT_PLATFORM:-}" ]; then
  read -rp "Enter choice [1/2/3] (default: 3): " platform_choice </dev/tty
  platform_choice="${platform_choice:-3}"
else
  platform_choice="${B_AGENT_PLATFORM:-3}"
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

    # Remove stale symlinks (agent files deleted from repo)
    echo "🧹 Removing stale OpenCode agents..."
    for existing in "$OPENCODE_AGENTS_DST"/*.md; do
      [ -e "$existing" ] || continue
      agent_name=$(basename "$existing")
      if [ -L "$existing" ] && [ ! -f "$OPENCODE_AGENTS_SRC/$agent_name" ]; then
        rm "$existing"
        echo "  🗑  removed $agent_name"
      fi
    done

    # Symlink each agent file
    echo "🔗 Syncing OpenCode agents..."
    for agent_file in "$OPENCODE_AGENTS_SRC"/*.md; do
      [ -f "$agent_file" ] || continue
      agent_name=$(basename "$agent_file")

      target="$OPENCODE_AGENTS_DST/$agent_name"

      if [ -L "$target" ] || [ -f "$target" ]; then
        rm "$target"
      fi

      ln -s "$agent_file" "$target"
      echo "  ✅ $agent_name"
    done

    echo ""
    echo "✨ OpenCode agents live in $OPENCODE_AGENTS_DST"
  else
    echo "ℹ️  No opencode/ folder found — skipping OpenCode agent sync"
  fi
fi

# ── 4. Sync HDCode agents (same source as OpenCode) ───────────────────────────
if [ "$sync_hdcode" = true ]; then
  if [ -d "$OPENCODE_AGENTS_SRC" ]; then
    mkdir -p "$HDCODE_AGENTS_DST"

    # Remove stale symlinks (agent files deleted from repo)
    echo "🧹 Removing stale HDCode agents..."
    for existing in "$HDCODE_AGENTS_DST"/*.md; do
      [ -e "$existing" ] || continue
      agent_name=$(basename "$existing")
      if [ -L "$existing" ] && [ ! -f "$OPENCODE_AGENTS_SRC/$agent_name" ]; then
        rm "$existing"
        echo "  🗑  removed $agent_name"
      fi
    done

    # Symlink each agent file from opencode/ source
    echo "🔗 Syncing HDCode agents..."
    for agent_file in "$OPENCODE_AGENTS_SRC"/*.md; do
      [ -f "$agent_file" ] || continue
      agent_name=$(basename "$agent_file")

      target="$HDCODE_AGENTS_DST/$agent_name"

      if [ -L "$target" ] || [ -f "$target" ]; then
        rm "$target"
      fi

      ln -s "$agent_file" "$target"
      echo "  ✅ $agent_name"
    done

    echo ""
    echo "✨ HDCode agents live in $HDCODE_AGENTS_DST"
  else
    echo "ℹ️  No opencode/ folder found — skipping HDCode agent sync"
  fi
fi

# ── 5. Sync global AGENTS.md (OpenCode global rules) ─────────────────────────
if [ "$sync_opencode" = true ] || [ "$sync_hdcode" = true ]; then
  GLOBAL_AGENTS_FILE="$OPENCODE_AGENTS_SRC/global/AGENTS.md"
  if [ -f "$GLOBAL_AGENTS_FILE" ]; then
    mkdir -p "$GLOBAL_AGENTS_DST"
    target="$GLOBAL_AGENTS_DST/AGENTS.md"

    if [ -L "$target" ] || [ -f "$target" ]; then
      rm "$target"
    fi

    ln -s "$GLOBAL_AGENTS_FILE" "$target"
    echo "🔗 Global AGENTS.md → $target"
  fi
fi
