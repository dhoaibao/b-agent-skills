#!/usr/bin/env python3
"""Check Claude Code direct MCP configuration and local readiness."""
from __future__ import annotations
import argparse
import json
import os
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SERVERS = ["serena", "codegraph", "context7", "linear", "brave-search", "firecrawl", "playwright"]

def main() -> int:
    parser=argparse.ArgumentParser()
    parser.add_argument("--config", default=os.environ.get("B_AGENTIC_CLAUDE_CONFIG_DIR", str(Path.home()/".claude")))
    args=parser.parse_args()
    plugin=ROOT/"plugin"
    config=Path(args.config).expanduser()
    source=config/"plugins/b-agentic/.mcp.json"
    if not source.exists(): source=plugin/".mcp.json"
    try: data=json.loads(source.read_text())
    except Exception as exc:
        print(f"runtime: Claude Code\nconfig: {source}\nstatus: invalid config: {exc}", file=sys.stderr); return 1
    mcp=data.get("mcpServers", {})
    missing=[name for name in SERVERS if name not in mcp]
    print(f"runtime: Claude Code\nconfig: {source}\nservers: {len(mcp)}")
    for name in SERVERS:
        entry=mcp.get(name, {})
        if name in missing: status="missing config entry"
        elif name in {"serena", "codegraph"} and not shutil.which(name): status=f"blocked: {name} executable not found"
        elif name in {"brave-search", "firecrawl", "playwright"} and not shutil.which("bunx"): status="blocked: bunx executable not found"
        elif name in {"context7", "brave-search", "firecrawl"} and not os.environ.get({"context7":"CONTEXT7_API_KEY", "brave-search":"BRAVE_API_KEY", "firecrawl":"FIRECRAWL_API_KEY"}[name]): status="blocked: set credential in the environment"
        elif name in {"context7", "brave-search", "firecrawl"}: status="ready: credential supplied at runtime"
        else: status="configured"
        print(f"{name}: {status}")
    if missing: return 1
    print("status: Claude MCP configuration is structurally ready; live startup is not attempted")
    return 0
if __name__ == "__main__": raise SystemExit(main())
