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
import {
  loadPaneRole,
  paneRolePath,
  roleFromSessionFile,
  savePaneRole,
  terminalPaneId,
} from "./b-agentic-support/role-store.ts";
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
export type ReviewPeerRole = Exclude<BAgenticRole, "off">;
export const REVIEW_PEER_TOOL = "b_agentic_review_peer";
export const REVIEW_HANDOFF_SIGNAL = "B_AGENTIC_REVIEW_HANDOFF";
export const REVIEW_HANDOFF_PREFIX = `${REVIEW_HANDOFF_SIGNAL}\n`;

function isRecord(value: unknown): value is Record<string, unknown> {
  return Boolean(value && typeof value === "object" && !Array.isArray(value));
}
export function reviewHandoffOrigin(
  entries: readonly unknown[],
  cwd: string,
): string | undefined {
  for (let index = entries.length - 1; index >= 0; index -= 1) {
    const entry = entries[index];
    if (
      !isRecord(entry) ||
      entry.type !== "custom_message" ||
      entry.customType !== "intercom_message"
    )
      continue;
    const details = entry.details;
    if (
      !isRecord(details) ||
      !isRecord(details.from) ||
      !isRecord(details.message)
    )
      continue;
    const from = details.from;
    const message = details.message;
    const content = isRecord(message.content) ? message.content : undefined;
    if (
      from.cwd === cwd &&
      typeof from.id === "string" &&
      message.expectsReply === true &&
      message.replyTo === undefined &&
      typeof content?.text === "string" &&
      content.text.startsWith(REVIEW_HANDOFF_PREFIX)
    )
      return from.id;
  }
  return undefined;
}

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
export function compatibleSameCwdPeerForRole(
  sessions: RoleSession[],
  cwd: string,
  pid: number,
  peerRoles: ReadonlyMap<string, BAgenticRole>,
  role: ReviewPeerRole,
  expectedSessionId?: string,
): RoleSession | undefined {
  const peers = sameCwdPeers(sessions, cwd, pid);
  if (peers.length !== 1 || !peers.every((peer) => peerRoles.has(peer.id)))
    return undefined;
  const peer = peers[0];
  if (
    peerRoles.get(peer.id) !== role ||
    (expectedSessionId && peer.id !== expectedSessionId)
  )
    return undefined;
  return peer;
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
  /** Explicit selections survive into later sessions of the same terminal pane. */
  const persistPaneSelection = (
    role: BAgenticRole,
    ctx: ExtensionContext,
  ): void => {
    try {
      savePaneRole(ctx.cwd, role);
    } catch {
      // A session entry still preserves the choice when the durable file is unavailable.
    }
  };
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
  pi.registerTool({
    name: REVIEW_PEER_TOOL,
    label: "Find b-agentic review peer",
    description:
      "Return exactly one validated compatible same-CWD implementer or reviewer session for intercom targeting; successful lookups include canonical handoff or findings-return metadata; never sends a message or mutates the worktree.",
    promptSnippet:
      "Find one compatible same-CWD b-agentic peer and return canonical handoff metadata before an automatic handoff",
    promptGuidelines: [
      "Use b_agentic_review_peer before automatic review or findings handoffs; successful reviewer lookups return handoff.action, handoff.to, and exact handoff.messagePrefix for the ask, while successful implementer lookups return returnTarget.to for the findings handback. Never send a message or mutate the worktree.",
    ],
    parameters: {
      type: "object",
      properties: {
        role: {
          type: "string",
          enum: ["implementer", "reviewer"],
          description: "The compatible peer role to locate.",
        },
      },
      required: ["role"],
      additionalProperties: false,
    } as const,
    async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
      const role = params.role as ReviewPeerRole;
      requestPeerRoles();
      const expectedOrigin =
        role === "implementer"
          ? reviewHandoffOrigin(ctx.sessionManager.getBranch(), ctx.cwd)
          : undefined;
      if (role === "implementer" && !expectedOrigin)
        return {
          content: [
            {
              type: "text" as const,
              text: "No active B_AGENTIC_REVIEW_HANDOFF origin is available; report a coordination gap.",
            },
          ],
          details: { available: false, role, reason: "handoff-origin-missing" },
        };
      if (!channel)
        return {
          content: [
            {
              type: "text" as const,
              text: `No compatible same-CWD ${role} peer is available; report a coordination gap.`,
            },
          ],
          details: { available: false, role, reason: "channel-unavailable" },
        };
      try {
        const sessions = await channel.listSessions();
        const peer = compatibleSameCwdPeerForRole(
          sessions,
          ctx.cwd,
          process.pid,
          peerRoles,
          role,
          expectedOrigin,
        );
        if (!peer)
          return {
            content: [
              {
                type: "text" as const,
                text: `No unique compatible same-CWD ${role} peer is available; report a coordination gap.`,
              },
            ],
            details: { available: false, role, reason: "peer-unavailable" },
          };
        const successMetadata = expectedOrigin
          ? {
              originSessionId: expectedOrigin,
              returnTarget: {
                to: peer.id,
                originSessionId: expectedOrigin,
              },
            }
          : {
              handoff: {
                action: "ask" as const,
                to: peer.id,
                messagePrefix: REVIEW_HANDOFF_PREFIX,
              },
            };
        const successText = expectedOrigin
          ? `Compatible same-CWD implementer peer: ${peer.id}; use the returned returnTarget metadata for the intercom findings handback.`
          : `Compatible same-CWD reviewer peer: ${peer.id}; use the returned handoff metadata for the intercom ask.`;
        return {
          content: [
            {
              type: "text" as const,
              text: `${successText}\nCanonical intercom metadata: ${JSON.stringify(successMetadata)}`,
            },
          ],
          details: {
            available: true,
            role,
            sessionId: peer.id,
            ...successMetadata,
            protocolVersion: ROLE_PROTOCOL_VERSION,
          },
        };
      } catch {
        return {
          content: [
            {
              type: "text" as const,
              text: `Could not validate a compatible same-CWD ${role} peer; report a coordination gap.`,
            },
          ],
          details: { available: false, role, reason: "peer-validation-failed" },
        };
      }
    },
  });
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
      // Record the explicit request itself, so a claim that loses same-CWD
      // arbitration still retries in this pane's next session.
      persistPaneSelection(next, ctx);
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
  pi.on("session_start", async (event, ctx) => {
    const persistedRole = latestRoleState(ctx.sessionManager.getBranch())?.role;
    // A startup flag stays a one-session override. Otherwise a session keeps its
    // own recorded role, then continues its predecessor's role, then this
    // terminal pane's last explicit selection; an unrelated pane stays Off.
    const inheritedRole = event.previousSessionFile
      ? roleFromSessionFile(event.previousSessionFile)
      : undefined;
    const flagRole = parseRole(pi.getFlag("b-role"));
    const requestedRole =
      flagRole ?? persistedRole ?? inheritedRole ?? loadPaneRole(ctx.cwd);
    const continuesLineage = !flagRole && persistedRole === undefined;
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
    // Record a continued role in this session too, so its own successors keep
    // inheriting it; a pending implementer claim records only once it wins.
    const recordsSelection =
      flagRole !== undefined ||
      (continuesLineage && requestedRole !== undefined);
    if (recordsSelection && !pendingImplementerClaim) persist();
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
  compatibleSameCwdPeerForRole,
  reviewHandoffOrigin,
  loadPaneRole,
  savePaneRole,
  paneRolePath,
  terminalPaneId,
  roleFromSessionFile,
  REVIEW_PEER_TOOL,
  REVIEW_HANDOFF_SIGNAL,
  REVIEW_HANDOFF_PREFIX,
};
