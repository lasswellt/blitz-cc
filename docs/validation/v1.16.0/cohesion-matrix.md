# v1.16.0 Cohesion Matrix

Synthesized from 49 unit validations (39 skills + 10 agents). Round-trip citations,
DW dual-path equivalence, spawn-idiom census, and validator output were **re-derived from
source**, not trusted from unit summaries. All file:line refs verified by direct read on
2026-05-28 (branch `main`, HEAD `4d70a53`).

---

## Table 1 — Owner→Consumer Round-Trip (O1–O5)

A consumer that **RESTATES** owned logic instead of citing it counts as a break, even if a
citation sentence is also present.

| Owner | Owner file:line | Consumer | Consumer file:line | Citation? | Restates? | Verdict |
|-------|-----------------|----------|--------------------|-----------|-----------|---------|
| **O1/O5** changelog map | `skills/release/SKILL.md:119` ("SINGLE source… consumers cite it") | doc-gen | `skills/doc-gen/SKILL.md:178` cites O1 | yes | **yes** — `skills/doc-gen/references/main.md:323` restates full 13-row table; drift: `docs:`→Other (canon: Documentation), `style:`/`test:`→Other (canon: EXCLUDED) | **BROKEN** |
| **O1/O5** changelog map | `skills/release/SKILL.md:119` | ship | `skills/ship/SKILL.md:159` ("ship does NOT restate the map") | yes | **yes** — immediately contradicted by `skills/ship/SKILL.md:163-168` restating strip/capitalize/hash/remove-empty rules | **BROKEN** |
| **O2** anti-mock pattern set | `skills/completeness-gate/SKILL.md:115` ("maintained here once") | sprint-review §1.5.1 | `skills/sprint-review/SKILL.md:127` cites O2 | yes | **yes** — inline 7-term regex at `:131-133`; canon has 13 named patterns (`skills/completeness-gate/references/main.md:7`); omits empty-catch, noop, hardcoded-sample, console-log, three-state-ui, unwired-store-actions | **BROKEN** |
| **O2** anti-mock pattern set | `skills/completeness-gate/SKILL.md:115` | code-sweep | `skills/code-sweep/SKILL.md:109` cites O2 | yes | **yes** — `skills/code-sweep/references/main.md:95` forks `todo-fixme` to `(TODO\|FIXME\|HACK\|XXX\|TEMP\|WORKAROUND)`; canon `:15` is `//\s*(TODO\|FIXME\|PLACEHOLDER\|STUB\|HACK\|XXX)` (TEMP/WORKAROUND added, PLACEHOLDER/STUB dropped) | **BROKEN** |
| **O3** wiring topology | `skills/integration-check/SKILL.md:29` ("single owner… completeness-gate delegates") | completeness-gate §2.11 | `skills/completeness-gate/SKILL.md:200-204` ("does NOT re-implement it") | yes | no — pure delegation, no restatement | **BIDIRECTIONAL** |
| **O3** wiring topology | `skills/integration-check/SKILL.md:29` | completeness-gate §2.12-L3 | `skills/completeness-gate/SKILL.md:221-223` ("L3 delegated to integration-check") | yes | no | **BIDIRECTIONAL** |
| **O4** routing matrix | `agents/orchestrator.md:55` §2 (39 skills routed) | ask (mirror) | `skills/ask/SKILL.md:25` cites O4 owner-first; orchestrator back-acks `/blitz:ask` at `:117` | yes (both directions) | mirror is **STALE** — 8 primary routes absent from ask (`code-doctor, code-sweep, ui-audit, compress, conform, worktree-prune, design-extract, implement`; all 0 hits in ask SKILL.md) | **ONE-WAY** (stale mirror; not a restatement break, but drift — 8 valid intents return "no row") |

**Cross-check on O3 caller docs (sprint-review side):** `skills/integration-check/SKILL.md:3`
(description) documents only `/blitz:sprint-dev Phase 3.5.0` as caller. sprint-review *does*
invoke it at `skills/sprint-review/SKILL.md:169` (`/blitz:integration-check all`, Phase 1.6) —
so the runtime wiring exists, but integration-check's description does not name sprint-review
as a caller. The sprint-review unit's V4 FAIL is correct about the §1.5.1 inline O2 restatement
(BROKEN row above); its claim that the O3 bidirectional cite is "broken" is **overstated** —
the invocation is real at Phase 1.6, only the description string is incomplete.

