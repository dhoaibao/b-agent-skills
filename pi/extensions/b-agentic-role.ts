/** Role selection, persistence, coordination, and role model preferences. */
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { ROLE_ENTRY_TYPE, parseRole, latestRoleState } from "./b-agentic-support/role.ts";
import { loadRoleModelPreferences, saveRoleModelPreference, type RoleModelPreference } from "./b-agentic-support/role-models.ts";
import { getRole, setRole } from "./b-agentic-support/state.ts";

type CoordinatedRole = "off" | "planner" | "worker";
type RoleSession = { id: string; cwd: string; name?: string; pid: number; startedAt: number };
type RoleChannel = {
  publish(payload: unknown, options?: { audience?: "owner" | "capable"; ownerOnly?: boolean }): void;
  listSessions(): Promise<RoleSession[]>;
};

function hasKnownSameCwdPeerRoles(sessions: RoleSession[], cwd: string, pid: number, peerRoles: ReadonlyMap<string, CoordinatedRole>): boolean {
  return sessions.filter((session) => session.cwd === cwd && session.pid !== pid).every((session) => peerRoles.has(session.id));
}

function hasActiveSameCwdPeerWorker(sessions: RoleSession[], cwd: string, pid: number, peerRoles: ReadonlyMap<string, CoordinatedRole>): boolean {
  return sessions.some((session) => session.cwd === cwd && session.pid !== pid && peerRoles.get(session.id) === "worker");
}

function canClaimWorker(sessions: RoleSession[], cwd: string): boolean {
  return sessions.filter((session) => session.cwd === cwd).length <= 2;
}
type RoleChannelEvent =
  | { type: "connection"; connected: boolean; supported: boolean }
  | { type: "session_joined" }
  | { type: "session_left"; sessionId: string }
  | { type: "message"; fromSessionId: string; payload: unknown };

function isRole(value: unknown): value is CoordinatedRole {
  return value === "off" || value === "planner" || value === "worker";
}

