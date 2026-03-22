---
name: b-analyze
description: >
  Deep code analysis — map structure, measure complexity, find duplicates, produce actionable suggestions.
  ALWAYS use when the user says "analyze", "review this code", "phân tích", "code review",
  "refactor", "dọn dẹp code", "tìm code smell", "cải thiện code", "tái cấu trúc",
  or when asked to understand an unfamiliar codebase before changes.
  Distinct from b-debug: use b-analyze when code works but could be better, not when something is broken.
---

# b-analyze

Understand code before changing it. Use jcodemunch to map structure, measure quality,
and surface concrete improvements — not vague suggestions.

## When to use

- Before a refactor: understand what exists before changing it
- Code review: assess quality, consistency, and maintainability
- Onboarding to an unfamiliar codebase or module
- Identifying duplicate logic, high-complexity hotspots, or inconsistent patterns
- User says: "analyze", "review", "phân tích code", "refactor", "tìm code smell"

**Difference from b-debug**: b-analyze is for code that works but could be better.
b-debug is for code that is broken. If there's an error message → use b-debug instead.

## Tools required

From `jcodemunch` MCP server:
- `index_folder` — index a local codebase before querying
- `suggest_queries` — auto-surface entry points, language distribution, and key architectural symbols
- `get_repo_outline` — overview of all modules, files, and top-level symbols
- `get_file_outline` — functions, classes, and exports per file (supports batch: `file_paths=[]`)
- `get_symbols` — batch-load multiple symbol definitions efficiently
- `get_dependency_graph` — module coupling and circular dependency detection
- `search_symbols` — find duplicate or similarly-named functions across files
- `find_importers` — find all files that import a given module (dead code chain detection)
- `check_references` — verify if a symbol has any live references (dead code detection)
- `get_class_hierarchy` — map class inheritance trees for OOP codebases
- `get_related_symbols` — discover functions closely associated with a symbol (pattern similarity)
- `search_text` — search for literal strings or regex patterns (magic numbers, hardcoded values)

From `sequential-thinking` MCP server *(optional)*:
- `sequentialthinking` — structured prioritization of findings to produce an ordered action list

From `brave-search` MCP server *(optional)*:
- `brave_web_search` — look up refactoring solutions for named anti-patterns found during analysis

If jcodemunch is unavailable: Use `Glob` to map file structure and identify all relevant files. Use `Grep` to find symbol usages, duplicate function names, and repeated patterns across files. Use `Read` for file-level inspection. Note limitation: cross-file dependency tracking will be incomplete without jcodemunch — flag this in the report.

Graceful degradation: ✅ Possible — if jcodemunch unavailable, use Glob/Grep/Read for file analysis. Quality is reduced but the skill remains functional.

---

## Steps

### Step 1 — Define analysis scope

Clarify what to analyze and why:

- **Target**: specific file, directory, module, or layer (e.g. "the service layer", "all route handlers")
- **Goal**: what decision will this analysis inform? (refactor, code review, onboarding, pre-feature audit)
- **Depth**: quick overview vs deep structural analysis

If the user says "analyze the whole project" without further context, ask which layer or
concern matters most — analyzing everything produces noise.
Exception: if the project has fewer than 15 files, proceed with whole-project analysis without asking — the noise risk is low.

---

### Step 2 — Structural analysis

Use `jcodemunch` to map the target code in this order:

1. **Index first** — call `index_folder` with the absolute path to the project root (e.g. `/home/user/my-project`). Use `use_ai_summaries: false` for speed. Note the `repo` identifier returned in the response (format: `local/[name]-[hash]`) — you must pass this as `repo` to every subsequent jcodemunch call.
   - If `file_count` returns 0 or `symbol_count` is 0, jcodemunch does not support this file type (e.g. Markdown, config-only repos) → switch to the Glob/Grep fallback immediately.
1.5. **suggest_queries** (repo: ...) — call immediately after indexing. This auto-surfaces entry points, language distribution, and key architectural symbols. Use the output to focus subsequent queries on the most significant areas rather than scanning everything.
2. `get_repo_outline` (repo: the identifier from step 1) — overview of all modules, files, and top-level symbols
3. `get_file_outline` (batch: pass `file_paths=[...]` with the most relevant files from step 1.5) — inspect each file for functions, classes, and exports; use batch mode to load multiple files in one call instead of calling one at a time
4. `get_dependency_graph` — map module coupling; look for circular deps and tight coupling
5. `search_symbols` — find duplicate or similarly-named functions across files

