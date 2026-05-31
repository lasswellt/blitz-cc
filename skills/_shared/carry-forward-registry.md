# Carry-Forward Registry Protocol

Shared reference for the **carry-forward registry** — an append-only JSONL ledger that links research-doc scope claims to delivered artifacts across sprints. Its purpose is to make silent scope drops impossible: any promised scope that hasn't been delivered remains loudly visible until it is completed, explicitly deferred, or dropped with a reason.

**Motivation:** see `docs/_research/2026-04-08_sprint-carryforward-registry.md` for the full incident analysis, industry precedent (Linear cycles, KEP lifecycles, PEP status headers, Shortcut archiving, Jira rightmost-column close, burn-up charts), and design rationale. The short version: when `sprint-plan` auto-waives uncovered acceptance criteria in `full` autonomy, the waiver currently lives only in the sprint manifest's `carry_forward` array, which the next sprint's planner never reads. The registry is the fix.

**Companion protocols:**
- [session-protocol.md](session-protocol.md) — Multi-session safety. The registry follows the same append-only convention as `.cc-sessions/activity-feed.jsonl`.
- [verbose-progress.md](verbose-progress.md) — Every registry write must also log a corresponding activity-feed event.
- [definition-of-done.md](definition-of-done.md) — Capability-level DoD should be an executable check (e.g., grep/AST), not a checklist item.

---

## Storage

**File:** `.cc-sessions/carry-forward.jsonl`

- One JSON object per line. Never comma-separated, never a JSON array.
- Append-only. Updates are new lines with the same `id`; **latest-wins by `id`** when reducing.
- Readers reduce to latest state with:
  ```bash
  jq -s 'group_by(.id) | map(max_by(.ts))' .cc-sessions/carry-forward.jsonl
  ```
- Never rewrite prior lines. Corrections are a new line with a corrected state plus `event: "correction"` and `notes` explaining the prior mistake.
- The registry lives in the consumer project's `.cc-sessions/` directory, co-located with the activity feed. The blitz plugin source does not ship a registry file — it ships the *protocol* and the skill behaviors that read and write it.

---

## Entry Schema

Every line is a JSON object. Eight fields are **load-bearing** (required to detect silent drops). Three are **optional but cheap**.

```jsonc
{
  // Load-bearing (required)
  "id": "cf-<YYYY-MM-DD>-<slug>",       // Stable across updates; new lines use same id
  "ts": "<ISO-8601>",                    // Each line is uniquely timestamped
  "event": "created|progress|auto_waived|deferred|dropped|complete|revived|correction",
  "source": {
    "doc": "<relative-path-to-research-doc>",
    "anchor": "<markdown-anchor-or-line>"
  },
  "parent": {
    "capability": "<CAP-NNN>",
    "epic": "<E-NNN>"
  },
  "scope": {
    "unit": "files|components|routes|tests|endpoints|...",
    "target": <integer>,
    "description": "<human-readable scope>",
    "acceptance": [
      // Executable DoD checks — each must be verifiable in seconds
      { "grep_absent":  "<regex>" },
      { "grep_present": { "pattern": "<regex>", "min": <integer> } },
      { "ast_absent":   "<query>" },
      { "shell":        "<command>" }
    ]
  },
  "delivered": {
    "unit": "<same as scope.unit>",
    "actual": <integer>,
    "last_sprint": "sprint-<N>"
  },
  "coverage": <float 0.0 to 1.0>,        // Precomputed: delivered.actual / scope.target
  "status": "provisional|active|partial|complete|deferred|dropped|replaced",
  "last_touched": {
    "sprint": "sprint-<N>",
    "date": "<ISO-8601>"
  },

  // Optional but cheap
  "children":          ["<story-id>", ...],     // Sprint stories that advanced this entry
  "blocker":           "<reason or null>",      // GitHub-style "blocked by" note
  "drop_reason":       "<required if status=dropped>",
  "revival_candidate": true|false,              // Required if status=dropped; true means a future sprint should revisit
  "rollover_count":    <integer>,               // Incremented each sprint the entry remains status ∈ {active, partial}
  "provenance": {                               // S-1 (TB-2): integrity tag for startup-validate.sh
    "source":            "<skill-name|blitz-internal>", // WHO wrote this line (≠ scope `source` doc)
    "write_session":     "<SESSION_ID>",         // Session that wrote it; lets the validator trust same-repo entries
    "first_seen_sprint": "sprint-<N>"            // Anchors temporal-decoupling re-verification (research-critic §2.7)
  },
  "notes":             "<free text>"
}
```

