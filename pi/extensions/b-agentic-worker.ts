/** Worker collaboration prompt. */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { workerPrompt } from "./b-agentic-support/role.ts";
import { getRole } from "./b-agentic-support/state.ts";

export default function bAgenticWorker(pi: ExtensionAPI): void {
  pi.on("before_agent_start", (event) => {
    if (getRole() !== "worker") return undefined;
    return { systemPrompt: `${event.systemPrompt}\n\n${workerPrompt()}` };
  });
}

export const __test__ = { workerPrompt };
