---
unit: codebase-map
validator: cli-val16cbm
date: 2026-05-28
cohort: v1.16.0
verdict: needs-hardening
highest_leverage_fix: "Remove the misleading 'This skill is read-only' prose on SKILL.md:29 — the skill writes CODEBASE-MAP.md and temp agent files (Write is in allowed-tools and required); the prose creates a false impression and fails the V7 disallowed-tools hardening check."
---

# Validation Report — codebase-map (v1.16.0)

Files examined:
- `skills/codebase-map/SKILL.md` (176 lines)
- `skills/codebase-map/references/main.md` (191 lines)

---

## V1 — Frontmatter Contract

**Verdict: PASS**

All required fields present and valid:

| Field | Value | Status |
|---|---|---|
| `name` | `codebase-map` | PASS |
| `description` | 325 chars (≤1024 limit), third-person | PASS |
| `model` | `opus` | PASS |
| `effort` | `medium` | PASS |
| `compatibility` | `">=2.1.71"` | PASS |
| `allowed-tools` | `Read, Write, Bash, Glob, Grep, Agent` | PASS |

Validator command: `hooks/scripts/skill-frontmatter-validate.sh skills/codebase-map/SKILL.md`
Output: `[skill-frontmatter-validate.sh] OK: 1 SKILL.md files conform`

---

## V2 — OUTPUT STYLE Snippet

**Verdict: PASS**

`SKILL.md:21` contains the canonical snippet verbatim (single line, byte-identical to `terse-output.md` canonical block between `<!-- canonical-output-style-start -->` / `<!-- canonical-output-style-end -->`).

