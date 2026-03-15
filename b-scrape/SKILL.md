---
name: b-scrape
description: >
  Scrape a URL and return clean markdown content using Firecrawl.
  ALWAYS use this skill when the user provides a URL and asks to "scrape", "đọc trang này",
  "lấy nội dung", "fetch this page", "read this link", or pastes a URL and wants its content.
  Trigger even if the user just pastes a URL without explanation.
---

# b-scrape

Scrapes a single URL using Firecrawl and returns clean markdown content.

## Tools required

- `firecrawl_scrape` — from `firecrawl` MCP server

If unavailable, stop and tell the user: "❌ firecrawl MCP is not connected. Please check `/mcp`."

Do NOT fall back to built-in web search or training data.

## Steps

1. Call `firecrawl_scrape` with the provided URL
   - Use `formats: ["markdown"]`
2. Return the content cleanly — no raw JSON, no metadata noise
3. If the page fails to scrape, tell the user: "❌ Failed to scrape `<URL>`. The page may require authentication or JavaScript that Firecrawl cannot handle."

## Output format

- Return the scraped content as-is in markdown
- Prepend with the page title and URL:
  ```
  ## [Page Title]
  Source: <URL>

  [scraped markdown content]
  ```
- If the user asked a specific question about the page, answer it after the content block

## Rules

- Do not summarize unless the user asks — return full content
- Do not truncate content
- Only scrape one URL at a time — if multiple URLs are given, ask which one to scrape first
