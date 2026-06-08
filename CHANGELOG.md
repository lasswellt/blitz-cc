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

### Fixed
- **Inventory drift (shared 12->13):** `html-template-helper.md` (E-039 HTML side-output) was never folded into inventory; `counts.json` + README + plugin.json + marketplace.json said "12 shared protocol files" while 13 exist. Regenerated `counts.json`, reconciled manifests, indexed the file in CLAUDE.md. `check-count-sync.sh` now exits 0.
- **sprint-review Workflow `pipeline()` misuse:** sequential reviewer dispatch passed the roster as both items and stages (N×N), so reviewers never received prior findings. Replaced with an explicit sequential accumulator loop.
- **Model-routing self-contradiction:** §1 routing matrix listed sprint-* orchestrators as `sonnet`, contradicting the weight-class table and deployed `model: opus` frontmatter (required for `[1m]` inheritance). Split the matrix row.
- **orchestrator agent missing `effort: low`** (contract-mandated) — added.

### Changed
- **Workflow contract doc refreshed** to current tool API: `budget{spent(),remaining()}`, `workflow()` one-level nesting, 4096-item / 1000-agent caps, concurrency `min(16, cores-2)`; added DEFERRED adoption rows for code-sweep, code-doctor, quality-metrics, ui-audit.
- **Autonomous-loop guard:** `next --loop` forces `BLITZ_DISPATCH=agent` so an unattended loop can't stall on a platform Workflow per-run confirmation.
- **Prompt-cache mandate reframed** MUST->guidance (markdown system prompts can't set `cache_control`; platform applies caching when static-prefix-first ordering is respected).
- **Count-sync gate hardened:** adding/removing a file under `skills/_shared`, `skills/*/SKILL.md`, `agents/`, or `hooks/scripts/` now hard-blocks the commit until counts are refreshed.
- **Frontmatter validator:** added a cumulative-description-chars guard near the 15k load-time budget.

## [2.4.4] — 2026-06-07 · fix [1m] inheritance on invokable skills

Bug-fix dot-release.

- **fix(skills): promote invokable skills to `model: opus`** — `next` + 9 others (`compress`, `dep-health`, `design-extract`, `health`, `quick`, `setup`, `test-gen`, `todo`, `worktree-prune`) declared `model: sonnet`. Invoked from an `opus[1m]` session they inherited `[1m]` → `sonnet[1m]`, which is credits-gated **separately** from Opus 1M (on every plan incl. Max) → `API Error: Usage credits required for 1M context`. `/blitz:next` broke while `/blitz:sprint` (already `model: opus` → `opus[1m]`) worked. Promoted to `opus` to match the sprint-family entry skills; heavy work still runs in spawned sonnet Agents (isolated, non-`[1m]` context). Per `docs/_research/2026-06-07_1m-context-credits-on-loop.md`. No change to skill/agent/hook counts (37/10/38).

## [2.4.3] — 2026-06-07 · conform wave-plan + gitignore hygiene

Maintenance dot-release.

- **conform: `wave-plan.json` entry** — `/blitz:conform` now inventories + shape-probes sprint-dev's `${SESSION_TMP_DIR}/wave-plan.json` (jq `.waves and .done and .derived_from`). Ephemeral/skip-if-absent, INFO-only, never MIGRATE (re-derived from STATE.md each run). Closes the last open question from `docs/_research/2026-06-07_cross-session-resume-plus-workflow.md` §8.
- **gitignore: skill-generated root artifacts** — root-anchored ignores for `CODEBASE-MAP.md`, `DESIGN.md`, `.ui-audit.json`, `.quality-metrics.json`, `KNOWLEDGE.md`, `todos.jsonl`, `.blitz-cache/`, `firebase-debug*.log` so running blitz skills in the plugin-dev repo can't accidentally commit generated output. Tracked `.ui-audit.json.example` fixture unaffected.

No change to skill/agent/hook counts (37/10/38).

## [2.4.2] — 2026-06-07 · Workflow dispatch adoption

Feature dot-release — extends the opt-in `Workflow` (dynamic-workflows) dispatch path to the remaining fan-out skills, with `Agent()` fallback preserved throughout. Research-backed (`docs/_research/2026-06-06_dynamic-workflows-claude-code.md`, `2026-06-07_cross-session-resume-plus-workflow.md`, `2026-06-07_deferred-resume-microopts.md`).

- **Workflow wiring (adoption table now all WIRED):** `sprint-plan` + `codebase-map` (flat pool → `parallel()`), `sprint-review` (reviewers → `parallel()`/`pipeline()`, critic → `agent({agentType,schema})`), `audit` refuter panel (per-finding nested `parallel()`).
- **sprint-dev cross-session resume + Workflow:** per-wave `parallel()` + `isolation:'worktree'`; lifted the `Agent()`-only resume guard — `STATE.md` is the durable journal, resume re-derives remaining waves (serialized `wave-plan.json`, pure Kahn sort) and dispatches each via `Workflow`. `resumeFromRunId` in-session-only; Resume Divergence Gate is the safety interlock.
- **Alt A — observability-only attempt counter:** `total_attempts` + `last_attempt_ts` mirrored to the STATE.md Blocked table (`Attempts`/`Last Attempt`). Diagnostic only — the circuit-breaker still resets per sprint run (Airflow-`clear` / CI-re-run model). Durable breaker counter, in-session `resumeFromRunId`, and idempotency tokens remain deferred behind documented trigger metrics.

No change to skill/agent/hook counts (37/10/38). Validators: skill-frontmatter, markdown-link (350), version-sync expected green.

## [2.4.1] — 2026-06-06 · compaction passes II–III

Maintenance/refactor pass — **zero behavior change** (validator-attested: skill-frontmatter, agent-frontmatter, markdown-link, check-registry, reference-compression, plugin-structure, count-sync, version-sync all exit 0; hook test suite 66/66). Skill semantics, hook wiring, agent roles, and flags are identical. Attacks the content pools v2.4.0 left untouched (`docs/`, `references/main.md`), plus changelog history and duplicated hook helpers.

**Tracked lines 54,803 → 42,301 (−12,502).**

- **`docs/` 91 → 14 files (11,408 → 1,854 lines).** Removed the uncited 51-file `docs/validation/v1.16.0/` snapshot (recoverable via `git tag validation-v1.16.0`) and archived design-process history across `consolidation/review-audit`, `integrations/harness-design`, `integrations/impeccable`, `security/containment` — keeping only runtime-cited references (`effectiveness-research.md`, `audit-spec.md`, `design-critic-upgrade.md`, `references-regrounded.md`, `detector-rebuild.md`, `blitz-surface-map.md`, the impeccable design pillar core + Apache-2.0 license/attribution). Every inbound link to a removed file rewritten in-commit.
- **`.review/` untracked + gitignored** — audit-skill generated output, not source (same category as the `.original` files v2.4.0 removed).
- **`counts.json` phrasing fix** — `canonical_phrasing.shared` now reads "12 shared protocol files".
- **`references/main.md` (12,718 → 12,708)** — collapsed two duplicated file-lock step-lists in `roadmap/references` to cite `session-lifecycle.md §File-Based Locking Protocol`. The hypothesized large de-boilerplating win did not materialize: the top reference files are dense skill-specific procedure protected by named-section SKILL.md contracts and the agent-prompt-payload invariant (intentional verbatim duplication), not boilerplate.
- **`agent-orchestration.md` (1,454 → 1,435)** — removed two HEARTBEAT/PARTIAL default blocks re-embedded in the boilerplate section, which already declared §3 canonical. No `_shared` file re-split.
- **`CHANGELOG.md` (870 → 201 lines, −87 KB)** — archived the 16 `1.x` releases (1.16.0 → 1.5.0) to `CHANGELOG-ARCHIVE.md` behind an "Older releases" pointer; kept `[Unreleased]`, the Release-Process header, and all `2.x` releases live so version-sync stays green.
- **`hooks/scripts/_lib/common.sh`** — hoisted the byte-identical `fail()` helper out of `agent-frontmatter-validate.sh` + `skill-frontmatter-validate.sh` (both already sourced common.sh). `find_project_root`/`block`/`validate_one`/`usage` left inline — not byte-identical across call sites (or semantically distinct from `blitz_find_root`). Hook-script count unchanged (38).

## [2.4.0] — 2026-06-06 · unification & slimming pass

Maintenance/refactor pass — **zero behavior change**. Reduces redundancy and lazy-loaded context across the suite. Skill semantics, hook wiring, agent roles, and flags are identical.

**`_shared/` protocols: 32 → 12 `.md` files** (+ `check-registry.json`). Fragmented single-concern protocols collapsed into cohesive docs so a skill loads one file per concern instead of many. All inbound cross-references rewritten mechanically; every linked anchor preserved:

- `terse-output.md` ← `verbose-progress.md` (canonical OUTPUT STYLE block untouched — validator-pinned).
- `agent-orchestration.md` ← `spawn-protocol`, `agent-prompt-boilerplate`, `agent-routing`, `agent-view-dispatch`, `workflow-dispatch`, `token-budget`.
- `session-lifecycle.md` ← `session-protocol`, `checkpoint-protocol`, `context-management`, `state-handoff`, `scheduling`.
- `sprint-contracts.md` ← `carry-forward-registry`, `story-frontmatter`, `definition-of-done`, `deviation-protocol`, `scope-limit-protocol`.
- `quality-engine.md` ← `check-registry.md`, `quality-matrix`, `shortcut-taxonomy`, `ratchet-protocol`, `deterministic-test-recipe` (the `check-registry.json` data file stays separate).
- `security.md` ← `threat-model`, `hook-trust`, `package-install-policy`.

> **Forking note:** if your fork references `skills/_shared/<old-name>.md` directly, repoint to the consolidated file above. Each consolidated file carries a top-of-file map listing what it absorbed; former section anchors are preserved.

**SKILL.md bodies de-boilerplated** — 11 oversized skills slimmed by 916 lines total (over-granular sub-phase numbering collapsed, prose tightened to terse-technical). Every distinct top-level Phase, command, safety block, and the verbatim OUTPUT STYLE line preserved.

**Cleanup** — dropped 17 tracked `*.original` compress backups (git history is the backup; pattern gitignored); fixed the retired `frontend-design-heuristics.md` link and the pre-existing CLAUDE.md 30-vs-32 shared-count drift.

No skills merged (quality surface + UX routers stay deliberately distinct per the `quality-engine.md` four-question test). Validators green: count-sync, version-sync, plugin-structure, skill/agent-frontmatter (OUTPUT STYLE hash resolves), markdown-link, check-registry, reference-compression.

## [2.3.5] — 2026-06-06 · critic-gemini stderr JSON fix

### Fixed
- **`critic-gemini.sh` stderr noise broke JSON parsing** (#17): line 146 captured gemini output with `2>&1`, merging the CLI's terminal-capability warnings ("True color (24-bit) support not detected", "Ripgrep is not available…") into the JSON on stdout, so `jq -e .` failed and the wrapper exited 1 — disabling the cross-model critic (gemini-only / dual-CMC modes). Now captures stderr to a tempfile (surfaced only on real invocation failure) and adds a line-based pre-JSON guard (`awk '/^[[:space:]]*\{/{f=1} f'`) as defense-in-depth for gemini-cli #21433 (startup messages leaking to stdout). Regression coverage: `hooks/tests/critic-gemini.bats` (5 tests, incl. brace-in-string non-truncation). Background: `docs/_research/2026-06-06_critic-gemini-stderr-json.md`.

## [2.3.4] — 2026-06-01 · argument-hint coverage + concision

### Fixed
- **argument-hint coverage**: added the field to the 7 arg-taking skills that lacked it (`audit`, `research`, `compress`, `sprint-dev`, `sprint-plan`, `sprint-review`, `ui-build`) — all 37 skills now show an autocomplete arg chip. Display-only field; no change to invocation or argument delivery.

### Changed
- **argument-hint concision**: trimmed the `-- <prose explanation>` tails from 15 hints (`review`, `browse`, `code-doctor`, `conform`, `dep-health`, `doc-gen`, `next`, `perf-profile`, `quality-metrics`, `roadmap`, `release`, `setup`, `ship`, `sprint`, `ui-audit`) to short chips, keeping every flag spelling. Aligns with the field's short-chip intent. Background: `docs/_research/2026-06-01_command-argument-hints.md`.

## [2.3.3] — 2026-06-01 · audit remediation + README rewrite

### Fixed
- **orchestrator boot summary**: removed unsupported `initialPrompt` frontmatter (silently ignored per the documented plugin-agent field allowlist) and folded the boot state-summary into the system-prompt body so it actually fires.
- **trigger collisions**: added reciprocal routing boundaries for `review`↔`sprint-review`, `ship`↔`release`, and the bare-`audit`/`security audit` overload (object-noun routing); secondary boundaries for `sprint`↔`implement`↔`sprint-dev`, `codebase-map`↔architect, `browse`↔`ui-audit`.
- **hook path robustness**: quoted all 38 `"${CLAUDE_PLUGIN_ROOT}"` command values in `hooks.json` (shell-form, install-paths-with-spaces safe); taught `scripts/validate-plugin-structure.sh` to strip the quotes when resolving.
- **version-gating**: surfaced the effective Claude Code minimum (`>=2.1.117`) in `plugin.json` description (no manifest `engines` field exists).
- **orphan agents**: documented `architect` + `doc-writer` as orchestrator-only freeform targets.
- de-orphaned `_shared/scheduling.md` (linked from `next` + `code-sweep`); removed unsupported `color` frontmatter from 4 agents; added worker-agent invocation markers (`reviewer`/`test-writer`/`doc-writer`); documented external deps (Playwright MCP, Gemini CLI).

### Changed
- **README**: full rewrite — corrected the ANSI Shadow ASCII banner; converted 4 ASCII diagrams to Mermaid (holistic-machine overview, the Blitz cycle, review/audit registry core, carry-forward lifecycle); corrected stale counts (shared protocols → 32, check-registry → 94 checks); dropped the nonexistent typed-agent-definitions section.

## [2.3.2] — 2026-05-31 · cohesion + count-drift cleanup

Plugin-wide cohesion pass: eliminated count/version drift, de-duplicated the routing surface, clarified maintenance-skill boundaries, and brought every SKILL.md body under 450 lines — without touching the holistic-machine contracts (orchestrator → skill → worktree-agent → registry-gated critic → disk-state). No skill merged, demoted, or deleted (all three overlap clusters resolved KEEP-SEPARATE), so this is a patch.

### Added
- **`.claude-plugin/counts.json`** — authoritative, filesystem-computed plugin inventory (skills, agents, shared protocol files, hook scripts/wired/sub-invoked/critic-spawned, events, detectors). Single source of truth for every prose count.
- **`scripts/check-count-sync.sh`** — recomputes counts from disk, asserts `counts.json` is current, and validates curated prose claims in `README.md` / `CLAUDE.md` / `plugin.json` / `marketplace.json`. Wired into `pre-commit-validate.sh` (blocks when a count-bearing doc is staged with drift). `--write` regenerates `counts.json`. Root-cause fix for the count drift `check-version-sync.sh` (semver-only) never caught.

### Changed
- **Count drift fixed** (`counts.json` truth): shared protocol files 29/30 → **32**; anti-shortcut detectors 19 → **20** (13 reject / 7 advisory); hook scripts 37 → **38** (35 event-wired, 2 sub-invoked, 1 critic-spawned); `skill-cross-references.md` `EXPECTED_FILES` off-by-one 7 → **6**.
- **Routing table de-duplicated** — `skills/ask` Phase 1 now reads `agents/orchestrator.md §2` as the canonical intent→skill map at runtime + a 6-row fallback; the divergent prose mirror (with its malformed `audit` row and stale `ship`/`migrate`/`/sprint cmd` slugs) is gone (123 → 107 lines).
- **Maintenance boundaries tightened** — reciprocal one-line statements added to `health` (read-only assert + runtime probes) and `conform` (`--fix` schema repair); `setup` (CLAUDE.md-rule conflicts) already orthogonal. No merge.
- **`implement` slimmed to pure dispatch** — re-declared sprint-dev flags + duplicated pre-flight removed; slug preserved (61 → 30 lines).
- **Conciseness pass** — 12 SKILL.md bodies relocated their largest non-startup blocks to `references/main.md` (verbatim, zero behavioral loss); all now ≤450 (was 450–496). `next` gained its first `references/main.md`.

### Removed
- **sprint-19 deprecation cutover finalized** — `completeness-gate` / `integration-check` standalone skill dirs were already removed; updated the live docs (`orchestrator §2`, `quality-matrix`) that still claimed "legacy slug still works" to reflect the completed sprint-20 cutover (use `/blitz:review --only completeness|wiring`). Historical validation/consolidation docs + CHANGELOG retain the old names by design. Fixed stale `det-01..19` → `det-01..20` range in `review`.

## [2.3.1] — 2026-05-31 · browse broken-wiring detection + interaction coverage

Ports the two functional (non-aesthetic) behaviors of v2.3.0's design-critic E2 live-navigation pattern into `/blitz:browse`. From research `docs/_research/2026-05-31_browse-live-navigation-e2.md` (R1 + R3); R2/R4/R5 deferred. Sprint 22.

### Added
- **Broken-wiring detection (R1)** — `skills/browse` Phase 3.5 / loop Phase 4.6: after each existing safe-allow-listed click (tabs / pagination / sort / accordion), a control that renders but produces no observable response (no a11y-tree change AND no route change AND no network request) is recorded as a `broken_wiring` finding — Warning, or Error when the inert control is a primary action. Couples the snapshot-diff with the network check to separate renders-but-inert from handler-fires-backend-404. False-positive guard for legitimately-inert clicks. New "Broken Wiring" report section + Error-Classification taxonomy row.
- **interaction_coverage schema (R3)** — additive per-page fields in `crawl-visited.json`: `interaction_coverage {safe_clicks, broken_wiring_checked, responsive_checked}` + `broken_wiring[]`. Non-breaking (existing readers unaffected). `responsive_checked` is a forward-compat placeholder for the deferred R2 opt-in responsive pass.

### Notes
- Rides **only** browse's existing safe-interaction allow-list — the 7 NON-NEGOTIABLE safety rules + "NEVER interact with" list are unchanged. No new tool grant (`browser_snapshot`/`browser_network_requests`/`browser_click` already loaded at Phase 1.2); `allowed-tools` frontmatter unchanged. `skills/browse/SKILL.md` 389/500 lines. Critic LGTM.

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


## Older releases

1.x and earlier moved to [CHANGELOG-ARCHIVE.md](CHANGELOG-ARCHIVE.md).
