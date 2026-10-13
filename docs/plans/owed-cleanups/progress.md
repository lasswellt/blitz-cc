## 2026-10-12T20:21:07-04:00 plan created
Ruling: class=bounded tasks=3; two owed items from 3.16.0, files known, no research needed.
Ruling: added T-004 after a suggest-mode dry run showed the row 2/3 gate is not toolchain-resolved; inbox triaged by hand (11 converted, 4 own-session idle notices dismissed).
## 2026-10-12T20:59:37-04:00 build T-001 start (attempt 1)
## 2026-10-12T21:00:50-04:00 verify T-001 ok=true
Ruling: T-001 DONE_WITH_CONCERNS: CITE_BAD numeric arm §([0-9]+)\1 false-positives on §11; fix folded into T-003, T-002 now depends on T-003 (T-001 concern, round 1).
Ruling: tasks.sh has no way to add a depends_on edge or a verify cmd post-add; T-003 is run before T-002 by id instead (T-002, round 0).
## 2026-10-12T21:00:57-04:00 build T-003 start (attempt 1)
## 2026-10-12T21:12:36-04:00 verify T-003 ok=true
Ruling: bats mise shim has no version on this host; verify ran with a PATH shim to npx bats@1.11.1 (517/517 ok). CHANGELOG.md excluded from CITE_BAD only: it quotes the malformed forms as history (T-003, round 1).
## 2026-10-12T21:12:36-04:00 build T-002 start (attempt 1)
## 2026-10-12T21:16:49-04:00 verify T-002 ok=true
Ruling: T-002 dev BLOCKED scope-expansion-needed on scripts/check-section-refs.sh (same §11 false positive as T-003). Valid: main thread replaced the doubled-number arm with check 1b (numbered §N must exist in head or reference); 1b surfaced 3 stale quality.md §4 citations in two hooks, fixed (T-002, round 1).
