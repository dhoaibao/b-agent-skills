# Sourced by install.sh — do not run directly.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
	echo "error: this script is sourced by install.sh" >&2
	exit 1
fi

readonly RUNTIME_UNINSTALL_LABEL="Pi personal config"
readonly RUNTIME_PRESERVE_LABEL="Pi"
readonly PI_AGENT_DIR="${B_AGENTIC_PI_AGENT_DIR:-$HOME/.pi/agent}"
readonly METADATA_DIR="$PI_AGENT_DIR/b-agentic"
readonly BACKUPS_DIR="$METADATA_DIR/backups"
readonly SKILLS_DST="$PI_AGENT_DIR/skills"
readonly SKILLS_SNAPSHOT_DST="$METADATA_DIR/skills"
readonly KERNEL_DST="$PI_AGENT_DIR/AGENTS.md"
readonly KERNEL_SNAPSHOT_DST="$METADATA_DIR/AGENTS.md"
readonly REFERENCES_DST="$METADATA_DIR/references"
readonly TEMPLATES_DST="$METADATA_DIR/templates"
readonly MANIFEST_DST="$METADATA_DIR/install.json"
readonly MCP_CONFIG_DST="${B_AGENTIC_PI_MCP_JSON:-$PI_AGENT_DIR/mcp.json}"
readonly EXTENSIONS_DST="$PI_AGENT_DIR/extensions"
readonly EXTENSION_NAMES=(
	b-agentic-permissions.ts
	b-agentic-mcp-permissions.ts
	b-agentic-auto-mode.ts
	b-agentic-role.ts
	b-agentic-planner.ts
	b-agentic-worker.ts
	b-agentic-sync.ts
	b-agentic-support/shell.ts
	b-agentic-support/mcp.ts
	b-agentic-support/role.ts
	b-agentic-support/role-models.ts
	b-agentic-support/worker.ts
	b-agentic-support/state.ts
	b-agentic-support/auto.ts
)
readonly EXTENSION_DST="$EXTENSIONS_DST/b-agentic-permissions.ts"
readonly EXTENSION_SNAPSHOT_DST="$METADATA_DIR/extensions/b-agentic-permissions.ts"
readonly EXTENSION_SRC="$SOURCE_DIR/pi/extensions/b-agentic-permissions.ts"
readonly PI_MCP_ADAPTER_SPEC="npm:pi-mcp-adapter"
readonly PI_MCP_ADAPTER_PACKAGE="pi-mcp-adapter"
readonly PI_OBSERVATIONAL_MEMORY_SPEC="npm:pi-observational-memory"
readonly PI_OBSERVATIONAL_MEMORY_PACKAGE="pi-observational-memory"
readonly PI_USAGE_SPEC="npm:@narumitw/pi-usage"
readonly PI_USAGE_PACKAGE="@narumitw/pi-usage"
readonly PI_INTERCOM_SPEC="npm:pi-intercom"
readonly PI_INTERCOM_PACKAGE="pi-intercom"
readonly MCP_ROOT_KEY="mcpServers"
readonly MCP_PLACEHOLDER_STYLE="env-brace"
readonly MCP_CONTEXT7_SECTION="headers"
readonly MCP_BRAVE_SECTION="env"
readonly MCP_FIRECRAWL_SECTION="env"
readonly MCP_BACKUP_KEY="mcpConfig"
readonly EXTENSION_BACKUP_KEY="permissionsExtension"

CONTEXT7_API_KEY_INPUT=""
BRAVE_API_KEY_INPUT=""
FIRECRAWL_API_KEY_INPUT=""
FIRECRAWL_API_URL_INPUT=""
INSTALL_EXTENSION_ACTION="skip"
INSTALL_EXTENSION_STATE="none"
INSTALL_EXTENSION_BACKUP="none"
INSTALL_PI_MCP_ADAPTER_ACTION="skip"
INSTALL_PI_MCP_ADAPTER_STATE="missing"
INSTALL_PI_OBSERVATIONAL_MEMORY_ACTION="skip"
INSTALL_PI_OBSERVATIONAL_MEMORY_STATE="missing"
INSTALL_PI_USAGE_ACTION="skip"
INSTALL_PI_USAGE_STATE="missing"
INSTALL_PI_INTERCOM_ACTION="skip"
INSTALL_PI_INTERCOM_STATE="missing"

