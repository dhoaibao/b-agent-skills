#!/usr/bin/env python3

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
errors: list[str] = []

def rel(path: Path) -> str:
    try:
        return path.relative_to(ROOT).as_posix()
    except ValueError:
        return str(path)


def read_text(path: Path) -> str:
    return path.read_text() if path.exists() else ""


def load_json(path: Path) -> dict:
    try:
        return json.loads(path.read_text())
    except Exception as exc:
        errors.append(f"{rel(path)}: invalid JSON-compatible YAML: {exc}")
        return {}


def require_contains(path: Path, text: str, needles: list[str], label: str) -> None:
    for needle in needles:
        if needle not in text:
            errors.append(f"{rel(path)}: missing {label} {needle!r}")


def frontmatter_parts(path: Path) -> tuple[str, str]:
    text = path.read_text()
    if not text.startswith("---\n"):
        errors.append(f"{rel(path)}: missing YAML frontmatter")
        return "", text
    parts = text.split("---", 2)
    if len(parts) < 3:
        errors.append(f"{rel(path)}: missing YAML frontmatter close")
        return "", text
    return parts[1], parts[2]


skills_registry = load_json(ROOT / "skills" / "registry.yaml")
skills = skills_registry.get("skills", [])
if not isinstance(skills, list) or not skills:
    errors.append("skills/registry.yaml: skills must be a non-empty array")
    skills = []

skill_names = [skill["name"] for skill in skills if isinstance(skill, dict) and isinstance(skill.get("name"), str)]
if len(skill_names) != len(set(skill_names)):
    errors.append("skills/registry.yaml: duplicate skill names")

prompt_dirs = {path.parent.name for path in (ROOT / "skills").glob("*/prompt.md")}
if prompt_dirs != set(skill_names):
    errors.append(
        "skills/registry.yaml: registry must match prompt directories "
        f"(registry={sorted(skill_names)}, dirs={sorted(prompt_dirs)})"
    )

for skill_name in sorted(prompt_dirs):
    prompt = ROOT / "skills" / skill_name / "prompt.md"
    skill_file = ROOT / "skills" / skill_name / "SKILL.md"
    if not skill_file.exists():
        errors.append(f"{rel(skill_file)}: missing generated skill file")
        continue
    frontmatter, body = frontmatter_parts(skill_file)
    if f"name: {skill_name}" not in frontmatter:
        errors.append(f"{rel(skill_file)}: frontmatter name must match directory")
    for section in ["## When to use", "## When NOT to use", "## Tool guidance", "## Steps", "## Output format", "## Rules"]:
        if section not in body:
            errors.append(f"{rel(skill_file)}: missing section {section!r}")
    text = prompt.read_text()
    for forbidden in [
        "Optional runtime subagent",
        "Subagents are optional",
        "verify subagent claims independently",
        "[status]",
        "state-machine",
        "strict mode",
        "B_AGENTIC_STRICT",
    ]:
        if forbidden in text:
            errors.append(f"{rel(prompt)}: removed ceremony remains: {forbidden!r}")

# Keep concise, high-risk prompt regressions covered without turning prompt prose
# into a broad exact-wording contract. These anchors correspond to behavior that
# cannot be inferred from routing or structural validation alone.
prompt_regression_contracts = {
    "b-debug": ["asked only to diagnose, explain, or investigate"],
    "b-test": ["explicitly requested a tightly scoped TDD red-green loop"],
    "b-design": [
        "explicit, task-conditional design read",
        "surface, audience, brand/repository evidence, hierarchy, density, layout variance, and motion posture",
        "product-appropriate art direction",
        "anti-default constraints",
        "Treat marketing pages, product apps, dashboards, and trust/regulated surfaces differently",
        "task-conditional self-audit",
        "surface/card restraint",
        "truthful copy/assets",
    ],
    "b-frontend": [
        "explicit, task-conditional design read",
        "product-appropriate art direction",
        "anti-default constraints",
        "Treat marketing pages, product apps, dashboards, and trust/regulated surfaces differently",
        "self-audit the implementation",
        "composition/layout repetition",
        "surface/card restraint",
        "truthful copy/assets",
    ],
    "b-browser": [
        "requested UI state",
        "user explicitly requests a visual assessment",
        "approved brief, `docs/DESIGN.md`, or supplied reference as the comparator",
        "hierarchy, clipping/overflow, responsive composition, contrast/focus/interaction affordance",
        "do not invent an aesthetic baseline",
        "report observations and gaps",
        "generic page load or screenshot alone is not aesthetic proof",
    ],
    "b-plan": ["For plans spanning more than 3 files", "In planner mode, instead keep the approved plan"],
    "b-research": ["resolved lockfiles", "go.mod"],
    "b-review": ["review of changed code"],
    "b-agentic-audit": [
        "Existing source/design conformance",
        "Whole-project and first-party-extension health",
        "Canonical skill/kernel quality",
        "Currentness/MCP compatibility",
        "measured hotspot or explicit algorithmic, safety, or complexity evidence",
        "Live MCP schema probing is approval-gated",
        "NEEDS FIXES",
        "READY WITH FOLLOW-UPS",
        "READY FOR PR",
    ],
    "b-commit": ["Ask before staging or committing; do not push or create a PR."],
    "b-pr-summary": [
        "Do not contact remotes, fetch, push, inspect merge bases, or open PR state.",
        "After producing the normal PR title and description, invoke `preview_markdown` exactly once",
        "complete original finished PR Markdown source",
        "Rendering is mandatory; do not make a separate optional offer.",
        "Never invoke the tool for any BLOCKED outcome; return the exact single-line BLOCKED output above.",
        "Pass only an object with string `markdown` and, when included, string `title`; use no extra keys",
        "pass the original Markdown source rather than rendered text",
        "Do not write a file or send a separate prose response after the tool call.",
    ],
}
for skill_name, markers in prompt_regression_contracts.items():
    text = read_text(ROOT / "skills" / skill_name / "prompt.md")
    for marker in markers:
        if marker not in text:
            errors.append(f"skills/{skill_name}/prompt.md: missing behavior regression anchor {marker!r}")

# Regression: b-pr-summary preview rendering was skippable, so completed PR copy
# could be returned without the required formatted preview while blocked outcomes
# still needed to remain tool-free.
b_pr_summary_prompt = read_text(ROOT / "skills" / "b-pr-summary" / "prompt.md")
for forbidden in [
    "optionally offer or render the finished Markdown source with `preview_markdown`",
    "Keep this skippable",
]:
    if forbidden in b_pr_summary_prompt:
        errors.append(
            "skills/b-pr-summary/prompt.md: obsolete optional preview behavior remains "
            f"{forbidden!r}"
        )

