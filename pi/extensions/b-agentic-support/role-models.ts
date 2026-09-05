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
    typeof value.model !== "string"
  )
    return undefined;
  if (!value.provider.trim() || !value.model.trim()) return undefined;
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

export function loadRoleModelPreferences(
  path = roleModelsPath(),
): RoleModelPreferences {
  if (!existsSync(path)) return {};
  try {
    const parsed = JSON.parse(readFileSync(path, "utf8"));
    if (!isPlainObject(parsed)) return {};
    return {
      ...(parsePreference(parsed.planner)
        ? { planner: parsePreference(parsed.planner) }
        : {}),
      ...(parsePreference(parsed.worker)
        ? { worker: parsePreference(parsed.worker) }
        : {}),
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
  const preferences = loadRoleModelPreferences(path);
  preferences[role] = preference;
  mkdirSync(dirname(path), { recursive: true });
  const temporaryPath = `${path}.${process.pid}.tmp`;
  writeFileSync(
    temporaryPath,
    `${JSON.stringify(preferences, null, 2)}\n`,
    "utf8",
  );
  renameSync(temporaryPath, path);
}
