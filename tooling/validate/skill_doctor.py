#!/usr/bin/env python3
"""Check installed Claude Code plugin skill readiness."""
from __future__ import annotations
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

def names() -> list[str]:
    try:
        data = json.loads((ROOT / "skills/registry.yaml").read_text())
        return sorted(s["name"] for s in data["skills"] if isinstance(s, dict) and isinstance(s.get("name"), str))
    except Exception:
        return []

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--home", default=str(Path.home()))
    args = parser.parse_args()
    config = Path(args.home).expanduser() / ".claude"
    plugin = config / "plugins/b-agentic"
    expected = names()
    actual = sorted(p.parent.name for p in plugin.glob("skills/b-*/SKILL.md"))
    missing = sorted(set(expected) - set(actual))
    stale = [name for name in expected if (ROOT / f"skills/{name}/SKILL.md").exists() and (plugin / f"skills/{name}/SKILL.md").exists() and (ROOT / f"skills/{name}/SKILL.md").read_bytes() != (plugin / f"skills/{name}/SKILL.md").read_bytes()]
    ready = plugin.is_dir() and actual == expected and not stale and (config / "CLAUDE.md").exists()
    print("runtime: Claude Code")
    print(f"plugin-path: {plugin}")
    print(f"kernel: {'ready' if (config / 'CLAUDE.md').exists() else 'missing'}")
    print(f"skills: {'ready' if actual == expected else 'missing: ' + ','.join(missing)}")
    print(f"content: {'ready' if not stale else 'stale: ' + ','.join(stale)}")
    return 0 if ready else 1

if __name__ == "__main__":
    raise SystemExit(main())