# Regression: quality guidance could equate passing checks with quality, skip
# proportionate alternatives for material work, or add ceremony to obvious tasks.
QUALITY_GATE_REGRESSION = {
    "observed_failure": (
        "Quality guidance could focus on command success while omitting relevant risks, "
        "proportionate alternatives, or evidence-backed trade-offs."
    ),
    "intended_behavior": (
        "The kernel defines quality as the best evidence-backed fit; planning compares "
        "material approaches including the simpler option, implementation consults local "
        "standards and relevant failure modes, review checks proportionate solution choice, "
        "and obvious work remains low ceremony."
    ),
    "anchors": {
        "references/kernel.template.md": [
            "best evidence-backed fit to the request, repository, and relevant risks",
            "passing checks alone are not sufficient",
        ],
        "skills/b-plan/prompt.md": [
            "non-trivial or risky work",
            "relevant quality dimensions",
            "including the simpler option",
            "evidence-backed rationale and accepted trade-offs",
            "small obvious tasks free of forced comparison or research",
        ],
        "skills/b-implement/prompt.md": [
            "Before edits, consult applicable project standards",
            "architecture boundaries",
            "relevant failure modes",
            "relevant quality constraints",
            "material framework/API best-practice uncertainty",
            "targeted **b-research**",
        ],
        "skills/b-review/prompt.md": [
            "solution choice is proportionate",
            "plan's quality criteria",
            "project conventions",
            "do not turn every review into an architecture report",
        ],
        "skills/b-init/prompt.md": [
            "slim, strong, and usable",
            "evidence-backed orientation and links",
            "generic best-practice or security catalog",
        ],
    },
}
for relative_path, markers in QUALITY_GATE_REGRESSION["anchors"].items():
    text = read_text(ROOT / relative_path)
    for marker in markers:
        if marker not in text:
            errors.append(
                f"{relative_path}: missing quality-gate regression anchor {marker!r}; "
                f"observed failure: {QUALITY_GATE_REGRESSION['observed_failure']}"
            )

# Regression: b-init could produce a stripped metadata file or an exhaustive
# catalog instead of an actionable operating guide, and refresh could silently
# discard developer-owned rules or unknown legacy content.
B_INIT_GUIDANCE_REGRESSION = {
    "observed_failure": (
        "b-init guidance could omit the concrete architecture, source-to-output flow, "
        "and project boundaries an agent needs, or could copy an exhaustive catalog into "
        "AGENTS.md while silently replacing developer-owned or unknown legacy content."
    ),
    "intended_behavior": (
        "b-init inventories only evidence needed for actionable orientation, then writes a "
        "slim, strong, usable managed block with exactly three ordered sections—Repository "
        "Purpose, Project Operating Guide, and Verification. The operating guide covers only "
        "architecture/change map, canonical sources/generated outputs and required change flows, "
        "and project-specific constraints/boundaries. Developer-owned Project Rules remain "
        "outside the markers and verbatim; unmarked replacement and legacy four-section "
        "migration require an explicit material choice. Non-actionable catalogs, invented facts, "
        "and generic kernel policy stay out, while absent evidence becomes a focused gap."
    ),
    "anchors": {
        "skills/b-init/prompt.md": [
            "language and package manifests, lockfiles",
            "lint, format, type, test, and CI configuration or scripts",
            "observable technical surfaces",
            "Treat absent evidence as absence",
            "exactly these ordered top-level sections",
            "`## Repository Purpose`",
            "`## Project Operating Guide`",
            "`## Verification`",
            "`## Project Rules` is developer-owned",
            "must stay outside those markers",
            "preserved verbatim",
            "must never be regenerated, moved, or deleted",
            "unmarked-content replacement remains a material choice",
            "legacy four-section managed block",
            "Do not silently discard unknown content",
            "request a material migration choice",
            "Offer a preserve option, a clean-baseline migration option only when the user explicitly approves it, and a stop option",
            "slim, strong, usable operating guide",
            "architecture and change map",
            "canonical sources, generated outputs, and required change flows",
            "project-specific constraints and boundaries",
            "Include only facts that answer where to change, source of truth, required companion or regeneration changes, a non-obvious project constraint, or how to verify",
            "Omit non-actionable catalogs or link to deeper docs instead of copying them into `AGENTS.md`",
            "list each existing, applicable repository verification command once",
            "focused gap or TODO",
            "The always-loaded kernel owns that guidance",
            "generic best-practice or security catalog",
        ],
        "skills/b-init/SKILL.md": [
            "language and package manifests, lockfiles",
            "exactly these ordered top-level sections",
            "`## Repository Purpose`",
            "`## Project Operating Guide`",
            "`## Verification`",
            "`## Project Rules` is developer-owned",
            "must stay outside those markers",
            "preserved verbatim",
            "must never be regenerated, moved, or deleted",
            "unmarked-content replacement remains a material choice",
            "legacy four-section managed block",
            "Do not silently discard unknown content",
            "request a material migration choice",
            "slim, strong, usable operating guide",
            "architecture and change map",
            "canonical sources, generated outputs, and required change flows",
            "project-specific constraints and boundaries",
            "Omit non-actionable catalogs or link to deeper docs instead of copying them into `AGENTS.md`",
            "list each existing, applicable repository verification command once",
            "focused gap or TODO",
            "The always-loaded kernel owns that guidance",
        ],
    },
    "fixture_contract": {
        "required_scenarios": {
            "typescript-web-actionable-guide": {
                "must": [
                    "Inventory the detected TypeScript tooling and existing verification commands",
                    "Orient the agent with concrete change locations, canonical sources, generated outputs, and required companion or regeneration flow",
                    "Include scoped input, authentication, and rendering boundaries only for the observed web surfaces",
                    "Use evidence paths or links for non-obvious project-specific claims",
                    "Omit non-actionable catalogs or link to deeper docs instead of copying them into AGENTS.md",
                    "Use exactly three top-level sections in this order: Repository Purpose, Project Operating Guide, Verification",
                    "List only existing, applicable verification commands once under Verification",
                    "Preserve the developer-owned Project Rules section verbatim outside the managed markers",
                    "Keep the guide slim, strong, and usable",
                    "Do not claim security coverage beyond the observed auth middleware and sanitizer",
                ],
                "avoid": [
                    "Invent commands, owners, policies, enforcement, or technical surfaces",
                    "Turn the operating guide into a setup, release, readiness, or diagnostic catalog",
                    "Create Project Profile or Project Map and Ownership sections",
                    "Put Project Rules inside the managed block",
                    "Restate generic kernel workflow, tool, or secret policy",
                ],
            },
            "minimal-repo-bounded-guide": {
                "must": [
                    "State that the evidence is insufficient for a specialized language or technical-area profile",
                    "Provide bounded gaps or TODOs only for missing applicable guidance or verification",
                    "Use exactly three top-level sections in this order: Repository Purpose, Project Operating Guide, Verification",
                    "Avoid unsupported commands, owners, policies, and risk surfaces",
                    "Keep the operating guide limited to actionable orientation and links",
                    "Keep the result slim, strong, and usable",
                    "Leave Project Rules outside markers and preserve it when present",
                ],
                "avoid": [
                    "Assume TypeScript, Python, web, or another unsupported stack",
                    "Invent lint, test, CI, or verification commands",
                    "Add a broad secure-coding or language standards catalog",
                    "Claim technical risk surfaces that the inventory did not observe",
                    "Copy an exhaustive command or tool-readiness catalog",
                    "Restate generic kernel workflow, tool, or secret policy",
                ],
            },
            "developer-rules-and-legacy-migration": {
                "must": [
                    "Recognize a legacy four-section managed block",
                    "Do not silently discard unknown managed content",
                    "Request a material migration choice before replacing that block",
                    "Preserve the existing developer-owned Project Rules section verbatim outside the markers",
                    "Offer preserve, explicitly approved clean-baseline, and stop choices",
                    "Do not edit until the material migration choice is resolved",
                ],
                "avoid": [
                    "Assume every line in the legacy block was generated",
                    "Automatically translate, drop, or move unknown content",
                    "Regenerate, move, or delete Project Rules",
                    "Treat the legacy shape as permission to replace unmarked content",
                ],
            },
            "approved-clean-baseline-migration": {
                "must": [
                    "Use the explicit clean-baseline approval as the migration decision",
                    "Remove old generated Project Profile and Project Map and Ownership boilerplate",
                    "Move the specifically identified changelog rule into Project Rules after the managed end marker",
                    "Preserve that developer rule verbatim",
                    "Write exactly three top-level sections in this order: Repository Purpose, Project Operating Guide, Verification",
                    "Keep only relevant orientation, sources/flows/boundaries, and applicable verification",
                    "Do not add a changelog entry for an uncommitted change",
                ],
                "avoid": [
                    "Retain legacy Project Profile or Project Map and Ownership headings",
                    "Place Project Rules inside the managed markers",
                    "Keep the old exhaustive setup, release, or diagnostic command inventory",
                    "Invent project facts or verification commands",
                    "Discard the identified changelog rule",
                ],
            },
        },
    },
}
for relative_path, markers in B_INIT_GUIDANCE_REGRESSION["anchors"].items():
    text = read_text(ROOT / relative_path)
    for marker in markers:
        if marker not in text:
            errors.append(
                f"{relative_path}: missing b-init guidance regression anchor {marker!r}; "
                f"observed failure: {B_INIT_GUIDANCE_REGRESSION['observed_failure']}; "
                f"intended behavior: {B_INIT_GUIDANCE_REGRESSION['intended_behavior']}"
            )

