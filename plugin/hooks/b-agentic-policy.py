#!/usr/bin/env python3
"""Claude Code PreToolUse policy hook for b-agentic.

The hook is deliberately fail-closed: malformed input, unknown tools, and
unclassified MCP operations return a deny decision.  The canonical operation
classes are copied into ``mcp_policy.json`` by the registry generator.
"""
from __future__ import annotations

import json
import os
import re
import shlex
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent
try:
    POLICY = json.loads((ROOT / "mcp_policy.json").read_text())
except Exception:
    POLICY = {}

Decision = tuple[str, str]
PROTECTED_MARKERS = (
    ".env", ".envrc", "credentials.", "secrets.", ".pem", ".key", ".p12", ".pfx",
    ".npmrc", ".netrc", ".pypirc", ".git-credentials", ".ssh/", ".config/gh/",
    ".aws/", ".kube/", "/.git/", ".git/", "id_rsa", "id_ed25519", "id_ecdsa", "id_dsa",
)
DENY_PREFIXES = (
    ("git", "reset", "--hard"), ("git", "clean", "-f"),
    ("git", "push", "--force"), ("git", "push", "--force-with-lease"),
    ("git", "branch", "-D"), ("docker", "system", "prune"),
    ("docker", "volume", "rm"),
)
ASK_PREFIXES = (("git", "push"), ("git", "pull"), ("rm", "-rf"), ("rm", "-fr"))
DANGEROUS_PREFIXES = (
    ("dd",), ("mkfs",), ("chmod",), ("chown",), ("kill",), ("pkill",),
    ("killall",), ("shutdown",), ("reboot",), ("poweroff",), ("halt",),
    ("systemctl", "stop"), ("systemctl", "restart"), ("systemctl", "disable"),
    ("docker", "rm"), ("docker", "container", "rm"), ("docker", "image", "rm"),
    ("docker", "compose", "down"), ("kubectl", "delete"),
)
EXTERNAL_MUTATIONS = {"aws", "psql", "scp", "sftp", "ssh"}
RTK_COMMANDS = {
    "git", "gh", "glab", "aws", "psql", "pnpm", "dotnet", "docker", "kubectl", "oc",
    "wget", "jest", "vitest", "prisma", "tsc", "next", "lint", "prettier", "format",
    "playwright", "cargo", "npm", "npx", "curl", "ruff", "pytest", "mypy", "rake",
    "rubocop", "rspec", "pip", "go", "gt", "golangci-lint", "gradlew", "mvn", "ecs",
    "paratest", "pest", "php", "phpstan", "phpunit", "pint", "sbt", "uv", "ls", "tree",
    "find", "diff", "grep", "rg", "wc",
}
LOCAL_PATH_COMMANDS = {
    "cat", "bat", "batcat", "cmp", "cp", "curl", "diff", "eza", "exa", "fd", "fdfind",
    "file", "find", "git", "grep", "head", "install", "ln", "ls", "make", "mkdir", "mv",
    "readlink", "realpath", "rg", "rm", "rmdir", "rsync", "sed", "stat", "tail", "tar",
    "tee", "test", "touch", "truncate", "unzip", "wc", "wget", "zip",
}
INTERPRETERS = {"bash", "sh", "dash", "zsh", "ksh", "fish", "node", "nodejs", "python", "python3", "ruby", "perl", "php", "lua", "deno", "bun"}


def result(decision: str, reason: str = "") -> dict[str, Any]:
    return {"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": decision, "permissionDecisionReason": reason or "b-agentic policy"}}


def emit(decision: str, reason: str = "") -> None:
    sys.stdout.write(json.dumps(result(decision, reason)) + "\n")


def protected(path: str) -> bool:
    value = path.replace("\\", "/")
    parts = value.split("/")
    base = parts[-1] if parts else value
    if base == ".env.example":
        value_without_example = value.replace("/.env.example", "")
    else:
        value_without_example = value
    for marker in PROTECTED_MARKERS:
        if marker == ".env" and base == ".env.example":
            continue
        if marker.endswith("/") or marker.startswith("/"):
            if marker in value:
                return True
        elif marker in {"credentials.", "secrets."}:
            if any(part.startswith(marker) for part in parts):
                return True
        elif marker.startswith("id_"):
            if any(part == marker or part.startswith((marker + ".", marker + "_", marker + "-")) for part in parts):
                return True
        elif base == marker or base.startswith(marker + ".") or marker in value_without_example:
            return True
    return False


