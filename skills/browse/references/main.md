# Browse — Reference Material

## Error Classification Taxonomy

### Console Error Categories

| Category | Pattern | Severity | Example |
|----------|---------|----------|---------|
| **Uncaught Exception** | `Uncaught TypeError`, `Uncaught ReferenceError` | Critical | `Uncaught TypeError: Cannot read properties of undefined (reading 'map')` |
| **Unhandled Promise** | `Unhandled Promise Rejection` | Critical | `Unhandled Promise Rejection: NetworkError when attempting to fetch resource` |
| **Render Error** | `Failed to mount`, `render error`, `hydration mismatch` | Critical | `[Vue warn]: Failed to mount component: template or render function not defined` |
| **Chunk Load Failure** | `Loading chunk`, `Failed to fetch dynamically imported module` | Critical | `Error: Loading chunk vendors-node_modules_xxx failed` |
| **Security** | `Content Security Policy`, `Mixed Content`, `CORS` | Critical | `Refused to load the script because it violates the Content Security Policy` |
| **API Error** | Application-thrown errors from API calls | Error | `Error: Request failed with status code 403` |
| **Component Warning** | `[Vue warn]`, `Invalid prop`, `Missing required prop` | Error | `[Vue warn]: Invalid prop: type check failed for prop "items"` |
| **Missing Resource** | `404`, `Failed to load resource` | Error | `GET http://localhost:3000/api/users 404 (Not Found)` |
| **Deprecation** | `deprecated`, `will be removed` | Warning | `[Deprecation] The feature will be removed in a future version` |
| **Vue Dev Warning** | `[Vue devtools]`, `[HMR]`, `[vite]` | Known Noise | `[vite] hot updated: /src/components/Header.vue` |
| **Extension Error** | Chrome extension URLs, `chrome-extension://` | Known Noise | `Error in chrome-extension://xxx/content.js` |
| **Favicon** | `favicon.ico` | Known Noise | `GET http://localhost:3000/favicon.ico 404` |

### Network Failure Categories

| Status Range | Category | Severity | Typical Cause |
|-------------|----------|----------|---------------|
| **0** | Connection Failed | Critical | Server down, CORS blocked, network error |
| **500-599** | Server Error | Critical | Backend crash, unhandled exception |
| **401** | Unauthorized | Error | Token expired, auth misconfigured |
| **403** | Forbidden | Error | Insufficient permissions |
| **404** | Not Found | Error | Wrong endpoint URL, missing resource |
| **400** | Bad Request | Error | Malformed request, validation failure |
| **408** | Timeout | Warning | Slow backend, large payload |
| **429** | Rate Limited | Warning | Too many requests |
| **300-399** | Redirect | Info | Expected behavior, but note redirect chains |

### Content Quality Issues

| Issue | Detection Method | Severity |
|-------|-----------------|----------|
| **Placeholder text** | Regex match for "Lorem ipsum", "TODO", "FIXME", "example.com" | Warning |
| **Mock data** | Regex match for "John Doe", "Jane Doe", "foo@bar", "test@test" | Warning |
| **Broken images** | `<img>` with error event or empty/missing `src` | Error |
| **Dead links** | `href="#"`, `href="javascript:void(0)"`, `href=""` | Warning |
| **Empty data views** | Container visible but no content, no empty state message | Error |
| **Console.log left in** | `console.log` in production build output | Info |
| **Unstyled content** | Flash of unstyled content, missing CSS | Error |
| **Broken wiring** | Safe interactive control clicked, but no a11y-tree change AND no route change AND no network request (Phase 4.6 detection) | Warning (Error if primary action) |

---

## Error Recovery Procedures

### Browser Crash Recovery
```
1. Detect: Browser tool calls fail or timeout
2. Action: Close browser (browser_close)
3. Wait: 2 seconds
4. Action: Record finding — Critical: "Browser crash on [route]"
5. Action: Open new browser (browser_navigate to BASE_URL)
6. Verify: Page loads successfully
7. Continue: Resume crawl from next route
8. Note: If crash repeats on same route, skip permanently
```

### Navigation Timeout Recovery
```
1. Detect: Page not ready after 15 seconds
2. Action: Take screenshot of current state
3. Action: Record finding — Warning: "Navigation timeout on [route]"
4. Action: Check console for errors (may reveal cause)
5. Continue: Navigate to next route
6. Note: Timeout routes often indicate infinite loops or missing data
```

### Authentication Loss Recovery
```
1. Detect: Page redirects to login, or 401 responses appear
2. Action: Record finding — Critical: "Authentication lost at [route]"
3. Action: Stop crawl
4. Report: Output partial report
5. Instruct user: "Session expired. Please re-authenticate and re-run."
```

### Dev Server Unreachable Recovery
```
1. Detect: Navigation fails with connection refused
2. Action: Wait 5 seconds
3. Retry: Attempt navigation once more
4. If still failing: Stop crawl
5. Report: Output partial report with note
6. Instruct user: "Dev server appears to have stopped."
```

### Memory Pressure Recovery
```
1. Detect: Browser becomes sluggish, pages take >10s to load
2. Action: Close browser immediately
3. Action: Open new browser instance
4. Continue: Resume from current route
5. Reduce: Lower browser recycling threshold to every 25 routes
```

---

## Auto-Fix Templates

### Undefined Property Access
**Error**: `Cannot read properties of undefined (reading 'xxx')`
**Fix**: Add optional chaining
```typescript
// Before
const value = obj.nested.property

// After
const value = obj?.nested?.property
```

### Missing Null Check in Template
**Error**: `Cannot read properties of null (reading 'length')`
**Fix**: Add v-if guard or fallback
```vue
<!-- Before -->
<div>{{ items.length }} items</div>

<!-- After -->
<div>{{ items?.length ?? 0 }} items</div>
```

### Missing Import
**Error**: `xxx is not defined`
**Fix**: Add the missing import statement
```typescript
// Add to top of <script setup>
import { xxx } from '@/path/to/module'
```

### Wrong API Endpoint (404)
**Error**: `GET /api/old-endpoint 404`
**Fix**: Update the endpoint URL
```typescript
// Before
const response = await api.get('/api/old-endpoint')

// After
const response = await api.get('/api/correct-endpoint')
```

### Missing Error State
**Error**: Component shows blank when API fails
**Fix**: Add error handling to the template
```vue
<!-- Add after the loading check -->
<div v-else-if="error" class="error-state">
  <p>Failed to load data. Please try again.</p>
</div>
```

### Missing Loading State
**Error**: Component shows flash of empty content before data loads
**Fix**: Add loading guard
```vue
<!-- Add before the data display -->
<template v-if="loading">
  <!-- Use project's skeleton pattern -->
</template>
```

### Unhandled Promise Rejection
**Error**: `Unhandled Promise Rejection` in async function
**Fix**: Add try-catch
```typescript
// Before
const data = await fetchData()

// After
try {
  const data = await fetchData()
} catch (error) {
  console.error('Failed to fetch data:', error)
  // Set error state
}
```

### Missing Reactive Reference
**Error**: `xxx is not defined` in template, but variable exists in setup
**Fix**: Ensure the variable is returned or defined with ref/reactive
```typescript
// Before
let count = 0

// After
const count = ref(0)
```

### CORS Error
**Error**: `Access to fetch has been blocked by CORS policy`
**Fix**: This is a server-side fix. Record as "needs manual fix" with instruction:
```
Server needs to add CORS headers for the requesting origin.
Check: vite.config proxy, server CORS middleware, or API gateway config.
```

