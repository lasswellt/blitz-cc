---
unit: roadmap
validator: claude-sonnet-4-6
date: 2026-05-28
sprint: v1.16.0
verdict: needs-tightening
highest_leverage_fix: "Body at 480 lines exceeds the 450-line target by 30; Phase 2.4 refresh-mode procedure (backfill path narrative, ~40 lines) can be extracted to references/main.md to trim under target."
---

# Skill Validation: roadmap — v1.16.0

## Files Examined

- `skills/roadmap/SKILL.md` (490 total lines; frontmatter lines 1–10; body lines 11–490 = 480)
- `skills/roadmap/references/main.md` (exists; referenced for Phases 5–8)
- `skills/_shared/terse-output.md` (canonical OUTPUT STYLE source)
- `skills/_shared/session-lifecycle.md` (pipeline contract)
- `skills/_shared/sprint-contracts.md` (canonical carry-forward owner)
- `skills/sprint-plan/SKILL.md` (downstream consumer)

---

## V1 — Frontmatter Contract

**Verdict: PASS**

Script run: `hooks/scripts/skill-frontmatter-validate.sh skills/roadmap/SKILL.md`
Output: `[skill-frontmatter-validate.sh] OK: 1 SKILL.md files conform`

Fields verified by direct read (SKILL.md lines 1–10):

| Field | Value | Valid? |
|---|---|---|
| `name` | `roadmap` | Yes |
| `description` | 304 chars, starts "Generates phased…" (third-person) | Yes (≤1024, third-person) |
| `model` | `opus` | Yes |
| `effort` | `high` | Yes |
| `compatibility` | `">=2.1.71"` | Yes |
| `allowed-tools` | `Read, Write, Edit, Bash, Glob, Grep, WebSearch, WebFetch, ToolSearch, Agent` | Yes (invokable skill) |

---

## V2 — OUTPUT STYLE Snippet

**Verdict: PASS**

Canonical line extracted from `skills/_shared/terse-output.md` (between `<!-- canonical-output-style-start -->` / `<!-- canonical-output-style-end -->` markers) compared byte-for-byte against `SKILL.md` line 25.

Shell comparison: `MATCH` (exact string equality confirmed).

Location in SKILL.md: line 25, between the second `---` fence (line 10) and the third `---` fence (line 27).

---

## V3 — Shared-Protocol Citations Resolve

**Verdict: PASS**

Script run: `hooks/scripts/markdown-link-validate.sh skills/roadmap/SKILL.md`
Output: `markdown-link-validate: OK (397 link(s) checked)`

All `/_shared/X` links verified:

| Link | Resolves to | Status |
|---|---|---|
| `/_shared/sprint-contracts.md` | `skills/_shared/sprint-contracts.md` | EXISTS |
| `/_shared/session-lifecycle.md` | `skills/_shared/session-lifecycle.md` | EXISTS |
| `/_shared/terse-output.md` | `skills/_shared/terse-output.md` | EXISTS |
| `/_shared/session-lifecycle.md` | `skills/_shared/session-lifecycle.md` | EXISTS |
| `/_shared/terse-output.md` | `skills/_shared/terse-output.md` | EXISTS |
| `/_shared/sprint-contracts.md` | `skills/_shared/sprint-contracts.md` | EXISTS |
| `references/main.md` | `skills/roadmap/references/main.md` | EXISTS |

---

## V4 — Canonical-Owner Compliance

**Verdict: PASS**

Roadmap is a **pipeline owner** (not a delegator to an O1–O5 owner): it owns `docs/roadmap/roadmap-registry.json`, `docs/roadmap/epic-registry.json`, and `.cc-sessions/carry-forward.jsonl` `created` lines per `session-lifecycle.md` lines 48–50.

Carry-forward protocol is owned by `skills/_shared/sprint-contracts.md`. Roadmap correctly cites it in four places (SKILL.md lines 18, 50, 129, 360) and does NOT restate the Reader Algorithm — it delegates via "See `skills/_shared/sprint-contracts.md` for the full protocol" (line 360).

