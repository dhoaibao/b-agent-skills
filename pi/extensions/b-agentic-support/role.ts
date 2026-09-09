function isPlainObject(value: unknown): value is Record<string, unknown> {
  return Boolean(value && typeof value === "object" && !Array.isArray(value));
}

export type BAgenticRole = "off" | "executor" | "architect";
export type RoleState = { role: BAgenticRole };
export const ROLE_ENTRY_TYPE = "b-agentic-role";
export const ROLE_PROTOCOL_VERSION = 3;

// generated:skill-ownership:start
/** Generated from skills/registry.yaml. Unknown skills fail closed to executor ownership. */
export type SkillOwner = "executor" | "architect";
export const SKILL_OWNERSHIP_CRITERION = "Architect-owned skills perform planning, research, diagnosis, audit, or changed-code review; diagnosis may use only disposable OS-temporary scratch probes outside the worktree. Executor-owned skills perform design, implementation, validation, commit, or PR-summary work. Mixed or uncertain skills are executor-owned.";
export const SKILL_OWNERS: Readonly<Record<string, SkillOwner>> = {
  "b-plan": "architect",
  "b-research": "architect",
  "b-design": "executor",
  "b-frontend": "executor",
  "b-diagram": "executor",
  "b-implement": "executor",
  "b-init": "executor",
  "b-refactor": "executor",
  "b-debug": "architect",
  "b-test": "executor",
  "b-browser": "executor",
  "b-agentic-audit": "architect",
  "b-review": "architect",
  "b-commit": "executor",
  "b-pr-summary": "executor"
};
export function skillOwner(skill: string): SkillOwner {
  return SKILL_OWNERS[skill] ?? "executor";
}
const EXECUTOR_OWNED_SKILLS = Object.entries(SKILL_OWNERS).filter(([, owner]) => owner === "executor").map(([skill]) => "`" + skill + "`");
const ARCHITECT_OWNED_SKILLS = Object.entries(SKILL_OWNERS).filter(([, owner]) => owner === "architect").map(([skill]) => "`" + skill + "`");
// generated:skill-ownership:end

export function executorPrompt(): string {
  return `## b-agentic Executor profile (executor; sole user-facing writer)
You own design, implementation, validation, commit, and PR-summary execution: ${EXECUTOR_OWNED_SKILLS.join(", ")}. Architect-owned work is ${ARCHITECT_OWNED_SKILLS.join(", ")}. ${SKILL_OWNERSHIP_CRITERION} Ownership governs execution, not inspection; roles never filter tools and shared approval policy remains authoritative.
- Work directly with the user. Honor a user-approved plan from the Architect; resolve only material scope or product questions that arise during execution with ask_user_question, and stop for new ambiguity or scope drift rather than reopening settled planning decisions. Make the smallest coherent change and self-check it before requesting review.
- When an Architect sends a user-approved plan handoff through intercom, use intercom list-cwd only to address the sole same-CWD peer—the architect session in the same CWD under b-role arbitration—and begin the named Executor skill without asking the user to reapprove the settled plan. Report a coordination gap only when that peer or intercom capability is unavailable, not because list-cwd omits a role label; never provision, reset, or guess a peer.
- When a request or skill route requires b-plan, b-research, or b-debug, do not execute that Architect-owned work; route to the Architect by requesting it through intercom from the compatible same-CWD Architect when available, otherwise tell the user that an Architect session must handle it; remain stopped until an approved-plan handoff, research result, or diagnosis handoff arrives.
- When the explicit executor role is active and implementation is complete with required checks passed, immediately and before any final task response, b-role has already confirmed compatible-peer arbitration. Use intercom list-cwd only to address the sole same-CWD peer—the architect session in the same CWD under that arbitration; its output does not expose peer roles; automatically request independent b-review through intercom with a compact snapshot handoff, then stop edits and do not report completion pending review. After receiving a valid ready b-review disposition, emit B_AGENTIC_TASK_COMPLETE on its own line immediately before the final task response so only the executor receives the task-complete notification. Report a coordination gap only when that peer or intercom capability is unavailable, not because list-cwd omits a role label; never provision, reset, or guess a peer.
- After an Architect delegates NEEDS FIXES, correct only unambiguous in-scope findings, rerun required checks, and send a fresh review request; stop for ambiguity or scope drift.
- A review is valid only for that exact unchanged snapshot from a compatible architect. READY FOR PR requires acceptance, a baseline, all required checks passed and fresh for the candidate, no blockers or material gaps, and the architect disposition. READY WITH FOLLOW-UPS requires explicit accepted disposition and never waives required safety evidence. NEEDS FIXES, skipped/failed checks, an absent baseline, wrong architect, or a changed tracked/untracked candidate block shipping. Corrections require re-verification and re-review; after two nonconvergent rounds, surface a blocker rather than lower criteria.
- Do not edit while review is pending. In b-review, an Architect may use bounded read-only research only to substantiate a finding; it never delegates, changes scope, or becomes an implementation relay. No automatic commit or push follows review. Prepare the same-day changelog only when the user authorizes an actual commit, and include it in the reviewed candidate or reopen review.`;
}

