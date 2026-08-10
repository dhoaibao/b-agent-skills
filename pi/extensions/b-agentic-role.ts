/** Role selection, persistence, coordination, and role model preferences. */
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { ROLE_ENTRY_TYPE, PLANNER_ALLOWED_TOOLS, parseRole, latestRoleState } from "./b-agentic-support/role.ts";
import { loadRoleModelPreferences, saveRoleModelPreference, type RoleModelPreference } from "./b-agentic-support/role-models.ts";
import { getRole, setRole, getToolsBeforePlanner, setToolsBeforePlanner } from "./b-agentic-support/state.ts";

type AvailableModel = ReturnType<ExtensionContext["modelRegistry"]["getAvailable"]>[number];
type ScopedModelContext = { scopedModels?: ReadonlyArray<{ model: AvailableModel }> };
type CoordinatedRole = "off" | "planner" | "worker";
type RoleSession = { id: string; cwd: string; name?: string; pid: number; startedAt: number };
type RoleChannel = {
  publish(payload: unknown, options?: { audience?: "owner" | "capable"; ownerOnly?: boolean }): void;
  listSessions(): Promise<RoleSession[]>;
};

function sameCwdSessionPosition(sessions: RoleSession[], cwd: string, pid: number): number | undefined {
  const ordered = sessions.filter((session) => session.cwd === cwd).sort((left, right) => left.startedAt - right.startedAt || left.id.localeCompare(right.id));
  const position = ordered.findIndex((session) => session.pid === pid);
  return position === -1 ? undefined : position;
}

function isFirstSameCwdSession(sessions: RoleSession[], cwd: string, pid: number): boolean {
  return sameCwdSessionPosition(sessions, cwd, pid) === 0;
}

function automaticRoleForSession(sessions: RoleSession[], cwd: string, pid: number): "planner" | "worker" | undefined {
  const position = sameCwdSessionPosition(sessions, cwd, pid);
  if (position === undefined) return undefined;
  return position === 1 ? "worker" : "planner";
}

function isAutomaticWorkerSession(sessions: RoleSession[], cwd: string, pid: number): boolean {
  return automaticRoleForSession(sessions, cwd, pid) === "worker";
}

function hasKnownSameCwdPeerRoles(sessions: RoleSession[], cwd: string, pid: number, peerRoles: ReadonlyMap<string, CoordinatedRole>): boolean {
  return sessions.filter((session) => session.cwd === cwd && session.pid !== pid).every((session) => peerRoles.has(session.id));
}

