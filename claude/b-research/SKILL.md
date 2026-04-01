---
name: b-research
description: >
  Deep research: search + scrape full pages + synthesize a comprehensive report with citations.
  ALWAYS use when the user says "research", "tìm hiểu sâu", "deep dive", "so sánh",
  "compare", "tổng hợp thông tin về", "viết report về", or needs depth — evaluating tools,
  comparing options, or producing a multi-source report.
  Use b-quick-search instead when a single search call can answer the question.
model: sonnet
---

# b-research

Deep research workflow: classify query type → optionally fetch versioned docs via Context7
(for API topics) → search with type-specific strategy via Brave Search → scrape full content
via Firecrawl → quality-gate scraped content → synthesize into a comprehensive report with
citations and freshness indicators.

## When to use

- User asks to research, compare, or deeply understand a topic.
- User wants a report or summary of multiple sources.
- A quick search snippet is not enough — full page content is needed.
- User says: "tìm hiểu", "research", "deep dive", "so sánh", "tổng hợp", "viết report về".

## When NOT to use

- Quick one-fact lookup (latest version, price, single answer) → use **b-quick-search**
- Library/framework API details or method signatures → use **b-docs**
- Daily news digest → use **b-news**

## Tools required

- `brave_web_search` — from `brave-search` MCP server (required, general search)
- `brave_news_search` — from `brave-search` MCP server *(required for NEWS-type queries; use instead of `brave_web_search` for time-sensitive topics)*
- `firecrawl_scrape` — from `firecrawl` MCP server (required, scrape individual pages)
- `firecrawl_search` — from `firecrawl` MCP server *(optional, single-call search+scrape fallback when `brave_web_search` returns <3 results)*
- `firecrawl_map` — from `firecrawl` MCP server *(optional, discover correct URLs when `firecrawl_scrape` returns empty content)*
- `firecrawl_crawl` + `firecrawl_check_crawl_status` — from `firecrawl` MCP server *(optional, async deep multi-page crawl for documentation sites)*
- `resolve-library-id` + `query-docs` — from `context7` MCP server *(optional, for library/framework API topics)*
- `sequentialthinking` — from `sequential-thinking` MCP server *(optional, for structured conflict resolution)*
- `Agent` tool (Explore subagent) *(optional, for Step 4 when ≥ 4 URLs need scraping)* — spawn a single Explore subagent with the selected URL list and original research question. The subagent runs all `firecrawl_scrape` calls in parallel, applies the post-scrape quality gate, and returns only relevant excerpts (max 500 words per source, with source URL). Main context receives the compact digest and proceeds directly to Step 5 without raw scraped content flooding the context. When < 4 URLs, use direct parallel scraping as before.

If brave-search or firecrawl is unavailable, stop and tell the user:
- brave-search missing: "❌ brave-search MCP is not connected. Please check `/mcp`.".
- firecrawl missing: "❌ firecrawl MCP is not connected. Please check `/mcp`.".

If context7 is unavailable on a library/framework topic, skip Step 2 silently and continue with Step 3.
If Agent tool is unavailable: use direct parallel `firecrawl_scrape` calls in the main context as before (existing behavior).

Graceful degradation: ❌ Not possible — this skill requires live web data (brave-search + firecrawl). If either MCP is unavailable, stop and tell the user. Agent tool unavailability: ✅ graceful — falls back to direct parallel scraping.

## Steps

### Step 1 — Classify query type

Classify the user's query into **one of four types** before doing anything else. The type determines the entire search strategy.

| Type | Signals | Strategy |
|------|---------|----------|
| **VERSION** | "latest version", "what's new", "changelog", "release notes", "current version of X" | Official docs FIRST via direct scrape, then web search |
| **COMPARE** | "vs", "so sánh", "which is better", "A or B", "compare X and Y" | 2 balanced searches (one per option), equal coverage of both sides |
| **NEWS** | "recent", "2025/2026", "mới nhất", "latest news", "what happened", time-sensitive topics | `brave_news_search` with `freshness: "pd"` or `"pw"` |
| **HOWTO / API** | "how to", "cách dùng", "tutorial", "setup", "configure", asking about API usage | Context7 first (Step 2), then scrape official docs + community |

**If topic is library/framework API → also run Step 2 (Context7) before Step 3.**
**All other types → skip Step 2, go to Step 3.**

---

### Step 2 — Context7 lookup *(HOWTO/API type only)*

