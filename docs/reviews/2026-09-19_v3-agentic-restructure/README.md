---
title: "blitz-cc v3 review — strip the sprint layer, keep the agentic harness"
date: 2026-09-19
status: implemented
plugin_version_reviewed: 2.5.0
plugin_version_shipped: 3.0.0
cc_version_reviewed_against: 2.1.277
---

# blitz-cc v3 review — strip the sprint layer, keep the agentic harness

**Scope.** Full review of the 2.5.0 plugin against Claude Code 2.1.277 and against current agentic-engineering practice, with three research rounds (platform docs, field harnesses, adversarial evidence). Sources with fetch dates: [sources.md](sources.md).

**Finding in one sentence.** 2.5.0 was two systems in one plugin: a first-rate agentic harness (anti-shortcut hooks, the Stop gate, hook-owned session records, the executable check registry, `next --loop`, worktree waves) wrapped in a Scrum simulator (sprints, stories, epics, roadmaps, retrospectives, a 1,048-line carry-forward protocol, an eight-state status machine nobody validated, LLM-executed file locks) whose ceremony cost context on every turn and whose "done" was a prose promise.

**Decision.** Drop the sprint layer, no compatibility aliases, clean 3.0.0. Keep every enforcement mechanism that a script or hook actually runs. Replace prose-enforced state with a JSON feature list that only one script can write.

---

## 1. Scorecard (2.5.0)

| Surface | Before | After | Finding |
|---|---|---|---|
| Skills | 38 · 10,851 SKILL.md lines | 21 · 6,223 | ~14% of every body was mandatory boilerplate; 27 skills cited `sprint-contracts.md`; `review` collided with the platform's bundled `/verify` in its own verification table |
| Agents | 11 · 2,525 lines | 5 · 1,309 | `architect` and `doc-writer` self-declared unwired; three `*-dev` agents differed only in role prose; `orchestrator` could only print a slash command |
| Protocols | 13 · 5,708 lines | 6 · 1,897 | 2,581 lines described behavior enforced by ~8 scripts; 14 of 26 `BLITZ_*` flags were read only by prose; three files were written by nothing |
| Hooks | 49 scripts · 24 events · 4,329 lines | 32 scripts · 14 events · 3,093 | two dead guards; nine events served by ≤45-line feed stubs; per-edit activity logging duplicated OpenTelemetry |
| Validators | ~750 lines of count-sync | generated catalog | count-sync passed while nine files were wrong (fail-open regex); README contradicted itself on hook counts |
| README / CLAUDE.md | 483 / 38 lines | 177 / 30 | ~180 README lines hand-mirrored the filesystem |

## 2. Contradiction register (platform facts that changed the design)

| # | 2.5.0 assumed | Claude Code 2.1.277 | v3 response |
|---|---|---|---|
| C1 | Task tools (`TaskCreate/Update/List/Get`, `TodoWrite`) available to skills and agents | Off on Claude 5 models unless `CLAUDE_CODE_ENABLE_TODO_TOOLS=1`; `TaskCreated`/`TaskCompleted`/`TeammateIdle` are agent-teams hooks; `TeamCreate` removed | `tasks.json` is the task list; validators reject Task tools in `allowed-tools`/`tools` |
| C2 | `/verify` was blitz's gate | `/verify` is a bundled user-only skill that records its recipe to `.claude/skills/verify/SKILL.md` | The gate skill is `check`; `check` reads the recorded recipe |
| C3 | Skills could dispatch any skill | A `disable-model-invocation: true` skill cannot be dispatched by the Skill tool or a scheduled fire | `ship` is slash-only and `next --loop` prints `Ready: /blitz:ship` instead of calling it |
| C4 | Subagent worktrees branch from the current head | They branch from `origin/<default>` unless `worktree.baseRef: "head"` | `build --parallel` and `doctor` check the setting; sequential is the default |
| C5 | Bundled `/code-review`, `/batch`, `/loop`, `/goal`, `/security-review` callable from a plugin | User-only | Blitz prints companion lines and points at them; never invokes them |
| C6 | Hooks run everywhere | Hooks need bash; native Windows without Git Bash fails open; PowerShell needs matcher `Bash\|PowerShell` | Matchers updated; `doctor` warns |
| C7 | Skill descriptions had a generous budget | Listing budget is 1% of the context window, truncated by least-used skill | Descriptions ≤300 chars, triggers first, cumulative cap 8 000 |
| C8 | Per-edit activity logging was the plugin's job | OpenTelemetry exports tool results, commits, PRs, per-skill usage; `/usage` and `/insights` attribute cost | Feed keeps loop and skill events only |

