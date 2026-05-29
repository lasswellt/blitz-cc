# v1.16.0 Cohesion Validation — FINAL VERDICT

Synthesized from 49 unit validations (39 skills × V1–V9, 10 agents × A1–A6) plus the cohesion
matrix (`docs/validation/v1.16.0/cohesion-matrix.md`). All defect claims below were
**independently re-derived from source** on 2026-05-28 (branch `main`, HEAD `4d70a53`) — not
trusted from unit summaries. Counts re-tallied directly from the 49 unit JSON blobs.

**Overall verdict: CONDITIONALLY COHESIVE.** The ownership model, spawn-protocol set, and
DW dual-path design are sound. Failures are sync-discipline lapses (restated mirror copies),
read-only hardening gaps the prior S14-009 audit missed, and two latent one-line defects
(research Workflow args, orchestrator `.sprint` injection cap). All 29 failing cells are
one-line fixes. Zero UNVERIFIED.

---

## 1. Pass Rate per Rubric Check (all 49 units)

Total rubric cells = 351 skill (39×9) + 60 agent (10×6) = **411**.
Tally: **PASS=222, FAIL=29, N/A=160, UNVERIFIED=0.**
Applicable (PASS+FAIL, excludes N/A) = 251 → **PASS rate = 222/251 = 88.4%**.

> **UNVERIFIED = 0.** Every check across all 49 units carries a re-runnable command or
> file:line citation. No check was scored PASS without evidence. This is called out
> explicitly per the assert-and-prove contract — there are no silent passes.

### Skill checks (V1–V9, 39 skills each)

| Check | Meaning | PASS | FAIL | N/A | UNVERIFIED |
|-------|---------|------|------|-----|------------|
| V1 | frontmatter validator + required fields | 39 | 0 | 0 | 0 |
| V2 | OUTPUT STYLE snippet byte-identical | 39 | 0 | 0 | 0 |
| V3 | markdown links resolve | 39 | 0 | 0 | 0 |
| V4 | owner round-trip (cite, no restate) | 14 | **4** | 21 | 0 |
| V5 | pipeline I/O handoff contract | 26 | **2** | 11 | 0 |
| V6 | DW dispatch wiring (codebase-audit/research only) | 1 | **1** | 37 | 0 |
| V7 | read-only enforcement (disallowed-tools) | 4 | **9** | 26 | 0 |
| V8 | body ≤450 target / ≤500 hard cap | 35 | **4** | 0 | 0 |
| V9 | spawn idiom canonical (Agent, not TeamCreate/SendMessage) | 10 | **2** | 27 | 0 |

### Agent checks (A1–A6, 10 agents each)

| Check | Meaning | PASS | FAIL | N/A | UNVERIFIED |
|-------|---------|------|------|-----|------------|
| A1 | frontmatter + reply-contract | 8 | **2** | 0 | 0 |
| A2 | read-only enforcement (tool allowlist) | 4 | **2** | 4 | 0 |
| A3 | orchestrator injection guard | 0 | **1** | 9 | 0 |
| A4 | orchestrator routing completeness | 1 | 0 | 9 | 0 |
| A5 | critic detector re-justification | 1 | 0 | 9 | 0 |
| A6 | DW critic-prompt parity | 1 | **2** | 7 | 0 |

### V8 note (body-cap)
V8 FAILs (migrate 461, refactor 416, retrospective 472, roadmap 480) are **soft-target (450)
breaches only — all ≤500 hard cap**. Not contract violations; flagged as tightening watch items,
not blocking defects. sprint-dev (447), next (451), codebase-audit (466), research (473),
test-gen (420) are at/near the line but scored PASS by their units (within hard cap).

---

## 2. Confirmed-Defect List

Each re-verified by direct read/command. Blast radius + one-line fix.

### D1 — O1/O5 changelog map restated in 2 places (doc-gen V4, ship V4) — **FAIL ×2**
- **Where:** `skills/doc-gen/references/main.md:323` restates the full 13-row commit-type→section
  table; `skills/ship/SKILL.md:163-168` restates strip/capitalize/hash/remove-empty rules
  *immediately after* its own delegation sentence at `:159`. Owner: `skills/release/SKILL.md:119`.
