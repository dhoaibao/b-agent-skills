---
name: b-research
description: >
  Research, library docs lookup, and multi-source synthesis. ALWAYS invoke when the user says
  "research", "tìm hiểu", "deep dive", "so sánh", "tổng hợp", "how to use X", "cách dùng",
  or needs library API docs, comparisons, or reports.
  Covers both quick library lookups (Context7-first) and full multi-source research.
  Unlike b-debug (fix broken) or b-plan (decide approach), b-research retrieves and synthesizes
  external knowledge.
effort: high
---

# b-research

$ARGUMENTS

All external knowledge in one skill: classify query → fetch versioned library docs via
Context7 (for API/HOWTO queries) → search with type-specific strategy via Brave Search →
scrape full content via Firecrawl → synthesize into a report with citations.

Handles both quick library lookups ("how do I use Prisma transactions?") and deep
multi-source research ("compare BullMQ vs Bee-Queue for job queues").

If `$ARGUMENTS` is provided, treat it as the research question — proceed directly to Step 1 (classify query type) using the provided text. Do not ask the user to restate their question.

## When to use

- User asks how to use a specific library, SDK, or framework feature.
- User asks "does X support Y?", "what's the API for X?", "how to configure X?".
- Before implementing code that calls an external library — verify the API first.
- User asks to research, compare, or deeply understand a topic.
- User wants a report or summary of multiple sources.
- User says: "tìm hiểu", "research", "deep dive", "so sánh", "tổng hợp", "how to use X",
  "cách dùng", "tra cứu", "viết report về".

## When NOT to use

- Quick one-fact lookup (latest version, price, single answer) → use **b-lookup**
- Daily news digest → call `brave_news_search` directly and format a digest
- Debugging a broken library call → use **b-debug**

## Tools required

- `brave_web_search` — from `brave-search` MCP server (required, general search)
- `brave_news_search` — from `brave-search` MCP server *(required for NEWS-type queries; use instead of `brave_web_search` for time-sensitive topics)*
- `firecrawl_scrape` — from `firecrawl` MCP server (required, scrape individual pages)
- `firecrawl_search` — from `firecrawl` MCP server *(optional, single-call search+scrape fallback when `brave_web_search` returns <3 results)*
- `firecrawl_map` — from `firecrawl` MCP server *(optional, discover correct URLs when `firecrawl_scrape` returns empty content)*
- `firecrawl_extract` — from `firecrawl` MCP server *(optional, for structured data extraction — HOWTO/API type when user asks about specific fields, prices, parameters, or specs; more efficient than scrape + manual parsing)*
- `firecrawl_crawl` + `firecrawl_check_crawl_status` — from `firecrawl` MCP server *(optional, async deep multi-page crawl for documentation sites)*
- `resolve-library-id` + `query-docs` — from `context7` MCP server *(optional, for library/framework API topics)*
- `sequentialthinking` — from `sequential-thinking` MCP server *(optional, for structured conflict resolution)*

If brave-search or firecrawl is unavailable, stop and tell the user:
- brave-search missing: "❌ brave-search MCP is not connected. Please check `/mcp`.".
- firecrawl missing: "❌ firecrawl MCP is not connected. Please check `/mcp`.".

If context7 is unavailable on a library/framework topic, skip Step 2 silently and continue with Step 3.
If sequential-thinking is unavailable: summarize conflicting findings inline as `Source A says X / Source B says Y / Best fit for user context: Z`.

Graceful degradation: ❌ Not possible — this skill requires live web data (brave-search + firecrawl). If either MCP is unavailable, stop and tell the user.

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

> **Session optimization**: If Context7 has already been queried for this library in the current session, reuse those findings — do not call it again.

**Version detection** — before querying docs, attempt to find the exact installed version:
- Use native file reads for manifests because Serena file tools are not exposed in this environment.
- Check `package.json`, `pyproject.toml`, `requirements.txt` in the project root.
- If version contains a range (`^`, `~`, `>=`, `*`), check the lockfile for the exact resolved version.
- If no manifest found, proceed without version constraint and note: `⚠️ No manifest found — docs may not match installed version.`

