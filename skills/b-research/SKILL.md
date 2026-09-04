---
name: b-research
description: >
  External knowledge, from quick lookup to multi-source synthesis, for
  library/framework docs, API facts, config keys, method signatures,
  comparisons, deep dives, or recency-sensitive topics. Auto-detects
  depth, answers with sources, and hands off to implementation when the
  next action is obvious. Unlike b-debug or b-plan, it fetches docs and
  web information rather than tracing code or choosing implementation.
---

<!-- Generated from skills/registry.yaml and skills/b-research/prompt.md. Edit those sources, not this file. -->

# b-research

Fetch outside truth at the lightest reliable depth, with sourced evidence and a clear next step when action naturally follows.

## When to use

- Library, framework, SDK, API, config, method signature, setup, migration, or capability questions.
- Comparisons, current facts, cited reports, or multi-source synthesis.
- Known URLs or documents require extraction.

## When NOT to use

- The repo itself can answer with one local lookup.
- Runtime tracing is needed -> use **b-debug**.
- Planning/sequencing is needed -> use **b-plan**.
- Changed-code review is needed -> use **b-review**.
- In a two-role workflow, the planner owns external research; workers ask the assigning planner rather than researching independently.
- Mobbin is not a general factual-research source; do not use it for ordinary documentation, API, or current-facts research, UI implementation, or visual QA.

## Tool guidance

- `context7` - versioned official library/framework docs.
- `firecrawl` - primary bounded public search (`firecrawl_search` limit ≤10), `firecrawl_developer_search` for programming/API/library questions, scrape/map/extract for known public URLs, and `research_search_papers` / `research_inspect_paper` / `research_read_paper` / `research_related_papers` / `research_search_github` for papers or prior-art/issue history.
- `brave-search` - independent web corroboration; use `brave_news_search`, `brave_local_search`, `brave_image_search`, `brave_video_search`, `brave_place_search`, `brave_summarizer`, or `brave_llm_context` only when that modality is required.
- `mobbin` - a deliberately narrow exception for an explicit standalone UI/UX precedent study or competitive UI comparison deliverable, not a general factual-research source. Choose `mobbin_search_screens` for screen, component, or state analysis; `mobbin_search_flows` for end-to-end journey analysis; or `mobbin_search_sections` for web-section analysis. Keep queries bounded and precise, use `task_intent` where useful, and inspect returned images rather than relying on metadata. Distinguish observed patterns from recommendations, and cite screen findings with the canonical `mobbin_url`. Do not use Mobbin for implementation or visual QA. If the findings need to become a durable design standard, `b-design` owns turning them into `DESIGN.md`.

## Steps

1. Classify the question and required source quality.
2. Pin version from resolved lockfiles (e.g., package-lock.json, poetry.lock, Cargo.lock, pnpm-lock.yaml) or go.mod when API details matter. Use manifests (e.g., package.json, pyproject.toml) only as a fallback, and state the uncertainty when versions are not pinned.
3. Use Context7 first for versioned library/framework APIs when suitable.
4. Use Firecrawl search first for public web discovery and current sources when library docs alone do not answer the question. Set an explicit result limit of at most 10.
5. Use Firecrawl for bounded extraction from known public URLs. Ask before deep autonomous research, broad crawls, or private/internal material.
6. Use Brave web search for independent corroboration. Switch to Brave's specialized tools only when the question needs news, local, image, video, place, summarizer, or llm-context results.
7. For academic/paper-grounded questions or prior-art/issue history, call Firecrawl `research_*` tools directly instead of generic web search. Do not submit Firecrawl feedback, start crawls/agents, or handle private material without approval.
8. For bounded multi-source research, use this recipe: start with Context7 for versioned library/framework facts; use Firecrawl developer search or bounded public search for primary-source discovery; use Brave for independent corroboration when needed; and use the trusted `mcpScript` container only for bounded, read-only fan-out with an explicit small call limit and per-source result limit; read-only metadata discovery is trusted and every nested `tools.call` retains normal approval policy.
9. Deduplicate sources and preserve URL, version, and provenance. Label each claim as direct evidence, corroboration, or unresolved uncertainty. If one research server is unavailable, continue with the approved fallback sources and state the resulting coverage gap.
10. Keep private/local material out of external tools unless explicitly approved.
11. Synthesize only from gathered evidence and cite sources.
12. When research points directly to a local change, hand frontend/UI production work to **b-frontend** and non-UI code/config work to **b-implement**; when uncertainty remains, say what is still unknown.

## Output format

Direct answer, key evidence, limitations, sources, and confidence when not high. Include the next handoff only when it is naturally implied.

## Mobbin exception

Use Mobbin only when the requested output is an explicit standalone UI/UX precedent or competitive comparison deliverable. Choose the analysis unit deliberately: `mobbin_search_screens` for screens, components, or states; `mobbin_search_flows` for end-to-end journeys; and `mobbin_search_sections` for web sections. Keep queries bounded and precise, use `task_intent` where useful, inspect returned images rather than just metadata, and cite screen findings with the canonical `mobbin_url`. Label what is directly observed in the returned references separately from recommendations or implications. This exception does not cover ordinary docs/API/current-facts research, UI implementation, or visual QA. `b-design` owns turning any resulting design guidance into `DESIGN.md`.

## Rules

- Use the lightest depth that answers correctly.
- Prefer primary sources over tutorials.
- Do not send private or internal material to public tools without approval.
- Hand off frontend/UI production changes to **b-frontend**, other code/config changes to **b-implement**, and tracing to **b-debug**.
