/** Persistence and bounded-input policy for the on-demand consultant. */
import { existsSync, mkdirSync, readFileSync, renameSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import type { ThinkingLevel } from "./role-models.ts";

export type ConsultModelPreference = {
  provider: string;
  model: string;
  thinkingLevel: ThinkingLevel;
};

export type ConsultMode = "solve" | "review-plan";
export type ConsultToolInput = {
  question: string;
  mode?: ConsultMode;
  context?: string;
  plan?: string;
};

export const CONSULT_THINKING_LEVELS: readonly ThinkingLevel[] = ["off", "minimal", "low", "medium", "high", "xhigh", "max"];
export const CONSULT_INPUT_LIMITS = {
  question: 4_000,
  context: 10_000,
  plan: 16_000,
  total: 28_000,
} as const;

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return Boolean(value && typeof value === "object" && !Array.isArray(value));
}

function isThinkingLevel(value: unknown): value is ThinkingLevel {
  return typeof value === "string" && CONSULT_THINKING_LEVELS.includes(value as ThinkingLevel);
}

function parsePreference(value: unknown): ConsultModelPreference | undefined {
  if (!isPlainObject(value) || typeof value.provider !== "string" || typeof value.model !== "string" || !isThinkingLevel(value.thinkingLevel)) return undefined;
  if (!value.provider.trim() || !value.model.trim()) return undefined;
  return { provider: value.provider, model: value.model, thinkingLevel: value.thinkingLevel };
}

export function consultModelPath(): string {
  return join(process.env.PI_CODING_AGENT_DIR ?? join(homedir(), ".pi", "agent"), "b-agentic", "consult-model.json");
}

export function loadConsultModelPreference(path = consultModelPath()): ConsultModelPreference | undefined {
  if (!existsSync(path)) return undefined;
  try {
    return parsePreference(JSON.parse(readFileSync(path, "utf8")));
  } catch {
    return undefined;
  }
}

export function saveConsultModelPreference(preference: ConsultModelPreference, path = consultModelPath()): void {
  mkdirSync(dirname(path), { recursive: true });
  const temporaryPath = `${path}.${process.pid}.tmp`;
  writeFileSync(temporaryPath, `${JSON.stringify(preference, null, 2)}\n`, "utf8");
  renameSync(temporaryPath, path);
}

export function isValidConsultToolInput(value: unknown): value is ConsultToolInput {
  if (!isPlainObject(value) || typeof value.question !== "string") return false;
  const keys = Object.keys(value);
  if (keys.some((key) => !["question", "mode", "context", "plan"].includes(key))) return false;
  if (!value.question.trim() || value.question.length > CONSULT_INPUT_LIMITS.question) return false;
  if (value.mode !== undefined && value.mode !== "solve" && value.mode !== "review-plan") return false;
  if (value.context !== undefined && (typeof value.context !== "string" || value.context.length > CONSULT_INPUT_LIMITS.context)) return false;
  if (value.plan !== undefined && (typeof value.plan !== "string" || value.plan.length > CONSULT_INPUT_LIMITS.plan)) return false;
  if (value.mode === "review-plan" && (typeof value.plan !== "string" || !value.plan.trim())) return false;
  const total = value.question.length + (value.context?.length ?? 0) + (value.plan?.length ?? 0);
  return total <= CONSULT_INPUT_LIMITS.total;
}

export const __test__ = {
  consultModelPath,
  loadConsultModelPreference,
  saveConsultModelPreference,
  isValidConsultToolInput,
  CONSULT_INPUT_LIMITS,
  CONSULT_THINKING_LEVELS,
};
