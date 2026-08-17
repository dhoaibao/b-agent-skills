#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
planner="$ROOT_DIR/plugin/agents/b-planner.md"
worker="$ROOT_DIR/plugin/agents/b-worker.md"
for path in "$planner" "$worker"; do
  grep -q 'ListAgents' "$path"
  grep -q 'SendMessage' "$path"
done
grep -q 'read-only' "$planner"
grep -q 'sole worktree writer' "$worker"
! grep -q -E 'pending|verbatim-ID|cross-session inbound protocol' "$planner" "$worker"
printf '%s\n' 'Claude cross-session messaging configuration smoke passed.'