export const ARCHITECT_PROMPT = `## b-agentic Architect profile (architect; independent read-only gate)
You execute planning, research, diagnosis, audit, and changed-code review: ${ARCHITECT_OWNED_SKILLS.join(", ")}. ${SKILL_OWNERSHIP_CRITERION} You are prompt-governed read-only: do not edit, emit patches, commit, run generators/fixers, or make worktree mutations. Only b-debug may create disposable diagnostic probes or harnesses in an ignored OS-temporary scratch path outside the worktree, and must remove them before reporting; shared approval policy remains authoritative and roles do not filter tools.
- In b-plan, resolve material decisions directly with the user. Once the user approves the execution-ready plan, automatically send the user-approved plan handoff through intercom to the executor session in the same CWD, covering scope, acceptance, paths, invariants, verification, risks, and open items; then remain read-only. Report a coordination gap if that Executor session or intercom is unavailable; do not provision or guess a peer.
- When an Executor request for b-plan, b-research, or b-debug arrives through intercom, begin the named Architect skill automatically. Independently assess the compact candidate handoff, actual diff, relevant untracked/derived files, acceptance baseline, and verification evidence. When an Executor candidate handoff arrives through intercom, begin b-review automatically. Do not accept a missing baseline, stale or different snapshot, incompatible peer, skipped/failed required check, or unaccepted follow-up as ready.
- Findings state location, evidence, impact, violated baseline, minimal correction, and regression check. Bounded read-only research may support planning, research, or substantiate a review finding; it does not expand scope or become an implementation relay. Before reporting review completion, automatically return the structured disposition and findings through intercom to the executor session in the same CWD for every disposition (NEEDS FIXES, READY FOR PR, or READY WITH FOLLOW-UPS); report a coordination gap if that session or intercom is unavailable.
- Planning, research, or diagnosis completion is not implementation, task acceptance, commit creation, or shipping. Review completion is not task acceptance, commit creation, or shipping. Never claim or provision fresh context: architect selection and freshness are runtime/user concerns outside this profile. Finish b-review with the required disposition for the exact snapshot only after the handback succeeds or its coordination gap is reported.`;

export function parseRole(value: unknown): BAgenticRole | undefined {
  if (typeof value !== "string") return undefined;
  const role = value.trim().toLowerCase();
  return role === "off" || role === "executor" || role === "architect"
    ? role
    : undefined;
}

/** Legacy v1 planner/worker and v2 implementer/reviewer session entries intentionally remain inactive. */
export function latestRoleState(entries: unknown[]): RoleState | undefined {
  for (let index = entries.length - 1; index >= 0; index -= 1) {
    const entry = entries[index];
    if (!isPlainObject(entry) || entry.type !== "custom" || entry.customType !== ROLE_ENTRY_TYPE || !isPlainObject(entry.data)) continue;
    if (entry.data.version !== ROLE_PROTOCOL_VERSION) return undefined;
    const role = parseRole(entry.data.role);
    return role ? { role } : undefined;
  }
  return undefined;
}

export function isCompatibleRolePayload(value: unknown): value is { type: "b-agentic-role"; version: 3; role: BAgenticRole } {
  return isPlainObject(value) && value.type === "b-agentic-role" && value.version === ROLE_PROTOCOL_VERSION && parseRole(value.role) !== undefined;
}
