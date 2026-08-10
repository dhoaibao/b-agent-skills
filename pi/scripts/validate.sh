#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

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
extension_files = [
    extension,
    root / 'pi/extensions/b-agentic-mcp-permissions.ts',
    root / 'pi/extensions/b-agentic-role.ts',
    root / 'pi/extensions/b-agentic-planner.ts',
    root / 'pi/extensions/b-agentic-worker.ts',
    root / 'pi/extensions/b-agentic-support/shell.ts',
    root / 'pi/extensions/b-agentic-support/mcp.ts',
    root / 'pi/extensions/b-agentic-support/role.ts',
    root / 'pi/extensions/b-agentic-support/role-models.ts',
    root / 'pi/extensions/b-agentic-support/worker.ts',
]
readme = root / 'pi/configs/README.md'

for path in [kernel, mcp, *extension_files, readme]:
    if not path.exists():
        errors.append(f'{path}: missing')

if kernel.exists():
    text = kernel.read_text()
    for marker in [
        'Pi Workflow Kernel',
        'Core Rules',
        'Safety and tools',
        'Managed MCP operations',
        'Planner and worker are the default collaboration roles',
        'The first same-CWD session is planner',
        'Planner owns `b-plan`, `b-research`, `b-review`, and `b-pr-summary`',
        'Worker is the sole worktree writer',
        'Use the role-aware same-CWD worker roster before delegation',
        'worker sends that planner paths/checks/gaps and pauses',
        'worker resumes only for findings/new work',
        'Natural language; no parsed protocol/chains',
    ]:
        if marker not in text:
            errors.append(f'{kernel}: missing {marker!r}')

if mcp.exists():
    data = json.loads(mcp.read_text())
    servers = data.get('mcpServers', {})
    for server in ['serena', 'context7', 'codegraph', 'brave-search', 'firecrawl', 'playwright']:
        if server not in servers:
            errors.append(f'{mcp}: missing MCP server {server!r}')
        elif servers[server].get('lifecycle') != 'lazy':
            errors.append(f'{mcp}: {server} must use lifecycle lazy by default')
    settings = data.get('settings', {})
    if settings.get('directTools') not in (False, None):
        errors.append(f'{mcp}: default directTools must be false (proxy tool default)')

if extension.exists():
    text = '\n'.join(path.read_text() for path in extension_files if path.exists())
    for marker in [
        'tool_call',
        '["git", "push"]',
        '["git", "pull"]',
        '["npm", "install"]',
        '["rm", "-rf"]',
        '["git", "reset", "--hard"]',
        '["git", "clean", "-f"]',
        '["git", "push", "--force"]',
        '["git", "branch", "-D"]',
        '["docker", "system", "prune"]',
        '["docker", "volume", "rm"]',
        'rtk',
        'hasUI',
        'fail-closed',
        '.env',
        'splitShellSegments',
        'stripWrappers',
        'isMcpOrCustomTool',
        'isAutoApprovedIntercomCall',
        'isTrustedManagedTool',
        'MANAGED_MCP_SERVERS',
        'SERENA_TRUSTED_TOOLS',
        'CODEGRAPH_TRUSTED_TOOLS',
        'CONTEXT7_TRUSTED_TOOLS',
        'BRAVE_SEARCH_TRUSTED_TOOLS',
        'FIRECRAWL_TRUSTED_TOOLS',
        'PLAYWRIGHT_TRUSTED_TOOLS',
        'firecrawl_search',
        'browser_snapshot',
        'isInterpreterOpaque',
        'commandDecision',
        'registerFlag("b-role"',
        'registerCommand("b-role"',
        'PLANNER_PROMPT',
        'workerPrompt',
        'planner profile (read-only coordinator)',
        'worker profile (implementation)',
        'PLANNER_ALLOWED_TOOLS',
        'Planner mode is enforced',
        'worker is the sole worktree writer',
        'Never perform implementation edits',
        'Default to non-blocking Intercom',
        "assigning planner's Intercom session name or id",
        'Pause all edits',
        'Resume only when the planner sends actionable findings or a new task',
        'SERENA_TRUSTED_TOOLS.has(toolName)',
        'isSafeSerenaSymbolRead',
        'mcpScript',
        'serena_onboarding',
    ]:
        if marker not in text:
            errors.append(f'{extension}: missing policy marker {marker!r}')
    if 'return { block: true' not in text and 'block: true' not in text:
        errors.append(f'{extension}: must be able to block tool calls')
    if 'custom/MCP tool' not in text and 'MCP' not in text:
        errors.append(f'{extension}: must gate MCP/custom tools')
    for server in ['serena', 'codegraph', 'context7', 'brave-search', 'firecrawl', 'playwright']:
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
    if 'isTrustedManagedGatewayCall' not in text or 'if (toolName === "mcp") return !isTrustedManagedGatewayCall(input);' not in text:
        errors.append(f'{extension}: must classify top-level MCP gateway calls by managed ownership and safety')
    if 'Blocked' not in text or 'protected path' not in text:
        errors.append(f'{extension}: must block protected paths')
    # read must share protected-path handling with write/edit
    if 'event.toolName === "read"' not in text and 'toolName === "read"' not in text:
        # Accept combined write/edit/read branch
        if not re.search(r'toolName === "write".*toolName === "edit".*toolName === "read"', text, re.DOTALL):
            if 'read' not in text or 'isProtectedPath' not in text:
                errors.append(f'{extension}: must apply protected-path policy to read')

if readme.exists():
    text = readme.read_text()
    # The first-party extension set is installed as one coherent bundle.
    for name in [path.name for path in extension_files if '/' not in str(path.relative_to(root / 'pi/extensions'))]:
        if name not in text and name != 'b-agentic-permissions.ts':
            errors.append(f'{readme}: missing extension {name!r}')

if readme.exists():
    text = readme.read_text()
    for marker in [
        'pi-mcp-adapter',
        'pi-observational-memory',
        '@narumitw/pi-usage',
        'extensions/b-agentic-permissions.ts',
        'mcp.json',
        'auto-approves schema-valid Intercom actions',
        'invalid actions, unknown fields, and malformed optional values remain approval-gated',
        'auto-allows reads of installed b-agentic `SKILL.md` files under the configured',
        'other outside-project reads remain approval-gated',
        '/b-role planner',
        'pi --b-role planner|worker',
        'Planner mode is enforced as analysis-only',
        'natural-language task',
        '`b-commit`',
        '`b-debug`',
        '`b-refactor`',
        'sole worktree writer',
        'pausing all edits',
        'There are no required `B_AGENTIC_TASK`',
        '`send` is the non-blocking default',
        'until approved',
    ]:
        if marker not in text:
            errors.append(f'{readme}: missing {marker!r}')

if errors:
    print('\n'.join(errors), file=sys.stderr)
    sys.exit(1)
print('Pi integration validation passed.')
PY
