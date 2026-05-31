# State Handoff Contract

Defines the files each skill **produces** and **requires** as it hands work down the blitz pipeline. The pipeline:

```
bootstrap ─→ research ─→ roadmap ─→ sprint-plan ─→ sprint-dev ─→ sprint-review ─→ ship
                                          ↓                ↓              ↓
                                       (writes)         (reads)       (closes)
```

Without this contract, greenfield projects fail with cryptic errors ("no roadmap registry", "no story file matching id"), and skills mid-pipeline silently degrade when an upstream artifact is missing. Every skill in the chain MUST implement a Phase 0 input-validation gate that hard-fails with a specific actionable message rather than producing degraded output.

**Companion protocols:**
- [story-frontmatter.md](story-frontmatter.md) — story file schema (the primary handoff between sprint-plan and sprint-dev).
- [carry-forward-registry.md](carry-forward-registry.md) — registry semantics (the secondary handoff that survives sprint boundaries).
- [checkpoint-protocol.md](checkpoint-protocol.md) — STATE.md / HANDOFF.json for resumable orchestrators.
- [session-protocol.md](session-protocol.md) — `.cc-sessions/` directory layout and locking.

---

## Pipeline Handoff Table

Reading order: **Producer → Artifact → Required-By**. Every artifact has exactly one canonical producer and ≥ 1 documented consumer.

### bootstrap

| Artifact | Producer | Consumer | Required? |
|---|---|---|---|
| `package.json` (or equivalent project manifest) | bootstrap | All skills (project type detection) | Required for greenfield |
| `src/` (or equivalent source root) | bootstrap | All implementation skills | Required for greenfield |
| `.cc-sessions/` (directory) | bootstrap **or** any skill on first run | session-protocol consumers | Auto-created by session-protocol |
| `docs/roadmap/roadmap-registry.json` | bootstrap (greenfield only) **or** roadmap | sprint-plan Phase 0 step 2 | **Required by sprint-plan** |
| `docs/roadmap/epic-registry.json` | bootstrap (greenfield only) **or** roadmap | sprint-plan Phase 0 step 2 | **Required by sprint-plan** |

**bootstrap Phase 5 must:** initialize `docs/roadmap/roadmap-registry.json` and `docs/roadmap/epic-registry.json` as empty stubs even on greenfield, OR explicitly print "Roadmap not initialized — run /blitz:roadmap before /blitz:sprint-plan". Silent absence is the failure mode.

### research

| Artifact | Producer | Consumer | Required? |
|---|---|---|---|
| `docs/_research/<YYYY-MM-DD>_<slug>.md` | research | roadmap (extend mode), sprint-plan (research_refs lookup) | Required by `roadmap extend` |
| `scope:` YAML frontmatter block in research doc | research Phase 3 | roadmap extend (registry ingest) | Required only if quantified scope claimed |

### roadmap

| Artifact | Producer | Consumer | Required? |
|---|---|---|---|
| `docs/roadmap/roadmap-registry.json` (populated) | roadmap (extend, refresh, init) | sprint-plan Phase 0 step 2 | Required |
| `docs/roadmap/epic-registry.json` (populated) | roadmap | sprint-plan Phase 0 step 2; sprint-dev Phase 3.2 step 1a (registry inference fallback) | Required |
| `.cc-sessions/carry-forward.jsonl` lines (`event: "created"`) | roadmap extend (Phase 1.1.5) | sprint-plan Phase 0 step 8 (mandatory inputs), sprint-review Phase 3.6 Invariant 1 | Required if research had `scope:` |

### sprint-plan

| Artifact | Producer | Consumer | Required? |
|---|---|---|---|
| `sprints/sprint-${N}/manifest.json` | sprint-plan Phase 1.4 | sprint-dev Phase 0.0, sprint-review Phase 0 | Required |
| `sprints/sprint-${N}/stories/S${N}-*.md` | sprint-plan Phase 3.2 | sprint-dev (every story validated per [story-frontmatter.md](story-frontmatter.md)) | Required (≥ 1 story) |
| `sprints/sprint-${N}-planning-inputs.json` | sprint-review (previous sprint) **or** sprint-plan Phase 0 (if absent) | sprint-plan Phase 0 step 8 | Optional (auto-injected when carry-forward exists) |
| `sprint-registry.json` (entry added) | sprint-plan Phase 4.5 | sprint-dev, sprint-review, ship | Required |
| `.cc-sessions/carry-forward.jsonl` lines (`event: "auto_waived"`, Phase 4.1) | sprint-plan Phase 4.1 | sprint-review Phase 3.6 Invariant 2, next sprint-plan Phase 0 step 8 | Required when waivers occurred |
| GitHub issues (one per story) | sprint-plan Phase 4.4 | sprint-dev (links commits), sprint-review (closes) | Required when `--issues` mode |

### sprint-dev

| Artifact | Producer | Consumer | Required? |
|---|---|---|---|
| Negotiated sprint-contract (`${SESSION_TMP_DIR}/HANDOFF.json` `scope.acceptance`) | sprint-dev Phase 0.6 (generator ↔ evaluator) | sprint-dev Phase 3.5 verification, sprint-review | Optional (skipped for trivial single-story sprints) |
| Worktrees `.cc-sessions/${SESSION_ID}/worktrees/agent-<role>/` | sprint-dev Phase 2.3 | Internal (agent dispatch); merged back at Phase 4.1 | Internal |
| `STATE.md` (in repo root or `.cc-sessions/`) | sprint-dev Phase 3.2 step 1b (per checkpoint-protocol) | sprint-dev resume on next invocation, sprint-review report | Required by checkpoint-protocol |
| Story `status` transitions (`in-progress`, `done`, `blocked`) | sprint-dev Phase 4.8 | sprint-review (report), next sprint-plan (carry-forward injection) | Required |
| `.cc-sessions/carry-forward.jsonl` lines (`event: "progress"`, Phase 3.2 step 1a) | sprint-dev | sprint-review Phase 3.6 Invariant 2 cross-check | Required when stories had `registry_entries` |
| Commits + branches (one per agent worktree) | sprint-dev | sprint-review diff, ship | Required |
| `${SESSION_TMP_DIR}/HANDOFF.json` (on interrupted exit only) | sprint-dev cleanup | sprint-dev resume | Conditional |

