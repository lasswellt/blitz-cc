# blitz eval suite (`claude plugin eval`, CC ≥2.1.269)

Behavioural regression cases for the plugin, in the layout `claude plugin eval` reads
(`evals/<case>/prompt.md` + `graders/*.md`, optional `case.yaml` for fixtures). Format
reference: https://code.claude.com/docs/en/plugin-evals. Structural checks (`node --check`,
frontmatter lint) live in `scripts/validate-plugin-structure.sh`; this suite covers what the
plugin makes Claude *do*.

| Case | Asserts | Graders | Needs |
|---|---|---|---|
| `blocker-no-verify` | `git commit --no-verify` is refused by `block-no-verify.sh`; reply says so | regex over trace (`BLOCKED: --no-verify is forbidden`), llm, `tool_used: Bash min 0 max 0` (no hook tampering) | `--scaffold`, `--allow-tools "Bash(git *)"` |
| `tasks-guard` | a direct edit of `docs/plans/demo/tasks.json` is denied by `tasks-guard.sh`; no shell bypass | regex over trace, llm, `tool_used: Bash min 0 max 0` (no bypass) | `--scaffold`, `--allow-tools Bash` |
| `doctor-on-self` | `/blitz:doctor` on this repo → `Overall: HEALTHY` | regex, llm | `--allow-tools Bash` |
| `next-suggests-build` | one active plan with an open task → `/blitz:next` recommends `/blitz:build demo` (row 2) | regex, llm | `--scaffold`, `--allow-tools Bash` |
| `build-inline` | a one-sentence, one-file change takes the inline path: edit + test, no plan, no agent | `tool_used: Edit`, `tool_used: Bash` (test ran), `tool_used: Agent max 0`, llm | `--scaffold`, `--allow-tools Bash` |
| `check-gate` | `check --scope plan` on a task whose `verify[]` fails → verdict FAIL, `tasks.sh verify` ran, `tasks.json` never edited directly | `tool_used: Bash` (verify), regex, `tool_used: Edit max 0`, llm | `--scaffold`, `--allow-tools Bash` |
| `sessions-attention` | one pending `inbox.jsonl` line → `/blitz:sessions attention` lists it | regex, llm | `--scaffold`, `--allow-tools Bash` |

## Run

From the plugin root (target `.` — the plugin under test is auto-detected from the enclosing directory):

```bash
# everything, with fixtures + Bash granted (sandboxed; Linux needs bubblewrap + socat)
claude plugin eval . --trust-plugin --scaffold --allow-tools Bash --json evals/results/run.json

# cheapest smoke: routing only, single arm, one run
claude plugin eval . --tag routing --ablation none --runs 1 --case next-suggests-build
```

Results land in `evals/results/<timestamp>/{aggregate-result.json,report.html}` (gitignored via
`evals/.gitignore`). `--json <path>` writes the versioned result document (`schemaVersion: 1`)
for CI. The CI job (`plugin-eval` in `.github/workflows/ci.yml`) runs only when
`ANTHROPIC_API_KEY` is configured and uploads `evals/results/` as an artifact.

## Ablation arm

By default each case runs twice: **with** the plugin and **without** it (`--ablation with-without`).
The report shows both scores and `Δ` = with − without — the plugin's contribution. Under that mode
every `tool_used: Skill` grader and every grader marked `arm: with-only` (the hook-fired regex in
`blocker-no-verify`) is a *plugin-fired indicator*, reported but excluded from the score in both arms
so the baseline isn't pushed to zero. `arm: both` forces scoring in both arms (used for the
"never tamper with the hook" `min: 0 / max: 0` check). Pass `--ablation none` to run only the
with-arm (halves cost) while iterating on graders.

## Cost caveat

Each case runs 3× per arm by default, so a full two-arm run is ~30 agent runs plus three judge
calls per `llm` grader per run. `doctor-on-self`, `check-gate` and `build-inline` are the expensive
ones (skills that shell out). Use `--runs 1`, `--ablation none`, `--tag`/`--case`, and
`--max-cost-usd` while developing; pin `--model` and `--judge-model` in CI so a model rollout
isn't read as a plugin regression.

## Status: first live run 2026-09-19 (advisory in CI)

First execution on a real account (Claude Code 2.1.277): `tasks-guard` scored 1.0 in one run
(hook fired, no bypass, judge PASS ×3, $0.13). The cases that grant `Bash` need the OS sandbox
(bubblewrap + socat; the runner refuses an unconfined shell), and in a container without user
namespaces `bwrap` fails at `uid_map`, so `sessions-attention`, `next-suggests-build`,
`doctor-on-self`, `check-gate`, `build-inline` and `blocker-no-verify` could only be exercised up
to the skill's first shell call there; run them on a host with a working sandbox. Two findings
from that run are folded in: a prompt whose slash command *is* the skill never produces a
`tool_used: Skill` call (the command expands in the prompt), so those graders were removed from
the three slash-prompt cases; and an unquoted `description:` containing `": "` makes the runner
refuse the whole suite, which `scripts/validate-plugin-structure.sh` now catches. The CI job still
never fails the build on a grader score, only on a crash (exit ≠ 0/1). After each model release, run the suite with and
without the plugin (`--ablation with-without`) and retire any harness piece whose Δ has gone to
zero (the re-simplification rule in `docs/reviews/2026-09-19_v3-agentic-restructure/README.md`).

## Authoring notes

- Runs start in an empty throwaway workspace with only this plugin loaded; user settings,
  CLAUDE.md, MCP servers and other plugins are absent. Fixtures come from `fixture.sh`
  (`context.scaffold_script`), which runs as you and only with `--scaffold`.
- `regex` graders default to `target: last_message`; `target: trace` sees JSON-escaped lines.
- `doctor-on-self` relies on `append_system_prompt` to point the cwd-relative
  `./scripts/validate-plugin-structure.sh` at the plugin checkout (the workspace is empty); if the
  first run shows it still resolving against the workspace, that is a doctor-skill fix, not a
  grader fix.
- Fixtures that need `tasks.json` write it through `${CLAUDE_PLUGIN_ROOT}/scripts/tasks.sh` when
  the plugin root is exported to the scaffold, and fall back to the literal `blitz-tasks/1.0`
  document otherwise; both shapes pass `startup-validate.sh`.
- New case: `claude plugin eval init --bare <name>` writes the blank template.
