import { createHash, randomBytes } from "node:crypto";
import {
  existsSync,
  mkdirSync,
  readFileSync,
  readlinkSync,
  renameSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { homedir } from "node:os";
import { basename, join, resolve } from "node:path";
import {
  ROLE_ENTRY_TYPE,
  ROLE_PROTOCOL_VERSION,
  latestRoleState,
  parseRole,
  type BAgenticRole,
} from "./role.ts";

type StoredPaneRole = {
  cwd?: unknown;
  pane?: unknown;
  role?: unknown;
  version?: unknown;
};

/** Terminal identities that survive a pi restart in the same pane. */
const PANE_ENVIRONMENT_KEYS = [
  "TMUX_PANE",
  "WEZTERM_PANE",
  "KITTY_WINDOW_ID",
  "ITERM_SESSION_ID",
  "TERM_SESSION_ID",
  "WINDOWID",
] as const;
/** Predecessor lookups stay bounded; a larger session file falls back to the pane record. */
const MAX_SESSION_FILE_BYTES = 32 * 1024 * 1024;

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return Boolean(value && typeof value === "object" && !Array.isArray(value));
}
export function projectKey(cwd: string): string {
  return resolve(cwd);
}
function ttyIdentity(): string | undefined {
  try {
    const link = readlinkSync("/proc/self/fd/0");
    return link.startsWith("/dev/") ? link : undefined;
  } catch {
    return undefined;
  }
}
/**
 * Identifies the terminal pane a session runs in, so a later session in that
 * pane restores its own role instead of another pane's selection. The parent
 * process is the last resort when no multiplexer or tty identity exists.
 */
export function terminalPaneId(
  env: NodeJS.ProcessEnv = process.env,
  parentPid: number = process.ppid,
): string {
  for (const key of PANE_ENVIRONMENT_KEYS) {
    const value = env[key];
    if (typeof value !== "string" || !value.trim()) continue;
    const server = key === "TMUX_PANE" ? (env.TMUX ?? "").split(",")[0] : "";
    return `${key}:${server}:${value.trim()}`;
  }
  const tty = ttyIdentity();
  return tty ? `tty:${tty}` : `ppid:${parentPid}`;
}
export function paneRolesDir(): string {
  return join(
    process.env.PI_CODING_AGENT_DIR ?? join(homedir(), ".pi", "agent"),
    "b-agentic",
    "roles",
  );
}
/**
 * Each pane and project pair owns an independent record, so concurrent sessions
 * never read-modify-write shared state and cannot drop one another's selection.
 */
export function paneRolePath(
  cwd: string,
  pane: string = terminalPaneId(),
  dir: string = paneRolesDir(),
): string {
  const key = `${projectKey(cwd)}\u0000${pane}`;
  const digest = createHash("sha256").update(key).digest("hex").slice(0, 16);
  const label =
    basename(projectKey(cwd))
      .replace(/[^A-Za-z0-9._-]/g, "-")
      .slice(0, 40) || "project";
  return join(dir, `${label}-${digest}.json`);
}
/** Unknown, legacy, or foreign stored values never activate a role. */
export function loadPaneRole(
  cwd: string,
  pane: string = terminalPaneId(),
  dir: string = paneRolesDir(),
): BAgenticRole | undefined {
  const path = paneRolePath(cwd, pane, dir);
  if (!existsSync(path)) return undefined;
  try {
    const parsed = JSON.parse(readFileSync(path, "utf8")) as unknown;
    if (!isPlainObject(parsed)) return undefined;
    const stored = parsed as StoredPaneRole;
    if (
      stored.cwd !== projectKey(cwd) ||
      stored.pane !== pane ||
      stored.version !== ROLE_PROTOCOL_VERSION
    )
      return undefined;
    return parseRole(stored.role);
  } catch {
    return undefined;
  }
}
export function savePaneRole(
  cwd: string,
  role: BAgenticRole,
  pane: string = terminalPaneId(),
  dir: string = paneRolesDir(),
): void {
  const path = paneRolePath(cwd, pane, dir);
  mkdirSync(dir, { recursive: true });
  const temporaryPath = `${path}.${process.pid}.${randomBytes(4).toString("hex")}.tmp`;
  const record: StoredPaneRole = {
    cwd: projectKey(cwd),
    pane,
    role,
    version: ROLE_PROTOCOL_VERSION,
  };
  writeFileSync(temporaryPath, `${JSON.stringify(record, null, 2)}\n`, "utf8");
  renameSync(temporaryPath, path);
}
/**
 * Reads the role a predecessor session ended with, so a new, forked, or
 * imported session continues its own lineage rather than a shared default.
 */
export function roleFromSessionFile(file: string): BAgenticRole | undefined {
  try {
    if (!existsSync(file) || statSync(file).size > MAX_SESSION_FILE_BYTES)
      return undefined;
    const lines = readFileSync(file, "utf8").split("\n");
    for (let index = lines.length - 1; index >= 0; index -= 1) {
      const line = lines[index];
      if (!line.includes(ROLE_ENTRY_TYPE)) continue;
      let entry: unknown;
      try {
        entry = JSON.parse(line);
      } catch {
        continue;
      }
      const state = latestRoleState([entry]);
      if (state) return state.role;
    }
  } catch {
    /* An unreadable predecessor falls back to the pane record. */
  }
  return undefined;
}
