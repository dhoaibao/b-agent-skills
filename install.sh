#!/usr/bin/env bash
# install.sh - Bootstrap or update b-agentic
# Bootstraps source sync, then installs or refreshes Pi-managed assets through
# the shared installer core.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/dhoaibao/b-agentic/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/dhoaibao/b-agentic/main/install.sh | bash -s -- --dry-run
#   curl -fsSL https://raw.githubusercontent.com/dhoaibao/b-agentic/main/install.sh | bash -s -- --uninstall
#   curl -fsSL https://raw.githubusercontent.com/dhoaibao/b-agentic/main/install.sh | bash -s -- --ref=<tag-or-sha>
#   ~/.b-agentic/install.sh --sync
#   ~/.b-agentic/install.sh --update

set -euo pipefail
# Variables shared with the sourced installer core are intentionally defined
# here even when ShellCheck analyzes this entrypoint in isolation.

readonly REPO_URL="${B_AGENTIC_REPO:-https://github.com/dhoaibao/b-agentic.git}"
readonly LOCAL_REPO="${B_AGENTIC_DIR:-$HOME/.b-agentic}"
REF="${B_AGENTIC_REF:-}"
TIMESTAMP="$(date +%Y%m%d%H%M%S)"
# shellcheck disable=SC2034
readonly TIMESTAMP

DRY_RUN_VALUE="${B_AGENTIC_DRY_RUN:-N}"
REPLACE_MEMORY_VALUE="${B_AGENTIC_REPLACE_MEMORY:-}"
UNINSTALL_VALUE="${B_AGENTIC_UNINSTALL:-N}"
PROMPT_API_KEYS_VALUE="${B_AGENTIC_PROMPT_API_KEYS:-auto}"
readonly PI_NAME="Pi"
# Bundled dependencies are mandatory and are installed without prompts.
OPERATION="install"

SOURCE_DIR="$LOCAL_REPO"
SKILLS_SRC="$SOURCE_DIR/skills"
REFERENCES_SRC="$SOURCE_DIR/references"
TEMPLATES_SRC="$SOURCE_DIR/pi/configs"
KERNEL_SRC="$SOURCE_DIR/references/kernel.template.md"
DRY_RUN_SOURCE_DIR=""
UI_ENABLED=0
UI_SUPPRESS_LOGS=0
UI_STAGE_CURRENT=0
UI_STAGE_TOTAL=0
UI_STAGE_ACTIVE=0
UI_STAGE_LABEL=""
readonly UI_STAGE_BAR_WIDTH=20
readonly UI_STAGE_LABEL_WIDTH=52
readonly UI_STAGE_LINE_WIDTH=82
# shellcheck disable=SC2034
INSTALL_PI_CLI_DECISION=""

ui_init() {
	if [ -t 1 ] && [ "${TERM:-}" != "dumb" ]; then
		UI_ENABLED=1
	else
		UI_ENABLED=0
	fi
}

ui_tty_enabled() {
	[ "${UI_ENABLED:-0}" -eq 1 ] && [ -t 1 ] && [ "${TERM:-}" != "dumb" ]
}

ui_clear_stage() {
	ui_tty_enabled || return 0
	printf '\r%*s\r' "$UI_STAGE_LINE_WIDTH" ''
}

ui_render_stage() {
	ui_tty_enabled || return 0
	local current="$1" total="$2" label="$3" state="${4:-running}"
	local filled=0 bar="" i
	if [ "$total" -gt 0 ]; then
		filled=$(((current - 1) * UI_STAGE_BAR_WIDTH / total))
	fi
	[ "$filled" -lt 0 ] && filled=0
	[ "$filled" -gt "$UI_STAGE_BAR_WIDTH" ] && filled="$UI_STAGE_BAR_WIDTH"
	if [ "$state" = "done" ]; then
		filled="$UI_STAGE_BAR_WIDTH"
	fi
	for ((i = 0; i < filled; i++)); do bar+='='; done
	for ((i = filled; i < UI_STAGE_BAR_WIDTH; i++)); do bar+='-'; done
	case "$state" in
	failed) bar="!!!!!!!!!!!!!!!!!!!!" ;;
	done) bar="====================" ;;
	esac
	if [ "${#label}" -gt "$UI_STAGE_LABEL_WIDTH" ]; then
		label="${label:0:UI_STAGE_LABEL_WIDTH-3}..."
	fi
	printf -v label '%-*s' "$UI_STAGE_LABEL_WIDTH" "$label"
	if [ "$total" -gt 0 ]; then
		printf '\r[%s/%s] [%s] %s' "$current" "$total" "$bar" "$label"
	else
		printf '\r[%s] [%s] %s' "$current" "$bar" "$label"
	fi
}

