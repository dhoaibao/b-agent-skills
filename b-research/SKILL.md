---
name: b-research
description: >
  Deep research by combining Brave Search + Firecrawl scraping to get full page content,
  with optional Context7 lookup for library/framework topics.
  ALWAYS use this skill when the user asks to "research", "tìm hiểu sâu", "deep dive",
  "so sánh", "compare", "tổng hợp thông tin về", "tìm hiểu", "viết report về", or any
  query that needs more than search snippets — such as evaluating tools, understanding
  concepts deeply, comparing options, or producing a comprehensive report.
  Prefer this over b-search when the user wants depth, not just a quick answer.
---

# b-research

Deep research workflow: optionally fetch versioned docs via Context7 (for library/framework
topics), search for relevant URLs via Brave Search, scrape full content via Firecrawl,
then synthesize into a comprehensive report with citations.

## When to use

- User asks to research, compare, or deeply understand a topic
- User wants a report or summary of multiple sources
- A quick search snippet is not enough — full page content is needed
- User says: "tìm hiểu", "research", "deep dive", "so sánh", "tổng hợp", "viết report về"

## Tools required

- `brave_web_search` — from `brave-search` MCP server
- `firecrawl_scrape` — from `firecrawl` MCP server
- `firecrawl_search` — from `firecrawl` MCP server *(optional, fallback search with full content)*
- `resolve-library-id` + `get-library-docs` — from `context7` MCP server *(optional, for library/framework topics)*
- `sequentialthinking` — from `sequential-thinking` MCP server *(optional, for resolving conflicting source recommendations)*

If brave-search or firecrawl is unavailable, stop and tell the user:
- brave-search missing: "❌ brave-search MCP is not connected. Please check `/mcp`."
- firecrawl missing: "❌ firecrawl MCP is not connected. Please check `/mcp`."

If context7 is unavailable on a library/framework topic, skip Step 1 silently and continue with Step 2.

---

## Steps

### Step 0 — Classify the topic

Before searching, determine: **is this topic a library, framework, SDK, or specific tool?**

Examples that qualify: `SendGrid SDK`, `BullMQ`, `Prisma`, `React Query`, `AWS SES SDK`, `Express.js`, `Zod`

Examples that do NOT qualify: `best practices for error handling`, `compare SaaS pricing models`, `history of REST APIs`

**If YES → run Step 1 before Step 2.**
**If NO → skip to Step 2.**

---

### Step 1 — Context7 lookup *(library/framework topics only)*

Use `resolve-library-id` to find the correct Context7 library ID, then `get-library-docs` to fetch version-accurate documentation.

- Set `topic` to the specific feature or API area relevant to the user's question
- Fetch enough tokens to cover the relevant API surface (default: 8000–12000 tokens)
- If `resolve-library-id` returns no match → skip this step, note it in the report
- **Do not use Context7 output as the sole source** — it provides API accuracy; web sources provide real-world usage, comparisons, and community feedback

---

### Step 2 — Search

- Use `brave_web_search` with a focused English query (unless topic is Vietnamese-specific)
- Fetch 5–8 results
- Pick the **3–5 most relevant URLs** — prioritize official docs, authoritative blogs, recent articles
- If Context7 already covered official docs well in Step 1, deprioritize official doc URLs here and favor community/comparison sources instead

**Fallback**: If `brave_web_search` returns fewer than 3 relevant results, retry with `firecrawl_search` using the same query. `firecrawl_search` returns full page content directly — skip Step 3 for these results.

---

### Step 3 — Scrape

- Call `firecrawl_scrape` on all selected URLs **in parallel** (single message, multiple tool calls)
- Use `formats: ["markdown"]` to get clean content
- **Fallback for JS-heavy pages** (SPAs, dashboards, React-rendered docs): if firecrawl returns empty content or <200 words, retry once with `waitFor: 3000`. If still empty, skip and note in report as "could not scrape — JS-rendered page".
- If a page returns a rate-limit or 403, skip it and note in report
- Max 5 URLs scraped per session to avoid excessive tool calls
- If rate-limiting occurs on parallel calls, retry failed URLs sequentially

---

### Step 4 — Synthesize

- Read all sources (Context7 output + scraped content) carefully
- Answer the user's specific question based on actual content — not training data
- If 2 or more sources recommend conflicting approaches for the same decision point (e.g., Source A: "use approach X", Source B: "use approach Y") → call `sequentialthinking` with: "Source A says [X] because [reason]. Source B says [Y] because [reason]. Given the user's context of [task], which approach is more applicable and why?" Include the structured reasoning in a "⚖️ Conflicting findings" subsection of the report.
- If sources conflict on minor details only, note the disagreement inline without calling sequentialthinking
- Produce a structured report (see output format below)

---

## Output format

```
## [Topic / Research Question]

### Summary
[2–4 sentence direct answer to the user's question]

### Key Findings
- **[Finding 1]**: ...
- **[Finding 2]**: ...
- **[Finding 3]**: ...

### [Optional: Comparison Table or Deep Dive Section]
...

### Sources
- [Page Title](URL) — [one line on what this source contributed]
- Context7 (`library-name`) — versioned API reference for [specific feature]
```

---

## Rules

- Always scrape — never rely on search snippets alone
- For library/framework topics: always attempt Context7 before scraping
- Max 5 URLs to scrape per research session
- Cite every claim with its source URL or "Context7 (`library-name`)"
- If the user asks a specific question, answer it directly in the Summary before going into detail
- Keep the report focused — omit irrelevant scraped content
- Note any sources that failed to scrape so the user can check manually