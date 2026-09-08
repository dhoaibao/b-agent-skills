function isPlainObject(value: unknown): value is Record<string, unknown> {
  return Boolean(value && typeof value === "object" && !Array.isArray(value));
}

export type BAgenticRole = "off" | "implementer" | "reviewer";
export type RoleState = { role: BAgenticRole };
export const ROLE_ENTRY_TYPE = "b-agentic-role";
export const ROLE_PROTOCOL_VERSION = 2;

// generated:skill-ownership:start
/** Generated from skills/registry.yaml. Unknown skills fail closed to implementer ownership. */
export type SkillOwner = "implementer" | "reviewer";
export const SKILL_OWNERSHIP_CRITERION = "Implementer-owned skills perform planning, research, design, implementation, validation, commit, or PR-summary work. Reviewer-owned skills perform independent read-only audit or changed-code review. Mixed or uncertain skills are implementer-owned.";
export const SKILL_OWNERS: Readonly<Record<string, SkillOwner>> = {
  "b-plan": "implementer",
  "b-research": "implementer",
  "b-design": "implementer",
  "b-frontend": "implementer",
  "b-diagram": "implementer",
  "b-implement": "implementer",
  "b-init": "implementer",
  "b-refactor": "implementer",
  "b-debug": "implementer",
  "b-test": "implementer",
  "b-browser": "implementer",
  "b-agentic-audit": "reviewer",
  "b-review": "reviewer",
  "b-commit": "implementer",
  "b-pr-summary": "implementer"
};
export function skillOwner(skill: string): SkillOwner {
  return SKILL_OWNERS[skill] ?? "implementer";
}
const IMPLEMENTER_OWNED_SKILLS = Object.entries(SKILL_OWNERS).filter(([, owner]) => owner === "implementer").map(([skill]) => "`" + skill + "`");
const REVIEWER_OWNED_SKILLS = Object.entries(SKILL_OWNERS).filter(([, owner]) => owner === "reviewer").map(([skill]) => "`" + skill + "`");
// generated:skill-ownership:end

export function implementerPrompt(): string {
  return `## b-agentic implementer profile (sole user-facing writer)
You own planning, research, design, implementation, validation, commit, and PR-summary execution: ${IMPLEMENTER_OWNED_SKILLS.join(", ")}. Reviewer-owned independent gates are ${REVIEWER_OWNED_SKILLS.join(", ")}. ${SKILL_OWNERSHIP_CRITERION} Ownership governs execution, not inspection; roles never filter tools and shared approval policy remains authoritative.
- Work directly with the user. Resolve material scope or product questions with ask_user_question; do not relay them through a reviewer. Make the smallest coherent change and self-check it before requesting review.
- When the explicit implementer role is active and implementation is complete with required checks passed, immediately and before any final task response, b-role has already confirmed compatible-peer arbitration. Use intercom list-cwd only to address the sole same-CWD peer—the reviewer session in the same CWD under that arbitration; its output does not expose peer roles; automatically request independent b-review through intercom with a compact snapshot handoff, then stop edits and do not report completion pending review. Report a coordination gap only when that peer or intercom capability is unavailable, not because list-cwd omits a role label; never provision, reset, or guess a peer.
- After a reviewer delegates NEEDS FIXES, correct only unambiguous in-scope findings, rerun required checks, and send a fresh review request; stop for ambiguity or scope drift.
- A review is valid only for that exact unchanged snapshot from a compatible reviewer. READY FOR PR requires acceptance, a baseline, all required checks passed and fresh for the candidate, no blockers or material gaps, and the reviewer disposition. READY WITH FOLLOW-UPS requires explicit accepted disposition and never waives required safety evidence. NEEDS FIXES, skipped/failed checks, an absent baseline, wrong reviewer, or a changed tracked/untracked candidate block shipping. Corrections require re-verification and re-review; after two nonconvergent rounds, surface a blocker rather than lower criteria.
- Do not edit while review is pending. A reviewer may use bounded read-only research only to substantiate a finding; it never delegates, changes scope, or becomes an implementation relay. No automatic commit or push follows review. Prepare the same-day changelog only when the user authorizes an actual commit, and include it in the reviewed candidate or reopen review.`;
}

export const REVIEWER_PROMPT = `## b-agentic reviewer profile (independent read-only gate)
You execute only independent changed-code review and b-agentic audit: ${REVIEWER_OWNED_SKILLS.join(", ")}. ${SKILL_OWNERSHIP_CRITERION} You are prompt-governed read-only: do not edit, emit patches, commit, run generators/fixers, or make any worktree mutation; shared approval policy remains authoritative and roles do not filter tools.
- Independently assess the compact candidate handoff, actual diff, relevant untracked/derived files, acceptance baseline, and verification evidence. When an implementer handoff arrives through intercom, begin b-review automatically. Do not accept a missing baseline, stale or different snapshot, incompatible peer, skipped/failed required check, or unaccepted follow-up as ready.
- Findings state location, evidence, impact, violated baseline, minimal correction, and regression check. Bounded read-only research may substantiate a review finding only; it does not expand scope or become a research relay. Before reporting review completion, automatically return the structured disposition and findings through intercom to the implementer session in the same CWD for every disposition (NEEDS FIXES, READY FOR PR, or READY WITH FOLLOW-UPS); report a coordination gap if that session or intercom is unavailable.
- Review completion is not task acceptance, commit creation, or shipping. Never claim or provision fresh context: reviewer selection and freshness are runtime/user concerns outside this profile. Finish with the required b-review disposition for the exact snapshot only after the handback succeeds or its coordination gap is reported.`;

export function parseRole(value: unknown): BAgenticRole | undefined {
  if (typeof value !== "string") return undefined;
  const role = value.trim().toLowerCase();
  return role === "off" || role === "implementer" || role === "reviewer"
    ? role
    : undefined;
}

/** Old planner/worker session entries intentionally remain inactive. */
export function latestRoleState(entries: unknown[]): RoleState | undefined {
  for (let index = entries.length - 1; index >= 0; index -= 1) {
    const entry = entries[index];
    if (!isPlainObject(entry) || entry.type !== "custom" || entry.customType !== ROLE_ENTRY_TYPE || !isPlainObject(entry.data)) continue;
    const role = parseRole(entry.data.role);
    if (!role) continue;
    return { role };
  }
  return undefined;
}

export function isCompatibleRolePayload(value: unknown): value is { type: "b-agentic-role"; version: 2; role: BAgenticRole } {
  return isPlainObject(value) && value.type === "b-agentic-role" && value.version === ROLE_PROTOCOL_VERSION && parseRole(value.role) !== undefined;
}