# Regression: the questionnaire package was installed, but worker-facing material
# decisions still prescribed plain chat and b-commit lacked a structured approval
# path. Check canonical and generated guidance, not only package installation.
INTERACTIVE_DECISION_REGRESSION = {
    "observed_failure": (
        "Worker-facing material decisions still prescribed plain chat despite the "
        "questionnaire extension being installed."
    ),
    "intended_behavior": (
        "Planner and solo/Off worker material user-facing decisions and blockers use "
        "the questionnaire with its grouped-option contract, while planner tool calls "
        "produce fixed privacy-safe notifications, worker-to-planner questions remain "
        "Intercom, and b-commit exposes structured approval with fallback."
    ),
    "anchors": {
        "references/kernel.template.md": [
            "Interactive, user-facing material decisions or blockers in planner or solo/Off work",
            "Worker→planner material blockers remain Intercom",
            "native tool-permission prompts for browser, external, or privileged actions are not replaced",
        ],
        "pi/extensions/b-agentic-support/role.ts": [
            "any interactive, user-facing material decision or blocker",
            "actual tool call in planner mode triggers the fixed",
            "notification contains no question or session data",
            "Solo/Off workers do not emit planner notifications",
            "If the package reports that it is unavailable or the UI is noninteractive",
            "B_AGENTIC_TASK_COMPLETE",
        ],
        "pi/extensions/b-agentic-planner-notify.ts": [
            "tool_call",
            "ask_user_question",
            "User input needed",
            "getRole() !== \"planner\"",
            "notifyUserInputNeeded",
        ],
        "skills/b-commit/prompt.md": [
            "Approve (Recommended)",
            "Decline",
            "focused plain-text confirmation in chat",
            "read-only proposal phase",
            "exact ordered commit groups",
            "exactly one user approval question",
            "original explicit user request plus the planner-relayed exact approval",
            "without re-proposing or re-asking",
            "snapshot or proposal differs",
            "stop and report—not regroup or reuse approval",
            "complete, unchanged planner handoff",
            "resumes at step 9",
            "does not repeat steps 3–8",
            "targeted pre-commit diff checks",
        ],
        "skills/b-commit/SKILL.md": [
            "Approve (Recommended)",
            "Decline",
            "focused plain-text confirmation in chat",
            "read-only proposal phase",
            "exact ordered commit groups",
            "exactly one user approval question",
            "original explicit user request plus the planner-relayed exact approval",
            "without re-proposing or re-asking",
            "snapshot or proposal differs",
            "stop and report—not regroup or reuse approval",
            "complete, unchanged planner handoff",
            "resumes at step 9",
            "does not repeat steps 3–8",
            "targeted pre-commit diff checks",
        ],
    },
}
for relative_path, markers in INTERACTIVE_DECISION_REGRESSION["anchors"].items():
    text = read_text(ROOT / relative_path)
    for marker in markers:
        if marker not in text:
            errors.append(
                f"{relative_path}: missing interactive-decision regression anchor {marker!r}; "
                f"observed failure: {INTERACTIVE_DECISION_REGRESSION['observed_failure']}"
            )

# Regression: MCPs were named but agents had no durable selection, sequencing, or
# first-use bootstrap workflow, and broad cross-file tasks could trigger needless
# CodeGraph setup or Serena symbol inspection. Keep the checks narrow so prompts
# remain editable.
MCP_WORKFLOW_REGRESSION = {
    "observed_failure": (
        "MCP capabilities lacked actionable roles and encouraged broad cross-file "
        "CodeGraph setup or Serena symbol inspection."
    ),
    "intended_behavior": (
        "Every managed MCP has a distinct task-appropriate role; native inspection "
        "is the default, while CodeGraph and Serena bootstrap only for concrete "
        "architecture/impact or exact-symbol/diagnostic needs."
    ),
    "anchors": {
        "b-plan": [
            "Do not initialize an absent index in planner mode",
            "Outside planner mode, initialize an absent index only for that question; do not initialize one merely because the task spans files",
            "In planner mode, do not initialize an absent index; fall back to native inspection and state the resulting gap. Outside planner mode, initialize one only for that question.",
        ],
        "b-debug": ["versioned dependency suspects"],
        "b-test": ["versioned framework semantics"],
        "b-browser": ["existing CI/script evidence; approved navigation"],
        "b-research": ["independent corroboration", "research_*"],
        "b-review": [
            "specialized Brave tools",
            "In planner mode, do not initialize an absent index;",
        ],
    },
}
for skill_name, markers in MCP_WORKFLOW_REGRESSION["anchors"].items():
    text = read_text(ROOT / "skills" / skill_name / "prompt.md")
    for marker in markers:
        if marker not in text:
            errors.append(
                f"skills/{skill_name}/prompt.md: missing MCP workflow anchor {marker!r}; "
                f"observed failure: {MCP_WORKFLOW_REGRESSION['observed_failure']}"
            )

