#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"
release=0
while [ "$#" -gt 0 ]; do
  case "$1" in --release) release=1;; *) printf 'usage: %s [--release]\n' "${BASH_SOURCE[0]}" >&2; exit 2;; esac
  shift
done
python3 tooling/generate/registry_sync.py --self-test --check
python3 tooling/validate/decision_design.py
python3 tooling/validate/behavior.py
python3 tooling/validate/mcp_policy.py
python3 tooling/validate/mcp_probe.py --self-test
python3 tooling/validate/session_readiness.py --self-test
python3 tooling/validate/suite_audit.py
python3 tooling/validate/browser_evidence.py --self-test
if [ "$release" -eq 1 ]; then
  bash tests/smoke/install.sh
  bash tests/smoke/messaging.sh
fi