runtime_warn_missing_cli() {
	command -v pi >/dev/null 2>&1 || warn "Pi CLI 'pi' not found; files will still be installed for Pi to discover later."
	command -v codegraph >/dev/null 2>&1 || warn "codegraph CLI not found; CodeGraph MCP will not start until CodeGraph is installed."
	command -v bunx >/dev/null 2>&1 || warn "bunx not found; MCP servers that use bunx (Brave, Firecrawl, Playwright) will not start until Bun is installed."
	if command -v pi >/dev/null 2>&1 && ! pi_mcp_adapter_installed; then
		warn "pi-mcp-adapter not installed; MCP servers will not load until the adapter is installed."
	fi
	if command -v pi >/dev/null 2>&1 && ! pi_observational_memory_installed; then
		warn "pi-observational-memory not installed; long-session compaction continuity is unavailable."
	fi
	if command -v pi >/dev/null 2>&1 && ! pi_usage_installed; then
		warn "@narumitw/pi-usage not installed; Pi usage reporting is unavailable."
	fi
}

runtime_cli_installed() {
	command -v pi >/dev/null 2>&1
}

runtime_update_cli() {
	if ! command -v pi >/dev/null 2>&1; then
		warn "Pi CLI not found; skipping Pi update"
		return 0
	fi
	if dry_run_enabled; then
		printf '[dry-run] pi update\n' >&2
		return 0
	fi
	log "Updating Pi CLI with pi update"
	if pi update; then
		log "Pi CLI update completed"
	else
		warn "Pi CLI update failed"
		return 1
	fi
}

runtime_upgrade_cli() {
	local command
	if command -v pi >/dev/null 2>&1; then
		command="pi update"
		log "Pi CLI already installed; upgrading with pi update"
	else
		command="curl -fsSL https://pi.dev/install.sh | sh"
		log "Pi CLI not found; installing with the Pi installer"
	fi
	if dry_run_enabled; then
		printf '[dry-run] %s\n' "$command" >&2
		return 0
	fi
	if [ "$command" = "pi update" ]; then
		if pi update; then
			log "Pi CLI install/upgrade completed"
		else
			warn "Pi CLI install/upgrade failed"
			return 1
		fi
	elif curl -fsSL https://pi.dev/install.sh | sh; then
		log "Pi CLI install/upgrade completed"
	else
		warn "Pi CLI install/upgrade failed"
		return 1
	fi
	return 0
}

pi_package_installed() {
	local package="$1"
	if ! command -v pi >/dev/null 2>&1; then
		return 1
	fi
	local listing
	# Bind to current HOME so sandbox / alternate-home installs do not
	# report a global package install as ready for this target.
	listing="$(
		HOME="${HOME}" \
			PI_CODING_AGENT_DIR="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}" \
			pi list 2>/dev/null || true
	)"
	printf '%s\n' "$listing" | grep -Eq "${package}(@| )|npm:${package}"
}

pi_mcp_adapter_installed() {
	pi_package_installed "$PI_MCP_ADAPTER_PACKAGE"
}

pi_observational_memory_installed() {
	pi_package_installed "$PI_OBSERVATIONAL_MEMORY_PACKAGE"
}

pi_usage_installed() {
	pi_package_installed "$PI_USAGE_PACKAGE"
}

pi_intercom_installed() {
	pi_package_installed "$PI_INTERCOM_PACKAGE"
}

