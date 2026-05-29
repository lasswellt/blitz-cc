---
title: "E-031 decision — honesty-aware prose trim: ledger is phantom, rescoped"
epic: E-031
created: 2026-05-28
verdict: RESCOPED — 1764-line conciseness ledger NOT grounded; executed the 1 real win (roadmap ≤500)
---

# E-031: Honesty-aware prose TRIM — verification + decision

## The premise did not survive verification
SYNTHESIS §3 claimed **1764 removable lines** of old-model-compensation (OMC) prose across ~31 units, ranked by per-unit `removable_lines`. Spot-checking the #1 target:

- **browse** (audit: "195 removable") is only **387 lines total**, and `grep -nE 'do NOT skip|MUST NOT|never skip|IMPORTANT:|always remember|be sure to'` returns **0 matches**. There is no 195-line OMC block to cut.

The per-unit `removable_lines` were **sonnet agent estimates, not grounded counts** — the same inflation pattern already seen in this audit:
- dead_refs:242 → actually 0 (resolver false positive, §4.1)
- E-027 "restated twice" → actually already cited once (S15-001)
- E-031 "1764 OMC lines" → top target has ~0

Hitting 1764 would require cutting **substantive skill instructions**, not OMC fluff — i.e. exactly the over-reach the two Sprint-14/15 critic REJECTs flagged. That is the "uncritically chase a flawed number" failure mode Opus 4.8 is built to avoid.

## Decision: RESCOPE — do not mass-trim
- **Do NOT** execute a 31-file / 1764-line trim. The scope is not real; the gates just passed; the risk/value ratio is bad.
- **Executed the one grounded win:** `roadmap/SKILL.md` was 508 > 500-line cap (the only real structure-validator WARN). Compressed the illustrative status-report template to a terse spec → **490 lines**. WARN cleared. (commit in sprint-16.)
- Detectors/hooks/invariants UNTOUCHED (acceptance verified): `ls hooks/scripts/*.sh` = 36; `ANTI-MOCK|BANNED|never skip|report ALL` still present; `shortcut-taxonomy.md` + `hooks/` unchanged (0 files vs `pre-honesty-trim` tag).

## Residual (optional, not an epic)
If genuine OMC prose is found later, trim it opportunistically with the `pre-honesty-trim` git tag as the revert point. No standing 1764-line obligation. E-031 closed as investigated.

## Meta
Three of the audit's quantified claims (dead-refs, E-027, E-031) were inflated by the per-unit agents. **Lesson for future audits:** treat agent `removable_lines`/`dead_refs` counts as hypotheses to verify (grep), not facts. Recorded in memory `project-xref-deadref-false-positives`.
