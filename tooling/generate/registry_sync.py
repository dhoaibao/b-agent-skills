#!/usr/bin/env python3
"""Render Claude Code delivery assets from b-agentic canonical sources."""
from __future__ import annotations

import argparse
import json
import re
import sys
import textwrap
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SKILL_REGISTRY_PATH = ROOT / "skills" / "registry.yaml"
KERNEL_TEMPLATE_PATH = ROOT / "references" / "kernel.template.md"
MCP_OPERATIONS_PATH = ROOT / "references" / "mcp_operations.yaml"
PLUGIN_PATH = ROOT / "plugin"

README_SKILLS_START = "<!-- generated:skills-table:start -->"
README_SKILLS_END = "<!-- generated:skills-table:end -->"
MCP_OPERATIONS_START = "<!-- generated:mcp-operations:start -->"
MCP_OPERATIONS_END = "<!-- generated:mcp-operations:end -->"
KERNEL_ROUTING_START = "<!-- generated:kernel-routing:start -->"
KERNEL_ROUTING_END = "<!-- generated:kernel-routing:end -->"
KERNEL_SKILL_OWNERSHIP_START = "<!-- generated:skill-ownership:start -->"
KERNEL_SKILL_OWNERSHIP_END = "<!-- generated:skill-ownership:end -->"
TEMPLATE_TOKEN_RE = re.compile(r"\{\{[a-z0-9_]+\}\}")
PROMPT_FRONTMATTER_FIELDS = [("when_to_use", "when_to_use"), ("user_invocable", "user-invocable")]
ALLOWED_PROMPT_KEYS = {"description", *[field for field, _ in PROMPT_FRONTMATTER_FIELDS]}
SKILL_OWNERS = {"planner", "worker"}
SKILL_OWNERSHIP_CRITERION = (
    "Planner-owned only when execution is read-only decision/planning, external research, audit/review, or release-summary coordination inside the planner boundary. "
    "Worker-owned when execution implements or mutates, diagnoses runtime behavior, builds/tests, performs browser/operational verification, commits, or otherwise requires worker capabilities. "
    "Mixed or uncertain skills are worker-owned."
)


def load_json_subset_yaml(path: Path) -> dict:
    try:
        value = json.loads(path.read_text())
    except json.JSONDecodeError as exc:
        raise SystemExit(f"{path}: sources must use the JSON-compatible YAML subset: {exc}") from exc
    if not isinstance(value, dict):
        raise SystemExit(f"{path}: expected object")
    return value


def ensure_string(value: object, label: str, errors: list[str]) -> str:
    if not isinstance(value, str) or not value:
        errors.append(f"{label}: expected non-empty string")
        return ""
    return value


def apply_template_tokens(text: str, replacements: dict[str, str], source: Path) -> str:
    rendered = text
    for token, value in replacements.items():
        rendered = rendered.replace(token, value)
    unresolved = sorted(set(TEMPLATE_TOKEN_RE.findall(rendered)))
    if unresolved:
        raise SystemExit(f"{source}: unresolved template tokens: {', '.join(unresolved)}")
    return rendered


def load_skills() -> list[dict]:
    skills = load_json_subset_yaml(SKILL_REGISTRY_PATH).get("skills")
    if not isinstance(skills, list):
        raise SystemExit(f"{SKILL_REGISTRY_PATH}: missing skills array")
    return skills


def validate_kernel_template(errors: list[str]) -> None:
    if not KERNEL_TEMPLATE_PATH.exists():
        errors.append(f"{KERNEL_TEMPLATE_PATH}: missing Claude Code kernel template")
    elif TEMPLATE_TOKEN_RE.search(KERNEL_TEMPLATE_PATH.read_text()):
        errors.append(f"{KERNEL_TEMPLATE_PATH}: unresolved template placeholders")


def validate_skill_prompt_source(skill: dict, errors: list[str]) -> None:
    name = skill.get("name")
    if not isinstance(name, str) or not name:
        return
    prompt_meta = skill.get("prompt")
    label = f"skills[{name}].prompt"
    if not isinstance(prompt_meta, dict):
        errors.append(f"{label}: expected object")
    else:
        unexpected = sorted(set(prompt_meta) - ALLOWED_PROMPT_KEYS)
        if unexpected:
            errors.append(f"{label}: unexpected keys {unexpected}")
        ensure_string(prompt_meta.get("description"), f"{label}.description", errors)
        for field, _ in PROMPT_FRONTMATTER_FIELDS:
            if field in prompt_meta and not isinstance(prompt_meta[field], (str, bool)):
                errors.append(f"{label}.{field}: expected string or boolean")
    prompt_path = ROOT / "skills" / name / "prompt.md"
    if not prompt_path.exists():
        errors.append(f"{prompt_path}: missing canonical prompt source")
    elif TEMPLATE_TOKEN_RE.search(prompt_path.read_text()):
        errors.append(f"{prompt_path}: unresolved canonical prompt token")


