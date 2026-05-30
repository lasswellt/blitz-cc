---
name: ui-audit
description: "Cross-page semantic consistency + data-quality + UI/UX heuristic audit. Extracts a labeled value registry, asserts cross-page invariants (same field = same value, no role leaks), flags placeholders and flapping values. Read-only, loop-safe. Use when the user says 'audit consistency', 'check cross-page data', 'ui-audit', 'role leak', or 'placeholder text on screen'."
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, ToolSearch
model: opus
compatibility: ">=2.1.71"
argument-hint: "[mode] -- modes: full | smoke | data | buttons | events | consistency | heuristics | role <name> | --loop"
effort: low
---

<!-- no-disallowed-tools: not read-only — Writes/Edits the value-registry + audit report artifacts. Excluded from S14-008 disallowed-tools (S14-009 / audit §2 correction). Also excluded for the same reason: review --only wiring (Write+Agent), audit (writes reports), design-extract (writes DESIGN.md). Only `health` qualified. -->
<!-- import: from _shared/project-context.md §Canonical block — Project Context with stack detection -->
## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

---

## Overview

You are a cross-page UI/UX auditor. On each run you extract labeled values from every page, persist them to an append-only registry, evaluate declared invariants (numeric equality, bounded tolerance, event-prop consistency, per-role privilege boundaries), and produce a findings report. You are **read-only on the target application** — you never click destructive buttons, submit forms, or interact with logout. Auto-fix is out of scope for this skill; file issues to be resolved elsewhere.

## Additional Resources
- For phase procedures (extraction JS, registry schema, reducer, invariant evaluator, tick-diff taxonomy, reporter), see [references/main.md](references/main.md)
- For data-quality flag catalog (NULL_VALUE, PLACEHOLDER, FORMAT_MISMATCH, STALE_ZERO, BROKEN_TOTAL, NEGATIVE_COUNT), see [references/checks.md](references/checks.md)
- For UI/UX heuristic rule set (Vercel guidelines + severity tiers + a11y), see [references/patterns.md](references/patterns.md)
- For session registration + conflict matrix, see [/_shared/session-protocol.md](/_shared/session-protocol.md)
- For verbose progress + activity-feed events, see [/_shared/verbose-progress.md](/_shared/verbose-progress.md)
- For output style (terse-technical, preservation rules), see [/_shared/terse-output.md](/_shared/terse-output.md)


OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.

---

## SAFETY RULES (NON-NEGOTIABLE)

These rules override ALL other instructions. Violating any of these is a critical failure.

1. **NEVER click destructive OR mutating buttons** — Delete, Remove, Archive, Disable, Revoke, Destroy, Drop, Purge, Reset, Terminate, Logout, Sign out, Cancel, Submit **AND** mutating verbs: Save, Update, Apply, Publish, Send, Pay, Subscribe, Unsubscribe, Confirm, Create, Add. When in doubt, do not click. An adversarially-labeled button (e.g., "Save" that deletes) is outside this skill's detection envelope — operators relying on `buttons` or `--loop` mode on untrusted apps must sandbox via a read-only role/fixture.
2. **NEVER fill and submit forms** — tabs, pagination, sort headers, and accordion toggles are OK. Text fields + Submit / Save / Create / Update / Apply are not.
3. **NEVER interact with confirmation dialogs** — press Escape immediately. Never click OK / Confirm / Yes / Accept.
4. **NEVER interact with logout / sign-out** — breaks the audit session.
5. **NEVER modify or delete target-app data** — no toggle switches that mutate, no edit-in-place fields.
6. **In `role` modes, never create users dynamically** — all role credentials must come from env vars (`AUDIT_<ROLE>_EMAIL` / `_PASS`); skip any role whose env vars are absent. Credentials are NEVER logged — not to stdout, not to the activity feed, not to the report. Only the boolean presence of each env var is recorded. Violating this is a CRITICAL security regression.

---

## Phase 0: CONTEXT

