## 2026-10-12T22:03:09-04:00 plan created
Ruling: class=architectural tasks=10; defects found by the owed-cleanups dogfood run, shapes known from that run so no research agents; user ruled CONDITIONAL -> advisories become tasks.
## 2026-10-12T22:04:29-04:00 build T-001 start (attempt 1)
## 2026-10-12T22:05:23-04:00 verify T-001 ok=true
Ruling: ship REPORT_TS keeps the old split-on-colon behaviour (ISO ts truncated to the hour) to stay behaviour-identical; latent bug left for a follow-up (T-001, round 1).
## 2026-10-12T22:05:32-04:00 build T-002 start (attempt 1)
## 2026-10-12T22:07:08-04:00 verify T-002 ok=true
Ruling: T-002 dev BLOCKED scope-expansion-needed: rule flagged $ARGUMENTS, used deliberately in 9 skill bodies. Spec defect: narrowed rule 13 to $<digit>; $ARGUMENTS allowed and tested as passing (T-002, round 1).
## 2026-10-12T22:07:08-04:00 build T-003 start (attempt 1)
## 2026-10-12T22:08:33-04:00 verify T-003 ok=true
Ruling: loop.reference.md and next/SKILL.md row table updated on main (Tier-1 doc sync, outside T-003 files) (T-003, round 1).
## 2026-10-12T22:08:33-04:00 build T-004 start (attempt 1)
## 2026-10-12T22:09:29-04:00 verify T-004 ok=true
## 2026-10-12T22:09:29-04:00 build T-005 start (attempt 1)
## 2026-10-12T22:10:43-04:00 verify T-005 ok=true
## 2026-10-12T22:10:43-04:00 build T-006 start (attempt 1)
## 2026-10-12T22:18:08-04:00 verify T-006 ok=true
## 2026-10-12T22:18:08-04:00 build T-007 start (attempt 1)
## 2026-10-12T22:19:46-04:00 verify T-007 ok=true
Ruling: det-01 and check:test-tamper exit codes were inverted vs their contract (det-01 could never fire); rewritten and self-tested in scratch repos. CHANGED is not exported by check §1.2, rows fall back to git diff BASE...HEAD (T-007, round 1).
## 2026-10-12T22:19:46-04:00 build T-008 start (attempt 1)
## 2026-10-12T22:20:43-04:00 verify T-008 ok=true
Ruling: pre-existing false negatives left for follow-up: git-clean dry-run exclusion and the protected-branch test grep the whole command, so a "-n"/"main" in a later command changes the verdict (T-008, round 1).
## 2026-10-12T22:20:43-04:00 build T-009 start (attempt 1)
## 2026-10-12T22:21:30-04:00 verify T-009 ok=true