ui_set_stage_total() {
	UI_STAGE_CURRENT=0
	UI_STAGE_TOTAL="${1:-0}"
	if ui_tty_enabled && [ "$UI_STAGE_ACTIVE" -eq 1 ]; then
		ui_clear_stage
		UI_STAGE_ACTIVE=0
	fi
}

ui_stage_start() {
	local label="$1"
	UI_STAGE_CURRENT=$((UI_STAGE_CURRENT + 1))
	UI_STAGE_LABEL="$label"
	UI_STAGE_ACTIVE=1
	if ui_tty_enabled; then
		ui_render_stage "$UI_STAGE_CURRENT" "$UI_STAGE_TOTAL" "$label"
	elif [ "$UI_STAGE_TOTAL" -gt 0 ]; then
		printf '[%s/%s] %s\n' "$UI_STAGE_CURRENT" "$UI_STAGE_TOTAL" "$label"
	else
		printf '[%s] %s\n' "$UI_STAGE_CURRENT" "$label"
	fi
}

ui_stage_finish() {
	local rc="${1:-0}"
	if [ "$UI_STAGE_ACTIVE" -eq 1 ] && ui_tty_enabled; then
		ui_clear_stage
		if [ "$UI_STAGE_TOTAL" -gt 0 ]; then
			if [ "$rc" -eq 0 ]; then
				printf '[%s/%s] %s\n' "$UI_STAGE_CURRENT" "$UI_STAGE_TOTAL" "$UI_STAGE_LABEL"
			else
				printf '[%s/%s] failed: %s\n' "$UI_STAGE_CURRENT" "$UI_STAGE_TOTAL" "$UI_STAGE_LABEL"
			fi
		else
			if [ "$rc" -eq 0 ]; then
				printf '[%s] %s\n' "$UI_STAGE_CURRENT" "$UI_STAGE_LABEL"
			else
				printf '[%s] failed: %s\n' "$UI_STAGE_CURRENT" "$UI_STAGE_LABEL"
			fi
		fi
	fi
	UI_STAGE_ACTIVE=0
	UI_STAGE_LABEL=""
	return "$rc"
}

ui_pause_stage() {
	ui_tty_enabled || return 0
	[ "$UI_STAGE_ACTIVE" -eq 1 ] || return 0
	ui_clear_stage
}

ui_resume_stage() {
	ui_tty_enabled || return 0
	[ "$UI_STAGE_ACTIVE" -eq 1 ] || return 0
	ui_render_stage "$UI_STAGE_CURRENT" "$UI_STAGE_TOTAL" "$UI_STAGE_LABEL"
}

log() {
	[ "${UI_SUPPRESS_LOGS:-0}" -eq 1 ] && return 0
	printf '%s\n' "$*"
}

summary_log() {
	ui_pause_stage
	printf '%s\n' "$*"
	ui_resume_stage
}

warn() {
	ui_pause_stage
	printf 'warning: %s\n' "$*" >&2
	ui_resume_stage
}

die() {
	ui_pause_stage
	printf 'error: %s\n' "$*" >&2
	exit 1
}

run_ui_stage() {
	local label="$1"
	shift
	local rc=0 previous_suppress="${UI_SUPPRESS_LOGS:-0}"

	ui_stage_start "$label"
	UI_SUPPRESS_LOGS=1
	if "$@"; then
		rc=0
	else
		rc=$?
	fi
	UI_SUPPRESS_LOGS="$previous_suppress"
	ui_stage_finish "$rc"
	return "$rc"
}

cleanup() {
	if [ -n "$DRY_RUN_SOURCE_DIR" ]; then
		rm -rf "$DRY_RUN_SOURCE_DIR"
	fi
}

trap cleanup EXIT

