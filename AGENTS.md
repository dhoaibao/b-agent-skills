# b-agents — Agent authoring conventions

Guidelines for creating, editing, and maintaining agents in this repository.

---

## Frontmatter spec

Every `opencode/b-[name].md` must begin with YAML frontmatter:

```yaml
---
name: b-skill-name
description: >
  [Trigger-focused description, ≤80 words. Answer ONLY: "when should Claude trigger this skill?"
  Include: ALWAYS trigger condition, key Vietnamese + English trigger phrases,
  and one sentence distinguishing this from similar skills.
  Do NOT include usage instructions — those go in the agent file body.]
---
```

**Required fields:**
- `name` — kebab-case, prefixed with `b-`
- `description` — ≤80 words, trigger-focused only

**Description rules:**
- Start with a one-line summary of what the skill does
- Include `ALWAYS use this skill when...` with specific trigger phrases
- Include both Vietnamese and English trigger keywords
- End with disambiguation from the most similar skill
- No step-by-step instructions, no tool lists, no output format details

---

## Agent file structure template

```markdown
---
name: b-example
description: >
  [≤80 words, trigger-focused]
---

# b-example

[1–2 sentence summary of what this skill does and why it exists.]

## When to use
- [Bullet list of scenarios]

## When NOT to use *(optional but recommended)*
- [Scenarios that should trigger a different skill instead]

## Tools required
- `tool_name` — from `mcp-server` MCP server
- `tool_name` — from `mcp-server` MCP server *(optional, for [condition])*

If [MCP] is unavailable: [what to do — stop, fallback, or degrade]

Graceful degradation: [✅ Possible / ⚠️ Partial / ❌ Not possible] — [brief explanation]

## Steps

### Step 1 — [Name]
[Imperative instructions. Every step must have action verbs.]

### Step 2 — [Name]
...

---

## Output format
[Template or example of expected output]

---

## Rules
- [Bullet list of constraints and guardrails]
```

---

## MCP selection criteria

When deciding which MCPs a skill should use:

| Role | When to add | Example |
|---|---|---|
| **Primary** | Skill cannot function without it | brave-search for b-quick-search |
| **Secondary** | Skill uses it conditionally for a specific step | context7 for b-research (HOWTO queries only) |
| **Optional** | Enhances quality but skill works without it | sequential-thinking for b-analyze |

**Rules:**
- Never add an MCP just to increase coverage — every MCP must have a clear use case in the Steps section
- Always document what happens when an optional/secondary MCP is unavailable
- Label each MCP in "Tools required" with its role: required vs `*(optional, for [condition])*`
- Always include a `Graceful degradation:` line summarizing fallback behavior

---

## Agent file sync rule

All skills live in `opencode/b-[name].md`. When changing agent files:

| Change type | Action |
|---|---|
| **Create** new agent | Create `opencode/b-[name].md` |
| **Update** agent | Edit `opencode/b-[name].md` directly |
| **Delete** agent | Delete `opencode/b-[name].md` |

**Exception: `b-execute-plan`** — its agent file contains intentional adaptations that must be preserved when updating:

| What changed | What to do in agent file |
|---|---|
| Step logic / routing / rules | Apply the equivalent change manually, keeping `@b-[name]` format |
| New subagent invocation added | Add to the `## Subagent invocation` section |
| New inter-skill state (e.g. new section written to plan file) | Update the state bridging block accordingly |
| Output format / cosmetic | Copy directly — no translation needed |

Intentional differences to preserve in `b-execute-plan` agent file:
- All subagent invocations use `@b-[name]` format
- State bridging block: writes context to plan file before each subagent call (`## Context`, `## Last Gate Failure`, `## Review Feedback`)
- `## Subagent invocation` section lists `@b-[name]` syntax throughout

**`opencode/global/AGENTS.md` sync** — update `opencode/global/AGENTS.md` (global rules) and `AGENTS.md` (repo rules) in the same commit when any of these change:

| Change | Section to update |
|---|---|
| Subagent added or removed | `## Subagents` table in `opencode/global/AGENTS.md` |
| New plan file section added | `## Plan file state sections` table in `opencode/global/AGENTS.md` |
| b-execute-plan workflow changes | `## Invoking the execution pipeline` in `opencode/global/AGENTS.md` |
| Git safety rules change | `## Git safety` in `opencode/global/AGENTS.md` |

**Agent file structure** — every `opencode/b-[name].md` follows this format:

```markdown
---
name: b-[name]
description: [one-line, trigger-focused]
mode: [primary for orchestrator agents / subagent for all others]
model: [see model table in OPENCODE.md]
---

[Agent file body — # heading onward]
```

**How to update**: edit `opencode/b-[name].md` directly.

**How to add a new agent**:
1. Create `opencode/b-[name].md` with the structure above.
2. `install.sh` picks it up automatically — no script changes needed.
3. Update `OPENCODE.md` model assignments table if the new agent uses a non-default model.

---

## Doc sync rule

**Any change to an agent file — create, update, or delete — requires updating both `README.md` and `REFERENCE.md` in the same commit.**

| Change type | README.md | REFERENCE.md |
|---|---|---|
| **Create** agent | Add row to skills overview table | Add full reference section |
| **Update** agent | Update `Use when` cell and MCP(s) cell if changed | Rewrite the agent's reference section to match |
| **Delete** agent | Remove row from skills overview table | Remove the agent's reference section entirely |

Never leave README or REFERENCE out of sync with an agent file change.

---

## Quality checklist

Before merging any agent file change, verify:

1. **Description ≤80 words** — verify with `wc -w` on the extracted description text
2. **Every step has imperative verbs** — "Call X", "Extract Y", "Check Z" — not "X is called" or "Y should be extracted"
3. **Every fallback path is explicit** — if a tool is unavailable, the skill says exactly what to do (stop, degrade, or use alternative)
4. **Inter-skill handoffs have trigger conditions** — "if [condition] → use b-[other]" with the specific condition, not just "consider using"
5. **No trigger keyword regression** — before rewriting a description, list all current trigger keywords and verify all survive in the new version

---

## New skill creation guide

### Folder structure

```
b-agents/
├── opencode/
│   ├── AGENTS.md         ← Global OpenCode rules (symlinked to ~/.agents/AGENTS.md)
│   └── b-new-skill.md    ← OpenCode agent file
├── install.sh
├── README.md
├── REFERENCE.md
└── AGENTS.md             ← Repo-level authoring conventions
```

### Naming convention

- `name` field: `b-[verb-or-noun]` in kebab-case
- Examples: `b-plan`, `b-docs`, `b-research`, `b-debug`
- Keep names short (1–2 words after `b-`)

### How to add to sync

1. Create `opencode/b-new-skill.md` with valid frontmatter (`name` + `description`)
2. `install.sh` picks it up automatically — no script changes needed
3. Update `README.md` skills overview table
4. Update `REFERENCE.md` with a detailed reference section
5. Commit, push, run `@b-sync` in OpenCode then restart OpenCode

### How to add a new MCP to the suite

1. Add the MCP to the `MCP dependencies` table in `README.md`
2. In each skill that uses it, add to the "Tools required" section with role label
3. Update the "All N MCPs must be connected" count in `README.md`
4. Document graceful degradation for every skill that uses the new MCP