Bidirectional check: `skills/_shared/sprint-contracts.md` line 125 documents "When `/blitz:roadmap extend` reads a research doc…" — back-reference confirmed. `session-lifecycle.md` line 44 has a `### roadmap` section listing roadmap as the producer — confirmed.

---

## V5 — Pipeline I/O Composition

**Verdict: PASS**

Chain traced: **research → roadmap → sprint-plan**

**Upstream (research → roadmap):**
- `session-lifecycle.md` line 41: research produces `docs/_research/<YYYY-MM-DD>_<slug>.md` and `scope:` YAML frontmatter → consumed by roadmap.
- SKILL.md Phase 0.2 (lines 71–73) globs `**/docs/_research/**/*.md` — exact match to research's output path.
- SKILL.md Phase 1.1.5 (lines 127–158) parses `scope:` YAML frontmatter — exact match to research Phase 3 writer contract per `session-lifecycle.md` line 42.

**Downstream (roadmap → sprint-plan):**
- `session-lifecycle.md` lines 48–50: roadmap produces `roadmap-registry.json`, `epic-registry.json`, and `carry-forward.jsonl` `created` lines.
- `skills/sprint-plan/SKILL.md` Phase 0 (lines 64–65) hard-fails if `docs/roadmap/roadmap-registry.json` or `docs/roadmap/epic-registry.json` are absent — exact match to roadmap's output artifacts.
- sprint-plan Phase 0 step 8 reads `.cc-sessions/carry-forward.jsonl` — confirmed at sprint-plan line 95–104.

Composition is coherent. No artifact name drift detected.

---

## V6 — Dynamic-Workflows Wiring

**Verdict: N/A**

roadmap is not `codebase-audit` or `research`. DW dispatch gate check not applicable.

---

## V7 — Disallowed-Tools Gap

**Verdict: N/A**

roadmap is not read-only by construction: it declares `Write`, `Edit`, and `Bash` (producing `docs/roadmap/` artifacts and `.cc-sessions/` registry lines). The disallowed-tools hardening check applies only to read-only skills. No gap to flag.

---

## V8 — Body-Line Budget

**Verdict: FAIL (over target; under hard cap)**

Body line count (lines 11–490): **480 lines**

| Limit | Value | Status |
|---|---|---|
| Hard cap | 500 | PASS (480 < 500) |
| Target | 450 | FAIL (480 > 450, over by 30) |

The unit notes warned of "body-watch ~481" — actual count is 480 (one line less than flagged). The hard cap is safe, but the target is missed by 30 lines.

Primary offender: Phase 2.4 (lines 303–360) is 58 lines of detailed refresh-mode procedure including the backfill path narrative. The "Backfill path for legacy research docs" block (lines 352–358, ~15 lines of prose + numbered steps) is a good extraction candidate into `references/main.md`.

---

## V9 — Spawn-Idiom Consistency

**Verdict: PASS**

`allowed-tools` declares `Agent` but NOT `TeamCreate` or `SendMessage`. This is the canonical single-agent `Agent()` pattern per `agent-orchestration.md`. No TeamCreate drift. No exception lookup required.

SKILL.md text references spawning agents in Phases 5 and 7 ("Spawn agents per domain…", "Spawn agents per phase…") — consistent with single `Agent` tool declaration.

---

## Skill Verdict

**`needs-tightening`**

One check fails (V8: body 480 lines vs 450-line target). All contract checks (V1–V5, V9) pass. V6 and V7 are N/A.

## Highest-Leverage Fix

Extract the "Backfill path for legacy research docs" prose block (Phase 2.4 lines 352–358, ~15–20 lines) and the detailed acceptance-check type table (Phase 2.4 lines 314–320) into `references/main.md` — replacing them with a single citation line. This trims ~25–30 lines, bringing body under the 450-line target while keeping the procedure discoverable via the existing references/main.md delegation pattern already established for Phases 5–8.