yes_value() {
	case "${1:-}" in
	y | Y | yes | YES | Yes | true | TRUE | 1) return 0 ;;
	*) return 1 ;;
	esac
}

dry_run_enabled() {
	yes_value "$DRY_RUN_VALUE"
}

replace_memory_enabled() {
	yes_value "$REPLACE_MEMORY_VALUE"
}

uninstall_enabled() {
	yes_value "$UNINSTALL_VALUE"
}


can_prompt_api_keys() {
	! dry_run_enabled || return 1
	case "$PROMPT_API_KEYS_VALUE" in
	n | N | no | NO | No | false | FALSE | 0) return 1 ;;
	auto | AUTO | Auto | y | Y | yes | YES | Yes | true | TRUE | 1) ;;
	*) die "invalid B_AGENTIC_PROMPT_API_KEYS value: $PROMPT_API_KEYS_VALUE" ;;
	esac
	[ -r /dev/tty ] && [ -w /dev/tty ]
}

run_cmd() {
	if dry_run_enabled; then
		printf '[dry-run] %s\n' "$*" >&2
		return 0
	fi
	"$@"
}

require_bin() {
	command -v "$1" >/dev/null 2>&1 || die "required binary not found: $1"
}

require_python_311() {
	python3 - <<'PY' >/dev/null 2>&1 || die "Python 3.11+ is required."
import sys
sys.exit(0 if sys.version_info >= (3, 11) else 1)
PY
}

check_dependencies() {
	local dependency_label="curl, git, python3"

	if command -v curl >/dev/null 2>&1; then
		:
	else
		warn "curl not found; install with the documented curl command will not work on this machine"
		dependency_label="git, python3"
	fi

	# git is needed only when the installer must fetch or update its source checkout.
	if [ "$OPERATION" = "update" ]; then
		dependency_label="curl, python3, local source"
	elif uninstall_enabled && { [ -d "$LOCAL_REPO/.git" ] || [ -d "$LOCAL_REPO/skills" ]; }; then
		dependency_label="${dependency_label}, local source"
	else
		require_bin git
	fi

	# Runtime installers use Python for structured config and manifest updates.
	require_bin python3
	require_python_311
	log "Using $dependency_label"
}

set_operation() {
	local next="$1"
	if [ "$OPERATION" != "install" ]; then
		die "--sync and --update cannot be combined"
	fi
	OPERATION="$next"
}

parse_args() {
	while [ "$#" -gt 0 ]; do
		case "$1" in
		--dry-run)
			DRY_RUN_VALUE=Y
			;;
		--replace-memory)
			REPLACE_MEMORY_VALUE=Y
			;;
		--preserve-memory)
			REPLACE_MEMORY_VALUE=N
			;;
		--uninstall)
			UNINSTALL_VALUE=Y
			;;
		--sync)
			set_operation "sync"
			;;
		--update)
			set_operation "update"
			;;
		--prompt-api-keys)
			PROMPT_API_KEYS_VALUE=Y
			;;
		--no-prompt-api-keys)
			PROMPT_API_KEYS_VALUE=N
			;;
		--runtime=* | --runtime)
			die "b-agentic installs Pi only; remove the --runtime option"
			;;
		--ref=*)
			REF="${1#--ref=}"
			[ -n "$REF" ] || die "invalid ref: empty"
			;;
		*)
			die "unknown argument: $1"
			;;
		esac
		shift
	done
}

validate_ref() {
	[ -n "$REF" ] || return 0
	[ "$OPERATION" != "update" ] || die "--ref cannot be used with --update"
	case "$REF" in
	-*) die "invalid ref: $REF (must not start with -)" ;;
	esac
}

validate_operation() {
	if uninstall_enabled && [ "$OPERATION" != "install" ]; then
		die "--uninstall cannot be combined with --sync or --update"
	fi
}

set_source_dir() {
	SOURCE_DIR="$1"
	SKILLS_SRC="$SOURCE_DIR/skills"
	REFERENCES_SRC="$SOURCE_DIR/references"
	TEMPLATES_SRC="$SOURCE_DIR/pi/configs"
	KERNEL_SRC="$SOURCE_DIR/references/kernel.template.md"
}

