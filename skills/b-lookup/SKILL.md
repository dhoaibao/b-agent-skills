---
name: b-lookup
description: >
  Ultra-fast single-fact library or API lookup. ALWAYS invoke when the user says
  "lookup", "tra cứu nhanh", "what's the API for", "method signature of X",
  "config key for Y", "does X support Y", or a one-sentence question answerable in 1-3
  sentences. Use instead of /b-research for micro-questions. Unlike b-research
  (full report with citations), b-lookup returns a concise answer in seconds with
  no scraping or synthesis.
effort: low
---

# b-lookup

$ARGUMENTS

Ultra-fast single-fact lookup. No pipeline, no report — just a direct answer
in 1-3 sentences, backed by Context7 or a single web search.

If `$ARGUMENTS` is provided, treat it as the lookup question — proceed directly
to Step 1. Do not ask "what do you want to look up?".

## When to use

- User asks a one-sentence question answerable in 1-3 sentences.
- Method signature, config key, yes/no capability, minimal working example.
- User says: "lookup", "tra cứu nhanh", "what's the API for", "method signature of X",
  "config key for Y", "does X support Y", "how do I call Z".
- The answer fits in a single sentence or short code snippet.

## When NOT to use

- Multi-step question or open-ended research → use **b-research**
- Runtime bug or failure → use **b-debug**
- Need to decide what to build → use **b-plan**
- The question requires comparing multiple sources or synthesizing a report

## Tools required

- `resolve-library-id`, `query-docs` — from `context7` MCP server (primary; for library/framework questions)
- `brave_web_search` — from `brave-search` MCP server *(fallback when context7 has no match or the question is not library-specific)*

If context7 is unavailable: use `brave_web_search` directly as the primary tool.
If brave-search is unavailable and context7 fails: answer from training knowledge with a clear confidence caveat. Format as: `[answer] ⚠️ (low confidence — no MCP connected, verify independently)`.

Graceful degradation: ✅ Possible — fallback to brave-search or training knowledge with caveat.

## Steps

### Step 1 — Quick detect

Classify the question:

| Type | Example | Strategy |
|------|---------|----------|
| **Library API** | "What's the signature of Zod.string.parse?" | Context7 first |
| **Config/tool** | "Config key for retry in BullMQ?" | Context7 or Brave |
| **Yes/No** | "Does Prisma support native upsert?" | Context7 or Brave |
| **Minimal example** | "How to create a ReadableStream in Node?" | Context7 or Brave |

If the question clearly names a library → go to Step 2.
If not library-specific (stdlib, general tool config) → go to Step 3.

---

### Step 2 — Context7 lookup *(library questions)*

1. Call `resolve-library-id` with the library name and the specific topic.
2. Call `query-docs` with the specific method/feature/behavior in question.
3. If Context7 returns a clear answer → go to Step 4.
4. If Context7 returns no match or unclear → fall through to Step 3.

---

### Step 3 — Brave fallback

Call `brave_web_search` with the exact question (include library name if relevant).
Return the top result snippet as the answer — no scraping, no synthesis needed.
Cap at 1 search query. Do not loop.

---

### Step 4 — Present answer

Return a concise answer using the format in ## Output format.

---

## Output format

```
### `[Library]` — `[topic]`

[1–3 sentence direct answer]

**Example:**
```[lang]
// minimal working example
```

**Source**: Context7 (`library-id`) / Brave Search
```

Keep it to one short paragraph plus a minimal example. No citations list,
no limitations section, no follow-up recommendations. The format is intentional:
b-lookup is for answers, not reports.

---

## Rules

- Cap at 2 tool calls total (Context7 → Brave fallback, or just one or the other).
- Never scrape or crawl — if you need to read a page, use `/b-research` instead.
- Never synthesize — if the answer needs multiple sources, use `/b-research`.
- Never call `sequentialthinking` — this skill is intentionally simple.
- Return a direct answer, not a question back.
- If the question is ambiguous: return the most likely answer with a brief caveat, e.g.
  "Assuming you're using React 18, useEffect runs after paint. ⚠️ (verify version)"
- Never trigger destructive git commands.