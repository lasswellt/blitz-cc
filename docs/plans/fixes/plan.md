# Plan: fixes

## Architecture
One task per defect; each lands its own regression test where a bats suite exists. Order: T-001 before T-002 (the validator would fail the repo first) and before T-010 (shared gate prose); T-003 before T-004 (check relies on the row-1 fallback). Rejected: a single "harden the loop" task (fails SPIDR, 15+ files); escaping `$` as `\$` in SKILL.md (substitution behaviour is undocumented; avoiding `$N` is robust).

## File map
- `skills/{build,ship,plan,research}/SKILL.md` → no `$N` (T-001)
- `hooks/scripts/skill-frontmatter-validate.sh` + bats → `$N` rule (T-002)
- `scripts/next-state.sh` + bats → CONDITIONAL row 1, row-0 plan fill (T-003)
- `skills/check/{SKILL.md,references/main.md}` → advisories to tasks (T-004)
- `hooks/scripts/heartbeat.sh` + bats → own-session dismissal (T-005)
- `scripts/tasks.sh` + bats → `depends_on=`, `add-verify` (T-006)
- `skills/_shared/check-registry.json` → layout-free rows (T-007)
- `hooks/scripts/block-destructive-git.sh` + bats → bounded match (T-008)
- `scripts/check-section-refs.sh` → wider 1b (T-009)
- `skills/{next,build}/references/main.md` → per-file lint over changed files (T-010)

## Coverage
| Outcome | Code | Test/guard |
|---|---|---|
| $N gone | T-001 | T-002 |
| CONDITIONAL exit | T-003, T-004 | next-state.bats |
| Idle notices | T-005 | heartbeat.bats |
| tasks.sh verbs | T-006 | tasks.bats |
| Registry layout | T-007 | jq grep_absent |
| Guard false positive | T-008 | block-destructive-git.bats |
| Section refs | T-009 | self-run |
| Row-3 lint | T-010 | grep |

## Risks
- T-001 ship parsing: rewriting awk without `$2` must keep identical output; the dev should diff old vs new on a fixture spec.md.
- T-007 changes reject-authority rows (det-01 P0); a wrong rewrite silently stops catching deleted tests. Critic held-out should probe det-01 with a real deletion.
- T-004 can loop if a check-filed task's fix is itself advisory; the breaker in loop.reference.md caps it.

## Solutions consulted
None (`docs/solutions/` and `docs/plans/BACKLOG.md` absent).

## Research
The owed-cleanups run: `docs/plans/owed-cleanups/progress.md` Ruling lines and `check-report.md`.