> **Session optimization**: If b-docs has already run for this library in the current session, skip this step and use those findings as the versioned API reference for Step 5 synthesis — do not call context7 again.

Use `resolve-library-id` to find the correct Context7 library ID, then `query-docs` to fetch version-accurate documentation.

- Set `topic` to the specific feature or API area relevant to the user's question.
- Fetch enough tokens to cover the relevant API surface (default: 8000–12000 tokens)
- If `resolve-library-id` returns no match → skip this step, note it in the report.
- Skip this step if user's question is clearly recency-dependent (e.g., "what changed in v5?") — Context7 may be stale for recent releases.
- **Do not use Context7 output as the sole source** — it provides API accuracy; web sources provide real-world usage, comparisons, and community feedback.
---

### Step 3 — Search (type-specific strategy)

Apply the strategy for the query type identified in Step 1:

**VERSION queries:**
- If the tool has a known official docs/changelog URL → use `firecrawl_scrape` on it DIRECTLY first (skip to Step 4 for this URL), then use Brave to find community context.
- If official URL is unknown → search with: `"[tool name] official changelog [year]"` or `"[tool name] release notes site:[official-domain]"`
- Always include `official` or `changelog` in the query to avoid third-party aggregators.
- Third-party version trackers (deepwiki, community changelogs) have staleness lag of 1–3 weeks — treat them as supplementary only, not authoritative.

**COMPARE queries:**
- Run **2 separate Brave searches**: one focused on option A, one on option B (in parallel)
- Pick sources that cover each option from its own perspective (official docs, official blog)
- Pick at least 1 neutral comparison source (benchmarks, independent reviews)
- Ensure balanced coverage: minimum 1 authoritative source per option being compared.
- Up to 7 URLs may be scraped for comparison queries to ensure balance (exception to the 5-URL default)

**NEWS queries:**
- Use `brave_news_search` (not `brave_web_search`) with `freshness: "pd"` (last 24h) or `freshness: "pw"` (last 7 days)
- Freshness options: `"pd"` = past day, `"pw"` = past week, `"pm"` = past month, `"py"` = past year — start with `"pd"`, broaden to `"pw"` if fewer than 3 results.
- Include the current year in the query.
- Prefer official announcements, official blogs, and reputable tech press over aggregators.

**HOWTO / API queries:**
- After Context7 (Step 2), use Brave to find community tutorials and real-world examples.
- Query should include the library name + version + specific feature.
- Deprioritize official doc URLs in Brave if Context7 already covered them well.

**Universal search rules (all types):**
- Use English queries unless the topic is Vietnamese-specific.
- Fetch 5–8 results from Brave.
- **Pick 3 highest-quality URLs** using the source quality hierarchy below (quality over quantity: 3 Tier-1 sources > 5 mixed-tier sources).
- **Fallback**: If `brave_web_search` returns fewer than 3 relevant results, retry with `firecrawl_search` using the same query — it returns full page content directly, skip Step 4 for those results.

**Source quality hierarchy (prefer top tiers):**
1. Official docs, official changelogs, official GitHub repo
2. Official team blog, official announcements
3. Well-known tech publications (The Verge, Ars Technica, HN top posts, official SDK examples)
4. Community Q&A (StackOverflow answers with high votes, GitHub Discussions)
5. Independent technical blogs with clear authorship
6. Third-party aggregators, trackers, wikis ← treat as supplementary only

**Avoid**: Pinterest, SEO-farm content mills, AI-generated listicles, paywalled pages (unless the snippet is already sufficient).

---

### Step 4 — Scrape

**Context isolation threshold**: if ≥ 6 URLs need scraping → spawn a single Explore subagent (see below). If < 6 URLs → use direct parallel `firecrawl_scrape` calls in main context. (With smart source selection keeping typical queries to 3 URLs, subagent spawn is rare — reduces context overhead.)

---

**When ≥ 4 URLs — spawn a single Explore subagent**

Pass to the subagent:
1. The list of selected URLs to scrape
2. The original research question

The subagent runs all `firecrawl_scrape` calls in parallel (`formats: ["markdown"]`, `onlyMainContent: true`), applies the full post-scrape quality gate (discards pages with < 300 words of relevant content, retries JS-heavy pages with `waitFor: 5000/8000`, uses `firecrawl_map` for empty pages), and returns a compact digest: relevant excerpt per source (max 500 words), source URL, and discard notes. Main context receives this digest and proceeds to Step 5 without raw scraped content in context.

---