## 3. Evidence table (why the loop looks the way it does)

| Claim | Evidence | v3 mechanism |
|---|---|---|
| "Done" must be structural | Anthropic long-running-agent harness and the Code with Claude 2026 take-home: a hook denies writes to the results file until evidence was read; "asking nicely in the prompt doesn't reliably stop this" | `tasks-guard.sh` + `tasks.sh verify` as the only path to `done` |
| Tests alone are gamed | SpecBench: every frontier model saturates visible tests while failing held-out ones; gap grows ~28 pp per 10× code size | `tasks.sh add` refuses a test-only `verify[]` without `--test-only-ok` |
| Agents over-mock | 1.2M-commit study: 36% of agent commits add mocks vs 26% human | `test-gen` mocking policy; `check:anti-mock` registry row |
| One task per fresh context | Anthropic harness (one feature per session, progress file + git as memory); superpowers SDD (`progress.md` ledger, status enum, never parallel implementers) | `build` spawns one `dev` per task; `progress.md` ledger; status enum |
| Parallel agents conflict | 33,596 agent PRs: cross-agent conflicts 41.7% vs 19.8% intra-agent; 42% structural; defenses that worked were file scoping, worktrees, sequential merge, `merge-tree` | `--parallel` opt-in, disjoint `files`, cap 4, sequential merge with `git merge-tree` |
| Fix loops need a ceiling | superpowers: ≤5 rounds, rounds 4–5 on a stronger model, adjudicate at 5 | attempts counter, opus at rounds 4–5, `blocked` with a ruling |
| Persistent state is memory | OWASP Agentic Top 10 2026 ASI06 (memory poisoning), ASI04 (supply chain) | `startup-validate.sh` scans `tasks.json` and `docs/solutions/`; `origin` provenance; pinned plugin version guidance |
| Compaction erases constraints | Context-rot studies; "governance decay" | HANDOFF carries plan, task, gate path, never-edit list |
| Humans review plans, not generated code | HumanLayer, compound engineering, OpenSpec | `plan` interview and spec approval; `check` and the critic gate the code |
| Multi-agent is rarely worth it | Anthropic 2026 trends report ("doesn't make sense for 95% of tasks"); agent teams ≈7× tokens | Sequential default; Workflow fan-out only for read-only surveys and disjoint waves |
| Re-simplify after each model release | Anthropic harness guidance; `claude plugin eval --ablation with-without` | Rule recorded in `evals/README.md` and here |

## 4. Target model

```
research ──► plan ──► build ──► check ──► ship (slash-only)
                        ▲                    │
                        └── next --loop ◄────┘   one tick = one task
                learn ──► docs/solutions/ ──► read by plan
```

Per initiative: `docs/plans/<slug>/{spec.md, plan.md, tasks.json, progress.md, check-report.md}`; archived by `ship`/`learn` to `docs/plans/archive/`. `tasks.json` schema, `next` rows, and gate arming are specified in `skills/_shared/loop.md`.

## 5. Consumer migration

`/blitz:doctor --migrate` converts `sprints/<n>/stories/*.md` into `docs/plans/sprint-<n>/tasks.json` through `tasks.sh add` (acceptance criteria → `verify[]` where a command can be derived; otherwise a note and `--test-only-ok`), carries active or partial carry-forward entries into `docs/plans/carry-forward/`, removes legacy session records, and re-baselines the ratchet from `sprint` to `ref` + `plan`. The rename table is in `CHANGELOG.md` [3.0.0].

## 6. Known risks

- `tasks.json` and `docs/solutions/` inherit the carry-forward registry's blast radius; the startup scan, the guard, and `origin` are the mitigation.
- Multi-writer conflicts if a dev agent edits `tasks.json` or `progress.md` in a worktree; the never-edit list and main-thread-only rule guard it, and parallel mode requires disjoint `files`.
- `worktree.baseRef` defaults to `fresh` and silently breaks parallel builds; `doctor` and `build` Phase 0 check it.
- Hooks require bash; native Windows without Git Bash fails open. A node rewrite is out of scope.
- The eval suite has never run on a real account; the CI job stays advisory.
- `/goal` and `stop-gate.sh` both fire on Stop; the gate stands down on `stop_hook_active`, but a user `/goal` still counts against the platform's 8-block cap.

## 7. Re-simplification rule

After every model release: run `claude plugin eval . --ablation with-without`, then disable harness pieces one at a time (a guard, the critic survey, the fix-round ceiling) and re-run. Retire any piece whose Δ has gone to zero. The harness is scaffolding for the current model, not doctrine.