def cwd_for(event: dict[str, Any]) -> Path:
    raw = event.get("cwd") or os.getcwd()
    try:
        return Path(str(raw)).expanduser().resolve()
    except Exception:
        return Path.cwd().resolve()


def inside(path: str, project: Path) -> bool:
    try:
        candidate = Path(path).expanduser()
        if not candidate.is_absolute():
            candidate = project / candidate
        candidate = candidate.resolve(strict=False)
        candidate.relative_to(project)
        return True
    except Exception:
        return False


def path_decision(tool: str, path: str, project: Path) -> Decision:
    if not path:
        return "deny", f"Denied by b-agentic policy: {tool} requires a path"
    if protected(path):
        if tool.lower() in {"read", "glob", "grep"}:
            return "ask", f"Requires approval: {tool} of protected path: {path}"
        return "deny", f"Denied by b-agentic policy: protected path: {path}"
    if not inside(path, project):
        return "ask", f"Requires approval: {tool} outside the project: {path}"
    return "allow", ""


def prefix(tokens: list[str], pattern: tuple[str, ...]) -> bool:
    return len(tokens) >= len(pattern) and tokens[: len(pattern)] == list(pattern)


def strip_wrappers(tokens: list[str]) -> tuple[list[str], bool, bool]:
    i = 0
    opaque = False
    rtk = False
    while i < len(tokens) and re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", tokens[i]):
        i += 1
    while i < len(tokens) and tokens[i] in {"sudo", "command", "nohup", "nice", "time", "env", "rtk"}:
        wrapper = tokens[i]
        if wrapper == "sudo":
            i += 1
            while i < len(tokens) and tokens[i].startswith("-"):
                i += 2 if tokens[i] in {"-u", "-g", "-C", "-n", "-p"} else 1
        elif wrapper == "env":
            i += 1
            while i < len(tokens) and ("=" in tokens[i] or tokens[i].startswith("-")):
                if tokens[i] in {"-u", "-C"}:
                    i += 2
                elif tokens[i] == "-S":
                    opaque = True
                    i += 2
                else:
                    i += 1
        elif wrapper == "rtk":
            rtk = True
            i += 1
            while i < len(tokens) and tokens[i] in {"--ultra-compact", "--skip-env", "-v", "-vv", "-vvv", "--verbose"}:
                i += 1
            if i < len(tokens) and tokens[i] in {"proxy", "err", "test", "summary", "run"}:
                i += 1
                if i < len(tokens) and tokens[i] in {"-c", "--command"}:
                    opaque = True
                    i += 2
        else:
            i += 1
    return tokens[i:], opaque, rtk


COMPOUND_PUNCTUATION = frozenset(";&|<>()")


def split_shell_commands(text: str) -> tuple[list[list[str]], bool]:
    """Tokenize shell punctuation without treating quoted punctuation as syntax."""
    lexer = shlex.shlex(text.replace("\n", ";"), posix=True, punctuation_chars=";&|<>()")
    lexer.whitespace_split = True
    tokens = list(lexer)
    segments: list[list[str]] = []
    current: list[str] = []
    compound = "\n" in text
    for token in tokens:
        if token and set(token) <= COMPOUND_PUNCTUATION:
            compound = True
            if current:
                segments.append(current)
                current = []
        else:
            current.append(token)
    if current:
        segments.append(current)
    return segments, compound


