#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

bash -n "$ROOT_DIR/pi/scripts/install-preview-markdown.sh"
bash -n "$ROOT_DIR/pi/scripts/typecheck.sh"
bash -n "$ROOT_DIR/pi/scripts/typecheck-preview-markdown.sh"

python3 - <<'PY'
from pathlib import Path
import json
import re
import sys

root = Path('.')
errors = []
kernel = root / 'references/kernel.template.md'
mcp = root / 'pi/configs/mcp.user.template.json'
extension = root / 'pi/extensions/b-agentic-permissions.ts'
preview_extension = root / 'pi/packages/preview-markdown/extensions/b-agentic-preview-markdown.ts'
preview_package = root / 'pi/packages/preview-markdown/package.json'
preview_tag_sections = [
    (
        root / 'README.md',
        'To install only the inline Markdown preview extension',
        'After the standalone package is published',
    ),
    (
        root / 'REFERENCE.md',
        'After the public immutable',
        'After the package is published',
    ),
    (
        root / 'pi/packages/preview-markdown/README.md',
        'For a version-pinned GitHub install',
        '## Scope',
    ),
]
extension_files = [
    extension,
    preview_extension,
    root / 'pi/extensions/b-agentic-mcp-permissions.ts',
    root / 'pi/extensions/b-agentic-auto-mode.ts',
    root / 'pi/extensions/b-agentic-role.ts',
    root / 'pi/extensions/b-agentic-planner.ts',
    root / 'pi/extensions/b-agentic-planner-notify.ts',
    root / 'pi/extensions/b-agentic-worker.ts',
    root / 'pi/extensions/b-agentic-sync.ts',
    root / 'pi/extensions/b-agentic-support/shell.ts',
    root / 'pi/extensions/b-agentic-support/mcp.ts',
    root / 'pi/extensions/b-agentic-support/role.ts',
    root / 'pi/extensions/b-agentic-support/role-models.ts',
    root / 'pi/extensions/b-agentic-support/worker.ts',
    root / 'pi/extensions/b-agentic-support/auto.ts',
]
readme = root / 'pi/configs/README.md'
standalone_preview_installer = root / 'pi/scripts/install-preview-markdown.sh'

for path in [kernel, mcp, *extension_files, readme, standalone_preview_installer, preview_package]:
    if not path.exists():
        errors.append(f'{path}: missing')

if kernel.exists():
    text = kernel.read_text()
    for marker in [
        'Pi Workflow Kernel', 'b-agentic defaults to Off', 'Planner-owned skills: `b-plan`, external `b-research`',
        'Worker-owned skills: `b-design`, `b-implement`, `b-init`, `b-refactor`, `b-debug`, `b-test`, `b-browser`, `b-commit`',
        'Ownership governs execution, not inspection', 'Planner-owned only when execution is read-only decision/planning',
        'Mixed or uncertain skills are worker-owned', 'Unknown or ambiguous skill ownership is worker-owned',
        'Worker is the sole worktree writer', 'same-CWD roster',
        'ask_user_question', '2–4 concrete options', ' (Recommended)', 'automatic custom-answer row',
        'focused plain-text question',
    ]:
        if marker not in text:
            errors.append(f'{kernel}: missing {marker!r}')

role_prompt = (root / 'pi/extensions/b-agentic-support/role.ts').read_text()
for marker in [
    # generated:role-prompt-markers:validate:start
    "Finish discovery before one bounded handoff",
    "Use send for task delegation and worker result/review reporting; use ask only for blockers, clarifications, or a planner's quick-answer need—not to wait",
    "Roster/status only selects or handles",
    "Before every Intercom send/reply call pending",
    "Reply to an inbound ask without send/list-cwd",
    "identifier token verbatim",
    "authoritative short ID is valid",
    "never guess, reconstruct, extend, further abbreviate, or reuse stale output",
    "Delivery makes a handoff, result, finding, or approval real",
    "one retry only",
    "applicable observable behavior, scope/non-goals, constraints/invariants",
    "send a completion/result to the same assigning planner before pausing",
    "including when no edits were needed or the task ends with a reported gap",
    "latest approved plan, handoff, and clarifications",
    "Only delegated worktree-changing tasks require actual b-review",
    "location, evidence, impact, violated baseline, smallest correction, and regression check",
    "For audit/review verification you cannot run, request bounded worker evidence",
    "same worker may b-commit only on explicit user request",
# generated:role-prompt-markers:validate:end
]:
    if marker not in role_prompt:
        errors.append(f"{root / 'pi/extensions/b-agentic-support/role.ts'}: missing {marker!r}")

