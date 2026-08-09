import { existsSync, realpathSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { delimiter, dirname, isAbsolute, relative, resolve } from "node:path";

import { baseName, expandLocalPath, normalizeTokens, splitShellSegments, tokenize, INTERPRETER_BASES } from "./shell.ts";
import { pathsMatch, protocolField } from "./role.ts";
import type { WorkerDirective } from "./role.ts";

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return Boolean(value && typeof value === "object" && !Array.isArray(value));
}

export function shellGlobExpression(pattern: string): string {
  let expression = "";
  for (let index = 0; index < pattern.length; index += 1) {
    const character = pattern[index];
    if (character === "*") {
      if (pattern[index + 1] === "*") {
        expression += ".*";
        index += 1;
      } else {
        expression += "[^/]*";
      }
      continue;
    }
    if (character === "?") {
      expression += "[^/]";
      continue;
    }
    if (character === "[") {
      const close = pattern.indexOf("]", index + 1);
      if (close > index + 1) {
        const content = pattern.slice(index + 1, close);
        const negated = content.startsWith("!") ? `^${content.slice(1)}` : content;
        expression += `[${negated.replace(/\\/g, "\\\\")}]`;
        index = close;
        continue;
      }
    }
    if (character === "{") {
      const close = pattern.indexOf("}", index + 1);
      if (close > index + 1) {
        const alternatives = pattern.slice(index + 1, close).split(",");
        if (alternatives.length > 1) {
          expression += `(?:${alternatives.map(shellGlobExpression).join("|")})`;
          index = close;
          continue;
        }
      }
    }
    expression += character.replace(/[.+^${}()|[\]\\]/g, "\\$&");
  }
  return expression;
}

export function shellPathPatternMatches(value: string, target: string, cwd: string): boolean {
  const optionValue = value.includes("=") ? value.slice(value.indexOf("=") + 1) : value;
  const candidate = optionValue.replace(/^(?:\d+)?(?:<|>|>>|&>|&>>)/, "").replace(/\\/g, "/");
  const gitPath = !/^[A-Za-z]:\//.test(candidate) && candidate.includes(":")
    ? candidate.slice(candidate.indexOf(":") + 1)
    : undefined;
  const values = gitPath ? [candidate, gitPath] : [candidate];
  const skillName = baseName(resolve(target, ".."));
  const targetPaths = [
    resolve(target),
    resolve(cwd, "skills", skillName, "SKILL.md"),
    resolve(cwd, skillName, "SKILL.md"),
    ...(baseName(cwd) === skillName ? [resolve(cwd, "SKILL.md")] : []),
  ].map((path) => path.replace(/\\/g, "/"));
  return values.some((pathValue) => {
    const normalizedValue = pathValue.replace(/\\/g, "/");
    if (!/[?*[\]{}]/.test(normalizedValue)) {
      const absoluteValue = resolve(cwd, normalizedValue).replace(/\\/g, "/");
      return normalizedValue === `${skillName}/SKILL.md` || normalizedValue.endsWith(`/${skillName}/SKILL.md`) ||
        targetPaths.includes(absoluteValue) || pathsMatch(normalizedValue, target, cwd);
    }
    const absolutePattern = (normalizedValue === "~" || normalizedValue.startsWith("~/"))
      ? expandLocalPath(normalizedValue)
      : resolve(cwd, normalizedValue);
    try {
      const matcher = new RegExp(`^${shellGlobExpression(absolutePattern.replace(/\\/g, "/"))}$`);
      return targetPaths.some((path) => matcher.test(path));
    } catch {
      return false;
    }
  });
}