def validate_skills(skills: list[dict]) -> list[str]:
    errors: list[str] = []
    validate_kernel_template(errors)
    skill_dirs = {path.parent.name for path in (ROOT / "skills").glob("*/prompt.md")}
    names: list[str] = []
    for index, skill in enumerate(skills, start=1):
        if not isinstance(skill, dict):
            errors.append(f"skills[{index}]: expected object")
            continue
        name = ensure_string(skill.get("name"), f"skills[{index}].name", errors)
        owner = ensure_string(skill.get("owner"), f"skills[{index}].owner", errors)
        if owner and owner not in SKILL_OWNERS:
            errors.append(f"skills[{index}].owner: expected one of {sorted(SKILL_OWNERS)}")
        phase = ensure_string(skill.get("phase"), f"skills[{index}].phase", errors)
        ensure_string(skill.get("use"), f"skills[{index}].use", errors)
        routing = skill.get("routing")
        if routing is not None:
            if not isinstance(routing, dict):
                errors.append(f"skills[{index}].routing: expected object or null")
            else:
                ensure_string(routing.get("intent"), f"skills[{index}].routing.intent", errors)
                triggers = routing.get("triggers")
                if not isinstance(triggers, list) or not triggers:
                    errors.append(f"skills[{index}].routing.triggers: expected non-empty array")
                else:
                    for trigger_index, trigger in enumerate(triggers, start=1):
                        ensure_string(trigger, f"skills[{index}].routing.triggers[{trigger_index}]", errors)
        validate_skill_prompt_source(skill, errors)
        if name:
            names.append(name)
        if phase == "Ship" and routing is not None:
            errors.append(f"skills[{index}]: ship-only skills must omit routing metadata")
        if phase != "Ship" and routing is None:
            errors.append(f"skills[{index}]: non-ship skills must include routing metadata")
    if len(names) != len(set(names)):
        errors.append(f"{SKILL_REGISTRY_PATH}: duplicate skill names")
    if sorted(skill_dirs) != sorted(set(names)):
        errors.append(f"{SKILL_REGISTRY_PATH}: registry must match canonical prompt directories")
    return errors


def render_readme_skills_table(skills: list[dict]) -> str:
    lines = ["| Skill | Phase | Use |", "|---|---|---|"]
    lines.extend(f"| `{skill['name']}` | {skill['phase']} | {skill['use']} |" for skill in skills)
    return "\n".join(lines)


def render_mcp_operations_table(policy: dict) -> str:
    lines = ["| Class | Policy | Scope |", "|---|---|---|"]
    for name, meta in policy.get("classes", {}).items():
        record = meta if isinstance(meta, dict) else {}
        lines.append(f"| `{name}` | {record.get('policy', '')} | {record.get('notes', '')} |")
    return "\n".join(lines)


def render_skill_ownership(skills: list[dict]) -> str:
    by_owner = {owner: [skill["name"] for skill in skills if skill["owner"] == owner] for owner in sorted(SKILL_OWNERS)}
    return "\n".join([
        f"- Planner-owned skills: {', '.join(f'`{name}`' for name in by_owner['planner'])}. The planner may execute these only inside its read-only coordinator boundary.",
        f"- Worker-owned skills: {', '.join(f'`{name}`' for name in by_owner['worker'])}. The planner delegates their execution to a ready named `b-worker` session.",
        f"- Ownership governs execution, not inspection: the planner may read any skill for planning, delegation, audit, or review. {SKILL_OWNERSHIP_CRITERION} Direct user wording or no ready worker never permits planner implementation. Unknown or ambiguous skill ownership is worker-owned; registry validation rejects a missing or invalid owner.",
    ])


def render_routing(skills: list[dict]) -> str:
    lines: list[str] = []
    for skill in skills:
        routing = skill.get("routing")
        if isinstance(routing, dict):
            lines.append(f"- {routing['intent']} -> `{skill['name']}` (triggers: {', '.join(routing['triggers'])}).")
        elif skill["name"] == "b-commit":
            lines.append("- Split and commit working-tree changes -> `b-commit` only on explicit user request.")
        elif skill["name"] == "b-pr-summary":
            lines.append("- PR summary for a commit count or commits ahead of cached origin -> `b-pr-summary` only on explicit user request.")
    return "\n".join(lines)


