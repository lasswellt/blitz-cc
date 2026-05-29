---
unit: skills/dep-health
kind: skill
verdict: needs-tightening
removable_lines: 60
created: 2026-05-28
---

# dep-health Cohesion Audit

## A. Identity & Boundaries

**Purpose**: Audits npm/pnpm/yarn dependencies for CVEs, outdated versions, and license compliance; three modes: `audit` (read-only scan), `upgrade` (patch+minor bumps), `report` (CSV/JSON output with health score).

**Description ↔ body match**: VERIFIED. Description matches the body's three-mode structure exactly. No scope creep.

**Overlaps**:

| Skill/Agent | Overlap | Classification |
|---|---|---|
| `quality-metrics` | mentions `dep-health` as a suggested downstream call; no logic replication | legitimate layering |
| `code-doctor` | general code health; does not touch package deps | no overlap |
| `integration-check` | checks wiring, not dep versions | no overlap |

No true duplication found.

---

## B. Cohesion

**_shared protocols cited**:

| Protocol | Cited | Followed |
|---|---|---|
| `session-protocol.md` | Phase 0.0 (explicit cite) | VERIFIED — `§Session Registration steps 1-9` reference |
| `verbose-progress.md` | Phase 0.0 (explicit cite) | VERIFIED |
| `terse-output.md` | Additional Resources + OUTPUT STYLE block | VERIFIED |
| `package-install-policy.md` | Additional Resources (explicit cite as "canonical rule for upgrade mode resolution") | VERIFIED |
| `definition-of-done.md` | Line 31 (explicit cite) | VERIFIED |
| `state-handoff.md` | NOT cited | ABSENT — no produce/consume shape declared |
| `story-frontmatter.md` | NOT cited | N/A — dep-health is not sprint-story-producing |
| `spawn-protocol.md` | NOT cited | N/A — no subagents |
| `carry-forward-registry.md` | NOT cited | N/A — no carry-forward entries |

**Invariant 5 (OUTPUT STYLE snippet)**: PRESENT verbatim at line 21. Passes.

**Cross-refs**:
- `references/main.md` — live, read, accurate.
- `/_shared/package-install-policy.md` — live, accurate.
- `/_shared/terse-output.md` — live.
- `/_shared/session-protocol.md` — live.
- `/_shared/verbose-progress.md` — live.
- `/_shared/definition-of-done.md` — not verified (not read), INFERRED live based on other audits.

**state-handoff.md compliance**: `dep-health` produces `${SESSION_TMP_DIR}/dep-health-report.md`. This path is ephemeral/session-scoped and not declared in `state-handoff.md`. Low severity — dep-health is a leaf tool, not pipeline-intermediate. No downstream skill is designed to consume its report artifact.

**Pipeline chain** (`audit` mode):
1. User runs `/blitz:dep-health audit`
2. Phase 0: session registration, mode parse, PM detect, env validate
3. Phase 1: `${PM} audit --json` → parse vulns
4. Phase 2: `${PM} outdated --json` → classify
5. Phase 3: `npx license-checker --json --production` → classify licenses
6. Phase 5: calculate health score → write `dep-health-report.md` → print summary → suggest `/dep-health upgrade` if critical CVEs
7. Session cleanup

Chain is internally coherent. No next-skill handoff artifact required (suggestions are prose, not structured data).

---

## C. Conciseness

**Body line count**: 390 lines. Under 500-line cap. Passes.

**References file**: 309 lines of tables, templates, examples. Well-separated. No drift risk.

**Anti-laziness nudges / defensive restatements** (candidates for deletion given 4.8 honesty):

| Location | Quote | Failure mode it guarded | Delete? |
|---|---|---|---|
| Line 27 | `"Execute every phase in order. Do NOT skip phases."` | Pre-4.8 skipping behavior | YES — Opus 4.8 lazy-investigation eval near-perfect (platform-delta.md `claude-opus-4-8 / 2026-05-28`) |
| Lines 32 | `"All code produced must satisfy the [Definition of Done]. No placeholder implementations."` | Pre-4.8 stub outputs | YES — same rationale; placeholder-prevention is 4.7-era guard |
| Phase 4.3 step 3 (lines 248-251) | detailed per-package revert-and-retry prose restating what "If either fails" means | defensive repetition of obvious error path | TRIM to one sentence |
| Phase 0.2 (lines 62-73) | inline bash snippet for PM detection duplicates detect-stack.sh logic already invoked via `!` import at line 13 | guard against stack detection missing PM info | INFERRED duplication risk; verify detect-stack.sh covers PM field before deleting |

