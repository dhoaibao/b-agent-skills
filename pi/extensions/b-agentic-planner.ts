/** Planner collaboration prompt. */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { PLANNER_ALLOWED_TOOLS, PLANNER_PROMPT, SKILL_OWNERS, SKILL_OWNERSHIP_CRITERION, isMcpAdapterToolName, isPlannerAllowedToolName, skillOwner } from "./b-agentic-support/role.ts";
import { getRole } from "./b-agentic-support/state.ts";

export default function bAgenticPlanner(pi: ExtensionAPI): void {
  pi.on("before_agent_start", (event) => {
    if (getRole() !== "planner") return undefined;
    return { systemPrompt: `${event.systemPrompt}\n\n${PLANNER_PROMPT}` };
  });
  pi.on("tool_call", (event) => {
    if (getRole() !== "planner") return undefined;
    // Planner task delegation remains prompt-governed. Commands and MCP calls use
    // the shared safety/approval policy instead of a stricter role-specific gate.
    if (event.toolName === "bash" || isMcpAdapterToolName(event.toolName)) return undefined;
    if (isPlannerAllowedToolName(event.toolName)) return undefined;
    return { block: true, reason: `Planner mode is read-only: ${event.toolName} is disabled` };
  });
}

export const __test__ = { isMcpAdapterToolName, isPlannerAllowedToolName, PLANNER_ALLOWED_TOOLS, PLANNER_PROMPT, SKILL_OWNERS, SKILL_OWNERSHIP_CRITERION, skillOwner };
