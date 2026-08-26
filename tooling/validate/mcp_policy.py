#!/usr/bin/env python3

"""Regression checks for the Pi MCP operation policy.

Canonical source: references/mcp_operations.yaml. Pi's permission extension is
b-agentic's enforced operation boundary.
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
POLICY_PATH = ROOT / "references" / "mcp_operations.yaml"
PI_VALIDATOR = ROOT / "pi" / "scripts" / "validate_mcp_policy.py"
GATED_CLASSES = {"local-upload", "external-mutation", "monitor-lifecycle", "local-mutation", "auth"}
READ_ONLY = "read-only"
TRUSTED_CLASSES = {"trusted-serena"}
CONDITIONAL_CLASSES = {"conditional-read", "conditional-local"}
MANAGED_SERVERS = {"serena", "codegraph", "context7", "linear", "mobbin", "brave-search", "firecrawl", "playwright"}
EXPECTED_SERENA_TOOLS = {
    "serena_search_for_pattern", "serena_get_symbols_overview", "serena_find_symbol",
    "serena_find_referencing_symbols", "serena_find_implementations", "serena_find_declaration",
    "serena_get_diagnostics_for_file", "serena_read_memory", "serena_list_memories",
    "serena_initial_instructions", "serena_replace_content", "serena_replace_in_files",
    "serena_replace_symbol_body", "serena_insert_after_symbol", "serena_insert_before_symbol",
    "serena_rename_symbol", "serena_safe_delete_symbol", "serena_write_memory",
    "serena_delete_memory", "serena_rename_memory", "serena_edit_memory",
    "serena_open_dashboard", "serena_onboarding",
}


def load_policy() -> dict:
    try:
        return json.loads(POLICY_PATH.read_text())
    except (OSError, json.JSONDecodeError) as exc:
        raise ValueError(f"{POLICY_PATH.relative_to(ROOT)}: invalid policy: {exc}") from exc


def validate_policy_shape(policy: dict, errors: list[str]) -> None:
    classes = policy.get("classes")
    if not isinstance(classes, dict) or not classes:
        errors.append("references/mcp_operations.yaml: missing classes map")
        classes = {}
    for required in [READ_ONLY, *sorted(TRUSTED_CLASSES), *sorted(CONDITIONAL_CLASSES), *sorted(GATED_CLASSES)]:
        if required not in classes:
            errors.append(f"references/mcp_operations.yaml: missing class {required!r}")

    servers = policy.get("servers")
    if not isinstance(servers, dict) or set(servers) != MANAGED_SERVERS:
        found = sorted(servers) if isinstance(servers, dict) else []
        errors.append(f"references/mcp_operations.yaml: expected servers {sorted(MANAGED_SERVERS)}, found {found}")
        return
    conditional_tools: set[str] = set()
    for server, record in servers.items():
        tools = record.get("tools") if isinstance(record, dict) else None
        if not isinstance(tools, dict) or not tools:
            errors.append(f"references/mcp_operations.yaml: server {server!r} has no tools")
            continue
        for tool, classification in tools.items():
            if classification not in classes:
                errors.append(f"references/mcp_operations.yaml: tool {server}:{tool} has unknown class {classification!r}")
            if classification in CONDITIONAL_CLASSES:
                conditional_tools.add(f"{server}:{tool}")
    serena_tools = servers.get("serena", {}).get("tools", {})
    if set(serena_tools) != EXPECTED_SERENA_TOOLS or any(
        classification not in {"trusted-serena", "conditional-read", "conditional-local"}
        for classification in serena_tools.values()
    ):
        errors.append(
            "references/mcp_operations.yaml: every supported Serena tool must have an autonomous Serena class"
        )

    conditional_arguments = policy.get("conditional_arguments")
    if not isinstance(conditional_arguments, dict) or set(conditional_arguments) != conditional_tools:
        found = sorted(conditional_arguments) if isinstance(conditional_arguments, dict) else []
        errors.append(
            "references/mcp_operations.yaml: conditional_arguments must match conditional tools "
            f"(expected {sorted(conditional_tools)}, found {found})"
        )
    elif any(
        not isinstance(record, dict)
        or not isinstance(record.get("known"), list)
        or not record["known"]
        or not all(isinstance(name, str) for name in record["known"])
        for record in conditional_arguments.values()
    ):
        errors.append("references/mcp_operations.yaml: each conditional argument record needs a non-empty known string list")

    runtime_policy = policy.get("runtime_enforcement", {}).get("pi", "")
    for marker in ("tools.search", "tools.describe", "nested tools.call"):
        if marker not in runtime_policy:
            errors.append(
                f"references/mcp_operations.yaml: mcpScript runtime policy missing {marker!r}"
            )


def main() -> int:
    errors: list[str] = []
    if not POLICY_PATH.is_file():
        print("references/mcp_operations.yaml: missing canonical MCP operations policy", file=sys.stderr)
        return 1
    try:
        policy = load_policy()
    except ValueError as exc:
        print(exc, file=sys.stderr)
        return 1
    validate_policy_shape(policy, errors)

    if not PI_VALIDATOR.is_file():
        errors.append("pi/scripts/validate_mcp_policy.py: missing Pi MCP policy validator")
    elif not errors:
        result = subprocess.run(
            [sys.executable, str(PI_VALIDATOR), "--policy", str(POLICY_PATH)],
            cwd=ROOT,
            capture_output=True,
            text=True,
        )
        if result.returncode:
            errors.append(f"Pi MCP policy validation failed: {(result.stderr or result.stdout).strip()}")

    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print("Pi MCP operation policy regression passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