maybe_install_pi_mcp_adapter() {
	if pi_mcp_adapter_installed; then
		INSTALL_PI_MCP_ADAPTER_ACTION="present"
		INSTALL_PI_MCP_ADAPTER_STATE="ready"
		log "Pi MCP adapter $PI_MCP_ADAPTER_PACKAGE already installed"
		return 0
	fi

	if ! command -v pi >/dev/null 2>&1 && ! dry_run_enabled; then
		warn "Pi CLI missing; cannot install $PI_MCP_ADAPTER_PACKAGE"
		return 1
	fi


	if dry_run_enabled; then
		printf '[dry-run] pi install %s\n' "$PI_MCP_ADAPTER_SPEC" >&2
		INSTALL_PI_MCP_ADAPTER_ACTION="install"
		INSTALL_PI_MCP_ADAPTER_STATE="dry-run"
		return 0
	fi

	log "Installing $PI_MCP_ADAPTER_PACKAGE"
	if pi install "$PI_MCP_ADAPTER_SPEC"; then
		INSTALL_PI_MCP_ADAPTER_ACTION="install"
		INSTALL_PI_MCP_ADAPTER_STATE="ready"
		log "Installed $PI_MCP_ADAPTER_PACKAGE"
	else
		INSTALL_PI_MCP_ADAPTER_ACTION="failed"
		INSTALL_PI_MCP_ADAPTER_STATE="missing"
		warn "Failed to install $PI_MCP_ADAPTER_PACKAGE"
		return 1
	fi
}

maybe_install_pi_usage() {
	if pi_usage_installed; then
		INSTALL_PI_USAGE_ACTION="present"
		INSTALL_PI_USAGE_STATE="ready"
		log "Pi Usage $PI_USAGE_PACKAGE already installed"
		return 0
	fi

	if ! command -v pi >/dev/null 2>&1 && ! dry_run_enabled; then
		warn "Pi CLI missing; cannot install $PI_USAGE_PACKAGE"
		return 1
	fi


	if dry_run_enabled; then
		printf '[dry-run] pi install %s\n' "$PI_USAGE_SPEC" >&2
		INSTALL_PI_USAGE_ACTION="install"
		INSTALL_PI_USAGE_STATE="dry-run"
		return 0
	fi

	log "Installing $PI_USAGE_PACKAGE"
	if pi install "$PI_USAGE_SPEC"; then
		INSTALL_PI_USAGE_ACTION="install"
		INSTALL_PI_USAGE_STATE="ready"
		log "Installed $PI_USAGE_PACKAGE"
	else
		INSTALL_PI_USAGE_ACTION="failed"
		INSTALL_PI_USAGE_STATE="missing"
		warn "Failed to install $PI_USAGE_PACKAGE"
		return 1
	fi
}

maybe_install_pi_intercom() {
	if pi_intercom_installed; then INSTALL_PI_INTERCOM_ACTION="present"; INSTALL_PI_INTERCOM_STATE="ready"; return 0; fi
	if ! command -v pi >/dev/null 2>&1 && ! dry_run_enabled; then warn "Pi CLI missing; cannot install $PI_INTERCOM_PACKAGE"; return 1; fi
	if dry_run_enabled; then
		printf '[dry-run] pi install %s\n' "$PI_INTERCOM_SPEC" >&2
		INSTALL_PI_INTERCOM_ACTION="install"; INSTALL_PI_INTERCOM_STATE="dry-run"; return 0
	fi
	if pi install "$PI_INTERCOM_SPEC"; then
		INSTALL_PI_INTERCOM_ACTION="install"; INSTALL_PI_INTERCOM_STATE="ready"
	else
		INSTALL_PI_INTERCOM_ACTION="failed"; INSTALL_PI_INTERCOM_STATE="missing"
		warn "Failed to install $PI_INTERCOM_PACKAGE"
		return 1
	fi
}

