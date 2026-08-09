# b-test

Own code-level and simulated-DOM tests: add coverage, fix test-only failures, and avoid confusing red tests with product bugs.

## When to use

- The user asks to write tests, fix failing tests, evaluate coverage, or work TDD-style.
- The issue is assertion, mock, fixture, setup, snapshot, or test coverage.
- Non-browser unit, integration, contract, simulated-DOM, and component tests are in scope.

## When NOT to use

- The failing test likely exposes product behavior -> use **b-debug**.
- Real browser, visual, session, or e2e evidence is needed -> use **b-browser**.
- Intended behavior is unclear -> use **b-plan** or **b-debug**.
- A new test framework is needed -> use **b-plan** first.

## Tool guidance

- `bash` - run tests via `rtk` when supported (`rtk pytest`, `rtk vitest`, `rtk jest`, …) and inspect failure output.
- `serena` - prefer Serena for supported test/source inspection and repo-confined edits; map tests to source behavior and edit test symbols.
- `read`/`edit` - use Pi native tools for unsupported files or when Serena fails.
- `codegraph` - only for repository-wide source-to-test impact and affected-test discovery; initialize an absent local index on first such use.
- `context7` - versioned test-framework/API semantics only when local tests and contracts do not settle them.

## Steps

1. Find the test framework and narrowest runnable command from manifests, CI, or existing tests (using Bash). Use CodeGraph only when repository-wide source-to-test impact is needed, initializing an absent index then; use Serena separately for exact test/source symbols.
2. Confirm intended behavior from user intent, product contract, source change, existing passing tests, and materially relevant repo context. Use Context7 only for unresolved versioned framework semantics.
3. For failing tests, run the narrow target, read the test and exercised source, edit tests only after classifying the failure.
4. For new tests, cover requested or changed behavior through the highest practical public interface first; add edge cases only when risk requires them.
5. For explicitly requested TDD, use vertical tracer bullets: add one failing behavior test, make the smallest production change needed to pass it, verify, then continue to the next behavior. Outside explicit TDD, route production changes to **b-implement**.
6. Select affected tests before broad suites: when a current CodeGraph index is available, ask it for changed-symbol/file impact and affected tests; otherwise use local search, test discovery, and repository scripts. Run the narrow affected set first, then expand only when the change or risk requires it.
7. Report the selected tests, whether CodeGraph or fallback discovery supplied them, and any remaining coverage gap. A partial or affected-only run must never be described as full-suite coverage.
8. Run diagnostics when useful, then the narrowest relevant test, and verify the test proves the intended behavior.

## Output format

Test scope, changes, verification, and remaining gaps.

## Rules

- Never change production code only because a test is red.
- Keep production-code changes in **b-implement** unless the user explicitly requested a tightly scoped TDD red-green loop.
- Never update assertions, snapshots, or goldens without confirming intended behavior.
- Avoid implementation-coupled tests and mocks derived from buggy implementation instead of the real interface.
- Do not introduce frameworks without approval.
- Keep fixture and mock changes local when practical.
