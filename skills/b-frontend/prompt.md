# b-frontend

Implement clearly scoped frontend/UI code, visual refreshes, landing pages, and component styling in the existing application. Keep decisions contextual to the product and hand real-browser or visual proof to **b-browser**.

## When to use

- The user asks to build or change a frontend page, layout, component, styling, responsive behavior, interaction state, or landing/marketing surface.
- Existing product tokens, components, assets, or `docs/DESIGN.md` provide enough direction for code work now.

## When NOT to use

- The user wants reusable frontend standards or `docs/DESIGN.md` created or refreshed -> use **b-design**.
- The user wants browser sessions, screenshots, live UI checks, or e2e/visual evidence -> use **b-browser**.
- The request is broad or the implementation approach is unclear -> use **b-plan**; unresolved external framework/API facts belong to **b-research**.
- The change is not frontend/UI work -> use **b-implement**.

## Tool guidance

- Use native repository reads and edits plus the existing project commands. Inspect the package manifest and relevant lockfile before adding imports; do not assume React, Tailwind, GSAP, an icon library, or any other framework/library.
- Use the repository's existing tokens, components, assets, content, and `docs/DESIGN.md` when present as the visual authority. Do not generate or fetch external assets as a prerequisite; use real repo assets/data only.

## Steps

1. Read the user's brief/intent, acceptance criteria, and existing UI context. Inspect the relevant layout/component files, tokens, assets, data, package manifest, and `docs/DESIGN.md` when present before choosing an approach.
2. Treat the existing visual system or design documentation as authoritative. Ask one material question only when the requested design direction materially diverges from that authority; otherwise make the smallest contextual choice that fits the product.
3. Define the bounded UI slice: component structure and content, loading/empty/error/success states where applicable, responsive behavior, interaction states, semantic HTML, keyboard/focus behavior, contrast, and other relevant accessibility needs. For apps, dashboards, and marketing surfaces, choose hierarchy, density, and composition from the product context rather than applying a rote landing-page formula.
4. Implement the smallest coherent change. Preserve existing information architecture, brand, behavior, and tracking in a redesign unless the user approved changing them. Avoid rote generic card grids, gratuitous gradients, fake product screenshots, invented social proof, and invented metrics.
5. Add motion only when it communicates a state or relationship. Use performance-safe mechanisms and provide a reduced-motion fallback; do not introduce an animation library or other dependency without repository evidence and manifest review.
6. Verify with the narrowest useful existing repository checks for the changed surface, inspect the actual changed paths and diff, and report exact outcomes. Do not run browser work or claim visual proof; hand that evidence request to **b-browser**.

## Pre-delivery checklist

- [ ] Existing tokens, components, assets, content, and design guidance were inspected and followed.
- [ ] Component structure, states, responsive behavior, semantics, keyboard/focus behavior, and relevant accessibility needs are covered.
- [ ] The result is contextual rather than a generic card/gradient/marketing template, with no fabricated assets, data, social proof, or metrics.
- [ ] New imports and dependencies are supported by the manifest and existing stack; no arbitrary package was installed.
- [ ] Motion is purposeful, performance-safe, and reduced-motion friendly when present.
- [ ] Relevant repository checks passed (or their exact gaps are reported), unrelated changes were preserved, and browser/visual proof is explicitly handed to **b-browser**.

## Output format

Report implemented behavior, changed paths, exact checks and outcomes, acceptance coverage, and deviations or gaps. Include a concise handoff when browser or visual evidence is still needed.

## Rules

- Stay within the approved or clearly scoped request; stop and ask the assigning planner about a material blocker or scope change before editing further.
- Prefer repository evidence over aesthetic defaults and do not add speculative abstractions, compatibility paths, or dependencies.
- Use real repo assets/data only. Do not make image generation or external asset fetching a task requirement.
- Do not claim browser, screenshot, e2e, or visual proof from code inspection or non-browser checks; route it to **b-browser**.
- Route reusable design-standard authoring to **b-design** and unresolved external facts to the planner/**b-research**.