maybe_install_pi_observational_memory() {
	if pi_observational_memory_installed; then
		INSTALL_PI_OBSERVATIONAL_MEMORY_ACTION="present"
		INSTALL_PI_OBSERVATIONAL_MEMORY_STATE="ready"
		log "Pi Observational Memory $PI_OBSERVATIONAL_MEMORY_PACKAGE already installed"
		return 0
	fi

	if ! command -v pi >/dev/null 2>&1 && ! dry_run_enabled; then
		warn "Pi CLI missing; cannot install $PI_OBSERVATIONAL_MEMORY_PACKAGE"
		return 1
	fi


	if dry_run_enabled; then
		printf '[dry-run] pi install %s\n' "$PI_OBSERVATIONAL_MEMORY_SPEC" >&2
		INSTALL_PI_OBSERVATIONAL_MEMORY_ACTION="install"
		INSTALL_PI_OBSERVATIONAL_MEMORY_STATE="dry-run"
		return 0
	fi

	log "Installing $PI_OBSERVATIONAL_MEMORY_PACKAGE"
	if pi install "$PI_OBSERVATIONAL_MEMORY_SPEC"; then
		INSTALL_PI_OBSERVATIONAL_MEMORY_ACTION="install"
		INSTALL_PI_OBSERVATIONAL_MEMORY_STATE="ready"
		log "Installed $PI_OBSERVATIONAL_MEMORY_PACKAGE"
	else
		INSTALL_PI_OBSERVATIONAL_MEMORY_ACTION="failed"
		INSTALL_PI_OBSERVATIONAL_MEMORY_STATE="missing"
		warn "Failed to install $PI_OBSERVATIONAL_MEMORY_PACKAGE"
		return 1
	fi
}

runtime_install_config_stage_count() { # extension update + permission extension + MCP merge + prompted keys
	printf '4'
}

install_permissions_extension() {
	local name src dst snapshot previous_backup backup action="skip" state="active" backups=()
	for name in "${EXTENSION_NAMES[@]}"; do
		src="$SOURCE_DIR/pi/extensions/$name"
		if [ ! -f "$src" ]; then
			die "missing Pi extension source: $src"
		fi
		dst="$EXTENSIONS_DST/$name"
		snapshot="$METADATA_DIR/extensions/$name"
		previous_backup="$(manifest_backup_value "extension:$name" none)"
		[ "$previous_backup" = "none" ] && [ "$name" = "b-agentic-permissions.ts" ] && previous_backup="$(manifest_backup_value permissionsExtension none)"
		if [ "$previous_backup" != "none" ]; then
			backups+=("$name|$(printf '%s' "$previous_backup" | base64 | tr -d '\n')")
		fi
		if dry_run_enabled; then
			printf '[dry-run] install extension %s -> %s\n' "$src" "$dst" >&2
			action="write"
			continue
		fi
		ensure_dir "$EXTENSIONS_DST"
		ensure_dir "$(dirname "$snapshot")"
		if [ -L "$dst" ]; then
			backup="$(backup_file "$dst")"
			copy_file "$src" "$dst"
			[ -n "$backup" ] && backups+=("$name|$(printf '%s' "$backup" | base64 | tr -d '\n')")
			action="replace"
		elif [ -f "$dst" ]; then
			if cmp -s "$src" "$dst"; then
				action="${action/skip/skip}"
			elif [ -f "$snapshot" ] && cmp -s "$dst" "$snapshot"; then
				copy_file "$src" "$dst"
				action="replace"
			else
				backup="$(backup_file "$dst")"
				copy_file "$src" "$dst"
				[ -n "$backup" ] && backups+=("$name|$(printf '%s' "$backup" | base64 | tr -d '\n')")
				action="replace"
			fi
		else
			copy_file "$src" "$dst"
			action="write"
		fi
		copy_file "$src" "$snapshot"
	done
	if dry_run_enabled; then
		printf 'write\nactive\nnone'
	else
		printf '%s\n%s\n%s' "$action" "$state" "${backups[*]:-none}"
	fi
}

update_pi_extensions() {
	if ! command -v pi >/dev/null 2>&1 && ! dry_run_enabled; then
		warn "Pi CLI missing; cannot update Pi extensions"
		return 1
	fi
	if dry_run_enabled; then
		printf '[dry-run] pi update --extensions\n' >&2
		return 0
	fi

	log "Updating installed Pi extensions with pi update --extensions"
	if pi update --extensions; then
		log "Pi extension update completed"
	else
		warn "Pi extension update failed"
		return 1
	fi
	return 0
}

