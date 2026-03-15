---
name: b-doc-read
description: >
  Read and answer questions from a documentation page using Firecrawl.
  ALWAYS use this skill when the user provides a docs URL and asks a question about it,
  says "đọc docs này", "theo docs này thì...", "check the docs for...", "what does the
  docs say about...", or pastes a documentation link and wants to understand something
  from it. Prefer this over training data when a specific docs URL is provided.
---

# b-doc-read

Scrapes a documentation page via Firecrawl and answers the user's question based on
the actual content — not training data.

## Tools required

- `firecrawl_scrape` — from `firecrawl` MCP server

If unavailable, stop and tell the user: "❌ firecrawl MCP is not connected. Please check `/mcp`."

## Steps

1. **Scrape the docs page** using `firecrawl_scrape`
   - Use `formats: ["markdown"]`
2. **Read the content carefully**
3. **Answer the user's question** based strictly on what the docs say
   - If the answer is in the docs, cite the relevant section
   - If the answer is NOT in the docs, say so explicitly — do not guess from training data
4. If the docs page links to sub-pages that are more relevant, offer to scrape those too

## Output format

```
### Answer
[Direct answer to the user's question based on the docs]

### From the docs
> [Relevant excerpt or paraphrase from the scraped content]

Source: [URL]
```

If the question cannot be answered from the scraped page:
```
❌ The answer to your question was not found on this page: <URL>
The page covers: [brief summary of what the page actually contains]
Would you like me to search for a more relevant docs page?
```

## Rules

- Always base answers on scraped content — never on training data
- Always cite which section of the docs the answer came from
- If the user didn't provide a URL, ask for one before proceeding
- Do not hallucinate — if unsure, say so and offer to search for a better source
