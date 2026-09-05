/** Explicit role selection, compatible peer discovery, and role model preferences. */
import type {
  ExtensionAPI,
  ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import {
  ROLE_ENTRY_TYPE,
  ROLE_PROTOCOL_VERSION,
  isCompatibleRolePayload,
  latestRoleState,
  parseRole,
  type BAgenticRole,
} from "./b-agentic-support/role.ts";
import {
  loadRoleModelPreferences,
  saveRoleModelPreference,
} from "./b-agentic-support/role-models.ts";
import { getRole, setRole } from "./b-agentic-support/state.ts";

type RoleSession = {
  id: string;
  cwd: string;
  name?: string;
  pid: number;
  startedAt: number;
};
type RoleChannel = {
  publish(
    payload: unknown,
    options?: { audience?: "owner" | "capable"; ownerOnly?: boolean },
  ): void;
  listSessions(): Promise<RoleSession[]>;
};
type RoleChannelEvent =
  | { type: "connection"; connected: boolean; supported: boolean }
  | { type: "session_joined" }
  | { type: "session_left"; sessionId: string }
  | { type: "message"; fromSessionId: string; payload: unknown };

function sameCwdPeers(
  sessions: RoleSession[],
  cwd: string,
  pid: number,
): RoleSession[] {
  return sessions.filter(
    (session) => session.cwd === cwd && session.pid !== pid,
  );
}
function hasCompatibleSameCwdPeerRoles(
  sessions: RoleSession[],
  cwd: string,
  pid: number,
  peerRoles: ReadonlyMap<string, BAgenticRole>,
): boolean {
  return sameCwdPeers(sessions, cwd, pid).every((peer) =>
    peerRoles.has(peer.id),
  );
}
function hasActiveSameCwdPeerImplementer(
  sessions: RoleSession[],
  cwd: string,
  pid: number,
  peerRoles: ReadonlyMap<string, BAgenticRole>,
): boolean {
  return sameCwdPeers(sessions, cwd, pid).some(
    (peer) => peerRoles.get(peer.id) === "implementer",
  );
}
function canClaimImplementer(
  sessions: RoleSession[],
  cwd: string,
  pid: number,
): boolean {
  return sameCwdPeers(sessions, cwd, pid).length <= 1;
}
function preferredImplementerId(
  sessions: RoleSession[],
  cwd: string,
  pid: number,
  peerRoles: ReadonlyMap<string, BAgenticRole>,
): string | undefined {
  return sessions
    .filter(
      (session) =>
        session.cwd === cwd &&
        (session.pid === pid || peerRoles.get(session.id) === "implementer"),
    )
    .map((session) => session.id)
    .sort((left, right) => left.localeCompare(right))[0];
}

export default function bAgenticRole(pi: ExtensionAPI): void {
  let channel: RoleChannel | undefined;
  let applyingSavedModel = false;
  let pendingImplementerClaim = false;
  let pendingImplementerModel = false;
  const peerRoles = new Map<string, BAgenticRole>();

  const updateStatus = (ctx: ExtensionContext): void => {
    const role = getRole();
    const status =
      role === "implementer"
        ? ctx.ui.theme.getColorMode() === "truecolor"
          ? "\x1b[38;2;0;215;255mb-agentic: implementer\x1b[39m"
          : "\x1b[38;5;45mb-agentic: implementer\x1b[39m"
        : role === "reviewer"
          ? ctx.ui.theme.fg("success", "b-agentic: reviewer")
          : undefined;
    ctx.ui.setStatus("b-agentic-role", status);
  };
  const publishRole = (): void => {
    try {
      channel?.publish(
        {
          type: "b-agentic-role",
          version: ROLE_PROTOCOL_VERSION,
          role: getRole(),
        },
        { audience: "capable" },
      );
    } catch {
      /* Retry on a connection event. */
    }
  };
  const requestPeerRoles = (): void => {
    try {
      channel?.publish(
        { type: "b-agentic-role-request", version: ROLE_PROTOCOL_VERSION },
        { audience: "capable" },
      );
    } catch {
      /* Retry on a connection event. */
    }
  };
  const persist = (): void =>
    pi.appendEntry(ROLE_ENTRY_TYPE, {
      role: getRole(),
      version: ROLE_PROTOCOL_VERSION,
    });
  const saveModel = (
    role: Exclude<BAgenticRole, "off">,
    model: { provider: string; id: string },
  ): void =>
    saveRoleModelPreference(role, {
      provider: model.provider,
      model: model.id,
      thinkingLevel: pi.getThinkingLevel(),
    });
  const applySavedModel = async (
    role: Exclude<BAgenticRole, "off">,
    ctx: ExtensionContext,
  ): Promise<boolean> => {
    const preference = loadRoleModelPreferences()[role];
    if (!preference) return false;
    const model = ctx.modelRegistry.find(preference.provider, preference.model);
    if (!model) {
      ctx.ui.notify(
        `b-agentic ${role} model is unavailable: ${preference.provider}/${preference.model}`,
        "warning",
      );
      return false;
    }
    applyingSavedModel = true;
    try {
      if (!(await pi.setModel(model))) {
        ctx.ui.notify(
          `b-agentic ${role} model has no configured authentication: ${preference.provider}/${preference.model}`,
          "warning",
        );
        return false;
      }
      if (preference.thinkingLevel)
        pi.setThinkingLevel(preference.thinkingLevel);
      return true;
    } finally {
      applyingSavedModel = false;
    }
  };
  const applyRole = (
    role: BAgenticRole,
    ctx: ExtensionContext,
    shouldPersist = true,
  ): void => {
    setRole(role);
    publishRole();
    updateStatus(ctx);
    if (shouldPersist) persist();
  };
  const resolvePendingImplementerClaim = async (
    ctx: ExtensionContext,
  ): Promise<void> => {
    if (!pendingImplementerClaim || !channel) return;
    try {
      const sessions = await channel.listSessions();
      if (
        !hasCompatibleSameCwdPeerRoles(
          sessions,
          ctx.cwd,
          process.pid,
          peerRoles,
        ) ||
        !canClaimImplementer(sessions, ctx.cwd, process.pid)
      )
        return;
      pendingImplementerClaim = false;
      const shouldApplySavedModel = pendingImplementerModel;
      pendingImplementerModel = false;
      if (
        hasActiveSameCwdPeerImplementer(
          sessions,
          ctx.cwd,
          process.pid,
          peerRoles,
        )
      ) {
        ctx.ui.notify(
          "A same-CWD b-agentic implementer is already active",
          "warning",
        );
        return;
      }
      applyRole("implementer", ctx);
      if (shouldApplySavedModel) await applySavedModel("implementer", ctx);
    } catch {
      /* Remain Off until compatible discovery completes. */
    }
  };
  const resolveImplementerCollision = async (
    ctx: ExtensionContext,
  ): Promise<void> => {
    if (getRole() !== "implementer" || !channel) return;
    try {
      const sessions = await channel.listSessions();
      const self = sessions.find(
        (session) => session.cwd === ctx.cwd && session.pid === process.pid,
      );
      if (
        !self ||
        preferredImplementerId(sessions, ctx.cwd, process.pid, peerRoles) !==
          self.id
      ) {
        applyRole("off", ctx);
        ctx.ui.notify(
          "A same-CWD implementer claim won; remaining Off",
          "warning",
        );
      }
    } catch {
      applyRole("off", ctx);
      ctx.ui.notify(
        "Could not resolve a same-CWD implementer claim; remaining Off",
        "warning",
      );
    }
  };
  const handleChannelEvent = async (
    event: RoleChannelEvent,
    ctx: ExtensionContext,
  ): Promise<void> => {
    if (event.type === "session_left") {
      peerRoles.delete(event.sessionId);
      await resolvePendingImplementerClaim(ctx);
      return;
    }
    if (event.type === "connection" && event.connected && event.supported) {
      publishRole();
      requestPeerRoles();
      await resolvePendingImplementerClaim(ctx);
      return;
    }
    if (event.type === "session_joined") {
      publishRole();
      return;
    }
    if (
      event.type !== "message" ||
      !event.payload ||
      typeof event.payload !== "object"
    )
      return;
    const payload = event.payload as Record<string, unknown>;
    if (
      payload.type === "b-agentic-role-request" &&
      payload.version === ROLE_PROTOCOL_VERSION
    ) {
      publishRole();
      return;
    }
    if (isCompatibleRolePayload(payload)) {
      peerRoles.set(event.fromSessionId, payload.role);
      await resolvePendingImplementerClaim(ctx);
      if (payload.role === "implementer")
        await resolveImplementerCollision(ctx);
    }
  };

  pi.registerFlag("b-role", {
    description: "Set b-agentic role: off, implementer, or reviewer",
    type: "string",
  });
  pi.registerCommand("b-role", {
    description: "Set b-agentic role: implementer, reviewer, or off",
    getArgumentCompletions: (prefix) =>
      ["implementer", "reviewer", "off"]
        .filter((role) => role.startsWith(prefix.trim().toLowerCase()))
        .map((role) => ({ value: role, label: role })),
    handler: async (args, ctx) => {
      let next = parseRole(args);
      if (!next && !args.trim() && ctx.hasUI)
        next = parseRole(
          await ctx.ui.select("Select b-agentic role", [
            "implementer",
            "reviewer",
            "off",
          ]),
        );
      if (!next) {
        ctx.ui.notify(
          args.trim()
            ? "Usage: /b-role implementer|reviewer|off"
            : `b-agentic role: ${getRole()}`,
          args.trim() ? "error" : "info",
        );
        return;
      }
      pendingImplementerClaim = next === "implementer";
      pendingImplementerModel = next === "implementer";
      applyRole(next === "implementer" ? "off" : next, ctx);
      if (next === "reviewer") await applySavedModel("reviewer", ctx);
      if (pendingImplementerClaim) {
        requestPeerRoles();
        await resolvePendingImplementerClaim(ctx);
      }
      ctx.ui.notify(
        pendingImplementerClaim
          ? "b-agentic implementer request is waiting for compatible peer discovery"
          : `b-agentic role set to ${getRole()}`,
        pendingImplementerClaim ? "warning" : "info",
      );
    },
  });
  pi.on("model_select", (event) => {
    const role = getRole();
    if (!applyingSavedModel && role !== "off") {
      try {
        saveModel(role, event.model);
      } catch {
        /* Preference persistence cannot block selection. */
      }
    }
  });
  pi.on("thinking_level_select", (event) => {
    const role = getRole();
    if (applyingSavedModel || role === "off") return;
    try {
      const preference = loadRoleModelPreferences()[role];
      if (preference)
        saveRoleModelPreference(role, {
          ...preference,
          thinkingLevel: event.level,
        });
    } catch {
      /* Preference persistence cannot block selection. */
    }
  });
  pi.on("session_start", async (_event, ctx) => {
    const persistedRole = latestRoleState(ctx.sessionManager.getBranch())?.role;
    const flagRole = parseRole(pi.getFlag("b-role"));
    const requestedRole = flagRole ?? persistedRole;
    pendingImplementerClaim = requestedRole === "implementer";
    pendingImplementerModel = pendingImplementerClaim;
    const selectedRole = pendingImplementerClaim
      ? "off"
      : (requestedRole ?? "off");
    applyRole(selectedRole, ctx, false);
    const startupModelRole =
      flagRole && flagRole !== "off"
        ? flagRole
        : !pendingImplementerClaim && selectedRole !== "off"
          ? selectedRole
          : undefined;
    if (startupModelRole) await applySavedModel(startupModelRole, ctx);
    if (flagRole && !pendingImplementerClaim) persist();
    pi.events.emit("intercom:extension-register", {
      namespace: "b-agentic/roles/v2",
      ownerEligible: false,
      onReady: (nextChannel: RoleChannel) => {
        channel = nextChannel;
        publishRole();
        requestPeerRoles();
        void resolvePendingImplementerClaim(ctx);
      },
      onEvent: (event: RoleChannelEvent) => handleChannelEvent(event, ctx),
    });
  });
}

export const __test__ = {
  ROLE_ENTRY_TYPE,
  ROLE_PROTOCOL_VERSION,
  parseRole,
  latestRoleState,
  isCompatibleRolePayload,
  loadRoleModelPreferences,
  saveRoleModelPreference,
  hasCompatibleSameCwdPeerRoles,
  hasActiveSameCwdPeerImplementer,
  canClaimImplementer,
  preferredImplementerId,
};