### Field notes

- **`id` format** — kebab-case with a date stem for uniqueness: `cf-2026-04-02-modal-consistency`. Never reuse ids across distinct scope claims.
- **`event` enum** — describes *why this line was written*, not the resulting state. The resulting state is in `status`.
- **`source.anchor`** — a markdown heading anchor (`#scope`) or a line reference (`L142`). Required so readers can re-locate the original scope claim if the doc is edited.
- **`scope.acceptance`** — the executable DoD. Prefer `grep_absent` / `grep_present` / `shell` over prose — they can be run in `/blitz:review --only completeness` without human interpretation.
- **`coverage`** — precomputed on write. Dashboards and invariants must not re-derive it from prior lines; they read the latest-wins value directly.
- **`rollover_count`** — incremented by `sprint-review` at sprint close if `status ∈ {active, partial}` and the entry was not touched this sprint. Any entry with `rollover_count >= 3` escalates to mandatory human review instead of auto-injecting into the next sprint (prevents infinite bounce loops).
- **`provenance`** (S-1, TB-2) — integrity tag read by `hooks/scripts/startup-validate.sh`. Because a carry-forward entry **auto-injects into `sprint-plan`**, it is high-blast-radius persistent state (the article's AP-4; memory-poisoning literature's *temporally-decoupled* attack — a poisoned entry can trigger sprints later). `provenance.source` lets the validator distinguish entries written by a registered same-repo session from injected ones; `first_seen_sprint` anchors the re-verification cadence (`/blitz:next` re-runs `research-critic.md` §2.7 grounding on entries older than 2 sprints). Pre-S-1 entries lack this field — the validator treats its absence as a migration advisory, never a block. New writers MUST populate it. See [threat-model.md](threat-model.md) §3 TB-2.

---

## Status Enum (Lifecycle)

Adapted from Kubernetes KEP + Python PEP + Shortcut archiving lifecycles.

| Status | Meaning | Transition triggers |
|---|---|---|
| `provisional` | Entry exists but scope has not been formally accepted | `research` skill emits a scope block; roadmap hasn't ingested it yet |
| `active` | Accepted, in flight, has not yet been touched by a sprint | Roadmap extend ingests the scope; initial coverage is 0 |
| `partial` | Sprint delivered some but not all of the target | Any sprint touches `delivered.actual`; coverage > 0 and < 1.0 |
| `complete` | Coverage reached 1.0; DoD checks pass | `/blitz:review --only completeness` confirms all `scope.acceptance` checks pass |
| `deferred` | Explicitly pushed out with a reason; not counted against current-sprint invariants | Human or skill writes a `deferred` event with `notes` |
| `dropped` | Explicitly abandoned; `drop_reason` + `revival_candidate` required | Human writes a `dropped` event; default path for entries hitting `rollover_count >= 3` that cannot be completed |
| `replaced` | Superseded by a newer entry; `notes` must reference the replacement id | Research doc is updated with new scope; old entry is closed out |

**Invalid transitions** (must be caught by the writer):
- `complete → partial` — completion is a one-way door unless a new `replaced`/`created` pair is written
- `dropped → active` — revival must create a **new** entry and mark the old one `replaced`, not re-activate
- Any transition that sets `coverage >= 1.0` without `status == complete`

---

## Writers

Four skills write to the registry. Each writer is responsible for logging **both** a registry line **and** a matching `activity-feed.jsonl` event so cross-session observers see the transition.

### 1. `research` — emits provisional entries

When Phase 3 of the research skill identifies a quantified scope claim (regex `\d+\s+(files|components|modals|routes|tests|endpoints|...)` in findings or recommendation), it emits a `scope:` YAML frontmatter block in the research doc. The roadmap skill (below) later ingests this block.

Research itself does **not** write directly to `.cc-sessions/carry-forward.jsonl` — it only emits the YAML block. This keeps research docs self-contained in consumer projects and avoids double-writes.

### 2. `roadmap extend` — creates entries from ingested scope blocks