- **Blast radius:** Runtime changelog drift. doc-gen mirror diverges (`docs:`→Other vs canon
  Documentation; `style:`/`test:`→Other vs canon EXCLUDED) — generated changelogs misclassify
  three commit types whenever doc-gen or ship runs instead of release.
- **Fix:** Replace `doc-gen/references/main.md:323` table and `ship/SKILL.md:163-168` bullets each
  with a single delegation cite to `skills/release/SKILL.md §Phase 2` (O1/O5 owner).

### D2 — O2 anti-mock pattern set forked in 2 places (code-sweep V4, sprint-review V4) — **FAIL ×2**
- **Where:** `skills/code-sweep/references/main.md:95` forks `todo-fixme` to
  `(TODO|FIXME|HACK|XXX|TEMP|WORKAROUND)` (TEMP/WORKAROUND added, PLACEHOLDER/STUB dropped) vs
  canon `//\s*(TODO|FIXME|PLACEHOLDER|STUB|HACK|XXX)`. `skills/sprint-review/SKILL.md:131-133`
  inlines a 7-term regex vs the 13 named canonical patterns. Owner: `completeness-gate/SKILL.md:115`
  + `completeness-gate/references/main.md:7`.
- **Blast radius:** Agents executing code-sweep tier scans and sprint-review §1.5.1 run forked
  patterns at runtime — placeholder/stub leftovers escape detection; the SKILL.md citation is
  decorative because `references/main.md` defines the operative pattern.
- **Fix:** Replace both forked pattern rows with a cross-ref directive to
  `completeness-gate/references/main.md §Grep Patterns` as single source of truth.

### D3 — research DW Workflow args mis-declared (research V6) — **FAIL** ✔ re-verified
- **Where:** `skills/research/SKILL.md` JS block: comment declares
  `args: { roster, gapSchema, gapQuestions }` but body dereferences `args.gapPrompt` and
  `args.findingsSchema` (both **undeclared**); `gapQuestions` is **never used**. Confirmed by read
  (`agent(args.gapPrompt, …)` + `schema: args.findingsSchema` present; comment omits both).
- **Blast radius:** **Workflow path only** (Agent() fallback unaffected). A developer assembling the
  Workflow args object from the comment omits `gapPrompt`/`findingsSchema` → runtime `undefined`
  deref. Latent: the DW path is opt-in, so this does not fire today, but blocks DW migration.
- **Fix:** Change comment to `args: { roster:[{name,prompt}], gapPrompt, gapSchema, findingsSchema }`.

### D4 — sprint-dev TeamCreate spawn-idiom drift (sprint-dev V9) — **FAIL** ✔ re-verified
- **Where:** `skills/sprint-dev/SKILL.md:4` declares `TeamCreate` + `SendMessage`; `:190` "Use
  TeamCreate to create a team". spawn-protocol.md:79 (foot-gun 5) deprecates TeamCreate with **no
  exception** for sprint-dev; Phase 2.3 already groups via `Agent(team_name:…)`.
- **Blast radius:** Redundant pre-v1.4.0 residual. TeamCreate does not accept `subagent_type`;
  team grouping already works via `Agent(team_name)`. SendMessage for UNBLOCK/HALT IS acceptable
  (spawn-protocol §3/§4). Low functional risk (Agent path already correct) but is a protocol-lag.
- **Fix:** Remove `TeamCreate` from allowed-tools `:4`; rewrite `:190` to note grouping via
  `Agent(team_name)` at Phase 2.3. Keep `SendMessage`.

### D5 — fix-issue SendMessage drift + missing Agent (fix-issue V9) — **FAIL** ✔ re-verified
- **Where:** `skills/fix-issue/SKILL.md:4` declares `SendMessage` (0 body uses); `:148` says "spawn
  a research subagent with subagent_type: general-purpose" which **requires Agent** (SendMessage
  rejects subagent_type); `Agent` absent from allowed-tools.
- **Blast radius:** The research-subagent spawn at `:148` cannot execute as written — SendMessage
  has no subagent_type. Functional gap on the research path of fix-issue.
- **Fix:** Replace `SendMessage` with `Agent` in allowed-tools `:4`.