**Summary:** O1/O5 = 2× BROKEN (restatement). O2 = 2× BROKEN (pattern fork). O3 = BIDIRECTIONAL
(clean). O4 = ONE-WAY (stale mirror, 8 missing routes). 4 of 7 owner edges carry a restatement
or drift defect.

---

## Table 2 — DW Dual-Path Equivalence (codebase-audit, research)

Proves the `Workflow` path and the `Agent()` fallback produce **findings-identical** output
(same files, same schema, same downstream consumers). Divergence = correctness break.

| Skill | Dispatch gate | Workflow path roster source | Schema | Findings files | Downstream consumer | Paths equivalent? |
|-------|---------------|-----------------------------|--------|----------------|---------------------|-------------------|
| codebase-audit | `SKILL.md:106-111` (`BLITZ_DISPATCH` auto/agent/workflow + fallback "Never hard-fail") | §1.1-W maps **same** `references/main.md` pillar prompts (`SKILL.md:122` "the pillar template from references/main.md") | `args.findingsSchema` (`SKILL.md:125`) — same gate the `Agent()` path uses (replaces `classify_output()`) | Phase 2 collects the validated return + agents' findings files "exactly as the `Agent()` path does" (`SKILL.md:120,127`) | `roadmap extend` via `docs/audits/*-epics.md` (`SKILL.md:360` ↔ `skills/roadmap/SKILL.md:73-76`) | **YES** — identical roster, identical schema, Phase 2 collection path-agnostic; hybrid boundary keeps all FS I/O in main-thread Bash (`SKILL.md:114`) |
| research | §1.2.6 gate + "runs research-critic as today via Agent()" fallback | §3.2.x roster maps same agent prompts; model routing `codebase-analyst→sonnet`, rest→`haiku` (`SKILL.md:144`) | `args.findingsSchema` | `docs/_research/<date>_<slug>.md` consumed by `roadmap extend` glob (`skills/roadmap/SKILL.md:71`) | roadmap | **AT RISK** — see defect |

**research DW DEFECT (re-verified at `skills/research/SKILL.md:138-152`):** the Workflow `args`
comment at line 140 declares `{ roster, gapSchema, gapQuestions }`, but the body dereferences
`args.gapPrompt` (line 145) and `args.findingsSchema` (lines 142, 147) — **neither declared** —
while `gapQuestions` is declared but **never used**. A developer assembling the Workflow args
object from the comment omits `gapPrompt`/`findingsSchema` → runtime `undefined` deref on the
**Workflow path only**. The `Agent()` fallback is unaffected. This is a latent dual-path
divergence: the two paths are *designed* identical but the Workflow path's interface contract is
mis-documented, so a caller can wire it to fail. One-line fix: change the comment to
`{ roster:[{name,prompt}], gapPrompt, gapSchema, findingsSchema }`.

**Verdict:** codebase-audit dual-path = EQUIVALENT. research dual-path = equivalent *in design*
but **the Workflow args interface is mis-declared** (correctness risk on the Workflow path).

---

## Table 3 — Spawn-Idiom Census

Every unit that spawns, mapped to its idiom, checked against the joint
`spawn-protocol.md` + `workflow-dispatch.md` contract. spawn-protocol.md:79 (foot-gun 5):
"`TeamCreate`+`SendMessage` does not accept `subagent_type`. Use the `Agent` tool instead
(v1.4.0 migrated all spawning skills to this)."

| Unit | Idiom in frontmatter / body | Canonical? | Notes |
|------|-----------------------------|------------|-------|
| codebase-audit | `Agent()` + `Workflow` (opt-in) | YES | DW pilot; `workflow-dispatch.md:80` WIRED |
| research | `Agent()` + `Workflow` (opt-in) | YES | DW pilot; `workflow-dispatch.md` WIRED |
| code-sweep, code-doctor, codebase-map, doc-gen, quality-metrics, roadmap, sprint-plan, sprint-review, ui-build, health, implement | `Agent()` only | YES | canonical per spawn-protocol.md:79 |
| **sprint-dev** | `TeamCreate` (`SKILL.md:190`) + `SendMessage` (`:298`) + `Agent(team_name)` | **DRIFT** | TeamCreate is redundant — Phase 2.3 already groups via `Agent(team_name:…)`; spawn-protocol.md:79 deprecates TeamCreate with **no exception** for sprint-dev. SendMessage for UNBLOCK/HALT coordination IS acceptable (spawn-protocol §3/§4). |
| **fix-issue** | `SendMessage` declared (`SKILL.md:4`) | **DRIFT** | 0 body uses of SendMessage; body `:148` says "spawn subagent with subagent_type: general-purpose" which **requires `Agent`** (SendMessage rejects subagent_type). `Agent` absent from allowed-tools. |
| orchestrator | none (no `Agent`/`TeamCreate`/`SendMessage` in tools) | YES | main-thread router; subagents-cannot-spawn-subagents constraint honored |

