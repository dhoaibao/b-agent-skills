# b-skills — Claude Code Global Rules

This file defines global Claude Code runtime rules. For repo-level skill authoring conventions, see the root `CLAUDE.md`.

## Claude Code workflow

Four skills covering the full development cycle:

| Skill | Role |
|---|---|
| `/b-plan` | Think before coding — decompose tasks, evaluate approaches, produce plan file |
| `/b-research` | All external knowledge — library docs, comparisons, multi-source research |
| `/b-debug` | Full-loop debugging — trace, confirm root cause, fix, verify |
| `/b-review` | Pre-PR review — logic correctness, requirements, edge cases, test adequacy |

**Typical flow:**
```
/b-plan → [implement manually] → /b-review → commit
/b-research (any time you need docs or comparisons)
/b-debug (any time something breaks)
```

## Invoking skills

Type `/` followed by the skill name in Claude Code:

```
/b-plan add rate limiting to the API
/b-research how to use Prisma transactions
/b-research compare BullMQ vs Bee-Queue
/b-debug webhook not triggering despite correct URL
/b-review
```

## Mandatory MCP toolset usage

> **Iron rule**: when an MCP is connected and available, its toolset **MUST** be used. Using native tools (Glob/Grep/Read/Bash/WebFetch) when the equivalent MCP is available is a violation — not a preference. Native tools are **last-resort fallbacks only**.

**How to check MCP availability**: treat each MCP as available unless a call returns a connection error. Do not pre-emptively skip MCPs based on assumptions.

---

### Code intelligence — Serena MCP (REQUIRED when available)

When Serena is connected: **never** use Glob, Grep, or Read as your first move to understand a codebase.

**Working style rule**: use Serena to activate the project, narrow by symbol/file, then read narrowly.
- Start with `activate_project` for the current workspace.
- If onboarding has not been performed, run `check_onboarding_performed` and `onboarding` once.
- Prefer `find_symbol` before `get_symbols_overview`.
- Prefer `get_symbols_overview` before `read_file`.
- Use `find_referencing_symbols` before broad manual searches when following impact across files.
- Use `search_for_pattern` for exact strings, error text, or repeated implementation patterns.
- For edits, prefer symbol-aware tools first: `replace_symbol_body`, `insert_before_symbol`, `insert_after_symbol`, `rename_symbol`, then `replace_content` only when symbolic edits are insufficient.

**Mandatory substitution table — no exceptions when Serena is available:**

| Native tool / action | ✅ MUST use instead (Serena) |
|---|---|
| `Glob("**/*.ts")` to find files | `find_file` / `list_dir` |
| `Read("src/foo.ts")` to read a file | `get_symbols_overview` → `read_file` |
| `Grep("functionName")` to find a symbol | `find_symbol` |
| `Grep("import.*foo")` to trace usages | `find_referencing_symbols` |
| `Grep("foo(")` to find call sites | `find_referencing_symbols` / `search_for_pattern` |
| Reading file structure by hand | `get_symbols_overview` |
| Checking if a symbol is used | `find_referencing_symbols` |
| Searching for error strings/config keys | `search_for_pattern` |
| Manual symbol-body edits | `replace_symbol_body` |
| Manual rename across files | `rename_symbol` |

**Serena preflight** — run at the start of any skill that needs to understand existing code:

1. `activate_project` for the current workspace path.
2. `check_onboarding_performed` — if onboarding is missing, run `onboarding` before deeper exploration.
3. `get_current_config` when tool availability or context looks wrong.
4. Start discovery with `find_symbol`, `find_file`, or `list_dir` based on the task.

**Best-practice Serena workflow**:
1. `activate_project`
2. `check_onboarding_performed` → `onboarding` if needed
3. `find_symbol` / `find_file` / `search_for_pattern`
4. `get_symbols_overview`
5. `find_referencing_symbols`
6. `read_file` only for the exact symbol/file section still needed
7. Edit with `replace_symbol_body` / `insert_before_symbol` / `insert_after_symbol` / `rename_symbol`
8. Use `replace_content` only when Serena's symbolic tools cannot express the exact change safely

**Read-order heuristic**:
1. `find_symbol` / `search_for_pattern`
2. `get_symbols_overview`
3. `find_referencing_symbols`
4. `read_file` only if still necessary

**Token-efficiency rule**:
- Do not open full files by default.
- Use symbol overview first, then only the exact symbol/file section you need.
- Use `search_for_pattern` for strings/config/errors; use `find_symbol` for code entities.

**Session reuse**: if Serena already activated the current project in this session, reuse that context only after confirming you are still in the same workspace.

**Fallback** *(only when Serena is unavailable or the project cannot be activated cleanly)*: use `Glob` + `Grep` + `Read`. Always note one of:
- "⚠️ Serena unavailable — analysis based on Glob/Grep/Read; cross-file tracking incomplete."
- "⚠️ Serena project activation failed — falling back to filesystem-native checks."
- "⚠️ workspace is empty — no code structure available for Serena analysis."

---

### Web search — Brave Search + Firecrawl (REQUIRED when available)

When brave-search or firecrawl is connected: **never** use `WebFetch` directly.

**Mandatory substitution table:**

