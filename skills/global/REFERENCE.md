# Global Rules — Reference

Operational details, MCP tool documentation, and setup instructions. See [CLAUDE.md](CLAUDE.md) for behavioral rules enforced every turn.

---

## MCP Tool Details

### Serena MCP (code intelligence)

**Workflow:**
1. `check_onboarding_performed` → `onboarding` if missing
2. `find_symbol` to locate functions, classes, methods
3. `get_symbols_overview` on relevant files to understand structure
4. `find_referencing_symbols` on shared/exported symbols to map impact

**Symbol edit tools:**
- `replace_symbol_body` — replace entire function/class/method body
- `insert_before_symbol` / `insert_after_symbol` — insert relative to a known symbol
- `rename_symbol` — rename a symbol across references
- `safe_delete_symbol` — delete a symbol only if no references exist

**Memory tools:** `list_memories`, `read_memory`, `write_memory`, `edit_memory`, `delete_memory`, `rename_memory`

**Direct native-tool exceptions (Serena lacks file/search tools):**
- File listing, discovery, exact string search, config inspection
- User explicitly names a small file to inspect
- Non-code prose (`*.md`, `*.txt`)
- Small manifests (`package.json`, `pyproject.toml`, `Makefile`, non-secret YAML/JSON)

> ⚠️ These exceptions do not apply to sensitive files or broad exploration when Serena tools can answer.

### Brave Search + Firecrawl

**Search-first rule:** `brave_web_search` → then `firecrawl_scrape` on top 1–3 results.

**Direct-scrape exceptions** (skip search, scrape directly):
- User provides a URL
- Skill explicitly requires a known official/source URL (changelog, release notes)
- URL already discovered via `firecrawl_map` or prior search

**Firecrawl tools by use case:**
| Tool | Use when |
|---|---|
| `firecrawl_scrape` | Single page content, docs, issues, changelogs |
| `firecrawl_search` | Brave returns <3 results (combined search+scrape) |
| `firecrawl_map` | Scrape returns empty/JS-rendered — discover correct URL |
| `firecrawl_extract` | Specific fields, prices, API params, specs — use JSON schema |
| `firecrawl_crawl` | Deep multi-page doc site crawl |
| `firecrawl_check_crawl_status` | Poll crawl job until `status: "completed"` |

**Fallback chain:** brave-search unavailable → `firecrawl_search` → `WebFetch` (last resort).

### Context7 (library docs)

Always: `resolve-library-id` first → `query-docs` with focused topic.

**Fallback (only when unavailable):**
1. `firecrawl_scrape` on official docs URL
2. If scrape fails: invoke `/b-research`
3. Never fall back to training knowledge

### Sequential Thinking (complex reasoning)

**Mandatory triggers:**
- Debugging with >2 hypotheses
- Architecture or data-flow design
- Decomposing vague requirements into steps
- Trade-off analysis between approaches
- Prioritizing findings by impact

**Fallback:** numbered list with `Hypothesis N → Evidence → Confirmed/Rejected`.

---

## Setup & Installation

### MCP verification
Run `/mcp` in Claude Code. All MCPs should show as connected. Reinstall any that fail.

### Serena hooks (recommended)

Claude Code's dynamic tool loading causes **agent drift**. Fix with hooks in `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "",
        "hooks": [
          { "type": "command", "command": "serena-hooks remind --client=claude-code" }
        ]
      },
      {
        "matcher": "mcp__serena__*",
        "hooks": [
          { "type": "command", "command": "serena-hooks auto-approve --client=claude-code" }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          { "type": "command", "command": "serena-hooks activate --client=claude-code" }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          { "type": "command", "command": "serena-hooks cleanup --client=claude-code" }
        ]
      }
    ]
  }
}
```

**What each hook does:**
- **`remind`** — nudges toward Serena tools when too many `grep`/native reads without any Serena call
- **`auto-approve`** — auto-approves Serena symbol edits
- **`activate`** — prompts project activation at session start
- **`cleanup`** — cleans up hook session data on exit

If hooks cause repeated reminders, remove the specific hook causing the loop.

### Serena project auto-activation

Add `--project-from-cwd` to the Serena MCP command:
```bash
claude mcp add --scope user serena -- serena start-mcp-server --context claude-code --project-from-cwd
```

---

## Session Management

### Compaction
After ~20 tool calls or degraded responses (slower, less precise), call `/compact`.

**After compaction:**
1. Re-read active plan file from `.claude/b-plans/`
2. `check_onboarding_performed` → `onboarding` if false
3. Re-read relevant skill instructions

### State handoff between sessions
1. Run `git status`
2. If uncommitted changes: `git diff` → summarize briefly
3. If plan exists: remind user of next step
4. Serena memories persist automatically

### Avoiding context window exhaustion
- Do not paste full file contents unless necessary
- Use Serena symbol tools instead of reading entire files
- For large diffs: focus on changed symbols only
- If >15 tool calls needed: split into smaller sub-tasks or `/compact`

---

## Skill Invocation

Type `/` followed by skill name in Claude Code:

```
/b-plan add rate limiting to the API
/b-research how to use Prisma transactions
/b-research compare BullMQ vs Bee-Queue
/b-debug webhook not triggering despite correct URL
/b-review
```

**Typical flow:**
```
/b-plan → approve plan → implement → targeted checks → /b-review → commit
/b-research (any time you need docs or comparisons)
/b-debug (any time something breaks)
```

---

## MCP Substitution Table (detailed)

| Task | 1st choice (MUST) | 2nd choice | Last resort |
|---|---|---|---|
| Inspect code structure | `serena:get_symbols_overview` | `Read` tool | `cat` via Bash |
| Find a function/class/method | `serena:find_symbol` | native search | `grep` via Bash |
| Trace symbol references | `serena:find_referencing_symbols` | native search | `grep` via Bash |
| Edit existing whole symbol | `serena:replace_symbol_body` / `insert_before_symbol` / `insert_after_symbol` / `rename_symbol` | `Edit` tool | line-edit via shell |
| Delete a symbol safely | `serena:safe_delete_symbol` | manual check + `Edit` | line-edit via shell |
| Create/read/list/search files | native `Write`/`Read`/Bash search | — | shell fallback |
| Search the web | `brave_web_search` | `firecrawl_search` | `WebFetch` |
| Scrape a URL | `firecrawl_scrape` | `WebFetch` | — |
| Library API lookup | `context7:query-docs` | `firecrawl_scrape(docs)` | training (❌) |
| Complex reasoning | `sequentialthinking` | numbered steps | inline prose (❌) |