function canClaimWorker(sessions: RoleSession[], cwd: string, pid: number): boolean {
  const sameCwdSessions = sessions.filter((session) => session.cwd === cwd);
  return sameCwdSessions.length === 1 || automaticRoleForSession(sessions, cwd, pid) === "worker";
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
  let automaticRole = false;
  let pendingWorkerClaim = false;
  const peerRoles = new Map<string, CoordinatedRole>();

  const updateStatus = (ctx: ExtensionContext): void => {
    const role = getRole();
    ctx.ui.setStatus("b-agentic-role", role === "planner" ? "b-agentic: planner (read-only)" : role === "worker" ? "b-agentic: worker" : undefined);
  };
  const publishRole = (): void => {
    try { channel?.publish({ type: "b-agentic-role", role: getRole() }, { audience: "capable" }); } catch { /* Connection events retry publication. */ }
  };
  const requestPeerRoles = (): void => {
    try { channel?.publish({ type: "b-agentic-role-request" }, { audience: "capable" }); } catch { /* Connection events retry discovery. */ }
  };
  const persist = (): void => {
    pi.appendEntry(ROLE_ENTRY_TYPE, { role: getRole(), automatic: automaticRole, toolsBeforePlanner: getToolsBeforePlanner() });
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
  const chooseModel = async (role: "planner" | "worker", ctx: ExtensionContext): Promise<void> => {
    const scoped = (ctx as unknown as ScopedModelContext).scopedModels ?? [];
    const models = scoped.length > 0 ? scoped.map((entry) => entry.model) : ctx.modelRegistry.getAvailable();
    if (models.length === 0) {
      ctx.ui.notify("No authenticated models are available for this session", "warning");
      return;
    }
    const byKey = new Map(models.map((model) => [`${model.provider}/${model.id}`, model]));
    const preference = loadRoleModelPreferences()[role];
    const saved = preference ? `${preference.provider}/${preference.model}` : undefined;
    const selected = await ctx.ui.select(`Select model for b-agentic ${role}`, [...byKey.keys()].map((key) => key === saved ? `${key} (saved ${role} model)` : key));
    if (!selected) return;
    const key = selected.replace(/ \(saved (?:planner|worker) model\)$/, "");
    const model = byKey.get(key);
    if (!model) return;
    if (!await pi.setModel(model)) {
      ctx.ui.notify(`No configured authentication for ${key}`, "error");
      return;
    }
    saveModel(role, model);
    ctx.ui.notify(`b-agentic ${role} model set to ${key}`, "info");
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
    publishRole();
    updateStatus(ctx);
    if (shouldPersist) persist();
  };
  const resolvePendingWorkerClaim = async (ctx: ExtensionContext): Promise<void> => {
    if (!pendingWorkerClaim || !channel) return;
    try {
      const sessions = await channel.listSessions();
      if (!hasKnownSameCwdPeerRoles(sessions, ctx.cwd, process.pid, peerRoles)) return;
      if (!canClaimWorker(sessions, ctx.cwd, process.pid)) return;
      pendingWorkerClaim = false;
      if ([...peerRoles.entries()].some(([id, role]) => role === "worker" && sessions.some((session) => session.id === id && session.cwd === ctx.cwd))) {
        ctx.ui.notify("A same-CWD b-agentic worker is already active", "warning");
        return;
      }
      applyRole("worker", ctx);
    } catch {
      // Stay planner-safe until a connection or peer-role event retries the claim.
    }
  };
  const reconcileAutomaticRole = async (ctx: ExtensionContext): Promise<void> => {
    if (!automaticRole || !channel) return;
    try {
      const sessions = await channel.listSessions();
      const expectedRole = automaticRoleForSession(sessions, ctx.cwd, process.pid);
      if (!expectedRole || getRole() === expectedRole) return;
      if (expectedRole === "worker" && !hasKnownSameCwdPeerRoles(sessions, ctx.cwd, process.pid, peerRoles)) return;
      if (expectedRole === "worker" && [...peerRoles.entries()].some(([id, role]) => role === "worker" && sessions.some((session) => session.id === id && session.cwd === ctx.cwd))) return;
      applyRole(expectedRole, ctx);
    } catch {
      // The next connection or session event retries after a transient broker disconnect.
    }
  };
  const handleChannelEvent = async (event: RoleChannelEvent, ctx: ExtensionContext): Promise<void> => {
    if (event.type === "session_left") {
      peerRoles.delete(event.sessionId);
      await resolvePendingWorkerClaim(ctx);
      await reconcileAutomaticRole(ctx);
      return;
    }
    if (event.type === "connection" && event.connected && event.supported) {
      publishRole();
      requestPeerRoles();
      await resolvePendingWorkerClaim(ctx);
      await reconcileAutomaticRole(ctx);
      return;
    }
    if (event.type === "session_joined") {
      publishRole();
      await reconcileAutomaticRole(ctx);
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
      await reconcileAutomaticRole(ctx);
      return;
    }
  };

  pi.registerFlag("b-role", { description: "Set b-agentic role: planner or worker", type: "string" });
  pi.registerCommand("b-role", {
    description: "Choose b-agentic role and model: planner, worker, or off",
    getArgumentCompletions: (prefix) => ["planner", "worker", "off"].filter((role) => role.startsWith(prefix.trim().toLowerCase())).map((role) => ({ value: role, label: role })),
    handler: async (args, ctx) => {
      const explicitRole = parseRole(args);
      let next = explicitRole;
      if (!next && !args.trim() && ctx.hasUI) next = parseRole(await ctx.ui.select("Select b-agentic role", ["planner", "worker", "off"]));
      if (!next) {
        ctx.ui.notify(args.trim() ? "Usage: /b-role planner|worker|off" : `b-agentic role: ${getRole()}`, args.trim() ? "error" : "info");
        return;
      }
      automaticRole = false;
      pendingWorkerClaim = next === "worker";
      applyRole(next === "worker" ? "planner" : next, ctx);
      if (next !== "off") {
        if (explicitRole) await applySavedModel(next, ctx);
        else if (ctx.hasUI) await chooseModel(next, ctx);
      }
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
  pi.on("session_start", async (_event, ctx) => {
    const persisted = latestRoleState(ctx.sessionManager.getBranch());
    const flagRole = parseRole(pi.getFlag("b-role"));
    const legacyTools = persisted?.toolsBeforePlanner;
    setToolsBeforePlanner(legacyTools);
    automaticRole = !flagRole && (persisted?.automatic ?? !persisted);
    pendingWorkerClaim = flagRole === "worker";
    const selectedRole = pendingWorkerClaim ? "planner" : flagRole ?? (automaticRole ? "planner" : persisted?.role ?? "planner");
    applyRole(selectedRole, ctx, false);
    if (flagRole && flagRole !== "off") await applySavedModel(flagRole, ctx);
    if (legacyTools || (flagRole && !pendingWorkerClaim) || automaticRole) persist();
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

export const __test__ = { ROLE_ENTRY_TYPE, parseRole, latestRoleState, loadRoleModelPreferences, saveRoleModelPreference, isFirstSameCwdSession, automaticRoleForSession, isAutomaticWorkerSession, hasKnownSameCwdPeerRoles, canClaimWorker };
