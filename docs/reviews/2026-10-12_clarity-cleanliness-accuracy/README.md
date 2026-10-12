---
title: "blitz-cc clarity, cleanliness and accuracy review"
date: 2026-10-12
status: implemented (defect-class and mechanical findings); open items below
plugin_version_reviewed: 3.15.1 at 5c820b8
cc_version_reviewed_against: 2.1.296
---

# Clarity, cleanliness and accuracy review

Every tracked file in the plugin was read in full (skills and their references, agents, shared protocols, hooks and their tests, scripts, workflows, the mod, evals, templates, the top-level docs and the `docs/` tree). Eight reviewers covered disjoint areas and cross-checked every path, flag, env var, section citation, registry id, model alias, version number and numeric claim against the code that is supposed to back it. Each finding was verified against the tree before it was accepted; a handful were refuted (notably "`force-for-plugin` has no mechanism": the key is present in the 2.1.296 CLI bundle, so the forced output style stands).

Baseline before the review: every validator green, `bats hooks/tests/` 355/355. After: every validator green, 361/361 (six new cases).

## What was wrong, in themes

| Theme | Examples |
|---|---|
| Guards that did not guard | `block-test-deletion.sh` never fired on a Write that stripped every assertion (`grep -c … \|\| echo 0` yielded `"0\n0"`, the arithmetic test errored and the call was allowed); the same script ignored `tool_name: PowerShell` despite its matcher. |
| Loop hand-offs that could not complete | `next --loop` row 4 archives the plan, then prints `Ready: /blitz:ship`, but `ship` looked only under `docs/plans/<slug>/`; `next`'s inbox triage keyed on `permission_denied` while the hooks write `permission`, so a permission line stayed pending and every later tick deferred; `ship --dry-run` committed, then tried a `git checkout -- .` that blitz's own hook denies. |
| Contracts that contradicted their parser | `dev` and `critic` were told to print a `STATUS:`/`VERDICT:` line before the JSON that `build` parses with `jq`; `test-writer` escalated with a `blocked_reason` `tasks.sh` rejects; `critic.md`'s detector block labelled four registry ids wrong, promoting advisory rows to reject findings. |
| Instructions that silently neutered a check | `plan`'s template rule told the model to write `\|` inside `grep -E` alternations (a literal pipe in ERE), so every `grep_absent` verify check always passed; `research` wrote the synthesized doc under a timestamp name no reader looked for; `doctor --verify-recipe` emitted `npm run testvitest run`. |
| Inverted or unsupported claims | README and the hook index said the guards fail open without bash (they fail closed and refuse every call); "every disable flag logs its use" (one does); the JVM toolchain row named lanes that do not exist; `tasks.sh add` refused test-only tasks only for JS/Python/Go/Rust runners while the README called the loop polyglot. |
| Drifted citations | "sessions.md §Session Registration (steps 1-9)" in eleven skills (the preamble is §2, seven steps); sections cited in a contract file that live in its `.reference.md`; `spawn-protocol §8` (a removed file); anchors in `security.md` that exist only in its reference; research documents cited that are not in the tree. |
| Retired protocol remnants | HEARTBEAT/PARTIAL markers, "autonomy = full", v2 session-cleanup blocks, a `worktree-create` hook, `developer-profile.json`, truncated OUTPUT STYLE fragments pasted mid-sentence into agent prompts. |
| Tooling blind spots | the link validator did not check anchors and exited 1 in hook mode on a broken link; the catalog check depended on the caller's locale; the section-citation checker scanned only skills, agents and workflows. |

## Fixed in this review

Code (each with a bats case where one was missing):

