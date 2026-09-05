import { createHash } from "node:crypto";

export type CandidateFile = {
  path: string;
  status: "tracked" | "untracked" | "derived";
  digest: string;
};
export type CandidateCheck = {
  name: string;
  required: boolean;
  outcome: "passed" | "failed" | "skipped";
};
export type CandidateSnapshot = {
  identity: string;
  files: readonly CandidateFile[];
  checks: readonly CandidateCheck[];
};
export type ReviewDisposition =
  "READY FOR PR" | "READY WITH FOLLOW-UPS" | "NEEDS FIXES";
export type CandidateGateResult = {
  eligible: boolean;
  reason?:
    | "missing-baseline"
    | "snapshot-changed"
    | "wrong-reviewer"
    | "required-check-missing"
    | "required-check-failed"
    | "needs-fixes"
    | "follow-ups-unaccepted";
};

function canonicalFiles(files: readonly CandidateFile[]): CandidateFile[] {
  return [...files].sort(
    (left, right) =>
      left.path.localeCompare(right.path) ||
      left.status.localeCompare(right.status),
  );
}
/** A caller supplies bounded metadata/digests; this helper never reads or persists project content. */
export function createCandidateSnapshot(
  files: readonly CandidateFile[],
  checks: readonly CandidateCheck[],
): CandidateSnapshot {
  const normalizedFiles = canonicalFiles(files);
  const identity = createHash("sha256")
    .update(JSON.stringify(normalizedFiles))
    .digest("hex");
  return {
    identity,
    files: normalizedFiles,
    checks: [...checks].sort((left, right) =>
      left.name.localeCompare(right.name),
    ),
  };
}
export function evaluateCandidateGate(
  baseline: CandidateSnapshot | undefined,
  current: CandidateSnapshot,
  reviewerId: string | undefined,
  expectedReviewerId: string | undefined,
  disposition: ReviewDisposition | undefined,
  followUpsAccepted = false,
): CandidateGateResult {
  if (!baseline) return { eligible: false, reason: "missing-baseline" };
  if (baseline.identity !== current.identity)
    return { eligible: false, reason: "snapshot-changed" };
  if (!reviewerId || reviewerId !== expectedReviewerId)
    return { eligible: false, reason: "wrong-reviewer" };
  const required = baseline.checks.filter((check) => check.required);
  if (required.length === 0)
    return { eligible: false, reason: "required-check-missing" };
  for (const check of required) {
    const currentCheck = current.checks.find(
      (candidate) => candidate.name === check.name && candidate.required,
    );
    if (!currentCheck || currentCheck.outcome === "skipped")
      return { eligible: false, reason: "required-check-missing" };
    if (currentCheck.outcome === "failed")
      return { eligible: false, reason: "required-check-failed" };
  }
  if (disposition === "NEEDS FIXES" || !disposition)
    return { eligible: false, reason: "needs-fixes" };
  if (disposition === "READY WITH FOLLOW-UPS" && !followUpsAccepted)
    return { eligible: false, reason: "follow-ups-unaccepted" };
  return { eligible: true };
}
