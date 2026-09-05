---
name: b-implement
description: >
  Execute approved or scoped non-UI work safely after b-plan approval,
  when a user gives a small direct request or an approved plan. Applies
  the next small step, verifies it, and hands back to planning or research
  instead of guessing when new ambiguity appears. Frontend/UI code—pages,
  layouts, components, styling, responsive behavior, interactions, or
  visual refreshes—belongs to b-frontend instead. Unlike b-plan,
  b-implement changes code.
---

<!-- Generated from skills/registry.yaml and skills/b-implement/prompt.md. Edit those sources, not this file. -->

# b-implement

Make the scoped non-UI change in the smallest coherent step after an approved plan or clear direct request.

## When to use

- The user approved a plan or gave a small direct request.
- The next action is a scoped non-UI code or repository change.

## When NOT to use

- Scope or behavior is unclear -> use **b-plan**.
- Frontend/UI code -> use **b-frontend**.
- A named behavior-preserving transform -> use **b-refactor**.
- Test-only work -> use **b-test**.
- An unknown runtime failure -> use **b-debug**.

## Tool guidance

- Use Pi native file tools by default and native tools or local search for routine discovery. Select CodeGraph only when a repository-wide architecture, impact, or affected-test question is central. Use supplied compacted observational-memory ids rather than guessing.

## Steps

1. Resolve the approved plan or direct request, run `rtk git status --short`, and preserve unrelated changes.
2. Before edits, consult applicable project standards, architecture boundaries, and relevant failure modes. State affected paths, invariants, observable success criteria, and relevant quality constraints. Use repository evidence; select CodeGraph only for a concrete central repository-wide question. Route material framework/API best-practice uncertainty to targeted **b-research**.
3. Ask the user directly with `ask_user_question` only for a material unresolved choice. Do not relay normal clarification through a reviewer.
4. Make the smallest coherent edit with native tools and remove imports/helpers made unused by it.
5. Run the narrowest useful verification, correct in-scope defects, and inspect explicit non-protected changed paths.
6. Before review, freeze the candidate: stop edits and provide the reviewer a compact snapshot covering tracked and relevant untracked/derived content, required checks and outcomes, acceptance, constraints, gaps, and risk. Do not claim a reviewer is fresh, provision one, or reset a session.
7. Do not edit while review is pending. A changed snapshot, skipped/failed required check, missing baseline, wrong reviewer, `NEEDS FIXES`, or unaccepted follow-up blocks shipping. Reverify and request another review after corrections. No review automatically commits or pushes.

## Output format

Changes, verification, acceptance coverage, and deviations or gaps. For a changed candidate, request actual **b-review** from an explicitly selected compatible reviewer and pause edits.

## Rules

- Stay within approved scope and use the smallest evidence-backed fit.
- Roles govern prompts, not tools; shared approval policy remains authoritative.
- Same-day changelog maintenance is required only when preparing a user-authorized commit. Include it in the reviewed candidate or reopen review.
- Never claim completion when required verification or the independent review gate is absent.
