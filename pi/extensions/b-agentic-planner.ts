/** Planner prompt, read-only enforcement, and task-handoff validation. */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import * as planner from "./b-agentic-support/role.ts";
import { getRole } from "./b-agentic-support/state.ts";
import { plannerCommandDecision } from "./b-agentic-support/shell.ts";

export default function bAgenticPlanner(pi: ExtensionAPI): void {
  pi.on("before_agent_start", (event) => {
    if (getRole() !== "planner") return undefined;
    return { systemPrompt: `${event.systemPrompt}\n\n${planner.PLANNER_PROMPT}` };
  });
  pi.on("tool_call", async (event) => {
    if (getRole() !== "planner") return undefined;
    if (event.toolName === "intercom" && event.input && typeof event.input === "object" && (event.input as { action?: unknown }).action && ((event.input as { action?: unknown }).action === "ask" || (event.input as { action?: unknown }).action === "reply")) {
      return { block: true, reason: "b-agentic role loop uses Intercom send, never ask/reply" };
    }
    const task = planner.plannerTaskValidation(event.toolName, event.input);
    if (task.isTask && !task.valid) return { block: true, reason: task.reason };
    if (event.toolName === "edit" || event.toolName === "write") return { block: true, reason: `Planner mode is read-only: ${event.toolName} is disabled` };
    if (event.toolName === "bash") {
      const command = String((event.input as { command?: string }).command || "");
      const decision = plannerCommandDecision(command);
      if (decision.decision === "deny") return { block: true, reason: decision.reason };
    } else if (!["read", "recall", "grep", "find", "ls", "intercom", "mcp", "mcpScript"].includes(event.toolName)) {
      return { block: true, reason: `Planner mode is read-only: custom tool ${event.toolName} blocked` };
    }
    return undefined;
  });
}

export const __test__ = {
  PLANNER_PROMPT: planner.PLANNER_PROMPT,
  plannerCommandDecision,
  plannerTaskValidation: planner.plannerTaskValidation,
};
