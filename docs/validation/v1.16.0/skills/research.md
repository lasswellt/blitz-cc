# Skill Validation: research — v1.16.0 Cohesion + DW

**Unit**: research  
**Files**: `skills/research/SKILL.md`, `skills/research/references/main.md`  
**Date**: 2026-05-28  
**Validator**: Claude Sonnet 4.6 (cli-v1valid01)

---

## V1 — Frontmatter Contract

**Verdict**: PASS

**Evidence**: `hooks/scripts/skill-frontmatter-validate.sh skills/research/SKILL.md` → `OK: 1 SKILL.md files conform`

Manual cross-check:
- `name: research` ✓ (SKILL.md line 2)
- `description`: 351 chars, third-person, ≤1024 ✓ (SKILL.md line 3)
- `model: opus` ✓ (line 5)
- `effort: high` ✓ (line 6)
- `compatibility: ">=2.1.71"` ✓ (line 7)
- `allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebSearch, WebFetch, ToolSearch, Agent` ✓ (line 4)

All required fields present and valid.

---

## V2 — OUTPUT STYLE Snippet

**Verdict**: PASS

**Evidence**: Byte-for-byte diff against canonical source (`skills/_shared/terse-output.md` lines 12–12 canonical snippet) → `Match: YES`. Snippet appears at SKILL.md line 26.

---

## V3 — Shared-Protocol Citations Resolve

**Verdict**: PASS

**Evidence**: `hooks/scripts/markdown-link-validate.sh skills/research/SKILL.md` → `OK (397 link(s) checked)`. All `/_shared/X` links resolve to real files under `skills/_shared/`.

---

## V4 — Canonical-Owner Compliance

**Verdict**: PASS

**Evidence**: No O1-O5 owner scheme exists in this codebase (`grep -rn 'O1\|O2\|O3\|O4\|O5' skills/_shared/` → empty). Research is classified as a **super-orchestrator** per `skills/_shared/agent-orchestration.md` line 25. It is a primary pipeline producer (not a delegate): `session-lifecycle.md` lines 38–42 document research as canonical producer of `docs/_research/<date>_<slug>.md` and `scope:` YAML. Consumer (`roadmap extend`) cites research as upstream via `roadmap/SKILL.md` line 3 description + Phase 1.1 glob. Bidirectional: research cites `sprint-contracts.md` (§3.1.1) and `roadmap` references research docs in Phase 0.1. No owned logic is restated — research delegates synthesis to agents, registry protocol to `sprint-contracts.md`.

---

## V5 — Pipeline I/O Composition

**Verdict**: PASS

**Evidence**: Chain: bootstrap (optional) → **research** → roadmap extend → sprint-plan.

Per `skills/_shared/session-lifecycle.md` lines 38–42:
- **research produces**: `docs/_research/YYYY-MM-DD_<slug>.md` + optional `scope:` YAML frontmatter block.
- **roadmap extend consumes**: same files via glob `**/docs/_research/**/*.md` (roadmap/SKILL.md line 71–73).

Research has no required upstream inputs (it is the pipeline head for research-initiated workflows). Its Phase 0 correctly does NOT implement a pipeline input gate (it has no required upstream artifacts). Output path matches exactly what roadmap extend's glob pattern resolves.

---

## V6 — Dynamic-Workflows Wiring

**Verdict**: FAIL (needs-tightening — args comment inconsistency)

### Gate §1.2.6 (dispatch mode selection)
PASS. The bash dispatch gate at SKILL.md lines 121–128 correctly implements the `agent-orchestration.md` spec:
- `agent` → `USE_WORKFLOW=false`
- `workflow` → `USE_WORKFLOW=true` (comment: "force; error if Workflow tool absent" — matches spec §Capability gate §49)
- `auto` → `USE_WORKFLOW=maybe` (truthy; attempt call, fall back on tool-unavailable error per `agent-orchestration.md` line 48)

### Fallback contract
PASS. Prose bullet at line 131: "else, or on ANY Workflow failure → fall back to §1.3 (Agent() path). Never hard-fail." Consistent with `agent-orchestration.md` line 50.

### Activity-feed logging
PASS. Line 132: "Log the chosen path to the activity-feed: `detail.dispatch: 'workflow'|'agent'`." Matches spec.

### Hybrid boundary
PASS. Line 133 explicitly states: "The Workflow script touches NO filesystem: working-dir creation (§1.1), SESSION_TMP_DIR polling, summarization (§2.2), classify (§2.1), synthesis (Phase 3), and activity-feed writes all stay in this skill's main-thread Bash." The §1.3-W JS block (lines 139–151) contains no `Date.now()`, `Math.random()`, `new Date()`, filesystem calls, `.cc-sessions` writes, or Node API calls — only `parallel()`, `agent()`, and `filter(Boolean)` primitives.