validate_pi_source_layout() {
	[ -d "$SKILLS_SRC" ] || die "missing source directory: $SKILLS_SRC"
	[ -f "$SKILLS_SRC/registry.yaml" ] || die "missing skill registry: $SKILLS_SRC/registry.yaml"
	[ -d "$REFERENCES_SRC" ] || die "missing source directory: $REFERENCES_SRC"
	[ -f "$REFERENCES_SRC/capabilities.yaml" ] || die "missing capability contract: $REFERENCES_SRC/capabilities.yaml"
	[ -d "$TEMPLATES_SRC" ] || die "missing Pi config directory: $TEMPLATES_SRC"
	[ -f "$KERNEL_SRC" ] || die "missing Pi kernel source: $KERNEL_SRC"
	[ -f "$SOURCE_DIR/pi/scripts/install.sh" ] || die "missing Pi installer: $SOURCE_DIR/pi/scripts/install.sh"
	[ -f "$SOURCE_DIR/pi/extensions/b-agentic-support/capabilities.ts" ] || die "missing generated capability module: $SOURCE_DIR/pi/extensions/b-agentic-support/capabilities.ts"
	[ -f "$SOURCE_DIR/tooling/install/common.sh" ] || die "missing installer core: $SOURCE_DIR/tooling/install/common.sh"
	python3 - "$SKILLS_SRC/registry.yaml" "$SKILLS_SRC" <<'PY' || die "Pi skill payload does not match registry: $SKILLS_SRC"
import json
import sys
from pathlib import Path

registry_path, skills_path = map(Path, sys.argv[1:])
registry = json.loads(registry_path.read_text())
skills = registry.get("skills")
if not isinstance(skills, list):
    raise SystemExit("invalid skills registry")

names = []
for skill in skills:
    name = skill.get("name") if isinstance(skill, dict) else None
    if not isinstance(name, str) or not name:
        raise SystemExit("invalid skill name in registry")
    names.append(name)

missing = [name for name in names if not (skills_path / name / "SKILL.md").is_file()]
if missing:
    raise SystemExit(f"missing generated skill payloads: {', '.join(sorted(missing))}")
PY
}

sync_source() {
	require_bin git
	require_bin python3

	if dry_run_enabled; then
		if [ -d "$LOCAL_REPO/.git" ] || [ -d "$LOCAL_REPO/skills" ]; then
			log "Dry-run source: $LOCAL_REPO (no fetch/pull)"
			set_source_dir "$LOCAL_REPO"
		else
			DRY_RUN_SOURCE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/b-agentic-dry-run.XXXXXX")"
			log "Dry-run source clone: $REPO_URL -> $DRY_RUN_SOURCE_DIR"
			git clone --quiet "$REPO_URL" "$DRY_RUN_SOURCE_DIR"
			if [ -n "$REF" ]; then
				git -C "$DRY_RUN_SOURCE_DIR" checkout --quiet "$REF"
			fi
			set_source_dir "$DRY_RUN_SOURCE_DIR"
		fi
	elif [ -d "$LOCAL_REPO/.git" ]; then
		log "Updating source: $LOCAL_REPO"
		git -C "$LOCAL_REPO" fetch --all --tags --prune --quiet
		if [ -n "$REF" ]; then
			git -C "$LOCAL_REPO" checkout --quiet "$REF"
		else
			git -C "$LOCAL_REPO" pull --ff-only --quiet
		fi
		set_source_dir "$LOCAL_REPO"
	else
		log "Cloning source: $REPO_URL -> $LOCAL_REPO"
		mkdir -p "$(dirname "$LOCAL_REPO")"
		git clone --quiet "$REPO_URL" "$LOCAL_REPO"
		if [ -n "$REF" ]; then
			git -C "$LOCAL_REPO" checkout --quiet "$REF"
		fi
		set_source_dir "$LOCAL_REPO"
	fi

	validate_pi_source_layout
}

prepare_source() {
	if [ "$OPERATION" = "update" ] || { uninstall_enabled && { [ -d "$LOCAL_REPO/.git" ] || [ -d "$LOCAL_REPO/skills" ]; }; }; then
		[ -d "$LOCAL_REPO/skills" ] || die "b-agentic source is not installed at $LOCAL_REPO; run the curl installer first"
		set_source_dir "$LOCAL_REPO"
		validate_pi_source_layout
		return 0
	fi

	sync_source
}

