/** Notify desktop users when a planner agent run settles. */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { getRole } from "./b-agentic-support/state.ts";

const NOTIFICATION_MESSAGE = "b-agentic planner finished";
const NOTIFICATION_TIMEOUT_MS = 5_000;
const MACOS_SCRIPT = `display notification "${NOTIFICATION_MESSAGE}" with title "b-agentic"`;
type Exec = (command: string, args: string[], options?: { timeout?: number }) => Promise<unknown>;

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
  pi.on("agent_settled", async () => {
    if (getRole() !== "planner") return;
    await notifyDesktop((command, args, options) => pi.exec(command, args, options));
  });
}

export const __test__ = { MACOS_SCRIPT, NOTIFICATION_MESSAGE, NOTIFICATION_TIMEOUT_MS, notifyDesktop };