Estimated removable: ~60 lines (guard prose + Phase 4.3 verbosity + potential PM detection inline bash if detect-stack.sh already covers it).

**Content belonging in shared protocol**: None found. License classification table lives in `references/main.md` (correct). Health score formula lives in `references/main.md` (correct). PM commands live in `references/main.md` (correct). DRY discipline is good.

---

## D. Modernization

**Native primitives** (per platform-delta.md):

| Claim | Verdict | Tradeoff |
|---|---|---|
| `disallowed-tools` frontmatter field could lock out `Edit`/`Write` in `audit` mode (platform-delta.md v2.1.152) | DELEGATE to native | SAFETY RULE 6 currently enforced by prose + model honor; `disallowed-tools: Edit,Write` in audit mode makes it declarative and enforcement moves to platform — no opinionation lost. **Top edit candidate.** |
| Parallel PM detection via workflow (platform-delta.md v2.1.154+) | KEEP as-is | Phase 0 is sequential by design; no fan-out gain from workflows here |
| `/goal` loop for recurring weekly sweep (platform-delta.md v2.1.139) | KEEP as-is | dep-health is a one-shot skill; the description notes "recurring weekly sweep" which suits a cron/schedule wrapper, not `/goal` |

**Model/effort frontmatter**:
- `model: sonnet` — correct; `claude-sonnet-4-6` per platform-delta.md `2026-05-28`. No model ID specified (uses alias). Acceptable.
- `effort: medium` — reasonable for a multi-phase scan+report. No change needed.
- No `disallowed-tools` field — gap vs. v2.1.152 capability (see above).

**Prose guard → declarative**: SAFETY RULE 6 (`"In audit mode, this skill is READ-ONLY"`) + SAFETY RULE 8 (`"NEVER run npm audit fix --force"`) are both expressible as `disallowed-tools: Edit,Write` (for audit mode READ-ONLY guard). RULE 8 cannot be a disallowed-tool but remains appropriate prose. Net gain: Rule 6 → `disallowed-tools` per mode (though per-mode disallowed-tools is not currently a platform feature — single frontmatter field applies globally). **Therefore**: add `disallowed-tools` to cover audit/report modes, document that upgrade mode requires user to invoke directly (confirmed by argument-hint). Partial win.

---

## E. Correctness

**Version refs**: No explicit version numbers in SKILL.md body. Clean.

**Dead flags/env vars**:
- `${SESSION_TMP_DIR}` — referenced in Phase 5.2 and 5.3. Validity INFERRED from session-protocol.md; not directly verified.
- `${PM}` — correctly set in Phase 0.2 and carried forward.
- `${LOCKFILE}` — used in Phase 4.3 commit command (`git add package.json ${LOCKFILE}`) but never defined. **BUG**: `${LOCKFILE}` is not assigned anywhere; Phase 0.2 sets `${PM}` but not `${LOCKFILE}`. The correct lockfile name depends on PM (e.g., `package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`). This will fail silently on commit.

**Broken paths**: None found.

**Wrong tool names**: None found.

**Multi-agent / subagents-cannot-spawn-subagents**: N/A — dep-health is single-agent, no spawning.

**Monorepo note** (Error Recovery section): Suggests running skill per workspace directory manually. No automation. Acceptable for now.

**`${SESSION_TMP_DIR}/dep-health-report.md`**: Ephemeral, session-scoped. Not accessible to downstream skills or users after session ends. Consider writing to `docs/dep-health-report.md` or a project-relative path in `report` mode for persistence. Current behavior undocumented risk.

---

## F. Verdict

**`needs-tightening`**

**Top 3 highest-leverage edits**:

1. **Fix `${LOCKFILE}` undefined variable** (Phase 4.3 commit command). Add assignment after PM detection:
   ```bash
   # After PM detection in Phase 0.2
   case "$PM" in
     npm)  LOCKFILE="package-lock.json" ;;
     pnpm) LOCKFILE="pnpm-lock.yaml" ;;
     yarn) LOCKFILE="yarn.lock" ;;
   esac
   ```

2. **Add `disallowed-tools: Edit,Write` frontmatter** (platform-delta.md v2.1.152). Note in SAFETY RULES that the platform enforces read-only for audit/report — prose Rule 6 becomes belt-and-suspenders. Removes reliance on model honor for safety-critical constraint.

3. **Delete anti-laziness guards** (lines 27, 32): `"Execute every phase in order. Do NOT skip phases."` and `"No placeholder implementations."` — 4.8 honesty improvements (platform-delta.md `claude-opus-4-8 / 2026-05-28`) make these defensive restatements obsolete.