if mcp.exists():
    data = json.loads(mcp.read_text())
    servers = data.get('mcpServers', {})
    for server in ['serena', 'context7', 'codegraph', 'linear', 'brave-search', 'firecrawl', 'playwright']:
        if server not in servers:
            errors.append(f'{mcp}: missing MCP server {server!r}')
        elif servers[server].get('lifecycle') != 'lazy':
            errors.append(f'{mcp}: {server} must use lifecycle lazy by default')
    linear = servers.get('linear', {})
    if linear.get('url') != 'https://mcp.linear.app/mcp/readonly' or linear.get('auth') != 'oauth' or linear.get('oauth', {}).get('scope') != 'read' or linear.get('includeTools') != ['get_issue']:
        errors.append(f'{mcp}: linear must be a read-only OAuth get_issue server')
    settings = data.get('settings', {})
    if settings.get('directTools') not in (False, None):
        errors.append(f'{mcp}: default directTools must be false (proxy tool default)')
    if settings.get('requestTimeoutMs') != 30000:
        errors.append(f'{mcp}: default requestTimeoutMs must be 30000 milliseconds')

if extension.exists():
    text = '\n'.join(path.read_text() for path in extension_files if path.exists())
    if preview_extension.exists():
        preview_text = preview_extension.read_text()
        for marker in [
            'preview_markdown', 'promptSnippet', 'promptGuidelines', 'ctx.mode', 'renderResult',
            'registerShortcut', 'ctrl+shift+m', 'copyToClipboard',
            'PALETTE', '#1e2030', '#222436', '#191b29', '#2f334d', '#c8d3f5', '#828bb8', '#636da6',
            '#3b4261', '#82aaff', '#86e1fc', '#ffc777', '#c3e88d', '#c099ff', '#65bcff',
            '#d5d6db', '#e1e2e7', '#c4c8da', '#dcdfe4', '#3760bf', '#6172b0', '#848cb5',
            '#8990b3', '#2e7de9', '#007197', '#8c6c3e', '#587539', '#9854f1',
            'getAgentDir', 'preview-markdown:render', 'preview-markdown:theme', 'preview-markdown:list', 'MAX_PREVIEW_HISTORY', 'currentPreviewTheme', 'previewRowInvalidators', 'clearPreviewRowInvalidators', 'loadCurrentPreviewTheme', 'session_shutdown', 'Tokyo Night Day', 'preview-theme.json',
            'FIXED_PAGE_BACKGROUND',
            'FIXED_CARD_BACKGROUND', 'PreviewCard', 'Ctrl+Shift+M  Copy source', 'Markdown preview rendered inline',
        ]:
            if marker not in preview_text:
                errors.append(f'{preview_extension}: missing preview marker {marker!r}')
    for marker in [
        'tool_call', 'isAutoApprovedIntercomCall', 'PLANNER_PROMPT', 'workerPrompt',
        'planner profile (read-only coordinator)', 'worker profile (implementation)',
        'SKILL_OWNERS', 'skillOwner', 'SKILL_OWNERSHIP_CRITERION', 'sole worktree writer', 'external b-research',
        'Planner-owned only when execution is read-only decision/planning', 'Mixed or uncertain skills are worker-owned',
        'Ownership governs execution, not inspection', 'bounded worker evidence',
        'applicable observable behavior', 'identifier token verbatim',
        'For a two-role material blocker', 'ask the assigning planner one focused question using its returned identifier token verbatim',
        'execute the assigned worker-owned work yourself', 'never delegate or hand off any part of it to another worker',
        'only for a material blocker, scope decision, or external-research decision',
        'At every terminal outcome in a two-role task', 'no edits were needed', 'reported gap',
        'same assigning planner before pausing',
        'authoritative short ID is valid', 'never guess, reconstruct, extend, further abbreviate',
        'actual b-review', 'latest approved plan, handoff, and clarifications',
        'unchanged reviewed snapshot', 'isDirectClassifiedManagedTool',
        'isSafeSerenaSymbolRead', 'mcpScript', 'serena_onboarding',
        'Planner task delegation remains prompt-governed', 'Roles guide skill execution through their prompts',
    ]:
        if marker not in text:
            errors.append(f'{extension}: missing policy marker {marker!r}')
    planner_extension = root / 'pi/extensions/b-agentic-planner.ts'
    planner_text = planner_extension.read_text() if planner_extension.exists() else ''
    planner_body = planner_text.split('export const __test__', 1)[0]
    if 'pi.on("tool_call"' in planner_body:
        errors.append(f'{planner_extension}: planner roles must not add role-specific tool-call blocks')
    if 'plannerCommandDecision(' in planner_body or 'isPlannerReadOnlyMcpCall(' in planner_body:
        errors.append(f'{planner_extension}: planner commands and MCP calls must use shared policy, not role-specific blocks')
    mcp_permissions = root / 'pi/extensions/b-agentic-mcp-permissions.ts'
    if 'getRole() === "planner"' in mcp_permissions.read_text():
        errors.append(f'{mcp_permissions}: planner MCP broker restrictions must not override shared policy')
    if 'return { block: true' not in text and 'block: true' not in text:
        errors.append(f'{extension}: must be able to block tool calls')
    if 'custom/MCP tool' not in text and 'MCP' not in text:
        errors.append(f'{extension}: must gate MCP/custom tools')
    for server in ['serena', 'codegraph', 'context7', 'linear', 'brave-search', 'firecrawl', 'playwright']:
        if f'"{server}"' not in text:
            errors.append(f'{extension}: missing managed MCP server {server!r}')
    firecrawl_trusted = re.search(r'FIRECRAWL_TRUSTED_TOOLS = new Set\(\[(.*?)\]\)', text, re.DOTALL)
    if firecrawl_trusted:
        # Exact quoted ids only so firecrawl_agent_status / firecrawl_interact_stop remain allowed.
        for forbidden in [
            '"firecrawl_interact"',
            '"firecrawl_parse"',
            '"firecrawl_search_feedback"',
            '"firecrawl_feedback"',
            '"firecrawl_agent"',
            '"firecrawl_crawl"',
        ]:
            if forbidden in firecrawl_trusted.group(1):
                errors.append(f'{extension}: {forbidden} must not be in FIRECRAWL_TRUSTED_TOOLS')
    playwright_trusted = re.search(r'PLAYWRIGHT_TRUSTED_TOOLS = new Set\(\[(.*?)\]\)', text, re.DOTALL)
    if playwright_trusted and re.search(r'"browser_click"', playwright_trusted.group(1)):
        errors.append(f'{extension}: browser_click must not be in PLAYWRIGHT_TRUSTED_TOOLS')
    if 'isTrustedManagedGatewayCall' not in text or 'isMcpProxyToolExecution' not in text or 'isTrustedPreviewMarkdownCall' not in text or 'if (toolName === "mcp") return !isMcpProxyToolExecution(input);' not in text:
        errors.append(f'{extension}: must route only explicit MCP proxy executions through the adapter broker')
    if 'Blocked' not in text or 'protected path' not in text:
        errors.append(f'{extension}: must block protected paths')
    # read must share protected-path handling with write/edit
    if 'event.toolName === "read"' not in text and 'toolName === "read"' not in text:
        # Accept combined write/edit/read branch
        if not re.search(r'toolName === "write".*toolName === "edit".*toolName === "read"', text, re.DOTALL):
            if 'read' not in text or 'isProtectedPath' not in text:
                errors.append(f'{extension}: must apply protected-path policy to read')

