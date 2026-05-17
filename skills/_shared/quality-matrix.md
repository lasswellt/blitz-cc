# Quality-Skill Decision Matrix

Blitz ships **7 quality-related skills**. They look superficially overlapping but each has a distinct scope, tempo, and depth. This matrix is the single reference for "which one do I want?" Updated 2026-05-16.

## TL;DR — pick by your symptom

| Symptom | Skill |
|---|---|
| "Is my sprint mergeable?" | `/blitz:sprint-review` |
| "Are there placeholders / stubs / `Not implemented` strings?" | `/blitz:completeness-gate` |
| "Comprehensive 5-pillar audit before a major release" | `/blitz:codebase-audit` |
| "Vue/Firestore/Pinia framework misuse patterns" | `/blitz:code-doctor` |
| "Continuous code-quality improvement; ratchet that only goes forward" | `/blitz:code-sweep` |
| "Are my exports wired to imports? Orphan routes? Auth coverage?" | `/blitz:integration-check` |
| "Just run the review phase" (thin alias) | `/blitz:review` |

## Full matrix

| skill | scope | tempo | depth | output | invokes other skills | invoked by |
|---|---|---|---|---|---|---|
| **sprint-review** | one sprint | per-sprint | type-check + lint + test + build + 4 parallel reviewer agents (security/backend/frontend/patterns) + critic agent | PASS/FAIL + 8-invariant report (`.cc-sessions/sprints/<sprint>/review.md`) | critic agent, reviewer/architect agents | ship; `/blitz:review` alias; manual |
| **completeness-gate** | repo or scope | gate (called) | placeholder/stub scan via grep + AST patterns (TODO/FIXME/STUB/`return {}`/`throw new Error('Not implemented')`) | A-F completeness score + file:line findings | none (read-only) | ship; manual |
| **codebase-audit** | full repo | pre-release / quarterly | 10 parallel agents (2 per pillar × 5 pillars: Architecture, Performance, Security, Maintainability, Robustness) | full report → roadmap-ingestible findings (`docs/_research/<date>_codebase-audit.md`) | 10 audit agents | manual; pre-release ritual |
| **code-doctor** | files matching `paths:` (Vue/Firestore/Pinia) | manual / hooks | framework-API anti-pattern rules (Firestore: reads in render, missing rules; Vue 3: ref/reactive misuse; Pinia: external mutation; dead exports; duplication candidates) | findings list + `--fix` auto-applies low-risk corrections | none | manual |
| **code-sweep** | scope (path/all) | continuous (`/loop`) | 30 static checks across 7 categories + dynamic standards discovered from convention; ratchet metric persisted to `.cc-sessions/ratchet.json` | per-iteration improvement report; standards report | none | `/loop`; manual |
| **integration-check** | recently-changed code | gate (sprint-dev Phase 3.5.0) | export-to-import tracing, orphan route detection, auth guard coverage, store-to-component wiring | findings list (read-only) | none | sprint-dev Phase 3.5.0; manual |
| **review** | (alias) | (alias) | thin wrapper — flag-parses + forwards to sprint-review | (delegated) | sprint-review | manual |

## Why they don't overlap (despite looking similar)