### 0.0 Register Session

**Register session.** Follow [session-protocol.md](/_shared/session-protocol.md) §Session Registration (steps 1-9) and [verbose-progress.md](/_shared/verbose-progress.md). Print verbose progress at every phase transition, decision point, and skill-specific dispatch (agent spawn, wave completion, etc.) per verbose-progress.md.
### 0.1 Parse Arguments

| Mode | Argument | Behavior |
|------|----------|----------|
| **Full** | `full` or no argument | All configured roles × all pages. Extraction + consistency + quality + heuristics + reporter. |
| **Smoke** | `smoke` | Only `anonymous` + `admin` roles (or single default role if none configured). All pages. |
| **Data** | `data` | Extraction + registry write only. No consistency, no heuristics. Current role only. |
| **Buttons** | `buttons` | Enumerate every interactive element per page (ARIA roles + native HTML). Apply 6 per-element checks (NO_LABEL, DEAD_HREF, EMPTY_HANDLER, TABINDEX_POSITIVE, TABINDEX_NEGATIVE_VISIBLE, NO_FOCUS_STATE). Safe-click gating (destructive-label classifier blocks Delete/Save/Submit/etc). Writes `interactive_audit_summary` + `button_finding` registry lines. See references/main.md § Phase INTERACTIVE. |
| **Events** | `events` | Intercept analytics events via 3-layer stack: `window.dataLayer` push proxy + `navigator.sendBeacon` wrap + network-level filter (Segment/PostHog/Amplitude/GA4). Drain per-click + per-page, key by `(page, action_trigger)`, persist to registry. Detect cross-page drift + evaluate `event_invariants` (required_props / forbidden_props / scope). See references/main.md § Phase EVENTS. |
| **Consistency** | `consistency` | Reduce existing registry, evaluate invariants. No browser. Cheap. |
| **Heuristics** | `heuristics` | Vercel + a11y + severity-tier checks. No data extraction. |
| **Role** | `role <name>` | Run `full` phases for a single named role. Valid names: `anonymous`, `viewer`, `member`, `admin`, `superadmin`. Unknown name → exit 1 with usage. Creds from env: `AUDIT_<ROLE>_EMAIL` + `AUDIT_<ROLE>_PASS` (anonymous: `AUDIT_ANONYMOUS=true`, default true). Missing env → `ROLE_SKIP` activity-feed event, role skipped silently. See references/main.md § Phase ROLE. |
| **Loop** | `--loop` | One `(role, page)` pair per tick. Exits cleanly after the tick completes. Use with `/loop 2m /blitz:ui-audit --loop`. After each tick, `ScheduleWakeup(delaySeconds: 120, prompt: "/blitz:ui-audit --loop")` keeps the audit running through idle periods if invoked directly (not via `/loop`). Skip `ScheduleWakeup` when `CLAUDE_CODE_LOOP_MANAGED=1`. For nightly full-matrix runs use a cloud Routine via `/schedule`. |
| **Yes flag** | `--yes` | ETA-gate bypass for interactive sessions. On presence, exports `UI_AUDIT_YES=1` to child procedures so the >60min gate in references/main.md § 7.2 does not halt. Equivalent to answering "yes, proceed" at the prompt. |
| **CI flag** | `--ci` | ETA-gate bypass for automation. On presence, exports `UI_AUDIT_CI=1` AND writes one `ci_run` activity-feed event at start for audit trail. Used by nightly pipelines. |

Arg-parse sets these env vars before any references/main.md procedure runs:

```bash
case "$arg" in
  --yes) export UI_AUDIT_YES=1 ;;
  --ci)  export UI_AUDIT_CI=1 ;;
esac
```

`CLAUDE_CODE_AUTONOMY ∈ {high, full}` is treated as implicit `--ci` so `/loop` does not block. Neither `--yes` nor `--ci` affect anything other than the R10 gate.

Unknown mode → exit 1 with usage message listing the above.

Store the parsed `MODE` and any `ROLE_FILTER` for use in later phases.