### Dynamic Import Failure
**Error**: `Failed to fetch dynamically imported module`
**Fix**: Add error handling to dynamic import
```typescript
// Before
const Component = defineAsyncComponent(() => import('./Component.vue'))

// After
const Component = defineAsyncComponent({
  loader: () => import('./Component.vue'),
  errorComponent: ErrorFallback,
  timeout: 10000,
})
```

---

## Report Template Structure

```markdown
# Browse Test Report

**Date**: YYYY-MM-DD HH:mm
**Mode**: [full | smoke | page <path> | fix]
**Base URL**: [http://localhost:XXXX]
**Routes discovered**: [N total]
**Routes tested**: [N tested] / [N total]
**Routes skipped**: [N skipped] (dynamic params, auth callbacks, etc.)
**Duration**: [Xm Ys]

---

## Summary

| Severity | Count | Auto-fixed |
|----------|-------|------------|
| Critical | X     | X          |
| Error    | X     | X          |
| Warning  | X     | —          |
| Info     | X     | —          |

**Overall health**: [PASS | WARN | FAIL]
- PASS: 0 Critical, 0 Error
- WARN: 0 Critical, 1+ Error or 5+ Warning
- FAIL: 1+ Critical

---

## Critical Issues

### [Short description]
- **Route(s)**: `/path` (also seen on: `/other`, `/another` — N total)
- **Category**: [Console Error | Network Failure | Render Issue | Security]
- **Details**: [Full error message]
- **Stack trace** (if available):
  ```
  [stack trace, truncated to relevant frames]
  ```
- **Source file**: `src/path/to/file.ts:123` (if identifiable)
- **Auto-fix**: [Applied — description | Not attempted | Failed — reason]

---

## Error Issues

[Same format as Critical, grouped by route]

---

## Warning Issues

[Same format, collapsed if many]

---

## Broken Wiring

Safe interactive controls that rendered but produced no observable response when clicked (no a11y-tree change, no route change, no network request). Deduplicated across routes ("seen on N routes"). `Error` severity instead of `Warning` when the inert control is a primary page action.

| Route | Element | Selector | Severity |
|-------|---------|----------|----------|
| [path] | [label] | [selector] | [Warning\|Error] |

---

## Info / Observations

- [Observation 1]
- [Observation 2]

---

## Clean Routes

<details>
<summary>[N] routes with no issues</summary>

- `/route1`
- `/route2`
- ...

</details>

---

## Auto-Fix Summary (fix mode only)

| # | File | Change | Lines Modified | Verified |
|---|------|--------|---------------|----------|
| 1 | `src/path/file.ts` | Added optional chaining for user.name | 1 | PASS |
| 2 | `src/path/other.vue` | Added error state template | 5 | PASS |
| 3 | `src/path/api.ts` | Fixed endpoint URL | 1 | FAIL — new 403 |

### Fixes Not Attempted
| Issue | Reason |
|-------|--------|
| CORS error on /api/external | Server-side fix required |
| Missing env variable | Configuration issue, not a code fix |

---

## Recommendations

1. [Highest priority recommendation]
2. [Second priority recommendation]
3. [Third priority recommendation]

---

## Test Environment

- **Framework**: [detected framework]
- **UI Framework**: [detected UI framework]
- **Browser**: Chromium (Playwright)
- **Viewport**: 1440x900 (desktop default)
```

---

## Safe Interaction Catalog

### Always Safe (interact freely)
| Element | Action | Condition |
|---------|--------|-----------|
| Tab buttons | Click | Part of a tab group (`role="tab"`) |
| Pagination controls | Click next/prev | Numbered pagination or next/prev buttons |
| Table sort headers | Click | Column headers with sort indicators |
| Accordions | Click to expand | Expand/collapse toggles |
| Breadcrumbs | Click | Navigation breadcrumb links within the app |
| Sidebar sections | Click to expand | Collapsible sidebar groups |
| "Show more" buttons | Click | Expands content without navigation |

### Conditionally Safe (interact with caution)
| Element | Action | Condition |
|---------|--------|-----------|
| Navigation links | Click | Only if target is in the route manifest |
| Dropdown menus | Open | Click to open, but do NOT select items that modify data |
| Search inputs | Type | Only in filter/search contexts, not create forms |
| View toggle (grid/list) | Click | Switches display mode only |

### Never Safe (do not interact)
| Element | Reason |
|---------|--------|
| Delete / Remove buttons | Destructive |
| Save / Submit / Create buttons | Data mutation |
| Form inputs (in create/edit contexts) | Data mutation |
| Toggle switches | Data mutation |
| Checkboxes (in data contexts) | Data mutation |
| Confirmation dialog buttons | May trigger destructive action |
| Logout / Sign out | Breaks session |
| Settings that persist | Data mutation |
| Import / Upload buttons | Data mutation |
| Approve / Reject buttons | Data mutation |

---

## Loop Mode — Crawl State Schemas

### `docs/crawls/crawl-queue.json`

Tracks pages discovered but not yet visited, plus URL pattern dedup.

```json
{
  "base_url": "http://localhost:3000",
  "queue": [
    {
      "url": "/dashboard",
      "parent": "/",
      "nav_context": "nav",
      "priority": 8.5,
      "depth": 1,
      "discovered_tick": 1
    }
  ],
  "url_patterns_seen": ["/users/:id", "/projects/:uuid"],
  "tick_count": 14,
  "started_at": "2026-03-27T04:15:00Z"
}
```

**Fields:**
- `base_url`: Dev server origin (e.g., `http://localhost:3000`)
- `queue[]`: Ordered pages to visit. Sorted by `priority` descending at read time.
- `queue[].url`: Relative path (e.g., `/dashboard/analytics`)
- `queue[].parent`: Page URL where link was discovered
- `queue[].nav_context`: Where link found: `root`, `nav`, `sidebar`, `content`, `footer`
- `queue[].priority`: Computed score: `(10 - depth) × context_multiplier`
- `queue[].depth`: Clicks from root to reach page
- `queue[].discovered_tick`: Tick that found link
- `url_patterns_seen[]`: Normalized URL patterns for dedup (e.g., `/users/:id`)
- `tick_count`: Total ticks executed
- `started_at`: ISO-8601 timestamp of first tick

### `docs/crawls/crawl-visited.json`

Tracks pages already crawled and their status.

```json
{
  "pages": {
    "/": {
      "title": "Home",
      "visited_tick": 1,
      "visited_at": "2026-03-27T04:20:00Z",
      "status": "clean",
      "links_found": 12,
      "findings_count": 0,
      "fixes_applied": 0
    },
    "/dashboard": {
      "title": "Dashboard",
      "visited_tick": 2,
      "visited_at": "2026-03-27T04:25:00Z",
      "status": "has_issues",
      "links_found": 8,
      "findings_count": 3,
      "fixes_applied": 1,
      "interaction_coverage": {
        "safe_clicks": 3,
        "broken_wiring_checked": true,
        "responsive_checked": false
      },
      "broken_wiring": [
        { "element": "Sort by date", "selector": "th[data-sort=date]", "route": "/dashboard" }
      ]
    }
  }
}
```

**Status values:**
- `clean` — No issues found
- `has_issues` — Issues found, some may be unfixed
- `fixed` — Had issues, all were auto-fixed
- `needs_re_verify` — A shared file was modified by a fix; this page imports that file and needs re-checking
- `unreachable` — Navigation failed 3+ times
- `re-verified` — Re-checked after fixes, now clean

