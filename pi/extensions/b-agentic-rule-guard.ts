/** Teach-not-block warnings for high-signal b-agentic rule violations. */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const DANGEROUS_GIT = /(?:^|[;&|\n]\s*)(?:(?:env|sudo|rtk)\s+)*(?:[\w./-]+\/)?git(?:\s+-C\s+\S+)?\s+(push|pull|reset\s+--hard|clean\s+(?:-[a-z]*f[a-z]*\b|--force\b)|branch\s+-D)(?=\s|$)/g;
const READ_COMMAND = /(?:^|[;&|\n]\s*)(?:cat|head|tail|less|more|sed|awk|grep|rg|readlink|stat|file|wc)\b[^;&|]*?(?<![\w.-])([^\s;&|]*(?:\.env(?:\.[\w-]+)?|\.pem|credentials\.[^\s;&|/]+|secrets\.[^\s;&|/]+))(?=\s|$)/gi;
const SECRET_PATH = /(?:^|[/\s])((?:(?!(?:\.env\.(?:example|sample|template))(?=$|[/\s;&|]))\.env(?:\.[\w-]+)?|[^/\s;&|]+\.pem|credentials\.[^/\s;&|]+|secrets\.[^/\s;&|]+))(?=$|[/\s;&|])/i;

export function detectRuleViolations(toolName: string, argsJson: string): string[] {
  if (toolName !== "bash") return [];
  try {
    const args = JSON.parse(argsJson) as { command?: unknown };
    const command = typeof args?.command === "string" ? args.command : "";
    if (!command) return [];
    const violations: string[] = [];
    for (const match of command.matchAll(DANGEROUS_GIT)) violations.push(`forbidden git command: git ${match[1]}`);
    for (const match of command.matchAll(READ_COMMAND)) {
      const path = match[1];
      if (SECRET_PATH.test(path)) violations.push(`likely-secret read: ${path}`);
      SECRET_PATH.lastIndex = 0;
    }
    return [...new Set(violations)];
  } catch {
    return [];
  }
}

export default function bAgenticRuleGuard(pi: ExtensionAPI): void {
  pi.on("tool_call", (event, ctx) => {
    try {
      const toolName = typeof event.toolName === "string" ? event.toolName : "";
      const argsJson = JSON.stringify(event.input ?? {});
      const violations = detectRuleViolations(toolName, argsJson);
      if (violations.length) ctx.ui.notify(`b-agentic rule guard: ${violations.join("; ")}`, "warning");
    } catch {
      // Teaching warnings must never disrupt or block tool execution.
    }
  });
}

export const __test__ = { detectRuleViolations };