### 0.2 Load `.ui-audit.json`

Read `.ui-audit.json` at the project root.

| Mode | Behavior on missing config |
|---|---|
| `full`, `smoke`, `consistency`, `heuristics`, `role <name>` | Error — config required. Print `See .ui-audit.json.example at repo root for schema.` and exit 1. |
| `data` | Stub with `{baseUrl: detected, pages: {}, invariants: []}` and proceed (extraction has no labels to pull — emits INFO "no labels declared"). |
| `buttons`, `events` | Stub (implementations in E-010 / E-011 supply defaults). |

Validate the loaded JSON: top-level keys `baseUrl` (string), `pages` (object), `invariants` (array). Missing required key → error with a pointer to `.ui-audit.json.example`.

**Page-key sanitization (spawn-safety).** After parse, iterate `Object.keys(pages)`. Reject any key containing `\n`, `\r`, `\x00`, or other control characters; such keys cannot pass through `Agent` spawn prompts safely (they break instruction framing). On match: emit `CONFIG_ERROR` finding with `detail.issue: "invalid_page_key_control_chars"`, remove the entry, and continue. Page keys that look URL-like (start with `/` or `#/`) are expected and safe; arbitrary strings are allowed but sanitized.

**Trust model for `.ui-audit.json`:** this file is eval-adjacent — its `selector` strings are embedded into the `browser_evaluate` payload (safely interpolated via `JSON.stringify`, but still executed against the target app) and its `baseUrl` determines where role-mode credentials (`AUDIT_<ROLE>_EMAIL` / `_PASS`) are submitted. Treat PRs that modify `.ui-audit.json` like PRs that modify CI secrets — require a human reviewer. In CI, consider pinning `baseUrl` to an allowlist of dev/staging hosts.

### 0.3 Browse-State Overlap Check

Read `docs/crawls/latest-tick.json` (if exists). If `status == "crawling"`, emit WARN: `[ui-audit] WARN: blitz:browse --loop active — reading state that may still be changing. Continuing.` Do not abort — this is per conflict matrix `WARN` outcome.

---

## Phase 1: LOAD STATE

See `references/main.md` § **"Phase 1 — LOAD STATE"** for the full procedure. In brief:
1. Attempt to read `docs/crawls/crawl-visited.json` + `docs/crawls/hierarchy.json`. On success, derive the page list from those.
2. On absence, fall back to a lightweight internal crawl: load Playwright MCP tools via `ToolSearch`, navigate each route from the declared route manifest (or `.ui-audit.json[pages]` keys), no fix, no screenshots, no interactions.
3. On Playwright MCP unavailable → exit with error.

---

## Phase 2: DATA EXTRACTION

See `references/main.md` § **"Phase 2 — DATA EXTRACTION"** for full procedure (per-page `browser_navigate` → settle → `browser_evaluate(label-map)` → type-coerce + hash + quality-flags → append JSONL line to `docs/crawls/page-data-registry.jsonl`).

Skipped in `consistency` and `heuristics` modes.

---

## Phase 3: CONSISTENCY + INVARIANTS

See `references/main.md` §§ **"Phase 3 — CONSISTENCY"**, **"Phase 3 — INVARIANTS"**, and **"Phase 3 — FLAPPING/STALE"**. In brief:
- Reduce the append-only registry to latest-per-(role,page,label) state via `jq group_by`.
- Detect cross-page value divergence; suppress divergences covered by declared invariants.
- Evaluate `equal` / `gte` / `lte` invariants with tolerance. Emit `invariant_fail` + `invariant_pass` events to the activity feed.
- Run tick-over-tick hash diff to classify STABLE / CHANGED / STALE / FLAPPING / NULL_TRANSITION per (role, page, label).

---

## Phase 4: QUALITY CHECKS