**Per-page interaction fields (additive — pre-existing readers unaffected):**
- `interaction_coverage` — `{ safe_clicks: int (count of allow-listed clicks exercised), broken_wiring_checked: bool, responsive_checked: bool }`. Records what Phase 4.6 exercised on the page.
- `broken_wiring` — array of `{ element, selector, route }` from Phase 4.6 broken-wiring detection; empty array when none found.
- `responsive_checked` defaults `false`; reserved for the opt-in `--interaction-depth=full` responsive pass (not enabled by default — forward-compat placeholder).

### `docs/crawls/hierarchy.json`

Navigational graph as adjacency list. Each node = one page. Web is directed graph, not tree — `/settings` may be linked from global nav and `/dashboard/preferences`. `discovered_from` determines display tree position; `also_linked_from` preserves full link graph.

```json
{
  "nodes": {
    "/": {
      "title": "Home",
      "depth": 0,
      "discovered_from": null,
      "also_linked_from": [],
      "children": ["/dashboard", "/settings", "/users"],
      "nav_context": "root",
      "external_links": ["https://docs.example.com"]
    },
    "/dashboard": {
      "title": "Dashboard",
      "depth": 1,
      "discovered_from": "/",
      "also_linked_from": ["/settings"],
      "children": ["/dashboard/analytics", "/dashboard/reports"],
      "nav_context": "nav",
      "external_links": []
    }
  }
}
```

**Fields:**
- `nodes{}`: Keyed by relative URL path
- `title`: Page title from `<title>` or first `<h1>`
- `depth`: Distance from root (0 for `/`). Based on `discovered_from` chain, not shortest path.
- `discovered_from`: URL of page that first linked here (null for root). Determines position in display tree.
- `also_linked_from[]`: Other pages that also link here. Preserves full link graph for navigation analysis.
- `children[]`: Internal URLs discovered on this page
- `nav_context`: Where this page's link appeared on parent
- `external_links[]`: External URLs found (informational only)

### `docs/crawls/crawl-ledger.jsonl`

Append-only JSONL findings log. One finding per line.

```jsonl
{"id":"console-err-/dashboard-TypeError-abc123","page":"/dashboard","type":"console_error","severity":"critical","category":"Uncaught Exception","message":"Uncaught TypeError: Cannot read properties of undefined","source_file":"src/pages/dashboard.vue:42","status":"found","found_tick":2,"fixed_tick":null}
{"id":"network-404-/dashboard-api-users","page":"/dashboard","type":"network_failure","severity":"error","category":"Not Found","message":"GET /api/users 404","source_file":null,"status":"fixed","found_tick":2,"fixed_tick":2}
```

**Fields:**
- `id`: Dedup key: `{type}-{page}-{short_hash}`
- `page`: Route where issue was found
- `type`: `console_error`, `console_warning`, `network_failure`, `content_quality`, `render_issue`
- `severity`: `critical`, `error`, `warning`, `info`
- `category`: From Error Classification Taxonomy (above)
- `message`: Full error message
- `source_file`: Source file:line if identifiable
- `status`: `found`, `fixed`, `needs-human`, `wontfix`, `noise`
- `found_tick`: Tick when discovered
- `fixed_tick`: Tick when fixed (null if not fixed)

### `docs/crawls/fix-log.jsonl`

Append-only log of fix attempts.

```jsonl
{"tick":2,"page":"/dashboard","finding_id":"network-404-/dashboard-api-users","file":"src/api/users.ts","change":"Fixed API endpoint from /api/users to /api/v2/users","verified":true,"commit":"abc1234"}
{"tick":5,"page":"/settings","finding_id":"console-err-/settings-ref","file":"src/pages/settings.vue","change":"Added optional chaining for user.preferences","verified":false,"reverted":true,"reason":"Typecheck failed: TS2532"}
```

### `docs/crawls/latest-tick.json`

Snapshot of the most recent tick for quick status checks.

```json
{
  "tick": 14,
  "page_visited": "/settings/profile",
  "pages_visited_total": 14,
  "pages_queued": 23,
  "findings_total": 7,
  "fixes_applied": 3,
  "fixes_failed": 1,
  "hierarchy_depth": 3,
  "status": "crawling",
  "circuit_breaker_cooldown": 0,
  "consecutive_fix_failures": 0,
  "page_data_registry": null,
  "updated_at": "2026-03-27T05:25:00Z"
}
```

**Status values:**
- `crawling` — Normal operation, queue has entries
- `re-verifying` — Queue empty, re-checking pages with issues
- `complete` — All pages visited and clean
- `auth_lost` — Authentication expired, needs user intervention
- `server_down` — Dev server unreachable

**Field `page_data_registry`:** path string to `docs/crawls/page-data-registry.jsonl` if `blitz:ui-audit` has run in this project, else `null`. Browse does not read or write this field — `blitz:ui-audit` owns it. Present here so overlap detection (ui-audit × browse-loop) can observe prior extraction state in one read.

---

## Loop Mode — URL Normalization Rules

### Dynamic Segment Patterns

When new URL found, normalize to pattern for dedup:

| Pattern | Regex | Replacement | Example |
|---------|-------|-------------|---------|
| UUID | `/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/i` | `:uuid` | `/users/550e8400-e29b-41d4-a716-446655440000` → `/users/:uuid` |
| Numeric ID | Path segment matching `/^\d+$/` | `:id` | `/users/123` → `/users/:id` |
| Date | `/\d{4}-\d{2}-\d{2}/` | `:date` | `/reports/2026-03-27` → `/reports/:date` |
| Firestore ID | Path segment matching `/^[A-Za-z0-9]{20,}$/` | `:docid` | `/docs/abc123def456ghi789jk` → `/docs/:docid` |
| Slug with ID | `/[a-z-]+-\d+$/` | `:slug` | `/posts/my-post-123` → `/posts/:slug` |

### Normalization Steps (in order)

1. Parse URL, resolve relative paths against `BASE_URL`
2. Decode percent-encoded characters (`%20` → space, `%C3%A9` → `é`) before comparison
3. Extract pathname only (discard origin, query, fragment)
4. **Hash routing check**: if app uses hash-based routing (`/#/page`), treat hash as pathname. Detect if `BASE_URL` contains `/#/` or root page has `#/` in links.
5. Remove trailing slash (except for root `/`)
6. Apply dynamic segment patterns to each path segment
7. Compare normalized pattern against `url_patterns_seen[]`
8. If pattern seen → skip. If new → add to `url_patterns_seen[]` and enqueue.

### Edge Cases

| Case | Handling |
|------|----------|
| **Percent-encoded characters** | Decode before dedup: `/users/john%20doe` and `/users/john doe` are the same |
| **Case sensitivity** | Treat paths as case-sensitive (Linux servers are case-sensitive). `/Dashboard` ≠ `/dashboard` |
| **Hash routing (`/#/`)** | If app uses hash routing, extract path from hash: `/#/dashboard` → `/dashboard` |
| **Section anchors (`#section`)** | Strip: `/page#section` → `/page` |
| **Protocol-relative URLs** | `//example.com/page` → treat as external (different origin) |
| **Base path prefix** | If app is served at `/app/`, normalize: `/app/dashboard` → `/dashboard` (strip base path) |
| **Redirect chains** | If navigation results in URL change (redirect), record BOTH the original and final URL in visited. Use the final URL as the canonical. |
| **Query strings with semantic meaning** | Strip all query params by default. If you observe that `/page?tab=settings` loads entirely different content than `/page`, note it in findings as an observation but still strip. |

### Filter Rules (never enqueue)

