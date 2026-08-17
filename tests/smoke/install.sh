#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEMP_HOME="$(mktemp -d "${TMPDIR:-/tmp}/b-agentic-claude-smoke.XXXXXX")"
trap 'rm -rf "$TEMP_HOME"' EXIT
HOME="$TEMP_HOME"
export HOME
CONFIG="$HOME/.claude"
mkdir -p "$CONFIG/skills/user-owned"
printf '%s\n' '# user instructions' > "$CONFIG/CLAUDE.md"
printf '%s\n' '# user skill' > "$CONFIG/skills/user-owned/SKILL.md"
printf '%s\n' '{"enabledPlugins":{"user@local":true},"theme":"user-theme"}' > "$CONFIG/settings.json"

B_AGENTIC_CLAUDE_CONFIG_DIR="$CONFIG" B_AGENTIC_SOURCE_DIR="$ROOT_DIR" bash "$ROOT_DIR/install.sh"
[ -f "$CONFIG/plugins/b-agentic/.claude-plugin/plugin.json" ]
[ -f "$CONFIG/plugins/b-agentic/hooks/hooks.json" ]
[ -f "$CONFIG/plugins/b-agentic/hooks/b-agentic-policy.py" ]
[ -f "$CONFIG/plugins/b-agentic/.mcp.json" ]
grep -q '# user instructions' "$CONFIG/CLAUDE.md"
grep -q 'b-agentic - Claude Code Workflow Kernel' "$CONFIG/CLAUDE.md"
grep -q 'user@local' "$CONFIG/settings.json"
grep -q '"b-agentic@local"' "$CONFIG/settings.json"
grep -q 'crossSessionInbound.*accept' "$CONFIG/settings.json"
grep -q 'git reset --hard' "$CONFIG/settings.json"
grep -q 'b-agentic-status-line.py' "$CONFIG/settings.json"
[ -f "$CONFIG/skills/user-owned/SKILL.md" ]
HOME="$HOME" python3 "$ROOT_DIR/tooling/validate/skill_doctor.py" --home "$HOME" >/dev/null

# Conflicting user-owned scalar settings fail closed without partial installation.
CONFLICT_CONFIG="$TEMP_HOME/conflict/.claude"
mkdir -p "$CONFLICT_CONFIG"
printf '%s\n' '{"crossSessionInbound":"reject","statusLine":{"type":"command","command":"user-status"}}' > "$CONFLICT_CONFIG/settings.json"
cp "$CONFLICT_CONFIG/settings.json" "$CONFLICT_CONFIG/settings.before.json"
if B_AGENTIC_CLAUDE_CONFIG_DIR="$CONFLICT_CONFIG" B_AGENTIC_SOURCE_DIR="$ROOT_DIR" bash "$ROOT_DIR/install.sh" > "$TEMP_HOME/conflict.log" 2>&1; then
    echo 'expected conflicting settings install to fail' >&2
    exit 1
fi
grep -q 'refusing to overwrite user-owned Claude setting' "$TEMP_HOME/conflict.log"
cmp -s "$CONFLICT_CONFIG/settings.json" "$CONFLICT_CONFIG/settings.before.json"
[ ! -e "$CONFLICT_CONFIG/plugins/b-agentic" ]
[ ! -e "$CONFLICT_CONFIG/CLAUDE.md" ]

# Sync deploys changed source assets into the installed plugin and keeps user files.
printf '%s\n' 'stale plugin file' > "$CONFIG/plugins/b-agentic/stale.txt"
SOURCE_COPY="$TEMP_HOME/source-copy"
mkdir -p "$SOURCE_COPY"
cp -a "$ROOT_DIR"/. "$SOURCE_COPY"/
printf '%s\n' '<!-- sync smoke marker -->' >> "$SOURCE_COPY/plugin/agents/b-worker.md"
B_AGENTIC_CLAUDE_CONFIG_DIR="$CONFIG" B_AGENTIC_SOURCE_DIR="$SOURCE_COPY" bash "$ROOT_DIR/install.sh" --sync
grep -q 'sync smoke marker' "$CONFIG/plugins/b-agentic/agents/b-worker.md"
[ ! -e "$CONFIG/plugins/b-agentic/stale.txt" ]
[ -f "$CONFIG/skills/user-owned/SKILL.md" ]

# Manifest-only uninstall works from a bootstrap copy when the source checkout is absent.
cp "$ROOT_DIR/install.sh" "$TEMP_HOME/bootstrap.sh"
B_AGENTIC_CLAUDE_CONFIG_DIR="$CONFIG" B_AGENTIC_DIR="$TEMP_HOME/no-source" bash "$TEMP_HOME/bootstrap.sh" --uninstall > "$TEMP_HOME/uninstall.log"
grep -q 'Manifest-only uninstall complete for claude-code' "$TEMP_HOME/uninstall.log"
grep -q '# user instructions' "$CONFIG/CLAUDE.md"
! grep -q 'b-agentic - Claude Code Workflow Kernel' "$CONFIG/CLAUDE.md"
grep -q 'user-theme' "$CONFIG/settings.json"
! grep -q 'b-agentic@local' "$CONFIG/settings.json"
! grep -q 'crossSessionInbound' "$CONFIG/settings.json"
! grep -q 'git reset --hard' "$CONFIG/settings.json"
! grep -q 'b-agentic-status-line.py' "$CONFIG/settings.json"
[ -f "$CONFIG/skills/user-owned/SKILL.md" ]
[ ! -e "$CONFIG/plugins/b-agentic" ]
printf '%s\n' 'Claude isolated install/uninstall smoke passed.'
