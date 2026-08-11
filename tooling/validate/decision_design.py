#!/usr/bin/env python3

"""Narrow traceability checks for the evidence-backed decision record.

These checks verify document structure, evidence markers, and exact tracked
source references. They do not mechanically prove the semantics of prose.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DECISION_PATH = ROOT / "docs" / "decision_design.md"
REPO_SOURCE_SUFFIXES = {".md", ".py", ".ts", ".json", ".yaml", ".yml", ".sh", ".toml"}
REQUIRED_SECTIONS = {
    "Scope and evidence",
    "Product boundary and architecture",
    "Workflow and skill design",
    "Safety and approval design",
    "MCP and external-evidence design",
    "Installation, configuration, and lifecycle",
    "Verification and change discipline",
    "Intentional non-goals",
}
HEADING_RE = re.compile(r"^(#{2,3}) (.+?)\s*$", re.MULTILINE)
CODE_SPAN_RE = re.compile(r"`([^`]+)`")


def tracked_paths() -> set[str]:
    result = subprocess.run(
        ["git", "ls-files"], cwd=ROOT, check=True, capture_output=True, text=True
    )
    return set(result.stdout.splitlines())


def source_references(text: str, tracked: set[str] | None = None) -> list[str]:
    references: list[str] = []
    for raw in CODE_SPAN_RE.findall(text):
        token = raw.strip()
        if (
            not token
            or any(char.isspace() for char in token)
            or "*" in token
            or token.endswith("/")
            or token.startswith(("/", "~/"))
            or Path(token).suffix.lower() not in REPO_SOURCE_SUFFIXES
            or ("/" not in token and tracked is not None and token not in tracked)
        ):
            continue
        references.append(token)
    return references


def section_bodies(text: str) -> list[tuple[str, str]]:
    headings = list(HEADING_RE.finditer(text))
    sections: list[tuple[str, str]] = []
    for index, heading in enumerate(headings):
        level = len(heading.group(1))
        end = len(text)
        for next_heading in headings[index + 1 :]:
            if len(next_heading.group(1)) <= level:
                end = next_heading.start()
                break
        sections.append((heading.group(2), text[heading.end() : end]))
    return sections


def validate(text: str, tracked: set[str], label: str = "docs/decision_design.md") -> list[str]:
    errors: list[str] = []
    sections = section_bodies(text)
    section_names = {name for name, _ in sections if name in REQUIRED_SECTIONS}
    missing_sections = sorted(REQUIRED_SECTIONS - section_names)
    if missing_sections:
        errors.append(f"{label}: missing decision sections: {', '.join(missing_sections)}")

    for name, body in sections:
        if name not in REQUIRED_SECTIONS:
            continue
        if not re.search(r"\bEvidence:", body):
            errors.append(f"{label}: decision section {name!r} has no Evidence marker")
        if not any(reference in tracked for reference in source_references(body, tracked)):
            errors.append(f"{label}: decision section {name!r} has no tracked repository source reference")

    references = source_references(text)
    for reference in sorted(set(references)):
        if reference not in tracked:
            errors.append(f"{label}: referenced repository source is not currently tracked: {reference}")
    if not references:
        errors.append(f"{label}: no repository source references found")
    return errors


def self_test() -> int:
    tracked = {"README.md", "tooling/validate/decision_design.py"}
    good = "## Scope and evidence\nEvidence: `README.md`.\n## Intentional non-goals\nEvidence: `README.md`."
    bad_reference = good.replace("README.md", "tooling/missing.py")
    bad_evidence = good.replace("Evidence:", "Support:")
    cases = [(bad_reference, "not currently tracked"), (bad_evidence, "no Evidence marker")]
    for text, expected in cases:
        errors = validate(text, tracked, "fixture")
        if not any(expected in error for error in errors):
            print(f"decision-design self-test failed: expected {expected!r}", file=sys.stderr)
            return 1
    print("Decision-design traceability self-test passed.")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Check decision-record traceability only.")
    parser.add_argument("--self-test", action="store_true", help="run focused parser regression checks")
    args = parser.parse_args()
    if args.self_test:
        return self_test()
    if not DECISION_PATH.exists():
        print(f"{DECISION_PATH.relative_to(ROOT)}: missing", file=sys.stderr)
        return 1
    decision_text = DECISION_PATH.read_text()
    tracked = tracked_paths()
    errors = validate(decision_text, tracked)
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    references = sorted(set(source_references(decision_text, tracked)))
    print(
        "Decision-design traceability check passed "
        f"({len(references)} tracked source references; prose semantics are not mechanically proven)."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
