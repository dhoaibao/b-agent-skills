import { existsSync, realpathSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { delimiter, dirname, isAbsolute, relative, resolve } from "node:path";

import { expandLocalPath } from "./shell.ts";

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return Boolean(value && typeof value === "object" && !Array.isArray(value));
}

export type BAgenticRole = "off" | "planner" | "worker";
export type Decision = "allow" | "ask" | "deny";
export type WorkerDirectiveKind = "task" | "changes_requested" | "approved" | "invalid";
export type WorkerDirective = {
  id: string;
  kind: WorkerDirectiveKind;
  skillName?: string;
  iteration?: number;
  reportTo?: string;
  plannerId?: string;
  plannerName?: string;
  plannerCwd?: string;
};
export type RoleState = {
  role: BAgenticRole;
  toolsBeforePlanner?: string[];
  reportedDirectiveIds: string[];
};

export const ROLE_ENTRY_TYPE = "b-agentic-role";
export const WORKER_SKILLS = new Set(["b-browser", "b-debug", "b-implement", "b-refactor", "b-research", "b-test"]);
export const PLANNER_DISABLED_TOOLS = new Set(["edit", "write"]);
export const PLANNER_CODEGRAPH_COMMANDS = new Set([
  "affected", "callees", "callers", "explore", "files", "help", "impact", "node", "query", "status", "version",
]);
export const PLANNER_READ_COMMANDS = new Set([
  "[", "basename", "bat", "batcat", "cat", "cd", "df", "diff", "dirname", "du", "echo", "eza", "exa",
  "fd", "fdfind", "file", "find", "grep", "head", "jq", "ls", "popd", "printf", "pushd", "pwd", "readlink",
  "realpath", "rg", "sort", "stat", "tail", "test", "true", "type", "uniq", "wc", "whereis", "which",
]);

export const PLANNER_PROMPT = `## b-agentic planner profile (read-only)
You are the planner, coordinator, and reviewer. This profile overrides execution routing while active.
- Use b-plan for decomposition, b-research only for blocking external facts, and b-review for every worker result. Read the selected SKILL.md before that phase.
- Never edit the repository, run builds/tests, create commits, or call mutating tools. If verification is needed, delegate it; switch role off for b-design, b-init, or b-commit.
- For a classified read-only MCP gateway call, always provide both \`server: <managed server>\` and \`tool: <tool name>\`; unscoped gateway calls remain blocked.
- When implementation needs delegation, first use Intercom \`list-cwd\` to locate one same-cwd worker, then send that worker a complete task. Construct and send the task yourself; never ask the user to write or relay \`B_AGENTIC_TASK\`. If no worker is available, say so concisely and continue planning rather than attempting repository writes.
- Delegate to at most one same-cwd worker with Intercom \`send\`. Use this exact task format:
\`\`\`text
B_AGENTIC_TASK v1
worker_skill: <worker skill>
iteration: 1
goal: <bounded outcome>
constraints: <scope and invariants>
success_checks: <observable checks>
report_to: <this planner session name or id>
\`\`\`
- Review the actual diff and evidence. Request fixes with this exact format:
\`\`\`text
B_AGENTIC_REVIEW v1
verdict: changes_requested
worker_skill: <next worker skill>
iteration: <previous iteration + 1>
findings: <ordered actionable findings>
\`\`\`
Approve with this exact format:
\`\`\`text
B_AGENTIC_REVIEW v1
verdict: approved
iteration: <completed iteration>
\`\`\`
- Use \`send\`, never \`ask\`/\`reply\`, for task, result, and review traffic.`;