When `/blitz:roadmap extend` reads a research doc with a `scope:` block, it:
1. Generates a registry `id` derived from the doc date and slug.
2. Appends a `created` line with `status: active`, `delivered.actual: 0`, `coverage: 0.0`.
3. Records the new entry id in the affected epic's `registry_entries` field (see `roadmap/references/main.md`).

Roadmap `refresh` mode re-verifies existing entries against the current codebase: if the executable DoD checks now pass, it appends a `complete` line.

### 3. `sprint-plan` — auto-waivers write `partial` entries

When Phase 4.1 auto-waives uncovered acceptance criteria in `autonomy=full`:
1. Append an `auto_waived` line against the parent registry entry with `waived_count: N` and `reason: "autonomy=full"`.
2. If the entry's status was `active`, transition it to `partial`.
3. Compute and write updated `coverage = delivered.actual / scope.target`.
4. Log a corresponding `decision` event to the activity feed.

Phase 0 step 8 **reads** the registry (latest-wins reduction) and injects every `status ∈ {active, partial}` entry as a **mandatory** planning input, regardless of whether the parent epic's status is `done` in `epic-registry.json`. This closes the "epic marked done → next sprint ignores the waived scope" hole.

### 4. `sprint-review` — enforces invariants at sprint close

Phase 3.6 (registry invariants, hard gate) runs before the sprint can close. See **Invariants** below.

---

## Invariants (sprint-review Phase 3.6)

At sprint close, `sprint-review` reduces the registry to latest-wins state and enforces four hard gates. **Failing any one fails the sprint close.**

### Invariant 1 — Quantified scope claims have registry entries

For every research doc touched this sprint (any doc referenced by a story, epic, or capability in the sprint manifest), scan for quantified language (regex `\d+\s+(files|components|modals|routes|tests|endpoints|...)` in the first two pages, or any `scope:` YAML block).

- If a doc contains a quantified claim AND no matching registry entry exists → **FAIL**. Require the author to add a `scope:` block and re-run `roadmap extend`, or write an explicit `<!-- no-registry: <reason> -->` comment on the scope statement.
- If a doc already has a `scope:` block but no registry ingestion has occurred → **FAIL**. The author must run `roadmap extend` before sprint close.

### Invariant 2 — Active entries are touched or deferred

For every registry entry with `status ∈ {active, partial}`:
- If `last_touched.sprint == <current sprint>` → pass (entry was touched this sprint).
- Else if the latest line for the entry has `event: "deferred"` with a non-empty `notes` → pass (explicitly deferred).
- Else → **FAIL** and increment `rollover_count`. Require the author to either (a) link a story in this sprint that touched the entry, (b) write a `deferred` event with a reason, or (c) write a `dropped` event with `drop_reason` + `revival_candidate`.

Entries with `rollover_count >= 3` escalate: they must be resolved by human action before sprint close (no auto-inject into next sprint). This prevents infinite bounce loops.

### Invariant 3 — Roadmap completion claims match registry coverage

If `roadmap-registry.json` or `tracker.md` claims "N/N epics complete" or equivalent, cross-check:
- Every epic marked `status: done|complete` that has a `registry_entries` field must have every referenced entry at `status == complete` in the registry.
- Mismatch → **FAIL**. Print the delta: "Epic E-105 claims done, but cf-2026-04-02-modal-consistency is partial at 0.646 coverage."

### Invariant 4 — Uncompleted active entries auto-inject into next sprint

Any entry with `status == active` and `coverage < 1.0` is written to `sprints/sprint-(N+1)-planning-inputs.json` as a mandatory planning input. The next invocation of `sprint-plan` must select the parent epic and generate stories against the remaining uncovered scope, OR the operator must explicitly `defer` the entry before planning runs.

This is **Linear cycle semantics** — nothing silently falls out of view. The operator is always choosing between "work it," "defer it with a reason," or "drop it with a reason + revival decision."

---

## Reader Algorithm (canonical)

Every reader (sprint-plan Phase 0, sprint-review Phase 3.6, roadmap refresh, dashboards) MUST use this single algorithm. It consolidates Invariants 1–4 into one executable sequence, eliminating per-skill drift.

