#!/usr/bin/env bash
# install.sh — Bootstrap or update b-agent-skills on any machine
# Usage:
#   First time : curl -fsSL https://raw.githubusercontent.com/dhoaibao/b-agent-skills/main/install.sh | bash
#   Update     : curl -fsSL https://raw.githubusercontent.com/dhoaibao/b-agent-skills/main/install.sh | bash

set -euo pipefail

REPO="https://github.com/dhoaibao/b-agent-skills.git"
LOCAL_REPO="$HOME/.b-agent-skills"
CLAUDE_SKILLS_SRC="$LOCAL_REPO/claude"
CLAUDE_SKILLS_DST="$HOME/.claude/skills"
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
echo "  1) Claude Code"
echo "  2) OpenCode"
echo "  3) HDCode"
echo "  4) All"
echo ""
if [ -t 0 ] && [ -z "${B_AGENT_PLATFORM:-}" ]; then
  read -rp "Enter choice [1/2/3/4] (default: 4): " platform_choice </dev/tty
  platform_choice="${platform_choice:-4}"
else
  platform_choice="${B_AGENT_PLATFORM:-4}"
fi

case "$platform_choice" in
  1) sync_claude=true;  sync_opencode=false; sync_hdcode=false ;;
  2) sync_claude=false; sync_opencode=true;  sync_hdcode=false ;;
  3) sync_claude=false; sync_opencode=false; sync_hdcode=true  ;;
  4) sync_claude=true;  sync_opencode=true;  sync_hdcode=true  ;;
  *)
    echo "❌ Invalid choice. Exiting."
    exit 1
    ;;
esac

# ── 3. Sync Claude Code skills ────────────────────────────────────────────────
if [ "$sync_claude" = true ]; then
  mkdir -p "$CLAUDE_SKILLS_DST"

  # Remove stale symlinks (skills deleted from repo)
  echo "🧹 Removing stale Claude Code skills..."
  for existing in "$CLAUDE_SKILLS_DST"/*/; do
    [ -e "$existing" ] || continue
    skill_name=$(basename "$existing")
    if [ -L "$existing" ] && [ ! -d "$CLAUDE_SKILLS_SRC/$skill_name" ]; then
      rm "$existing"
      echo "  🗑  removed $skill_name"
    fi
  done

  # Symlink each skill folder that contains a SKILL.md
  echo "🔗 Syncing Claude Code skills..."
  for skill_dir in "$CLAUDE_SKILLS_SRC"/*/; do
    skill_name=$(basename "$skill_dir")

    if [ ! -f "$skill_dir/SKILL.md" ]; then
      continue
    fi

    target="$CLAUDE_SKILLS_DST/$skill_name"

    if [ -L "$target" ] || [ -d "$target" ]; then
      rm -rf "$target"
    fi

    ln -s "$skill_dir" "$target"
    echo "  ✅ $skill_name"
  done

  echo ""
  echo "✨ Claude Code skills live in $CLAUDE_SKILLS_DST"
fi

# ── 4. Sync OpenCode agents ───────────────────────────────────────────────────
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

    # Symlink each agent file (skip AGENTS.md — handled as global rules)
    echo "🔗 Syncing OpenCode agents..."
    for agent_file in "$OPENCODE_AGENTS_SRC"/*.md; do
      [ -f "$agent_file" ] || continue
      agent_name=$(basename "$agent_file")
      [ "$agent_name" = "AGENTS.md" ] && continue

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

# ── 5. Sync HDCode agents (same source as OpenCode) ───────────────────────────
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

    # Symlink each agent file from opencode/ source (skip AGENTS.md)
    echo "🔗 Syncing HDCode agents..."
    for agent_file in "$OPENCODE_AGENTS_SRC"/*.md; do
      [ -f "$agent_file" ] || continue
      agent_name=$(basename "$agent_file")
      [ "$agent_name" = "AGENTS.md" ] && continue

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

# ── 6. Sync global AGENTS.md (OpenCode global rules) ─────────────────────────
if [ "$sync_opencode" = true ] || [ "$sync_hdcode" = true ]; then
  GLOBAL_AGENTS_FILE="$OPENCODE_AGENTS_SRC/AGENTS.md"
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
