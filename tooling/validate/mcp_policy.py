#!/usr/bin/env python3
"""Validate canonical and generated Claude managed-MCP policy inputs."""
from __future__ import annotations
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CANONICAL = ROOT / "references/mcp_operations.yaml"
GENERATED = ROOT / "plugin/hooks/mcp_policy.json"
REQUIRED_CLASSES = {"read-only", "conditional-read", "conditional-local", "local-upload", "external-mutation", "monitor-lifecycle", "local-mutation", "auth"}

def main() -> int:
    errors=[]
    try: policy=json.loads(CANONICAL.read_text())
    except Exception as exc: errors.append(f"canonical policy invalid: {exc}"); policy={}
    if not REQUIRED_CLASSES.issubset(policy.get("classes", {})): errors.append("canonical policy classes are incomplete")
    if "claude" not in policy.get("runtime_enforcement", {}): errors.append("canonical policy lacks Claude hook enforcement")
    try: generated=json.loads(GENERATED.read_text())
    except Exception as exc: errors.append(f"generated policy invalid: {exc}"); generated={}
    if policy != generated: errors.append("plugin/hooks/mcp_policy.json is stale; run registry_sync.py")
    servers=policy.get("servers", {})
    if not isinstance(servers, dict) or not servers: errors.append("canonical policy has no servers")
    for server, value in servers.items():
        if not isinstance(value, dict) or not isinstance(value.get("tools"), dict): errors.append(f"server {server} has no tools map")
        for tool, op in value.get("tools", {}).items() if isinstance(value, dict) else []:
            if op not in policy.get("classes", {}): errors.append(f"unknown class {op} for {server}:{tool}")
    if errors:
        print("\n".join(errors), file=sys.stderr); return 1
    print("Claude managed-MCP operation policy validation passed.")
    return 0
if __name__ == "__main__": raise SystemExit(main())
