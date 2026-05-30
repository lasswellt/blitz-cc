---
name: review
description: "Consolidated precision review gate (per-change). Runs both detection lanes from the shared check-registry (deterministic: tsc/lint/test/build + grep/git/import-graph; semantic: parallel reviewer agents single-pass), FP-verifies findings, gates by confidence (high band), and invokes the critic. Folds completeness-gate (--only completeness), integration-check (--only wiring), and code-doctor framework rules (--only framework); delegates the full 8-invariant gate to the sprint-review engine. Use for 'review sprint N', 'run quality gates', 'check completeness', 'check wiring', 'validate before shipping'."
argument-hint: "[--sprint NNN] [--auto-fix] [--only completeness|wiring|framework|design|full] [--min-confidence high|low] [--dual] -- full run = sprint-review 8-invariant gate (parallel reviewers + critic); --only runs one folded concern; --dual adds cross-model critic for semantic findings"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, ToolSearch, Agent
disable-model-invocation: false
model: opus
effort: low
compatibility: ">=2.1.71"
---


OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.

# Review — Consolidated Precision Gate

The per-change quality gate. **Precision-biased**: it runs constantly, so a false alarm is expensive — low-confidence advisory findings are suppressed by default. Selects checks from the shared registry [`/_shared/check-registry.json`](/_shared/check-registry.json) and runs both detection lanes; delegates the full 8-invariant run to the **sprint-review** engine. Companion: [`/blitz:audit`](../audit/SKILL.md) is the recall-biased pre-release deep audit that re-surfaces what review suppresses.

**Session registration**: follow [session-protocol.md](/_shared/session-protocol.md) §Session Registration before any other work.

**Verbose progress is mandatory.** Follow [verbose-progress.md](/_shared/verbose-progress.md). Print `[review]` status at every phase + dispatch. Log `skill_start`/`skill_complete` to the activity feed.

## Flag Parsing

- `--sprint NNN` — review the specified sprint (defaults to current / uncommitted changes).
- `--auto-fix` — apply safe fixes (types, lint, imports) automatically.
- `--only {completeness|wiring|framework|design|full}` — run one folded concern instead of the full gate (default `full`).
- `--min-confidence {high|low}` — advisory-finding gate band (default `high` ≥0.8). `reject`-authority findings always surface (bypass the gate). See [check-registry.md](/_shared/check-registry.md).
- `--dual` — set `BLITZ_DUAL_CRITIC=1` (cross-model critic for semantic/security findings).

## Two detection lanes (both run; registry-driven)

Per [check-registry.md](/_shared/check-registry.md), select `consolidated_target ∈ {review, both}`:

1. **Deterministic lane** (run first, fast, zero-FP): `lane == deterministic` checks — tsc/lint/test/build (det-11/12), shortcut detectors (det-01..19), anti-mock O2 (o2-*, was completeness-gate), wiring O3 (o3-*, was integration-check, conditional on new modules), framework rules (fw-*, conditional on Vue/Firestore/Pinia). `reject`-authority findings may flip the verdict and bypass the confidence gate.
2. **Semantic lane** (single-pass — diff is small, bias is precision): the 4 parallel reviewer agents (security/backend/frontend/patterns). Single-pass findings start at base_confidence ≈0.5 and MUST pass FP-verification to survive; un-reproduced findings are dropped. FP-verification cannot *raise* confidence (only aggregation does, and review is single-pass) — so a default-review semantic finding stays a sub-threshold advisory, never a blocker. Aggregation is opt-in (`--aggregate`); audit is where it re-surfaces.

**FP-verification** (mandatory before any blocker on a `base_confidence < 1.0` finding): re-read the cited code, confirm the flaw reproduces against actual behavior, attach the excerpt. No evidence → downgrade to advisory.

## --only folded concerns

