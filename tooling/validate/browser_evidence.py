#!/usr/bin/env python3
"""Validate opt-in browser evidence artifact paths without starting a browser."""

from __future__ import annotations

import argparse
import tempfile
from pathlib import Path


def safe_evidence_path(approved_dir: Path, candidate: str | Path) -> bool:
    """Return whether candidate resolves strictly below the approved directory."""
    if not str(candidate):
        return False
    root = approved_dir.expanduser().resolve()
    path = Path(candidate).expanduser()
    resolved = (root / path if not path.is_absolute() else path).resolve()
    return resolved != root and root in resolved.parents


def self_test() -> int:
    with tempfile.TemporaryDirectory(prefix="b-agentic-browser-evidence-") as temporary:
        root = Path(temporary) / "approved"
        root.mkdir()
        cases = {
            "browser/run-1/manifest.json": True,
            "browser/run-1/snapshot.txt": True,
            "../outside.json": False,
            str(Path(temporary) / "outside.json"): False,
            ".": False,
            "": False,
        }
        for candidate, expected in cases.items():
            if safe_evidence_path(root, candidate) != expected:
                print(f"browser evidence path fixture failed: {candidate!r}")
                return 1
    print("Browser evidence path self-test passed.")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        return self_test()
    parser.error("use --self-test")
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
