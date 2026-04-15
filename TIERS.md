# Skill Effort Tiers

Classification of 4 b-skills into tiers based on task complexity and model capability needed.

---

## Tier 1 — Premium (deep reasoning / critical decisions)

Skills where wrong output causes cascade failures. Low call frequency, high cost acceptable.

| Skill | Why Tier 1 |
|---|---|
| `/b-plan` | Wrong decomposition or approach decision → entire implementation fails. Needs deep reasoning for trade-offs, feasibility, impact analysis |
| `/b-debug` | Wrong root cause → wrong fix → bug persists. Hypothesis ranking needs critical thinking |

---

## Tier 2 — Standard (balanced quality + cost)

Skills producing findings or reports. Good quality needed but not critical.

| Skill | Why Tier 2 |
|---|---|
| `/b-review` | Missed logic bug or security vuln ships to production — needs careful judgment |
| `/b-research` | Tool-use heavy, output is a reference report or docs lookup |