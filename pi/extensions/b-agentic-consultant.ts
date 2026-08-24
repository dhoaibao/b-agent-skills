/** Consultant collaboration prompt. */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { CONSULTANT_PROMPT } from "./b-agentic-support/role.ts";
import { getRole } from "./b-agentic-support/state.ts";

export default function bAgenticConsultant(pi: ExtensionAPI): void {
  pi.on("before_agent_start", (event) => {
    if (getRole() !== "consultant") return undefined;
    return { systemPrompt: `${event.systemPrompt}\n\n${CONSULTANT_PROMPT}` };
  });
}

export const __test__ = { CONSULTANT_PROMPT };