install_app() {
	if [ "$OPERATION" = "update" ]; then
		log "Using installed b-agentic source without pulling changes"
		prepare_source
		return 0
	fi

	if uninstall_enabled; then
		log "Preparing uninstall source"
		prepare_source
		log "Uninstall source ready"
		return 0
	fi

	if [ -d "$LOCAL_REPO/.git" ] || [ -d "$LOCAL_REPO/skills" ]; then
		warn "b-agentic is already installed; running upgrade"
	else
		log "b-agentic is not installed; downloading installer source"
	fi

	prepare_source
	log "Installer source ready"
}

manifest_only_records() {
	python3 - <<'PY'
import json
import os
from pathlib import Path

home = Path.home()
candidates = []
candidates.extend(home.glob(".*/b-agentic/install.json"))
# Nested agent homes (e.g. ~/.pi/agent/b-agentic/install.json)
candidates.extend(home.glob(".*/*/b-agentic/install.json"))
candidates.extend((home / ".config").glob("*/b-agentic/install.json"))
candidates.extend((home / ".local" / "share").glob("*/b-agentic/install.json"))
candidates.extend((home / "Library" / "Application Support").glob("*/b-agentic/install.json"))
candidates.extend((home / ".gemini").glob("*/b-agentic/install.json"))
candidates.append(home / ".pi" / "agent" / "b-agentic" / "install.json")

allowed_roots = [home.resolve()]

seen = set()
for path in candidates:
    try:
        resolved = path.resolve()
        if not any(resolved.is_relative_to(root) for root in allowed_roots):
            continue
    except Exception:
        continue
    if resolved in seen or not path.is_file():
        continue
    seen.add(resolved)
    try:
        data = json.loads(path.read_text())
    except Exception:
        continue
    suite = data.get("suite")
    if suite is not None and suite != "b-agentic":
        continue
    runtime = data.get("runtime")
    if isinstance(runtime, str) and runtime:
        print(f"{runtime}\t{path}")
PY
}

manifest_only_uninstall_one() {
	local runtime_name="$1" manifest_path="$2"
	[ -f "$manifest_path" ] || return 1
	local installed_script
	installed_script="$(dirname "$manifest_path")/tooling/install/manifest_uninstall.py"
	if [ -f "$installed_script" ]; then
		run_cmd python3 "$installed_script" "$manifest_path"
		return $?
	fi
	if [ -n "${SOURCE_DIR:-}" ] && [ -f "$SOURCE_DIR/tooling/install/manifest_uninstall.py" ]; then
		run_cmd python3 "$SOURCE_DIR/tooling/install/manifest_uninstall.py" "$manifest_path"
		return $?
	fi
	die "manifest-only uninstall for $runtime_name requires $installed_script; reinstall once or restore the source checkout to uninstall safely"
}

try_manifest_only_uninstall() {
	uninstall_enabled || return 1
	{ [ -d "$LOCAL_REPO/.git" ] || [ -d "$LOCAL_REPO/skills" ]; } && return 1

	local product_name manifest_path
	while IFS=$'\t' read -r product_name manifest_path; do
		[ "$product_name" = "pi" ] || continue
		[ -f "$manifest_path" ] || continue
		manifest_only_uninstall_one "$PI_NAME" "$manifest_path"
		return $?
	done < <(manifest_only_records)
	return 1
}

