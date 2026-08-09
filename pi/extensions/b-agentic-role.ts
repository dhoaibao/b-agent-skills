/** Role selection, persistence, status, and legacy tool restoration. */
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { ROLE_ENTRY_TYPE, parseRole, latestRoleState } from "./b-agentic-support/role.ts";
import { getRole, setRole, getToolsBeforePlanner, setToolsBeforePlanner } from "./b-agentic-support/state.ts";

export default function bAgenticRole(pi: ExtensionAPI): void {
  const updateStatus = (ctx: ExtensionContext): void => {
    const role = getRole();
    ctx.ui.setStatus("b-agentic-role", role === "planner" ? "b-agentic: planner" : role === "worker" ? "b-agentic: worker" : undefined);
  };
  const persist = (): void => {
    pi.appendEntry(ROLE_ENTRY_TYPE, {
      role: getRole(),
      toolsBeforePlanner: getToolsBeforePlanner(),
    });
  };
  const applyRole = (next: "off" | "planner" | "worker", ctx: ExtensionContext, shouldPersist = true): void => {
    // Restore tools hidden by role state persisted by releases that enforced a
    // read-only planner. Current roles never alter Pi's active tool set.
    if (getToolsBeforePlanner()) {
      pi.setActiveTools(getToolsBeforePlanner()!);
      setToolsBeforePlanner(undefined);
    }
    setRole(next);
    updateStatus(ctx);
    if (shouldPersist) persist();
  };

  pi.registerFlag("b-role", { description: "Set b-agentic role: planner or worker", type: "string" });
  pi.registerCommand("b-role", {
    description: "Choose b-agentic role: planner, worker, or off",
    getArgumentCompletions: (prefix) => ["planner", "worker", "off"].filter((role) => role.startsWith(prefix.trim().toLowerCase())).map((role) => ({ value: role, label: role })),
    handler: async (args, ctx) => {
      let next = parseRole(args);
      if (!next && !args.trim() && ctx.hasUI) next = parseRole(await ctx.ui.select("Select b-agentic role", ["planner", "worker", "off"]));
      if (!next) {
        ctx.ui.notify(args.trim() ? "Usage: /b-role planner|worker|off" : `b-agentic role: ${getRole()}`, args.trim() ? "error" : "info");
        return;
      }
      applyRole(next, ctx);
      ctx.ui.notify(`b-agentic role set to ${next}`, "info");
    },
  });

  pi.on("session_start", (_event, ctx) => {
    const persisted = latestRoleState(ctx.sessionManager.getBranch());
    const flagRole = parseRole(pi.getFlag("b-role"));
    const legacyTools = persisted?.toolsBeforePlanner;
    setToolsBeforePlanner(legacyTools);
    const selectedRole = flagRole ?? persisted?.role ?? "off";
    applyRole(selectedRole, ctx, false);
    if (legacyTools || (flagRole && flagRole !== persisted?.role)) persist();
  });
}

export const __test__ = { ROLE_ENTRY_TYPE, parseRole, latestRoleState };
