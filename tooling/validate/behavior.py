#!/usr/bin/env python3

"""Routing-metadata consistency check.

This is a static heuristic over skill registry metadata (names, triggers,
intents, descriptions). It scores each fixture prompt against every skill's
metadata and asserts the intended skill wins, guarding against trigger/intent
collisions that would make two skills indistinguishable. It does NOT exercise
the runtime's actual LLM routing.
"""

from __future__ import annotations

import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


@dataclass(frozen=True)
class Fixture:
    name: str
    prompt: str
    expected: str
    not_expected: tuple[str, ...] = ()


# Regression: splitting runtime guidance across runtime.md and safety-tools.md
# made the always-loaded kernel omit routing, safety, bootstrap, and verification
# guarantees. Consolidation must retain those guarantees in the single kernel.
KERNEL_CONSOLIDATION_REGRESSION = {
    "observed_failure": "The runtime kernel lacked contract guidance unless agents opened extra files.",
    "intended_behavior": "The single always-loaded kernel retains routing, approval, verification, and local-tool fallback guidance.",
    "required_clauses": (
        "latest user instruction, approved plan, repo evidence, then stated assumptions",
        "define success, make the smallest coherent change, and verify its observable outcome",
        "Auto-run repository-local commands and edits, including build, test, package, and scripts",
        "likely-secret files (`.env`, `*.pem`, `credentials.*`, `secrets.*`)",
        "Use CodeGraph only when native inspection leaves a concrete repository-wide architecture or impact question",
        "Do not install missing tools; fall back to local evidence and state the resulting gap.",
    ),
}

# Regression: unscoped Git diffs could expose protected content without a
# literal path token, and RTK guidance must not weaken that protection.
SHELL_POLICY_REGRESSION = {
    "observed_failure": (
        "Kernel designated RTK and modern replacements, but unscoped Git content "
        "reads bypassed path protection."
    ),
    "intended_behavior": (
        "Recommend RTK and modern fallbacks while allowing regular repository-local "
        "commands, and require approval for unscoped Git content reads."
    ),
    "required_clauses": (
        "RTK never bypasses these protections",
        "Prefer modern shell tools when available",
        "Use `rtk` for every command family it supports",
    ),
    # Runtime companions: pi/tests/smoke.sh covers RTK discovery enforcement,
    # modern fallback availability, and scoped Git content reads.
}

# Regression: prompt-only planner roles retained mutation tools, so a planner
# implemented directly even while a worker session was active.
INTERCOM_DELEGATION_REGRESSION = {
    "observed_failure": (
        "Planner mode only described delegation and did not prevent direct implementation "
        "or fixes when a worker session was available."
    ),
    "intended_behavior": (
        "Make natural-language planner-to-worker handoffs the default while enforcing planner "
        "read-only ownership and retaining worker-local repository automation."
    ),
    "required_clauses": (
        "b-agentic defaults to Off for a single-session workflow",
        "The two-role workflow is explicit",
        "Planner owns `b-plan`, `b-research`, `b-agentic-audit`, `b-review`, and `b-pr-summary`",
        "Worker is the sole worktree writer",
        "Finish discovery and settle the approach before one handoff",
        "while worker edits, no exploration or new implementation requests",
        "Use the role-aware same-CWD Worker roster after explicit role selection",
        "Worker sends that planner paths/checks/gaps and pauses",
        "Worker resumes only for findings/new work",
        "Natural language; no parsed protocol/chains",
        "Planners and workers must call Intercom `pending` first before every `send` or `reply`; if `pending` reports an inbound ask, the response must use `reply` for that ask and must not call `send` or `list-cwd`; only when `pending` reports no inbound ask may the role call `list-cwd` again to retrieve the exact session ID, then call `send` to that exact ID",
        "This `list-cwd` call is the explicit exception to avoiding repeated `list-cwd` polling",
        "After assigning a task, wait for the worker's result instead of polling again",
        "Keep roster/status calls for selecting a worker or handling genuine connection needs, not a polling loop",
        "Every task delegated by a planner to a worker must pass the actual `b-review` skill against the actual diff and verification before the planner may mark it done, complete, approved, or closed",
        "A regular or generic review is insufficient, and this review gate must never be bypassed under any circumstances",
        "If a blocker or decision cannot be resolved from scope or repository evidence, the planner asks the user one focused question and keeps the task open",
        "when it can resolve a worker's blocker, it uses Intercom `pending` first and then `reply` to the worker",
        "A worker with an unresolved issue or blocker must use Intercom `ask` to the assigning planner with one focused question and wait",
        "must not ask the user directly, stop midway, or send a premature completion or review message while the planner waits",
        "The planner resolves the blocker via `reply` when possible; otherwise it escalates to the user and keeps the task open",
    ),
}


