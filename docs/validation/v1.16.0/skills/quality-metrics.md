# Validation: quality-metrics — v1.16.0 Cohesion + DW

**Date**: 2026-05-28  
**Validator**: cli-qm-validate  
**Files checked**: `skills/quality-metrics/SKILL.md`, `skills/quality-metrics/references/main.md`  
**Skill verdict**: cohesive

---

## V1 — Frontmatter Contract

**Verdict**: PASS

**Evidence**:

`hooks/scripts/skill-frontmatter-validate.sh skills/quality-metrics/SKILL.md` output:
```
[skill-frontmatter-validate.sh] OK: 1 SKILL.md files conform
```

Manual read confirms all required fields present and valid:
- `name: quality-metrics` — present
- `description`: 370 chars (≤1024); starts "Collects, stores…" (third-person verb) — present, valid
- `model: opus` — present
- `effort: medium` — present
- `compatibility: ">=2.1.71"` — present
- `allowed-tools: Read, Write, Bash, Glob, Grep, Agent` — present (skill is invokable)

---

## V2 — OUTPUT STYLE Snippet

**Verdict**: PASS

**Evidence**:

`skills/quality-metrics/SKILL.md` line 23 contains verbatim:
```
OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.
```

Python comparison against canonical (`<!-- canonical-output-style-start -->` block in `skills/_shared/terse-output.md`): exact byte-for-byte match confirmed.

The agent prompt template in `references/main.md` lines 49–53 also contains the verbatim snippet (required by sprint-review Invariant 5 for `references/main.md` files that contain agent-prompt templates). Python comparison: `Match canonical? True`.

---

## V3 — Shared-Protocol Citations Resolve

**Verdict**: PASS

**Evidence**:

`hooks/scripts/markdown-link-validate.sh skills/quality-metrics/SKILL.md` output:
```
markdown-link-validate: OK (397 link(s) checked)
```

Links in SKILL.md manually verified:
- `/_shared/session-protocol.md` → `skills/_shared/session-protocol.md` — EXISTS
- `/_shared/verbose-progress.md` → `skills/_shared/verbose-progress.md` — EXISTS
- `/_shared/spawn-protocol.md` → `skills/_shared/spawn-protocol.md` — EXISTS
- `/_shared/terse-output.md` → `skills/_shared/terse-output.md` — EXISTS

Link in `references/main.md`:
- `[/_shared/agent-prompt-boilerplate.md](/_shared/agent-prompt-boilerplate.md)` → `skills/_shared/agent-prompt-boilerplate.md` — EXISTS

---

## V4 — Canonical-Owner Compliance

**Verdict**: N/A

Per unit notes: quality-metrics has no special owner/delegation role. It is not an O1–O5 canonical owner, and does not delegate to one.

---

## V5 — Pipeline I/O Composition

**Verdict**: PASS

**Chain traced**: `sprint-review → ship → quality-metrics collect`

**Upstream producer (ship)**: `ship` Phase 1.3 dispatches `Invoke: /blitz:quality-metrics collect` with no artifact handoff — quality-metrics takes no upstream file inputs for `collect` mode. Ship runs completeness-gate immediately before (Phase 1.2), but quality-metrics does not consume completeness-gate's `${SESSION_TMP_DIR}/completeness-gate.json`. Instead, the `collect-completeness` collector agent reads a *prior* quality-metrics snapshot (`docs/metrics/*.json`) to forward the completeness score — this is intentional self-referential design (pass-through of prior snapshot; null if none).

**state-handoff.md**: Does not list quality-metrics as a consumer of any sprint pipeline artifact (confirmed: no `quality-metrics` row in the pipeline table). This is correct — collect mode is a standalone observability snapshot requiring no upstream handoff artifact.

**Downstream consumers**: `sprint-review` Phase 4.5 calls `collect` informally (informational, no gate). Ship Phase 1.3 calls `collect` (informational, no gate). Neither skill expects a specific file contract beyond `docs/metrics/YYYY-MM-DD.json` existing.

**story-frontmatter.md**: `skills/_shared/story-frontmatter.md` line 109 lists quality-metrics as a reader of the `points` field — valid (for sprint-plan story context; this is consumed during metric collection cross-references, not a pipeline I/O dependency).

Composition is sound: no missing inputs, no schema mismatch between what upstream produces and what this skill consumes.

---

## V6 — Dynamic-Workflows Wiring

**Verdict**: N/A

Per unit notes: quality-metrics is not `codebase-audit` or `research`. No DW dispatch wiring applies.

---

## V7 — Disallowed-Tools Gap

**Verdict**: N/A

quality-metrics is **not** read-only-by-construction. `allowed-tools` includes `Write` and `Bash` (writes to `docs/metrics/` and `.cc-sessions/`). The Safety Rules section correctly states "Read-only on source code" (meaning it doesn't modify application source), not that the skill itself is read-only. `disallowed-tools` is therefore not applicable and not required. No hardening gap.

---

## V8 — Body-Line Budget

**Verdict**: PASS

**Evidence**:

Python count: body starts at line 10 (1-indexed), after frontmatter closing `---` at line 9. Total file lines: 400. Body line count: **391**.

- Hard cap (500): 391 — PASS (109 lines under cap)
- Target (450): 391 — PASS (59 lines under target)

---

## V9 — Spawn-Idiom Consistency

**Verdict**: N/A

`allowed-tools: Read, Write, Bash, Glob, Grep, Agent` — no `TeamCreate` or `SendMessage`. Uses canonical `Agent` pattern (5 parallel collector agents, `general-purpose` subagent_type, Light weight class). No blessed exception needed. No drift.

---

## Summary

| Check | Verdict | Note |
|-------|---------|------|
| V1 Frontmatter contract | PASS | Validator clean; all fields valid |
| V2 OUTPUT STYLE snippet | PASS | Verbatim match in SKILL.md and references/main.md |
| V3 Shared-protocol citations | PASS | Link validator: OK (397 links); all _shared files exist |
| V4 Canonical-owner compliance | N/A | No owner/delegation role |
| V5 Pipeline I/O composition | PASS | Standalone collect mode; no upstream artifact required; ship chain correct |
| V6 DW wiring | N/A | Not codebase-audit or research |
| V7 Disallowed-tools gap | N/A | Not read-only-by-construction; Write/Bash required for snapshots |
| V8 Body-line budget | PASS | 391 lines (hard cap 500, target 450) |
| V9 Spawn-idiom consistency | N/A | Agent (no TeamCreate/SendMessage) |

**Skill verdict**: **cohesive**

**Highest-leverage fix**: None required. The skill is fully conformant. Optional improvement: the `collect-completeness` collector reads a prior quality-metrics snapshot rather than the live `completeness-gate` output — this means the completeness score in a first-ever snapshot is always `null`. Document this design decision explicitly in `references/main.md` §Metric Collection Commands so future maintainers don't "fix" it by accidentally introducing a cross-session tmp-dir dependency.
