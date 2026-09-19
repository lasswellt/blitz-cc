# ui-audit — Data-Quality Flag Catalog

> **SKELETON — populated in E-009 (CAP-011) — DO NOT treat as shipping checklist.**
>
> Sprint-6 ships the flag names + 1-line definitions so CAP-008 AC2 closes and Phase 4 (QUALITY) has a stable reference to link against. Implementation procedures land in E-009.

Findings produced by this module surface as `page:label:FLAG` in `docs/crawls/ui-audit-report.md` and as `label: "quality_flag"` entries in `docs/crawls/page-data-registry.jsonl`.

---

## NULL_VALUE

The extracted `parsed` value is `null` — the selector matched nothing, or matched an element with empty `.textContent`. Fires once per (role, page, label). Severity: HIGH when the label is declared in `.ui-audit.json` and the page is declared; MED otherwise.

**Detection:** inline in Phase 2 § 2.4 extraction JS — emits when `raw === null || raw === ''` for a declared label. Implemented in the 2.x ui-audit pass. See `skills/ui-audit/references/main.md § Phase 2 § 2.4`.

## PLACEHOLDER

Raw text matches a placeholder regex. Default pattern: `/lorem|TODO|FIXME|N\/A|--|\?\?\?|xxx|placeholder|fpo|coming soon/i`. Configurable via `.ui-audit.json[placeholder_patterns]` (array of regex strings — compiled at config-load with try/catch; malformed regex emits CONFIG_ERROR, not crash). Severity: HIGH (production placeholder leakage).

**Detection:** inline in Phase 2 § 2.4 extraction JS against the compiled union of built-in + user patterns. See `references/main.md § Phase 2 § 2.4` + `§ Phase 4 § 4.1` (aggregation).

## FORMAT_MISMATCH

The raw string's format (currency symbol, decimal separator, thousands separator, negative style) differs from the mode of prior observations of the same `(role, page, label)`. Fires after ≥2 observations. Severity: MED.

**Detection:** reducer in Phase 4 § 4.2 — jq over registry history + bash format-tuple extraction (`extract_fmt`). See `references/main.md § Phase 4 § 4.2`.

## STALE_ZERO

`parsed === 0` but the latest-wins registry history for the same `(role, page, label)` has ≥1 non-zero observation over the prior 5 ticks. Requires ≥3 observations. Suggests cache miss or silent fetch failure rendered a placeholder zero. Severity: MED.

**Detection:** reducer in Phase 4 § 4.3. See `references/main.md § Phase 4 § 4.3`.

## BROKEN_TOTAL

Configured parent/child relationship: sum of declared child `parsed` values != parent `parsed` within `tolerance` (default 0.01). Requires author to declare a `totals[]` entry in `.ui-audit.json` with `{id, parent:{page,key}, children:[{page,key}], tolerance}`. Severity: HIGH.

**Detection:** evaluator in Phase 4 § 4.4 — jq over reduced registry snapshot. `children[].key` may resolve to multiple observations per page (one per row); all matches are summed. See `references/main.md § Phase 4 § 4.4`.

## NEGATIVE_COUNT

`parsed < 0` on a label whose type is `count`. Counts should not be negative in a healthy UI. Severity: HIGH.

**Detection:** inline in Phase 2 § 2.4 extraction JS — emitted when `LABEL_TYPE == 'count' && Number.isFinite(parsed) && parsed < 0`. Implemented in the 2.x ui-audit pass.

---

## Interactive-element checks (CAP-014 / E-010)

These are orthogonal to data-quality flags — they target interactive elements, not labeled values. Findings surface as `button_finding` registry lines. Full detection procedures in `skills/ui-audit/references/main.md` § Phase INTERACTIVE § I.3.

| Check | Severity | Section |
|---|---|---|
| `NO_LABEL` | HIGH | I.3 (WCAG 2.1 AA) |
| `DEAD_HREF` | MED | I.3 |
| `EMPTY_HANDLER` | MED | I.3 |
| `TABINDEX_POSITIVE` | MED | I.3 |
| `TABINDEX_NEGATIVE_VISIBLE` | MED | I.3 (R7 500ms settle) |
| `NO_FOCUS_STATE` | HIGH | I.4 (WCAG 2.1 AA) |
| `CLICK_ERROR` | CRITICAL | § I.5 (console/network errors within 1s of safe-click) |

---

## Integration with reporter

The Phase 6 reporter (skills/ui-audit/references/main.md § REPORT) consumes quality-flag findings as:

```jsonl
{"ts":"...","role":"...","page":"/dashboard","label":"quality_flag","raw":"","parsed":null,"detail":{"flag":"NULL_VALUE","target_label":"open_invoices","severity":"HIGH"},"hash":"...","tick":7}
```

Reporter groups these alongside invariant failures and heuristic findings by severity tier.