# Regression: suite audit found skills under-specified Pi native file tools, optional
# recall, targeted Serena semantic work, and specialized research/browser surfaces
# that policy already classifies. Serena startup/tool calls can also hang or time out
# under concurrency, so the prompts must make native-first and serialized use explicit.
PROMPT_TOOL_LEVERAGE_REGRESSION = {
    "observed_failure": (
        "Skill prompts could prefer unreliable Serena calls for routine file work and "
        "lacked explicit native-first/serialized guidance, alongside specialized MCP "
        "leverage already classified by mcp_operations/permissions."
    ),
    "intended_behavior": (
        "Skills teach Pi native file tools for routine work, reserve Serena for targeted "
        "semantic precision, serialize Serena calls, teach optional recall, Firecrawl "
        "research_*, specialized Brave modalities, ordered Playwright evidence, and "
        "consistent rtk git usage where git is primary."
    ),
    "anchors": {
        "b-implement": [
            "Prefer native",
            "`read`/`edit`/`write` for routine file work",
            "materially improves safety or precision",
            "Use native tools or local search",
            "repository-wide architecture, impact, or affected-test question",
            "compacted observational-memory ids",
            "serialize requests",
            "parallelize or batch them",
        ],
        "b-refactor": [
            "reference-aware refactor",
            "native search for routine discovery",
            "symbol ops only",
            "serialize requests",
            "parallelize or batch them",
        ],
        "b-debug": [
            "materially improves safety or precision",
            "native",
            "`read`/`edit`/`write` for routine work",
            "compacted repro",
            "serialize requests",
            "parallelize or batch Serena calls",
        ],
        "b-research": [
            "research_search_papers",
            "research_search_github",
            "brave_news_search",
        ],
        "b-review": ["specialized Brave tools", "rtk git"],
        "b-browser": ["browser_snapshot", "browser_find", "browser_network_requests"],
        "b-commit": ["rtk git status --short", "rtk git diff"],
        "b-pr-summary": ["rtk git log", "rtk git show"],
        "b-plan": ["Pi native `read`", "compacted prior planning"],
    },
    # Runtime companions: pi/tests/smoke.sh recall specialized + firecrawl
    # skipTlsVerification rejection; permissions RTK_OPTIONAL_COMMANDS.
}
for skill_name, markers in PROMPT_TOOL_LEVERAGE_REGRESSION["anchors"].items():
    text = read_text(ROOT / "skills" / skill_name / "prompt.md")
    for marker in markers:
        if marker not in text:
            errors.append(
                f"skills/{skill_name}/prompt.md: missing tool-leverage anchor {marker!r}; "
                f"observed failure: {PROMPT_TOOL_LEVERAGE_REGRESSION['observed_failure']}"
            )

principles_path = ROOT / "tests" / "behavior" / "principles.json"
principles_fixture = load_json(principles_path)
principle_names = {
    "think-before-coding",
    "simplicity-first",
    "surgical-changes",
    "goal-driven-execution",
}
if principles_fixture.get("version") != 1:
    errors.append(f"{rel(principles_path)}: expected fixture version 1")
if not isinstance(principles_fixture.get("source"), str) or not principles_fixture["source"]:
    errors.append(f"{rel(principles_path)}: source must be a non-empty string")
scenarios = principles_fixture.get("scenarios")
if not isinstance(scenarios, list) or not scenarios:
    errors.append(f"{rel(principles_path)}: scenarios must be a non-empty array")
    scenarios = []
scenario_ids: list[str] = []
covered_principles: set[str] = set()
for index, scenario in enumerate(scenarios, start=1):
    label = f"{rel(principles_path)}: scenario {index}"
    if not isinstance(scenario, dict):
        errors.append(f"{label} must be an object")
        continue
    scenario_id = scenario.get("id")
    if not isinstance(scenario_id, str) or not scenario_id:
        errors.append(f"{label} must have a non-empty id")
    else:
        scenario_ids.append(scenario_id)
    principle = scenario.get("principle")
    if principle not in principle_names:
        errors.append(f"{label} has unknown principle {principle!r}")
    else:
        covered_principles.add(principle)
    if scenario.get("skill", "b-implement") not in skill_names:
        errors.append(f"{label} has unknown skill {scenario.get('skill')!r}")
    if not isinstance(scenario.get("prompt"), str) or not scenario["prompt"]:
        errors.append(f"{label} must have a non-empty prompt")
    for field in ("must", "avoid"):
        values = scenario.get(field)
        if not isinstance(values, list) or not values or not all(isinstance(value, str) and value for value in values):
            errors.append(f"{label} {field} must be a non-empty string array")
    regression_fields = ("observed_failure", "intended_behavior")
    if any(field in scenario for field in regression_fields):
        for field in regression_fields:
            if not isinstance(scenario.get(field), str) or not scenario[field]:
                errors.append(f"{label} {field} must be a non-empty string")
if len(scenario_ids) != len(set(scenario_ids)):
    errors.append(f"{rel(principles_path)}: scenario ids must be unique")
if covered_principles != principle_names:
    errors.append(f"{rel(principles_path)}: scenarios must cover all four principles")

routing_path = ROOT / "tests" / "behavior" / "routing.json"
routing_fixture = load_json(routing_path)
routing_scenarios = routing_fixture.get("scenarios", [])
if routing_fixture.get("version") != 1 or not isinstance(routing_scenarios, list) or not routing_scenarios:
    errors.append(f"{rel(routing_path)}: expected version 1 with non-empty scenarios")
else:
    routing_ids: list[str] = []
    for index, scenario in enumerate(routing_scenarios, start=1):
        label = f"{rel(routing_path)}: scenario {index}"
        if not isinstance(scenario, dict):
            errors.append(f"{label} must be an object")
            continue
        scenario_id = scenario.get("id")
        if not isinstance(scenario_id, str) or not scenario_id:
            errors.append(f"{label} must have a non-empty id")
        else:
            routing_ids.append(scenario_id)
        if scenario.get("expected_skill") not in skill_names:
            errors.append(f"{label} has unknown expected_skill {scenario.get('expected_skill')!r}")
        forbidden = scenario.get("forbidden_skills")
        if not isinstance(forbidden, list) or not all(value in skill_names for value in forbidden):
            errors.append(f"{label} forbidden_skills must contain only registered skills")
        if not isinstance(scenario.get("prompt"), str) or not scenario["prompt"]:
            errors.append(f"{label} must have a non-empty prompt")
    if len(routing_ids) != len(set(routing_ids)):
        errors.append(f"{rel(routing_path)}: scenario ids must be unique")

roles_path = ROOT / "tests" / "behavior" / "roles.json"
roles_fixture = load_json(roles_path)
role_scenarios = roles_fixture.get("scenarios", [])
if roles_fixture.get("version") != 1 or not isinstance(role_scenarios, list) or not role_scenarios:
    errors.append(f"{rel(roles_path)}: expected version 1 with non-empty scenarios")
