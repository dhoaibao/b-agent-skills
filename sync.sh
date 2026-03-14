#!/usr/bin/env bash
# sync.sh — Bootstrap or update b-agent-skills on any Linux machine
# Usage:
#   First time : bash <(ssh git@github.com ...) OR clone manually then run ./sync.sh
#   Update     : ~/.b-agent-skills/sync.sh

set -euo pipefail

REPO="git@github-personal.com:dhoaibao/b-agent-skills.git"
LOCAL_REPO="$HOME/.b-agent-skills"
SKILLS_DIR="$HOME/.claude/skills"

# ── 1. Clone or update the repo ──────────────────────────────────────────────
if [ -d "$LOCAL_REPO/.git" ]; then
  echo "🔄 Updating b-agent-skills..."
  git -C "$LOCAL_REPO" pull --ff-only
else
  echo "📦 Cloning b-agent-skills..."
  git clone "$REPO" "$LOCAL_REPO"
fi

# ── 2. Ensure skills directory exists ────────────────────────────────────────
mkdir -p "$SKILLS_DIR"

# ── 3. Symlink each skill folder (skip non-skill files like sync.sh itself) ──
echo "🔗 Syncing skills..."
for skill_dir in "$LOCAL_REPO"/*/; do
  skill_name=$(basename "$skill_dir")

  # Only symlink folders that contain a SKILL.md
  if [ ! -f "$skill_dir/SKILL.md" ]; then
    continue
  fi

  target="$SKILLS_DIR/$skill_name"

  # Remove stale symlink or old folder if it exists
  if [ -L "$target" ] || [ -d "$target" ]; then
    rm -rf "$target"
  fi

  ln -s "$skill_dir" "$target"
  echo "  ✅ $skill_name"
done

echo ""
echo "✨ Done! Skills are live in $SKILLS_DIR"