### D6 — disallowed-tools under-adoption: 3 read-only-by-construction skills (V7) — **FAIL ×3**
- **Where:** `completeness-gate`, `setup`, `worktree-prune` all have
  `allowed-tools: Read, Bash, Glob, Grep` (✔ verified by grep) and assert read-only in prose, but
  **none declare `disallowed-tools`**. Only `health/SKILL.md:6` truly enforces. (`ui-audit:11` and
  `dep-health:11` carry `<!-- no-disallowed-tools -->` *exclusion* comments — they write artifacts,
  correctly excluded.)
- **Blast radius:** Prose-only read-only guarantee is not platform-enforced; a future edit adding a
  Write call would not be blocked. S14-009 audit concluded "only health qualified" but **missed
  these 3 identical candidates**.
- **Fix:** Add `disallowed-tools: Edit, Write, NotebookEdit` to each of the 3 frontmatters.
  (V7 also flags code-doctor, codebase-map, conform, design-extract, integration-check,
  perf-profile — those are *conditional/partial*: they legitimately Write artifacts or have
  scan/fix modes; not clean read-only-by-construction. The 3 above are the unambiguous gaps.)

### D7 — orchestrator `.sprint` injection cap missing (orchestrator A3) — **FAIL** ✔ re-verified
- **Where:** `agents/orchestrator.md:147` HANDOFF render: `.message`[0:200]✔, `.phase`
  `|tostring|.[0:200]`✔, but `.sprint` rendered raw as `\(.sprint // "none")` — **uncapped**.
- **Blast radius:** Single uncapped semi-trusted HANDOFF free-text field defeats the injection-
  surface guard (the v1.16.0 Opus 4.8 ASR-regression mitigation). One uncapped field = guard breach.
- **Fix:** `\(.sprint // "none")` → `\((.sprint // "none")|tostring|.[0:200])`.

### D8 — agent read-only/reply-contract gaps (architect A2, reviewer A2, backend-dev A1, design-critic A1+A6, research-critic A6) — **FAIL ×6**
- **architect A2:** `agents/architect.md:148` instructs writing
  `${SESSION_TMP_DIR}/architect-findings.md` while claiming read-only (`:155`); contradicts
  spawn-protocol.md:54/76 (orchestrator must extract from text return). Fix: delete `:148`.
- **reviewer A2:** `agents/reviewer.md:13` holds `Write` with prose-only source exclusion; plugin
  agents cannot use disallowed-tools → fix is prose note + caller-side path validation.
- **backend-dev A1 / design-critic A1+A6 / research-critic A6:** reply-contract / OUTPUT-STYLE
  injection lives at the *spawn site*, not the agent body. backend-dev's DONE:/BLOCKED: prefix
  protocol needs a documented exception in token-budget.md §3; research-critic's spawn prompt
  (`skills/research/SKILL.md:416-418`) and design-critic's ui-build spawn
  (`skills/ui-build/SKILL.md:326`) omit the mandatory verbatim OUTPUT STYLE / "Return ONLY this
  JSON" boilerplate. **Blast radius:** prompt-assembly, not runtime defect today; carry-forward.

### D9 — bootstrap + migrate pipeline-contract gaps (bootstrap V5, migrate V5) — **FAIL ×2**
- **bootstrap V5:** Phase 5 neither creates roadmap/epic-registry stubs nor prints the fallback
  message required by `state-handoff.md:35` → sprint-plan Phase 0 can hard-fail silently on
  greenfield. **migrate V5:** body writes only `${SESSION_TMP_DIR}` artifacts, never the
  `docs/migrations/<from>-<to>/{plan,STATE,report}.md` + `--resume` contract declared in
  `state-handoff.md §migrate` → canonical I/O contract is a dead letter for consumers.

### D10 — validate-plugin-structure.sh: 3 FALSE POSITIVES (Table 5) — **confirmed**
- **Re-run output:** `FAIL: 3 errors, 0 warnings (out of 282 checks)` with **EXIT=0** (✔ verified —
  exit code does not propagate error count). All 3 are false positives:
  1–2. `skill-/agent-frontmatter-validate.sh --all missing` — scripts exist & are `-rwxr-xr-x`;
  validator concatenates the `--all` arg into the path and stats a nonexistent file.
  3. `_lib/common.sh is not executable` — it is `-rw-r--r--` and **sourced**, never executed;
  non-exec is correct.
- **Hypothesized 4th FP (code-doctor description) does NOT fire** — validator emits exactly 3.
- **markdown-link-validate full-suite** ran `OK (397 link(s) checked)`, EXIT=0, <30s — documented
  timeout NOT reproduced.
