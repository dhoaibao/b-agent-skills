#!/usr/bin/env python3

"""Check the structured, still-editable CHANGELOG section.

This check validates shape and citation resolution only. It cannot verify that a
cited check semantically covers the change it claims to cover; prose semantics
remain a review responsibility.

The released sections below ``## Unreleased`` use a legacy single-bullet shape,
and older Unreleased list items without a title colon do too. The structural
contract therefore applies only to colon-terminated structured entries under
``## Unreleased``; released history and legacy bullets remain untouched.
"""

from __future__ import annotations

import re
import shlex
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CHANGELOG_PATH = ROOT / "CHANGELOG.md"
REQUIRED_SUB_BULLETS = ("Observed failure", "Intended behavior", "Regression")
UNCOVERED_MARKER = "no automated coverage:"
REPO_SOURCE_SUFFIXES = {".md", ".py", ".ts", ".json", ".yaml", ".yml", ".sh", ".toml"}
CODE_SPAN_RE = re.compile(r"`([^`]+)`")
PLAIN_PATH_RE = re.compile(
    r"(?<![@\w])(?:[A-Za-z0-9_.-]+/)+[A-Za-z0-9_.*@+-]+(?:\.[A-Za-z0-9_-]+)?"
)
SUB_BULLET_RE = re.compile(r"^  - (Observed failure|Intended behavior|Regression):")


def tracked_paths() -> set[str]:
    result = subprocess.run(
        ["git", "ls-files"], cwd=ROOT, check=True, capture_output=True, text=True
    )
    return set(result.stdout.splitlines())


def unreleased_lines(text: str) -> list[tuple[int, str]]:
    heading = re.search(r"^## Unreleased\s*$", text, re.MULTILINE)
    if heading is None:
        return []
    body_start = heading.end()
    next_release = re.search(r"^## (?!#)\S.*$", text[body_start:], re.MULTILINE)
    body = text[body_start : body_start + next_release.start()] if next_release else text[body_start:]
    first_line = text[:body_start].count("\n") + 1
    return [(first_line + index, line) for index, line in enumerate(body.splitlines())]


def entry_blocks(lines: list[tuple[int, str]]) -> list[list[tuple[int, str]]]:
    starts = [index for index, (_, line) in enumerate(lines) if line.startswith("- ")]
    return [lines[start : starts[position + 1] if position + 1 < len(starts) else len(lines)] for position, start in enumerate(starts)]


def title_for(block: list[tuple[int, str]]) -> str:
    parts: list[str] = []
    for _, line in block:
        if SUB_BULLET_RE.match(line) or line.startswith("  - "):
            break
        if line.startswith("- "):
            parts.append(line[2:].strip())
        else:
            parts.append(line.strip())
    return " ".join(part for part in parts if part)


def regression_text(block: list[tuple[int, str]]) -> str:
    for index, (_, line) in enumerate(block):
        if line.startswith("  - Regression:"):
            parts = [line.removeprefix("  - Regression:").strip()]
            for _, continuation in block[index + 1 :]:
                if continuation.startswith("  - ") or continuation.startswith("- "):
                    break
                parts.append(continuation.strip())
            return " ".join(part for part in parts if part)
    return ""


def candidate_path(token: str) -> str | None:
    token = token.strip().strip(".,;:!?)]}>")
    token = token.lstrip("([{<")
    if not token or token.startswith(("@", "npm:", "http:", "https:")):
        return None
    if "*" in token:
        return token
    if "/" in token:
        if not re.fullmatch(r"(?:[A-Za-z0-9_.-]+/)+[A-Za-z0-9_.*@+-]+(?:\.[A-Za-z0-9_-]+)?", token):
            return None
        if Path(token).suffix.lower() not in REPO_SOURCE_SUFFIXES:
            return None
        return token
    if Path(token).suffix.lower() in REPO_SOURCE_SUFFIXES:
        return token
    return None


def path_citations(text: str, tracked: set[str]) -> list[str]:
    citations: list[str] = []
    for raw in CODE_SPAN_RE.findall(text):
        try:
            tokens = shlex.split(raw)
        except ValueError:
            tokens = raw.split()
        for index, token in enumerate(tokens):
            if token == "--prefix" and index + 1 < len(tokens):
                citation = candidate_path(tokens[index + 1]) or tokens[index + 1]
                if citation and citation not in citations:
                    citations.append(citation)
                continue
            citation = candidate_path(token)
            if citation and ("/" in citation or resolve_path(citation, tracked)) and citation not in citations:
                citations.append(citation)
    for token in PLAIN_PATH_RE.findall(text):
        citation = candidate_path(token)
        if citation and citation not in citations:
            citations.append(citation)
    return citations


