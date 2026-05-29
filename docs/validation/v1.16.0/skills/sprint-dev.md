# Validation Report — sprint-dev

**Cohort:** v1.16.0 cohesion+DW validation  
**Date:** 2026-05-28  
**Unit:** `skills/sprint-dev/SKILL.md` + `skills/sprint-dev/references/main.md`  
**Validator session:** `val-sprint-dev-e5f6g7h8`

---

## V1 — Frontmatter Contract

**Verdict:** PASS

**Evidence:** `hooks/scripts/skill-frontmatter-validate.sh skills/sprint-dev/SKILL.md` output: `[skill-frontmatter-validate.sh] OK: 1 SKILL.md files conform`. Manual read confirms all required fields:

- `name: sprint-dev` — present (line 2)
- `description:` — present (line 3), third-person, 444 chars (≤ 1024 ✓)
- `model: opus` — present (line 6)
- `effort: high` — present (line 7)
- `compatibility: ">=2.1.71"` — present (line 8)
- `allowed-tools:` — present (line 4); skill is invokable, field required and present ✓

---

## V2 — OUTPUT STYLE Snippet

**Verdict:** PASS

**Evidence:** Verbatim diff against canonical source `skills/_shared/terse-output.md` lines 12-12 (between `<!-- canonical-output-style-start -->` / `<!-- end -->`):

```
CANONICAL == SKILL line 26: exact byte match confirmed by shell comparison (echo "MATCH")
```

The OUTPUT STYLE line at SKILL.md:26 is identical to the canonical snippet. No drift.

---

## V3 — Shared-Protocol Citations Resolve

**Verdict:** PASS

**Evidence:** `hooks/scripts/markdown-link-validate.sh skills/sprint-dev/SKILL.md` output: `markdown-link-validate: OK (397 link(s) checked)`. All `/_shared/X` links in the Additional Resources section (lines 16-24) and in-body citations (`state-handoff.md`, `story-frontmatter.md`, `session-protocol.md`, `checkpoint-protocol.md`, `deviation-protocol.md`, `context-management.md`, `carry-forward-registry.md`, `spawn-protocol.md`, `package-install-policy.md`, `worktree-lifecycle.md`, `knowledge-protocol.md`, `terse-output.md`) resolve. `references/main.md` also exists at `skills/sprint-dev/references/main.md` (786 lines).

---

## V4 — Canonical-Owner Compliance

**Verdict:** PASS

**Evidence:** `sprint-dev` is not a declared O1-O5 canonical owner and does not claim to own any shared protocol. It delegates to owners by citation — e.g., `spawn-protocol.md` for agent spawning, `carry-forward-registry.md` §Writers for registry writes, `worktree-lifecycle.md` for cleanup contract — and does NOT restate the owned logic inline. Phase 4.4 explicitly says "Canonical contract: `/_shared/worktree-lifecycle.md`" and "Full cleanup script in `references/main.md`" rather than duplicating the logic here. Phase 4.7 likewise says "per `session-protocol.md` §File-Based Locking Protocol (the canonical acquire/verify/release sequence lives there — do not restate it)". Consumer-side bidirectional check: `state-handoff.md` §sprint-dev table (lines 63-73) references sprint-dev as the consumer of sprint-plan outputs and producer of `STATE.md` + story status transitions — confirmed present in `_shared/state-handoff.md` lines 63-73.

---

## V5 — Pipeline I/O Composition

**Verdict:** PASS

**Evidence:** Chain: `sprint-plan → sprint-dev → sprint-review`

Per `_shared/state-handoff.md`:

- **sprint-plan produces** (lines 54-61): `sprints/sprint-${N}/manifest.json`, `sprints/sprint-${N}/stories/S${N}-*.md`, `sprint-registry.json` entry.
- **sprint-dev consumes** exactly those artifacts: Phase 0.0 gate (SKILL.md lines 58-72) checks `sprint-registry.json`, `${SPRINT_DIR}/manifest.json`, and `${SPRINT_DIR}/stories/S*.md` — matching the three required inputs listed in `state-handoff.md` §sprint-plan.
- **sprint-dev produces** (state-handoff.md lines 63-73): `STATE.md`, story `status` transitions, `.cc-sessions/carry-forward.jsonl progress` lines, commits+branches. SKILL.md Phase 1b (line 294) writes carry-forward; Phase 4.8 (line 411) updates story frontmatter; Phase 3.2 step 1b (line 295) writes STATE.md. All outputs cited in handoff table are produced.
- **sprint-review consumes** those same artifacts per state-handoff.md §sprint-review. Composition is sound.

Story-frontmatter contract: Phase 0.0 (line 74) validates every story file against `story-frontmatter.md` §Validation algorithm. Fields extracted at Phase 1.3 (`id`, `title`, `assigned_agent`, `depends_on`, `priority`, `points`, `files`) match the canonical schema producer/consumer matrix.