prepare_user_bin_paths() {
	local -a candidates=()
	local path index

	[ -n "${UV_INSTALL_DIR:-}" ] && candidates+=("$UV_INSTALL_DIR")
	[ -n "${UV_TOOL_BIN_DIR:-}" ] && candidates+=("$UV_TOOL_BIN_DIR")
	[ -n "${XDG_BIN_HOME:-}" ] && candidates+=("$XDG_BIN_HOME")
	if [ -n "${XDG_DATA_HOME:-}" ]; then
		candidates+=("${XDG_DATA_HOME%/}/../bin")
	fi
	candidates+=("$HOME/.local/bin" "$HOME/.cargo/bin" "$HOME/.bun/bin")

	for ((index = ${#candidates[@]} - 1; index >= 0; index--)); do
		path="${candidates[$index]}"
		[ -n "$path" ] || continue
		case ":${PATH:-}:" in
		*":$path:"*) ;;
		*) PATH="$path:${PATH:-}" ;;
		esac
	done
	export PATH
}

install_rtk() {
	if command -v rtk >/dev/null 2>&1; then
		if dry_run_enabled; then
			printf '[dry-run] curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh\n' >&2
			return 0
		fi
		log "RTK already installed; upgrading"
		if curl -fsSL "https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh" | sh; then
			log "RTK upgraded"
		else
			warn "RTK upgrade failed"
			return 1
		fi
		return 0
	fi

	# Missing RTK is installed automatically; no TTY or confirmation is needed.

	if dry_run_enabled; then
		printf '[dry-run] curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh\n' >&2
		return 0
	fi

	log "Installing RTK"
	if curl -fsSL "https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh" | sh; then
		if command -v rtk >/dev/null 2>&1; then
			log "RTK installed"
		else
			die "RTK installed but not found on PATH; b-agentic requires RTK"
		fi
	else
		die "RTK installation failed; b-agentic requires RTK"
	fi
}

update_rtk() {
	log "Updating RTK"
	if ! command -v rtk >/dev/null 2>&1; then
		install_rtk
		return $?
	fi
	if dry_run_enabled; then
		printf '[dry-run] curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh\n' >&2
	elif curl -fsSL "https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh" | sh; then
		log "RTK updated"
	else
		warn "RTK update failed"
		return 1
	fi
}

update_codegraph() {
	log "Updating CodeGraph"
	if ! command -v codegraph >/dev/null 2>&1; then
		install_codegraph
		return $?
	fi
	if dry_run_enabled; then
		printf '[dry-run] CODEGRAPH_NO_INSTALL_REFRESH=1 codegraph upgrade\n' >&2
	elif CODEGRAPH_NO_INSTALL_REFRESH=1 codegraph upgrade; then
		log "CodeGraph updated"
	else
		warn "CodeGraph update failed"
		return 1
	fi
}

install_bun() {
	if command -v bun >/dev/null 2>&1; then
		if dry_run_enabled; then printf '[dry-run] bun upgrade\n' >&2; return 0; fi
		log "Updating Bun"
		bun upgrade || return 1
		return 0
	fi
	if dry_run_enabled; then
		printf '[dry-run] curl -fsSL https://bun.sh/install | bash\n' >&2
		return 0
	fi
	log "Installing Bun"
	curl -fsSL https://bun.sh/install | bash || return 1
	export PATH="$HOME/.bun/bin:$PATH"
	command -v bunx >/dev/null 2>&1 || { warn "Bun installed but bunx is not on PATH"; return 1; }
}

run_parallel_chains() {
	local log_dir
	log_dir="$(mktemp -d "${TMPDIR:-/tmp}/b-agentic-chains.XXXXXX")"
	local -a pids=() pid_indexes=() chains=() logs=() statuses=()
	local chain pid index position chain_index status rc=0
	for chain in "$@"; do
		index=${#chains[@]}; chains+=("$chain"); logs+=("$log_dir/$index.log")
		(
			# shellcheck disable=SC2034
			UI_HIDE_STAGES=1
			UI_SUPPRESS_LOGS=1
			"$chain"
		) >"${logs[$index]}" 2>&1 &
		pids+=("$!")
		pid_indexes+=("$index")
		if [ "${#pids[@]}" -ge 3 ]; then
			for position in "${!pids[@]}"; do
				pid="${pids[$position]}"
				chain_index="${pid_indexes[$position]}"
				if wait "$pid"; then
					statuses[chain_index]=0
				else
					status=$?
					statuses[chain_index]="$status"
					if [ "$rc" -eq 0 ] || [ "$status" -eq 2 ]; then rc="$status"; fi
				fi
			done
			pids=()
			pid_indexes=()
		fi
	done
	for position in "${!pids[@]}"; do
		pid="${pids[$position]}"
		chain_index="${pid_indexes[$position]}"
		if wait "$pid"; then
			statuses[chain_index]=0
		else
			status=$?
			statuses[chain_index]="$status"
			if [ "$rc" -eq 0 ] || [ "$status" -eq 2 ]; then rc="$status"; fi
		fi
	done
	if ui_tty_enabled && [ "$UI_STAGE_ACTIVE" -eq 1 ]; then
		ui_stage_finish "$rc"
	fi
	if dry_run_enabled; then
		for index in "${!chains[@]}"; do
			cat "${logs[$index]}"
		done
	else
		for index in "${!chains[@]}"; do
			awk '/^(warning:|b-agentic .* complete for Pi|Installed:|Planned:|Manifest:|Readiness:|Attention:|  [[:alnum:]_-]+:|Next:)/ { print }' "${logs[$index]}"
		done
	fi
	if [ "$rc" -ne 0 ]; then
		for index in "${!chains[@]}"; do
			if [ "${statuses[$index]:-0}" -ne 0 ]; then
				printf 'Dependency chain failed: %s\n' "${chains[$index]}" >&2
				if [ -s "${logs[$index]}" ]; then cat "${logs[$index]}" >&2; fi
			fi
		done
	fi
	rm -rf "$log_dir"
	return "$rc"
}

dependency_install_chain() {
	install_rtk
}

bun_install_chain() {
	install_bun
}

update_tooling() {
	set_install_stage_total 3
	run_parallel_chains update_rtk update_codegraph bun_install_chain
}

install_codegraph() {
	if command -v codegraph >/dev/null 2>&1; then
		if dry_run_enabled; then
			printf '[dry-run] CODEGRAPH_NO_INSTALL_REFRESH=1 codegraph upgrade\n' >&2
			return 0
		fi
		log "CodeGraph already installed; upgrading"
		if CODEGRAPH_NO_INSTALL_REFRESH=1 codegraph upgrade; then
			log "CodeGraph upgraded"
		else
			warn "CodeGraph upgrade failed"
			return 1
		fi
		return 0
	fi

	if dry_run_enabled; then
		printf '[dry-run] curl -fsSL https://raw.githubusercontent.com/colbymchenry/codegraph/main/install.sh | sh\n' >&2
		return 0
	fi

	log "Installing CodeGraph"
	if curl -fsSL https://raw.githubusercontent.com/colbymchenry/codegraph/main/install.sh | sh; then
		if command -v codegraph >/dev/null 2>&1; then
			log "CodeGraph installed"
		else
			warn "CodeGraph installed but not found on PATH"
			return 1
		fi
	else
		warn "CodeGraph installation failed"
		return 1
	fi
}

source_installer_core() {
	local common_src="$SOURCE_DIR/tooling/install/common.sh"
	[ -f "$common_src" ] || die "missing installer core: $common_src"
	# shellcheck disable=SC1090
	source "$common_src"
}

load_pi_installer() {
	local pi_script="$SOURCE_DIR/pi/scripts/install.sh"
	[ -f "$pi_script" ] || die "missing Pi installer: $pi_script"
	# shellcheck disable=SC1090
	source "$pi_script"
}

load_installer_sources() {
	source_installer_core
	validate_pi_source_layout
	load_pi_installer
}

main() {
	local rc=0

	ui_init
	parse_args "$@"
	validate_operation
	validate_ref

	if try_manifest_only_uninstall; then
		return 0
	fi

	ui_set_stage_total 5
	run_ui_stage "Checking prerequisites" check_dependencies || return 1
	run_ui_stage "Preparing source" install_app || return 1
	run_ui_stage "Loading Pi installer" load_installer_sources || return 1
	prepare_user_bin_paths
	run_ui_stage "Checking optional shell tooling" install_shell_tools || return 1

	if uninstall_enabled; then
		set +e
		(
			set -e
			pi_uninstall
		)
		rc=$?
		set -e
		return "$rc"
	fi

	if [ "$OPERATION" = "install" ]; then
		run_ui_stage "Installing dependencies and Pi" run_parallel_chains dependency_install_chain install_codegraph bun_install_chain pi_install || return 1
	elif [ "$OPERATION" = "update" ]; then
		run_ui_stage "Updating dependencies and Pi" run_parallel_chains update_tooling pi_update || return 1
	fi

	if [ "$OPERATION" = "sync" ]; then
		set +e
		pi_sync
		rc=$?
		set -e
		[ "$rc" -eq 0 ] && summary_log "b-agentic sync complete for Pi"
		return "$rc"
	fi
	if [ "$OPERATION" = "update" ]; then
		summary_log "b-agentic update complete for Pi"
	fi
	return 0
}

main "$@"
