---
name: b-news
description: >
  Aggregate and summarize today's top news from any domain into a grouped digest.
  ALWAYS use when the user says "tin tức", "news hôm nay", "có gì mới", "điểm tin",
  "b-news", or asks for news about any topic (tech, finance, science, politics, AI, crypto, etc.).
  Accepts user-defined topics as input. Trigger even for short queries like "hôm nay có gì mới không"
  or topic-specific like "tin tức tài chính hôm nay".
---

# b-news

Fetches today's top news on any user-specified topic from trusted, authoritative sources,
then groups stories by sub-topic into a clean bilingual daily digest.

## When to use
- User asks for news on any topic: tech, AI, finance, science, politics, health, crypto, etc.
- User says "b-news [topic]" or "tin tức [topic] hôm nay"
- Generic news request with no topic → default to general tech

## When NOT to use
- User wants deep analysis or a research report → use `b-research` instead
- User needs a single fact, latest version, or a single news answer → use `b-quick-search` instead (b-news produces a grouped digest, not a single answer)

## Tools required

- `brave_news_search` — from `brave-search` MCP server (required)
- `firecrawl_scrape` — from `firecrawl` MCP server (optional, for detail on demand)

If `brave-search` is unavailable: stop and tell the user:
"❌ brave-search MCP is not connected. Please check `/mcp`."

Graceful degradation: ❌ Not possible — requires live news data. Stop if MCP is unavailable.

## Recommended model

**Haiku** (`/model haiku`) — optimal for speed and cost.

News aggregation is grouping + formatting fetched headlines. No deep analysis required. Haiku produces clean digests at lower cost and higher throughput than Sonnet.

---

## Trusted sources by domain

Prefer results from domain-matched sources. Use the **Universal** tier as fallback when
domain-specific sources produce insufficient results.

| Domain | Trusted Sources |
|---|---|
| **Universal** | reuters.com, apnews.com, bbc.com |
| **Tech** | arstechnica.com, theregister.com, theverge.com, techcrunch.com, howtogeek.com, news.ycombinator.com |
| **AI / ML** | venturebeat.com, arstechnica.com, techcrunch.com, theverge.com, wired.com |
| **Security / Cyber** | bleepingcomputer.com, krebsonsecurity.com, darkreading.com, therecord.media, securityweek.com |
| **Mobile / Devices** | 9to5google.com, 9to5mac.com, gsmarena.com, theverge.com |
| **Linux / Open Source** | 9to5linux.com, lwn.net, omgubuntu.co.uk, phoronix.com |
| **Finance / Business** | reuters.com, bloomberg.com, ft.com, cnbc.com, wsj.com, marketwatch.com |
| **Crypto / Web3** | coindesk.com, theblock.co, decrypt.co, cointelegraph.com |
| **Science** | nature.com, sciencedaily.com, phys.org, newscientist.com, scientificamerican.com |
| **Health / Medicine** | statnews.com, medscape.com, reuters.com, nejm.org |
| **Politics / World** | reuters.com, apnews.com, bbc.com, theguardian.com, politico.com, foreignpolicy.com |
| **Startups / VC** | techcrunch.com, venturebeat.com, crunchbase.com, sifted.eu |

---

## Steps

### Step 0 — Model check

This skill is optimized for **Haiku** (`/model haiku`) for speed and cost.

Check the current model from the system context. If you are not running on Haiku:
- Output: "💡 b-news runs best on Haiku. Run `/model haiku` for faster, cheaper digests."
- **Continue anyway** — Haiku is recommended, not required. Any model can produce the digest.

---

### Step 1 — Parse user input

Extract topics from the user's message:
- `b-news AI crypto` → topics: `["AI", "crypto"]`
- `b-news` or "tin tức hôm nay" (no topic) → topics: `["tech"]` (default)
- `b-news tài chính thị trường` → topics: `["finance", "markets"]`
- `b-news React TypeScript` → topics: `["tech", "JavaScript ecosystem"]`

Map each topic to its domain in the trusted sources table above. If a topic spans multiple
domains (e.g., "AI in healthcare"), select sources from both relevant domains.

