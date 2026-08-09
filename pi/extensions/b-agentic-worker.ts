/** Worker assignment, skill isolation, review state, and result validation. */
import { existsSync } from "node:fs";
import { homedir } from "node:os";
import { resolve } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { B_AGENTIC_SKILL_NAMES } from "./b-agentic-support/shell.ts";
import { workerResultValidation, bashReadsAnotherSkill, bashHasBraceFileOperand } from "./b-agentic-support/worker.ts";
import { latestWorkerDirective, pathsMatch, workerPrompt } from "./b-agentic-support/role.ts";
import { getRole, getDirective, setDirective, isSkillLoaded, setSkillLoaded, isResultReported, setResultReported, getReportedDirectiveIds, setReportedDirectiveIds, getKnownSkills, setKnownSkills } from "./b-agentic-support/state.ts";

let workerSkillPath: string | undefined;
let workerSkillPaths = new Set<string>();
let pendingReportedDirectiveId: string | undefined;

function isObject(value: unknown): value is Record<string, unknown> {
  return Boolean(value && typeof value === "object" && !Array.isArray(value));
}

function syncWorkerDirective(ctx: ExtensionContext, skills: Array<{ name: string; filePath: string }>): void {
  if (skills.length) setKnownSkills(skills);
  const known = getKnownSkills();
  const agentDir = process.env.PI_CODING_AGENT_DIR?.trim() || resolve(homedir(), ".pi", "agent");
  const fallback = [...B_AGENTIC_SKILL_NAMES].flatMap((name) => [resolve(agentDir, "skills", name, "SKILL.md"), resolve(ctx.cwd, "skills", name, "SKILL.md")]).filter((path) => existsSync(path));
  workerSkillPaths = new Set([...known.filter((skill) => B_AGENTIC_SKILL_NAMES.has(skill.name)).map((skill) => skill.filePath), ...fallback]);
  const available = known.length ? new Set(known.map((skill) => skill.name)) : undefined;
  const next = latestWorkerDirective(ctx.sessionManager.getBranch(), ctx.cwd, available);
  const nextPath = next?.skillName ? known.find((skill) => skill.name === next.skillName)?.filePath ?? [resolve(agentDir, "skills", next.skillName, "SKILL.md"), resolve(ctx.cwd, "skills", next.skillName, "SKILL.md")].find((path) => existsSync(path)) : undefined;
  if (next?.id === getDirective()?.id) { workerSkillPath = nextPath; return; }
  setDirective(next);
  setSkillLoaded(false);
  setResultReported(Boolean(next?.id && getReportedDirectiveIds().has(next.id)));
  pendingReportedDirectiveId = undefined;
  workerSkillPath = nextPath;
}

export default function bAgenticWorker(pi: ExtensionAPI): void {
  pi.on("before_agent_start", (event, ctx) => {
    if (getRole() !== "worker") return undefined;
    syncWorkerDirective(ctx, event.systemPromptOptions.skills ?? []);
    return { systemPrompt: `${event.systemPrompt}\n\n${workerPrompt(getDirective(), workerSkillPath, isSkillLoaded(), isResultReported())}` };
  });

  pi.on("tool_result", (event, ctx) => {
    if (getRole() !== "worker") return;
    const result = workerResultValidation(event.toolName, event.input, getDirective());
    if (result.isResult && pendingReportedDirectiveId) {
      if (!event.isError) {
        getReportedDirectiveIds().add(pendingReportedDirectiveId);
        setResultReported(true);
      } else setResultReported(false);
      pendingReportedDirectiveId = undefined;
      return;
    }
    if (isSkillLoaded() || !workerSkillPath || event.toolName !== "read" || event.isError) return;
    const pathValue = String((event.input as { path?: string }).path || "");
    if (pathsMatch(pathValue, workerSkillPath, ctx.cwd)) setSkillLoaded(true);
  });

  pi.on("turn_end", () => {
    if (getRole() === "worker") pi.appendEntry("b-agentic-role", { role: "worker", reportedDirectiveIds: [...getReportedDirectiveIds()] });
  });

  pi.on("tool_call", (event, ctx) => {
    if (getRole() !== "worker") return undefined;
    if ((!getDirective() || isResultReported() || getDirective()?.kind === "invalid" || getDirective()?.kind === "approved")) syncWorkerDirective(ctx, getKnownSkills());
    const input = event.input;
    if (event.toolName === "intercom" && isObject(input) && (input.action === "ask" || input.action === "reply")) return { block: true, reason: "b-agentic role loop uses Intercom send, never ask/reply" };
    if (event.toolName === "intercom" && isObject(input) && input.action === "send" && typeof input.message === "string" && /(?:^|\n)B_AGENTIC_(?:TASK|REVIEW)(?:\s+v1)?(?:\n|$)/m.test(input.message)) return { block: true, reason: "Worker mode cannot send task or review directives; delegation chains are forbidden" };
    const result = workerResultValidation(event.toolName, input, getDirective());
    if (result.isResult) {
      if (!result.valid) return { block: true, reason: result.reason };
      if (!isSkillLoaded()) return { block: true, reason: "Worker must load the assigned skill before reporting a result" };
      if (isResultReported()) return { block: true, reason: "Worker already reported this iteration" };
      setResultReported(true); pendingReportedDirectiveId = getDirective()?.id;
    }
    if (event.toolName === "intercom") return undefined;
    const directive = getDirective();
    if (isResultReported()) return { block: true, reason: "Worker mode is waiting for planner review of B_AGENTIC_RESULT" };
    if (!directive || directive.kind === "invalid" || directive.kind === "approved") return { block: true, reason: "Worker mode is waiting for a valid B_AGENTIC_TASK or changes_requested review" };
    if (event.toolName === "bash") {
      const command = String((input as { command?: string }).command || "");
      if (bashHasBraceFileOperand(command)) return { block: true, reason: "Worker mode blocks brace-expanded file operands; use explicit paths" };
      if (bashReadsAnotherSkill(command, workerSkillPath, workerSkillPaths, ctx.cwd)) return { block: true, reason: `Worker mode may not read a skill other than assigned ${directive.skillName}` };
    }
    const pathValue = event.toolName === "read" ? String((input as { path?: string }).path || "") : "";
    const readsAnother = event.toolName === "read" && workerSkillPath && [...workerSkillPaths].some((path) => pathsMatch(pathValue, path, ctx.cwd)) && !pathsMatch(pathValue, workerSkillPath, ctx.cwd);
    if (readsAnother) return { block: true, reason: `Worker mode may use only the assigned ${directive.skillName} skill` };
    if (!isSkillLoaded() && (!workerSkillPath || event.toolName !== "read" || !pathsMatch(pathValue, workerSkillPath, ctx.cwd))) return { block: true, reason: `Worker mode must read the assigned ${directive.skillName} SKILL.md before repository work` };
    return undefined;
  });
}

export const __test__ = { workerPrompt, latestWorkerDirective, workerResultValidation, bashReadsAnotherSkill, bashHasBraceFileOperand };
