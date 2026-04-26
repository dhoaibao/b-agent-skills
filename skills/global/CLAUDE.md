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
/b-plan → approve plan → implement from plan/protocol → run targeted checks → /b-review → commit
/b-research (any time you need docs or comparisons)
/b-debug (any time something breaks)
```

**Implementation protocol** *(after a plan is approved)*:
1. Read the approved chat plan or `.claude/b-plans/[task].md` before editing.
2. Follow confirmed decisions and planned touch points; do not reopen settled decisions unless blocked.
3. Execute steps in dependency order and keep changes surgical.
4. Verify each step using its `Done when` check or the narrowest relevant test/typecheck.
5. Stop and ask if implementation reveals a new product/behavior decision.
6. After implementation, run `/b-review` for non-trivial changes before committing.

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

When Serena is connected: use it for the operations it actually supports in this environment: symbol discovery, file structure overview, reference tracing, whole-symbol edits, safe symbol deletion, renames, and Serena memories. Do not document or call Serena tools that are not exposed in the current toolset.

**Supported Serena toolset in this suite:**

| Category | Tools |
|---|---|
| **workflow** | `initial_instructions`, `check_onboarding_performed`, `onboarding` |
| **symbol read** | `find_symbol`, `get_symbols_overview`, `find_referencing_symbols` |
| **symbol edit** | `replace_symbol_body`, `insert_before_symbol`, `insert_after_symbol`, `rename_symbol`, `safe_delete_symbol` |
| **memory** | `list_memories`, `read_memory`, `write_memory`, `edit_memory`, `delete_memory`, `rename_memory` |

**Unsupported Serena capabilities in this environment**: file listing/discovery, file reads, exact-string search, config inspection, generic file creation, and arbitrary text replacement are not exposed through Serena. Use native `Read`, `Edit`, `Write`, or Bash search for those gaps.

**Working style rule**: use Serena first when the task is about code symbols or cross-file impact.
- Start with `check_onboarding_performed`; if onboarding is missing, call `onboarding` before deeper exploration.
- Use `find_symbol` to locate known functions, classes, commands, handlers, or methods.
- Use `get_symbols_overview` to inspect a relevant file's top-level structure before reading full source.
- Use `find_referencing_symbols` before broad manual searches when following callers, dependents, or impact.
- Use native `Read` only after Serena identifies the relevant file/symbol or when the file is prose/config/non-code.
- Use native Bash search for exact strings, error text, config keys, or repeated patterns because Serena pattern search is not exposed.
- For edits, prefer supported symbol-aware tools first: `replace_symbol_body`, `insert_before_symbol`, `insert_after_symbol`, `rename_symbol`, `safe_delete_symbol`. Use native `Edit` for line-level patches inside a larger symbol or prose/config changes.

**Direct native-tool exceptions** *(because Serena lacks file/search tools here)*: native `Read`, `Edit`, `Write`, and Bash search are acceptable after sensitivity checks when:
- The task needs file listing, file discovery, exact string search, or config/prose inspection.
- The user explicitly names a small file to inspect.
- The file is non-code prose (`*.md`, `*.txt`) where symbol tools add no value.
- The file is a small manifest/config needed for orientation (`package.json`, `pyproject.toml`, `Cargo.toml`, `Makefile`, non-secret YAML/TOML/JSON).
- Serena has identified the relevant file/symbol and a narrow source read is still needed.

These exceptions do not apply to sensitive files (`.env*`, credentials, secrets, tokens) or broad source-code exploration when supported Serena symbol tools can answer the question.

**Mandatory substitution table — use Serena when the operation is supported:**

| Task | ✅ Use Serena | Use native tools when |
|---|---|---|
| Locate a known symbol | `find_symbol` | The target is not a code symbol or the language server cannot resolve it |
| Inspect file structure | `get_symbols_overview` | The file is prose/config or unsupported by Serena |
| Trace usages/callers | `find_referencing_symbols` | You need raw text matches instead of semantic references |
| Replace an entire function/class/method | `replace_symbol_body` | You only need a few line-level edits inside a larger symbol |
| Insert code before/after a known symbol | `insert_before_symbol` / `insert_after_symbol` | The insertion point is not symbol-relative |
| Rename a symbol across references | `rename_symbol` | The rename is textual/prose-only |
| Delete a symbol safely | `safe_delete_symbol` | The deletion is not a code symbol |
| Store/read durable Serena context | memory tools | The information is ephemeral task state |

**Best-practice Serena workflow**:
1. `check_onboarding_performed` → `onboarding` if needed.
2. `find_symbol` for the likely entry point or changed symbol.
3. `get_symbols_overview` on relevant files to understand structure.
4. `find_referencing_symbols` on exported/public/shared symbols to map impact.
5. Use native `Read` narrowly only for source bodies/prose/config still needed after symbol discovery.
6. Edit with supported symbol tools for whole-symbol changes; use native `Edit` for smaller line patches.
7. Use Serena memory tools only for durable project/user/feedback/reference context, not temporary task notes.

**Token-efficiency rule**:
- Do not open full source files by default.
- Use symbol search/overview/references first, then only the exact source or prose section still needed.
- Use native string search for exact error messages, config keys, and repeated text patterns.

**Fallback** *(only when Serena is unavailable or cannot analyze the language/file)*: use native Bash search + `Read`. Note: "⚠️ Serena unavailable or unsupported for this file — analysis used native file/search tools; semantic cross-file tracking may be incomplete."

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

**Search-first rule**: call `brave_web_search` first, then `firecrawl_scrape` on the top 1–3 results, unless a direct-scrape exception applies.

**Direct-scrape exceptions**: call `firecrawl_scrape` directly when:
- The user provides a URL to inspect.
- A skill explicitly requires direct scrape of a known official/source URL (for example, official changelog or release notes).
- The correct URL was already discovered via `firecrawl_map`, prior search results, or repo documentation in the same task.

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
| Inspect code structure | `serena:get_symbols_overview` | `Read` tool | `cat` via Bash |
| Find a function/class/method | `serena:find_symbol` | native search | `grep` via Bash |
| Trace symbol references | `serena:find_referencing_symbols` | native search | `grep` via Bash |
| Edit existing whole symbol | `serena:replace_symbol_body` / `insert_before_symbol` / `insert_after_symbol` / `rename_symbol` | `Edit` tool | line-edit via shell |
| Delete a symbol safely | `serena:safe_delete_symbol` | manual reference check + `Edit` | line-edit via shell |
| Create/read/list/search files | native `Write` / `Read` / Bash search | — | shell fallback |
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

**Project auto-activation**: add `--project-from-cwd` to the Serena MCP server command so it activates the current directory automatically on startup (no hook needed):
```bash
claude mcp add --scope user serena -- serena start-mcp-server --context claude-code --project-from-cwd
```

Add the following hooks to `~/.claude/settings.json`:

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
- **`remind`** — nudges the agent to use Serena's symbolic tools when it makes too many consecutive `grep`/native reads calls without using any Serena tool.
- **`auto-approve`** — auto-approves Serena tool calls in `acceptEdits` mode so blanket edit approvals cover symbol-level edits.
- **`cleanup`** — cleans up hook session data when the session ends.

If hooks cause issues (e.g. repeated reminders), remove the specific hook causing the loop.

---

## Git safety

Never run these commands autonomously:
- `git push`, `git pull`, `git commit`, `git reset --hard`
- `git revert`, `git clean -f`, `git branch -D`

Rollback (`git checkout -- .`) must be **offered to the user**, never auto-executed.

---

## Sensitive file safety

Sensitive files (credentials, secrets, env files) must **never be modified or read without explicit user permission**.

Never autonomously:
- Read, edit, or commit `.env`, `.env.*`, `*.env`, `credentials.json`, `secrets.yml`, `settings.local.json`, or any file matching common secret/credential patterns
- Auto-add sensitive file paths to gitignore
- Create stub credentials files
- Suggest or generate API keys, tokens, or secrets

When a task touches a sensitive file:
1. **Stop** and state what the file is
2. **Ask** for explicit user permission before reading or modifying
3. After editing, **remind** the user to verify the change

This applies to any file that, if leaked or misconfigured, could cause security, financial, or access harm.

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