- `hooks/scripts/block-test-deletion.sh`: Write branch count bug; `Bash|PowerShell` case.
- `hooks/scripts/markdown-link-validate.sh`: heading-anchor resolution (GitHub slugs, same-file `#anchor` links); `set -e` no longer skips the hook-mode `exit 0`; `HOOK_MODE` exported.
- `hooks/scripts/session-start.sh`: runs `startup-validate.sh` on every `SessionStart`, as TB-2 and the hook index claimed.
- `hooks/scripts/stop-gate.sh`: `timeout` fallback for hosts without GNU coreutils; `max_blocks` fallback 4.
- `hooks/scripts/critic-external.sh`: single-provider replies expose `findings[]` as `issues[]`.
- `hooks/hooks.json`: `markdown-link-validate.sh` unwired as its own hook (it ran twice per commit and once per Bash call through `pre-commit-validate.sh`).
- `scripts/tasks.sh`: test-runner regex covers rspec, dotnet, mix, gradle, mvn, deno, swift, phpunit, mocha, `node --test`, bun; `--help` exits 0 and prints the whole block; `next` usage text; `tail_out` naming.
- `scripts/gen-catalog.sh`: character-based truncation through python3 (locale independent); unknown argument is a usage error; `ci-local.sh` workaround removed.
- `scripts/check-section-refs.sh`: scans hooks, rules, README, SECURITY and the hook index; exits 2 without python3.
- `scripts/check-version-sync.sh`: compares the marketplace's `blitz-guard` entry with the mod manifest; `compat.json` `cited_in` deduplicated and widened.
- `scripts/detect-stack.sh`, `scripts/toolchain.sh`, `scripts/gen-review-md.sh`, `scripts/skill-scan.sh`: header and usage drift.
- `.github/workflows/ci.yml`: `command -v bats || { apt … }` precedence; stale version in a comment.

Contracts and prose (the full list is in the CHANGELOG `[Unreleased]` entry):

- Shared protocols: `loop.md` (inbox writers, `last_verify` shape, `progress.md` enforcement, fix-round gating), `loop.reference.md`, `sessions.reference.md` (inbox kinds, `HANDOFF.json` fields, kill-switch marker, dropped `worktree_create`), `quality.md`/`quality.reference.md` (`runs[]`, pillar enum, block cap, registry size, orthogonal rows), `security.md`/`security.reference.md` (anchors, `origin` enum, floor), `agents.md`/`agents.reference.md` (preload claim), `output.reference.md`, `design-criteria.md`, `spawn-invariant.md` untouched.
- Rules: `.claude/rules/skills.md`, `.claude/rules/hooks.md`, `.claude/CLAUDE.md` (dead section citations, roster, validator flag).
- Agents: `critic.md` (registry ids, reply contract, `BLITZ_DUAL_CRITIC` row), `dev.md` (reply contract), `test-writer.md` (`hard_spec`, `INVESTIGATE:`), `research-critic.md` (frontmatter parsers that parsed the body, orphan fragment, citations), `design-critic.md`.
- Skills: every SKILL.md and most references; the loop hand-offs above; `build` wave branch per task and the `git log --grep` lookup; `check` registry ids and `bash`-prefixed script calls that match the grants; `audit` retry and threshold contradictions, Heavy class, duplicate report template; `browse` tool list, waits, placeholder list, autonomy wording; `dep-health` fence, `npm update` semantics, report mode; `doc-gen` `!cat` line, team wording, weight class, placeholder output; `doctor` grants, D-104/D-201/D-308 text, verify-recipe expansion, conflict catalog; `learn` preamble; `migrate` `--resume`, failure rules, stale Node table, `@vue/compat`; `next` flags, env wording, triage kinds, conditional gate; `onboard` grants, map-mode rule, pin, scaffold `services/items.ts`, LSP ladder; `perf-profile` thresholds, `nuxi analyze`, INP, cleanup; `plan` literal script paths, the `\|` rule; `refactor` checkpoint, find command; `sessions` dashboard sections; `ship` archived plans, `--dry-run`, hint, toolchain row; `test-gen` `mocks_in_src`, `stubActions`, async timers, `importActual`; `todo` grants; `ui-audit` safety carve-outs, `PAGE` variable, guarded invariant evaluator, report collector, flags, autonomy vars, Playwright parameters, config schema; `ui-build` state order; `ui-audit` catalog headers.
- Docs: README (fence, fail-closed, JVM row, flags, hook table, prices, Contributing, layout), SECURITY (critic shell, external critic modes, TB-4 scope, `verify[]`, Windows), hook index (every drifted row, env inventory, two missing rows), `docs/EPICS.md`, `docs/research/README.md`, both guides, `evals/README.md`, `.ui-audit.json.example`, `.gitignore`, the mod README, historical banners on the containment and impeccable specs.