FIXTURES = [
    Fixture(
        name="explicit debug skill request",
        prompt="Please use b-debug to diagnose this stack trace.",
        expected="b-debug",
    ),
    Fixture(
        name="planning request",
        prompt="Plan how to add billing scope and decompose the work.",
        expected="b-plan",
    ),
    Fixture(
        name="external docs lookup",
        prompt="Look up the React Router API docs and compare the config options.",
        expected="b-research",
    ),
    Fixture(
        name="frontend design standard doc",
        prompt="Create docs/DESIGN.md as the frontend design standard for this app.",
        expected="b-design",
        not_expected=("b-plan",),
    ),
    Fixture(
        name="screenshot-derived design guidance",
        prompt="Analyze this screenshot and write the visual design rules for docs/DESIGN.md.",
        expected="b-design",
        not_expected=("b-browser", "b-plan"),
    ),
    Fixture(
        name="approved implementation",
        prompt="Implement the approved plan and finish the next build step.",
        expected="b-implement",
    ),
    Fixture(
        name="mechanical rename",
        prompt="Rename UserService to AccountService without changing behavior.",
        expected="b-refactor",
    ),
    Fixture(
        name="runtime bug",
        prompt="This regression is broken in production and throws this error stack trace.",
        expected="b-debug",
    ),
    Fixture(
        name="product bug exposed by failing test",
        prompt="A failing test exposes a real product regression in checkout.",
        expected="b-debug",
        not_expected=("b-test",),
    ),
    Fixture(
        name="test mechanics",
        prompt="Fix the failing component test mock assertion and update coverage.",
        expected="b-test",
        not_expected=("b-debug",),
    ),
    Fixture(
        name="browser evidence",
        prompt="Run Playwright e2e, capture a screenshot, and check the live UI.",
        expected="b-browser",
        not_expected=("b-test",),
    ),
    Fixture(
        name="changed-code review",
        prompt="Review my working tree diff before PR.",
        expected="b-review",
        not_expected=("b-agentic-audit",),
    ),
    Fixture(
        name="review changes",
        prompt="Please review these changes.",
        expected="b-review",
    ),
    Fixture(
        name="plan review remains planning",
        prompt="Review this implementation plan before coding.",
        expected="b-plan",
        not_expected=("b-review",),
    ),
    Fixture(
        name="commit working-tree changes",
        prompt="Split my tracked and untracked working-tree changes into cohesive commits.",
        expected="b-commit",
    ),
    Fixture(
        name="commit message for staged changes",
        prompt="Write a commit message for my staged changes.",
        expected="b-commit",
        not_expected=("b-pr-summary",),
    ),
    Fixture(
        name="PR copy for staged changes is blocked by commit",
        prompt="Write PR copy for my staged changes.",
        expected="b-commit",
        not_expected=("b-pr-summary",),
    ),
    Fixture(
        name="review staged changes stays in review",
        prompt="Review my staged changes before committing.",
        expected="b-review",
        not_expected=("b-commit",),
    ),
    Fixture(
        name="PR summary for recent commits",
        prompt="Use b-pr-summary 3 to write a PR title and description for my latest three commits.",
        expected="b-pr-summary",
    ),
    Fixture(
        name="PR summary for unpushed commits",
        prompt="Use b-pr-summary to write PR copy for all commits on my current branch that are not pushed to origin.",
        expected="b-pr-summary",
    ),
    Fixture(
        name="natural PR summary for unpushed commits",
        prompt="Write PR copy for all my unpushed commits.",
        expected="b-pr-summary",
    ),
    Fixture(
        name="natural PR summary for counted commits",
        prompt="Write PR copy for my latest 3 commits.",
        expected="b-pr-summary",
    ),
    Fixture(
        name="planning a commit strategy stays in b-plan",
        prompt="How should I plan the commit strategy for this feature?",
        expected="b-plan",
        not_expected=("b-commit", "b-pr-summary"),
    ),
    Fixture(
        name="reviewing a PR description stays in b-review",
        prompt="Review my PR description before I submit it.",
        expected="b-review",
        not_expected=("b-commit", "b-pr-summary"),
    ),
    Fixture(
        name="generic summary of docs stays in research",
        prompt="Summarize the React Router API docs and compare the config options.",
        expected="b-research",
        not_expected=("b-commit", "b-pr-summary"),
    ),
    # High-risk phase-boundary / authorization / tool-choice fixtures.
    Fixture(
        name="ambiguous goal stays in planning",
        prompt="Help me figure out what to do about billing and decompose the work.",
        expected="b-plan",
        not_expected=("b-implement",),
    ),
    Fixture(
        name="approved plan handoff to implement",
        prompt="The plan is approved; implement the next small build step only.",
        expected="b-implement",
        not_expected=("b-plan",),
    ),
    Fixture(
        name="implement does not claim browser evidence",
        prompt="Implement the approved build step from the plan and verify with unit tests only.",
        expected="b-implement",
        not_expected=("b-browser", "b-plan"),
    ),
    Fixture(
        name="runtime stack trace stays in debug",
        prompt="Diagnose this production stack trace and confirm the runtime root cause.",
        expected="b-debug",
        not_expected=("b-test", "b-implement"),
    ),
    Fixture(
        name="test assertion failure stays in test",
        prompt="The unit test assertion is wrong and the mock fixture needs fixing.",
        expected="b-test",
        not_expected=("b-debug",),
    ),
    Fixture(
        name="live UI session stays in browser",
        prompt="Open a real browser session, capture a screenshot, and collect e2e evidence.",
        expected="b-browser",
        not_expected=("b-test", "b-debug"),
    ),
    Fixture(
        name="pre-pr changed code review stays in review",
        prompt="Review the changed code in my working tree before I open a PR.",
        expected="b-review",
        not_expected=("b-commit", "b-pr-summary", "b-plan"),
    ),
    Fixture(
        name="suite self-audit routes to audit",
        prompt="Run a b-agentic repository suite self-audit and report decision-design drift.",
        expected="b-agentic-audit",
        not_expected=("b-review",),
    ),
    Fixture(
        name="design-conformance audit routes to audit",
        prompt="Run the design-conformance audit and compare documented decisions with canonical sources.",
        expected="b-agentic-audit",
        not_expected=("b-review",),
    ),
    # Trigger-tightening regressions (suite audit: bare add/build/error/docs over-routed).
    Fixture(
        name="finish the implementation phrasing stays implement",
        prompt="Please finish the implementation of the approved checkout step.",
        expected="b-implement",
        not_expected=("b-plan", "b-debug"),
    ),
    Fixture(
        name="make the change phrasing stays implement",
        prompt="Make the change described in the approved plan for the parser.",
        expected="b-implement",
        not_expected=("b-plan",),
    ),
    Fixture(
        name="build the feature phrasing stays implement",
        prompt="Build the feature for export CSV as approved.",
        expected="b-implement",
        not_expected=("b-plan", "b-browser"),
    ),
    Fixture(
        name="runtime error phrasing stays debug",
        prompt="Diagnose this runtime error in checkout.",
        expected="b-debug",
        not_expected=("b-test", "b-implement"),
    ),
    Fixture(
        name="product bug phrasing stays debug",
        prompt="There is a product bug in tax calculation.",
        expected="b-debug",
        not_expected=("b-test",),
    ),
    Fixture(
        name="readme approach without external lookup stays plan",
        prompt="How should I approach updating the outdated README install section?",
        expected="b-plan",
        not_expected=("b-research", "b-implement"),
    ),
    Fixture(
        name="external documentation phrasing stays research",
        prompt="Read external documentation for Stripe webhooks.",
        expected="b-research",
        not_expected=("b-plan",),
    ),
]


