<div align="center">

```
   ─── ⚡ ──────────────────────────────────

   ██████╗ ██╗     ██╗████████╗███████╗
   ██╔══██╗██║     ██║╚══██╔══╝╚══███╔╝
   ██████╔╝██║     ██║   ██║     ███╔╝
   ██╔══██╗██║     ██║   ██║    ███╔╝
   ██████╔╝███████╗██║   ██║   ███████╗
   ╚═════╝ ╚══════╝╚═╝   ╚═╝   ╚══════╝

   ──────────────────────────────── ⚡ ───
```

**A holistic-machine Claude Code plugin for Vue/Nuxt + Firebase**

**37 skills** · **10 agents** · **37 hook scripts across 16 events** · **29 shared protocols**

Orchestrator main-thread agent · 7 anti-shortcut hooks · 8-invariant quality ratchet · optional Cross-Model Critic

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude Code Plugin](https://img.shields.io/badge/Claude_Code-Plugin-blue)](https://docs.anthropic.com/en/docs/claude-code)
[![Version](https://img.shields.io/github/v/release/lasswellt/cc-plugin-suite?color=cyan)](https://github.com/lasswellt/cc-plugin-suite/releases)

</div>

---

## What is Blitz?

Blitz turns Claude Code into an opinionated, partly-autonomous development environment for Vue/Nuxt + Firebase projects. Concretely, it ships:

- **A freeform orchestrator** — `agents/orchestrator.md` is wired as the plugin's main-thread agent. It receives natural-language input, reads `.cc-sessions/HANDOFF.json` + recent activity, and routes to the right `/blitz:*` skill. Slash commands bypass it.
- **A research-to-release pipeline** — `/blitz:research` produces quantified `scope:` claims; `/blitz:sprint` chains plan → implement → review; `/blitz:ship` runs the release gates. Every scope claim is tracked across sprints in an append-only carry-forward registry that prevents silent drops.
- **Quality gates that cannot be silently bypassed** — six `PreToolUse` blockers and one `PostToolUse` typecheck ratchet stop `--no-verify`, destructive git/SQL, test deletion, `as any` insertion, disabled tests, and type-error regressions at the tool boundary. Each returns `exit 2` with an explicit override path.
- **An adversarial critic** — `agents/critic.md` runs a 20-detector shortcut taxonomy + ratchet + acceptance checks + hallucinated-symbol spot-check before any sprint can reach `PASS`. Optionally routed to a different model family (Gemini) for blindspot coverage.

It's designed so that `/loop /blitz:next --loop` produces shippable code unattended.

> Current version: **v1.16.0** (2026-05-28) — see [CHANGELOG.md](CHANGELOG.md).

---

## Reading Tiers

| Audience | Read |
|---|---|
| **Evaluating Blitz** | [What is Blitz?](#what-is-blitz) · [Quick Start](#quick-start) · [The Blitz Cycle](#the-blitz-cycle) |
| **Installing for daily use** | [Quick Start](#quick-start) · [Supported Stacks](#supported-stacks) · [Skill Catalog](#skill-catalog-37) · [Anti-shortcut Blockers](#2-anti-shortcut-blockers) |
| **Contributing or forking** | [Architecture](#architecture) · [Hook Reference](#hook-reference-37-scripts-16-events) · [Shared Protocols](#shared-protocols-29) · [Sprint-review Invariants](#3-sprint-review-invariants-8) |

---

## Quick Start

```bash
npx blitz-cc@latest
```

The installer detects your stack, registers the plugin, configures permissions, and sets up hooks.

<details>
<summary><b>More install options</b></summary>

**Non-interactive:**
```bash
npx blitz-cc@latest --yes
```

**Bash fallback** (no Node.js — minimal install; skips stack detection + agent copy):
```bash
curl -fsSL https://raw.githubusercontent.com/lasswellt/cc-plugin-suite/main/installer/install.sh | bash
```

**From the marketplace:**
```bash
/plugin marketplace add lasswellt/cc-plugin-suite
/plugin install blitz@blitz
```

**Local development:**
```bash
claude --plugin-dir ./blitz
/reload-plugins   # hot-reload after edits
```

</details>

### First five minutes

```bash
/blitz:next                       # reads state, recommends the next command
/blitz:ask "I want to add X"      # routes a vague request to the right skill(s)
/blitz:research <topic>           # parallel-agent investigation → docs/_research/
/blitz:sprint                     # full cycle: plan → implement → review
/blitz:ship                       # gates → release → publish
```

Or just type freeform — the orchestrator routes for you.

### Prerequisites

- **Claude Code** ≥ v2.1.71 (orchestrator main-thread agent requires ≥ 2.1.117)
- **bash**, **Node.js / npx** ≥ 18.0.0, **python3**, **jq**

---

## Supported Stacks

| Layer | Supported |
|---|---|
| **Frameworks** | Vue 3 (Vite), Nuxt 3 |
| **UI** | Tailwind, Quasar, Vuetify *(auto-detected)* |
| **Backend** | Firebase / GCP, Cloud Functions v2 |
| **State** | Pinia, VueFire |
| **Testing** | Vitest, Jest |
| **Workspaces** | pnpm, Nx, Turborepo |

`scripts/detect-stack.sh` runs on every skill invocation; results cache to `.cc-sessions/stack-profile.cache` for 1 hour.

---

## The Blitz Cycle

```
/blitz:research <topic>
        │ writes docs/_research/YYYY-MM-DD_<slug>.md with `scope:` YAML
        │ research-critic verifies cited URLs + quoted spans (Phase 3.2.5)
        ▼
/blitz:sprint
        │ auto-detects uningested research, chains roadmap extend
        ▼
  roadmap extend  → seeds epic-registry.json + carry-forward.jsonl
        ▼
  sprint-plan    → stories with dependency ordering, GitHub issues
        ▼
  sprint-dev     → parallel builder agents in isolated worktrees
        ▼
  sprint-review  → 5 auto-gates + 4 reviewer agents + critic + 8 invariants
        ▼
/blitz:ship      → review --only completeness → quality-metrics → release → PushNotification
```

### Autonomous loop

```bash
/loop 5m /blitz:next --loop
```

`/blitz:next --loop` (canonical since v1.13.0) is the project-lifecycle reconciliation engine. Each tick reads current state, walks an 8-row decision tree, dispatches **exactly one phase**, commits/pushes, and exits cleanly so `/loop` or `ScheduleWakeup` can re-tick. It emits stop signals so wrappers know when to halt:

| Signal | Meaning |
|---|---|
| `LOOP_DONE` | Idle — nothing to reconcile. External `/loop` may halt. |
| `LOOP_ESCALATE` | A carry-forward entry rolled over ≥3 sprints. Human review required. External `/loop` should halt. |
| `LOOP_DEFER` | Active session conflict — keep ticking; the next tick may resolve it. |
| *(no marker)* | Phase dispatched; next tick re-evaluates. |

`PreCompact` writes `.cc-sessions/HANDOFF.json` (sprint, phase, branch, head SHA, recent files, resume hint). `SessionStart` detects a fresh handoff (≤24h) and resumes without re-reading every protocol. `/loop /blitz:sprint --loop` continues to work as a backwards-compat alias that dispatches to `/blitz:next --loop`.

---

## The Holistic Machine

Four layers turn the skill suite into a partly-autonomous development environment. Slash commands still work unchanged.

### 1. Orchestrator (freeform-input router)

`agents/orchestrator.md` is wired as the plugin's main-thread agent via `.claude-plugin/settings.json`:

```json
{ "agent": "orchestrator" }
```

The orchestrator is **read-only by construction** (its `allowed-tools` is `Read, Grep, Glob, Bash, TaskCreate, TaskUpdate, TaskList, Monitor` — no Write, no Edit, no Agent). Claude Code's subagents-cannot-spawn-subagents constraint means any skill that spawns parallel agents (sprint-dev, sprint-plan, research, audit, …) stays slash-invoked. See [`skills/_shared/agent-routing.md`](skills/_shared/agent-routing.md).

```bash
# Opt out per session
export BLITZ_DISABLE_ORCHESTRATOR=1
```

### 2. Anti-shortcut blockers

Six `PreToolUse` hooks plus one `PostToolUse` typecheck ratchet block common shortcut shapes at the tool boundary. Each returns `exit 2` with an explicit override path.

| Shortcut | Hook | Override |
|---|---|---|
| `git commit --no-verify` / `--no-gpg-sign` | `block-no-verify.sh` | `BLITZ_OVERRIDE_NO_VERIFY=1` (logged) |
| On dirty tree: `git reset --hard`, `checkout -- .`, `clean -fd`, `restore .`, force-push to main, `branch -D` current | `block-destructive-git.sh` | None — use a less destructive command |
| `DROP TABLE` / `TRUNCATE` / `DELETE FROM` without `WHERE` outside `migrations/` | `block-destructive-sql.sh` | Move to a versioned migration file |
| `rm` of test files, renames test→non-test, empty Write to test | `block-test-deletion.sh` | None — pin the failing test |
| `as any` / `@ts-ignore` / `@ts-nocheck` in non-test source | `block-as-any-insertion.sh` | `// blitz:any-allowed: <reason>` · `BLITZ_DISABLE_AS_ANY_BLOCK=1` |
| `.skip(` / `.only(` / `xit` / `xdescribe` / `test.todo(` in tests | `block-test-disabling.sh` | `// blitz:skip-pinned: #<issue>` · `BLITZ_DISABLE_TEST_DISABLING_BLOCK=1` |
| Type-error count rise (`tsc --noEmit`) | `post-edit-typecheck-block.sh` | Rebaseline after a real cleanup · `BLITZ_DISABLE_TYPECHECK_BLOCK=1` |

### 3. Sprint-review invariants (8)

`sprint-review` Phase 3.6 cannot reach `PASS` while any of these fail. Invariants 2 and 4 are reserved placeholders (consolidated into the canonical Reader Algorithm).

1. **Carry-forward Reader Algorithm** — registry consistency (no `provisional` post-extend; stale active/partial → fail)
2. *(reserved)*
3. **Epic completion** — no `done` epics with `incomplete` registry entries
4. *(reserved)*
5. **OUTPUT STYLE snippet** present in every `SKILL.md` + agent-prompt template *(blocker)*
6. **Ratchet** — 8 monotonic metrics never regress without a covering carry-forward *(blocker)*: `test_count` ↑, `type_errors` ↓ (absolute floor 0), `as_any_count` ↓, `lint_violations` ↓, `completeness_score` ↑, `mocks_in_src` ↓, `todo_count` ↓, `stale_worktree_branch_count` ↓ *(added 2026-05-17)*
7. **Critic** — the `blitz:critic` adversarial agent must emit `LGTM` after running the 20-detector shortcut taxonomy *(blocker)*
8. **Branch hygiene** — sprint-dev Phase 4.4 deleted every `sprint-${N}/{backend,frontend,tests,infra,integration}` branch *(blocker)*

### 4. Cross-Model Critic (optional)

By default, the pre-`PASS` critic runs in-Claude as the `blitz:critic` agent. For higher-signal review, route the same prompt to a different model family — research shows a critic from a different model catches blindspots the home model has on its own work (arxiv 2604.19049).

```bash
sprint-review                              # default: in-Claude blitz:critic
BLITZ_USE_GEMINI_CRITIC=1 sprint-review    # Gemini-only
BLITZ_DUAL_CRITIC=1 sprint-review          # both — require LGTM from each (~2× cost)
```

Setup:
```bash
npm i -g @google/gemini-cli
gemini auth
```

| Env | Default | Purpose |
|---|---|---|
| `BLITZ_GEMINI_BIN` | `gemini` | Binary path override |
| `BLITZ_GEMINI_MODEL` | `gemini-2.5-pro` | Switch to `gemini-2.5-flash` for cheaper review |
| `BLITZ_GEMINI_FLAGS` | (empty) | Extra flags |

The wrapper (`hooks/scripts/critic-gemini.sh`) supports three review domains: `--mode pre-pass` (Invariant 7), `--mode research` (citation/quote validation in `research` Phase 3.2.5), `--mode design` (vision-based aesthetic scoring in `ui-build` Phase 5.4.2). When `gemini` isn't installed, the wrapper exits 1 cleanly; the in-Claude critic remains the default. The script is invoked from skill bodies, not from `hooks.json`.

---

## Skill Catalog (37)

### Orchestrators

| Skill | What it does | Invocation |
|---|---|---|
| **next** | Reads sprint/roadmap/carry-forward state, recommends the next command. With `--loop`: canonical autonomous reconciliation engine — full project lifecycle. | `/blitz:next [--loop]` |
| **ask** | Classifies a vague request and dispatches to the right skill(s) via decision tree. | `/blitz:ask <request>` |
| **sprint** | Full cycle: plan → implement → review. `--loop` aliases to `/blitz:next --loop` (since v1.13.0). | `/blitz:sprint [--plan-only\|--skip-review\|--loop\|--gaps\|--resume\|--epics E-001]` |
| **implement** | Thin dispatcher to sprint-dev. | `/blitz:implement [--sprint N\|--resume]` |
| **review** | Sprint review phase only. | `/blitz:review [--sprint N]` |
| **ship** | review → review --only completeness → quality-metrics → release → PushNotification. | `/blitz:ship [version]` |

### Sprint lifecycle

| Skill | What it does | Invocation |
|---|---|---|
| **research** | Parallel research agents (domain, library, codebase, optional infra). Produces `docs/_research/<date>_<topic>.md` with quantified `scope:` YAML frontmatter. research-critic verifies citations + quoted spans. | `/blitz:research <topic>` |
| **roadmap** | Generates phased roadmaps. `extend` ingests new research into the carry-forward registry. | `/blitz:roadmap [full\|refresh\|extend\|status]` |
| **sprint-plan** | Plans a sprint from unblocked epics. Reads `carry-forward.jsonl` as mandatory input. Spawns GitHub issues. | `/blitz:sprint-plan [--sprint N\|--gaps]` |
| **sprint-dev** | Spawns backend/frontend/test agents in isolated worktrees. Monitor-tool event-driven progress. Merges per-role branches on completion (Phase 4.4 deletes them). | `/blitz:sprint-dev [--sprint N\|--resume\|--mode autonomous\|checkpoint\|interactive]` |
| **sprint-review** | 5 auto-gates (type-check, lint, tests, build, imports) + 4 parallel reviewer agents (security, backend, frontend, patterns) + critic + 8-invariant gate. Auto-injects planning inputs for next sprint. | `/blitz:sprint-review [--sprint N]` |

### Code quality

| Skill | What it does | Invocation |
|---|---|---|
| **code-doctor** | Framework-API correctness — Firestore, VueFire, Vue 3, Pinia anti-patterns. Read-only by default. | `/blitz:code-doctor [--fix\|--fix-all\|--scan]` |
| **code-sweep** | Convention discovery + standards enforcement. 30 checks across 7 categories. Ratchet enforces monotonic improvement. Loop-safe. | `/blitz:code-sweep [--loop\|--category <name>\|--deep]` |
| **audit** | 5-pillar audit (Architecture, Performance, Security, Maintainability, Robustness). Spawns 10 parallel agents (2 per pillar). | `/blitz:audit` |
| **ui-audit** | Cross-page semantic + data-quality + UX heuristics. Extracts a labeled value registry, asserts invariants, flags placeholders/nulls/flapping values. Loop-safe. | `/blitz:ui-audit [full\|smoke\|data\|buttons\|events\|consistency\|heuristics\|role <name>\|--loop]` |
| **quality-metrics** | Collects, stores, and visualizes metrics over time (test counts, lint debt, complexity hotspots, type-error trends). | `/blitz:quality-metrics [collect\|dashboard\|trend\|compare]` |
| **perf-profile** | Read-only bundle / runtime / Lighthouse analysis with baseline comparison. | `/blitz:perf-profile [bundle\|runtime\|lighthouse]` |
| **dep-health** | Vulnerabilities (`npm audit`), outdated packages, license compliance. | `/blitz:dep-health [audit\|upgrade\|report]` |

### Core development

| Skill | What it does | Invocation |
|---|---|---|
| **ui-build** | 5 phases — Discover → Analyze → Design → Implement → Refine. Phase 5.4.2 vision-critique loop via design-critic. Generates Vue 3 UI native to the project's design system. | `/blitz:ui-build <feature description>` |
| **design-extract** | Read-only extraction of brownfield design tokens (Tailwind config, CSS vars, fonts, accents) → portable `DESIGN.md`. | `/blitz:design-extract` |
| **browse** | Playwright MCP testing. Captures console errors + failed network requests + screenshots. Auto-fix mode. Loop-safe (one page per tick, builds navigational hierarchy). | `/blitz:browse [full\|smoke\|page <path>\|fix\|--loop]` |
| **refactor** | Snapshot tests, refactor one piece at a time, revert if any previously passing test fails. | `/blitz:refactor <file-or-dir> <goal>` |
| **test-gen** | Tests in project conventions (Vitest/Jest auto-detect). AAA, factory functions, regression checks. | `/blitz:test-gen <file-path>` |
| **fix-issue** | GitHub issue → research → fix with tests → close via `gh` CLI. Independent of sprint-dev. | `/blitz:fix-issue <issue-number>` |
| **migrate** | Framework/library/tooling migrations. Researches breaking changes, atomic steps, verifies after each. | `/blitz:migrate <target>` |
| **bootstrap** | Greenfield scaffold (creates `package.json`, `src/`, roadmap stubs) or feature/package into an existing project. | `/blitz:bootstrap <type> <name>` |
| **quick** | Small targeted edits without sprint ceremony. | `/blitz:quick <request>` |

### Documentation & release

| Skill | What it does | Invocation |
|---|---|---|
| **doc-gen** | API docs / component docs / architecture diagrams (Mermaid) / CHANGELOG entries from source + conventional commits. | `/blitz:doc-gen [api\|components\|architecture\|changelog\|full]` |
| **release** | Semver, CHANGELOG, GitHub release. | `/blitz:release [prepare\|verify\|publish\|rollback]` |

### Analysis & meta

| Skill | What it does | Invocation |
|---|---|---|
| **codebase-map** | 4-dim analysis (Technology, Architecture, Quality, Concerns) → `CODEBASE-MAP.md` for brownfield onboarding. | `/blitz:codebase-map` |
| **compress** | Rewrites markdown/text to terse form. Preserves code, URLs, tables, YAML/JSON verbatim. Writes a `.original` backup before modifying. | `/blitz:compress <file>` |
| **retrospective** | Mines activity-feed + git diffs to surface recurring friction. Generates self-improvement proposals classified by safety (auto-apply / propose-only / never-auto-apply). | `/blitz:retrospective` |
| **setup** | Detects conflicts between CLAUDE.md and blitz skill behaviors. Validates permissions + stack assumptions. | `/blitz:setup` |
| **health** | Plugin structural integrity check — hooks, sessions, locks, frontmatter lint. | `/blitz:health` |
| **conform** | Detects + migrates drift in a project's blitz runtime artifacts against current canonical schemas. Read-only by default; `--fix` applies migrations. | `/blitz:conform [target-dir] [--fix\|--report-only] [--scope project\|plugin\|all]` |
| **todo** | Tracks development todos in `.cc-sessions/todos.jsonl` with `file:line` context. | `/blitz:todo [add\|list\|check\|resolve]` |
| **worktree-prune** | Lists + safely deletes stale agent-spawned branches. Default dry-run; `--apply --merged-only` is safe (ancestors of `origin/HEAD`); `--all-older-than 30d` requires `--force`. | `/blitz:worktree-prune [--dry-run\|--apply] [--merged-only\|--all-older-than <duration>] [--force]` |

### At a glance

- **Loop-safe** (4): browse, code-sweep, next, ui-audit
- **Read-only by default** (6): conform, design-extract, health, perf-profile, setup, worktree-prune
- **Multi-agent super-orchestrators** (slash-invoked due to subagents-cannot-spawn-subagents): sprint-dev, sprint-plan, sprint-review, research, audit, quality-metrics, code-sweep, code-doctor, ui-audit
- **Pure chainers** (dispatch to other skills): sprint, ship, fix-issue, ui-build, review, bootstrap, conform, setup, browse, perf-profile, next

---

## Agent Catalog (10)

Three roles. **Builder agents** are spawned by skills via `Agent({isolation: "worktree"})` — each gets its own branch that is auto-cleaned if no changes are made. **Critic agents** are read-only adversarial reviewers at gate points. The **orchestrator** is the plugin's main-thread agent for freeform input.

### Builder agents (6)

| Agent | Model | Role | Tools |
|---|---|---|---|
| **backend-dev** | sonnet | Cloud Functions v2 / Zod / Firestore. Numbered comment flow (Auth → Validate → Logic → Audit → Return). | Read, Write, Edit, Bash, Glob, Grep, WebSearch, ToolSearch |
| **frontend-dev** | sonnet | Vue 3 `<script setup lang="ts">` / Pinia / components, stores, composables, routes. Adapts to Tailwind / Quasar / Vuetify. | Read, Write, Edit, Bash, Glob, Grep, WebSearch, ToolSearch |
| **test-writer** | sonnet | Vitest/Jest. AAA with factory functions. Per-spec Spec Fix Mode classifier. | Read, Write, Edit, Bash, Glob, Grep |
| **reviewer** | sonnet | OWASP top-10 + pattern violations. Writes findings incrementally to `${SESSION_TMP_DIR}/review-findings.md`. ≤15 files per session. | Read, Write, Bash, Glob, Grep |
| **architect** | sonnet | Read-only structural analysis — coupling, cohesion, dependency graphs, circular deps. Stack-detects monorepo (pnpm / nx / turbo / lerna). | Read, Glob, Grep, Bash |
| **doc-writer** | haiku | API docs, ADRs, README sections, migration guides. Haiku (≈3× cheaper than Sonnet) — mechanical pattern-following work. | Read, Write, Edit, Bash, Glob, Grep |

### Critic agents (3) — adversarial reviewers

| Agent | Model | Role | Output | Spawned at |
|---|---|---|---|---|
| **critic** | sonnet | Adversarial pre-`PASS` reviewer. Runs the 20-detector shortcut taxonomy + ratchet + acceptance-checks + hallucinated-symbol spot-check + `--no-verify` reflog scan + test-rename detection. Halts at first REJECT. | JSON `{verdict: LGTM \| REJECT, issues: [...]}` | `sprint-review` Phase 3.6 Invariant 7 |
| **research-critic** | sonnet | Probes every cited URL, classifies LIVE/DEAD/LIKELY_HALLUCINATED/UNKNOWN per the urlhealth taxonomy (arxiv 2604.03173). Verifies `> "..."` quoted spans appear in fetched source (Deterministic Quoting). | JSON `{verdict: PASS \| CITATIONS_MISSING, issues: [...]}` | `research` Phase 3.2.5 |
| **design-critic** | sonnet | Vision-based aesthetic scorer. Reads `/tmp/ui-build-screenshots/*.png` against `DESIGN.md` (or frontend-design heuristics). 5 dimensions, 0–10 each. | JSON `{scores, verdict: PASS \| ITERATE \| REWORK, issues: [...]}` | `ui-build` Phase 5.4.2 |

### Orchestrator (1)

| Agent | Model | Role |
|---|---|---|
| **orchestrator** | sonnet | Top-level main-thread agent. Read-only (no Write / Edit / Agent — cannot spawn subagents). Receives freeform input, surfaces in-flight state from `HANDOFF.json` + activity feed, routes to the right `/blitz:*` skill. Activated via `.claude-plugin/settings.json`. Disable with `BLITZ_DISABLE_ORCHESTRATOR=1`. |

### Typed agent definitions

Drop typed agent YAML into `.claude/agents/` to scope MCP server access per agent. Sprint-dev auto-detects these at spawn time:

```
.claude/agents/
├── blitz-backend-dev.md   # mcpServers: [firebase]
├── blitz-frontend-dev.md  # mcpServers: [playwright]
└── blitz-test-writer.md   # tools: read-only only
```

---

## Carry-Forward Registry

`.cc-sessions/carry-forward.jsonl` is the backbone of the blitz cycle — an append-only JSONL ledger that tracks quantified scope claims across sprints and prevents silent drops.

### Lifecycle

```
provisional ─┐
             ├─→ active ──→ partial ──→ complete
             │     │            │           ▲
             │     ▼            ▼           │
             │  deferred     deferred       │
             │     │            │           │
             │     └────────────┴───────────┘
             ▼
          dropped (one-way; cannot auto-revive)
```

1. **Research emits `scope:`** when a doc contains quantified claims:
   ```yaml
   scope:
     - id: cf-2026-04-25-modal-migration
       unit: components
       target: 45
       description: Migrate modal components to @mbk/ui Modal.vue
       acceptance:
         - grep_absent: 'class="modal-overlay"'
         - grep_present:
             pattern: 'from.*@mbk/ui.*Modal'
             min: 30
   ```
2. **`roadmap extend`** ingests the block as a registry entry with `status: active`, `coverage: 0.0`.
3. **sprint-plan** treats every `status ∈ {active, partial}` entry as mandatory planning input.
4. **sprint-dev** advances `delivered.actual` and `coverage` as stories complete.
5. **sprint-review** runs the canonical Reader Algorithm (see [`skills/_shared/carry-forward-registry.md`](skills/_shared/carry-forward-registry.md)):
   - `exit 0` — registry consistent
   - `exit 2` — invariant failure (block planning/review)
   - `exit 3` — escalation (`rollover_count ≥ 3` → human review required → emits `LOOP_ESCALATE`)
6. When `coverage` reaches 1.0 and DoD checks pass, status flips to `complete` (one-way door unless explicitly `replaced`).

### Quality ratchet

Eight monotonic metrics in `docs/sweeps/ratchet.json`. Any regression without a covering carry-forward entry fails sprint-review Invariant 6.

| Metric | Direction | Floor |
|---|---|---|
| `test_count` | ↑ | baseline |
| `type_errors` | ↓ | **absolute 0** |
| `as_any_count` | ↓ | baseline |
| `lint_violations` | ↓ | baseline |
| `completeness_score` | ↑ | baseline |
| `mocks_in_src` | ↓ | baseline |
| `todo_count` | ↓ | baseline |
| `stale_worktree_branch_count` | ↓ | baseline *(added 2026-05-17)* |

On improvement: tighten thresholds + append history snapshot. On deterministic regression: auto-revert (except `test_count`, which only flags). Multi-agent merge takes `min(max_allowed)` and `max(min_allowed)` across worktrees.

---

## Worktree Lifecycle

`Agent({isolation: "worktree"})` spawns workers on dedicated branches. Blitz controls the per-sprint branches; the harness controls `worktree-agent-*` / `worktree-sprint-*`.

| Branch pattern | Source | Controlled by |
|---|---|---|
| `sprint-${N}/{backend,frontend,tests,infra}` | sprint-dev Phase 2.3 | Blitz |
| `sprint-${N}/integration` | sprint-dev Phase 3.5.1 | Blitz |
| `sprint-${N}/merged` | sprint-dev Phase 4.1 | Blitz |
| `worktree-agent-<8hex>` | Claude Code harness | Platform |
| `worktree-sprint-*-plan` | Harness auto-assign | Platform |
| `worktree-<name>` | CLI `--worktree` | User |

**Hygiene mechanisms:**

- **Spawn-time collision guard** (`hooks/scripts/worktree-create.sh`) — aborts if a `worktree-agent-<8hex>` exists with commits ahead of `origin/HEAD`. Escape: `BLITZ_ALLOW_WORKTREE_COLLISION=1`.
- **Post-merge cleanup** (sprint-dev Phase 4.4) — deletes `sprint-${N}/{role}` and integration branch with `git branch -d` (refuses unmerged). Escape: `BLITZ_SKIP_BRANCH_CLEANUP=1`.
- **Opportunistic remove-hook cleanup** (`hooks/scripts/worktree-remove.sh`) — on WorktreeRemove, deletes ancestor-of-`origin/HEAD` `worktree-agent-*` / `worktree-sprint-*` branches. Best-effort; never blocks.
- **Resume divergence gate** (sprint-dev Phase 0.1) — before re-spawning on an existing branch, checks `git rev-list --count <merge-base>..<branch>`. Escape: `BLITZ_RESUME_ON_DIVERGENCE={prompt|abandon|halt}` (default `halt`).
- **Manual prune** — `/blitz:worktree-prune --dry-run` lists with age + merge-status + divergence + disk; `--apply --merged-only` is safe.

Full protocol: [`skills/_shared/worktree-lifecycle.md`](skills/_shared/worktree-lifecycle.md).

---

## Token Budget

Multi-agent runs are ≈15× more expensive than single-agent by default. The token-budget protocol targets a 50–70% cut on top of that baseline.

**Model routing matrix** (mandatory explicit `model:` on every agent + skill):

| Role | Model | When |
|---|---|---|
| Mechanical (doc-gen, test-writer, lint-fix, file ops) | `haiku` (4.5) | Pattern-following; ≈5× cheaper than Sonnet |
| Standard (backend-dev, frontend-dev, reviewer, refactorer) | `sonnet` (4.6) | Default — impl + review |
| Heavy reasoning (architect, security audit, audit, research) | `opus` (4.7) | Reserve for hard multi-step decisions |
| Orchestrator / Critic | `sonnet` (4.6) | Routing/review, not synthesis |

Target distribution by output tokens: **≈60% Haiku · 35% Sonnet · 5% Opus**.

**Prompt caching:** static prefixes (role + protocols + output style) ≥ 1024 tokens are marked `{"type": "ephemeral", "ttl": "1h"}`. Dynamic content (sprint context, story args) comes after the cached block. Target cache-hit rate ≥ 0.6 once the orchestrator warms up.

**Subagent reply contract** (canonical JSON, ≤ 50-word summary):

```json
{
  "status": "complete|partial|failed",
  "summary": "≤50 words, ≤400 chars",
  "files_changed": ["path/relative"],
  "issues": [{"severity": "blocker|major|minor", "where": "path:line", "what": "≤30 words"}],
  "next_blocked_by": ["needs-typecheck"],
  "metrics": {"test_count_delta": 0, "type_errors_delta": 0, "lines_changed": 0}
}
```

Prose replies bloat orchestrator context 430–1,930 tokens per return × N agents — forbidden. Full spec: [`skills/_shared/token-budget.md`](skills/_shared/token-budget.md).

---

## Architecture

```
blitz/
├── .claude-plugin/
│   ├── plugin.json              # name=blitz · version=1.15.0
│   ├── settings.json            # {"agent": "orchestrator"} — main-thread activation
│   ├── marketplace.json         # Marketplace catalog
│   └── model-profiles.json      # quality / balanced / budget
├── installer/                   # npm package blitz-cc v0.4.0 (node ≥ 18)
│   ├── bin/install.js           # npx blitz-cc entry point
│   ├── src/                     # Zero-dependency Node.js implementation
│   └── install.sh               # Bash fallback (curl | bash)
├── scripts/                     # detect-stack.sh, check-version-sync.sh, validate-plugin-structure.sh, ...
├── output-styles/
│   └── terse-technical.md       # Canonical OUTPUT STYLE (referenced by every SKILL.md)
├── skills/                      # 37 skill directories
│   ├── _shared/                 # 29 shared protocol files
│   ├── next/                    # Canonical autonomous reconciliation engine (--loop)
│   ├── sprint/                  # Cycle orchestrator
│   ├── sprint-plan/             # Carry-forward-aware planning
│   ├── sprint-dev/              # Monitor-tool progress, worktree isolation
│   ├── sprint-review/           # 8-invariant gate
│   ├── research/                # Parallel agents → scope: YAML; research-critic gate
│   ├── roadmap/                 # Research ingestion → epic-registry
│   ├── ui-build/                # 5 phases + design-critic vision loop
│   ├── design-extract/          # Brownfield tokens → DESIGN.md
│   ├── code-doctor/             # Framework-API correctness
│   ├── conform/                 # Migrates legacy artifacts to current spec
│   ├── worktree-prune/          # Cleans stale agent-spawned branches
│   └── ... (28 more — see Skill Catalog above)
├── agents/                      # 10 agents
│   ├── orchestrator.md          # Top-level main-thread router (sonnet)
│   ├── critic.md                # Adversarial pre-PASS reviewer (sonnet)
│   ├── research-critic.md       # Citation + claim reviewer (sonnet)
│   ├── design-critic.md         # Vision-based aesthetic scorer (sonnet)
│   ├── backend-dev.md           # Firestore / VueFire / Cloud Functions (sonnet)
│   ├── frontend-dev.md          # Vue 3 / Pinia / Quasar / Tailwind (sonnet)
│   ├── test-writer.md           # Vitest / Jest AAA (sonnet)
│   ├── reviewer.md              # OWASP + pattern review (sonnet)
│   ├── architect.md             # Dependency analysis (sonnet)
│   └── doc-writer.md            # API docs / ADRs / changelogs (haiku)
└── hooks/
    ├── hooks.json               # 16 event types wired
    └── scripts/                 # 37 scripts: 36 hook-wired + critic-gemini.sh utility
```

### Runtime artifacts

Skills generate machine-local state in the consuming project — gitignored, not plugin source:

```
sprints/             # Sprint stories, manifests, STATE.md checkpoints
sprint-registry.json # Live sprint tracking
.cc-sessions/        # Session state, activity feed, carry-forward, HANDOFF.json, KNOWLEDGE.md
docs/_research/      # Generated research documents
docs/roadmap/        # Generated roadmap, epic-registry, capability-index
docs/retrospective/  # Session retrospective proposals
docs/sweeps/         # ratchet.json + sweep history
```

### Conforming after upgrades

Projects bootstrapped on older blitz versions may carry artifact drift (old story-frontmatter schema, missing `registry_entries`, etc.). Run `/blitz:conform` to detect; `/blitz:conform --fix` to apply migrations idempotently with per-file backups. `--scope plugin` targets plugin forks.

---

## Hook Reference (37 scripts, 16 events)

35 scripts are wired into `hooks.json`. `critic-gemini.sh` is a utility invoked from skill bodies — not a hook event.

| Event | Matcher | Script | Behavior |
|---|---|---|---|
| `PreCompact` | `auto\|manual` | `pre-compact-snapshot.sh` | Writes `compact-state.json` + `HANDOFF.json` (sprint, phase, branch, head SHA, recent files, resume hint) |
| `PostCompact` | `auto\|manual` | `post-compact-log.sh` | Reads snapshot, appends restoration hint to activity feed |
| `UserPromptExpansion` | `blitz:.*` | `blitz-prompt-expansion.sh` | Injects last 5 activity-feed events into every `blitz:*` invocation |
| `SessionStart` | — | `session-start.sh` | Detects fresh `HANDOFF.json` (≤24h) → offers auto-resume; otherwise prints recent activity |
| `TeammateIdle` | — | `teammate-idle.sh` | Quality gate for agent teams — can return feedback (exit 2) |
| `TaskCompleted` | — | `task-completed-validate.sh` | Validates task completion against Definition of Done |
| `PostToolUse` | `Write\|Edit` | `post-edit-activity-log.sh` | Appends `file_change` event |
| `PostToolUse` | `Write\|Edit` | `post-edit-format.sh` | Auto-format (Prettier or Biome — auto-detected) |
| `PostToolUse` | `Write\|Edit` | `post-edit-lint.sh` | Auto-lint (ESLint or Biome — auto-detected) |
| `PostToolUse` | `Write\|Edit` | `post-edit-test.sh` | Runs matching test file after source edits |
| `PostToolUse` | `Write\|Edit` | `analysis-paralysis-guard.sh` | Warns after 5+ consecutive reads without writes |
| `PostToolUse` | `Read\|Glob\|Grep` | `analysis-paralysis-guard.sh` | Same guard on read-heavy ops |
| `PostToolUse` | `Write\|Edit` | `skill-frontmatter-validate.sh --all` | Lints modified `SKILL.md` against the canonical contract |
| `PostToolUse` | `Write\|Edit` | `agent-frontmatter-validate.sh --all` | Lints modified `agents/*.md`; blocks silently-stripped fields |
| `PostToolUse` | `Read\|Glob\|Grep\|Bash` | `context-monitor.sh` | Tracks context utilization; warns at ~60% and ~80% |
| **PreToolUse blockers (anti-shortcut)** | | | |
| `PreToolUse` | `Bash` | `block-no-verify.sh` | **Blocks** `git commit --no-verify` / `--no-gpg-sign` |
| `PreToolUse` | `Bash` | `block-destructive-git.sh` | **Blocks** on dirty tree: `reset --hard`, `checkout -- .`, `clean -fd`, `restore .`, force-push to main, `branch -D` current |
| `PreToolUse` | `Bash` | `block-destructive-sql.sh` | **Blocks** `DROP TABLE`, `DELETE FROM`-no-`WHERE`, `TRUNCATE`, Mongo `.drop()` outside `migrations/` |
| `PreToolUse` | `Bash\|Write` | `block-test-deletion.sh` | **Blocks** `rm` of test files, renames test→non-test, empty Writes |
| `PreToolUse` | `Write\|Edit\|MultiEdit` | `block-as-any-insertion.sh` | **Blocks** new `as any` / `@ts-ignore` / `@ts-nocheck` in non-test |
| `PreToolUse` | `Write\|Edit\|MultiEdit` | `block-test-disabling.sh` | **Blocks** new `.skip(`, `.only(`, `xit`, `xdescribe`, `xtest`, `test.todo(` in tests |
| `PostToolUse` | `Write\|Edit` | `post-edit-typecheck-block.sh` | Runs `tsc --noEmit`; **blocks** if error count rose vs baseline |
| **PreToolUse other** | | | |
| `PreToolUse` | `Write\|Edit` | `pre-edit-guard.sh` | Blocks edits to protected files (.env, lock files, node_modules, .git/) |
| `PreToolUse` | `Write\|Edit` | `pre-edit-backup.sh` | Timestamped backup in `/tmp/cc-backups/` |
| `PreToolUse` | `Bash` | `pre-commit-validate.sh` | On `git commit`: frontmatter lint + version-sync drift + broken-link warn |
| `PreToolUse` | `Bash` | `reference-compression-validate.sh` | On `git commit`: validates compressed `references/main.md` matches `.original` structure |
| `PreToolUse` | `Bash` | `markdown-link-validate.sh` | On `git commit`: warn-only scan for broken relative `.md` links |
| `PreToolUse` | `Bash` | `workflow-guard.sh` | Warns on out-of-order phase execution in phased skills |
| **Platform-event hooks** — logging-first, exit 0 | | | |
| `SubagentStart` | — | `subagent-start.sh` | Logs Agent spawn (agent_id + agent_type) |
| `SubagentStop` | — | `subagent-stop.sh` | Logs subagent completion. *Future:* enforce Agent Output Contract |
| `PostToolBatch` | — | `post-tool-batch.sh` | Logs parallel tool batch resolution. *Future:* single batched ratchet check |
| `PostToolUseFailure` | — | `post-tool-failure.sh` | Logs failed tool execution |
| `StopFailure` | — | `stop-failure.sh` | Logs turn-end API errors (rate_limit / billing_error / server_error / max_output_tokens) |
| `PermissionRequest` | — | `permission-request.sh` | Logs permission-prompt opportunities |
| `WorktreeCreate` | — | `worktree-create.sh` | Spawn-collision guard. Synchronous (non-zero ABORTS) |
| `WorktreeRemove` | — | `worktree-remove.sh` | Logs removal + opportunistic ancestor-of-`origin/HEAD` cleanup |

### Environment overrides

| Variable | Purpose |
|---|---|
| `BLITZ_DISABLE_ORCHESTRATOR=1` | Bypass main-thread orchestrator (slash commands unaffected) |
| `BLITZ_OVERRIDE_NO_VERIFY=1` | One-shot `--no-verify` allow (logged) |
| `BLITZ_DISABLE_AS_ANY_BLOCK=1` | Disable `as any` / `@ts-ignore` insertion block |
| `BLITZ_DISABLE_TEST_DISABLING_BLOCK=1` | Disable `.skip` / `.only` / `xit` block |
| `BLITZ_DISABLE_TYPECHECK_BLOCK=1` | Disable type-error regression blocker |
| `BLITZ_SKIP_BRANCH_CLEANUP=1` | Skip per-role branch deletion in sprint-dev Phase 4.4 |
| `BLITZ_ALLOW_WORKTREE_COLLISION=1` | Allow `worktree-agent-<8hex>` collision with stale ahead commits |
| `BLITZ_RESUME_ON_DIVERGENCE=prompt\|abandon\|halt` | Sprint-dev resume behavior on diverged branch (default `halt`) |
| `BLITZ_USE_GEMINI_CRITIC=1` · `BLITZ_DUAL_CRITIC=1` | Cross-Model Critic routing |
| `BLITZ_GEMINI_BIN` · `BLITZ_GEMINI_MODEL` · `BLITZ_GEMINI_FLAGS` | Gemini CLI tuning |

---

## Shared Protocols (29)

All skills share 29 protocol files in [`skills/_shared/`](skills/_shared/) that define cross-cutting behavior.

| Protocol | Purpose |
|---|---|
| [`session-protocol.md`](skills/_shared/session-protocol.md) | Multi-session safety — file locks, conflict matrix, autonomy levels |
| [`verbose-progress.md`](skills/_shared/verbose-progress.md) | Output format + activity-feed logging spec |
| [`terse-output.md`](skills/_shared/terse-output.md) | Output style, canonical exemptions, OUTPUT STYLE snippet (Invariant 5) |
| [`carry-forward-registry.md`](skills/_shared/carry-forward-registry.md) | Registry schema + canonical Reader Algorithm + writer contracts |
| [`story-frontmatter.md`](skills/_shared/story-frontmatter.md) | Sprint-story YAML schema, producer/consumer matrix, `acceptance_checks:` |
| [`state-handoff.md`](skills/_shared/state-handoff.md) | Pipeline contracts — artifact producers/consumers |
| [`spawn-protocol.md`](skills/_shared/spawn-protocol.md) | Agent spawn rules, Agent Output Contract, three-tier timeout (soft 20m / idle 10m / hard 30m), WRAP_UP at 70% context |
| [`ratchet-protocol.md`](skills/_shared/ratchet-protocol.md) | 8 monotonic metrics, `ratchet.json` schema, multi-agent merge, auto-revert |
| [`shortcut-taxonomy.md`](skills/_shared/shortcut-taxonomy.md) | 20-detector catalog with grep patterns, severity tiers (P0/P1/P2/P3), escape hatches |
| [`token-budget.md`](skills/_shared/token-budget.md) | Model routing matrix (60/35/5), 1-hr cache TTL, lazy MCP/skill load, JSON reply contract |
| [`agent-routing.md`](skills/_shared/agent-routing.md) | Orchestrator decision tree, subagents-cannot-spawn-subagents constraint |
| [`knowledge-protocol.md`](skills/_shared/knowledge-protocol.md) | `.cc-sessions/KNOWLEDGE.md` cross-session lessons format |
| [`frontend-design-heuristics.md`](skills/_shared/frontend-design-heuristics.md) | Aesthetic philosophy, 13-tone selector, NEVER list |
| [`worktree-lifecycle.md`](skills/_shared/worktree-lifecycle.md) | Branch lifecycle for `Agent({isolation: "worktree"})` |
| [`definition-of-done.md`](skills/_shared/definition-of-done.md) | Banned anti-patterns (TODO / FIXME / placeholder / mock in production) |
| [`quality-matrix.md`](skills/_shared/quality-matrix.md) | Decision matrix across the 7 quality-related skills |
| [`checkpoint-protocol.md`](skills/_shared/checkpoint-protocol.md) | `STATE.md` contract for sprint resume |
| [`deviation-protocol.md`](skills/_shared/deviation-protocol.md) | Tiered escalation when implementation hits unexpected issues |
| [`deterministic-test-recipe.md`](skills/_shared/deterministic-test-recipe.md) | Anti-flake patterns for async / timers / randomness / shared state |
| [`context-management.md`](skills/_shared/context-management.md) | Window hygiene for multi-agent sessions |
| [`agent-prompt-boilerplate.md`](skills/_shared/agent-prompt-boilerplate.md) | Canonical Agent() prompt fragments (BUDGET, WRITE-AS-YOU-GO, HEARTBEAT/PARTIAL) |
| [`package-install-policy.md`](skills/_shared/package-install-policy.md) | How to add npm/pnpm packages — single source of truth |
| [`project-context.md`](skills/_shared/project-context.md) | `## Project Context` boilerplate + `detect-stack.sh` invocation |
| [`scheduling.md`](skills/_shared/scheduling.md) | `/loop` and `ScheduleWakeup` integration |
| [`session-report-template.md`](skills/_shared/session-report-template.md) | Standard session-report format |
| [`skill-cross-references.md`](skills/_shared/skill-cross-references.md) | Source of truth for canonical cross-skill links |

---

## Model Profiles

Three behavioral profiles in `.claude-plugin/model-profiles.json` tune skill **thoroughness**, not model choice. (Model choice is per-skill in `SKILL.md` frontmatter and governed by [`token-budget.md`](skills/_shared/token-budget.md).)

| Profile | Research Agents | Verification | Browser | Completeness threshold | Use Case |
|---|---|---|---|---|---|
| **quality** | Max | 2 passes | Enabled | 80% | Critical features, production releases |
| **balanced** *(default)* | Standard | 1 pass | Enabled | 70% | Everyday development |
| **budget** | Min | 1 pass | Skipped | 60% | Quick iterations, prototyping |

---

## Installer CLI

```
Usage:
  npx blitz-cc@latest              Interactive install
  npx blitz-cc@latest --yes        Non-interactive with defaults
  npx blitz-cc@latest --uninstall  Remove Blitz from project

Options:
  --project <path>     Target project directory (default: cwd)
  --yes, -y            Accept all defaults
  --dry-run            Preview changes without writing
  --skip-agents        Skip agent copy step
  --skip-permissions   Skip permissions setup
  --uninstall          Remove Blitz from the project
  --verbose            Show detailed output
```

The installer is idempotent — safe to run multiple times. Merges settings without overwriting existing configuration.

---

## Contributing

1. Fork the repo
2. Create a feature branch
3. Test locally: `claude --plugin-dir .` then `/reload-plugins` after edits
4. Validate: `./scripts/validate-plugin-structure.sh`
5. Add a [CHANGELOG.md](CHANGELOG.md) entry
6. Submit a PR

Every `SKILL.md` must satisfy the canonical frontmatter contract enforced by [`hooks/scripts/skill-frontmatter-validate.sh`](hooks/scripts/skill-frontmatter-validate.sh): third-person description ≤ 1024 chars, body ≤ 500 lines, required fields (`name`, `description`, `model`, `effort`, `compatibility`, `allowed-tools` when invokable), and the verbatim OUTPUT STYLE snippet from [`output-styles/terse-technical.md`](output-styles/terse-technical.md) (referenced via [`skills/_shared/terse-output.md`](skills/_shared/terse-output.md)). Every `agents/*.md` is checked by [`hooks/scripts/agent-frontmatter-validate.sh`](hooks/scripts/agent-frontmatter-validate.sh) and blocks silently-stripped fields (`hooks`, `mcpServers`, `permissionMode`).

## Acknowledgments

- Clarification Gate ([`CLAUDE.md`](CLAUDE.md)) and Scope Discipline ([`skills/_shared/definition-of-done.md`](skills/_shared/definition-of-done.md)) adapted from [multica-ai/andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills) (MIT). Original principles by Andrej Karpathy.
- The terse-output style draws on caveman-mode (MIT).
- Cross-Model Critic motivated by published evidence that critics from different model families catch blindspots the home model has on its own work (arxiv 2604.19049).
- URL-health classification (LIVE / DEAD / LIKELY_HALLUCINATED / UNKNOWN) per arxiv 2604.03173.

## License

MIT
