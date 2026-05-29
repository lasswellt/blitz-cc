# fix-issue — v1.16.0 Cohesion+DW Validation

**Date**: 2026-05-28
**Validator**: claude-sonnet-4-6 (agent)
**Files audited**:
- `skills/fix-issue/SKILL.md`
- `skills/fix-issue/references/main.md`

---

## V1 — Frontmatter Contract

**Verdict**: PASS

**Evidence**: `hooks/scripts/skill-frontmatter-validate.sh skills/fix-issue/SKILL.md` → `[skill-frontmatter-validate.sh] OK: 1 SKILL.md files conform`

Manual field audit:
- `name: fix-issue` — lowercase+hyphens, ≤64 chars, no reserved words ✓
- `description` — 364 chars (≤1024), third-person ("Resolves GitHub issues…") ✓
- `model: opus` — valid ✓
- `effort: medium` — valid ✓
- `compatibility: ">=2.1.71"` — valid >=X.Y.Z format ✓
- `allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebSearch, WebFetch, ToolSearch, SendMessage` — present, not empty ✓
- `argument-hint: "<issue-number>"` — present (body references `$ARGUMENTS`) ✓

---

## V2 — OUTPUT STYLE Snippet

**Verdict**: PASS

**Evidence**: Byte-identical match confirmed — `grep -A0 'OUTPUT STYLE:' skills/_shared/terse-output.md` vs `grep -A0 'OUTPUT STYLE:' skills/fix-issue/SKILL.md` → strings equal (MATCH). Validator hash check also passes (validator exit 0). Snippet appears at SKILL.md line 21, inside the body block.

---

## V3 — Shared-Protocol Citations Resolve

**Verdict**: PASS

**Evidence**: `hooks/scripts/markdown-link-validate.sh skills/fix-issue/SKILL.md` → `markdown-link-validate: OK (397 link(s) checked)`

Links in body verified by script:
- `/_shared/session-protocol.md` → `skills/_shared/session-protocol.md` ✓
- `/_shared/verbose-progress.md` → `skills/_shared/verbose-progress.md` ✓
- `/_shared/spawn-protocol.md` → `skills/_shared/spawn-protocol.md` ✓
- `/_shared/terse-output.md` → `skills/_shared/terse-output.md` ✓
- `/_shared/definition-of-done.md` → `skills/_shared/definition-of-done.md` ✓

---

## V4 — Canonical-Owner Compliance

**Verdict**: N/A

fix-issue is a standalone skill, not a delegating skill and not an O1–O5 canonical owner. It delegates one light subagent spawn to `general-purpose` in Phase 1.4 — that is an execution pattern, not an ownership delegation to an O-numbered owner. No bidirectional owner check required.

---

## V5 — Pipeline I/O Composition

**Verdict**: PASS

**Evidence**: `grep -n 'fix-issue' skills/_shared/state-handoff.md` → line 161: `Consumer: operator (reviews report), sprint-plan (if migration is tracked as a story), fix-issue (if a step fails and needs targeted repair)`. fix-issue is downstream of no mandatory producer — it is explicitly documented as standalone. It consumes a GitHub issue number (user-supplied argument), not a pipeline artifact. `state-handoff.md` anti-pattern table at lines 167-171 confirms standalone skills may accept user-supplied inputs. No upstream artifact contract to verify.

---

## V6 — Dynamic-Workflows Wiring

**Verdict**: N/A

fix-issue is not `codebase-audit` or `research`. Dynamic-Workflows dispatch is a pilot limited to those two skills per `skills/_shared/workflow-dispatch.md`. No DW wiring required or expected.

---

## V7 — Disallowed-Tools Gap

**Verdict**: N/A

fix-issue is not read-only-by-construction. It actively edits project files (Edit, Write tools) as part of its core fix implementation. The hardening requirement (`disallowed-tools: [Edit, Write, NotebookEdit]`) applies only to skills that declare themselves read-only. No gap here.

---

## V8 — Body-Line Budget

**Verdict**: PASS

**Evidence**: Exact replication of validator logic — `awk '/^---$/{c++; next} c>=2{print}' skills/fix-issue/SKILL.md | wc -l` → **365 lines**. Hard cap is 500; target is 450. At 365 the skill is within target.

---

## V9 — Spawn-Idiom Consistency

**Verdict**: FAIL (needs-hardening)

**Evidence**:

1. `grep 'allowed-tools' skills/fix-issue/SKILL.md` → `allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebSearch, WebFetch, ToolSearch, SendMessage` — SendMessage present, `Agent` absent.

2. `grep -c 'SendMessage' skills/fix-issue/SKILL.md` → **1** (only the frontmatter declaration; zero body usages).

3. `skills/_shared/spawn-protocol.md` line 79: `TeamCreate+SendMessage does not accept subagent_type — the SDK picks by heuristic. Use the Agent tool instead (v1.4.0 migrated all spawning skills to this).`

4. fix-issue body (line 148) says: `spawn a research subagent with subagent_type: general-purpose` — specifying `subagent_type` requires the `Agent` tool, not SendMessage. But `Agent` is not in allowed-tools.

5. No documented exception in `spawn-protocol.md` for fix-issue to use SendMessage instead of Agent. The three skills using SendMessage (`sprint-dev`, `setup`, `fix-issue`) — sprint-dev and setup coordinate multi-agent teams; fix-issue coordinates no team.

**Root defect**: SendMessage was carried over from an earlier multi-agent design (or from template drift). The canonical single-subagent pattern requires `Agent` in allowed-tools, not SendMessage. SendMessage is for cross-agent coordination (resume, WRAP_UP nudge), not for spawning — and fix-issue spawns exactly one agent with no inter-agent coordination.

---

## Skill Verdict

**needs-hardening**

---

## Highest-Leverage Fix

Replace `SendMessage` with `Agent` in the `allowed-tools` frontmatter (`skills/fix-issue/SKILL.md` line 4). SendMessage has zero body usages and its presence implies a multi-agent coordination pattern that doesn't exist in this skill. `Agent` is the canonical tool for the `spawn a research subagent with subagent_type: general-purpose` instruction at line 148, and it correctly accepts `subagent_type` per spawn-protocol §1.
