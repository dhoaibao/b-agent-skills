/** Notify desktop users when a planner task passes b-review. */
import type { AgentEndEvent, ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { getRole } from "./b-agentic-support/state.ts";

const NOTIFICATION_MESSAGE = "Task done and passed b-review";
const NOTIFICATION_TIMEOUT_MS = 5_000;
const MACOS_SCRIPT = `display notification "${NOTIFICATION_MESSAGE}" with title "b-agentic"`;
const PASSING_REVIEW_VERDICT = /^(?:verdict\s*:\s*)?(?:READY FOR PR|READY WITH FOLLOW-UPS)[.!]?$/i;
type Exec = (command: string, args: string[], options?: { timeout?: number }) => Promise<unknown>;

function finalAssistantText(messages: AgentEndEvent["messages"]): string | undefined {
  const finalAssistant = [...messages].reverse().find((message) => message.role === "assistant");
  if (!finalAssistant) return;
  return finalAssistant.content
    .filter((content) => content.type === "text")
    .map((content) => content.text)
    .join("\n");
}

export function hasPassingReviewVerdict(messages: AgentEndEvent["messages"]): boolean {
  const text = finalAssistantText(messages);
  if (!text) return false;
  return text.split(/\r?\n/).some((line) => {
    const normalized = line.replace(/[`*_]/g, "").replace(/^\s*(?:[-*>]\s*|#{1,6}\s*)/, "").trim();
    return PASSING_REVIEW_VERDICT.test(normalized);
  });
}

export async function notifyDesktop(exec: Exec, platform: string = process.platform): Promise<void> {
  if (platform === "linux") {
    try {
      await exec("notify-send", [NOTIFICATION_MESSAGE], { timeout: NOTIFICATION_TIMEOUT_MS });
    } catch {
      // Missing or failing desktop notifiers must not disrupt Pi.
    }
    return;
  }
  if (platform === "darwin") {
    try {
      await exec("osascript", ["-e", MACOS_SCRIPT], { timeout: NOTIFICATION_TIMEOUT_MS });
    } catch {
      // Missing or failing desktop notifiers must not disrupt Pi.
    }
  }
}

export default function bAgenticPlannerNotify(pi: ExtensionAPI): void {
  let lastAgentEndPassedReview = false;

  pi.on("agent_start", () => {
    lastAgentEndPassedReview = false;
  });
  pi.on("agent_end", ({ messages }) => {
    lastAgentEndPassedReview = hasPassingReviewVerdict(messages);
  });
  pi.on("agent_settled", async () => {
    const shouldNotify = getRole() === "planner" && lastAgentEndPassedReview;
    lastAgentEndPassedReview = false;
    if (!shouldNotify) return;
    await notifyDesktop((command, args, options) => pi.exec(command, args, options));
  });
}

export const __test__ = { MACOS_SCRIPT, NOTIFICATION_MESSAGE, NOTIFICATION_TIMEOUT_MS, notifyDesktop, hasPassingReviewVerdict };
