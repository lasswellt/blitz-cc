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

**39 skills** · **10 agents** · **36 hooks across 16 events** · **26 shared protocols**

Orchestrator main-thread agent · 7 anti-shortcut hooks · 8-invariant quality ratchet · optional Cross-Model Critic

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude Code Plugin](https://img.shields.io/badge/Claude_Code-Plugin-blue)](https://docs.anthropic.com/en/docs/claude-code)
[![Version](https://img.shields.io/github/v/release/lasswellt/cc-plugin-suite?color=cyan)](https://github.com/lasswellt/cc-plugin-suite/releases)

</div>

---

## What is Blitz?

Blitz turns Claude Code into an opinionated, partly-autonomous development environment for Vue/Nuxt + Firebase projects. It ships:

- A **freeform orchestrator** that routes natural-language input ("research X", "ship the sprint", "what's next?") to the right skill, with state continuity across context compactions.
- A **sprint pipeline** — research → roadmap → plan → implement → review → ship — with a carry-forward registry that prevents silent scope drops between cycles.
- **Quality gates that cannot be bypassed** — seven `PreToolUse` blockers stop `--no-verify`, destructive git/SQL, test deletion, `as any` insertion, and disabled tests at the tool boundary; a monotonic ratchet enforces that 8 quality metrics never regress.
- A **read-only adversarial critic** that runs a 19-detector shortcut taxonomy before any sprint can reach `PASS`, optionally backed by a different model family (Gemini) for blindspot coverage.

It's designed so that `/loop /blitz:sprint --loop` produces shippable code unattended.

---

## Three Tiers

> **Evaluating Blitz?** Read [Quick Start](#quick-start) and [The Blitz Cycle](#the-blitz-cycle).
>
> **Installing for daily use?** Read [Quick Start](#quick-start), [Supported Stacks](#supported-stacks), and [Skill Catalog](#skill-catalog-39).
>
> **Contributing or forking?** Read [Architecture](#architecture), [Shared Protocols](#shared-protocols), and [Hook Reference](#hook-reference-36-scripts-16-events).

---

## Quick Start

```bash
npx blitz-cc@latest
```

The installer auto-detects your stack, registers the plugin, configures permissions, and sets up hooks.

<details>
<summary><b>More install options</b></summary>

**Non-interactive:**
```bash
npx blitz-cc@latest --yes
```

**Bash fallback** (no Node.js):
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
/blitz:next                       # tells you what to do next based on repo state
/blitz:ask "I want to add X"      # routes a vague request to the right skill(s)
/blitz:research <topic>           # parallel-agent investigation → docs/_research/
/blitz:sprint                     # full cycle: plan → implement → review
/blitz:ship                       # gates → release → publish
```

Or just type freeform — the orchestrator routes for you.

### Prerequisites

- **Claude Code** ≥ v2.1.71 (orchestrator main-thread agent requires ≥ 2.1.117)
- **bash**, **Node.js / npx**, **python3**, **jq**

---

## Supported Stacks

| Layer | Supported |
|-------|-----------|
| **Frameworks** | Vue 3 (Vite), Nuxt 3 |
| **UI** | Tailwind, Quasar, Vuetify *(auto-detected)* |
| **Backend** | Firebase / GCP, Cloud Functions v2 |
| **State** | Pinia, VueFire |
| **Testing** | Vitest, Jest |
| **Workspaces** | pnpm, Nx, Turborepo |

Skills detect stack at invocation time — no manual config.

---

## The Blitz Cycle

```
/blitz:research <topic>
        │ writes docs/_research/YYYY-MM-DD_<slug>.md with `scope:` YAML
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
  sprint-review  → 8 invariants (gates + critic + ratchet + branch hygiene)
        ▼
/blitz:ship      → completeness-gate → release → PushNotification
```

Every quantified scope claim from research lands in `.cc-sessions/carry-forward.jsonl` as an append-only registry entry. Sprint-review enforces that no entry silently drops between cycles; the loop cannot declare "done" while active entries remain. See [Carry-Forward Registry](#carry-forward-registry) for the lifecycle.

### Autonomous loop

```bash
/loop 5m /blitz:sprint --loop
```

Each tick reads current state, executes exactly one phase, commits, exits. `PreCompact` writes `.cc-sessions/HANDOFF.json`; `SessionStart` detects a fresh handoff (≤24h) and resumes without re-reading every protocol.

---

## The Holistic Machine

Three layers turn the skill suite into a partly-autonomous development environment. Slash commands still work unchanged.

### 1. Orchestrator (freeform-input router)

`agents/orchestrator.md` is wired as the plugin's main-thread agent via `.claude-plugin/settings.json`:

```json
{ "agent": "orchestrator" }
```

Freeform input lands on the orchestrator; it reads `HANDOFF.json` + recent activity-feed events, then routes to the right `/blitz:*` skill. Slash commands bypass it.

```bash
# Opt out per session
export BLITZ_DISABLE_ORCHESTRATOR=1
```

The orchestrator is read-only by construction (no Write/Edit/Agent tools) — Claude Code's subagents-cannot-spawn-subagents constraint means orchestrator-class skills (sprint-dev, sprint-plan, research, codebase-audit, …) stay slash-invoked. See [`skills/_shared/agent-routing.md`](skills/_shared/agent-routing.md).

### 2. Anti-shortcut blockers

Seven `PreToolUse` hooks block common shortcut shapes at the tool boundary. Each returns `exit 2` with an explicit override path.

| Shortcut | Hook | Override |
|---|---|---|
| `git commit --no-verify` | `block-no-verify.sh` | `BLITZ_OVERRIDE_NO_VERIFY=1` (logged) |
| `git reset --hard` / `checkout -- .` / `clean -f` / force-push to main | `block-destructive-git.sh` | None — use a less destructive command |
| `DROP TABLE` / `DELETE FROM` without `WHERE` / `TRUNCATE` outside migrations | `block-destructive-sql.sh` | Versioned migration file |
| `rm` of test files, renames test→non-test, empty Write to test | `block-test-deletion.sh` | None — pin the failing test |
| Type-error count rise (`tsc --noEmit`) | `post-edit-typecheck-block.sh` | Fix or rebaseline after a real cleanup |
| `as any` / `@ts-ignore` / `@ts-nocheck` in non-test source | `block-as-any-insertion.sh` | `// blitz:any-allowed: <reason>` |
| `.skip(` / `.only(` / `xit` / `xdescribe` in test files | `block-test-disabling.sh` | `// blitz:skip-pinned: #<issue>` |

### 3. Sprint-review invariants (8)

`sprint-review` Phase 3.6 cannot reach `PASS` while any of these fail:

1. **Carry-forward Reader Algorithm** — registry consistency
2. *(reserved — canonical algorithm)*
3. **Epic completion** — no `done` epics with `incomplete` registry entries
4. *(reserved — canonical algorithm)*
5. **OUTPUT STYLE** snippet present in every `SKILL.md` + agent-prompt template
6. **Ratchet** — 8 monotonic metrics never regress without a covering carry-forward: `test_count`, `type_errors` (absolute floor at 0), `as_any_count`, `lint_violations`, `completeness_score`, `mocks_in_src`, `todo_count`, `stale_worktree_branch_count`
7. **Critic** — the `blitz:critic` adversarial agent must emit `LGTM` (runs the 19-detector shortcut taxonomy)
8. **Branch hygiene** — sprint-dev Phase 4.4 deleted every `sprint-${N}/{backend,frontend,tests,infra,integration}` branch

### 4. Cross-Model Critic (optional)

By default, the pre-`PASS` critic runs in-Claude. For higher-signal review, route the same prompt to a different model family — research shows a critic from a different model catches blindspots the home model has on its own work (arxiv 2604.19049).

```bash
# Default: in-Claude blitz:critic agent
sprint-review

# Gemini-only
BLITZ_USE_GEMINI_CRITIC=1 sprint-review

# Dual: require both LGTM (highest signal, ~2× cost)
BLITZ_DUAL_CRITIC=1 sprint-review
```

```bash
npm i -g @google/gemini-cli
gemini auth
```

| Env | Default | Purpose |
|---|---|---|
| `BLITZ_GEMINI_BIN` | `gemini` | Binary path override |
| `BLITZ_GEMINI_MODEL` | `gemini-2.5-pro` | Switch to `gemini-2.5-flash` for cheaper review |
| `BLITZ_GEMINI_FLAGS` | (empty) | Extra flags |

The wrapper supports three review domains: `--mode pre-pass` (Invariant 7), `--mode research` (citation/quote validation in `research` Phase 3.2.5), `--mode design` (vision-based aesthetic scoring in `ui-build` Phase 5.4.2). When `gemini` isn't installed the wrapper exits 1 cleanly; the in-Claude critic remains the default.

---

## Skill Catalog (39)

### Orchestrators

| Skill | What it does | Invocation |
|---|---|---|
| **ask** | Classifies vague requests, dispatches to the right skill(s) | `/blitz:ask <request>` |
| **sprint** | Full cycle: plan → implement → review. Auto-chains `roadmap extend` on uningested research. | `/blitz:sprint [--plan-only\|--skip-review\|--loop\|--gaps\|--resume\|--epics E-001]` |
| **implement** | Sprint implementation phase only | `/blitz:implement [--sprint N\|--resume]` |
| **review** | Sprint review phase only | `/blitz:review [--sprint N]` |
| **ship** | review → completeness-gate → quality-metrics → release → PushNotification | `/blitz:ship [version]` |
| **next** | Reads sprint/roadmap/carry-forward state, recommends the next command | `/blitz:next` |

### Sprint lifecycle

| Skill | What it does | Invocation |
|---|---|---|
| **research** | Parallel research agents (library-docs, web-researcher, codebase-analyst) → structured doc with `scope:` YAML. | `/blitz:research <topic>` |
| **roadmap** | Generates phased roadmaps. `extend` ingests new research into the carry-forward registry. | `/blitz:roadmap [full\|refresh\|extend\|status]` |
| **sprint-plan** | Plans a sprint from unblocked epics. Reads carry-forward.jsonl as mandatory input. Spawns GitHub issues. | `/blitz:sprint-plan [--sprint N\|--gaps]` |
| **sprint-dev** | Spawns backend/frontend/test agents in isolated worktrees. Monitor-tool event-driven progress. Merges on completion. | `/blitz:sprint-dev [--sprint N\|--resume\|--mode autonomous\|checkpoint\|interactive]` |
| **sprint-review** | Parallel reviewer agents + 8-invariant gate. Auto-injects planning inputs for next sprint. | `/blitz:sprint-review [--sprint N]` |

### Code quality

| Skill | What it does | Invocation |
|---|---|---|
| **code-doctor** | Framework-API correctness — Firestore, VueFire, Vue 3, Pinia anti-patterns. Read-only by default. | `/blitz:code-doctor [--fix]` |
| **code-sweep** | 30 checks across 7 categories. Ratchet enforces monotonic improvement. Loop-safe. | `/blitz:code-sweep [--loop\|--category <name>]` |
| **codebase-audit** | 5-pillar audit: Architecture, Performance, Security, Maintainability, Robustness. | `/blitz:codebase-audit` |
| **completeness-gate** | Scans for placeholders + production-readiness issues. `file:line` findings. | `/blitz:completeness-gate [scope]` |
| **integration-check** | Export→import tracing, route coverage, auth guard coverage, store→component wiring. Read-only. | `/blitz:integration-check [scope]` |
| **ui-audit** | Cross-page semantic + data-quality + UX heuristics. Loop-safe. | `/blitz:ui-audit [full\|smoke\|data\|buttons\|events\|consistency\|heuristics\|role <name>\|--loop]` |
| **quality-metrics** | Collects, stores, visualizes metrics over time. | `/blitz:quality-metrics [collect\|dashboard\|trend\|compare]` |
| **perf-profile** | Bundle size, runtime perf, Lighthouse. | `/blitz:perf-profile [bundle\|runtime\|lighthouse]` |
| **dep-health** | Vulnerabilities, outdated packages, licenses. | `/blitz:dep-health [audit\|upgrade\|report]` |

### Core development

| Skill | What it does | Invocation |
|---|---|---|
| **ui-build** | 5-phase: Discover → Analyze → Design → Implement → Refine. Phase 5.4.2 vision-critique loop via design-critic. | `/blitz:ui-build <feature description>` |
| **design-extract** | Reads brownfield design tokens (Tailwind config, CSS vars, fonts, accents) → portable `DESIGN.md`. | `/blitz:design-extract` |
| **browse** | Playwright MCP testing. Console errors, failed network requests, auto-fix mode. Loop-safe. | `/blitz:browse [full\|smoke\|page <path>\|fix\|--loop]` |
| **refactor** | Incremental refactoring with test snapshot before/after each step. | `/blitz:refactor <file-or-dir> <goal>` |
| **test-gen** | Tests in project conventions (Vitest/Jest). AAA, factories, edge cases. | `/blitz:test-gen <file-path>` |
| **fix-issue** | GitHub issue → root cause → fix with tests → close. | `/blitz:fix-issue <issue-number>` |
| **migrate** | Framework/library/tooling migrations. Researches breaking changes, atomic steps. | `/blitz:migrate <target>` |
| **bootstrap** | Greenfield scaffold or feature/package into an existing project. | `/blitz:bootstrap <type> <name>` |
| **quick** | Small targeted edits without skill ceremony. | `/blitz:quick <request>` |

### Documentation & release

| Skill | What it does | Invocation |
|---|---|---|
| **doc-gen** | API/component docs, architecture diagrams, changelogs from source. | `/blitz:doc-gen [api\|components\|architecture\|changelog\|full]` |
| **release** | Semver, changelog, GitHub release. | `/blitz:release [prepare\|verify\|publish\|rollback]` |

### Analysis & meta

| Skill | What it does | Invocation |
|---|---|---|
| **codebase-map** | 4-dim analysis (Technology, Architecture, Quality, Concerns) → `CODEBASE-MAP.md` for brownfield onboarding. | `/blitz:codebase-map` |
| **compress** | Rewrites markdown/text to terse form. Preserves code, URLs, tables, YAML/JSON verbatim. | `/blitz:compress <file>` |
| **retrospective** | Analyzes sessions, generates self-improvement proposals with safety classification. | `/blitz:retrospective` |
| **setup** | Detects CLAUDE.md conflicts + validates permissions and stack assumptions. | `/blitz:setup` |
| **health** | Plugin health check — hooks, sessions, registry, structural integrity. | `/blitz:health` |
| **conform** | Detects + migrates drift in an existing project's blitz runtime artifacts against current canonical schemas. | `/blitz:conform [target-dir] [--fix\|--report-only] [--scope project\|plugin\|all]` |
| **todo** | Tracks development todos in `.cc-sessions/todos.jsonl`. | `/blitz:todo [add\|list\|check\|resolve]` |
| **worktree-prune** | Lists + safely deletes stale agent-spawned branches. Default dry-run; `--apply --merged-only` is safe; `--all-older-than 30d` requires `--force`. | `/blitz:worktree-prune [--dry-run\|--apply] [--merged-only\|--all-older-than <duration>] [--force]` |

---

## Agent Catalog (10)

Agents fall into three roles. **Builder agents** are spawned by skills via `isolation: "worktree"` — each gets its own branch that is auto-cleaned if no changes are made. **Critic agents** are read-only adversarial reviewers at gate points. The **orchestrator** is the plugin's main-thread agent for freeform input.

### Builder agents (6)

| Agent | Role | MCP Scope |
|---|---|---|
| **backend-dev** | Cloud Functions v2 / Zod / Firestore. Numbered comment flow, audit logging. | Firestore, Firebase |
| **frontend-dev** | Vue 3 / Pinia components, stores, composables, routes. Adapts to Tailwind/Quasar/Vuetify. | Playwright |
| **test-writer** | Vitest/Jest. AAA, factories, regression tests. | Read-only |
| **reviewer** | OWASP top-10, pattern violations, correctness issues. | Read-only |
| **architect** | Read-only architecture — coupling, cohesion, dependency graphs. | Read-only |
| **doc-writer** | API docs, ADRs, README sections, migration guides (haiku — mechanical work). | Read-only |

### Critic agents (3) — adversarial reviewers

| Agent | Role | Spawned at |
|---|---|---|
| **critic** | Adversarial pre-`PASS` reviewer. 19-detector shortcut taxonomy + ratchet + acceptance checks + hallucinated-symbol spot-check. Returns `{verdict: LGTM \| REJECT}` JSON. Optional Gemini variant. | `sprint-review` Phase 3.6 Invariant 7 |
| **research-critic** | Probes every cited URL, classifies LIVE/DEAD/LIKELY_HALLUCINATED/UNKNOWN per the urlhealth taxonomy. Verifies `> "..."` quoted spans against fetched source (Deterministic Quoting). | `research` Phase 3.2.5 |
| **design-critic** | Vision-based aesthetic scorer. Reads `/tmp/ui-build-screenshots/*.png` vs `DESIGN.md`. 5 dimensions, verdicts `PASS / ITERATE / REWORK`. | `ui-build` Phase 5.4.2 |

### Orchestrator (1)

| Agent | Role |
|---|---|
| **orchestrator** | Top-level main-thread agent (read-only — no Write/Edit/Agent). Receives freeform input, surfaces in-flight state from `HANDOFF.json` + activity feed, routes to the right `/blitz:*` skill. Activated via `.claude-plugin/settings.json`. Disable with `BLITZ_DISABLE_ORCHESTRATOR=1`. |

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

`.cc-sessions/carry-forward.jsonl` is the backbone of the cycle — it tracks quantified scope claims across sprints and prevents silent drops.

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
2. **`roadmap extend`** (auto-chained by `/blitz:sprint`) ingests the block as a registry entry with `status: active`, `coverage: 0.0`.
3. **sprint-plan** treats every `status ∈ {active, partial}` entry as mandatory planning input.
4. **sprint-dev** advances `delivered.actual` and `coverage` as stories complete.
5. **sprint-review** enforces 8 invariants (see [above](#3-sprint-review-invariants-8)). The loop cannot exit while entries remain active. Entries stuck for 3+ sprints get rollover banners.
6. When `coverage` reaches 1.0, status flips to `complete`.

The canonical Reader Algorithm is in [`skills/_shared/carry-forward-registry.md`](skills/_shared/carry-forward-registry.md).

---

## Architecture

```
blitz/
├── .claude-plugin/
│   ├── plugin.json              # Manifest (name, version, author)
│   ├── marketplace.json         # Marketplace catalog
│   ├── settings.json            # {"agent": "orchestrator"} — main-thread activation
│   └── model-profiles.json      # quality / balanced / budget
├── installer/
│   ├── bin/install.js           # npx blitz-cc entry point
│   ├── src/                     # Zero-dependency Node.js modules
│   └── install.sh               # Bash fallback (curl | bash)
├── scripts/                     # Maintenance + detection (detect-stack, validate-*)
├── skills/                      # 39 skill directories
│   ├── _shared/                 # 26 shared protocol files
│   ├── sprint/                  # Cycle orchestrator
│   ├── sprint-plan/             # Carry-forward-aware planning
│   ├── sprint-dev/              # Monitor-tool progress, worktree isolation
│   ├── sprint-review/           # 8-invariant gate
│   ├── research/                # Parallel agents → scope: YAML; research-critic gate
│   ├── roadmap/                 # Research ingestion → epic-registry
│   ├── ui-build/                # 5-phase + design-critic vision loop
│   ├── design-extract/          # Brownfield tokens → DESIGN.md
│   ├── code-doctor/             # Framework-API correctness
│   ├── conform/                 # Migrates legacy artifacts to current spec
│   ├── worktree-prune/          # Cleans stale agent-spawned branches
│   └── ... (28 more)
├── agents/                      # 10 agents
│   ├── orchestrator.md          # Top-level main-thread router
│   ├── critic.md                # Adversarial pre-PASS reviewer
│   ├── research-critic.md       # Citation + claim reviewer
│   ├── design-critic.md         # Vision-based aesthetic scorer
│   ├── backend-dev.md           # Firestore / VueFire / Cloud Functions
│   ├── frontend-dev.md          # Vue 3 / Pinia / Quasar / Tailwind
│   ├── test-writer.md           # Vitest / Jest AAA
│   ├── reviewer.md              # OWASP + pattern review
│   ├── architect.md             # Dependency analysis
│   └── doc-writer.md            # API docs / ADRs / changelogs
└── hooks/
    ├── hooks.json               # 16 event types wired
    └── scripts/                 # 36 hook scripts + critic-gemini.sh utility
```

### Runtime artifacts

Skills generate machine-local state in the consuming project — gitignored, not plugin source:

```
sprints/             # Sprint stories, manifests, STATE.md checkpoints
sprint-registry.json # Live sprint tracking
.cc-sessions/        # Session state, activity feed, carry-forward, handoff
docs/_research/      # Generated research documents
docs/roadmap/        # Generated roadmap, epic-registry, capability-index
docs/retrospective/  # Session retrospective proposals
```

### Conforming after upgrades

Projects bootstrapped on older blitz versions may carry artifact drift (old story-frontmatter schema, missing `registry_entries`, etc.). Run `/blitz:conform` to detect; `/blitz:conform --fix` to apply migrations idempotently with per-file backups. `--scope plugin` targets plugin forks.

---

## Shared Protocols

All skills share **26 protocol files** in [`skills/_shared/`](skills/_shared/) that define cross-cutting behavior. Highlights:

| Protocol | Purpose |
|---|---|
| [`session-protocol.md`](skills/_shared/session-protocol.md) | Multi-session safety — file locks, conflict matrix, autonomy levels |
| [`verbose-progress.md`](skills/_shared/verbose-progress.md) | Output format + activity-feed logging spec |
| [`terse-output.md`](skills/_shared/terse-output.md) | Output style, canonical exemptions, OUTPUT STYLE snippet |
| [`carry-forward-registry.md`](skills/_shared/carry-forward-registry.md) | Registry schema + canonical Reader Algorithm + writer contracts |
| [`story-frontmatter.md`](skills/_shared/story-frontmatter.md) | Sprint-story YAML schema, producer/consumer matrix, `acceptance_checks:` |
| [`state-handoff.md`](skills/_shared/state-handoff.md) | Pipeline contracts — artifact producers/consumers |
| [`spawn-protocol.md`](skills/_shared/spawn-protocol.md) | Agent spawn rules, **Agent Output Contract**, three-tier timeout, WRAP_UP, JSON reply contract |
| [`ratchet-protocol.md`](skills/_shared/ratchet-protocol.md) | 8 monotonic metrics, `docs/sweeps/ratchet.json` schema, multi-agent merge, auto-revert |
| [`shortcut-taxonomy.md`](skills/_shared/shortcut-taxonomy.md) | 19-detector catalog with grep patterns, severity tiers, false-positive escape hatches |
| [`token-budget.md`](skills/_shared/token-budget.md) | Model routing (60% Haiku / 35% Sonnet / 5% Opus), 1-hr cache TTL, lazy MCP/skill load |
| [`agent-routing.md`](skills/_shared/agent-routing.md) | Orchestrator decision tree, subagents-cannot-spawn-subagents constraint |
| [`knowledge-protocol.md`](skills/_shared/knowledge-protocol.md) | `.cc-sessions/KNOWLEDGE.md` cross-session lessons format |
| [`frontend-design-heuristics.md`](skills/_shared/frontend-design-heuristics.md) | Aesthetic philosophy, 13-tone selector, NEVER list |
| [`worktree-lifecycle.md`](skills/_shared/worktree-lifecycle.md) | Branch lifecycle for `Agent({isolation: "worktree"})` — spawn collision guard, Phase 4.4 cleanup, `/blitz:worktree-prune` |
| [`definition-of-done.md`](skills/_shared/definition-of-done.md) | Banned anti-patterns (TODO/FIXME/placeholder/mock in production) |
| [`quality-matrix.md`](skills/_shared/quality-matrix.md) | Decision matrix across the 7 quality-related skills |

Plus 10 more: `checkpoint-protocol`, `context-management`, `deterministic-test-recipe`, `deviation-protocol`, `package-install-policy`, `project-context`, `scheduling`, `session-report-template`, `skill-cross-references`, `agent-prompt-boilerplate`.

---

## Hook Reference (36 scripts, 16 events)

| Event | Matcher | Script | Behavior |
|---|---|---|---|
| `PreCompact` | `auto\|manual` | `pre-compact-snapshot.sh` | Writes `compact-state.json` + `HANDOFF.json` (sprint, phase, branch, head SHA, recent files, resume hint) |
| `PostCompact` | `auto\|manual` | `post-compact-log.sh` | Reads snapshot, appends restoration hint to activity feed |
| `UserPromptExpansion` | `blitz:.*` | `blitz-prompt-expansion.sh` | Injects last 5 activity-feed events into every `blitz:*` invocation |
| `SessionStart` | — | `session-start.sh` | Detects fresh `HANDOFF.json` (≤24h) → offers auto-resume; otherwise prints recent activity |
| `TeammateIdle` | — | `teammate-idle.sh` | Quality gate for agent teams — can return feedback (exit 2) |
| `TaskCompleted` | — | `task-completed-validate.sh` | Validates task completion against Definition of Done |
| `PostToolUse` | `Write\|Edit` | `post-edit-activity-log.sh` | Appends `file_change` event |
| `PostToolUse` | `Write\|Edit` | `post-edit-format.sh` | Auto-format (Prettier or Biome) |
| `PostToolUse` | `Write\|Edit` | `post-edit-lint.sh` | Auto-lint (ESLint or Biome) |
| `PostToolUse` | `Write\|Edit` | `post-edit-test.sh` | Runs matching test file after source edits |
| `PostToolUse` | `Write\|Edit` | `analysis-paralysis-guard.sh` | Warns after 5+ consecutive reads without writes |
| `PostToolUse` | `Read\|Glob\|Grep` | `analysis-paralysis-guard.sh` | Same guard on read-heavy ops |
| `PostToolUse` | `Write\|Edit` | `skill-frontmatter-validate.sh` | Lints modified `SKILL.md` against the canonical contract |
| `PostToolUse` | `Write\|Edit` | `agent-frontmatter-validate.sh` | Lints modified `agents/*.md`; blocks silently-stripped fields |
| `PostToolUse` | `Read\|Glob\|Grep\|Bash` | `context-monitor.sh` | Tracks context utilization, warns at ~60% and ~80% |
| **PreToolUse blockers (anti-shortcut)** | | | |
| `PreToolUse` | `Bash` | `block-no-verify.sh` | **Blocks** `git commit --no-verify` |
| `PreToolUse` | `Bash` | `block-destructive-git.sh` | **Blocks** `reset --hard`, `checkout -- .`, `clean -f`, force-push to main, `branch -D` on dirty current |
| `PreToolUse` | `Bash` | `block-destructive-sql.sh` | **Blocks** `DROP TABLE`, `DELETE FROM`-no-`WHERE`, `TRUNCATE`, `FLUSHDB`, Mongo `.drop()` outside migrations |
| `PreToolUse` | `Bash\|Write` | `block-test-deletion.sh` | **Blocks** `rm` of test files, renames test→non-test, empty Writes |
| `PreToolUse` | `Write\|Edit\|MultiEdit` | `block-as-any-insertion.sh` | **Blocks** new `as any` / `@ts-ignore` / `@ts-nocheck` in non-test |
| `PreToolUse` | `Write\|Edit\|MultiEdit` | `block-test-disabling.sh` | **Blocks** new `.skip(`, `.only(`, `xit`, `xdescribe`, `xtest`, `test.todo(` in tests |
| `PostToolUse` | `Write\|Edit` | `post-edit-typecheck-block.sh` | Runs `tsc --noEmit`; **blocks** on error-count rise vs baseline |
| **PreToolUse other** | | | |
| `PreToolUse` | `Write\|Edit` | `pre-edit-guard.sh` | Blocks edits to protected files (.env, lock files, node_modules) |
| `PreToolUse` | `Write\|Edit` | `pre-edit-backup.sh` | Timestamped backup in `/tmp/cc-backups/` |
| `PreToolUse` | `Bash` | `pre-commit-validate.sh` | On `git commit`: frontmatter lint + version-sync drift + broken-link warn |
| `PreToolUse` | `Bash` | `reference-compression-validate.sh` | On `git commit`: validates compressed `references/main.md` matches `.original` |
| `PreToolUse` | `Bash` | `markdown-link-validate.sh` | On `git commit`: warn-only scan for broken relative `.md` links |
| `PreToolUse` | `Bash` | `workflow-guard.sh` | Warns on out-of-order phase execution in phased skills |
| **Platform-event hooks** — logging-first, exit 0 | | | |
| `SubagentStart` | — | `subagent-start.sh` | Logs Agent spawn (agent_id + agent_type) |
| `SubagentStop` | — | `subagent-stop.sh` | Logs subagent completion. *Future:* enforce Agent Output Contract |
| `PostToolBatch` | — | `post-tool-batch.sh` | Logs parallel tool batch resolution. *Future:* single batched ratchet check |
| `PostToolUseFailure` | — | `post-tool-failure.sh` | Logs failed tool execution. *Future:* auto-recover from common failure modes |
| `StopFailure` | — | `stop-failure.sh` | Logs turn-end API errors (rate_limit / billing_error / server_error / max_output_tokens) |
| `PermissionRequest` | — | `permission-request.sh` | Logs permission-prompt opportunities. *Future:* auto-approve safe read-only patterns |
| `WorktreeCreate` | — | `worktree-create.sh` | Logs worktree creation. Synchronous (non-zero ABORTS) |
| `WorktreeRemove` | — | `worktree-remove.sh` | Logs worktree removal |

> Plus `hooks/scripts/critic-gemini.sh` — invoked from sprint-review, not a hook event. See [Cross-Model Critic](#4-cross-model-critic-optional).

---

## Model Profiles

Three behavioral profiles control skill thoroughness. Set in `.claude-plugin/model-profiles.json`.

| Profile | Research Agents | Verification | Optional Phases | Use Case |
|---|---|---|---|---|
| **quality** | Max | 2 passes | All run | Critical features, production releases |
| **balanced** | Standard | 1 pass | All run | Default — everyday development |
| **budget** | Min | 1 pass | Skip browser/E2E | Quick iterations, prototyping |

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
5. Add a CHANGELOG entry
6. Submit a PR

Every `SKILL.md` must satisfy the canonical frontmatter contract enforced by [`hooks/scripts/skill-frontmatter-validate.sh`](hooks/scripts/skill-frontmatter-validate.sh): third-person description ≤ 1024 chars, body ≤ 500 lines, required fields (`name`, `description`, `model`, `effort`, `compatibility`, `allowed-tools` when invokable), and the verbatim OUTPUT STYLE snippet from [`skills/_shared/terse-output.md`](skills/_shared/terse-output.md).

## Acknowledgments

- Clarification Gate ([`CLAUDE.md`](CLAUDE.md)) and Scope Discipline ([`skills/_shared/definition-of-done.md`](skills/_shared/definition-of-done.md)) adapted from [multica-ai/andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills) (MIT). Original principles by Andrej Karpathy.
- Cross-Model Critic motivated by published evidence that critics from different model families catch blindspots the home model has on its own work (arxiv 2604.19049).

## License

MIT
