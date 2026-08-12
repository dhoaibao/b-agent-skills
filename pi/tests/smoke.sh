# Sourced by tests/smoke/install.sh — do not run directly.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
	echo "error: this script is sourced by tests/smoke/install.sh" >&2
	exit 1
fi

run_pi_permission_behavioral_fixture() {
	local sandbox="$1"
	# Behavioral permission coverage via node --experimental-strip-types (no Pi runtime).
	ROOT_DIR="$ROOT_DIR" PI_TEST_HOME="$sandbox/home" PI_CODING_AGENT_DIR="$sandbox/home/.pi/agent" node --experimental-strip-types --input-type=module - <<'NODE'
import { mkdirSync, mkdtempSync, readFileSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const root = process.env.ROOT_DIR || process.cwd();
process.env.B_AGENTIC_DIR = path.join(root, '.b-agentic-test');
const installedRoot = path.join(process.env.PI_TEST_HOME || '', '.pi/agent/extensions');
const extensionModules = await Promise.all([
  'b-agentic-permissions.ts', 'b-agentic-mcp-permissions.ts', 'b-agentic-auto-mode.ts', 'b-agentic-role.ts',
  'b-agentic-planner.ts', 'b-agentic-worker.ts', 'b-agentic-sync.ts',
].map((name) => import(pathToFileURL(path.join(installedRoot, name)).href)));
for (const name of ['shell.ts', 'mcp.ts', 'role.ts', 'role-models.ts', 'worker.ts', 'state.ts', 'auto.ts']) {
  await import(pathToFileURL(path.join(installedRoot, 'b-agentic-support', name)).href);
}
const mod = extensionModules[0];
const t = mod.__test__;
const roleTest = extensionModules[3].__test__;
if (!t) {
  console.error('permission extension missing __test__ exports');
  process.exit(1);
}
const handlers = {};
const registrations = {};
const commands = {};
const tools = {};
const flags = {};
const flagDefinitions = {};
const persistedEntries = [];
const branchEntries = [];
let activeTools = ['read', 'bash', 'edit', 'write', 'recall', 'intercom', 'mcp', 'mcpScript'];
let activeModel = { provider: 'anthropic', id: 'claude-sonnet-4-5' };
let activeThinkingLevel = 'high';
const roleStatuses = [];
const roleNotifications = [];
const sentMessages = [];
let mcpApprovalHandler;
let roleChannelRegistration;
const executedCommands = [];
const extensionHost = {
  on(eventName, handler) {
    (registrations[eventName] ||= []).push(handler);
    handlers[eventName] = async (...args) => {
      let result;
      for (const registered of registrations[eventName] || []) {
        const next = await registered(...args);
        if (eventName === 'before_agent_start' && next) result = { ...result, ...next };
        else if (next) return next;
      }
      return result;
    };
  },
  registerFlag(name, definition) { flagDefinitions[name] = definition; },
  getFlag(name) { return flags[name]; },
  registerCommand(name, definition) { commands[name] = definition; },
  registerTool(definition) { tools[definition.name] = definition; },
  async exec(command, args, options) {
    executedCommands.push({ command, args, options });
    return { code: 0, stdout: '', stderr: '', killed: false };
  },
  getActiveTools() { return [...activeTools]; },
  setActiveTools(names) { activeTools = [...names]; },
  async setModel(model) { activeModel = model; return true; },
  getThinkingLevel() { return activeThinkingLevel; },
  setThinkingLevel(level) { activeThinkingLevel = level; },
  sendMessage(message, options) { sentMessages.push({ message, options }); },
  appendEntry(customType, data) {
    const entry = { type: 'custom', customType, data };
    persistedEntries.push(entry);
    branchEntries.push(entry);
  },
  events: {
    on(channel, handler) {
      if (channel === 'pi-mcp-adapter:tool-approval-request') mcpApprovalHandler = handler;
      return () => {};
    },
    emit(channel, value) {
      if (channel === 'intercom:extension-register') roleChannelRegistration = value;
    },
  },
};
for (const extension of extensionModules) extension.default(extensionHost);
const toolCallHandler = handlers.tool_call;

function expect(cond, msg) {
  if (!cond) throw new Error(msg);
}

const validIntercomCalls = [
  { action: 'list' },
  { action: 'list-cwd' },
  { action: 'list-cwd', cwd: '/workspace/b-agentic' },
  { action: 'status' },
  { action: 'pending' },
  { action: 'send', to: 'peer', message: 'bounded task', attachments: [{ type: 'snippet', name: 'note.md', content: 'context', language: 'markdown' }], replyTo: 'message-1', supersedes: 'message-0', retryOf: 'message-previous' },
  { action: 'ask', to: 'peer', message: 'question' },
  { action: 'reply', message: 'answer', replyTo: 'message-1' },
  { action: 'cancel', messageId: 'message-1' },
];
for (const input of validIntercomCalls) {
  expect(t.isAutoApprovedIntercomCall('intercom', input) === true, `valid Intercom call must be auto-approved: ${input.action}`);
}
expect(t.isAutoApprovedIntercomCall('intercom', { action: 'send', to: 'peer', message: 'attachment', attachments: [] }) === true, 'empty Intercom attachments remain auto-approved');
expect(t.isAutoApprovedIntercomCall('intercom', { action: 'send', to: 'peer', message: 'unknown', priority: 'high' }) === false, 'Intercom unknown fields remain approval-gated');
expect(t.isAutoApprovedIntercomCall('intercom', { action: 'send', to: 'peer', message: 'bad attachment', attachments: [{ type: 'snippet', name: 'note.md', content: 'context', extra: true }] }) === false, 'invalid Intercom attachments remain approval-gated');
expect(t.isAutoApprovedIntercomCall('intercom', { action: 'unknown' }) === false, 'unknown Intercom actions remain approval-gated');
expect(t.isAutoApprovedIntercomCall('intercom', { action: 'cancel', messageId: 1 }) === false, 'invalid Intercom optional field types remain approval-gated');
expect(t.isAutoApprovedIntercomCall('intercom', { action: 'reply', replyTo: 'message-1' }) === true, 'targetless schema-valid Intercom replies remain auto-approved');

expect(typeof toolCallHandler === 'function', 'permission extension must register a tool_call handler');
expect(typeof mcpApprovalHandler === 'function', 'permission extension must register the MCP approval broker');
expect(tools.b_agentic_confirm_commit, 'permission extension must register the commit confirmation tool');
expect(!activeTools.includes('b_agentic_confirm_commit'), 'commit confirmation activation must wait until session startup');
let commitConfirmation;
const approvedCommit = await tools.b_agentic_confirm_commit.execute('', { proposal: '1. fix: preserve test\n   Files: tests/smoke/install.sh' }, undefined, () => {}, {
  hasUI: true,
  ui: {
    select: async (title, options) => {
      commitConfirmation = { title, options };
      return 'Approve';
    },
  },
});
expect(approvedCommit.details.approved === true && approvedCommit.details.uiAvailable === true, 'approved commit confirmation must report approval');
expect(commitConfirmation.title.includes('Confirm commits') && commitConfirmation.title.includes('fix: preserve test') && commitConfirmation.options.join(',') === 'Approve,Cancel', 'commit confirmation must show the exact proposal in a selection UI');
const declinedCommit = await tools.b_agentic_confirm_commit.execute('', { proposal: 'proposal' }, undefined, () => {}, { hasUI: true, ui: { select: async () => 'Cancel' } });
expect(declinedCommit.details.approved === false && declinedCommit.details.uiAvailable === true, 'declined commit confirmation must not approve commits');
const unavailableCommit = await tools.b_agentic_confirm_commit.execute('', { proposal: 'proposal' }, undefined, () => {}, { hasUI: false, ui: { select: async () => 'Approve' } });
expect(unavailableCommit.details.approved === false && unavailableCommit.details.uiAvailable === false, 'commit confirmation must require an interactive UI');
const noUiContext = { hasUI: false, ui: { select: async () => 'Approve' } };
expect(await toolCallHandler({ toolName: 'b_agentic_confirm_commit', input: { proposal: 'proposal' } }, noUiContext) === undefined, 'commit confirmation must bypass generic custom-tool approval');
let rolePickerCalls = 0;
let modelPickerCalls = 0;
const roleContext = {
  get model() { return activeModel; },
  cwd: root,
  hasUI: true,
  ui: {
    confirm: async () => true,
    select: async (title) => {
      if (title === 'Select b-agentic role') {
        rolePickerCalls += 1;
        return 'planner';
      }
      if (title.startsWith('Select model for b-agentic ')) {
        modelPickerCalls += 1;
        return 'anthropic/claude-sonnet-4-5';
      }
      return 'Allow once';
    },
    notify(message, level) { roleNotifications.push({ message, level }); },
    theme: {
      fg(color, text) { return `<${color}>${text}</${color}>`; },
    },
    setStatus(key, value) { roleStatuses.push({ key, value }); },
  },
  modelRegistry: {
    find: (provider, id) => provider === 'anthropic' && id === 'claude-sonnet-4-5' ? { provider, id } : undefined,
    getAvailable: () => [{ provider: 'anthropic', id: 'claude-sonnet-4-5' }],
  },
  scopedModels: [],
  sessionManager: {
    getBranch: () => [...branchEntries],
  },
};
await registrations.session_start[0]({}, roleContext);
expect(activeTools.includes('b_agentic_confirm_commit'), 'registered commit confirmation tool must activate after session startup');
branchEntries.push({
  type: 'custom', customType: 'b-agentic-role',
  data: { role: 'planner', toolsBeforePlanner: ['read', 'bash', 'edit', 'write', 'b_agentic_confirm_commit'] },
});
activeTools = ['read', 'bash'];
await handlers.session_start({}, roleContext);
expect(roleStatuses.at(-1)?.value === '<warning>b-agentic: planner (read-only)</warning>', 'planner status must use the warning color');
expect(roleChannelRegistration?.namespace === 'b-agentic/roles/v1', 'roles must register an Intercom coordination channel');
const publishedRoles = [];
roleChannelRegistration.onReady({
  publish(payload) { publishedRoles.push(payload); },
  listSessions: async () => [{ id: 'planner', cwd: root, pid: process.pid, startedAt: 1 }],
});
expect(publishedRoles.length === 0, 'role channel must not publish before Intercom connects');
await roleChannelRegistration.onEvent({ type: 'connection', connected: true, supported: true });
expect(publishedRoles.some((payload) => payload.role === 'planner'), 'role channel must publish its role after Intercom connects');
expect(publishedRoles.some((payload) => payload.type === 'b-agentic-role-request'), 'role channel must request existing peer roles after Intercom connects');
const roster = await registrations.before_agent_start[0]({ systemPrompt: 'base' }, roleContext);
expect(roster.systemPrompt.includes('Ready same-CWD workers: none'), 'planner roster must use the ready Intercom channel');
const plannerAndWorker = [
  { id: 'planner', cwd: root, pid: 101, startedAt: 1 },
  { id: 'worker', cwd: root, pid: 202, startedAt: 2 },
];
expect(roleTest.hasKnownSameCwdPeerRoles(plannerAndWorker, root, 202, new Map()) === false, 'an explicit worker must wait for existing peer roles');
expect(roleTest.hasKnownSameCwdPeerRoles(plannerAndWorker, root, 202, new Map([['planner', 'planner']])) === true, 'an explicit worker can claim after peer role discovery');
expect(roleTest.hasKnownSameCwdPeerRoles(plannerAndWorker, root, 202, new Map([['planner', 'off']])) === true, 'an off peer must not block role discovery');
expect(roleTest.hasActiveSameCwdPeerWorker(plannerAndWorker, root, 202, new Map([['worker', 'worker']])) === false, 'a session must not treat its own worker role announcement as an active peer');
expect(roleTest.hasActiveSameCwdPeerWorker(plannerAndWorker, root, 202, new Map([['planner', 'worker']])) === true, 'a same-CWD peer worker must remain active');
const plannerAndWorkerClaim = [
  { id: 'planner', cwd: root, pid: 101, startedAt: 1 },
  { id: 'worker', cwd: root, pid: 202, startedAt: 2 },
];
expect(roleTest.canClaimWorker(plannerAndWorkerClaim, root) === true, 'a two-role session may claim its explicit worker');
expect(roleTest.canClaimWorker([...plannerAndWorkerClaim, { id: 'other', cwd: root, pid: 303, startedAt: 3 }], root) === false, 'a third same-CWD session must not claim another worker');
expect(activeTools.length === 2 && activeTools.includes('read') && activeTools.includes('bash') && !activeTools.includes('b_agentic_confirm_commit'), 'persisted planner role must restore its safe analysis tool set');
expect(persistedEntries.at(-1)?.data.toolsBeforePlanner?.includes('write'), 'persisted planner tools must remain available for restoration after leaving the role');
activeTools = ['read', 'bash'];
await handlers.session_start({}, roleContext);
expect(activeTools.length === 2 && activeTools.includes('read') && activeTools.includes('bash'), 'planner role must retain safe analysis tools on later resumes');
await commands['b-role'].handler('off', roleContext);
expect(activeTools.includes('b_agentic_confirm_commit'), 'leaving planner mode must restore the active commit confirmation tool');
branchEntries.length = 0;
activeTools = ['read', 'bash', 'edit', 'write', 'recall', 'intercom', 'mcp', 'mcpScript', 'b_agentic_confirm_commit'];
await registrations.session_start.at(-1)({}, roleContext);
expect(activeTools.includes('edit') && activeTools.includes('write') && activeTools.includes('b_agentic_confirm_commit'), 'a session without an explicit role must remain Off with normal tools');
expect(commands['b-role'], 'permission extension must register /b-role');
expect(commands['b-sync'] && commands['b-update'], 'refresh extension must register /b-sync and /b-update');
let refreshConfirmations = 0;
let reloads = 0;
const refreshContext = {
  hasUI: true,
  ui: {
    confirm: async () => { refreshConfirmations += 1; return true; },
    notify() {},
  },
  async reload() { reloads += 1; },
};
await commands['b-sync'].handler('', refreshContext);
await commands['b-update'].handler('', refreshContext);
expect(refreshConfirmations === 1, 'only /b-sync must confirm external updates');
expect(executedCommands.at(-2)?.command === 'bash' && executedCommands.at(-2)?.args.at(-1) === '--sync', '/b-sync must run the sync-only installer mode');
expect(executedCommands.at(-1)?.command === 'bash' && executedCommands.at(-1)?.args.at(-1) === '--update', '/b-update must run the update-only installer mode');
expect(reloads === 2, 'successful refresh commands must reload Pi');
await commands['b-sync'].handler('unexpected', refreshContext);
expect(executedCommands.length === 2 && reloads === 2, '/b-sync arguments must be rejected without a refresh');
await commands['b-role'].handler('', roleContext);
expect(rolePickerCalls === 1, '/b-role without an argument must open a role picker');
expect(modelPickerCalls === 0, '/b-role must not open a model picker');
expect(activeModel.provider === 'anthropic' && activeModel.id === 'claude-sonnet-4-5', '/b-role must leave the active model unchanged');
await handlers.model_select({ model: { provider: 'anthropic', id: 'claude-sonnet-4-5' } }, roleContext);
const roleModelPreferences = JSON.parse(readFileSync(path.join(process.env.PI_CODING_AGENT_DIR, 'b-agentic', 'role-models.json'), 'utf8'));
expect(roleModelPreferences.planner.model === 'claude-sonnet-4-5' && roleModelPreferences.planner.thinkingLevel === 'high', '/model changes must persist the active role preference');
activeThinkingLevel = 'low';
await handlers.thinking_level_select({ level: 'low', previousLevel: 'high' }, { ...roleContext, model: undefined });
const updatedPlannerPreferences = JSON.parse(readFileSync(path.join(process.env.PI_CODING_AGENT_DIR, 'b-agentic', 'role-models.json'), 'utf8'));
expect(updatedPlannerPreferences.planner.provider === 'anthropic' && updatedPlannerPreferences.planner.model === 'claude-sonnet-4-5' && updatedPlannerPreferences.planner.thinkingLevel === 'low', 'thinking-level changes must update the planner preference without changing its saved model when the current model is unavailable');
await commands['b-role'].handler('off', roleContext);
activeModel = { provider: 'other', id: 'other-model' };
activeThinkingLevel = 'off';
await commands['b-role'].handler('planner', roleContext);
expect(activeModel.provider === 'anthropic' && activeModel.id === 'claude-sonnet-4-5' && activeThinkingLevel === 'low', '/b-role planner must apply its saved model and thinking preference');
expect(activeTools.length === 5 && activeTools.every((tool) => ['read', 'recall', 'intercom', 'bash', 'mcp'].includes(tool)), 'planner role must expose its safe analysis and coordination tools');
for (const toolName of ['edit', 'write', 'mcpScript', 'b_agentic_confirm_commit']) {
  expect((await toolCallHandler({ toolName, input: {} }, roleContext))?.block === true, `planner role must block ${toolName}`);
}
branchEntries.length = 0;
branchEntries.push({
  type: 'custom', customType: 'b-agentic-role',
  data: { role: 'planner', automatic: true, toolsBeforePlanner: ['read', 'bash', 'edit', 'write', 'b_agentic_confirm_commit'] },
});
activeTools = ['read', 'bash', 'edit', 'write', 'recall', 'intercom', 'mcp', 'mcpScript', 'b_agentic_confirm_commit'];
await registrations.session_start.at(-1)({}, roleContext);
expect(activeTools.includes('edit') && activeTools.includes('write') && activeTools.includes('b_agentic_confirm_commit'), 'legacy automatic planner state must migrate to Off');
const migratedLegacyStart = await handlers.before_agent_start({ systemPrompt: 'base' }, roleContext);
expect(!migratedLegacyStart?.systemPrompt?.includes('planner profile (read-only coordinator)'), 'legacy automatic planner state must not activate planner prompt');
branchEntries.length = 0;
branchEntries.push({
  type: 'custom', customType: 'b-agentic-role',
  data: { role: 'planner' },
});
activeTools = ['read', 'bash', 'edit', 'write', 'recall', 'intercom', 'mcp', 'mcpScript', 'b_agentic_confirm_commit'];
activeModel = { provider: 'other', id: 'other-model' };
activeThinkingLevel = 'off';
await registrations.session_start.at(-1)({}, roleContext);
expect(!activeTools.includes('write') && !activeTools.includes('edit') && !activeTools.includes('b_agentic_confirm_commit'), 'an explicitly persisted planner must restore planner-safe tools');
expect(activeModel.provider === 'anthropic' && activeModel.id === 'claude-sonnet-4-5' && activeThinkingLevel === 'low', 'a persisted planner role must restore its saved model and thinking preference');
for (const command of ['rtk git status --short', 'fdfind -t f SKILL.md skills', 'eza -la', 'codegraph init']) {
  expect(await toolCallHandler({ toolName: 'bash', input: { command } }, roleContext) === undefined, `planner role must allow safe discovery: ${command}`);
}
for (const command of ['rtk pytest -q', 'rtk git commit -m role-smoke', "rtk git -c 'alias.status=!touch owned' status", 'node -e "process.exit()"']) {
  expect((await toolCallHandler({ toolName: 'bash', input: { command } }, roleContext))?.block === true, `planner role must block worktree or execution command: ${command}`);
}
const plannerSerenaReadArgs = { name_path_pattern: 'applyRole', relative_path: 'pi/extensions/b-agentic-role.ts' };
for (const toolName of ['serena_find_symbol', 'serena_serena_find_symbol', 'mcp__serena__serena_find_symbol']) {
  expect(await toolCallHandler({ toolName, input: plannerSerenaReadArgs }, roleContext) === undefined, `planner role must allow read-only Serena discovery: ${toolName}`);
}
expect(await toolCallHandler({ toolName: 'mcp', input: { server: 'serena', tool: 'serena_find_symbol', args: plannerSerenaReadArgs } }, roleContext) === undefined, 'planner role must allow Serena symbol reads');
expect(await toolCallHandler({ toolName: 'mcp', input: { server: 'serena', tool: 'mcp__serena__serena_find_symbol', args: plannerSerenaReadArgs } }, roleContext) === undefined, 'planner role must allow prefixed Serena gateway reads');
expect(await toolCallHandler({ toolName: 'mcp', input: { server: 'serena', tool: 'serena_initial_instructions', args: {} } }, roleContext) === undefined, 'planner role must allow Serena initial instructions');
expect(await toolCallHandler({ toolName: 'mcp', input: { server: 'codegraph', tool: 'codegraph_codegraph_explore', args: { query: 'role enforcement' } } }, roleContext) === undefined, 'planner role must allow CodeGraph reads');
const plannerSerenaEditArgs = { relative_path: 'README.md', needle: 'old', repl: 'new', mode: 'literal' };
for (const toolName of ['serena_replace_content', 'serena_serena_replace_content', 'mcp__serena__serena_replace_content']) {
  expect((await toolCallHandler({ toolName, input: plannerSerenaEditArgs }, roleContext))?.block === true, `planner role must block Serena repository edits: ${toolName}`);
}
const directPlannerSerenaMutation = await toolCallHandler({ toolName: 'serena_replace_content', input: plannerSerenaEditArgs }, roleContext);
expect(directPlannerSerenaMutation?.block === true && String(directPlannerSerenaMutation.reason).includes('local-mutation Serena calls are blocked'), 'planner mode must fail closed on direct serena_replace_content');
for (const tool of ['serena_replace_content', 'mcp__serena__serena_replace_content']) {
  expect((await toolCallHandler({ toolName: 'mcp', input: { server: 'serena', tool, args: plannerSerenaEditArgs } }, roleContext))?.block === true, `planner role must block Serena gateway repository edits: ${tool}`);
}
let plannerMutationClaim;
mcpApprovalHandler({
  serverName: 'serena', originalToolName: 'serena_replace_content', prefixedToolName: 'serena_serena_replace_content',
  args: plannerSerenaEditArgs, origin: 'direct',
  claim(handler) { plannerMutationClaim = handler; return true; },
});
expect(await plannerMutationClaim() === 'deny', 'planner role must deny Serena mutations through the MCP approval broker');
let plannerReadClaim;
mcpApprovalHandler({
  serverName: 'serena', originalToolName: 'serena_find_symbol', prefixedToolName: 'serena_serena_find_symbol',
  args: plannerSerenaReadArgs, origin: 'direct',
  claim(handler) { plannerReadClaim = handler; return true; },
});
expect(await plannerReadClaim() === 'allow_once', 'planner role must allow Serena discovery through the MCP approval broker');
expect(await toolCallHandler({ toolName: 'intercom', input: { action: 'send', to: 'worker', message: 'Implement the approved task.' } }, roleContext) === undefined, 'planner role must allow Intercom handoffs');
expect(await toolCallHandler({ toolName: 'intercom', input: { action: 'ask', to: 'worker', message: 'Need clarification?' } }, roleContext) === undefined, 'planner role must allow Intercom blockers');
expect(await toolCallHandler({ toolName: 'intercom', input: { action: 'reply', message: 'Proceed with the narrow fix', replyTo: 'message-1' } }, roleContext) === undefined, 'planner role must allow replies');
const plannerStart = await handlers.before_agent_start({ systemPrompt: 'base', systemPromptOptions: { skills: [] } }, roleContext);
expect(plannerStart.systemPrompt.includes('planner profile (read-only coordinator)') && plannerStart.systemPrompt.includes('safe repository discovery, classified read-only MCP calls') && plannerStart.systemPrompt.includes('worker is the sole worktree writer') && plannerStart.systemPrompt.includes('Never perform implementation edits') && plannerStart.systemPrompt.includes('even when it comes directly from the user') && plannerStart.systemPrompt.includes('never authorization for you to edit') && plannerStart.systemPrompt.includes('Do not emit patches or modifying commands') && plannerStart.systemPrompt.includes('Default to non-blocking Intercom') && plannerStart.systemPrompt.includes('Before every Intercom `send` or `reply`, call `pending` first') && plannerStart.systemPrompt.includes('if it reports an inbound ask, the response must use `reply` for that ask and must not call `send` or `list-cwd`') && plannerStart.systemPrompt.includes('if an inbound ask exists, use `reply`') && plannerStart.systemPrompt.includes('call `list-cwd` again to retrieve the exact session ID') && plannerStart.systemPrompt.includes('call `send` to that exact ID') && plannerStart.systemPrompt.includes('exact session identifier returned verbatim by the immediately preceding authoritative Intercom action') && plannerStart.systemPrompt.includes('display name, alias, or abbreviated prefix') && plannerStart.systemPrompt.includes('successful delivery') && plannerStart.systemPrompt.includes('delivery fails') && plannerStart.systemPrompt.includes('if an inbound ask exists, use `reply` and do not call `send` or `list-cwd`') && plannerStart.systemPrompt.includes('otherwise call a fresh `list-cwd`') && plannerStart.systemPrompt.includes('retry exactly once') && plannerStart.systemPrompt.includes('continue, commit, or close') && plannerStart.systemPrompt.includes('unavailable worker as the blocker') && plannerStart.systemPrompt.includes('explicit exception to avoiding repeated `list-cwd` polling') && plannerStart.systemPrompt.includes('After assigning a task, wait for the worker\'s result') && plannerStart.systemPrompt.includes('instead of polling again') && plannerStart.systemPrompt.includes('use `ask` only when intentionally waiting for a response') && plannerStart.systemPrompt.includes('Keep roster/status calls for selecting a worker') && plannerStart.systemPrompt.includes('Send findings and wait for a revised result') && plannerStart.systemPrompt.includes('Every task delegated to a worker must pass the actual `b-review` skill') && plannerStart.systemPrompt.includes('before you may mark it done, complete, approved, or closed') && plannerStart.systemPrompt.includes('A regular or generic review is insufficient') && plannerStart.systemPrompt.includes('this gate must never be bypassed under any circumstances') && plannerStart.systemPrompt.includes('resolve it when possible by calling Intercom `pending` first and then `reply` to the worker') && plannerStart.systemPrompt.includes('If it cannot be resolved from scope or repository evidence, escalate to the user with one focused question and keep the task open'), 'planner role must enforce delegated waiting, completion review, and unresolved-blocker escalation without blocking analysis');

let activePeerWorker = true;
roleChannelRegistration.onReady({
  publish(payload) { publishedRoles.push(payload); },
  listSessions: async () => [
    { id: 'self', cwd: root, pid: process.pid, startedAt: 1 },
    ...(activePeerWorker ? [{ id: 'active-worker', cwd: root, pid: 202, startedAt: 2 }] : []),
  ],
});
await roleChannelRegistration.onEvent({ type: 'connection', connected: true, supported: true });
await roleChannelRegistration.onEvent({ type: 'message', fromSessionId: 'active-worker', payload: { type: 'b-agentic-role', role: 'worker' } });
await roleChannelRegistration.onEvent({ type: 'message', fromSessionId: 'self', payload: { type: 'b-agentic-role', role: 'worker' } });
roleNotifications.length = 0;
await commands['b-role'].handler('worker', roleContext);
expect(!activeTools.includes('edit') && !activeTools.includes('write'), 'an explicit worker request must not create a second writer');
expect(roleNotifications.some(({ level }) => level === 'warning'), 'a real same-CWD peer worker must still block the worker claim');
activePeerWorker = false;
await roleChannelRegistration.onEvent({ type: 'session_left', sessionId: 'active-worker' });
roleNotifications.length = 0;
await commands['b-role'].handler('worker', roleContext);
expect(roleStatuses.at(-1)?.value === '<success>b-agentic: worker</success>', 'worker status must use the success color');
expect(roleNotifications.at(-1)?.level === 'info', 'a self worker announcement must not trigger a duplicate-worker warning');
expect(activeTools.includes('edit') && activeTools.includes('write') && activeTools.includes('bash') && activeTools.includes('b_agentic_confirm_commit'), 'worker role must restore normal tools');
await handlers.model_select({ model: { provider: 'anthropic', id: 'claude-sonnet-4-5' } }, roleContext);
activeThinkingLevel = 'minimal';
await handlers.thinking_level_select({ level: 'minimal', previousLevel: 'high' }, roleContext);
const updatedWorkerPreferences = JSON.parse(readFileSync(path.join(process.env.PI_CODING_AGENT_DIR, 'b-agentic', 'role-models.json'), 'utf8'));
expect(updatedWorkerPreferences.worker.model === 'claude-sonnet-4-5' && updatedWorkerPreferences.worker.thinkingLevel === 'minimal', 'thinking-level changes must update the worker preference without changing its model');
await commands['b-role'].handler('off', roleContext);
activeModel = { provider: 'other', id: 'other-model' };
activeThinkingLevel = 'off';
await commands['b-role'].handler('worker', roleContext);
expect(activeModel.provider === 'anthropic' && activeModel.id === 'claude-sonnet-4-5' && activeThinkingLevel === 'minimal', '/b-role worker must apply its saved model and thinking preference');
expect(await toolCallHandler({ toolName: 'edit', input: { path: 'README.md', edits: [] } }, roleContext) === undefined, 'worker role must not wait for a structured assignment');
for (const skill of ['b-implement', 'b-debug', 'b-refactor', 'b-test', 'b-browser', 'b-research', 'b-design', 'b-init']) {
  expect(await toolCallHandler({ toolName: 'read', input: { path: path.join(root, `skills/${skill}/SKILL.md`) } }, roleContext) === undefined, `worker role must allow task-appropriate skill ${skill}`);
}
for (const command of ['rtk git status --short', 'fdfind -t f SKILL.md skills', 'eza -la']) {
  expect(await toolCallHandler({ toolName: 'bash', input: { command } }, roleContext) === undefined, `worker role must preserve local discovery: ${command}`);
}
const workerStart = await handlers.before_agent_start({ systemPrompt: 'base', systemPromptOptions: { skills: [] } }, roleContext);
expect(workerStart.systemPrompt.includes('worker profile (implementation)') && workerStart.systemPrompt.includes('sole worktree writer') && workerStart.systemPrompt.includes('b-debug') && workerStart.systemPrompt.includes('b-refactor') && workerStart.systemPrompt.includes('assigning planner as the intended peer') && workerStart.systemPrompt.includes('Before every Intercom `send` or `reply`, call `pending` first') && workerStart.systemPrompt.includes('if it reports an inbound ask, the response must use `reply` for that ask and must not call `send` or `list-cwd`') && workerStart.systemPrompt.includes('if an inbound ask exists, use `reply`') && workerStart.systemPrompt.includes('call `list-cwd` again to retrieve the exact session ID') && workerStart.systemPrompt.includes('call `send` to that exact ID') && workerStart.systemPrompt.includes('exact session identifier returned verbatim by the immediately preceding authoritative Intercom action') && workerStart.systemPrompt.includes('display name, alias, or abbreviated prefix') && workerStart.systemPrompt.includes('successful delivery') && workerStart.systemPrompt.includes('delivery fails') && workerStart.systemPrompt.includes('if an inbound ask exists, use `reply` and do not call `send` or `list-cwd`') && workerStart.systemPrompt.includes('otherwise call a fresh `list-cwd`') && workerStart.systemPrompt.includes('retry exactly once') && workerStart.systemPrompt.includes('continue, commit, or close') && workerStart.systemPrompt.includes('unavailable planner as the blocker') && workerStart.systemPrompt.includes('explicit exception to avoiding repeated `list-cwd` polling') && workerStart.systemPrompt.includes('assigning planner\'s exact session ID') && workerStart.systemPrompt.includes('request must explicitly ask the planner to invoke the actual `b-review` skill') && workerStart.systemPrompt.includes('regular or generic review is insufficient') && workerStart.systemPrompt.includes('Pause all edits') && workerStart.systemPrompt.includes('Resume only when the planner sends actionable findings or a new task') && workerStart.systemPrompt.includes('use Intercom `ask` addressed to that exact identifier with one focused question and wait') && workerStart.systemPrompt.includes('do not ask the user directly') && workerStart.systemPrompt.includes('premature completion or review message while the planner waits') && workerStart.systemPrompt.includes('keep the task open pending the planner\'s response') && workerStart.systemPrompt.includes('Planner mode is enforced as read-only'), 'worker role must own implementation, flexible skill routing, and review pauses');
expect(await toolCallHandler({ toolName: 'intercom', input: { action: 'send', to: 'planner', message: 'Changed README.md; smoke passed; no known gaps.' } }, roleContext) === undefined, 'worker role must allow plain-language results');
expect(await toolCallHandler({ toolName: 'intercom', input: { action: 'ask', to: 'planner', message: 'Should I include the compatibility cleanup?' } }, roleContext) === undefined, 'worker role must allow clarification asks');
expect(await toolCallHandler({ toolName: 'intercom', input: { action: 'reply', message: 'Acknowledged', replyTo: 'message-2' } }, roleContext) === undefined, 'worker role must allow replies');
expect(persistedEntries.some((entry) => entry.data.role === 'planner') && persistedEntries.some((entry) => entry.data.role === 'worker'), 'role changes must persist');
await commands['b-role'].handler('off', roleContext);
expect(commands['b-auto-mode'], 'auto-mode extension must register /b-auto-mode');
expect(flagDefinitions['b-auto-mode']?.type === 'boolean', 'auto-mode must register a boolean startup flag');
const autoTest = extensionModules[2].__test__;
expect(autoTest.AUTO_MODE_ENTRY_TYPE === 'b-agentic-auto-mode', 'auto-mode state must use a dedicated persisted entry');
expect(autoTest.parseAutoMode(true) === true && autoTest.parseAutoMode('off') === false && autoTest.parseAutoMode('invalid') === undefined, 'auto-mode values must parse safely');
expect(autoTest.latestAutoModeState([{ type: 'custom', customType: 'b-agentic-auto-mode', data: { enabled: true } }]) === true, 'auto-mode state must restore from the session branch');
await commands['b-auto-mode'].handler('on', roleContext);
expect(roleStatuses.at(-1)?.key === 'b-auto-mode' && roleStatuses.at(-1)?.value === '<error>b-auto-mode</error>', 'enabled auto-mode must display red b-auto-mode status');
const refreshConfirmationsBeforeAutoSync = refreshConfirmations;
const refreshExecutionsBeforeAutoSync = executedCommands.length;
await commands['b-sync'].handler('', refreshContext);
expect(refreshConfirmations === refreshConfirmationsBeforeAutoSync, 'b-sync must skip its confirmation when auto-mode is enabled');
expect(executedCommands.length === refreshExecutionsBeforeAutoSync + 1, 'auto-mode b-sync must still execute the refresh');
expect(persistedEntries.at(-1)?.customType === 'b-agentic-auto-mode' && persistedEntries.at(-1)?.data.enabled === true, 'enabling auto-mode must persist its state');
expect(await toolCallHandler({ toolName: 'bash', input: { command: 'rm -rf /tmp/auto-mode-ask' } }, noUiContext) === undefined, 'auto-mode must auto-allow shell ask decisions without UI');
expect((await toolCallHandler({ toolName: 'bash', input: { command: 'git push --force origin main' } }, noUiContext))?.block === true, 'auto-mode must retain explicit shell deny decisions');
expect(await toolCallHandler({ toolName: 'write', input: { path: '/tmp/auto-mode-write' } }, noUiContext) === undefined, 'auto-mode must auto-allow native path ask decisions without UI');
expect((await toolCallHandler({ toolName: 'write', input: { path: '.env' } }, noUiContext))?.block === true, 'auto-mode must retain explicit native path deny decisions');
expect(await toolCallHandler({ toolName: 'custom-tool', input: { value: 'external' } }, noUiContext) === undefined, 'auto-mode must auto-allow custom-tool asks without UI');
let autoModeBrokerClaim;
mcpApprovalHandler({
  serverName: 'firecrawl', originalToolName: 'firecrawl_agent', prefixedToolName: 'firecrawl_firecrawl_agent', args: {}, origin: 'proxy',
  claim(handler) { autoModeBrokerClaim = handler; return true; },
});
expect(await autoModeBrokerClaim() === 'allow_once', 'auto-mode must auto-allow broker ask decisions without UI');
await commands['b-auto-mode'].handler('off', roleContext);
expect(roleStatuses.at(-1)?.value === undefined && persistedEntries.at(-1)?.data.enabled === false, 'disabling auto-mode must clear status and persist off');
expect((await toolCallHandler({ toolName: 'bash', input: { command: 'rm -rf /tmp/auto-mode-off' } }, noUiContext))?.block === true, 'off auto-mode must retain fail-closed no-UI shell asks');

expect(await toolCallHandler({ toolName: 'mcpScript', input: { code: 'return 1;' } }, noUiContext) === undefined, 'trusted mcpScript container must auto-allow without UI');
expect(await toolCallHandler({
  toolName: 'mcpScript',
  input: { code: "const found = await tools.search({ query: 'symbol' }); return tools.describe({ path: found.items[0].path });" },
}, noUiContext) === undefined, 'trusted mcpScript must permit read-only tools.search/tools.describe metadata discovery');
let nestedScriptMutationClaim;
mcpApprovalHandler({
  serverName: 'firecrawl', originalToolName: 'firecrawl_agent', prefixedToolName: 'firecrawl_firecrawl_agent', args: {}, origin: 'script',
  claim(handler) { nestedScriptMutationClaim = handler; return true; },
});
expect(await nestedScriptMutationClaim() === 'deny', 'unsafe nested mcpScript operations must retain normal approval policy');
expect(await toolCallHandler({ toolName: 'mcp', input: { server: 'firecrawl', tool: 'firecrawl_agent' } }, noUiContext) === undefined, 'top-level MCP mutations must reach the broker without generic blocking');
expect(await toolCallHandler({ toolName: 'mcp', input: { server: 'firecrawl', tool: 'firecrawl_search', args: { query: 'collision check', limit: 1 } } }, noUiContext) === undefined, 'valid top-level MCP proxy calls must not require generic UI approval');
for (const input of [
  { search: 'symbol' },
  { describe: 'tool' },
  { action: 'ui-messages' },
  { connect: 'serena' },
  { tool: 'firecrawl_developer_search', args: { query: 'collision check' } },
  { server: 'firecrawl', tool: 'firecrawl_search', extra: true },
  { connect: 'serena', tool: 'serena_read_memory' },
]) {
  expect((await toolCallHandler({ toolName: 'mcp', input }, noUiContext))?.block === true, 'non-execution MCP selectors must retain the generic approval gate');
}
expect((await toolCallHandler({ toolName: 'firecrawl_firecrawl_agent', input: {} }, noUiContext))?.block === true, 'direct managed-looking tools must retain the top-level approval gate');
expect(await toolCallHandler({ toolName: 'serena_onboarding', input: {} }, noUiContext) === undefined, 'direct Serena tools must auto-allow without UI');
let directSerenaClaim;
mcpApprovalHandler({
  serverName: 'serena',
  originalToolName: 'serena_onboarding',
  prefixedToolName: 'serena_serena_onboarding',
  args: {},
  origin: 'direct',
  claim(handler) { directSerenaClaim = handler; return true; },
});
expect(await directSerenaClaim() === 'allow_once', 'direct Serena broker requests must auto-allow');
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
let directSafeClaim;
mcpApprovalHandler({
  serverName: 'firecrawl',
  originalToolName: 'firecrawl_search',
  prefixedToolName: 'firecrawl_firecrawl_search',
  args: { query: 'Pi', limit: 10 },
  origin: 'direct',
  claim(handler) { directSafeClaim = handler; return true; },
});
expect(await directSafeClaim() === 'allow_once', 'direct safe managed adapter calls must auto-allow');
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
expect(await parallelProxyClaim() === 'deny', 'unsafe adapter-owned proxy calls must use the broker without UI');
let safeProxyClaim;
mcpApprovalHandler({
  serverName: 'firecrawl',
  originalToolName: 'firecrawl_search',
  prefixedToolName: 'firecrawl_firecrawl_search',
  args: { query: 'Pi', limit: 10 },
  origin: 'proxy',
  claim(handler) { safeProxyClaim = handler; return true; },
});
expect(await safeProxyClaim() === 'allow_once', 'safe managed proxy calls must auto-allow through the adapter broker');
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
expect(await approvedGatewayClaim() === 'allow_for_session', 'unsafe top-level MCP proxy calls must use the selected broker approval');
mcpApprovalHandler({
  serverName: 'firecrawl',
  originalToolName: 'firecrawl_agent',
  prefixedToolName: 'firecrawl_firecrawl_agent',
  args: {},
  origin: 'script',
  claim(handler) { sessionClaim = handler; return true; },
});
expect(await sessionClaim() === 'allow_for_session', 'MCP broker must support session-scoped approval');
expect(await toolCallHandler({ toolName: 'mcp', input: { server: 'user-server', tool: 'user_tool' } }, noUiContext) === undefined, 'unmanaged MCP gateway calls must reach the broker');
let userGatewayClaim;
mcpApprovalHandler({
  serverName: 'user-server',
  originalToolName: 'user_tool',
  prefixedToolName: 'user-server_user_tool',
  args: {},
  origin: 'proxy',
  claim(handler) { userGatewayClaim = handler; return true; },
});
expect(await userGatewayClaim() === 'deny', 'unmanaged MCP proxy calls must use the broker without UI');
expect(await toolCallHandler({ toolName: 'bash', input: { command: 'rtk git status --short' } }, noUiContext) === undefined, 'registered handler must allow safe RTK command');
expect(await toolCallHandler({ toolName: 'bash', input: { command: 'git commit -m x' } }, noUiContext) === undefined, 'registered handler must allow regular project-local Git commands');
expect((await toolCallHandler({ toolName: 'mcp', input: { connect: 'serena' } }, noUiContext))?.block === true, 'managed MCP connect calls must retain the generic approval gate');
expect((await toolCallHandler({ toolName: 'read', input: { path: '.env' } }, noUiContext))?.block === true, 'registered handler must fail closed for protected read');

// Compound commands and wrappers
expect(t.commandDecision('cd repo && git reset --hard').decision === 'deny', 'compound reset --hard must deny');
expect(t.commandDecision('git -C repo reset --hard').decision === 'deny', 'git -C reset --hard must deny');
expect(t.commandDecision('/usr/bin/git reset --hard').decision === 'deny', 'path-qualified git reset --hard must deny');
expect(t.commandDecision('/usr/bin/npm install lodash').decision === 'allow', 'path-qualified npm install must allow local dependency automation');
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
expect(t.commandDecision('env X=1 npm install lodash').decision === 'allow', 'env-wrapped npm install must allow local dependency automation');
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
  expect(t.commandDecision(`rtk ${wrapper} --skip-env npm install lodash`).decision === 'allow', `rtk ${wrapper} options must allow local dependency automation`);
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
  ['cargo remove serde', 'cargo remove'], ['pip uninstall requests', 'pip uninstall'],
  ['pip3 uninstall requests', 'pip3 uninstall'], ['poetry update', 'poetry update'],
  ['uv pip uninstall requests', 'uv pip uninstall'], ['uv pip sync requirements.txt', 'uv pip sync'],
]) expect(t.commandDecision(command).decision === 'allow', `${label} must allow repository-local dependency automation`);
expect(t.commandDecision('npm --unknown-option install lodash').decision === 'ask', 'unknown package options must remain opaque');
for (const command of ['rtk npm --prefix ./app install lodash', 'rtk pnpm --dir ./app add lodash', 'rtk cargo --manifest-path app/Cargo.toml update']) {
  expect(t.commandDecision(command).decision === 'allow', `${command} must allow repository-confined dependency automation via RTK`);
}
for (const command of ['npm --prefix /tmp install lodash', 'pnpm --dir /tmp add lodash', 'cargo --manifest-path /tmp/Cargo.toml update', 'pip install --prefix /tmp requests', 'pip install --target /tmp requests']) {
  expect(t.commandDecision(command).decision === 'ask', `${command} must ask for an outside-project dependency target`);
}
for (const command of ['pip install --prefix ./venv requests', 'pip install --target ./vendor requests']) {
  expect(t.commandDecision(command).decision === 'allow', `${command} must allow a repository-confined dependency target`);
}
for (const command of ['npm install -g lodash', 'npm install --location=global lodash', 'pnpm add --global lodash', 'yarn global add lodash', 'bun install --global lodash', 'pip install --user requests', 'pip install --break-system-packages requests']) {
  expect(t.commandDecision(command).decision === 'ask', `${command} must ask for a global dependency target`);
}
for (const command of ['cargo install ripgrep', 'go install example.com/tool@latest']) {
  expect(t.commandDecision(command).decision === 'ask', `${command} must ask for an external binary install`);
}
expect(t.commandDecision('git --config-env=alias.wipe=ALIAS wipe').decision === 'ask', 'inline Git alias invocation must ask');
for (const command of ['npm view lodash', 'pnpm list', 'cargo search serde']) {
  expect(t.commandDecision(command).decision === 'allow', `${command} is a regular command and must not require RTK`);
}
for (const command of ['rtk npm view lodash', 'rtk pnpm list', 'rtk cargo search serde', 'rtk pytest -q']) {
  expect(t.commandDecision(command).decision === 'allow', `${command} must preserve supported RTK use`);
}
for (const command of ['rtk npx eslint .', 'rtk npm test', 'rtk npm run build', 'rtk pnpm exec vite']) {
  expect(t.commandDecision(command).decision === 'allow', `${command} is routine project-local automation and must allow`);
}
for (const command of ['rtk npm run deploy', 'rtk pnpm run release', 'rtk yarn publish']) {
  expect(t.commandDecision(command).decision === 'ask', `${command} may mutate external state and must ask`);
}
const automationFixture = mkdtempSync(path.join(root, 'pi/tests/', '.b-agentic-automation-'));
try {
  const projectScript = path.join(automationFixture, 'build.js');
  writeFileSync(projectScript, 'console.log("build");');
  const relativeProjectScript = path.relative(process.cwd(), projectScript);
  for (const command of [`node ${relativeProjectScript}`, `bash ${relativeProjectScript}`]) {
    expect(t.commandDecision(command).decision === 'allow', `${command} is a project-local script and must allow`);
  }
} finally {
  rmSync(automationFixture, { recursive: true, force: true });
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
expect(t.SPECIALIZED_TOOLS.has('b_agentic_confirm_commit'), 'commit confirmation must bypass generic custom-tool approval');
expect(t.SPECIALIZED_TOOLS.has('mcpScript'), 'mcpScript must be a trusted container whose nested calls retain policy');
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
expect(t.commandDecision("rtk rg -n 'CONFIRM:' skills pi tests tooling --glob '!**/.git/**'").decision === 'allow', 'negated glob exclusions must not be treated as protected-path reads');
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
const nativeToolContext = { ...noUiContext, cwd: root };
await handlers.turn_start({ type: 'turn_start', turnIndex: 1, timestamp: 1 }, nativeToolContext);
expect(await toolCallHandler({ toolName: 'edit', input: { path: 'README.md', edits: [{ oldText: 'one', newText: 'two' }] } }, nativeToolContext) === undefined, 'first native edit for a path must remain allowed');
const duplicateEdit = await toolCallHandler({ toolName: 'edit', input: { path: './README.md', edits: [{ oldText: 'three', newText: 'four' }] } }, nativeToolContext);
expect(duplicateEdit?.block === true && duplicateEdit.reason.includes('merge disjoint replacements into one edits[] call') && duplicateEdit.reason.includes('reread and retry next turn'), 'same-turn duplicate native edit must be blocked with recovery guidance');
await handlers.turn_start({ type: 'turn_start', turnIndex: 2, timestamp: 2 }, nativeToolContext);
expect(await toolCallHandler({ toolName: 'edit', input: { path: 'README.md', edits: [{ oldText: 'five', newText: 'six' }] } }, nativeToolContext) === undefined, 'native edit must be permitted again on a later turn');
sentMessages.length = 0;
await handlers.tool_result({
  type: 'tool_result', toolCallId: 'edit-1', toolName: 'edit', input: { path: 'README.md' },
  content: [{ type: 'text', text: 'Could not find edits[0] in README.md. The oldText must match exactly including all whitespace and newlines.' }],
  isError: true,
}, nativeToolContext);
expect(sentMessages.length === 1 && sentMessages[0].options.deliverAs === 'steer' && sentMessages[0].message.display === false && sentMessages[0].message.details.path === 'README.md' && sentMessages[0].message.content.includes('Immediately read README.md') && sentMessages[0].message.content.includes('one exact retry'), 'exact-oldText failures must enqueue a path-specific recovery steer');
await handlers.tool_result({
  type: 'tool_result', toolCallId: 'edit-2', toolName: 'edit', input: { path: 'README.md' },
  content: [{ type: 'text', text: 'Could not find the exact text in README.md. The old text must match exactly including all whitespace and newlines.' }],
  isError: true,
}, nativeToolContext);
expect(sentMessages.length === 2 && sentMessages[1].message.details.path === 'README.md' && sentMessages[1].options.deliverAs === 'steer', 'single-edit exact-oldText failures must enqueue recovery for the runtime wording');
await handlers.tool_result({
  type: 'tool_result', toolCallId: 'edit-3', toolName: 'edit', input: { path: 'README.md' },
  content: [{ type: 'text', text: 'Could not edit README.md: permission denied.' }],
  isError: true,
}, nativeToolContext);
expect(sentMessages.length === 2, 'unrelated native edit errors must not enqueue recovery');
const installedSkillFixture = mkdtempSync(path.join(os.tmpdir(), 'b-agentic-installed-skills-'));
const installedSkillAliasParent = mkdtempSync(path.join(os.tmpdir(), 'b-agentic-installed-skills-alias-'));
const installedSkillAlias = path.join(installedSkillAliasParent, 'agent');
const externalSkillFixture = mkdtempSync(path.join(os.tmpdir(), 'b-agentic-external-skill-'));
const previousPiAgentDir = process.env.PI_CODING_AGENT_DIR;
try {
  const installedSkillPath = path.join(installedSkillFixture, 'skills', 'b-implement', 'SKILL.md');
  const installedOtherPath = path.join(installedSkillFixture, 'notes.md');
  const installedCustomSkillPath = path.join(installedSkillFixture, 'skills', 'b-custom', 'SKILL.md');
  const outsideSkillTarget = path.join(externalSkillFixture, 'outside-skill.md');
  mkdirSync(path.dirname(installedSkillPath), { recursive: true });
  mkdirSync(path.dirname(installedCustomSkillPath), { recursive: true });
  writeFileSync(installedSkillPath, 'Generated from skills/registry.yaml');
  writeFileSync(installedOtherPath, 'user data');
  writeFileSync(installedCustomSkillPath, 'user skill');
  writeFileSync(outsideSkillTarget, 'outside target');
  symlinkSync(installedSkillFixture, installedSkillAlias, 'dir');
  process.env.PI_CODING_AGENT_DIR = installedSkillAlias;
  expect(t.nativePathDecision('read', installedSkillPath).decision === 'allow', 'installed b-agentic skill reads through a root alias must auto-allow');
  expect(t.nativePathDecision('write', installedSkillPath).decision === 'ask', 'installed skill writes must remain approval-gated');
  expect(t.nativePathDecision('read', installedOtherPath).decision === 'ask', 'other Pi-agent files must remain approval-gated');
  expect(t.nativePathDecision('read', installedCustomSkillPath).decision === 'ask', 'unknown installed skills must remain approval-gated');
  const linkedSkillPath = path.join(installedSkillFixture, 'skills', 'b-debug', 'SKILL.md');
  mkdirSync(path.dirname(linkedSkillPath), { recursive: true });
  symlinkSync(outsideSkillTarget, linkedSkillPath);
  expect(t.nativePathDecision('read', linkedSkillPath).decision === 'ask', 'symlinked installed skill reads outside the agent root must remain gated');
} finally {
  if (previousPiAgentDir === undefined) delete process.env.PI_CODING_AGENT_DIR;
  else process.env.PI_CODING_AGENT_DIR = previousPiAgentDir;
  rmSync(installedSkillAliasParent, { recursive: true, force: true });
  rmSync(installedSkillFixture, { recursive: true, force: true });
  rmSync(externalSkillFixture, { recursive: true, force: true });
}
const trustedSerenaTools = [
  'serena_search_for_pattern', 'serena_get_symbols_overview', 'serena_find_symbol',
  'serena_find_referencing_symbols', 'serena_find_implementations', 'serena_find_declaration',
  'serena_get_diagnostics_for_file', 'serena_read_memory', 'serena_list_memories',
  'serena_initial_instructions', 'serena_replace_content', 'serena_replace_in_files',
  'serena_replace_symbol_body', 'serena_insert_after_symbol', 'serena_insert_before_symbol',
  'serena_rename_symbol', 'serena_safe_delete_symbol', 'serena_write_memory',
  'serena_delete_memory', 'serena_rename_memory', 'serena_edit_memory',
  'serena_open_dashboard', 'serena_onboarding',
];
const serenaSourcePath = path.join(root, 'pi/extensions/b-agentic-support/mcp.ts');
const serenaConditionalArgs = {
  serena_search_for_pattern: { substring_pattern: 'isSafeSerena', relative_path: serenaSourcePath, restrict_search_to_code_files: true },
  serena_get_symbols_overview: { relative_path: serenaSourcePath },
  serena_find_symbol: { name_path_pattern: 'isTrustedManagedTool', relative_path: serenaSourcePath },
  serena_find_referencing_symbols: { name_path: 'isTrustedManagedTool', relative_path: serenaSourcePath },
  serena_find_implementations: { name_path: 'isTrustedManagedTool', relative_path: serenaSourcePath },
  serena_find_declaration: { relative_path: serenaSourcePath, regex: 'isTrustedManagedTool' },
  serena_get_diagnostics_for_file: { relative_path: serenaSourcePath },
  serena_replace_content: { relative_path: serenaSourcePath, needle: 'old', repl: 'new', mode: 'literal' },
  serena_replace_in_files: { relative_path: serenaSourcePath, needle: 'old', repl: 'new', mode: 'literal', dry_run: true },
  serena_replace_symbol_body: { name_path: 'isTrustedManagedTool', relative_path: serenaSourcePath, body: 'body' },
  serena_insert_after_symbol: { name_path: 'isTrustedManagedTool', relative_path: serenaSourcePath, body: 'body' },
  serena_insert_before_symbol: { name_path: 'isTrustedManagedTool', relative_path: serenaSourcePath, body: 'body' },
  serena_rename_symbol: { name_path: 'isTrustedManagedTool', relative_path: serenaSourcePath, new_name: 'isTrustedManagedOperation' },
  serena_safe_delete_symbol: { name_path_pattern: 'isTrustedManagedTool', relative_path: serenaSourcePath },
  serena_read_memory: { memory_name: 'review-notes' },
  serena_list_memories: { topic: 'review' },
  serena_write_memory: { memory_name: 'review-notes', content: 'durable project fact' },
  serena_delete_memory: { memory_name: 'obsolete-review-notes' },
  serena_rename_memory: { old_name: 'review-notes', new_name: 'archive/review-notes' },
  serena_edit_memory: { memory_name: 'review-notes', needle: 'old', repl: 'new', mode: 'literal' },
};
const conditionalSerenaTools = new Set(Object.keys(serenaConditionalArgs));
const serenaArgsFor = (tool) => serenaConditionalArgs[tool] || {};
for (const tool of trustedSerenaTools) {
  expect(t.isTrustedManagedTool('serena', tool, serenaArgsFor(tool)) === true, `${tool} must auto-allow for its safe intended input`);
}
const codegraphTool = 'codegraph_codegraph_explore';
const codegraphArgs = { query: 'approval policy' };
expect(t.isTrustedManagedTool('codegraph', codegraphTool, codegraphArgs) === true, 'classified CodeGraph exploration must be trusted');
for (const tool of [codegraphTool]) {
  expect(t.isMcpOrCustomTool(tool, codegraphArgs) === false, `${tool} direct execution must auto-allow`);
  expect(t.isMcpOrCustomTool(`mcp__codegraph__${tool}`, codegraphArgs) === false, `${tool} prefixed execution must auto-allow`);
}
expect(t.isMcpOrCustomTool('mcp__serena__serena_replace_content', { relative_path: '/etc/hosts' }) === true, 'unsafe prefixed Serena edits retain the path gate');
expect(t.isMcpOrCustomTool('mcp__codegraph__serena_find_symbol', codegraphArgs) === true, 'mismatched CodeGraph namespace must remain gated');
expect(t.isMcpOrCustomTool('mcp__serena__codegraph_codegraph_explore', codegraphArgs) === true, 'mismatched Serena namespace must remain gated');
expect(t.isMcpOrCustomTool('mcp__user_server__codegraph_codegraph_explore', codegraphArgs) === true, 'unmanaged prefixed namespaces must remain gated');
const globalMemoryArgs = {
  serena_read_memory: { memory_name: 'global/review-notes' },
  serena_list_memories: { topic: 'global' },
  serena_write_memory: { memory_name: 'global/review-notes', content: 'shared fact' },
  serena_delete_memory: { memory_name: 'global/review-notes' },
  serena_rename_memory: { old_name: 'review-notes', new_name: 'global/review-notes' },
  serena_edit_memory: { memory_name: 'global/review-notes', needle: 'old', repl: 'new', mode: 'literal' },
};
for (const [tool, args] of Object.entries(globalMemoryArgs)) {
  expect(t.isTrustedManagedTool('serena', tool, args) === false, `${tool} must gate shared global memory access`);
  expect(t.isMcpOrCustomTool(tool, args) === true, `${tool} direct calls must retain the shared-memory gate`);
}
expect(t.isTrustedManagedTool('serena', 'serena_list_memories', {}) === false, 'unfiltered Serena memory listing must gate possible shared global memories');
expect(t.isTrustedManagedTool('serena', 'serena_write_memory', { memory_name: '../outside', content: 'x' }) === false, 'Serena memory traversal must remain gated');
const serenaRootSearch = {
  substring_pattern: 'isSafeSerena',
  relative_path: root,
  restrict_search_to_code_files: true,
};
expect(t.isTrustedManagedTool('serena', 'serena_search_for_pattern', serenaRootSearch) === true, 'repository-wide Serena code search must auto-allow');
expect(t.isTrustedManagedTool('serena', 'serena_search_for_pattern', {
  ...serenaRootSearch,
  paths_include_glob: '**/*.ts',
  paths_exclude_glob: '**/*.test.ts',
}) === true, 'repository-wide Serena code search must allow safe project globs');
expect(t.isTrustedManagedTool('serena', 'serena_search_for_pattern', {
  substring_pattern: 'isSafeSerena',
  restrict_search_to_code_files: true,
}) === true, 'project-root Serena code search without a relative path must auto-allow');
expect(t.isTrustedManagedTool('serena', 'serena_find_symbol', {
  name_path_pattern: 'isTrustedManagedTool', include_body: true,
}) === true, 'project-root Serena symbol reads must auto-allow when code descendants are safe');
expect(t.isTrustedManagedTool('serena', 'serena_search_for_pattern', {
  ...serenaRootSearch,
  relative_path: os.tmpdir(),
}) === false, 'outside-project Serena code search remains gated');
expect(t.isTrustedManagedTool('serena', 'serena_replace_content', { relative_path: '/etc/hosts' }) === false, 'outside-project Serena edits remain gated');
const serenaProtectedFixture = mkdtempSync(path.join(root, 'pi/tests/', '.b-agentic-serena-'));
try {
  const protectedSerenaPath = path.join(serenaProtectedFixture, '.env');
  const protectedSerenaLink = path.join(serenaProtectedFixture, 'safe-link');
  writeFileSync(path.join(serenaProtectedFixture, 'safe.ts'), 'export const safe = true;');
  const safeDirectoryReplace = {
    relative_path: serenaProtectedFixture,
    needle: 'safe',
    repl: 'safer',
    mode: 'literal',
    dry_run: true,
  };
  expect(t.isTrustedManagedTool('serena', 'serena_replace_in_files', safeDirectoryReplace) === true, 'safe directory-wide Serena replacements must auto-allow');
  expect(t.isMcpOrCustomTool('serena_replace_in_files', safeDirectoryReplace) === false, 'safe direct directory-wide Serena replacements must auto-allow');
  const protectedGitDirectory = path.join(serenaProtectedFixture, '.git');
  mkdirSync(protectedGitDirectory);
  writeFileSync(path.join(protectedGitDirectory, 'config'), 'old');
  expect(t.isTrustedManagedTool('serena', 'serena_replace_in_files', safeDirectoryReplace) === false, 'directory-wide Serena replacements must gate protected .git descendants');
  rmSync(protectedGitDirectory, { recursive: true, force: true });
  writeFileSync(protectedSerenaPath, 'secret');
  symlinkSync(protectedSerenaPath, protectedSerenaLink);
  expect(t.isTrustedManagedTool('serena', 'serena_search_for_pattern', {
    ...serenaRootSearch,
    relative_path: serenaProtectedFixture,
  }) === true, 'directory Serena code search must ignore non-code protected files');
  writeFileSync(path.join(serenaProtectedFixture, 'credentials.ts'), 'export const token = true;');
  expect(t.isTrustedManagedTool('serena', 'serena_search_for_pattern', {
    ...serenaRootSearch,
    relative_path: serenaProtectedFixture,
  }) === false, 'directory Serena code search must gate protected code descendants');
  expect(t.isTrustedManagedTool('serena', 'serena_find_symbol', {
    name_path_pattern: 'token', include_body: true,
  }) === false, 'unscoped Serena symbol reads must gate protected code descendants');
  expect(t.isTrustedManagedTool('serena', 'serena_find_symbol', {
    name_path_pattern: 'token', relative_path: serenaProtectedFixture, include_body: true,
  }) === false, 'directory Serena symbol reads must gate protected code descendants');
  expect(t.isTrustedManagedTool('serena', 'serena_find_referencing_symbols', {
    name_path: 'isTrustedManagedTool', relative_path: serenaSourcePath,
  }) === false, 'project-wide Serena reference reads must gate protected code descendants');
  expect(t.isTrustedManagedTool('serena', 'serena_find_implementations', {
    name_path: 'isTrustedManagedTool', relative_path: serenaSourcePath,
  }) === false, 'project-wide Serena implementation reads must gate protected code descendants');
  expect(t.isTrustedManagedTool('serena', 'serena_rename_symbol', {
    name_path: 'isTrustedManagedTool', relative_path: serenaSourcePath, new_name: 'isTrustedManagedOperation',
  }) === false, 'project-wide Serena renames must gate protected code descendants');
  expect(t.isMcpOrCustomTool('serena_rename_symbol', {
    name_path: 'isTrustedManagedTool', relative_path: serenaSourcePath, new_name: 'isTrustedManagedOperation',
  }) === true, 'unsafe direct Serena renames retain the protected-descendant gate');
  expect(t.isTrustedManagedTool('serena', 'serena_replace_in_files', safeDirectoryReplace) === false, 'directory-wide Serena replacements must gate protected descendants');
  expect(t.isMcpOrCustomTool('serena_replace_in_files', safeDirectoryReplace) === true, 'unsafe direct directory-wide Serena replacements retain the protected-descendant gate');
  expect(t.isTrustedManagedTool('serena', 'serena_replace_content', { relative_path: protectedSerenaPath }) === false, 'Serena edits of protected files remain gated');
  expect(t.isTrustedManagedTool('serena', 'serena_replace_content', { relative_path: protectedSerenaLink }) === false, 'Serena edits through protected symlinks remain gated');
} finally {
  rmSync(serenaProtectedFixture, { recursive: true, force: true });
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

// Explicitly targeted mcp proxy executions route to the adapter broker;
// metadata and lifecycle selectors remain behind generic approval.
expect(t.isMcpOrCustomTool('bash') === false, 'bash is specialized');
for (const input of [
  { search: 'symbol' },
  { describe: 'tool' },
  { action: 'ui-messages' },
  { connect: 'serena' },
  { server: 'firecrawl' },
  { tool: 'user_tool' },
  { tool: 'firecrawl_parse' },
  { server: 'firecrawl', tool: 'firecrawl_search', extra: true },
  { server: '', tool: 'firecrawl_search' },
  { server: 'firecrawl', tool: '' },
  { server: 'firecrawl', tool: 'firecrawl_search', args: 'not-json' },
  { connect: 'serena', tool: 'serena_read_memory' },
]) {
  expect(t.isMcpOrCustomTool('mcp', input) === true, 'non-execution mcp selectors must retain generic approval');
}
for (const input of [
  { server: 'serena', tool: 'new_serena_tool' },
  { server: 'user-server', tool: 'user_tool' },
  { server: 'firecrawl', tool: 'firecrawl_search', args: '{}' },
]) {
  expect(t.isMcpProxyToolExecution(input) === true, 'valid server/tool proxy executions must be recognized');
  expect(t.isMcpOrCustomTool('mcp', input) === false, 'valid proxy executions must bypass generic approval');
}
for (const tool of trustedSerenaTools) {
  const args = serenaArgsFor(tool);
  expect(t.isTrustedManagedGatewayCall({ server: 'serena', tool, args }) === true, `${tool} gateway execution must be classified safe`);
  expect(t.isMcpOrCustomTool(tool, args) === false, `${tool} direct execution must auto-allow`);
  expect(t.isMcpOrCustomTool(`mcp__serena__${tool}`, args) === false, `${tool} prefixed direct execution must auto-allow`);
}
expect(t.isMcpOrCustomTool('serena_search_for_pattern', serenaRootSearch) === false, 'repository-wide direct Serena code search must auto-allow');
expect(t.isMcpOrCustomTool('serena_replace_content', { relative_path: '/etc/hosts' }) === true, 'unsafe direct Serena edits retain the path gate');
expect(t.isTrustedManagedGatewayCall({ tool: 'serena_read_memory' }) === false, 'gateway execution without explicit server ownership must remain untrusted');
expect(t.isTrustedManagedGatewayCall({ server: 'firecrawl', tool: 'firecrawl_search', args: '{"query":"Pi","limit":1}' }) === true, 'validated conditional gateway execution must be classified safe');
for (const input of [
  { server: 'serena', tool: 'firecrawl_agent' },
  { server: 'serena', tool: 'mcp__firecrawl__serena_read_memory' },
  { connect: 'firecrawl', tool: 'firecrawl_agent' },
  { tool: 'playwright_browser_click' },
  { tool: 'playwright_browser_navigate', args: JSON.stringify({ url: 'https://example.com' }) },
  { tool: 'playwright_browser_take_screenshot', args: JSON.stringify({ filename: 'shot.png' }) },
]) {
  expect(t.isTrustedManagedGatewayCall(input) === false, 'unsafe or ambiguous gateway calls must remain untrusted');
}
expect(t.isMcpOrCustomTool('firecrawl_firecrawl_agent') === true, 'direct managed Firecrawl tools retain the top-level approval gate');
expect(t.isMcpOrCustomTool('firecrawl_developer_search') === true, 'direct trusted-looking Firecrawl names retain the top-level approval gate');
expect(t.isMcpOrCustomTool('browser_click') === true, 'direct managed Playwright tools retain the top-level approval gate');
expect(t.isMcpOrCustomTool('browser_snapshot') === true, 'direct trusted-looking Playwright names retain the top-level approval gate');
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
expect(t.isTrustedManagedTool('user-server', 'user_tool') === false, 'unmanaged server is not trusted');
expect(t.approvalLabel('\u001b[31mtool\u0007\u009b') === ' [31mtool  ', 'broker approval labels must strip terminal control characters');
expect(t.MANAGED_MCP_SERVERS.has('playwright'), 'managed MCP servers present');

console.log('pi permission behavioral fixtures ok');
NODE
}

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
	for extension in b-agentic-permissions.ts b-agentic-mcp-permissions.ts b-agentic-auto-mode.ts b-agentic-role.ts b-agentic-planner.ts b-agentic-worker.ts b-agentic-sync.ts; do
		assert_file "$sandbox/home/.pi/agent/extensions/$extension"
		assert_file "$sandbox/home/.pi/agent/b-agentic/extensions/$extension"
	done
	for support in shell.ts mcp.ts role.ts role-models.ts worker.ts state.ts auto.ts; do
		assert_file "$sandbox/home/.pi/agent/extensions/b-agentic-support/$support"
		assert_file "$sandbox/home/.pi/agent/b-agentic/extensions/b-agentic-support/$support"
	done
	assert_file "$sandbox/home/.pi/agent/b-agentic/install.json"
	assert_contains "$sandbox/home/.pi/agent/mcp.json" '"codegraph"'
	assert_contains "$sandbox/home/.pi/agent/mcp.json" '"lifecycle": "lazy"'
	assert_contains "$sandbox/home/.pi/agent/extensions/b-agentic-permissions.ts" 'tool_call'
	assert_contains "$sandbox/home/.pi/agent/b-agentic/install.json" '"mcpAdapterState": "ready"'
	assert_contains "$sandbox/home/.pi/agent/b-agentic/install.json" '"extensions"'
	assert_contains "$sandbox/home/.pi/agent/AGENTS.md" 'b-agentic-managed'
	assert_file "$sandbox/smoke-bin/pi-install.log"
	assert_contains "$sandbox/smoke-bin/pi-install.log" 'npm:pi-mcp-adapter'
	assert_contains "$sandbox/smoke-bin/pi-install.log" 'npm:pi-observational-memory'
	assert_contains "$sandbox/smoke-bin/pi-install.log" 'npm:@narumitw/pi-usage'
	assert_contains "$sandbox/smoke-bin/pi-install.log" 'npm:pi-intercom'

	# Split in-session modes: sync pulls/assets only; update uses installed source without Git.
	# Exercise sync with the default environment so package, Pi CLI, and MCP setup
	# cannot be hidden by opt-out flags.
	local sync_mcp_snapshot="$sandbox/sync-mcp.json"
	local sync_manifest_snapshot="$sandbox/sync-manifest.json"
	local sync_helper_snapshot="$sandbox/sync-helper.py"
	cp "$sandbox/home/.pi/agent/mcp.json" "$sync_mcp_snapshot"
	cp "$sandbox/home/.pi/agent/b-agentic/install.json" "$sync_manifest_snapshot"
	cp "$sandbox/home/.pi/agent/b-agentic/tooling/install/manifest_uninstall.py" "$sync_helper_snapshot"
	rm -rf "$sandbox/home/.pi/agent/skills/b-plan"
	printf '\n<!-- stale sync fixture -->\n' >>"$sandbox/home/.pi/agent/AGENTS.md"
	printf '\n// stale sync fixture\n' >>"$sandbox/home/.pi/agent/extensions/b-agentic-sync.ts"
	env \
		-u B_AGENTIC_PROMPT_API_KEYS \
		HOME="$sandbox/home" \
		PATH="$(smoke_runtime_cli_path "$sandbox")" \
		B_AGENTIC_REPO="$snapshot_repo" \
		B_AGENTIC_DIR="$sandbox/source" \
		bash "$ROOT_DIR/install.sh" --sync >/dev/null 2>&1
	assert_equal_files "$sandbox/home/.pi/agent/mcp.json" "$sync_mcp_snapshot"
	assert_equal_files "$sandbox/home/.pi/agent/b-agentic/install.json" "$sync_manifest_snapshot"
	assert_equal_files "$sandbox/home/.pi/agent/b-agentic/tooling/install/manifest_uninstall.py" "$sync_helper_snapshot"
	assert_equal_files "$sandbox/home/.pi/agent/skills/b-plan/SKILL.md" "$sandbox/source/skills/b-plan/SKILL.md"
	assert_equal_files "$sandbox/home/.pi/agent/AGENTS.md" "$sandbox/source/references/kernel.template.md"
	assert_equal_files "$sandbox/home/.pi/agent/extensions/b-agentic-sync.ts" "$sandbox/source/pi/extensions/b-agentic-sync.ts"
	# Mark an existing package only for the update-mode proof below.
	: >"$sandbox/smoke-bin/pi-adapter-installed"
	cat >"$sandbox/smoke-bin/curl" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
	chmod +x "$sandbox/smoke-bin/curl"
	mv "$sandbox/source/.git" "$sandbox/source/.git-without-pull"
	HOME="$sandbox/home" \
		PATH="$(smoke_runtime_cli_path "$sandbox")" \
		B_AGENTIC_REPO="$snapshot_repo" \
		B_AGENTIC_DIR="$sandbox/source" \
		B_AGENTIC_PROMPT_API_KEYS=N \
		bash "$ROOT_DIR/install.sh" --update >/dev/null 2>&1
	mv "$sandbox/source/.git-without-pull" "$sandbox/source/.git"
	assert_contains "$sandbox/smoke-bin/pi-install.log" 'update'
	assert_contains "$sandbox/smoke-bin/pi-install.log" 'update --extensions'

	local behavioral_pid
	run_pi_permission_behavioral_fixture "$sandbox" &
	behavioral_pid=$!

	(

	# Optional Pi packages via env opt-in (mock pi records installs).
	# expect_install_status hardcodes env; invoke installer directly for package opt-ins.
	local smoke_path
	smoke_path="$(smoke_runtime_cli_path "$sandbox_adapter")"
	HOME="$sandbox_adapter/home" \
		PATH="$smoke_path" \
		B_AGENTIC_REPO="$snapshot_repo" \
		B_AGENTIC_DIR="$sandbox_adapter/source" \
		B_AGENTIC_PROMPT_API_KEYS=N \
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
	expect_install_status 1 "$sandbox_preserve" "$snapshot_repo"
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

	# Uninstall restores pre-existing entrypoint and support files after reinstall and managed-file deletion.
	mkdir -p "$sandbox_extension_restore/home/.pi/agent/extensions/b-agentic-support"
	printf 'user-owned permission extension\n' >"$sandbox_extension_restore/home/.pi/agent/extensions/b-agentic-permissions.ts"
	printf 'user-owned worker extension\n' >"$sandbox_extension_restore/home/.pi/agent/extensions/b-agentic-worker.ts"
	printf 'user-owned shell support\n' >"$sandbox_extension_restore/home/.pi/agent/extensions/b-agentic-support/shell.ts"
	expect_install_status 0 "$sandbox_extension_restore" "$snapshot_repo"
	assert_not_contains "$sandbox_extension_restore/home/.pi/agent/extensions/b-agentic-permissions.ts" 'user-owned permission extension'
	expect_install_status 0 "$sandbox_extension_restore" "$snapshot_repo"
	rm "$sandbox_extension_restore/home/.pi/agent/extensions/b-agentic-permissions.ts"
	rm "$sandbox_extension_restore/home/.pi/agent/extensions/b-agentic-worker.ts"
	rm "$sandbox_extension_restore/home/.pi/agent/extensions/b-agentic-support/shell.ts"
	expect_install_status 0 "$sandbox_extension_restore" "$snapshot_repo"
	expect_install_status 0 "$sandbox_extension_restore" "$snapshot_repo" --uninstall
	assert_contains "$sandbox_extension_restore/home/.pi/agent/extensions/b-agentic-permissions.ts" 'user-owned permission extension'
	assert_contains "$sandbox_extension_restore/home/.pi/agent/extensions/b-agentic-worker.ts" 'user-owned worker extension'
	assert_contains "$sandbox_extension_restore/home/.pi/agent/extensions/b-agentic-support/shell.ts" 'user-owned shell support'

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

	) &
	local base_pid=$!

	local base_status
	if wait "$base_pid"; then
		:
	else
		base_status=$?
		wait "$behavioral_pid" 2>/dev/null || true
		return "$base_status"
	fi

	if wait "$behavioral_pid"; then
		:
	else
		local behavioral_status=$?
		return "$behavioral_status"
	fi

	# Source-backed uninstall removes managed content only.
	expect_install_status 0 "$sandbox" "$snapshot_repo" --uninstall
	assert_no_path "$sandbox/home/.pi/agent/skills/b-plan"
	assert_no_path "$sandbox/home/.pi/agent/b-agentic/install.json"
	assert_no_path "$sandbox/home/.pi/agent/extensions/b-agentic-permissions.ts"
	# User MCP entries would be preserved by merge cleanup; managed-only install removes mcp.json entirely.
}