| Native tool / action | ✅ MUST use instead |
|---|---|
| `WebFetch(url)` to search for info | `brave_web_search(query)` → then `firecrawl_scrape(url)` |
| `WebFetch(url)` to read a known page | `firecrawl_scrape(url, formats=["markdown"])` |
| Manually guessing and fetching URLs | `firecrawl_map(url, search=...)` to discover the right URL first |
| Repeated `WebFetch` for multi-page coverage | `firecrawl_crawl(url, limit=N)` |
| News / current events lookup | `brave_news_search(query, freshness=...)` |

**Search-first rule**: always call `brave_web_search` first, then `firecrawl_scrape` on the top 1–3 results.

**Fallback chain** *(only when MCPs are unavailable)*:
- brave-search unavailable → use `firecrawl_search` (combined search+scrape).
- firecrawl unavailable → use `WebFetch` as last resort.

---

### Library documentation — Context7 (REQUIRED when available)

When context7 is connected: **never** rely on training knowledge for library APIs, method signatures, or framework behavior.

**Mandatory substitution table:**

| Native action | ✅ MUST use instead (context7) |
|---|---|
| Recalling a library method from memory | `resolve-library-id` → `query-docs(topic="method name")` |
| Assuming an API signature is correct | `query-docs` to verify before writing code |
| Guessing config options | `query-docs(topic="configuration options")` |
| Writing integration code without checking | `resolve-library-id` → `query-docs` first, always |

**Call order**: always `resolve-library-id` first (get exact library ID), then `query-docs` with a focused topic.

**Fallback** *(only when context7 is unavailable)*:
1. Try `firecrawl_scrape` on the official docs URL.
2. If scrape fails: invoke `/b-research` to retrieve docs.
3. Never fall back to training-data assumptions.

---

### Reasoning — Sequential Thinking (REQUIRED when available for complex problems)

When sequential-thinking is connected: **never** reason through a complex multi-step problem with free-form prose alone.

**Mandatory trigger conditions — MUST call `sequentialthinking` when:**

| Situation | Why sequentialthinking is required |
|---|---|
| Debugging with >2 hypotheses | Tracks ranked hypotheses, eliminates ruled-out paths explicitly |
| Architecture or data-flow design | Surfaces trade-offs and dependency ordering that prose misses |
| Decomposing a vague requirement into steps | Produces atomic, ordered, dependency-aware steps |
| Trade-off analysis between approaches | Forces structured comparison, prevents anchoring bias |
| Prioritizing a list of findings by impact | Produces an evidence-based ordering, not intuition |

**Fallback** *(only when sequential-thinking is unavailable)*: structure reasoning as an explicit numbered list with `Hypothesis N → Evidence → Confirmed/Rejected` format.

---

### MCP priority order (global rule — enforced, not advisory)

```
MCP toolset  >  specialized native tool  >  general native tool  >  Bash command
```

| Task | 1st choice (MUST) | 2nd choice | Last resort |
|---|---|---|---|
| Read a source file | `serena:get_symbols_overview` / `read_file` | `Read` tool | `cat` via Bash |
| Find a function | `serena:find_symbol` | `Grep` tool | `grep` via Bash |
| Edit existing symbol | `serena:replace_symbol_body` / `insert_*` / `rename_symbol` | `apply_patch` | line-edit via shell |
| Search the web | `brave_web_search` | `firecrawl_search` | `WebFetch` |
| Scrape a URL | `firecrawl_scrape` | `WebFetch` | — |
| Library API lookup | `context7:query-docs` | `firecrawl_scrape(docs URL)` | training knowledge (❌ avoid) |
| Complex reasoning | `sequentialthinking` | numbered prose with explicit steps | inline prose (❌ avoid) |

---

## Setup

### MCP verification
Run `/mcp` in Claude Code and confirm all MCPs show as connected. If a MCP is missing or fails to connect, reinstall it.

### Serena hooks (strongly recommended)
Claude Code's dynamic tool loading causes **agent drift** — the agent forgets to use Serena's tools after a few tool calls. Fix this with hooks.

Add to `~/.claude/settings.json` (or `~/.claude.json` if that's your settings file):

```json
{
  "hooks": {
    "PreToolUse": [
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
      },
      {
        "matcher": "",
        "hooks": [
          { "type": "command", "command": "serena-hooks remind --client=claude-code" }
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

What the hooks do:
- **`activate`** — activates the project and re-reads Serena's instructions at session start. Eliminates the need to manually activate on every session.
- **`remind`** — nudges the agent to use Serena's symbolic tools when it makes too many consecutive `grep`/`read_file` calls without using any Serena tool.
- **`auto-approve`** — auto-approves Serena tool calls in `acceptEdits` mode so blanket edit approvals cover symbol-level edits.
- **`cleanup`** — cleans up hook session data when the session ends.

If hooks cause issues (e.g. repeated reminders), remove the specific hook causing the loop. The `PreToolUse` hooks on `mcp__serena__*` are the most impactful; the others are additive.

---

## Git safety

Never run these commands autonomously:
- `git push`, `git pull`, `git commit`, `git reset --hard`
- `git revert`, `git clean -f`, `git branch -D`

Rollback (`git checkout -- .`) must be **offered to the user**, never auto-executed.

---

## Coding principles (Karpathy)

> Derived from [Andrej Karpathy's observations](https://x.com/karpathy/status/2015883857489522876) on LLM coding pitfalls.
> Bias toward caution over speed. For trivial tasks, use judgment.

### 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them — don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

### 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

### 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it — don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: every changed line should trace directly to the user's request.

### 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.
