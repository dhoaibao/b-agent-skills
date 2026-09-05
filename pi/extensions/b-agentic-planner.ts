/** Legacy filename retained; injects the reviewer profile. */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import {
  REVIEWER_PROMPT,
  SKILL_OWNERS,
  SKILL_OWNERSHIP_CRITERION,
  skillOwner,
} from "./b-agentic-support/role.ts";
import { getRole } from "./b-agentic-support/state.ts";

export default function bAgenticReviewer(pi: ExtensionAPI): void {
  pi.on("before_agent_start", (event) => {
    if (getRole() !== "reviewer") return undefined;
    return { systemPrompt: `${event.systemPrompt}\n\n${REVIEWER_PROMPT}` };
  });
}
export const __test__ = {
  REVIEWER_PROMPT,
  SKILL_OWNERS,
  SKILL_OWNERSHIP_CRITERION,
  skillOwner,
};