runtime_install_configs() {
	maybe_install_pi_mcp_adapter || return $?
	maybe_install_pi_observational_memory || return $?
	maybe_install_pi_usage || return $?
	maybe_install_pi_intercom || return $?
	run_stage "Updating Pi extensions" update_pi_extensions || return $?
	run_install_triplet_stage "Installing Pi permission extension" install_permissions_extension "skip" "none" "none" \
		INSTALL_EXTENSION_ACTION INSTALL_EXTENSION_STATE INSTALL_EXTENSION_BACKUP || return $?
	run_install_triplet_stage "Merging MCP config" install_mcp_config "skip" "none" "none" \
		INSTALL_MCP_ACTION INSTALL_MCP_STATE INSTALL_MCP_BACKUP || return $?
	apply_prompted_mcp_keys_stage INSTALL_MCP_ACTION INSTALL_MCP_BACKUP
}

runtime_write_manifest() {
	local skills_string="${INSTALL_SKILL_NAMES[*]}"

	if dry_run_enabled; then
		printf '[dry-run] write manifest %s\n' "$MANIFEST_DST" >&2
		return 0
	fi

	ensure_dir "$METADATA_DIR"
	env \
		MANIFEST_DST="$MANIFEST_DST" \
		TIMESTAMP="$TIMESTAMP" \
		RUNTIME="pi" \
		MEMORY_ACTION="$INSTALL_MEMORY_ACTION" \
		ACTIVATION_STATE="$INSTALL_ACTIVATION_STATE" \
		MEMORY_BACKUP="$INSTALL_MEMORY_BACKUP" \
		EXTENSION_ACTION="$INSTALL_EXTENSION_ACTION" \
		EXTENSION_STATE="$INSTALL_EXTENSION_STATE" \
		EXTENSION_BACKUP="$INSTALL_EXTENSION_BACKUP" \
		MCP_ACTION="$INSTALL_MCP_ACTION" \
		MCP_STATE="$INSTALL_MCP_STATE" \
		MCP_BACKUP="$INSTALL_MCP_BACKUP" \
		MCP_ADAPTER_ACTION="$INSTALL_PI_MCP_ADAPTER_ACTION" \
		MCP_ADAPTER_STATE="$INSTALL_PI_MCP_ADAPTER_STATE" \
		PI_OBSERVATIONAL_MEMORY_ACTION="$INSTALL_PI_OBSERVATIONAL_MEMORY_ACTION" \
		PI_OBSERVATIONAL_MEMORY_STATE="$INSTALL_PI_OBSERVATIONAL_MEMORY_STATE" \
		PI_USAGE_ACTION="$INSTALL_PI_USAGE_ACTION" \
		PI_USAGE_STATE="$INSTALL_PI_USAGE_STATE" \
		PI_INTERCOM_ACTION="$INSTALL_PI_INTERCOM_ACTION" \
		PI_INTERCOM_STATE="$INSTALL_PI_INTERCOM_STATE" \
		PI_AGENT_DIR="$PI_AGENT_DIR" \
		MCP_CONFIG_DST="$MCP_CONFIG_DST" \
		EXTENSION_DST="$EXTENSION_DST" \
		EXTENSION_NAMES="${EXTENSION_NAMES[*]}" \
		EXTENSIONS_DST="$EXTENSIONS_DST" \
		EXTENSION_BACKUP="$INSTALL_EXTENSION_BACKUP" \
		SKILLS_DST="$SKILLS_DST" \
		REFERENCES_DST="$REFERENCES_DST" \
		TEMPLATES_DST="$TEMPLATES_DST" \
		KERNEL_DST="$KERNEL_DST" \
		SKILLS="$skills_string" \
		python3 - <<'PY'
import json
import os
from pathlib import Path

skills = [name for name in os.environ['SKILLS'].split() if name]
import base64

extension_backups = {}
for item in os.environ['EXTENSION_BACKUP'].split():
    if '|' in item:
        name, encoded = item.split('|', 1)
        try:
            extension_backups[name] = base64.b64decode(encoded).decode()
        except Exception:
            continue
    elif '=' in item:  # legacy triplet output
        name, backup = item.split('=', 1)
        extension_backups[name] = backup
manifest = {
    'suite': 'b-agentic',
    'runtime': os.environ['RUNTIME'],
    'installedAt': os.environ['TIMESTAMP'],
    'activationState': os.environ['ACTIVATION_STATE'],
    'memoryAction': os.environ['MEMORY_ACTION'],
    'extensionAction': os.environ['EXTENSION_ACTION'],
    'extensionState': os.environ['EXTENSION_STATE'],
    'mcpAction': os.environ['MCP_ACTION'],
    'mcpState': os.environ['MCP_STATE'],
    'mcpAdapterAction': os.environ['MCP_ADAPTER_ACTION'],
    'mcpAdapterState': os.environ['MCP_ADAPTER_STATE'],
    'piObservationalMemoryAction': os.environ['PI_OBSERVATIONAL_MEMORY_ACTION'],
    'piObservationalMemoryState': os.environ['PI_OBSERVATIONAL_MEMORY_STATE'],
    'piUsageAction': os.environ['PI_USAGE_ACTION'],
    'piUsageState': os.environ['PI_USAGE_STATE'],
    'piIntercomAction': os.environ['PI_INTERCOM_ACTION'],
    'piIntercomState': os.environ['PI_INTERCOM_STATE'],
    'paths': {
        'piAgentDir': os.environ['PI_AGENT_DIR'],
        'mcpConfig': os.environ['MCP_CONFIG_DST'],
        'permissionsExtension': os.environ['EXTENSION_DST'],
        'extensions': {
            name: str(Path(os.environ['EXTENSIONS_DST']) / name)
            for name in os.environ['EXTENSION_NAMES'].split()
        },
        'kernel': os.environ['KERNEL_DST'],
        'skills': os.environ['SKILLS_DST'],
        'references': os.environ['REFERENCES_DST'],
        'templates': os.environ['TEMPLATES_DST'],
    },
    'skills': skills,
    'backups': {
        'agentsMd': os.environ['MEMORY_BACKUP'],
        'permissionsExtension': extension_backups.get('b-agentic-permissions.ts', 'none'),
        'extensions': extension_backups,
        'mcpConfig': os.environ['MCP_BACKUP'],
    },
}
Path(os.environ['MANIFEST_DST']).write_text(json.dumps(manifest, indent=2, sort_keys=True) + '\n')
PY
}

