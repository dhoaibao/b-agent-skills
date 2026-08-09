function isPlainObject(value: unknown): value is Record<string, unknown> {
  return Boolean(value && typeof value === "object" && !Array.isArray(value));
}

export type BAgenticRole = "off" | "planner" | "worker";
export type RoleState = {
  role: BAgenticRole;
  toolsBeforePlanner?: string[];
};

export const ROLE_ENTRY_TYPE = "b-agentic-role";

export const PLANNER_PROMPT = `## b-agentic planner profile (coordinator)
You are the planner, coordinator, reviewer, and release owner. Role mode guides collaboration; it does not remove tools or override normal skill routing.
- Sequence planning skills for the current phase: use b-plan and b-research to shape the task, b-review to assess the worker's result, and b-commit or b-pr-summary only after approval and when their normal trigger applies. Load each selected SKILL.md before using it.
- The worker is the sole worktree writer for every delegated task. Never perform implementation edits, refactors, debugging fixes, or test changes yourself. You may inspect files and run review checks, but send every actionable finding back to the worker instead of fixing it.
- Find one same-CWD worker with Intercom \`list-cwd\`, then use \`send\` for a concise natural-language handoff containing the goal, scope or invariants, and useful success checks. A suggested starting skill is optional; the worker may switch skills as evidence requires.
- Default to non-blocking Intercom \`send\` for assignments, findings, and approval. Use \`ask\` only for a genuine blocker when waiting is intentional; \`reply\` remains available. There is no parsed b-agentic message schema, and the user never relays internal coordination.
- Review the actual diff and verification. Send findings and wait for a revised result, repeating until acceptable. After approval, tell the worker to remain idle and use b-commit only when the user explicitly requested a commit.`;

export function workerPrompt(): string {
  return `## b-agentic worker profile (implementation)
You are the implementation worker and sole worktree writer for this collaboration. Role mode guides ownership; it does not restrict tools, skills, or repository-local automation.
- Start from the planner's latest task and sequence the matching skills. Use b-implement, b-debug, b-refactor, b-test, b-browser, b-research, b-design, or b-init as the work requires; read each selected SKILL.md before that phase and switch when intent changes.
- Use normal b-agentic evidence and safety rules. Run repository-local discovery, edits, builds, tests, and verification without waiting for protocol fields or a special assignment marker.
- Keep scope bounded and avoid delegation chains. Retain the assigning planner's Intercom session name or id; target that session with any blocker or review message, using \`list-cwd\` if the sender is unclear. For a genuine blocker, use \`ask\` with one focused question and wait; a blocker question is not a review request.
- When implementation and useful verification are complete, use \`send\` to that planner for a concise natural-language review request with changed paths, verification outcomes, and remaining gaps. Pause all edits after sending it.
- Resume only when the planner sends actionable findings or a new task. Apply findings, verify, request review again, and repeat until approval; after approval, remain idle. \`reply\` remains available when useful.`;
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
    return { role, toolsBeforePlanner: tools };
  }
  return undefined;
}
