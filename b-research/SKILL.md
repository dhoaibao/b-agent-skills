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

Deep research workflow: classify query type → optionally fetch versioned docs via Context7
(for API topics) → search with type-specific strategy via Brave Search → scrape full content
via Firecrawl → quality-gate scraped content → synthesize into a comprehensive report with
citations and freshness indicators.

## When to use

- User asks to research, compare, or deeply understand a topic
- User wants a report or summary of multiple sources
- A quick search snippet is not enough — full page content is needed
- User says: "tìm hiểu", "research", "deep dive", "so sánh", "tổng hợp", "viết report về"

## Tools required

- `brave_web_search` — from `brave-search` MCP server
- `firecrawl_scrape` — from `firecrawl` MCP server
- `firecrawl_search` — from `firecrawl` MCP server *(optional, fallback search with full content)*
- `resolve-library-id` + `get-library-docs` — from `context7` MCP server *(optional, for library/framework API topics)*
- `sequentialthinking` — from `sequential-thinking` MCP server *(optional, for structured conflict resolution)*

If brave-search or firecrawl is unavailable, stop and tell the user:
- brave-search missing: "❌ brave-search MCP is not connected. Please check `/mcp`."
- firecrawl missing: "❌ firecrawl MCP is not connected. Please check `/mcp`."

If context7 is unavailable on a library/framework topic, skip Step 1 silently and continue with Step 2.

Graceful degradation: ❌ Not possible — this skill requires live web data (brave-search + firecrawl). If either MCP is unavailable, stop and tell the user.

---

## Steps

### Step 0 — Classify query type

Classify the user's query into **one of four types** before doing anything else. The type determines the entire search strategy.

| Type | Signals | Strategy |
|------|---------|----------|
| **VERSION** | "latest version", "what's new", "changelog", "release notes", "current version of X" | Official docs FIRST via direct scrape, then web search |
| **COMPARE** | "vs", "so sánh", "which is better", "A or B", "compare X and Y" | 2 balanced searches (one per option), equal coverage of both sides |
| **NEWS** | "recent", "2025/2026", "mới nhất", "latest news", "what happened", time-sensitive topics | Brave search with `freshness: pw` or `pd` |
| **HOWTO / API** | "how to", "cách dùng", "tutorial", "setup", "configure", asking about API usage | Context7 first (Step 1), then scrape official docs + community |

**If topic is library/framework API → also run Step 1 (Context7) before Step 2.**
**All other types → skip Step 1, go to Step 2.**

---

### Step 1 — Context7 lookup *(HOWTO/API type only)*

Use `resolve-library-id` to find the correct Context7 library ID, then `get-library-docs` to fetch version-accurate documentation.

- Set `topic` to the specific feature or API area relevant to the user's question
- Fetch enough tokens to cover the relevant API surface (default: 8000–12000 tokens)
- If `resolve-library-id` returns no match → skip this step, note it in the report
- Skip this step if user's question is clearly recency-dependent (e.g., "what changed in v5?") — Context7 may be stale for recent releases
- **Do not use Context7 output as the sole source** — it provides API accuracy; web sources provide real-world usage, comparisons, and community feedback

---

### Step 2 — Search (type-specific strategy)

Apply the strategy for the query type identified in Step 0:

**VERSION queries:**
- If the tool has a known official docs/changelog URL → use `firecrawl_scrape` on it DIRECTLY first (skip to Step 3 for this URL), then use Brave to find community context
- If official URL is unknown → search with: `"[tool name] official changelog [year]"` or `"[tool name] release notes site:[official-domain]"`
- Always include `official` or `changelog` in the query to avoid third-party aggregators
- Third-party version trackers (deepwiki, community changelogs) have staleness lag of 1–3 weeks — treat them as supplementary only, not authoritative

**COMPARE queries:**
- Run **2 separate Brave searches**: one focused on option A, one on option B (in parallel)
- Pick sources that cover each option from its own perspective (official docs, official blog)
- Pick at least 1 neutral comparison source (benchmarks, independent reviews)
- Ensure balanced coverage: minimum 1 authoritative source per option being compared
- Up to 7 URLs may be scraped for comparison queries to ensure balance (exception to the 5-URL default)

**NEWS queries:**
- Add `freshness: "pw"` (last 7 days) or `freshness: "pd"` (last 24h) to `brave_web_search`
- Include the current year in the query
- Prefer official announcements, official blogs, and reputable tech press over aggregators

**HOWTO / API queries:**
- After Context7 (Step 1), use Brave to find community tutorials and real-world examples
- Query should include the library name + version + specific feature
- Deprioritize official doc URLs in Brave if Context7 already covered them well