**Pre-scrape filtering** (before Step 4, eliminate low-value URLs):
- Remove from scrape queue:
  - Homepage or landing page (no specific content)
  - Pages requiring login/authentication
  - Tutorial/guide when user asked for API specs or comparisons (skip tutorials for spec queries)
  - Third-party aggregators or version trackers (use official source instead)
  - Paywalled pages with paywall message visible
- **Goal**: scrape only high-signal sources → saves 1–2K tokens by avoiding trash content

---

**When < 4 URLs — scrape directly in main context**

- Call `firecrawl_scrape` on all selected URLs **in parallel** (single message, multiple tool calls)
- Use `formats: ["markdown"]`, `onlyMainContent: true` to get clean content without boilerplate.
- **Fallback for JS-heavy pages** (SPAs, Mintlify/GitBook docs, React-rendered pages): if content is empty or <200 words after one retry with `waitFor: 5000` → skip and note in report as "could not scrape — JS-rendered or access denied". (Removed retry with `waitFor: 8000` and `firecrawl_map` fallback to save tokens — not worth the cost for marginal improvement.)
- If a page returns rate-limit or 403 → skip it and note in report.
- Default max: **3 URLs** scraped per session (quality > quantity). Exception: **5 URLs** for COMPARE queries (ensure balanced coverage of both options).
- If rate-limiting occurs on parallel calls, retry failed URLs sequentially.

**Deep multi-page crawl** *(for documentation sites — use when you need comprehensive coverage of a multi-page doc, not just a single article)*:
1. Call `firecrawl_crawl` on the documentation root URL with `limit: 10–20` pages
2. Poll `firecrawl_check_crawl_status` every few seconds until `status: "completed"` — do NOT proceed until crawl is done
3. Use the returned pages as your source set; apply the post-scrape quality gate below

**Post-scrape quality gate** (strict filtering — do this before synthesizing):
- For each scraped page, check: does the content actually address the user's question?
- **Discard immediately** if: < 300 words of relevant content AND topic is not mentioned → note "low-quality source discarded"
- **Discard if** > 50% boilerplate (nav, footer, ads, sidebars) and < 200 unique content words → note "mostly boilerplate"
- **If fewer than 2 usable sources remain after discarding** → STOP. Tell user: "Couldn't find enough reliable sources on this topic. Try being more specific or rephrasing the question." Do NOT blindly scrape more URLs.
- **Exception**: For COMPARE queries where sources explicitly disagree, retain >1 source per option even if marginal, to preserve conflicting perspectives.

---

### Step 5 — Synthesize

- Read all sources (Context7 output + scraped content) carefully.
- **Answer from actual scraped content only** — if no source explicitly covers a fact, do NOT fill the gap from training data. Instead, flag it in the `Limitations` section.
- Note the publication/update date of each source when available — use it to assess freshness.
- If 2 or more sources recommend conflicting approaches for the same decision point → call `sequentialthinking` with: "Source A says [X] because [reason]. Source B says [Y] because [reason]. Given the user's context of [task], which approach is more applicable and why?" Include the structured reasoning in a "⚖️ Conflicting findings" subsection.
- If sources conflict on minor details only, note the disagreement inline without calling `sequentialthinking`
- For VERSION queries: always note the official source version separately from any third-party tracker versions if they differ.
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

- Always scrape — never rely on search snippets alone.
- Apply query type routing from Step 1 — do not use a generic one-size-fits-all search strategy.
- For VERSION queries: official docs via direct scrape takes priority over any search result.
- For COMPARE queries: ensure balanced source coverage — do not let one option dominate.
- For library/framework API topics: always attempt Context7 before scraping.
- Default max 5 URLs; 7 URLs allowed for COMPARE queries.
- Cite every claim with its source URL or "Context7 (`library-name`)".
- Never state a fact not found in scraped content — use the `Limitations` section for gaps.
- Label each source as `[Official]`, `[Community]`, or `[Blog]` in the Sources list.
- For time-sensitive data (versions, prices, availability): always note the source's date and link to official source for verification.
- If the user asks a specific question, answer it directly in the Summary before going into detail.
- Keep the report focused — omit irrelevant scraped content.
- Note any sources that failed to scrape or were discarded so the user can check manually.
- Never trigger destructive git commands — no `git push`, `git pull`, `git commit`, `git reset`, `git revert`, `git clean -f`, `git checkout -- <file>`, or `git branch -D`. If a commit is needed after completing work, delegate to b-commit.