### §1.3-W Script body (gap agent inside Workflow)
PASS. The gap detection agent `await agent(args.gapPrompt, {phase:'GapFill', model:'haiku', schema:args.gapSchema})` inside the Workflow script is valid dispatch-only logic per `agent-orchestration.md` §Pattern mapping (line 73): "gap second-wave (research Phase 2.4) → `if (gaps.length) await agent(...)`". The result `.filter()` is computation on returned data — allowed.

### **DEFECT: args comment vs script usage mismatch**
FAIL. The Workflow args comment at line 141 declares:
```
// args: { roster:[{name,prompt}], gapSchema, gapQuestions }
```
But the script body uses:
- `args.gapPrompt` (line 146) — **NOT declared**; comment says `gapQuestions`
- `args.findingsSchema` (lines 144, 149) — **NOT declared** in the args comment

The gap prompt agent is called with `args.gapPrompt` but `args` only declares `gapQuestions`. This is a stale args interface comment: either `gapQuestions` should be `gapPrompt`, or the script should build the prompt from `args.gapQuestions` + construct the prompt inline. `findingsSchema` is also undeclared (codebase-audit has the same gap, but both are defects).

This is a contract-level defect: any consumer assembling the `args` object for the Workflow dispatch will not know to pass `gapPrompt` or `findingsSchema`.

### Model routing in §1.3-W agents
PASS. Line 144: `model: a.name === 'codebase-analyst' ? 'sonnet' : 'haiku'` — correct per 60/35/5 matrix. Gap agents: `model: 'haiku'` (line 146, 149) — correct.

### OUTPUT STYLE in §1.3-W agent() prompts
PASS. Line 155: "Each prompt MUST embed the OUTPUT STYLE snippet (Invariant 5) + write-as-you-go rule." The prompts are assembled on the main thread (passed via `args.roster[i].prompt`), so Invariant 5 enforcement is delegated to main-thread prompt assembly — acceptable pattern.

---

## V7 — Disallowed-Tools Gap

**Verdict**: N/A

**Evidence**: Research is a read-write skill by construction — it spawns agents that write findings files (`general-purpose` agents with Write), synthesizes research docs to `docs/_research/`, and creates working directories. `allowed-tools` correctly includes `Write, Edit`. The disallowed-tools hardening pattern (as in `health/SKILL.md` which declares `disallowed-tools: Edit, Write, NotebookEdit`) does not apply to write-required orchestrators. No gap.

---

## V8 — Body-Line Budget

**Verdict**: PASS (target: ≤450, hard: ≤500)

**Evidence**: `awk '/^---$/{count++; if(count==2) start=1; next} start{lines++} END{print lines}' skills/research/SKILL.md` → **473 lines**. Below the 500 hard cap. Above the 450 target — watch-listed but not a FAIL. The unit note predicted ~483; actual is 473 (7 lines under the note's estimate, still in amber zone).

---

## V9 — Spawn-Idiom Consistency

**Verdict**: PASS

**Evidence**: `allowed-tools` at SKILL.md line 4: `Read, Write, Edit, Bash, Glob, Grep, WebSearch, WebFetch, ToolSearch, Agent`. Neither `TeamCreate` nor `SendMessage` is present. Skill uses the canonical `Agent` tool for spawning (`general-purpose` subagent_type per §1.3 line 163). No TeamCreate/SendMessage drift from `agent-orchestration.md` §1 footnote 5 ("v1.4.0 migrated all spawning skills to Agent tool"). Consistent.

---

## Skill Verdict

**`dw-wiring-defect`**

The skill is structurally cohesive and passes 8 of 9 checks. The single FAIL is in V6: the `§1.3-W` Workflow script's args comment declares `{roster, gapSchema, gapQuestions}` but the script body references `args.gapPrompt` (undeclared — should be `gapPrompt`, not `gapQuestions`) and `args.findingsSchema` (also undeclared). Any developer assembling the args object for the Workflow call will not know to include these two fields, causing a runtime `undefined` dereference. This is a wiring-contract defect, not just a doc smell.

---

## Highest-Leverage Fix

**Fix the Workflow args comment at SKILL.md line 141** to declare all consumed arg fields:

```js
// args: { roster:[{name,prompt}], gapPrompt, gapSchema, findingsSchema } — prompts embed OUTPUT STYLE + write-as-you-go
```

Change `gapQuestions` → `gapPrompt` (matches script usage) and add `findingsSchema` (used on lines 144 and 149). One-line fix; removes the only failing check and closes the contract gap before runtime discovers it.