| `--only` | Registry checks | Replaces |
|---|---|---|
| `completeness` | `o2-anti-mock`, `o2-artifact-l1l2`, det-09/10 | completeness-gate (deleted; folded here) |
| `wiring` | `o3-wiring`, `o3-orphan-route`, det-16 | integration-check (deleted; folded here) |
| `framework` | `fw-firestore-vue-pinia` | `/blitz:code-doctor` rule scan (code-doctor keeps `--fix` standalone) |
| `design` | `pillar == design` — Layer 0 (universal slop) always; Layer 1/2 gated by the `scripts/detect-stack.sh` adapter; reconciliation suppresses per stack | impeccable design pillar (new) |
| `full` (default) | all review-targeted checks + the sprint-review 8-invariant gate | — |

`--only` runs that concern's registry checks read-only and reports; `full` delegates to the sprint-review engine. sprint-dev Phase 3.5.0 calls `/blitz:review --only wiring`.

## Pre-Flight Validation (full runs)

1. **Sprint exists**: `sprint-registry.json` shows target sprint `status: review|in-progress`. Else inform + stop.
2. **Stories exist**: `sprints/sprint-${N}/stories/` has ≥1 `status: done`.
3. **No conflicting sessions**: no active `sprint-review` session on the same sprint.

## Execution

- `--only X`: run X's registry checks (read `detection.command` per row), FP-verify, report ranked by `effective_confidence`. No engine dispatch.
- `--only design`: **first run the preflight** `scripts/design/preflight.sh <target-repo>` and render its `DESIGN_LANE_STATUS` banner. If `semantic != OK`, surface the `DESIGN_LANE_UNAVAILABLE` line in the summary, run only the lanes that don't need impeccable (the deterministic regex rows), and do **not** return green for the design pillar — coverage is reduced, not passed. Then resolve the adapter by parsing the `DESIGN_ADAPTER primary=… variant=… secondary=… incompat=… confidence=…` token line from `scripts/detect-stack.sh` (the machine line, not the prose); select `pillar == design` rows where `adapter ∈ inclusion(primary) ∪ secondary` and not suppressed by `reconciliation.relaxFor` (where `inclusion`: `none→{universal}`, `tailwind→{universal,tailwind}`, `tailwind-md3→{universal,tailwind,tailwind-md3}`, `vuetify→{universal,vuetify}`, `quasar→{universal,quasar}`). Vendored (semantic) rows share ONE impeccable run and match hits by `detection.filter`; deterministic L1/L2 rows run their `regex` command (always available, key-free), then apply the registry's `design.exclude` set — a two-step scoped filter (drop files matching `files` OR containing any `contentGuard`; drop lines matching any `lineGuard`) so token-definition surfaces (`@theme`/`tailwind.config`/`quasar.variables`/Vuetify theme), comments, and SVG paint don't false-positive. FP-verify each survivor (re-read the cited line; reject token-def/comment/SVG) before reporting as a blocker. The consolidated `design-raw-color-literal` selects its remediation message from `perAdapter` by the detected stack. Layer 0 always on; Layer 1/2 gated to the stack. impeccable is a dependency of the **target project**, not the plugin (`npm i -D impeccable@2.3.2`). See [detector-rebuild.md](../../docs/integrations/impeccable/detector-rebuild.md) and [improvements/dependency-resolution.md](../../docs/integrations/impeccable/improvements/dependency-resolution.md).
- `full`: invoke the **sprint-review** skill (passing `--sprint`, `--auto-fix`, `--dual`). It runs the type-check/lint/test/build gates, parallel reviewer agents, auto-fix, and **Phase 3.6 the 8 carry-forward invariants** (incl. Invariant 7 = critic LGTM via [`agents/critic.md`](../../agents/critic.md)).

## Output

- Findings by severity (Critical/Warning/Suggestion), ranked by `effective_confidence`; advisory findings below `--min-confidence` suppressed (logged, not surfaced).
- `--auto-fix`: report auto-fixed vs manual.
- Pass/fail per gate; for `full`, the 8-invariant PASS/FAIL summary.
