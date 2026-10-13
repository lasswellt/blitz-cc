---
result: CONDITIONAL
ts: 2026-10-12T23:26:16-04:00
ref: 4d23922aea54ebe99fe26f49c3506b1718fe8509
scope: plan
plan: fixes
---
# check fixes: CONDITIONAL

Base `57e6247`. Reject critic: one full pass ran out of turns (MISSING), then split per half: A REJECT → A2 LGTM (T-001..T-005); B REJECT → B2 REJECT → B3 LGTM (T-006..T-010). One fix landed after B3 (4d23922, function/alias wrapper), proven by a parity table, not re-reviewed by a critic.

## Gates
| Gate | Result |
|---|---|
| typecheck / lint / test / build (toolchain lanes) | skipped: no stack detected |
| validate-plugin-structure, check-version-sync, gen-catalog --check, check-section-refs, skill/agent frontmatter, markdown-link-validate --all | pass |
| bats hooks/tests/ | 600/600 (npx bats@1.11.1 shim) |
| tasks.sh verify T-001..T-010 | 10/10; held-out 10/10 across A2 and B3 |
| deterministic lane (repo registry, BLITZ_BASE=57e6247) | every runnable row passes its exit contract; det-17/det-18/check:anti-mock/o2-artifact-l1l2 hold prose |

## Fix rounds
1. check --fix: det-03/06 still scanned src/; det-06/07 `\x27` under grep -E never matched quoted values (now grep -P, pipefail); det-09/10 skip the registry; research and check SKILL.md back under the byte cap.
2. Critic A: heartbeat inbox rewrite lost concurrent appends, mode 0600 → inbox lock helpers (3ea12e7); check→build cycle unbounded → tasks.sh dedupe + BLITZ_CHECK_TASK_CAP (b0bdeb5).
3. Critic B: T-008 bound not quote-aware → masked quotes (4e8919b).
4. Critic B2: redirections and expansions bypassed it → fail-closed redesign (aac7f57).
5. Parity table vs 57e6247 (26 candidates): function wrapper bypass → fail closed on function/alias definitions (4d23922). Table added to T-008 verify[].

## Advisory (unresolved, hence CONDITIONAL)
- block-destructive-git: git-clean dry-run exclusion and the protected-branch test grep the whole command (pre-existing false negatives).
- check's own tasks.sh / next-state.sh run from the installed 3.16.0 plugin: the CONDITIONAL row 1, check-task cap and heartbeat dismissal take effect only after a release.
- scripts/test-listener.sh fallback appends to the inbox without the lock; next's triage rewrite does not use the lock helper; a stale mkdir lock.d is never cleared.
- Registry rows default BLITZ_BASE to origin/main and check does not export CHANGED or its BASE; det-05/07 do not exclude docs or tests.
- check-section-refs 1c resolves markdown-link forms only.
- A single 30-turn reject critic cannot cover a 10-task plan; check should split by task.
- ship REPORT_TS keeps the old split-on-colon truncation.

## Not auto-verified
Architectural fit; the last guard change (4d23922) has parity-table evidence but no critic pass.