### Step 2 — Generate search queries

Generate **3 to 5 queries** based on extracted topics, covering different angles:
- 1 broad query per major topic
- 1 focused query on recent developments or key players in that space
- If user has ≥ 2 topics: allocate ~2 queries per topic, cap at 5 total

Examples:
- Topic `AI`: → `"artificial intelligence latest news"`, `"OpenAI Google DeepMind update"`
- Topic `finance`: → `"financial markets news today"`, `"stock market economy latest"`
- Topic `crypto`: → `"cryptocurrency Bitcoin Ethereum news"`, `"crypto market regulation"`
- Topics `AI + crypto`: → `"AI news today"`, `"OpenAI Gemini update"`, `"cryptocurrency news today"`, `"Bitcoin Ethereum latest"`

Do NOT use `site:` operators or boolean `OR` — use natural topic keywords only.

### Step 3 — Run parallel searches

Run all generated queries **in parallel** (single message, multiple tool calls).

- Tool: `brave_news_search`
- Parameters: `count: 5`, `freshness: "pd"` (past day)

After collecting results: if total unique stories is fewer than 10 →
retry the 2 broadest queries with `freshness: "pw"` (past week).
Mark any stories from the retry with `(earlier this week)` in the output.

From each result, collect: headline, URL, 1-sentence snippet, source domain, published date.

### Step 4 — Filter and select sources

From all collected stories (~15–25 total):
- **Prefer** stories from domain-matched trusted sources in Step 1
- **Accept** stories from Universal tier (reuters, apnews, bbc) regardless of domain
- **Discard**: duplicates covering the same event (keep the best source), opinion pieces,
  sponsored content, listicles ("10 best…"), and stories older than 48 hours
- **Keep**: max 3 stories per sub-topic category — quality over quantity

### Step 5 — Categorize dynamically

Derive categories from the actual topics found in results — do NOT use hardcoded category sets.

Category rules:
- Create one category per distinct sub-topic identified in the results
- Name each category with a relevant emoji + label (e.g., `🤖 AI & Machine Learning`, `💰 Markets`, `🔬 Research`)
- Omit any category with 0 stories — never pad with weak content
- Use a `📌 Other` catch-all only when a story doesn't fit any derived category

### Step 6 — Scrape for detail (on demand only)

Only if the user follows up with "đọc thêm về..." / "chi tiết về..." / "tell me more about..." a specific story:
call `firecrawl_scrape` on that one URL and summarize the full article.
Do NOT bulk-scrape during initial digest generation.

---

## Output format

**Language detection**: Check the user's query language before formatting.
- Vietnamese query ("tin tức", "điểm tin", "hôm nay có gì mới") → bilingual output
- English query ("news today", "what's new in X") → English-only output
- Ambiguous or mixed → default to bilingual

The header title reflects the actual topics, not a generic label.

### Bilingual output (Vietnamese query)

```
# 📰 [Topic] News — [Today's Date]

## [Emoji] [Category Name]

**[English Headline]**
[1-sentence English summary] — ([Source Name](URL))
> [Tiêu đề tiếng Việt] — [1 câu tóm tắt tiếng Việt]

[... remaining categories ...]

---
*[N] stories · Topics: [user-specified topics] · Preferred sources: [comma-separated domains used]*
```

### English-only output (English query)

```
# 📰 [Topic] News — [Today's Date]

## [Emoji] [Category Name]

**[English Headline]**
[1-sentence English summary] — ([Source Name](URL))

[... remaining categories ...]

---
*[N] stories · Topics: [user-specified topics] · Preferred sources: [comma-separated domains used]*
```

---

## Rules

- Always include today's actual date in the header
- Always run all search queries in parallel — never sequentially
- Never use `site:` operator or boolean `OR` in queries
- Max 3 stories per category — cut weakest stories if more found
- Omit empty categories rather than padding with weak content
- Do not scrape during digest generation — search snippets are sufficient
- Vietnamese translations must be natural, not literal word-for-word
- Footer must list the actual source domains that returned results, not the full trusted-sources table
- If user specifies no topic, default to tech news (backward compatible with existing trigger phrases)