**Universal search rules (all types):**
- Use English queries unless the topic is Vietnamese-specific
- Fetch 5–8 results from Brave
- Pick 3–5 most relevant URLs, applying the source quality hierarchy below
- **Fallback**: If `brave_web_search` returns fewer than 3 relevant results, retry with `firecrawl_search` using the same query — it returns full page content directly, skip Step 3 for those results

**Source quality hierarchy (prefer top tiers):**
1. Official docs, official changelogs, official GitHub repo
2. Official team blog, official announcements
3. Well-known tech publications (The Verge, Ars Technica, HN top posts, official SDK examples)
4. Community Q&A (StackOverflow answers with high votes, GitHub Discussions)
5. Independent technical blogs with clear authorship
6. Third-party aggregators, trackers, wikis ← treat as supplementary only

**Avoid**: Pinterest, SEO-farm content mills, AI-generated listicles, paywalled pages (unless the snippet is already sufficient).

---

### Step 3 — Scrape

- Call `firecrawl_scrape` on all selected URLs **in parallel** (single message, multiple tool calls)
- Use `formats: ["markdown"]`, `onlyMainContent: true` to get clean content
- **Fallback for JS-heavy pages** (SPAs, Mintlify/GitBook docs, React-rendered pages): if content is empty or <200 words, retry with `waitFor: 5000`. If still <200 words, retry once more with `waitFor: 8000`. If still empty, skip and note in report as "could not scrape — JS-rendered page".
- If a page returns rate-limit or 403 → skip it and note in report
- Default max: **5 URLs** scraped per session. Exception: **7 URLs** for COMPARE queries
- If rate-limiting occurs on parallel calls, retry failed URLs sequentially

**Post-scrape quality gate** (do this before synthesizing):
- For each scraped page, check: does the content actually address the user's question?
- If a page has < 300 words of relevant content OR the topic is not mentioned → discard it and note "low-quality source discarded"
- If fewer than 2 usable sources remain after discarding → run a second Brave search with a different query angle and scrape 1–2 more URLs

---

### Step 4 — Synthesize

- Read all sources (Context7 output + scraped content) carefully
- **Answer from actual scraped content only** — if no source explicitly covers a fact, do NOT fill the gap from training data. Instead, flag it in the `Limitations` section.
- Note the publication/update date of each source when available — use it to assess freshness
- If 2 or more sources recommend conflicting approaches for the same decision point → call `sequentialthinking` with: "Source A says [X] because [reason]. Source B says [Y] because [reason]. Given the user's context of [task], which approach is more applicable and why?" Include the structured reasoning in a "⚖️ Conflicting findings" subsection.
- If sources conflict on minor details only, note the disagreement inline without calling `sequentialthinking`
- For VERSION queries: always note the official source version separately from any third-party tracker versions if they differ
- Produce a structured report (see output format below)

---

## Output format

```
## [Topic / Research Question]

> 📅 Research date: [today's date] | Sources: [N scraped] | Freshness: [Official/Community/Mixed]

### Summary
[2–4 sentence direct answer to the user's question, based only on scraped content]

### Key Findings
- **[Finding 1]**: ... *(Source: [Official] / [Community])*
- **[Finding 2]**: ...
- **[Finding 3]**: ...

### [Optional: Comparison Table or Deep Dive Section]
...

### ⚖️ Conflicting findings *(optional — only if sources disagree on a key point)*
[structured reasoning from sequentialthinking]

### Limitations
- [Any important question the sources did NOT answer]
- [Any sources discarded and why]
- [Any data that may be stale — link to official source for verification]

### Sources
- [Official] [Page Title](URL) — [one line on what this source contributed]
- [Community] [Page Title](URL) — [one line on what this source contributed]
- Context7 (`library-name`) — versioned API reference for [specific feature]

### Recommended next steps *(optional)*
- [What the user might want to do now with this information]
```

---

## Rules

- Always scrape — never rely on search snippets alone
- Apply query type routing from Step 0 — do not use a generic one-size-fits-all search strategy
- For VERSION queries: official docs via direct scrape takes priority over any search result
- For COMPARE queries: ensure balanced source coverage — do not let one option dominate
- For library/framework API topics: always attempt Context7 before scraping
- Default max 5 URLs; 7 URLs allowed for COMPARE queries
- Cite every claim with its source URL or "Context7 (`library-name`)"
- Never state a fact not found in scraped content — use the `Limitations` section for gaps
- Label each source as `[Official]`, `[Community]`, or `[Blog]` in the Sources list
- For time-sensitive data (versions, prices, availability): always note the source's date and link to official source for verification
- If the user asks a specific question, answer it directly in the Summary before going into detail
- Keep the report focused — omit irrelevant scraped content
- Note any sources that failed to scrape or were discarded so the user can check manually
