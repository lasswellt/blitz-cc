---
result: CONDITIONAL
ts: 2026-10-12T21:52:08-04:00
ref: 030d69cc2442505e4013d363fa3176226c8691c1
scope: plan
plan: owed-cleanups
---
# check owed-cleanups: CONDITIONAL

Base `db7ae01`. Critic `--mode reject`: REJECT, REJECT, LGTM (three fresh passes, two fix rounds).

## Gates
| Gate | Result |
|---|---|
| typecheck / lint / test / build (toolchain lanes) | skipped: `toolchain.sh stacks` detects no stack |
| validate-plugin-structure, check-version-sync, gen-catalog --check, check-section-refs, skill/agent frontmatter, markdown-link-validate --all | pass |
| bats hooks/tests/ | 517/517 (via npx bats@1.11.1 shim; mise bats shim has no version) |
| tasks.sh verify T-001..T-004 | 4/4 pass; critic held-out 4/4 ok |

## Fix rounds
1. Critic held-out T-002: stale `agents.md §1.3/§1.5` in README.md, mods/blitz-guard (policy.ts deny reasons, README), evals/critic-false-block/fixture.sh, ui-audit:1110, research SKILL:138, stray `(§11.)`. Fixed b07d244.
2. research/references/main.md:514 short-form `(§1.5)`. Fixed 030d69c.

## Advisory (unresolved, hence CONDITIONAL)
- `scripts/check-section-refs.sh` check 1b covers only `_shared/<NAME>` citation forms; a doubled or stale §N in a skill-local or short-form cite is not caught (the removed doubled-number heuristics only ever flagged legit §11).
- `next` row 3 gate: every node/python lint row in the toolchain table is per-file `{file}`, so row 3 arms typecheck only (node lost `eslint .`).
- T-002 touched files outside its `files[]` (check-section-refs.sh, two hooks); recorded as a Ruling in progress.md.
- research/references/main.md:516 `(§1.3 step 5)` points at bullets, not steps (pre-existing).

## Deterministic lane
det-01/02/06/08/11/12/13/14/19 pass; det-03 6 to 6; det-05/07/09/10 re-run on changed files (registry commands hard-code `src/`): clean, det-09 hits are pre-existing prose. check:anti-mock and o2-artifact-l1l2 carry prose, not commands. check:test-tamper exits 1 with empty output (its trailing `[ ] && echo` makes a clean run exit 1).

## cannot_verify
- mods/blitz-guard bun tests need harness-only `claude-code/testing`; the change is two reason strings and one comment.

## Not auto-verified
Architectural fit, wording quality of moved sections.