else:
    role_ids: list[str] = []
    covered_roles: set[str] = set()
    for index, scenario in enumerate(role_scenarios, start=1):
        label = f"{rel(roles_path)}: scenario {index}"
        if not isinstance(scenario, dict):
            errors.append(f"{label} must be an object")
            continue
        scenario_id = scenario.get("id")
        if not isinstance(scenario_id, str) or not scenario_id:
            errors.append(f"{label} must have a non-empty id")
        else:
            role_ids.append(scenario_id)
        role = scenario.get("role")
        if role not in {"planner", "worker"}:
            errors.append(f"{label} has unknown role {role!r}")
        else:
            covered_roles.add(role)
        if scenario.get("skill") not in skill_names:
            errors.append(f"{label} has unknown skill {scenario.get('skill')!r}")
        for field in ("prompt", "observed_failure", "intended_behavior"):
            if not isinstance(scenario.get(field), str) or not scenario[field]:
                errors.append(f"{label} {field} must be a non-empty string")
        for field in ("must", "avoid"):
            values = scenario.get(field)
            if not isinstance(values, list) or not values or not all(isinstance(value, str) and value for value in values):
                errors.append(f"{label} {field} must be a non-empty string array")
    if len(role_ids) != len(set(role_ids)):
        errors.append(f"{rel(roles_path)}: scenario ids must be unique")
    if covered_roles != {"planner", "worker"}:
        errors.append(f"{rel(roles_path)}: scenarios must cover planner and worker")

init_guidance_path = ROOT / "tests" / "behavior" / "init-guidance.json"
init_guidance_fixture = load_json(init_guidance_path)
init_guidance_scenarios = init_guidance_fixture.get("scenarios", [])
required_init_guidance_ids = set(B_INIT_GUIDANCE_REGRESSION["fixture_contract"]["required_scenarios"])
if init_guidance_fixture.get("version") != 1:
    errors.append(f"{rel(init_guidance_path)}: expected fixture version 1")
if not isinstance(init_guidance_fixture.get("source"), str) or not init_guidance_fixture["source"]:
    errors.append(f"{rel(init_guidance_path)}: source must be a non-empty string")
if not isinstance(init_guidance_scenarios, list) or not init_guidance_scenarios:
    errors.append(f"{rel(init_guidance_path)}: scenarios must be a non-empty array")
    init_guidance_scenarios = []
init_guidance_ids: list[str] = []
for index, scenario in enumerate(init_guidance_scenarios, start=1):
    label = f"{rel(init_guidance_path)}: scenario {index}"
    if not isinstance(scenario, dict):
        errors.append(f"{label} must be an object")
        continue
    scenario_id = scenario.get("id")
    if not isinstance(scenario_id, str) or not scenario_id:
        errors.append(f"{label} must have a non-empty id")
    else:
        init_guidance_ids.append(scenario_id)
    if scenario.get("skill") != "b-init":
        errors.append(f"{label} must target b-init")
    for field in ("prompt", "observed_failure", "intended_behavior"):
        if not isinstance(scenario.get(field), str) or not scenario[field]:
            errors.append(f"{label} {field} must be a non-empty string")
    scenario_contract = B_INIT_GUIDANCE_REGRESSION["fixture_contract"]["required_scenarios"].get(scenario_id)
    for field in ("must", "avoid"):
        values = scenario.get(field)
        if not isinstance(values, list) or not values or not all(isinstance(value, str) and value for value in values):
            errors.append(f"{label} {field} must be a non-empty string array")
            continue
        if len(values) != len(set(values)):
            errors.append(f"{label} {field} entries must be unique")
        if scenario_contract is None:
            continue
        for marker in scenario_contract[field]:
            if marker not in values:
                errors.append(
                    f"{label} {field} missing b-init guidance fixture contract marker {marker!r}; "
                    f"observed failure: {B_INIT_GUIDANCE_REGRESSION['observed_failure']}; "
                    f"intended behavior: {B_INIT_GUIDANCE_REGRESSION['intended_behavior']}"
                )
if len(init_guidance_ids) != len(set(init_guidance_ids)):
    errors.append(f"{rel(init_guidance_path)}: scenario ids must be unique")
if set(init_guidance_ids) != required_init_guidance_ids:
    errors.append(
        f"{rel(init_guidance_path)}: expected scenarios {sorted(required_init_guidance_ids)}, "
        f"found {sorted(init_guidance_ids)}; observed failure: {B_INIT_GUIDANCE_REGRESSION['observed_failure']}; "
        f"intended behavior: {B_INIT_GUIDANCE_REGRESSION['intended_behavior']}"
    )

# Validate only this repository's managed example. The structural checks protect
# ownership and actionable shape; the fixture contract covers model behavior.
managed_agents_path = ROOT / "AGENTS.md"
managed_agents = read_text(managed_agents_path)
managed_start_marker = "<!-- b-init-managed:start -->"
managed_end_marker = "<!-- b-init-managed:end -->"
managed_marker_error_context = (
    f"observed failure: {B_INIT_GUIDANCE_REGRESSION['observed_failure']}; "
    f"intended behavior: {B_INIT_GUIDANCE_REGRESSION['intended_behavior']}"
)
if managed_agents.count(managed_start_marker) != 1 or managed_agents.count(managed_end_marker) != 1:
    errors.append(
        f"{rel(managed_agents_path)}: b-init managed markers must occur exactly once; "
        f"{managed_marker_error_context}"
    )