| Rule | Pattern |
|------|---------|
| External origin | `new URL(href).origin !== new URL(BASE_URL).origin` |
| Non-HTTP scheme | `mailto:`, `tel:`, `javascript:`, `data:`, `blob:` |
| Auth paths | `/auth/*`, `/oauth/*`, `/login`, `/logout`, `/callback`, `/signup`, `/register`, `/forgot-password`, `/reset-password` |
| File downloads | Ends with: `.pdf`, `.zip`, `.csv`, `.xlsx`, `.doc`, `.docx`, `.png`, `.jpg`, `.jpeg`, `.gif`, `.svg`, `.webp`, `.mp4`, `.mp3` |
| Already visited | Exact URL exists in `crawl-visited.json` |
| Already queued | Exact URL exists in `crawl-queue.json` queue |
| Pattern seen | Normalized pattern exists in `url_patterns_seen[]` |
| API endpoints | Starts with `/api/`, `/_/`, `/__/` |
| Static assets | Starts with `/_nuxt/`, `/static/`, `/assets/`, `/public/` |

---

## Loop Mode — Navigation Context Classification

When extracting links, classify each by DOM context to prioritize navigation-critical pages.

### Detection Method

For each `<a>` element, check ancestor chain:

| Context | Detection | Priority Multiplier |
|---------|-----------|-------------------|
| **nav** | Inside `<nav>`, `<header>`, `[role="navigation"]`, `.navbar`, `.nav-menu` | ×2.0 |
| **sidebar** | Inside `<aside>`, `[role="complementary"]`, `.sidebar`, `.side-nav`, `.drawer` | ×1.5 |
| **content** | Inside `<main>`, `[role="main"]`, `.content`, or none of the above | ×1.0 |
| **footer** | Inside `<footer>`, `.footer` | ×0.5 |

**Priority formula**: `(10 - depth) × context_multiplier`

Where `depth` = current page's depth + 1 (new link is one level deeper).

### Examples

| Link Location | Depth | Priority |
|--------------|-------|----------|
| Root page nav link → `/dashboard` | 1 | (10-1) × 2.0 = **18.0** |
| Dashboard sidebar → `/dashboard/analytics` | 2 | (10-2) × 1.5 = **12.0** |
| Content area link → `/blog/post-1` | 2 | (10-2) × 1.0 = **8.0** |
| Footer link → `/privacy` | 1 | (10-1) × 0.5 = **4.5** |

---

## Loop Mode — Tick Budget Breakdown

Target: < 2 minutes per tick.

| Step | Estimated Time | Notes |
|------|---------------|-------|
| Load state files | 1–2s | Read 6 JSON/JSONL files |
| Navigate to page | 3–5s | Including DNS, TLS, initial load |
| Wait for full load | 5–15s | Network idle + content landmarks + deferred rendering |
| Capture errors | 2–3s | Console messages + network requests |
| Snapshot + quality | 3–5s | Accessibility tree + content checks |
| Safe interactions | 10–20s | Tabs, pagination, accordions (varies by page) |
| Extract links | 2–3s | Parse snapshot or evaluate script |
| Auto-fix (0–2 fixes) | 0–60s | Read source, edit, verify, commit |
| Save state | 1–2s | Write 6 files |
| **Total** | **27–115s** | Well within 2-minute target |

---

## Loop Mode — Completion Criteria

Crawl is **complete** when ALL true:

1. `crawl-queue.json` queue empty (no more pages to visit)
2. All pages in `crawl-visited.json` re-verified (status `clean`, `fixed`, or `re-verified`)
3. OR: 3 consecutive ticks discovered zero new links and queue remains empty

After completion:
- Run cross-page visual audit (Phase 7.4)
- Set `latest-tick.json` status to `"complete"`
- Print full site map tree
- Generate final report summarizing findings, fixes, visual audit, hierarchy
- Subsequent ticks detect `complete` status and exit with: `[browse] Crawl already complete. To re-crawl, delete docs/crawls/ and re-run.`

---

## Loop Mode — Visual Analysis

### Structural Metadata Schema

Extracted from accessibility snapshot every tick. Stored in `crawl-visited.json` under each page's `"structure"` field.

```json
{
  "has_breadcrumbs": true,
  "has_pagination": false,
  "has_sidebar": true,
  "has_search": false,
  "has_footer": true,
  "card_count": 4,
  "table_row_count": 0,
  "image_count": 3,
  "broken_image_count": 0,
  "heading_levels": ["h1", "h2"],
  "nav_item_count": 7,
  "loading_indicators_present": false,
  "empty_containers": 0,
  "content_density": "low|medium|high"
}
```

**Detection methods from accessibility snapshot:**

| Field | How to Detect |
|-------|--------------|
| `has_breadcrumbs` | Look for `nav` with `aria-label="breadcrumb"` or element containing `>` separators with hierarchical links |
| `has_pagination` | Look for `nav` with `aria-label="pagination"` or elements with "Previous"/"Next" + page numbers |
| `has_sidebar` | Look for `aside`, `[role="complementary"]`, or element with sidebar/drawer class names |
| `has_search` | Look for `input[type="search"]`, `[role="search"]`, or input with placeholder containing "search" |
| `has_footer` | Look for `footer` element or `[role="contentinfo"]` |
| `card_count` | Count elements with card/panel-like structure (distinct bordered/shadowed containers) |
| `table_row_count` | Count `tr` elements inside `tbody` (0 = empty table) |
| `image_count` | Count `img` elements in content area (exclude nav icons, favicons) |
| `broken_image_count` | Count `img` with `alt` containing "error" or missing `src`, or with explicit error state |
| `heading_levels` | Collect unique heading levels (`h1`-`h6`) present on the page |
| `nav_item_count` | Count link elements inside the primary `nav` |
| `loading_indicators_present` | Check for: `[aria-busy="true"]`, elements with "loading"/"spinner"/"skeleton" in class/role, progress bars |
| `empty_containers` | Count visible containers (has a heading or label) with no child content and no "empty state" message |
| `content_density` | Estimate based on total text node count: <20 text nodes = `low`, 20-100 = `medium`, >100 = `high` |

### Visual Finding Types

Visual findings use `type: "visual"` in the crawl ledger. Subcategories:

| Subcategory | Severity | Description | Auto-fixable |
|-------------|----------|-------------|-------------|
| `visual_data_missing` | Warning | Page appears to have incomplete or missing data (empty table, chart with no data, sparse content) | No |
| `visual_loading_stuck` | Error | Loading state that didn't resolve (stuck spinner, unresolving skeleton) | No |
| `visual_layout_broken` | Error | Layout/overflow/overlap issue visible in screenshot | Sometimes — check for missing CSS class or container overflow |
| `visual_design_inconsistency` | Warning | Page is inconsistent with established patterns across the site | No |
| `visual_empty_state` | Warning | Content area is blank with no empty-state message for the user | Sometimes — can add a basic empty-state template |

### Screenshot Safety Rules

Screenshots are powerful but expensive. Follow strictly:

1. **Resize browser to 1280×720** before every screenshot — prevents oversized images that crash session
2. **Viewport-only screenshots** — NEVER full-page. Long pages can exceed 8000px height, causing unrecoverable API errors
3. **One screenshot per tick maximum** — each costs ~1,600 tokens; multiple fill context rapidly
4. **PNG format preferred** — lossless, sharper text for analysis
5. **Conditional triggers only** — do NOT screenshot every page. Only when structural analysis flags anomaly or every 10th tick.
6. **Disable animations before capture** — inject CSS `* { animation: none !important; transition: none !important; }` via `browser_evaluate` before screenshot to avoid partial animation frames

