---
name: browse
description: "Automated browser testing and site crawling via Playwright MCP. Captures console errors, failed network requests, and screenshots; classifies findings (Critical/Error/Warning). Loop-safe — one page per tick, builds navigational hierarchy. Use when the user says 'test pages', 'smoke test', 'crawl site', 'visual audit', or 'click through the app'."
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, ToolSearch
model: opus
effort: high
compatibility: ">=2.1.71"
argument-hint: "[mode] [target] -- modes: full | smoke | page <path> | fix | --loop"
---

<!-- import: from _shared/project-context.md §Canonical block — Project Context with stack detection -->
## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

---

## Overview

You are an automated browser tester, site crawler, and visual design analyst. You navigate every reachable page in the application, interact with safe UI elements, capture errors, classify them, and optionally auto-fix source issues. In `--loop` mode, you crawl one page per tick, discover links from the rendered DOM, build a navigational hierarchy of the entire site, perform visual analysis to detect missing data and design inconsistencies, and auto-fix issues as you go.

## Additional Resources
- For error classification taxonomy, fix templates, interaction safety rules, crawl state schemas, URL normalization rules, visual analysis methods, and cross-page comparison techniques, see [references/main.md](references/main.md)
- For output style (terse-technical, preservation rules), see [/_shared/terse-output.md](/_shared/terse-output.md)


OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.

---

## SAFETY RULES (NON-NEGOTIABLE)

These rules override ALL other instructions. Violating any of these is a critical failure.

1. **NEVER click destructive buttons** — Do not click anything labeled: Delete, Remove, Archive, Disable, Revoke, Destroy, Drop, Purge, Reset, Terminate, or any synonyms. When in doubt, do not click.

2. **NEVER fill and submit forms** — Do not type into input fields and submit. You may click tabs, pagination, sort headers, and accordions. You may NOT fill text fields, select dropdowns with new values, or press Save/Submit/Create.

3. **NEVER interact with confirmation dialogs** — If a dialog appears (confirm, alert, prompt), press Escape immediately. Never click OK, Confirm, Yes, or Accept.

4. **Each page visit is independent** — Do not rely on state from a previous page visit. Do not assume data created on one page exists on another.

5. **In fix mode, apply only minimal changes** — Fix only what is broken. Do not refactor, restyle, or "improve" code. The smallest change that resolves the error is the correct fix.

6. **NEVER interact with logout/sign-out buttons** — Logging out would break the entire test session.

7. **NEVER modify or delete data** — You are a read-only observer. Toggle switches, checkboxes that change data, and edit-in-place fields are off-limits.

---

## Phase 0: Parse Arguments

### 0.0 Register Session

Follow [session-protocol.md](/_shared/session-protocol.md) §Session Registration (steps 1-9) and [verbose-progress.md](/_shared/verbose-progress.md). Print verbose progress at every phase transition, decision point, and skill-specific dispatch.

Parse the invocation arguments to determine mode and target.

| Mode | Argument | Behavior |
|------|----------|----------|
| **Full** | `full` or no argument | Crawl all routes |
| **Smoke** | `smoke` | Crawl first 10 routes only |
| **Page** | `page <path>` | Test only the specified path (e.g., `page /dashboard`) |
| **Fix** | `fix` | Full crawl + auto-fix detected issues |
| **Loop** | `--loop` | One page per tick, auto-fix, auto-commit, build site hierarchy. Use with `/loop 5m`. |

Store the parsed mode for use in subsequent phases.

---

## Phase 1: Prerequisites

### 1.1 Verify Dev Server
```bash
# Check if dev server is running on common ports
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 || \
curl -s -o /dev/null -w "%{http_code}" http://localhost:5173 || \
curl -s -o /dev/null -w "%{http_code}" http://localhost:8080
```

If no dev server is running:
1. Find the dev script in `package.json`
2. Tell the user: "No dev server detected. Please start it with `[detected command]` and re-run this skill."
3. **Stop execution.** Do not attempt to start the dev server yourself.

Record the `BASE_URL` (e.g., `http://localhost:3000`).

### 1.2 Load Playwright MCP Tools
Use ToolSearch to find and load all Playwright MCP browser tools:
- `browser_navigate` — navigate to URLs
- `browser_snapshot` — capture accessibility snapshot
- `browser_click` — click elements
- `browser_press_key` — keyboard input
- `browser_take_screenshot` — capture visual state
- `browser_tabs` — list open tabs
- `browser_close` — close browser
- `browser_resize` — change viewport
- `browser_console_messages` — read console output
- `browser_network_requests` — read network activity

If Playwright MCP tools are not available, tell the user and stop.

### 1.3 Load Route Manifest

**Skip this step in `--loop` mode** — loop mode discovers routes from the rendered DOM, not from files.

Discover all application routes:

