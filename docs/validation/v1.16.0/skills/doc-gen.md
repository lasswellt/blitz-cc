---
unit: doc-gen
cohort: v1.16.0
validator: claude-sonnet-4-6
date: 2026-05-28
verdict: contract-violation:V4
highest-leverage-fix: "Delete the 'Commit Type to Section Mapping' table from references/main.md and replace with a pointer to skills/release/SKILL.md; fix the 3 drift rows in SKILL.md Phase 2.4 inline quick-ref (docs:→Documentation, style:→EXCLUDED, test:→EXCLUDED)"
---

# doc-gen Validation Report — v1.16.0

Files examined:
- `skills/doc-gen/SKILL.md` (375 lines total; body 366 lines from line 10)
- `skills/doc-gen/references/main.md`

---

## V1 — Frontmatter contract

**PASS**

`hooks/scripts/skill-frontmatter-validate.sh skills/doc-gen/SKILL.md` → `[skill-frontmatter-validate.sh] OK: 1 SKILL.md files conform`

All required fields present and valid:
- `name: doc-gen` ✓
- `description:` 359 chars ≤ 1024, starts "Generates" (third-person) ✓
- `model: opus` ✓
- `effort: medium` ✓
- `compatibility: ">=2.1.71"` ✓
- `allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebSearch, ToolSearch, Agent` (skill is invokable) ✓

---

## V2 — OUTPUT STYLE snippet

**PASS**

Byte-for-byte match confirmed between canonical source (`skills/_shared/terse-output.md` lines 12–12) and `SKILL.md` line 23:

```
OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.
```

Shell diff: `MATCH`

---

## V3 — Shared-protocol citations resolve

**PASS**

`hooks/scripts/markdown-link-validate.sh skills/doc-gen/SKILL.md` → `markdown-link-validate: OK (397 link(s) checked)`

All `/_shared/` links in SKILL.md verified to exist under `skills/_shared/`:
- `/_shared/agent-orchestration.md` → `skills/_shared/agent-orchestration.md` ✓
- `/_shared/terse-output.md` → `skills/_shared/terse-output.md` ✓
- `/_shared/sprint-contracts.md` → `skills/_shared/sprint-contracts.md` ✓
- `/_shared/session-lifecycle.md` → `skills/_shared/session-lifecycle.md` ✓
- `/_shared/terse-output.md` → `skills/_shared/terse-output.md` ✓

Relative link `../release/SKILL.md` (in Phase 2.4) also resolves.

---

## V4 — Canonical-owner compliance

**FAIL**

`skills/release` is the declared O1/O5 canonical owner of the commit-type → changelog-section map (`release/SKILL.md` line 119: "skills/release is the SINGLE source of the commit-type → changelog-section map … doc-gen (changelog mode) … MUST delegate here — they do not restate this map").

**Finding 1 — `references/main.md` fully restates the map without O1 delegation.**

`skills/doc-gen/references/main.md` contains a complete "Commit Type to Section Mapping" table (13 rows) with no citation of `skills/release` as the owner. This is an independent restatement — exactly what the unit notes prohibit.

**Finding 2 — Both in-file maps diverge from the canonical O1 map.**

| Commit prefix | Release (canonical) | SKILL.md Phase 2.4 inline | references/main.md table |
|---|---|---|---|
| `docs:` | Documentation | Other (grouped) | Other |
| `style:` | EXCLUDED (not in changelog) | Other | Other |
| `test:` | EXCLUDED (not in changelog) | Other | Other |

SKILL.md Phase 2.4 acknowledges O1 ownership ("the summary below is for quick reference only — do not let it diverge") but the quick-ref *has* diverged on 3 rows (`docs`, `style`, `test`).

`references/main.md` has the same 3-row drift and no delegation notice at all.

**Verdict: FAIL** — `references/main.md` restates the O1-owned map; both copies have 3-row drift from canonical.

---

## V5 — Pipeline I/O composition

**N/A**

`doc-gen` is not listed in `skills/_shared/session-lifecycle.md` pipeline table (confirmed: grep finds no matches). It is a standalone/on-demand skill invoked directly by the user, not a sprint-pipeline consumer. No upstream producer / downstream consumer chain to trace.

---

## V6 — Dynamic-Workflows wiring

**N/A**

`doc-gen` is not `codebase-audit` or `research`. DW check does not apply.

---

## V7 — disallowed-tools gap

**N/A**

`doc-gen` is not read-only by construction — it explicitly writes to `docs/generated/` (Safety Rules: "This skill only reads source files and writes to `docs/generated/`"). `Write` and `Edit` are intentional. The health-skill `disallowed-tools` pattern applies only to skills that are read-only-by-construction. No hardening gap.

---

## V8 — Body-line budget

**PASS**

Body measured from line 10 (after second `---` fence) to EOF: **366 lines**.

- Hard limit: 500 ✓
- Target: 450 ✓ (366 < 450)

---

## V9 — Spawn-idiom consistency

**PASS**

`allowed-tools` does not declare `TeamCreate` or `SendMessage`. Spawning uses `Agent(subagent_type: "general-purpose", ...)` as required by `agent-orchestration.md` §5 (v1.4.0 migration). Consistent with canonical Agent() pattern.

---

## Summary

| ID | Verdict | Key evidence |
|----|---------|-------------|
| V1 | PASS | `skill-frontmatter-validate.sh` → OK; description 359 chars, third-person |
| V2 | PASS | Shell diff: MATCH against canonical terse-output.md snippet |
| V3 | PASS | `markdown-link-validate.sh` → OK (397 links); all /_shared/ links resolve |
| V4 | FAIL | `references/main.md` restates O1-owned map without delegation; 3-row drift in both copies (docs/style/test sections) |
| V5 | N/A | doc-gen not in sprint pipeline (session-lifecycle.md) |
| V6 | N/A | Not codebase-audit/research |
| V7 | N/A | Not read-only-by-construction |
| V8 | PASS | Body: 366 lines (hard 500, target 450) |
| V9 | PASS | No TeamCreate/SendMessage; uses canonical Agent() pattern |

**Skill verdict: contract-violation:V4**

**Highest-leverage fix:** Delete the "Commit Type to Section Mapping" table from `skills/doc-gen/references/main.md` and replace with a single pointer: `See [skills/release/SKILL.md](../../release/SKILL.md) — canonical O1 owner.` Then fix the 3 drift rows in SKILL.md Phase 2.4 inline quick-ref to match the canonical map (`docs:→Documentation`; `style:→EXCLUDED`; `test:→EXCLUDED`).