### Cross-Page Comparison: Anomaly Detection

After 10+ pages visited, structural metadata enables pattern-based anomaly detection without screenshots:

**Global element detection** (identify elements present on 80%+ of pages):
```
For each boolean field (has_breadcrumbs, has_pagination, has_sidebar, has_search, has_footer):
  count = pages where field is true
  percentage = count / total_pages
  if percentage >= 0.8:
    mark as "global element"

For each page missing a global element:
  finding: visual_design_inconsistency
  message: "[element] missing — present on [count]/[total] other pages"
```

**Sibling comparison** (compare pages at same hierarchy depth or sharing a parent):
```
For pages sharing the same parent (e.g., all children of /dashboard):
  Compute: median card_count, median table_row_count, median content_density

  For each page in the group:
    if table_row_count == 0 AND median > 5:
      finding: visual_data_missing — "Table has 0 rows (siblings median: [N])"
    if content_density == "low" AND median_density in ["medium", "high"]:
      finding: visual_data_missing — "Low content density (siblings: [density])"
    if card_count == 0 AND median_card_count > 0:
      finding: visual_design_inconsistency — "No cards found (siblings have [N] cards)"
```

**Heading hierarchy check** (global consistency):
```
Compute most common heading pattern: e.g., most pages use [h1, h2, h3]

For each page:
  if page uses h3 as top-level heading but most pages use h1:
    finding: visual_design_inconsistency — "Top heading is h3 (expected h1)"
  if page skips heading levels (h1 → h3, no h2):
    finding: visual_design_inconsistency — "Heading levels skip h2"
```

### Cross-Page Visual Audit Prompt Template (COMPLETE phase)

Used when taking screenshots of page groups for final comparison:

```
You are analyzing [N] pages from the [section] section of a Vue/Nuxt application.
Each screenshot is labeled with its URL path.

Analyze these pages TOGETHER for the following:

1. DESIGN CONSISTENCY
   - Do all pages use the same layout structure (sidebar, header, content area)?
   - Are headings, fonts, and spacing consistent?
   - Are colors and component styles consistent?
   - Are buttons, cards, tables styled the same way?

2. MISSING ELEMENTS
   - Are navigation elements (breadcrumbs, sidebar, header) present on all pages?
   - Does any page lack pagination, search, or filters that siblings have?
   - Are empty states handled consistently (or are some pages just blank)?

3. DATA COMPLETENESS
   - Do any pages appear to have missing or incomplete data?
   - Are there empty tables, charts with no data, or sparse cards?
   - Do all pages with images have proper images (no broken/placeholder icons)?

4. LAYOUT QUALITY
   - Any overlapping text or elements?
   - Content overflowing containers?
   - Inconsistent alignment or grid structure?
   - Responsive issues visible (if viewport is not desktop)?

For each issue found, return:
- Page URL
- Issue category (consistency/missing/data/layout)
- Specific description
- Severity (error/warning)
```

---

## Loop Mode — Full Procedure (extracted from SKILL.md in v1.4.1)

---

## Loop Mode (`--loop`)

**When mode is `--loop`, Phases 0–2 still execute normally (session registration, prerequisites, auth check), then skip Phases 3–6 and execute these loop-specific phases instead.**

Loop mode designed for `/loop 5m /blitz:browse --loop`. Each tick visits one page, discovers links, fixes issues, exits. Over many ticks, builds complete navigational hierarchy of site.

**Tick lifecycle**: `SEED → CRAWL → CRAWL → ... → RE-VERIFY → COMPLETE`

**Tick budget**: < 2 minutes per tick (hard timeout: 100 seconds). 5-minute loop interval provides buffer. If any phase exceeds remaining time, skip to Phase 7-LOOP (Save State) and exit gracefully.

**Autonomy**: Full. Auto-approve all, auto-commit+push, no user prompts.

**Crawl limits** (prevent crawler traps):
- **Max depth**: 8 levels from root. Deeper pages not enqueued.
- **Max pages**: 500 total. Override with `docs/crawls/.crawl-config.json` → `{ "max_pages": 1000 }`.
- **Max ticks**: 300 (25 hours at 5-min intervals). After, complete regardless of queue.

**Browser lifecycle**: Playwright MCP browser may or may not persist between ticks — each tick must NOT assume browser state from previous tick. Always start with `browser_navigate` to target page. Auth state (cookies, localStorage) managed by MCP server; if auth lost, recovery procedure handles it.

---

### Phase 3-LOOP: Load Crawl State

#### 3.0 Tick Overlap Guard
Before loading state, check for concurrent ticks:
1. Read `docs/crawls/latest-tick.json` (if exists)
2. If `updated_at` less than 2 minutes ago → another tick likely still running. Exit with: `[browse] Tick overlap detected. Previous tick updated ${seconds}s ago. Skipping.`
3. If `status` is `"auth_lost"` → exit with: `[browse] Auth lost. Please re-authenticate and delete docs/crawls/latest-tick.json to resume.`
4. If `status` is `"complete"` → exit with: `[browse] Crawl complete. To re-crawl, delete docs/crawls/ and re-run.`
5. If `status` is `"server_down"` → proceed (will retry server connection)

#### 3.1 Load or Initialize State
1. Check if `docs/crawls/crawl-queue.json` exists.
2. **If NOT exists** (first tick / SEED):
   - Create `docs/crawls/` directory
   - Initialize `crawl-queue.json` with root URL `/` as only entry:
     ```json
     {
       "base_url": "<BASE_URL>",
       "queue": [
         { "url": "/", "parent": null, "nav_context": "root", "priority": 10, "depth": 0, "discovered_tick": 0 }
       ],
       "url_patterns_seen": [],
       "tick_count": 0,
       "started_at": "<ISO-8601>"
     }
     ```
   - Initialize empty `crawl-visited.json`, `hierarchy.json`, `crawl-ledger.jsonl`, `fix-log.jsonl`, `latest-tick.json`
3. **If exists** (subsequent tick):
   - Load all state files from `docs/crawls/`
   - If any JSON fails to parse: rename to `.bak`, log warning, attempt reconstruction from `crawl-ledger.jsonl` (append-only, most reliable). If reconstruction fails, re-seed from scratch.
   - Increment `tick_count`
   - Check crawl limits: if `tick_count > max_ticks` or visited pages > `max_pages`, set tick type to COMPLETE.
4. **Determine tick type**:
   - `SEED` — first tick, queue just initialized
   - `CRAWL` — queue has entries
   - `RE-VERIFY` — queue empty, but `crawl-visited.json` has pages with `status: "has_issues"` not yet re-verified
   - `COMPLETE` — queue empty AND all pages clean or re-verified. Print final site map and exit.

See references/main.md for full state file schemas.

---

### Phase 4-LOOP: Visit One Page

#### 4.1 Pop Next Page
- Sort queue by `priority` (descending)
- Pop the highest-priority entry
- In RE-VERIFY mode: instead pop first page with `status: "has_issues"` from `crawl-visited.json`

#### 4.2 Navigate
- Navigate to `BASE_URL + page.url`
- **Wait for full page load** — critical, page must be fully rendered:
  1. Wait for network idle (no pending requests for 2 seconds)
  2. Wait for content landmarks (heading, main content area, or data table visible)
  3. Wait for loading indicators to disappear (spinners, skeletons, progress bars, `[aria-busy="true"]`)
  4. Maximum wait: 15 seconds, then proceed with whatever loaded
  5. After wait, pause additional 2 seconds for deferred rendering (lazy-loaded images, intersection observers)

