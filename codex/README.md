# b-agent-skills — Codex Edition

Codex-compatible versions of all 12 b-agent-skills. Drop-in into `~/.agents/skills/` and Codex auto-triggers them via implicit invocation.

---

## Prerequisites

- **Codex CLI** installed and authenticated (`codex --version` works)
- **ChatGPT Plus or Pro** subscription (required for Codex)
- **git** installed on your machine
- API keys for the MCPs you want to use (see [MCP configuration](#mcp-configuration))

---

## Installation

### First time (bootstrap)

```bash
git clone https://github.com/dhoaibao/b-agent-skills.git ~/.b-agent-skills
bash ~/.b-agent-skills/codex/codex-sync.sh
```

### Update (everyday use)

```bash
bash ~/.b-agent-skills/codex/codex-sync.sh
```

### Project-level install (optional)

To install skills into the current project directory instead of user-level:

```bash
bash ~/.b-agent-skills/codex/codex-sync.sh --project
# Installs to: <current-dir>/.agents/skills/
```

---

## MCP configuration

Copy the example config and fill in your API keys:

```bash
mkdir -p ~/.codex
cp ~/.b-agent-skills/codex/config.toml.example ~/.codex/config.toml
```

Then open `~/.codex/config.toml` and replace each `YOUR_*_API_KEY_HERE` placeholder:

| MCP | Where to get the key |
|-----|---------------------|
| `brave-search` | [brave.com/search/api](https://brave.com/search/api/) |
| `firecrawl` | [firecrawl.dev](https://firecrawl.dev/) |
| `context7` | No key required (public endpoint) |
| `sequential-thinking` | No key required |
| `jcodemunch` | See jcodemunch documentation |

---

## Verification

After installation and config, verify everything is working:

```bash
# Check MCP connections
codex mcp list
```

All configured MCPs should show as connected. Then open a Codex session and try:

```
b-quick-search latest Node.js version
```

If the skill triggers and returns a result, the install is working.

To see all installed skills:
```
/skills
```

---

## Skill → MCP dependency map

| Skill | Required MCPs | Optional MCPs |
|-------|--------------|---------------|
| `b-gate` | none | — |
| `b-commit` | none | — |
| `b-tdd` | none | — |
| `b-review` | none | — |
| `b-sync` | none | — |
| `b-news` | brave-search | — |
| `b-quick-search` | brave-search | — |
| `b-docs` | context7 | firecrawl |
| `b-plan` | sequential-thinking | jcodemunch |
| `b-debug` | sequential-thinking | jcodemunch, brave-search, firecrawl |
| `b-analyze` | jcodemunch | sequential-thinking, brave-search |
| `b-research` | brave-search, firecrawl | context7, sequential-thinking |

Skills with no required MCPs work out of the box. Skills with optional MCPs degrade gracefully — they still function but with reduced capability.

---

## Known limitations

### firecrawl — HTTP transport in Codex cloud sandbox

**Affected skills**: `b-research` (required), `b-docs` (optional), `b-news` (optional), `b-debug` (optional)

Codex cloud sandbox may block outbound HTTP connections to Firecrawl's API. Symptoms:
- `firecrawl_scrape` returns a connection error or times out
- b-research fails at Step 4 (scrape)

**Mitigation options:**
1. **Run Codex locally** — Codex can run in local mode where outbound connections are allowed. This is the recommended fix.
2. **Local Firecrawl proxy** — Run a local Firecrawl server and point the MCP config to `http://localhost:3002`. Update `config.toml`:
   ```toml
   [mcpServers.firecrawl]
   command = "npx"
   args = ["-y", "firecrawl-mcp"]
   [mcpServers.firecrawl.env]
   FIRECRAWL_API_URL = "http://localhost:3002"
   FIRECRAWL_API_KEY = "test"
   ```

### jcodemunch — Local filesystem access in Codex cloud sandbox

**Affected skills**: `b-analyze` (required), `b-plan` (optional), `b-debug` (optional), `b-review` (optional)

jcodemunch indexes your local codebase and requires filesystem access. In Codex cloud mode, the sandbox may not have access to your project files.

**Mitigation**: Run Codex locally (`codex --local` or equivalent) when using jcodemunch-dependent skills. All affected skills degrade gracefully to Glob/Read fallback when jcodemunch is unavailable.

### b-gate and b-tdd — Shell commands in cloud sandbox

**Affected skills**: `b-gate`, `b-tdd`

These skills run lint, typecheck, test, and security commands via shell. In Codex cloud mode, dev tools (eslint, pytest, go, etc.) may not be installed in the sandbox.

**Mitigation**: Run Codex locally when using b-gate or b-tdd. Both skills report "not installed" for missing tools rather than failing silently.

### Agent tool (Explore subagent) — Claude Code only

The `b-research` skill in the original Claude Code edition uses an Agent tool (Explore subagent) for context isolation when scraping ≥4 URLs. This feature is specific to Claude Code and is not available in Codex.

The Codex edition of b-research uses direct parallel `firecrawl_scrape` calls for all URL counts instead. Behavior is equivalent; only the context isolation boundary differs.

---

## Updating skills

Skills are symlinked from `~/.b-agent-skills/codex/skills/`. To update:

```bash
bash ~/.b-agent-skills/codex/codex-sync.sh
```

This pulls the latest from GitHub and refreshes all symlinks.

---

## Differences from the Claude Code edition

| Feature | Claude Code | Codex |
|---------|-------------|-------|
| Skills directory | `~/.claude/skills/` | `~/.agents/skills/` |
| Plan files | `.claude/b-plans/` | `.agents/plans/` |
| MCP check command | `/mcp` | `codex mcp list` |
| MCP config format | JSON (settings.json) | TOML (config.toml) |
| Implicit invocation | automatic | `policy.allow_implicit_invocation: true` |
| Agent tool (subagent) | available | not available — direct parallel scraping used |
| Config docs | `CLAUDE.md` | `AGENTS.md` |

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Skill not triggering | Check `SKILL.md` has `policy.allow_implicit_invocation: true` in frontmatter |
| MCP not connected | Run `codex mcp list`, check `~/.codex/config.toml` for correct API key |
| firecrawl connection error | Run Codex locally; see [firecrawl limitation](#firecrawl--http-transport-in-codex-cloud-sandbox) |
| jcodemunch returns no results | Run Codex locally with project filesystem access |
| Symlink broken | Re-run `codex-sync.sh` to refresh |
| Skills not showing after sync | Run `grep -rL 'name:' ~/.agents/skills/*/SKILL.md` to find broken frontmatter |
