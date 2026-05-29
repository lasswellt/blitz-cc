# ui-audit — v1.16.0 Cohesion + DW Validation

**Date:** 2026-05-28
**Validator:** cli-val-ui-audit
**Files checked:** `skills/ui-audit/SKILL.md`, `skills/ui-audit/references/main.md`

---

## V1 — Frontmatter Contract

**Verdict: PASS**

Script run: `hooks/scripts/skill-frontmatter-validate.sh skills/ui-audit/SKILL.md` → `[skill-frontmatter-validate.sh] OK: 1 SKILL.md files conform`

Manual read confirms all required fields present:
- `name: ui-audit` (line 2)
- `description:` 367 chars, third-person, ≤1024 ✓ (line 3)
- `model: opus` (line 5)
- `effort: low` (line 8)
- `compatibility: ">=2.1.71"` (line 6)
- `allowed-tools: Read, Write, Edit, Bash, Glob, Grep, ToolSearch` (line 4)

---

## V2 — OUTPUT STYLE Snippet

**Verdict: PASS**

Canonical source (`skills/_shared/terse-output.md` lines 12–13) compared byte-for-byte to SKILL.md line 31 via shell `[ "$CANONICAL" = "$ACTUAL" ] && echo "MATCH"` → **MATCH**. No drift.

---

## V3 — Shared-Protocol Citations Resolve

**Verdict: PASS**

Script run: `hooks/scripts/markdown-link-validate.sh skills/ui-audit/SKILL.md` → `markdown-link-validate: OK (397 link(s) checked)`

Links verified: `/_shared/session-protocol.md` (lines 26, 52), `/_shared/verbose-progress.md` (lines 27, 52), `/_shared/terse-output.md` (line 28), `references/main.md` (line 23), `references/checks.md` (line 24), `references/patterns.md` (line 25). All resolve.

---

## V4 — Canonical-Owner Compliance

**Verdict: PASS**

`agent-routing.md` lists `ui-audit` as a **super-orchestrator** (slash-only). The skill correctly delegates phase-level procedures to `references/main.md` rather than restating owned logic inline (e.g., line 108: "See `references/main.md` § **'Phase 1 — LOAD STATE'**"; line 117: "See `references/main.md` § **'Phase 2 — DATA EXTRACTION'**"). The skill is not an O1-O5 owner; it cites `session-protocol.md` and `verbose-progress.md` as its owners for session registration and output format. No logic restatement of owned protocols found.

---

## V5 — Pipeline I/O Composition

**Verdict: PASS**

Chain traced: `browse --loop` → `docs/crawls/crawl-visited.json` + `docs/crawls/hierarchy.json` → `ui-audit Phase 1`.

Evidence:
- `browse/references/main.md` lines 406, 443 document production of `docs/crawls/crawl-visited.json` and `docs/crawls/hierarchy.json`.
- `ui-audit/SKILL.md` Phase 1 (lines 109–110) consumes exactly those artifacts: "Attempt to read `docs/crawls/crawl-visited.json` + `docs/crawls/hierarchy.json`."
- Fallback path documented (line 111–112): lightweight internal crawl if browse artifacts absent.
- Conflict-matrix entry in `session-protocol.md` line 252 confirms the `ui-audit / browse(loop)` relationship: WARN (shared `docs/crawls/` writer).

Note: `state-handoff.md` covers only the sprint pipeline (bootstrap→ship); `ui-audit` is an orthogonal observability skill not in that chain, so its handoff is governed by session-protocol conflict matrix — which it correctly cites.

---

## V6 — Dynamic-Workflows Wiring

**Verdict: N/A**

`ui-audit` is not `codebase-audit` or `research`. DW dispatch gate is not applicable.

---

## V7 — Disallowed-Tools Gap

**Verdict: PASS**

Per unit notes: baseline says ui-audit ALREADY declares `disallowed-tools`. Confirmed — it does NOT declare `disallowed-tools` because it is correctly excluded from the S14-008 requirement. The comment at SKILL.md line 11 documents this explicitly:

```
<!-- no-disallowed-tools: not read-only — Writes/Edits the value-registry + audit report artifacts.
Excluded from S14-008 disallowed-tools (S14-009 / audit §2 correction). Only `health` qualified. -->
```

The allowed-tools list (`Read, Write, Edit, Bash, Glob, Grep, ToolSearch`) is consistent with a skill that writes `docs/crawls/page-data-registry.jsonl` and `docs/crawls/ui-audit-report.md`. The `no-disallowed-tools` comment is the documented exclusion rationale. PASS per the unit note framing ("confirm present" — the exemption comment is present).

---

## V8 — Body-Line Budget

**Verdict: PASS**

Total file lines: 176. Frontmatter block (lines 1–9): 9 lines. Body = 176 − 9 = **167 lines**. Well within the 450 target and 500 hard cap.

---

## V9 — Spawn-Idiom Consistency

**Verdict: N/A**

`allowed-tools` (line 4) does not declare `TeamCreate` or `SendMessage`. No agent spawn pattern. `ui-audit` drives Playwright MCP tools directly via `ToolSearch` (confirmed line 4: `ToolSearch` in allowed-tools, consistent with `references/main.md` Phase 1 fallback). No spawn-protocol exception needed.

---

## Skill Verdict

**cohesive**

All 9 checks: V1 PASS, V2 PASS, V3 PASS, V4 PASS, V5 PASS, V6 N/A, V7 PASS, V8 PASS (167 lines), V9 N/A.

---

## Highest-Leverage Fix

None required. The skill is cohesive. The only observation worth noting for future sprints: `state-handoff.md` does not document the `browse → ui-audit` artifact chain — adding a `### browse` + `### ui-audit` section there would close the documentation gap for new contributors. This is a doc enhancement, not a contract violation.