**Joint coverage check:** The three idioms (`Agent()`, `Workflow`, `TeamCreate`+`SendMessage`)
are jointly accounted for without contradiction — spawn-protocol.md owns the `Agent()` canonical
pattern and the TeamCreate/SendMessage *prohibition* (§1.3 foot-gun 5, line 79);
workflow-dispatch.md owns the `Workflow` opt-in path (capability-gated + `Agent()` fallback).
**No contradiction between the two protocol docs.** The two legacy idioms (sprint-dev TeamCreate,
fix-issue SendMessage) are **unblessed residual drift** — neither protocol grants an exception, so
both are correctly flagged FAIL by their units (sprint-dev V9, fix-issue V9). The protocols are
internally consistent; the two skills lag the v1.4.0 migration.

---

## Table 4 — disallowed-tools Enforcement Gap

Baseline claim ("dep-health, ui-audit, health declare it") is **corrected**: only `health`
**declares** the field (`skills/health/SKILL.md:6 → disallowed-tools: Edit, Write, NotebookEdit`).
`ui-audit:11` and `dep-health:11` carry an explanatory `<!-- no-disallowed-tools: … -->`
*comment* documenting why they are **excluded** (they write artifacts) — that is the opposite of
declaring enforcement. So real platform-enforced read-only baseline = **health alone**.

A unit is a gap only if it is **read-only-by-construction** (allowed-tools = Read/Bash/Glob/Grep,
no Write/Edit needed). Verified allowed-tools by direct read:

| Unit | allowed-tools (verified) | Asserts read-only? | Enforces? | Gap? | One-line fix |
|------|--------------------------|--------------------|-----------|------|--------------|
| **completeness-gate** | `Read, Bash, Glob, Grep` | yes (`SKILL.md:34`) | no | **YES** | add `disallowed-tools: Edit, Write, NotebookEdit` after allowed-tools |
| **setup** | `Read, Bash, Glob, Grep` | yes (`SKILL.md:30,36`) | no | **YES** | add `disallowed-tools: Edit, Write, NotebookEdit` after `:4` |
| **worktree-prune** | `Read, Bash, Glob, Grep` | yes (`--dry-run` default, prose) | no | **YES** | add `disallowed-tools: Edit, Write, NotebookEdit` after `:5` |
| integration-check | `Read, Write, Bash, Glob, Grep, Agent` | prose `:31` | n/a (Write needed for session logs) | partial | `disallowed-tools: Edit, NotebookEdit` (keep Write) |
| perf-profile | `Read, Write, Edit, Bash, Glob, Grep, ToolSearch` | yes (`:39`) | no | partial | drop unused `Edit`; `disallowed-tools: Edit, NotebookEdit` (keep Write) |
| code-doctor | `Read, Write, Edit, Bash, Glob, Grep, Agent` | scan-mode only | no | conditional | needs scan/fix sub-skill split before enforcing |
| conform | `Read, Write, Edit, Bash, Glob, Grep` | default-mode only | no | conditional | `--fix` needs Write; document opt-in like dep-health |
| design-extract | `Read, Write, Edit, Bash, Glob, Grep` | DoD `:189` | no | partial | drop `Edit`, use `Write` (full overwrite) for DESIGN.md |
| codebase-map | `Read, Write, Bash, Glob, Grep, Agent` | misleading prose `:29` | n/a (Write needed for CODEBASE-MAP.md) | doc-only | reword prose; cannot enforce (Write required) |

**Agent-side (read-only-asserted but Write-capable via Bash):** `agents/architect.md:148` instructs
writing `${SESSION_TMP_DIR}/architect-findings.md` while claiming read-only (`:155`) and holding
`Bash` (`:12`) — contradicts spawn-protocol.md:54/76. `agents/reviewer.md:13` holds `Write` with
prose-only source exclusion (no structural scoping). Plugin agents cannot use `disallowed-tools`;
fix is prose + caller-side path validation.

**True enforceable gaps = 3 skills** (completeness-gate, setup, worktree-prune). The S14-009 audit
(cited in `ui-audit:11`) already adjudicated that integration-check/codebase-audit/design-extract
*write* and are correctly excluded — so the "only health qualified" conclusion is consistent for
the units the audit examined, but it **missed completeness-gate, setup, and worktree-prune**, which
qualify identically to health.

