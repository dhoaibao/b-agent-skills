/** Notify desktop users for explicit planner attention signals. */
import type {
  AgentEndEvent,
  ExtensionAPI,
  ExtensionContext,
  ToolCallEvent,
} from "@earendil-works/pi-coding-agent";
import { getRole } from "./b-agentic-support/state.ts";

export const PLANNER_ATTENTION_SIGNALS = {
  TASK_COMPLETE: "B_AGENTIC_TASK_COMPLETE",
} as const;
export type PlannerAttentionSignal =
  (typeof PLANNER_ATTENTION_SIGNALS)[keyof typeof PLANNER_ATTENTION_SIGNALS];

const NOTIFICATION_MESSAGES: Record<PlannerAttentionSignal, string> = {
  [PLANNER_ATTENTION_SIGNALS.TASK_COMPLETE]: "Task complete",
};
export const USER_INPUT_NOTIFICATION = "User input needed";
export const NOTIFICATION_CONTEXT_ENV = "B_AGENTIC_NOTIFICATION_CONTEXT";
const NOTIFICATION_CONTEXT_OPT_IN = "1";
const NOTIFICATION_TIMEOUT_MS = 5_000;
const MACOS_TITLE = "b-agentic";
const MACOS_CONTEXT_SCRIPT = [
  "on run argv",
  `  display notification (item 1 of argv) with title "${MACOS_TITLE}"`,
  "end run",
].join("\n");
const macosNotificationScript = (message: string): string =>
  `display notification "${message}" with title "${MACOS_TITLE}"`;
const MACOS_SCRIPTS: Record<PlannerAttentionSignal, string> =
  Object.fromEntries(
    Object.entries(NOTIFICATION_MESSAGES).map(([signal, message]) => [
      signal,
      macosNotificationScript(message),
    ]),
  ) as Record<PlannerAttentionSignal, string>;
type Exec = (
  command: string,
  args: string[],
  options?: { timeout?: number },
) => Promise<unknown>;

export function notificationRepositoryLabel(
  cwd: string | undefined,
): string | undefined {
  if (process.env[NOTIFICATION_CONTEXT_ENV] !== NOTIFICATION_CONTEXT_OPT_IN)
    return;
  if (!cwd) return;
  const candidate = cwd.replace(/[\\/]+$/, "").split(/[\\/]/).pop() ?? "";
  const label = candidate
    .replace(/[\u0000-\u001f\u007f-\u009f]/g, "")
    .trim();
  if (
    !label ||
    label === "." ||
    label === ".." ||
    label.includes("/") ||
    label.includes("\\") ||
    /^[A-Za-z]:?$/.test(label)
  )
    return;
  return label;
}

function contextualNotificationMessage(
  message: string,
  cwd: string | undefined,
): { message: string; repository: string | undefined } {
  const repository = notificationRepositoryLabel(cwd);
  return {
    message: repository ? `${message} — ${repository}` : message,
    repository,
  };
}

export function setInteractiveNotificationTitle(ctx: ExtensionContext): void {
  if (ctx.mode !== "tui") return;
  const repository = notificationRepositoryLabel(ctx.cwd);
  if (repository) ctx.ui.setTitle(`pi — ${repository}`);
}

function finalAssistantText(
  messages: AgentEndEvent["messages"],
): string | undefined {
  const finalAssistant = [...messages]
    .reverse()
    .find((message) => message.role === "assistant");
  if (!finalAssistant) return;
  return finalAssistant.content
    .filter((content) => content.type === "text")
    .map((content) => content.text)
    .join("\n");
}

export function plannerAttentionSignals(
  messages: AgentEndEvent["messages"],
): PlannerAttentionSignal[] {
  const text = finalAssistantText(messages);
  if (!text) return [];
  const signals = new Set<PlannerAttentionSignal>();
  for (const line of text.split(/\r?\n/).map((line) => line.trim())) {
    if (line === PLANNER_ATTENTION_SIGNALS.TASK_COMPLETE)
      signals.add(PLANNER_ATTENTION_SIGNALS.TASK_COMPLETE);
  }
  return signals.size === 1 ? [...signals] : [];
}

async function notifyMessage(
  exec: Exec,
  message: string,
  platform: string,
  cwd?: string,
): Promise<void> {
  const { message: notificationMessage, repository } =
    contextualNotificationMessage(message, cwd);
  if (platform === "linux") {
    try {
      const args =
        process.env[NOTIFICATION_CONTEXT_ENV] === NOTIFICATION_CONTEXT_OPT_IN
          ? ["--app-name=b-agentic", notificationMessage]
          : [message];
      await exec("notify-send", args, {
        timeout: NOTIFICATION_TIMEOUT_MS,
      });
    } catch {
      // Missing or failing desktop notifiers must not disrupt Pi.
    }
    return;
  }
  if (platform === "darwin") {
    try {
      const args = repository
        ? ["-e", MACOS_CONTEXT_SCRIPT, notificationMessage]
        : ["-e", macosNotificationScript(message)];
      await exec("osascript", args, {
        timeout: NOTIFICATION_TIMEOUT_MS,
      });
    } catch {
      // Missing or failing desktop notifiers must not disrupt Pi.
    }
  }
}

export async function notifyDesktop(
  exec: Exec,
  signal: PlannerAttentionSignal,
  platform: string = process.platform,
  cwd?: string,
): Promise<void> {
  const message = NOTIFICATION_MESSAGES[signal];
  if (!message) return;
  await notifyMessage(exec, message, platform, cwd);
}

export async function notifyUserInputNeeded(
  exec: Exec,
  platform: string = process.platform,
  cwd?: string,
): Promise<void> {
  await notifyMessage(exec, USER_INPUT_NOTIFICATION, platform, cwd);
}

export default function bAgenticPlannerNotify(pi: ExtensionAPI): void {
  let lastAgentEndSignals: PlannerAttentionSignal[] = [];

  pi.on("session_start", (_event, ctx) => {
    setInteractiveNotificationTitle(ctx);
  });
  pi.on("agent_start", () => {
    lastAgentEndSignals = [];
  });
  pi.on("agent_end", ({ messages }) => {
    lastAgentEndSignals = plannerAttentionSignals(messages);
  });
  pi.on("tool_call", async (event: ToolCallEvent, ctx) => {
    if (getRole() !== "planner" || event.toolName !== "ask_user_question")
      return;
    await notifyUserInputNeeded(
      (command, args, options) => pi.exec(command, args, options),
      process.platform,
      ctx?.cwd,
    );
  });
  pi.on("agent_settled", async (_event, ctx) => {
    const signals = getRole() === "planner" ? lastAgentEndSignals : [];
    lastAgentEndSignals = [];
    for (const signal of signals) {
      await notifyDesktop(
        (command, args, options) => pi.exec(command, args, options),
        signal,
        process.platform,
        ctx?.cwd,
      );
    }
  });
}

export const __test__ = {
  MACOS_CONTEXT_SCRIPT,
  MACOS_SCRIPTS,
  NOTIFICATION_CONTEXT_ENV,
  NOTIFICATION_MESSAGES,
  NOTIFICATION_TIMEOUT_MS,
  PLANNER_ATTENTION_SIGNALS,
  USER_INPUT_NOTIFICATION,
  notifyDesktop,
  notifyUserInputNeeded,
  notificationRepositoryLabel,
  plannerAttentionSignals,
  setInteractiveNotificationTitle,
};
