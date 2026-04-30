# b-skills — Repo conventions & skill authoring

Guidelines for creating, editing, and maintaining Claude Code skills in this repository.

## Quick links

- `skills/b-plan/SKILL.md` — Task decomposition and planning
- `skills/b-research/SKILL.md` — Library docs and multi-source research
- `skills/b-debug/SKILL.md` — Hypothesis-driven debugging
- `skills/b-review/SKILL.md` — Pre-PR code review
- `skills/global/CLAUDE.md` — Behavioral rules (installed to `~/.claude/CLAUDE.md`)
- `skills/global/REFERENCE.md` — Operational reference (MCP details, setup, session mgmt)

---

## Frontmatter spec

Every `skills/<name>/SKILL.md` must begin with YAML frontmatter:

```yaml
---
name: b-skill-name
description: >
  [Trigger-focused description, ≤80 words. Answer ONLY: "when should Claude Code invoke this skill?"
  Include: ALWAYS trigger condition, key Vietnamese + English trigger phrases,
  and one sentence distinguishing this from similar skills.
  Do NOT include usage instructions — those go in the skill body.]
effort: [low | medium | high | max]
---
```

**Required fields:**
- `name` — kebab-case, prefixed with `b-`
- `description` — ≤80 words, trigger-focused only

**Optional fields:**
- `effort` — reasoning effort level (low, medium, high, max). Default is medium.
- `model` — model override (sonnet, opus, haiku, or full model ID). Omit to use default.
- `disable-model-invocation` — set `true` to prevent auto-trigger; skill can only be invoked via `/skill-name`.
- `user-invocable` — set `false` to hide from `/` menu; skill is loaded automatically when context matches.
- `paths` — glob patterns limiting when the skill activates (e.g., `"src/api/**/*.ts"`).

**Description rules:**
- Start with a one-line summary of what the skill does
- Include `ALWAYS invoke when...` with specific trigger phrases
- Include both Vietnamese and English trigger keywords
- End with disambiguation from the most similar skill
- No step-by-step instructions, no tool lists, no output format details

---

## Skill directory structure template

```
skills/<name>/
├── SKILL.md           # Main instructions (required)
├── reference.md       # Detailed reference (optional)
├── examples.md        # Usage examples (optional)
└── scripts/           # Utility scripts (optional)
    └── helper.sh
```

For this repo, each skill currently uses a single `SKILL.md` file. Additional files can be added as needed.

---

## Skill file structure template

```markdown
---
name: b-example
description: >
  [≤80 words, trigger-focused]
effort: [low | medium | high | max]
---

# b-example

$ARGUMENTS

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
| **Primary** | Skill cannot function without it | brave-search for b-research |
| **Secondary** | Skill uses it conditionally for a specific step | context7 for b-research (HOWTO queries only) |
| **Optional** | Enhances quality but skill works without it | sequential-thinking for b-review |

**Rules:**
- Never add an MCP just to increase coverage — every MCP must have a clear use case in the Steps section
- Always document what happens when an optional/secondary MCP is unavailable
- Label each MCP in "Tools required" with its role: required vs `*(optional, for [condition])*`
- Always include a `Graceful degradation:` line summarizing fallback behavior

---

## Skill file sync rule

All skills live in `skills/<name>/SKILL.md`. When changing skill files:

| Change type | Action |
|---|---|
| **Create** new skill | Create `skills/<name>/SKILL.md` |
| **Update** skill | Edit `skills/<name>/SKILL.md` directly |
| **Delete** skill | Delete `skills/<name>/SKILL.md` (and the directory if empty) |

**`skills/global/` sync** — update both `skills/global/CLAUDE.md` and `skills/global/REFERENCE.md` in the same commit when any of these change:

| Change | File to update | Section to update |
|---|---|---|
| Skill added or removed | `REFERENCE.md` | Skill table |
| Git safety rules change | `CLAUDE.md` or `REFERENCE.md` | `## Git safety` |
| MCP tool details change | `REFERENCE.md` | `## MCP Tool Details` |

---

## Doc sync rule

**Any change to a skill file — create, update, or delete — requires updating both `README.md` and `REFERENCE.md` in the same commit.**

| Change type | README.md | REFERENCE.md |
|---|---|---|
| **Create** skill | Add row to skills overview table | Add full reference section |
| **Update** skill | Update `Use when` cell and MCP(s) cell if changed | Rewrite the skill's reference section to match |
| **Delete** skill | Remove row from skills overview table | Remove the skill's reference section entirely |

Never leave README or REFERENCE out of sync with a skill file change.

---

## Quality checklist

Before merging any skill file change, verify:

1. **Description ≤80 words** — verify with `wc -w` on the extracted description text
2. **Every step has imperative verbs** — "Call X", "Extract Y", "Check Z" — not "X is called" or "Y should be extracted"
3. **Every fallback path is explicit** — if a tool is unavailable, the skill says exactly what to do (stop, degrade, or use alternative)
4. **Inter-skill handoffs have trigger conditions** — "if [condition] → use /b-[other]" with the specific condition, not just "consider using"
5. **No trigger keyword regression** — before rewriting a description, list all current trigger keywords and verify all survive in the new version

---

## New skill creation guide

### Folder structure

```
b-skills/
├── skills/
│   ├── global/
│   │   └── CLAUDE.md      ← Global Claude Code rules (symlinked to ~/.claude/CLAUDE.md)
│   ├── b-plan/
│   │   └── SKILL.md
│   ├── b-research/
│   │   └── SKILL.md
│   ├── b-debug/
│   │   └── SKILL.md
│   └── b-review/
│       └── SKILL.md
├── install.sh
├── README.md
├── REFERENCE.md
├── TIERS.md
└── CLAUDE.md              ← Repo-level instructions + authoring conventions
```

### Naming convention

- `name` field: `b-[verb-or-noun]` in kebab-case
- Examples: `b-plan`, `b-docs`, `b-research`, `b-debug`
- Keep names short (1–2 words after `b-`)

### How to add a new skill

1. Create `skills/<name>/SKILL.md` with valid frontmatter (`name` + `description`)
2. `install.sh` picks it up automatically — no script changes needed
3. Update `README.md` skills overview table
4. Update `REFERENCE.md` with a detailed reference section
5. Commit, push, run the install script, then restart Claude Code

### How to add a new MCP to the suite

1. Add the MCP to the `MCP dependencies` table in `README.md`
2. In each skill that uses it, add to the "Tools required" section with role label
3. Update the "All N MCPs must be connected" count in `README.md`
4. Document graceful degradation for every skill that uses the new MCP