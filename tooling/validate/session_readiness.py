#!/usr/bin/env python3
"""Validate Claude workflow kernel and named-agent readiness."""
from __future__ import annotations
import json
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]

def main() -> int:
    errors=[]
    kernel=(ROOT/"references/kernel.template.md").read_text()
    if "Solo Claude Code is the default" not in kernel: errors.append("kernel missing solo default")
    for marker in ("ListAgents", "SendMessage", "b-planner", "b-worker", "sole worktree writer"):
        if marker not in kernel: errors.append(f"kernel missing {marker}")
    for path, required in ((ROOT/"plugin/agents/b-planner.md", ("tools:", "Read", "read-only")), (ROOT/"plugin/agents/b-worker.md", ("tools:", "Write", "sole worktree writer"))):
        text=path.read_text() if path.exists() else ""
        tools_line = next((line for line in text.splitlines() if line.startswith("tools:")), "")
        if "Task" in tools_line: errors.append(f"{path.relative_to(ROOT)} must not expose Task")
        for marker in required:
            if marker not in text: errors.append(f"{path.relative_to(ROOT)} missing {marker}")
    try:
        hooks=json.loads((ROOT/"plugin/hooks/hooks.json").read_text())
        if "PreToolUse" not in hooks.get("hooks", {}): errors.append("hooks missing PreToolUse")
        elif not any(item.get("matcher") == ".*" for item in hooks["hooks"]["PreToolUse"]): errors.append("PreToolUse must use an all-tools matcher")
    except Exception as exc: errors.append(f"hooks invalid: {exc}")
    if "--self-test" in sys.argv:
        if errors: print("\n".join(errors), file=sys.stderr); return 1
        print("Claude session readiness self-test passed."); return 0
    if errors: print("\n".join(errors), file=sys.stderr); return 1
    print("Claude named-session workflow readiness passed."); return 0
if __name__ == "__main__": raise SystemExit(main())