```bash
# Inputs:
#   $REG       — path to .cc-sessions/carry-forward.jsonl (default: ./.cc-sessions/carry-forward.jsonl)
#   $SPRINT    — current sprint number (e.g., "sprint-198")
#   $MODE      — "plan" | "review" | "audit"
#
# Outputs (file: ${SESSION_TMP_DIR}/registry-state.json):
#   { "active": [...], "partial": [...], "escalated": [...], "complete_this_sprint": [...] }
#
# Exit codes:
#   0 — registry consistent, output written
#   2 — INVARIANT FAILURE (block sprint close / planning); details in registry-state.json
#   3 — ESCALATION required (one or more entries hit rollover_count >= 3)

set -euo pipefail
REG="${REG:-.cc-sessions/carry-forward.jsonl}"
OUT="${SESSION_TMP_DIR}/registry-state.json"

# Step 1 — Reduce to latest-wins.
[ -s "$REG" ] || { echo "{}" > "$OUT"; exit 0; }
LATEST=$(jq -s 'group_by(.id) | map(max_by(.ts))' "$REG")

# Step 2 — Bucket by status.
echo "$LATEST" | jq '
  {
    active:   map(select(.status == "active")),
    partial:  map(select(.status == "partial")),
    deferred: map(select(.status == "deferred")),
    dropped:  map(select(.status == "dropped")),
    complete: map(select(.status == "complete"))
  }
' > "$OUT"

# Step 3 — Invariant 1 (provisional shouldn't exist post-roadmap-extend).
PROVISIONAL=$(echo "$LATEST" | jq '[.[] | select(.status == "provisional")] | length')
if [ "$PROVISIONAL" -gt 0 ] && [ "$MODE" != "audit" ]; then
  echo "INVARIANT 1 FAIL: $PROVISIONAL provisional entries — run /blitz:roadmap extend" >&2
  exit 2
fi

# Step 4 — Invariant 2 (active/partial entries touched-or-deferred this sprint).
STALE=$(echo "$LATEST" | jq --arg s "$SPRINT" '
  [.[] | select(
    (.status == "active" or .status == "partial") and
    .last_touched.sprint != $s and
    .event != "deferred"
  )]
')
STALE_COUNT=$(echo "$STALE" | jq 'length')
if [ "$STALE_COUNT" -gt 0 ] && [ "$MODE" == "review" ]; then
  echo "INVARIANT 2 FAIL: $STALE_COUNT entries not touched this sprint and not deferred" >&2
  echo "$STALE" | jq -r '.[] | "  - \(.id) (status=\(.status), last=\(.last_touched.sprint))"' >&2
  exit 2
fi

# Step 5 — Rollover ceiling escalation.
ESCALATED=$(echo "$LATEST" | jq '[.[] | select(.rollover_count >= 3 and (.status == "active" or .status == "partial"))]')
ESCALATED_COUNT=$(echo "$ESCALATED" | jq 'length')
if [ "$ESCALATED_COUNT" -gt 0 ]; then
  jq --argjson e "$ESCALATED" '. + {escalated: $e}' "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"
  if [ "$MODE" != "audit" ]; then
    echo "ESCALATION: $ESCALATED_COUNT entries at rollover_count >= 3 — human review required" >&2
    echo "$ESCALATED" | jq -r '.[] | "  - \(.id) (rollover=\(.rollover_count), parent=\(.parent.epic))"' >&2
    exit 3
  fi
fi

# Step 6 — Invariant 4 (auto-inject for next sprint planning).
if [ "$MODE" == "review" ]; then
  NEXT_SPRINT=$(echo "$SPRINT" | sed 's/sprint-//' | awk '{print "sprint-" $1+1}')
  PLANNING_INPUTS="sprints/${NEXT_SPRINT}-planning-inputs.json"
  echo "$LATEST" | jq '[.[] | select(.status == "active" and .coverage < 1.0)]' > "$PLANNING_INPUTS"
fi

# Step 7 — Activity feed event.
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "{\"ts\":\"$TS\",\"session\":\"${SESSION_ID:-unknown}\",\"skill\":\"${SKILL:-unknown}\",\"event\":\"registry_read\",\"message\":\"reader algorithm $MODE pass\",\"detail\":{\"active\":$(jq '.active | length' "$OUT"),\"partial\":$(jq '.partial | length' "$OUT"),\"escalated\":$ESCALATED_COUNT}}" \
  >> .cc-sessions/activity-feed.jsonl

exit 0
```

**Calling convention.**

