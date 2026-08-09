import type { BAgenticRole, WorkerDirective } from "./role.ts";

let activeRole: BAgenticRole = "off";
let toolsBeforePlanner: string[] | undefined;
let currentDirective: WorkerDirective | undefined;
let skillLoaded = false;
let resultReported = false;
let reportedDirectiveIds = new Set<string>();
let knownSkills: Array<{ name: string; filePath: string }> = [];

export function getRole(): BAgenticRole { return activeRole; }
export function setRole(role: BAgenticRole): void { activeRole = role; }
export function getToolsBeforePlanner(): string[] | undefined { return toolsBeforePlanner; }
export function setToolsBeforePlanner(value: string[] | undefined): void { toolsBeforePlanner = value; }
export function getDirective(): WorkerDirective | undefined { return currentDirective; }
export function setDirective(value: WorkerDirective | undefined): void { currentDirective = value; }
export function isSkillLoaded(): boolean { return skillLoaded; }
export function setSkillLoaded(value: boolean): void { skillLoaded = value; }
export function isResultReported(): boolean { return resultReported; }
export function setResultReported(value: boolean): void { resultReported = value; }
export function getReportedDirectiveIds(): Set<string> { return reportedDirectiveIds; }
export function setReportedDirectiveIds(value: Set<string>): void { reportedDirectiveIds = value; }
export function getKnownSkills(): Array<{ name: string; filePath: string }> { return knownSkills; }
export function setKnownSkills(value: Array<{ name: string; filePath: string }>): void { knownSkills = value; }
export function resetWorkerState(): void {
  currentDirective = undefined;
  skillLoaded = false;
  resultReported = false;
  reportedDirectiveIds = new Set();
  knownSkills = [];
}
