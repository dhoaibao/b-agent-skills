#!/usr/bin/env python3
"""Best-effort Claude Code session status hook."""
from __future__ import annotations
import json
import os
import sys

try:
    event = json.load(sys.stdin)
except Exception:
    event = {}
source = event.get("source", "session") if isinstance(event, dict) else "session"
# Hook output is context-only; a notification/status failure must never stop a session.
print(json.dumps({"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": f"b-agentic Claude workflow kernel active ({source}); solo mode is the default."}}))
