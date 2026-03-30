#!/usr/bin/env bash
# codex/codex-sync.sh — Bootstrap or update b-agent-skills (Codex edition) on any machine
# Installs Codex-compatible skills to ~/.agents/skills/
#
# Usage:
#   First time : git clone https://github.com/dhoaibao/b-agent-skills.git ~/.b-agent-skills && bash ~/.b-agent-skills/codex/codex-sync.sh
#   Update     : bash ~/.b-agent-skills/codex/codex-sync.sh
#
# Optional flags:
#   --project   Install to .agents/skills/ in the current directory (project-level)
#               instead of the default ~/.agents/skills/ (user-level)

set -euo pipefail

REPO="https://github.com/dhoaibao/b-agent-skills.git"
LOCAL_REPO="$HOME/.b-agent-skills"
CODEX_SKILLS_SRC="$LOCAL_REPO/codex/skills"

# ── Parse flags ───────────────────────────────────────────────────────────────
PROJECT_LEVEL=false
for arg in "$@"; do
  if [ "$arg" = "--project" ]; then
    PROJECT_LEVEL=true
  fi
done

if [ "$PROJECT_LEVEL" = true ]; then
  SKILLS_DIR="$(pwd)/.agents/skills"
  echo "📁 Project-level install: $SKILLS_DIR"
else
  SKILLS_DIR="$HOME/.agents/skills"
  echo "📁 User-level install: $SKILLS_DIR"
fi

# ── 1. Clone or update the repo ──────────────────────────────────────────────
if [ -d "$LOCAL_REPO/.git" ]; then
  # Check for uncommitted changes before pulling
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

# ── 2. Verify codex/skills/ source exists ────────────────────────────────────
if [ ! -d "$CODEX_SKILLS_SRC" ]; then
  echo "❌ codex/skills/ not found in $LOCAL_REPO — is this a b-agent-skills repo?"
  exit 1
fi

# ── 3. Ensure skills directory exists ────────────────────────────────────────
mkdir -p "$SKILLS_DIR"

# ── 4. Remove stale symlinks (skills deleted from repo) ──────────────────────
echo "🧹 Removing stale skills..."
for existing in "$SKILLS_DIR"/*/; do
  [ -e "$existing" ] || continue
  skill_name=$(basename "$existing")
  if [ -L "$existing" ] && [ ! -d "$CODEX_SKILLS_SRC/$skill_name" ]; then
    rm "$existing"
    echo "  🗑  removed $skill_name"
  fi
done

# ── 5. Symlink each codex skill folder ───────────────────────────────────────
echo "🔗 Syncing Codex skills..."
for skill_dir in "$CODEX_SKILLS_SRC"/*/; do
  skill_name=$(basename "$skill_dir")

  # Only symlink folders that contain a SKILL.md
  if [ ! -f "$skill_dir/SKILL.md" ]; then
    continue
  fi

  target="$SKILLS_DIR/$skill_name"

  # Replace stale or outdated symlink
  if [ -L "$target" ] || [ -d "$target" ]; then
    rm -rf "$target"
  fi

  ln -s "$skill_dir" "$target"
  echo "  ✅ $skill_name"
done

echo ""
echo "✨ Done! Codex skills are live in $SKILLS_DIR"
echo ""
echo "Next steps:"
echo "  1. Copy codex/config.toml.example to ~/.codex/config.toml and fill in API keys"
echo "  2. Verify MCP connections: codex mcp list"
