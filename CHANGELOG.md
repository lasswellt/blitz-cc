# Changelog

All notable changes to the blitz plugin are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Release Process — Version-Drift Watch

Bump these files together on every release. `installer/package.json` and `installer/src/constants.js` are the npm-installer manifest — out-of-band drift means `npx blitz-cc@latest` advertises stale skill counts:

- `.claude-plugin/plugin.json` — `version`, `description`
- `.claude-plugin/marketplace.json` — `version` (if pinned)
- `installer/package.json` — `version`, `description`
- `installer/src/constants.js` — `VERSION`
- `installer/install.sh` — version banner (line ~45)
- `README.md` — version banner / current-feature counts
- This file — new release section

(`scripts/check-version-sync.sh` enforces this if present; otherwise manual.)


## [Unreleased]

_Nothing yet._

## [2.3.0] — 2026-05-31 · GAN-harness design-loop integration (E1–E5)

Closes the five deltas between blitz's design loop and the planner/generator/evaluator harness in [anthropic.com/engineering/harness-design-long-running-apps](https://www.anthropic.com/engineering/harness-design-long-running-apps). Blitz already had the architecture (sprint-plan → ui-build/sprint-dev → design-critic/critic); these are the deltas, not a rebuild. Specs: `docs/integrations/harness-design/`.

### Added
- **`skills/_shared/design-criteria.md`** — single-source 5-dimension design rubric, shared by the generator (steering) and evaluator (scoring). The criteria themselves steer the model off generic defaults before any evaluator cycle.
- **E1 criteria-as-steering** — `ui-build` Phase 3.0.1.1 carries the 5 dims ("museum quality") into generation, not just into the evaluator. Tone-conditional phrasing for informal tones.
- **E2 live-navigating evaluator** — `agents/design-critic.md` granted the Playwright navigation subset and navigates the live page before scoring (click primaries, exercise states, resize for responsive, read console). New `coverage_boundary` reply field; static-screenshot path retained as fallback (never silently passes interaction dims). `maxTurns` 15→30. `browser_run_code_unsafe`/`browser_evaluate` deliberately NOT granted (threat-model §5 posture).
- **E3 iterate + pivot** — `ui-build` Phase 5.4.2 flat-3 cap replaced with `ceiling = min(10, budget)`; refine-vs-pivot strategic decision after each evaluation (pivot space = the 13-tone menu).
- **E4 sprint-contract negotiation** — `sprint-dev` Phase 0.6: generator↔evaluator negotiate testable acceptance before code; persisted as co-owned `scope.acceptance`. Registered in `state-handoff.md`.
- **E5 capability-relative trigger** — `ui-build` `standard` tier evaluates only on edge-of-capability signals (novel aesthetic / interaction complexity / low generator confidence / deterministic-lane hits); `high` always evaluates. Re-examine per model release; cites the v1.16.0/cohesion/det-20 detector re-justification precedent.

### Changed
- `agents/design-critic.md` — "read screenshots, not source" → "read the rendered app, not the source" (input surface expands to live DOM; the source prohibition stands).

## [2.2.1] — 2026-05-30 · fix check-registry schema (v2.2.0 hotfix)

v2.2.0's LANE-1 re-laned 41 rows to `lane: semantic` but left `detection.type: command` and one `verdict_authority: reject` — which the `check-registry-validate` CI gate rejects (semantic rows must be `detection.type: semantic` + `verdict_authority: advisory`). The gate runs in CI only and was not run locally, so v2.2.0 shipped with a schema-invalid registry (red CI on `main`).

### Fixed
- `check-registry.json` — the 41 semantic design rows now carry `detection.type: "semantic"` (the `npx impeccable detect` command is retained on the row) and `verdict_authority: "advisory"` (`design-low-contrast` was `reject`). Registry passes `hooks/scripts/check-registry-validate.sh` (90 checks, derivation clean).
- `hooks/tests/design-pillar.bats` — added two guards that run the CI schema validator + assert every semantic design row is `type:semantic`/`advisory`, so this class of drift fails locally (suite 57→59).
- `.github/workflows/{ci,publish}.yml` — `actions/checkout` + `actions/setup-node` bumped `v4 → v5` (Node 24 compat; silences the Node 20 deprecation warning).

## [2.2.0] — 2026-05-30 · design-pillar reliability + precision hardening

Post-release hardening of the v2.1.0 design pillar. A validation pass found the absorption architecturally sound but with concrete reliability/precision gaps in the deterministic lane: an undeclared impeccable dependency that silently no-ops, 42 browser-rendered rows mislabeled `deterministic`, and regex rules that false-positive on the token definitions they protect. Fixed across five epics (`docs/integrations/impeccable/improvements/`), each gated by a new permanent test suite.