#### 4.3 Capture Console Errors
- Read all console messages since navigation
- Filter to `error` and `warning` levels
- Record each with: level, message text, source URL, page path

#### 4.4 Capture Network Failures
- Read all network requests since navigation
- Filter to: status >= 400, status === 0 (failed), CORS errors
- Record each with: method, URL, status code, page path
- Ignore known noise: favicon.ico 404, browser extension requests, analytics failures

#### 4.5 Snapshot, Content Quality, and Structural Metadata
- Take accessibility snapshot
- **Content quality checks:**
  - **Mock/placeholder data**: Text containing "Lorem ipsum", "TODO", "FIXME", "example.com", "John Doe", "Jane Doe"
  - **Broken images**: Images with error state or empty `src`
  - **Dead links**: Links with `href="#"` or `href="javascript:void(0)"`
  - **Empty containers**: Visible sections with no content (missing empty state)

- **Extract structural metadata** from snapshot (see references/main.md for full schema). Record for each page:
  - `has_breadcrumbs`, `has_pagination`, `has_sidebar`, `has_search`, `has_footer`
  - `card_count`, `table_row_count`, `image_count`, `broken_image_count`
  - `heading_levels` (which h1-h6 present)
  - `nav_item_count` (items in primary nav)
  - `loading_indicators_present` (spinners, skeletons, `[aria-busy="true"]` still visible)
  - `empty_containers` (sections with no content and no empty-state message)
  - `content_density` — rough estimate: `low` (mostly whitespace), `medium`, `high`

  Store metadata in `crawl-visited.json` under page entry as `"structure": {...}`. Enables cross-page comparison after enough pages visited (see Phase 5.6).

#### 4.6 Safe Interactions
Same rules as Phase 3.5 in non-loop mode. Interact ONLY with:
- **Tabs**: Click each tab, snapshot after switch
- **Pagination**: Click "next page" if available, snapshot
- **Sort headers**: Click table column header, snapshot
- **Accordions/Expanders**: Click to expand, snapshot

After each interaction:
- Wait 1 second for UI to settle
- Check for new console errors and network failures
- **Re-snapshot** — interactions (especially tabs) often reveal new content with new links. Collect links from each post-interaction snapshot for Phase 5-LOOP.
- **Broken-wiring check** (below) — record a `broken_wiring` finding if the click produced no observable response.

**NEVER interact with**: buttons (except tabs), form inputs, toggles, checkboxes, links that navigate away, anything inside modal/dialog.

##### Broken-Wiring Detection

A safe-allow-listed control that renders but produces **no observable response** when clicked is a functional bug (the "broken-wiring" class — a control wired to nothing, or to a dead handler). Detect by diffing page state across the click already performed above, reusing the snapshot + network reads already taken. **No new tools; rides ONLY the safe-interaction allow-list — never broaden to buttons / forms / destructive controls (the 7 SAFETY RULES in SKILL.md remain authoritative).**

```
# wraps the EXISTING safe click — adds before/after capture, no new navigation
snap_before = browser_snapshot();   net_before = browser_network_requests().length
browser_click(target);  wait 1s     # existing settle
snap_after  = browser_snapshot();   net_after  = browser_network_requests().length

if a11y_tree(snap_after) == a11y_tree(snap_before)   # no DOM/content change
   and url unchanged                                  # no route change
   and net_after == net_before:                       # no request fired
     finding {
       type: "broken_wiring",
       severity: primary_action(target) ? "Error" : "Warning",
       element: <label>, selector: <selector>, route: <current route>
     }
```

**Couple the snapshot-diff WITH the network check** — separates two distinct defects:
- *renders-but-inert* (no a11y change AND no request) → `broken_wiring` here.
- *handler fires, backend fails* (a request DID fire, returned ≥400) → already a network-failure finding via Phase 4.4 / Phase 3.3; NOT broken-wiring.

**False-positive guard.** Some safe clicks legitimately produce no change: re-clicking an already-sorted column, toggling an already-open accordion, clicking the current tab. The triple-condition (a11y-tree AND url AND network all unchanged) suppresses most; remaining noise is bounded by Warning severity + cross-route dedupe ("seen on N routes"). Never promote a single inconclusive observation to Error unless the control is a primary page action.

#### 4.7 Extract Page Title
- Read page `<title>` or first `<h1>` from snapshot
- Store as page's display name in hierarchy

#### 4.8 Visual Analysis (Conditional Screenshot)

**This step is NOT taken on every tick.** Take screenshot and perform visual analysis ONLY when one or more triggers met:

1. **Empty container detected** — content area blank with no empty-state message
2. **Loading indicators still present** — spinners, skeletons, or `[aria-busy]` visible after full wait
3. **Structural anomaly** — page missing pattern that 80%+ of visited pages have (e.g., no breadcrumbs when most pages have them). Requires 10+ pages visited.
4. **Content density outlier** — page has significantly less content than sibling pages at same hierarchy depth
5. **Every 10th tick** — periodic visual check regardless of triggers

**When triggered:**

1. **Resize browser** to 1280×720 (prevents oversized screenshot issues)
2. Take **viewport-only screenshot** (never full-page — long pages can exceed 8000px and crash session)
3. Analyze screenshot for:

   **Data completeness:**
   - Tables with headers but no rows
   - Charts with axes but no data
   - Cards that are emptier than similar cards on other pages
   - Avatar/profile images that are generic placeholders
   - Sections that should have content but show only whitespace

   **Loading state issues:**
   - Stuck spinners or progress bars
   - Skeleton placeholders that never resolved to real content
   - Partially loaded content (some sections rendered, others blank)

   **Layout and design issues:**
   - Overlapping text or elements
   - Content overflowing its container (horizontal scroll)
   - Misaligned elements that break the visual grid
   - Inconsistent spacing compared to other pages
   - Z-index issues (elements hidden behind others)

   **Design consistency** (requires 10+ pages visited — compare against accumulated structural metadata):
   - Typography inconsistencies (different heading sizes for same-level content)
   - Color usage not matching established palette
   - Component variants used inconsistently (e.g., primary buttons where siblings use secondary)
   - Missing UI patterns present on sibling pages (pagination, search, filters)

4. Record visual findings in ledger with `type: "visual"` and subcategory:
   - `visual_data_missing` — page appears to have incomplete or missing data
   - `visual_loading_stuck` — loading state that didn't resolve
   - `visual_layout_broken` — layout/overflow/overlap issue
   - `visual_design_inconsistency` — inconsistent with established page patterns
   - `visual_empty_state` — empty area with no user-facing message

5. **Token budget**: One screenshot costs ~1,600 tokens. Keep visual analysis under 30 seconds.

---

### Phase 5-LOOP: Extract Links & Build Hierarchy

#### 5.1 Extract Links
Combine links from ALL snapshots taken during Phase 4 — initial page snapshot AND every post-interaction snapshot (tabs, pagination, accordions may reveal new links). Deduplicate by href.

Use `browser_snapshot` to find all link elements. Accessibility tree returns refs for clickable elements including links with text and href.

**Fallback**: If snapshot doesn't expose hrefs, use `browser_evaluate` with:
```javascript
JSON.stringify(
  Array.from(document.querySelectorAll('a[href]')).map(a => ({
    href: a.href,
    text: a.textContent.trim().slice(0, 100),
    inNav: !!a.closest('nav, [role="navigation"], header'),
    inSidebar: !!a.closest('aside, [role="complementary"], .sidebar'),
    inFooter: !!a.closest('footer')
  }))
)
```