def load_registry() -> list[dict]:
    return json.loads((ROOT / "skills" / "registry.yaml").read_text())["skills"]


def normalize(text: str) -> str:
    return re.sub(r"\s+", " ", text.lower()).strip()


def words(text: str) -> set[str]:
    stopwords = {
        "a", "an", "the", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with", "by",
        "from", "as", "is", "was", "are", "were", "be", "been", "being", "have", "has", "had",
        "do", "does", "did", "will", "would", "could", "should", "may", "might", "can", "shall",
        "i", "me", "my", "myself", "we", "our", "ours", "us", "you", "your", "yours", "he", "him",
        "his", "she", "her", "hers", "it", "its", "they", "them", "their", "this", "that", "these",
        "those", "not", "no", "yes", "if", "then", "than", "so", "very", "just", "now", "only",
    }
    return set(re.findall(r"[a-z0-9][a-z0-9-]*", text.lower())) - stopwords


def metadata_terms(skill: dict) -> tuple[list[str], set[str]]:
    phrases: list[str] = []
    word_set: set[str] = set()

    prompt = skill.get("prompt", {})
    routing = skill.get("routing") or {}

    for value in [
        skill.get("name"),
        skill.get("phase"),
        skill.get("use"),
        prompt.get("description"),
        routing.get("intent"),
    ]:
        if isinstance(value, str):
            phrases.append(value.strip('"'))
            word_set.update(words(value))

    triggers = routing.get("triggers", [])
    if isinstance(triggers, list):
        for trigger in triggers:
            if isinstance(trigger, str):
                phrases.append(trigger.strip('"'))
                word_set.update(words(trigger))

    return [normalize(phrase) for phrase in phrases if phrase], word_set


