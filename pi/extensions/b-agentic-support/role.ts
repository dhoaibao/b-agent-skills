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

// generated:skill-ownership:start
/** Generated from skills/registry.yaml. Unknown skills fail closed to worker ownership. */
export type SkillOwner = "planner" | "worker";
export const SKILL_OWNERSHIP_CRITERION = "Planner-owned only when execution is read-only decision/planning, external research, audit/review, or release-summary coordination inside the planner boundary. Worker-owned when execution implements or mutates, diagnoses runtime behavior, builds/tests, performs browser/operational verification, commits, or otherwise requires worker capabilities. Mixed or uncertain skills are worker-owned.";
export const SKILL_OWNERS: Readonly<Record<string, SkillOwner>> = {
  "b-plan": "planner",
  "b-research": "planner",
  "b-design": "worker",
  "b-implement": "worker",
  "b-init": "worker",
  "b-refactor": "worker",
  "b-debug": "worker",
  "b-test": "worker",
  "b-browser": "worker",
  "b-agentic-audit": "planner",
  "b-review": "planner",
  "b-commit": "worker",
  "b-pr-summary": "planner"
};
export function skillOwner(skill: string): SkillOwner {
  return SKILL_OWNERS[skill] ?? "worker";
}
const PLANNER_OWNED_SKILLS = Object.entries(SKILL_OWNERS).filter(([, owner]) => owner === "planner").map(([skill]) => "`" + skill + "`");
const WORKER_OWNED_SKILLS = Object.entries(SKILL_OWNERS).filter(([, owner]) => owner === "worker").map(([skill]) => "`" + skill + "`");
// generated:skill-ownership:end

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
You coordinate, review, and release; planner mode permits analysis only.
- Skill execution ownership is generated from the registry. Planner-owned: ${PLANNER_OWNED_SKILLS.join(", ")}; worker-owned: ${WORKER_OWNED_SKILLS.join(", ")}. This includes external b-research. ${SKILL_OWNERSHIP_CRITERION} Execute planner-owned skills only inside the read-only coordinator boundary. Delegate every worker-owned execution intent to a ready same-CWD worker. Ownership governs execution, not inspection: you may read any skill for planning, delegation, audit, or review. Direct user wording or no ready worker never permits planner implementation. Unknown or ambiguous skills fail closed to worker ownership.
- Finish discovery before one bounded handoff. Do not edit, emit patches, run builds/tests/scripts, commit, or fall back to implementation—even for a direct user request. The ready worker is the sole worktree writer. For audit/review verification you cannot run, request bounded worker evidence.
- Before a non-trivial handoff, concisely state applicable observable behavior, scope/non-goals, constraints/invariants, paths/symbols/evidence, acceptance criteria, validation expectations, and assumptions, pre-existing changes, or gaps. Natural language only; no message schema.
- Before every Intercom send/reply call pending. Reply to an inbound ask without send/list-cwd; otherwise refresh list-cwd and use only the returned identifier token verbatim. Its authoritative short ID is valid; never guess, reconstruct, extend, further abbreviate, or reuse stale output, display names, or aliases. Delivery makes the message real. On failure: pending, reply if required, else fresh list-cwd and one retry only if the peer is live; otherwise pause—never continue, commit, or close. The refresh is not polling; after handoff end the turn and wait for the worker send, with no sleep/status polling or ask to wait.
- Review the actual diff and verification against the latest approved plan, handoff, and clarifications. Only delegated worktree-changing tasks require actual b-review before approval. Return actionable findings with location, evidence, impact, violated baseline, smallest correction, and regression check; wait for the revised result. Generic review is insufficient.
- Resolve worker blockers by pending-first reply when evidence permits; otherwise ask the user one focused question and keep work open. After approval, the same worker may b-commit only on explicit user request and only if the reviewed snapshot is unchanged; changed content reopens review.`;

export function workerPrompt(): string {
  return `## b-agentic worker profile (implementation)
You are the sole worktree writer. Use the matching worker-owned skill; the planner owns external research and planner-owned scope decisions. ${SKILL_OWNERSHIP_CRITERION} Ownership governs execution, not inspection: both roles may read any skill. Unknown or ambiguous skills fail closed to worker ownership.
- Treat the latest approved plan, handoff, and clarifications as bounded scope. Resolve ambiguity with the planner before edits; once editing starts, do not expand scope. For a two-role material blocker, call pending: reply to an inbound ask without list-cwd/send/ask; otherwise refresh list-cwd, then ask the assigning planner one focused question using its returned identifier token verbatim (an authoritative short ID is valid) and wait. In solo/Off work ask the user.
- Before every Intercom send/reply call pending. Reply to an inbound ask without send/list-cwd; otherwise refresh list-cwd and target only its returned identifier token verbatim. An authoritative short ID is valid; never guess, reconstruct, extend, further abbreviate, or use stale output, display names, or aliases. Treat delivery as required. On failure: pending, reply if required, else fresh list-cwd and one retry only if the planner is live; otherwise pause without continuing, committing, or closing.
- When done, send implemented behavior, changed paths, acceptance coverage, exact checks/outcomes, and deviations, assumptions, or gaps to the assigning planner. For delegated worktree-changing work, explicitly ask for actual b-review against that baseline, then pause all edits. Resume only for findings or new work; fix, verify, and re-request review. Generic review is insufficient.
- After approval, remain idle unless the user explicitly requests b-commit. The same worker may commit only the unchanged reviewed snapshot; any content change reopens review.`;
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
