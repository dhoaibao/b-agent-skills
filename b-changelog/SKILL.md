---
name: b-changelog
description: >
  Fetch and summarize the changelog or release notes for a package, tool, or library.
  ALWAYS use this skill when the user asks "changelog của X", "phiên bản mới nhất của X",
  "X có gì mới", "what changed in X", "release notes for X", "latest version of X",
  or anything about recent updates to a specific tool, package, or library.
---

# b-changelog

Fetches the latest changelog or release notes for a given tool/package and summarizes
the most important changes.

## Tools required

- `brave_web_search` — from `brave-search` MCP server
- `firecrawl_scrape` — from `firecrawl` MCP server

If either tool is unavailable, stop and tell the user:
- brave-search missing: "❌ brave-search MCP is not connected. Please check `/mcp`."
- firecrawl missing: "❌ firecrawl MCP is not connected. Please check `/mcp`."

Do NOT rely on training data for version or changelog information — it may be outdated.

## Steps

### 1. Find the changelog URL
Use `brave_web_search` with a query like:
- `<package> changelog site:github.com`
- `<package> release notes`
- `<package> latest version`

Prioritize in this order:
1. GitHub Releases page (`github.com/<org>/<repo>/releases`)
2. Official changelog file (`CHANGELOG.md`)
3. Official docs changelog page
4. npm/PyPI release page as last resort

### 2. Scrape the changelog
- Call `firecrawl_scrape` on the best URL found
- Focus on the most recent 1–3 versions

### 3. Summarize
- Extract the latest version number and release date
- List breaking changes first (if any)
- Then new features, then bug fixes
- Skip minor/patch noise unless specifically asked

## Output format

```
## [Package Name] — Latest: vX.Y.Z (YYYY-MM-DD)

### Breaking Changes
- ...

### New Features
- ...

### Bug Fixes
- ...

Source: [URL]
```

If no breaking changes, omit that section.

## Rules

- Always state the version number and release date
- Always cite the source URL
- If the changelog page is too long, focus on the latest 2–3 releases only
- If the user asks about a specific version range, scrape and summarize that range
