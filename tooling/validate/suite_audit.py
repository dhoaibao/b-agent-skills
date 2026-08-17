#!/usr/bin/env python3
"""Audit the repository for Claude-only delivery and source consistency."""
from __future__ import annotations
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
errors: list[str] = []

def read(path: Path) -> str:
    try: return path.read_text()
    except OSError: return ""

def valid_agent(path: Path, required: str) -> bool:
    tools = next((line for line in path.read_text().splitlines() if line.startswith("tools:")), "")
    return required in tools and "Task" not in tools

def valid_manifest(path: Path) -> bool:
    data = json.loads(path.read_text())
    return (
        data.get("name") == "b-agentic"
        and data.get("skills") == "./skills/"
        and data.get("agents") == ["./agents/b-planner.md", "./agents/b-worker.md"]
        and data.get("hooks") == "./hooks/hooks.json"
        and data.get("mcpServers") == "./.mcp.json"
        and all((path.parent.parent / relative).exists() for relative in ["skills", "agents/b-planner.md", "agents/b-worker.md", "hooks/hooks.json", ".mcp.json"])
    )

if (ROOT / "pi").exists():
    errors.append("legacy runtime directory pi/ must not exist")
required = {
    "plugin/.claude-plugin/plugin.json": valid_manifest,
    "plugin/hooks/hooks.json": lambda p: (
        "PreToolUse" in json.loads(p.read_text()).get("hooks", {})
        and any(item.get("matcher") == ".*" for item in json.loads(p.read_text())["hooks"]["PreToolUse"])
    ),
    "plugin/hooks/b-agentic-policy.py": lambda p: p.stat().st_mode & 0o111,
    "plugin/hooks/b-agentic-status-line.py": lambda p: p.stat().st_mode & 0o111,
    "plugin/settings.json": lambda p: (
        json.loads(p.read_text()).get("crossSessionInbound") == "accept"
        and "statusLine" in json.loads(p.read_text())
        and "Bash(git reset --hard*)" in json.loads(p.read_text()).get("permissions", {}).get("deny", [])
    ),
    "plugin/.mcp.json": lambda p: "mcpServers" in json.loads(p.read_text()),
    "plugin/agents/b-planner.md": lambda p: valid_agent(p, "Read"),
    "plugin/agents/b-worker.md": lambda p: valid_agent(p, "Write"),
}
for name, check in required.items():
    path = ROOT / name
    if not path.exists(): errors.append(f"{name}: missing")
    else:
        try:
            if not check(path): errors.append(f"{name}: invalid")
        except Exception as exc: errors.append(f"{name}: invalid ({exc})")
if errors:
    print("\n".join(errors), file=sys.stderr)
    raise SystemExit(1)
print("Claude Code suite audit passed.")