From these, extract:
- **Call graph**: what calls what, entry points, leaf functions
- **Dependency map**: which modules depend on which, circular dependencies
- **File/module boundaries**: what's responsible for what
- **Size distribution**: unusually large files or functions are complexity hotspots

Goal: build a mental model of the code's shape before evaluating its quality.

---

### Step 3 — Quality analysis

With the structure mapped, evaluate:

**Complexity**
- Functions or methods with high cyclomatic complexity (flag anything >10)
- Deeply nested conditionals or loops
- Long functions that do more than one thing

**Duplication**
- Similar logic appearing in multiple places
- Copy-pasted error handling, validation, or transformation code
- Inconsistent patterns for the same concern (e.g. 3 different ways to handle errors)

**Cohesion & coupling**
- Modules that know too much about each other
- Single files/classes doing too many unrelated things
- Cross-layer violations (e.g. DB queries inside route handlers)

**Maintainability signals**
- Missing or misleading names (variables, functions, files)
- Magic numbers or hardcoded values: use `search_text(is_regex=true, pattern='[0-9]{4,}')` to find suspicious numeric constants; use `search_text` with specific string patterns to find hardcoded configuration values
- Dead code: use `check_references` on any function that appears to have no callers — a zero-reference count confirms dead code. Use `find_importers` to trace the full import chain before removing a module (verifies it truly has no dependents)

**Class hierarchy (OOP codebases)**
- Use `get_class_hierarchy` on base classes to map inheritance chains — hierarchies deeper than 3 levels are a coupling signal

**Pattern similarity**
- Use `get_related_symbols` on key functions to discover semantically similar functions across the codebase — candidates for consolidation or inconsistent implementations of the same concern

For any High finding that involves a named anti-pattern (e.g., circular dependency, god class, N+1 query, DB query in controller) → call `brave_web_search` with `'{pattern name} refactoring solution'`. Use the result to make the concrete suggestion in Step 4 more specific than a generic recommendation.

---

### Step 4 — Produce findings

Organize findings by severity:

- **🔴 High**: causes maintenance burden now, or will cause bugs soon (circular deps, very high complexity, cross-layer violations)
- **🟡 Medium**: technical debt that slows down development (duplication, inconsistent patterns, large functions)
- **🟢 Low**: nice-to-have improvements (naming, minor reorganization)

For each finding:
- State exactly what was found and where (file, function, line range if relevant)
- Explain why it's a problem — not just "this is bad"
- Suggest a concrete improvement — not just "refactor this"

After grouping findings by severity, call `sequentialthinking` with the question: "Given these findings, if the team can address only 3 issues this sprint, which 3 have the highest ROI and in what order?" Use the result to produce an **Ordered action list** at the top of the Recommended Next Steps section.

---

### Step 5 — Recommend next actions

Based on findings, suggest:

- If refactor is needed → hand off to `b-plan` to sequence the refactor safely
- If a specific pattern is broken → flag which functions need fixing and in what order
- If complexity is concentrated in one area → suggest splitting it first before any other changes
- If findings are minor → list them as a backlog, not urgent action

---

## Output format

```
### Analysis: [target — file, module, or layer]

**Scope**: [what was analyzed]
**Goal**: [what decision this informs]

---

**Structure overview**
[Call graph or module map — brief, not exhaustive]
[Key entry points, main dependencies]

---

**Findings**

🔴 High priority
- [Finding]: [where] — [why it's a problem] → [concrete suggestion]

🟡 Medium priority
- [Finding]: [where] — [why it's a problem] → [concrete suggestion]

🟢 Low priority
- [Finding]: [where] — [suggestion]

---

**Metrics snapshot**
- Highest complexity: `[function]` — cyclomatic complexity [N]
- Largest file: `[file]` — [N] lines
- Duplication detected: [yes/no — where]
- Circular dependencies: [yes/no — which]

---

**Recommended next steps**
1. [Most impactful action first]
2. ...

*Use `b-plan` to sequence the refactor if proceeding.*
```

---

## Rules

- Never suggest a refactor without first understanding the full structure — partial analysis leads to wrong recommendations
- Findings must be specific: file + function + reason, not "this module is messy"
- Every High finding must have a concrete suggestion, not just a complaint
- Don't fix anything during analysis — this skill produces findings, not changes
- If analysis reveals a bug (broken logic, not just poor style) → state: 'Root cause analysis needed. Run: `b-debug: [symptom] in [entry point]` to trace the execution path.'
- Keep Low findings in the report but don't let them dominate — focus on what actually matters
- After outputting findings, always recommend whether to proceed with `b-plan` or if the code is healthy enough to modify directly