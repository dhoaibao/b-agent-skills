import type { BAgenticRole } from "./role.ts";

type SharedState = {
  activeRole: BAgenticRole;
  autoModeEnabled: boolean;
};

const STATE_KEY = Symbol.for("b-agentic.shared-state");
const globalState = globalThis as typeof globalThis & { [key: symbol]: SharedState | undefined };
const state = globalState[STATE_KEY] ??= {
  activeRole: "off",
  autoModeEnabled: false,
};

export function getRole(): BAgenticRole { return state.activeRole; }
export function setRole(role: BAgenticRole): void { state.activeRole = role; }
export function isAutoModeEnabled(): boolean { return state.autoModeEnabled; }
export function setAutoModeEnabled(enabled: boolean): void { state.autoModeEnabled = enabled; }
