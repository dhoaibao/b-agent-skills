---
name: b-quick-search
description: >
  Use Brave Search MCP to get a fast, cited answer from the live web in a single
  search call — no scraping, no deep synthesis.
  ALWAYS use this skill when the user asks to "search", "tìm kiếm", "look up",
  "tìm nhanh", "find latest", "tìm mới nhất", "what is the latest version of X",
  "recent news about X", or any query that needs a quick current-info lookup:
  latest releases, current prices, recent changelogs, CVEs, or anything where
  freshness matters and a fast answer is enough.
  Use b-research instead when the user wants depth, comparison, or a full report.
  When in doubt between the two: if one search call can answer it → use this skill.
  If the answer requires reading multiple full pages → use b-research.
---

# b-quick-search

Single-call web lookup via Brave Search. Fast, cited, no scraping.
The rule is simple: one search call, one clean answer.

## When to use

- User says: "search", "tìm", "look up", "find", "tìm nhanh", "latest X", "current X"
- Queries about: latest versions, recent news, current prices, new releases, CVEs
- Any question where training data might be stale and one search is enough
- User explicitly says `b-quick-search` or "use brave search"

## When NOT to use

- User wants a deep dive, comparison, or multi-source report → use **b-research**
- Topic is a library/framework and the user wants API details → use **b-docs**
- The answer clearly requires reading full articles, not just search snippets

## Tools required

- `brave_web_search` — from `brave-search` MCP server (required)
- `brave_summarizer` — from `brave-search` MCP server *(optional, for factual queries)*

If unavailable: stop and tell the user:
"❌ brave-search MCP is not connected. Please check `/mcp`."
Do NOT substitute with any other search tool or training data.

---

## Steps

### Step 1 — Search

Call `brave_web_search` with:
- A focused, specific query (1–6 words works best)
- `count: 5` — enough for a quick lookup, not overwhelming
- English queries unless the topic is Vietnamese-specific

If the first query returns no useful results, retry once with a rephrased query.
Rephrasing tips: add the current year, replace ambiguous words with specific technical terms (e.g. "fix" → "patch", "tool" → the exact product name), add the full product/company name, or remove generic qualifiers like "best" or "how to".
If the retry also fails → tell the user the search returned no relevant results
and suggest they try b-research for a deeper lookup.

**For factual queries** (version numbers, prices, dates, definitions, yes/no questions):
Also call `brave_summarizer` with the same query in parallel with `brave_web_search`.
Use the summarizer output as the primary answer; use search result URLs as citations.

### Step 2 — Synthesize

Do NOT dump raw results. Write a clean, direct response:
- Lead with the direct answer (from summarizer if available, otherwise from search snippets)
- Include version numbers and dates when relevant
- Group related findings if results cover multiple aspects
- Cite sources at the end

---

## Output format

```
[Direct answer]

Key findings:
- Finding 1 (source title if needed)
- Finding 2

Sources:
- [Title](URL)
- [Title](URL)
```

For single-fact lookups (e.g. "latest version of X"), skip "Key findings" and
just answer directly with one source citation inline.

---

## Rules

- One search call only — this is a quick lookup, not a research session
- Never use training data as the answer — always search first
- Never substitute another tool if brave-search is unavailable
- Keep answers concise — no need to reproduce full article content
- If results are insufficient for a confident answer, say so and suggest b-research