else:
    managed_start = managed_agents.index(managed_start_marker) + len(managed_start_marker)
    managed_end = managed_agents.index(managed_end_marker)
    if managed_end < managed_start:
        errors.append(
            f"{rel(managed_agents_path)}: b-init managed markers are out of order; "
            f"{managed_marker_error_context}"
        )
    else:
        managed_block = managed_agents[managed_start:managed_end]
        required_managed_headings = [
            "Repository Purpose",
            "Project Operating Guide",
            "Verification",
        ]
        managed_headings = re.findall(r"^##\s+(.+?)\s*$", managed_block, re.MULTILINE)
        if managed_headings != required_managed_headings:
            errors.append(
                f"{rel(managed_agents_path)}: expected b-init headings "
                f"{required_managed_headings!r} in order, found {managed_headings!r}; "
                f"{managed_marker_error_context}"
            )

        operating_match = re.search(
            r"^##\s+Project Operating Guide\s*$([\s\S]*?)(?=^##\s+|\Z)",
            managed_block,
            re.MULTILINE,
        )
        if operating_match is None:
            errors.append(
                f"{rel(managed_agents_path)}: missing ## Project Operating Guide section; "
                f"{managed_marker_error_context}"
            )
        else:
            operating_body = operating_match.group(1)
            nested_headings = re.findall(r"^#{3,6}\s+(.+?)\s*$", operating_body, re.MULTILINE)
            required_topics = {
                "architecture/change map": r"architecture|change map",
                "canonical sources/change flows": r"canonical source|generated output|change flow",
                "project constraints/boundaries": r"constraint|boundary",
            }
            for topic, pattern in required_topics.items():
                if not any(re.search(pattern, heading, re.IGNORECASE) for heading in nested_headings):
                    errors.append(
                        f"{rel(managed_agents_path)}: Project Operating Guide lacks a descriptive "
                        f"nested heading for {topic}; {managed_marker_error_context}"
                    )

            legacy_heading_names = {
                "Project Profile",
                "Project Map and Ownership",
                "Working Rules",
                "Safety Rules",
                "Maintainer Guide",
                "Sources and Generated Assets",
                "Codebase Map",
            }
            for raw_heading in re.findall(r"^#{1,6}\s+(.+?)\s*$", operating_body, re.MULTILINE):
                heading = raw_heading.rstrip("#").strip()
                if heading in legacy_heading_names:
                    errors.append(
                        f"{rel(managed_agents_path)}: legacy heading {heading!r} is forbidden in "
                        f"Project Operating Guide; found {raw_heading!r}; {managed_marker_error_context}"
                    )

            required_operating_content = [
                "skills/",
                "references/",
                "pi/",
                "tooling/",
                "tests/",
                "skills/registry.yaml",
                "tooling/generate/registry_sync.py",
                "references/kernel.template.md",
                "references/mcp_operations.yaml",
                "slim, strong, and usable",
            ]
            for marker in required_operating_content:
                if marker not in operating_body:
                    errors.append(
                        f"{rel(managed_agents_path)}: Project Operating Guide missing actionable "
                        f"orientation marker {marker!r}; {managed_marker_error_context}"
                    )

        project_rules_matches = list(
            re.finditer(r"^##\s+Project Rules\s*$", managed_agents, re.MULTILINE)
        )
        if len(project_rules_matches) != 1:
            errors.append(
                f"{rel(managed_agents_path)}: expected exactly one developer-owned ## Project Rules "
                f"section outside the managed markers; {managed_marker_error_context}"
            )
        else:
            project_rules_match = project_rules_matches[0]
            if project_rules_match.start() < managed_end:
                errors.append(
                    f"{rel(managed_agents_path)}: ## Project Rules must be outside and after the "
                    f"managed block; {managed_marker_error_context}"
                )
            project_rules_body = managed_agents[project_rules_match.end() :]
            for marker in ["developer-owned", "preserve it verbatim", "Agents preparing a commit", "CHANGELOG.md"]:
                if marker not in project_rules_body:
                    errors.append(
                        f"{rel(managed_agents_path)}: Project Rules missing preserved developer-rule "
                        f"marker {marker!r}; {managed_marker_error_context}"
                    )

        verification_match = re.search(
            r"^##\s+Verification\s*$([\s\S]*?)(?=^##\s+|\Z)",
            managed_block,
            re.MULTILINE,
        )
        if verification_match is None:
            errors.append(
                f"{rel(managed_agents_path)}: missing ## Verification section; "
                f"{managed_marker_error_context}"
            )
        else:
            verification_body = verification_match.group(1)
            verification_commands = re.findall(r"`([^`\n]+)`", verification_body)
            if len(verification_commands) > 6:
                errors.append(
                    f"{rel(managed_agents_path)}: Verification should remain a concise applicable "
                    f"set, found {len(verification_commands)} commands; {managed_marker_error_context}"
                )
            seen_commands: set[str] = set()
            for command in verification_commands:
                if command in seen_commands:
                    errors.append(
                        f"{rel(managed_agents_path)}: duplicate Verification inline-code command "
                        f"{command!r}; {managed_marker_error_context}"
                    )
                seen_commands.add(command)
            for command in [
                "python3 tooling/generate/registry_sync.py --check",
                "scripts/validate-skills.sh",
                "npm run quality",
                "rtk git diff --check",
            ]:
                if command not in verification_commands:
                    errors.append(
                        f"{rel(managed_agents_path)}: Verification missing applicable command "
                        f"{command!r}; {managed_marker_error_context}"
                    )
            for catalog_marker in ["npm ci", "pip install", "--release", "mcp-doctor", "skill-doctor", "smoke-install"]:
                if catalog_marker in verification_body:
                    errors.append(
                        f"{rel(managed_agents_path)}: Verification includes non-applicable catalog marker "
                        f"{catalog_marker!r}; {managed_marker_error_context}"
                    )

prompt_runner_path = ROOT / "pi" / "tests" / "prompt_effectiveness.py"
prompt_runner = read_text(prompt_runner_path)
require_contains(
    prompt_runner_path,
    prompt_runner,
    ["--allow-model-calls", '"--no-session"', '"--no-tools"', '"--routing"', "scenario_role_prompt", "ROLE_SOURCE", 'environment["PI_TELEMETRY"] = "0"'],
    "prompt-effectiveness safety marker",
)

# Registry metadata is user-facing routing evidence. It must preserve the
# diagnosis/fix authorization boundary enforced by the b-debug prompt.
b_debug = next(
    (skill for skill in skills if isinstance(skill, dict) and skill.get("name") == "b-debug"),
    {},
)
b_debug_metadata = " ".join(
    str(value)
    for value in (
        b_debug.get("use", ""),
        (b_debug.get("prompt") or {}).get("description", ""),
    )
)
for required in ["authorized", "Diagnosis-only requests stop"]:
    if required not in b_debug_metadata:
        errors.append(
            "skills/registry.yaml: b-debug metadata must preserve diagnosis/fix "
            f"authorization marker {required!r}"
        )

MCP_SERVERS = {"serena", "codegraph", "context7", "linear", "mobbin", "brave-search", "firecrawl", "playwright"}
LOCAL_TOOLS = {"bash", "read", "edit", "write", "recall", "lsp_diagnostics", "lsp_fix"}
KNOWN_TOOLS = MCP_SERVERS | LOCAL_TOOLS


def tool_guidance_tokens(prompt_text: str) -> list[str]:
    """Return tool ids from Tool guidance bullets.

    Accepts a leading compound id such as `read`/`edit`/`write` before the
    description dash so first-party Pi tools can be listed together.
    """
    tokens: list[str] = []
    in_section = False
    for line in prompt_text.splitlines():
        if line.startswith("## "):
            in_section = line.strip() == "## Tool guidance"
            continue
        if in_section and line.lstrip().startswith("- "):
            match = re.match(r"\s*-\s+((?:`[^`]+`(?:\s*/\s*)?)+)", line)
            if match:
                tokens.extend(re.findall(r"`([^`]+)`", match.group(1)))
    return tokens


TOKEN_TO_DISPLAY_NAME = {
    "serena": "Serena",
    "codegraph": "CodeGraph",
    "context7": "Context7",
    "linear": "Linear",
    "mobbin": "Mobbin",
    "brave-search": "Brave",
    "firecrawl": "Firecrawl",
    "playwright": "Playwright",
    "bash": "Bash",
    "read": "read",
    "edit": "edit",
    "write": "write",
    "recall": "recall",
    "lsp_diagnostics": "LSP",
    "lsp_fix": "LSP",
}