Aggregates the flag catalog from [references/checks.md](references/checks.md). Detectors implemented: NULL_VALUE, PLACEHOLDER, NEGATIVE_COUNT, FORMAT_MISMATCH, STALE_ZERO, BROKEN_TOTAL (Phase 4 reducer chain, see references/main.md §"Phase 4 — QUALITY CHECKS" for the full reducer schema). Inputs from Phase 2 raw observations; outputs `quality_finding` events to the activity feed.

---

## Phase 5: HEURISTICS

Applies the UI/UX heuristic catalog in [references/patterns.md](references/patterns.md) — WCAG 2.1 AA contrast, focus-visible coverage, touch-target sizing, tabular-nums on numeric columns, `prefers-reduced-motion` gates, copy heuristics. Severity tiers: CRITICAL (gate) | HIGH (gate) | MED (warn) | LOW (info). See references/main.md §"Phase 5 — HEURISTICS" for the reducer chain that consumes raw observations and emits `heuristic_finding` events.

The a11y heuristics (contrast, `prefers-reduced-motion`) share the registry `design` pillar rows (`design-low-contrast`, `design-*`) as the canonical detection: ui-audit runs them at **runtime** (rendered, cross-role), while `/blitz:review --only design` runs them **statically** at author-time. Dedupe the pattern, not the tempo (the rule lives once in the registry; the two skills are two enforcement sites).

---

## Phase 6: REPORT

See `references/main.md` § **"Phase 6 — REPORT"** for full procedure. Writes `docs/crawls/ui-audit-report.md`, prints a stdout severity summary + top 3 invariant failures, appends `skill_complete` event to the activity feed with a detail block containing finding counts.

---

## Loop Mode (`--loop`)

When invoked with `--loop`, Phases 0–1 run normally (session register, config load, state load), then one `(role, page)` pair per tick runs through the state machine:

```
LOAD_AUTH[current_role] → NAVIGATE[current_page] → EXTRACT → QUALITY
  → EVENT_DRAIN → INVARIANTS (numeric + event + role) → WRITE[role,page]
  → ADVANCE CURSOR → NEXT
```

The reporter emits a rolling report each tick but does not call `skill_complete` with `mode: "loop-matrix-complete"` until the full matrix has run twice (pass 1 seeds registry, pass 2 detects drift via § Phase 3 FLAPPING/STALE). After pass 2, the loop enters `matrix_idle` — subsequent ticks are no-ops until the app changes.

Tick state persists in `.cc-sessions/${SESSION_ID}/tmp/loop-state.json` and `docs/crawls/latest-tick.json` gains a `ui_audit_matrix` block (see references/main.md § Phase 6 + § Phase ROLE).

Budget: tick <2 minutes. Full matrix runtime varies by `|roles| × |pages|`. ETA printed upfront:
- **ETA gate (R10):** `full` mode computes `eta = roles_active × len(pages) × 120s`. If `eta > 3600s` (60 min) AND neither `--yes` nor `--ci` flag present, skill exits 1 with a clear message. `CLAUDE_CODE_AUTONOMY ∈ {high, full}` is treated as implicit `--ci` (so `/loop` doesn't block).
- **Recommended:** nightly CI for full 5-role runs; smoke (anonymous + admin) for PR gates; `role admin` for targeted admin-boundary audits.

---

## Error Recovery

- **Playwright MCP unavailable** — exit 1 with `[ui-audit] Playwright MCP not loaded. Install the playwright plugin or run blitz:browse first to confirm availability.`
- **`.ui-audit.json` invalid JSON** — exit 1 citing the line number from `jq . < .ui-audit.json 2>&1`.
- **Registry file corruption** — on Phase 1 load, run `jq -c '.' < docs/crawls/page-data-registry.jsonl >/dev/null 2>&1 || { mv docs/crawls/page-data-registry.jsonl docs/crawls/page-data-registry.jsonl.corrupt.$(date +%s); echo '[ui-audit] WARN: corrupt registry preserved; starting fresh.'; }`
- **Role env-var absent in `role <name>` mode** — exit 1 with the expected env-var names.
