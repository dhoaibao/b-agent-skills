/** Injects the Executor profile. */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { executorPrompt } from "./b-agentic-support/role.ts";
import { getRole } from "./b-agentic-support/state.ts";

export default function bAgenticExecutor(pi: ExtensionAPI): void {
  pi.on("before_agent_start", (event) => {
    if (getRole() !== "executor") return undefined;
    return { systemPrompt: `${event.systemPrompt}\n\n${executorPrompt()}` };
  });
}
export const __test__ = { executorPrompt };
