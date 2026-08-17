#!/usr/bin/env bash
# Install, synchronize, or uninstall the Claude Code b-agentic plugin.
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_URL="${B_AGENTIC_REPO:-https://github.com/dhoaibao/b-agentic.git}"
readonly LOCAL_REPO="${B_AGENTIC_DIR:-$HOME/.b-agentic}"
readonly CLAUDE_CONFIG="${B_AGENTIC_CLAUDE_CONFIG_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}}"
OPERATION=install
DRY_RUN=0
REPLACE_KERNEL=0
REF="${B_AGENTIC_REF:-}"
SOURCE_DIR=""

log() { printf '%s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }
usage() {
	cat >&2 <<'EOF'
usage: install.sh [--dry-run] [--sync|--update|--uninstall] [--replace-kernel] [--ref=<tag-or-sha>]

Claude Code is the only supported runtime. The installer never updates the
Claude Code executable and preserves unrelated files under its configuration root.
EOF
	exit 2
}

parse_args() {
	while [ "$#" -gt 0 ]; do
		case "$1" in
		--dry-run) DRY_RUN=1 ;;
		--sync) [ "$OPERATION" = install ] || die "lifecycle flags cannot be combined"; OPERATION=sync ;;
		--update) [ "$OPERATION" = install ] || die "lifecycle flags cannot be combined"; OPERATION=update ;;
		--uninstall) [ "$OPERATION" = install ] || die "lifecycle flags cannot be combined"; OPERATION=uninstall ;;
		--replace-kernel) REPLACE_KERNEL=1 ;;
		--ref=*) REF="${1#--ref=}"; [ -n "$REF" ] || die "empty source ref" ;;
		-h|--help) usage ;;
		*) die "unknown argument: $1" ;;
		esac
		shift
	done
	if [ "$OPERATION" = update ] && [ -n "$REF" ]; then die "--ref cannot be combined with --update"; fi
	if [ "$OPERATION" != install ] && [ "$REPLACE_KERNEL" -eq 1 ]; then die "--replace-kernel is install-only"; fi
}

check_dependencies() {
	command -v python3 >/dev/null 2>&1 || die "python3 is required"
	python3 - <<'PY' || die "Python 3.11+ is required"
import sys
raise SystemExit(0 if sys.version_info >= (3, 11) else 1)
PY
	if [ "$OPERATION" != uninstall ] && [ ! -d "$SOURCE_DIR" ]; then command -v git >/dev/null 2>&1 || die "git is required to fetch b-agentic"; fi
}

set_source() {
	SOURCE_DIR="$1"
	[ -d "$SOURCE_DIR/plugin" ] || die "missing Claude plugin source: $SOURCE_DIR/plugin"
	[ -f "$SOURCE_DIR/plugin/.claude-plugin/plugin.json" ] || die "missing Claude plugin manifest"
	[ -f "$SOURCE_DIR/plugin/settings.json" ] || die "missing Claude plugin settings"
	[ -f "$SOURCE_DIR/references/kernel.template.md" ] || die "missing kernel source"
	[ -f "$SOURCE_DIR/tooling/install/claude.py" ] || die "missing Claude installer helper"
}

prepare_source() {
	if [ -n "${B_AGENTIC_SOURCE_DIR:-}" ]; then
		set_source "$B_AGENTIC_SOURCE_DIR"
		return
	fi
	if [ -d "$SCRIPT_DIR/plugin" ] && [ -f "$SCRIPT_DIR/tooling/install/claude.py" ]; then
		set_source "$SCRIPT_DIR"
		return
	fi
	if [ "$OPERATION" = uninstall ] || [ "$OPERATION" = sync ]; then
		[ -d "$LOCAL_REPO/plugin" ] || return 1
		set_source "$LOCAL_REPO"
		return
	fi
	if [ "$OPERATION" = update ] && [ -d "$LOCAL_REPO/.git" ]; then
		log "Refreshing b-agentic source: $LOCAL_REPO"
		git -C "$LOCAL_REPO" fetch --all --tags --prune --quiet
		git -C "$LOCAL_REPO" pull --ff-only --quiet
		set_source "$LOCAL_REPO"
		return
	fi
	if [ -d "$LOCAL_REPO/plugin" ]; then
		set_source "$LOCAL_REPO"
		return
	fi
	command -v git >/dev/null 2>&1 || die "git is required to fetch b-agentic"
	mkdir -p "$(dirname "$LOCAL_REPO")"
	log "Cloning b-agentic source: $REPO_URL -> $LOCAL_REPO"
	git clone --quiet "$REPO_URL" "$LOCAL_REPO"
	if [ -n "$REF" ]; then git -C "$LOCAL_REPO" checkout --quiet "$REF"; fi
	set_source "$LOCAL_REPO"
}

manifest_path() { printf '%s\n' "$CLAUDE_CONFIG/b-agentic/install.json"; }

manifest_only_uninstall() {
	local manifest helper
	manifest="$(manifest_path)"
	[ -f "$manifest" ] || return 1
	helper="$CLAUDE_CONFIG/b-agentic/manifest_uninstall.py"
	if [ -f "$helper" ]; then
		python3 "$helper" uninstall --manifest "$manifest"
		return
	fi
	if [ -n "$SOURCE_DIR" ] && [ -f "$SOURCE_DIR/tooling/install/claude.py" ]; then
		python3 "$SOURCE_DIR/tooling/install/claude.py" uninstall --manifest "$manifest"
		return
	fi
	return 1
}

main() {
	parse_args "$@"
	if [ "$OPERATION" = uninstall ] && [ ! -d "$LOCAL_REPO/plugin" ] && [ ! -d "$SCRIPT_DIR/plugin" ] && [ -z "${B_AGENTIC_SOURCE_DIR:-}" ]; then
		if manifest_only_uninstall; then exit 0; fi
		die "b-agentic source and manifest uninstaller are unavailable"
	fi
	prepare_source || { [ "$OPERATION" = uninstall ] && manifest_only_uninstall && exit 0; die "b-agentic source is not installed at $LOCAL_REPO"; }
	check_dependencies
	if [ "$OPERATION" = uninstall ]; then
		python3 "$SOURCE_DIR/tooling/install/claude.py" uninstall --manifest "$(manifest_path)"
		exit 0
	fi
	python3 "$SOURCE_DIR/tooling/generate/registry_sync.py" --check || die "generated Claude assets are stale; run registry_sync.py"
	if [ "$OPERATION" = sync ] && [ ! -f "$(manifest_path)" ]; then
		die "cannot sync before b-agentic is installed"
	fi
	args=(install --source "$SOURCE_DIR" --config "$CLAUDE_CONFIG")
	[ "$DRY_RUN" -eq 1 ] && args+=(--dry-run)
	[ "$REPLACE_KERNEL" -eq 1 ] && args+=(--replace-kernel)
	python3 "$SOURCE_DIR/tooling/install/claude.py" "${args[@]}"
	if [ "$DRY_RUN" -eq 1 ]; then
		log "Next: rerun without --dry-run to apply the plan; Claude Code itself was not changed."
	else
		# Make manifest-only uninstall possible without the source checkout.
		mkdir -p "$CLAUDE_CONFIG/b-agentic"
		cp "$SOURCE_DIR/tooling/install/claude.py" "$CLAUDE_CONFIG/b-agentic/manifest_uninstall.py"
		if [ "$OPERATION" = sync ]; then
			log "b-agentic Claude plugin and managed settings synchronized."
		else
			log "Next: start or reload Claude Code with the b-agentic plugin enabled."
		fi
	fi
}

main "$@"
