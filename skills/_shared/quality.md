# Quality

How blitz decides that work is done, what `check` runs, and what can flip a verdict. Siblings: [loop.md](/_shared/loop.md) (the tick, `gate.json`, `tasks.json`), [agents.md](/_shared/agents.md) (critic modes, dev reply enum), [security.md](/_shared/security.md) (trust boundaries, kill switch). Data: [check-registry.json](/_shared/check-registry.json).


> **Reference:** [quality.reference.md](quality.reference.md) carries the rest of this protocol: The shared check registry and its selection contract, detectors and severity tiers, the ratchet and its schema, the Definition of Done checklist, the REVIEW.md export, and the verification stack. Load it when you need one of those; this file is the contract every consumer obeys.

## Structural done

"Done" is a bit a script sets after reading evidence, never a sentence an agent writes. Asking nicely in the prompt does not reliably stop premature completion; the file guard does.

| Rule | Enforced by |
|---|---|
| Only `scripts/tasks.sh` writes `docs/plans/*/tasks.json` (`init\|add\|list\|set\|verify\|next`, atomic rename) | `hooks/scripts/tasks-guard.sh` (PreToolUse) denies `Edit`/`Write` on that path |
| `tasks.sh verify <plan> <id>` runs every `verify[].cmd` under its `timeout`, writes `passes` and `last_verify {ts, ok, failed, tail}` (200-char evidence tail) | the only path to `passes: true` |
| `status: done ⇒ passes ∧ last_verify.ok` | `tasks.sh set … status=done` refuses otherwise; `startup-validate.sh` flags a violating row |
| `verify[]` non-empty; behavior tasks carry ≥1 non-test check | `plan` rejects the task; `tasks.sh add` refuses a task with no `--verify-cmd` and, without `--test-only-ok`, one whose only checks are test runs |
| Dev agents never edit `tasks.json` or `progress.md` | never-edit list in [agents.md](/_shared/agents.md); `build` writes both at task boundaries on the main branch |
| A plan reaches PASS only after `critic --mode reject` returns `LGTM` on the diff | `check` Phase 4.3; fresh context, no Write/Edit, `omitClaudeMd: true` |
| Stop is gated on tsc + selected tests while `gate.json` is armed | `hooks/scripts/stop-gate.sh`, contract in [loop.md](/_shared/loop.md) |

`attempts` increments per failed build attempt; `blocked` at 3 or on `ESCALATE:`. A blocked task is not done and `next --loop` escalates it (row 1) rather than retrying forever.

## Tests are not the only signal

SpecBench (May 2026): every frontier model saturates the visible tests while failing held-out tests, and the gap grows ~28 pp per 10× code size. Building to the Test (Jun 2026) went further: with a hidden Playwright oracle in the loop, models reached near-perfect scores while the library itself was dead or absent; SpecPath (Aug 2026) found 35 of 100 passing task blocks fail a contract-equivalent revision of the spec. A green test run is therefore evidence, not proof.

| Rule | Where |
|---|---|
| Every behavior task carries ≥1 non-test check beside its test command: `grep_absent` (`! grep -nE 'TODO\|return \{\}' src/x.ts`), `grep_present` (the new export / route / rule string exists), `shell` (a script that exercises the change), or `e2e` (Playwright / `browse`) | `plan` templates per stack; `tasks.sh verify` runs them all |
| `check` runs the critic on the **diff**, not only the tests: spec compliance against `plan.md` first, then code quality (two-stage, one survey pass each) | `check` Phase 2.1; [agents.md](/_shared/agents.md) `critic --mode survey` |
| Deterministic rows run before any semantic pass; a semantic finding without reproducing evidence is dropped, never a blocker | §Shared check registry |
| Full-suite check: the full suite runs once at `check` time even when TIA selected a subset; escaped failures feed `tia_escaped_failures` | `scripts/test-selector.sh`, `docs/guides/tia.md` |
| Held-out check: the reject critic authors one check per task that the builder never saw (derived from `spec.md`, not `verify[]`), runs it, and REJECTs on failure | [critic.md](../../agents/critic.md) §2.5; `check-report.md` §Held-out checks |
| Oracle tamper: deleted `expect(` lines, trivial assertions, snapshot rewrites, `.skip`/`.only` insertions, or a falling assertion count while source grew in the diff's test files is P1 | registry `check:test-tamper`; `check` §1.7 |
| Cannot verify is an answer: a survey critic records what the diff cannot settle in `cannot_verify[]`; `check` runs the command or records a `Ruling:` before the gate | [critic.md](../../agents/critic.md) §5.4; `check` §2.2 |
| Optional `check --mutation`: `@stryker-mutator/vitest-runner` with `coverageAnalysis: "perTest"` and `incremental: true`; surviving mutants on changed files are P3 findings. Off by default (cost) | `check` flag; results cached in `.stryker-tmp/` (gitignored) |

Mocking guidance for authors (what may be mocked, emulator-backed alternatives) lives in [test-gen/references/deterministic-tests.md](../test-gen/references/deterministic-tests.md) §Mocking policy.

## PASS / CONDITIONAL / FAIL

`check` writes `docs/plans/<slug>/check-report.md` with one of three verdicts; `next --loop` row 3→4 reads it.

| Verdict | Criteria |
|---|---|
| **PASS** | tsc, lint, full test run and build pass; every task in scope has `passes: true` via `tasks.sh verify`; no P0/P1 finding; ratchet has no regression; critic `--mode reject` returned `LGTM`; security posture gate clean |
| **CONDITIONAL** | gates pass but P2 findings or unresolved advisory findings remain; or minor gate failures with no P0/P1; or a ratchet regression already carried as a `ratchet:<metric>` blocked task; or the security posture gate reported a non-zero without injection |
| **FAIL** | any gate fails after `--fix`; any P0/P1 finding; critic `REJECT`; `type_errors > 0` (absolute floor); a `ratchet:<metric>` task still blocked at attempt 3; injection in persistent state or a hook executing project content |

Security posture gate (run every time; registry `sec-startup-*`, `sec-content-inspection`, `sec-capability-grant`):

```bash
bash hooks/scripts/check-registry-validate.sh            # security rows schema-valid
bash hooks/scripts/startup-validate.sh --strict --quiet  # tasks.json, docs/solutions, .cc-sessions clean; exit 2 = injection
grep -REn '^[[:space:]]*(eval|source|\.)[[:space:]]+' hooks/scripts/*.sh | grep -v '_lib/common.sh' \
  && echo "FAIL: pre-trust execution of project content" || true
```

Injection or pre-trust execution → FAIL; any other non-zero → CONDITIONAL at best; `sec-content-inspection` stays advisory. Details: [security.md](/_shared/security.md).