---

## V6 — Dynamic-Workflows Wiring

**Verdict:** N/A

**Evidence:** `workflow-dispatch.md` line 83 explicitly classifies `sprint-dev` as **`deferred`** — not a current DW adopter. The skill has no `Workflow` dispatch gate. N/A is the correct verdict; no wiring defect to evaluate here.

---

## V7 — Disallowed-Tools Gap

**Verdict:** N/A (not a read-only-by-construction skill)

**Evidence:** `sprint-dev` is a write-heavy super-orchestrator — it creates files, edits story frontmatter, merges branches, writes STATE.md. `disallowed-tools` is only required for skills that are read-only by construction (like `health`). `grep -n "disallowed-tools" skills/sprint-dev/SKILL.md` returns no output (correct: this skill must not declare it). No gap.

---

## V8 — Body-Line Budget

**Verdict:** PASS (under hard cap; over soft target)

**Evidence:** Body line count (between second `---` fence and EOF): **447 lines**. Hard cap: 500 ✓. Soft target: 450 — over by 3 lines (minor). No action required; within hard contract.

---

## V9 — Spawn-Idiom Consistency

**Verdict:** FAIL — drift from canonical Agent() pattern, no explicit blessing in spawn-protocol.md

**Evidence:**

1. `skills/sprint-dev/SKILL.md` line 4 declares `TeamCreate, SendMessage` in `allowed-tools`.
2. SKILL.md Phase 2.1 (line 190) instructs: "Use `TeamCreate` to create a team named `sprint-${SPRINT_NUMBER}-dev`."
3. SKILL.md Phase 3.2 step 3 (lines 298-303) instructs using `SendMessage` for inter-agent coordination.
4. `skills/_shared/spawn-protocol.md` line 79 (Foot-Guns section §1.3, item 5): **"`TeamCreate`+`SendMessage` does not accept `subagent_type`** — the SDK picks by heuristic. **Use the `Agent` tool instead** (v1.4.0 migrated all spawning skills to this)."** This is an explicit foot-gun warning and migration notice, not a blessing.
5. No section in `spawn-protocol.md` carves out an exception for `sprint-dev` or any other skill to use `TeamCreate` for team management while also using `Agent()` for spawning.
6. `references/main.md` (786 lines) contains zero occurrences of `TeamCreate` or `SendMessage` — no supplementary rationale exists there either.

**Assessment:** The SKILL declares `TeamCreate` in `allowed-tools` and instructs its use at Phase 2.1, while `spawn-protocol.md` explicitly says "Use the `Agent` tool instead" after v1.4.0. There is no documented exception. `SendMessage` is referenced for agent coordination (WRAP_UP/UNBLOCK) in spawn-protocol §3 and §4 — that use-case is legitimate and described in the protocol, so `SendMessage` is partially blessed for inter-agent messaging, but `TeamCreate` is not.

**Distinction:** `SendMessage` for orchestrator→agent messaging (UNBLOCK, ASSIST, HALT) is described in spawn-protocol.md §3 (WRAP_UP via SendMessage, line 220) and §4 (stuck agent nudge, line 280). This use is consistent. `TeamCreate` for team grouping, however, has no equivalent blessing; the foot-gun note says use `Agent()` instead (which has a `team_name` parameter per SKILL.md Phase 2.3 line 218).

**Verdict breakdown:** `TeamCreate` in `allowed-tools` + Phase 2.1 instruction = drift (spawn-protocol says deprecated in favor of Agent() team_name). `SendMessage` = partially acceptable (coordination use described in protocol). The declaration of `TeamCreate` in `allowed-tools` should be removed; team grouping is achieved via `Agent(team_name: "...")` per Phase 2.3 itself.

---

## Skill Verdict

**`needs-tightening`**

Checks V1-V8 pass. V9 reveals a single drift: `TeamCreate` is declared in `allowed-tools` and instructed at Phase 2.1, but `spawn-protocol.md` §1.3 Foot-Gun 5 explicitly deprecated it in favor of `Agent(team_name: ...)`. Phase 2.3 already shows the correct `Agent()` invocation with `team_name`; Phase 2.1 is a leftover instruction that contradicts both the protocol and the skill's own Phase 2.3.

---

## Highest-Leverage Fix

Remove `TeamCreate` from `allowed-tools` (line 4) and delete/rewrite Phase 2.1 (line 190) to note that team grouping is achieved by the `team_name` parameter in every `Agent()` call at Phase 2.3 — no separate `TeamCreate` call needed. This eliminates the spawn-protocol drift with a one-line frontmatter edit and a 2-line body edit.
