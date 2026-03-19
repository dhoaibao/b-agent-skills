---
name: b-news
description: >
  Aggregate and summarize today's top tech news from curated sources.
  ALWAYS use this skill when the user says "tin tức hôm nay", "news hôm nay",
  "có gì mới hôm nay", "tech news", "b-news", "điểm tin", or asks what's
  happening in tech today. Trigger even if the user just says "hôm nay có gì mới không".
---

# b-news

Aggregates today's top tech news from curated sources using Brave Search,
then groups stories by topic into a clean bilingual daily digest.

## Tools required

- `brave_news_search` — from `brave-search` MCP server (required)
- `firecrawl_scrape` — from `firecrawl` MCP server (optional, for detail on demand)

If `brave-search` is unavailable, stop and tell the user:
"❌ brave-search MCP is not connected. Please check `/mcp`."

Graceful degradation: ❌ Not possible — this skill requires live web data. If the MCP is unavailable, stop and tell the user.

## Curated sources

Results from these domains are preferred over generic tech blogs:

| Source | Domain | Strength |
|---|---|---|
| Ars Technica | arstechnica.com | Deep tech + science reporting |
| 9to5Google | 9to5google.com | Android, Google, Pixel |
| 9to5Mac | 9to5mac.com | Apple, iOS, Mac |
| 9to5Linux | 9to5linux.com | Linux, open source |
| BleepingComputer | bleepingcomputer.com | Security, malware, CVEs |
| The Register | theregister.com | Enterprise tech |
| How-To Geek | howtogeek.com | Software, Windows, tools |
| Hacker News | news.ycombinator.com | Community top stories |

---

## Steps

### Step 1 — Search by topic category

**Before running the 5 default searches**: check if the user mentioned a specific topic (e.g., 'news about React', 'AI news today', 'security breaches this week'). If yes: replace 1–2 of the 5 default queries with focused queries on that topic, keeping the rest as-is. Example: if user says 'AI news', replace Search 3 (`Apple Google Microsoft product`) with `'[specific AI topic] latest news [year]'`. If user made a generic request ('news today', 'điểm tin') → run the 5 default queries unchanged.

Run **5 searches in parallel** (single message, multiple tool calls), one per major topic area.
Use `brave_news_search` — it is designed for news with built-in freshness filtering.
Do NOT use `site:` or boolean `OR` operators, as these are unreliable in Brave Search MCP.

```
Search 1: "AI machine learning"
Search 2: "security vulnerability breach"
Search 3: "Apple Google Microsoft product"
Search 4: "Linux open source release"
Search 5: "developer tools programming"
```

- Use `brave_news_search` with `count: 5` and `freshness: "pd"` (past day) per search
- After getting results, prefer stories from the curated source list above
  over generic tech blogs — but do not discard good stories from other sources
- Collect: headline, URL, 1-sentence snippet per story

After collecting results: if total unique stories across all 5 searches is fewer than 10 → retry searches 1 and 2 (`AI machine learning`, `security vulnerability breach`) with `freshness: "pw"` (past week). Mark any stories from this retry with `(earlier this week)` in the output.

### Step 2 — Deduplicate and categorize

From all collected results (~25 stories), filter and group:

- **Discard**: duplicates covering the same event (keep the best source), opinion
  pieces, sponsored content, listicles ("10 best..."), and stories older than 48 hours
- **Group** into categories (omit any category with no stories):
  - 🤖 AI & Machine Learning
  - 🔒 Security & Privacy
  - 📱 Mobile & Devices
  - 💻 Software & Apps
  - 🐧 Linux & Open Source
  - 🏢 Big Tech
  - 📌 Other

Target: **3 stories per category max** — quality over quantity.

### Step 3 — Scrape for detail (on demand only)

Only if the user follows up with "đọc thêm về..." or "chi tiết về..." a specific story:
call `firecrawl_scrape` on that one URL. Do not bulk scrape during the initial digest.

---

## Output format

Each story: English headline + 1-sentence English summary + source link,
followed by Vietnamese translation on the next line.

```
# 📰 Tech News — [Today's Date]

## 🤖 AI & Machine Learning

**[English Headline]**
[1-sentence English summary] — ([Source Name](URL))
> [Tiêu đề tiếng Việt] — [1 câu tóm tắt tiếng Việt]

## 🔒 Security & Privacy

**[English Headline]**
[1-sentence English summary] — ([Source Name](URL))
> [Tiêu đề tiếng Việt] — [1 câu tóm tắt tiếng Việt]

[... remaining categories ...]

---
*[N] stories · Sources searched: Ars Technica, 9to5Google, 9to5Mac, BleepingComputer,
The Register, 9to5Linux, How-To Geek, Hacker News*
```

---

## Rules

- Always include today's actual date in the header
- Always run all 5 `brave_news_search` calls in parallel — never sequentially
- Never use `site:` operator or boolean `OR` in queries — use topic keywords instead
- Max 3 stories per category — cut the weakest stories if more are found
- Omit any category with no stories rather than padding with weak content
- Do not scrape during digest generation — search snippets are sufficient for summaries
- Vietnamese translations should be natural, not literal word-for-word