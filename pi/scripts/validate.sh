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
    root / 'pi/extensions/b-agentic-auto-mode.ts',
    root / 'pi/extensions/b-agentic-role.ts',
    root / 'pi/extensions/b-agentic-planner.ts',
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
        'b-agentic defaults to Off for a single-session workflow',
        'The two-role workflow is explicit',
        'Planner owns `b-plan`, `b-research`, `b-agentic-audit`, `b-review`, and `b-pr-summary`',
        'Worker is the sole worktree writer',
        'Use the role-aware same-CWD Worker roster after explicit role selection',
        'Worker sends that planner paths/checks/gaps and pauses',
        'Worker resumes only for findings/new work',
        'Natural language; no parsed protocol/chains',
        'Planners and workers must call Intercom',
        'pending` first',
        'if `pending` reports an inbound ask, the response must use `reply` for that ask and must not call `send` or `list-cwd`',
        'only when `pending` reports no inbound ask may',
        'retrieve the exact session ID',
        'exact session identifier returned verbatim by the immediately preceding authoritative Intercom action',
        'immediately preceding',
        'returned verbatim by the immediately preceding authoritative Intercom action',
        'copy the send target exactly',
        'without reconstructing, extending, guessing, fabricating, or substituting a longer ID',
        'display name, alias, or abbreviated prefix',
        'successful delivery',
        'delivery fails',
        'if an inbound ask exists, use',
        'do not retry',
        'otherwise call a fresh',
        'retry exactly once',
        'continue, commit, or close',
        'unavailable',
        'explicit exception to avoiding repeated `list-cwd` polling',
        'Immediately after delegating an editing task to the worker',
        'Never use `sleep`, polling, or timeout-based waiting',
        'until the worker has finished and explicitly reported back',
        'After assigning a task, wait for the worker\'s `send` result instead of polling again',
        'Use `send` for task delegation and worker result/review reporting',
        'Reserve `ask` for a worker\'s blocker or clarification question to the planner, or for a planner\'s quick-answer need from the worker',
        'Keep roster/status calls for selecting a worker or handling genuine connection needs, not a polling loop',
        'Every task delegated by a planner to a worker must pass the actual `b-review` skill',
        'before the planner may mark it done, complete, approved, or closed',
        'A regular or generic review is insufficient',
        'this review gate must never be bypassed under any circumstances',
        'If a blocker or decision cannot be resolved from scope or repository evidence, the planner asks the user one focused question and keeps the task open',
        'when it can resolve a worker\'s blocker, it uses Intercom `pending` first and then `reply` to the worker',
        'A worker with an unresolved issue or blocker must use Intercom `ask` to the assigning planner with one focused question and wait',
        'must not ask the user directly, stop midway, or send a premature completion or review message while the planner waits',
        'The planner resolves the blocker via `reply` when possible; otherwise it escalates to the user and keeps the task open',
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
    if settings.get('requestTimeoutMs') != 30000:
        errors.append(f'{mcp}: default requestTimeoutMs must be 30000 milliseconds')

if extension.exists():
    text = '\n'.join(path.read_text() for path in extension_files if path.exists())
    for marker in [
        'tool_call',
        '["git", "push"]',
        '["git", "pull"]',
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
        'local-mutation Serena calls are blocked',
        'worker is the sole worktree writer',
        'Finish discovery and settle the approach before one bounded handoff',
        'stop exploring and issuing new implementation requests',
        'Treat the handoff as bounded',
        'once edits start, do not expand scope from exploratory requests',
        'Never perform implementation edits',
        'Default to non-blocking Intercom',
        'task delegation, findings, worker results, review requests, and approval',
        'Reserve \\`ask\\` for a worker\'s blocker or clarification question to the planner, or for a planner\'s quick-answer need from the worker',
        'Before every Intercom',
        'pending\\` first',
        'response must use \\`reply\\` for that ask and must not call \\`send\\` or \\`list-cwd\\`',
        'only when it reports no inbound ask may you call \\`list-cwd\\` again',
        'inbound ask exists',
        'retrieve the exact session ID',
        'exact session identifier returned verbatim by the immediately preceding authoritative Intercom action',
        'immediately preceding',
        'Copy every send target verbatim from the authoritative Intercom output',
        'never reconstruct, extend, guess, fabricate, or substitute a longer ID',
        'display name, alias, or abbreviated prefix',
        'successful delivery',
        'delivery fails',
        'if an inbound ask exists, use',
        'do not retry',
        'otherwise call a fresh',
        'retry exactly once',
        'continue, commit, or close',
        'unavailable',
        'explicit exception to avoiding repeated',
        'Immediately after delegating an editing task to the worker',
        'timeout-based waiting',
        'until the worker has finished and explicitly reported back',
        'assigning planner as the intended peer',
        'Pause all edits',
        'Resume only when the planner sends actionable findings or a new task',
        'then use Intercom \\`ask\\` addressed to that exact identifier with one focused question and wait',
        'ask\\` is not for reporting a completed result or review request',
        'do not ask the user directly',
        'premature completion or review message while the planner waits',
        'keep the task open pending the planner\'s response',
        'when a worker asks about an unresolved blocker, resolve it when possible by calling Intercom \\`pending\\` first and then \\`reply\\` to the worker',
        'If it cannot be resolved from scope or repository evidence, escalate to the user with one focused question and keep the task open',
        'isDirectClassifiedManagedTool',
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
    if 'isTrustedManagedGatewayCall' not in text or 'isMcpProxyToolExecution' not in text or 'if (toolName === "mcp") return !isMcpProxyToolExecution(input);' not in text:
        errors.append(f'{extension}: must route only explicit MCP proxy executions through the adapter broker')
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
        '/b-auto-mode',
        'explicit `deny` decisions remain blocked',
        '`/b-role` selects only a role and does not open a model picker',
        '/b-sync',
        '/b-update',
        'Planner mode is enforced as analysis-only',
        'natural-language task',
        '`b-commit`',
        '`b-debug`',
        '`b-refactor`',
        'sole worktree writer',
        'pausing all edits',
        'There are no required `B_AGENTIC_TASK`',
        '`reply` is required when `pending` reports an inbound ask',
        'use a `send` addressed to the exact session identifier returned verbatim',
        'until approved',
    ]:
        if marker not in text:
            errors.append(f'{readme}: missing {marker!r}')

if errors:
    print('\n'.join(errors), file=sys.stderr)
    sys.exit(1)
print('Pi integration validation passed.')
PY