def score(prompt: str, skill: dict) -> int:
    name = skill.get("name", "")
    normalized_prompt = normalize(prompt)
    prompt_words = words(prompt)
    phrases, word_set = metadata_terms(skill)
    score_value = 0

    if name == "b-commit":
        commit_markers = ["commit changes", "commit message", "working-tree changes", "working tree changes", "create commits", "split my"]
        matched_markers = [m for m in commit_markers if m in normalized_prompt]
        staged_change = "staged changes" in normalized_prompt or "staged diff" in normalized_prompt
        staged_commit_intent = "commit message" in normalized_prompt or "pr copy" in normalized_prompt
        if staged_change and staged_commit_intent:
            matched_markers.append("staged commit or PR-copy intent")
        if not matched_markers:
            return 0
        score_value += len(matched_markers) * 4

    if name == "b-pr-summary":
        if "staged changes" in normalized_prompt or "staged diff" in normalized_prompt:
            return 0
        pr_summary_markers = ["b-pr-summary", "pr summary", "pr copy", "unpushed commits", "latest commits", "recent commits"]
        matched_markers = [m for m in pr_summary_markers if m in normalized_prompt]
        if not matched_markers:
            return 0
        score_value += len(matched_markers) * 4

    if name and re.search(rf"(^|\W){re.escape(name)}($|\W)", normalized_prompt):
        score_value += 100

    routing = skill.get("routing") or {}
    triggers = routing.get("triggers", [])
    if isinstance(triggers, list):
        for trigger in triggers:
            if isinstance(trigger, str) and normalize(trigger.strip('"')) in normalized_prompt:
                score_value += 12

    for phrase in phrases:
        if len(phrase) > 2 and phrase in normalized_prompt:
            score_value += 4

    score_value += len(prompt_words & word_set)
    return score_value


