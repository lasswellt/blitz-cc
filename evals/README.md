# blitz eval suite (`claude plugin eval`, CC ≥2.1.269)

Behavioural regression cases for the plugin, in the layout `claude plugin eval` reads
(`evals/<case>/prompt.md` + `graders/*.md`, optional `case.yaml` for fixtures). Format
reference: https://code.claude.com/docs/en/plugin-evals. Structural checks (`node --check`,
frontmatter lint) live in `scripts/validate-plugin-structure.sh`; this suite covers what the
plugin makes Claude *do*.

| Case | Asserts | Graders | Needs |
|---|---|---|---|
| `orchestrator-routing` | freeform "what's running / who needs input" → `/blitz:sessions` | `tool_used: Skill` (sessions), llm | — |
| `blocker-no-verify` | `git commit --no-verify` is refused by `block-no-verify.sh`; reply says so | regex over trace (`BLOCKED: --no-verify is forbidden`), llm, `tool_used: Bash min 0 max 0` (no hook tampering) | `--scaffold`, `--allow-tools "Bash(git *)"` |
| `health-on-self` | `/blitz:health` on this repo → `Overall: HEALTHY` | `tool_used: Skill` (health), regex, llm | `--allow-tools Bash` |
| `next-suggests-plan` | roadmap + no sprints → `/blitz:next` recommends `/blitz:sprint-plan` | `tool_used: Skill` (next), regex, llm | `--scaffold`, `--allow-tools Bash` |
| `sessions-attention` | one pending `inbox.jsonl` line → `/blitz:sessions attention` lists it | `tool_used: Skill` (sessions), regex, llm | `--scaffold`, `--allow-tools Bash` |

## Run

From the plugin root (target `.` — the plugin under test is auto-detected from the enclosing directory):

```bash
# everything, with fixtures + Bash granted (sandboxed; Linux needs bubblewrap + socat)
claude plugin eval . --trust-plugin --scaffold --allow-tools Bash --json evals/results/run.json

# cheapest smoke: routing only, single arm, one run
claude plugin eval . --tag routing --ablation none --runs 1 --case orchestrator-routing
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
calls per `llm` grader per run. `health-on-self` and `next-suggests-plan` are the expensive
ones (skills that shell out). Use `--runs 1`, `--ablation none`, `--tag`/`--case`, and
`--max-cost-usd` while developing; pin `--model` and `--judge-model` in CI so a model rollout
isn't read as a plugin regression.

## Status: advisory until first real run

The graders were authored from the documented format and the skills' printed contracts; the
suite has **not yet been executed on a real account** (no dry-run/validate-only mode exists in
`claude plugin eval` 2.1.276). Until a run has been reviewed, treat scores as advisory: the CI
job never fails the build on a grader score, only on a crash (exit ≠ 0/1). Expect first-run
tuning of `max_turns`, the llm rubrics, and whether the eval child session loads
`.claude-plugin/settings.json` (`agent: orchestrator`) — if it does not, `orchestrator-routing`
still passes via the sessions skill's own description trigger.

## Authoring notes

- Runs start in an empty throwaway workspace with only this plugin loaded; user settings,
  CLAUDE.md, MCP servers and other plugins are absent. Fixtures come from `fixture.sh`
  (`context.scaffold_script`), which runs as you and only with `--scaffold`.
- `regex` graders default to `target: last_message`; `target: trace` sees JSON-escaped lines.
- `health-on-self` relies on `append_system_prompt` to point Phase 0's cwd-relative
  `./scripts/validate-plugin-structure.sh` at the plugin checkout (the workspace is empty); if the
  first run shows it still resolving against the workspace, that is a health-skill fix, not a
  grader fix.
- New case: `claude plugin eval init --bare <name>` writes the blank template.