- **Blast radius:** `validate-plugin-structure.sh` cannot be trusted at face value; CI/agents must
  rely on the dedicated `skill-frontmatter-validate.sh` + `markdown-link-validate.sh` (both clean).
- **Fix:** Patch the validator's argument parsing (split `--all` off the path before `[ -f ]`) and
  exempt sourced `_lib/*.sh` from the exec check.

---

## 3. Did the v1.16.0 Improvements Land?

| Claimed change | Status | Evidence |
|----------------|--------|----------|
| **DW adoption** (workflow-dispatch.md, codebase-audit + research pilots) | **PARTIAL** | codebase-audit dual-path EQUIVALENT (V6 PASS — same roster, `args.findingsSchema`, Phase 2 collection path-agnostic, `SKILL.md:106-127`). research dispatch gate + fallback land, but Workflow `args` interface mis-declared (D3, research V6 FAIL) — Workflow path latently broken. |
| **O1–O5 ownership model** | **PARTIAL** | Model is sound and bidirectional where clean: O3 BIDIRECTIONAL (integration-check:29 ↔ completeness-gate:200-223). But O1/O5 restated ×2 (D1) and O2 forked ×2 (D2) in mirror/reference copies; O4 ask mirror stale (8 routes, 0 hits). 4 of 7 owner edges carry a restate/drift defect — sync discipline lapsed, ownership intent intact. |
| **Injection guards** (orchestrator HANDOFF/feed truncation, Opus 4.8 ASR mitigation) | **PARTIAL** | `.message` and `.phase` capped at `[0:200]` (orchestrator.md:144,147 ✔), but `.sprint` left uncapped (D7, A3 FAIL) — one field defeats the guard. Landed for 2 of 3 free-text fields. |
| **Model-string update** (token-budget §1 routing → haiku for mechanical workers) | **PARTIAL** | `agents/doc-writer.md:19 model: haiku` matches token-budget.md §1 ✔, but `spawn-protocol.md:49` still lists doc-writer's default as **sonnet** (stale reference table — doc-writer A1 advisory). The live agent declaration is correct; the cross-ref doc lags. |
| **disallowed-tools hardening** (read-only enforcement) | **PARTIAL** | `health/SKILL.md:6` enforces ✔. But 3 identical read-only-by-construction skills (completeness-gate, setup, worktree-prune) ship prose-only, no declaration (D6). S14-009 audit's "only health qualified" missed them. Landed for 1 of 4 clean candidates. |

No change REGRESSED. All five landed at least partially; none fully clean. Net: the v1.16.0
architecture is in place; the gaps are completion/sync defects, not design reversals.

---

## 4. Remediation — Blitz Carry-Forward Entries (sequenced)

Sequenced for `/blitz:roadmap extend` → `/blitz:sprint-plan`. Each entry carries a **grep-based
acceptance check** so the next sprint self-verifies. Highest leverage first (CF-1 closes 4 breaks).

### CF-1 — Purge restated owner copies (closes D1 + D2; 4 V4 FAILs) — P0
**Action:** Replace 4 restated copies with single delegation cites:
`doc-gen/references/main.md:323` table, `ship/SKILL.md:163-168` bullets,
`code-sweep/references/main.md:95` pattern fork, `sprint-review/SKILL.md:131-133` inline regex.
**Acceptance (grep):**
```bash
# Must return 0 hits each (no restated 13-row table / forked pattern / inline anti-mock regex):
grep -n "WORKAROUND" skills/code-sweep/references/main.md            # expect 0
grep -nE "docs:.*Other|style:.*Other|test:.*Other" skills/doc-gen/references/main.md  # expect 0
grep -nE "strip.*prefix|capitalize|remove.*empty section" skills/ship/SKILL.md | grep -v "release"  # expect 0
grep -cE "throw new Error\('Not impl|return \{\}\)|TODO\|FIXME" skills/sprint-review/SKILL.md  # expect 0 inline regex
# And each consumer must cite its owner:
grep -q "skills/release" skills/doc-gen/references/main.md && grep -q "skills/release" skills/ship/SKILL.md
grep -q "completeness-gate" skills/code-sweep/references/main.md && grep -q "completeness-gate" skills/sprint-review/SKILL.md
```