export function searchCommandPathTokens(tokens: string[], start: number): string[] {
  const paths: string[] = [];
  let patternSeen = false;
  let filesMode = false;
  const patternOptions = new Set(["-e", "--regexp"]);
  const fileOptions = new Set(["-f", "--file", "--files-from", "--exclude-from", "--ignore-file"]);
  const includeOptions = new Set(["-g", "--glob", "--iglob", "--include"]);
  const ignoredValueOptions = new Set([
    "-A", "-B", "-C", "-d", "-D", "-j", "-m", "-M", "--after-context", "--before-context", "--binary-files",
    "--color", "--colors", "--context", "--context-separator", "--devices", "--directories", "--encoding", "--engine",
    "--exclude", "--exclude-dir", "--field-context-separator", "--field-match-separator", "--label", "--max-columns",
    "--max-count", "--max-depth", "--path-separator", "--replace", "--sort", "--sortr", "--threads", "--type",
    "--type-add", "--type-clear", "--type-not",
  ]);
  for (let index = start; index < tokens.length; index += 1) {
    const token = tokens[index];
    if (token === "--") continue;
    if (token === "--files") {
      filesMode = true;
      continue;
    }
    const optionName = token.includes("=") ? token.slice(0, token.indexOf("=")) : token;
    const inlineValue = token.includes("=") ? token.slice(token.indexOf("=") + 1) : undefined;
    const attachedPattern = token.startsWith("-e") && !token.startsWith("--") && token.length > 2;
    if (patternOptions.has(optionName) || attachedPattern) {
      patternSeen = true;
      if (!inlineValue && !attachedPattern) index += 1;
      continue;
    }
    const attachedFile = token.startsWith("-f") && !token.startsWith("--") && token.length > 2;
    if (fileOptions.has(optionName) || attachedFile) {
      const value = inlineValue ?? (attachedFile ? token.slice(2) : tokens[index + 1]);
      if (value) paths.push(value);
      if (!inlineValue && !attachedFile) index += 1;
      continue;
    }
    const attachedInclude = token.startsWith("-g") && !token.startsWith("--") && token.length > 2;
    if (includeOptions.has(optionName) || attachedInclude) {
      const value = inlineValue ?? (attachedInclude ? token.slice(2) : tokens[index + 1]);
      if (value && !value.startsWith("!")) paths.push(value);
      if (!inlineValue && !attachedInclude) index += 1;
      continue;
    }
    if (ignoredValueOptions.has(optionName) || (tokens[0] === "rg" && optionName === "-r")) {
      if (!inlineValue) index += 1;
      continue;
    }
    if (token.startsWith("-")) continue;
    if (filesMode || patternSeen) paths.push(token);
    else patternSeen = true;
  }
  return paths;
}

export function shellSkillPathTokens(tokens: string[]): string[] {
  const redirections = tokens.filter((token) => /^(?:\d+)?</.test(token));
  if (tokens[0] === "rg" || tokens[0] === "grep") return [...redirections, ...searchCommandPathTokens(tokens, 1)];
  if (tokens[0] === "git" && tokens[1] === "grep") return [...redirections, ...searchCommandPathTokens(tokens, 2)];
  if (tokens[0] === "echo" || tokens[0] === "printf") return redirections;
  return tokens.slice(1);
}

export function jqFileTokens(tokens: string[]): string[] {
  const paths = tokens.filter((token) => /^(?:\d+)?</.test(token));
  let filterSeen = false;
  for (let index = 1; index < tokens.length; index += 1) {
    const token = tokens[index];
    if (token === "-f" || token === "--from-file") {
      if (tokens[index + 1]) paths.push(tokens[index + 1]);
      filterSeen = true;
      index += 1;
      continue;
    }
    if (token === "-L") {
      if (tokens[index + 1]) paths.push(tokens[index + 1]);
      index += 1;
      continue;
    }
    if (token === "--slurpfile" || token === "--rawfile" || token === "--argfile") {
      if (tokens[index + 2]) paths.push(tokens[index + 2]);
      index += 2;
      continue;
    }
    if (token === "--arg" || token === "--argjson") {
      index += 2;
      continue;
    }
    if (token.startsWith("-")) continue;
    if (filterSeen) paths.push(token);
    else filterSeen = true;
  }
  return paths;
}

