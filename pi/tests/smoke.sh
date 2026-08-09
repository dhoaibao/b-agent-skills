# Sourced by tests/smoke/install.sh — do not run directly.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
	echo "error: this script is sourced by tests/smoke/install.sh" >&2
	exit 1
fi

run_pi_smoke_cases() {
	local snapshot_repo="$1"
	local sandbox="$WORK_DIR/pi"
	local sandbox_adapter="$WORK_DIR/pi-adapter"
	local sandbox_preserve="$WORK_DIR/pi-preserve"
	local sandbox_replace="$WORK_DIR/pi-replace"
	local sandbox_mcp_merge="$WORK_DIR/pi-mcp-merge"
	local sandbox_extension_restore="$WORK_DIR/pi-extension-restore"
	local sandbox_extension_modified="$WORK_DIR/pi-extension-modified"
	local sandbox_extension_symlink="$WORK_DIR/pi-extension-symlink"
	local sandbox_skill_modified="$WORK_DIR/pi-skill-modified"
	local sandbox_skill_reinstall="$WORK_DIR/pi-skill-reinstall"
	local sandbox_skill_stale="$WORK_DIR/pi-skill-stale"
	local sandbox_skill_symlink="$WORK_DIR/pi-skill-symlink"
	mkdir -p \
		"$sandbox/home" \
		"$sandbox_adapter/home" \
		"$sandbox_preserve/home" \
		"$sandbox_replace/home" \
		"$sandbox_mcp_merge/home" \
		"$sandbox_extension_restore/home/.pi/agent/extensions" \
		"$sandbox_extension_modified/home" \
		"$sandbox_extension_symlink/home/.pi/agent/extensions" \
		"$sandbox_skill_modified/home" \
		"$sandbox_skill_reinstall/home" \
		"$sandbox_skill_stale/home" \
		"$sandbox_skill_symlink/home"

	# Core install layout without adapter package.
	expect_install_status 0 "$sandbox" "$snapshot_repo"
	assert_file "$sandbox/home/.pi/agent/AGENTS.md"
	assert_file "$sandbox/home/.pi/agent/skills/b-plan/SKILL.md"
	assert_no_path "$sandbox/home/.pi/agent/skills/b-plan/prompt.md"
	assert_file "$sandbox/home/.pi/agent/b-agentic/references/kernel.template.md"
	assert_file "$sandbox/home/.pi/agent/b-agentic/references/mcp_operations.yaml"
	assert_no_path "$sandbox/home/.pi/agent/b-agentic/references/contract"
	assert_file "$sandbox/home/.pi/agent/mcp.json"
	assert_file "$sandbox/home/.pi/agent/extensions/b-agentic-permissions.ts"
	assert_file "$sandbox/home/.pi/agent/b-agentic/extensions/b-agentic-permissions.ts"
	assert_file "$sandbox/home/.pi/agent/b-agentic/install.json"
	assert_contains "$sandbox/home/.pi/agent/mcp.json" '"codegraph"'
	assert_contains "$sandbox/home/.pi/agent/mcp.json" '"lifecycle": "lazy"'
	assert_contains "$sandbox/home/.pi/agent/extensions/b-agentic-permissions.ts" 'tool_call'
	assert_contains "$sandbox/home/.pi/agent/b-agentic/install.json" '"mcpAdapterState": "missing"'
	assert_contains "$sandbox/home/.pi/agent/AGENTS.md" 'b-agentic-managed'
	assert_no_path "$sandbox/smoke-bin/pi-install.log"

	# Optional Pi packages via env opt-in (mock pi records installs).
	# expect_install_status hardcodes env; invoke installer directly for package opt-ins.
	local smoke_path
	smoke_path="$(smoke_runtime_cli_path "$sandbox_adapter")"
	HOME="$sandbox_adapter/home" \
		PATH="$smoke_path" \
		B_AGENTIC_REPO="$snapshot_repo" \
		B_AGENTIC_DIR="$sandbox_adapter/source" \
		B_AGENTIC_PROMPT_API_KEYS=N \
		B_AGENTIC_INSTALL_PI_CLI=N \
		B_AGENTIC_INSTALL_RTK=N \
		B_AGENTIC_INSTALL_SERENA=N \
		B_AGENTIC_INSTALL_CODEGRAPH=N \
		B_AGENTIC_INSTALL_PI_MCP_ADAPTER=Y \
		B_AGENTIC_INSTALL_PI_OBSERVATIONAL_MEMORY=Y \
		B_AGENTIC_INSTALL_PI_USAGE=Y \
		bash "$ROOT_DIR/install.sh" >/dev/null 2>&1
	assert_file "$sandbox_adapter/home/.pi/agent/b-agentic/install.json"
	assert_contains "$sandbox_adapter/home/.pi/agent/b-agentic/install.json" '"mcpAdapterState": "ready"'
	assert_contains "$sandbox_adapter/home/.pi/agent/b-agentic/install.json" '"piObservationalMemoryState": "ready"'
	assert_contains "$sandbox_adapter/home/.pi/agent/b-agentic/install.json" '"piUsageState": "ready"'
	assert_file "$sandbox_adapter/smoke-bin/pi-install.log"
	assert_contains "$sandbox_adapter/smoke-bin/pi-install.log" 'npm:pi-mcp-adapter'
	assert_contains "$sandbox_adapter/smoke-bin/pi-install.log" 'npm:pi-observational-memory'
	assert_contains "$sandbox_adapter/smoke-bin/pi-install.log" 'npm:@narumitw/pi-usage'
	assert_contains "$sandbox_adapter/smoke-bin/pi-install.log" 'update --extensions'

	# Preserve user-owned kernel.
	mkdir -p "$sandbox_preserve/home/.pi/agent"
	printf 'user-owned pi kernel\n' >"$sandbox_preserve/home/.pi/agent/AGENTS.md"
	expect_install_status 2 "$sandbox_preserve" "$snapshot_repo"
	assert_file "$sandbox_preserve/home/.pi/agent/AGENTS.md"
	assert_contains "$sandbox_preserve/home/.pi/agent/AGENTS.md" 'user-owned pi kernel'
	assert_file "$sandbox_preserve/home/.pi/agent/b-agentic/install.json"
	assert_contains "$sandbox_preserve/home/.pi/agent/b-agentic/install.json" '"activationState": "pending"'

	# --replace-memory overwrites user kernel.
	mkdir -p "$sandbox_replace/home/.pi/agent"
	printf 'user-owned pi kernel\n' >"$sandbox_replace/home/.pi/agent/AGENTS.md"
	expect_install_status 0 "$sandbox_replace" "$snapshot_repo" --replace-memory
	assert_contains "$sandbox_replace/home/.pi/agent/AGENTS.md" 'b-agentic-managed'
	assert_not_contains "$sandbox_replace/home/.pi/agent/AGENTS.md" 'user-owned pi kernel'

	# MCP merge preserves unrelated servers.
	mkdir -p "$sandbox_mcp_merge/home/.pi/agent"
	cat >"$sandbox_mcp_merge/home/.pi/agent/mcp.json" <<'EOF'
{
  "mcpServers": {
    "user-server": {
      "command": "echo",
      "args": ["user"]
    }
  }
}
EOF
	expect_install_status 0 "$sandbox_mcp_merge" "$snapshot_repo"
	assert_contains "$sandbox_mcp_merge/home/.pi/agent/mcp.json" '"user-server"'
	assert_contains "$sandbox_mcp_merge/home/.pi/agent/mcp.json" '"serena"'

	# Uninstall restores a pre-existing extension after no-op reinstall and managed-file deletion.
	printf 'user-owned permission extension\n' >"$sandbox_extension_restore/home/.pi/agent/extensions/b-agentic-permissions.ts"
	expect_install_status 0 "$sandbox_extension_restore" "$snapshot_repo"
	assert_not_contains "$sandbox_extension_restore/home/.pi/agent/extensions/b-agentic-permissions.ts" 'user-owned permission extension'
	expect_install_status 0 "$sandbox_extension_restore" "$snapshot_repo"
	rm "$sandbox_extension_restore/home/.pi/agent/extensions/b-agentic-permissions.ts"
	expect_install_status 0 "$sandbox_extension_restore" "$snapshot_repo"
	expect_install_status 0 "$sandbox_extension_restore" "$snapshot_repo" --uninstall
	assert_contains "$sandbox_extension_restore/home/.pi/agent/extensions/b-agentic-permissions.ts" 'user-owned permission extension'

	# Uninstall preserves symlink destinations instead of restoring through them.
	printf 'user-owned permission extension\n' >"$sandbox_extension_symlink/home/.pi/agent/extensions/b-agentic-permissions.ts"
	expect_install_status 0 "$sandbox_extension_symlink" "$snapshot_repo"
	cp "$sandbox_extension_symlink/home/.pi/agent/extensions/b-agentic-permissions.ts" "$sandbox_extension_symlink/target.ts"
	rm "$sandbox_extension_symlink/home/.pi/agent/extensions/b-agentic-permissions.ts"
	ln -s "$sandbox_extension_symlink/target.ts" "$sandbox_extension_symlink/home/.pi/agent/extensions/b-agentic-permissions.ts"
	expect_install_status 0 "$sandbox_extension_symlink" "$snapshot_repo" --uninstall
	[ -L "$sandbox_extension_symlink/home/.pi/agent/extensions/b-agentic-permissions.ts" ] || fail "expected symlinked extension to be preserved"
	assert_contains "$sandbox_extension_symlink/target.ts" 'tool_call'
	assert_not_contains "$sandbox_extension_symlink/target.ts" 'user-owned permission extension'

	# Uninstall preserves an extension modified after installation.
	expect_install_status 0 "$sandbox_extension_modified" "$snapshot_repo"
	printf 'post-install user modification\n' >"$sandbox_extension_modified/home/.pi/agent/extensions/b-agentic-permissions.ts"
	expect_install_status 0 "$sandbox_extension_modified" "$snapshot_repo" --uninstall
	assert_contains "$sandbox_extension_modified/home/.pi/agent/extensions/b-agentic-permissions.ts" 'post-install user modification'

	# Reinstall preserves a modified managed skill.
	expect_install_status 0 "$sandbox_skill_reinstall" "$snapshot_repo"
	printf '\npost-install skill modification\n' >>"$sandbox_skill_reinstall/home/.pi/agent/skills/b-plan/SKILL.md"
	expect_install_status 0 "$sandbox_skill_reinstall" "$snapshot_repo"
	assert_contains "$sandbox_skill_reinstall/home/.pi/agent/skills/b-plan/SKILL.md" 'post-install skill modification'

	# Stale modified and symlinked skills survive reinstall pruning.
	expect_install_status 0 "$sandbox_skill_stale" "$snapshot_repo"
	mkdir -p \
		"$sandbox_skill_stale/home/.pi/agent/skills/stale-skill" \
		"$sandbox_skill_stale/home/.pi/agent/b-agentic/skills/stale-skill"
	printf 'Generated from skills/registry.yaml\n' >"$sandbox_skill_stale/home/.pi/agent/skills/stale-skill/SKILL.md"
	cp "$sandbox_skill_stale/home/.pi/agent/skills/stale-skill/SKILL.md" \
		"$sandbox_skill_stale/home/.pi/agent/b-agentic/skills/stale-skill/SKILL.md"
	mkdir -p "$sandbox_skill_stale/stale-target"
	printf 'Generated from skills/registry.yaml\n' >"$sandbox_skill_stale/stale-target/SKILL.md"
	ln -s "$sandbox_skill_stale/stale-target" \
		"$sandbox_skill_stale/home/.pi/agent/skills/stale-link"
	python3 - "$sandbox_skill_stale/home/.pi/agent/b-agentic/install.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text())
data['skills'].extend(['stale-skill', 'stale-link'])
path.write_text(json.dumps(data, indent=2) + '\n')
PY
	printf '\nuser stale-skill edit\n' >>"$sandbox_skill_stale/home/.pi/agent/skills/stale-skill/SKILL.md"
	expect_install_status 0 "$sandbox_skill_stale" "$snapshot_repo"
	assert_contains "$sandbox_skill_stale/home/.pi/agent/skills/stale-skill/SKILL.md" 'user stale-skill edit'
	[ -L "$sandbox_skill_stale/home/.pi/agent/skills/stale-link" ] || fail "expected stale skill symlink to be preserved"

	# Source-backed uninstall preserves a modified skill.
	expect_install_status 0 "$sandbox_skill_modified" "$snapshot_repo"
	printf '\npost-install skill modification\n' >>"$sandbox_skill_modified/home/.pi/agent/skills/b-plan/SKILL.md"
	expect_install_status 0 "$sandbox_skill_modified" "$snapshot_repo" --uninstall
	assert_contains "$sandbox_skill_modified/home/.pi/agent/skills/b-plan/SKILL.md" 'post-install skill modification'

	# Source-backed uninstall preserves a symlinked skill.
	expect_install_status 0 "$sandbox_skill_symlink" "$snapshot_repo"
	cp -R "$sandbox_skill_symlink/home/.pi/agent/skills/b-plan" "$sandbox_skill_symlink/target-skill"
	rm -rf "$sandbox_skill_symlink/home/.pi/agent/skills/b-plan"
	ln -s "$sandbox_skill_symlink/target-skill" "$sandbox_skill_symlink/home/.pi/agent/skills/b-plan"
	expect_install_status 0 "$sandbox_skill_symlink" "$snapshot_repo" --uninstall
	[ -L "$sandbox_skill_symlink/home/.pi/agent/skills/b-plan" ] || fail "expected symlinked skill to be preserved"
	assert_file "$sandbox_skill_symlink/target-skill/SKILL.md"

	# Behavioral permission coverage via node --experimental-strip-types (no Pi runtime).
	ROOT_DIR="$ROOT_DIR" node --experimental-strip-types --input-type=module - <<'NODE'
import { mkdirSync, mkdtempSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const root = process.env.ROOT_DIR || process.cwd();
const modPath = path.join(root, 'pi/extensions/b-agentic-permissions.ts');
const mod = await import(pathToFileURL(modPath).href);
const t = mod.__test__;
if (!t) {
  console.error('permission extension missing __test__ exports');
  process.exit(1);
}
let toolCallHandler;
let mcpApprovalHandler;
mod.default({
  on(eventName, handler) {
    if (eventName === 'tool_call') toolCallHandler = handler;
  },
  events: {
    on(channel, handler) {
      if (channel === 'pi-mcp-adapter:tool-approval-request') mcpApprovalHandler = handler;
      return () => {};
    },
    emit() {},
  },
});

function expect(cond, msg) {
  if (!cond) {
    console.error(msg);
    process.exit(1);
  }
}

expect(t.isAutoApprovedIntercomCall('intercom', { action: 'list-cwd' }) === true, 'Intercom list-cwd is auto-approved without delegation config');
expect(t.isAutoApprovedIntercomCall('intercom', { action: 'status' }) === true, 'Intercom status is auto-approved without delegation config');
expect(t.isAutoApprovedIntercomCall('intercom', { action: 'pending' }) === true, 'Intercom pending is auto-approved without delegation config');
expect(t.isAutoApprovedIntercomCall('intercom', { action: 'list' }) === false, 'Intercom list remains approval-gated');
expect(t.isAutoApprovedIntercomCall('intercom', { action: 'send', to: 'arbitrary-session', message: 'bounded task' }) === true, 'plain Intercom send allows arbitrary local session targets');
expect(t.isAutoApprovedIntercomCall('intercom', { action: 'ask', to: 'arbitrary-session', message: 'bounded task' }) === true, 'plain Intercom ask allows arbitrary local session targets');
expect(t.isAutoApprovedIntercomCall('intercom', { action: 'reply', to: 'arbitrary-session', message: 'bounded reply' }) === true, 'plain Intercom reply allows arbitrary local session targets');
expect(t.isAutoApprovedIntercomCall('intercom', { action: 'reply', message: 'missing target' }) === false, 'Intercom reply requires explicit target');
expect(t.isAutoApprovedIntercomCall('intercom', { action: 'send', to: 'arbitrary-session', message: 'attachment', attachments: [] }) === false, 'Intercom attachments require approval');
expect(t.isAutoApprovedIntercomCall('intercom', { action: 'send', to: 'arbitrary-session', message: 'unknown', priority: 'high' }) === false, 'Intercom unknown fields require approval');
expect(t.isAutoApprovedIntercomCall('intercom', { action: 'cancel', to: 'arbitrary-session', message: 'unknown action' }) === false, 'Intercom unknown actions require approval');

expect(typeof toolCallHandler === 'function', 'permission extension must register a tool_call handler');
expect(typeof mcpApprovalHandler === 'function', 'permission extension must register the MCP approval broker');
const noUiContext = { hasUI: false, ui: { confirm: async () => true } };
expect((await toolCallHandler({ toolName: 'mcp', input: { server: 'firecrawl', tool: 'firecrawl_agent' } }, noUiContext))?.block === true, 'managed MCP mutations must retain the approval gate');
expect((await toolCallHandler({ toolName: 'mcp', input: { server: 'firecrawl', tool: 'firecrawl_search', args: { query: 'collision check', limit: 1 } } }, noUiContext)) === undefined, 'classified safe MCP gateway execution must auto-allow');
expect((await toolCallHandler({ toolName: 'mcp', input: { search: 'symbol' } }, noUiContext))?.block === true, 'MCP metadata calls must retain the approval gate');
expect((await toolCallHandler({ toolName: 'mcp', input: { tool: 'firecrawl_developer_search', args: { query: 'collision check' } } }, noUiContext))?.block === true, 'MCP calls without explicit managed ownership must retain the approval gate');
expect((await toolCallHandler({ toolName: 'firecrawl_firecrawl_agent', input: {} }, noUiContext))?.block === true, 'direct managed-looking tools must retain the top-level approval gate');
let directClaim;
mcpApprovalHandler({
  serverName: 'firecrawl',
  originalToolName: 'firecrawl_agent',
  prefixedToolName: 'firecrawl_firecrawl_agent',
  args: {},
  origin: 'direct',
  claim(handler) { directClaim = handler; return true; },
});
expect(await directClaim() === 'abstain', 'top-level direct MCP approval must not prompt twice');
await toolCallHandler({ toolName: 'bash', input: { command: 'rtk git status --short' } }, noUiContext);
let parallelProxyClaim;
mcpApprovalHandler({
  serverName: 'firecrawl',
  originalToolName: 'firecrawl_agent',
  prefixedToolName: 'firecrawl_firecrawl_agent',
  args: {},
  origin: 'proxy',
  claim(handler) { parallelProxyClaim = handler; return true; },
});
expect(await parallelProxyClaim() === 'abstain', 'adapter-owned proxy calls must not depend on sibling tool preflight state');
let noUiClaim;
mcpApprovalHandler({
  serverName: 'firecrawl',
  originalToolName: 'firecrawl_agent',
  prefixedToolName: 'firecrawl_firecrawl_agent',
  args: {},
  origin: 'script',
  claim(handler) { noUiClaim = handler; return true; },
});
expect(typeof noUiClaim === 'function', 'MCP broker request must be claimed');
expect(await noUiClaim() === 'deny', 'MCP broker must fail closed without UI');
let safeClaim;
mcpApprovalHandler({
  serverName: 'firecrawl',
  originalToolName: 'firecrawl_search',
  prefixedToolName: 'firecrawl_firecrawl_search',
  args: { query: 'Pi', limit: 10 },
  origin: 'script',
  claim(handler) { safeClaim = handler; return true; },
});
expect(await safeClaim() === 'allow_once', 'MCP broker must auto-allow classified safe calls');
let sessionClaim;
const uiContext = { hasUI: true, ui: { confirm: async () => true, select: async () => 'Allow for session' } };
await toolCallHandler({ toolName: 'mcp', input: { server: 'firecrawl', tool: 'firecrawl_agent' } }, uiContext);
let approvedGatewayClaim;
mcpApprovalHandler({
  serverName: 'firecrawl',
  originalToolName: 'firecrawl_agent',
  prefixedToolName: 'firecrawl_firecrawl_agent',
  args: {},
  origin: 'proxy',
  claim(handler) { approvedGatewayClaim = handler; return true; },
});
expect(await approvedGatewayClaim() === 'abstain', 'approved top-level MCP gateway calls must not prompt twice');
mcpApprovalHandler({
  serverName: 'firecrawl',
  originalToolName: 'firecrawl_agent',
  prefixedToolName: 'firecrawl_firecrawl_agent',
  args: {},
  origin: 'script',
  claim(handler) { sessionClaim = handler; return true; },
});
expect(await sessionClaim() === 'allow_for_session', 'MCP broker must support session-scoped approval');
expect((await toolCallHandler({ toolName: 'mcp', input: { server: 'user-server', tool: 'user_tool' } }, noUiContext))?.block === true, 'unmanaged MCP gateway calls must retain the top-level approval gate');
let userGatewayClaim;
mcpApprovalHandler({
  serverName: 'user-server',
  originalToolName: 'user_tool',
  prefixedToolName: 'user-server_user_tool',
  args: {},
  origin: 'proxy',
  claim(handler) { userGatewayClaim = handler; return true; },
});
expect(await userGatewayClaim() === 'abstain', 'top-level unmanaged MCP approval must not prompt twice');
expect(await toolCallHandler({ toolName: 'bash', input: { command: 'rtk git status --short' } }, noUiContext) === undefined, 'registered handler must allow safe RTK command');
expect(await toolCallHandler({ toolName: 'bash', input: { command: 'git commit -m x' } }, noUiContext) === undefined, 'registered handler must allow regular project-local Git commands');
expect((await toolCallHandler({ toolName: 'mcp', input: { connect: 'serena' } }, noUiContext))?.block === true, 'registered handler must fail closed for managed MCP connect');
expect((await toolCallHandler({ toolName: 'read', input: { path: '.env' } }, noUiContext))?.block === true, 'registered handler must fail closed for protected read');

// Compound commands and wrappers
expect(t.commandDecision('cd repo && git reset --hard').decision === 'deny', 'compound reset --hard must deny');
expect(t.commandDecision('git -C repo reset --hard').decision === 'deny', 'git -C reset --hard must deny');
expect(t.commandDecision('/usr/bin/git reset --hard').decision === 'deny', 'path-qualified git reset --hard must deny');
expect(t.commandDecision('/usr/bin/npm install lodash').decision === 'ask', 'path-qualified npm install must ask');
expect(t.commandDecision('/bin/rm -rf /tmp/x').decision === 'ask', 'path-qualified rm -rf must ask');
expect(t.commandDecision('/usr/bin/printf x').decision === 'allow', 'unsupported raw command must allow');
const originalCwd = process.cwd();
const codegraphFixture = mkdtempSync(path.join(os.tmpdir(), 'b-agentic-codegraph-'));
const indexedCodegraphFixture = mkdtempSync(path.join(os.tmpdir(), 'b-agentic-codegraph-indexed-'));
try {
  process.chdir(codegraphFixture);
  expect(t.commandDecision('codegraph init').decision === 'allow', 'exact CodeGraph initialization must allow only while its index is absent');
  expect(t.commandDecision('./codegraph init').decision === 'ask', 'relative CodeGraph executable must require approval');
  expect(t.commandDecision('/tmp/codegraph init').decision === 'ask', 'path-qualified CodeGraph executable must require approval');
  expect(t.commandDecision('sudo codegraph init').decision === 'ask', 'sudo CodeGraph initialization must require approval');
  expect(t.commandDecision('PATH=./bin codegraph init').decision === 'ask', 'PATH-assigned CodeGraph initialization must require approval');
  expect(t.commandDecision('env PATH=./bin codegraph init').decision === 'ask', 'env PATH-assigned CodeGraph initialization must require approval');
  expect(t.commandDecision('LD_PRELOAD=/tmp/payload.so codegraph init').decision === 'ask', 'runtime-injected CodeGraph initialization must require approval');
  expect(t.commandDecision('env LD_PRELOAD=/tmp/payload.so codegraph init').decision === 'ask', 'env runtime-injected CodeGraph initialization must require approval');
  expect(t.commandDecision('env -i codegraph init').decision === 'ask', 'env-wrapped CodeGraph initialization must require approval');
  expect(t.commandDecision('PATH=./bin; codegraph init').decision === 'ask', 'compound PATH-modified CodeGraph initialization must require approval');
  mkdirSync(path.join(indexedCodegraphFixture, '.codegraph'));
  writeFileSync(path.join(indexedCodegraphFixture, '.codegraph', 'codegraph.db'), 'index');
  expect(t.commandDecision(`env -C ${indexedCodegraphFixture} codegraph init`).decision === 'ask', 'env -C CodeGraph initialization must require approval');
  mkdirSync(path.join(codegraphFixture, '.codegraph'));
  writeFileSync(path.join(codegraphFixture, '.codegraph', 'codegraph.db'), 'index');
  expect(t.commandDecision('codegraph init').decision === 'allow', 'project-local CodeGraph initialization must allow');
} finally {
  process.chdir(originalCwd);
  rmSync(codegraphFixture, { recursive: true, force: true });
  rmSync(indexedCodegraphFixture, { recursive: true, force: true });
}
expect(t.commandDecision('codegraph init --force').decision === 'allow', 'project-local CodeGraph commands must allow');
expect(t.commandDecision('codegraph status').decision === 'allow', 'project-local CodeGraph status must allow');
expect(t.commandDecision("git -c alias.wipe='reset --hard' wipe").decision === 'ask', 'inline Git alias invocation must ask');
expect(t.commandDecision('env X=1 npm install lodash').decision === 'ask', 'env-wrapped npm install must ask');
for (const command of ['env', 'env -i', 'env X=1']) {
  expect(t.commandDecision(command).decision === 'ask', `${command} must require rtk env`);
}
expect(t.commandDecision('rtk env').decision === 'allow', 'rtk env must allow');
expect(t.commandDecision('rtk git commit -m x').decision === 'allow', 'regular project-local Git commands must allow');
expect(t.commandDecision('rtk proxy git reset --hard').decision === 'deny', 'rtk proxy must preserve deny decisions');
for (const wrapper of ['err', 'test', 'summary']) {
  expect(t.RTK_EXECUTION_WRAPPERS.has(wrapper), `rtk ${wrapper} must be classified as an execution wrapper`);
  expect(t.commandDecision(`rtk ${wrapper} git reset --hard`).decision === 'deny', `rtk ${wrapper} must preserve deny decisions`);
  expect(t.commandDecision(`rtk ${wrapper} -- git reset --hard`).decision === 'deny', `rtk ${wrapper} -- must preserve deny decisions`);
  expect(t.commandDecision(`rtk ${wrapper} --skip-env npm install lodash`).decision === 'ask', `rtk ${wrapper} options must preserve approval gates`);
}
expect(t.commandDecision('rtk run git reset --hard').decision === 'deny', 'positional rtk run must preserve deny decisions');
expect(t.commandDecision('rtk --ultra-compact run git reset --hard').decision === 'deny', 'RTK global options must not hide deny decisions');
expect(t.commandDecision('rtk --skip-env git reset --hard').decision === 'deny', 'RTK global options must preserve direct command classification');
expect(t.commandDecision("rtk run -c 'git reset --hard'").decision === 'ask', 'rtk run -c must fail closed as opaque');
expect(t.commandDecision('rtk g\\it reset --hard').decision === 'deny', 'escaped command name must not bypass reset denial');
expect(t.commandDecision(['rtk g', '\\', '\n', 'it reset --hard'].join('')).decision === 'deny', 'line-continuation command name must not bypass reset denial');
const noModernTools = new Set();
const allModernTools = new Set(['rg', 'fd', 'bat', 'eza', 'sd', 'jq']);
expect(t.commandDecision('rtk proxy c\\at src/main.ts', noModernTools).decision === 'allow', 'baseline fallback remains allowed when the preferred modern tool is unavailable or inappropriate');
expect(t.commandDecision('rtk proxy grep needle src/main.ts', noModernTools).decision === 'allow', 'RTK-wrapped legacy discovery may fall back when rg is unavailable');
expect(t.commandDecision('grep needle src/main.ts', noModernTools).decision === 'allow', 'bare project-local grep must allow');
expect(t.commandDecision('rtk grep needle src/main.ts', allModernTools).decision === 'allow', 'RTK-wrapped grep must allow');
expect(t.commandDecision('rg needle src/main.ts', allModernTools).decision === 'allow', 'bare project-local rg must allow');
expect(t.commandDecision('rtk rg needle src/main.ts', allModernTools).decision === 'allow', 'RTK-wrapped rg must allow');
expect(t.commandDecision('rtk find . -name main.ts', noModernTools).decision === 'allow', 'RTK-wrapped find may fall back when fd is unavailable');
expect(t.commandDecision('rtk find . -name main.ts', allModernTools).decision === 'allow', 'RTK-wrapped find must allow when fd is available');
expect(t.commandDecision('fd -t f main.ts', allModernTools).decision === 'allow', 'unsupported modern fd discovery must allow directly');
expect(t.commandDecision('eza -la', allModernTools).decision === 'allow', 'unsupported modern eza discovery must allow directly');
expect(t.commandDecision('cat src/main.ts', allModernTools).decision === 'allow', 'project-local cat must allow when bat is available');
expect(t.commandDecision('python3 -m json.tool package.json', allModernTools).decision === 'allow', 'project-local JSON formatting must allow when jq is available');
expect(t.commandDecision('sudo git push --force origin main').decision === 'deny', 'sudo force push must deny');
expect(t.commandDecision('/usr/bin/env X=1 git reset --hard').decision === 'deny', 'path-qualified env must not bypass reset denial');
expect(t.commandDecision('/usr/bin/sudo git push --force origin main').decision === 'deny', 'path-qualified sudo must not bypass force-push denial');
expect(t.commandDecision('/opt/bin/rtk git reset --hard').decision === 'deny', 'path-qualified RTK must not bypass reset denial');
expect(t.commandDecision('rtk git --git-dir repo/.git reset --hard').decision === 'deny', 'Git option value must not hide reset denial');
expect(t.commandDecision('rtk git --git-dir repo/.git --config-env=alias.wipe=ALIAS wipe').decision === 'ask', 'RTK Git command with opaque options must ask');
expect(t.commandDecision('git push -f origin main').decision === 'deny', 'git push -f must deny');
for (const command of [
  'rtk git restore .',
  'rtk git checkout -- src/main.ts',
  'rtk git checkout -f main',
  'rtk git switch --discard-changes main',
  'rtk git stash clear',
  'rtk git stash drop',
  'rtk git stash pop',
  'rtk git stash --quiet clear',
  'rtk git stash --quiet drop',
  'rtk git stash --quiet pop',
]) {
  expect(t.commandDecision(command).decision === 'ask', `${command} can discard work and must ask`);
}
for (const command of [
  'git add .',
  'git branch feature',
  'git fetch origin',
  'git reset HEAD src/main.ts',
  'git stash push',
  'git tag v1',
]) expect(t.commandDecision(command).decision === 'allow', `${command} is a regular project-local Git command and must allow`);
expect(t.commandDecision('git worktree remove ../other').decision === 'ask', 'Git worktree removal outside the project must ask');
for (const command of [
  'rtk git branch',
  'rtk git branch -a',
  'rtk git branch --contains HEAD',
  'rtk git log -1',
  'rtk git remote -v',
  'rtk git stash list',
  'rtk git status --short',
  "rtk git tag --list 'v*'",
  'rtk git diff --name-only',
  'rtk git show --name-status --format= HEAD',
  'rtk git diff -- pi/tests/smoke.sh',
  'rtk git show HEAD -- pi/tests/smoke.sh',
]) expect(t.commandDecision(command).decision === 'allow', `${command} is a scoped or metadata-only Git read and may allow via RTK`);
for (const command of [
  'rtk git diff', 'rtk git diff --cached', 'rtk git show HEAD',
  'rtk git diff --name-only --patch', 'rtk git show --name-status --patch HEAD',
  'rtk git diff -- .', 'rtk git show HEAD -- pi',
]) {
  expect(t.commandDecision(command).decision === 'ask', `${command} must not automatically expose unscoped Git content`);
}
expect(t.commandDecision('rtk git diff -- .env').decision === 'ask', 'targeted protected Git content must require approval');
expect(t.commandDecision('rm -rf /tmp/x').decision === 'ask', 'rm -rf must ask');
expect(t.commandDecision('rm -r /tmp/x').decision === 'ask', 'recursive rm must ask');
for (const command of [
  'mkdir -p /etc/b-agentic-review',
  'tee /etc/hosts',
  'unlink /tmp/important',
  'shred /tmp/important',
  'cd /etc && cat passwd',
  'pushd /etc && cat passwd',
  'popd && cat passwd',
  'env --chdir=/etc cat passwd',
  'sudo -C /etc cat passwd',
  'tar -xf /tmp/a.tar -C /etc',
  'make -C /etc all',
  'rsync src /etc/',
  'rsync src user@example.com:/etc/',
  'scp src user@example.com:/etc/hosts',
  'ssh user@example.com cat /etc/passwd',
  'unzip a.zip -d /etc',
  'rtk curl --output=/etc/hosts https://example.com',
  'rtk wget -O /etc/hosts https://example.com',
]) expect(t.commandDecision(command).decision === 'ask', `${command} must ask for outside-project mutation or cwd change`);
expect(t.commandDecision('rm -f /tmp/important').decision === 'ask', 'local file removal must ask');
expect(t.commandDecision('cat /etc/passwd').decision === 'ask', 'outside-project reads must ask');
expect(t.commandDecision('cat ~/.bashrc').decision === 'ask', 'home reads must ask');
expect(t.commandDecision('printf x > /etc/hosts').decision === 'ask', 'outside-project redirections must ask');
expect(t.commandDecision('cp src/main.ts /etc/hosts').decision === 'ask', 'outside-project copies must ask');
expect(t.commandDecision('mv src/main.ts /etc/hosts').decision === 'ask', 'outside-project moves must ask');
expect(t.commandDecision('touch /etc/hosts').decision === 'ask', 'outside-project touches must ask');
expect(t.commandDecision('cat src/main.ts', noModernTools).decision === 'allow', 'project-local reads must remain autonomous when bat is unavailable');
expect(t.commandDecision('printf x > pi/tests/new-file.ts').decision === 'allow', 'project-local writes must remain autonomous');
for (const command of ['dd if=/dev/zero of=/dev/sda', 'mkfs.ext4 /dev/sda', 'chmod -R 777 .', 'chown -R root .', 'kill -9 1']) {
  expect(t.commandDecision(command).decision === 'ask', `${command} must ask`);
}
expect(t.commandDecision('ls -la', noModernTools).decision === 'allow', 'bare project-local ls must allow');
expect(t.commandDecision('find . -name "*.ts"', noModernTools).decision === 'allow', 'bare project-local find must allow');
expect(t.commandDecision('rtk ls -la', noModernTools).decision === 'allow', 'RTK-wrapped ls may allow');
expect(t.commandDecision('rtk ls -la', allModernTools).decision === 'allow', 'RTK-wrapped ls may allow when eza is available');
expect(t.commandDecision('env X=1 rtk ls -la', noModernTools).decision === 'allow', 'env-wrapped RTK ls must allow when eza is unavailable');
expect(t.commandDecision('command rtk ls -la', noModernTools).decision === 'allow', 'command-wrapped RTK ls must allow when eza is unavailable');
expect(t.commandDecision('sudo rtk ls -la', noModernTools).decision === 'ask', 'sudo-wrapped commands must require approval');
expect(t.commandDecision('env -u FOO rtk ls -la', noModernTools).decision === 'allow', 'env -u wrapped RTK ls must allow when eza is unavailable');
expect(t.commandDecision('env -S ls').decision === 'ask', 'env -S legacy command must be approval-gated');
expect(t.commandDecision('env -S "grep needle src/main.ts"').decision === 'ask', 'env -S command string must be approval-gated');
for (const command of [
  'cat src/main.ts',
  'sed -n 1p src/main.ts',
  'awk {print} src/main.ts',
  'python3 -m json.tool package.json',
]) expect(t.commandDecision(command, noModernTools).decision === 'allow', `${command} must remain an allowed fallback when its replacement is unavailable`);
for (const [command, label] of [
  ['npm add lodash', 'npm add'], ['npm remove lodash', 'npm remove'], ['npm --silent install lodash', 'npm option install'], ['npm ci', 'npm ci'],
  ['/usr/bin/npm --silent install lodash', 'path-qualified npm option install'],
  ['pnpm update', 'pnpm update'], ['pnpm up lodash', 'pnpm up'],
  ['yarn remove lodash', 'yarn remove'], ['yarn up lodash', 'yarn up'], ['bun uninstall lodash', 'bun uninstall'],
  ['cargo remove serde', 'cargo remove'],
  ['npm --unknown-option install lodash', 'unknown package option'], ['pip uninstall requests', 'pip uninstall'],
  ['pip3 uninstall requests', 'pip3 uninstall'], ['poetry update', 'poetry update'],
  ['uv pip uninstall requests', 'uv pip uninstall'], ['uv pip sync requirements.txt', 'uv pip sync'],
]) expect(t.commandDecision(command).decision === 'ask', `${label} must gate dependency writes`);
for (const command of ['rtk npm --prefix ./app install lodash', 'rtk pnpm --dir ./app add lodash', 'rtk cargo --manifest-path app/Cargo.toml update']) {
  expect(t.commandDecision(command).decision === 'ask', `${command} must ask even via RTK`);
}
expect(t.commandDecision('git --config-env=alias.wipe=ALIAS wipe').decision === 'ask', 'inline Git alias invocation must ask');
for (const command of ['npm view lodash', 'pnpm list', 'cargo search serde']) {
  expect(t.commandDecision(command).decision === 'allow', `${command} is a regular command and must not require RTK`);
}
for (const command of ['rtk npm view lodash', 'rtk pnpm list', 'rtk cargo search serde', 'rtk pytest -q']) {
  expect(t.commandDecision(command).decision === 'allow', `${command} must preserve supported RTK use`);
}
for (const command of ['rtk npx eslint .', 'rtk npm test', 'rtk npm run build', 'rtk pnpm exec vite']) {
  expect(t.commandDecision(command).decision === 'ask', `${command} executes opaque package code and must ask`);
}
for (const command of [
  'rtk gh pr create',
  'rtk gh pr checkout 42',
  'rtk gh workflow run ci.yml',
  'rtk glab mr merge 42',
  'rtk aws s3 rm s3://bucket/key',
  'rtk psql database',
  'rtk kubectl apply -f deployment.yaml',
  'rtk kubectl delete pods get',
  'rtk oc rollout restart deployment/app',
  'rtk docker run image',
  'rtk docker run image ps',
  'rtk curl -X POST https://example.com',
  'rtk wget --post-data=x https://example.com',
]) expect(t.commandDecision(command).decision === 'ask', `${command} may mutate external or shared state and must ask`);
for (const command of [
  'rtk gh pr view 42',
  'rtk gh run view 42',
  'rtk glab mr list',
  'rtk kubectl get pods',
  'rtk oc logs pod/app',
  'rtk docker ps',
  'rtk docker compose logs',
  'rtk curl https://example.com',
  'rtk wget https://example.com',
]) expect(t.commandDecision(command).decision === 'allow', `${command} is read-only and may allow via RTK`);
for (const command of ['yarn why lodash', 'bun --version']) {
  expect(t.commandDecision(command).decision === 'allow', `${command} must allow when RTK does not support it`);
  expect(t.commandDecision(`rtk proxy ${command}`).decision === 'allow', `rtk proxy ${command} must preserve safety classification`);
}
const rtkRequiredCommands = [
  'git', 'gh', 'glab', 'aws', 'psql', 'pnpm',
  'dotnet', 'docker', 'kubectl', 'oc', 'wget',
  'jest', 'vitest', 'prisma', 'tsc', 'next', 'lint', 'prettier', 'format',
  'playwright', 'cargo', 'npm', 'npx', 'curl', 'ruff', 'pytest', 'mypy',
  'rake', 'rubocop', 'rspec', 'pip', 'go', 'gt', 'golangci-lint', 'gradlew', 'mvn',
  'ecs', 'paratest', 'pest', 'php', 'phpstan', 'phpunit', 'pint', 'sbt', 'uv',
];
const rtkDiscoveryCommands = ['ls', 'tree', 'find', 'diff', 'grep', 'rg', 'wc'];
for (const command of [...rtkRequiredCommands, ...rtkDiscoveryCommands]) {
  expect(t.RTK_REQUIRED_COMMANDS.has(command), `${command} must remain documented as RTK-supported`);
  expect(t.commandDecision(`${command} --version`, noModernTools).decision === 'allow', `${command} version checks must not require RTK`);
}
expect(t.RTK_OPTIONAL_COMMANDS.size === 0, 'RTK-supported command families retain a single documentation list');
expect(t.SPECIALIZED_TOOLS.has('recall'), 'recall must be a first-party specialized tool');
expect(t.isMcpOrCustomTool('recall', { id: 'aaaaaaaaaaaa' }) === false, 'recall must not require custom-tool approval');
expect(t.commandDecision('pip show requests').decision === 'allow', 'regular package metadata reads must not require RTK');
for (const command of ['poetry show', 'printf x']) {
  expect(t.commandDecision(command).decision === 'allow', `${command} must allow when RTK does not support it`);
}
for (const command of ['rtk proxy poetry show', 'rtk proxy printf x']) {
  expect(t.commandDecision(command).decision === 'allow', `${command} must preserve safety classification`);
}
expect(t.commandDecision('printf x\ngit reset --hard').decision === 'deny', 'newline-separated reset --hard must deny');
expect(t.commandDecision('printf x\r\ngit reset --hard').decision === 'deny', 'CRLF-separated reset --hard must deny');
expect(t.commandDecision('rtk proxy printf x\ncat .env').decision === 'ask', 'newline-separated protected-path read must ask');
expect(t.commandDecision('printf x\nprintf y').decision === 'allow', 'unsupported multiline raw commands must allow when safe');
expect(t.commandDecision('cat .env').decision === 'ask', 'bare protected-path read must ask');
expect(t.commandDecision('cat .env.local').decision === 'ask', 'root-relative protected-path read must ask');
expect(t.commandDecision('cat .envrc').decision === 'ask', '.envrc read must ask');
expect(t.commandDecision('cat /tmp/.env.production').decision === 'ask', 'absolute protected-path read must ask');
expect(t.commandDecision('printf EXAMPLE=value > .env.example').decision === 'allow', 'public env template writes must allow');
expect(t.commandDecision('rtk cat ./config/../.env.local').decision === 'ask', 'rtk-wrapped protected-path read must ask');
expect(t.commandDecision('rtk rg SECRET .env').decision === 'ask', 'RTK-supported command must gate protected paths');
expect(t.commandDecision('ls src && cat credentials.json').decision === 'ask', 'compound protected-path read must ask');
expect(t.commandDecision('cat src/main.ts', noModernTools).decision === 'allow', 'direct cat must allow when bat is unavailable');
expect(t.commandDecision('cat "$SECRET_FILE"').decision === 'ask', 'variable shell paths must fail closed as ambiguous');
expect(t.commandDecision('rtk proxy bat .e?v').decision === 'ask', 'unquoted protected-path glob must fail closed');
expect(t.commandDecision("rtk rg 'src/*.ts'").decision === 'allow', 'quoted glob argument must remain usable');
expect(t.commandDecision("rtk rg '\\d+' src/main.ts").decision === 'allow', 'quoted regex escape must remain usable');
expect(t.commandDecision("cat '.env").decision === 'ask', 'unbalanced shell quotes must fail closed');

// Ambiguous shell
expect(t.commandDecision('eval "$(echo git reset --hard)"').decision === 'ask', 'eval must ask');
expect(t.hasAmbiguousShellSyntax('$(git reset --hard)') === true, 'subshell must be ambiguous');
expect(t.hasUnbalancedQuotes("cat '.env") === true, 'unbalanced quotes must be ambiguous');
expect(t.commandDecision('bash <(printf "git reset --hard")').decision === 'ask', 'process substitution must ask');
expect(t.commandDecision('rtk proxy find . -exec git reset --hard \\;').decision === 'ask', 'RTK find execution proxy must ask');
expect(t.commandDecision('rtk proxy printf "git reset --hard" | rtk proxy xargs sh').decision === 'ask', 'xargs execution proxy must ask');
expect(t.commandDecision('if rtk ls .; then rtk proxy echo ok; fi').decision === 'ask', 'if control structure must ask');
expect(t.commandDecision('while rtk ls .; do rtk proxy echo ok; break; done').decision === 'ask', 'while control structure must ask');
expect(t.hasShellControlSyntax('for item in one; do rtk proxy echo "$item"; done') === true, 'for control structure must be recognized');

// Interpreter/eval-style wrappers (opaque body) must ask
expect(t.commandDecision("bash -c 'git reset --hard'").decision === 'ask', 'bash -c must ask');
expect(t.commandDecision("sh -c 'git push --force'").decision === 'ask', 'sh -c must ask');
expect(t.commandDecision("node -e \"require('fs').rmSync('.')\"").decision === 'ask', 'node -e must ask');
expect(t.commandDecision('python3 -c "import os; os.system(\'git reset --hard\')"').decision === 'ask', 'python -c must ask');
for (const command of ['bash ./untrusted.sh', 'python3 ./untrusted.py', 'node app.js', 'python3 -m untrusted_module', './untrusted.sh', '../untrusted.sh', '/tmp/untrusted', '/tmp/rtk git status', 'sudo /tmp/untrusted', 'rtk /usr/bin/../../tmp/untrusted', 'rtk ~/untrusted']) {
  expect(t.commandDecision(command).decision === 'ask', `${command} must gate opaque code execution`);
}
expect(t.commandDecision('/usr/bin/printf x').decision === 'allow', 'trusted absolute system executable may allow');
expect(t.isInterpreterOpaque(['bash', '-c', 'git reset --hard']) === true, 'isInterpreterOpaque bash -c');
expect(t.isInterpreterOpaque(['bash', './untrusted.sh']) === true, 'isInterpreterOpaque script file');
expect(t.commandDecision('bash --version').decision === 'allow', 'unsupported raw shell executable may allow');
expect(t.commandDecision('rtk proxy bash --version').decision === 'allow', 'rtk proxy shell executable may allow');

// Protected paths
expect(t.isProtectedPath('.env') === true, '.env protected');
expect(t.isProtectedPath('.env.local') === true, 'root-relative .env variant protected');
expect(t.isProtectedPath('.envrc') === true, '.envrc protected');
expect(t.isProtectedPath('.envrc.local') === true, '.envrc variant protected');
expect(t.isProtectedPath('/tmp/.env.production') === true, 'absolute .env variant protected');
expect(t.isProtectedPath('.env.example') === false, 'public env template must not be protected');
expect(t.isProtectedPath('.ssh/.env.example') === true, 'env template within SSH directory must remain protected');
expect(t.isProtectedPath('.aws/.env.example') === true, 'env template within AWS directory must remain protected');
expect(t.isProtectedPath('src/app.env') === true, 'app.env protected');
expect(t.isProtectedPath('secrets.json') === true, 'secrets. marker');
expect(t.isProtectedPath('apps/api/src/modules/provider-secrets/application/provider-secrets.service.ts') === false, 'secret words inside code path must not protect it');
expect(t.isProtectedPath('apps/api/src/modules/provider-credentials/application/provider-credentials.service.ts') === false, 'credential words inside code path must not protect it');
expect(t.isProtectedPath('apps/api/src/modules/secrets/application/secrets.service.ts') === false, 'secret-named source file must not protect it');
expect(t.isProtectedPath('apps/api/src/modules/credentials/application/credentials.service.ts') === false, 'credential-named source file must not protect it');
expect(t.isProtectedPath('credentials.types.ts') === false, 'credential-named compound source file must not protect it');
expect(t.isProtectedPath('secrets.fixture.ts') === false, 'secret-named compound source file must not protect it');
expect(t.isProtectedPath('credentials.ts') === true, 'literal credential source file protected');
expect(t.isProtectedPath('secrets.ts') === true, 'literal secret source file protected');
expect(t.isProtectedPath('credentials.json') === true, 'credential data file protected');
expect(t.isProtectedPath('.git/config') === true, '.git path protected');
expect(t.isProtectedPath('src/main.ts') === false, 'normal path not protected');
expect(t.nativePathDecision('write', 'apps/api/src/modules/provider-secrets/application/provider-secrets.service.ts').decision === 'allow', 'code path containing secret words must allow writes');
expect(t.nativePathDecision('write', 'apps/api/src/modules/provider-credentials/application/provider-credentials.service.ts').decision === 'allow', 'code path containing credential words must allow writes');
expect(t.nativePathDecision('write', 'apps/api/src/modules/secrets/application/secrets.service.ts').decision === 'allow', 'secret-named source file must allow writes');
expect(t.nativePathDecision('write', 'apps/api/src/modules/credentials/application/credentials.service.ts').decision === 'allow', 'credential-named source file must allow writes');
expect(t.nativePathDecision('write', 'credentials.types.ts').decision === 'allow', 'credential-named compound source file must allow writes');
expect(t.nativePathDecision('write', 'credentials.ts').decision === 'deny', 'literal credential source file must remain blocked');
expect(t.nativePathDecision('write', 'secrets.ts').decision === 'deny', 'literal secret source file must remain blocked');
expect(t.nativePathDecision('read', '.env').decision === 'ask', 'protected native read must ask for approval');
expect(t.nativePathDecision('read', '.envrc').decision === 'ask', '.envrc native read must ask for approval');
expect(t.nativePathDecision('write', '.env').decision === 'deny', 'protected native write must remain blocked');
expect(t.nativePathDecision('write', '.envrc').decision === 'deny', '.envrc native write must remain blocked');
expect(t.nativePathDecision('edit', '.env').decision === 'deny', 'protected native edit must remain blocked');
expect(t.nativePathDecision('edit', '.envrc').decision === 'deny', '.envrc native edit must remain blocked');
expect(t.nativePathDecision('write', '.env.example').decision === 'allow', 'public env template writes must allow');
expect(t.nativePathDecision('write', '.ssh/.env.example').decision === 'deny', 'SSH directory env template writes must remain blocked');
expect(t.nativePathDecision('write', '.aws/.env.example').decision === 'deny', 'AWS directory env template writes must remain blocked');
expect(t.nativePathDecision('read', 'src/main.ts').decision === 'allow', 'normal native read must allow');
expect(t.nativePathDecision('read', '/etc/passwd').decision === 'ask', 'outside-project native reads must ask');
expect(t.nativePathDecision('write', '/etc/hosts').decision === 'ask', 'outside-project native writes must ask');
expect(t.nativePathDecision('write', 'pi/tests/new-file.ts').decision === 'allow', 'project-local native writes must allow');
const serenaCodeFixture = mkdtempSync(path.join(root, 'pi/tests/', '.b-agentic-serena-'));
try {
  const providerSecretsService = path.join(serenaCodeFixture, 'provider-secrets.service.ts');
  const providerCredentialsService = path.join(serenaCodeFixture, 'provider-credentials.service.ts');
  writeFileSync(providerSecretsService, 'export const providerSecrets = true;');
  writeFileSync(providerCredentialsService, 'export const providerCredentials = true;');
  expect(t.isConditionallyTrustedTool('serena', 'serena_get_symbols_overview', { relative_path: providerSecretsService }) === true, 'Serena must trust code paths containing secret words');
  expect(t.isConditionallyTrustedTool('serena', 'serena_get_symbols_overview', { relative_path: providerCredentialsService }) === true, 'Serena must trust code paths containing credential words');
} finally {
  rmSync(serenaCodeFixture, { recursive: true, force: true });
}
const protectedPathFixture = mkdtempSync(path.join(os.tmpdir(), 'b-agentic-protected-path-'));
try {
  const secretPath = path.join(protectedPathFixture, '.env');
  const secretLink = path.join(protectedPathFixture, 'safe-link');
  const secretDirectory = path.join(protectedPathFixture, '.ssh');
  const secretDirectoryLink = path.join(protectedPathFixture, 'safe-directory');
  writeFileSync(secretPath, 'secret');
  mkdirSync(secretDirectory);
  symlinkSync(secretPath, secretLink);
  symlinkSync(secretDirectory, secretDirectoryLink);
  expect(t.nativePathDecision('read', secretLink).decision === 'ask', 'symlinked protected read must ask for approval');
  expect(t.nativePathDecision('write', secretLink).decision === 'deny', 'symlinked protected write must deny');
  expect(t.nativePathDecision('edit', path.join(secretDirectoryLink, 'new-file')).decision === 'deny', 'protected write through symlinked directory must deny');
  expect(t.commandDecision(`cat ${secretLink}`).decision === 'ask', 'shell reads through protected symlinks must ask');
  expect(t.commandDecision(`printf x > ${secretLink}`).decision === 'ask', 'shell writes through protected symlinks must ask');
  expect(t.isConditionallyTrustedTool('serena', 'serena_get_symbols_overview', { relative_path: secretLink }) === false, 'Serena must not autonomously read a symlinked protected path');
} finally {
  rmSync(protectedPathFixture, { recursive: true, force: true });
}
for (const pathValue of ['.npmrc', '.netrc', '.pypirc', '.git-credentials', '.config/gh/hosts.yml', '.ssh/config']) {
  expect(t.nativePathDecision('read', pathValue).decision === 'ask', `${pathValue} must require approval`);
}
const protectedReadReason = t.nativePathDecision('read', '.env').reason;
expect(await t.confirmOrBlock({ hasUI: false, ui: { confirm: async () => true } }, 'test', 'test', protectedReadReason), 'protected native read must fail closed without UI');
expect((await t.confirmOrBlock({ hasUI: true, ui: { confirm: async () => true } }, 'test', 'test', protectedReadReason)) === undefined, 'approved protected native read must allow');
expect(await t.confirmOrBlock({ hasUI: true, ui: { confirm: async () => false } }, 'test', 'test', protectedReadReason), 'denied protected native read must block');

// The gateway auto-allows only an unambiguous, classified safe managed call.
expect(t.isMcpOrCustomTool('bash') === false, 'bash is specialized');
expect(t.isMcpOrCustomTool('mcp', { search: 'symbol' }) === true, 'MCP metadata search requires the approval gate');
expect(t.isMcpOrCustomTool('mcp', { describe: 'tool' }) === true, 'MCP metadata describe requires the approval gate');
expect(t.isMcpOrCustomTool('mcp', { action: 'ui-messages' }) === true, 'MCP UI message retrieval requires the approval gate');
expect(t.isMcpOrCustomTool('mcp', { server: 'serena', tool: 'serena_read_memory' }) === false, 'classified managed read-only gateway execution must auto-allow');
expect(t.isMcpOrCustomTool('mcp', { server: 'firecrawl', tool: 'firecrawl_search', args: '{"query":"Pi","limit":1}' }) === false, 'validated conditional gateway execution must auto-allow');
expect(t.isMcpOrCustomTool('mcp', { tool: 'serena_read_memory' }) === true, 'gateway execution without explicit server ownership must require approval');
expect(t.isMcpOrCustomTool('mcp', { tool: 'serena_onboarding', args: '{}' }) === true, 'managed Serena gateway execution requires the top-level gate');
expect(t.isMcpOrCustomTool('mcp', { tool: 'serena_onboarding', args: '{"unexpected":true}' }) === true, 'managed Serena gateway execution requires the top-level gate');
expect(t.isMcpOrCustomTool('mcp', { tool: 'serena_write_memory', args: JSON.stringify({ memory_name: 'core', content: 'repo map' }) }) === true, 'managed Serena gateway execution requires the top-level gate');
expect(t.isMcpOrCustomTool('mcp', { tool: 'serena_write_memory', args: JSON.stringify({ memory_name: 'task_note', content: 'do not persist' }) }) === true, 'managed Serena gateway execution requires the top-level gate');
expect(t.isMcpOrCustomTool('mcp', { tool: 'serena_replace_content' }) === true, 'managed Serena gateway execution requires the top-level gate');
expect(t.isMcpOrCustomTool('mcp', { tool: 'firecrawl_parse' }) === true, 'managed Firecrawl gateway execution requires the top-level gate');
expect(t.isMcpOrCustomTool('mcp', { tool: 'mcpScript' }) === true, 'MCP scripting remains approval-gated');
expect(t.isMcpOrCustomTool('mcp', { tool: 'playwright_browser_click' }) === true, 'managed Playwright gateway execution requires the top-level gate');
expect(t.isMcpOrCustomTool('mcp', { tool: 'playwright_browser_navigate', args: JSON.stringify({ url: 'https://example.com' }) }) === true, 'managed Playwright gateway execution requires the top-level gate');
expect(t.isMcpOrCustomTool('mcp', { tool: 'playwright_browser_navigate_back' }) === true, 'managed Playwright gateway execution requires the top-level gate');
expect(t.isMcpOrCustomTool('mcp', { tool: 'playwright_browser_navigate', args: JSON.stringify({ url: 'https://example.com/redirect?target=http://127.0.0.1' }) }) === true, 'managed Playwright gateway execution requires the top-level gate');
expect(t.isMcpOrCustomTool('mcp', { tool: 'playwright_browser_navigate', args: JSON.stringify({ url: 'http://localhost:3000' }) }) === true, 'managed Playwright gateway execution requires the top-level gate');
expect(t.isMcpOrCustomTool('mcp', { tool: 'playwright_browser_take_screenshot', args: '{}' }) === true, 'managed Playwright gateway execution requires the top-level gate');
expect(t.isMcpOrCustomTool('mcp', { tool: 'playwright_browser_take_screenshot', args: JSON.stringify({ filename: 'shot.png' }) }) === true, 'managed Playwright gateway execution requires the top-level gate');
expect(t.isMcpOrCustomTool('mcp', { connect: 'serena' }) === true, 'managed MCP connect requires approval');
expect(t.isMcpOrCustomTool('mcp', { server: 'firecrawl' }) === true, 'managed MCP server listing requires approval');
expect(t.isMcpOrCustomTool('mcp', { server: 'serena', tool: 'new_serena_tool' }) === true, 'unlisted managed gateway execution requires the top-level gate');
expect(t.isMcpOrCustomTool('serena_replace_content') === true, 'direct managed Serena tools retain the top-level approval gate');
expect(t.isMcpOrCustomTool('serena_read_memory') === true, 'direct trusted-looking Serena names retain the top-level approval gate');
expect(t.isMcpOrCustomTool('firecrawl_firecrawl_agent') === true, 'direct managed Firecrawl tools retain the top-level approval gate');
expect(t.isMcpOrCustomTool('firecrawl_developer_search') === true, 'direct trusted-looking Firecrawl names retain the top-level approval gate');
expect(t.isMcpOrCustomTool('browser_click') === true, 'direct managed Playwright tools retain the top-level approval gate');
expect(t.isMcpOrCustomTool('browser_snapshot') === true, 'direct trusted-looking Playwright names retain the top-level approval gate');
expect(t.isMcpOrCustomTool('mcp', { server: 'serena', tool: 'firecrawl_agent' }) === true, 'mismatched server/tool fails closed');
expect(t.isMcpOrCustomTool('mcp', { server: 'serena', tool: 'mcp__firecrawl__serena_read_memory' }) === true, 'MCP namespace/server mismatches fail closed');
expect(t.isMcpOrCustomTool('mcp', { connect: 'firecrawl', tool: 'firecrawl_agent' }) === true, 'mixed MCP selectors fail closed');
expect(t.isMcpOrCustomTool('mcp', { tool: 'user_tool', server: 'user-server' }) === true, 'user MCP tool requires approval');
expect(t.isMcpOrCustomTool('some-extension-tool') === true, 'unknown tool is custom');
expect(t.isTrustedManagedTool('playwright', 'browser_snapshot', { depth: 2 }) === true, 'safe Playwright snapshots are trusted');
expect(t.isTrustedManagedTool('playwright', 'browser_snapshot', { filename: 'artifacts/snapshot.md' }) === true, 'project-confined snapshot filenames are trusted');
expect(t.isTrustedManagedTool('playwright', 'browser_snapshot', { filename: '/tmp/snapshot.md' }) === false, 'outside-project snapshot filenames require approval');
expect(t.isTrustedManagedTool('playwright', 'browser_close') === false, 'browser close requires approval');
expect(t.isTrustedManagedTool('playwright', 'browser_resize') === false, 'browser resize requires approval');
expect(t.isTrustedManagedTool('playwright', 'browser_hover') === false, 'browser hover requires approval');
expect(t.isTrustedManagedTool('firecrawl', 'new_tool') === false, 'unlisted managed tool is not trusted');
expect(t.isTrustedManagedTool('firecrawl', 'firecrawl_search', { query: 'Pi coding agent', limit: 10 }) === true, 'bounded Firecrawl search is trusted');
expect(t.isTrustedManagedTool('firecrawl', 'firecrawl_search', { query: 'Pi coding agent', limit: 10, highlights: true }) === true, 'Firecrawl search highlights are trusted');
expect(t.isTrustedManagedTool('firecrawl', 'firecrawl_search', { query: 'Pi coding agent', limit: 10, unexpected: true }) === false, 'unknown Firecrawl search arguments require approval');
expect(t.isTrustedManagedTool('firecrawl', 'firecrawl_developer_search', { query: 'Pi MCP adapter approval broker', k: 10 }) === true, 'Firecrawl developer search is trusted');
expect(t.isTrustedManagedTool('firecrawl', 'firecrawl_scrape', { url: 'https://example.org' }) === true, 'public Firecrawl scrape is trusted');
expect(t.isTrustedManagedTool('firecrawl', 'firecrawl_scrape', { url: 'https://example.org', skipTlsVerification: true }) === false, 'Firecrawl scrape with TLS verification disabled must require approval');
expect(t.isTrustedManagedTool('firecrawl', 'firecrawl_search', { query: 'Pi coding agent' }) === false, 'Firecrawl search without an explicit bound requires approval');
expect(t.isTrustedManagedTool('firecrawl', 'firecrawl_search', { query: 'Pi coding agent', limit: 11 }) === false, 'Firecrawl search above the local bound requires approval');
expect(t.isTrustedManagedTool('firecrawl', 'firecrawl_search', { query: 'Pi coding agent', limit: 0 }) === false, 'empty Firecrawl search bounds require approval');
expect(t.isTrustedManagedTool('firecrawl', 'firecrawl_map', { url: 'https://example.org', limit: 10 }) === true, 'bounded public Firecrawl map is trusted');
expect(t.isTrustedManagedTool('firecrawl', 'firecrawl_map', { url: 'http://127.0.0.1', limit: 10 }) === false, 'private Firecrawl map must require approval');
expect(t.isTrustedManagedTool('firecrawl', 'firecrawl_map', { url: 'https://user:token@example.org', limit: 10 }) === false, 'credential-bearing Firecrawl map must require approval');
expect(t.isTrustedManagedTool('firecrawl', 'firecrawl_extract', { urls: ['https://example.org'], enableWebSearch: false }) === true, 'bounded public Firecrawl extract is trusted');
expect(t.isTrustedManagedTool('firecrawl', 'firecrawl_extract', { urls: ['https://example.org'], allowExternalLinks: true }) === false, 'unbounded Firecrawl extract must require approval');
expect(t.isTrustedManagedTool('serena', 'serena_read_memory') === true, 'managed read-only tool is trusted');
expect(t.isProjectConfinedPath(path.join(root, 'pi/extensions/b-agentic-permissions.ts')) === true, 'project file must be confined');
expect(t.isProjectConfinedPath(os.tmpdir()) === false, 'outside path must not be project-confined');
expect(t.isConditionallyTrustedTool('serena', 'serena_get_symbols_overview', { relative_path: os.tmpdir() }) === false, 'Serena reads outside the project require approval');
expect(t.isTrustedManagedTool('user-server', 'user_tool') === false, 'unmanaged server is not trusted');
expect(t.approvalLabel('\u001b[31mtool\u0007\u009b') === ' [31mtool  ', 'broker approval labels must strip terminal control characters');
expect(t.MANAGED_MCP_SERVERS.has('playwright'), 'managed MCP servers present');

console.log('pi permission behavioral fixtures ok');
NODE

	# Source-backed uninstall removes managed content only.
	expect_install_status 0 "$sandbox" "$snapshot_repo" --uninstall
	assert_no_path "$sandbox/home/.pi/agent/skills/b-plan"
	assert_no_path "$sandbox/home/.pi/agent/b-agentic/install.json"
	assert_no_path "$sandbox/home/.pi/agent/extensions/b-agentic-permissions.ts"
	# User MCP entries would be preserved by merge cleanup; managed-only install removes mcp.json entirely.
}