### CF-2 — Add disallowed-tools to 3 read-only skills (closes D6; 3 V7 FAILs) — P0
**Action:** Add `disallowed-tools: Edit, Write, NotebookEdit` to completeness-gate, setup,
worktree-prune frontmatter.
**Acceptance (grep):**
```bash
for s in completeness-gate setup worktree-prune; do
  grep -q "^disallowed-tools: Edit, Write, NotebookEdit" skills/$s/SKILL.md || echo "MISSING: $s"
done   # expect no output
```

### CF-3 — Fix research Workflow args declaration (closes D3; research V6) — P0
**Action:** Update the JS-block comment in `skills/research/SKILL.md` to
`args: { roster:[{name,prompt}], gapPrompt, gapSchema, findingsSchema }`.
**Acceptance (grep):**
```bash
grep -qE "args:.*gapPrompt.*findingsSchema" skills/research/SKILL.md   # expect hit
grep -q "gapQuestions" skills/research/SKILL.md && echo "STILL HAS gapQuestions"  # expect no output
```

### CF-4 — Cap orchestrator .sprint injection field (closes D7; orchestrator A3) — P0
**Action:** In `agents/orchestrator.md:147`, change `\(.sprint // "none")` →
`\((.sprint // "none")|tostring|.[0:200])`.
**Acceptance (grep):**
```bash
grep -qE '\(\.sprint // "none"\)\|tostring\|\.\[0:200\]' agents/orchestrator.md   # expect hit
grep -nE 'sprint: \\\(\.sprint // "none"\) ' agents/orchestrator.md   # expect 0 (raw uncapped form gone)
```

### CF-5 — Migrate sprint-dev off TeamCreate + fix-issue to Agent (closes D4 + D5; 2 V9 FAILs) — P1
**Action:** Remove `TeamCreate` from `sprint-dev/SKILL.md:4` and rewrite `:190` to group via
`Agent(team_name)`; replace `SendMessage` with `Agent` in `fix-issue/SKILL.md:4`.
**Acceptance (grep):**
```bash
grep -q "TeamCreate" skills/sprint-dev/SKILL.md && echo "sprint-dev STILL HAS TeamCreate"  # expect no output
grep -qE "^allowed-tools:.*\bAgent\b" skills/fix-issue/SKILL.md || echo "fix-issue MISSING Agent"  # expect no output
grep -q "SendMessage" skills/fix-issue/SKILL.md && echo "fix-issue STILL HAS SendMessage"  # expect no output
```

### CF-6 — Fix validate-plugin-structure.sh false positives (closes D10) — P1
**Action:** Patch arg-parsing to split `--all` before the `[ -f ]` path check; exempt sourced
`_lib/*.sh` from the executable check.
**Acceptance (command):**
```bash
bash scripts/validate-plugin-structure.sh 2>&1 | grep -E "^.FAIL.: [0-9]+ errors"
# expect "0 errors" (currently reports 3 false positives)
```

### CF-7 — Pipeline-contract + agent-prompt + body-cap cleanup (closes D8 + D9 + V8/V5) — P2
**Action:** bootstrap Phase 5 roadmap stub/fallback (D9); migrate `docs/migrations/` + `--resume`
contract (D9); architect.md:148 delete write-instruction (D8); add OUTPUT-STYLE/JSON boilerplate to
research-critic + design-critic spawn prompts and document backend-dev DONE: exception (D8); update
stale `spawn-protocol.md:49` doc-writer model to haiku; trim migrate/refactor/retrospective/roadmap
bodies under 450.
**Acceptance (grep/command):**
```bash
grep -qE "roadmap-registry.json|Roadmap not initialized" skills/bootstrap/SKILL.md   # expect hit
grep -qE "docs/migrations/.*plan\.md|--resume" skills/migrate/SKILL.md   # expect hit
grep -q "architect-findings.md" agents/architect.md && echo "architect STILL writes"  # expect no output
grep -nE "doc-writer.*sonnet" skills/_shared/spawn-protocol.md   # expect 0
for s in migrate refactor retrospective roadmap; do
  n=$(awk 'f{c++} /^---$/{f++} f==2{exit} END{print c}' skills/$s/SKILL.md 2>/dev/null);
  [ "$(tail -n +10 skills/$s/SKILL.md | wc -l)" -le 450 ] || echo "$s OVER 450";
done   # expect no OVER output
```
