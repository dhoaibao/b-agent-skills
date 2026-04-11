# b-agents — Agent authoring conventions

Guidelines for creating, editing, and maintaining agents in this repository.

---

## Frontmatter spec

Every `claude/agents/b-[name].md` must begin with YAML frontmatter:

```yaml
---
name: b-agent-name
description: >
  [Trigger-focused description. Answer ONLY: "when should Claude Code route to this agent?"
  Include: ALWAYS trigger condition, key Vietnamese + English trigger phrases,
  one sentence distinguishing this from similar agents, and 1–2 <example> blocks.
  Do NOT include usage instructions — those go in the agent file body.]

  <example>
  Context: [Situation description]
  user: "[User request]"
  assistant: "[How assistant should respond]"
  <commentary>
  [Why this agent should be triggered]
  </commentary>
  </example>
model: sonnet  # or opus, haiku
color: blue    # optional, for visual distinction
---
```

**Required fields:**
- `name` — kebab-case, prefixed with `b-`
- `description` — trigger-focused, includes `<example>` blocks

**Optional fields:**
- `model` — `sonnet` (default), `opus` (complex reasoning), `haiku` (fast/cheap)
- `color` — visual label: `red`, `blue`, `green`, `purple`, `yellow`, `orange`, `cyan`, `pink`

**Model tiers:**
- `opus` — Tier 1 agents (complex reasoning, critical decisions): `b-plan`, `b-debug`
- `sonnet` — Tier 2 agents (balanced quality + cost): `b-review`, `b-research`

**Description rules:**
- Start with a one-line summary of what the agent does
- Include `ALWAYS use this agent when...` with specific trigger phrases
- Include both Vietnamese and English trigger keywords
- Include 1–2 `<example>` blocks (important for automatic routing in Claude Code)
- End with disambiguation from the most similar agent
- No step-by-step instructions, no tool lists, no output format details

---

## Agent file structure template

```markdown
---
name: b-example
description: >
  [Trigger-focused, with <example> blocks]
model: sonnet
color: blue
---

# b-example

$ARGUMENTS

[1–2 sentence summary of what this agent does and why it exists.]

## When to use
- [Bullet list of scenarios]

## When NOT to use *(optional but recommended)*
- [Scenarios that should trigger a different agent instead]

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

When deciding which MCPs an agent should use:

| Role | When to add | Example |
|---|---|---|
| **Primary** | Agent cannot function without it | context7 for b-docs |
| **Secondary** | Agent uses it conditionally for a specific step | context7 for b-research (HOWTO queries only) |
| **Optional** | Enhances quality but agent works without it | sequential-thinking for b-analyze |

**Rules:**
- Never add an MCP just to increase coverage — every MCP must have a clear use case in the Steps section
- Always document what happens when an optional/secondary MCP is unavailable
- Label each MCP in "Tools required" with its role: required vs `*(optional, for [condition])*`
- Always include a `Graceful degradation:` line summarizing fallback behavior

---

## Agent file sync rule

All agents live in `claude/agents/b-[name].md`. When changing agent files:

| Change type | Action |
|---|---|
| **Create** new agent | Create `claude/agents/b-[name].md` |
| **Update** agent | Edit `claude/agents/b-[name].md` directly |
| **Delete** agent | Delete `claude/agents/b-[name].md` |

**`claude/CLAUDE.md` sync** — update `claude/CLAUDE.md` (global rules) and `AGENTS.md` (repo rules) in the same commit when any of these change:

| Change | Section to update |
|---|---|
| Agent added or removed | Agent table in `claude/CLAUDE.md` |
| Git safety rules change | `## Git safety` in `claude/CLAUDE.md` |

**Agent file structure** — every `claude/agents/b-[name].md` follows this format:

```markdown
---
name: b-[name]
description: >
  [trigger-focused with <example> blocks]
model: [sonnet / opus / haiku]
color: [optional]
---

[Agent file body — # heading onward]
```

**How to update**: edit `claude/agents/b-[name].md` directly.

**How to add a new agent**:
1. Create `claude/agents/b-[name].md` with the structure above.
2. `install.sh` picks it up automatically — no script changes needed.
3. Update `TIERS.md` if the new agent has a specific model tier rationale.

---

## Doc sync rule

**Any change to an agent file — create, update, or delete — requires updating both `README.md` and `REFERENCE.md` in the same commit.**

| Change type | README.md | REFERENCE.md |
|---|---|---|
| **Create** agent | Add row to agents overview table | Add full reference section |
| **Update** agent | Update `Use when` cell and MCP(s) cell if changed | Rewrite the agent's reference section to match |
| **Delete** agent | Remove row from agents overview table | Remove the agent's reference section entirely |

Never leave README or REFERENCE out of sync with an agent file change.

---

## Quality checklist

Before merging any agent file change, verify:

1. **Description has `<example>` blocks** — at least one `<example>` block with `user:`, `assistant:`, and `<commentary>` for correct Claude Code routing
2. **Every step has imperative verbs** — "Call X", "Extract Y", "Check Z" — not "X is called" or "Y should be extracted"
3. **Every fallback path is explicit** — if a tool is unavailable, the agent says exactly what to do (stop, degrade, or use alternative)
4. **Inter-agent handoffs have trigger conditions** — "if [condition] → use b-[other]" with the specific condition, not just "consider using"
5. **No trigger keyword regression** — before rewriting a description, list all current trigger keywords and verify all survive in the new version

---

## New agent creation guide

### Folder structure

```
b-agent-skills/
├── claude/
│   ├── agents/
│   │   ├── b-plan.md
│   │   ├── b-research.md
│   │   ├── b-debug.md
│   │   └── b-review.md
│   └── CLAUDE.md         ← Global Claude Code rules (symlinked to ~/.claude/CLAUDE.md)
├── install.sh
├── README.md
├── REFERENCE.md
├── TIERS.md
└── AGENTS.md             ← Repo-level authoring conventions
```

### Naming convention

- `name` field: `b-[verb-or-noun]` in kebab-case
- Examples: `b-plan`, `b-docs`, `b-research`, `b-debug`
- Keep names short (1–2 words after `b-`)

### How to add to sync

1. Create `claude/agents/b-new-agent.md` with valid frontmatter (`name` + `description`)
2. `install.sh` picks it up automatically — no script changes needed
3. Update `README.md` agents overview table
4. Update `REFERENCE.md` with a detailed reference section
5. Commit, push, run the install script, then restart Claude Code

### How to add a new MCP to the suite

1. Add the MCP to the `MCP dependencies` table in `README.md`
2. In each agent that uses it, add to the "Tools required" section with role label
3. Update the "All N MCPs must be connected" count in `README.md`
4. Document graceful degradation for every agent that uses the new MCP