#### 5.2 Normalize & Filter URLs
For each extracted link, apply normalization rules from references/main.md:

1. Parse URL. If relative, resolve against `BASE_URL`.
2. **Skip if**:
   - External origin (different host than `BASE_URL`)
   - `mailto:`, `tel:`, `javascript:`, `data:` scheme
   - Auth path: matches `/auth/*`, `/oauth/*`, `/login`, `/logout`, `/callback`, `/signup`, `/register`
   - File download: ends with `.pdf`, `.zip`, `.csv`, `.xlsx`, `.doc`, `.png`, `.jpg`, `.svg`
   - Already in `crawl-visited.json` (exact URL)
   - Already in queue (exact URL)
3. Strip hash fragments (`#section` → removed)
4. Strip query parameters (visit base URL only)
5. Normalize trailing slashes (remove trailing `/`)
6. **Dynamic segment dedup**: Normalize URL to pattern:
   - UUID segments: `/[0-9a-f]{8}-[0-9a-f]{4}-...` → `:uuid`
   - Numeric IDs: `/\d+` (path segment that is all digits) → `:id`
   - Date strings: `/\d{4}-\d{2}-\d{2}` → `:date`
   - Firestore-style IDs: `/[A-Za-z0-9]{20,}` → `:docid`
   - Check if normalized pattern exists in `url_patterns_seen[]`. If so, skip.
   - If not, add pattern to `url_patterns_seen[]`.

#### 5.3 Classify & Enqueue
For each link passing filtering:
1. Classify navigation context:
   - **nav**: Inside `<nav>`, `<header>`, or `role="navigation"` → priority multiplier ×2.0
   - **sidebar**: Inside `<aside>`, `role="complementary"`, or `.sidebar` → multiplier ×1.5
   - **content**: In main content area → multiplier ×1.0
   - **footer**: Inside `<footer>` → multiplier ×0.5
2. Compute priority: `(10 - depth) × context_multiplier`
   - `depth` = current page's depth + 1
3. Add to queue:
   ```json
   { "url": "/path", "parent": "<current_page_url>", "nav_context": "nav", "priority": 8.5, "depth": 2, "discovered_tick": 14 }
   ```

#### 5.4 Update Hierarchy
1. Add current page as node in `hierarchy.json` (if not already present):
   ```json
   { "title": "Page Title", "depth": 1, "discovered_from": "/", "also_linked_from": [], "children": [], "nav_context": "nav", "external_links": [] }
   ```
   - `discovered_from` = page that first linked here (determines tree position)
   - `also_linked_from` captures additional pages linking here (preserves full link graph)
2. If page already exists in hierarchy but discovered again from different parent, append to `also_linked_from[]`
3. Add newly discovered internal links as children of current node
4. Record any external links in node's `external_links[]` array
5. If current page's `discovered_from` node exists, ensure this page is in its `children[]`

#### 5.5 Update Visited Map
Add/update the current page in `crawl-visited.json`:
```json
{
  "title": "Page Title",
  "visited_tick": 14,
  "visited_at": "<ISO-8601>",
  "status": "clean|has_issues",
  "links_found": 8,
  "findings_count": 2,
  "fixes_applied": 0,
  "structure": {
    "has_breadcrumbs": true,
    "has_pagination": false,
    "has_sidebar": true,
    "has_search": false,
    "has_footer": true,
    "card_count": 4,
    "table_row_count": 0,
    "image_count": 3,
    "broken_image_count": 0,
    "heading_levels": ["h1", "h2"],
    "nav_item_count": 7,
    "loading_indicators_present": false,
    "empty_containers": 0,
    "content_density": "medium"
  }
}
```

#### 5.6 Cross-Page Structural Comparison

**Run only after 10+ pages visited.** Compare current page's structural metadata against accumulated patterns:

1. **Compute pattern baselines** from all visited pages:
   - What percentage have breadcrumbs? Pagination? Sidebar? Search?
   - Median card count, table row count, image count per page?
   - Typical nav item count?

2. **Flag anomalies** when current page deviates:
   - **Missing common element**: If 80%+ of pages have breadcrumbs but this page doesn't → finding: `visual_design_inconsistency`
   - **Structural outlier**: If sibling pages (same hierarchy depth or same parent section) have 10+ table rows but this page has 0 → finding: `visual_data_missing`
   - **Nav count mismatch**: If nav item count differs from mode → possible conditional nav rendering issue
   - **Content density outlier**: If page is `low` density but siblings are `medium`/`high` → finding: `visual_data_missing`

3. Record structural comparison findings in ledger with `type: "visual"` and relevant subcategory.

4. **Print anomalies** in tick summary when found:
   ```
   [browse] Tick #22 — /projects
     ├─ ...
     ├─ Visual: Missing breadcrumbs (present on 18/20 other pages)
     └─ Visual: Table has 0 rows (siblings avg 12 rows)
   ```

---

### Phase 6-LOOP: Auto-Fix

For each Critical and Error finding on current page (max 2 fixes per tick):

#### 6.1 Trace to Source
1. Read error message and stack trace (if available)
2. Identify source file and line number
3. Read source file to understand context
4. Identify root cause

**Tracing by finding type:**
- **Console errors with stack trace**: Follow stack trace directly to source file and line
- **Network 404**: Grep codebase for failing endpoint URL (e.g., search for `/api/users`). Check both API definition and calling component.
- **Network 401/403**: Likely auth config — check middleware, route guards, or API client headers. Often not auto-fixable.
- **Content quality (placeholder text)**: Grep for exact text ("Lorem ipsum", "TODO") in source files under page's component tree
- **Broken images**: Grep for image filename or `src` attribute in templates
- **Dead links (`href="#"`)**: Grep for `href="#"` in page's component and children

#### 6.2 Apply Minimal Fix
- Fix ONLY specific error — do not refactor surrounding code
- Use same fix templates as Phase 5 (non-loop mode) — see references/main.md
- Common fixes: optional chaining, missing imports, wrong API endpoints, missing error states

#### 6.3 Verify
1. Run verify command (typecheck + lint, auto-detected)
2. **If pass**: commit with message `browse-fix(<page_path>): <description>`
3. **Wait 3 seconds** after commit — dev server needs time to process file change and complete HMR. Navigating too early hits partially-rebuilt state.
4. **If fail**: revert ALL changes, mark finding as `needs-human` in ledger. If revert also fails (file not writable), log error and exit tick immediately.

#### 6.4 Fix Limits & Circuit Breaker
- **Max 2 fixes per tick** — keeps within time budget
- **Max 1 fix per file per tick** — prevents cascading failures from multiple edits to same file
- **Circuit breaker state** (tracked in `latest-tick.json`):
  - `consecutive_fix_failures`: incremented on each failed fix, reset to 0 on any successful fix
  - `circuit_breaker_cooldown`: when `consecutive_fix_failures >= 3`, set to `current_tick + 3`
  - During cooldown (`tick < circuit_breaker_cooldown`): skip Phase 6 entirely, only crawl
  - After cooldown expires: resume fixing, counter stays at 0
- **Cascading invalidation**: if fix modifies shared file (composable, utility, store), mark all visited pages importing that file as `status: "needs_re_verify"` in `crawl-visited.json`. These pages rejoin RE-VERIFY queue.

#### 6.5 Fix Quality Gate
Same rules as Phase 5.5 (non-loop mode):
- **BANNED**: silent `return`, empty catch, `// TODO` comments, `@ts-ignore` without resolution

---

### Phase 7-LOOP: Save State & Report

#### 7.1 Save State (Atomic Writes)