referenced_servers: set[str] = set()
for skill_name in sorted(prompt_dirs):
    prompt = ROOT / "skills" / skill_name / "prompt.md"
    prompt_content = read_text(prompt)
    tokens = tool_guidance_tokens(prompt_content)

    # Check for tool references outside of Tool guidance.
    lines = prompt_content.splitlines()
    outside_lines = []
    in_tool_guidance = False
    for line in lines:
        if line.startswith("## "):
            in_tool_guidance = (line.strip() == "## Tool guidance")
            if not in_tool_guidance:
                outside_lines.append(line)
            continue
        if not in_tool_guidance:
            outside_lines.append(line)
    outside_text = "\n".join(outside_lines)

    for token in tokens:
        if token not in KNOWN_TOOLS:
            errors.append(
                f"{rel(prompt)}: unknown tool {token!r} in Tool guidance; "
                f"expected one of {sorted(KNOWN_TOOLS)}"
            )
        else:
            if token in MCP_SERVERS:
                referenced_servers.add(token)
            
            display_name = TOKEN_TO_DISPLAY_NAME.get(token, token)
            if (token not in outside_text) and (display_name not in outside_text):
                errors.append(
                    f"{rel(prompt)}: tool {token!r} is declared in Tool guidance but never referenced outside that section"
                )

unreferenced_servers = sorted(MCP_SERVERS - referenced_servers)
if unreferenced_servers:
    errors.append(
        "skills/: configured MCP servers not referenced by any skill Tool guidance: "
        f"{unreferenced_servers}"
    )

if list((ROOT / "skills").glob("*/reference.md")):
    errors.append("skills/: skill-local reference.md files were removed from the slim product")

references_dir = ROOT / "references"
expected_reference_mds = {"kernel.template.md"}
actual_reference_mds = {path.name for path in references_dir.glob("*.md")}
if actual_reference_mds != expected_reference_mds:
    errors.append(
        f"references/: expected markdown {sorted(expected_reference_mds)}, "
        f"found {sorted(actual_reference_mds)}"
    )
if (references_dir / "contract").exists():
    errors.append("references/contract/: removed contract directory remains")
if not (references_dir / "mcp_operations.yaml").exists():
    errors.append("references/mcp_operations.yaml: missing canonical MCP operation policy")

kernel_template = read_text(references_dir / "kernel.template.md")
for required in ["Core Rules", "Routing", "Safety and tools", "Managed MCP operations"]:
    if required not in kernel_template:
        errors.append(f"references/kernel.template.md: missing kernel marker {required!r}")
for forbidden in ["state-machine.md", "decisions.md", "index.md", "Strict governance", "Advisory-only runtime"]:
    if forbidden in kernel_template:
        errors.append(f"references/kernel.template.md: removed kernel concept remains: {forbidden!r}")

if "Use `rtk` for every command family it supports" not in kernel_template:
    errors.append(
        "references/kernel.template.md: RTK must cover every supported command family"
    )
if "Prefer modern shell tools when available" not in kernel_template:
    errors.append(
        "references/kernel.template.md: modern shell-tool preference must remain explicit"
    )
if "RTK never bypasses these protections" not in kernel_template:
    errors.append(
        "references/kernel.template.md: RTK must not be described as bypassing protections"
    )
SERENA_WORKFLOW_REGRESSION = {
    "observed_failure": (
        "Serena startup and tool calls can hang or time out under concurrency, while "
        "guidance preferred Serena for routine reads and edits."
    ),
    "intended_behavior": (
        "Before the first Serena use in a coding task, agents call "
        "serena_initial_instructions and follow it. The kernel and representative "
        "skills prefer native file tools for routine work, reserve Serena for materially "
        "safer or more precise semantic tasks, prohibit routine Serena reads/searches/edits, "
        "and serialize calls without parallel or batched Serena requests."
    ),
    "anchors": {
        "references/kernel.template.md": [
            "Prefer Pi native `read`/`edit`/`write`",
            "Before the first Serena use in a coding task, call `serena_initial_instructions` and follow it.",
            "begin with native search/read",
            "concrete exact-symbol",
            "Do not use Serena for routine reads/searches/edits",
            "Never parallelize or batch Serena calls",
            "Use CodeGraph only for a concrete repository-wide architecture",
            "do not initialize it merely because work spans files",
            "Never duplicate questions",
            "nested tools keep policy",
        ],
        "skills/b-implement/prompt.md": [
            "Prefer native",
            "serialize requests",
            "parallelize or batch them",
        ],
        "skills/b-debug/prompt.md": [
            "native",
            "`read`/`edit`/`write` for routine work",
            "serialize requests",
            "parallelize or batch Serena calls",
        ],
        "skills/b-refactor/prompt.md": [
            "native search for routine discovery",
            "serialize requests",
            "parallelize or batch them",
        ],
    },
}
for relative_path, markers in SERENA_WORKFLOW_REGRESSION["anchors"].items():
    text = read_text(ROOT / relative_path)
    for marker in markers:
        if marker not in text:
            errors.append(
                f"{relative_path}: missing Serena workflow anchor {marker!r}; "
                f"observed failure: {SERENA_WORKFLOW_REGRESSION['observed_failure']}"
            )

for intercom_marker in [
    "b-agentic defaults to Off", "external `b-research`", "sole worktree writer", "same-CWD roster",
]:
    if intercom_marker not in kernel_template:
        errors.append(
            f"references/kernel.template.md: Intercom workflow marker missing {intercom_marker!r}"
        )

role_prompt = read_text(ROOT / "pi/extensions/b-agentic-support/role.ts")
for intercom_marker in [
    # generated:role-prompt-markers:shared:start
    "Finish discovery before one bounded handoff",
    "expected paths/symbols",
    "independent read-only work outside",
    "do not mutate, revise in-flight scope, issue another implementation task, or review the in-flight diff",
    "re-read the actual changed paths before review",
    "Use send for task delegation, terminal results, review requests/findings, and any question/request needing material work",
    "one focused question whose answer needs no substantial investigation, implementation, or waiting",
    "never use ask to wait",
    "Roster/status only selects or handles",
    "Before every outbound Intercom send or ask",
    "If it reports an inbound ask, reply to that ask immediately—do not call send, ask, list-cwd, or another pending first",
    "If none exists, immediately call list-cwd",
    "identifier token verbatim",
    "authoritative short ID is valid",
    "never guess, reconstruct, extend, further abbreviate, or reuse stale output",
    "Delivery makes a handoff, result, finding, or approval real",
    "one retry only",
    "applicable observable behavior, scope/non-goals, constraints/invariants",
    "latest approved plan, handoff, and clarifications",
    "Only delegated worktree-changing tasks require actual b-review",
    "location, evidence, impact, violated baseline, smallest correction, and regression check",
    "For audit/review verification you cannot run, request bounded worker evidence",
    "same worker may b-commit only on explicit user request",
    "b-commit remains worker-owned",
    "read-only proposal analysis",
    "exactly one user approval",
    "captured snapshot",
    "without re-proposing or re-asking",
    "snapshot or proposal differs",
    "stop and report—not regroup or reuse approval",
# generated:role-prompt-markers:shared:end
]:
    if intercom_marker not in role_prompt:
        errors.append(
            f"pi/extensions/b-agentic-support/role.ts: Intercom workflow marker missing {intercom_marker!r}"
        )

