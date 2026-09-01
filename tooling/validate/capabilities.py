#!/usr/bin/env python3
"""Validate the canonical managed-capability contract and generated runtime copy."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))


def main() -> int:
    from tooling.generate.registry_sync import (
        CAPABILITIES_OUTPUT_PATH,
        load_capabilities,
        render_capability_module,
        validate_capabilities,
        validate_capability_regressions,
    )

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--self-test",
        action="store_true",
        help="also verify deterministic contract-validation regressions",
    )
    args = parser.parse_args()

    contract = load_capabilities()
    errors = validate_capabilities(contract)
    if args.self_test:
        errors.extend(validate_capability_regressions(contract))
    generated = render_capability_module(contract)
    if not CAPABILITIES_OUTPUT_PATH.exists():
        errors.append(f"{CAPABILITIES_OUTPUT_PATH}: missing generated capability module")
    elif CAPABILITIES_OUTPUT_PATH.read_text() != generated:
        errors.append(f"{CAPABILITIES_OUTPUT_PATH}: generated capability module is out of date")

    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print("Capability contract validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