`references/main.md:55-59` contains the snippet inside the dimension-agent prompt template (wrapped across 5 lines for readability within the ``` block). When whitespace-normalized, the content is identical to canonical. The sprint-review SNIPPET_RE check (`OUTPUT STYLE: (terse-technical|lite|full|ultra) per /_shared/terse-output.md`) matches on `references/main.md:55`. Confirmed by grep:
```
OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles,
PASS: references/main.md matches SNIPPET_RE
```

---

## V3 — Shared-Protocol Citations Resolve

**Verdict: PASS**

Link validator run: `hooks/scripts/markdown-link-validate.sh skills/codebase-map/SKILL.md`
Output: `markdown-link-validate: OK (397 link(s) checked)`

Link validator run: `hooks/scripts/markdown-link-validate.sh skills/codebase-map/references/main.md`
Output: `markdown-link-validate: OK (397 link(s) checked)`

All `/_shared/X` citations in SKILL.md resolve: `session-protocol.md`, `verbose-progress.md`, `spawn-protocol.md`, `terse-output.md`. Cross-references in the Additional Resources block resolve correctly.

---

## V4 — Canonical-Owner Compliance

**Verdict: PASS**

`codebase-map` is not an O1–O5 canonical logic owner — it is a standalone brownfield analysis skill. It correctly delegates to shared protocols:

- Subagent spawning → `spawn-protocol.md` (cited at SKILL.md:17 and SKILL.md:86)
- Output style → `terse-output.md` (cited at SKILL.md:18 and in Additional Resources)
- Session registration → `session-protocol.md` (cited at SKILL.md:37)
- Activity feed → `verbose-progress.md` (cited at SKILL.md:37)
- Agent boilerplate → `agent-prompt-boilerplate.md` (cited at `references/main.md:9`)

Shared protocols confirm the relationship bidirectionally: `skills/_shared/agent-prompt-boilerplate.md` lists `codebase-map` as a consumer; `skills/_shared/spawn-protocol.md` cites `codebase-map` as a flat-pool parallel spawn example. `skills/_shared/agent-routing.md` categorizes it as a "single-spawn orchestrator." No restated owned logic detected.

---

## V5 — Pipeline I/O Composition

**Verdict: PASS (standalone — no upstream producer required)**

`codebase-map` is **not in the sprint pipeline** (`state-handoff.md` pipeline table covers `bootstrap → research → roadmap → sprint-plan → sprint-dev → sprint-review → ship`; `codebase-map` appears in none of those rows).

It is a standalone analysis tool. Its declared chain (from `skills/ask/SKILL.md`): `codebase-map → roadmap` (informational, not an artifact handoff). The skill produces `CODEBASE-MAP.md` at the project root, which downstream skills may read as context but no consumer declares it as a required pipeline input.

The skill has no upstream producer dependency — Phase 0.1 builds its own inventory via Bash. No `state-handoff.md` contract to violate. Pipeline I/O composition check is vacuously satisfied.

---

## V6 — Dynamic-Workflows Wiring

**Verdict: N/A**

`codebase-map` is not `codebase-audit` or `research` (the two DW pilot skills per `workflow-dispatch.md` v1.16+). No `BLITZ_DISPATCH` gate, no `Workflow` dispatch code, no DW references in SKILL.md or references/main.md. Not applicable.

---

## V7 — Disallowed-Tools Gap

**Verdict: FAIL / needs-hardening**

The unit notes flag `codebase-map` as a "disallowed-tools READ-ONLY candidate." The issue is:

**Misleading prose:** `SKILL.md:29` states: `**This skill is read-only. It does NOT modify any code.**`

**Actual behavior:** The skill uses the `Write` tool extensively:
- Phase 0.1 writes temp files to `${SESSION_TMP_DIR}/`
- Phase 3 writes `CODEBASE-MAP.md` to the project root
- The 4 dimension agents receive Write access and write `${SESSION_TMP_DIR}/map-*.md`

`Write` is correctly declared in `allowed-tools` — removing it would break the skill. The prose is factually inaccurate. "Read-only" in this context means "does not modify existing source code" — but that nuance is not stated and would mislead users and automated auditors expecting enforcement via `disallowed-tools`.

The reference skill `health` (which IS truly read-only) declares `disallowed-tools: Edit, Write, NotebookEdit` in its frontmatter. `codebase-map` cannot do this (Write is required), but the current prose creates a false equivalence.

**Hardening needed:** Replace `"This skill is read-only. It does NOT modify any code."` with `"This skill does not modify existing source code — it only creates CODEBASE-MAP.md and temporary analysis files."` Removes the misleading "read-only" framing while accurately describing the constraint.

---

## V8 — Body-Line Budget

**Verdict: PASS**

Frontmatter fence locations: `---` on lines 1 and 9. Body runs from line 10 to line 176 (EOF).

Body lines: **167** (target ≤450, hard cap ≤500). Well within budget.

---

## V9 — Spawn-Idiom Consistency

**Verdict: PASS**

`allowed-tools: Read, Write, Bash, Glob, Grep, Agent`

`TeamCreate` and `SendMessage` are **not** in `allowed-tools`. The skill uses the canonical `Agent` tool for spawning (per `spawn-protocol.md` §5: "v1.4.0 migrated all spawning skills to this"). SKILL.md:78 and SKILL.md:82 explicitly instruct `Agent` tool calls with `subagent_type: general-purpose` and `model: sonnet`. Spawn idiom is correct and consistent with protocol.

---

## Summary

| Check | Verdict | Key Evidence |
|---|---|---|
| V1 Frontmatter | PASS | `skill-frontmatter-validate.sh` → OK; all 6 required fields present, description 325 chars |
| V2 OUTPUT STYLE | PASS | SKILL.md:21 byte-identical to canonical; references/main.md:55 matches SNIPPET_RE |
| V3 Link resolve | PASS | `markdown-link-validate.sh` → OK (397 links checked) for both files |
| V4 Owner compliance | PASS | Standalone skill; delegates to shared protocols; bidirectional citations confirmed |
| V5 Pipeline I/O | PASS | Not in sprint pipeline; no upstream producer required; produces CODEBASE-MAP.md |
| V6 DW wiring | N/A | Not codebase-audit or research; no DW dispatch code |
| V7 Disallowed-tools | FAIL | Prose "read-only" on SKILL.md:29 is inaccurate — Write is in allowed-tools and used for CODEBASE-MAP.md output |
| V8 Body lines | PASS | 167 lines (hard cap 500, target 450) |
| V9 Spawn idiom | PASS | Uses Agent tool (not TeamCreate/SendMessage); explicit `model: sonnet` and `subagent_type: general-purpose` |

**Skill verdict: needs-hardening**

**Highest-leverage fix:** Remove the misleading "This skill is read-only" prose on `SKILL.md:29`. Replace with accurate framing: "This skill does not modify existing source code — it only creates `CODEBASE-MAP.md` and temporary analysis files." The current prose fails the V7 read-only hardening check because it implies `disallowed-tools:[Write]` enforcement that cannot be applied (Write is required), misleading both users and automated auditors.
