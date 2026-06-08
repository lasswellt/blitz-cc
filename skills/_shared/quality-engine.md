# Quality Engine

Consolidated blitz protocol. **Absorbs** (2026-06-06 `_shared` consolidation) 5 former files; each appears below as a top-level section with original sub-headings preserved as anchor targets. Inbound `oldfile.md#anchor` links were mechanically rewritten to `quality-engine.md#anchor`.

| Former file | Section |
|---|---|
| `check-registry.md` | [Shared Check Registry](#shared-check-registry) |
| `quality-matrix.md` | [Quality-Skill Decision Matrix](#quality-skill-decision-matrix) |
| `shortcut-taxonomy.md` | [Shortcut Taxonomy — 20 Autonomous-Coder Failure Modes (13 reject, 7 advisory)](#shortcut-taxonomy--20-autonomous-coder-failure-modes-13-reject-7-advisory) |
| `ratchet-protocol.md` | [Quality Ratchet Protocol](#quality-ratchet-protocol) |
| `deterministic-test-recipe.md` | [Deterministic Test Recipe — patterns for async / timing / mock-heavy specs](#deterministic-test-recipe--patterns-for-async--timing--mock-heavy-specs) |


---

<!-- ===== Absorbed from check-registry.md ===== -->

## Shared Check Registry

`check-registry.json` (schema `blitz-check-registry/2.0`) is the single source of truth for every check the review/audit family runs. It supersedes the prose detector table and grep patterns that were previously duplicated across `shortcut-taxonomy.md §1/§3`, `agents/critic.md §2.1`, and the quality skills. Consumers **select rows** from it; `agents/critic.md` and `agents/research-critic.md` **enforce rows** from it. Confidence math is defined once, here.

Status: shipped 2026-05-29 (sprint-18, migration-map Epic 1). The `/blitz:review` and `/blitz:audit` consolidations that select from it land in sprint-19 (Epics 4–6).

### The two axes

#### Lane (detection mechanism)

| Lane | Mechanism | FP rate | base_confidence | Verification |
|---|---|---|---|---|
| `deterministic` | grep / AST / tsc / git / import-graph / npm-audit | ~0 | 0.6–1.0 | the mechanism *is* the verification (a `tsc` error reproduces by definition) |
| `semantic` | LLM agent reasoning about behavior/intent | high, sporadic | 0.45–0.55 single-pass | requires **aggregation** (≥2 agreers) AND **FP-verification** (re-read code, confirm reproduces) |

The lanes catch **disjoint** bug classes (ianlpaterson 38-task, 2026-03-08: "neither alone sufficed"), so a skill running only one lane ships errors.

#### Verdict authority (ground truth vs judgment)

Derived deterministically from `lane`+`severity`, NOT decided per-run:

- **`reject`** — ground-truth-anchored (deterministic lane, severity P0/P1/P2). May flip a critic/gate verdict to REJECT. **Bypasses the min-confidence gate** (facts aren't confidence-triaged).
- **`advisory`** — opinion-anchored (semantic lane, or P3 deterministic checks). May ONLY append to `issues[]`. **Never flips a verdict.** Subject to min-confidence suppression.

Derivation: `reject iff (lane==deterministic AND severity ∈ {P0,P1,P2}); else advisory`. This codifies the self-critique paradox (Snorkel 2025-11-26; arxiv 2402.08115): opinion-anchored verification is structurally barred from rejection; ground-truth findings (`tsc`, reflog, ratchet arithmetic) carry no blind-spot risk and keep full reject authority. See [`agents/critic.md`](../../agents/critic.md) §4.

### Confidence model

```
effective_confidence = base_confidence × fp_verification_factor
```

- `base_confidence` — inverse-FP prior. Deterministic ≈ 0.6–1.0; semantic single-pass ≈ 0.5; **semantic rises to ≈0.85 only when ≥2 independent agents flag the same finding** (Multi-Review aggregation; SWRBench 2509.01494, +43.67% F1).
- `fp_verification_factor` — `reproduced → 1.0`, `not_reproduced → 0.0` (dropped), `inaccessible/unverifiable → 0.5`. **Maxes at 1.0 — FP-verification can only preserve or drop, never raise.** Only aggregation raises a semantic finding's confidence.

Gate (advisory findings only): `/blitz:review` → `--min-confidence high` (≥0.8, precision); `/blitz:audit` → `--min-confidence low` (≥0.0, recall). **`reject` findings bypass the gate** (`confidence_gate.reject_bypass`) — e.g. det-06 (env-fallback, base 0.75, reject-authority) surfaces despite being below the high band, because a fact is not confidence-triaged.

**Severity ≠ verdict authority.** A semantic check can carry high severity (sem-sec is P2) yet remain `advisory` — severity encodes ratchet/triage importance; `verdict_authority` encodes whether it may REJECT. Orthogonal, derived independently.

**Downgrade rule (anti-FP):** a semantic finding with no reproducing evidence is capped at `advisory` and can NEVER be a `blocker` regardless of confidence; `fp_verification_factor` defaults to 0 (dropped) until evidence is attached. This is the structural fix for the v1.16.0 inflated-count incident (counts reported as findings without sampled code).

### Detector-count reconciliation

**Canonical phrasing: "20 catalogued detectors (det-01…20; det-20 — audit-FP — appended 2026-05-16). 13 carry reject authority, 7 are advisory (det-05, det-08, det-09, det-10, det-16, det-17, det-20)."** The retired "19 blocking + 1 advisory" phrasing was wrong (6 of det-01…19 are advisory). `critic.md`'s LGTM summary "8 critic checks" counts the 8 reject-checklist *classes* §2.1–2.8, distinct from the 20 detectors.

### Selection contract

```
review_checks  = checks.filter(c => c.consolidated_target in {review, both})
audit_checks   = checks.filter(c => c.consolidated_target in {audit, both})
deterministic  = checks.filter(c => c.lane == 'deterministic')   # both skills, run first, fast, zero-FP
semantic       = checks.filter(c => c.lane == 'semantic')        # review: single-pass; audit: aggregated
reject_only    = checks.filter(c => c.verdict_authority == 'reject')   # critic may flip verdict; bypass min-confidence
```

Skills/critics cite `det-NN` / `sem-*` ids and run `detection.command` — no grep pattern lives in any skill or agent body. The schema lint ([`hooks/scripts/check-registry-validate.sh`](../../hooks/scripts/check-registry-validate.sh)) asserts the derivation invariant + `detection` presence/type at commit time (risks R2/R5).

### Out of scope

Orthogonal-domain checks are NOT in the registry: `dep-health`, `perf-profile`, `ui-audit`, `browse`, `quality-metrics` — distinct scope/tempo/downstream per [`quality-matrix.md`](#quality-skill-decision-matrix). The registry is the review/audit shared core only.

### Related

- [`check-registry.json`](check-registry.json) — the data
- [`shortcut-taxonomy.md`](#shortcut-taxonomy--20-autonomous-coder-failure-modes-13-reject-7-advisory) — human-readable view of the `det-*` rows
- [`agents/critic.md`](../../agents/critic.md), [`agents/research-critic.md`](../../agents/research-critic.md) — enforcement engines
- `docs/consolidation/review-audit/` — full design specs (registry-design, review-spec, audit-spec, critic-redesign, research-critic-redesign, flaw-finding-proof, effectiveness-research)



---

<!-- ===== Absorbed from quality-matrix.md ===== -->

## Quality-Skill Decision Matrix

Updated 2026-05-29 (sprint-19 consolidation). The review/audit/quality surface is now **2 consolidated entry points** over a **shared check registry** ([`check-registry.json`](check-registry.json)), plus 2 standalone tools and 5 orthogonal-domain skills. This matrix is the single "which one do I want?" reference.

### TL;DR — pick by your symptom

| Symptom | Skill |
|---|---|
| "Is this change/sprint mergeable?" (per-change gate) | `/blitz:review` |
| "Comprehensive pre-release deep audit; find all tech debt" | `/blitz:audit` |
| "Just the placeholder/stub scan" | `/blitz:review --only completeness` |
| "Just the wiring/orphan-route/auth check" | `/blitz:review --only wiring` |
| "Vue/Firestore/Pinia framework misuse" | `/blitz:review --only framework`, or `/blitz:code-doctor --fix` |
| "AI-aesthetic tells / design slop / design-system conformance" | `/blitz:review --only design` (precision) · `/blitz:audit --pillar design` (recall) |
| "Continuous ratchet that only goes forward" | `/blitz:code-sweep` (loop) |
| "Dependency CVEs / licenses" | `/blitz:dep-health` |
| "Bundle size / Lighthouse / runtime perf" | `/blitz:perf-profile` |
| "Cross-page UI consistency / data drift" | `/blitz:ui-audit` |
| "E2E smoke / console errors" | `/blitz:browse` |
| "Quality trend over time" | `/blitz:quality-metrics` |

### The two consolidated entry points

| | `/blitz:review` | `/blitz:audit` |
|---|---|---|
| Scope | one change / sprint | full codebase |
| Tempo | per-change gate | pre-release / quarterly |
| **Bias** | **precision** (low FP — runs constantly) | **recall** (catch everything — runs rarely) |
| Lanes | both (deterministic + single-pass semantic) | both (deterministic + **aggregated** semantic) |
| Aggregation | opt-in (`--aggregate`) | required (≥2 agreers → high confidence) |
| FP-verification | inline (re-read, reproduce) | adversarial panel (refute + majority vote) |
| Confidence gate | `--min-confidence high` (≥0.8) | `--min-confidence low` (≥0.0, ranked) |
| Critic | in-Claude default; `--dual` for semantic | `BLITZ_DUAL_CRITIC=1` default + FP-panel |
| Engine | `sprint-review` (8-invariant gate) | `audit` (5-pillar fan-out) |
| Output | PASS/FAIL + 8-invariant report + auto-fix | scorecard + ranked findings + roadmap epics + `coverage_boundary` |

Both select checks from [`check-registry.json`](check-registry.json) by `consolidated_target`. The registry carries each check's `lane` (deterministic|semantic), `verdict_authority` (reject|advisory), and `base_confidence`. **review suppresses what audit re-surfaces**: a single-pass semantic finding review drops as low-confidence is exactly what audit's aggregation lifts to high confidence — complementary, not redundant. See [check-registry.md](#shared-check-registry) for the confidence model + verdict-flip asymmetry.

### Folded into the entry points (deprecated standalone — sprint-19)

| Was standalone | Now | Invoke |
|---|---|---|
| `completeness-gate` | review Phase 1.5 (O2: `o2-*`, det-09/10) | `/blitz:review --only completeness` |
| `integration-check` | review Phase 1.6 (O3: `o3-*`, det-16) | `/blitz:review --only wiring` |

**Cutover complete (sprint-20).** The standalone `completeness-gate` / `integration-check` skill dirs are removed; the legacy slugs no longer resolve. Use the `--only` invocations above. Canonical patterns live in the registry, not in the skill bodies.

### Standalone tools (NOT folded — distinct tempo/mechanism)

| Skill | Why standalone |
|---|---|
| `code-sweep` | continuous `/loop` ratchet + convention-discovered standards — a *tempo*, not a gate. Its checks (det-03/04/08/17) are registry-shared; the loop is not. |
| `code-doctor` | framework rule packs (F/V/P/G) + `--fix` auto-apply + `paths:` glob auto-load. review embeds the *scan* (`--only framework`); `--fix` stays here. |

### Orthogonal domains (out of review/audit scope)

Distinct scope + tempo + downstream + domain (the four-question test below). Invoked alongside, never inside, review/audit:

| Skill | Domain |
|---|---|
| `quality-metrics` | observability / trend (audit Phase 4 *calls* it for a snapshot; not absorbed) |
| `dep-health` | dependency CVE / license governance |
| `ui-audit` | cross-page visual + data-integrity |
| `perf-profile` | bundle / Lighthouse / runtime |
| `browse` | E2E smoke / console / network |

### The agents

| Agent | Role |
|---|---|
| `critic` | adversarial pre-PASS gate (review Invariant 7; audit critic). Registry-driven §2.1; verdict-flip asymmetry (ground-truth → REJECT, advisory → annotate). |
| `research-critic` | citation/claim gate for research docs (graded claim-grounding, UNVERIFIED verdict, scope-claim blocker). |
| `reviewer` | the 4 parallel reviewer agents review spawns (security/backend/frontend/patterns). |
| `architect` | audit Architecture pillar. |
| `design-critic` | design pillar's semantic/vision lane (5-dim screenshot score); backed by the deterministic Layer 0/1/2 detector + the detect-stack adapter. |

### Authoring guidance — before adding an 8th quality skill

1. **Scope distinct?** (change vs repo vs file)
2. **Tempo distinct?** (per-change gate vs continuous loop vs pre-release)
3. **Downstream distinct?** (review.md vs ratchet.json vs roadmap doc vs exit code)
4. **Would a `--mode`/`--only` flag on review/audit do?** Usually yes — prefer flags over new skills.

If you can't answer all four with distinct values, don't add the skill — add a registry row or a `--only` mode instead.

### Cross-refs

- [`check-registry.json`](check-registry.json) / [`check-registry.md`](#shared-check-registry) — shared check source + confidence model
- [`shortcut-taxonomy.md`](#shortcut-taxonomy--20-autonomous-coder-failure-modes-13-reject-7-advisory) — human-readable view of `det-*` rows
- `skills/review/SKILL.md` — precision front-door · `skills/audit/SKILL.md` — recall entry point
- `skills/sprint-review/SKILL.md` — review engine (8-invariant gate) · `skills/audit/SKILL.md` — audit engine
- `agents/critic.md`, `agents/research-critic.md` — enforcement engines
- `docs/consolidation/review-audit/` — full design specs



---

<!-- ===== Absorbed from shortcut-taxonomy.md ===== -->

## Shortcut Taxonomy — 20 Autonomous-Coder Failure Modes (13 reject, 7 advisory)

> **Canonical source is now [`check-registry.json`](check-registry.json)** (schema `blitz-check-registry/2.0`, shipped sprint-18). This doc is the human-readable **view** of the `det-*` rows. The executable `detection.command`, `lane`, `verdict_authority`, and `base_confidence` live in the registry; the §1 table and §3 greps below mirror them for reading and MUST stay in sync (the schema lint `hooks/scripts/check-registry-validate.sh` enforces structure). Cite detectors as `det-NN`.
>
> **Count reconciliation:** 20 catalogued detectors (det-01…20; det-20 appended 2026-05-16). **13 carry reject authority** (may flip a verdict; bypass the min-confidence gate); **7 are advisory** (det-05, det-08, det-09, det-10, det-16, det-17, det-20 — append to `issues[]` only). The older "19 blocking + 1 advisory" phrasing was wrong (6 of det-01…19 are also advisory). Severity (P0–P3) ≠ verdict authority — see [`check-registry.md`](#shared-check-registry).

Canonical detector catalog for autonomous-coder shortcuts, lies, and fake-completion. Used by:

- `agents/critic.md` (read-only adversarial review before sprint-review PASS)
- `skills/sprint-review/SKILL.md` (Phase 3.6 invariants)
- `skills/review/SKILL.md` (`--only completeness` extends placeholder scanning)
- `hooks/scripts/block-*` (PreToolUse blockers for the most damaging classes)

**Why this doc exists**: `docs/_research/2026-05-01_autonomous-blitz-quality-efficiency.md` §3.3 catalogued the original 19 ways autonomous coders silently produce non-production-ready output (det-20, audit-FP, was appended 2026-05-16 → 20 total). Without grep/diff detectors, these shortcuts ship undetected. The patterns are now defined as data in [`check-registry.json`](check-registry.json); this doc is the readable view.

---

### 1. Detector matrix

| # | Failure | Detector signal | Enforcement | Source |
|---|---|---|---|---|
| 1 | Deleted failing tests | `git diff --diff-filter=D -- '*.test.*' '*.spec.*'` returns any path | `block-test-deletion.sh` (PreToolUse) + critic 2.4 | TestKube 2026 |
| 2 | `--no-verify` bypass | Bash command contains standalone `--no-verify`; reflog grep | `block-no-verify.sh` (PreToolUse) + critic 2.7 | claude-code#40117 (Mar 2026) |
| 3 | Mock count grows in src/ | `grep -rE '\bvi\.mock\|jest\.mock\|sinon\.stub\b' src/ --exclude-dir=__tests__ \| wc -l` delta > 0 | ratchet `mocks_in_src` | TestKube 2026 |
| 4 | `as any` / `@ts-ignore` proliferation | `git diff HEAD~N -- src/ \| grep -E '^\+.*\bas any\b\|@ts-(ignore\|nocheck)'` (non-test) | ratchet `as_any_count` + critic 2.1 | code-sweep Tier 1 |
| 5 | Swallow-and-continue catch | regex `catch\s*\([^)]*\)\s*\{[\s\n]*\}` or `catch.*\{[^}]*console\.(log\|warn)[^}]*\}` no rethrow | review --only completeness | OWASP A09 |
| 6 | Env var fallbacks hiding config errors | `\|\|\s*['"]` or `\?\?\s*['"]` near password\|secret\|key\|token\|host\|port | review --only completeness | autonomous-coding 2026 reports |
| 7 | Hardcoded credentials | `password\s*=\s*['"][^'"]{3,}` + entropy heuristic | pre-edit-guard (.env) + review --only completeness | OWASP A07 |
| 8 | Commented-out failing assertions | `git diff \| grep '^+\s*//.*expect\|assert\|should\.'` | code-sweep Tier 2 | autonomous-coding 2026 reports |
| 9 | `throw new Error('Not implemented')` | grep | review --only completeness | blitz baseline |
| 10 | `return {}` / `return []` stubs | grep `return\s*\{\s*\}\|return\s*\[\s*\]` in business logic | review --only completeness | blitz baseline |
| 11 | Hallucinated APIs / symbols | `tsc --noEmit` + import resolution check | post-edit-typecheck-block.sh + critic 2.6 | Arize 2026 |
| 12 | Claiming done on broken build | tsc errors increased after Write | `post-edit-typecheck-block.sh` (PostToolUse, blocking) | dev.to Feb 2026 |
| 13 | `.skip`/`.only`/`xit`/`xdescribe` | grep on test files | critic 2.1 + sprint-review | blitz baseline |
| 14 | Test file renamed away | `git log --diff-filter=R --name-status \| grep '\.test\.\|\.spec\.'` to non-test | critic 2.8 | autonomous-coding 2026 reports |
| 15 | Hardcoded localhost / ports / URLs | grep `localhost\|127\.0\.0\.1\|0\.0\.0\.0\|:[0-9]{3,5}` in src | review --only completeness | OWASP A08 |
| 16 | Orphaned files never imported | import-graph traversal (Level 3) | review --only wiring | blitz baseline |
| 17 | Infinite correction loop | consecutive-fix-failure counter ≥ 2 | code-sweep circuit breaker (existing) | blitz baseline |
| 18 | Destructive SQL outside migration | DROP/DELETE/TRUNCATE in psql/mysql/sqlite3/mongosh CLI command | `block-destructive-sql.sh` (PreToolUse) | Cursor+Railway, Replit Rogue |
| 19 | `git reset --hard` on dirty tree | git command + working-tree non-empty | `block-destructive-git.sh` (PreToolUse) | autonomous-coding 2026 reports |
| 20 | Unverified pattern-match claim (audit FP) | Audit finding cites grep count in Evidence with no sampled code excerpt or inverse-query output; OR no `Confidence:` field | critic 2.9 (advisory) | `docs/_research/2026-05-16_audit-agent-fp-prevention.md` |

---

### 2. Severity tiers

- **P0 (PreToolUse hard-block)**: 1, 2, 18, 19 — and 12 (PostToolUse hard-block). These are the catastrophic classes; the hook must `exit 2`.
- **P1 (sprint-review BLOCKER)**: 4, 13, 14 — sprint cannot reach PASS while present.
- **P2 (ratchet metric)**: 3, 4, 6, 7, 15 — surfaced as ratchet regressions; trigger auto-revert on deterministic regression.
- **P3 (advisory)**: 5, 8, 16, 17, 20 — review (`--only completeness`/`--only wiring`) / critic findings; surface but do not auto-block.

P0 corresponds to the five hooks shipped as part of this protocol (blast-radius too large to defer to review).

---

### 3. Detector reference (canonical greps)

Single-source-of-truth grep patterns. Scripts and skills SHOULD reference this doc instead of duplicating:

```bash
# 1. Test deletion (since N commits)
git diff --diff-filter=D --name-only HEAD~N..HEAD -- '*.test.*' '*.spec.*' '*.test.tsx' '*.spec.tsx'

# 2. --no-verify
git log --all --since='3 days ago' --pretty='%H %s%n%b' | grep -E '(^|\s)--no-verify(\s|$)'

# 3. Mock count in src/
grep -rEn '\b(vi\.mock|jest\.mock|sinon\.stub)\b' src/ --exclude-dir=__tests__ 2>/dev/null | wc -l

# 4. as any / @ts-ignore in non-test
grep -rEn '\bas any\b|@ts-(ignore|nocheck)' src/ \
  --include='*.ts' --include='*.tsx' --include='*.vue' --exclude-dir=__tests__ 2>/dev/null | wc -l

# 5. Empty catch
grep -rPzo '(?s)catch\s*\([^)]*\)\s*\{\s*\}' src/ 2>/dev/null

# 6. Env fallback near credential names
grep -rEn '(\|\||\?\?)\s*[\x27"][^\x27"]*[\x27"]' src/ 2>/dev/null | grep -iE 'password|secret|key|token|host|port' | head

# 7. Hardcoded credentials
grep -rEn '(password|api_?key|secret|token)\s*[:=]\s*[\x27"][^\x27"]{8,}' src/ 2>/dev/null | head

# 8. Commented-out assertions (in diff)
git diff HEAD~5..HEAD | grep -E '^\+\s*//.*\b(expect|assert|should)\b'

# 9, 10. Not-implemented / empty stubs
grep -rEn "throw new Error.*[Nn]ot\s*[Ii]mplemented|return\s*\{\s*\}\s*$|return\s*\[\s*\]\s*$" src/ 2>/dev/null

# 11. Hallucinated APIs (use type-check)
npx tsc --noEmit 2>&1 | grep -E 'error TS2(307|305|304|339|345)'

# 13. .skip/.only/xit/xdescribe in tests
grep -rEn '\.(skip|only)\s*\(|\bxit\b|\bxdescribe\b|\bxtest\b|test\.todo\(' \
  --include='*.test.*' --include='*.spec.*' . 2>/dev/null

# 14. Test file rename to non-test
git log --since='1 day ago' --diff-filter=R --name-status -- '*.test.*' '*.spec.*'

# 15. Hardcoded localhost/ports
grep -rEn '(https?://(localhost|127\.0\.0\.1|0\.0\.0\.0)|:[0-9]{4,5}\b)' src/ \
  --include='*.ts' --include='*.tsx' --include='*.vue' 2>/dev/null | head

# 18. Destructive SQL in shell history (best-effort)
history 2>/dev/null | grep -iE '(DROP\s+TABLE|TRUNCATE|DELETE\s+FROM\s+[^;]+;)' | head

# 19. git reset --hard usage in commit messages
git reflog --all | grep -iE 'reset.*--hard' | head

# 20. Unverified pattern-match claim in audit findings file
# Flag Evidence blocks that record a count without a sampled code excerpt or
# inverse-query output. Run against each audit-style findings file.
FINDING_FILE="${1:-}"
grep -A3 '^\*\*Evidence\*\*:' "$FINDING_FILE" \
  | grep -E '^\*\*Evidence\*\*:\s*[0-9]+\s*(hits|matches|occurrences|instances|files)\b' \
  | grep -v '```'
# Also flag findings missing a Confidence: <0-100> field
grep -L 'Confidence:\s*[0-9]\+' "$FINDING_FILE"
```

Replace `HEAD~N` with the appropriate sprint-start commit when running from sprint-review.

---

### 4. False-positive escape hatches

| Detector | Escape | Justification |
|---|---|---|
| Test deletion | If commit message contains `BREAKING:` AND user is the committer, allow. | Genuine breaking change with intentional test removal. |
| `--no-verify` | Env var `BLITZ_OVERRIDE_NO_VERIFY=1` set by user (not agent). | Production hotfix with documented flaky test. Logged. |
| `as any` in non-test | Inline comment `// blitz:any-allowed: <reason>` on same line. | Unavoidable interop. Comment is documentation. |
| `.skip` in tests | Inline comment `// blitz:skip-pinned: #<issue>` referencing tracked issue. | Test pinned awaiting external fix. |
| Destructive SQL | Path contains `migrations/` OR `migrate up\|down\|run` invocation. | Migration tooling. |
| `git reset --hard` | Working tree clean OR user manually invoked. | No work to lose. |

The escape hatches are documented to keep critic from being uselessly noisy. Agents must NOT add these comments unless they have a real, defensible reason — sprint-review Phase 3.6 spot-checks 3 random escape-hatch comments per sprint and demands the rationale survive scrutiny.

---

### 5. Related

- `agents/critic.md` — primary consumer (read-only adversarial review)
- `hooks/scripts/block-no-verify.sh`, `block-destructive-git.sh`, `block-destructive-sql.sh`, `block-test-deletion.sh`, `post-edit-typecheck-block.sh` — P0 enforcement
- `skills/_shared/quality-engine.md` — ratchet metrics 3, 4, 6, 7, 15
- `skills/review/SKILL.md` — `--only completeness` placeholder scan + `--only wiring` import-graph
- `skills/code-sweep/SKILL.md` — Tier 1/2 progressive cleanup
- `skills/sprint-review/SKILL.md` — Phase 3.6 enforcement
- `docs/_research/2026-05-01_autonomous-blitz-quality-efficiency.md` §3.3 — research basis (with citations)



---

<!-- ===== Absorbed from ratchet-protocol.md ===== -->

## Quality Ratchet Protocol

Authoritative protocol for monotonic quality metrics. The ratchet ensures **work compounds**: code quality only improves across sprints, never regresses. Sprint-review enforces ratchet invariants in Phase 3.6; auto-revert triggers on deterministic regressions.

**Why this doc exists**: `docs/_research/2026-05-01_autonomous-blitz-quality-efficiency.md` §3.3 documented 19 shortcut signals and the ratchet pattern that proves work compounds across monotonic metrics (originally 7; expanded to 8 on 2026-05-17 with `stale_worktree_branch_count` per [worktree-lifecycle.md](worktree-lifecycle.md)). This is the canonical schema and enforcement contract.

---

### 1. The 7 Monotonic Metrics

Stored in `docs/sweeps/ratchet.json`, updated by `code-sweep` and `sprint-review`:

| Metric | Direction | Floor | Detector |
|---|---|---|---|
| `test_count` | ↑ | baseline | `grep -rcE '\b(it\|test)\(' --include='*.test.*' --include='*.spec.*' . \| awk -F: '{s+=$2} END {print s}'` |
| `type_errors` | ↓ | absolute 0 | `npx tsc --noEmit 2>&1 \| grep -cE 'error TS\d+'` |
| `as_any_count` | ↓ | baseline | `grep -rEn '\bas any\b' src/ --include='*.ts' --include='*.tsx' --include='*.vue' --exclude-dir=__tests__ \| wc -l` |
| `lint_violations` | ↓ | baseline | `npx eslint --format=json . 2>/dev/null \| jq '[.[].errorCount] \| add // 0'` |
| `completeness_score` | ↑ | baseline | `/blitz:review --only completeness` (existing) |
| `mocks_in_src` | ↓ | baseline | `grep -rEn '\b(vi\.mock\|jest\.mock\|sinon\.stub)\b' src/ --exclude-dir=__tests__ \| wc -l` |
| `todo_count` | ↓ | baseline | `grep -rEn '\b(TODO\|FIXME)\b' src/ \| wc -l` |
| `stale_worktree_branch_count` | ↓ | baseline | `git for-each-ref --format='%(refname:short)' refs/heads/worktree-agent-* refs/heads/worktree-sprint-* refs/heads/sprint-*/backend refs/heads/sprint-*/frontend refs/heads/sprint-*/tests refs/heads/sprint-*/infra refs/heads/sprint-*/integration \| wc -l` |

`type_errors` is special: it has an **absolute floor of 0** in addition to the ratchet. Once a project hits 0, it cannot regress to 1.

`stale_worktree_branch_count` measures branches matching the spawn-protocol-controlled patterns from [worktree-lifecycle.md](worktree-lifecycle.md). Existing projects must run `code-sweep --baseline stale_worktree_branch_count` once to grandfather pre-fix debt; otherwise the first sprint-review post-upgrade will fail Invariant 8 for projects with N>0 stale branches. After baselining, the ratchet tightens monotonically as `/blitz:worktree-prune` reduces the count.

> **Native agent-view interop:** this detector counts blitz-controlled branch refs only. A live `claude agents` background session may transiently inflate the count via its `.claude/worktrees/<id>` worktree — a measurement-timing artifact, not a leak. Do **not** auto-prune to drive the count down: the live-session guard ([worktree-lifecycle.md](worktree-lifecycle.md) §Interop, invariant 6) forbids removing a live session's worktree. Let the count settle after the session completes.

---

### 2. File Schema

`docs/sweeps/ratchet.json`:

```json
{
  "$schema": "blitz-ratchet/1.0",
  "sprint": "sprint-N",
  "updated_at": "2026-05-01T00:00:00Z",
  "metrics": {
    "test_count":         {"baseline": 0, "current": 0, "min_allowed": 0, "direction": "up"},
    "type_errors":        {"baseline": 0, "current": 0, "max_allowed": 0, "direction": "down", "absolute_floor": 0},
    "as_any_count":       {"baseline": 0, "current": 0, "max_allowed": 0, "direction": "down"},
    "lint_violations":    {"baseline": 0, "current": 0, "max_allowed": 0, "direction": "down"},
    "completeness_score": {"baseline": 0, "current": 0, "min_allowed": 0, "direction": "up"},
    "mocks_in_src":       {"baseline": 0, "current": 0, "max_allowed": 0, "direction": "down"},
    "todo_count":         {"baseline": 0, "current": 0, "max_allowed": 0, "direction": "down"},
    "stale_worktree_branch_count": {"baseline": 0, "current": 0, "max_allowed": 0, "direction": "down"}
  },
  "auto_revert": {"enabled": true, "needs_human_label": "ratchet-regression"},
  "history": [
    {"sprint": "sprint-1", "ts": "2026-04-01T00:00:00Z", "metrics": {"...": "..."}}
  ]
}
```

Key rules:
- `baseline` = value from end of previous sprint (frozen reference).
- `current` = value at last sprint-review run.
- `min_allowed` / `max_allowed` = enforcement threshold (= baseline by default; tightens when current beats baseline).
- `direction` = `up` (↑) or `down` (↓).
- `history[]` = append-only sprint-end snapshots; never rewritten.

---

### 3. Tighten-on-Improvement (the actual ratchet)

When a sprint-review run computes `current` better than `max_allowed`/`min_allowed`:

1. Update `current` to the new value.
2. Tighten threshold: `max_allowed = current` (for ↓ metrics) or `min_allowed = current` (for ↑ metrics).
3. Append snapshot to `history[]`.

The threshold can never loosen. Once `as_any_count` drops to 5, it must stay ≤5 forever.

---

### 4. Multi-Agent Worktree Merge

When two parallel sprint-dev waves modify ratchet metrics in separate worktrees, the merge takes the **min** of `max_allowed` and the **max** of `min_allowed` across both worktrees:

```bash
merge_ratchet() {
  local left="$1" right="$2" out="$3"
  jq -s '
    .[0] as $L | .[1] as $R |
    {
      sprint: $L.sprint,
      updated_at: now | strftime("%Y-%m-%dT%H:%M:%SZ"),
      metrics: ($L.metrics | to_entries | map(
        .key as $k |
        .value as $lv |
        $R.metrics[$k] as $rv |
        {key: $k, value:
          if $lv.direction == "down"
          then $lv + {max_allowed: ([$lv.max_allowed, $rv.max_allowed] | min),
                      current:     ([$lv.current,     $rv.current]     | min)}
          else $lv + {min_allowed: ([$lv.min_allowed, $rv.min_allowed] | max),
                      current:     ([$lv.current,     $rv.current]     | max)}
          end
        }
      ) | from_entries),
      auto_revert: $L.auto_revert,
      history: ($L.history + $R.history)
    }' "$left" "$right" > "$out"
}
```

The intent: a parallel branch cannot "loosen" the ratchet by merging; it can only contribute improvements.

---

### 5. Auto-Revert Protocol (deterministic regressions only)

When a fix commit during sprint-dev causes a deterministic metric to regress, sprint-dev MUST:

```
after each fix commit:
  current = compute_metrics()
  for each metric where direction-violation detected:
    if metric in {type_errors, as_any_count, lint_violations, completeness_score, mocks_in_src, todo_count, stale_worktree_branch_count}:
      git reset --hard HEAD~1   # only the fix commit
      # Conforming carry-forward line (Entry Schema, sprint-contracts.md). The
      # human-review intent maps to blocker/notes — NOT a bare token (a non-schema
      # line breaks the Reader's group_by(.id)).
      append to .cc-sessions/carry-forward.jsonl:
        {"id":"cf-<date>-ratchet-<metric>","ts":"<ISO>","event":"correction","status":"active","blocker":"ratchet:<metric>","notes":"auto-revert <metric> <old>-><new>; needs human review","provenance":{"source":"sprint-review","session":"<id>"}}
      activity-feed: event=auto_revert detail={metric, old, new}
      stop further auto-fixes for this metric this sprint
    elif metric == "test_count":
      # flaky, do not auto-revert; flag for human via a conforming carry-forward line
      append to .cc-sessions/carry-forward.jsonl:
        {"id":"cf-<date>-ratchet-test_count","ts":"<ISO>","event":"correction","status":"active","blocker":"ratchet:test_count","notes":"test_count regression — possible flaky; needs human review","provenance":{"source":"sprint-review","session":"<id>"}}
```

`test_count` regression NEVER triggers auto-revert (could be flaky test removal); it only flags. All other metrics are deterministic.

---

### 6. Sprint-Review Enforcement (Phase 3.6 invariant)

`sprint-review` Phase 3.6 reads `docs/sweeps/ratchet.json`, computes current values, and:

1. Sprint **cannot reach PASS** if any metric violates direction with no carry-forward escalation.
2. Improvements are recorded automatically (tighten thresholds + history snapshot).
3. Regressions surfaced as Phase 3.6 BLOCKERs unless covered by an explicit carry-forward entry with `rollover_count <= 2`.

This integrates with the existing carry-forward registry (see [sprint-contracts.md](./sprint-contracts.md)).

---

### 7. Bootstrap (greenfield / first sprint)

Run once at project setup:

```bash
mkdir -p docs/sweeps
cat > docs/sweeps/ratchet.json <<'JSON'
{
  "$schema": "blitz-ratchet/1.0",
  "sprint": "sprint-0",
  "updated_at": "<TS>",
  "metrics": {
    "test_count":         {"baseline": 0, "current": 0, "min_allowed": 0, "direction": "up"},
    "type_errors":        {"baseline": 0, "current": 0, "max_allowed": 0, "direction": "down", "absolute_floor": 0},
    "as_any_count":       {"baseline": 0, "current": 0, "max_allowed": 0, "direction": "down"},
    "lint_violations":    {"baseline": 0, "current": 0, "max_allowed": 0, "direction": "down"},
    "completeness_score": {"baseline": 0, "current": 0, "min_allowed": 0, "direction": "up"},
    "mocks_in_src":       {"baseline": 0, "current": 0, "max_allowed": 0, "direction": "down"},
    "todo_count":         {"baseline": 0, "current": 0, "max_allowed": 0, "direction": "down"},
    "stale_worktree_branch_count": {"baseline": 0, "current": 0, "max_allowed": 0, "direction": "down"}
  },
  "auto_revert": {"enabled": true, "needs_human_label": "ratchet-regression"},
  "history": []
}
JSON
```

First real `sprint-review` run will compute baselines from the codebase and tighten thresholds.

---

### 8. Disable / Override

`auto_revert.enabled: false` disables auto-revert (advisory mode). Set this for projects with very high test flakiness while flakiness is being addressed.

There is no override for the absolute floor on `type_errors`. Type-clean is non-negotiable.

---

### Related

- [`agent-orchestration.md`](./agent-orchestration.md) §8 — output contract integrates with ratchet metric reporting via `metrics:` field
- [`sprint-contracts.md`](./sprint-contracts.md) — ratchet violations create carry-forward entries
- `skills/sprint-review/SKILL.md` Phase 3.6 — runtime enforcement
- `skills/code-sweep/SKILL.md` — surfaces ratchet-tightening opportunities
- `docs/_research/2026-05-01_autonomous-blitz-quality-efficiency.md` — research basis



---

<!-- ===== Absorbed from deterministic-test-recipe.md ===== -->

## Deterministic Test Recipe — patterns for async / timing / mock-heavy specs

Reference protocol. Documents patterns that reduce test flakiness when generating or fixing tests for code involving async operations, timers, randomness, shared state, or external services. Consulted by `agents/test-writer.md` and `skills/test-gen/SKILL.md` when the target code has signals of this class. **Not auto-enforced** — the agent decides when to apply.

**Sourced from**:
- [Claude Code best practices — Anthropic](https://code.claude.com/docs/en/best-practices) — verification-first principle
- [trunk.io — How to avoid flaky tests in vitest](https://trunk.io/blog/how-to-avoid-and-detect-flaky-tests-in-vitest)
- [fast-check.dev — Beyond flaky tests: controlled randomness](https://fast-check.dev/blog/2025/03/28/beyond-flaky-tests-bringing-controlled-randomness-to-vitest/)
- [Vitest fake timers docs](https://vitest.dev/api/vi.html#vi-usefaketimers)
- `docs/_research/2026-05-16_agent-success-recipes-spec-fixing.md` F3 (failure modes and footgun warnings)

---

### When to consult this recipe

Signals in the target code that flag a deterministic-test recipe is warranted:

| Signal | Threshold | Why it matters |
|---|---|---|
| `setTimeout` / `setInterval` / `requestAnimationFrame` | any | Timing is non-deterministic without fake timers |
| `Math.random` / `crypto.randomUUID` / `Date.now` / `performance.now` | any in production code | Stochastic outputs vary between runs |
| `fetch` / `axios` / API client | any | Network latency is non-deterministic |
| `await` chains with ≥3 promises | structural | Promise scheduling order can vary |
| Singletons / module-scope state | any | Test ordering can leak state |
| `vi.mock` / `jest.mock` chains | ≥5 in one file | Mock isolation hazards compound |

When any of these are present, prefer the recipe sections below over a default test setup.

---

### Vitest recipe

#### Fake timers — async-safe

```ts
import { vi } from 'vitest'

beforeEach(() => {
  vi.useFakeTimers()
})

afterEach(() => {
  vi.useRealTimers()
})

it('resolves after delay', async () => {
  const promise = something()
  // CRITICAL: async variant — sync advanceTimersByTime deadlocks on
  // promise + timer chains
  await vi.advanceTimersByTimeAsync(1000)
  await expect(promise).resolves.toBe('done')
})
```

**Footgun**: `vi.advanceTimersByTime(N)` (no `Async`) deadlocks when the test code has `await` between the timer and the assertion. Use `advanceTimersByTimeAsync` when ANY async is in the chain. Symptom: test hangs until Vitest timeout.

#### Seeded randomness

```ts
// vitest.config.ts
export default defineConfig({
  test: {
    sequence: { seed: 12345 },        // deterministic file/test order
    env: { TEST_SEED: '12345' },      // pass to seeded RNG in test helpers
  },
})

// In test file
import { fc, test } from '@fast-check/vitest'

test.prop([fc.integer()])('handles any integer', (n) => {
  expect(process(n)).not.toThrow()
})
// Every failure includes the seed for reproduction
```

#### `isolate: false` (faster but risky)

```ts
// vitest.config.ts
export default defineConfig({
  test: {
    isolate: false,   // skip per-test isolation; faster, but...
  },
})
```

**Footgun**: shared module state leaks between tests. Use only when state is proven shared-immutable (e.g., pure-function modules). For tests with mocks or singletons, leave `isolate: true` (default).

#### MSW (Mock Service Worker)

Prefer MSW handlers over `vi.mock()` for HTTP calls:

```ts
import { setupServer } from 'msw/node'
import { http, HttpResponse } from 'msw'

const server = setupServer(
  http.get('/api/users/:id', ({ params }) =>
    HttpResponse.json({ id: params.id, name: 'Test User' })
  ),
)

beforeAll(() => server.listen())
afterEach(() => server.resetHandlers())
afterAll(() => server.close())
```

Why prefer over `vi.mock('axios')`: MSW handles the wire format, so test code uses the real HTTP client. Mocking the client hides serialization bugs.

---

### Jest recipe

#### Fake timers — `modern` and await

```ts
beforeEach(() => {
  jest.useFakeTimers()     // 'modern' is default in Jest 27+
})

afterEach(() => {
  jest.useRealTimers()
})

it('resolves after delay', async () => {
  const promise = something()
  jest.advanceTimersByTime(1000)   // sync — fine here
  await Promise.resolve()           // flush microtasks
  await expect(promise).resolves.toBe('done')
})
```

**Footgun**: unlike Vitest, Jest has no `advanceTimersByTimeAsync` variant. Manually flush microtasks via `await Promise.resolve()` or `await new Promise(setImmediate)` after the sync advance.

#### Serial run

```bash
npx jest --runInBand            # single process, no worker non-determinism
npx jest --seed=12345           # deterministic test order (Jest 30+)
```

`--runInBand` is the most reliable lever when a flaky test reproduces only under parallel workers. Pays a wall-clock cost.

---

### Property-based testing (cross-runner)

`@fast-check/vitest` or `fast-check` with Jest:

```ts
import { fc } from 'fast-check'

it('reverse is involutive', () => {
  fc.assert(
    fc.property(fc.array(fc.string()), (xs) => {
      expect(reverse(reverse(xs))).toEqual(xs)
    }),
    { seed: 42, numRuns: 100 },
  )
})
```

Every failure is reproducible from `seed`. Shipped pattern from `fast-check.dev`.

---

### What this recipe does NOT cover

- **Multi-process orchestration** (Worker, child_process, browser-Node IPC) — fake timers don't span processes. Use real timers + generous `vi.setConfig({ testTimeout: N })`.
- **File-system race conditions** — tests that race on `fs.writeFile` / `fs.readFile`. Use `mock-fs` or scoped temp directories.
- **`Date.now` shifts mid-test** — `vi.setSystemTime(new Date('2026-01-01'))` works, but advances don't update unless you call it again.
- **Snapshot fragility for time-stamped output** — wrap in `expect(output.replace(/\d{4}-\d{2}-\d{2}/, 'DATE')).toMatchSnapshot()`.
- **`Promise.all` ordering** — fake timers don't guarantee scheduling order between promises; treat as a documented test-design limitation.

---

### Counter-evidence and caveats (must read before adopting)

Per `docs/_research/2026-05-16_agent-success-recipes-spec-fixing.md` F3 + F6:

1. **Fake timers deadlock on async chains** (Vitest sync variant) — fix is the `Async` variant; tutorials often skip this.
2. **Determinism via low temperature is not absolute** — empirical study (arxiv 2509.19185, 39 frameworks, 439 apps) found non-determinism persists even with fixed low temperature and Top-P. This recipe addresses runtime determinism; LLM-generation determinism is a separate concern.
3. **`isolate: false` leaks shared state** — only use when state is proven immutable.
4. **Property-based testing surfaces real bugs but inflates test runtime** — set `numRuns` modestly (50–200) unless investigating a specific class of inputs.
5. **MSW requires setup-file plumbing** — for one-off tests, a single `vi.mock` may be cheaper. Adopt MSW project-wide or skip.
6. **Spec-as-test trap** — 1-in-10 spurious passes where the output is right but the test assertion is wrong (per Monte Carlo Data, AI Agent Evaluation). Deterministic runners don't help here; the assertion has to be right.

---

### Related

- [agent-orchestration.md](agent-orchestration.md) — Self-Falsification rule (artifact-construction discipline; complementary to verification-first principle here)
- [knowledge-protocol.md](knowledge-protocol.md) — capture "this async pattern stalled before" lessons here for future test-writer dispatches
- [terse-output.md](terse-output.md) — output style for test code itself (preserve verbatim per the boundary list)

---

### Status

**Author-time reference.** No agent is auto-required to consult this. The expected pattern: when `agents/test-writer.md` or `skills/test-gen/SKILL.md` detects the signals listed above in the target code, the agent reads this file and applies the patterns that fit. If the agent skips this consultation and the test ends up flaky, the issue surfaces via the normal sprint-review path — at which point an entry can be added to `.cc-sessions/KNOWLEDGE.md` flagging the missed-signal pattern for future runs.

Behavioral enforcement (mandatory consultation, classifier-driven routing, etc.) is deferred per the v1.13 evaluation — Option A in `docs/_research/2026-05-16_agent-success-recipes-spec-fixing.md` summary.