---

## Table 5 — Validator Trust (`scripts/validate-plugin-structure.sh`)

Actual command output (re-run 2026-05-28):

```
FAIL: hooks.json references missing script: ${CLAUDE_PLUGIN_ROOT}/hooks/scripts/skill-frontmatter-validate.sh --all
FAIL: hooks.json references missing script: ${CLAUDE_PLUGIN_ROOT}/hooks/scripts/agent-frontmatter-validate.sh --all
FAIL: hooks/scripts/_lib/common.sh is not executable
FAIL: 3 errors, 0 warnings (out of 282 checks)
```
(script `EXIT=0` despite the "FAIL" summary line — exit code does not propagate the error count.)

| # | Reported error | Real? | Evidence |
|---|----------------|-------|----------|
| 1 | `skill-frontmatter-validate.sh --all` missing | **FALSE POSITIVE** | `ls -la` → `-rwxr-xr-x … skill-frontmatter-validate.sh` exists & executable; validator concatenates the `--all` argument into the path and stats a non-existent file |
| 2 | `agent-frontmatter-validate.sh --all` missing | **FALSE POSITIVE** | `ls -la` → `-rwxr-xr-x … agent-frontmatter-validate.sh` exists & executable; same `--all` arg-misparse |
| 3 | `_lib/common.sh is not executable` | **FALSE POSITIVE** | `-rw-r--r-- … _lib/common.sh`, shebang `#!/usr/bin/env bash`, but it is **sourced** (`grep -rl _lib/common.sh hooks/scripts` → post-edit-typecheck-block.sh, agent-frontmatter-validate.sh, post-edit-test.sh …), never executed; non-exec mode is correct for a sourced lib |
| 4 | code-doctor "missing description" (hypothesized 4th FP) | **DOES NOT FIRE** | validator output: `PASS: skills/code-doctor/SKILL.md has description: field` — the hypothesized 4th false positive is not present in current code; only **3** errors emitted, not 4 |

**markdown-link-validate.sh full-suite:** ran in this environment without timing out —
`timeout 30 bash hooks/scripts/markdown-link-validate.sh` → `OK (397 link(s) checked)`, `EXIT=0`.
The documented full-suite timeout was **not reproduced** here (completed well under 30s).

**Conclusion:** all 3 of the validator's reported errors are false positives (2× `--all`
arg-misparse, 1× sourced-lib non-exec). The 4th hypothesized FP (code-doctor description) does
not fire. `validate-plugin-structure.sh` cannot be trusted at face value for these three checks;
the canonical frontmatter/link gates are `skill-frontmatter-validate.sh` and
`markdown-link-validate.sh`, both of which pass cleanly.

---

## Cohesion Verdict

**Conditionally cohesive — 5 real contract breaks + 3 enforceable hardening gaps, all one-line fixes.**

- **Owner round-trips:** O3 clean; O1/O5 and O2 each carry restatement breaks in `references/main.md`
  (doc-gen table, ship bullets, code-sweep todo-fixme fork, sprint-review §1.5.1 inline regex); O4
  ask mirror is stale (8 missing routes). The breaks are in *mirror/reference* copies, not in the
  owners — the ownership model is sound, the sync discipline lapsed.
- **DW dual-path:** codebase-audit equivalent; research Workflow args interface mis-declared
  (latent Workflow-path-only failure).
- **Spawn idioms:** protocols jointly consistent; sprint-dev (TeamCreate) and fix-issue
  (SendMessage) are residual pre-v1.4.0 drift, correctly flagged, not protocol contradictions.
- **disallowed-tools:** only `health` truly enforces; completeness-gate, setup, worktree-prune are
  identical read-only-by-construction candidates the S14-009 audit missed.
- **Validator:** 3 errors, all confirmed false positives; trust the dedicated frontmatter/link
  validators instead.

**Highest-leverage fix:** purge the restated copies — O1/O5 (`doc-gen/references/main.md:323`
table + `ship/SKILL.md:163-168` bullets) and O2 (`code-sweep/references/main.md:95` pattern fork +
`sprint-review/SKILL.md:131-133` inline regex) — replacing each with a single delegation cite to
its owner. This closes 4 of the 5 contract breaks (the doc-gen, ship, code-sweep, sprint-review V4
FAILs) in one coordinated edit and stops the runtime pattern/changelog drift at its source.
