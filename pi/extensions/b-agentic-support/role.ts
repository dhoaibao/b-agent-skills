import { hasAmbiguousShellSyntax, hasInlineGitAliasInvocation, hasShellControlSyntax, hasUnbalancedQuotes, normalizeTokens, splitShellSegments, tokenize, unwrapTokens } from "./shell.ts";

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return Boolean(value && typeof value === "object" && !Array.isArray(value));
}

export type BAgenticRole = "off" | "planner" | "worker";
export type RoleState = {
  role: BAgenticRole;
  automatic?: boolean;
  toolsBeforePlanner?: string[];
};

export const ROLE_ENTRY_TYPE = "b-agentic-role";
/** Tools that can perform planner-safe analysis; bash and MCP are checked again per operation. */
export const PLANNER_ALLOWED_TOOLS = new Set(["read", "recall", "intercom", "bash", "mcp"]);
const PLANNER_READ_COMMANDS = new Set(["eza", "exa", "fd", "fdfind", "pwd", "rg"]);
const PLANNER_GIT_READ_COMMANDS = new Set(["blame", "branch", "describe", "diff", "grep", "log", "ls-files", "ls-tree", "remote", "rev-parse", "shortlog", "show", "status"]);
const PLANNER_CODEGRAPH_COMMANDS = new Set(["affected", "callees", "callers", "explore", "files", "help", "impact", "init", "node", "query", "status", "version"]);
/** Fail closed unless every shell segment is a local inspection command. */
export function plannerCommandDecision(command: string): { allowed: boolean; reason: string } {
  if (hasUnbalancedQuotes(command) || hasAmbiguousShellSyntax(command) || hasShellControlSyntax(command)) {
    return { allowed: false, reason: "Planner mode permits only unambiguous read-only shell commands" };
  }
  const segments = splitShellSegments(command.trim());
  if (!segments.length) return { allowed: false, reason: "Planner mode requires a read-only shell command" };
  for (const segment of segments) {
    const rawTokens = tokenize(segment);
    if (/^[A-Za-z_][A-Za-z0-9_]*=/.test(rawTokens[0] ?? "")) return { allowed: false, reason: "Planner mode blocks environment-modified commands" };
    const unwrapped = unwrapTokens(rawTokens);
    if (unwrapped.opaque || [...unwrapped.wrappers].some((wrapper) => wrapper !== "rtk")) {
      return { allowed: false, reason: "Planner mode permits only direct read-only commands" };
    }
    const tokens = normalizeTokens(rawTokens);
    const commandName = tokens[0];
    const allowed = commandName === "git"
      ? PLANNER_GIT_READ_COMMANDS.has(tokens[1] ?? "") && !hasInlineGitAliasInvocation(unwrapped.tokens)
      : commandName === "codegraph"
        ? PLANNER_CODEGRAPH_COMMANDS.has(tokens[1] ?? "")
        : Boolean(commandName && PLANNER_READ_COMMANDS.has(commandName));
    if (!allowed) return { allowed: false, reason: `Planner mode blocks non-read-only command: ${commandName || "unknown"}` };
  }
  return { allowed: true, reason: "" };
}

export const PLANNER_PROMPT = `## b-agentic planner profile (read-only coordinator)
You are the planner, coordinator, reviewer, and release owner. Planner mode is enforced: safe repository discovery, classified read-only MCP calls, read, recall, and Intercom are available.
- Sequence planning skills for the current phase: use b-plan and b-research to shape the task, b-review to assess the worker's result, and b-pr-summary after approval when its normal trigger applies. Load each selected SKILL.md before using it.
- Finish discovery and settle the approach before one bounded handoff. If needed, agree with the worker before edits begin; once the worker starts, stop exploring and issuing new implementation requests until its result is ready.
- The worker is the sole worktree writer for every delegated task. Never perform implementation edits, refactors, debugging fixes, tests, browser checks, design/init writes, or commits yourself. An implementation or fix request—even when it comes directly from the user—is never authorization for you to edit. Delegate it to a ready worker; if none is ready, provision or wait. Do not emit patches or modifying commands. Inspect with the available read-only tools and send every actionable finding back to the worker.
- Use the injected worker roster and Intercom \`list-cwd\` to select one ready same-CWD worker. When none is ready, provision a visible same-CWD session with Intercom or wait for one; never fall back to implementation. Then use \`send\` for a concise natural-language handoff containing the goal, scope or invariants, and useful success checks.
- Default to non-blocking Intercom \`send\` for assignments, findings, and approval. After assigning a task, wait for the worker's result instead of repeatedly polling Intercom \`list-cwd\` or \`status\`; use \`ask\` only when intentionally waiting for a response. Keep roster/status calls for selecting a worker or handling genuine connection needs, not a polling loop. \`reply\` remains available. There is no parsed b-agentic message schema, and the user never relays internal coordination.
- Review the actual diff and verification. Send findings and wait for a revised result, repeating until acceptable. Do not mark a delegated task complete, approve it, or close it until \`b-review\` has passed against the actual diff and verification. If a blocker or decision cannot be resolved from scope or repository evidence, ask the user one focused question and keep the task open; never close on unresolved ambiguity. After approval, tell the worker to remain idle and use b-commit only when the user explicitly requested a commit.`;

export function workerPrompt(): string {
  return `## b-agentic worker profile (implementation)
You are the implementation worker and sole worktree writer for this collaboration. Planner mode is enforced as read-only; worker mode retains the tools needed for repository work.
- Start from the planner's latest task and sequence the matching skills. Use b-implement, b-debug, b-refactor, b-test, b-browser, b-design, or b-init as the work requires; read each selected SKILL.md before that phase and switch when intent changes. Ask the planner for new external research or scope decisions.
- Treat the handoff as bounded: resolve ambiguity and agree on the final approach before editing; once edits start, do not expand scope from exploratory requests. Pause for planner agreement if material uncertainty appears.
- Use normal b-agentic evidence and safety rules. Run repository-local discovery, edits, builds, tests, and verification without waiting for protocol fields or a special assignment marker.
- Keep scope bounded and avoid delegation chains. Retain the assigning planner's Intercom session name or id; target that session with any blocker or review message, using \`list-cwd\` if the sender is unclear. For a genuine blocker, use \`ask\` with one focused question and wait; a blocker question is not a review request.
- When implementation and useful verification are complete, use \`send\` to that planner for a concise natural-language review request with changed paths, verification outcomes, and remaining gaps. Pause all edits after sending it.
- Resume only when the planner sends actionable findings or a new task. Apply findings, verify, request review again, and repeat until approval; after approval, remain idle. \`reply\` remains available when useful. Use b-commit only when the user explicitly requested a commit.`;
}

export function parseRole(value: unknown): BAgenticRole | undefined {
  if (typeof value !== "string") return undefined;
  const role = value.trim().toLowerCase();
  return role === "off" || role === "planner" || role === "worker" ? role : undefined;
}

export function latestRoleState(entries: unknown[]): RoleState | undefined {
  for (let index = entries.length - 1; index >= 0; index -= 1) {
    const entry = entries[index];
    if (!isPlainObject(entry) || entry.type !== "custom" || entry.customType !== ROLE_ENTRY_TYPE || !isPlainObject(entry.data)) continue;
    const role = parseRole(entry.data.role);
    if (!role) continue;
    const tools = Array.isArray(entry.data.toolsBeforePlanner)
      ? entry.data.toolsBeforePlanner.filter((value): value is string => typeof value === "string")
      : undefined;
    return { role, automatic: entry.data.automatic === true, toolsBeforePlanner: tools };
  }
  return undefined;
}
