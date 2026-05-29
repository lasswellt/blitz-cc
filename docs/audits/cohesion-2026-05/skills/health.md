---
unit: skills/health/SKILL.md
kind: skill
verdict: needs-tightening
removable_lines: 22
created: 2026-05-28
---

# Cohesion Audit — `health`

## A. Identity & Boundaries

**Purpose (one sentence):** Read-only structural validator for the plugin: hooks executable, sessions/locks clean, activity-feed sized, every SKILL.md frontmatter-conformant.

**Description vs body match:** Yes. Description is accurate. Body delivers exactly what description promises.

**Overlap map:**

| Skill/Agent | Overlap | Type |
|---|---|---|
| `conform` | `conform` runs `skill-frontmatter-validate.sh --all` (same as Phase 3.1 here) | Legitimate layering — `conform` is a fix-and-report tool; `health` is read-only audit; different affordance |
| `next` | `next` calls `health` as a pre-flight check per `skills/next/SKILL.md` | Caller/callee — not duplication |

No true duplication found.

---

## B. Cohesion

### _shared protocol citations

| Protocol | Referenced in SKILL.md | Followed or restated inline? |
|---|---|---|
| `session-protocol.md` | Implicit only ("No session protocol required.") | Waived — legitimate for read-only skill |
| `verbose-progress.md` | Not cited | No activity-feed logging prescribed in body — drift risk |
| `terse-output.md` | Canonical OUTPUT STYLE snippet present (line 19) | Verbatim match — Invariant 5 **PASS** |
| `state-handoff.md` | Not cited | `health` produces no pipeline artifacts; omission acceptable |
| `story-frontmatter.md` | Not cited | N/A for this skill |

**Invariant 5:** OUTPUT STYLE snippet at line 19 matches canonical form. **PASS.**

### Cross-reference accuracy

Phase 3.3 hardcodes a legacy protocol list:
```
session-protocol.md, verbose-progress.md, definition-of-done.md,
checkpoint-protocol.md, deviation-protocol.md, context-management.md,
session-report-template.md
```
Actual `skills/_shared/` contains 26 files. The list above is a stale subset — notably absent: `quality-matrix.md`, `ratchet-protocol.md`, `shortcut-taxonomy.md`, `spawn-protocol.md`, `token-budget.md`, `agent-routing.md`, `worktree-lifecycle.md`, `knowledge-protocol.md`, `carry-forward-registry.md` (added v1.11–v1.15). The hardcoded list will produce false PASS for any of those 18 missing files.

**Broken path:** Phase 3.1 calls `hooks/scripts/skill-frontmatter-validate.sh --all`. Script exists (verified). Path is correct.

**Broken path:** Phase 0 calls `./scripts/validate-plugin-structure.sh`. Script exists. Path correct.

### Pipeline chain (end-to-end trace)

`next` → calls `health` → `health` emits human-readable console report with HEALTHY/NEEDS ATTENTION/UNHEALTHY. `next` consumes this as a status signal (not a structured artifact). No structured producer/consumer contract — acceptable for a diagnostic skill.

---

## C. Conciseness

**Line count:** 185 (well under 500-line cap). No padding issue.

**Prose marking for deletion (defensive/anti-laziness):**

- Line 25: `"No session protocol required. This skill is lightweight and read-only."` — informational filler. No model behavior to guard; Opus 4.8 won't misread this. **~2 lines removable.**

- Phase 3.3 hardcoded expected protocol list (lines 142–143): 
  ```
  Check that the expected protocols are present: session-protocol.md, verbose-progress.md, definition-of-done.md, checkpoint-protocol.md, deviation-protocol.md, context-management.md, session-report-template.md.
  ```
  This is both stale and redundant with the `ls` command on line 139. The prose list exists to guard against the model reporting "all present" without checking — anti-laziness hedge. With 4.8 honesty, the `ls` output alone is sufficient. **~3 lines removable (and fixes the stale-list correctness bug simultaneously).**

- Phase 3.4 (lines 147–152) repeats `./scripts/detect-stack.sh` verbatim from Phase 0. Phase 0 already runs it; Phase 4 runs it a second time. **~8 lines removable (entire Phase 4 is duplicate).**

