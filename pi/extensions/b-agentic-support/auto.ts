export const AUTO_MODE_ENTRY_TYPE = "b-agentic-auto-mode";

export function parseAutoMode(value: unknown): boolean | undefined {
  if (typeof value === "boolean") return value;
  if (typeof value !== "string") return undefined;
  const normalized = value.trim().toLowerCase();
  if (["on", "enable", "enabled", "true", "yes"].includes(normalized)) return true;
  if (["off", "disable", "disabled", "false", "no"].includes(normalized)) return false;
  return undefined;
}

export function latestAutoModeState(entries: unknown[]): boolean | undefined {
  for (let index = entries.length - 1; index >= 0; index -= 1) {
    const entry = entries[index];
    if (!entry || typeof entry !== "object" || Array.isArray(entry)) continue;
    const record = entry as Record<string, unknown>;
    if (record.type !== "custom" || record.customType !== AUTO_MODE_ENTRY_TYPE) continue;
    const data = record.data;
    if (!data || typeof data !== "object" || Array.isArray(data)) continue;
    if (typeof (data as Record<string, unknown>).enabled === "boolean") {
      return (data as Record<string, unknown>).enabled as boolean;
    }
  }
  return undefined;
}
