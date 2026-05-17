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

**Production-grade Claude Code plugin for Vue/Nuxt + Firebase**

**39 skills** · **10 agents** · **36 hooks** · **16 hook events** · **26 shared protocols**

Top-level orchestrator agent · 7 anti-shortcut hooks · 8-invariant quality ratchet · optional Gemini Cross-Model Critic

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude Code Plugin](https://img.shields.io/badge/Claude_Code-Plugin-blue)](https://docs.anthropic.com/en/docs/claude-code)
[![Version](https://img.shields.io/github/v/release/lasswellt/cc-plugin-suite?color=cyan)](https://github.com/lasswellt/cc-plugin-suite/releases)

</div>

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

**Bash fallback** (if Node.js is not available):

```bash
curl -fsSL https://raw.githubusercontent.com/lasswellt/cc-plugin-suite/main/installer/install.sh | bash
```

**From the marketplace (manual):**

```bash
/plugin marketplace add lasswellt/blitz
/plugin install blitz@blitz
```

**Local development:**

```bash
claude --plugin-dir ./blitz
/reload-plugins   # hot-reload after edits
```

</details>

### What the installer does

```
  Checking environment...
    ├─ Claude CLI ✓ (v2.x)
    ├─ Node.js ✓
    ├─ python3 ✓
    └─ Platform: linux (WSL)

  Stack detection...
    ├─ Framework: Nuxt 3
    ├─ UI Framework: Quasar
    ├─ Backend: Firebase/GCP
    ├─ Package Manager: pnpm
    └─ Testing: Vitest

  Marketplace registration... ✓
  Plugin installation...      ✓
  Plugin enablement...        ✓
  Permissions setup...        ✓ (29 allow, 2 deny)
  Environment variables...    ✓
  Activity feed setup...      ✓
```

Stack-aware permissions are generated automatically — Tailwind, Quasar, Firebase, VueFire domains and CLI tools are allowed based on what's in your `package.json`.

---

## Supported Stacks

| Layer | Supported |
|-------|-----------|
| **Frameworks** | Vue 3 (Vite), Nuxt 3 |
| **UI Frameworks** | Tailwind CSS, Quasar, Vuetify *(auto-detected)* |
| **Backend** | Firebase/GCP, Cloud Functions v2 |
| **State** | Pinia, VueFire |
| **Testing** | Vitest, Jest |
| **Build Systems** | pnpm workspaces, Nx, Turborepo |

Skills auto-detect the project's tech stack at invocation time — no manual configuration needed.

### Prerequisites

- **Claude Code** ≥ v2.1.71
- **bash** — hooks and stack detection
- **Node.js / npx** — installer + format/lint hooks (Prettier, ESLint, Biome)
- **python3** — JSON parsing in hooks
- **jq** — carry-forward registry operations

---

## The Blitz Cycle

Blitz implements an opinionated development cycle from research to shipped code:

```
/blitz:research <topic>
        │ writes docs/_research/YYYY-MM-DD_<slug>.md
        │ with scope: YAML frontmatter (quantified claims)
        ▼
/blitz:sprint  ← auto-detects uningested research,
        │         chains roadmap extend if needed
        ▼
  roadmap extend → seeds epic-registry.json + carry-forward.jsonl
        ▼
  sprint-plan   → stories with dependency ordering
        ▼
  sprint-dev    → parallel agents in isolated worktrees
        ▼
  sprint-review → quality gates (type-check, lint, tests, build)
        ▼
/blitz:ship     → completeness-gate → release → PushNotification
```

Every scope claim from research is tracked in `.cc-sessions/carry-forward.jsonl` as an append-only registry. Sprint-review enforces that no quantified scope silently drops between cycles. The loop cannot declare "done" while the registry has active entries.

### Autonomous Loop

```bash
/loop 5m /blitz:sprint --loop
```

Each tick the reconciliation engine reads current state, executes exactly one phase (ingest → plan → implement → review), commits progress, and exits. The loop re-enters on the next tick. Fully autonomous under bypass permissions.

PreCompact handoff + SessionStart auto-resume keep state across context compactions: the snapshot writes `.cc-sessions/HANDOFF.json` (sprint, phase, branch, head SHA, recent files, resume hint); the next session detects a fresh handoff (≤24h) and resumes without re-reading every protocol.

---

## Holistic Machine (v1.11+)

Three layers turn the skill suite into a fully autonomous development machine. Slash commands still work unchanged — the new pieces add freeform-input routing, automatic shortcut prevention, and a cross-model adversarial reviewer.

### 1. Orchestrator agent (freeform-input router)

`agents/orchestrator.md` is activated as the plugin's main-thread agent via `.claude-plugin/settings.json {"agent": "orchestrator"}` (Claude Code ≥ 2.1.117). Freeform input ("research X", "implement the sprint", "what's next?") lands on the orchestrator; it reads `.cc-sessions/HANDOFF.json` + recent activity-feed events, then routes to the right `/blitz:*` skill. Slash commands bypass the orchestrator and run unchanged.

```bash
# Disable per-session if you prefer raw Claude Code routing
export BLITZ_DISABLE_ORCHESTRATOR=1
```

The orchestrator is read-only by construction (no Write/Edit/Agent tools) — it cannot itself spawn parallel waves; subagents-cannot-spawn-subagents is a hard Claude Code constraint. Orchestrator-class skills (sprint-dev, sprint-plan, research, codebase-audit, …) stay slash-invoked. See `skills/_shared/agent-routing.md` for the routing decision tree.

### 2. Quality gates (anti-shortcut blockers)

Seven `PreToolUse` hooks block common shortcut shapes at the tool boundary. Each returns `exit 2` with a clear message and an explicit override path; none can be silently bypassed.

| Shortcut | Hook | Override |
|---|---|---|
| `git commit --no-verify` | `block-no-verify.sh` | `BLITZ_OVERRIDE_NO_VERIFY=1` (logged) |
| `git reset --hard` / `checkout -- .` / `clean -f` / force-push to main | `block-destructive-git.sh` | None — confirm intent and use a less destructive command |
| `DROP TABLE` / `DELETE FROM` without `WHERE` / `TRUNCATE` outside migrations | `block-destructive-sql.sh` | Move the SQL into a versioned migration file |
| `rm` of test files, renames test→non-test, empty Write to test | `block-test-deletion.sh` | None — pin the failing test instead |
| Type-error count rise (`tsc --noEmit`) | `post-edit-typecheck-block.sh` | Fix or update `.cc-sessions/typecheck-baseline.json` after a real cleanup |
| `as any` / `@ts-ignore` / `@ts-nocheck` insertion in non-test source | `block-as-any-insertion.sh` | Inline `// blitz:any-allowed: <reason>` |
| `.skip(` / `.only(` / `xit` / `xdescribe` insertion in test files | `block-test-disabling.sh` | Inline `// blitz:skip-pinned: #<issue>` |

`sprint-review` Phase 3.6 enforces 8 invariants — registry consistency, OUTPUT STYLE coverage, **ratchet** (8 monotonic metrics: `test_count`, `type_errors`, `as_any_count`, `lint_violations`, `completeness_score`, `mocks_in_src`, `todo_count`, `stale_worktree_branch_count` — never regress without a covering carry-forward), **critic** (the `blitz:critic` agent must emit `LGTM`), and **branch hygiene** (per-sprint `sprint-${N}/${role}` branches deleted by Phase 4.4). Sprint cannot reach `PASS` while any fail.

### 3. Cross-Model Critic (CMC) — optional Gemini integration

By default, sprint-review's adversarial pre-PASS check runs in-Claude as the `blitz:critic` agent. For higher-signal review, route the same prompt to a different model family (Gemini) — research has shown a critic from a different model catches blindspots the home model has on its own work (arxiv 2604.19049).

`hooks/scripts/critic-gemini.sh` wraps `@google/gemini-cli`, lifts the in-Claude critic body verbatim, appends a JSON-only directive, validates the reply matches the canonical `{verdict, issues, summary}` contract, and exits `0` on `LGTM/PASS`, `2` on `REJECT/CITATIONS_MISSING`.

**Three modes**, selected per sprint:

```bash
# (default)               in-Claude blitz:critic agent (cheapest)
sprint-review

# Gemini-only             swap in CMC; same cost as default + Gemini API
BLITZ_USE_GEMINI_CRITIC=1 sprint-review

# Dual-CMC                run both; require both LGTM (highest signal, ~2× cost)
BLITZ_DUAL_CRITIC=1 sprint-review
```

**Setup:**

```bash
npm i -g @google/gemini-cli
gemini auth     # one-time OAuth or API-key setup
```

**Tunables:**

| Env | Default | Purpose |
|---|---|---|
| `BLITZ_GEMINI_BIN` | `gemini` | Override binary path (custom wrapper, alternate install) |
| `BLITZ_GEMINI_MODEL` | `gemini-2.5-pro` | Model id — switch to `gemini-2.5-flash` for cheaper review |
| `BLITZ_GEMINI_FLAGS` | (empty) | Extra flags appended to the gemini invocation |

The wrapper supports three review domains:

| Mode | Replaces / pairs with | Used by |
|---|---|---|
| `--mode pre-pass` | `agents/critic.md` | sprint-review Invariant 7 |
| `--mode research` | `agents/research-critic.md` | research skill Phase 3.2.5 (citation/quote validation) |
| `--mode design`  | `agents/design-critic.md`  | ui-build Phase 5.4.2 (vision-based aesthetic scoring; requires Gemini multimodal) |

When the `gemini` binary isn't installed, the wrapper exits 1 with a clear install message — the in-Claude critic remains the default, no breakage.

---

## Skills (38)

### Orchestrators

| Skill | What it does | Invocation |
|-------|-------------|------------|
| **ask** | Classifies vague requests and dispatches to the right skill | `/blitz:ask <request>` |
| **sprint** | Full cycle: plan → implement → review. Auto-chains `roadmap extend` when uningested research docs are detected. | `/blitz:sprint [--plan-only\|--skip-review\|--loop\|--gaps\|--resume\|--epics E-001]` |
| **implement** | Sprint implementation phase only | `/blitz:implement [--sprint N\|--resume]` |
| **review** | Sprint review and quality gate only | `/blitz:review [--sprint N]` |
| **ship** | review → completeness-gate → quality-metrics → release → PushNotification | `/blitz:ship [version]` |
| **next** | Reads sprint/roadmap/carry-forward state and recommends the logical next command | `/blitz:next` |

### Sprint Lifecycle

| Skill | What it does | Invocation |
|-------|-------------|------------|
| **research** | Spawns parallel research agents (library-docs, web-researcher, codebase-analyst), synthesizes structured research doc with `scope:` YAML frontmatter | `/blitz:research <topic>` |
| **roadmap** | Generates phased roadmaps from research docs. `extend` ingests new docs into the carry-forward registry. | `/blitz:roadmap [full\|refresh\|extend\|status]` |
| **sprint-plan** | Plans a sprint from unblocked epics. Reads carry-forward.jsonl as mandatory planning input. Spawns GitHub issues. | `/blitz:sprint-plan [--sprint N\|--gaps]` |
| **sprint-dev** | Spawns backend/frontend/test agents in isolated worktrees. Monitor-tool event-driven progress tracking. Merges branches on completion. | `/blitz:sprint-dev [--sprint N\|--resume\|--mode autonomous\|checkpoint\|interactive]` |
| **sprint-review** | Parallel reviewer agents (security, backend, frontend, pattern). Enforces 5 carry-forward invariants. Auto-injects planning inputs for next sprint. | `/blitz:sprint-review [--sprint N]` |

### Code Quality

| Skill | What it does | Invocation |
|-------|-------------|------------|
| **code-doctor** | Framework-API correctness audit: Firestore anti-patterns, VueFire binding, Vue 3 reactivity misuse, Pinia store coupling. Read-only by default. | `/blitz:code-doctor [--fix]` |
| **code-sweep** | 30 checks across 7 categories. Ratchet mechanism ensures quality only improves. Loop-safe. | `/blitz:code-sweep [--loop\|--category <name>]` |
| **codebase-audit** | 5-pillar audit: Architecture, Performance, Security, Maintainability, Robustness | `/blitz:codebase-audit` |
| **completeness-gate** | Scans for placeholder patterns and production-readiness issues. Returns structured findings with `file:line` refs. | `/blitz:completeness-gate [scope]` |
| **integration-check** | Export-to-import tracing, route coverage, auth guard coverage, store-to-component wiring. Read-only. | `/blitz:integration-check [scope]` |
| **ui-audit** | Cross-page semantic consistency + data-quality + UX heuristics. Extracts labeled value registry, asserts invariants, flags placeholders/nulls/flapping. Loop-safe. | `/blitz:ui-audit [full\|smoke\|data\|buttons\|events\|consistency\|heuristics\|role <name>\|--loop]` |
| **quality-metrics** | Collects, stores, and visualizes code quality metrics over time | `/blitz:quality-metrics [collect\|dashboard\|trend\|compare]` |
| **perf-profile** | Bundle size, runtime performance, Lighthouse scores | `/blitz:perf-profile [bundle\|runtime\|lighthouse]` |
| **dep-health** | Vulnerabilities, outdated packages, license compliance | `/blitz:dep-health [audit\|upgrade\|report]` |

### Core Development

| Skill | What it does | Invocation |
|-------|-------------|------------|
| **ui-build** | 5-phase workflow (Discover, Analyze, Design, Implement, Refine). Phase 3.0 aesthetic-direction selection + Phase 5.4.2 vision-critique loop via design-critic. Generates Vue 3 UI native to the project's design system. | `/blitz:ui-build <feature description>` |
| **design-extract** | Reads brownfield design tokens (Tailwind config, CSS variables, font sources, accent-color usage) and emits `DESIGN.md`. Bootstraps the design-critic / ui-build / frontend-design pipeline. | `/blitz:design-extract` |
| **browse** | Playwright MCP browser testing. Captures console errors, failed network requests. Auto-fix mode. Loop-safe. | `/blitz:browse [full\|smoke\|page <path>\|fix\|--loop]` |
| **refactor** | Incremental refactoring with test snapshot before/after each step | `/blitz:refactor <file-or-dir> <goal>` |
| **test-gen** | Tests matching project conventions (Vitest/Jest auto-detect). AAA pattern, factory functions, edge cases. | `/blitz:test-gen <file-path>` |
| **fix-issue** | Fetches GitHub issue → researches root cause → implements fix with tests → updates issue | `/blitz:fix-issue <issue-number>` |
| **migrate** | Framework/library/tooling migrations. Researches breaking changes, atomic steps, verifies after each. | `/blitz:migrate <target>` |
| **bootstrap** | Greenfield project scaffold or feature/package scaffold into existing project | `/blitz:bootstrap <type> <name>` |
| **quick** | Small targeted edits without skill ceremony | `/blitz:quick <request>` |

### Documentation & Release

| Skill | What it does | Invocation |
|-------|-------------|------------|
| **doc-gen** | API docs, component docs, architecture diagrams, changelogs from source | `/blitz:doc-gen [api\|components\|architecture\|changelog\|full]` |
| **release** | Semantic versioning, changelog, GitHub release | `/blitz:release [prepare\|verify\|publish\|rollback]` |

### Analysis & Meta

| Skill | What it does | Invocation |
|-------|-------------|------------|
| **codebase-map** | 4-dimension analysis (Technology, Architecture, Quality, Concerns). Produces `CODEBASE-MAP.md` for brownfield onboarding. | `/blitz:codebase-map` |
| **compress** | Rewrites markdown/text files to terse form to reduce input tokens. Preserves code, URLs, tables, YAML/JSON verbatim. | `/blitz:compress <file>` |
| **retrospective** | Analyzes completed sessions, identifies patterns, generates self-improvement proposals with safety classification | `/blitz:retrospective` |
| **setup** | Detects conflicts between CLAUDE.md files and blitz skill behaviors. Validates permissions and stack assumptions. | `/blitz:setup` |
| **health** | Plugin health check — hooks, sessions, registry, structural integrity | `/blitz:health` |
| **conform** | Detects + fixes drift in an existing project's blitz runtime artifacts (`.cc-sessions/`, `sprints/`, `docs/roadmap/`, `docs/_research/`, `STATE.md`) against the current canonical schemas in `skills/_shared/`. Use after upgrading blitz when sprint-dev/review starts complaining about missing fields. Read-only by default; `--fix` applies migrations. `--scope plugin` available for plugin-fork structural drift. | `/blitz:conform [target-dir] [--fix\|--report-only] [--scope project\|plugin\|all]` |
| **todo** | Track development todos in `.cc-sessions/todos.jsonl` | `/blitz:todo [add\|list\|check\|resolve]` |

---

## Agents (10)

Agents fall into three roles. **Builder agents** are spawned by skills using `isolation: "worktree"` — each gets its own git branch that is auto-cleaned if no changes are made. **Critic agents** are read-only adversarial reviewers spawned at gate points. The **orchestrator** is the plugin's main-thread agent for freeform input.

### Builder agents (6)

| Agent | Role | MCP Scope |
|-------|------|-----------|
| **backend-dev** | Cloud Functions v2 / Zod / Firestore implementation. Numbered comment flow, audit logging patterns. | Firestore, Firebase |
| **frontend-dev** | Vue 3 / Pinia components, stores, composables, routes. Adapts to Tailwind/Quasar/Vuetify. | Playwright |
| **test-writer** | Vitest/Jest tests. AAA pattern, factory functions, coverage awareness, regression tests. | Read-only |
| **reviewer** | Code quality and security review. OWASP top-10, pattern violations, correctness issues. | Read-only |
| **architect** | Read-only architecture analysis — coupling, cohesion, module boundaries, dependency graphs. | Read-only |
| **doc-writer** | API docs, component docs, ADRs, README sections, migration guides from source. (haiku — mechanical work) | Read-only |

### Critic agents (3) — adversarial reviewers

| Agent | Role | Spawned at |
|-------|------|------------|
| **critic** | Adversarial pre-PASS reviewer. Runs the 19-detector shortcut taxonomy + ratchet + acceptance-checks + hallucinated-symbol spot-check. Returns canonical `{verdict: LGTM \| REJECT}` JSON. Optional Gemini variant via `BLITZ_USE_GEMINI_CRITIC=1` (Cross-Model Critic per arxiv 2604.19049). | `sprint-review` Phase 3.6 Invariant 7 |
| **research-critic** | Read-only citation + claim reviewer. Probes every cited URL, classifies LIVE/DEAD/LIKELY_HALLUCINATED/UNKNOWN per the urlhealth taxonomy. Verifies `> "..."` quoted spans appear in fetched source content (Deterministic Quoting). Returns `{verdict: PASS \| CITATIONS_MISSING}`. | `research` skill Phase 3.2.5 |
| **design-critic** | Vision-based aesthetic scorer. Reads `/tmp/ui-build-screenshots/*.png` against `DESIGN.md` and scores 5 dimensions (Prompt Adherence, Aesthetic Fit, Visual Polish, UX, Creative Distinction). Verdicts `PASS / ITERATE / REWORK`. | `ui-build` Phase 5.4.2 |

### Orchestrator (1)

| Agent | Role |
|-------|------|
| **orchestrator** | Top-level main-thread agent (Sonnet, read-only — no Write/Edit/Agent). Receives freeform input, surfaces in-flight state from `.cc-sessions/HANDOFF.json` + activity feed, routes to the right `/blitz:*` skill. Activated via `.claude-plugin/settings.json {"agent": "orchestrator"}`. Disable with `BLITZ_DISABLE_ORCHESTRATOR=1`. |

### Typed Agent Definitions

Drop typed agent YAML files into `.claude/agents/` to scope MCP server access per agent. Sprint-dev auto-detects these at spawn time:

```
.claude/agents/
├── blitz-backend-dev.md   # mcpServers: [firebase]
├── blitz-frontend-dev.md  # mcpServers: [playwright]
└── blitz-test-writer.md   # tools: read-only only
```

---

## Hooks (36 scripts, 16 events)

| Event | Matcher | Script | Behavior |
|-------|---------|--------|----------|
| `PreCompact` | `auto\|manual` | `pre-compact-snapshot.sh` | Writes `.cc-sessions/compact-state.json` AND `.cc-sessions/HANDOFF.json` (sprint, phase, branch, head SHA, recent files, resume hint) — survives context compaction and SessionStart auto-resume |
| `PostCompact` | `auto\|manual` | `post-compact-log.sh` | Reads snapshot, appends restoration hint to activity feed |
| `UserPromptExpansion` | `blitz:.*` | `blitz-prompt-expansion.sh` | Injects last 5 activity-feed events as `additionalContext` into every `blitz:*` invocation |
| `SessionStart` | — | `session-start.sh` | Detects fresh `HANDOFF.json` (≤24h) and offers auto-resume; otherwise prints recent cross-session activity |
| `TeammateIdle` | — | `teammate-idle.sh` | Quality gate for agent teams — can return feedback (exit 2) |
| `TaskCompleted` | — | `task-completed-validate.sh` | Validates task completion against Definition of Done |
| `PostToolUse` | `Write\|Edit` | `post-edit-activity-log.sh` | Appends `file_change` event to activity feed |
| `PostToolUse` | `Write\|Edit` | `post-edit-format.sh` | Auto-formats with Prettier or Biome (auto-detected) |
| `PostToolUse` | `Write\|Edit` | `post-edit-lint.sh` | Auto-lints with ESLint or Biome (auto-detected) |
| `PostToolUse` | `Write\|Edit` | `post-edit-test.sh` | Runs matching test file after source edits |
| `PostToolUse` | `Write\|Edit` | `analysis-paralysis-guard.sh` | Warns after 5+ consecutive reads without writes |
| `PostToolUse` | `Read\|Glob\|Grep` | `analysis-paralysis-guard.sh` | Same guard on read-heavy operations |
| `PostToolUse` | `Write\|Edit` | `skill-frontmatter-validate.sh` | Lints modified `SKILL.md` against canonical frontmatter contract |
| `PostToolUse` | `Write\|Edit` | `agent-frontmatter-validate.sh` | Lints modified `agents/*.md` — required fields, body cap, OUTPUT STYLE snippet, blocks silently-stripped fields (hooks/mcpServers/permissionMode) |
| `PostToolUse` | `Read\|Glob\|Grep\|Bash` | `context-monitor.sh` | Tracks context window utilization, warns at ~60% and ~80% |
| **PreToolUse blockers (anti-shortcut)** | | | |
| `PreToolUse` | `Bash` | `block-no-verify.sh` | **Blocks** `git commit --no-verify`. Override: `BLITZ_OVERRIDE_NO_VERIFY=1` (logged) |
| `PreToolUse` | `Bash` | `block-destructive-git.sh` | **Blocks** `reset --hard`, `checkout -- .`, `clean -f`, force-push to main, `branch -D` on dirty current branch |
| `PreToolUse` | `Bash` | `block-destructive-sql.sh` | **Blocks** `DROP TABLE` / `DELETE FROM`-no-`WHERE` / `TRUNCATE` / `FLUSHDB` / Mongo `.drop()` outside migrations |
| `PreToolUse` | `Bash\|Write` | `block-test-deletion.sh` | **Blocks** `rm` of test files, renames test→non-test, Write that drops all assertions to zero |
| `PreToolUse` | `Write\|Edit\|MultiEdit` | `block-as-any-insertion.sh` | **Blocks** new `as any` / `@ts-ignore` / `@ts-nocheck` in non-test source. Override: inline `// blitz:any-allowed: <reason>` |
| `PreToolUse` | `Write\|Edit\|MultiEdit` | `block-test-disabling.sh` | **Blocks** new `.skip(`, `.only(`, `xit`, `xdescribe`, `xtest`, `test.todo(` in test files. Override: inline `// blitz:skip-pinned: #<issue>` |
| `PostToolUse` | `Write\|Edit` | `post-edit-typecheck-block.sh` | Runs `tsc --noEmit`; **blocks** if error count rose vs `.cc-sessions/typecheck-baseline.json` |
| **PreToolUse other** | | | |
| `PreToolUse` | `Write\|Edit` | `pre-edit-guard.sh` | Blocks edits to protected files (.env, lock files, node_modules) |
| `PreToolUse` | `Write\|Edit` | `pre-edit-backup.sh` | Creates timestamped backup in /tmp/cc-backups/ before every edit |
| `PreToolUse` | `Bash` | `pre-commit-validate.sh` | On `git commit`: SKILL.md frontmatter lint + version-sync drift check + broken markdown link warn |
| `PreToolUse` | `Bash` | `reference-compression-validate.sh` | On `git commit`: validates compressed `references/main.md` matches `.original` structure |
| `PreToolUse` | `Bash` | `markdown-link-validate.sh` | On `git commit`: warn-only scan for broken relative `.md` links |
| `PreToolUse` | `Bash` | `workflow-guard.sh` | Warns on out-of-order phase execution in phased skills |
| **New platform-event stubs (v1.15+)** — logging only, exit 0 | | | |
| `SubagentStart` | — | `subagent-start.sh` | Logs Agent tool spawn (agent_id + agent_type) to activity feed |
| `SubagentStop` | — | `subagent-stop.sh` | Logs subagent completion. Future: enforce Agent Output Contract (spawn-protocol §9) |
| `PostToolBatch` | — | `post-tool-batch.sh` | Logs parallel tool batch resolution. Future: single batched ratchet check |
| `PostToolUseFailure` | — | `post-tool-failure.sh` | Logs failed tool execution. Future: auto-recover from common failure modes |
| `StopFailure` | — | `stop-failure.sh` | Logs turn-end API errors (rate_limit/billing_error/server_error/max_output_tokens) |
| `PermissionRequest` | — | `permission-request.sh` | Logs permission-prompt opportunities. Future: auto-approve safe read-only patterns |
| `WorktreeCreate` | — | `worktree-create.sh` | Logs worktree creation. Synchronous (non-zero ABORTS), prints nothing to stdout |
| `WorktreeRemove` | — | `worktree-remove.sh` | Logs worktree removal |

> **Plus** `hooks/scripts/critic-gemini.sh` — invoked from sprint-review (not a hook event). See [Cross-Model Critic](#3-cross-model-critic-cmc--optional-gemini-integration) above.

---

## Carry-Forward Registry

The carry-forward registry (`.cc-sessions/carry-forward.jsonl`) is the backbone of the blitz cycle. It tracks quantified scope claims across sprints and prevents silent drops.

**How it works:**

1. `/blitz:research` emits a `scope:` YAML block when the research doc contains quantified claims (e.g., "migrate 45 components"):
   ```yaml
   ---
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
   ---
   ```

2. `/blitz:roadmap extend` (auto-invoked by `/blitz:sprint`) ingests the block as a registry entry with `status: active`, `coverage: 0.0`.

3. Sprint-plan treats every `status ∈ {active, partial}` entry as a mandatory planning input.

4. Sprint-dev advances `delivered.actual` and `coverage` as stories complete.

5. Sprint-review enforces **8 invariants** — registry consistency, epic completion, OUTPUT STYLE coverage, **ratchet** (8 monotonic metrics: `test_count`, `type_errors`, `as_any_count`, `lint_violations`, `completeness_score`, `mocks_in_src`, `todo_count`, `stale_worktree_branch_count` — `type_errors > 0` is an absolute floor), **critic** LGTM, and **branch hygiene** (per-sprint cleanup). The loop cannot exit while entries remain active. Entries stuck for 3+ sprints are escalated with rollover banners.

6. When `coverage` reaches 1.0, the entry transitions to `status: complete`.

---

## Shared Protocols (`skills/_shared/`)

All skills share 20 protocol files that define cross-cutting behavior:

| Protocol | Purpose |
|----------|---------|
| `session-protocol.md` | Multi-session safety — file locks, conflict matrix, session registration, autonomy levels |
| `verbose-progress.md` | Output format and activity feed logging spec |
| `definition-of-done.md` | Banned anti-patterns (TODO/FIXME/placeholder/mock in production, etc.) |
| `checkpoint-protocol.md` | Sprint STATE.md format and resume flow |
| `deviation-protocol.md` | 4-tier escalation for unexpected implementation issues |
| `context-management.md` | Context window hygiene rules — when to summarize, when to offload to STATE.md |
| `carry-forward-registry.md` | Carry-forward registry — schema, **canonical Reader Algorithm**, writer contracts, rollover escalation |
| `story-frontmatter.md` | Canonical YAML schema for sprint stories — producer/consumer matrix, validation algorithm, `acceptance_checks:` schema (grep_present \| grep_absent \| shell \| ast_absent), `design_quality:` enum |
| `state-handoff.md` | Pipeline contracts — which artifacts each skill produces/requires |
| `spawn-protocol.md` | Agent spawn rules — type selection, workload sizing, HEARTBEAT/PARTIAL, **Agent Output Contract**, three-tier timeout (soft 20m / idle 10m / hard 30m), stuck-loop detection, WRAP_UP at 70% context, JSON reply contract |
| `terse-output.md` | Output style — canonical exemptions list, intensity precedence, OUTPUT STYLE snippet |
| **`token-budget.md`** *(v1.11+)* | Model routing matrix (60% Haiku / 35% Sonnet / 5% Opus), mandatory `cache_control: {ttl: "1h"}` on prompts ≥1024 tokens, lazy skill load, deferred MCP via ToolSearch. Combined target: 50–70% cut on top of 15× multi-agent baseline. |
| **`ratchet-protocol.md`** *(v1.11+)* | 8 monotonic quality metrics (incl. `stale_worktree_branch_count` added 2026-05-17), `docs/sweeps/ratchet.json` schema, multi-agent worktree merge takes `min(max_allowed)` deterministically, auto-revert on regression |
| **`shortcut-taxonomy.md`** *(v1.11+)* | 19-detector catalog with canonical grep patterns, severity tiers (P0/P1/P2/P3), false-positive escape hatches |
| **`knowledge-protocol.md`** *(v1.11+)* | `.cc-sessions/KNOWLEDGE.md` cross-session lessons format (Context / Lesson / How to apply). Append-only paragraphs. Pruned at 500 lines. |
| **`frontend-design-heuristics.md`** *(v1.11+)* | Paraphrased aesthetic philosophy, 13-tone selector, NEVER list (Inter/Roboto/Arial/Space Grotesk + purple-on-white + uniform corners + all-centered + default Tailwind palette) |
| **`agent-routing.md`** *(v1.11+)* | Orchestrator routing decision tree. Documents the subagents-cannot-spawn-subagents constraint. Super-orchestrator skills stay slash-invoked. |
| `agent-prompt-boilerplate.md` / `scheduling.md` / `session-report-template.md` | Agent prompt preamble, loop-mode scheduling, session report format |

---

## Model Profiles

Three behavioral profiles control skill thoroughness. Set in `.claude-plugin/model-profiles.json`.

| Profile | Research Agents | Verification | Optional Phases | Use Case |
|---------|----------------|-------------|-----------------|----------|
| **quality** | Max | 2 passes | All run | Critical features, production releases |
| **balanced** | Standard | 1 pass | All run | Default — everyday development |
| **budget** | Min | 1 pass | Skip browser/E2E | Quick iterations, prototyping |

---

## Architecture

```
blitz/
├── .claude-plugin/
│   ├── plugin.json              # Manifest (name, version, author)
│   ├── marketplace.json         # Marketplace catalog
│   ├── settings.json            # {"agent": "orchestrator"} — main-thread agent activation (v1.11+)
│   └── model-profiles.json      # quality / balanced / budget profiles
├── installer/
│   ├── bin/install.js           # npx blitz-cc entry point
│   ├── src/                     # Zero-dependency Node.js modules
│   └── install.sh               # Bash fallback (curl | bash)
├── scripts/                     # Maintenance + detection scripts (detect-stack, validate-*, etc.)
├── skills/                      # 38 skill directories
│   ├── _shared/                 # 20 shared protocol files
│   ├── sprint/                  # Orchestrator — auto-chains roadmap extend
│   ├── sprint-plan/             # Carry-forward-aware sprint planning
│   ├── sprint-dev/              # Monitor-tool progress, worktree isolation
│   ├── sprint-review/           # 8 invariants (registry + ratchet + critic + branch-hygiene)
│   ├── research/                # Parallel agents → scope: YAML; research-critic gate
│   ├── roadmap/                 # Research ingestion → epic-registry
│   ├── ui-build/                # 5-phase + design-critic vision loop
│   ├── design-extract/          # Brownfield design tokens → DESIGN.md (v1.11+)
│   ├── code-doctor/             # Framework-API correctness audit
│   ├── conform/                 # Brings legacy project artifacts into current spec
│   └── ... (28 more)
├── agents/                      # 10 agents
│   ├── orchestrator.md          # Top-level main-thread router (v1.11+)
│   ├── critic.md                # Adversarial pre-PASS reviewer (v1.11+)
│   ├── research-critic.md       # Citation + claim reviewer (v1.11+)
│   ├── design-critic.md         # Vision-based aesthetic scorer (v1.11+)
│   ├── backend-dev.md           # Firestore/VueFire/Cloud Functions
│   ├── frontend-dev.md          # Vue 3/Pinia/Quasar/Tailwind
│   ├── test-writer.md           # Vitest/Jest AAA
│   ├── reviewer.md              # OWASP + pattern review
│   ├── architect.md             # Read-only dependency analysis
│   └── doc-writer.md            # API docs, ADRs, changelogs (haiku — mechanical work)
└── hooks/
    ├── hooks.json               # 8 event types wired
    └── scripts/                 # 27 hook scripts + critic-gemini.sh utility
        # Anti-shortcut blockers (v1.11+)
        ├── block-no-verify.sh           # PreToolUse: block git --no-verify
        ├── block-destructive-git.sh     # PreToolUse: reset --hard, force-push to main, etc.
        ├── block-destructive-sql.sh     # PreToolUse: DROP/DELETE-no-WHERE/TRUNCATE outside migrations
        ├── block-test-deletion.sh       # PreToolUse: rm of tests, renames, empty Writes
        ├── block-as-any-insertion.sh    # PreToolUse: as any / @ts-ignore / @ts-nocheck in non-test
        ├── block-test-disabling.sh      # PreToolUse: .skip / .only / xit / xdescribe in tests
        ├── post-edit-typecheck-block.sh # PostToolUse: tsc --noEmit error-count rise
        # Validators (v1.11 added agent-frontmatter-validate)
        ├── skill-frontmatter-validate.sh
        ├── agent-frontmatter-validate.sh
        # Cross-Model Critic wrapper (not a hook event — invoked from sprint-review)
        ├── critic-gemini.sh             # Wraps @google/gemini-cli for pre-pass / research / design
        # Autonomy + state
        ├── pre-compact-snapshot.sh      # PreCompact: HANDOFF.json + compact-state.json
        ├── session-start.sh             # SessionStart: HANDOFF auto-resume + activity feed summary
        # ... (15 more — see hooks/scripts/README.md for full event-grouped index)
```

---

## Runtime Artifacts

Blitz generates runtime state in the project directory. These are **gitignored** — they are machine-local outputs of the plugin, not plugin source:

```
sprints/             # Sprint stories, manifests, STATE.md checkpoints
sprint-registry.json # Live sprint tracking
.cc-sessions/        # Session state, activity feed, carry-forward registry
docs/_research/      # Generated research documents
docs/roadmap/        # Generated roadmap, epic-registry, capability-index
docs/retrospective/  # Session retrospective proposals
```

### Conforming after upgrades

Existing projects that were bootstrapped on an older blitz version may carry artifact drift — old story-frontmatter schema (`epic` instead of `epic_id`), missing `registry_entries` field, STATE.md formats no longer mentioned in shared protocols, etc. Run **`/blitz:conform`** to detect drift; **`/blitz:conform --fix`** to apply mechanical migrations idempotently with per-file backups. Default scope is `project` (runtime artifacts); `--scope plugin` targets plugin forks. See `skills/conform/SKILL.md` and `skills/conform/references/main.md` for the full schema-detection rules and migration tables.

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

The installer is idempotent — safe to run multiple times. Merges settings without overwriting your existing configuration.

---

## Contributing

1. Fork the repository
2. Create a feature branch
3. Test locally: `claude --plugin-dir .` then `/reload-plugins` after edits
4. Validate structure: `./scripts/validate-plugin-structure.sh`
5. Add a CHANGELOG entry
6. Submit a pull request

## Acknowledgments

- Clarification Gate (`CLAUDE.md`) and Scope Discipline (`skills/_shared/definition-of-done.md`) adapted from [multica-ai/andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills) (MIT). Original principles by Andrej Karpathy.

## License

MIT
