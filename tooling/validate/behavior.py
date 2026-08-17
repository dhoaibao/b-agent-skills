#!/usr/bin/env python3
"""Static routing and solo workflow input validation."""
from __future__ import annotations
import json
import re
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]

def load(path: Path):
    return json.loads(path.read_text())

def main() -> int:
    errors=[]
    registry=load(ROOT/"skills/registry.yaml")
    skills=registry.get("skills", [])
    names={s.get("name") for s in skills if isinstance(s,dict)}
    routing={s["name"]:s.get("routing") for s in skills if isinstance(s,dict) and s.get("name")}
    fixtures=load(ROOT/"tests/behavior/routing.json").get("scenarios", [])
    for fixture in fixtures:
        prompt=fixture.get("prompt", "").lower()
        expected=fixture.get("expected_skill")
        if expected not in names: errors.append(f"routing fixture {fixture.get('id')}: unknown skill {expected}")
        scores={name: sum(str(trigger).lower() in prompt for trigger in (meta or {}).get("triggers", [])) for name,meta in routing.items()}
        if expected and routing.get(expected) is not None and scores.get(expected, 0) == 0 and not any(expected in token for token in prompt.split()):
            # Natural-language fixtures are allowed when intent words are present.
            intent=str((routing.get(expected) or {}).get("intent", "")).lower()
            if not any(word in prompt for word in re.findall(r"[a-z]{4,}", intent)):
                errors.append(f"routing fixture {fixture.get('id')}: expected skill has no metadata match")
        for forbidden in fixture.get("forbidden_skills", []):
            if forbidden not in names: errors.append(f"routing fixture {fixture.get('id')}: unknown forbidden skill {forbidden}")
    kernel=(ROOT/"references/kernel.template.md").read_text()
    for marker in ("latest user instruction, approved plan, repo evidence, then stated assumptions", "Auto-run repository-local commands", "likely-secret files", "RTK never bypasses these protections", "Solo Claude Code is the default", "ListAgents", "SendMessage"):
        if marker not in kernel: errors.append(f"kernel missing contract clause: {marker}")
    if errors: print("\n".join(errors), file=sys.stderr); return 1
    print(f"Claude solo workflow and routing validation passed ({len(fixtures)} fixtures).")
    return 0
if __name__ == "__main__": raise SystemExit(main())