export function workerPrompt(directive: WorkerDirective | undefined, skillPath: string | undefined, skillLoaded: boolean, resultReported: boolean): string {
  const assignment = resultReported
    ? "The result was sent. Wait for B_AGENTIC_REVIEW before any more repository work."
    : directive?.skillName
    ? `Assigned skill: ${directive.skillName}${directive.iteration ? ` (iteration ${directive.iteration})` : ""}. Skill file: ${skillPath ?? "unavailable"}.`
    : directive?.kind === "approved"
      ? "The planner approved the result. Wait for another B_AGENTIC_TASK or changes_requested review."
      : directive?.kind === "invalid"
        ? "The latest handoff is invalid. Report the malformed handoff to the planner and wait."
        : "No structured assignment is active. Wait for a B_AGENTIC_TASK or changes_requested B_AGENTIC_REVIEW.";
  const loadRule = resultReported
    ? "Do not continue implementation while review is pending."
    : directive?.skillName && !skillLoaded
      ? "Before any repository action, read the exact assigned SKILL.md path."
      : "Follow only the assigned skill for this iteration.";
  const resultInstruction = !resultReported && (directive?.kind === "task" || directive?.kind === "changes_requested") &&
    directive.skillName && directive.iteration && directive.reportTo
    ? `When ready, request planner review with exactly this format:
\`\`\`text
B_AGENTIC_RESULT v1
status: ready_for_review
worker_skill: ${directive.skillName}
iteration: ${directive.iteration}
changed_paths: <paths or none>
verification: <commands and outcomes>
gaps: <remaining gaps or none>
\`\`\`
Send it to exactly: ${directive.reportTo}`
    : "Wait for a valid assignment before sending B_AGENTIC_RESULT.";
  return `## b-agentic worker profile (primary edit)
You are the sole implementation worker. ${assignment}
- ${loadRule}
- Own only the bounded task. Implement/fix/test with normal b-agentic safety and verification rules; do not plan, review, commit, or delegate.
- ${resultInstruction}
- Use Intercom \`send\`, never \`ask\`/\`reply\`, then stop changing the repository until a new review iteration arrives.`;
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
    const reportedDirectiveIds = Array.isArray(entry.data.reportedDirectiveIds)
      ? entry.data.reportedDirectiveIds.filter((value): value is string => typeof value === "string")
      : [];
    return { role, toolsBeforePlanner: tools, reportedDirectiveIds };
  }
  return undefined;
}

export function protocolField(body: string, name: string): string | undefined {
  const escaped = name.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const value = new RegExp(`^${escaped}:\\s*(.+?)\\s*$`, "im").exec(body)?.[1]?.trim();
  return value || undefined;
}

export function intercomSender(entry: Record<string, unknown>): { id: string; name?: string; cwd: string } | undefined {
  if (!isPlainObject(entry.details) || !isPlainObject(entry.details.from)) return undefined;
  const from = entry.details.from;
  if (typeof from.id !== "string" || typeof from.cwd !== "string") return undefined;
  return { id: from.id, name: typeof from.name === "string" ? from.name : undefined, cwd: from.cwd };
}

export type PlannerTaskValidation = { isTask: boolean; valid: boolean; reason: string };

/**
 * Reject incomplete planner handoffs before delivery, rather than leaving a
 * worker idle with an invalid task it cannot execute.
 */
export function plannerTaskValidation(toolName: string, input: unknown): PlannerTaskValidation {
  if (toolName !== "intercom" || !isPlainObject(input) || input.action !== "send" || typeof input.message !== "string") {
    return { isTask: false, valid: true, reason: "" };
  }
  const marker = /(?:^|\n)B_AGENTIC_TASK(?:\s+v1)?\s*(?:\n|$)/m.exec(input.message);
  if (!marker) return { isTask: false, valid: true, reason: "" };

  const body = input.message.slice(marker.index ?? 0);
  const problems: string[] = [];
  if (!/^B_AGENTIC_TASK\s+v1\s*(?:\n|$)/m.test(body)) problems.push("use B_AGENTIC_TASK v1");
  const skillName = protocolField(body, "worker_skill");
  if (!skillName || !WORKER_SKILLS.has(skillName)) problems.push("choose an allowed worker_skill");
  if (Number(protocolField(body, "iteration")) !== 1) problems.push("set iteration: 1");
  for (const field of ["goal", "constraints", "success_checks", "report_to"]) {
    if (!protocolField(body, field)) problems.push(`include ${field}`);
  }
  return problems.length === 0
    ? { isTask: true, valid: true, reason: "" }
    : { isTask: true, valid: false, reason: `Planner task is incomplete: ${problems.join("; ")}` };
}

