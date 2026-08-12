import type { BAgenticRole } from "./role.ts";

let activeRole: BAgenticRole = "off";
let toolsBeforePlanner: string[] | undefined;
let autoModeEnabled = false;

export function getRole(): BAgenticRole { return activeRole; }
export function setRole(role: BAgenticRole): void { activeRole = role; }
export function getToolsBeforePlanner(): string[] | undefined { return toolsBeforePlanner; }
export function setToolsBeforePlanner(value: string[] | undefined): void { toolsBeforePlanner = value; }
export function isAutoModeEnabled(): boolean { return autoModeEnabled; }
export function setAutoModeEnabled(enabled: boolean): void { autoModeEnabled = enabled; }
