# v1.16.0 Cohesion+DW Validation — `refactor`

**Validated:** 2026-05-28  
**Validator:** Claude Code (Sonnet 4.6)  
**Files examined:** `skills/refactor/SKILL.md`, `skills/refactor/references/main.md`

---

## V1 — Frontmatter Contract

**Verdict: PASS**

All required fields present and valid:

| Field | Value |
|---|---|
| `name` | `refactor` |
| `description` | 357 chars (≤1024 limit) — third-person present tense |
| `model` | `opus` |
| `effort` | `medium` |
| `compatibility` | `>=2.1.71` |
| `allowed-tools` | `Read, Write, Edit, Bash, Glob, Grep` |

Evidence: `hooks/scripts/skill-frontmatter-validate.sh skills/refactor/SKILL.md` → `[skill-frontmatter-validate.sh] OK: 1 SKILL.md files conform` (confirmed by manual read of SKILL.md lines 1–8).

---

## V2 — OUTPUT STYLE Snippet

**Verdict: PASS**

Canonical snippet from `skills/_shared/terse-output.md` (between `<!-- canonical-output-style-start -->` markers) matches byte-for-byte the line at `skills/refactor/SKILL.md:19`.

Shell comparison: `MATCH` — no drift detected.

---

## V3 — Shared-Protocol Citations Resolve

**Verdict: PASS**

All `/_shared/` links in SKILL.md resolve to real files under `skills/_shared/`:

| Link target | Resolves to |
|---|---|
| `/_shared/terse-output.md` | `skills/_shared/terse-output.md` — EXISTS |
| `/_shared/definition-of-done.md` | `skills/_shared/definition-of-done.md` — EXISTS |
| `/_shared/session-protocol.md` | `skills/_shared/session-protocol.md` — EXISTS |
| `/_shared/verbose-progress.md` | `skills/_shared/verbose-progress.md` — EXISTS |

Evidence: `hooks/scripts/markdown-link-validate.sh skills/refactor/SKILL.md` → `markdown-link-validate: OK (397 link(s) checked)`.

---

## V4 — Canonical-Owner Compliance

**Verdict: N/A**

`refactor` is not an O1–O5 owner and has no documented owner delegation. The skill references sibling skills (`test-gen`, `browse`, `codebase-audit`) only as follow-up suggestions in Phase 6.2 — no restated owned logic detected.

---

## V5 — Pipeline I/O Composition

**Verdict: N/A**

`refactor` is a standalone user-invoked skill with no pipeline producer/consumer role. It does not appear in `skills/_shared/state-handoff.md` (confirmed by grep returning no output). It does not consume sprint story artifacts or emit pipeline artifacts consumed by downstream skills. Follow-up suggestions in Phase 6.2 are advisory, not pipeline I/O contracts.

---

## V6 — Dynamic-Workflows Wiring

**Verdict: N/A**

`refactor` is not `codebase-audit` or `research`. DW wiring check does not apply.

---

## V7 — Disallowed-Tools Gap

**Verdict: N/A**

`refactor` is not read-only-by-construction — `allowed-tools` explicitly includes `Write` and `Edit` (`SKILL.md:4`). The skill makes code edits as its primary function. The disallowed-tools hardening check applies only to read-only skills; this skill is not a candidate.

---

## V8 — Body-Line Budget

**Verdict: FAIL**

Body (from line 10 to EOF at line 425) = **416 lines**, exceeding the 500-line hard cap but critically above the 450-line target.

| Threshold | Limit | Actual | Status |
|---|---|---|---|
| Hard cap | 500 | 416 | PASS |
| Target | 450 | 416 | FAIL (over target by 34 lines) |

Evidence: `awk 'NR>=10' skills/refactor/SKILL.md | wc -l` → `416`.

The skill exceeds the 450-line target by 34 lines. While it is within the 500-line hard cap and therefore not a contract violation, it needs tightening. The references/main.md companion (163 lines) offloads significant content correctly, but the main SKILL.md body has room for further compression — particularly Phase 2.5 (Research Patterns, 35 lines) and the verbose Regression Protocol inline block (14 lines) could be condensed.

---

## V9 — Spawn-Idiom Consistency

**Verdict: N/A**

`allowed-tools` does not include `TeamCreate` or `SendMessage`. No spawn idioms present. `refactor` runs as a single-agent skill using only direct tool calls.

---

## Skill Verdict

**`needs-tightening`**

The skill is coherent, correctly wired, and passes all contract checks. The sole issue is body length: 416 lines against a 450-line target (34 lines over). No contract violations, no DW defects, no delegation breakage.

---

## Highest-Leverage Fix

Compress **Phase 2.5 (Research Patterns, §§2.5.1–2.5.3, lines 189–222)** and the **Regression Protocol block (lines 325–338)** by extracting verbose prose into `references/main.md` (which already exists and is 163 lines under its own limit). This would save ~30–40 lines and bring the body to ≤450 without removing any behavioral content.
