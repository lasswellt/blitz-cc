# Skill Validation — retrospective — v1.16.0

**Unit:** retrospective  
**File:** skills/retrospective/SKILL.md  
**References:** skills/retrospective/references/main.md (EXISTS)  
**Validated:** 2026-05-28  
**Validator:** claude-sonnet-4-6

---

## V1 — Frontmatter Contract

**Verdict:** PASS

`hooks/scripts/skill-frontmatter-validate.sh skills/retrospective/SKILL.md` → `[skill-frontmatter-validate.sh] OK: 1 SKILL.md files conform`

Manual check of all required fields:
- `name: retrospective` — present
- `description:` — 395 chars (≤1024 limit); third-person ("Analyzes completed sessions…") — PASS
- `model: opus` — present
- `effort: medium` — present
- `compatibility: ">=2.1.71"` — present
- `allowed-tools: Read, Write, Edit, Bash, Glob, Grep` — present (skill is invokable)
- `argument-hint:` — optional field, present

All required fields valid. Script verdict: OK.

---

## V2 — OUTPUT STYLE Snippet

**Verdict:** PASS

Canonical snippet extracted from `skills/_shared/terse-output.md` (between `<!-- canonical-output-style-start -->` and `<!-- canonical-output-style-end -->`):

```
OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.
```

SKILL.md line 20 is byte-identical to canonical (Python `==` comparison: `True`). No drift.

---

## V3 — Shared-Protocol Citations Resolve

**Verdict:** PASS

`hooks/scripts/markdown-link-validate.sh skills/retrospective/SKILL.md` → `markdown-link-validate: OK (397 link(s) checked)`

Links verified by script include:
- `/_shared/session-lifecycle.md` → `skills/_shared/session-lifecycle.md` — resolves
- `/_shared/terse-output.md` → `skills/_shared/terse-output.md` — resolves
- `/_shared/terse-output.md` → `skills/_shared/terse-output.md` — resolves
- `/_shared/sprint-contracts.md` → `skills/_shared/sprint-contracts.md` — EXISTS (confirmed via ls)
- `references/main.md` (relative) — EXISTS in `skills/retrospective/references/main.md`

Script exit OK.

---

## V4 — Canonical-Owner Compliance

**Verdict:** N/A

Retrospective is not an O1-O5 owner and does not explicitly delegate to an O-owner. No canonical-owner relationship declared or implied in SKILL.md or references/main.md. No bidirectional citation obligation applies.

---

## V5 — Pipeline I/O Composition

**Verdict:** PASS

`skills/_shared/session-lifecycle.md` line 78: `sprints/sprint-${N}/review-report.md` — producer: `sprint-review Phase 4.1`, consumer: `ship, retrospective`, Required.

SKILL.md Phase 0.2 data-sources table (line 93) lists `**/review-findings.md`, `**/review-report.md` as "Review reports" — exact match to what sprint-review produces.

SKILL.md Phase 0.1 bash block reads `.cc-sessions/activity-feed.jsonl` and `.cc-sessions/*.json` — these are written by the session-protocol (session-start) which all skills produce. No upstream producer gap.

Retrospective has no section in session-lifecycle.md as a *producer* (it writes `docs/retrospective/YYYY-MM-DD-proposals.md` and `.cc-sessions/developer-profile.json` for downstream consumers). Neither is declared as a downstream input in session-lifecycle.md for any other skill — consistent with retrospective being a terminal analysis skill.

Chain: `sprint-review → review-report.md → retrospective (Phase 0.2)` — input exactly matches declared source.

---

## V6 — Dynamic-Workflows Wiring

**Verdict:** N/A

Retrospective is not `codebase-audit` or `research`. Dynamic-Workflows dispatch check does not apply.

---

## V7 — Disallowed-Tools Gap

**Verdict:** N/A (not read-only-by-construction)

Retrospective has `Write` and `Edit` in `allowed-tools` — it intentionally writes `docs/retrospective/YYYY-MM-DD-proposals.md` (Phase 2.3), `.cc-sessions/developer-profile.json` (Phase 2.5.2), and applies safe proposals (Phase 3.1). It is not a read-only skill. No `disallowed-tools` declaration needed or expected.

---

## V8 — Body-Line Budget

**Verdict:** PASS (at target boundary)

Total lines in SKILL.md: 481  
Frontmatter fence: lines 1–9 (opening `---` on line 1, closing `---` on line 9)  
Body: lines 10–481 = **472 lines**

Hard limit: 500 — PASS  
Target: 450 — EXCEEDED by 22 lines

Note: Unit notes flagged "body-watch ~473" — actual count is 472, confirming the near-target concern. Not a hard failure (472 < 500), but at the watch threshold.

---

## V9 — Spawn-Idiom Consistency

**Verdict:** N/A

`allowed-tools: Read, Write, Edit, Bash, Glob, Grep` — no `TeamCreate` or `SendMessage` declared. Retrospective does not spawn multi-agent teams. Spawn-idiom check not applicable.

---

## Final Skill Verdict

**needs-tightening**

Retrospective passes all hard contract checks (frontmatter, OUTPUT STYLE byte-match, link resolution, pipeline I/O composition). The single concern is V8: body is 472 lines against a 450-line target (22-line overage). All other checks are PASS or N/A.

## Highest-Leverage Fix

Trim body from 472 → ≤450 lines: the `references/main.md` already holds pattern taxonomy, proposal templates, safety classification rules, and before/after metrics templates. Phase 0.2's data-sources table, Phase 2.1's classification table, and Phase 4.1's summary block are partially redundant with references/main.md content — collapsing them to one-line citations would recover the 22+ lines needed to hit the 450-line target.