# The kernel owns the RTK requirement and modern shell-tool preferences.
for required_tool in ["`rtk`", "`rg`", "`fdfind`", "`batcat`", "`eza`", "`sd`", "`jq`"]:
    if required_tool not in kernel_template:
        errors.append(
            f"references/kernel.template.md: missing shell-tool guidance for {required_tool!r}"
        )
if "prompt the user to install the shell tooling before falling back" in kernel_template:
    errors.append(
        "references/kernel.template.md: blocking shell-tool install prompt remains"
    )

installer = read_text(ROOT / "tooling" / "install" / "common.sh")
if 'CONTEXT7_API_KEY_INPUT="$CONTEXT7_API_KEY_INPUT"' in installer:
    errors.append("tooling/install/common.sh: prompted MCP keys must not enter a child environment")
if "os.fdopen(3, 'rb')" not in installer:
    errors.append("tooling/install/common.sh: prompted MCP keys must use the private input pipe")

for marker in [
    "<!-- generated:kernel-routing:start -->",
    "<!-- generated:kernel-routing:end -->",
    "<!-- generated:mcp-operations:start -->",
    "<!-- generated:mcp-operations:end -->",
]:
    if marker not in kernel_template:
        errors.append(f"references/kernel.template.md: missing generated marker {marker!r}")
for skill in skills:
    if not isinstance(skill.get("routing"), dict):
        continue
    name_token = f"`{skill['name']}`"
    if name_token not in kernel_template:
        errors.append(
            f"references/kernel.template.md: routing is missing {name_token}"
        )

# Firecrawl is external research infrastructure, not browser evidence. Keeping
# it out of b-browser prevents overlapping tool ownership with b-research.
browser_prompt = read_text(ROOT / "skills" / "b-browser" / "prompt.md")
if "`firecrawl`" in browser_prompt:
    errors.append("skills/b-browser/prompt.md: firecrawl ownership must remain in b-research")

readme_path = ROOT / "README.md"
readme = read_text(readme_path)
reference_path = ROOT / "REFERENCE.md"
reference = read_text(reference_path)
if not reference_path.exists():
    errors.append("REFERENCE.md: missing operational reference")
else:
    if "README.md" not in reference:
        errors.append("REFERENCE.md: must link back to README.md")
if "REFERENCE.md" not in readme:
    errors.append("README.md: must link to REFERENCE.md")
for forbidden in ["hooks", "subagent", "strict", "state-machine"]:
    if re.search(rf"\b{re.escape(forbidden)}\b", readme, re.IGNORECASE):
        errors.append(f"README.md: removed product concept remains: {forbidden!r}")

# Safety-gate parity: every runtime that ships a permission model must gate the
# command families the kernel (references/kernel.template.md)
# requires, at no weaker than the canonical severity. "ask" = must prompt for
# approval; "deny" = must be refused. Each family is checked through the
# runtime's own permission model. Runtimes without a managed permission gate
# (e.g. Pi's adapter-only model) are checked against their shipped extension.
SAFETY_GATES = [
    # (command tokens, minimum severity)
    (["git", "push"], "ask"),
    (["git", "pull"], "ask"),
    (["rm", "-rf"], "ask"),
    (["git", "reset", "--hard"], "deny"),
    (["git", "clean", "-f"], "deny"),
    (["git", "push", "--force"], "deny"),
    (["git", "push", "--force-with-lease"], "deny"),
    (["git", "branch", "-D"], "deny"),
    (["docker", "system", "prune"], "deny"),
    (["docker", "volume", "rm"], "deny"),
]
SEVERITY_RANK = {"ask": 1, "deny": 2}


def pi_gate_severity(tokens: list[str], extension_text: str) -> int:
    # Pi gates live in the first-party TypeScript extension as token patterns.
    # DENY patterns are checked first; ASK/SERVICE patterns require confirmation.
    # Runtime normalizes a leading rtk token before matching.
    def patterns_from(const_name: str) -> list[list[str]]:
        match = re.search(rf"const {const_name}: string\[\]\[\] = \[(.*?)\];", extension_text, re.DOTALL)
        if not match:
            return []
        patterns: list[list[str]] = []
        for raw in re.findall(r"\[([^\]]*)\]", match.group(1)):
            entry = re.findall(r'"([^"]+)"', raw)
            if entry:
                patterns.append(entry)
        return patterns

    for pattern in patterns_from("DENY_COMMANDS"):
        if tokens[: len(pattern)] == pattern:
            return 2
    for pattern in patterns_from("ASK_COMMANDS") + patterns_from("SERVICE_COMMANDS"):
        if tokens[: len(pattern)] == pattern:
            return 1
    return 0


pi_extension = read_text(ROOT / "pi" / "extensions" / "b-agentic-support" / "shell.ts")
skill_roster_match = re.search(
    r"export const B_AGENTIC_SKILL_NAMES = new Set\(\[(.*?)\]\);",
    pi_extension,
    re.DOTALL,
)
if not skill_roster_match:
    errors.append(
        "pi/extensions/b-agentic-support/shell.ts: missing B_AGENTIC_SKILL_NAMES roster"
    )
else:
    pi_skill_names = re.findall(r'\"([^\"]+)\"', skill_roster_match.group(1))
    if pi_skill_names != skill_names:
        errors.append(
            "pi/extensions/b-agentic-support/shell.ts: B_AGENTIC_SKILL_NAMES must match "
            f"skills/registry.yaml (roster={pi_skill_names!r}, registry={skill_names!r})"
        )

for tokens, min_severity in SAFETY_GATES:
    if pi_gate_severity(tokens, pi_extension) < SEVERITY_RANK[min_severity]:
        errors.append(
            f"pi/extensions/b-agentic-support/shell.ts: safety gate {' '.join(tokens)!r} weaker than required {min_severity!r}; "
            "align with references/kernel.template.md"
        )

for deleted_path in ["tooling/policy", "tooling/state", "tooling/hooks", "tooling/conformance", "tooling/scenarios"]:
    leftovers = [
        path for path in (ROOT / deleted_path).glob("**/*")
        if path.is_file() and "__pycache__" not in path.parts and path.suffix != ".pyc"
    ]
    if leftovers:
        errors.append(f"{deleted_path}: removed-governance files remain in the worktree")

generated_paths = [
    ROOT / "README.md",
    ROOT / "REFERENCE.md",
    ROOT / "references" / "kernel.template.md",
    *(ROOT / "skills" / name / "SKILL.md" for name in skill_names),
]
for path in generated_paths:
    if path.exists() and "{{" in path.read_text():
        errors.append(f"{rel(path)}: unresolved template token")

if errors:
    for error in errors:
        print(error, file=sys.stderr)
    sys.exit(1)

print(f"Shared skill validation passed ({len(skill_names)} skills).")