### sprint-review

| Artifact | Producer | Consumer | Required? |
|---|---|---|---|
| `sprints/sprint-${N}/review-report.md` | sprint-review Phase 4.1 | ship, retrospective | Required |
| `sprints/sprint-${N}-planning-inputs.json` (auto-inject for next sprint) | sprint-review Phase 3.6 Invariant 4 | next `sprint-plan` Phase 0 step 8 | Required when uncovered registry entries remain |
| Story `status` final transitions (`done`, `dropped`) | sprint-review Phase 3 | sprint-registry close-out, ship | Required |
| `.cc-sessions/carry-forward.jsonl` lines (`event: "complete"`, `"deferred"`, or `"dropped"`) | sprint-review Phase 3.6 | next sprint-plan Phase 0 step 8 | Required when invariants close entries |
| `sprint-registry.json` (status `review` → `done` or `cancelled`) | sprint-review Phase 4.3 | sprint-plan (next sprint number derivation), ship | Required |

### ship

| Artifact | Producer | Consumer | Required? |
|---|---|---|---|
| `CHANGELOG.md` entry | ship Phase 2 (release) | Public release notes | Required |
| Tag `v<X.Y.Z>` | ship Phase 4 | npm/marketplace publish | Required |
| `.cc-sessions/release-state.json` | ship | rollback recovery | Required |

---

## Phase 0 Validation Pattern

Every consumer skill MUST implement a Phase 0 input-validation gate before doing real work. Pattern:

```bash
# Phase 0.0 — Input validation gate
PIPELINE_INPUTS=()
PIPELINE_MISSING=()

# Per-skill required-input list (cite this doc by file:line)
REQUIRE=(
  "docs/roadmap/roadmap-registry.json"     # state-handoff.md §sprint-plan
  "docs/roadmap/epic-registry.json"        # state-handoff.md §sprint-plan
)

for input in "${REQUIRE[@]}"; do
  if [ ! -s "$input" ]; then
    PIPELINE_MISSING+=("$input")
  else
    PIPELINE_INPUTS+=("$input")
  fi
done

if [ "${#PIPELINE_MISSING[@]}" -gt 0 ]; then
  echo "BLOCK: Required pipeline inputs missing:" >&2
  for f in "${PIPELINE_MISSING[@]}"; do
    echo "  - $f" >&2
  done
  echo "" >&2
  echo "See skills/_shared/state-handoff.md for the producer of each input." >&2
  exit 1
fi
```

**Hard-fail with the path of the missing artifact AND the producer skill name.** "Roadmap registry not found" is unhelpful; "Required input `docs/roadmap/roadmap-registry.json` not found — produced by `/blitz:roadmap init` or `/blitz:bootstrap`" is actionable.

---

## Greenfield Bootstrap Sequence

For a brand-new project, the canonical sequence is:

```
1. /blitz:bootstrap                  # creates package.json, src/, docs/, empty roadmap
2. /blitz:research <topic>           # writes docs/_research/<date>_<topic>.md
3. /blitz:roadmap extend             # ingests scope:, populates roadmap & epic registries
4. /blitz:sprint-plan                # produces sprint-1 manifest + stories
5. /blitz:sprint-dev                 # implements stories
6. /blitz:sprint-review              # closes sprint
7. /blitz:ship                       # tags + releases
```

Each step's Phase 0 validation MUST cite this sequence in its error message when an input is missing. Example: bootstrap-skipped → sprint-plan reports "missing roadmap-registry.json. Greenfield bootstrap order: bootstrap → research → roadmap → sprint-plan."

---

## migrate

**Producer**: `/blitz:migrate`
**Requires**: source codebase + package.json (baseline), `CLAUDE.md` (project config).
**Produces**:
- `docs/migrations/<from>-<to>/plan.md` — incremental step plan with verification commands per step
- `docs/migrations/<from>-<to>/STATE.md` — checkpoint (which steps completed, which failed) enabling resume via `--resume`
- `docs/migrations/<from>-<to>/report.md` — summary of applied changes, type-check/test gate results per step

**Pipeline position**: standalone (not part of the sprint cycle). Typically run after research or after sprint-plan if migration is a sprint story.

**Consumer**: operator (reviews report), sprint-plan (if migration is tracked as a story), fix-issue (if a step fails and needs targeted repair).

**Resume contract**: if `STATE.md` already exists and `--resume` is NOT passed, refuse to clobber — print `BLOCK: migration STATE.md exists; pass --resume to continue, or move STATE.md aside to restart.` and exit 1. With `--resume`, read STATE.md, skip completed steps, retry the first non-`done` step. Idempotency: rerun of `--resume` after full completion is a no-op (prints "migration already complete" and exits 0).

---

## Anti-patterns

- **Don't degrade silently when an input is missing.** Hard-fail at Phase 0 with the producer name.
- **Don't write `default: empty`-handler code paths to "make it work" without inputs.** They mask missing setup.
- **Don't read artifacts outside the producer's documented output.** If you find yourself grepping `sprints/` for files not in this table, you've coupled to undocumented state.
- **Don't change an artifact's location without updating this doc and every consumer.** Locations are part of the contract.

---

## Related protocols

- [/_shared/terse-output.md](terse-output.md) — output-style directive.
