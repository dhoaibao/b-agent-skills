/** Injects the Architect profile. */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import {
  ARCHITECT_PROMPT,
  SKILL_OWNERS,
  SKILL_OWNERSHIP_CRITERION,
  skillOwner,
} from "./b-agentic-support/role.ts";
import { getRole } from "./b-agentic-support/state.ts";

export default function bAgenticArchitect(pi: ExtensionAPI): void {
  pi.on("before_agent_start", (event) => {
    if (getRole() !== "architect") return undefined;
    return { systemPrompt: `${event.systemPrompt}\n\n${ARCHITECT_PROMPT}` };
  });
}
export const __test__ = {
  ARCHITECT_PROMPT,
  SKILL_OWNERS,
  SKILL_OWNERSHIP_CRITERION,
  skillOwner,
};
