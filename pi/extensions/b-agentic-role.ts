/** Role selection, persistence, status, and planner tool restriction. */
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { ROLE_ENTRY_TYPE, PLANNER_ALLOWED_TOOLS, parseRole, latestRoleState } from "./b-agentic-support/role.ts";
import { getRole, setRole, getToolsBeforePlanner, setToolsBeforePlanner } from "./b-agentic-support/state.ts";

export default function bAgenticRole(pi: ExtensionAPI): void {
  const updateStatus = (ctx: ExtensionContext): void => {
    const role = getRole();
    ctx.ui.setStatus("b-agentic-role", role === "planner" ? "b-agentic: planner (read-only)" : role === "worker" ? "b-agentic: worker" : undefined);
  };
  const persist = (): void => {
    pi.appendEntry(ROLE_ENTRY_TYPE, {
      role: getRole(),
      toolsBeforePlanner: getToolsBeforePlanner(),
    });
  };
  const applyRole = (next: "off" | "planner" | "worker", ctx: ExtensionContext, shouldPersist = true): void => {
    const previous = getRole();
    if (previous === "planner" && next !== "planner" && getToolsBeforePlanner()) {
      pi.setActiveTools(getToolsBeforePlanner()!);
      setToolsBeforePlanner(undefined);
    }
    if (next === "planner") {
      const tools = getToolsBeforePlanner() ?? pi.getActiveTools();
      setToolsBeforePlanner(tools);
      pi.setActiveTools(tools.filter((name) => PLANNER_ALLOWED_TOOLS.has(name)));
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
