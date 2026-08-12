import { hasGitMutationRisk, hasInlineGitAliasInvocation, hasShellControlSyntax, hasUnbalancedQuotes, hasUnquotedGlob, hasUnsafeShellSyntax, isProtectedPath, isProjectConfinedLocalPath, normalizeTokens, PROTECTED_PATH_MARKERS, splitShellSegments, tokenize, unwrapTokens } from "./shell.ts";

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
const PLANNER_GIT_READ_COMMANDS = new Set(["blame", "branch", "cat-file", "count-objects", "describe", "diff", "diff-tree", "for-each-ref", "fsck", "grep", "log", "ls-files", "ls-tree", "merge-base", "name-rev", "reflog", "remote", "rev-list", "rev-parse", "shortlog", "show", "show-ref", "status", "tag", "verify-commit"]);
const PLANNER_CODEGRAPH_COMMANDS = new Set(["affected", "callees", "callers", "explore", "files", "help", "impact", "init", "node", "query", "status", "version"]);

const SOURCE_FILE_EXTENSION = /(?:[cm]?[jt]sx?|py|rb|go|rs|java|kt|kts|c(?:c|pp|xx)?|h(?:pp)?|cs|php|swift|scala|vue|svelte|astro)$/i;

function isCompoundSourceGlob(base: string): boolean {
  const suffix = base.match(/^(?:credentials|secrets)\.(.+)$/i)?.[1];
  if (!suffix) return false;
  // Preserve shell.ts's compound-source exception for patterns such as
  // credentials.service* and credentials.*.ts without inventing a literal
  // path that may not exist.
  return /^[A-Za-z0-9_-]+(?:[?*\[]|$)/.test(suffix) ||
    (suffix.includes("*") && SOURCE_FILE_EXTENSION.test(suffix.replace(/[?*\[\]]/g, "")));
}

function hasPlannerProtectedGlob(tokens: string[]): boolean {
  return tokens.some((token) => {
    if (!hasUnquotedGlob(token)) return false;
    if (/[?\[\]{}]/.test(token)) return true;
    const normalized = token.replace(/\\/g, "/");
    const segments = normalized.split("/");
    const base = segments.at(-1) ?? normalized;
    const staticPrefix = normalized.split(/[*?\[\]{}]/, 1)[0] || ".";
    const protectedDirectory = /(?:^|\/)(?:\.env|\.config\/gh|\.aws|\.kube|\.ssh|\.git)(?:\/|$)/i.test(normalized);
    const confinedPrefix = !staticPrefix.startsWith("..") && !staticPrefix.startsWith("/") && (isProjectConfinedLocalPath(staticPrefix) ||
      (isCompoundSourceGlob(base) && isProjectConfinedLocalPath(".")));
    if (!confinedPrefix || protectedDirectory) return true;
    if (isCompoundSourceGlob(base)) return false;
    if (/^(?:credentials|secrets)\*/i.test(base) || /(?:^|\/)(?:credentials|secrets)\/(?:\*|$)/i.test(normalized)) return true;
    const globPattern = new RegExp(`^${normalized
      .replace(/[.+^$()|\\\\*]/g, "\\\\$&")
      .replace(/\\\\\*/g, ".*")}$`, "i");
    const candidates = new Set<string>();
    for (const marker of PROTECTED_PATH_MARKERS) {
      const clean = marker.endsWith("/") ? marker.slice(0, -1) : marker;
      candidates.add(clean);
      candidates.add(`${clean}secret`);
      candidates.add(`x${clean}`);
      candidates.add(`foo/${clean}`);
      candidates.add(`foo/${clean}/secret`);
    }
    return [...candidates].some((candidate) => globPattern.test(candidate) && isProtectedPath(candidate));
  });
}

function hasPlannerGitGlobalOption(tokens: string[]): boolean {
  if (tokens[0] !== "git") return false;
  const globalOptions = new Set(["-c", "-C", "--config-env", "--git-dir", "--work-tree", "--namespace"]);
  for (let index = 1; index < tokens.length; index += 1) {
    const token = tokens[index];
    if (token === "--") break;
    if (!token.startsWith("-")) return false;
    const base = token.split("=", 1)[0];
    if (globalOptions.has(token) ||
      token.startsWith("-c") || token.startsWith("-C") ||
      [...globalOptions].some((option) => option.startsWith("--") && base.length >= 5 && option.startsWith(base))) return true;
  }
  return false;
}

function hasPlannerUnsafeGitOption(tokens: string[]): boolean {
  const separator = tokens.indexOf("--");
  const optionTokens = tokens.slice(0, separator < 0 ? tokens.length : separator);
  return optionTokens.some((token) =>
    token === "-o" || token.startsWith("-o") ||
      ["--ext-diff", "--textconv", "--output", "--no-index"].some((option) =>
        option.startsWith(token.split("=", 1)[0]) || token.startsWith(`${option}=`))
  );
}

function hasGitContentOutputRisk(tokens: string[]): boolean {
  const separator = tokens.indexOf("--");
  const options = tokens.slice(2, separator < 0 ? tokens.length : separator);
  return options.some((token) => token === "-p" || token === "-u" || token === "-c" || token === "--cc" ||
    ["--patch", "--patch-with-raw", "--patch-with-stat", "--binary", "--word-diff", "--color-words", "--textconv", "--ext-diff"].some((option) =>
      option.startsWith(token) || token.startsWith(option)));
}

function isPlannerGitReadOnly(tokens: string[], rawTokens: string[]): boolean {
  const gitTokens = tokens[0] === "rtk" ? tokens.slice(1) : tokens;
  const operation = gitTokens[1];
  const gitRawTokens = rawTokens[0] === "rtk" ? rawTokens.slice(1) : rawTokens;
  if (!operation || hasPlannerGitGlobalOption(gitRawTokens) || hasPlannerUnsafeGitOption(gitRawTokens)) return false;
  if (operation === "reflog" && !["", "show", "list"].includes(gitTokens[2] || "")) return false;
  if (operation === "diff-tree" && hasGitContentOutputRisk(gitTokens)) return false;
  if (operation === "remote") {
    const remoteArgs = gitTokens.slice(2);
    return remoteArgs.length === 0 || remoteArgs.length === 1 && remoteArgs[0] === "-v" ||
      remoteArgs[0] === "get-url" ||
      (remoteArgs.includes("show") && remoteArgs.includes("-n") && remoteArgs.filter((token) => token !== "-n").length === 2);
  }
  if (hasGitMutationRisk(gitTokens)) return false;
  return true;
}

/** Fail closed unless every shell segment is a direct local inspection command. */
export function plannerCommandDecision(command: string): { allowed: boolean; reason: string } {
  if (hasUnbalancedQuotes(command) || hasUnsafeShellSyntax(command) || hasShellControlSyntax(command)) {
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
      ? PLANNER_GIT_READ_COMMANDS.has(tokens[1] ?? "") && !hasInlineGitAliasInvocation(unwrapped.tokens) && isPlannerGitReadOnly(tokens, unwrapped.tokens)
      : commandName === "codegraph"
        ? PLANNER_CODEGRAPH_COMMANDS.has(tokens[1] ?? "")
        : Boolean(commandName && PLANNER_READ_COMMANDS.has(commandName));
    if (hasPlannerProtectedGlob(rawTokens)) {
      return { allowed: false, reason: "Planner mode blocks protected-path globs" };
    }
    if (hasUnquotedGlob(segment) && !allowed) {
      return { allowed: false, reason: "Planner mode permits unquoted globs only for direct read-only commands" };
    }
    if (!allowed) return { allowed: false, reason: `Planner mode blocks non-read-only command: ${commandName || "unknown"}` };
  }
  return { allowed: true, reason: "" };
}

export const PLANNER_PROMPT = `## b-agentic planner profile (read-only coordinator)
You are the planner, coordinator, reviewer, and release owner. Planner mode is enforced: safe repository discovery, classified read-only MCP calls, read, recall, and Intercom are available.
- Sequence planning skills for the current phase: use b-plan and b-research to shape the task, b-agentic-audit for repository/design-conformance audits, b-review to assess the worker's result, and b-pr-summary after approval when its normal trigger applies. Load each selected SKILL.md before using it.
- Finish discovery and settle the approach before one bounded handoff. If needed, agree with the worker before edits begin; once the worker starts, stop exploring and issuing new implementation requests until its result is ready.
- The worker is the sole worktree writer for every delegated task. Never perform implementation edits, refactors, debugging fixes, tests, browser checks, design/init writes, or commits yourself. An implementation or fix request—even when it comes directly from the user—is never authorization for you to edit. Delegate it to a ready worker; if none is ready, provision or wait. Do not emit patches or modifying commands. Inspect with the available read-only tools and send every actionable finding back to the worker.
- Use the injected worker roster and Intercom \`list-cwd\` to select one ready same-CWD worker. When none is ready, provision a visible same-CWD session with Intercom or wait for one; never fall back to implementation. Before the handoff, call \`pending\` first; if it reports an inbound ask, the response must use \`reply\` for that ask and must not call \`send\` or \`list-cwd\`; only when it reports no inbound ask may you call \`list-cwd\` again to retrieve the exact worker session ID, then call \`send\` to that exact ID for a concise natural-language handoff containing the goal, scope or invariants, and useful success checks.
- Immediately after delegating an editing task to the worker, stop by ending the current turn or using Intercom \`ask\` to wait for the worker's result. Never use \`sleep\`, polling, or timeout-based waiting. Do not review or take any further implementation-related action until the worker has finished and explicitly reported back.
- Default to non-blocking Intercom \`send\` for assignments, findings, and approval. Before every Intercom \`send\` or \`reply\`, call \`pending\` first; if it reports an inbound ask, the response must use \`reply\` for that ask and must not call \`send\` or \`list-cwd\`; only when it reports no inbound ask may you call \`list-cwd\` again to retrieve the exact session ID, then call \`send\` to that exact ID. This \`list-cwd\` call is the explicit exception to avoiding repeated \`list-cwd\` polling. After assigning a task, wait for the worker's result instead of polling again; use \`ask\` only when intentionally waiting for a response. Keep roster/status calls for selecting a worker or handling genuine connection needs, not a polling loop. \`reply\` remains available. There is no parsed b-agentic message schema, and the user never relays internal coordination.
- Use only the exact session identifier returned verbatim by the immediately preceding authoritative Intercom action, such as list-cwd, for to; never reconstruct, extend, guess, fabricate, or substitute a longer ID. Never use a display name, alias, or abbreviated prefix. Treat a handoff, finding, or approval as sent only after Intercom reports successful delivery. If \`send\` delivery fails, do not retry the stale target or continue, commit, or close: call \`pending\` first; if an inbound ask exists, use \`reply\` and do not call \`send\` or \`list-cwd\`; otherwise call a fresh \`list-cwd\`; retry exactly once only if the intended worker is still live, otherwise pause and surface the unavailable worker as the blocker.
- Copy every send target verbatim from the authoritative Intercom output (such as list-cwd); use the exact session identifier returned verbatim by the immediately preceding authoritative Intercom action, never reconstruct, extend, guess, fabricate, or substitute a longer ID. Review the actual diff and verification. Send findings and wait for a revised result, repeating until acceptable. Every task delegated to a worker must pass the actual \`b-review\` skill against the actual diff and verification before you may mark it done, complete, approved, or closed. A regular or generic review is insufficient, and this gate must never be bypassed under any circumstances. If a blocker or decision cannot be resolved from scope or repository evidence, keep the task open; when a worker asks about an unresolved blocker, resolve it when possible by calling Intercom \`pending\` first and then \`reply\` to the worker. If it cannot be resolved from scope or repository evidence, escalate to the user with one focused question and keep the task open; never close on unresolved ambiguity. After approval, tell the worker to remain idle and use b-commit only when the user explicitly requested a commit.`;

export function workerPrompt(): string {
  return `## b-agentic worker profile (implementation)
You are the implementation worker and sole worktree writer for this collaboration. Planner mode is enforced as read-only; worker mode retains the tools needed for repository work.
- Start from the planner's latest task and sequence the matching skills. Use b-implement, b-debug, b-refactor, b-test, b-browser, b-design, or b-init as the work requires; read each selected SKILL.md before that phase and switch when intent changes. Ask the planner for new external research or scope decisions.
- Treat the handoff as bounded: resolve ambiguity and agree on the final approach before editing; once edits start, do not expand scope from exploratory requests. Pause for planner agreement if material uncertainty appears.
- Use normal b-agentic evidence and safety rules. Run repository-local discovery, edits, builds, tests, and verification without waiting for protocol fields or a special assignment marker.
- Before every Intercom \`send\` or \`reply\`, call \`pending\` first; if it reports an inbound ask, the response must use \`reply\` for that ask and must not call \`send\` or \`list-cwd\`; only when it reports no inbound ask may you call \`list-cwd\` again to retrieve the exact session ID, then call \`send\` to that exact ID. This \`list-cwd\` call is the explicit exception to avoiding repeated \`list-cwd\` polling.
- Use only the exact session identifier returned verbatim by the immediately preceding authoritative Intercom action, such as list-cwd, for to; never reconstruct, extend, guess, fabricate, or substitute a longer ID. Never use a display name, alias, or abbreviated prefix. Treat a handoff, result, or review request as sent only after Intercom reports successful delivery. If \`send\` delivery fails, do not retry the stale target or continue, commit, or close: call \`pending\` first; if an inbound ask exists, use \`reply\` and do not call \`send\` or \`list-cwd\`; otherwise call a fresh \`list-cwd\`; retry exactly once only if the assigning planner is still live, otherwise pause and surface the unavailable planner as the blocker.
- Copy every send target verbatim from the authoritative Intercom output (such as list-cwd); use the exact session identifier returned verbatim by the immediately preceding authoritative Intercom action, never reconstruct, extend, guess, fabricate, or substitute a longer ID. Keep scope bounded and avoid delegation chains. Retain the assigning planner as the intended peer; after \`pending\` reports nothing to reply to, use \`list-cwd\` again to retrieve that planner's exact session identifier before sending any blocker or review message. If an unresolved issue or blocker remains, do not ask the user directly. After \`pending\` reports no inbound ask, use \`list-cwd\` again to retrieve the assigning planner's exact session identifier, then use Intercom \`ask\` addressed to that exact identifier with one focused question and wait. If \`pending\` reports an inbound ask, use \`reply\` for it and do not call \`send\` or \`list-cwd\`. Do not stop midway or send a premature completion or review message while the planner waits; keep the task open pending the planner's response. A blocker question is not a review request.
- When implementation and useful verification are complete, call Intercom \`pending\` first; if it reports an inbound ask, the response must use \`reply\` for that ask and must not call \`send\` or \`list-cwd\`; only when it reports no inbound ask may you call \`list-cwd\` again to retrieve the assigning planner's exact session ID, then call \`send\` to that exact ID with a concise natural-language review request containing changed paths, verification outcomes, and remaining gaps. The request must explicitly ask the planner to invoke the actual \`b-review\` skill; a regular or generic review is insufficient and never substitutes for it. Pause all edits after sending it.
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
