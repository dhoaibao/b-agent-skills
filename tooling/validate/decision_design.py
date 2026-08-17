#!/usr/bin/env python3
"""Narrow traceability checks for the Claude Code decision record."""
from __future__ import annotations
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATH = ROOT / "docs/decision_design.md"
REQUIRED = {
    "Claude Code is the runtime boundary",
    "Source layers and generated delivery",
    "Safety is fail-closed and fixture-backed",
    "Solo first; named coordination is explicit",
    "Claude-native lifecycle facilities",
    "Installer preservation",
    "Verification lanes",
}

def main() -> int:
    text = PATH.read_text() if PATH.exists() else ""
    errors = []
    if not text:
        errors.append("docs/decision_design.md: missing")
    for section in REQUIRED:
        if f"## {section}" not in text:
            errors.append(f"docs/decision_design.md: missing section {section!r}")
    for source in ("skills/registry.yaml", "references/kernel.template.md", "references/mcp_operations.yaml", "plugin/hooks/b-agentic-policy.py", "install.sh"):
        if f"`{source}`" not in text:
            errors.append(f"docs/decision_design.md: missing source reference `{source}`")
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print("Decision-design traceability check passed.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