| Apparent overlap | Reality |
|---|---|
| sprint-review + completeness-gate | Different concerns. sprint-review = "does this sprint pass the 8 invariants" (types, lint, tests, build, reviewer findings, branch hygiene). completeness-gate = "are there placeholders". Chained sequentially by `ship`, not by each other. No code duplication. |
| codebase-audit + code-doctor | Different scopes. codebase-audit = 5 broad pillars across whole codebase. code-doctor = narrow framework-specific rule pack. code-doctor's `paths:` field auto-loads only on Vue/Firestore projects; codebase-audit is universal. |
| code-sweep + code-doctor | Different mechanisms. code-sweep = ratchet + continuous loop. code-doctor = one-shot framework rules. code-sweep's "standards" are convention-discovered; code-doctor's are framework-canonical. |
| code-sweep + completeness-gate | Both grep TODOs but for different purposes. completeness-gate = "is this prod-ready right now" (gate semantics). code-sweep = "this metric should only decrease over time" (ratchet semantics). The grep patterns happen to overlap; the user-visible semantics differ. |
| critic agent + code-sweep | Different layers. critic = adversarial review of a SPECIFIC sprint's claims (does this work survive scrutiny). code-sweep = global metric ratchet. critic is one-shot; sweep is continuous. |
| sprint-review reviewer agents + reviewer skill | Different actors. sprint-review spawns 4 parallel reviewer agents (security/backend/frontend/patterns) PLUS the critic agent. The standalone `reviewer.md` agent is for ad-hoc one-off reviews outside a sprint context. |

## When sprint-review runs which

```
/blitz:sprint-review
├── Phase 0.0: input gate — validate pipeline inputs
├── Phase 0:   context — load sprint state
├── Phase 1:   automated checks — type-check + lint + tests + build
├── Phase 1.5: pattern analysis — anti-mock scan + convention check
├── Phase 2:   code review — parallel reviewer agents (security, backend, frontend, patterns)
├── Phase 2.5: browser verification (when Playwright available)
├── Phase 3:   auto-fix — resolve common failures
├── Phase 3.6: registry invariants — carry-forward hard gate (8 invariants, including
│              Invariant 7 = critic agent LGTM via agents/critic.md)
├── Phase 3.7: automation coverage — declare boundary
└── Phase 4:   report — write review report and update registry
```

The critic agent runs INSIDE Phase 3.6 as Invariant 7, not as a separate Phase 3.7. Phase 3.7 is the "automation coverage / declared boundary" step where the skill states which checks were skipped (e.g. browser unavailable, no test runner detected) so reviewers can spot-check those manually.

Notably, sprint-review does NOT run completeness-gate — that's a separate concern owned by `ship`. The chain is:

```
/blitz:ship
├── /blitz:sprint-review     (PASS gate — 8 invariants)
├── /blitz:completeness-gate (≥C / 70 required)
├── /blitz:quality-metrics   (observability snapshot)
└── /blitz:release           (tag + publish)
```

Each gate is independently invokable. The ship pipeline composes them; users can also run them individually.

## Authoring guidance — when to add a new quality skill

Before adding an 8th quality-class skill, check:

1. **Is the scope distinct?** (e.g., sprint-scoped vs repo-scoped vs file-scoped)
2. **Is the tempo distinct?** (e.g., per-sprint gate vs continuous loop vs pre-release ritual)
3. **Is the output consumed by a different downstream?** (review.md vs ratchet.json vs roadmap doc vs commit-blocking exit code)
4. **Would a `--mode` flag on an existing skill do?** Often yes — prefer mode flags over new skills.

If you cannot answer all four with distinct values, do not add the skill. Update this matrix instead — most "missing" quality skills are subsets of an existing one with a new flag.

## Cross-refs

- `skills/sprint-review/SKILL.md` — 8-invariant gate spec
- `skills/codebase-audit/SKILL.md` — 5-pillar agent fan-out
- `skills/code-doctor/SKILL.md` — framework-API rule packs + `paths:` glob auto-load
- `skills/code-sweep/SKILL.md` — ratchet protocol + `/loop` integration
- `skills/completeness-gate/SKILL.md` — placeholder/stub patterns
- `skills/integration-check/SKILL.md` — cross-module wiring
- `skills/ship/SKILL.md` — release-chain composition
- `_shared/ratchet-protocol.md` — 8 monotonic metrics, multi-agent worktree merge, auto-revert
- `_shared/shortcut-taxonomy.md` — 19 anti-shortcut detectors + grep patterns
- `agents/critic.md` — adversarial pre-PASS reviewer (8 reject checks + JSON contract)
