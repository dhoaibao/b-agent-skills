/** Planner collaboration prompt. */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { isMcpAdapterToolName, isPlannerMcpToolName, isPlannerReadOnlyMcpCall } from "./b-agentic-support/mcp.ts";
import { PLANNER_ALLOWED_TOOLS, PLANNER_PROMPT, SKILL_OWNERS, SKILL_OWNERSHIP_CRITERION, isPlannerAllowedToolName, plannerCodeGraphInitAllowed, plannerCommandDecision, skillOwner } from "./b-agentic-support/role.ts";
import { getRole } from "./b-agentic-support/state.ts";

export default function bAgenticPlanner(pi: ExtensionAPI): void {
  pi.on("before_agent_start", (event) => {
    if (getRole() !== "planner") return undefined;
    return { systemPrompt: `${event.systemPrompt}\n\n${PLANNER_PROMPT}` };
  });
  pi.on("tool_call", (event) => {
    if (getRole() !== "planner") return undefined;
    if (event.toolName === "bash") {
      const decision = plannerCommandDecision(String((event.input as { command?: unknown })?.command ?? ""));
      return decision.allowed ? undefined : { block: true, reason: decision.reason };
    }
    if (isMcpAdapterToolName(event.toolName)) {
      return isPlannerMcpToolName(event.toolName) && isPlannerReadOnlyMcpCall(event.toolName, event.input)
        ? undefined
        : { block: true, reason: "Planner mode permits only safe metadata or classified read-only MCP calls" };
    }
    if (isPlannerAllowedToolName(event.toolName)) return undefined;
    return { block: true, reason: `Planner mode is read-only: ${event.toolName} is disabled` };
  });
}

export const __test__ = { isMcpAdapterToolName, isPlannerAllowedToolName, isPlannerMcpToolName, isPlannerReadOnlyMcpCall, PLANNER_ALLOWED_TOOLS, PLANNER_PROMPT, SKILL_OWNERS, SKILL_OWNERSHIP_CRITERION, plannerCodeGraphInitAllowed, plannerCommandDecision, skillOwner };
