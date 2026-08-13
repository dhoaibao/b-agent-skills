import { existsSync } from "node:fs";
import { resolve } from "node:path";
import { isPlannerMcpToolName } from "./mcp.ts";
import { hasGitMutationRisk, hasInlineGitAliasInvocation, hasLocalFilesystemRisk, hasShellControlSyntax, hasUnbalancedQuotes, hasUnquotedGlob, hasUnsafeShellSyntax, isNegatedGlob, isProtectedPath, isProjectConfinedLocalPath, jqOperands, normalizeTokens, PROTECTED_PATH_MARKERS, splitShellSegments, tokenize, unwrapTokens } from "./shell.ts";

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return Boolean(value && typeof value === "object" && !Array.isArray(value));
}

export type BAgenticRole = "off" | "planner" | "worker";
export type RoleState = {
  role: BAgenticRole;
  automatic?: boolean;
  toolsBeforePlanner?: string[];
};

export const ROLE_ENTRY_TYPE = "b-agentic-role";

// generated:skill-ownership:start
/** Generated from skills/registry.yaml. Unknown skills fail closed to worker ownership. */
export type SkillOwner = "planner" | "worker";
export const SKILL_OWNERSHIP_CRITERION = "Planner-owned only when execution is read-only decision/planning, external research, audit/review, or release-summary coordination inside the planner boundary. Worker-owned when execution implements or mutates, diagnoses runtime behavior, builds/tests, performs browser/operational verification, commits, or otherwise requires worker capabilities. Mixed or uncertain skills are worker-owned.";
export const SKILL_OWNERS: Readonly<Record<string, SkillOwner>> = {
  "b-plan": "planner",
  "b-research": "planner",
  "b-design": "worker",
  "b-implement": "worker",
  "b-init": "worker",
  "b-refactor": "worker",
  "b-debug": "worker",
  "b-test": "worker",
  "b-browser": "worker",
  "b-agentic-audit": "planner",
  "b-review": "planner",
  "b-commit": "worker",
  "b-pr-summary": "planner"
};
export function skillOwner(skill: string): SkillOwner {
  return SKILL_OWNERS[skill] ?? "worker";
}
const PLANNER_OWNED_SKILLS = Object.entries(SKILL_OWNERS).filter(([, owner]) => owner === "planner").map(([skill]) => "`" + skill + "`");
const WORKER_OWNED_SKILLS = Object.entries(SKILL_OWNERS).filter(([, owner]) => owner === "worker").map(([skill]) => "`" + skill + "`");
// generated:skill-ownership:end

/** Tools that can perform planner-safe analysis; bash and MCP are checked again per operation. */
export const PLANNER_ALLOWED_TOOLS = new Set(["read", "recall", "intercom", "bash", "mcp"]);
const PLANNER_READ_COMMANDS = new Set(["bat", "batcat", "eza", "exa", "fd", "fdfind", "jq", "pwd", "rg"]);
const PLANNER_GIT_READ_COMMANDS = new Set(["annotate", "blame", "branch", "cat-file", "count-objects", "describe", "diff", "diff-tree", "for-each-ref", "fsck", "grep", "log", "ls-files", "ls-tree", "merge-base", "name-rev", "reflog", "remote", "rev-list", "rev-parse", "shortlog", "show", "show-ref", "stash", "status", "submodule", "tag", "verify-commit", "verify-tag", "version", "worktree"]);
const PLANNER_CODEGRAPH_COMMANDS = new Set(["affected", "callees", "callers", "explore", "files", "help", "impact", "init", "node", "query", "status", "version"]);

/** Planner tool surface includes base tools plus concretely namespaced, policy-checked MCP tools. */
export function isPlannerAllowedToolName(toolName: string): boolean {
  return PLANNER_ALLOWED_TOOLS.has(toolName) || isPlannerMcpToolName(toolName);
}

const SOURCE_FILE_EXTENSION = /(?:[cm]?[jt]sx?|py|rb|go|rs|java|kt|kts|c(?:c|pp|xx)?|h(?:pp)?|cs|php|swift|scala|vue|svelte|astro)$/i;