runtime_print_install_report() {
	local -a attention=()
	local status shell_status summary_label="Installed"

	installer_summary_log "b-agentic install complete for Pi"
	if dry_run_enabled; then
		summary_label="Planned"
	fi
	installer_summary_log "$summary_label: ${#INSTALL_SKILL_NAMES[@]} skills; kernel $INSTALL_MEMORY_ACTION; MCP $INSTALL_MCP_ACTION"
	if dry_run_enabled; then
		installer_summary_log "Manifest: not written (dry-run)"
	else
		installer_summary_log "Manifest: $MANIFEST_DST"
	fi

	if [ "$INSTALL_ACTIVATION_STATE" = "pending" ]; then
		attention+=("activation: review $KERNEL_SNAPSHOT_DST, then rerun with --replace-memory if desired")
	fi

	status="$(serena_readiness_status)"
	case "$status" in ready:*) ;; *) attention+=("serena: $status") ;; esac
	status="$(codegraph_readiness_status)"
	case "$status" in ready:*) ;; *) attention+=("codegraph: $status") ;; esac
	status="$(context7_readiness_status)"
	case "$status" in ready:*) ;; *) attention+=("context7: $status") ;; esac
	status="$(linear_readiness_status)"
	case "$status" in configured:*) attention+=("linear: $status") ;; ready:*) ;; *) attention+=("linear: $status") ;; esac
	status="$(brave_search_readiness_status)"
	case "$status" in ready:*) ;; *) attention+=("brave-search: $status") ;; esac
	status="$(firecrawl_readiness_status)"
	case "$status" in ready:*) ;; *) attention+=("firecrawl: $status") ;; esac
	status="$(playwright_readiness_status)"
	case "$status" in ready:*) ;; *) attention+=("playwright: $status") ;; esac
	status="$(rtk_readiness_status)"
	case "$status" in ready:*) ;; *) attention+=("rtk: $status") ;; esac

	[ "$INSTALL_PI_MCP_ADAPTER_STATE" = "ready" ] || attention+=("mcp-adapter: install $PI_MCP_ADAPTER_PACKAGE with 'pi install $PI_MCP_ADAPTER_SPEC'")
	[ "$INSTALL_PI_OBSERVATIONAL_MEMORY_STATE" = "ready" ] || attention+=("observational-memory: install $PI_OBSERVATIONAL_MEMORY_PACKAGE with 'pi install $PI_OBSERVATIONAL_MEMORY_SPEC'")
	[ "$INSTALL_PI_USAGE_STATE" = "ready" ] || attention+=("pi-usage: install $PI_USAGE_PACKAGE with 'pi install $PI_USAGE_SPEC'")
	[ "$INSTALL_PI_INTERCOM_STATE" = "ready" ] || attention+=("pi-intercom: install $PI_INTERCOM_PACKAGE with 'pi install $PI_INTERCOM_SPEC'")

	shell_status="$(shell_tool_readiness_status)"
	case "$shell_status" in
	ready:*) ;;
	*) attention+=("shell tooling: $shell_status; hint: $(shell_tool_install_hint "$(detect_shell_tool_package_manager)")") ;;
	esac

	if [ "${#attention[@]}" -gt 0 ]; then
		installer_summary_log "Readiness:"
		installer_summary_log "Attention:"
		for status in "${attention[@]}"; do
			installer_summary_log "  $status"
		done
	else
		installer_summary_log "Readiness: ready"
	fi

	if dry_run_enabled; then
		installer_summary_log "Next: rerun without --dry-run to apply the plan; no manifest was written."
	elif [ "$INSTALL_ACTIVATION_STATE" = "pending" ]; then
		installer_summary_log "Next: review the activation snapshot; see $MANIFEST_DST for backups and installed paths."
	else
		installer_summary_log "Next: start a new Pi session; see $MANIFEST_DST for backups and installed paths."
	fi
}

