#!/usr/bin/env python3
"""Non-networked direct-MCP and hook readiness checks."""
from __future__ import annotations
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
HOOK=ROOT/"plugin/hooks/b-agentic-policy.py"

def run(event: dict) -> dict:
    result=subprocess.run([sys.executable, str(HOOK)], input=json.dumps(event), text=True, capture_output=True, check=True)
    return json.loads(result.stdout)

def decision(value: dict) -> str:
    return value["hookSpecificOutput"]["permissionDecision"]

def self_test() -> int:
    fixtures=json.loads((ROOT/"tests/behavior/hook-decisions.json").read_text()).get("cases", [])
    for case in fixtures:
        event=case.get("event", {})
        # Resolve the fixture's project-relative cwd against the repository.
        if event.get("cwd") == ".": event["cwd"]=str(ROOT)
        expected=case.get("decision")
        actual=decision(run(event))
        if actual != expected:
            print(f"hook fixture {case.get('name')}: expected {expected}, got {actual}", file=sys.stderr); return 1
    print("Claude hook and direct-MCP fixtures passed.")
    return 0

def main() -> int:
    if "--self-test" in sys.argv: return self_test()
    print("Live MCP probing is opt-in; run --self-test for local policy fixtures.")
    return 0
if __name__ == "__main__": raise SystemExit(main())