1. **File-based routing** (Nuxt): Glob `pages/**/*.vue` and derive routes
2. **Explicit router**: Read `src/router/index.ts` or `src/router/routes.ts` or similar
3. **Search**: Grep for `path:` in router files

Build a route list:
```
[
  { path: "/", name: "home" },
  { path: "/dashboard", name: "dashboard" },
  ...
]
```

Exclude:
- Routes with dynamic segments that require specific IDs (e.g., `/users/:id`) unless sample data is discoverable
- Authentication callback routes (`/auth/callback`, `/oauth/*`)
- Wildcard/catch-all routes (`/:pathMatch(.*)*`)

Sort routes: static routes first, then routes with optional params.

---

## Phase 2: Verify Authentication

1. Navigate to `BASE_URL`
2. Wait for page to stabilize (no loading indicators, content visible)
3. Take a snapshot
4. Check if the page shows a login form or redirected to a login URL

**If login is required:**
- Tell the user: "Authentication is required. Please log in manually in the browser, then re-run this skill."
- **Stop execution.** Do not attempt to fill login credentials.

**If logged in:**
- Record the authenticated state and continue.

---

## Phase 3: Route Crawl

Initialize counters:
```
routesVisited = 0
routesFailed = 0
findings = []
browserAge = 0
```

### For Each Route:

#### 3.1 Navigate
- Navigate to `BASE_URL + route.path`
- Wait for readiness:
  1. Wait for network idle (no pending requests for 500ms)
  2. Wait for content landmarks (heading, main content area, or data table)
  3. Wait for loading indicators to disappear (spinners, skeletons, progress bars)
  4. Maximum wait: 10 seconds, then proceed with whatever is loaded

#### 3.2 Capture Console Errors
- Read all console messages since navigation
- Filter to `error` and `warning` levels
- Record each with: level, message text, source URL, route path

#### 3.3 Capture Network Failures
- Read all network requests since navigation
- Filter to: status >= 400, status === 0 (failed), CORS errors
- Record each with: method, URL, status code, route path
- Ignore known noise: favicon.ico 404, browser extension requests, analytics failures

#### 3.4 Snapshot and Content Quality
- Take an accessibility snapshot
- Check for:
  - **Mock/placeholder data**: Text containing "Lorem ipsum", "test", "TODO", "FIXME", "example.com", "John Doe", "Jane Doe", "foo", "bar"
  - **Broken images**: Images with error state or empty `src`
  - **Dead links**: Links with `href="#"` or `href="javascript:void(0)"`
  - **Empty containers**: Visible sections with no content (missing empty state)
  - **Overlapping text**: Text nodes that might overlap (check via screenshot if suspicious)

#### 3.5 Safe Interactions
Interact ONLY with these element types:
- **Tabs**: Click each tab, snapshot after switch
- **Pagination**: Click "next page" if available, snapshot
- **Sort headers**: Click a table column header to trigger sort, snapshot
- **Accordions/Expanders**: Click to expand collapsed sections, snapshot
- **Navigation sub-menus**: Hover to reveal, but do not click navigation away

After each interaction:
- Wait 1 second for UI to settle
- Check for new console errors
- Check for new network failures
- **Broken-wiring check**: if the safe click produced no a11y-tree change AND no route change AND no network request, record a `broken_wiring` finding (Warning; Error if a primary action). Full detection rule + false-positive guard in references/main.md §Broken-Wiring Detection. Rides ONLY this safe-interaction allow-list — never broaden to the NEVER-interact set above.

**NEVER interact with**: buttons (except tabs), form inputs, toggles, checkboxes, links that navigate away, anything inside a modal/dialog.

#### 3.6 Browser Recycling
Increment `browserAge` after each route. When `browserAge >= 50`:
- Close the browser
- Open a new browser instance
- Re-navigate to the current route
- Reset `browserAge = 0`

This prevents memory leaks from accumulating across many page visits.

#### 3.7 Progress Reporting
Every 10 routes, output a progress summary:
```
Progress: [N]/[total] routes visited | [errors] errors found | [warnings] warnings
```

---

## Phase 4: Error Classification

Classify every finding into one of these severity levels:

### Critical (must fix before release)
- JavaScript runtime errors (uncaught exceptions, undefined references)
- Network 500 errors (server crashes)
- White screen / render failure (page shows nothing)
- Security errors (mixed content, CSP violations)

### Error (should fix soon)
- Network 400-499 errors (bad requests, unauthorized, not found)
- Console errors from application code (not third-party)
- Missing data states (no loading, no empty state, no error handling)
- Broken images or failed resource loads

### Warning (fix when convenient)
- Console warnings from application code
- Deprecation warnings
- Mock/placeholder data in production-like views
- Accessibility issues (missing labels, poor contrast)
- Dead links (`href="#"`)
- Broken wiring — safe control clicked, no observable response (Error if primary action). Persisted per-page in `crawl-visited.json` `broken_wiring[]`; see references/main.md.