runtime_uninstall_configs() {
	local mcp_config_path name extension_path snapshot original backup
	mcp_config_path="$(manifest_path_value mcpConfig "$MCP_CONFIG_DST")"
	remove_merged_config "$mcp_config_path" "$TEMPLATES_DST/mcp.user.template.json" "mcp.json" "mcpConfig" "mcpAction"
	for name in "${EXTENSION_NAMES[@]}"; do
		extension_path="$(manifest_extension_path "$name" "$EXTENSIONS_DST/$name")"
		snapshot="$METADATA_DIR/extensions/$name"
		if [ -L "$extension_path" ]; then
			warn "preserving symlinked Pi extension: $extension_path"
		elif [ -f "$extension_path" ]; then
			if [ -f "$snapshot" ] && cmp -s "$extension_path" "$snapshot"; then
				original="$(manifest_backup_value "extension:$name" none)"
				[ "$original" = "none" ] && [ "$name" = "b-agentic-permissions.ts" ] && original="$(manifest_backup_value permissionsExtension none)"
				if [ "$original" = "none" ]; then
					run_cmd rm -f "$extension_path"
				elif [ -f "$original" ] && [ ! -L "$original" ] && [[ "$original" == "$METADATA_DIR/backups/"* ]]; then
					copy_file "$original" "$extension_path"
				else
					warn "preserving Pi extension because its original backup is unavailable: $extension_path"
				fi
			else
				warn "preserving modified Pi extension: $extension_path"
			fi
		fi
	 done
	# Intentionally leave pi-mcp-adapter, pi-observational-memory, and pi-usage packages installed.
}


pi_install() {
	runtime_install_common
}

pi_sync() {
	runtime_sync_common
}

pi_update() {
	set_install_stage_total 8
	run_stage "Updating Pi CLI" runtime_upgrade_cli || return $?
	run_stage "Installing Pi MCP adapter" maybe_install_pi_mcp_adapter || return $?
	run_stage "Installing observational memory" maybe_install_pi_observational_memory || return $?
	run_stage "Installing Pi usage" maybe_install_pi_usage || return $?
	run_stage "Installing Pi intercom" maybe_install_pi_intercom || return $?
	run_stage "Syncing first-party extensions" install_permissions_extension >/dev/null || return $?
	run_stage "Updating Pi extensions" update_pi_extensions
}

pi_uninstall() {
	runtime_uninstall_common
}