if standalone_preview_installer.exists():
    text = standalone_preview_installer.read_text()
    for marker in [
        'dhoaibao/b-agentic', 'VERSION', 'invalid version',
        'pi/packages/preview-markdown/extensions/b-agentic-preview-markdown.ts',
        'PI_CODING_AGENT_DIR', 'registerShortcut("ctrl+shift+m"',
        'name: "preview_markdown"', 'export default function',
        'Run /reload', 'AGENTS.md',
    ]:
        if marker not in text:
            errors.append(f'{standalone_preview_installer}: missing installer marker {marker!r}')

if preview_package.exists():
    manifest = json.loads(preview_package.read_text())
    package_version = manifest.get('version')
    version_pattern = r'(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)'
    if not isinstance(package_version, str) or not re.fullmatch(version_pattern, package_version):
        errors.append(f'{preview_package}: version must be a numeric semver string')
    else:
        expected_tag = f'v{package_version}'
        tag_pattern = re.compile(r'\bv' + version_pattern + r'\b')
        command_pattern = re.compile(
            r'https://raw\.githubusercontent\.com/dhoaibao/b-agentic/'
            r'(v(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*))'
            r'/pi/scripts/install-preview-markdown\.sh\s*\|\s*bash\s+-s\s+--\s+'
            r'(v(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*))'
        )
        for doc, start_marker, end_marker in preview_tag_sections:
            if not doc.exists():
                errors.append(f'{doc}: missing preview install documentation')
                continue
            text = doc.read_text()
            start = text.find(start_marker)
            end = text.find(end_marker, start + len(start_marker)) if start >= 0 else -1
            if start < 0 or end < 0:
                errors.append(f'{doc}: cannot locate the bounded preview tag section')
                continue
            section = text[start:end]
            tags = tag_pattern.findall(section)
            if not tags:
                errors.append(f'{doc}: missing documented preview release tag')
            mismatches = sorted({tag for tag in tags if tag != expected_tag})
            if mismatches:
                errors.append(
                    f'{doc}: documented preview tag(s) {", ".join(mismatches)} '
                    f'do not match package version {package_version!r}; expected {expected_tag}'
                )
            commands = command_pattern.findall(section)
            if not commands:
                errors.append(f'{doc}: missing preview bootstrap URL and trailing installer argument')
            for url_tag, argument_tag in commands:
                if url_tag != expected_tag or argument_tag != expected_tag or url_tag != argument_tag:
                    errors.append(
                        f'{doc}: preview bootstrap tag {url_tag} and installer argument {argument_tag} '
                        f'must both match package version {package_version!r} (expected {expected_tag})'
                    )