Use `resolve-library-id` to find the correct Context7 library ID, then `query-docs` to fetch version-accurate documentation.

- Set `topic` to the specific feature or API area relevant to the user's question.
- Fetch enough tokens to cover the relevant API surface (default: 8000–12000 tokens).
- If `resolve-library-id` returns no match → skip to Step 3 (web search). Note it in the report.
- If Context7 returns docs for a different major version than detected → flag explicitly: "⚠️ Context7 returned docs for vX but project uses vY — API may differ."
- Skip this step if user's question is clearly recency-dependent (e.g., "what changed in v5?") — Context7 may be stale for recent releases.
- **Do not use Context7 output as the sole source** — it provides API accuracy; web sources provide real-world usage and community feedback.

**For simple library lookups** (single method, config key, or yes/no capability check): if Context7 returns a clear answer, you may stop here and present the result using the Library Lookup output format below — no need to proceed to web search.

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

**Pre-scrape filtering** (before Step 4, eliminate low-value URLs):
- Remove from scrape queue:
  - Homepage or landing page (no specific content)
  - Pages requiring login/authentication
  - Tutorial/guide when user asked for API specs or comparisons (skip tutorials for spec queries)
  - Third-party aggregators or version trackers (use official source instead)
  - Paywalled pages with paywall message visible
- **Goal**: scrape only high-signal sources → saves 1–2K tokens by avoiding trash content

- Call `firecrawl_scrape` on all selected URLs **in parallel** (single message, multiple tool calls)
- Use `formats: ["markdown"]`, `onlyMainContent: true` to get clean content without boilerplate.
- **Structured data queries** — if the user asks about specific fields (prices, API parameters, field names, feature lists), prefer `firecrawl_extract` with a JSON schema instead of scrape + manual parsing. Call `firecrawl_extract` in parallel on the same URLs as a replacement or complement to `firecrawl_scrape`.
- **Fallback for JS-heavy pages** (SPAs, Mintlify/GitBook docs, React-rendered pages): if content is empty or <200 words after one retry with `waitFor: 5000` → skip and note in report as "could not scrape — JS-rendered or access denied".
- If a page returns rate-limit or 403 → skip it and note in report.
- Default max: **3 URLs** scraped per session (quality > quantity). Exception: **5 URLs** for COMPARE queries (ensure balanced coverage of both options — 2–3 per side).
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
- If 2 or more sources recommend conflicting approaches for the same decision point **and the disagreement changes the recommendation** → call `sequentialthinking` with: "Source A says [X] because [reason]. Source B says [Y] because [reason]. Given the user's context of [task], which approach is more applicable and why? State the deciding criteria and what assumption would change the answer." Include the structured reasoning in a "⚖️ Conflicting findings" subsection.
- If sources conflict on minor details only, note the disagreement inline without calling `sequentialthinking`
- For VERSION queries: always note the official source version separately from any third-party tracker versions if they differ.
- Produce a structured report (see output format below)

---

## Output format

### Library lookup (HOWTO/API type — answered by Context7 alone)

```
### `[LibraryName]` — [feature/topic]
*(Context7 — [library-id], v[version if detected])*

[2–3 sentence summary of the API]

**Key methods / options:**
- `method(params)` — what it does
- ...

**Example:**
\`\`\`[lang]
// minimal working example based on fetched docs
\`\`\`

**Notes:**
- Any gotchas, deprecations, or version differences found in docs
```

### Full research report (all other types)

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
- Default max 3 URLs; 5 URLs allowed for COMPARE queries (balanced coverage of both options).
- Cite every claim with its source URL or "Context7 (`library-name`)".
- Never state a fact not found in scraped content — use the `Limitations` section for gaps.
- Label each source as `[Official]`, `[Community]`, or `[Blog]` in the Sources list.
- For time-sensitive data (versions, prices, availability): always note the source's date and link to official source for verification.
- If the user asks a specific question, answer it directly in the Summary before going into detail.
- Keep the report focused — omit irrelevant scraped content.
- Note any sources that failed to scrape or were discarded so the user can check manually.
- Never trigger destructive git commands — no `git push`, `git pull`, `git commit`, `git reset`, `git revert`, `git clean -f`, or `git checkout -- <file>`.