### Added
- `scripts/design/preflight.sh` — design-lane availability gate. Resolves impeccable **from the target project** (not the plugin; it's a browser/puppeteer-class dep), emits a machine-readable `DESIGN_LANE_STATUS` line, and fails **loud** (`DESIGN_LANE_UNAVAILABLE` + `npm i -D impeccable@2.3.2` hint) instead of silent-green when the semantic lane can't run. Exit 0 — the deterministic regex lane is never blocked.
- `scripts/detect-stack.sh` normalized `DESIGN_ADAPTER primary=… variant=… secondary=… incompat=… confidence=…` token — single parseable line consumers read instead of the prose block.
- 8 native blitz **deterministic** static rules (key-free, browser-free grep approximations of the impeccable slop tells): `bounce-easing-static`, `thin-border-wide-shadow-static`, `repeating-stripes-static`, `gradient-text-static`, `extreme-negative-tracking-static`, `tiny-text-static`, `all-caps-body-static`, `overused-font-static`.
- `check-registry.json` top-level `design.exclude` — token-definition exclusion set (file globs + content guards + line guards) applied to every deterministic design regex row before reporting; eliminates within-stack false positives on `@theme`/`tailwind.config`/`quasar.variables`/Vuetify-theme surfaces, comments, and SVG paint (measured 75%→0% FP on the raw-color-literal fixture).
- `hooks/tests/design-pillar.bats` — 22-test permanent gate: adapter-detection matrix, layer-gating selection harness, reconciliation suppression, FP exclusions, lane integrity, and the preflight loud-failure contract.

### Changed
- **41 vendored impeccable rows re-laned `deterministic` → `semantic`.** They are browser-rendered (require the impeccable package + a rendered DOM) — the deterministic tag was false. The genuinely deterministic design lane is now the blitz-authored grep rows only (`{ semantic: 41, deterministic: 19 }`; zero deterministic rows shell out to `npx`).
- **Gemini routing** — stripped impeccable's `--gpt --gemini` provider flags from all detector commands (the deterministic run is now key-free); the provider-gated tells route through `design-critic`'s gemini CLI, reusing the adversarial critic's `BLITZ_GEMINI_BIN`/`BLITZ_GEMINI_MODEL` env instead of a separate Gemini API key.
- `/blitz:review --only design` + `/blitz:audit --pillar design` — run the preflight first, parse the `DESIGN_ADAPTER` token + inclusion map, apply `design.exclude` + FP-verify before reporting.
- `scripts/maint/design/gen-design-rows.mjs` — dropped the silent `/tmp/impeccable-src` default (non-reproducible); the impeccable source path is now a required explicit arg.
- `skills/setup` + `skills/bootstrap` recommend `npm i -D impeccable@2.3.2` to the **target project** (the plugin never installs it).

### Removed
- 5 near-duplicate color rules (`tw-arbitrary-color`, `md3-role-conformance`, `vuetify-hardcoded-color`, `quasar-inline-hex`, `quasar-color-outside-brand`) folded into a single consolidated `design-raw-color-literal` carrying per-adapter messaging (`perAdapter`) + the `*.html` coverage. Design rows 57→60 (−5 color, +8 static).

### Fixed
- `installer/install.sh` curl install one-liner + `installer/src/index.js` docs link — corrected stale `lasswellt/blitz` → `lasswellt/blitz-cc` (the one-liner 404'd as written; the live remote/npm/homepage were already `blitz-cc`).
- `hooks/tests/_helpers.bash` — `fake_tool_input`/`fake_edit_input` were missing `tool_name`, so `block-test-deletion.sh` (which dispatches on it) fell through to allow instead of block — two long-standing test failures. Full `hooks/tests` suite now 57/57.

## [2.1.0] — 2026-05-30 · framework-adaptive design pillar (impeccable absorption)

Absorbed `pbakaus/impeccable@2.3.2` (Apache-2.0) as a **framework-adaptive design pillar**: a normalized 7-facet design model + pluggable adapters (Tailwind v4 · Tailwind+MD3 · Vuetify v4/v3/v0 · Quasar 2) that detect the project's UI stack and adapt guidance + conformance to it. Specs in `docs/integrations/impeccable/`; epics E0→E6 (`SYNTHESIS.md`). The universal AI-slop detection runs on any stack; per-adapter conformance fires only for the detected stack (no cross-stack false positives).

### Added
- `docs/integrations/impeccable/` — 8 spec docs (normalized-model, adapter-detection, framework-profiles, detector-rebuild, references-regrounded, migration-spec, ATTRIBUTION, SYNTHESIS) + vendored Apache-2.0 `LICENSE-APACHE-2.0.txt`.
- `check-registry.json` `design` pillar — **57 rows** (39 Layer-0 universal slop · 5 Layer-1 token-discipline · 13 Layer-2 adapter conformance), tagged by `layer`/`adapter` with per-adapter `reconciliation`; registry now 87 checks. Vendored from impeccable@2.3.2, re-grounded (Apache-2.0).
- `scripts/detect-stack.sh` Adapter Stack selector — primary + variant (Vuetify v3/v4/v0, Tailwind v3/v4, tailwind-md3) + secondary + incompatibility; component framework wins over Tailwind.
- `/blitz:review --only design` (precision) + `/blitz:audit --pillar design` (recall) + `design-critic` as the design pillar's semantic/vision lane. Deterministic detection shells out to `npx impeccable detect`.
- `scripts/maint/design/gen-design-rows.mjs` — idempotent registry-row generator (re-runnable against an impeccable checkout).

### Changed
- **Repository renamed** `lasswellt/cc-plugin-suite` → `lasswellt/blitz-cc` (matches the `blitz-cc` npm package). GitHub redirects the old URL; plugin-manifest `homepage`/`repository` + installer URLs updated to the new slug. The legacy `cc-plugin-suite@cc-plugin-suite` plugin-enablement key is retained for backward-compatibility.
- `ui-build` / `design-extract` / `ui-audit` made adapter-aware; `design-extract` DESIGN.md template gains a `## Stack` section; `quality-matrix` + orchestrator §2 route the design pillar.

### Removed
- `skills/_shared/frontend-design-heuristics.md` (122 lines) — superseded by the design pillar (normalized-model + `references-regrounded.md` §8.1 + the Layer-0 detector). Coverage proven in `migration-spec.md` §2; consumers redirected; `CLAUDE.md` reference updated.

## [2.0.0] — 2026-05-29 · review/audit consolidation (sprints 18–20)

Collapsed the 7-skill review/audit/quality surface into **2 entry points over a shared check registry**, grounded in the verified research in `docs/consolidation/review-audit/`.

### Added
- `skills/_shared/check-registry.json` (schema `blitz-check-registry/2.0`) + `check-registry.md` — single source of truth for every review/audit check: `lane` (deterministic|semantic), `verdict_authority` (reject|advisory, derived), `base_confidence`, `detection.{type,command}`, provenance. 30 checks (20 detectors + 5 semantic pillars + O2/O3/fw).
- `hooks/scripts/check-registry-validate.sh` — schema lint (verdict-authority derivation invariant + detection presence/type); wired into `pre-commit-validate.sh`.
- `/blitz:review` — consolidated **precision** front-door (two detection lanes, confidence gate + reject-bypass, FP-verify, `--only completeness|wiring|framework|full`).
- `/blitz:audit` — consolidated **recall** entry point with net-new flaw-finding: deterministic lane, Multi-Review aggregation (≥2 independent agreers → high confidence), adversarial FP-verify panel, and `coverage_boundary` recall instrumentation.

### Changed
- `agents/critic.md` — verdict-flip asymmetry (ground-truth → REJECT; advisory → annotate-only), reject-bypass of the confidence gate, FP-verify substep, principled CMC routing, registry-driven §2.1. Detector count reconciled to **20 catalogued (13 reject, 7 advisory)**.
- `agents/research-critic.md` — §2.5 claim-grounding promoted to a graded gate, `UNVERIFIED` first-class verdict, refuse-without-evidence for `scope:` claims, carry-forward citation-drift re-verification, corrected 4-way-taxonomy attribution.
- `shortcut-taxonomy.md` → human-readable view of the registry; `quality-matrix.md` rewritten for the 2-entry-point model.

### Removed (BREAKING)
- `skills/completeness-gate/` and `skills/integration-check/` — folded into `/blitz:review --only completeness` and `/blitz:review --only wiring`. Deprecation shims (sprint-19) removed in the sprint-20 cutover.
- `skills/codebase-audit/` — **renamed** to `skills/audit/` (the engine; `/blitz:audit` is the entry point). All ~50 references migrated. Skill count 39 → 37.

## [1.16.0] — 2026-05-28

Dynamic-Workflows adoption + a self-audited cohesion/modernization pass (Phase 8). The suite ran its own lifecycle on itself — research → 93-agent cohesion audit (native Dynamic Workflow) → roadmap extend → sprints 14-16 — and its adversarial gates caught (and fixed) two real defects introduced along the way. Counts: **39 skills · 10 agents · 36 hook scripts · 28 shared protocols** (+2: `workflow-dispatch.md`, and the count was already stale at 27).

### Added
- `skills/_shared/workflow-dispatch.md` — opt-in `Workflow` (dynamic-workflows) dispatch contract: capability gate + `Agent()` fallback, hybrid wrapper boundary (script owns dispatch, skill owns filesystem I/O), main-thread-only constraint, mandatory prompt invariants. Pilot wired into `codebase-audit` (Phase 1.0/1.1-W) and `research` (§1.2.6/§1.3-W).
- `hooks/scripts/markdown-link-validate.sh` — convention-aware resolution (`/_shared/X` → `skills/_shared/X`, relative bases, runtime-output skip) + scans `agents/`; coverage 114 → 397 links. Caught + fixed 1 real broken link.
- `hooks/scripts/tests/test-link-resolver.sh` — regression test for the resolver.
- `integration-check` — executable `unwired-store-actions` check (declared canonical owner of wiring topology).
- `health` — `disallowed-tools: [Edit, Write, NotebookEdit]` (declarative read-only enforcement).
- `docs/audits/cohesion-2026-05/` — full suite cohesion+modernization audit (49 unit findings + SYNTHESIS + decision docs).

### Changed
- `token-budget.md` — model IDs → `claude-haiku-4-5` / `claude-sonnet-4-6` / `claude-opus-4-8`; removed stale Opus-4.7 foot-gun; added fast-mode lane + effort low/high split; re-affirmed 60/35/5.
- `release` declared canonical changelog owner; `doc-gen` + `ship` delegate (O1/O5).
- `orchestrator` §2 declared canonical routing-table owner; `ask` cites it (O4).
- `completeness-gate` declared canonical anti-mock pattern owner (O2); its wiring checks (§2.11, §2.12-L3) delegate to `integration-check` (O3) with no coverage loss.
- `roadmap/SKILL.md` 508 → 490 (cleared the >500-line warning).

### Fixed
- `agents/orchestrator.md` — `[0:200]` field caps on `HANDOFF.json` + activity-feed `jq` renders (injection-surface guard; Opus 4.8 ASR regression).
- `conform/SKILL.md` — broken `/_shared/../../../` link repointed.

### Notes
- Three of the audit's quantified claims were inflated by per-unit agents and corrected on verification, not executed: dead-refs 242 → 0 (resolver false positive), E-027 "restated twice" → already cited, E-031 "1764 removable lines" → top target had ~0. Lesson: treat agent counts as hypotheses to verify.


## [1.15.0] — 2026-05-18

Four-sprint audit-closure release. The full 9-epic backlog from `docs/audits/audit-20260517.md` (E-013 through E-021) is now closed across sprints 9-12. Hook scripts gained a shared `common.sh` library, a four-suite `bats-core` test harness, anti-shortcut hardening, and standardized boilerplate. Sprint orchestrator skills shed ~1100 lines of inlined procedure to keep `SKILL.md` bodies under 450 lines via `references/main.md` extraction. STATE.md detection tolerates em-dash + bold-timestamp variants; `SPRINT_NUMBER` interpolation paths get a numeric path-traversal guard. Counts unchanged: **39 skills · 10 agents · 36 hook scripts across 16 events · 26 shared protocols** — this release hardens what exists rather than adding new surface area.

### Added

- **`hooks/scripts/_lib/common.sh`** — shared helper library for log timestamps, repo-root detection, JSON-line safe construction. Adopted by 19 hook scripts (sprint-10 standardization). Eliminates per-hook copy-pasted boilerplate; reduces total hook-script LoC ~200 (126e60f).
- **`hooks/tests/` bats-core test harness** — four blocker-hook test suites plus `_helpers.bash` factory. Initial coverage: `blitz-extract.bats` (8 tests incl. nested-quote / newline / backslash / jq-injection / digit-prefix fuzz), `block-destructive-git.bats` (8 tests), `block-no-verify.bats` (6 tests), `block-test-deletion.bats` (4 tests). Total: 26 hook tests pass on `bats hooks/tests/` (126e60f, 3df3338).
- **`docs/audits/audit-20260517*`** — full audit report, 9-epic backlog, and machine-readable index covering hook performance, installer hygiene, anti-shortcut detection, token reduction, error recovery, orchestrator routing completeness, and spawn-API consistency (84738ec).
- **Per-skill `Register Session.` citation** — 18 `SKILL.md` files added the canonical `[session-protocol.md] §Session Registration (steps 1-9) and [verbose-progress.md]` snippet so the protocol is discoverable from every skill that registers a session (102ff52).
- **`installer/install.sh` resiliency** — npm-presence probe + clearer error envelopes on `npx` fallback path; banner version derives from a single source (84738ec).

### Changed

- **`sprint-plan` / `sprint-dev` / `sprint-review` `SKILL.md` body lines: ≤450** — verbose bash blocks, inline tables, and procedural detail moved to `references/main.md` (15 sections extracted across the three skills). Net body line counts: 575 → 441 (sprint-plan), 583 → 440 (sprint-review), 567 → 447 (sprint-dev). Token-listing cost when always-loaded drops proportionally (102ff52, a050ff2).
- **`conform/SKILL.md` description** — 1000 → 568 chars (`description` field counts against the listing budget) (102ff52).
- **Hook scripts standardized on `_lib/common.sh`** — 19 scripts switched to `source "$HOOK_DIR/_lib/common.sh"`: `block-no-verify`, `block-destructive-git`, `critic-gemini`, `markdown-link-validate`, `permission-request`, `post-edit-activity-log`, `post-edit-format`, `post-edit-lint`, `post-edit-test`, `post-edit-typecheck-block`, `post-tool-batch`, `pre-commit-validate`, `reference-compression-validate`, `session-start`, `skill-frontmatter-validate`, `subagent-start`, `subagent-stop`, `task-completed-validate`, `worktree-create`, `worktree-remove`. Behavior identical (126e60f, 7a2021b).
- **`agents/orchestrator.md` routing table** — `/blitz:worktree-prune` row added with full flag surface (`--dry-run`, `--apply`, `--merged-only`, `--all-older-than`, `--force`); Vue-conditional skills (`code-doctor`, `ui-build`, `ui-audit`) tagged as stack-gated (ea8e22d).
- **`skills/doc-gen/SKILL.md`** — `TeamCreate` + `SendMessage` spawn pattern replaced with `Agent()` per the canonical `spawn-protocol.md` `Agent` Tool Spawning section. `allowed-tools` updated accordingly (ea8e22d).
- **`skills/migrate/SKILL.md`** — `SendMessage` removed from `allowed-tools`, replaced with `Agent` (ea8e22d).
- **`skills/ui-build/SKILL.md`** — `AskUserQuestion` added to `allowed-tools` (was used but undeclared) (ea8e22d).
- **`skills/_shared/state-handoff.md`** — `migrate` section added with full producer/consumer/resume contract (`STATE.md` exists + `--resume` not passed → refuse to clobber) (ea8e22d).
- **`skills/_shared/quality-matrix.md`** — `implement` and `review` alias rows documented; clarifies that `/blitz:implement` and `/blitz:review` are thin pass-throughs to `sprint-dev` / `sprint-review` (ea8e22d, c0a615b).

### Fixed

- **`SPRINT_NUMBER` path-traversal guard** — `sprint-dev` Phase 0.0 + `sprint-review` Phase 0.0 now reject empty and non-numeric (`^[0-9]{1,4}$`) sprint numbers before any path interpolation. Prior behavior: `SPRINT_NUMBER="../etc/passwd"` would expand into the path (431d8f4).
- **`STATE.md` detection regex** — `checkpoint-protocol.md` em-dash header variant (`# Sprint N — STATE`) and bold timestamp variant (`**Last updated:**`) now recognized; previous anchored regex silently mis-classified valid STATE files as corrupt. Replaced with non-anchored `grep -qE` structural validation (94cc94c).
- **`python3` one-liner `NameError`** — hook scripts using `python3 -c` for JSON construction no longer reference undefined locals; switched to `jq -n --arg` for all dynamic JSON-line construction (431d8f4).
- **Hook script logging consistency** — `block-no-verify`, `block-destructive-git`, `critic-gemini`, `permission-request`, `post-tool-failure`, `stop-failure`, `teammate-idle` now emit `{"event": "blocker_fired", ...}` lines via `_lib/common.sh::log_event` rather than ad-hoc `echo` (7a2021b).
- **`blitz-extract` JSONL safety** — embedded quotes, newlines, backslashes, and shell metacharacters in extracted values no longer corrupt downstream `jq` pipelines. New `digit-prefix` guard rejects identifiers starting with `[0-9]` (jq filter injection vector). 5 new fuzz tests cover the boundaries (3df3338).
- **`/blitz:next --loop` row 1a HARD_SPEC escalation** — `block_reason` vocabulary cross-referenced in `STATE.md` parsing so `LOOP_ESCALATE` fires before row 1 auto-resumes a stuck story (102ff52).

### Documentation

- **`agents/orchestrator.md`** — completeness pass for the routing table; every skill in `skills/` now has at least one trigger phrase mapped to it (39/39 coverage) (ea8e22d).
- **`docs/audits/audit-20260517*`** — final audit closure tracking: 9/9 epics shipped across sprints 9-12, full traceability from audit finding → epic → sprint → commit.

### Audit closure

All 9 epics from `docs/audits/audit-20260517.md` are now `done`:

| Epic | Title | Shipped in |
|------|-------|-----------|
| E-013 | Installer hygiene | sprint-9 |
| E-014 | Hook library + bats infrastructure | sprint-10 |
| E-015 | Skill frontmatter normalization | sprint-9 |
| E-016 | Anti-shortcut hardening | sprint-10 |
| E-017 | Token reduction (SKILL.md slimming) | sprint-11 |
| E-018 | Error-recovery robustness | sprint-11 |
| E-019 | Orchestrator routing completeness | sprint-12 |
| E-020 | Hook performance | sprint-9 |
| E-021 | Spawn-API + allowed-tools consistency | sprint-12 |


## [1.14.0] — 2026-05-17

Worktree lifecycle enforcement, 8 new platform-event hooks wired, 5 platform-feature primitives adopted, and 9 spec-fixing recipes ship in this release. Counts move to **39 skills · 10 agents · 36 hook scripts across 16 events · 26 shared protocols** with an **8-invariant** sprint-review gate and an **8-metric** ratchet. The README is rewritten ground-up from a parallel-agent deep-dive of the codebase.

### Added

- **`/blitz:worktree-prune` skill** (39th) — lists and safely deletes stale `worktree-agent-*`, `worktree-sprint-*-plan`, and `sprint-N/{role}` branches. Default `--dry-run` classifies by age + merge-status + divergence + disk; `--apply --merged-only` deletes ancestors of `origin/HEAD`; `--all-older-than 30d --force` reaps unmerged stale branches (83dd3bf).
- **Sprint-review Invariant 8 — Branch hygiene** — asserts every `sprint-${N}/{backend,frontend,tests,infra,integration}` branch was deleted by sprint-dev Phase 4.4 (83dd3bf).
- **Ratchet metric 8 — `stale_worktree_branch_count`** — cumulative count of leaked worktree branches; ↓ direction. Existing projects run `code-sweep --baseline stale_worktree_branch_count` once to grandfather pre-fix debt (83dd3bf).
- **8 platform-event hooks wired** as logging-first stubs (all exit 0, no behavior change): `SubagentStart`, `SubagentStop`, `PostToolBatch`, `PostToolUseFailure`, `StopFailure`, `PermissionRequest`, `WorktreeCreate`, `WorktreeRemove`. Activity-feed proves wiring; each carries a candidate-future-work comment block. Hook scripts: 28 → 36; hook events: 8 → 16 (ee605cd).
- **`skills/_shared/worktree-lifecycle.md`** — canonical contract for `Agent({isolation: "worktree"})` branch lifecycle. Referenced by sprint-dev, spawn-protocol, state-handoff, checkpoint-protocol (83dd3bf).
- **`skills/_shared/quality-matrix.md`** — decision table for the 7 quality-related skills (sprint-review × codebase-audit × code-doctor × code-sweep × completeness-gate × integration-check × review). Documents why apparent overlaps are real distinctions (edf1d1b).
- **`skills/_shared/deterministic-test-recipe.md`** — vitest/jest deterministic-test patterns (fake timers, seeded randomness, MSW). Cited by test-writer + test-gen as a discoverability pointer (aa20279).
- **`output-styles/terse-technical.md`** — plugin-level OUTPUT STYLE with `force-for-plugin: true`. Pilot; does not yet retire the per-SKILL.md snippets or Invariant 5 (7e5b71a).
- **HARD_SPEC complexity classifier in `agents/test-writer.md`** — 6-signal detector (timers, stochastic, network, deep async, singletons, mock-heavy). Emits `INVESTIGATE:` on HARD_SPEC. Spec Fix Prompt Template (verification-first oracle, "fix impl not assertions"), per-spec turn cap (10 tool calls, then `ESCALATE: spec-investigation-budget-exhausted`) (d57ac60).
- **`block_reason` field on `agent_tracker`** — 6-value controlled vocabulary (`hard_spec`, `oracle-underivable`, `test-assertion-suspect`, `scope-expansion-needed`, `circuit-breaker`, `dependency-missing`). Per-Story Scope Constraint with `SCOPE_FILES` injection (advisory `ESCALATE: scope-expansion-needed`, not a hard block) (d57ac60).
- **Per-call output budget** in `spawn-protocol.md` §2 — per-model safe write ceiling table (sonnet 32KB, opus 48KB, haiku 16KB). New banned pattern #6: single Write > 40 KB (sonnet) / > 64 KB (opus). `compress` skill auto-routes 40–500 KB targets to sectioned-Edit mode (784abe5).
- **`/blitz:next --loop` HARD_SPEC awareness** — Phase 0.10 detects HARD_SPEC-blocked stories from `STATE.md`; row 1a short-circuits row 1 with `LOOP_ESCALATE` so the loop doesn't blindly resume on stuck specs (d57ac60).
- **Orchestrator ask-before-code routing** — `agents/orchestrator.md` §6.1: "fix this failing spec" + HARD_SPEC signals routes to read-only investigation before edit (d57ac60).
- **Karpathy Clarification Gate** in `CLAUDE.md` — autonomy-gated "Think Before Coding" step. Builder agents (backend-dev, frontend-dev) gain Phase 0 Think + minimum-code + surgical-scope rules. Adapted from `multica-ai/andrej-karpathy-skills` (MIT) (4f688f9).
- **Scope Discipline checklist** in `definition-of-done.md` + reviewer scope-check in `spawn-protocol.md` §6 (4f688f9).

### Changed

- **`disable-model-invocation: true` on `ship`, `release`, `migrate`** — user-only invocation for destructive ops. Removes their descriptions from the always-loaded skill listing (saves listing-budget tokens). Slash invocations still work; the model can no longer auto-fire them (7e5b71a).
- **`paths:` field on `code-doctor`** — Vue/Firestore/Pinia globs gate conditional auto-load. Plus `ultrathink` keyword in `codebase-audit` body for the 5-pillar synthesis (7e5b71a).
- **`memory: project` on `critic`, `reviewer`, `architect`** — cross-session lessons coverage now 6/10 agents (7e5b71a, b6201fe).
- **`sprint-dev` Phase 4.4 deletes per-role branches** post-merge (was: only `git worktree remove`, which leaked branches every sprint). Escape: `BLITZ_SKIP_BRANCH_CLEANUP=1` (83dd3bf).
- **`sprint-dev` Phase 0.1 resume divergence gate** — detects branches with commits ahead of merge-base before re-spawning. Behavior: `BLITZ_RESUME_ON_DIVERGENCE={prompt|abandon|halt}` (default `halt`) (83dd3bf).
- **`worktree-create.sh` aborts collision** — when a `worktree-agent-<8hex>` stale branch has commits ahead of `origin/HEAD`. Escape: `BLITZ_ALLOW_WORKTREE_COLLISION=1`. Fixes GH#51596 silent stale-branch reuse (83dd3bf).
- **`worktree-remove.sh` opportunistic cleanup** — deletes `worktree-*` branches that are ancestors of `origin/HEAD` (best-effort, never blocks) (83dd3bf).
- **`compress` skill** — Phase 0.2 classifies target by 40 KB threshold; Phase 2.4 single-Write mode (≤40KB), Phase 2.5 sectioned-Edit mode (>40KB) (784abe5).
- **Plugin manifest description** updated for new counts and capabilities. Homepage + repository URLs corrected to `lasswellt/cc-plugin-suite` (this release).

### Fixed

- **`workflow-guard.sh` reclassified** from "anti-shortcut blocker" to "warner" (per script line 4 comment). Anti-shortcut blocker count in `hooks/scripts/README.md` corrected to 6. `CLAUDE.md` was already correct (b6201fe).
- **`quality-matrix.md` phase labels** — sprint-review Phase 3.7 was wrongly labeled "critic agent". Actually Phase 3.7 = "Automation Coverage — Declare Boundary"; critic runs inside Phase 3.6 as Invariant 7 (b6201fe).
- **README stale counts** reconciled across multiple passes — 38→39 skills, 8→16 hook events, 27→36 hook scripts, 19→26 shared protocols (37b761f, e8545bb, 8ac21aa, 424794f).
- **`README.md` autonomous-loop entry point** — corrected from `/loop /blitz:sprint --loop` to `/loop /blitz:next --loop` (canonical since v1.13.0) (8477f52).
- **`worktree-remove.sh` defensive append** — aligned `2>/dev/null || true` with `worktree-create.sh` for consistency (b6201fe).

### Documentation

- **`README.md` ground-truth rewrite** — spawned 5 parallel Explore agents to audit `skills/`, `agents/`, `hooks/`, plugin metadata, and quality-gate mechanics independently of the prior README. Tiered reading paths (evaluator / installer / contributor). New sections: carry-forward lifecycle state diagram, ratchet metric table, worktree lifecycle, token-budget routing matrix, autonomous-loop stop signals, BLITZ_* env-var override table (424794f).
- **`CLAUDE.md` count reconciliation** — agents 8→10 (added explicit roster), shared 19→26, hooks 26→36 across 8→16 events (8ac21aa, edf1d1b, e8545bb, 83dd3bf).
- **`hooks/scripts/README.md`** — added rows for all 6 anti-shortcut blockers, `agent-frontmatter-validate`, `post-edit-typecheck-block`, and `critic-gemini` (8ac21aa).

### Other

- **`chore(ui-audit)`** — compressed `references/main.md` via sectioned-Edit mode (1570 → 1566 lines, 70756 → 64277 bytes; 50 Edits across 15 sections). Investigation showed 6 of 7 originally-scoped targets were already at minimum size (d6746f8).

### Retracted

- **`fallbackModel` on opus skills** — re-reading platform docs confirms `fallbackModel` is an Agent SDK option (`query({...})`), not a `SKILL.md` or agent frontmatter field. Cannot be adopted in plugin context. Removed from the platform-frontmatter adoption target (b6201fe).

### Migration

Drop-in upgrade from v1.13.0. Two opt-in baselines for existing projects:

1. **Ratchet baseline for stale branches** — run `/blitz:code-sweep --baseline stale_worktree_branch_count` once to grandfather pre-fix worktree debt. Without this, sprint-review Invariant 6 may flag the new 8th metric on first run.
2. **Resume divergence behavior** — `BLITZ_RESUME_ON_DIVERGENCE` defaults to `halt`. If you prefer the prior behavior (re-spawn without divergence check), set `BLITZ_ALLOW_WORKTREE_COLLISION=1` and `BLITZ_RESUME_ON_DIVERGENCE=abandon`.

No breaking changes. All existing slash commands work unchanged.

## [1.13.0] — 2026-05-16

`/blitz:next --loop` is now the canonical autonomous reconciliation engine. `/blitz:sprint --loop` becomes a backwards-compat alias that dispatches to it. Same Observe → Diff → Act → Report semantics, same scheduling tiers, same 8-row decision tree, same stop signals — but the engine now lives in the skill whose scope is "what should I do next?" rather than "run a sprint", reflecting that autonomous reconciliation handles the full project lifecycle (bootstrap, roadmap creation, ship, carry-forward gap closure) and not just the sprint cycle.

### Added

- **`/blitz:next --loop`** (`skills/next/SKILL.md`) — new autonomous reconciliation mode. Reads state, executes one phase, commits + pushes, exits. Designed for `/loop /blitz:next --loop` (external loop wrapper) or self-scheduled `ScheduleWakeup` when invoked directly. Sets autonomy to `full` (all sub-skill confirmation prompts auto-approved). Full reconciliation spec: Phases 3 (Act) and 4 (Report) of the skill body. Two new tools in `allowed-tools`: `Skill` (for dispatch) and `ScheduleWakeup` (for self-scheduling).
- **8-row decision tree** ported into `next` from sprint --loop:
  - Row 0: uningested research (newer than roadmap-registry.json AND scope-IDs not yet in carry-forward) → dispatch `/blitz:roadmap extend`
  - Row 1: in-progress sprint + STATE.md → `/blitz:implement --resume`
  - Row 2: in-progress sprint without STATE.md → `/blitz:implement --sprint N`
  - Row 3: status `review` → `/blitz:review --sprint N`
  - Row 4: status `reviewed` + quality passing → `/blitz:ship`
  - Row 5: status `planned` → `/blitz:implement --sprint N`
  - Row 6a: `CF_ESCALATED > 0` (rollover_count ≥ 3) → human-review escalation, exit with `LOOP_ESCALATE` marker
  - Row 6b: `CF_PENDING_INPUTS == 1` (planning-inputs file from prior review Invariant 4) → `/blitz:sprint-plan`
  - Row 6c: roadmap with unblocked epics → `/blitz:sprint-plan`
  - Row 6d: `CF_ACTIVE > 0` (carry-forward registry has active/partial entries) → `/blitz:sprint-plan` (re-select parent epics)
  - Row 7: nothing to do → idle, exit with `LOOP_DONE` marker
  - Row 8: no roadmap + `CF_ACTIVE == 0` → `/blitz:roadmap full`

  Tie-breaking, carry-forward awareness, and the row 6a-6d split (preventing silent scope drops per `docs/_research/2026-04-08_sprint-carryforward-registry.md`) carry forward unchanged.

- **Stop signals** emitted in the per-tick reconciliation banner so `/loop` wrappers know when to halt:
  - `LOOP_DONE` (row 7 idle) — external `/loop` MAY halt
  - `LOOP_ESCALATE` (row 6a) — external `/loop` SHOULD halt (re-firing only re-prints the escalation)
  - `LOOP_DEFER` (active session conflict) — keep ticking; next tick may find the conflict resolved
  - (no marker) — phase dispatched; next tick should re-evaluate state

### Changed

- **`/blitz:sprint --loop` is now a thin alias** that dispatches `/blitz:next --loop` via the `Skill` tool and exits. The ~175-line `## Loop Mode: Reconciliation Phase (--loop only)` section in `skills/sprint/SKILL.md` is replaced by a ~15-line alias-and-rationale block. `sprint/SKILL.md` shrunk from 339 → 119 lines (−65%). Scripted `/loop /blitz:sprint --loop` invocations continue to work — each tick alias-routes to `/blitz:next --loop` which executes one phase.
- **`agents/orchestrator.md` §2 routing** updated: added a dedicated row for "autonomous loop" intents that routes to `/blitz:next --loop`, with a cross-reference noting it supersedes `/blitz:sprint --loop`. The "what should I do next?" row for `/blitz:next` now mentions the `--loop` autonomous mode.

### Migration

No user-facing breaking changes. Drop-in upgrade from v1.12.2.

- **If you scripted `/loop /blitz:sprint --loop`**: continues to work, every tick now alias-hops through one extra layer. Optional: migrate to `/loop /blitz:next --loop` to skip the alias hop.
- **If you scripted `/blitz:sprint --loop` directly** (no external `/loop`): continues to work, sprint --loop dispatches next --loop which dispatches the appropriate phase. Optional: migrate to `/blitz:next --loop` for the canonical direct invocation.
- **If you have automation expecting specific reconciliation-banner text**: per-tick report now starts with `[next --loop]` instead of `[sprint] Loop reconciliation`. Update grep patterns accordingly.

### Compatibility

No new env vars. New `allowed-tools` entries on `next/SKILL.md` (`Skill`, `ScheduleWakeup`) — required for the autonomous dispatch + self-scheduling behavior. Drop-in upgrade from v1.12.2.

## [1.12.2] — 2026-05-16

Token-saving patch — `/blitz:compress` rerun on `skills/sprint-review/references/main.md` after v1.12.0 added substantial content (Phase 0.0 Input Gate, Automation Coverage Block, Reviewer Spawn Strategy, Phase 2.5 Browser Verification, Invariant 6/7 Procedures). Reclaims ~300 tokens per `/blitz:sprint-review` invocation that loads this reference.

### Changed

- **`skills/sprint-review/references/main.md`** — prose tightened across 14 sections via 20 sectioned Edits. 35,727 → 34,427 bytes (−1,300, 3.6%); 825 → 817 lines (−8). All structural invariants exactly preserved: 40/40 code fences, 90/90 headings, 119/119 table rows, 0/0 URLs. Validates clean against `reference-compression-validate.sh` (v1.12.1 loss-only semantics).
- **`skills/sprint-review/references/main.md.original`** — refreshed to pre-compress snapshot (the prior v1.12.1 refresh was a same-content sync to clear stale drift; this release's `.original` is a true backup of the v1.12.1 pre-compress content, enabling the validator to detect any future content loss).

### Process note

The /blitz:compress skill works well end-to-end on files ≤ ~35KB but timed out on `skills/ui-audit/references/main.md` (70KB / 1570 lines) — the per-call sonnet output budget cannot produce a single 50KB+ Write. Future work: extend compress to support a chunked (sectioned-Edit) mode for files >40KB. Tracked separately.

### Compatibility

No new env vars. No new APIs. No behavior changes. Drop-in upgrade from v1.12.1.

## [1.12.1] — 2026-05-16

**Critical patch.** v1.12.0's `reference-compression-validate.sh` PreToolUse hook blocked every blitz user's `git commit` regardless of whether their project had any `references/main.md.original` pairs. Two structural fixes plus drift cleanup.

### Fixed

- **`hooks/scripts/reference-compression-validate.sh` — scope changed from plugin cache to user repo.** Prior `REPO_ROOT="$(dirname $0)/../.."` pointed into the plugin install directory, so drift in OUR bundled `.original` files (sprint-review and research references/main.md, which I edited across recent sprints without refreshing their snapshots) blocked every user's commit. New behavior: `REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"`. The `find` then operates on the caller's repo. Most user projects have no `.original` files — find returns nothing, hook exits 0 immediately. Plugin developers running commits inside the plugin repo still get the validation as before.
- **Hook validation is now loss-only.** v1.12.0's strict-parity checks (`code-fence count != original`, `URL set drift`, `heading drift`, `table-row count !=`) couldn't distinguish "compression lost content" from "later sprint added new sections." Both produced the same FAIL. The compressed form **must** preserve all of the original's structural elements (≥ counts; ⊇ URL and heading sets), but it **may** contain additional content. Surfaces only real content-loss; tolerates legitimate additions.
- **Exit code downgraded from 2 to 1 in hook mode.** Plugin-internal drift must not hard-block user commits. Failure now prints an advisory and exits 1, leaving the user free to proceed via `--no-verify` for the affected commit. Direct invocation (CI / verify) is unchanged.
- **`skills/sprint-review/references/main.md.original` + `skills/research/references/main.md.original` refreshed** to current state. The originals dated from April 16-18 (sprint v1.7 era) and had not been refreshed when subsequent sprints added Phase 0.0 Input Gate, Automation Coverage Block, Reviewer Spawn Strategy, Phase 2.5 Browser Verification, Invariant 6/7 Procedures, etc. After this refresh, the validator passes all 16 pairs cleanly inside the plugin repo. Future drift will surface as real failures.

### Workaround for users still on 1.12.0

Until upgrade, either of:

```bash
# One-off commit (acceptable for this hook only — bypassing blitz's own
# anti-shortcut hooks like block-no-verify.sh is NOT recommended)
git commit --no-verify -m "..."
```

Or disable the hook in `.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "Bash",
      "hooks": [{
        "type": "command",
        "command": "/path/to/cache/blitz/blitz/1.12.0/hooks/scripts/reference-compression-validate.sh",
        "disabled": true
      }]
    }]
  }
}
```

### Compatibility

No new env vars. No breaking changes. Drop-in upgrade from v1.12.0.

## [1.12.0] — 2026-05-16

Minor release across three themes: (1) incorporating six specialist-agent patterns from GitHub's May-15-2026 accessibility-agent post-mortem; (2) closing two broken pipeline handoffs (sprint-review and ship) plus a self-audit-driven compactness + consistency sweep; (3) a four-iteration recursive cycle that hardened audit-agent false-positive prevention, validated against Anthropic's shipped Code Review Plugin pattern, and converged to a stable rule.

### Added — GitHub accessibility-agent pattern incorporations

Six patterns from `docs/_research/2026-05-16_github-accessibility-agent-patterns.md` (commit `317c47d`). The blog reported 3,535 PRs reviewed at 68% resolution rate; we mapped its 8 reusable patterns + 5 failure modes against blitz state and adopted six:

- **KNOWLEDGE.md slice injection** into sprint-dev worker prompts (`skills/sprint-dev/SKILL.md` Phase 0.5 + Dev Agent Prompt Specification item 14). Counters training-data bias per [knowledge-protocol.md](skills/_shared/knowledge-protocol.md) — workers see project-specific gotchas before generation, not after type-check fails post-hoc. Opt-out: `BLITZ_SKIP_KNOWLEDGE_INJECTION=1`.
- **Pre-flight complexity gate** in `sprint-dev/SKILL.md` Phase 1.4: `complexity_score = story_count * 2 + est_loc / 100`. Warn at >40, hard-stop at >80 (escape: `BLITZ_SPRINT_COMPLEXITY_OVERRIDE=1`). Prevents token-explosion that the ratchet only catches retrospectively.
- **Sequential review fallback** in `sprint-review/SKILL.md` Phase 2.2.0: triggered by `BLITZ_REVIEW_SEQUENTIAL=1` or diff >2000 LOC. Passes prior reviewer findings as `## Prior Reviewer Findings` context to the next spawn. Default parallel behavior unchanged.
- **Reviewer "Instruction Gaps" field** in `sprint-review/references/main.md`: non-empty entries route to `.cc-sessions/KNOWLEDGE.md` under `## Skill Instruction Drift — <reviewer-role>`, creating an automated feedback loop from reviewer agents to skill authors.
- **Phase 3.7 Automation Coverage** in `sprint-review/SKILL.md`: declares deterministic-gates-passed vs human-judgment-required boundary. Sets `REVIEW_RECOMMENDATION` to `auto-merge-safe` (all gates + Phase 2.5 `full` + zero critical/major) or `needs-human-review` otherwise. Mitigates F4 over-confidence by making the gap explicit in the report.
- **Mandatory Playwright gate** in `sprint-review/SKILL.md` Phase 2.5: when MCP available, skipping smoke test counts as `phase_2_5_coverage: partial` and surfaces in Phase 4 Recommendations. When unavailable, gate still skips silently (gap, not failure).

### Added — Audit-Agent False-Positive Prevention

Self-Falsification + Confidence pattern (commit `6199a65`), mirrored on Anthropic's shipped Code Review Plugin (github.com/anthropics/claude-code/plugins/code-review, 129K+ installs, <1% FP rate). Driven by 3 false positives in the 2026-05-16 self-audit + literature review (CHIIR 2026, EMNLP 2025, arxiv 2309.11495 CoVe).

- **`skills/codebase-audit/references/main.md`** Rules block: new rule 2 (Falsify before recording — count/negative/duplication artifacts) + rule 3 (Confidence: 0-100 on every finding). Pillar agents inherit immediately. Refined across 3 iterations to add: routing for `Confidence < 50` to `## Discarded Drafts`, `## Verified Clean` section for no-violation reports, and count-discipline rule disambiguating `grep -l | wc -l` (files) from `grep -rn | wc -l` (hits).
- **`skills/_shared/agent-prompt-boilerplate.md`** §Self-Falsification: inheritance target for all future audit-style skills via Pattern A author-time reference. Same 5 clauses as above plus a `${VAR}` output-path resolution clause to prevent agents from taking placeholder text literally.
- **`skills/_shared/shortcut-taxonomy.md`** detector #20 (Unverified pattern-match claim): P3 advisory tier; canonical grep pattern in §3 that flags Evidence blocks with count-only claims or missing Confidence scores.
- **`agents/critic.md`** §2.9: audit-finding integrity check that fires detector #20 against audit findings files in the sprint diff. Advisory only — adds findings to critic `issues[]` with `severity: advisory`, signaling re-run with Self-Falsification rule.
- **`skills/codebase-audit/SKILL.md`** Phase 2.1.5: confidence threshold filter (default 80, tunable via `BLITZ_AUDIT_CONFIDENCE_THRESHOLD`). Filters findings below threshold before deduplication. Findings missing Confidence trigger detector #20 advisory.

The four-iteration cycle (initial implementation → generous test → blind retest #1 → blind retest #2) reached a fixed point: blind retest #2 surfaced zero new rule gaps and only two Confidence-65 housekeeping items, both verified real on independent falsification.

### Added — Shared Protocols

- **`skills/_shared/skill-cross-references.md`** (new) — canonical source-of-truth for the 2-line "Additional Resources" block (spawn-protocol + terse-output refs) shared by 7 SKILL.md files. Each file carries an `<!-- import: from _shared/skill-cross-references.md ... -->` marker. No runtime line reclaim — Claude Code's skill loader needs each SKILL.md to declare its own resources — but provides a canonical-wording target plus a drift-detection grep snippet at the file's bottom.
- **`skills/_shared/project-context.md`** (new) — canonical source-of-truth for the `## Project Context` heading + `detect-stack.sh` invocation shared by 29 SKILL.md files. Same `<!-- import: -->` marker pattern. design-extract is intentionally excluded (has bespoke body). The independent-falsification process that produced this file disambiguated three counts (30 files with heading, 29 with full block, 30 grep-hits) — the kind of confusion the new count-discipline rule prevents.

### Fixed — Broken Pipeline Handoffs

- **`skills/sprint-review/SKILL.md` Phase 0.0** — hard-fail input gate on `sprint-registry.json`, `${SPRINT_DIR}/manifest.json`, and `${SPRINT_DIR}/stories/S*.md`. Override (not recommended): `BLITZ_REVIEW_NO_MANIFEST=1`. State-handoff.md declared sprint-review consumed manifest.json but the skill never gated on its existence — would proceed silently on missing input. Bash block lives in `references/main.md §Phase 0.0 Input Gate`.
- **`skills/ship/SKILL.md` Phase 0.1** — added `[ -s "${SPRINT_DIR}/review-report.md" ] || exit 1` check when sprint context exists. Ship would previously cut a release without a passing review when the review-report file was missing.

### Changed — Self-Audit Driven Sweep

Three waves of fixes from `docs/_research/2026-05-16_blitz-self-audit.md` (commits `b06fa08`, `4182ea0`, `cbada5b`):

- **18 SKILL.md compatibility floors** bumped from `>=2.1.50` to `>=2.1.71` (CLAUDE.md-declared project floor). Affects ask, bootstrap, browse, completeness-gate, dep-health, fix-issue, health, migrate, next, perf-profile, quick, refactor, release, retrospective, test-gen, todo, ui-audit, ui-build. `design-extract` retains `>=2.1.117` (holistic-machine orchestrator dependency, now annotated with an HTML comment in the file).
- **`agents/orchestrator.md` §2 routing matrix** expanded from 19 to 38 skills (full coverage of the user-invocable skill catalog). Reorganized into 5 intent groups: greenfield/setup, sprint pipeline, research/audit/quality, dev/maintenance, diagnostics/meta. The two greenfield-pipeline entry points (`bootstrap` and `roadmap`) were previously unrouted from natural-language input.
- **`skills/_shared/verbose-progress.md`** Sprint Selection Verbosity section: 300→247 lines (−53). Replaced 85-line per-format ASCII-art dashboard examples with a 4-row trigger/format/content table plus three condensed canonical examples. Box-drawing dashboards still acceptable but the inline form is now also valid.
- **`skills/_shared/spawn-protocol.md` §7** trimmed: ~21 lines reclaimed via Output Style prose tightening; Historical Reference section (v1.4.0 merge notes) deleted.
- **7 SKILL.md persona preambles trimmed** (bootstrap, completeness-gate, dep-health, retrospective, migrate, release, perf-profile): dropped "You are a X. You..." framing while keeping the imperative-mood description. The frontmatter description already conveys the role. ui-audit and browse preserved as-is — their preambles contain meaningful read-only constraints and loop-mode behavior worth keeping inline.
- **v1.4.0 SendMessage tombstone dedup** (research, sprint-plan, sprint-review, codebase-audit): five identical historical paragraphs collapsed to single-line `synthesized by orchestrator (not peer-to-peer, per spawn-protocol.md)` references. Exact duplicate at `research/SKILL.md:155` deleted entirely.
- **`skills/research/SKILL.md:92`** dangling reference: relative `../_shared/token-budget.md` → canonical absolute `/_shared/token-budget.md`.
- **`skills/health/SKILL.md` description**: "activity feed" → "activity-feed" (hyphen form when referring to the `.cc-sessions/activity-feed.jsonl` file, matching retrospective's description).
- **`skills/design-extract/SKILL.md`**: HTML comment after frontmatter explains why compatibility floor is `>=2.1.117` (requires holistic-machine orchestrator for the DESIGN.md handoff to ui-build, frontend-design, and design-critic).

### Compatibility

No breaking changes. Drop-in upgrade from v1.11.2.

- New env vars introduced (all opt-out / tunable): `BLITZ_SKIP_KNOWLEDGE_INJECTION`, `BLITZ_SPRINT_COMPLEXITY_OVERRIDE`, `BLITZ_REVIEW_SEQUENTIAL`, `BLITZ_REVIEW_NO_MANIFEST`, `BLITZ_AUDIT_CONFIDENCE_THRESHOLD`.
- New shared protocols (5 total now at 23 files: was 21): `skill-cross-references.md`, `project-context.md`.
- New detector (#20 in `shortcut-taxonomy.md`): P3 advisory tier, does not block sprint-review.

## [1.11.2] — 2026-05-02

Patch release adding a single new shared protocol that closes a high-frequency drift source: agents picking outdated package versions from training memory.

### Added

- **`skills/_shared/package-install-policy.md`** (new shared protocol, 21st `_shared/` file). Single source of truth for `pnpm add` / `npm install` / `yarn add` / `bun add` behavior across every skill and agent that touches `package.json`. Three states with one rule each:
  1. **Net-new dependency, no user-specified version** → bare `pnpm add <pkg>` (no `@latest`, no invented number) so the package manager resolves the registry's `latest` tag.
  2. **User explicitly specified a version** → use exactly what they said. Their intent is authoritative.
  3. **Peer-compatibility constraint** → resolve from the project's existing peer (`node -p "require('./package.json').dependencies['vite']"`), pin to that major.

  Mandatory verification step after install: `npm view <pkg> version` cross-check against the resolved version. Anti-pattern catalog (5 patterns) included for reviewer reference: invented versions, `^1.0.0` "to be safe" pins, direct `package.json` editing without install, copy-pasted snippets from stale tutorials, `"foo": "*"` or `"foo": "latest"` in the manifest.

### Changed

- **`agents/backend-dev.md` + `agents/frontend-dev.md`** — new "Package Install Policy" section in the agent body, two paragraphs above Stack Detection. Inlined summary + reference to the protocol.
- **`skills/bootstrap/SKILL.md` + `skills/migrate/SKILL.md` + `skills/dep-health/SKILL.md` + `skills/quick/SKILL.md`** — Additional Resources entry pointing to the new protocol. Migrate's note clarifies that the migration target version is the case-2 user-specified exception; secondary deps follow the latest-resolution rule.
- **`skills/sprint-dev/SKILL.md` + `skills/sprint-dev/references/main.md`** — Dev Agent Prompt Specification now has 13 items (was 12). New item 13 injects a 5-line verbatim PACKAGE INSTALLS block into every backend-dev / frontend-dev / test-writer spawn so dev agents see the policy directly in their system prompt, not via cross-link.
- **Shared-protocol count**: 21 files (was 20; added `package-install-policy`).

### Future work

- **`hooks/scripts/block-stale-package-add.sh`** (planned for v1.12) — `PreToolUse` hook that intercepts Bash commands of the form `pnpm add foo@<version>` and rejects when `<version>` is more than 1 major behind the registry latest. Override: inline `// blitz:version-pinned: <reason>`.

### Compatibility

No breaking changes. Drop-in upgrade from v1.11.1.

## [1.11.1] — 2026-05-02

Patch release driven by lessons from the first real `/blitz:sprint-dev` run on v1.11.0 (sprint-276 — 8 regressed `@mbk/web` test files). Two structural workload-sizing gaps surfaced; both are now fixed. Also addresses an orchestrator hallucination in sprint-review that misreported the Cross-Model Critic install state.

### Fixed

- **`skills/sprint-dev/SKILL.md` — per-wave file cap.** The existing 4-stories-per-agent cap allowed sprint-276 to assign one test-writer 8 files (3 stories: 2 + 1 + 5). At ~5-7 tool calls per file, that's 48-56 tool calls — exhausts Heavy-class budget mid-work. Added a complementary **6-files-per-agent-per-wave** cap; whichever bites first triggers the split. Sprint-dev now refuses to pack a 5-file story alongside two 1-file siblings even though story count = 3.
- **`skills/sprint-plan/SKILL.md` §3.1.1 — bulk-story guard tightened.** The file-count heuristic was `> 8 files → mandatory split`. The 5-file S276-003 story sat in the gap between the 1-3 file granularity target and the 8-file guard, slipping through unsplit. Replaced with a two-band heuristic: `> 5` is mandatory split (was `> 8`); `4-5` is soft warn with a `decision` event log; `1-3` is green (matches §3.1 target).
- **`skills/_shared/spawn-protocol.md` — Resume Protocol.** New canonical `SendMessage` payload for resuming a budget-exhausted (PARTIAL) agent. Must include `COMPLETED` (verbatim from prior reply), `REMAINING` (original task list minus completed), `WORKTREE`, `HEAD`, and `DO NOT` (re-explore, re-read, re-test) lists. Without it, resumed agents burn ~60% of fresh budget rebuilding context — exactly what re-exhausted S276-003 on first SendMessage. If the prior PARTIAL marker is missing or malformed, spawn fresh instead — stateless restart is cheaper than confused continuation.
- **`skills/sprint-review/references/main.md` §Invariant 7 — explicit mode-resolution algorithm.** During the v1.11.0 dual-CMC sprint-review run, the orchestrator emitted *"Critic agent available (sonnet, in-Claude only — critic-gemini.sh not installed in this plugin version)"* despite both `critic-gemini.sh` and the `gemini` binary being present. Replaced the implicit logic with a 4-step probe (env intent → script existence → binary existence → resolve) and a single canonical `[critic] mode=...` line. Each fallback path produces a precise diagnostic ("gemini binary missing" vs "critic-gemini.sh missing — plugin <v1.11.0?"); orchestrators are forbidden from improvising the message.

### Documentation

- **All skills with sparse `argument-hint:` frontmatter expanded** — 12 skills (`roadmap`, `review`, `ship`, `doc-gen`, `release`, `perf-profile`, `dep-health`, `quality-metrics`, `sprint`, `setup`, `code-doctor`, `conform`) now describe each mode/flag inline in the slash-command UI rather than just naming them. Matches the richer pattern already used by `browse`, `ui-audit`, and `code-sweep`. No behavioral change.

### Compatibility

No breaking changes. Drop-in upgrade from v1.11.0.

## [1.11.0] — 2026-05-01

The "autonomous holistic-machine" release. Two research investigations (`docs/_research/2026-05-01_skills-to-agents-architecture.md` and `docs/_research/2026-05-01_autonomous-blitz-quality-efficiency.md`) drove a six-wave implementation: P0 anti-shortcut hooks, token-efficiency protocol, autonomy primitives (PreCompact handoff + auto-resume), critic adversarial review, frontend-design integration, and a top-level orchestrator agent that provides freeform-input routing alongside the existing slash commands.

### Added

- **`agents/orchestrator.md`** — top-level holistic-machine router. Receives freeform input ("research X", "implement the sprint"), surfaces in-flight state from `.cc-sessions/HANDOFF.json` + activity-feed, and routes to the right slash skill. Activated via new `.claude-plugin/settings.json {"agent": "orchestrator"}` (Claude Code ≥2.1.117). Slash commands bypass the orchestrator and run unchanged. Disable per-session via `BLITZ_DISABLE_ORCHESTRATOR=1`. Read-only by construction (no Write/Edit/Agent — subagents cannot spawn subagents).
- **`agents/critic.md`** — read-only adversarial pre-PASS reviewer (Read/Grep/Glob/Bash only). Runs the 19-detector shortcut taxonomy + ratchet + acceptance-checks + hallucinated-symbol spot-check. Returns canonical JSON `{verdict: LGTM | REJECT}`. `sprint-review` Phase 3.6 Invariant 7 cannot reach PASS without LGTM.
- **`agents/design-critic.md`** — vision-model design-quality scorer (5 dimensions 0-10: Prompt Adherence, Aesthetic Fit, Visual Polish, UX, Creative Distinction). Reads `/tmp/ui-build-screenshots/*.png` against `DESIGN.md` or `frontend-design-heuristics.md`. Verdicts PASS/ITERATE/REWORK. Wired into `ui-build` Phase 5.4.2 with `design_quality: skip|standard|high` story switch.
- **`skills/design-extract/SKILL.md`** — reads brownfield project tokens (Tailwind config, CSS variables, font sources, accent-color usage) and emits `DESIGN.md` (Google Labs Apache-2.0 spec). Bootstraps the design-critic / ui-build / frontend-design pipeline.
- **7 anti-shortcut hooks** (all `exit 2` blocking, registered in `hooks/hooks.json`):
  - `block-no-verify.sh` — blocks `git commit --no-verify`. Emergency override `BLITZ_OVERRIDE_NO_VERIFY=1` (logged). Closes anthropics/claude-code#40117 (March 2026 incident: 6 commits with 63 failing tests landed via --no-verify).
  - `block-destructive-git.sh` — blocks `git reset --hard`, `checkout -- .`, `clean -f`, force-push to main, `branch -D` on current branch when working tree dirty.
  - `block-destructive-sql.sh` — blocks DROP TABLE / DELETE FROM-no-WHERE / TRUNCATE / FLUSHDB / Mongo `.drop()` outside migration paths. Closes Cursor+Railway production-DB deletion class.
  - `block-test-deletion.sh` — blocks `rm` of test files, renames test→non-test, Write that drops all assertions to zero.
  - `post-edit-typecheck-block.sh` — runs `tsc --noEmit` after Write to .ts/.vue and rejects edit if error count rose vs `.cc-sessions/typecheck-baseline.json`. Replaces always-exit-0 behavior for type errors specifically.
  - `block-as-any-insertion.sh` — PreToolUse on Write/Edit/MultiEdit. Counts `as any` / `@ts-ignore` / `@ts-nocheck` deltas in non-test source. Blocks introductions without an inline `// blitz:any-allowed: <reason>` justification (escape hatch from `shortcut-taxonomy.md` §4).
  - `block-test-disabling.sh` — PreToolUse on Write/Edit/MultiEdit to test files. Blocks insertions of `.skip(`, `.only(`, `xit`, `xdescribe`, `xtest`, `test.todo(` without an inline `// blitz:skip-pinned: #<issue>` justification.
- **`skills/_shared/token-budget.md`** — model routing (60% Haiku / 35% Sonnet / 5% Opus), mandatory `cache_control: {ttl: "1h"}` on orchestrator system prompts ≥1024 tokens (default 5min TTL — silently dropped from 60min — is net negative without opt-in). Canonical JSON subagent reply contract. Lazy skill loading. Deferred MCP via ToolSearch. Combined target: 50-70% cut on top of 15× multi-agent baseline.
- **`skills/_shared/ratchet-protocol.md`** — 7 monotonic quality metrics (`test_count`, `type_errors`, `as_any_count`, `lint_violations`, `completeness_score`, `mocks_in_src`, `todo_count`). `docs/sweeps/ratchet.json` schema. Tighten-on-improvement, never loosen. Multi-agent worktree merge takes `min(max_allowed)` deterministically. Auto-revert on deterministic regression; test_count regressions only flag (could be flaky removal).
- **`skills/_shared/shortcut-taxonomy.md`** — 19-detector catalog with canonical grep patterns, severity tiers (P0/P1/P2/P3), false-positive escape hatches.
- **`skills/_shared/knowledge-protocol.md`** + bootstrapped **`.cc-sessions/KNOWLEDGE.md`** — cross-session lessons format (`Context / Lesson / How to apply`). Append-only paragraphs. Injected into autonomous-loop dispatches. Pruned at 500 lines; archived past 365 days. `.gitignore`d by default. Three seed entries about plugin-agent restrictions, subagent-spawn constraints, the cache TTL pitfall.
- **`skills/_shared/frontend-design-heuristics.md`** — paraphrased Anthropic frontend-design philosophy (license-safe; upstream ships under non-standard `LICENSE.txt`). 13-tone selector, NEVER list (Inter/Roboto/Arial/Space Grotesk + purple-on-white + uniform corners + all-centered + default Tailwind palette).
- **`skills/_shared/agent-routing.md`** — orchestrator routing decision tree. Documents the constraint that subagents cannot spawn subagents; super-orchestrator skills stay slash-invoked. 4-class skill taxonomy with per-class routing rule.
- **`.claude-plugin/settings.json`** — activates `orchestrator` as plugin main-thread agent.
- **`spawn-protocol.md` §9 + §3 additions** — Token Budget & Reply Contract; WRAP_UP signal at 70% context ceiling; three-tier timeout (soft 20m / idle 10m / hard 30m); stuck-loop detection via dispatch-history pattern match.
- **`pre-compact-snapshot.sh` HANDOFF.json extension** — every PreCompact event now writes `.cc-sessions/HANDOFF.json` (sprint/phase/branch/head_sha/uncommitted/recent_files/last_activity/resume_hint). Generic resume artifact, not sprint-specific.
- **`session-start.sh` auto-resume** — surfaces fresh HANDOFF.json (≤24h) with one-line state summary; user opts to resume or archives.
- **`sprint-review` Phase 3.6 Invariants 6 + 7** — ratchet-regression hard gate + critic LGTM hard gate. Detailed procedures in `references/main.md`.
- **`ui-build` Phase 3.0 + 5.4.2** — mandatory aesthetic-direction step before wireframe (or invoke `frontend-design:frontend-design`); design-critic vision-iteration loop with up-to-3 revisions on `design_quality: high` stories. Implementation Gate gains banned-font + `prefers-reduced-motion` + `console.log`-zero + inline-style-ban checks.
- **`completeness-gate` §2.13 + §2.14** — new env-var-fallback detector (matches `process.env.X || '...'` near credential-named identifiers; Major severity in `src/`) and hardcoded-localhost / port detector (matches `https?://localhost|127.0.0.1|0.0.0.0` and 4-5-digit ports outside test fixtures and dev configs). Both have inline escape hatches (`// blitz:fallback-allowed:`, `// blitz:localhost-allowed:`).
- **`story-frontmatter.md` `acceptance_checks:` schema** — optional executable-predicate array for stories. Four check types: `grep_present` (with `min`), `grep_absent`, `shell` (with `assert_eq`), `ast_absent` (best-effort tree-sitter). `agents/critic.md` §2.5 contains the dispatcher; sprint-review Phase 3.6 Invariant 7 routes through it. Producer/consumer matrix updated with the new fields and the optional `design_quality:` enum (`skip` | `standard` | `high`).
- **`agents/research-critic.md`** — read-only adversarial citation+claim reviewer for `/blitz:research` Phase 3.2.5. Probes every cited URL via WebFetch, classifies LIVE / DEAD / LIKELY_HALLUCINATED / UNKNOWN per arxiv 2604.03173 urlhealth taxonomy. Verifies `> "..."` quoted spans appear in fetched source content (Deterministic Quoting). Returns `{verdict: PASS | CITATIONS_MISSING}`. CITATIONS_MISSING blocks cleanup so the user can inspect dead URLs before the findings dir is deleted.
- **`hooks/scripts/agent-frontmatter-validate.sh`** — sibling of `skill-frontmatter-validate.sh` for `agents/*.md`. Enforces required fields (`name` / `description` / `model` / `tools` / `maxTurns`), forbids silently-stripped plugin-agent fields (`hooks` / `mcpServers` / `permissionMode`), caps body at 500 lines, requires canonical OUTPUT STYLE snippet (or `[CANONICAL PREAMBLE]` inheritance marker). Wired into `PostToolUse` alongside the skill validator.
- **`hooks/scripts/critic-gemini.sh`** — Cross-Model Critic (CMC) wrapper per arxiv 2604.19049. Wraps `@google/gemini-cli`, lifts the in-Claude critic body verbatim (`--mode pre-pass | research | design`), appends a JSON-only directive, validates the reply matches the canonical reply contract, exits 0 on LGTM/PASS or 2 on REJECT/CITATIONS_MISSING. `sprint-review` Phase 3.6 Invariant 7 supports three modes: default (in-Claude only), `BLITZ_USE_GEMINI_CRITIC=1` (Gemini replaces in-Claude), `BLITZ_DUAL_CRITIC=1` (both must LGTM, ~2× cost, highest signal). Tunable via `BLITZ_GEMINI_BIN`, `BLITZ_GEMINI_MODEL` (default `gemini-2.5-pro`), `BLITZ_GEMINI_FLAGS`. Graceful failure when binary missing.

### Changed

- **`agents/doc-writer.md` → model: haiku** — mechanical pattern-following per the new routing matrix. ~5× per-output-token saving vs prior Sonnet default.
- **architect / backend-dev / frontend-dev / reviewer / test-writer** — added explicit model rationale comments per `token-budget.md`. Models unchanged (sonnet); now self-documenting.
- **`CLAUDE.md`** — describes the orchestrator entry point, 5 new shared protocols, 7-invariant Phase 3.6 gate, 27-hook count (was 19). Stays under the 200-line CLAUDE.md token-budget rule.
- **8 specialist agents updated to canonical OUTPUT STYLE snippet** — replaces the prior `**Output style:**` paraphrase across architect / backend-dev / critic / design-critic / doc-writer / frontend-dev / reviewer / test-writer to satisfy Invariant 5 unification across `skills/` and `agents/`.
- **README.md** — new "Holistic Machine" section documenting orchestrator, quality gates, and Cross-Model Critic with full Gemini setup. Skills/agents/hooks/protocols counts updated. Architecture tree expanded for v1.11+ artifacts.
- **Skill count**: 38 (was 37; added `design-extract`).
- **Agent count**: 10 plugin agents (was 6; added `orchestrator`, `critic`, `design-critic`, `research-critic`).
- **Hook count**: 27 scripts (was 19; added 7 anti-shortcut blockers + `agent-frontmatter-validate.sh`).
- **Shared-protocol count**: 20 files (was 14; added `token-budget`, `ratchet-protocol`, `shortcut-taxonomy`, `knowledge-protocol`, `frontend-design-heuristics`, `agent-routing`).

### Compatibility

- Compatibility floor for orchestrator-activation features remains `>=2.1.117`. P0 hooks have no version dependency.

### Migration notes

1. The orchestrator activation is plugin-default. Per-project override: set `{"agent": null}` in your `.claude/settings.json`, or env `BLITZ_DISABLE_ORCHESTRATOR=1`.
2. Ratchet bootstraps on the first `sprint-review` PASS in a project; greenfield starts at 0 and tightens.
3. The 5 P0 hooks fire on any Bash command in a blitz-aware project. False positives surface via `BLITZ_OVERRIDE_*` env vars (documented in each hook's stderr message).
4. `KNOWLEDGE.md` is `.gitignore`d by default; team-shared lessons go in a separate committed `docs/engineering-notes.md`.

---

## [1.10.0] — 2026-04-26

Eleven follow-up commits after the v1.9.0 overhaul, capped by the new `/blitz:conform` skill that brings legacy projects into current spec. No breaking changes; one new feature, one regression fix, broad conformance tightening, and preventive coverage.

### Added

- **`/blitz:conform` skill** (`skills/conform/`) — detects + fixes drift in an existing project's blitz runtime artifacts against the canonical schemas in `skills/_shared/`. Schema-version aware: detects pre-v1.9.0 story frontmatter (`epic` + `verify` + `done`) and migrates to current spec (`epic_id` + `acceptance_criteria` + `registry_entries`) while preserving project-specific extension fields. Three-format STATE.md parser (field-form / bold-prefix-line / table-form). Optional-feature semantics (carry-forward and developer-profile absent + zero consumer signals = NO ACTION, not MISSING). Session model flexibility (file-style `<id>.json` AND directory-style `<id>/`). Sample mode auto-engages on >50 sprints or >300 stories (random sample of latest-3 + 10 older via `shuf`, with extrapolation). Project-extension awareness (39+ non-canonical roadmap files like `roadmap-registry.json`, `.bak` archives stay INFO, never deleted). Read-only by default; `--fix` applies migrations idempotently with per-file `.pre-conform.<ts>` backups. Plugin-fork mode via `--scope plugin`. Dry-run validated against a 123-sprint / 1,018-story / 160-session project. Skill 285 lines + references/main.md 288 lines.
- **`hooks/scripts/markdown-link-validate.sh`** — pre-commit warn-only hook for broken relative `.md` links across `skills/`. Strips fenced code blocks, inline code, http URLs, anchors, `/_shared/` plugin-absolute links. Closes the gap that allowed pass-3's renames to silently break links until pass-4 swept them.
- **`hooks/scripts/README.md`** — discoverability index for the 19 hook scripts. Tables grouped by hook event with matcher + purpose + blocking-vs-non-blocking conventions.
- **`scripts/maint/v1.9.0/`** — archived 5 migration scripts that performed the v1.9.0 mechanical work (`blitz-restructure.py`, `blitz-trim-preamble.py`, `blitz-rewrite-desc.py`, `blitz-fix-frontmatter.sh`, `blitz-xref-audit.py`) plus README documenting each script's purpose, idempotency contract, and re-run safety. Now also referenced by `/blitz:conform --scope plugin`.

### Fixed

- **🔴 sprint-review Invariant 5 silent regression** (`sprint-review/SKILL.md`) — Phase 3.6 audit script grepped `skills/*/reference.md`, which matched zero files post-v1.9.0 restructure. Invariant silently passed for any missing OUTPUT STYLE snippet. Updated all 4 path references (lines 389, 405, 419, 420) to `skills/*/references/main.md`. Now correctly identifies 8 references/main.md files with embedded agent-prompt templates.
- **`reference-compression-validate.sh` find pattern** — `find -name 'references/main.md.original'` never matched (slash in `-name`); switched to `-path '*/references/main.md.original'`. Hook now correctly checks all 16 .original/main.md pairs.
- **`installer/install.sh` banner version drift** — banner read `v1.4.1 · 33 skills · 12 hooks` (5 versions stale); now `v1.10.0 · 36 skills · 19 hooks`. Caught by `check-version-sync.sh`, which had been emitting warnings on every commit.
- **README hook count drift** — said "17 hooks" in 3 places; now 19 (added `skill-frontmatter-validate.sh` in v1.9.0 + `markdown-link-validate.sh` in v1.10.0).
- **Hook script JSON-escaping bugs** — `blitz-prompt-expansion.sh` and `post-compact-log.sh` used `printf`/sed pipelines for activity-feed JSON; rewritten with `jq -nc --arg` for safe escaping.
- **`session-start.sh` portability** — added portable epoch parser (GNU `date -d` → BSD `date -j` → python3 fallback) for stale-session detection. Per-session context counter now reset on `SessionStart` (was monotonically accumulating across sessions).
- **`task-completed-validate.sh` regex** — story-id check `^S\d+-\d+:` now accepts gap-fix IDs `^S\d+-G?\d+:` (e.g., `S3-G001`).
- **`sprint-review` allowed-tools** — removed unused `ToolSearch` declaration (per-skill manual audit confirmed zero invocations in body).

### Changed

- **All `disable-model-invocation: true` flags removed** — 5 skills (`ask`, `quick`, `next`, `health`, `codebase-audit`) are now eligible for description-based auto-invocation. Added `allowed-tools` to the 4 that previously omitted it (was implied by the disable flag): `ask` (Read, Bash, Glob, AskUserQuestion), `quick` (Read, Write, Edit, Bash, Glob, Grep), `next` (Read, Bash, Glob, Grep), `health` (Read, Bash, Glob, Grep). `codebase-audit` already had `allowed-tools` declared.
- **Companion file restructure to canonical Anthropic layout** — 46 file moves: `reference.md` → `references/main.md` (27 skills + 16 `.original` siblings), `ui-audit/CHECKS.md` → `references/checks.md`, `ui-audit/PATTERNS.md` → `references/patterns.md`, `setup/conflict-catalog.json` → `assets/conflict-catalog.json`. 202 cross-reference substitutions across 30 files.
- **Inline duplication trim** — 21 SKILL.md files had a verbose ~500-char session-registration preamble inlined; replaced with a canonical ~270-char citation referencing `/_shared/session-protocol.md` §Session Registration and `/_shared/verbose-progress.md`. ~5.4 KB saved per session start.
- **Description triggerability rewrite** — every skill's `description:` field rewritten in third-person + front-loaded explicit trigger phrases for better Claude Code skill discovery.
- **Stale `reference.md` string sweep** — pass-3 markdown-link regex missed 15 path-fragment refs in 12 files (cross-skill cites in compress/quality-metrics/doc-gen/roadmap/review SKILLs, self-references inside moved files, fixture script comments). All cleaned; one intentional historical narrative preserved in `_shared/story-frontmatter.md`.
- **`agent-prompt-boilerplate.md` self-consistency** — protocol's own 7 internal `reference.md` paths updated to `references/main.md` (it's actively cited from 7 references/main.md files via `<!-- import: -->` markers).
- **`state-handoff.md` consumer wiring (3 → 7)** — added citations in `bootstrap`, `ship`, `roadmap`, `next` SKILL.md (was only sprint-plan/dev/review). Pipeline contract now visible to every producer/consumer.
- **CLAUDE.md Hooks section** — replaced single sentence with event-grouped overview (8 events × 19 scripts) and link to new `hooks/scripts/README.md`. Added `agent-prompt-boilerplate.md` to "Required for skills that spawn agents".
- **README hooks table + architecture diagram** — both now accurately list 19 scripts with one-line purposes; added `conform/` to named-skill list; new "Conforming after upgrades" subsection in Runtime Artifacts pointing at `/blitz:conform`.

### Audit findings (no code change)

- **`allowed-tools` precision audit** — manual per-skill review across all 37 SKILL.md files via spawned Explore agent + spot-check verification: 31 CLEAN, 4 EXEMPT (no `allowed-tools` field; ask/health/next/quick previously had `disable-model-invocation: true`), 1 EXTRA fixed (sprint-review ToolSearch removed), 0 true MISSING (the initial heuristic flag list of 14 was entirely false positives).
- **Markdown link health** — 72 relative `.md` links across `skills/`, all valid (now enforced on every commit by `markdown-link-validate.sh`).

## [1.9.0] — 2026-04-26

### Skill Suite Overhaul to Anthropic-Canonical Conventions

A full review of all 36 skills against Anthropic's official Skill authoring guidance (`code.claude.com/docs/en/skills`, `platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices`, `github.com/anthropics/skills`) and the production carry-forward / sprint-family contracts. Every skill now satisfies a single canonical contract enforced by a new lint hook.

### Breaking

- **Removed `.claude-plugin/skill-registry.json`** — non-canonical per Anthropic; skills are now auto-discovered from `skills/<name>/SKILL.md`. The only consumer (`skills/health/SKILL.md` Phase 3.1) was rewritten to walk SKILL.md files directly via the new lint hook.

### Added

- **`skills/_shared/story-frontmatter.md`** (NEW) — single canonical YAML schema for sprint stories. Producer/consumer matrix (sprint-plan writes; sprint-dev/sprint-review read). Validation algorithm (sprint-dev Phase 0). Closes the producer/consumer drift that contributed to the CAP-133 carry-forward incident.
- **`skills/_shared/state-handoff.md`** (NEW) — pipeline contracts for every artifact passed between bootstrap → research → roadmap → sprint-plan → sprint-dev → sprint-review → ship. Documents the producer/consumer/required-by table and the Phase 0 input-validation pattern.
- **`skills/_shared/carry-forward-registry.md`** §Reader Algorithm — single executable script that consolidates Invariants 1, 2, 4 + rollover-ceiling escalation. Sprint-plan / sprint-review / roadmap / dashboards now shell out to one canonical implementation; thresholds no longer drift across skills.
- **`skills/_shared/spawn-protocol.md`** §8 Agent Output Contract — unified SUCCESS / PARTIAL / MALFORMED / EMPTY / MISSING / TIMEOUT classifications and standard gate thresholds (N=1 → ABORT @ 1; N=2-3 → ABORT @ 2; N≥4 → ABORT @ ⌈N/2⌉). PARTIAL retry policy. Validator script. Skills that spawn agents now share one threshold table.
- **`skills/_shared/terse-output.md`** §Canonical Exemptions List — single authoritative list of sections that always use full prose (Safety, Root Cause, Risks, Destructive ops, First-time onboarding, Migration notices). Skills must not redefine the exemption set.
- **`hooks/scripts/skill-frontmatter-validate.sh`** (NEW) — Anthropic-canonical lint. Checks required frontmatter fields, name length (≤64 chars + reserved-word ban), description length (≤1024 chars), body length (≤500 lines), `effort:` presence, `model:` presence when invokable, and verbatim OUTPUT STYLE snippet. Wired into `hooks.json` PostToolUse Write|Edit chain and `pre-commit-validate.sh`.
- **Phase 0.0 Input Gate** — added to `sprint-plan` and `sprint-dev`; hard-fails with the missing-artifact path AND the producer skill name when an upstream input is missing (no more cryptic "no roadmap registry" errors on greenfield projects).

### Changed

- **All 36 SKILL.md files** — every skill now satisfies the canonical frontmatter contract: `effort:` field present (low/medium/high), `model:` explicit when invokable (no `[1m]` inheritance), verbatim OUTPUT STYLE snippet from `/_shared/terse-output.md` immediately below the Additional Resources block. Bodies trimmed to ≤500 lines (sprint-plan and sprint-dev pushed redundant content to canonical shared docs and references/main.md).
- **`skills/sprint-plan/SKILL.md`** — Additional Resources cite story-frontmatter.md and state-handoff.md as load-bearing; Phase 2.4 cites spawn-protocol.md §8 Agent Output Contract instead of inline thresholds; Phase 1.4 lock cycle delegates to session-protocol.md §File-Based Locking Protocol.
- **`skills/sprint-dev/SKILL.md`** — Execution Mode now reads autonomy from `.cc-sessions/developer-profile.json` per session-protocol.md §Autonomy Levels (canonical: low → interactive, medium → checkpoint, high/full → autonomous-forced); Phase 0.0 gate validates upstream artifacts; Phase 3.1a registry write delegates to carry-forward-registry.md §Writers; Phase 3.5.0 integration-check **mandatory** (was "optional").
- **`skills/sprint-review/SKILL.md`** — Phase 3.6 invocation switched to canonical Reader Algorithm; Invariant 5 now scans **SKILL.md AND references/main.md** (was reference.md only) — every SKILL.md without the canonical OUTPUT STYLE snippet auto-fails. Phase 2.6 cites spawn-protocol.md §8.
- **`skills/sprint/SKILL.md`, `skills/implement/SKILL.md`, `skills/review/SKILL.md`** — orchestrators now declare `model: opus`, `effort: low`, `allowed-tools`; descriptions rewritten in third person with explicit trigger phrases.
- **`skills/health/SKILL.md`** — Phase 3.1 rewritten to walk `skills/*/SKILL.md` via the new lint hook (was: parse `skill-registry.json`).
- **`hooks/scripts/pre-commit-validate.sh`** — adds SKILL.md frontmatter validation gate on staged SKILL.md files. Commits with violations are blocked.
- **`hooks/hooks.json`** — added `skill-frontmatter-validate.sh --all` to the PostToolUse Write|Edit chain.

### Documentation

- **`CLAUDE.md`** — fixed skill count (31 → 36); dropped `skill-registry.json` reference; added the canonical SKILL.md contract description and an expanded shared-protocol cross-reference list.
- **`README.md`** — fixed protocol count (9 → 12); dropped `skill-registry.json` from the architecture diagram; expanded the Shared Protocols table with three new entries (story-frontmatter.md, state-handoff.md, agent-prompt-boilerplate.md / scheduling.md / session-report-template.md).
- **`.claude-plugin/marketplace.json`** — version 1.6.0 → 1.9.0; description updated to "36 skills, 6 agents, 17 hook scripts".
- **`.claude-plugin/plugin.json`** — version 1.8.0 → 1.9.0.

### Why This Matters

A fresh Claude Code session can now invoke any skill from its SKILL.md alone. The sprint family round-trips cleanly because producer (sprint-plan) and consumers (sprint-dev, sprint-review) share one schema. Agent failure thresholds no longer drift between skills — one Agent Output Contract governs all spawns. The carry-forward registry has one Reader Algorithm; impossible-to-diverge implementations replace three near-duplicates. The OUTPUT STYLE snippet is now enforced by lint on every SKILL.md, eliminating the silent drift that triggered Invariant 5 failures.

## [1.8.0] — 2026-04-25

### April 2026 CC Platform Feature Adoption

Six CC platform features from the research backlog (`docs/_research/2026-04-25_blitz-skill-alignment.md`) implemented across skills and hooks.

### Added

- **`PreCompact` / `PostCompact` hooks** (`hooks/hooks.json` + `hooks/scripts/pre-compact-snapshot.sh` + `hooks/scripts/post-compact-log.sh`) — PreCompact fires before context compaction and writes a state snapshot (sprint number, wave progress, stories done/remaining, CF_ACTIVE count) to `.cc-sessions/compact-state.json`. PostCompact (async) reads the snapshot and appends a restoration hint to the activity feed so the next turn knows where to resume. Addresses the highest blitz failure mode: silent state loss during auto-compact on long sprints.
- **`UserPromptExpansion` hook** (`hooks/hooks.json` + `hooks/scripts/blitz-prompt-expansion.sh`) — fires on every `blitz:*` slash command expansion, reads the last 5 substantive activity-feed events, and injects them as `additionalContext` into the expansion prompt. Gives every skill instant awareness of prior session state without relying on Claude reading CLAUDE.md manually.

### Changed

- **`skills/sprint-dev/SKILL.md`** Phase 3.2 — Monitoring loop now uses the `Monitor` tool (event-driven) as the primary progress-tracking mechanism. Agents append JSON lines to a sprint-scoped progress file; a `tail -f` monitor wakes the orchestrator on DONE/BLOCKED/wave_complete events, eliminating the per-turn polling cost on long sprints. `TaskList` polling retained as fallback when Monitor is unavailable.
- **`skills/sprint-dev/SKILL.md`** Phase 2.2 — Agent MCP scoping table added. When `.claude/agents/blitz-{backend,frontend,test}-dev.md` definitions exist, each agent is spawned with its typed `mcpServers` config (backend=Firestore/Firebase, frontend=Playwright, test=read-only). Falls back to full session MCP set if agent definition files are absent.
- **`skills/sprint-dev/SKILL.md`** Phase 4.11 (new) — `PushNotification` call at sprint completion: sends title, story counts, and GitHub URL as a mobile push via Remote Control. No-op when Remote Control is not configured.
- **`skills/ship/SKILL.md`** Phase 4.2 (new) — `PushNotification` call at ship completion: sends version, feature/fix counts, and release URL. No-op when Remote Control is not configured.
- **`skills/sprint/SKILL.md`** `--loop` flag — Documents CronCreate-backed scheduling tiers (session/desktop/cloud Routine) and adds `ScheduleWakeup` self-scheduling pattern for direct `--loop` invocations (skipped when `CLAUDE_CODE_LOOP_MANAGED=1`). Documents 7-day CronCreate session expiry; recommends cloud Routines for runs >7 days.
- **`skills/ui-audit/SKILL.md`** Loop mode — `ScheduleWakeup` pattern added to `--loop` table: each tick registers the next wakeup so the audit survives idle periods without a persistent terminal.
- **`.claude-plugin/skill-registry.json`** — version 1.4.0 → 1.5.0.

## [1.7.0] — 2026-04-25

### blitz:code-doctor + Research → Sprint Auto-Chain

New skill `blitz:code-doctor` audits framework-API correctness (Firestore, VueFire, Vue 3, Pinia) — detects anti-patterns, misuse, dead exports, and duplication candidates. Read-only by default; `--fix` applies low-risk auto-fixes.

Auto-chain closes the only blocking manual step in the blitz cycle: running `/research` then `/sprint` previously failed with "No roadmap. Run `/blitz:roadmap` first." because `sprint/SKILL.md` Pre-Flight never detected uningested `docs/_research/*.md`. Now `sprint` automatically detects and ingests research docs via `roadmap extend` before proceeding — in both normal and `--loop` modes. `next/SKILL.md` gains carry-forward registry awareness so it never reports "nothing to do" while active entries exist.

### Added

- **`blitz:code-doctor` skill** (`skills/code-doctor/`) — SKILL.md + reference.md. Opus orchestrator + sonnet Agent workers. Framework-API correctness audit: Firestore (misuse, subcollection patterns, transaction anti-patterns), VueFire (reactive binding correctness), Vue 3 (Options/Composition anti-patterns, reactivity misuse), Pinia (store coupling, action patterns). `--fix` mode for low-risk auto-fixes (read-only by default). Registered in skill-registry.json (`quality` category, `beta` maturity).
- **Research doc** `docs/_research/2026-04-25_blitz-skill-alignment.md` — full 3-agent cycle alignment analysis. Identified 3 skill gaps + 7 un-adopted April-2026 CC platform features. Scope block `cf-2026-04-25-sprint-from-research-autochain`.
- **Research doc** `docs/_research/2026-04-25_code-doctor-skill.md` — code-doctor capability research.

### Changed

- **`skills/sprint/SKILL.md`** — Loop Step 1 Observe gains `UNINGESTED` / `UNINGESTED_COUNT` detection (cross-checks `carry-forward.jsonl` to skip already-ingested docs, preventing duplicate-id hard-fail). Loop Step 2 decision tree gains row 0: "uningested research → roadmap extend, exit clean." Pre-Flight gains step 1b: auto-invokes `roadmap extend` in normal mode; fails loud on malformed `scope:` blocks.
- **`skills/research/SKILL.md`** — Phase 4.2 follow-up table reordered: `roadmap extend` first (mandatory ingestion step made explicit), `sprint` second (single-command auto-chain path), `sprint-plan` third.
- **`skills/next/SKILL.md`** — Phase 0 gains steps 0.6 (`CF_ACTIVE` / `CF_ESCALATED` reads from carry-forward registry) and 0.7 (`UNINGESTED_COUNT`). Decision tree gains rows 8b–8d: escalation banner for stuck entries, ingest-and-plan path, gap-closure path. `next` can no longer report "nothing to do" while carry-forward entries are active.
- **`.claude-plugin/skill-registry.json`** — code-doctor entry added; version 1.3.0 → 1.4.0.

## [1.6.0] — 2026-04-23

### ui-audit — Continuous Cross-Page Consistency & UX Auditor

New skill `blitz:ui-audit` fills a gap no mainstream tool covers: semantic cross-page data consistency ("dashboard says 47, list page says 46" detection). Visual-regression tools (Percy, Chromatic, Applitools) explicitly mask numeric changes as noise. This skill extracts labeled values via Playwright MCP `browser_evaluate`, persists to an append-only registry, and asserts invariants across pages, roles, events, and interactive elements.

Delivered across 3 sprints (Sprint 6–8) and 35 stories. Research: `docs/_research/2026-04-23_ui-audit-skill.md`. All 5 epics closed (E-008 foundation + E-009 quality/heuristics + E-010 interactive + E-011 events + E-012 role matrix).

### Added

- **`blitz:ui-audit` skill** (`skills/ui-audit/`) — SKILL.md + reference.md + CHECKS.md + PATTERNS.md + tests/. 9 modes: `full`, `smoke`, `data`, `buttons`, `events`, `consistency`, `heuristics`, `role <name>`, `--loop`. Opus orchestrator + effort:low + sonnet Agent workers for parallel heuristic scans when pages >30.
- **Labeled-value registry** at `docs/crawls/page-data-registry.jsonl` — append-only, latest-wins-by-`(role, page, label)` via `jq group_by`. Reader protocol excludes 10 finding-label families to prevent feedback on re-run.
- **Cross-page invariants** — `.ui-audit.json` declares `invariants` (`equal`/`gte`/`lte` with tolerance), `event_invariants` (`required_props`/`forbidden_props`/`scope`), `role_invariants` (`equal`/`viewer_null`/`gte`), plus `totals` parent/child sums, `placeholder_patterns`, `role_leak_patterns`.
- **Interactive element coverage** — enumerates every ARIA-role + native interactive element per page; runs 6 static checks (NO_LABEL, DEAD_HREF, EMPTY_HANDLER, TABINDEX_POSITIVE, TABINDEX_NEGATIVE_VISIBLE, NO_FOCUS_STATE) + destructive-classifier-gated safe-click pass + CLICK_ERROR capture.
- **Analytics event consistency** — 3-layer interception (`window.dataLayer` push proxy + `navigator.sendBeacon` wrap + network filter for Segment/PostHog/Amplitude/GA4). Cross-page event drift detection + `event_invariants` with 20-key PII auto-escalation list (CRITICAL on `user_email`/`password`/`ssn`/`token`/etc leaked in analytics).
- **Per-permissions-role audit matrix** — 5 roles (anonymous/viewer/member/admin/superadmin) via env-var credentials, scripted login with R9 sentinel check after every role transition, storageState harvest at `.auth/<role>.json`, HTML-source role-leak scan. Loop matrix = `(role, page)` per tick, 2-pass termination, R10 ETA gate (`--yes`/`--ci` bypass on >60min runs).
- **6 data-quality flags**: NULL_VALUE + PLACEHOLDER + NEGATIVE_COUNT (inline Phase 2) + FORMAT_MISMATCH + STALE_ZERO + BROKEN_TOTAL (Phase 4 reducers).
- **Vercel Web Interface Guidelines heuristics** — Category 9 (URL reflects filter/tab/pagination state, consumes click records) + Category 16 (NUMERIC_COLUMN_NOT_TABULAR via `getComputedStyle(cell).fontVariantNumeric` + WRITTEN_OUT_COUNT regex scan).
- **Self-contained fixture test** (`skills/ui-audit/tests/run-fixture.sh`) — python3 static server + synthetic HTML fixture + shell assertions for 6 numeric + 3 interactive + 2 event + 4 quality + 2 heuristic scenarios. Runs without Claude Code or Playwright MCP.
- **Phase 7 LOOP MATRIX** — role×page cursor persisted in `docs/crawls/latest-tick.json.ui_audit_matrix`; `matrix_idle: true` after pass-2 completion.
- **Prompt-injection defense** on Phase 5 sonnet worker spawn — page-key sanitization at config-load (reject control chars) + `---BEGIN/END PAGE LIST---` delimiters with literal-interpretation framing in prompt.

### Changed

- `skills/browse/reference.md` — `latest-tick.json` schema gains `page_data_registry` field so browse can observe ui-audit state in one read.
- `skills/_shared/session-protocol.md` — conflict matrix adds 3 ui-audit rows (BLOCK self / WARN vs browse-loop / OK vs sprint-dev).
- `.claude-plugin/skill-registry.json` — ui-audit entry, category `quality`, `dependencies: ["browse"]`, `maturity: "experimental"`.
- `skills/sprint-review/SKILL.md` — Invariant 5 floor bumped 7→8 (ui-audit/reference.md carries an agent-prompt template).
- Plugin skill count: 33 → 35 (ui-audit; one skill-review housekeeping).

### Fixed

Review auto-fixes that landed this cycle and hardened the design:

- Fixture `awk /dev/stdin <<<"$HTML"` bug — would silently null-out interactive assertions on WSL (sprint-7 pattern review).
- Safety-rule verb-list divergence — SKILL.md Rule 1 and `DESTRUCTIVE_LABELS` regex now share the full 24-verb list (sprint-7 security review).
- `--yes` / `--ci` arg-parse gap — ETA-gate flags now documented in Phase 0.1 mode table with explicit env-var export (sprint-7 security review).
- dataLayer proxy circular-ref crash — wrapped in try/catch; original `_push` always called last (sprint-7 security review).
- PII auto-escalation list expanded from 8 → 20 keys with substring match (`phone`, `address`, `dob`, `ip_address`, passport, reset codes, etc).
- Phase 3 reducer exclude-label divergence — CONSISTENCY + FLAPPING reducers now share the 10-label canonical exclude set (sprint-8 pattern review).
- URL-token capture in Cat 9 findings — `scrub_url` helper redacts `token|session|auth|key|secret|password|reset|code|nonce|state|access_token|refresh_token` values before emission; state-change signal preserved via symmetric redaction (sprint-8 security review).
- Worker malformed-JSON silent-drop — Phase 5 coordinator now validates each spawned worker's output with `jq -c '.'` and preserves malformed output as `.malformed.<ts>` with CONFIG_ERROR (sprint-8 security review).
- placeholder_patterns ReDoS guard — rejects patterns >200 chars or containing nested quantifiers at config-load (sprint-8 housekeeping).

### Closed capabilities

9 new capabilities (CAP-008..CAP-016), all tracked in `docs/roadmap/capability-index.json`:

| ID | Title |
|---|---|
| CAP-008 | Scaffold skills/ui-audit/ |
| CAP-009 | Page data extraction + labeled-value registry |
| CAP-010 | Consistency + invariant evaluator + FLAPPING/STALE/NULL_TRANSITION |
| CAP-011 | Data-quality flags (6 flags, 3 reducers + 3 inline) |
| CAP-012 | UI/UX heuristic audit (Vercel Cat 9 + 16) |
| CAP-013 | Reporter (markdown + stdout + activity-feed) |
| CAP-014 | Interactive element coverage (buttons/links/tabs) |
| CAP-015 | Analytics event consistency |
| CAP-016 | Per-permissions-role audit matrix |

---

## [1.5.0] — 2026-04-18

### Caveman Full Absorption

Delivers the full 14-entry caveman-absorption work plan tracked in `docs/_research/2026-04-18_caveman-full-absorption.md` and `docs/_research/2026-04-18_runtime-artifact-terse-propagation.md`. Spans 4 sprints (Sprint 2-5) and 14 `/loop` ticks of autonomous sprint-plan/dev/review cycles. 12 of 14 registry entries landed complete; 2 dropped with documented reasons (preservation-boundary and supersede). Zero silent drops.

### Added

- **Terse-output directive coverage** across every load-bearing context (`agents/*.md` ×6, `skills/*/SKILL.md` ×31, `skills/_shared/*.md` ×11). Every context that spawns or reads instructions now cross-references `/_shared/terse-output.md`.
- **Runtime directive injection** at 8 SKILL.md write-phases (`research`, `sprint-plan`, `sprint-review`, `retrospective`, `roadmap`, `release`, `fix-issue`, `todo`). Inline 5-line Output-style block ensures generated artifacts default to terse prose rather than verbose defaults.
- **Caveman-review output format** in `skills/sprint-review/reference.md` and `skills/review/reference.md`. Finding pattern: `L<line>: <severity-prefix> <problem>. <fix>.` with 🔴/🟡/🔵/❓ prefixes. `LGTM` short-circuit. Auto-clarity for security/CVE findings.
- **Intensity persistence**: `output_intensity: lite|full|ultra` documented in `developer-profile.json`, `BLITZ_OUTPUT_INTENSITY` env override, precedence chain in `skills/_shared/terse-output.md` and interpolated into `spawn-protocol.md` §7 snippet.
- **LITE-intensity exemption markers** on 9 safety/reasoning-sensitive skills (`completeness-gate`, `codebase-audit`, `research`, `retrospective`, `sprint-review`, `release`, `migrate`, `fix-issue`, `bootstrap`). Prevents brevity-induced accuracy degradation per Renze 2024 + Prompt-Compression-in-the-Wild evidence.
- **Agent-prompt boilerplate shared fragment** at `skills/_shared/agent-prompt-boilerplate.md`. Canonical source for HEARTBEAT, PARTIAL, weight-class caps, session-registration preambles. Pattern A delivery (author-time reference; inline preserved per Invariant 5 safety).
- **Sprint-review Phase 3.6 Invariant 5** enforces OUTPUT STYLE snippet presence in every UNSAFE agent-prompt `reference.md`. Any missing snippet → Critical finding → sprint FAILs.
- **Activity-feed message length rule** in `skills/_shared/verbose-progress.md`: `message` ≤ 200 chars (soft) / 300 chars (grep audit threshold), overflow moves to `detail`.
- **Scope-block ingestion** scripts: `scripts/parse-scope-to-registry.py` and `scripts/backfill-registry-parents.py`. Used by `/blitz:roadmap` Phase 1.1.5 and Phase 7 backfill.
- **New skill directory**: `skills/review/reference.md` (previously missing; bonus delivery via S3-003).

### Changed

- `skills/_shared/spawn-protocol.md:328` — enforcement clause upgraded from `WARNING (not BLOCKER)` to hard BLOCKER. Paired with sprint-review Invariant 5.
- `skills/_shared/terse-output.md` — added `## Intensity override precedence` section documenting env > dev-profile > skill > default resolution.
- 18 input files compressed author-time (`/blitz:compress`): 6 SAFE `reference.md` (wave 2) + 12 `docs/_research/*.md`. Aggregate reduction ~-1.5% (~4 KB), scope-block YAML preserved byte-identical in all 6 research docs with `scope:` frontmatter.

### Fixed

- `skills/completeness-gate/reference.md` flagged UNSAFE at compression time (contains load-bearing `## Grep Patterns by Check` heading). Registry entry `cf-2026-04-18-compress-safe-references-wave2` transitioned to `dropped` with preservation-boundary rationale rather than forcing a partial delivery.

### Dropped (terminal, documented)

- `cf-2026-04-18-compress-safe-references-wave2` (0.857 coverage) — completeness-gate's grep-pattern heading is load-bearing; compression risk exceeds ~0.3% saving.
- `cf-2026-04-18-task-type-gating` — superseded by `cf-2026-04-18-lite-exemption-markers` (per-section markers are strictly more expressive than whole-skill `output_style_policy`). Capability-index `dedup_log` pre-announced the supersede at plan time.

### Documentation

- `docs/_research/2026-04-18_caveman-full-absorption.md` — 9 scope entries, 7 capabilities mapped into the roadmap.
- `docs/_research/2026-04-18_runtime-artifact-terse-propagation.md` — 5 scope entries, documents the 0%-runtime-reach propagation gap and its phased fix.
- `docs/roadmap/` — full roadmap ingested from the 2 research docs: 7 capabilities, 3 domains, 4 phases, 7 epics, 14 carry-forward registry entries with parent.capability + parent.epic backfill.
- 5 sprint scaffolds under `sprints/sprint-{1..5}/` with manifest, stories, STATE, ac-coverage, summary, and review-report per sprint.
- 16 GitHub issues (#1-#16) created across Sprint 2-5 for story tracking.

### Registry Contract

Carry-forward registry format (`.cc-sessions/carry-forward.jsonl`) validated across:

- 14 unique IDs with full `created` → `correction` → `progress` → `complete|dropped` lifecycle.
- Zero silent drops across 5 sprints.
- Zero rollover escalations (rollover_count capped at 2; `deferred` events used for scheduled-to-later entries).
- `Invariant 5` self-tested on its own dogfood at Sprint 5 review (7/7 UNSAFE `reference.md` carry the required snippet).

### Release Metadata

- Tag range: `v1.4.1` → `v1.5.0`
- Commits: 37 on `main` (40f8bcf..HEAD)
- Contributors: 1 (lasswellt, automated via `/blitz:sprint --loop`)
- Issues closed: #1-#16 (all stories from Sprint 2-5)
- Research source: 2 April-18 research docs (full absorption + runtime propagation)

[1.13.0]: https://github.com/lasswellt/blitz-cc/releases/tag/v1.13.0
[1.12.2]: https://github.com/lasswellt/blitz-cc/releases/tag/v1.12.2
[1.12.1]: https://github.com/lasswellt/blitz-cc/releases/tag/v1.12.1
[1.12.0]: https://github.com/lasswellt/blitz-cc/releases/tag/v1.12.0
[1.11.2]: https://github.com/lasswellt/blitz-cc/releases/tag/v1.11.2
[1.11.1]: https://github.com/lasswellt/blitz-cc/releases/tag/v1.11.1
[1.11.0]: https://github.com/lasswellt/blitz-cc/releases/tag/v1.11.0
[1.10.0]: https://github.com/lasswellt/blitz-cc/releases/tag/v1.10.0
[1.5.0]: https://github.com/lasswellt/blitz-cc/releases/tag/v1.5.0
[1.4.1]: https://github.com/lasswellt/blitz-cc/compare/v1.4.0...v1.4.1
