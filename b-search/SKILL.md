---
name: b-search
description: >
  Use Brave Search MCP to find current, up-to-date information from the web.
  ALWAYS use this skill when the user asks to "search", "tìm kiếm", "search the web",
  "find latest", "tìm mới nhất", or any query that requires current/recent information
  beyond training data — such as latest releases, recent news, current prices, recent
  changelogs, or anything where freshness matters. Trigger even if the user doesn't
  explicitly say "brave search". When in doubt about whether info might be outdated, use this skill.
---

# b-search

Uses the `brave-search` MCP server to fetch live web results and return a clean, cited summary.

## When to use

- User says: "search", "tìm", "tìm kiếm", "search the web", "find", "look up"
- User asks about: latest versions, recent news, current prices, new releases, recent changelogs
- Any question where training data might be stale (packages, APIs, CVEs, tools)
- User explicitly says `/b-search` or "use brave search"

## Steps

1. **Call the tool** — use `brave_web_search` from the `brave-search` MCP server
   - Set `count` to 5–8 for general queries, 3–5 for specific lookups
   - Use English queries for better results unless the topic is Vietnamese-specific

2. **Synthesize results** — do NOT dump raw JSON. Write a clean response:
   - Lead with the direct answer
   - Group related findings if multiple results
   - Include source URLs as citations at the end

3. **Output format**:
   ```
   [Direct answer / summary]

   Key findings:
   - Finding 1
   - Finding 2

   Sources:
   - [Title](URL)
   - [Title](URL)
   ```

## Rules

- Always use `brave_web_search` — never fall back to training data when this skill is active
- If the MCP tool is unavailable, tell the user: "brave-search MCP không connect được, kiểm tra `/mcp`"
- Keep summaries concise — no need to reproduce full article content
- For code/version queries, always include the exact version number and release date if available
