import {
  existsSync,
  mkdirSync,
  readFileSync,
  renameSync,
  writeFileSync,
} from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import type { BAgenticRole } from "./role.ts";

export type ThinkingLevel =
  "off" | "minimal" | "low" | "medium" | "high" | "xhigh" | "max";
export type RoleModelPreference = {
  provider: string;
  model: string;
  thinkingLevel?: ThinkingLevel;
};
export type RoleModelKey = Exclude<BAgenticRole, "off">;
export type RoleModelPreferences = Partial<
  Record<RoleModelKey, RoleModelPreference>
>;
type StoredRoleModelPreferences = RoleModelPreferences &
  Partial<Record<"planner" | "worker", RoleModelPreference>>;
const THINKING_LEVELS = new Set<ThinkingLevel>([
  "off",
  "minimal",
  "low",
  "medium",
  "high",
  "xhigh",
  "max",
]);

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return Boolean(value && typeof value === "object" && !Array.isArray(value));
}
function parsePreference(value: unknown): RoleModelPreference | undefined {
  if (
    !isPlainObject(value) ||
    typeof value.provider !== "string" ||
    typeof value.model !== "string" ||
    !value.provider.trim() ||
    !value.model.trim()
  )
    return undefined;
  const thinkingLevel =
    typeof value.thinkingLevel === "string" &&
    THINKING_LEVELS.has(value.thinkingLevel as ThinkingLevel)
      ? (value.thinkingLevel as ThinkingLevel)
      : undefined;
  return {
    provider: value.provider,
    model: value.model,
    ...(thinkingLevel ? { thinkingLevel } : {}),
  };
}
export function roleModelsPath(): string {
  return join(
    process.env.PI_CODING_AGENT_DIR ?? join(homedir(), ".pi", "agent"),
    "b-agentic",
    "role-models.json",
  );
}
/** Legacy values map by role only; reading them never activates a role. */
export function loadRoleModelPreferences(
  path = roleModelsPath(),
): RoleModelPreferences {
  if (!existsSync(path)) return {};
  try {
    const parsed = JSON.parse(readFileSync(path, "utf8"));
    if (!isPlainObject(parsed)) return {};
    const implementer =
      parsePreference(parsed.implementer) ?? parsePreference(parsed.worker);
    const reviewer =
      parsePreference(parsed.reviewer) ?? parsePreference(parsed.planner);
    return {
      ...(implementer ? { implementer } : {}),
      ...(reviewer ? { reviewer } : {}),
    };
  } catch {
    return {};
  }
}
export function saveRoleModelPreference(
  role: RoleModelKey | "off",
  preference: RoleModelPreference,
  path = roleModelsPath(),
): void {
  if (role === "off") return;
  let stored: StoredRoleModelPreferences = {};
  if (existsSync(path)) {
    try {
      const parsed = JSON.parse(readFileSync(path, "utf8"));
      if (isPlainObject(parsed)) stored = parsed as StoredRoleModelPreferences;
    } catch {
      /* Replace malformed preference content only when saving a new explicit preference. */
    }
  }
  stored[role] = preference;
  mkdirSync(dirname(path), { recursive: true });
  const temporaryPath = `${path}.${process.pid}.tmp`;
  writeFileSync(temporaryPath, `${JSON.stringify(stored, null, 2)}\n`, "utf8");
  renameSync(temporaryPath, path);
}
