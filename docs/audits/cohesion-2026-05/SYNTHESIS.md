---
title: "Cross-Cutting Synthesis — Blitz Suite Cohesion + Modernization Audit"
created: 2026-05-28
inputs: [platform-delta.md, xref-graph.json, skills/*.md (39), agents/*.md (10)]
units_audited: 49
total_removable_lines: 1764
---

# Synthesis — Cohesion + Modernization Audit, cohesion-2026-05

Scope: 39 skills + 10 agents. Every per-unit verdict = `needs-tightening` (skills) or `REFINE/MODERNIZE/NEEDS_WORK/PASS_WITH_WARNINGS` (agents). No unit is `RETIRE`. No platform overlap survives `verify` as delegate/retire — all `claims[].refuted:true` entries are downgraded to keep-or-guard per §2. Headline modernization decision (Dynamic-Workflows-vs-sprint-dev) = **keep, guard**.

---

## 1. Overlap Map — duplicated concerns + single owner

Each row = a concern appearing in 2+ units. `Owner` = the unit that should hold the canonical logic; others cite/delegate. "True dup" = same logic maintained twice (must consolidate). "Layering" = legitimate distinct scope (document the contract, do not merge).

| # | Concern | Units touching it | Kind | SINGLE owner | Action |
|---|---|---|---|---|---|
| O1 | Changelog generation (commit-type map + Keep-a-Changelog output) | doc-gen, release, ship | **TRUE DUP** | `skills/release` (executes) | doc-gen `changelog` mode + ship Phase 2 → delegate to release prepare; collapse inline logic |
| O2 | Anti-mock / placeholder grep scan (`return {}`, TODO/FIXME, `throw new Error('Not implemented')`) | completeness-gate, sprint-review (Phase 1.5.1), code-sweep, sprint-dev (agent templates) | **TRUE PARTIAL DUP** | `skills/completeness-gate` | sprint-review 1.5.1 + code-sweep TODO grep → cite completeness-gate scan; keep gate-vs-ratchet semantic split documented |
| O3 | Unwired-store-actions + artifact-verification (Level 3) checks | completeness-gate (checks 2.11/2.12), integration-check | **TRUE PARTIAL DUP** | `skills/integration-check` (wiring topology) | completeness-gate 2.11/2.12 → delegate to integration-check; gate keeps story-AC scope only |
| O4 | Intent→skill routing table | agents/orchestrator (§2), skills/ask (Phase 1) | **TRUE DUP (maintenance surface)** | `agents/orchestrator.md §2` | ask Phase 1 → derive from / cite orchestrator table; eliminate independent maintenance |
| O5 | Changelog Phase 2 (ship) | ship, release | **TRUE DUP** | `skills/release` | (subset of O1) ship orchestrates, release executes |
| O6 | Architecture / Mermaid diagram emission | doc-gen, codebase-map | Layering | codebase-map (snapshot) / doc-gen (maintained) | document contract; no merge |
| O7 | Dead-export + duplication detection | code-doctor (D1/DUP1), code-sweep, refactor | Layering (quality-matrix §35–36) | code-sweep (ratchet) | keep; cite quality-matrix |
| O8 | Security domain coverage | codebase-audit, security-review (native) | **POTENTIAL TRUE DUP (unverified)** | codebase-audit (5-pillar) | RESOLVE: read security-review SKILL.md; if duplicate, retire one. Flagged inferred — not actioned this audit |
| O9 | package.json dep inspection | dep-health, perf-profile (1.3/1.4), migrate | Layering (audit vs act vs size-signal) | dep-health | thin boundary on perf-profile dup-version check — cite dep-health |
| O10 | Worktree branch cleanup | sprint-dev (4.4), worktree-prune, sprint-review (Inv 8), hooks/worktree-remove.sh, ratchet-protocol (Inv 6) | Layering (happy-path vs catch vs assert vs measure) | worktree-lifecycle.md (spec) | document 4-layer chain; no merge |
| O11 | Browser MCP setup + page extraction | browse, ui-audit, perf-profile | Layering (extraction targets differ) | browse (crawl state producer) | ui-audit reads browse crawl state — document interface contract (already in ui-audit/SKILL.md §page_data_registry) |
| O12 | File-based lock CHECK→ACQUIRE→VERIFY→OPERATE→RELEASE | sprint-dev (Phase 1.6 + 4.7 — restated twice), all sprint-family | **TRUE DUP (intra-unit)** | `_shared/session-protocol.md §File-Based Locking` | sprint-dev both blocks → 1-line cite each (~20 lines) |
| O13 | Carry-forward inference-fallback (parent-epic `delta:1`) | sprint-dev (3.2 §1a), carry-forward-registry.md §Writers | **TRUE DUP** | `_shared/carry-forward-registry.md §Writers` | sprint-dev → cite, drop restatement |
| O14 | Per-wave spawn caps (`≤4 stories AND ≤6 files`) | sprint-dev (2.3), spawn-protocol.md | DRY drift | `_shared/spawn-protocol.md §Heavy` | move policy to protocol |
| O15 | tsc/eslint/test/build invocation | quality-metrics, sprint-review, dep-health | Layering (observability vs gate vs CVE) | sprint-review (gate) / quality-metrics (trend) | document; no merge |
| O16 | Cross-session learning store | retrospective, knowledge-protocol.md (KNOWLEDGE.md), developer-profile.json | **DRIFT RISK** | `_shared/knowledge-protocol.md` | coordinate developer-profile.json ↔ KNOWLEDGE.md ownership (currently uncoordinated) |
| O17 | Metric trend tracking | quality-metrics, ratchet-protocol.md | Layering now / dup risk if ratchet expands to lint+type scores | ratchet-protocol.md (gate metrics) / quality-metrics (observability) | document boundary; revisit if ratchet adds lint |
| O18 | Tone / design taxonomy | design-extract, frontend-design, ui-build, design-critic | Layering (emitter/consumer/evaluator) | DESIGN.md (spec, Apache-2.0) | document directionality |

**True-dup consolidation backlog (must-fix)**: O1, O2, O3, O4, O5, O12, O13. **Resolve-then-decide**: O8 (security-review unread). **Coordinate**: O16, O17.

---

## 2. Native-Delegation Decisions — keep / delegate / retire / guard

One row per platform-delta native overlap. RESPECT verify: every `claims[].refuted:true` → downgraded to **keep** or **guard**, never delegate/retire. The audit produced 30+ refuted native-delegation claims; the dominant finding is that native primitives are intra-session/stateless and cannot replace Blitz's cross-session state contracts.

| Native primitive (platform-delta row) | Blitz overlap | Decision | Tradeoff / why | Migration sketch |
|---|---|---|---|---|
| **Dynamic Workflows v2.1.154+** (JS fan-out ≤16 concurrent, ≤1000/run, intermediate state in script vars) | sprint-dev wave-dispatch (Phase 3.2), spawn-protocol.md, agent-routing.md | **KEEP + GUARD** (headline) | See §2.1 | §2.1 |
| `/deep-research` adversarial verification (agents refute, vote) | agents/critic.md, research-critic.md, skills/research | **KEEP** | Blitz critic runs 19-detector shortcut-taxonomy + LGTM gate (Invariant 7) tied to sprint-review; native voting has no taxonomy or gate integration. research claim refuted | none — research spawns research-critic, not competing |
| Resumable workflow state (cached agent results on resume; **intra-session only**) | STATE.md, carry-forward-registry.md | **KEEP** | Native resume dies on new session; Blitz cross-session resume is the entire value. Hard floor | none |
| `/goal` completion-loop (v2.1.139) | next `--loop`, sprint `--loop` alias | **KEEP**; optionally add `/goal` row for single-condition intra-session loops | next has 10-row priority tree + cross-session STATE.md + structured stop signals; `/goal` is single-condition only. next claim refuted | orchestrator §2: additive `/goal` row for "loop until cond, no resume needed" |
| `claude agents` TUI (v2.1.139, research preview) | sprint-dev Monitor(tail -f), implement progress reporting | **KEEP** (complementary) | TUI is a viewer; Monitor drives logic. implement claim refuted | informational note in sprint-dev §visibility |
| `disallowed-tools` frontmatter (v2.1.152) | prose SAFETY RULES in 15+ skills (bootstrap, browse, ask, completeness-gate, conform, dep-health, design-extract, fix-issue, integration-check, migrate, next, quality-metrics, quick, roadmap, sprint, ui-audit) | **GUARD (additive only)** | Refuted as a *replacement* across the board: SAFETY RULES are **semantic** (no stubs, report ALL, no form-fill content) — tool-level lockdown cannot enforce content rules. `disallowed-tools` only helps where the guard is literally "don't use tool X". Defense-in-depth where applicable | per-skill: add `disallowed-tools: [Edit,Write]` ONLY to genuinely read-only audit skills (dep-health, codebase-audit, integration-check, health, ui-audit, design-extract source phases); keep prose for semantic guards |
| `/code-review --fix` (v2.1.152) | sprint-review Phase 3.6 critic apply-step, fix-issue self-review | **KEEP** (optional inline) | fix-issue claim refuted (Opus 4.8 honesty does not make a structured self-review pass redundant) | optional Phase 3.5 in fix-issue; no removal |
| `/simplify` (v2.1.154, cleanup-only auto-apply) | code-sweep, refactor, compress, skills/simplify wrapper | **KEEP** | code-sweep Reduction+Optimization overlap is partial; ratchet/ledger/grade dashboard + snapshot/revert/metrics (refactor) are stateless-native-irreplaceable. compress is markdown-domain, not code. All refuted | simplify wrapper may thin-delegate to `/simplify`; code-sweep/refactor keep |
| Opus 4.8 fast mode ($10/$50 MTok, 2.5× tok/s) | token-budget.md Opus routing; sprint-dev/doc-gen/codebase-audit/sprint-plan model fields | **GUARD / SURFACE** | NOT cost-justified for routing orchestrators (refuted for codebase-audit synthesis, doc-gen, sprint-plan as a *workload-changing* claim). IS worth surfacing for latency-critical wave-dispatch | token-budget.md: add fast-mode cost column + "latency-critical only" note; do not auto-switch |
| Native JS workflow orchestration | research §1.3-W parallel agents, codebase-map 4-agent fan-out | **KEEP** | both refuted: registry/scope contracts + web-search prohibition + cross-session not native | none |
| Mid-conv system messages (Opus 4.8, cache-preserving) | agent-prompt-boilerplate.md injection pattern | **KEEP** (opportunistic) | additive cache-preservation, not a replacement | optional: use for mid-run instruction updates |
| `settings.autoMode.hard_deny` (v2.1.136) | session-protocol.md autonomy rules | **GUARD** | align Blitz autonomy with built-in hard_deny to avoid duplicating repo-manipulation blocks | session-protocol.md: cross-ref hard_deny, drop overlapping prose |
| Opus 4.8 honesty (~4× fewer flaws unremarked) | anti-laziness prose in fix-issue, health, retrospective, completeness-gate, codebase-audit | **GUARD — partial prose cut** | See §5. Refuted as *full removal*; the verified honesty gain is real but the Gray-Swan injection *regression* is Unverified and counter-indicates blanket cuts | §5 single risk assessment |

### 2.1 Headline — Dynamic Workflows vs sprint-dev

**Decision: KEEP sprint-dev's worktree-per-agent wave engine; GUARD against premature port; selectively adopt native concurrency primitives where contracts permit.** sprint-dev claim `"Native workflow orchestration could replace wave-dispatch loop"` = **refuted:true** → not eligible for delegate/retire.

What native Dynamic Workflows give (platform-delta.md v2.1.154+):
- JS fan-out across ≤16 concurrent / ≤1000 total agents per run; intermediate results stay in script vars (out of context window) — strict win over sprint-dev's in-context `agent_tracker`.
- Confirmation never-prompts under `-p`/Agent SDK → CI alignment.

What sprint-dev has that native Workflows DO NOT subsume:
1. **Cross-session resume** — native resume is intra-session only (platform-delta.md 2026-05-28). sprint-dev rebuilds from `STATE.md` + carry-forward across sessions. **Hard blocker to delegation.**
2. **Per-story failure taxonomy** — `block_reason` vocab + circuit breaker + `BLITZ_RESUME_ON_DIVERGENCE` contract → routes into `/blitz:next` `LOOP_ESCALATE`. Native workflows surface no per-agent failure metadata.
3. **Worktree merge + ratchet** — Phase 4.4 cleanup feeds `stale_worktree_branch_count` (Invariant 6); merge-conflict handling is Blitz-specific.
4. **subagents-cannot-spawn-subagents** — constraint holds *within* a workflow run; slash-only entry point is required for cross-session resume regardless of port.

**Migration sketch (deferred, not this cycle)**: when native workflows surface (a) per-agent failure metadata and (b) cross-session resume, port the *inner* wave loop to a JS workflow script while keeping `/blitz:sprint-dev` as the slash entry point that owns STATE.md, carry-forward, and `block_reason` translation. Concurrency cap already aligns (native 16 ≥ typical 4-agent wave). Until then: adopt the **16-agent cap** as an explicit budget note in spawn-protocol.md (cheap, no risk).

---

## 3. Conciseness Ledger — removable lines by leverage

**Total removable across 49 units: 1764 lines** (skills 1682 + agents 82). Every unit reads `needs-tightening`/`REFINE`/`MODERNIZE` — none clean. Three categories: **OMC** = old-model-compensation prose (anti-laziness, "must not skip", manual-fallback notes); **DRY** = logic restated from a `_shared` protocol or sibling skill; **STALE** = dead refs / version pins / aspirational TODO notes.

Ranked by leverage (top removable_lines first):

| Unit | Removable | Dominant category | Note |
|---|---|---|---|
| browse | 195 | OMC + DRY | largest single target; SAFETY RULE prose (refuted as `disallowed-tools` replacement → trim prose, keep semantic) |
| doc-gen | 90 | DRY (O1 changelog) | delegate changelog to release |
| sprint-review | 80 | DRY (O2) + OMC | Phase 1.5.1 anti-mock re-impl → cite completeness-gate |
| dep-health | 60 | OMC | read-only audit prose |
| sprint-plan | 60 | OMC + DRY | research-scope restatement |
| next | 55 | OMC + DRY | priority-tree prose |
| perf-profile | 55 | DRY (O9) + OMC | Lighthouse scaffold prose (refuted as MCP-replaceable → keep code, trim prose) |
| quality-metrics | 55 | OMC + DRY | Safety Rules prose |
| refactor | 55 | OMC | atomic-step prose |
| research | 55 | OMC | parallel-orchestration prose |
| retrospective | 55 | OMC (honesty §5) | 55 lines defensive framing — gate on §5 risk |
| roadmap | 55 | OMC + DRY | |
| ui-audit | 55 | OMC | Safety Rule 2 prose |
| ui-build | 55 | OMC + DRY | |
| sprint-dev | 55 | DRY (O12/O13/O14) | lock-step blocks ×2 → cite |
| migrate | 45 | OMC + DRY (O9) | |
| release | 45 | DRY | |
| test-gen | 40 | OMC | |
| completeness-gate | 38 | DRY (O2/O3) + OMC | |
| fix-issue | 38 | OMC | honesty-driven |
| ship | 38 | DRY (O1/O5) | |
| codebase-audit | 35 | OMC | |
| bootstrap | 35 | OMC | SAFETY RULE 2 |
| conform | 30 | OMC | |
| code-sweep | 28 | DRY (O2/O7) | |
| compress | 28 | DRY | |
| setup | 28 | STALE + OMC | |
| todo | 25 | OMC | |
| ask | 22 | DRY (O4) | routing table |
| design-extract | 22 | OMC | |
| health | 22 | OMC (honesty §5) | |
| sprint | 22 | DRY | invocation stubs |
| code-doctor | 18 | DRY (O7) | |
| codebase-map | 18 | OMC | |
| integration-check | 18 | OMC | |
| review | 18 | DRY (alias) | |
| reviewer (agent) | 22 | OMC | |
| architect (agent) | 18 | OMC | |
| critic (agent) | 18 | OMC | |
| orchestrator (agent) | 12 | DRY + STALE | model-rationale comment |
| research-critic (agent) | 12 | OMC | |
| implement | 12 | OMC | |
| worktree-prune | 12 | DRY (O10) | |
| quick | 10 | OMC | |
| backend-dev, design-critic, doc-writer, frontend-dev, test-writer (agents) | 0 | — | clean on conciseness |

Category leverage summary: **OMC** is the single largest bucket (≈55–60% of the 1764) — directly tied to the §5 4.8-honesty assessment. **DRY** concentrates in the O1/O2/O12 true-dup chains. **STALE** is small (setup, orchestrator) — most stale weight is in xref dead-refs (§4), not prose.

---

## 4. Cohesion Fixes

### 4.1 Dead cross-references (from xref-graph) — ⚠️ SUPERSEDED: resolver artifact

> **CORRECTION (post-synthesis verification, 2026-05-28).** The xref agent's `dead_refs:242` is a **false positive**, not a real defect. The agent's link resolver treats the suite's `/_shared/X` **plugin-root convention** (resolves to `skills/_shared/X`) as a filesystem-absolute path, and joins relative links against the wrong base — fabricating phantom `_shared/_shared/` and `agents/agents/` "doubled" paths that **do not exist in any source link text**. Independent checks:
> - `grep -rEn '\]\([^)]*(_shared/_shared|agents/agents|skills/skills)' skills/ agents/` → **0 matches** (Class A does not exist in source).
> - `grep -rEc '\]\([^)]*references/docs/_research' skills/` → **0** (Class C prefix-drift does not exist).
> - All sampled `/_shared/*.md` + `docs/_research/*.md` targets resolve.
> - Authoritative suite validator `hooks/scripts/markdown-link-validate.sh` → **0 broken links**.
>
> The original Class A/B/C triage below is retained struck-through for provenance. **Do not action it.** The only valid residue is a tooling fix to the audit's own resolver (see reframed E-TOOL-1 in §6) — NOT edits to suite links. See memory `project-xref-deadref-false-positives`.

~~**Class A — broken `_shared/` self-references (real bug, must fix).** Path-doubling like `skills/_shared/_shared/ratchet-protocol.md`.~~ → **Refuted: no path-doubling in source.**
~~**Class B — generated-artifact placeholders.** `docs/generated/*`, `findings/0*-*.md`, `tmp/*`, etc.~~ → Correctly *absent* (runtime output paths); resolver should not have counted them — confirms resolver is naive.
~~**Class C — moved/renamed research docs (verify + repoint).**~~ → **Refuted: 0 prefix-drift links; all research docs resolve.**

### 4.2 Contract mismatches in real pipeline chains

- **sprint-plan → sprint-dev → sprint-review**: verified intact (sprint-dev audit §B). `status: planned → review` handoff consistent. No shape mismatch. Keep.
- **research → roadmap → sprint-plan**: roadmap consumes research `scope:` frontmatter + `*-epics.md` glob; codebase-audit is an alternate upstream producer. Verify codebase-audit emits the same `scope:`/epics shape roadmap expects (audit marked inferred, not re-read). **Action: assert producer-shape parity.**
- **completeness-gate ↔ integration-check** (O3): completeness-gate checks 2.11/2.12 duplicate integration-check's wiring level — not a *mismatch* but a logic fork that can drift. Consolidate per O3.
- **fix-issue → completeness-gate** (inline `/blitz:` invocation, no state-handoff contract): fix-issue Phase 3.3.5 calls completeness-gate without a declared artifact contract. **Add a state-handoff.md entry** so the dependency is visible.

### 4.3 Concepts defined in 2+ places (drift candidates)

| Concept | Defined in | Consolidation target |
|---|---|---|
| Changelog commit-type map | doc-gen, release, ship | `skills/release` (O1) |
| Anti-mock pattern list | completeness-gate, sprint-review, code-sweep, agent templates | `completeness-gate` + cite (O2) |
| Routing table | orchestrator §2, ask Phase 1 | `orchestrator.md §2` (O4) |
| Lock protocol | sprint-dev ×2, session-protocol.md | `session-protocol.md` (O12) |
| Carry-forward inference-fallback | sprint-dev, carry-forward-registry.md | `carry-forward-registry.md §Writers` (O13) |
| Cross-session learning | retrospective, knowledge-protocol.md, developer-profile.json | `knowledge-protocol.md` (O16) |
| Per-wave caps | sprint-dev, spawn-protocol.md | `spawn-protocol.md §Heavy` (O14) |

---

## 5. 4.8 Readiness — model strings, effort, injection, honesty cuts (single risk-assessed block)

### 5.1 token-budget.md model-string updates (STALE — must fix)

Current matrix (token-budget.md:13–23) cites retired/aliased IDs:

| Current cell | Fix to (platform-delta.md model IDs 2026-05-28) |
|---|---|
| `haiku` (4.5) | `claude-haiku-4-5` (alias of `claude-haiku-4-5-20251001`) |
| `sonnet` (4.6) | `claude-sonnet-4-6` |
| `opus` (4.7) | `claude-opus-4-8` |
| line 23 foot-gun: "Opus 4.7's new tokenizer +35% vs 4.6" | replace — stale; add Opus 4.8 fast-mode row instead |

**Add fast-mode column** (platform-delta.md `fast-mode-2026-02-01`): Opus 4.8 fast = `$10` in / `$50` out per MTok, 2.5× tok/s, `speed:"fast"` API param, research preview / Claude-API-only. Note: 3× cheaper than 4.6/4.7 fast ($30/$150). Surface for latency-critical wave-dispatch ONLY; not a default.

### 5.2 Re-derive the 60/35/5 split

The ≈60% Haiku / 35% Sonnet / 5% Opus target predates 4.8. Re-derivation:
- **Opus floor unchanged or lower**: Opus 4.8 fast mode is 3× cheaper than prior Opus fast, so the 5% Opus budget buys more; but routing/orchestration still belongs on Sonnet (refuted: fast mode not cost-justified for routing). Keep Opus ≤5% by output tokens.
- **Sonnet 4.6 stays the workhorse**: $3/$15 MTok vs Opus-fast $10/$50 — Sonnet still 3× cheaper on input, and orchestration is routing not synthesis (orchestrator audit §D). Keep 35%.
- **Haiku 4.5 unchanged** for mechanical work. Keep 60%.
- **Verdict**: 60/35/5 split survives 4.8; only the model IDs + fast-mode cost column change. test-gen `model: sonnet` flagged misaligned with Haiku mechanical-routing — **refuted** (test-gen reasoning about edge cases is Sonnet-class). Keep.

### 5.3 effort / profile re-derivation

- Routing orchestrators (`orchestrator.md`, `blitz:next`) → `effort: low` per MEMORY.md feedback. **Confirmed.**
- Multi-wave orchestrators (sprint-dev) → `effort: high`. **Confirmed divergence** — the `effort: low` feedback applies to routing-only, not multi-phase work (sprint-dev audit §D). Document this split in token-budget.md to stop future "fix" churn.
- `/effort ultracode` (= xhigh + auto-workflow, session-scoped) → token-budget.md must note ultracode sessions spawn multiple sequential workflows; do not assume single-workflow budgets.

### 5.4 Injection-surface guards (additive, low-risk)

- **orchestrator.md** reads `HANDOFF.json` + `activity-feed.jsonl` unsanitized via `jq`, renders verbatim. Add field-length caps: `jq -r '.message // "" | .[0:200]'` (~4 lines). These files are skill-written (semi-trusted), not user-controlled — risk low but non-zero (compromised skill → injected `summary`).
- Gray-Swan ASR regression (Opus 4.8 ~9.6% vs 4.7 6.0%) is **Unverified** in platform-delta.md → do NOT cite as justification, but it counsels against *relaxing* injection guards on 4.8. Net: add caps, keep existing guards.

### 5.5 Honesty-gain-driven detector/blocker cuts — ONE place, ONE risk assessment

Verified gain (platform-delta.md, `claude-opus-4-8`): "~4× less likely to let own code flaws pass unremarked." Per-unit audits marked the following anti-laziness prose as honesty-redundant — **ALL such delete-claims were verified `refuted:true`** (fix-issue, health, retrospective, completeness-gate, codebase-audit). Therefore:

**Decision: TRIM, do not DELETE.** Compress OMC prose for readability (counts toward the §3 1764 line budget) but retain the *imperative invariant* in one line each. Do not remove the structural guard, the hook, or the detector.

Rationale the verify passes give:
1. The verified honesty metric is about *self-reported code flaws*, not about following multi-phase protocol steps or anti-mock content rules — different failure mode.
2. The strongest honesty evals (0% uncritical-reporting, perfect lazy-investigation) are **Unverified** (system-card PDF, not directly fetched) — cannot found a removal on them.
3. The Gray-Swan ASR regression (also Unverified) points the other way.
4. Detectors/blockers also catch *non-Opus* agents (Sonnet/Haiku workers) where the honesty gain does not apply.

**Single risk assessment — what is lost if 4.8 regresses, and the re-enable path:**
- *If trimmed prose only*: no capability lost — invariants + hooks + detectors all remain; a regressed model still hits the structural gate. **Risk: negligible.**
- *If detectors/blockers were cut* (NOT recommended): suite loses the 19-detector shortcut-taxonomy floor on every sprint-review (Invariant 7) and the 7 anti-shortcut hooks. A 4.8 regression (or any Sonnet/Haiku worker) would ship stubs/no-verify silently.
- **Re-enable path** (if someone over-trims): the cut prose is recoverable from git history; the detectors live in `hooks/scripts/` + `shortcut-taxonomy.md` (never touched by this plan); restoring is a revert. Keep a single `git tag pre-honesty-trim` before the §6 E-OMC epic so revert is one command.

---

## 6. Sequenced Remediation Plan — as blitz epics (dog-food via `/blitz:roadmap extend`)

Dependency-ordered. Each epic: scope claim, grep-based acceptance checks, blast radius. Feed to `/blitz:roadmap extend` → `/blitz:sprint-plan` → `/blitz:sprint-dev`. Tooling-only items (xref classifier) are pre-reqs that unblock measurement.

**E-TOOL-1 — fix the audit's xref resolver to understand `/_shared/` convention (pre-req, blast: audit tooling only)**
- ⚠️ Reframed post-verification: the §4.1 "242 dead refs" were resolver false positives, NOT suite link defects (`markdown-link-validate.sh` → 0 broken). The fix is to the *cohesion-audit's own xref step*, so a future re-run doesn't fabricate phantom dead-refs.
- Scope: resolver must (a) map leading-slash `/_shared/X` → `skills/_shared/X` (plugin-root convention), (b) resolve relative links against the citing file's dir, (c) classify `docs/generated/`, `findings/`, `sprints/sprint-N/`, `tmp/` as runtime-output. Reuse `markdown-link-validate.sh` conventions as ground truth.
- Accept: re-run xref on the suite → `dead_refs` count matches `markdown-link-validate.sh` broken count (currently 0).
- Blast: audit/workflow tooling only; no skill edits.

**E-XREF-1 / E-XREF-2 — CANCELLED (phantom).** Original scope (fix path-doubling, repoint research docs) targeted non-existent defects. Source has 0 path-doubling and 0 prefix-drift links; all `/_shared/` + research-doc citations resolve. No work to do. Retained as a record so the next audit run does not re-file them.

**E-DUP-1 — changelog single-owner (O1/O5, depends: none, blast: doc-gen, ship, release)**
- Scope: release owns commit-type map + Keep-a-Changelog emit; doc-gen `changelog` mode + ship Phase 2 delegate.
- Accept: `grep -rl 'Keep a Changelog\|feat:\|fix:.*BREAKING' skills/doc-gen skills/ship` → only delegation cites, no inline map; release retains the map.
- Blast: medium — 3 skills; verify ship/doc-gen still emit identical output (golden-file test).

**E-DUP-2 — anti-mock + wiring single-owner (O2/O3, depends: none, blast: completeness-gate, sprint-review, code-sweep, integration-check)**
- Scope: completeness-gate owns placeholder scan; sprint-review 1.5.1 + code-sweep TODO grep cite it. integration-check owns wiring (checks 2.11/2.12 move out of completeness-gate).
- Accept: `grep -rn "return {}\|throw new Error('Not implemented')" skills/sprint-review skills/code-sweep` → only cites to completeness-gate; `grep -n 'unwired-store\|artifact-verification' skills/completeness-gate/SKILL.md` → delegates to integration-check.
- Blast: high — touches the quality-gate core; preserve Invariant 7 semantics; run a sprint-review smoke test.

**E-DUP-3 — routing-table single-owner (O4, depends: none, blast: orchestrator, ask)**
- Scope: orchestrator §2 is canonical; ask Phase 1 derives/cites.
- Accept: `diff <(extract orchestrator §2 intent→skill) <(extract ask Phase 1)` → ask has no independent mapping; one source.
- Blast: low.

**E-DRY-1 — sprint-dev DRY collapse (O12/O13/O14, depends: none — E-XREF-1 cancelled, blast: sprint-dev)**
- Scope: collapse both lock blocks to 1-line `session-protocol.md` cites; drop carry-forward restatement; move per-wave caps to spawn-protocol.md §Heavy. Fix Phase 4.2.1/4.2.5 ordering.
- Accept: `grep -c 'CHECK→ACQUIRE\|ACQUIRE.*VERIFY.*OPERATE' skills/sprint-dev/SKILL.md` → 0 (cited not restated); SKILL.md line count drops ~55; `grep -n '4.2.1' skills/sprint-dev/SKILL.md` precedes `4.2.5`.
- Blast: low-medium — sprint-dev is load-bearing; verify lock behavior unchanged.

**E-48-1 — token-budget.md model-string + fast-mode update (§5.1/5.2/5.3, depends: none, blast: token-budget.md + every model: frontmatter)**
- Scope: update matrix to `claude-haiku-4-5`/`claude-sonnet-4-6`/`claude-opus-4-8`; add fast-mode cost column; document effort low-vs-high split; note ultracode multi-workflow budget. Re-affirm 60/35/5.
- Accept: `grep -E 'opus-4\.7|sonnet-4\.6\b|haiku-4\.5\b|4\.7.*tokenizer' skills/_shared/token-budget.md` → 0 stale; `grep -c 'claude-opus-4-8\|fast mode\|speed.*fast' skills/_shared/token-budget.md` ≥ 1.
- Blast: medium — every `model:` field should resolve to a current ID; sprint-dev `model: opus` → confirm alias resolves to `claude-opus-4-8` (no functional change).

**E-48-2 — injection guards (§5.4, depends: none, blast: orchestrator.md)**
- Scope: add `| .[0:200]` field caps to orchestrator §4 `jq` snippets.
- Accept: `grep -c '\.\[0:200\]\|// "" | \.' agents/orchestrator.md` ≥ 1 on message/summary extraction.
- Blast: trivial.

**E-48-3 — disallowed-tools for read-only audit skills (§2 GUARD row, depends: E-48-1 for compatibility bump, blast: dep-health, codebase-audit, integration-check, health, ui-audit, design-extract)**
- Scope: add `disallowed-tools: [Edit, Write]` to genuinely read-only skills; bump `compatibility: ">=2.1.152"` on those. Do NOT add to semantic-guard skills (refuted).
- Accept: for each, `grep -A1 'disallowed-tools' SKILL.md` present AND `grep 'compatibility.*2.1.152' SKILL.md`; semantic-guard skills (bootstrap, completeness-gate, fix-issue) UNCHANGED.
- Blast: low — additive frontmatter; verify skills still function (they never wrote files).

**E-OMC-1 — honesty-aware prose trim (§5.5, depends: ALL above, blast: ~25 skills + 6 agents, ≈55–60% of 1764 lines)**
- Pre-req: `git tag pre-honesty-trim` (re-enable path).
- Scope: TRIM OMC prose to 1-line invariants; DELETE no detector/hook/structural guard. Largest targets first: browse(195), then doc-gen residual, sprint-review residual, dep-health, sprint-plan…
- Accept: per-unit body line count drops toward audit `removable_lines`; `grep -rl 'ANTI-MOCK\|BANNED:\|never skip\|report ALL' skills/` still non-empty (invariants survive); `ls hooks/scripts/ | wc -l` unchanged (36); `grep -c . skills/_shared/shortcut-taxonomy.md` unchanged.
- Blast: high surface, low logic — readability only; revert path = `git revert` to `pre-honesty-trim`. Run full sprint-review smoke + frontmatter lint (`hooks/scripts/skill-frontmatter-validate.sh --all`) after.

**Resolve-then-decide (not an epic until input read):**
- **R-1 (O8)**: read `security-review` SKILL.md vs codebase-audit security pillars; if true dup, file a retire/merge epic. Until read, no action.
- **R-2 (O16/O17)**: coordinate `developer-profile.json` ↔ `KNOWLEDGE.md` ownership and ratchet-vs-quality-metrics metric boundary; design note before code.

Ordering rationale: tooling (E-TOOL-1) and xref fixes unblock accurate measurement; DUP/DRY consolidations are independent and parallelizable; 4.8 model/guard updates are low-blast and independent; **E-OMC-1 runs LAST** because it touches the most files and its safety depends on the §5.5 risk floor (detectors/hooks untouched) being verified intact first.

---
{"written":true,"sections":6}
