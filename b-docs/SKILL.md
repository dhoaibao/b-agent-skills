---
name: b-docs
description: >
  Fetch live, version-accurate library documentation from Context7 before writing integration code.
  ALWAYS use when the user mentions a library by name (SendGrid, BullMQ, Prisma, Zod, Stripe, etc.),
  asks "how to use X", "X API", "does X support Y", "tra cứu", "hướng dẫn sử dụng", "cách dùng thư viện",
  or before any SDK integration. Never implement library code from memory alone — training data may be outdated.
  Distinct from b-research: use b-docs for specific API lookup, b-research for deep multi-source synthesis.
---

# b-docs

Fetch versioned, accurate documentation from Context7 before writing any library or
SDK code. Prevents hallucinated APIs, wrong method signatures, and version mismatches.

## When to use

- User asks how to use a specific library, SDK, or framework feature
- User is about to implement integration with a third-party service (SendGrid, Mailgun, AWS SES, Stripe, etc.)
- User asks "does X support Y?", "what's the API for X?", "how to configure X?"
- Before implementing ANY code that calls an external library — even familiar ones
- When context says the project uses a specific version (e.g. `sendgrid@8`, `bullmq@5`)

## When NOT to use

- User wants a deep comparison or multi-source report → use **b-research**
- User is debugging a broken library call → use **b-debug**
- User wants general news or current events → use **b-quick-search** or **b-news**

## Tools required

- `resolve-library-id` — from `context7` MCP server
- `query-docs` — from `context7` MCP server
- `firecrawl_scrape` — from `firecrawl` MCP server *(optional, fallback when context7 has no index)*

If context7 is unavailable:
- Tell the user: "❌ context7 MCP is not connected. Please check `/mcp`."
- Do NOT fall back to training data for API details — offer to use `b-research` to scrape official docs instead.

Graceful degradation: ⚠️ Partial — fallback chain: context7 → firecrawl (direct scrape of official docs) → b-research (full research pipeline).

## Recommended model

**Sonnet** (`/model sonnet`) — default is sufficient.

Most work is retrieval (resolve library ID → fetch docs). Code generation from well-structured docs does not require deep reasoning. Sonnet handles this reliably.

---

## Steps

### Step 1 — Identify library and topic

First, use `Glob` to find `package.json`, `pyproject.toml`, or `requirements.txt` in the project root. If found, read it and extract the version of the requested library. Use this version when calling `query-docs`. If the file is not found or version parsing fails (e.g. `workspace:*`, missing entry), continue without version constraint — do not block on this.

If the extracted version contains a range operator (`^`, `~`, `>=`, `*`, or `workspace:*`), the version is imprecise. In that case, check for a lock file: read `package-lock.json` (look for `"resolved"` or `"version"` under the package name), `pnpm-lock.yaml` (look for `version:` under the package), or `yarn.lock` (look for the resolved version line). Use the exact version found in the lock file. If no lock file exists, proceed with the range version and note: `⚠️ Using version range [range] — Context7 docs may not match exact installed version.`

Extract from the user's request:
- **Library name**: e.g. `sendgrid`, `bullmq`, `@aws-sdk/client-ses`
- **Topic / feature**: the specific API area needed, e.g. `send email`, `webhook verification`, `retry configuration`, `job scheduling`
- **Version** (if mentioned in conversation or package.json): e.g. `v8`, `v5`

If multiple libraries are involved (e.g. "integrate Mailgun with Express"), run Steps 2–3 for each library separately.

---

### Step 2 — Resolve library ID

Call `resolve-library-id` with the library name.

- If multiple results return, pick the one with the highest match and correct scope (e.g. prefer `@sendgrid/mail` over a community fork)
- If no result found: try the firecrawl direct-scrape fallback (see below) before escalating to b-research

**Firecrawl direct-scrape fallback** *(when context7 has no index for a library)*:
If the library has a well-known official docs URL (e.g. docs.sendgrid.com, docs.bullmq.io, docs.stripe.com) → call `firecrawl_scrape` on that URL with `formats: ["markdown"], onlyMainContent: true`. If the scrape returns ≥300 words of relevant content → use it directly as the doc source, skip b-research. If the scrape fails or returns <300 words → then escalate to b-research: tell the user "⚠️ context7 has no index for `[library]` and direct scrape was insufficient. Falling back to b-research to scrape official docs."

---

### Step 3 — Fetch docs

Call `query-docs` with:
- The resolved library ID from Step 2
- `topic`: the specific feature area (keep focused — don't fetch entire docs)
- `tokens`: 8000 for simple APIs, 12000–15000 for complex ones (auth flows, multi-method APIs, SDK setup)

Repeat with a different `topic` if the user's task spans multiple API areas (e.g. "send email" AND "handle bounce webhooks" — fetch both).

---

### Step 4 — Extract and present

From the fetched docs, extract only what's needed for the user's task:

- Correct method names and signatures
- Required vs optional parameters
- Authentication setup (especially if it changed between versions)
- Error codes and exception types
- Any deprecation notices or breaking changes relevant to the user's version

**Do not dump the entire docs.** Summarize the relevant section, show the key API surface, then implement or answer the user's question based on that.

---

### Step 5 — Hand off

Present the extracted API surface. Then route based on context:

- **Lookup only** ("how does X work?") → stop here, output lookup format below
- **User requested implementation** → write the code using the fetched docs; add a one-line comment on non-obvious API calls: `// per Context7: sendgrid v8 uses dynamic templates`
- **Called from b-feature pipeline (Phase 3a)** → return the fetched doc context to Phase 4 (Implement). Do NOT implement here — the orchestrator handles execution in Session 2.

If the docs reveal a caveat or version difference, call it out explicitly before any code.

---

## Output format

For a lookup-only request ("how does X work?"):

```
### `[LibraryName]` — [feature/topic]
*(Context7 — [library-id], [version if available])*

[2–3 sentence summary of the API]

**Key methods:**
- `method(params)` — what it does
- ...

**Example:**
\`\`\`js
// minimal working example based on fetched docs
\`\`\`

**Notes:**
- Any gotchas, deprecations, or version differences found in docs
```

For an implementation request ("implement X using Y"):

- Skip the lookup-only format
- Write the implementation directly, informed by the fetched docs
- Add a one-line comment citing Context7 on any non-obvious API call

---

## Topic query tips

Keep the `topic` param focused — a narrow topic returns the right section faster:

| Instead of | Use |
|---|---|
| `"email"` | `"send email with attachments"` |
| `"authentication"` | `"API key setup"` or `"OAuth flow"` |
| `"errors"` | `"error codes and exception types"` |
| `"setup"` | `"installation and configuration"` |

When the task spans multiple areas, run `query-docs` once per topic rather than one broad fetch.

---

## Rules

- Never implement library code from training data alone — always fetch first
- If context7 returns docs for a different major version than the project uses, flag it explicitly: "⚠️ Context7 returned docs for v3 but your package.json shows v8 — API may differ"
- Keep topic queries focused — broad topic = too much noise, wrong section fetched
- If docs are sparse or unhelpful, escalate to `b-research` to scrape official docs directly
- One `query-docs` call per distinct API area — don't batch unrelated topics in one fetch