## Open items (judgment calls, not changed)

| # | Item | Where | Recommendation |
|---|---|---|---|
| 1 | `build` hard-codes `npx tsc` / `npx vitest` / `npm run` in its gate, `T.1` and `I.x` steps while `check` resolves gates through `toolchain.sh`; the plugin calls the loop language-agnostic | `skills/build/SKILL.md` §Gate, `references/main.md` | resolve the gate `cmd` from `toolchain.sh resolve typecheck`; keep the vitest selector only when `toolchain.sh stacks` includes `node` |
| 2 | `progress.md` is on the never-edit list but no hook denies it (now documented as prose-only) | `skills/_shared/loop.md` §Structural rules | extend `tasks-guard.sh` to deny `docs/plans/*/progress.md` from subagent context (`agent_type` is on stdin) |
| 3 | `browse` grants cover none of what the skill does (curl, Playwright, source edits in `fix`, commits in loop mode) | `skills/browse/SKILL.md` | grant `Edit(docs/crawls/**)`, `Bash(git status *)`, `Bash(git --no-pager log *)`; the rest follows the permission mode, which the body now says |
| 4 | `audit` phase numbering carries two schemes (`2.1.4 … (Phase 2.0)`, `2.3.5 … (Phase 2.5)`), `§1.1-W` precedes `§1.1`, and both `audit` and `check` references have their "moved from SKILL.md" blocks out of phase order | `skills/audit/SKILL.md`, both `references/main.md` | renumber sequentially and reorder the moved blocks |
| 5 | `ui-audit`: STALE and FLAPPING have the same rule with a three-entry history; three finding-label exclude sets drift between §3.1, §4.2 and the shared reducer; Playwright MCP parameter names should be re-verified against the installed server; epic ids (E-/S-/CAP-) remain in comments; Phase 7 sits before Phase 6 | `skills/ui-audit/references/main.md` | define the exclude set once as a jq `def is_obs`; extend history to four entries or drop STALE |
| 6 | `ui-build`: the inline aesthetic greps in the Implementation Gate are "superseded" by `check --only design` but still gate; `design_quality` in `tasks.json` `notes` has no convention in `loop.md`; `design-critic` verdict semantics (ITERATE/REWORK) differ from `ui-build`'s bounded iteration policy | `skills/ui-build/SKILL.md`, `agents/design-critic.md` | replace the greps with `check --only design`; define the `notes` convention in `loop.md`; state in `design-critic` §3 that the verdict is advisory and `ui-build` §5.4.2 owns the policy |
| 7 | `dev.md` asks for minimum code and no abstractions for one call site, then mandates JSDoc on every export and a try/catch wrapper on every fallible function | `agents/dev.md` | scope the JSDoc and try/catch sections to "when the role conventions or the project require it" |
| 8 | `test-writer` is registered everywhere but no skill spawns it; its description says `test-gen` and `build` do | `agents/test-writer.md` | either spawn it from `test-gen` Phase 3 or reword the description to "read by `dev` (ROLE: test) spawns" |
| 9 | Feed lines in `block-no-verify.sh`, `block-test-disabling.sh`, `block-as-any-insertion.sh` and `HANDOFF.json` in `pre-compact-snapshot.sh` are built with `printf`/heredoc; a quote in a path or `until` label corrupts the line | `hooks/scripts/*` | build them with `jq -n --arg` through `blitz_log_event` |
| 10 | No bats suite for `pre-edit-guard.sh` (block and pass-through), `pre-commit-validate.sh`, `blitz-prompt-expansion.sh`, `config-change.sh`, `post-edit-test.sh`, `pre-compact-snapshot.sh`, `startup-validate.sh`, `stop-failure.sh`, `agent-frontmatter-validate.sh`; `test-selector.bats` uses GNU-only `grep -P` | `hooks/tests/` | add the suites the hook contract requires; `grep -E $'\t'` for the tab |
| 11 | `pre-commit-validate.sh` sits in the BLOCKING table but is not a `blitz_guard_input` guard and exits 0 on unreadable input (now documented) | `hooks/scripts/README.md` | either add `onFailure: block` plus `blitz_guard_input` and a bats case, or keep it advisory on bad input as now |
| 12 | `heartbeat.sh` logs a `post_tool_batch` feed event on every batch, which the feed schema does not list and the retention rule will have to prune | `hooks/scripts/heartbeat.sh:259` | drop the event or document it |
| 13 | `BLITZ_INJECTION_RX` matches `system:` inside `filesystem:` and `ecosystem:` | `hooks/scripts/_lib/common.sh:25` | `(^\|[^a-z])system:` |
| 14 | Registry metadata is stale (`detector_count.whole_registry` 96 vs 97 rows, 16 vs 17 reject; design "47 rows" vs 60) and the validator does not check the `pillar`, `severity`, `consolidated_target` or `stacks` enums | `skills/_shared/check-registry.json`, `check-registry-validate.sh` | compute the counts in the validator and assert the enums |
| 15 | v3.15.1 (and v3.0.0 to v3.5.1, v3.10.0 to v3.13.1) were never tagged; the README badge shows 3.15.0 and `ship` promises tags | GitHub releases | tag and release 3.15.1; add to "Release process" that a version is released when its tag exists |
| 16 | impeccable attribution: the ATTRIBUTION.md merge-gate checklist is unchecked, no CI step enforces it, and the 41 vendored registry rows carry no `source` tag naming impeccable | `docs/integrations/impeccable/ATTRIBUTION.md`, the registry | add `"source": "impeccable@2.3.2 (Apache-2.0, see ATTRIBUTION.md)"` to the vendored rows and a one-line grep in `ci.yml` |
| 17 | `stop-gate.sh` executes `gate.json` `checks[].cmd` and `tasks.sh verify` executes `verify[]`; both are TB-1 exceptions that `security.reference.md` does not list | `skills/_shared/security.reference.md` | add the exception with its justification (both files are written only by blitz and scanned first) |
| 18 | `output_intensity` frontmatter: the protocol says skills SHOULD declare it, none does and the validator does not know the field | `skills/_shared/output.md` §Intensity | drop the SHOULD or add the field to the validator's optional set |
| 19 | `cc_min_slash` in `compat.json` is referenced by no skill; every SKILL.md pins `>=2.1.296` | `.claude-plugin/compat.json` | use it for `ship` and `migrate` or delete it |
| 20 | About 2,600 em-dashes across the shipped prose (skills, agents, protocols, hooks, README) | repo-wide | a style decision; a mechanical sweep is one `sed` pass but touches nearly every file |
| 21 | Smaller cleanliness items from the reviews: `validate-plugin-structure.sh` section numbering and GNU-only flags; `tasks.sh` GNU-only `mktemp -p`/`timeout` and unvalidated `--status`; `stop-gate.sh`/`heartbeat.sh` temp files without an EXIT trap; `subagent-context.sh` and `post-edit-typecheck-block.sh` use `set -uo` without a comment; `CATALOG.md` descriptions cut mid-word; `CHANGELOG-ARCHIVE.md` links a removed `knowledge-protocol.md`; `effectiveness-research.md` `maps_to` names removed files; the impeccable docs count "8" | various | batch in a cleanliness release |

## Behaviour changes to be aware of

- Every `SessionStart` now runs `startup-validate.sh` (advisory, non-blocking; findings print into context).
- `tasks.sh add` now refuses a test-only `verify[]` for Ruby, .NET, JVM, Elixir, Deno, Swift, PHP, mocha, `node --test` and bun runners unless `--test-only-ok` is passed; existing plans are unaffected, new tasks in those stacks need a non-test check.
- `markdown-link-validate.sh` checks heading anchors; a link to a heading that does not exist now fails CI.
- `build` and `next` arm the Stop gate's `tests` check only when the selector returned something.
- The reject critic and `dev` reply with the JSON block only (no `VERDICT:`/`STATUS:` line).

## Verification

`scripts/ci-local.sh`: every gate green (the Cisco scanner and the token-count step skip here as in any checkout without the tool or a credential). `bats hooks/tests/`: 361/361 under `CI=true`. `claude plugin validate` on the marketplace manifest passes. Reviewer working notes (one file per area, with the longer "verified OK" lists) were kept out of the tree; this file and the CHANGELOG entry are the record.