| Caller | `MODE` | Treats exit 2 as | Treats exit 3 as |
|---|---|---|---|
| sprint-plan Phase 0 | `plan` | BLOCK planning; print remediation | BLOCK; require human waiver before continuing |
| sprint-review Phase 3.6 | `review` | INVARIANT FAILURE; sprint cannot close | ESCALATION; sprint cannot close |
| roadmap refresh | `audit` | Print warning; continue | Print warning; continue |
| dashboards | `audit` | Display in UI | Display with red badge |

**Why a single algorithm.** Prior versions split this across sprint-plan Phase 0 step 8, sprint-review Phase 3.6 Invariant 1–4, and roadmap refresh — three places, three slightly different threshold conventions. The CAP-133 incident traced back to two places implementing the rollover ceiling slightly differently, with the higher one in plan and the lower one in review. The algorithm above is now the only place these thresholds live; consumers shell out to it, period.

---

## Readers (jq one-liners)

For ad-hoc inspection outside the canonical algorithm, reduce the registry with `jq`:

```bash
# Latest-wins reduction
jq -s 'group_by(.id) | map(max_by(.ts))' .cc-sessions/carry-forward.jsonl

# All active entries
jq -s 'group_by(.id) | map(max_by(.ts)) | map(select(.status == "active" or .status == "partial"))' \
  .cc-sessions/carry-forward.jsonl

# Entries stalled for 2+ sprints
jq -s --arg sprint "sprint-42" '
  group_by(.id) | map(max_by(.ts))
  | map(select(.status == "partial" and .last_touched.sprint != $sprint and .rollover_count >= 2))
' .cc-sessions/carry-forward.jsonl

# Coverage by parent epic
jq -s 'group_by(.id) | map(max_by(.ts))
       | group_by(.parent.epic)
       | map({epic: .[0].parent.epic, entries: length,
              avg_coverage: (map(.coverage) | add / length)})' \
  .cc-sessions/carry-forward.jsonl
```

---

## Example: The Modal Standardization Incident (Backfilled)

This is the entry that would have existed if the registry had been in place when CAP-133 was first researched. Shown as three successive JSONL lines — the latest wins.

```jsonl
{"id":"cf-2026-04-02-modal-consistency","ts":"2026-04-02T10:00:00Z","event":"created","source":{"doc":"docs/_research/2026-04-02_modal-consistency.md","anchor":"#scope"},"parent":{"capability":"CAP-133","epic":"EPIC-105"},"scope":{"unit":"files","target":130,"description":"Migrate modal components to @mbk/ui Modal.vue","acceptance":[{"grep_absent":"class=\"modal-overlay\""},{"grep_absent":"from.*shared/ConfirmDialog"},{"grep_present":{"pattern":"from.*@mbk/ui.*Modal","min":30}}]},"delivered":{"unit":"files","actual":0,"last_sprint":null},"coverage":0.0,"status":"active","last_touched":{"sprint":null,"date":"2026-04-02"},"rollover_count":0,"notes":""}
{"id":"cf-2026-04-02-modal-consistency","ts":"2026-04-03T18:30:00Z","event":"progress","delivered":{"unit":"files","actual":84,"last_sprint":"sprint-197"},"coverage":0.646,"status":"partial","last_touched":{"sprint":"sprint-197","date":"2026-04-03"},"children":["S197-004"],"rollover_count":0,"notes":""}
{"id":"cf-2026-04-02-modal-consistency","ts":"2026-04-03T18:31:00Z","event":"auto_waived","waived_count":46,"reason":"autonomy=full auto-waiver at sprint-plan Phase 4.1","notes":"46 files uncovered — carry_forward in sprint-197 manifest"}
```

**With the registry and invariants in place**, sprint-198's planner would have seen the `partial`/`active` entry in its mandatory planning inputs and generated stories against the remaining 46 files. Sprint-197's review would have incremented `rollover_count`, and if sprint-198 also failed to close it, sprint-199 review would have escalated to mandatory human review at `rollover_count == 3`. No silent drop is possible.

---

## Backfilling Legacy Research Docs

Consumer projects that adopted blitz before the carry-forward registry shipped will have research docs that predate the `scope:` YAML convention. A common case: `docs/_research/2026-04-02_modal-consistency.md` says "migrate 130 modal files" in prose, but has no frontmatter block. Its parent epic may already be marked `done` while real coverage sits at ~64%. Backfill is how you reconcile.