def bash_decision(command: str, project: Path) -> Decision:
    text = command.strip()
    if not text:
        return "allow", ""
    try:
        segments, compound = split_shell_commands(text)
    except ValueError:
        return "ask", "Requires approval: unbalanced shell quotes"
    if compound:
        decisions = [bash_decision(" ".join(segment), project) for segment in segments if segment]
        denied = next((decision for decision in decisions if decision[0] == "deny"), None)
        if denied is not None:
            return denied
        return "ask", "Requires approval: compound shell command or separator"
    if re.search(r"(?:^|[;&|\n])\s*(?:if|for|while|until|case|function|then|else|do|done)\b", text) or re.search(r"[$`]", text) or re.search(r"\b(?:source|eval)\b", text) or re.search(r"[<>]\(", text):
        return "ask", "Requires approval: ambiguous shell syntax (expansion/control structure/eval/source)"
    try:
        raw = shlex.split(text, posix=True)
    except ValueError:
        return "ask", "Requires approval: unbalanced shell quotes"
    if not raw:
        return "allow", ""
    tokens, opaque_wrapper, rtk = strip_wrappers(raw)
    if opaque_wrapper:
        return "ask", "Requires approval: opaque shell wrapper"
    if not tokens:
        return "ask", "Requires approval: standalone environment command"
    command_name = Path(tokens[0]).name
    tokens[0] = command_name
    if any(protected(token) for token in tokens if not token.startswith("!")):
        return "ask", "Requires approval: shell command references a protected path"
    for denied in DENY_PREFIXES:
        if prefix(tokens, denied) or (denied == ("git", "clean", "-f") and prefix(tokens, ("git", "clean")) and any("f" in t.lstrip("-") for t in tokens[2:])):
            return "deny", f"Denied by b-agentic policy: {' '.join(denied)}"
    if command_name == "git" and "push" in tokens and any(x in tokens for x in {"--force", "--force-with-lease", "-f"}):
        return "deny", "Denied by b-agentic policy: git push --force"
    if command_name == "git" and tokens[1:2] == ["branch"] and "-D" in tokens:
        return "deny", "Denied by b-agentic policy: git branch -D"
    if command_name in INTERPRETERS and any(t in {"-c", "-e", "--eval", "-Command", "-"} or t.startswith("--eval=") for t in tokens[1:]):
        return "ask", "Requires approval: opaque script invocation"
    if command_name in {"sudo"} or "sudo" in raw:
        return "ask", "Requires approval: sudo elevates command privileges"
    if command_name == "rm":
        return "ask", "Requires approval: shell command removes local files"
    for ask in ASK_PREFIXES + DANGEROUS_PREFIXES:
        if prefix(tokens, ask) or (ask == ("mkfs",) and command_name.startswith("mkfs.")):
            return "ask", f"Requires approval: {' '.join(ask)}"
    if command_name in EXTERNAL_MUTATIONS:
        return "ask", "Requires approval: external or shared-environment operation may mutate state"
    if command_name in {"gh", "glab", "kubectl", "oc", "docker"}:
        read_only = {"status", "list", "ls", "get", "show", "view", "diff", "logs", "ps", "images", "info", "inspect", "version", "config", "describe", "explain", "api-resources", "api-versions", "cluster-info"}
        if not any(t in read_only for t in tokens[1:]):
            return "ask", "Requires approval: external or shared-environment operation may mutate state"
    if command_name in {"curl", "wget"} and any(re.match(r"(?:-d|-F|-T|-X|--data|--form|--request|--upload-file)", t) for t in tokens[1:]):
        return "ask", "Requires approval: external or shared-environment operation may mutate state"
    for i, token in enumerate(tokens[1:], start=1):
        if token.startswith(("-", "!")) or re.match(r"^\d+$", token) or "://" in token:
            continue
        if command_name in LOCAL_PATH_COMMANDS and not inside(token, project):
            return "ask", "Requires approval: shell command reads or mutates outside the project"
    if command_name in RTK_COMMANDS and not rtk:
        # This is guidance rather than a hard denial: the Claude permission
        # model must not make ordinary repository work unusable when RTK is absent.
        pass
    if command_name == "rm" and any(t in {"-r", "-R", "--recursive"} or (t.startswith("-") and "r" in t) for t in tokens[1:]):
        return "ask", "Requires approval: recursive rm"
    return "allow", ""


SERENA_PATH_ARGUMENTS = (
    "relative_path",
    "path",
    "file_path",
    "paths_include_glob",
    "paths_exclude_glob",
)


