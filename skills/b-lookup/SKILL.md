---
name: b-lookup
description: >
  Legacy compatibility alias for b-research quick mode. Do not auto-invoke. Keep only
  for callers that explicitly type `/b-lookup`; new quick questions like "lookup",
  "tra cứu nhanh", "what's the API for", "method signature of X", and "config key for Y"
  should go to `/b-research`.
effort: low
disable-model-invocation: true
user-invocable: false
---

# b-lookup

$ARGUMENTS

Legacy compatibility alias. Prefer `/b-research`, which now auto-detects quick lookup vs full research.

If `$ARGUMENTS` is provided, treat it as the lookup question — answer in quick mode only.

## When to use

- Only when a caller explicitly invokes `/b-lookup` for backward compatibility.
- Quick fact question that fits in 1–3 sentences.

## When NOT to use

- New user-facing lookups → use **b-research**
- Multi-source research, comparisons, or anything that needs scraping → use **b-research**

## Tools required

- Same as `b-research` quick mode: `resolve-library-id`, `query-docs`, and `brave_web_search`

Graceful degradation: ⚠️ Partial — if quick mode cannot answer with Context7 and/or one Brave search, escalate to `/b-research` full mode.

## Behavior

- Use the same quick-mode flow as `b-research`.
- Context7 first for library/framework questions.
- Single Brave search fallback.
- No scraping, crawling, or synthesis.
- Return a direct 1–3 sentence answer with a minimal example.

## Output format

```
### `[Library or Topic]` — `[question]`

[1–3 sentence direct answer]

**Example:**
```[lang]
// minimal working example
```

**Source**: Context7 (`library-id`) / Brave Search
```

## Rules

- Do not auto-invoke this skill.
- Do not present this as the recommended entry point.
- If the answer needs multiple sources or page reads, escalate to `/b-research` full mode.
