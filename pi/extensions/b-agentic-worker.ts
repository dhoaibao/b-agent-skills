/** Legacy filename retained; injects the implementer profile. */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { implementerPrompt } from "./b-agentic-support/role.ts";
import { getRole } from "./b-agentic-support/state.ts";

export default function bAgenticImplementer(pi: ExtensionAPI): void {
  pi.on("before_agent_start", (event) => {
    if (getRole() !== "implementer") return undefined;
    return { systemPrompt: `${event.systemPrompt}\n\n${implementerPrompt()}` };
  });
}
export const __test__ = { implementerPrompt };