def mcp_path_decision(server: str, operation: str, classification: str, tool_input: dict[str, Any], project: Path) -> Decision:
    if server != "serena":
        return "allow", ""
    configured = POLICY.get("path_arguments", {}).get(server) if isinstance(POLICY.get("path_arguments", {}), dict) else None
    path_arguments = tuple(value for value in configured if isinstance(value, str)) if isinstance(configured, list) else SERENA_PATH_ARGUMENTS
    path_values = [(key, tool_input[key]) for key in path_arguments if key in tool_input]
    for key, value in path_values:
        if not isinstance(value, str) or not value.strip():
            return "deny", f"Denied by b-agentic policy: invalid MCP path argument {key} for {server}:{operation}"
    # Serena's local mutations must never write a protected path. Reads and
    # outside-project targets require explicit approval, matching native tools.
    tool = "Write" if classification == "conditional-local" else "Read"
    pending: Decision | None = None
    for key, value in path_values:
        decision = path_decision(tool, value, project)
        if decision[0] == "deny":
            return decision[0], f"{decision[1]} (MCP argument {key})"
        if decision[0] == "ask":
            pending = (decision[0], f"{decision[1]} (MCP argument {key})")
    if pending is not None:
        return pending
    return "allow", ""


def mcp_decision(tool_name: str, tool_input: Any, project: Path) -> Decision:
    match = re.match(r"^mcp__([^_]+(?:-[^_]+)*)__(.+)$", tool_name)
    if not match:
        return "deny", f"Denied by b-agentic policy: unclassified tool {tool_name}"
    server, operation = match.groups()
    servers = POLICY.get("servers", {}) if isinstance(POLICY, dict) else {}
    server_data = servers.get(server)
    if not isinstance(server_data, dict):
        return "deny", f"Denied by b-agentic policy: unmanaged MCP server {server}"
    classification = server_data.get("tools", {}).get(operation)
    if classification in {"read-only", "trusted-serena"}:
        return "allow", ""
    conditional = POLICY.get("conditional_arguments", {}).get(f"{server}:serena_{operation}") or POLICY.get("conditional_arguments", {}).get(f"{server}:{operation}")
    if classification in {"conditional-read", "conditional-local"}:
        if not isinstance(tool_input, dict):
            return "deny", "Denied by b-agentic policy: MCP arguments must be an object"
        known = conditional.get("known", []) if isinstance(conditional, dict) else []
        if not all(isinstance(k, str) and k in known for k in tool_input):
            return "deny", f"Denied by b-agentic policy: unclassified arguments for {server}:{operation}"
        return mcp_path_decision(server, operation, classification, tool_input, project)
    if classification:
        return "ask", f"Requires approval: MCP operation {server}:{operation}"
    return "deny", f"Denied by b-agentic policy: unclassified MCP operation {server}:{operation}"


def main() -> None:
    try:
        event = json.load(sys.stdin)
        if not isinstance(event, dict):
            raise ValueError("event must be an object")
        tool = str(event.get("tool_name") or event.get("toolName") or "")
        data = event.get("tool_input") if isinstance(event.get("tool_input"), dict) else event.get("input", {})
        project = cwd_for(event)
        if tool == "Bash":
            decision = bash_decision(str(data.get("command", "")) if isinstance(data, dict) else "", project)
        elif tool in {"Read", "Edit", "Write", "Glob", "Grep"}:
            path = str((data or {}).get("file_path") or (data or {}).get("path") or (data or {}).get("pattern") or "")
            decision = path_decision(tool, path, project)
        elif tool.startswith("mcp__"):
            decision = mcp_decision(tool, data, project)
        elif tool in {"ListAgents", "SendMessage", "TodoWrite", "WebFetch", "WebSearch", "AskUserQuestion"}:
            decision = ("allow", "")
        else:
            decision = ("deny", f"Denied by b-agentic policy: unclassified tool {tool or '<missing>'}")
        emit(*decision)
    except Exception as exc:
        emit("deny", f"Denied by b-agentic policy: hook input error ({type(exc).__name__})")


if __name__ == "__main__":
    main()
