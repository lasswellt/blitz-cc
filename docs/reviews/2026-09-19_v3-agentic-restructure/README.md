---
title: "blitz-cc v3 review — strip the sprint layer, keep the agentic harness"
date: 2026-09-19
status: implemented
plugin_version_reviewed: 2.5.0
plugin_version_shipped: 3.0.1
validation_round: 2026-09-19 (docs re-fetched, field evidence Jun–Sep 2026, contract audit)
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
| C2 | `/verify` was blitz's gate | `/verify` is a bundled skill with `disable-model-invocation`; it records its recipe to `.claude/skills/verify/SKILL.md`, and at the repo root that recorded skill replaces the bundled one (≥2.1.200) | The gate skill is `check`; `check` reads the recorded recipe |
| C3 | Skills could dispatch any skill | A `disable-model-invocation: true` skill cannot be dispatched by the Skill tool, preloaded into a subagent, or run by a scheduled fire (≥2.1.196; the bundled `/verify` included) | `ship` is slash-only and `next --loop` prints `Ready: /blitz:ship` instead of calling it |
| C4 | Subagent worktrees branch from the current head | They branch from `origin/<default>` unless `worktree.baseRef: "head"` | `build --parallel` and `doctor` check the setting; sequential is the default |
| C5 | Bundled `/code-review`, `/batch`, `/loop`, `/goal`, `/security-review` callable from a plugin | Some are: the docs name `/init` and `/security-review` as available through the Skill tool; `/compact` and the like are not, and `/verify` is slash-only. `/loop` and `/goal` are session controls, not skills to call | Blitz prints companion lines for `/loop` and `/goal`; `check --security` may call `/security-review` through the Skill tool when it is present |
| C6 | Hooks run everywhere | Hooks need bash; native Windows without Git Bash fails open; PowerShell needs matcher `Bash\|PowerShell` | Matchers updated; `doctor` warns |
| C7 | Skill descriptions had a generous budget | Each skill's `description` plus `when_to_use` is truncated at 1,536 characters in the listing; every listed skill costs context on every turn | Descriptions ≤300 chars, triggers first, cumulative cap 8 000 |
| C8 | Per-edit activity logging was the plugin's job | OpenTelemetry exports tool results, commits, PRs, per-skill usage; `/usage` and `/insights` attribute cost | Feed keeps loop and skill events only |
| C9 | Stop hooks may block 8 times in a row; `max_blocks: 6` stays under it | The cap is **5** (`stopHookBlockCap`, `CLAUDE_STOP_HOOK_BLOCK_CAP`); `/goal` and prompt-type Stop hooks count against it | `max_blocks` defaults to 4 and is clamped there (3.0.1) |
| C10 | `.claude/loop.md` assumed | Confirmed: project then user scope, 25,000-byte cap, edits apply next iteration; self-paced `/loop` ends with `ScheduleWakeup stop:true` or one ~20-minute fallback wake | `doctor --loop-md`; `next` row 5 |
| C11 | Plugin pinning by SHA is enough | Plugin4Shell (Sep 18, 2026): git resolves hash-shaped branch names as refs, so a SHA-pinned plugin from a non-GitHub source could be swapped; fixed in 2.1.179; GitHub-hosted marketplaces immune; `--accept-command <sha256>` (2.1.269), npm `--ignore-scripts` + integrity (2.1.275) | `security.md` §Supply chain; floor ≥2.1.271 already covers the fix |
| C12 | `PostCompact` could restore constraints | `PostCompact` cannot inject context; `SessionStart` fires with `source: compact` | `session-start.sh` re-pins gate path, never-edit list, and mock policy from HANDOFF on compaction (3.0.1) |

## 3. Evidence table (why the loop looks the way it does)

