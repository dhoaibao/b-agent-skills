/**
 * b-agentic shell/filesystem/local-tool policy for Pi.
 *
 * MCP/custom-tool approval and prompt-only collaboration roles live in their
 * purpose-specific sibling extensions.
 * This entry point remains the compatibility module for policy helpers and
 * owns only local command/path gates.
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import {
  ASK_COMMANDS, DENY_COMMANDS, SERVICE_COMMANDS, DANGEROUS_ASK_COMMANDS,
  commandDecision, nativePathDecision,
  isProtectedPath, isProtectedLocalPath, isInstalledBAgenticSkillPath,
  SPECIALIZED_TOOLS,
} from "./b-agentic-support/shell.ts";
import * as shell from "./b-agentic-support/shell.ts";
import * as mcp from "./b-agentic-support/mcp.ts";
import * as role from "./b-agentic-support/role.ts";

// Keep this standalone extension free of package-resolution dependencies.
const COMMIT_CONFIRMATION_PARAMETERS = {
  type: "object",
  properties: {
    proposal: { type: "string", description: "Exact commit messages and file paths proposed for staging." },
  },
  required: ["proposal"],
  additionalProperties: false,
};

export default function bAgenticPermissions(pi: ExtensionAPI): void {
  pi.registerTool({
    name: "b_agentic_confirm_commit",
    label: "Confirm commits",
    description: "Open a yes/no confirmation for the exact proposed commits. Call only after presenting the proposal to the user.",
    parameters: COMMIT_CONFIRMATION_PARAMETERS as any,
    async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
      if (!ctx.hasUI) {
        return {
          content: [{ type: "text", text: "No interactive UI is available; ask the user for text confirmation." }],
          details: { approved: false, uiAvailable: false },
        };
      }
      const approved = await ctx.ui.confirm("Confirm commits", `${params.proposal}\n\nStage and create these commits?`);
      return {
        content: [{ type: "text", text: approved ? "Commit creation approved." : "Commit creation declined." }],
        details: { approved, uiAvailable: true },
      };
    },
  });

  pi.on("tool_call", async (event, ctx) => {
    if (event.toolName === "bash") {
      const command = String((event.input as { command?: string }).command || "");
      const decision = commandDecision(command);
      if (decision.decision === "deny") return { block: true, reason: decision.reason };
      if (decision.decision === "ask") {
        if (!ctx.hasUI) return { block: true, reason: `${decision.reason} (no UI; fail-closed)` };
        const allowed = await ctx.ui.confirm(
          "b-agentic approval",
          `${decision.reason}\n\nCommand:\n${command}\n\nAllow this tool call?`,
        );
        return allowed ? undefined : { block: true, reason: `${decision.reason} (denied by user)` };
      }
      return undefined;
    }

    if (event.toolName === "write" || event.toolName === "edit" || event.toolName === "read") {
      const pathValue = String((event.input as { path?: string }).path || "");
      const decision = nativePathDecision(event.toolName, pathValue);
      if (decision.decision === "deny") return { block: true, reason: decision.reason };
      if (decision.decision === "ask") {
        if (!ctx.hasUI) return { block: true, reason: `${decision.reason} (no UI; fail-closed)` };
        const allowed = await ctx.ui.confirm("b-agentic approval", `${decision.reason}\n\nAllow this tool call?`);
        return allowed ? undefined : { block: true, reason: `${decision.reason} (denied by user)` };
      }
      return undefined;
    }

    return undefined;
  });
}

// Compatibility test surface. Domain tests should import the corresponding
// sibling extension, while existing consumers can continue importing this one.
export const __test__ = {
  ...shell,
  ...mcp,
  ...role,
};
