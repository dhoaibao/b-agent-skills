import { createHash, randomBytes } from "node:crypto";
import {
  existsSync,
  mkdirSync,
  readFileSync,
  renameSync,
  writeFileSync,
} from "node:fs";
import { homedir } from "node:os";
import { basename, join, resolve } from "node:path";
import { parseRole, type BAgenticRole } from "./role.ts";

type StoredProjectRole = { cwd?: unknown; role?: unknown };

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return Boolean(value && typeof value === "object" && !Array.isArray(value));
}
/** Explicit selections are scoped per project directory, not per session. */
export function projectKey(cwd: string): string {
  return resolve(cwd);
}
export function projectRolesDir(): string {
  return join(
    process.env.PI_CODING_AGENT_DIR ?? join(homedir(), ".pi", "agent"),
    "b-agentic",
    "roles",
  );
}
/**
 * Each project owns an independent record, so concurrent sessions in different
 * projects never read-modify-write shared state and cannot drop one another's
 * selection. The digest keeps distinct paths on distinct files.
 */
export function projectRolePath(cwd: string, dir = projectRolesDir()): string {
  const key = projectKey(cwd);
  const digest = createHash("sha256").update(key).digest("hex").slice(0, 16);
  const label =
    basename(key)
      .replace(/[^A-Za-z0-9._-]/g, "-")
      .slice(0, 40) || "project";
  return join(dir, `${label}-${digest}.json`);
}
/** Unknown, legacy, or malformed stored values never activate a role. */
export function loadProjectRole(
  cwd: string,
  dir = projectRolesDir(),
): BAgenticRole | undefined {
  const path = projectRolePath(cwd, dir);
  if (!existsSync(path)) return undefined;
  try {
    const parsed = JSON.parse(readFileSync(path, "utf8")) as unknown;
    if (!isPlainObject(parsed)) return undefined;
    const stored = parsed as StoredProjectRole;
    if (stored.cwd !== projectKey(cwd)) return undefined;
    return parseRole(stored.role);
  } catch {
    return undefined;
  }
}
export function saveProjectRole(
  cwd: string,
  role: BAgenticRole,
  dir = projectRolesDir(),
): void {
  const path = projectRolePath(cwd, dir);
  mkdirSync(dir, { recursive: true });
  const temporaryPath = `${path}.${process.pid}.${randomBytes(4).toString("hex")}.tmp`;
  const record: StoredProjectRole = { cwd: projectKey(cwd), role };
  writeFileSync(temporaryPath, `${JSON.stringify(record, null, 2)}\n`, "utf8");
  renameSync(temporaryPath, path);
}
