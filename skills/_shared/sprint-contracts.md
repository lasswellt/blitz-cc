# Sprint Contracts

Consolidated blitz protocol. **Absorbs** (2026-06-06 `_shared` consolidation) 5 former files; each appears below as a top-level section with original sub-headings preserved as anchor targets. Inbound `oldfile.md#anchor` links were mechanically rewritten to `sprint-contracts.md#anchor`.

| Former file | Section |
|---|---|
| `carry-forward-registry.md` | [Carry-Forward Registry Protocol](#carry-forward-registry-protocol) |
| `story-frontmatter.md` | [Story Frontmatter Contract](#story-frontmatter-contract) |
| `definition-of-done.md` | [Definition of Done](#definition-of-done) |
| `deviation-protocol.md` | [Deviation Handling Protocol](#deviation-handling-protocol) |
| `scope-limit-protocol.md` | [SCOPE-LIMIT.md Protocol](#scope-limitmd-protocol) |

**Related:** the compaction/resume **state-handoff contract** lives in [`session-lifecycle.md`](session-lifecycle.md#state-handoff-contract) (one home; it is the session/resume contract, cross-linked here because sprint artifacts are its primary payload).


---

<!-- ===== Absorbed from carry-forward-registry.md ===== -->

## Carry-Forward Registry Protocol

Shared reference for the **carry-forward registry** — an append-only JSONL ledger that links research-doc scope claims to delivered artifacts across sprints. Its purpose is to make silent scope drops impossible: any promised scope that hasn't been delivered remains loudly visible until it is completed, explicitly deferred, or dropped with a reason.

**Motivation:** see `docs/_research/2026-04-08_sprint-carryforward-registry.md` for the full incident analysis, industry precedent (Linear cycles, KEP lifecycles, PEP status headers, Shortcut archiving, Jira rightmost-column close, burn-up charts), and design rationale. The short version: when `sprint-plan` auto-waives uncovered acceptance criteria in `full` autonomy, the waiver currently lives only in the sprint manifest's `carry_forward` array, which the next sprint's planner never reads. The registry is the fix.

**Companion protocols:**
- [session-lifecycle.md](session-lifecycle.md) — Multi-session safety. The registry follows the same append-only convention as `.cc-sessions/activity-feed.jsonl`.
- [terse-output.md](terse-output.md) — Every registry write must also log a corresponding activity-feed event.
- [definition-of-done.md](#definition-of-done) — Capability-level DoD should be an executable check (e.g., grep/AST), not a checklist item.

---

### Storage

**File:** `.cc-sessions/carry-forward.jsonl`

- One JSON object per line. Never comma-separated, never a JSON array.
- Append-only. Updates are new lines with the same `id`; reducing **field-merges in `ts` order** (latest non-null value wins per field). A line need only carry the fields it changes.
- Readers reduce to latest state with (canonical — **field-merge**, not `max_by`):
  ```bash
  jq -s 'group_by(.id) | map(sort_by(.ts) | reduce .[] as $x ({}; . * $x))' \
    .cc-sessions/carry-forward.jsonl
  ```
  Field-merge is load-bearing: writers emit **thin delta lines** (`progress` carries `delivered`/`coverage`/`status`; `correction` carries just `parent` or `rollover_count`; `auto_waived` carries `waived_count`). A naïve `map(max_by(.ts))` reader would take the whole latest object and NULL every field the delta omits (`status`, `scope`, `coverage`) — silently dropping the entry. The deep-merge (`. * $x`) preserves earlier fields and overlays later ones.
- Never rewrite prior lines. Corrections are a new delta line with `event: "correction"` (carrying only the changed fields) plus `notes` explaining the prior mistake; the field-merge preserves everything else.
- The registry lives in the consumer project's `.cc-sessions/` directory, co-located with the activity feed. The blitz plugin source does not ship a registry file — it ships the *protocol* and the skill behaviors that read and write it.

---

### Entry Schema

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

#### Field notes

- **`id` format** — kebab-case with a date stem for uniqueness: `cf-2026-04-02-modal-consistency`. Never reuse ids across distinct scope claims.
- **`event` enum** — describes *why this line was written*, not the resulting state. The resulting state is in `status`.
- **`source.anchor`** — a markdown heading anchor (`#scope`) or a line reference (`L142`). Required so readers can re-locate the original scope claim if the doc is edited.
- **`scope.acceptance`** — the executable DoD. Prefer `grep_absent` / `grep_present` / `shell` over prose — they can be run in `/blitz:review --only completeness` without human interpretation.
- **`coverage`** — precomputed on write. Dashboards and invariants must not re-derive it from prior lines; they read the latest-wins value directly.
- **`rollover_count`** — incremented by `sprint-review` at sprint close if `status ∈ {active, partial}` and the entry was not touched this sprint. Any entry with `rollover_count >= 3` escalates to mandatory human review instead of auto-injecting into the next sprint (prevents infinite bounce loops).
- **`provenance`** (S-1, TB-2) — integrity tag read by `hooks/scripts/startup-validate.sh`. Because a carry-forward entry **auto-injects into `sprint-plan`**, it is high-blast-radius persistent state (the article's AP-4; memory-poisoning literature's *temporally-decoupled* attack — a poisoned entry can trigger sprints later). `provenance.source` lets the validator distinguish entries written by a registered same-repo session from injected ones; `first_seen_sprint` anchors the re-verification cadence (`/blitz:next` re-runs `research-critic.md` §2.7 grounding on entries older than 2 sprints). Pre-S-1 entries lack this field — the validator treats its absence as a migration advisory, never a block. New writers MUST populate it. See [threat-model.md](security.md) §3 TB-2.

---

### Status Enum (Lifecycle)

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

### Writers

Four skills write to the registry. Each writer is responsible for logging **both** a registry line **and** a matching `activity-feed.jsonl` event so cross-session observers see the transition.

#### 1. `research` — emits provisional entries

When Phase 3 of the research skill identifies a quantified scope claim (regex `\d+\s+(files|components|modals|routes|tests|endpoints|...)` in findings or recommendation), it emits a `scope:` YAML frontmatter block in the research doc. The roadmap skill (below) later ingests this block.

Research itself does **not** write directly to `.cc-sessions/carry-forward.jsonl` — it only emits the YAML block. This keeps research docs self-contained in consumer projects and avoids double-writes.

#### 2. `roadmap extend` — creates entries from ingested scope blocks

When `/blitz:roadmap extend` reads a research doc with a `scope:` block, it:
1. Generates a registry `id` derived from the doc date and slug.
2. Appends a `created` line with `status: active`, `delivered.actual: 0`, `coverage: 0.0`.
3. Records the new entry id in the affected epic's `registry_entries` field (see `roadmap/references/main.md`).

Roadmap `refresh` mode re-verifies existing entries against the current codebase: if the executable DoD checks now pass, it appends a `complete` line.

#### 3. `sprint-plan` — auto-waivers write `partial` entries

When Phase 4.1 auto-waives uncovered acceptance criteria in `autonomy=full`:
1. Append an `auto_waived` line against the parent registry entry with `waived_count: N` and `reason: "autonomy=full"`.
2. If the entry's status was `active`, transition it to `partial`.
3. Compute and write updated `coverage = delivered.actual / scope.target`.
4. Log a corresponding `decision` event to the activity feed.

Phase 0 step 8 **reads** the registry (latest-wins reduction) and injects every `status ∈ {active, partial}` entry as a **mandatory** planning input, regardless of whether the parent epic's status is `done` in `epic-registry.json`. This closes the "epic marked done → next sprint ignores the waived scope" hole.

#### 4. `sprint-review` — enforces invariants at sprint close

Phase 3.6 (registry invariants, hard gate) runs before the sprint can close. See **Invariants** below.

---

### Invariants (sprint-review Phase 3.6)

At sprint close, `sprint-review` reduces the registry to latest-wins state and enforces four hard gates. **Failing any one fails the sprint close.**

#### Invariant 1 — Quantified scope claims have registry entries

For every research doc touched this sprint (any doc referenced by a story, epic, or capability in the sprint manifest), scan for quantified language (regex `\d+\s+(files|components|modals|routes|tests|endpoints|...)` in the first two pages, or any `scope:` YAML block).

- If a doc contains a quantified claim AND no matching registry entry exists → **FAIL**. Require the author to add a `scope:` block and re-run `roadmap extend`, or write an explicit `<!-- no-registry: <reason> -->` comment on the scope statement.
- If a doc already has a `scope:` block but no registry ingestion has occurred → **FAIL**. The author must run `roadmap extend` before sprint close.

#### Invariant 2 — Active entries are touched or deferred

For every registry entry with `status ∈ {active, partial}`:
- If `last_touched.sprint == <current sprint>` → pass (entry was touched this sprint).
- Else if the latest line for the entry has `event: "deferred"` with a non-empty `notes` → pass (explicitly deferred).
- Else → **FAIL** and increment `rollover_count`. Require the author to either (a) link a story in this sprint that touched the entry, (b) write a `deferred` event with a reason, or (c) write a `dropped` event with `drop_reason` + `revival_candidate`.

Entries with `rollover_count >= 3` escalate: they must be resolved by human action before sprint close (no auto-inject into next sprint). This prevents infinite bounce loops.

#### Invariant 3 — Roadmap completion claims match registry coverage

If `roadmap-registry.json` or `tracker.md` claims "N/N epics complete" or equivalent, cross-check:
- Every epic marked `status: done|complete` that has a `registry_entries` field must have every referenced entry at `status == complete` in the registry.
- Mismatch → **FAIL**. Print the delta: "Epic E-105 claims done, but cf-2026-04-02-modal-consistency is partial at 0.646 coverage."

#### Invariant 4 — Uncompleted active entries auto-inject into next sprint

Any entry with `status == active` and `coverage < 1.0` is written to `sprints/sprint-(N+1)-planning-inputs.json` as a mandatory planning input. The next invocation of `sprint-plan` must select the parent epic and generate stories against the remaining uncovered scope, OR the operator must explicitly `defer` the entry before planning runs.

This is **Linear cycle semantics** — nothing silently falls out of view. The operator is always choosing between "work it," "defer it with a reason," or "drop it with a reason + revival decision."

---

### Reader Algorithm (canonical)

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
LATEST=$(jq -s 'group_by(.id) | map(sort_by(.ts) | reduce .[] as $x ({}; . * $x))' "$REG")

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

### Readers (jq one-liners)

For ad-hoc inspection outside the canonical algorithm, reduce the registry with `jq`:

```bash
# Latest-wins reduction
jq -s 'group_by(.id) | map(sort_by(.ts) | reduce .[] as $x ({}; . * $x))' .cc-sessions/carry-forward.jsonl

# All active entries
jq -s 'group_by(.id) | map(sort_by(.ts) | reduce .[] as $x ({}; . * $x)) | map(select(.status == "active" or .status == "partial"))' \
  .cc-sessions/carry-forward.jsonl

# Entries stalled for 2+ sprints
jq -s --arg sprint "sprint-42" '
  group_by(.id) | map(sort_by(.ts) | reduce .[] as $x ({}; . * $x))
  | map(select(.status == "partial" and .last_touched.sprint != $sprint and .rollover_count >= 2))
' .cc-sessions/carry-forward.jsonl

# Coverage by parent epic
jq -s 'group_by(.id) | map(sort_by(.ts) | reduce .[] as $x ({}; . * $x))
       | group_by(.parent.epic)
       | map({epic: .[0].parent.epic, entries: length,
              avg_coverage: (map(.coverage) | add / length)})' \
  .cc-sessions/carry-forward.jsonl
```

---

### Example: The Modal Standardization Incident (Backfilled)

This is the entry that would have existed if the registry had been in place when CAP-133 was first researched. Shown as three successive JSONL lines — the latest wins.

```jsonl
{"id":"cf-2026-04-02-modal-consistency","ts":"2026-04-02T10:00:00Z","event":"created","source":{"doc":"docs/_research/2026-04-02_modal-consistency.md","anchor":"#scope"},"parent":{"capability":"CAP-133","epic":"EPIC-105"},"scope":{"unit":"files","target":130,"description":"Migrate modal components to @mbk/ui Modal.vue","acceptance":[{"grep_absent":"class=\"modal-overlay\""},{"grep_absent":"from.*shared/ConfirmDialog"},{"grep_present":{"pattern":"from.*@mbk/ui.*Modal","min":30}}]},"delivered":{"unit":"files","actual":0,"last_sprint":null},"coverage":0.0,"status":"active","last_touched":{"sprint":null,"date":"2026-04-02"},"rollover_count":0,"notes":""}
{"id":"cf-2026-04-02-modal-consistency","ts":"2026-04-03T18:30:00Z","event":"progress","delivered":{"unit":"files","actual":84,"last_sprint":"sprint-197"},"coverage":0.646,"status":"partial","last_touched":{"sprint":"sprint-197","date":"2026-04-03"},"children":["S197-004"],"rollover_count":0,"notes":""}
{"id":"cf-2026-04-02-modal-consistency","ts":"2026-04-03T18:31:00Z","event":"auto_waived","waived_count":46,"reason":"autonomy=full auto-waiver at sprint-plan Phase 4.1","notes":"46 files uncovered — carry_forward in sprint-197 manifest"}
```

**With the registry and invariants in place**, sprint-198's planner would have seen the `partial`/`active` entry in its mandatory planning inputs and generated stories against the remaining 46 files. Sprint-197's review would have incremented `rollover_count`, and if sprint-198 also failed to close it, sprint-199 review would have escalated to mandatory human review at `rollover_count == 3`. No silent drop is possible.

---

### Backfilling Legacy Research Docs

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
   jq -s 'group_by(.id) | map(sort_by(.ts) | reduce .[] as $x ({}; . * $x)) | map(select(.id == "cf-YYYY-MM-DD-<slug>"))' \
     .cc-sessions/carry-forward.jsonl
   ```
   If `coverage` is `1.0` and `status` is `complete`, the legacy work was already fully shipped — no further action needed. The next `sprint-review` will honor this and the parent epic can close cleanly.
   If `coverage < 1.0`, the remaining scope is now visible to `sprint-plan` Phase 0 step 8 and will auto-inject into the next sprint's planning inputs. The previously-silent drop is now loud.

5. **Optionally, run `/blitz:sprint --loop`.** With backfilled registry state, the loop's Step 2 decision tree will either exit idle cleanly (if everything is `complete`) or dispatch a gap-closure sprint against the remaining scope. Either way, the prior incoherent state is resolved.

**Multi-doc backfill:** There is no bulk backfill command. Each legacy doc must be edited individually because only a human can translate "130 files in the prose" into a meaningful acceptance check. This is intentional — a sloppy bulk backfill would defeat the point of the registry (loudly visible scope). Walk the docs one at a time, run refresh after each, and sanity-check the registry delta. Expect 5-15 minutes per doc.

**Edge case — the work is already done.** If the backfill recompute immediately sets `status: complete` and the parent epic is also `done`, no story needs to be planned; the registry just catches up with reality. Log a `backfilled` event note so the audit trail is clear.

**Edge case — the work was silently dropped.** If the backfill recompute yields `coverage < 1.0` on an epic that roadmap-registry claims is done, that's exactly the CAP-133 incident. `sprint-review` Invariant 3 will fail on the next review run, forcing the operator to either (a) reopen the epic and plan gap-closure stories, or (b) write an explicit `deferred` or `dropped` event on the registry entry with a reason. The state-machine no longer silently tolerates mismatch.

---

### Anti-Patterns (Don't)

- **Don't rewrite prior lines.** Corrections are new lines with `event: "correction"`. The audit trail is the point.
- **Don't batch registry writes outside a writer's own transaction.** Each writer (research, roadmap, sprint-plan, sprint-review) writes its own lines atomically.
- **Don't skip the activity-feed companion event.** The registry is the machine-readable state; the activity feed is the human-readable timeline. Both must be updated.
- **Don't treat `deferred` as permanent.** Deferred entries must reappear in planning inputs at a specified revisit sprint or date, tracked in `notes`.
- **Don't mark `status: complete` without running the `scope.acceptance` checks.** `/blitz:review --only completeness` is the authority — never self-mark.
- **Don't auto-revive `dropped` entries.** Revival is always a fresh `created` line with a new `id` and a `replaced` transition on the old one.


### Related protocols

- [/_shared/terse-output.md](/_shared/terse-output.md) — output-style directive. All content this protocol produces (reports, checkpoints, logs) should follow it.



---

<!-- ===== Absorbed from story-frontmatter.md ===== -->

## Story Frontmatter Contract

Canonical YAML frontmatter schema for sprint stories. Single source of truth for the producer (`sprint-plan`) and consumers (`sprint-dev`, `sprint-review`, `quick`, gap-closure path).

**Why this doc exists.** The schema previously lived in `skills/sprint-plan/reference.md` Story File Format section, but consumers cited it indirectly. When sprint-plan emitted a field, sprint-dev had no shared spec to validate against; when sprint-dev expected a field, sprint-plan had no shared spec to enforce. This file is the single authoritative contract — both producer and consumer link here.

**Companion protocols:**
- [carry-forward-registry.md](#carry-forward-registry-protocol) — Defines `registry_entries` semantics and the writer contract.
- [session-lifecycle.md](session-lifecycle.md) — Defines which file consumes which field, end-to-end across the sprint pipeline.
- [definition-of-done.md](#definition-of-done) — `done:` and `verify:` fields are executable DoD checks.

---

### File path & naming

```
sprints/sprint-${SPRINT_NUMBER}/stories/S${SPRINT_NUMBER}-${SEQ}-<slug>.md
```

- `${SPRINT_NUMBER}`: integer (1, 2, …); no zero padding on the directory.
- `${SEQ}`: zero-padded 3-digit sequence within the sprint (`001`, `002`, …, `999`). Gap-closure stories use the `G` prefix: `G001`, `G002`, ….
- `<slug>`: kebab-case, ≤ 6 words, derived from `title:`.
- The filename `id` segment (`S${SPRINT_NUMBER}-${SEQ}`) MUST equal the `id:` frontmatter field.

---

### Canonical Schema (standard story)

```yaml
---
# ─── Identity (required) ─────────────────────────────────────────────────
id: "S1-001"                          # Sprint number + zero-padded seq
title: "Create user profile schema"   # Imperative, ≤ 80 chars
epic: "E003"                          # Parent epic ID from epic-registry.json
type: "standard"                      # standard | gap-closure | spike

# ─── Lifecycle (required) ────────────────────────────────────────────────
status: "planned"                     # planned | in-progress | done | blocked | dropped
priority: "high"                      # high | medium | low
points: 3                             # Fibonacci: 1, 2, 3, 5, 8

# ─── Dependencies & assignment (required) ────────────────────────────────
depends_on: []                        # Story ids this blocks on (e.g., ["S1-000"])
assigned_agent: "backend-dev"         # backend-dev | frontend-dev | test-writer | infra-dev

# ─── Scope contract (required) ───────────────────────────────────────────
files:                                # Files this story creates or modifies
  - "src/models/user-profile.ts"
verify:                               # Shell commands; ALL must pass for done
  - "npx tsc --noEmit"
  - "npx vitest run src/schemas/user-profile.test.ts"
done: "UserProfile schema exists, validates correctly, and has passing tests"

# ─── Tracing (required) ──────────────────────────────────────────────────
research_refs: []                     # Format: "<agent-role>:<finding-anchor>"
github_issue: null                    # Populated after issue creation
carry_forward: false                  # true if rolled over from a previous sprint

# ─── Registry link (optional but recommended) ────────────────────────────
registry_entries:                     # Carry-forward registry ids this story advances
  - id: "cf-2026-04-02-modal-consistency"
    delta: 10                         # Integer units toward scope.target

# ─── Acceptance checks (optional; consumed by critic + sprint-review) ────
acceptance_checks:                    # Executable predicates; ALL must pass before PASS
  - type: "grep_present"
    pattern: "export.*useUserProfileStore"
    file: "src/stores/user-profile.ts"
    min: 1
    message: "store must export useUserProfileStore"
  - type: "grep_absent"
    pattern: "TODO|FIXME|Not implemented"
    file: "src/stores/user-profile.ts"
    message: "no placeholders in store"
  - type: "shell"
    command: "npx tsc --noEmit 2>&1 | grep -c 'error TS' || true"
    assert_eq: "0"
    message: "zero type errors"
  - type: "ast_absent"
    node: "TSAsExpression[typeAnnotation.type='TSAnyKeyword']"
    file: "src/stores/user-profile.ts"
    message: "no `as any` in store"

# ─── Design quality (optional; consumed by ui-build Phase 5.4.2) ─────────
design_quality: "skip"                # skip | standard | high — drives design-critic spawning

# ─── Source traceability (gap-closure only) ──────────────────────────────
source_finding:                       # OMIT unless type == "gap-closure"
  report: "sprint-review"             # sprint-review | review | STATE.md
  severity: "high"                    # high | medium | low
  description: "Original finding text"
---
```

---

### Field Contract (Producer / Consumer Matrix)

Required = R, Optional = O, Conditional = C (required iff condition).

| Field | Type | Producer (writer) | Consumer (reader) | R/O |
|---|---|---|---|---|
| `id` | string | sprint-plan Phase 3.2 | sprint-dev (worktree naming, registry write), sprint-review (story status sweep) | R |
| `title` | string | sprint-plan Phase 3.2 | sprint-dev (commit messages), sprint-review (report) | R |
| `epic` | string | sprint-plan Phase 3.2 | sprint-dev (epic-registry lookup), sprint-review (Invariant 3) | R |
| `type` | enum | sprint-plan Phase 3.2 | sprint-dev (assignment), sprint-review (gap-closure handling) | R |
| `status` | enum | sprint-plan (= `planned`); sprint-dev (`in-progress`/`done`/`blocked`); sprint-review (`done`/`dropped`) | All sprint-family skills | R |
| `priority` | enum | sprint-plan Phase 3.2 | sprint-dev (wave ordering tie-break) | R |
| `points` | int | sprint-plan Phase 3.2 | sprint-review (velocity report), quality-metrics | R |
| `depends_on` | string[] | sprint-plan Phase 3.4 (dependency graph) | sprint-dev (wave computation) | R |
| `assigned_agent` | enum | sprint-plan Phase 3.3 (partition logic) | sprint-dev (agent dispatch) | R |
| `files` | string[] | sprint-plan Phase 3.2 | sprint-dev (worktree scope), sprint-review (file-touched audit), code-sweep | R |
| `verify` | string[] | sprint-plan Phase 3.2 | sprint-dev (story-done gate), review | R |
| `done` | string | sprint-plan Phase 3.2 | sprint-review (acceptance) | R |
| `research_refs` | string[] | sprint-plan Phase 3.2 | sprint-dev (read findings during impl), sprint-review (Invariant 1) | R |
| `github_issue` | int\|null | sprint-plan Phase 4.4 (after issue create); never sprint-dev | sprint-review (link in report), ship | R (nullable) |
| `carry_forward` | bool | sprint-plan Phase 0 step 8 (if injected from prior sprint) | sprint-review Phase 3.6 Invariant 4 (cross-check) | R |
| `registry_entries` | object[] | sprint-plan Phase 4.1 (link stories to scope) | sprint-dev Phase 3.2 step 1a (writes `progress` event) | O |
| `registry_entries[*].id` | string | sprint-plan | sprint-dev (registry id validation; hard-fail on unknown) | R if `registry_entries` present |
| `registry_entries[*].delta` | int | sprint-plan | sprint-dev (passed as `delivered.actual` increment) | O (defaults to `len(files)`) |
| `source_finding` | object | sprint-plan `--gaps` mode | sprint-review (gap-closure traceability) | C (required iff `type == "gap-closure"`) |
| `acceptance_checks` | object[] | sprint-plan Phase 3.2 (recommended), or sprint-dev Phase 3 if missing and adding | `agents/critic.md` §2.5, `sprint-review` Phase 3.6 Invariant 7 (executable predicates) | O |
| `acceptance_checks[*].type` | enum | sprint-plan / sprint-dev | critic + sprint-review (dispatcher) | R if `acceptance_checks` present |
| `acceptance_checks[*].message` | string | sprint-plan / sprint-dev | critic (failure surfacing) | R if `acceptance_checks` present |
| `design_quality` | enum | sprint-plan (UI stories only) | `ui-build` Phase 5.4.2 (design-critic spawning) | O (default `skip`) |

**Producer hard rules.** `sprint-plan` is the only skill that creates story files. `sprint-dev` may transition `status` and append a `progress_notes` block to the body, but MUST NOT add or remove frontmatter fields outside `status`, `github_issue`, `progress_notes`, and `acceptance_checks` (sprint-dev MAY add executable checks if absent and the implementation has settled). `sprint-review` may transition `status` to `done` or `dropped` only.

#### Acceptance check types

The four `type:` values map to executable predicates. Critic (`agents/critic.md` §2.5) and sprint-review Phase 3.6 Invariant 7 dispatch on `type` and run each in turn. Failure of any check → REJECT verdict.

| Type | Required fields | Optional fields | Predicate |
|---|---|---|---|
| `grep_present` | `pattern`, `file` | `min` (default 1) | `grep -cE '<pattern>' <file>` returns count `≥ min` |
| `grep_absent` | `pattern`, `file` | — | `grep -E '<pattern>' <file>` returns no match (exit 1) |
| `shell` | `command`, `assert_eq` | — | running `<command>` produces stdout exactly equal to `<assert_eq>` (after rstrip) |
| `ast_absent` | `node`, `file` | — | tree-sitter / AST query for `<node>` on `<file>` returns zero matches |

`grep_present` accepts directories in `file:` (recurses with `-r`).

`message:` is required on every entry — it's the human-readable surface text the critic uses when reporting REJECT.

#### Validator implementation

Reference implementation lives in `agents/critic.md` §2.5 (consumes the schema) and the spec for sprint-review Phase 3.6 Invariant 7 (`skills/sprint-review/references/main.md`). Skills MAY emit additional check types via prefix `x-<vendor>-<type>` — unknown prefixes are skipped with a warning, not failed.

#### Wiring with `verify:`

`verify:` is a story-local pre-commit gate (sprint-dev story-done check). `acceptance_checks:` is a critic-level pre-PASS gate (sprint-review). They overlap intentionally: `verify:` ensures the story implementation passes its own tests; `acceptance_checks:` ensures the artifact contains the right shape (specific symbols exported, no `as any`, etc.). Both must pass for sprint PASS; failure surfaces at different phases.

**Consumer hard rules.** Consumers MUST treat unknown fields as forward-compatible (don't reject), but MUST hard-fail on missing required fields. The `registry_entries` inference fallback (parent-epic pro-rata with `delta: 1`) lives in sprint-dev Phase 3.2 step 1a — see [carry-forward-registry.md](#carry-forward-registry-protocol) §Writers.

---

### Body sections (required for `type: "standard"`)

```markdown
## Description
2-4 sentences explaining what this story delivers and why it matters.

## Acceptance Criteria
1. [ ] Specific, testable criterion one
2. [ ] Specific, testable criterion two

## Implementation Notes
- Key patterns to follow (reference existing code)
- Imports and dependencies needed
- Research findings that inform the approach

## Code Snippets
```typescript
// Starter type definition, function signature, or test skeleton
```

## Dependencies
- Blocks on: S1-000 (reason)
- Blocked by: nothing
```

For `type: "gap-closure"`, replace with:

```markdown
## Finding
<Original finding from the review/gate report>

## Root Cause
<Why this gap exists>

## Fix
<Specific change to make, referencing existing code patterns>

## Verification
<How to confirm the fix addresses the finding>
```

---

### Validation algorithm (sprint-dev Phase 0)

Sprint-dev MUST validate each story file before dispatching to agents. Hard-fail on any of the following:

```bash
# 1. Filename matches id field
basename "$story" .md | cut -d- -f1-2 == $(yq '.id' "$story")

# 2. All required fields present and non-empty
for field in id title epic type status priority points depends_on assigned_agent files verify done research_refs github_issue carry_forward; do
  yq -e ".${field}" "$story" >/dev/null || die "Missing required field: ${field}"
done

# 3. assigned_agent is in the recognized set
yq '.assigned_agent' "$story" =~ ^(backend-dev|frontend-dev|test-writer|infra-dev)$

# 4. depends_on entries reference real stories in this sprint
for dep in $(yq '.depends_on[]' "$story"); do
  test -f "sprints/sprint-${SPRINT}/stories/${dep}-"*.md || die "Dangling depends_on: ${dep}"
done

# 5. registry_entries[*].id values exist in .cc-sessions/carry-forward.jsonl
for rid in $(yq '.registry_entries[].id' "$story"); do
  jq -se --arg id "$rid" 'group_by(.id) | map(sort_by(.ts) | reduce .[] as $x ({}; . * $x)) | map(select(.id == $id)) | length > 0' \
    .cc-sessions/carry-forward.jsonl || die "Unknown registry id: ${rid}"
done

# 6. source_finding present iff type == gap-closure
[[ "$(yq '.type' "$story")" == "gap-closure" ]] && yq -e '.source_finding' "$story" >/dev/null
```

Validation failures are **BLOCKER** — sprint-dev MUST NOT dispatch any story until all stories in the sprint pass. Report all failures together; do not abort on the first.

---

### Anti-patterns

- **Don't create stories outside sprint-plan.** Manual story creation bypasses the partition logic, dependency graph, and registry linkage. If gap stories are needed mid-sprint, run `/blitz:sprint-plan --gaps`.
- **Don't promote `progress_notes` to frontmatter.** Body section, not metadata.
- **Don't omit `verify:` in favor of "see done field".** Verify is the executable contract; done is the human-readable summary.
- **Don't use `assigned_agent: "any"` or `null`.** The partition is deterministic — pick a role.
- **Don't skip `registry_entries` for stories that contribute to a quantified scope claim.** The inference fallback exists for safety, not as the default path. Sprint-review Invariant 2 will flag epics whose registry entries are stuck at `partial` because no story explicitly claimed delta.

---

### Related protocols

- [/_shared/terse-output.md](terse-output.md) — output-style directive. Story body sections are user-facing; follow LITE intensity.



---

<!-- ===== Absorbed from definition-of-done.md ===== -->

## Definition of Done

Universal checklist every code-producing skill and agent must verify before marking work complete.

---

### Functional Completeness

- [ ] Every function is fully implemented with real logic
- [ ] Every acceptance criterion from the story/task is addressed
- [ ] Feature works end-to-end (not just one layer)
- [ ] All code paths produce meaningful results

---

### Anti-Mock Rules (CRITICAL — NON-NEGOTIABLE)

The following patterns are **BANNED** in production code. Any of these in delivered code means the work is NOT done.

| # | Banned Pattern | Why |
|---|---------------|-----|
| 1 | `return {}` / `return []` / `return null` as placeholder returns | Produces silent wrong behavior in production |
| 2 | `throw new Error('Not implemented')` / `throw new Error('TODO')` | Crash in production |
| 3 | Empty function bodies that should have logic | Feature silently does nothing |
| 4 | Hardcoded sample data posing as real data | App shows fake data to users |
| 5 | `// TODO: implement` / `// FIXME` / `// PLACEHOLDER` / `// STUB` where code should be | Incomplete delivery |
| 6 | Empty catch blocks that silently swallow errors | Hides failures, makes debugging impossible |
| 7 | Functions that only log and return without performing their stated purpose | Feature silently does nothing |
| 8 | Event handlers that are no-ops (`() => {}`) | User interactions do nothing |
| 9 | Store actions that return hardcoded data instead of calling real APIs | App displays stale/fake data |

#### Self-Check

Before marking work as done, ask yourself for **every function you wrote**:

> "If this ran in production right now, would it actually work?"

If the answer is no, the work is not done.

---

### Scope Discipline (Karpathy Principle 2)

- [ ] No abstraction added unless the story explicitly required it
- [ ] No "future-proofing" not in the story (configurability, plugin hooks, generics)
- [ ] No error handling for scenarios the story does not mention
- [ ] No files modified outside the story's surgical scope (every changed line traces to an acceptance_check)
- [ ] If implementation exceeds ~150% of estimated story size, add a carry-forward note explaining why before marking complete

---

### Code Quality

- [ ] Type-check passes with zero new errors
- [ ] Lint passes with zero new errors
- [ ] No `any` types — use `unknown` with type guards if truly unknown
- [ ] No `console.log` left behind — use proper logger if needed
- [ ] No hardcoded secrets, API keys, or URLs — use environment variables
- [ ] No commented-out code blocks left in

---

### Security (Backend)

- [ ] Every callable function has an auth check
- [ ] Every endpoint validates authorization (not just authentication)
- [ ] No user input reaches the database without validation
- [ ] No PII in logs beyond user ID
- [ ] Error messages do not leak internal details (stack traces, DB schemas, etc.)

---

### Testing

- [ ] New public functions have at least one test
- [ ] Error paths are tested (not just happy path)
- [ ] Tests exercise real code — not just mock return values
- [ ] No `it.skip`, `xit`, or `describe.skip` left in test files

---

### Build

- [ ] Project builds successfully
- [ ] No new build warnings introduced


### Related protocols

- [/_shared/terse-output.md](/_shared/terse-output.md) — output-style directive. All content this protocol produces (reports, checkpoints, logs) should follow it.



---

<!-- ===== Absorbed from deviation-protocol.md ===== -->

## Deviation Handling Protocol

When an agent encounters something unexpected during implementation — a bug in existing code, a missing dependency, a design issue not covered by the story — follow these tiered rules to decide how to handle it.

**Companion protocols:**
- [definition-of-done.md](#definition-of-done) — Quality standards that must not be compromised by deviations

---

### Tier 1: Auto-Fix (No Escalation Needed)

Handle these silently. Fix, commit separately, and continue.

| Situation | Action |
|---|---|
| Bug in existing code that blocks the current story | Fix it, add a comment explaining why, commit separately with `fix(scope):` prefix |
| Missing import or export in an existing file | Add it |
| Clear type mismatch in existing code | Fix the type definition if it's obviously wrong |
| Missing barrel file entry (`index.ts`) | Add the export |
| Broken test caused by your changes (not a regression) | Fix the test to match the new behavior |

**Commit format for auto-fixes:** `fix(sprint-${N}/<role>): fix <what> — discovered during S${N}-XXX`

---

### Tier 2: Auto-Add (Report to Orchestrator)

Handle these, but report what you did so the orchestrator can track scope changes.

| Situation | Action |
|---|---|
| Need a utility/helper function not in the story | Create it, report via DEVIATION message |
| Missing error handling in existing code that new code depends on | Add it, report via DEVIATION message |
| Need an additional type or interface not specified | Create it, report via DEVIATION message |
| Discovered a closely related issue worth fixing | Fix it if < 20 lines, report via DEVIATION message |

**Report format:**
```
DEVIATION: <what was added or changed>
  Reason: <why it was needed>
  Files: <list of files touched>
  Impact: <low — isolated to this story's scope>
```

---

### Tier 3: Escalate (Ask Orchestrator)

Do NOT proceed. Report to the orchestrator and wait for guidance.

| Situation | Action |
|---|---|
| Architectural change needed (new module boundaries, new shared packages) | ESCALATE and wait |
| Changes to public API contracts that other agents depend on | ESCALATE and wait |
| Changes affecting more than 3 files outside the agent's assigned stories | ESCALATE and wait |
| Story's acceptance criteria are contradictory or impossible | ESCALATE and wait |
| Need to modify another agent's worktree or branch | ESCALATE and wait |
| Performance concern that would require a different approach | ESCALATE and wait |

**Report format:**
```
ESCALATE: <what needs to change>
  Impact: <which agents/stories are affected>
  Options: <2-3 possible approaches if known>
  Blocked: <yes/no — can I continue other stories while waiting?>
```

---

### Tier 4: Never Auto-Fix

These changes MUST be escalated even if they seem simple. The orchestrator must involve the user.

- Security rules or authentication patterns
- Database schema migrations or Firestore security rules
- Breaking changes to shared APIs (used by multiple modules)
- Environment variable additions (require deployment coordination)
- Dependency additions (new packages in package.json)
- License-affecting changes

---

### Orchestrator Handling

When the orchestrator receives a deviation or escalation:

#### For DEVIATION messages:
1. Log the deviation to the activity feed with `event: "decision"`.
2. Track cumulative deviations. If total deviations exceed 5 in a sprint, flag to the user.
3. Update STATE.md with deviation notes.

#### For ESCALATE messages:
1. Log the escalation to the activity feed.
2. If the agent said `Blocked: no`, let them continue with other stories.
3. If the agent said `Blocked: yes`, check if other agents can take their ready stories.
4. Present the escalation to the user with the agent's options. Also fire a remote push so a user monitoring via `claude agents` is alerted off-screen (no-op if Remote Control unconfigured; gate on developer-profile `notify`):
   ```
   PushNotification(title: "Escalation — decision needed", message: "<skill>: <one-line what needs to change>")
   ```
5. After user decision, send resolution via `ASSIST:` message to the agent.

---

### Auto-Fix Priority Order

When multiple deviations or issues are discovered simultaneously, resolve them in this priority order:

| Priority | Category | Examples | Rationale |
|----------|----------|----------|-----------|
| **P1** | Bugs blocking current story | Type errors, import failures, runtime crashes | Unblocks the agent immediately |
| **P2** | Critical functionality gaps | Missing auth checks, broken API contracts | Prevents security/data issues |
| **P3** | Blockers for dependent stories | Missing exports, incomplete types, missing barrel entries | Unblocks downstream agents |
| **P4** | Architecture/convention issues | Wrong directory, inconsistent naming, missing error handling | Maintains codebase quality |

Within the same priority level, resolve issues affecting more files first (wider impact = earlier fix).

#### Tier 2 Auto-Add Escalation Rule

If a Tier 2 auto-add exceeds **30 lines of new code**, it must be promoted to **Tier 3 (Escalate)**. The threshold exists because large auto-adds risk:
- Introducing scope creep that the orchestrator cannot track
- Creating merge conflicts with other agents' work
- Hiding significant design decisions in deviation reports

When promoting, include the completed work so far in the ESCALATE message so the orchestrator can decide whether to accept it as-is or request changes.


### Related protocols

- [/_shared/terse-output.md](/_shared/terse-output.md) — output-style directive. All content this protocol produces (reports, checkpoints, logs) should follow it.



---

<!-- ===== Absorbed from scope-limit-protocol.md ===== -->

## SCOPE-LIMIT.md Protocol

Operator-facing stop signal: tells the autonomous loop to halt proposing new work even when work exists. Distinct from `STATE.md` (sprint-level checkpoint) and from `deferred` carry-forward registry entries (item-level deferral). A `SCOPE-LIMIT.md` is the **whole-codebase override**: when present and unexpired, `/blitz:next --loop` short-circuits its decision tree to `LOOP_ESCALATE` regardless of pending sprints, active carry-forward entries, or unsprintified audit epics.

---

### When to declare

- **Diminishing-returns ceiling** reached on a series of audit-derived sprints (e.g., 4 sprints of cleanup with sub-linear findings/sprint).
- **Architectural pause** required while a major capability lands (the loop should wait, not propose patchwork).
- **Operator out-of-band** wants to suspend autonomous progress for review/audit/handoff.
- **Cooldown after incident** — e.g., a runaway loop iteration produced regressions; lock the loop until investigation completes.

Do NOT declare a scope limit to defer a single item — use the carry-forward registry `deferred` event for that (see [carry-forward-registry.md](#carry-forward-registry-protocol)).

---

### File location

Single canonical path: `SCOPE-LIMIT.md` at repo root. No glob; no per-domain variants in v1 (extend only if operators ask).

---

### Frontmatter schema

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

### `/blitz:next` Phase 0.9c + row 6f behavior

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

### Expiry semantics

- `expires_after` is **required** (no missing-field tolerance — see schema).
- Comparison: `today (UTC) < expires_after` → active. Equal-day → expired (boundary is exclusive on the active side).
- Past-date file → treated as cleared (file is informational only, never re-emits LOOP_ESCALATE).
- Date-only granularity: time-of-day not honored. A scope-limit declared `expires_after: 2026-08-01` becomes inactive at the first `/blitz:next` tick on or after `2026-08-01 00:00 UTC`.

Operators who want indefinite scope limits should still set `expires_after` (e.g., `2099-12-31`). Indefinite-without-expiry is intentionally disallowed to prevent the "forever-block" failure mode (Risk 4 in `docs/_research/2026-05-18_audit-deferred-work-detection.md`).

---

### Lifecycle commands (provisional)

In v1, lifecycle is hand-edit only:

| Operation | How |
|---|---|
| Declare | Write `SCOPE-LIMIT.md` by hand at repo root with required frontmatter |
| Clear | Delete the file OR set `expires_after` to a past date |
| Extend | Edit `expires_after` to a later date |
| Inspect | `cat SCOPE-LIMIT.md` |

**Future**: A `/blitz:scope-limit declare|clear|extend|inspect` skill could automate this (out of scope for v1 — covered as future-epic candidate).

---

### Distinction from related concepts

| Signal | Granularity | Persistence | Effect on `/blitz:next` |
|---|---|---|---|
| `STATE.md` | per-sprint | sprint-only | row 1: resume sprint from checkpoint |
| Carry-forward entry (`status: deferred`) | per-item | indefinite until revived | row 6a if `rollover_count >= 3` |
| `SCOPE-LIMIT.md` | full-codebase | until file deleted OR expires_after past | row 6f: LOOP_ESCALATE (short-circuits all other rows) |

---

### Related protocols

- [session-lifecycle.md](session-lifecycle.md) — pipeline artifact contracts
- [carry-forward-registry.md](#carry-forward-registry-protocol) — item-level deferred work
- [session-lifecycle.md](session-lifecycle.md) — sprint-level STATE.md
- [terse-output.md](terse-output.md) — output style for banner formatting
