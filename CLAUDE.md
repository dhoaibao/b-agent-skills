# b-agent-skills — Skill authoring conventions

Guidelines for creating, editing, and maintaining skills in this repository.

---

## Frontmatter spec

Every `SKILL.md` must begin with YAML frontmatter:

```yaml
---
name: b-skill-name
description: >
  [Trigger-focused description, ≤80 words. Answer ONLY: "when should Claude trigger this skill?"
  Include: ALWAYS trigger condition, key Vietnamese + English trigger phrases,
  and one sentence distinguishing this from similar skills.
  Do NOT include usage instructions — those go in the SKILL.md body.]
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

## SKILL.md structure template

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

## Doc sync rule

**Any change to a skill — create, update, or delete — requires updating both `README.md` and `REFERENCE.md` in the same commit.**

| Change type | README.md | REFERENCE.md |
|---|---|---|
| **Create** skill | Add row to skills overview table | Add full reference section |
| **Update** skill | Update `Use when` cell and MCP(s) cell if changed | Rewrite the skill's reference section to match |
| **Delete** skill | Remove row from skills overview table | Remove the skill's reference section entirely |

Never leave README or REFERENCE out of sync with a SKILL.md change. If a PR touches `b-[skill]/SKILL.md`, it must also touch both doc files.

---

## Quality checklist

Before merging any SKILL.md change, verify:

1. **Description ≤80 words** — verify with `wc -w` on the extracted description text
2. **Every step has imperative verbs** — "Call X", "Extract Y", "Check Z" — not "X is called" or "Y should be extracted"
3. **Every fallback path is explicit** — if a tool is unavailable, the skill says exactly what to do (stop, degrade, or use alternative)
4. **Inter-skill handoffs have trigger conditions** — "if [condition] → use b-[other]" with the specific condition, not just "consider using"
5. **No trigger keyword regression** — before rewriting a description, list all current trigger keywords and verify all survive in the new version

---

## New skill creation guide

### Folder structure

```
b-agent-skills/
├── b-new-skill/
│   └── SKILL.md          ← only file needed
├── sync.sh
├── README.md
├── REFERENCE.md
└── CLAUDE.md
```

### Naming convention

- Folder and `name` field: `b-[verb-or-noun]` in kebab-case
- Examples: `b-plan`, `b-docs`, `b-research`, `b-debug`
- Keep names short (1–2 words after `b-`)

### How to add to sync

1. Create the folder at repo root: `mkdir b-new-skill`
2. Add `b-new-skill/SKILL.md` with valid frontmatter (`name` + `description`)
3. `sync.sh` picks up any root folder containing `SKILL.md` automatically — no script changes needed
4. Update `README.md` skills overview table
5. Update `REFERENCE.md` with a detailed reference section
6. Commit, push, run `sync.sh` on target machines

### How to add a new MCP to the suite

1. Add the MCP to the `MCP dependencies` table in `README.md`
2. In each skill that uses it, add to the "Tools required" section with role label
3. Update the "All N MCPs must be connected" count in `README.md`
4. Document graceful degradation for every skill that uses the new MCP