export function shellBraceFileTokens(tokens: string[]): string[] {
  if (tokens[0] === "jq") return jqFileTokens(tokens);
  if (INTERPRETER_BASES.has(tokens[0]) && tokens.some((token) => ["-c", "-e", "-E", "-p", "-r", "--eval", "--print"].includes(token))) {
    return tokens.filter((token) => /^(?:\d+)?</.test(token));
  }
  if (tokens[0] === "git") {
    const values: string[] = [];
    for (let index = 1; index < tokens.length; index += 1) {
      if (["--format", "--pretty"].includes(tokens[index])) {
        index += 1;
        continue;
      }
      if (tokens[index].startsWith("--format=") || tokens[index].startsWith("--pretty=")) continue;
      values.push(tokens[index]);
    }
    return values;
  }
  return shellSkillPathTokens(tokens);
}

export function braceTokenLooksLikePath(token: string): boolean {
  const optionValue = token.includes("=") ? token.slice(token.indexOf("=") + 1) : token;
  const value = optionValue.replace(/^(?:\d+)?(?:<|>|>>|&>|&>>)/, "");
  return /[{}]/.test(value) && (/[\\/]/.test(value) || value.includes("SKILL") || /\.[A-Za-z0-9][A-Za-z0-9._-]*$/.test(value));
}

export function bashHasBraceFileOperand(command: string): boolean {
  return splitShellSegments(command).some((segment) =>
    shellBraceFileTokens(normalizeTokens(tokenize(segment))).some(braceTokenLooksLikePath));
}

export function bashReadsAnotherSkill(
  command: string,
  assignedSkillPath: string | undefined,
  skillPaths: ReadonlySet<string>,
  cwd: string,
): boolean {
  if (!assignedSkillPath) return false;
  if (bashHasBraceFileOperand(command)) return true;
  const otherSkills = [...skillPaths].filter((path) => !pathsMatch(path, assignedSkillPath, cwd));
  let segmentCwd = cwd;
  const directoryStack: string[] = [];
  for (const segment of splitShellSegments(command)) {
    const tokens = normalizeTokens(tokenize(segment));
    if (shellSkillPathTokens(tokens).some((token) =>
      otherSkills.some((path) => shellPathPatternMatches(token, path, segmentCwd)))) return true;
    if ((tokens[0] === "cd" || tokens[0] === "pushd") && tokens[1] && !tokens[1].startsWith("-")) {
      if (tokens[0] === "pushd") directoryStack.push(segmentCwd);
      segmentCwd = tokens[1] === "~" || tokens[1].startsWith("~/") ? expandLocalPath(tokens[1]) : resolve(segmentCwd, tokens[1]);
    } else if (tokens[0] === "popd" && directoryStack.length > 0) {
      segmentCwd = directoryStack.pop() || cwd;
    }
  }
  return false;
}

export function workerResultValidation(
  toolName: string,
  input: unknown,
  directive: WorkerDirective | undefined,
): { isResult: boolean; valid: boolean; reason: string } {
  if (toolName !== "intercom" || !isPlainObject(input) || input.action !== "send" || typeof input.message !== "string" ||
    !/(?:^|\n)B_AGENTIC_RESULT(?:\s+v1)?(?:\n|$)/m.test(input.message)) {
    return { isResult: false, valid: false, reason: "" };
  }
  if (!directive || (directive.kind !== "task" && directive.kind !== "changes_requested")) {
    return { isResult: true, valid: false, reason: "Worker result has no active assignment" };
  }
  const marker = /(?:^|\n)B_AGENTIC_RESULT(?:\s+v1)?\s*(?:\n|$)/m.exec(input.message);
  const body = input.message.slice(marker?.index ?? 0);
  const iteration = Number(protocolField(body, "iteration"));
  const valid = typeof input.to === "string" && input.to.trim().toLowerCase() === directive.reportTo?.trim().toLowerCase() &&
    protocolField(body, "status")?.toLowerCase() === "ready_for_review" &&
    protocolField(body, "worker_skill") === directive.skillName && iteration === directive.iteration &&
    Boolean(protocolField(body, "changed_paths") && protocolField(body, "verification") && protocolField(body, "gaps"));
  return {
    isResult: true,
    valid,
    reason: valid ? "" : "B_AGENTIC_RESULT must match report_to, worker_skill, iteration, status, changed_paths, verification, and gaps",
  };
}

