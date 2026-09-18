---
id: E-045
title: "Plugin evals + workflows/ distribution"
status: implemented
implemented_in: "2.5.0"
priority: P2
phase: 3
domain: platform
depends_on: [E-040]
cc_floor: "2.1.269"
estimated_stories: 5
source_research_doc: docs/reviews/2026-09-18_cc-2.1.276-alignment/README.md
registry_entries: []
---

# E-045 Plugin evals + workflows/ distribution

**Why.** `claude plugin eval` (2.1.269) runs a plugin's eval suite and emits a scored, reproducible JSON + HTML report suitable for CI. Plugins can now ship `workflows/*.js` that run as namespaced commands (`/blitz:<name>`), with `args` input and resume replay. blitz's Workflow scripts live inline in SKILL.md prose (sprint-dev §2.3-W, sprint-review §2.2.0-W, audit §1.1-W), so they cannot be saved, diffed, or replayed by the runtime.

## Stories

### S1 Eval suite
- **Files:** new `evals/` (layout and file format confirmed from `claude plugin eval --help` before authoring; the docs show markdown cases with frontmatter `name` / `category`); `.claude-plugin/plugin.json` (`experimental.evals` only if a non-default path is used).
- **Cases (v0):** orchestrator routing (five freeform prompts → expected skill); blocker hooks (`git commit --no-verify` blocked; mass `it.skip` blocked); `/blitz:health` returns HEALTHY on the plugin repo; `/blitz:next` suggests `sprint-plan` on a fixture with no sprints; `/blitz:sessions attention` lists a fixture blocked session (after E-041).
- **Acceptance:** `claude plugin eval . --output json` exits 0 locally with all cases passing.

### S2 CI job
- **Files:** `.github/workflows/ci.yml`.
- **Change:** job `plugin-eval`, `if: ${{ secrets.ANTHROPIC_API_KEY != '' }}`, installs the CLI, runs the eval, uploads JSON + HTML as artifacts. Drop hard-coded counts from step names (overlaps E-047).
- **Acceptance:** job is skipped cleanly on forks without the secret; passes on main.

### S3 Extract plugin workflows
- **Files:** new `workflows/sprint-wave.js`, `workflows/review-fanout.js`, `workflows/audit-sweep.js`; `skills/sprint-dev/SKILL.md` §2.3-W; `skills/sprint-review/SKILL.md` §2.2.0-W; `skills/audit/SKILL.md` §1.1-W; `skills/_shared/agent-orchestration.md` §Workflow Dispatch Contract.
- **Change:** move the script bodies into `workflows/` with `export const meta = {name, description, phases}` as a pure literal; read inputs from `args`; no `Date.now()` / `Math.random()` / `new Date()` (timestamps passed via `args`); respect `CLAUDE_CODE_WORKFLOW_MAX_CONCURRENT_AGENTS`; skills invoke `/blitz:sprint-wave` etc. and keep the Agent() fallback. Document resume replay semantics and the usage-limit pause (2.1.271+).
- **Acceptance:** `node --check workflows/*.js`; a saved run resumes from `/workflows` after a stop.

### S4 Validator coverage
- **Files:** `scripts/validate-plugin-structure.sh`.
- **Change:** §9 `node --check workflows/*.js` and grep-fail on `Date.now|Math.random|new Date()`; §10 `evals/` present → every case file parses.

### S5 Counts
- **Files:** `.claude-plugin/counts.json`, `scripts/check-count-sync.sh`, `README.md` banner.
- **Change:** add `workflows` and `evals` counts.

## Verification
- `validate-plugin-structure.sh && check-count-sync.sh`; CI artifact present.

## Risks
- Eval format is documented sparsely; confirm against the CLI before writing cases.
- Workflows are opt-in per permission mode; `-p` loops need a `Workflow(<name>)` allow rule, which `next --loop` must document instead of forcing `BLITZ_DISPATCH=agent`.