export default function bAgenticRole(pi: ExtensionAPI): void {
  let applyingSavedModel = false;
  let channel: RoleChannel | undefined;
  let pendingWorkerClaim = false;
  let pendingWorkerModel = false;
  const peerRoles = new Map<string, CoordinatedRole>();

  const updateStatus = (ctx: ExtensionContext): void => {
    const role = getRole();
    const status = role === "planner"
      ? ctx.ui.theme.fg("success", "b-agentic: planner")
      : role === "worker"
        ? ctx.ui.theme.fg("accent", "b-agentic: worker")
        : undefined;
    ctx.ui.setStatus("b-agentic-role", status);
  };
  const publishRole = (): void => {
    try { channel?.publish({ type: "b-agentic-role", role: getRole() }, { audience: "capable" }); } catch { /* Connection events retry publication. */ }
  };
  const requestPeerRoles = (): void => {
    try { channel?.publish({ type: "b-agentic-role-request" }, { audience: "capable" }); } catch { /* Connection events retry discovery. */ }
  };
  const persist = (): void => {
    pi.appendEntry(ROLE_ENTRY_TYPE, { role: getRole(), automatic: false });
  };
  const saveModel = (role: "planner" | "worker", model: { provider: string; id: string }): void => {
    const preference: RoleModelPreference = { provider: model.provider, model: model.id, thinkingLevel: pi.getThinkingLevel() };
    saveRoleModelPreference(role, preference);
  };
  const applySavedModel = async (role: "planner" | "worker", ctx: ExtensionContext): Promise<boolean> => {
    const preference = loadRoleModelPreferences()[role];
    if (!preference) return false;
    const model = ctx.modelRegistry.find(preference.provider, preference.model);
    if (!model) {
      ctx.ui.notify(`b-agentic ${role} model is unavailable: ${preference.provider}/${preference.model}`, "warning");
      return false;
    }
    applyingSavedModel = true;
    try {
      if (!await pi.setModel(model)) {
        ctx.ui.notify(`b-agentic ${role} model has no configured authentication: ${preference.provider}/${preference.model}`, "warning");
        return false;
      }
      if (preference.thinkingLevel) pi.setThinkingLevel(preference.thinkingLevel);
      return true;
    } finally {
      applyingSavedModel = false;
    }
  };
  const applyRole = (next: "off" | "planner" | "worker", ctx: ExtensionContext, shouldPersist = true): void => {
    // Roles guide skill execution through their prompts; they never filter active tools.
    setRole(next);
    publishRole();
    updateStatus(ctx);
    if (shouldPersist) persist();
  };
  const resolvePendingWorkerClaim = async (ctx: ExtensionContext): Promise<void> => {
    if (!pendingWorkerClaim || !channel) return;
    try {
      const sessions = await channel.listSessions();
      if (!hasKnownSameCwdPeerRoles(sessions, ctx.cwd, process.pid, peerRoles)) return;
      if (!canClaimWorker(sessions, ctx.cwd)) return;
      pendingWorkerClaim = false;
      const shouldApplySavedModel = pendingWorkerModel;
      pendingWorkerModel = false;
      if (hasActiveSameCwdPeerWorker(sessions, ctx.cwd, process.pid, peerRoles)) {
        ctx.ui.notify("A same-CWD b-agentic worker is already active", "warning");
        return;
      }
      applyRole("worker", ctx);
      if (shouldApplySavedModel) await applySavedModel("worker", ctx);
    } catch {
      // Stay planner-safe until a connection or peer-role event retries the claim.
    }
  };
  const handleChannelEvent = async (event: RoleChannelEvent, ctx: ExtensionContext): Promise<void> => {
    if (event.type === "session_left") {
      peerRoles.delete(event.sessionId);
      await resolvePendingWorkerClaim(ctx);
      return;
    }
    if (event.type === "connection" && event.connected && event.supported) {
      publishRole();
      requestPeerRoles();
      await resolvePendingWorkerClaim(ctx);
      return;
    }
    if (event.type === "session_joined") {
      publishRole();
      return;
    }
    if (event.type !== "message" || !event.payload || typeof event.payload !== "object") return;
    const payload = event.payload as Record<string, unknown>;
    if (payload.type === "b-agentic-role-request") {
      publishRole();
      return;
    }
    if (payload.type === "b-agentic-role" && isRole(payload.role)) {
      peerRoles.set(event.fromSessionId, payload.role);
      await resolvePendingWorkerClaim(ctx);
      return;
    }
  };

  pi.registerFlag("b-role", { description: "Set b-agentic role: off, planner, or worker", type: "string" });
  pi.registerCommand("b-role", {
    description: "Set b-agentic role: planner, worker, or off",
    getArgumentCompletions: (prefix) => ["planner", "worker", "off"].filter((role) => role.startsWith(prefix.trim().toLowerCase())).map((role) => ({ value: role, label: role })),
    handler: async (args, ctx) => {
      const explicitRole = parseRole(args);
      let next = explicitRole;
      if (!next && !args.trim() && ctx.hasUI) next = parseRole(await ctx.ui.select("Select b-agentic role", ["planner", "worker", "off"]));
      if (!next) {
        ctx.ui.notify(args.trim() ? "Usage: /b-role planner|worker|off" : `b-agentic role: ${getRole()}`, args.trim() ? "error" : "info");
        return;
      }
      pendingWorkerClaim = next === "worker";
      pendingWorkerModel = next === "worker";
      applyRole(next === "worker" ? "planner" : next, ctx);
      if (next === "planner") await applySavedModel(next, ctx);
      if (pendingWorkerClaim) {
        requestPeerRoles();
        await resolvePendingWorkerClaim(ctx);
      }
      ctx.ui.notify(pendingWorkerClaim ? "b-agentic worker request is waiting for peer role discovery" : `b-agentic role set to ${getRole()}`, pendingWorkerClaim ? "warning" : "info");
    },
  });
  pi.on("before_agent_start", async (event, ctx) => {
    if (getRole() !== "planner" || !channel) return undefined;
    let sessions: RoleSession[];
    try { sessions = await channel.listSessions(); } catch { sessions = []; }
    const workers = sessions.filter((session) => session.cwd === ctx.cwd && peerRoles.get(session.id) === "worker");
    const roster = workers.length
      ? workers.map((worker) => `${worker.name ?? worker.id} (${worker.id})`).join(", ")
      : "none";
    return { systemPrompt: `${event.systemPrompt}\n\n## b-agentic worker roster\nReady same-CWD workers: ${roster}. Do not implement when this is none; provision or wait for a worker.` };
  });

  pi.on("model_select", (event) => {
    const role = getRole();
    if (applyingSavedModel || role === "off") return;
    try { saveModel(role, event.model); } catch { /* Preference persistence must not block model selection. */ }
  });
  pi.on("thinking_level_select", (event) => {
    const role = getRole();
    if (applyingSavedModel || role === "off") return;
    try {
      const preference = loadRoleModelPreferences()[role];
      if (!preference) return;
      saveRoleModelPreference(role, { ...preference, thinkingLevel: event.level });
    } catch { /* Preference persistence must not block thinking-level selection. */ }
  });
  pi.on("session_start", async (_event, ctx) => {
    const persisted = latestRoleState(ctx.sessionManager.getBranch());
    const flagRole = parseRole(pi.getFlag("b-role"));
    const legacyAutomatic = persisted?.automatic === true;
    const persistedRole = legacyAutomatic ? undefined : persisted?.role;
    pendingWorkerClaim = flagRole === "worker";
    pendingWorkerModel = false;
    const selectedRole = pendingWorkerClaim ? "planner" : flagRole ?? persistedRole ?? "off";
    applyRole(selectedRole, ctx, false);
    const startupModelRole = flagRole && flagRole !== "off"
      ? flagRole
      : !pendingWorkerClaim && selectedRole !== "off" ? selectedRole : undefined;
    if (startupModelRole) await applySavedModel(startupModelRole, ctx);
    if (flagRole && !pendingWorkerClaim) persist();
    pi.events.emit("intercom:extension-register", {
      namespace: "b-agentic/roles/v1",
      ownerEligible: false,
      onReady: (nextChannel: RoleChannel) => {
        channel = nextChannel;
      },
      onEvent: (event: RoleChannelEvent) => handleChannelEvent(event, ctx),
    });
  });
}

export const __test__ = { ROLE_ENTRY_TYPE, parseRole, latestRoleState, isRole, loadRoleModelPreferences, saveRoleModelPreference, hasKnownSameCwdPeerRoles, hasActiveSameCwdPeerWorker, canClaimWorker };
