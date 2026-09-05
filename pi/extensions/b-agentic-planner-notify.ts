/** Legacy filename retained; privacy-safe implementer/reviewer attention notifications. */
import type {
  AgentEndEvent,
  ExtensionAPI,
  ToolCallEvent,
} from "@earendil-works/pi-coding-agent";
import { getRole } from "./b-agentic-support/state.ts";

export const REVIEW_ATTENTION_SIGNAL = "B_AGENTIC_REVIEW_COMPLETE";
export const USER_INPUT_NOTIFICATION = "User input needed";
export const REVIEW_COMPLETE_NOTIFICATION = "Review complete";
export const NOTIFICATION_CONTEXT_ENV = "B_AGENTIC_NOTIFICATION_CONTEXT";
const NOTIFICATION_CONTEXT_OPT_IN = "1";
export const NOTIFICATION_TIMEOUT_MS = 5_000;
const MACOS_TITLE = "b-agentic";
type Exec = (
  command: string,
  args: string[],
  options?: { timeout?: number },
) => Promise<unknown>;

export function notificationRepositoryLabel(
  cwd: string | undefined,
): string | undefined {
  if (
    process.env[NOTIFICATION_CONTEXT_ENV] !== NOTIFICATION_CONTEXT_OPT_IN ||
    !cwd
  )
    return;
  const candidate = [
    ...(cwd
      .replace(/[\\/]+$/, "")
      .split(/[\\/]/)
      .pop() ?? ""),
  ]
    .filter((character) => {
      const codePoint = character.codePointAt(0) ?? 0;
      return codePoint > 0x1f && (codePoint < 0x7f || codePoint > 0x9f);
    })
    .join("")
    .trim();
  return candidate &&
    candidate !== "." &&
    candidate !== ".." &&
    !candidate.includes("/") &&
    !candidate.includes("\\") &&
    !/^[A-Za-z]:?$/.test(candidate)
    ? candidate
    : undefined;
}
function messageWithContext(message: string, cwd?: string): string {
  const repository = notificationRepositoryLabel(cwd);
  return repository ? `${message} — ${repository}` : message;
}
export async function notifyDesktop(
  exec: Exec,
  message: string,
  platform = process.platform,
  cwd?: string,
): Promise<void> {
  const notification = messageWithContext(message, cwd);
  try {
    if (platform === "linux")
      await exec(
        "notify-send",
        process.env[NOTIFICATION_CONTEXT_ENV] === NOTIFICATION_CONTEXT_OPT_IN
          ? ["--app-name=b-agentic", notification]
          : [message],
        { timeout: NOTIFICATION_TIMEOUT_MS },
      );
    if (platform === "darwin")
      await exec(
        "osascript",
        [
          "-e",
          `display notification ${JSON.stringify(notification)} with title ${JSON.stringify(MACOS_TITLE)}`,
        ],
        { timeout: NOTIFICATION_TIMEOUT_MS },
      );
  } catch {
    /* Desktop notifier availability does not affect the workflow. */
  }
}
function finalAssistantText(messages: AgentEndEvent["messages"]): string {
  const assistant = [...messages]
    .reverse()
    .find((message) => message.role === "assistant");
  return (
    assistant?.content
      .filter((content) => content.type === "text")
      .map((content) => content.text)
      .join("\n") ?? ""
  );
}
export function hasReviewCompleteSignal(
  messages: AgentEndEvent["messages"],
): boolean {
  return finalAssistantText(messages)
    .split(/\r?\n/)
    .some((line) => line.trim() === REVIEW_ATTENTION_SIGNAL);
}
export default function bAgenticRoleNotify(pi: ExtensionAPI): void {
  let reviewCompleted = false;
  pi.on("agent_start", () => {
    reviewCompleted = false;
  });
  pi.on("agent_end", ({ messages }) => {
    reviewCompleted =
      getRole() === "reviewer" && hasReviewCompleteSignal(messages);
  });
  pi.on("tool_call", async (event: ToolCallEvent, ctx) => {
    if (
      getRole() !== "implementer" ||
      !ctx.hasUI ||
      event.toolName !== "ask_user_question"
    )
      return;
    await notifyDesktop(
      (command, args, options) => pi.exec(command, args, options),
      USER_INPUT_NOTIFICATION,
      process.platform,
      ctx.cwd,
    );
  });
  pi.on("agent_settled", async (_event, ctx) => {
    if (!reviewCompleted || getRole() !== "reviewer" || !ctx.hasUI) return;
    reviewCompleted = false;
    await notifyDesktop(
      (command, args, options) => pi.exec(command, args, options),
      REVIEW_COMPLETE_NOTIFICATION,
      process.platform,
      ctx.cwd,
    );
  });
}
export const __test__ = {
  REVIEW_ATTENTION_SIGNAL,
  USER_INPUT_NOTIFICATION,
  REVIEW_COMPLETE_NOTIFICATION,
  NOTIFICATION_CONTEXT_ENV,
  NOTIFICATION_TIMEOUT_MS,
  hasReviewCompleteSignal,
  notificationRepositoryLabel,
  notifyDesktop,
};