**Canonical backfill procedure** (one doc at a time):

1. **Open the legacy research doc** in an editor. Scan Summary / Findings / Recommendation for quantified claims.

2. **Add a `scope:` YAML frontmatter block** at the very top of the file, above the `# <title>` heading. Use best-guess values for unit, target, and acceptance checks — the recompute step will correct the delivered counts:
   ```yaml
   ---
   scope:
     - id: cf-YYYY-MM-DD-<short-slug>     # Use the doc's date as the stem
       unit: files
       target: 130                         # The number from the original prose claim
       description: |
         <Quote the original scope statement from the doc>
       acceptance:
         - grep_absent: '<legacy pattern that should disappear>'
         - grep_present:
             pattern: '<new pattern that should appear>'
             min: <integer>
   ---
   ```

3. **Run `/blitz:roadmap refresh`.** Two things happen automatically:
   - **Phase 1.1.5** ingests the new `scope:` block and writes a `created` line to `.cc-sessions/carry-forward.jsonl` with `status: active, delivered.actual: 0`.
   - **Phase 2.4** runs the acceptance checks against the current codebase and appends a `progress` (or `complete`) line with the real `delivered.actual` and `coverage`.

4. **Verify the reconciliation.** Reduce the registry with `jq` and confirm the entry reflects true state:
   ```bash
   jq -s 'group_by(.id) | map(max_by(.ts)) | map(select(.id == "cf-YYYY-MM-DD-<slug>"))' \
     .cc-sessions/carry-forward.jsonl
   ```
   If `coverage` is `1.0` and `status` is `complete`, the legacy work was already fully shipped — no further action needed. The next `sprint-review` will honor this and the parent epic can close cleanly.
   If `coverage < 1.0`, the remaining scope is now visible to `sprint-plan` Phase 0 step 8 and will auto-inject into the next sprint's planning inputs. The previously-silent drop is now loud.

5. **Optionally, run `/blitz:sprint --loop`.** With backfilled registry state, the loop's Step 2 decision tree will either exit idle cleanly (if everything is `complete`) or dispatch a gap-closure sprint against the remaining scope. Either way, the prior incoherent state is resolved.

**Multi-doc backfill:** There is no bulk backfill command. Each legacy doc must be edited individually because only a human can translate "130 files in the prose" into a meaningful acceptance check. This is intentional — a sloppy bulk backfill would defeat the point of the registry (loudly visible scope). Walk the docs one at a time, run refresh after each, and sanity-check the registry delta. Expect 5-15 minutes per doc.

**Edge case — the work is already done.** If the backfill recompute immediately sets `status: complete` and the parent epic is also `done`, no story needs to be planned; the registry just catches up with reality. Log a `backfilled` event note so the audit trail is clear.

**Edge case — the work was silently dropped.** If the backfill recompute yields `coverage < 1.0` on an epic that roadmap-registry claims is done, that's exactly the CAP-133 incident. `sprint-review` Invariant 3 will fail on the next review run, forcing the operator to either (a) reopen the epic and plan gap-closure stories, or (b) write an explicit `deferred` or `dropped` event on the registry entry with a reason. The state-machine no longer silently tolerates mismatch.

---

## Anti-Patterns (Don't)

- **Don't rewrite prior lines.** Corrections are new lines with `event: "correction"`. The audit trail is the point.
- **Don't batch registry writes outside a writer's own transaction.** Each writer (research, roadmap, sprint-plan, sprint-review) writes its own lines atomically.
- **Don't skip the activity-feed companion event.** The registry is the machine-readable state; the activity feed is the human-readable timeline. Both must be updated.
- **Don't treat `deferred` as permanent.** Deferred entries must reappear in planning inputs at a specified revisit sprint or date, tracked in `notes`.
- **Don't mark `status: complete` without running the `scope.acceptance` checks.** `/blitz:review --only completeness` is the authority — never self-mark.
- **Don't auto-revive `dropped` entries.** Revival is always a fresh `created` line with a new `id` and a `replaced` transition on the old one.


## Related protocols

- [/_shared/terse-output.md](/_shared/terse-output.md) — output-style directive. All content this protocol produces (reports, checkpoints, logs) should follow it.