def render_folded_yaml_block(key: str, value: str) -> list[str]:
    wrapper = textwrap.TextWrapper(width=74, initial_indent="  ", subsequent_indent="  ", break_long_words=False, break_on_hyphens=False)
    return [f"{key}: >", *wrapper.fill(value).splitlines()]


def render_skill_file(skill: dict) -> str:
    prompt_path = ROOT / "skills" / skill["name"] / "prompt.md"
    body = apply_template_tokens(prompt_path.read_text().rstrip() + "\n", {}, prompt_path).rstrip()
    lines = ["---", f"name: {skill['name']}"]
    lines.extend(render_folded_yaml_block("description", skill["prompt"]["description"]))
    for field, yaml_key in PROMPT_FRONTMATTER_FIELDS:
        if field in skill["prompt"]:
            value = skill["prompt"][field]
            lines.append(f"{yaml_key}: {json.dumps(value, ensure_ascii=False)}")
    lines.extend(["---", "", f"<!-- Generated from skills/registry.yaml and skills/{skill['name']}/prompt.md. Edit those sources, not this file. -->", "", body, ""])
    return "\n".join(lines)


def replace_block(text: str, start_marker: str, end_marker: str, body: str) -> str:
    try:
        start = text.index(start_marker) + len(start_marker)
        end = text.index(end_marker, start)
    except ValueError as exc:
        raise SystemExit(f"missing generated block markers: {start_marker} / {end_marker}") from exc
    return text[:start] + "\n" + body.rstrip() + "\n" + text[end:]


def render_outputs(skills: list[dict]) -> dict[Path, str]:
    outputs: dict[Path, str] = {}
    readme = ROOT / "README.md"
    outputs[readme] = replace_block(readme.read_text(), README_SKILLS_START, README_SKILLS_END, render_readme_skills_table(skills))
    kernel = KERNEL_TEMPLATE_PATH.read_text()
    kernel = replace_block(kernel, KERNEL_ROUTING_START, KERNEL_ROUTING_END, render_routing(skills))
    kernel = replace_block(kernel, KERNEL_SKILL_OWNERSHIP_START, KERNEL_SKILL_OWNERSHIP_END, render_skill_ownership(skills))
    policy = load_json_subset_yaml(MCP_OPERATIONS_PATH)
    outputs[KERNEL_TEMPLATE_PATH] = replace_block(kernel, MCP_OPERATIONS_START, MCP_OPERATIONS_END, render_mcp_operations_table(policy))
    for skill in skills:
        rendered = render_skill_file(skill)
        outputs[ROOT / "skills" / skill["name"] / "SKILL.md"] = rendered
        outputs[PLUGIN_PATH / "skills" / skill["name"] / "SKILL.md"] = rendered
    outputs[PLUGIN_PATH / "hooks" / "mcp_policy.json"] = json.dumps(policy, indent=2) + "\n"
    return outputs


def validate_owner_regressions(skills: list[dict]) -> list[str]:
    errors: list[str] = []
    for owner in (None, "coordinator"):
        fixture = [dict(skill) for skill in skills]
        if owner is None:
            fixture[0] = dict(fixture[0]); fixture[0].pop("owner", None)
        else:
            fixture[0] = dict(fixture[0]); fixture[0]["owner"] = owner
        if not any("owner" in error for error in validate_skills(fixture)):
            errors.append("ownership regression: missing or invalid owner must be rejected")
    return errors


def sync_outputs(check: bool) -> int:
    skills = load_skills()
    errors = validate_skills(skills)
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    dirty: list[str] = []
    for path, content in render_outputs(skills).items():
        if path.exists() and path.read_text() == content:
            continue
        dirty.append(str(path.relative_to(ROOT)))
        if not check:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content)
    if check and dirty:
        print("\n".join(f"generated output out of date: {path}" for path in dirty), file=sys.stderr)
        return 1
    if not check:
        print("Generated Claude Code plugin outputs refreshed.")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Render Claude Code assets from canonical sources.")
    parser.add_argument("--check", action="store_true", help="fail if generated outputs are stale")
    parser.add_argument("--self-test", action="store_true", help="verify invalid skill owners fail validation")
    args = parser.parse_args()
    if args.self_test:
        errors = validate_owner_regressions(load_skills())
        if errors:
            print("\n".join(errors), file=sys.stderr)
            return 1
        print("Skill ownership validation regressions passed.")
    return sync_outputs(args.check)


if __name__ == "__main__":
    sys.exit(main())