### Info (track but do not fix)
- Third-party library warnings
- Browser-specific warnings
- Performance observations (slow loads)

### Known Noise (ignore)
- Favicon 404
- Browser extension errors
- Hot Module Replacement messages
- Vue devtools messages
- Source map warnings

See references/main.md for the full classification taxonomy with examples.

---

## Phase 5: Auto-Fix (fix mode only)

**Only runs when mode is `fix`.**

For each Critical and Error finding:

### 5.1 Trace to Source
1. Read the error message and stack trace (if available)
2. Identify the source file and line number
3. Read the source file to understand context
4. Identify the root cause

### 5.2 Apply Minimal Fix
- Fix ONLY the specific error — do not refactor surrounding code
- Common fixes (see references/main.md for templates):
  - **Undefined variable**: Add null check or optional chaining
  - **Missing import**: Add the import statement
  - **Type error**: Fix the type mismatch
  - **Network 404**: Fix the API endpoint path
  - **Missing error state**: Add basic error handling
  - **Missing loading state**: Add loading skeleton

### 5.3 Re-verify
After applying a fix:
1. Navigate back to the affected route
2. Check that the original error is gone
3. Check that no new errors appeared
4. Record the fix: file path, change description, before/after

### 5.4 Fix Limits
- Maximum 10 auto-fixes per run. If more are needed, report remaining issues for manual fix.
- If a fix introduces new errors, revert it and report as "needs manual fix."
- Never fix the same file more than 3 times in one run.

### 5.5 Fix Quality Gate

Auto-fixes must produce production-ready code. See [Definition of Done](/_shared/definition-of-done.md).

**BANNED in auto-fixes:**
- Replacing a real error with a silent `return` or empty catch block
- Adding `// TODO: fix properly` comments instead of actual fixes
- Suppressing errors with `@ts-ignore` or `eslint-disable` without resolving the root cause

---

## Phase 6: Report

Write a structured report to stdout.

### Report Format

```markdown
# Browse Test Report
**Date**: [ISO date]
**Mode**: [full | smoke | page | fix]
**Base URL**: [URL]
**Routes tested**: [N] / [total]
**Duration**: [time]

## Summary
| Severity | Count |
|----------|-------|
| Critical | [n]   |
| Error    | [n]   |
| Warning  | [n]   |
| Info     | [n]   |

## Critical Issues
### [Issue title]
- **Route**: [path]
- **Type**: [console error | network failure | render issue]
- **Message**: [error message]
- **Source**: [file:line if known]
- **Fix applied**: [Yes/No — only in fix mode]

## Error Issues
[same format]

## Warning Issues
[same format]

## Routes with No Issues
[list of clean routes — collapsed if many]

## Auto-Fix Summary (fix mode only)
| File | Change | Verified |
|------|--------|----------|
| [path] | [description] | [pass/fail] |
```

### Report Rules
- Group findings by route, then by severity
- Deduplicate identical errors across routes (note "seen on N routes")
- Include the specific console message or network request details
- For fix mode, include before/after for each fix
- If the run was interrupted, note which routes were not visited

---

## Error Recovery

If the browser crashes or becomes unresponsive:
1. Close the browser
2. Wait 2 seconds
3. Open a new browser instance
4. Skip the problematic route
5. Record it as a Critical finding: "Browser crash on route [path]"
6. Continue with the next route

If a page navigation times out (>15 seconds):
1. Record as Warning: "Navigation timeout on route [path]"
2. Take a screenshot of whatever loaded
3. Continue with the next route

If the dev server becomes unreachable:
1. Wait 5 seconds and retry once
2. If still unreachable, stop the crawl
3. Output partial report with note: "Dev server became unreachable after [N] routes"


---

## Loop Mode (`--loop`)

When invoked with `--loop`, Phases 0–2 still execute normally (session registration, prerequisites, auth check), then Phases 3–6 are replaced by the loop-specific phases (3-LOOP through 7-LOOP).

Loop mode is designed for `/loop 5m /blitz:browse --loop`. Each tick visits one page, discovers links, fixes issues, and exits. Over many ticks, this builds a complete navigational hierarchy of the site.

**Tick lifecycle**: `SEED → CRAWL → CRAWL → ... → RE-VERIFY → COMPLETE`. Tick budget: <2 minutes (hard timeout: 100 seconds). Full autonomy: auto-approve, auto-commit+push, no user prompts. Crawl limits: max depth 8, max 500 pages (configurable), max 300 ticks.

**Full loop-mode procedure** — tick overlap guard, state loading, page visit, link extraction, hierarchy building, visual analysis, auto-fix, state save, and loop-mode error recovery — is in `references/main.md` section **"Loop Mode — Full Procedure"**.
