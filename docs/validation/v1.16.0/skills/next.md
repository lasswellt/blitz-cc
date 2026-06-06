# Validation Report — `next` skill (v1.16.0)

Date: 2026-05-28  
Validator session: val-next-v1160  
Files examined: `skills/next/SKILL.md` (no `references/main.md` exists)

---

## V1 — Frontmatter Contract

**PASS**

`hooks/scripts/skill-frontmatter-validate.sh skills/next/SKILL.md` output:

```
[skill-frontmatter-validate.sh] OK: 1 SKILL.md files conform
```

Manual verification of frontmatter fields (lines 1–8):

| Field | Value | Valid |
|---|---|---|
| `name` | `next` | yes |
| `description` | 383 chars, third-person ("Reads project, sprint, and carry-forward state…") | yes |
| `model` | `sonnet` | yes |
| `effort` | `low` | yes |
| `compatibility` | `>=2.1.71` | yes |
| `allowed-tools` | `Read, Write, Edit, Bash, Glob, Grep, Skill, ScheduleWakeup` | yes |
| `argument-hint` | present | yes |

Description length 383 chars ≤ 1024 limit. Third-person voice confirmed.

---

## V2 — OUTPUT STYLE Snippet

**PASS**

Canonical line from `skills/_shared/terse-output.md` (between `<!-- canonical-output-style-start -->` and `<!-- canonical-output-style-end -->`):

```
OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.
```

`skills/next/SKILL.md` line 23 is byte-identical to the canonical snippet. No drift.

---

## V3 — Shared-Protocol Citations Resolve

**PASS**

`hooks/scripts/markdown-link-validate.sh` run against `skills/next/SKILL.md`:

```
markdown-link-validate: OK (397 link(s) checked)
```

All `/_shared/` links verified by file existence:

| Link | File | Exists |
|---|---|---|
| `/_shared/session-lifecycle.md` | `skills/_shared/session-lifecycle.md` | yes |
| `/_shared/sprint-contracts.md` | `skills/_shared/sprint-contracts.md` | yes |
| `/_shared/session-lifecycle.md` | `skills/_shared/session-lifecycle.md` | yes |
| `/_shared/sprint-contracts.md` | `skills/_shared/sprint-contracts.md` | yes |
| `/_shared/terse-output.md` | `skills/_shared/terse-output.md` | yes |

---

## V4 — Canonical-Owner Compliance

**PASS**

`next` is not an O1–O5 canonical owner; it is a read-and-dispatch consumer. It correctly cites the owned logic rather than restating it:

- Loop reconciliation decision tree: owned here, consumed by `sprint` (alias-routes to `/blitz:next --loop` — `skills/sprint/SKILL.md` line 38–45 explicitly cites next as canonical owner).
- Carry-forward reads: delegates to `/_shared/sprint-contracts.md` (line 18).
- State-handoff contracts: delegates to `/_shared/session-lifecycle.md` (line 17).
- Scope-limit protocol: delegates to `/_shared/sprint-contracts.md` (line 189).

Bidirectional check: `skills/sprint/SKILL.md` line 40 cites `next` as canonical loop engine. `skills/sprint-dev/SKILL.md` line 261 and `references/main.md` lines 342–348 cite `/blitz:next` row 1a as the HARD_SPEC escalation consumer. The relationship is bidirectional. No owned logic restated in body.

---

## V5 — Pipeline I/O Composition

**PASS**

Traced chain: sprint-plan → sprint-dev → sprint-review → **next**.

| Artifact | Producer (per `session-lifecycle.md`) | `next` consumes at |
|---|---|---|
| `sprint-registry.json` entry | sprint-plan Phase 4.5 (line 59) | Phase 0.1 |
| `STATE.md` | sprint-dev Phase 3.2 step 1b (line 68) | Phase 0.2 |
| `.cc-sessions/carry-forward.jsonl` | sprint-review Phase 3.6 (line 81); sprint-plan Phase 4.1 (line 60) | Phase 0.6 |
| `sprints/sprint-${N}-planning-inputs.json` | sprint-review Phase 3.6 Invariant 4 (line 79) | Phase 0.7 |
| `roadmap-registry.json` | roadmap (implicit) | Phase 0.5 |

Every artifact `next` reads is listed as a required output of its declared producer in `session-lifecycle.md`. Composition is valid.

---

## V6 — Dynamic-Workflows Wiring

**N/A**

`next` is not `codebase-audit` or `research`. DW validation does not apply.

---

## V7 — Disallowed-Tools Gap

**N/A (not read-only-by-construction)**

`next` has two explicit operating modes: default (read-only suggest) and `--loop` (dispatch + commit + push). In `--loop` mode, `Write`, `Edit`, and `Bash` (for `git commit/push`) are legitimately needed. The `disallowed-tools` pattern (used by `health`) applies only to skills that are read-only in ALL modes. `next` is not such a skill. No hardening gap.

---

## V8 — Body-Line Budget

**PASS (at target, watch)**

Python-derived count (body = lines after second `---` fence, trailing blanks stripped):

- Body starts at line 10 (1-indexed)
- Body line count: **451**
- Hard limit: 500 — 49 lines under
- Target: 450 — **1 line over target**

Evidence: `python3` body-count run returned `451` with last body line `"- (no marker) — phase dispatched; next tick should re-evaluate state"`. The skill is 1 line over the 450-line target but within the 500-line hard cap. Unit notes called this out (`body-watch ~452`). No immediate action required, but next edit should aim for a net reduction.

---

## V9 — Spawn-Idiom Consistency

**N/A**

`allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Skill, ScheduleWakeup` — neither `TeamCreate` nor `SendMessage` declared. Spawn-idiom check does not apply.

---

## Skill Verdict

**cohesive**

All contractual checks pass. No delegation drift, no DW scope, no disallowed-tools gap, no output-style drift. Body is 1 line over the 450-line target (within hard cap of 500) — flagged as watch item only.

## Highest-Leverage Fix

Trim 2–3 lines from Phase 4 REPORT examples (the "Scope-limit active" and "Escalation" banner blocks are the largest prose chunks) to bring body under the 450-line target, eliminating the watch flag.
