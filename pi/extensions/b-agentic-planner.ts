/** Planner collaboration prompt. */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import {
  PLANNER_PROMPT,
  SKILL_OWNERS,
  SKILL_OWNERSHIP_CRITERION,
  skillOwner,
} from "./b-agentic-support/role.ts";
import { getRole } from "./b-agentic-support/state.ts";

export default function bAgenticPlanner(pi: ExtensionAPI): void {
  // Planner task delegation remains prompt-governed; shared policies apply to all roles.
  pi.on("before_agent_start", (event) => {
    if (getRole() !== "planner") return undefined;
    return { systemPrompt: `${event.systemPrompt}\n\n${PLANNER_PROMPT}` };
  });
}

export const __test__ = {
  PLANNER_PROMPT,
  SKILL_OWNERS,
  SKILL_OWNERSHIP_CRITERION,
  skillOwner,
};