def classify(prompt: str, skills: list[dict]) -> tuple[str, dict[str, int]]:
    scores = {
        skill["name"]: score(prompt, skill)
        for skill in skills
        if isinstance(skill, dict) and isinstance(skill.get("name"), str)
    }
    best_score = max(scores.values())
    winners = sorted(name for name, value in scores.items() if value == best_score)
    if len(winners) != 1:
        return f"ambiguous({','.join(winners)})", scores
    return winners[0], scores


def routing_table_text() -> str:
    return (ROOT / "references" / "kernel.template.md").read_text()


def validate_runtime_contract(skills: list[dict], errors: list[str]) -> None:
    text = routing_table_text()
    for skill in skills:
        name = skill.get("name")
        if not isinstance(name, str):
            continue
        if skill.get("routing") is None:
            expected_ship_rules = {
                "b-commit": "Split and commit working-tree changes -> `b-commit`",
                "b-pr-summary": "PR summary for a commit count or commits ahead of cached origin -> `b-pr-summary`",
            }
            expected_rule = expected_ship_rules.get(name)
            if expected_rule and expected_rule not in text:
                errors.append(f"references/kernel.template.md: missing {name} routing rule")
            continue
        if f"`{name}`" not in text:
            errors.append(f"references/kernel.template.md: missing routing entry for {name}")
        for trigger in skill.get("routing", {}).get("triggers", []):
            if isinstance(trigger, str) and trigger.strip('"') not in text:
                errors.append(
                    f"references/kernel.template.md: missing trigger {trigger!r} for {name}"
                )


def validate_clause_regression(name: str, regression: dict, errors: list[str]) -> None:
    kernel = routing_table_text()
    for clause in regression["required_clauses"]:
        if clause not in kernel:
            errors.append(
                f"{name}: missing required clause {clause!r}; observed failure: "
                f"{regression['observed_failure']}"
            )


def validate_kernel_consolidation_regression(errors: list[str]) -> None:
    validate_clause_regression(
        "kernel consolidation regression",
        KERNEL_CONSOLIDATION_REGRESSION,
        errors,
    )


def validate_shell_policy_regression(errors: list[str]) -> None:
    validate_clause_regression(
        "shell policy regression",
        SHELL_POLICY_REGRESSION,
        errors,
    )


def validate_intercom_delegation_regression(errors: list[str]) -> None:
    validate_clause_regression(
        "Intercom delegation regression",
        INTERCOM_DELEGATION_REGRESSION,
        errors,
    )


def main() -> int:
    skills = load_registry()
    skill_names = {skill.get("name") for skill in skills if isinstance(skill, dict)}
    errors: list[str] = []

    validate_runtime_contract(skills, errors)
    validate_kernel_consolidation_regression(errors)
    validate_shell_policy_regression(errors)
    validate_intercom_delegation_regression(errors)

    for fixture in FIXTURES:
        if fixture.expected not in skill_names:
            errors.append(f"{fixture.name}: expected unknown skill {fixture.expected!r}")
            continue

        actual, scores = classify(fixture.prompt, skills)
        if actual != fixture.expected:
            ordered = ", ".join(
                f"{name}={value}" for name, value in sorted(scores.items(), key=lambda item: (-item[1], item[0]))
            )
            errors.append(
                f"{fixture.name}: expected {fixture.expected}, classified as {actual}; scores: {ordered}"
            )
        for forbidden in fixture.not_expected:
            if forbidden in actual:
                errors.append(f"{fixture.name}: incorrectly routed to {forbidden}")

    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1

    print(f"Routing-metadata consistency check passed ({len(FIXTURES)} fixtures).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
