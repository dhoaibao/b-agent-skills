# Agent Model Tiers

Classification of 4 b-agents into tiers based on task complexity and model capability needed.

---

## Tier 1 — Opus (deep reasoning / critical decisions)

Agents where wrong output causes cascade failures. Low call frequency, higher cost acceptable.

| Agent | Model | Why Tier 1 |
|---|---|---|
| `b-plan` | `opus` | Wrong decomposition or approach decision → entire implementation fails. Needs deep reasoning for trade-offs, feasibility, impact analysis |
| `b-debug` | `opus` | Wrong root cause → wrong fix → bug persists. Hypothesis ranking needs critical thinking |

---

## Tier 2 — Sonnet (balanced quality + cost)

Agents producing findings or reports. Good quality needed but not critical.

| Agent | Model | Why Tier 2 |
|---|---|---|
| `b-review` | `sonnet` | Missed logic bug or security vuln ships to production — needs careful judgment |
| `b-research` | `sonnet` | Tool-use heavy, output is a reference report or docs lookup |

---