def resolve_path(citation: str, tracked: set[str]) -> bool:
    if "*" in citation:
        # Wildcard citations are intentionally skipped, following decision_design.py.
        return True
    normalized = citation.removeprefix("./")
    exact = ROOT / normalized
    if normalized in tracked:
        return exact.is_file()
    if exact.is_dir():
        return any(path.startswith(normalized.rstrip("/") + "/") for path in tracked)
    suffix_matches = [path for path in tracked if path.endswith("/" + normalized)]
    return len(suffix_matches) == 1 and (ROOT / suffix_matches[0]).is_file()


RUNNABLE_COMMANDS = {"bash", "node", "npm", "python", "python3", "rtk", "sh"}


def has_runnable_command(text: str) -> bool:
    for raw in CODE_SPAN_RE.findall(text):
        try:
            tokens = shlex.split(raw)
        except ValueError:
            tokens = raw.split()
        if tokens and tokens[0] in RUNNABLE_COMMANDS:
            return True
    return False


def uncovered_reason(text: str) -> str:
    marker_index = text.lower().find(UNCOVERED_MARKER)
    if marker_index < 0:
        return ""
    reason = text[marker_index + len(UNCOVERED_MARKER) :].strip()
    return reason if re.search(r"[A-Za-z0-9]", reason) else ""


def validate(text: str, tracked: set[str]) -> tuple[list[str], int, int, int, int]:
    errors: list[str] = []
    lines = unreleased_lines(text)
    if not lines:
        return ["CHANGELOG.md: missing ## Unreleased section"], 0, 0, 0, 0

    structured_count = 0
    citation_count = 0
    citation_entries = 0
    uncovered_entries = 0
    for block in entry_blocks(lines):
        title = title_for(block)
        if not title.endswith(":"):
            # Legacy Unreleased list items have no structured title colon and
            # remain untouched, just like the released sections below Unreleased.
            continue
        structured_count += 1
        labels = []
        for _, line in block:
            if line.startswith("  - "):
                match = SUB_BULLET_RE.match(line)
                labels.append(match.group(1) if match else line[4:].split(":", 1)[0])
        if tuple(labels) != REQUIRED_SUB_BULLETS:
            errors.append(
                f"CHANGELOG.md: entry {title!r} must have exactly these sub-bullets in order: "
                + ", ".join(REQUIRED_SUB_BULLETS)
            )
            continue

        regression = regression_text(block)
        citations = path_citations(regression, tracked)
        citation_count += len(citations)
        reason = uncovered_reason(regression)
        if citations:
            citation_entries += 1
        elif reason:
            uncovered_entries += 1
        for citation in citations:
            if not resolve_path(citation, tracked):
                errors.append(
                    f"CHANGELOG.md: entry {title!r} Regression cites missing or untracked path {citation!r}"
                )
        has_marker = UNCOVERED_MARKER in regression.lower()
        if has_marker and not reason:
            errors.append(
                f"CHANGELOG.md: entry {title!r} Regression declares {UNCOVERED_MARKER!r} without a substantive reason"
            )
        if not citations and not has_runnable_command(regression) and not reason and not has_marker:
            errors.append(
                f"CHANGELOG.md: entry {title!r} Regression must cite a concrete repository path or runnable command "
                f"or declare {UNCOVERED_MARKER!r} with a substantive reason"
            )

    return errors, structured_count, citation_count, citation_entries, uncovered_entries


def main() -> int:
    if not CHANGELOG_PATH.exists():
        print("CHANGELOG.md: missing", file=sys.stderr)
        return 1
    errors, structured_count, citation_count, citation_entries, uncovered_entries = validate(
        CHANGELOG_PATH.read_text(), tracked_paths()
    )
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print(
        "CHANGELOG validation passed "
        f"({structured_count} structured Unreleased entries; "
        f"{citation_entries} with citations, {uncovered_entries} explicitly uncovered; "
        f"{citation_count} citations resolved)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