function isCompoundSourceGlob(base: string): boolean {
  const suffix = base.match(/^(?:credentials|secrets)\.(.+)$/i)?.[1];
  if (!suffix) return false;
  // Preserve shell.ts's compound-source exception for patterns such as
  // credentials.service* and credentials.*.ts without inventing a literal
  // path that may not exist.
  return /^[A-Za-z0-9_-]+(?:[?*\[])/.test(suffix) ||
    (suffix.includes("*") && SOURCE_FILE_EXTENSION.test(suffix.replace(/[?*\[\]]/g, "")));
}

function hasPlannerProtectedGlob(tokens: string[]): boolean {
  return tokens.some((token) => {
    if (isNegatedGlob(token) || !hasUnquotedGlob(token)) return false;
    if (/[?\[\]{}]/.test(token)) return true;
    const normalized = token.replace(/\\/g, "/");
    const segments = normalized.split("/");
    const base = segments.at(-1) ?? normalized;
    const staticPrefix = normalized.split(/[*?\[\]{}]/, 1)[0] || ".";
    const protectedDirectory = /(?:^|\/)(?:\.env|\.config\/gh|\.aws|\.kube|\.ssh|\.git)(?:\/|$)/i.test(normalized);
    const confinedPrefix = !staticPrefix.startsWith("..") && !staticPrefix.startsWith("/") && (isProjectConfinedLocalPath(staticPrefix) ||
      (isCompoundSourceGlob(base) && isProjectConfinedLocalPath(".")));
    if (!confinedPrefix || protectedDirectory) return true;
    if (isCompoundSourceGlob(base)) return false;
    if (/^(?:credentials|secrets)\*/i.test(base) || /(?:^|\/)(?:credentials|secrets)\/(?:\*|$)/i.test(normalized)) return true;
    const globPattern = new RegExp(`^${normalized
      .replace(/[.+^$()|\\\\*]/g, "\\\\$&")
      .replace(/\\\\\*/g, ".*")}$`, "i");
    const candidates = new Set<string>();
    for (const marker of PROTECTED_PATH_MARKERS) {
      const clean = marker.endsWith("/") ? marker.slice(0, -1) : marker;
      candidates.add(clean);
      candidates.add(`${clean}secret`);
      candidates.add(`x${clean}`);
      candidates.add(`foo/${clean}`);
      candidates.add(`foo/${clean}/secret`);
    }
    return [...candidates].some((candidate) => globPattern.test(candidate) && isProtectedPath(candidate));
  });
}

function hasPlannerGitGlobalOption(tokens: string[]): boolean {
  if (tokens[0] !== "git") return false;
  const safe = new Set(["--no-pager"]);
  for (let index = 1; index < tokens.length; index += 1) {
    const token = tokens[index]!;
    if (token === "--") return true;
    if (!token.startsWith("-")) return false;
    if (!safe.has(token)) return true;
  }
  return true;
}

function hasPlannerUnsafeGitOption(tokens: string[]): boolean {
  const separator = tokens.indexOf("--");
  const optionTokens = tokens.slice(0, separator < 0 ? tokens.length : separator);
  return optionTokens.some((token) =>
    token === "-o" || token.startsWith("-o") || token === "-O" || token.startsWith("-O") ||
      ["--ext-diff", "--filters", "--no-index", "--open-files-in-pager", "--output", "--textconv"].some((option) =>
        option.startsWith(token.split("=", 1)[0]) || token.startsWith(`${option}=`))
  );
}

function hasGitContentOutputRisk(tokens: string[]): boolean {
  const separator = tokens.indexOf("--");
  const options = tokens.slice(2, separator < 0 ? tokens.length : separator);
  return options.some((token) => token === "-p" || token === "-u" || token === "-c" || token === "--cc" ||
    ["--patch", "--patch-with-raw", "--patch-with-stat", "--binary", "--word-diff", "--color-words", "--textconv", "--ext-diff"].some((option) =>
      option.startsWith(token) || token.startsWith(option)));
}

function isProtectedGitPath(path: string): boolean {
  if (path.startsWith(":(")) return true; // Git pathspec magic is intentionally not interpreted here.
  const candidate = path.replace(/^:\/?/, "");
  if (isCompoundSourceGlob(candidate.split("/").at(-1) ?? candidate)) return false;
  return isProtectedPath(candidate) || isProtectedPath(`${candidate}/`) || isProtectedPath(candidate.replace(/[*?[\]{}]/g, "x"));
}

/** Reject protected pathspecs and revision:path object expressions before Git resolves historical content. */
function hasProtectedGitObjectOrPath(tokens: string[]): boolean {
  let operationIndex = 1;
  while (tokens[operationIndex] === "--no-pager") operationIndex += 1;
  for (let index = operationIndex + 1, afterSeparator = false; index < tokens.length; index += 1) {
    const token = tokens[index]!;
    if (token === "--") { afterSeparator = true; continue; }
    if (afterSeparator && isProtectedGitPath(token)) return true;
    if (!token.startsWith("-")) {
      const colon = token.lastIndexOf(":");
      if (colon >= 0 && isProtectedGitPath(token.slice(colon))) return true;
      // A standalone path operand may be accepted by several read operations; reject its protected form.
      if (isProtectedGitPath(token)) return true;
    }
  }
  return false;
}

function isSafeGitObjectPath(object: string): boolean {
  const colon = object.lastIndexOf(":");
  if (colon < 1) return false;
  const path = object.slice(colon + 1);
  return Boolean(path) && !path.startsWith("/") && !path.startsWith("(") && !/[*?[\]{}]/.test(path) && !isProtectedGitPath(path);
}

function isPlannerRevListReadOnly(tokens: string[]): boolean {
  const args = tokens.slice(2);
  // b-pr-summary needs bounded revision selection only. Object, filter, stdin, and
  // unrecognized output modes can enumerate historical protected-path objects.
  if (args.some((token) => token === "--stdin" || token.startsWith("--stdin=") || token.startsWith("--objects") || token.startsWith("--disk-usage") || token.startsWith("--filter") || token.startsWith("--filter-print-omitted"))) return false;
  if (!args.length || args[0] !== "-1" || args.length !== 2) return false;
  return !args[1]!.startsWith("-") && !/[\s]/.test(args[1]!);
}

function isPlannerCatFileReadOnly(tokens: string[]): boolean {
  const args = tokens.slice(2);
  const metadata = new Set(["-t", "-s", "-e", "--type", "--size", "--exists"]);
  if (args.length !== 2 || !metadata.has(args[0]!)) return false;
  const object = args[1]!;
  // Metadata for a single revision/object is safe; content output must name a checked path.
  return !object.startsWith("-") && !/[\s]/.test(object);
}

function isPlannerGitReadOnly(tokens: string[], rawTokens: string[]): boolean {
  const gitTokens = tokens[0] === "rtk" ? tokens.slice(1) : tokens;
  const operation = gitTokens[1];
  const gitRawTokens = rawTokens[0] === "rtk" ? rawTokens.slice(1) : rawTokens;
  if (!operation || hasPlannerGitGlobalOption(gitRawTokens) || hasPlannerUnsafeGitOption(gitRawTokens) || hasProtectedGitObjectOrPath(gitRawTokens)) return false;
  if (operation === "cat-file") return isPlannerCatFileReadOnly(gitTokens);
  if (operation === "rev-list") return isPlannerRevListReadOnly(gitTokens);
  if (operation === "reflog" && !["", "show", "list"].includes(gitTokens[2] || "")) return false;
  if (operation === "stash" && gitTokens[2] !== "list") return false;
  if (operation === "submodule" && (gitTokens[2] !== "status" || gitTokens.length !== 3)) return false;
  if (operation === "worktree" && (gitTokens[2] !== "list" || gitTokens.length !== 3)) return false;
  if (operation === "diff-tree" && hasGitContentOutputRisk(gitTokens)) return false;
  if (operation === "remote") {
    const remoteArgs = gitTokens.slice(2);
    return remoteArgs.length === 0 || remoteArgs.length === 1 && remoteArgs[0] === "-v" ||
      remoteArgs[0] === "get-url" ||
      (remoteArgs.includes("show") && remoteArgs.includes("-n") && remoteArgs.filter((token) => token !== "-n").length === 2);
  }
  if (hasGitMutationRisk(gitTokens)) return false;
  return true;
}

function isConfinedCodeGraphPath(path: string | undefined): boolean {
  return Boolean(path && !path.startsWith("-") && isProjectConfinedLocalPath(path));
}

export function plannerCodeGraphInitAllowed(path: string | undefined, cwd = process.cwd()): boolean {
  return (!path || resolve(cwd, path) === cwd) && !existsSync(resolve(cwd, ".codegraph"));
}

function isPositiveNumber(value: string | undefined): boolean {
  return Boolean(value && /^\d+$/.test(value) && Number(value) >= 0);
}

function isPlannerCodeGraphReadOnly(tokens: string[]): boolean {
  const operation = tokens[1];
  const rest = tokens.slice(2);
  if (!operation || rest.some((token) => token === "--force" || token.startsWith("--force="))) return false;
  if (rest.length === 1 && ["-h", "--help"].includes(rest[0]!)) return true;
  if (operation === "init") return rest.length <= 1 && plannerCodeGraphInitAllowed(rest[0]);
  if (operation === "status") return rest.every((token) => ["-j", "--json", "-h", "--help"].includes(token) || isConfinedCodeGraphPath(token)) && rest.filter((token) => !token.startsWith("-")).length <= 1;
  const schemas: Record<string, { path: string[]; value: string[]; number: string[]; flags: string[]; positionalPaths?: boolean }> = {
    affected: { path: ["-p", "--path"], value: ["-f", "--filter"], number: ["-d", "--depth"], flags: ["-j", "--json", "-q", "--quiet"], positionalPaths: true },
    callees: { path: ["-p", "--path"], value: [], number: ["-l", "--limit"], flags: ["-j", "--json"] },
    callers: { path: ["-p", "--path"], value: [], number: ["-l", "--limit"], flags: ["-j", "--json"] },
    impact: { path: ["-p", "--path"], value: [], number: ["-d", "--depth"], flags: ["-j", "--json"] },
    query: { path: ["-p", "--path"], value: ["-k", "--kind"], number: ["-l", "--limit"], flags: ["-j", "--json"] },
    explore: { path: ["-p", "--path"], value: [], number: ["--max-files"], flags: [] },
    node: { path: ["-p", "--path", "-f", "--file"], value: [], number: ["--offset", "--limit"], flags: ["--symbols-only"] },
    files: { path: ["-p", "--path", "--filter"], value: ["--pattern", "--format"], number: ["--max-depth"], flags: ["--no-metadata", "-j", "--json"] },
    help: { path: [], value: [], number: [], flags: [] }, version: { path: [], value: [], number: [], flags: [] },
  };
  const schema = schemas[operation];
  if (!schema) return false;
  for (let index = 0; index < rest.length; index += 1) {
    const token = rest[index]!;
    if (!token.startsWith("-")) { if (schema.positionalPaths && !isConfinedCodeGraphPath(token)) return false; continue; }
    const option = token.split("=", 1)[0]!;
    if (schema.flags.includes(token) || token === "-h" || token === "--help") continue;
    const value = token.includes("=") ? token.slice(token.indexOf("=") + 1) : rest[++index];
    if (schema.path.includes(option) && !isConfinedCodeGraphPath(value)) return false;
    if (schema.number.includes(option) && !isPositiveNumber(value)) return false;
    if (schema.value.includes(option) && !value) return false;
    if (![...schema.path, ...schema.value, ...schema.number].includes(option)) return false;
  }
  return true;
}

function optionTokens(tokens: string[]): string[] {
  const separator = tokens.indexOf("--");
  return tokens.slice(0, separator < 0 ? tokens.length : separator);
}

function hasOption(tokens: string[], options: string[]): boolean {
  return optionTokens(tokens).some((token) => options.some((option) => token === option || token.startsWith(`${option}=`) || option.length === 2 && token.startsWith(option) && token.length > option.length));
}

function hasUnsafeReadPathOption(tokens: string[], options: string[]): boolean {
  const optionsEnd = optionTokens(tokens).length;
  for (let index = 0; index < optionsEnd; index += 1) {
    const token = tokens[index]!;
    const option = options.find((candidate) => token === candidate || token.startsWith(`${candidate}=`) || candidate.length === 2 && token.startsWith(candidate) && token.length > candidate.length);
    if (option) {
      const value = token === option ? tokens[index + 1] : token.slice(option.length).replace(/^=/, "");
      if (!isConfinedCodeGraphPath(value)) return true;
    }
  }
  return false;
}

function jqInterpolationEnd(program: string, start: number): number | undefined {
  let depth = 1;
  for (let index = start; index < program.length; index += 1) {
    if (program[index] === "\\") { index += 1; continue; }
    if (program[index] === "(") depth += 1;
    if (program[index] === ")" && --depth === 0) return index;
  }
  return undefined;
}

function isUnsafeJqProgram(program: string | undefined): boolean {
  if (!program) return true;
  for (let index = 0; index < program.length;) {
    const char = program[index]!;
    if (char === '"') { // Scan interpolation bodies, but ignore literal string text.
      index += 1;
      while (index < program.length && program[index] !== '"') {
        if (program[index] === "\\" && program[index + 1] === "(") {
          const end = jqInterpolationEnd(program, index + 2);
          if (end === undefined || isUnsafeJqProgram(program.slice(index + 2, end))) return true;
          index = end + 1;
        } else index += program[index] === "\\" ? 2 : 1;
      }
      if (index >= program.length) return true;
      index += 1;
      continue;
    }
    if (char === "#") { while (index < program.length && program[index] !== "\n") index += 1; continue; }
    if (char === "$" && program.slice(index, index + 4) === "$ENV" && !/[A-Za-z0-9_]/.test(program[index + 4] ?? "")) return true;
    if (/[A-Za-z_]/.test(char)) {
      const start = index;
      while (/[A-Za-z0-9_]/.test(program[index] ?? "")) index += 1;
      const identifier = program.slice(start, index);
      const previous = program[start - 1] ?? "";
      if (identifier === "env" && previous !== ".") return true;
      if (identifier === "getenv" || (["include", "import", "module"].includes(identifier) && previous !== ".")) return true;
      continue;
    }
    index += 1;
  }
  return false;
}

function hasUnsafeShortOptionCluster(tokens: string[], unsafe: string): boolean {
  return optionTokens(tokens).some((token) => token.startsWith("-") && !token.startsWith("--") && token.slice(1).split("").some((flag) => unsafe.includes(flag)));
}

function hasUnsafeRgShortOption(tokens: string[]): boolean {
  const options = optionTokens(tokens);
  for (let index = 1; index < options.length; index += 1) {
    const token = options[index]!;
    if (token === "-e") { index += 1; continue; }
    if (token.startsWith("-e") && !token.startsWith("--")) continue; // attached `-ePATTERN`
    if (token.startsWith("-") && !token.startsWith("--") && /[Lu.f]/.test(token.slice(1))) return true;
  }
  return false;
}

function protectedSelectionGlob(value: string): boolean {
  if (!value || value.startsWith("!")) return false; // exclusion globs cannot expose paths
  const parts = value.replace(/\\/g, "/").split("/");
  if (parts.some((part) => /^\.env(?:[?*\[].*)?$/i.test(part))) return true;
  if (parts.some((part, index) => part === ".config" && parts[index + 1]?.startsWith("gh"))) return true;
  if (parts.some((part) => [".aws", ".kube", ".ssh", ".git"].includes(part))) return true;
  return parts.includes("**") && parts.some((part) => /^(?:credentials|secrets)(?:\.|\*|\[)/i.test(part));
}

function hasProtectedSelectionGlob(tokens: string[]): boolean {
  for (let index = 1; index < tokens.length; index += 1) {
    const token = tokens[index]!;
    let glob: string | undefined;
    if (token === "-g" || token === "--glob" || token === "--iglob") glob = tokens[++index];
    else if (token.startsWith("--glob=") || token.startsWith("--iglob=")) glob = token.slice(token.indexOf("=") + 1);
    else if (token.startsWith("-g") && token.length > 2) glob = token.slice(2);
    // `--exclude` and `--ignore-glob` only remove matches; they cannot expose protected files.
    else if (token === "--exclude" || token === "--ignore-glob") { index += 1; continue; }
    if (glob && protectedSelectionGlob(glob)) return true;
  }
  return false;
}

function hasAmbiguousJqProtectedProgram(segment: string, tokens: string[]): boolean {
  const parsed = jqOperands(tokens);
  if (!parsed.program || !isProtectedPath(parsed.program)) return false;
  const delimiter = segment.indexOf("--");
  if (delimiter < 0) return false;
  const afterDelimiter = segment.slice(delimiter + 2).trimStart();
  return !afterDelimiter.startsWith("'") && !afterDelimiter.startsWith('"');
}

function isPlannerReadCommand(commandName: string | undefined, tokens: string[]): boolean {
  if (!commandName || !PLANNER_READ_COMMANDS.has(commandName) || hasLocalFilesystemRisk(tokens, { allowUnquotedGlob: true })) return false;
  if (["fd", "fdfind"].includes(commandName)) return !hasOption(tokens, ["-l", "-L", "-x", "-X", "-H", "-I", "-u", "--exec", "--exec-batch", "--follow", "--list-details", "--hidden", "--no-ignore", "--unrestricted"]) && !hasUnsafeShortOptionCluster(tokens, "lLxXHIu") && !optionTokens(tokens).some((token) => token.startsWith("--no-ignore")) && !hasUnsafeReadPathOption(tokens, ["--base-directory", "--search-path", "--ignore-file"]);
  if (commandName === "rg") return hasOption(tokens, ["--no-config"]) && !hasOption(tokens, ["-L", "-u", "-.", "--follow", "--hidden", "--unrestricted", "--pre", "--pre-glob", "--hostname-bin", "--hyperlink-format"]) && !hasUnsafeRgShortOption(tokens) && !optionTokens(tokens).some((token) => token.startsWith("--no-ignore")) && !hasUnsafeReadPathOption(tokens, ["-f", "--file", "--ignore-file"]);
  if (["bat", "batcat"].includes(commandName)) return (optionTokens(tokens).includes("--paging=never") || optionTokens(tokens).some((token, index) => token === "--paging" && optionTokens(tokens)[index + 1] === "never")) && !hasOption(tokens, ["--pager", "--config-file"]);
  if (commandName === "jq") { const parsed = jqOperands(tokens); return parsed.valid && !parsed.externalProgram && !parsed.nullInput && !isUnsafeJqProgram(parsed.program); }
  if (["eza", "exa"].includes(commandName)) return !hasOption(tokens, ["-a", "-A", "-X", "--all", "--almost-all", "--dereference", "--follow-symlinks"]) && !hasUnsafeShortOptionCluster(tokens, "aAX") && !optionTokens(tokens).some((token, index) => token === "--absolute=follow" || token === "--absolute" && optionTokens(tokens)[index + 1] === "follow");
  return true;
}

/** Fail closed unless every shell segment is a direct local inspection command. */
export function plannerCommandDecision(command: string): { allowed: boolean; reason: string } {
  if (hasUnbalancedQuotes(command) || hasUnsafeShellSyntax(command) || hasShellControlSyntax(command)) {
    return { allowed: false, reason: "Planner mode permits only unambiguous read-only shell commands" };
  }
  const segments = splitShellSegments(command.trim());
  if (!segments.length) return { allowed: false, reason: "Planner mode requires a read-only shell command" };
  for (const segment of segments) {
    const rawTokens = tokenize(segment);
    if (/^[A-Za-z_][A-Za-z0-9_]*=/.test(rawTokens[0] ?? "")) return { allowed: false, reason: "Planner mode blocks environment-modified commands" };
    const unwrapped = unwrapTokens(rawTokens);
    if (unwrapped.opaque || [...unwrapped.wrappers].some((wrapper) => wrapper !== "rtk")) {
      return { allowed: false, reason: "Planner mode permits only direct read-only commands" };
    }
    const tokens = normalizeTokens(rawTokens);
    const commandName = tokens[0];
    const allowed = commandName === "git"
      ? PLANNER_GIT_READ_COMMANDS.has(tokens[1] ?? "") && !hasInlineGitAliasInvocation(unwrapped.tokens) && isPlannerGitReadOnly(tokens, unwrapped.tokens)
      : commandName === "codegraph"
        ? PLANNER_CODEGRAPH_COMMANDS.has(tokens[1] ?? "") && isPlannerCodeGraphReadOnly(tokens)
        : isPlannerReadCommand(commandName, tokens);
    if (hasPlannerProtectedGlob(rawTokens) || (["rg", "fd", "fdfind", "eza", "exa"].includes(commandName ?? "") && hasProtectedSelectionGlob(rawTokens)) || (commandName === "jq" && hasAmbiguousJqProtectedProgram(segment, tokens))) {
      return { allowed: false, reason: "Planner mode blocks protected-path globs" };
    }
    if (hasUnquotedGlob(segment) && !allowed) {
      return { allowed: false, reason: "Planner mode permits unquoted globs only for direct read-only commands" };
    }
    if (!allowed) return { allowed: false, reason: `Planner mode blocks non-read-only command: ${commandName || "unknown"}` };
  }
  return { allowed: true, reason: "" };
}

export const PLANNER_PROMPT = `## b-agentic planner profile (read-only coordinator)
You coordinate, review, and release; planner mode permits analysis only.
- Skill execution ownership is generated from the registry. Planner-owned: ${PLANNER_OWNED_SKILLS.join(", ")}; worker-owned: ${WORKER_OWNED_SKILLS.join(", ")}. This includes external b-research. ${SKILL_OWNERSHIP_CRITERION} Execute planner-owned skills only inside the read-only coordinator boundary. Delegate every worker-owned execution intent to a ready same-CWD worker. Ownership governs execution, not inspection: you may read any skill for planning, delegation, audit, or review. Direct user wording or no ready worker never permits planner implementation. Unknown or ambiguous skills fail closed to worker ownership.
- Finish discovery before one bounded handoff. Do not edit, emit patches, run builds/tests/repository scripts, commit, or fall back to implementation—even for a direct user request. The ready worker is the sole worktree writer. For audit/review verification you cannot run, request bounded worker evidence.
- Before a non-trivial handoff, concisely state applicable observable behavior, scope/non-goals, constraints/invariants, paths/symbols/evidence, acceptance criteria, validation expectations, and assumptions, pre-existing changes, or gaps. Natural language only; no message schema.
- Before every Intercom send/reply call pending. Reply to an inbound ask without send/list-cwd; otherwise refresh list-cwd and use only the returned identifier token verbatim. Its authoritative short ID is valid; never guess, reconstruct, extend, further abbreviate, or reuse stale output, display names, or aliases. Delivery makes the message real. On failure: pending, reply if required, else fresh list-cwd and one retry only if the peer is live; otherwise pause—never continue, commit, or close. The refresh is not polling; after handoff end the turn and wait for the worker send, with no sleep/status polling or ask to wait.
- Review the actual diff and verification against the latest approved plan, handoff, and clarifications. Only delegated worktree-changing tasks require actual b-review before approval. Return actionable findings with location, evidence, impact, violated baseline, smallest correction, and regression check; wait for the revised result. Generic review is insufficient.
- Resolve worker blockers by pending-first reply when evidence permits; otherwise ask the user one focused question and keep work open. After approval, the same worker may b-commit only on explicit user request and only if the reviewed snapshot is unchanged; changed content reopens review.`;

export function workerPrompt(): string {
  return `## b-agentic worker profile (implementation)
You are the sole worktree writer. Use the matching worker-owned skill; the planner owns external research and planner-owned scope decisions. ${SKILL_OWNERSHIP_CRITERION} Ownership governs execution, not inspection: both roles may read any skill. Unknown or ambiguous skills fail closed to worker ownership.
- Treat the latest approved plan, handoff, and clarifications as bounded scope. Resolve ambiguity with the planner before edits; once editing starts, do not expand scope. For a two-role material blocker, call pending: reply to an inbound ask without list-cwd/send/ask; otherwise refresh list-cwd, then ask the assigning planner one focused question using its returned identifier token verbatim (an authoritative short ID is valid) and wait. In solo/Off work ask the user.
- Before every Intercom send/reply call pending. Reply to an inbound ask without send/list-cwd; otherwise refresh list-cwd and target only its returned identifier token verbatim. An authoritative short ID is valid; never guess, reconstruct, extend, further abbreviate, or use stale output, display names, or aliases. Treat delivery as required. On failure: pending, reply if required, else fresh list-cwd and one retry only if the planner is live; otherwise pause without continuing, committing, or closing.
- When done, send implemented behavior, changed paths, acceptance coverage, exact checks/outcomes, and deviations, assumptions, or gaps to the assigning planner. For delegated worktree-changing work, explicitly ask for actual b-review against that baseline, then pause all edits. Resume only for findings or new work; fix, verify, and re-request review. Generic review is insufficient.
- After approval, remain idle unless the user explicitly requests b-commit. The same worker may commit only the unchanged reviewed snapshot; any content change reopens review.`;
}

export function parseRole(value: unknown): BAgenticRole | undefined {
  if (typeof value !== "string") return undefined;
  const role = value.trim().toLowerCase();
  return role === "off" || role === "planner" || role === "worker" ? role : undefined;
}

export function latestRoleState(entries: unknown[]): RoleState | undefined {
  for (let index = entries.length - 1; index >= 0; index -= 1) {
    const entry = entries[index];
    if (!isPlainObject(entry) || entry.type !== "custom" || entry.customType !== ROLE_ENTRY_TYPE || !isPlainObject(entry.data)) continue;
    const role = parseRole(entry.data.role);
    if (!role) continue;
    const tools = Array.isArray(entry.data.toolsBeforePlanner)
      ? entry.data.toolsBeforePlanner.filter((value): value is string => typeof value === "string")
      : undefined;
    return { role, automatic: entry.data.automatic === true, toolsBeforePlanner: tools };
  }
  return undefined;
}
