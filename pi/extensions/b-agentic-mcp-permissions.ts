/** Managed MCP, custom-tool, and Intercom approval policy. */
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import * as policy from "./b-agentic-support/mcp.ts";

let currentContext: ExtensionContext | undefined;

export default function bAgenticMcpPermissions(pi: ExtensionAPI): void {
  pi.on("tool_call", async (event, ctx) => {
    currentContext = ctx;
    const input = event.input;
    if (policy.isAutoApprovedIntercomCall(event.toolName, input)) return undefined;
    if (policy.isMcpOrCustomTool(event.toolName, input)) {
      if (!ctx.hasUI) return { block: true, reason: `Requires approval: custom/MCP tool ${event.toolName} (no UI; fail-closed)` };
      const preview = JSON.stringify(input ?? {}).slice(0, 400);
      const allowed = await ctx.ui.confirm(
        "b-agentic approval",
        `Requires approval: tool "${event.toolName}" may perform external or side-effecting work.\n\nInput:\n${preview}\n\nAllow this tool call?`,
      );
      return allowed ? undefined : { block: true, reason: `Requires approval: custom/MCP tool ${event.toolName} (denied by user)` };
    }
    return undefined;
  });

  pi.events.on(policy.MCP_TOOL_APPROVAL_REQUEST_EVENT, (value) => {
    if (!policy.isMcpToolApprovalRequest(value)) return;
    const server = policy.normalizeServerId(value.serverName);
    if (policy.isTrustedManagedTool(server, value.originalToolName, value.args)) {
      value.claim(() => policy.brokerApprovalDecision(value, currentContext));
      return;
    }
    if (["direct", "resource"].includes(value.origin)) {
      value.claim(() => "abstain");
      return;
    }
    // Top-level proxy calls bypass the generic mcp handler, so unsafe and
    // unmanaged requests must use the broker rather than abstaining.
    value.claim(() => policy.brokerApprovalDecision(value, currentContext));
  });
}

export const __test__ = { ...policy };