if readme.exists():
    text = readme.read_text()
    # The first-party extension set is installed as one coherent bundle.
    for path in extension_files:
        if path.parent != root / 'pi/extensions':
            continue
        name = path.name
        if name not in text and name != 'b-agentic-permissions.ts':
            errors.append(f'{readme}: missing extension {name!r}')

if readme.exists():
    text = readme.read_text()
    for marker in [
        'pi-mcp-adapter', 'pi-observational-memory', '@sreetej510/pi-usage', '@gotgenes/pi-anthropic-auth', '@narumitw/pi-lsp@0.32.0', '@juicesharp/rpiv-ask-user-question',
        'extensions/b-agentic-permissions.ts', 'mcp.json', '/b-role planner',
        'pi --b-role planner|worker', '/b-auto-mode', '/b-sync', '/b-update',
        'Planner mode is prompt-governed rather than tool-gated', 'generated ownership mapping gives the planner',
        '`b-design`, `b-implement`, `b-init`, `b-refactor`, `b-debug`, `b-test`, `b-browser`, and `b-commit`',
        'ownership governs execution, not inspection', 'Planner ownership is limited to read-only decision/planning',
        'mixed, and uncertain work belong to the worker', 'sole worktree writer',
        'authoritative short ID is valid', 'Never guess, reconstruct, extend, further abbreviate',
        'applicable observable behavior, scope/non-goals, constraints/invariants',
        'actual `b-review` of the diff and verification', 'unchanged reviewed snapshot',
    ]:
        if marker not in text:
            errors.append(f'{readme}: missing {marker!r}')

if errors:
    print('\n'.join(errors), file=sys.stderr)
    sys.exit(1)
print('Pi integration validation passed.')
PY