- Phase 5 report template (lines 156–185): the "Structural validation" row duplicates Phase 0 output already shown on stdout. Template is useful as a format spec but the `Structural validation` row is redundant. **~2 lines removable.**

- Phase 1.1 `grep` incantation (lines 51–53): parses `hooks.json` with a fragile regex that will miss scripts not matching `scripts/([^"]+)`. Phase 0 already validates hook-script existence via `validate-plugin-structure.sh`. **Duplication — ~5 lines removable.**

**Total estimated removable:** ~20–22 lines.

**Content belonging in shared protocol:** None — the diagnostic steps are skill-specific.

---

## D. Modernization

**Native primitive overlap (per `platform-delta.md`):**

| Native change | Version | Relevance | Claim |
|---|---|---|---|
| `disallowed-tools` frontmatter field | v2.1.152 (platform-delta.md) | `health` is already `allowed-tools: Read, Bash, Glob, Grep` — no Write/Edit. No `disallowed-tools` needed since the allowlist already restricts. | Keep — allowlist sufficient; `disallowed-tools` adds no value here |
| Opus 4.8 honesty improvements | claude-opus-4-8 / 2026-05-28 (platform-delta.md) | Anti-laziness nudges in Phase 3.3 (hardcoded list) and the "No session protocol required" note exist to prevent model shortcuts. With 4.8 honesty these are low-value. | Delete the prose guards; rely on model + `ls` output |
| Native `claude agents` TUI | v2.1.139 / 2026-05-11 (platform-delta.md) | Phase 2 (stale session + lock detection) partially overlaps. Native TUI shows running/blocked/done sessions. Gap: `health` checks `.cc-sessions/*.json` status + PID liveness; native TUI only shows live sessions — doesn't surface stale JSON artifacts. | Keep Phase 2 — native TUI doesn't replace file-level cleanup |

**model/effort:** `model: sonnet`, `effort: low` — appropriate for a read-only diagnostic. No change needed.

**Prose guard → `disallowed-tools`:** N/A — skill doesn't have guards against write operations; allowed-tools already restricts.

---

## E. Correctness

**Stale version refs:** None explicit in body.

**Phase 3.3 stale protocol list:** `definition-of-done.md`, `checkpoint-protocol.md`, `deviation-protocol.md`, `context-management.md`, `session-report-template.md` still exist; but 18 newer protocols (v1.11–v1.15) are absent from the expected list. A `health` check that passes on 7/26 protocols but silently ignores 19 is a correctness bug.

**Phase 1.1 grep pattern:** `grep -oP '"command":\s*"[^"]*scripts/([^"]+)"'` — will miss hook entries where the command path pattern differs. `validate-plugin-structure.sh` (Phase 0) already does this more robustly. The Phase 1.1 re-check is both fragile and redundant.

**`--all` flag for `skill-frontmatter-validate.sh`:** verified the script exists; `--all` flag not independently verified (inferred from CLAUDE.md description of the hook). Confidence: medium.

**`compatibility: ">=2.1.71"`:** no newer minimum pinned despite using features from v2.1.152+? Actually health uses only Bash/Read/Glob/Grep — no new features. Compatibility claim is fine.

**subagents-cannot-spawn-subagents:** N/A — `health` spawns no agents.

---

## F. Verdict

**`needs-tightening`**

Highest-leverage edits:

1. **Fix Phase 3.3 stale protocol list** — replace hardcoded 7-file list with `ls skills/_shared/*.md | wc -l` plus a count assertion (or remove prose guard entirely and let `ls` output speak). Fixes correctness bug + removes ~3 lines.

2. **Delete Phase 4 (lines 147–152)** — duplicate of Phase 0 stack detection. Remove entirely. Saves ~8 lines.

3. **Delete Phase 1.1 fragile grep (lines 49–54)** — covered by Phase 0's `validate-plugin-structure.sh`. Or replace with: `python3 -c "import json; d=json.load(open('hooks/hooks.json')); [print(h.get('command','')) for e in d.get('hooks',{}).values() for h in (e if isinstance(e,list) else [e])]" | grep scripts/`. But simplest fix is removal since Phase 0 already covers it.