export function latestWorkerDirective(
  entries: unknown[],
  workerCwd?: string,
  availableSkills?: ReadonlySet<string>,
): WorkerDirective | undefined {
  let current: WorkerDirective | undefined;
  let reported = new Set<string>();
  for (let index = 0; index < entries.length; index += 1) {
    const entry = entries[index];
    if (!isPlainObject(entry)) continue;
    if (entry.type === "custom" && entry.customType === ROLE_ENTRY_TYPE && isPlainObject(entry.data)) {
      reported = Array.isArray(entry.data.reportedDirectiveIds)
        ? new Set(entry.data.reportedDirectiveIds.filter((value): value is string => typeof value === "string"))
        : new Set();
      if (parseRole(entry.data.role) !== "worker") current = undefined;
      continue;
    }
    if (entry.type !== "custom_message" || entry.customType !== "intercom_message" || typeof entry.content !== "string") continue;
    const marker = /(?:^|\n)B_AGENTIC_(TASK|REVIEW)(?:\s+v1)?\s*(?:\n|$)/m.exec(entry.content);
    if (!marker) continue;
    const body = entry.content.slice(marker.index ?? 0);
    const kind = marker[1];
    const id = typeof entry.id === "string" ? entry.id : `entry-${index}`;
    const iterationValue = Number(protocolField(body, "iteration"));
    const iteration = Number.isInteger(iterationValue) && iterationValue > 0 ? iterationValue : undefined;
    const sender = intercomSender(entry);
    const senderInWorkerCwd = Boolean(sender && (!workerCwd || pathsMatch(sender.cwd, workerCwd, workerCwd)));

    if (kind === "TASK") {
      if (current && current.kind !== "approved" && current.kind !== "invalid") continue;
      const skillName = protocolField(body, "worker_skill");
      const reportTo = protocolField(body, "report_to");
      const completeTask = protocolField(body, "goal") && protocolField(body, "constraints") && protocolField(body, "success_checks");
      if (!sender || !senderInWorkerCwd || !skillName || !WORKER_SKILLS.has(skillName) ||
        (availableSkills && !availableSkills.has(skillName)) || iteration !== 1 ||
        !reportTo || !completeTask) {
        current = { id, kind: "invalid", iteration };
        continue;
      }
      // The broker-authenticated sender is the only reliable result target:
      // session aliases and configured stable IDs are not available to this extension.
      current = {
        id, kind: "task", skillName, iteration, reportTo: sender.id,
        plannerId: sender.id, plannerName: sender.name, plannerCwd: sender.cwd,
      };
      continue;
    }

    if (!current || (current.kind !== "task" && current.kind !== "changes_requested") ||
      !sender || !senderInWorkerCwd || sender.id !== current.plannerId || !reported.has(current.id)) continue;
    const verdict = protocolField(body, "verdict")?.toLowerCase();
    if (verdict === "approved" && iteration === current.iteration) {
      current = { ...current, id, kind: "approved" };
      continue;
    }
    const skillName = protocolField(body, "worker_skill");
    if (verdict === "changes_requested" && iteration === (current.iteration || 0) + 1 &&
      skillName && WORKER_SKILLS.has(skillName) && (!availableSkills || availableSkills.has(skillName)) && protocolField(body, "findings")) {
      current = { ...current, id, kind: "changes_requested", skillName, iteration };
    }
  }
  return current;
}

export function pathsMatch(first: string, second: string, cwd: string): boolean {
  const normalize = (value: string): string => {
    const absolute = value === "~" || value.startsWith("~/") ? expandLocalPath(value) : resolve(cwd, value);
    try {
      return realpathSync(absolute);
    } catch {
      return absolute;
    }
  };
  return normalize(first) === normalize(second);
}
