# SCOPE-LIMIT.md Protocol

Operator-facing stop signal: tells the autonomous loop to halt proposing new work even when work exists. Distinct from `STATE.md` (sprint-level checkpoint) and from `deferred` carry-forward registry entries (item-level deferral). A `SCOPE-LIMIT.md` is the **whole-codebase override**: when present and unexpired, `/blitz:next --loop` short-circuits its decision tree to `LOOP_ESCALATE` regardless of pending sprints, active carry-forward entries, or unsprintified audit epics.

---

## When to declare

- **Diminishing-returns ceiling** reached on a series of audit-derived sprints (e.g., 4 sprints of cleanup with sub-linear findings/sprint).
- **Architectural pause** required while a major capability lands (the loop should wait, not propose patchwork).
- **Operator out-of-band** wants to suspend autonomous progress for review/audit/handoff.
- **Cooldown after incident** — e.g., a runaway loop iteration produced regressions; lock the loop until investigation completes.

Do NOT declare a scope limit to defer a single item — use the carry-forward registry `deferred` event for that (see [carry-forward-registry.md](carry-forward-registry.md)).

---

## File location

Single canonical path: `SCOPE-LIMIT.md` at repo root. No glob; no per-domain variants in v1 (extend only if operators ask).

---

## Frontmatter schema

```yaml
---
declared_at: 2026-05-18         # ISO-8601 date (REQUIRED)
declared_by: operator           # operator | audit-skill | automation (REQUIRED)
scope: full-codebase            # full-codebase | <domain-slug> | <epic-id> (REQUIRED)
reason: |                       # Multi-line string (REQUIRED)
  Free-form rationale. First non-blank line surfaces in /blitz:next row 6f
  banner; rest visible only via `cat SCOPE-LIMIT.md`.
expires_after: 2026-08-01       # ISO-8601 date (REQUIRED — see Expiry semantics)
revival_conditions:             # Optional list of strings
  - New capability landing
  - Explicit operator action
---
# Scope Limit Declaration

Free-form prose body. Operators should briefly note the trigger event,
what work is being suspended, and the resumption criteria.
```

**Required fields**: `declared_at`, `declared_by`, `scope`, `reason`, `expires_after`. Missing any required field → `/blitz:next` Phase 0.9c treats as malformed, prints warning, does NOT honor the file.

**`scope` enum values**:
- `full-codebase` — block all autonomous loop progress
- `<domain-slug>` — reserved for future per-domain scoping; in v1 treated as `full-codebase` (forward-compat)
- `<epic-id>` (e.g., `E-022`) — reserved for future epic-level scoping; in v1 treated as `full-codebase`

**`declared_by` enum**: `operator | audit-skill | automation`. `audit-skill` reserved for future `audit` integration (audit declares a scope limit when findings/sprint drops below a threshold).

---

## `/blitz:next` Phase 0.9c + row 6f behavior

**Phase 0.9c detection** (see `skills/next/SKILL.md` after S13-008 lands):

```bash
SCOPE_LIMIT_ACTIVE=0
if [ -f SCOPE-LIMIT.md ]; then
  # Strip surrounding quotes so quoted-YAML form (`expires_after: "2026-08-01"`)
  # extracts as `2026-08-01`, not `"2026-08-01"` — the quote char sorts below '0'
  # in shell string-compare, silently treating active limits as expired.
  EXPIRES=$(awk '/^expires_after:/ {print $2; exit}' SCOPE-LIMIT.md | tr -d '"'"'")
  if [ -z "$EXPIRES" ]; then
    echo "[next] SCOPE-LIMIT.md present but missing expires_after — malformed, ignoring" >&2
  elif [ "$(date -u +%Y-%m-%d)" \< "$EXPIRES" ]; then
    SCOPE_LIMIT_ACTIVE=1
  fi
fi
```

**Row 6f dispatch** (decision-tree position: after 6e, before 7):
- Condition: **No active sprint** + `SCOPE_LIMIT_ACTIVE == 1` (an in-progress/planned sprint at rows 1-5 still dispatches first — see Tie-break precedence below)
- Short-circuits rows 6a-6e regardless of `CF_ESCALATED` / `CF_PENDING_INPUTS` / `CF_ACTIVE`
- Action: Print SCOPE-LIMIT banner including declared_at, expires_after, first line of reason, and revival instructions
- Exit: emit `LOOP_ESCALATE` stop signal

**Tie-break precedence**: Row 6f short-circuits rows 6a-6e (new-work auto-detection paths). An in-progress or planned sprint (rows 1-5) continues to ship — SCOPE-LIMIT.md suspends the loop's appetite for NEW work but does not interrupt committed sprints. Operators who need to halt active work should let the sprint complete OR manually delete `sprint-${N}/STATE.md` to abandon.

**Re-entry semantics**: Each subsequent `/blitz:next --loop` tick re-detects the file and re-prints the banner. Operators clear the override by deleting the file OR editing `expires_after` to a past date.

---

## Expiry semantics

- `expires_after` is **required** (no missing-field tolerance — see schema).
- Comparison: `today (UTC) < expires_after` → active. Equal-day → expired (boundary is exclusive on the active side).
- Past-date file → treated as cleared (file is informational only, never re-emits LOOP_ESCALATE).
- Date-only granularity: time-of-day not honored. A scope-limit declared `expires_after: 2026-08-01` becomes inactive at the first `/blitz:next` tick on or after `2026-08-01 00:00 UTC`.

Operators who want indefinite scope limits should still set `expires_after` (e.g., `2099-12-31`). Indefinite-without-expiry is intentionally disallowed to prevent the "forever-block" failure mode (Risk 4 in `docs/_research/2026-05-18_audit-deferred-work-detection.md`).

---

## Lifecycle commands (provisional)

In v1, lifecycle is hand-edit only:

| Operation | How |
|---|---|
| Declare | Write `SCOPE-LIMIT.md` by hand at repo root with required frontmatter |
| Clear | Delete the file OR set `expires_after` to a past date |
| Extend | Edit `expires_after` to a later date |
| Inspect | `cat SCOPE-LIMIT.md` |

**Future**: A `/blitz:scope-limit declare|clear|extend|inspect` skill could automate this (out of scope for v1 — covered as future-epic candidate).

---

## Distinction from related concepts

| Signal | Granularity | Persistence | Effect on `/blitz:next` |
|---|---|---|---|
| `STATE.md` | per-sprint | sprint-only | row 1: resume sprint from checkpoint |
| Carry-forward entry (`status: deferred`) | per-item | indefinite until revived | row 6a if `rollover_count >= 3` |
| `SCOPE-LIMIT.md` | full-codebase | until file deleted OR expires_after past | row 6f: LOOP_ESCALATE (short-circuits all other rows) |

---

## Related protocols

- [state-handoff.md](state-handoff.md) — pipeline artifact contracts
- [carry-forward-registry.md](carry-forward-registry.md) — item-level deferred work
- [checkpoint-protocol.md](checkpoint-protocol.md) — sprint-level STATE.md
- [terse-output.md](terse-output.md) — output style for banner formatting