State files have interdependencies — crash mid-write can leave inconsistent state. Use this write order (JSONL appends first, then JSON overwrites):

1. **Append** to `crawl-ledger.jsonl` — new findings (append-only, crash-safe)
2. **Append** to `fix-log.jsonl` — fix attempts (append-only, crash-safe)
3. **Write** `latest-tick.json` — tick snapshot (write last so overlap guard works)
4. **Write** `crawl-queue.json` — updated queue
5. **Write** `crawl-visited.json` — updated visited map (include this page's `interaction_coverage` + `broken_wiring[]` from Phase 4.6)
6. **Write** `hierarchy.json` — updated hierarchy

For JSON files (steps 3-6): write to `.tmp` file first, then rename to final path. Ensures each file is either fully old or fully new, never partially written.

`latest-tick.json` snapshot:
```json
{
  "tick": 14,
  "page_visited": "/settings/profile",
  "pages_visited_total": 14,
  "pages_queued": 23,
  "findings_total": 7,
  "fixes_applied": 3,
  "fixes_failed": 1,
  "hierarchy_depth": 3,
  "status": "crawling",
  "circuit_breaker_cooldown": 0,
  "consecutive_fix_failures": 0,
  "updated_at": "<ISO-8601>"
}
```

#### 7.2 Print Tick Summary
```
[browse] Tick #14 — /settings/profile
  ├─ Links: 8 found, 5 new (3 already visited/queued)
  ├─ Findings: 1 error (fixed ✓), 2 warnings
  ├─ Visual: 1 design inconsistency (missing breadcrumbs)
  ├─ Fixes: 1 applied, 0 failed
  ├─ Queue: 23 remaining, max depth 3
  └─ Progress: 14/37 pages (37.8%)
```

#### 7.3 Site Map (every 10th tick)
Every 10 ticks, print navigational hierarchy as tree:
```
[browse] Site Map (14 pages visited, 23 queued):
/ (Home) ✓
├─ /dashboard (Dashboard) ✓
│  ├─ /dashboard/analytics (Analytics) ✓
│  └─ /dashboard/reports (Reports) [queued]
├─ /settings (Settings) ✓
│  ├─ /settings/profile (Profile) ✓ ← current
│  └─ /settings/billing (Billing) [queued]
├─ /users (Users) [queued]
└─ /projects (Projects) [queued]
```

Legend: `✓` = visited clean, `⚠` = has issues, `✗` = has unfixed issues, `[queued]` = not yet visited

#### 7.4 Cross-Page Visual Audit (on COMPLETE tick only)

When crawl transitions to `COMPLETE` status, run final design consistency audit before final report:

1. **Group pages by section** — pages sharing same first path segment (e.g., all `/dashboard/*`, all `/settings/*`)
2. **For each group of 3+ pages**, take viewport screenshots of up to 5 pages and pass to model simultaneously:

   > "These [N] screenshots are from the [section] section of a [framework] application. Analyze them together for:
   > 1. Design consistency: Do they share the same layout, spacing, typography, and color usage?
   > 2. Missing elements: Are structural patterns (breadcrumbs, headers, sidebars, footers) present on some but missing on others?
   > 3. Data completeness: Do any pages appear emptier or more sparse than their siblings?
   > 4. Visual quality: Any overlapping elements, overflow, misalignment, or broken images?
   > Return findings as a list with page URL, issue type, and description."

3. **Compare structural metadata** across all groups to find global patterns:
   - Which UI elements truly global (present on 90%+ pages)? Flag pages missing them.
   - Heading hierarchies consistent? (e.g., all pages use h1 for title, h2 for sections)
   - Card/table rendering consistent across similar page types?

4. Record all findings as `type: "visual"` in ledger. Not auto-fixable but valuable for report.

5. **Write visual audit summary** to `docs/crawls/visual-audit.md`:
   ```markdown
   # Visual Audit — [date]

   ## Global Patterns
   - Breadcrumbs: present on 42/47 pages (missing on: /projects, /reports, ...)
   - Sidebar: present on 45/47 pages
   - Pagination: present on 8/12 list pages (missing on: /users, ...)

   ## Design Consistency Issues
   ### /dashboard section (5 pages)
   - /dashboard/reports: Missing chart data, empty container without empty-state
   - /dashboard/analytics: Heading uses h3 instead of h2 (inconsistent with siblings)

   ## Data Completeness Issues
   - /projects: Table has 0 rows (siblings average 12)
   - /settings/billing: Card is missing 2 fields present on /settings/profile card
   ```

#### 7.5 Final Report
When `status` is `COMPLETE`:
```
[browse] ✓ Site crawl complete!
  ├─ Pages visited: 47
  ├─ Total findings: 12 (8 fixed, 4 needs-human)
  ├─ Visual findings: 6 (3 design inconsistency, 2 missing data, 1 layout)
  ├─ Hierarchy depth: 4
  ├─ Duration: 47 ticks (~4 hours)
  ├─ Visual audit: docs/crawls/visual-audit.md
  └─ Full site map: docs/crawls/hierarchy.json
```
Print full site map tree. Skill will no-op on subsequent ticks (check `latest-tick.json` status).

#### 7.6 Session Cleanup
- Log to activity feed: `skill_complete` or `phase_complete` (per tick)
- Update session JSON: status and last_activity
- On COMPLETE: full session cleanup per session-protocol.md

---

### Loop Mode Error Recovery

**Browser not available at tick start:**
1. Use ToolSearch to reload Playwright MCP tools
2. Navigate to BASE_URL to start fresh
3. If still failing, log error and exit tick (retry on next tick)

**Page navigation fails:**
1. Record as Warning: "Navigation failed on [page]"
2. Move page to end of queue with reduced priority (halve current priority)
3. Track failure count per page in `crawl-queue.json` entry: `"nav_failures": N`
4. If same page fails 3 times, mark as `unreachable` in visited and skip permanently
5. Continue to save state and exit

**Authentication lost (redirect to login or 401 responses):**
1. Record as Critical in ledger
2. Set `latest-tick.json` status to `"auth_lost"`
3. Print message: "Authentication lost. Please re-authenticate in browser, then delete `docs/crawls/latest-tick.json` or set its status to `crawling` to resume."
4. Exit tick. Subsequent ticks detect `auth_lost` status and exit immediately until user intervenes.

**Dev server unreachable:**
1. Wait 5 seconds and retry once
2. If still unreachable, set status to `"server_down"`, exit tick
3. Next tick will retry automatically (server_down not a terminal state)

**State file corruption:**
1. Detect: JSON parse error when loading any state file
2. Rename corrupted file to `<filename>.bak`
3. For `crawl-queue.json` or `crawl-visited.json`: attempt reconstruction from `crawl-ledger.jsonl` (most reliable, append-only)
4. For `hierarchy.json`: rebuild from `crawl-visited.json` parent references
5. If reconstruction fails: log error, re-seed from scratch (delete all state, restart crawl)

**Fix revert failure:**
1. If fix fails verification AND revert also fails
2. Log both errors to `fix-log.jsonl`
3. Mark finding as `needs-human`
4. Exit tick immediately — do not attempt further fixes or state writes
5. Next tick will detect dirty state via `git status` and warn

**Tick timeout exceeded:**
1. If elapsed time > 100 seconds at any phase boundary
2. Skip remaining phases, jump directly to Phase 7-LOOP (Save State)
3. Log warning: `[browse] Tick #N exceeded time budget at Phase X. Saving state and exiting.`
4. Unfinished work (links not extracted, fixes not attempted) handled on next tick