| Claim | Evidence | v3 mechanism |
|---|---|---|
| "Done" must be structural | Anthropic long-running-agent harness and the Code with Claude 2026 take-home: a hook denies writes to the results file until evidence was read; "asking nicely in the prompt doesn't reliably stop this" | `tasks-guard.sh` + `tasks.sh verify` as the only path to `done` |
| Tests alone are gamed | SpecBench (May 2026): every frontier model saturates visible tests while failing held-out ones; gap grows ~28 pp per 10× code size. Building to the Test (Jun): near-perfect scores against a hidden Playwright oracle while the library was dead. SpecPath (Aug): 35/100 passing blocks fail a contract-equivalent spec revision. Hacker-Fixer Loops (Jun): 16% of benchmark tasks hackable | `tasks.sh add` refuses a test-only `verify[]` without `--test-only-ok`; the reject critic authors one held-out check per task; registry `check:test-tamper` flags oracle edits (3.0.1) |
| Agents over-mock | 1.2M-commit study: 36% of agent commits add mocks vs 26% human | `test-gen` mocking policy; `check:anti-mock` registry row |
| One task per fresh context | Anthropic harness (one feature per session, progress file + git as memory); superpowers SDD (`progress.md` ledger, status enum, never parallel implementers) | `build` spawns one `dev` per task; `progress.md` ledger; status enum |
| Parallel agents conflict | 33,596 agent PRs: cross-agent conflicts 41.7% vs 19.8% intra-agent; 42% structural; defenses that worked were file scoping, worktrees, sequential merge, `merge-tree` | `--parallel` opt-in, disjoint `files`, cap 4, sequential merge with `git merge-tree` |
| Fix loops need a ceiling | superpowers 6.4.1 (Sep 19, 2026): rounds 1–3 resume the same implementer, 4–5 fresh on a stronger model, adjudicate at 5, rulings ledgered, "cannot verify from diff" is a first-class reviewer answer | attempts counter, `SendMessage` resume for rounds 1–3, opus at 4–5, `blocked` with a ruling; survey critic `cannot_verify[]` resolved by `check` (3.0.1) |
| Persistent state is memory | OWASP Agentic Top 10 2026 ASI06 (memory poisoning), ASI04 (supply chain) | `startup-validate.sh` scans `tasks.json` and `docs/solutions/`; `origin` provenance; pinned plugin version guidance |
| Compaction erases constraints | Governance Decay (Jun 2026, 1,323 episodes, seven model families): violations 0% with the full policy, 30–59% after compaction, back to 0% when the constraint is pinned through summarization | HANDOFF carries plan, task, gate path, never-edit list; `session-start.sh` re-emits them on `source: compact` (3.0.1) |
| Humans review plans, not generated code | HumanLayer, compound engineering, OpenSpec | `plan` interview and spec approval; `check` and the critic gate the code |
| Multi-agent is rarely worth it | Platform docs: agent teams ≈7× tokens when teammates run in plan mode, single session or subagents for sequential work and same-file edits; AgentRoom (Aug 2026): coordination, not parallelism, carries the gain. The "95% of tasks" line attributed to the trends report could not be verified in the primary and is withdrawn | Sequential default; Workflow fan-out only for read-only surveys and disjoint waves |
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
- `/goal` and `stop-gate.sh` both fire on Stop; the gate stands down on `stop_hook_active`, and `max_blocks` is 4, but a user `/goal` shares the platform's 5-block `stopHookBlockCap`, so a long `/goal` session can exhaust the cap before the gate does.

## 7. Validation round (2026-09-19)

Three vectors, all read-only before the fixes: the platform claims above re-fetched from code.claude.com (2.1.277 still current), field evidence newer than the sources first cited, and a contract audit across scripts, skills, agents, workflows, and evals. Outcome: every design claim confirmed or strengthened; four platform rows corrected (C5, C7, C9 and the `/verify` wording in C2); one quote withdrawn (the "95%" line); five contract blockers found, two of which meant the loop did not run as documented (the `build-wave` args shape threw on every `--parallel` dispatch; `next --loop` never ran `build` autonomously). All are fixed in 3.0.1 with bats coverage (`workflows.bats`, breaker override, `created` ordering, compaction pin).

Not adopted, with reasons: a TDAD-style AST impact map (the selector's sibling + import graph covers the common case; TDAD's gains are on small open-weight models with no frontier replication); CRDT workspaces (AgentRoom's gain came from file claims, which `files[]` scoping already gives); per-task token accounting in `tasks.json` (`/usage` attributes cost per skill and subagent); wrapping `/goal` inside the plugin (a plugin cannot invoke it; the gate stands down for it and `next` prints the line).

## 8. Re-simplification rule

After every model release: run `claude plugin eval . --ablation with-without`, then disable harness pieces one at a time (a guard, the critic survey, the fix-round ceiling) and re-run. Retire any piece whose Δ has gone to zero. The harness is scaffolding for the current model, not doctrine.
