/** Notify desktop users for explicit planner attention signals. */
import type { AgentEndEvent, ExtensionAPI, ToolCallEvent } from "@earendil-works/pi-coding-agent";
import { getRole } from "./b-agentic-support/state.ts";

export const PLANNER_ATTENTION_SIGNALS = {
  TASK_COMPLETE: "B_AGENTIC_TASK_COMPLETE",
} as const;
export type PlannerAttentionSignal = (typeof PLANNER_ATTENTION_SIGNALS)[keyof typeof PLANNER_ATTENTION_SIGNALS];

const NOTIFICATION_MESSAGES: Record<PlannerAttentionSignal, string> = {
  [PLANNER_ATTENTION_SIGNALS.TASK_COMPLETE]: "Task complete",
};
export const USER_INPUT_NOTIFICATION = "User input needed";
const NOTIFICATION_TIMEOUT_MS = 5_000;
const MACOS_TITLE = "b-agentic";
const macosNotificationScript = (message: string): string => `display notification "${message}" with title "${MACOS_TITLE}"`;
const MACOS_SCRIPTS: Record<PlannerAttentionSignal, string> = Object.fromEntries(
  Object.entries(NOTIFICATION_MESSAGES).map(([signal, message]) => [signal, macosNotificationScript(message)]),
) as Record<PlannerAttentionSignal, string>;
type Exec = (command: string, args: string[], options?: { timeout?: number }) => Promise<unknown>;

function finalAssistantText(messages: AgentEndEvent["messages"]): string | undefined {
  const finalAssistant = [...messages].reverse().find((message) => message.role === "assistant");
  if (!finalAssistant) return;
  return finalAssistant.content
    .filter((content) => content.type === "text")
    .map((content) => content.text)
    .join("\n");
}

export function plannerAttentionSignals(messages: AgentEndEvent["messages"]): PlannerAttentionSignal[] {
  const text = finalAssistantText(messages);
  if (!text) return [];
  const signals = new Set<PlannerAttentionSignal>();
  for (const line of text.split(/\r?\n/).map((line) => line.trim())) {
    if (line === PLANNER_ATTENTION_SIGNALS.TASK_COMPLETE) signals.add(PLANNER_ATTENTION_SIGNALS.TASK_COMPLETE);
  }
  return signals.size === 1 ? [...signals] : [];
}

async function notifyMessage(exec: Exec, message: string, platform: string): Promise<void> {
  if (platform === "linux") {
    try {
      await exec("notify-send", [message], { timeout: NOTIFICATION_TIMEOUT_MS });
    } catch {
      // Missing or failing desktop notifiers must not disrupt Pi.
    }
    return;
  }
  if (platform === "darwin") {
    try {
      await exec("osascript", ["-e", macosNotificationScript(message)], { timeout: NOTIFICATION_TIMEOUT_MS });
    } catch {
      // Missing or failing desktop notifiers must not disrupt Pi.
    }
  }
}

export async function notifyDesktop(
  exec: Exec,
  signal: PlannerAttentionSignal,
  platform: string = process.platform,
): Promise<void> {
  const message = NOTIFICATION_MESSAGES[signal];
  if (!message) return;
  await notifyMessage(exec, message, platform);
}

export async function notifyUserInputNeeded(exec: Exec, platform: string = process.platform): Promise<void> {
  await notifyMessage(exec, USER_INPUT_NOTIFICATION, platform);
}

export default function bAgenticPlannerNotify(pi: ExtensionAPI): void {
  let lastAgentEndSignals: PlannerAttentionSignal[] = [];

  pi.on("agent_start", () => {
    lastAgentEndSignals = [];
  });
  pi.on("agent_end", ({ messages }) => {
    lastAgentEndSignals = plannerAttentionSignals(messages);
  });
  pi.on("tool_call", async (event: ToolCallEvent) => {
    if (getRole() !== "planner" || event.toolName !== "ask_user_question") return;
    await notifyUserInputNeeded((command, args, options) => pi.exec(command, args, options));
  });
  pi.on("agent_settled", async () => {
    const signals = getRole() === "planner" ? lastAgentEndSignals : [];
    lastAgentEndSignals = [];
    for (const signal of signals) {
      await notifyDesktop((command, args, options) => pi.exec(command, args, options), signal);
    }
  });
}

export const __test__ = {
  MACOS_SCRIPTS,
  NOTIFICATION_MESSAGES,
  NOTIFICATION_TIMEOUT_MS,
  PLANNER_ATTENTION_SIGNALS,
  USER_INPUT_NOTIFICATION,
  notifyDesktop,
  notifyUserInputNeeded,
  plannerAttentionSignals,
};
