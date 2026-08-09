# b-browser

Own real-browser, visual, screenshot, live UI, browser-session, and e2e evidence.

## When to use

- The user asks for browser, visual, screenshot, live UI, or e2e checks.
- PR readiness depends on real-browser evidence.
- Another phase reports a browser evidence gap.

## When NOT to use

- Unit, integration, contract, mock, fixture, snapshot, or simulated-DOM work -> use **b-test**.
- Implementing UI behavior or fixing app code -> use **b-implement** or **b-debug**.
- Changed-code review with sufficient browser evidence already supplied -> use **b-review**.

## Tool guidance

- `bash` - existing approved browser/e2e commands (`rtk playwright` when using the CLI runner).
- `playwright` - approval-gated `browser_navigate` / interactions; then `browser_snapshot`, `browser_find`, `browser_console_messages`, `browser_network_requests` / `browser_network_request`; `browser_take_screenshot` only when requested (approval-gated local artifact).
- `codegraph` - only for repository-wide flow or impact after a confirmed product failure; initialize an absent local index on first such use.
- `serena` - map browser failures to exact source ownership.

## Steps

For bounded, read-only multi-page browser observations, the trusted `mcpScript` container can reduce round trips when several MCP calls share one session; read-only metadata discovery is trusted and each nested `tools.call` retains normal approval policy. Use at most three routes per script and cap each page's extracted result set; it is an observation aid, not a replacement for the ordered browser evidence workflow.

1. Classify the request: direct command, supplied evidence, live exploration, or readiness gap.
2. Prefer supplied/CI evidence or existing repo scripts (run via Bash) before live browser operation.
3. Ask before starting dev servers, installing tools, persisting sessions, navigation, screenshots, or unsafe arbitrary browser code.
4. Collect Playwright evidence in order for the requested UI state: existing CI/script evidence; approved navigation to the requested state (plus approved interactions when needed); `browser_snapshot` (and `browser_find` when locating controls); focused console plus network list/detail; then a requested approved screenshot. Do not claim readiness from a generic page load. A scripted browser fan-out is only an observation aid; it does not replace the ordered evidence bundle or screenshot requirement. In headless or CI environments, use headless config or display servers (e.g., xvfb-run).
5. When evidence output is requested, first confirm an explicitly approved local evidence directory. Keep every artifact under `<approved-dir>/browser/<run-id>/`; reject traversal or absolute paths outside that root. Write `manifest.json` with `requested_state`, `url`, `snapshot_path`, `console_path`, `network_path`, `screenshot_path` (null unless requested and collected), and `cleanup_result`; record the requested UI state, accessibility snapshot, focused console evidence, network evidence, and cleanup result there.
6. Classify failures as product, harness/setup, environment, auth/session, external-service, flaky/timing, or tool-unavailable. For confirmed product failures needing repository-wide flow evidence, initialize an absent CodeGraph index and use it for that question; use Serena separately for exact source ownership.
7. Clean up browser state, artifacts, and lingering processes where applicable. Do not claim screenshot coverage when no screenshot was collected.

## Output format

Evidence path, browser result, artifacts/cleanup, and readiness impact.

## Rules

- Do not invent browser commands.
- Do not treat missing browser evidence as covered by non-browser tests.
- Do not claim browser readiness from a generic page load when the request needs a specific observable state.
- Do not store auth/session state under tracked paths.
- Route product failures to **b-debug**.
