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
[![Version](https://img.shields.io/github/v/release/lasswellt/blitz-cc?color=cyan)](https://github.com/lasswellt/blitz-cc/releases)

</div>

---

## What is Blitz?

Blitz is a **holistic machine**: a set of parts wired so that natural-language intent goes in one end and shippable, gated code comes out the other — with no step able to silently skip the one after it. It turns Claude Code into an opinionated, partly-autonomous development environment for Vue/Nuxt + Firebase.

The mechanism, in one breath: **freeform input lands on a read-only orchestrator that routes to a `/blitz:*` skill; skills spawn worker agents in isolated worktrees; every artifact they produce is checked at a gate that runs off a single shared rule registry; an adversarial critic must sign off before anything reaches `PASS`; and the whole loop persists its state to disk so it can resume itself unattended.**

Four properties make it a *machine* rather than a pile of prompts:

- **State is external and append-only.** Scope claims, sprint progress, quality metrics, and cross-session handoff all live in `.cc-sessions/` — so any tick can reconstruct what the last one was doing.
- **Gates run on data, not vibes.** Detection logic lives in one `check-registry.json`; skills and critics *select* from it. A check either fires deterministically (grep/tsc/git) or is an LLM judgment — and the registry records which, so only facts can block.
- **Verification is adversarial and external.** The critic's job is to find one reason to REJECT; the research-critic's job is to catch a hallucinated citation. Both are read-only and can be routed to a *different model family* to dodge home-model blind spots.
- **It closes the loop.** `/blitz:next --loop` reads state, dispatches exactly one phase, commits, and exits — so `/loop` or a scheduler can re-tick it toward "shippable" without a human in the chair.

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

The installer detects your stack, registers the plugin, configures permissions, and wires the hooks. From then on you mostly type intent and let the orchestrator route.

<details>
<summary><b>More install options</b></summary>

**Non-interactive:** `npx blitz-cc@latest --yes`
**Bash fallback** (no Node): `curl -fsSL https://raw.githubusercontent.com/lasswellt/blitz-cc/main/installer/install.sh | bash`
**Marketplace:** `/plugin marketplace add lasswellt/blitz-cc` then `/plugin install blitz@blitz`
**Local dev:** `claude --plugin-dir ./blitz` then `/reload-plugins`

</details>

### First five minutes

```bash
/blitz:next                       # reads state, recommends the next command
/blitz:ask "I want to add X"      # routes a vague request to the right skill(s)
/blitz:research <topic>           # parallel-agent investigation → docs/_research/
/blitz:sprint                     # full cycle: plan → implement → review
/blitz:review                     # the precision quality gate, on demand
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

The pipeline is a conveyor belt where **each station hands a typed artifact to the next, and the carry-forward registry threads every scope claim end-to-end so nothing is silently dropped**:

```
/blitz:research <topic>
        │ writes docs/_research/<date>_<slug>.md with quantified `scope:` YAML
        │ research-critic probes every cited URL + verifies quoted spans (Phase 3.2.5)
        ▼
/blitz:roadmap extend   → seeds epic-registry.json + carry-forward.jsonl from scope claims
        ▼
/blitz:sprint-plan      → unblocked epics → stories w/ dependency ordering + GitHub issues
        ▼
/blitz:sprint-dev       → builder agents in isolated worktrees, merged per-role on completion
        ▼
/blitz:review           → both detection lanes + parallel reviewers + critic + 8 invariants
        ▼
/blitz:ship             → review --only completeness → quality-metrics → release → notify
```

**Why it holds together:** every `scope:` claim from research becomes a carry-forward entry; sprint-plan *must* read that ledger; sprint-review reconciles it; and an entry that rolls over three sprints escalates for human review. The claim cannot evaporate between stations.

### Autonomous loop

```bash
/loop 5m /blitz:next --loop
```

`/blitz:next --loop` is the project-lifecycle reconciliation engine. Each tick reads current state, walks an 8-row decision tree, **dispatches exactly one phase**, commits/pushes, and exits cleanly so the wrapper can re-tick. Stop signals tell the wrapper when to halt:

| Signal | Meaning |
|---|---|
| `LOOP_DONE` | Idle — nothing to reconcile. |
| `LOOP_ESCALATE` | A carry-forward entry rolled over ≥3 sprints — human review required. |
| `LOOP_DEFER` | Active session conflict — keep ticking; next tick may resolve it. |
| *(no marker)* | Phase dispatched; next tick re-evaluates. |

`PreCompact` writes `.cc-sessions/HANDOFF.json` (sprint, phase, branch, head SHA, recent files); `SessionStart` detects a fresh handoff (≤24h) and resumes without re-reading every protocol. That handoff file is *how the machine survives its own context window*.

---

## The Holistic Machine

Four layers turn a skill collection into a partly-autonomous environment. Slash commands still work unchanged.

### 1. Orchestrator (freeform-input router)

`agents/orchestrator.md` is wired as the plugin's main-thread agent via `.claude-plugin/settings.json` (`{ "agent": "orchestrator" }`). It is **read-only by construction** — its tools are `Read, Grep, Glob, Bash, TaskCreate, TaskUpdate, TaskList, Monitor`, with no Write/Edit/Agent. That constraint is load-bearing: Claude Code forbids subagents from spawning subagents, so any skill that fans out parallel agents (sprint-dev, sprint-plan, research, audit, …) stays slash-invoked, and the orchestrator *routes to it* rather than running it. See [`skills/_shared/agent-routing.md`](skills/_shared/agent-routing.md).

```bash
export BLITZ_DISABLE_ORCHESTRATOR=1   # opt out per session
```

### 2. Anti-shortcut blockers

Six `PreToolUse` blockers and one `PostToolUse` typecheck ratchet stop the most damaging autonomous-coder shortcuts **at the tool boundary** — before they ever land — each returning `exit 2` with an explicit, logged override path:

`--no-verify` bypass · destructive git on a dirty tree · destructive SQL outside a migration · test deletion · `as any` insertion · test disabling · type-error regression.

These are the catastrophic (P0) classes from the shortcut taxonomy; they're enforced as hooks precisely because their blast radius is too large to defer to review.

### 3. Sprint-review invariants (8)

A sprint cannot reach `PASS` while any invariant fails. They are deliberately mostly *deterministic* — carry-forward consistency, the monotonic quality ratchet (`type_errors` is an absolute floor), branch hygiene, and the **critic LGTM** (Invariant 7). The one judgment-heavy invariant is advisory by design. Facts gate; opinions annotate.

### 4. Cross-Model Critic (optional)

The adversarial critic can be lifted verbatim and piped to a different model family (Gemini) so it doesn't share Claude's blind spots on Claude's own work:

| Env var | Mode |
|---|---|
| *(unset)* | In-Claude critic only (cheapest) |
| `BLITZ_USE_GEMINI_CRITIC=1` | Replace in-Claude critic with Gemini |
| `BLITZ_DUAL_CRITIC=1` | Run both; require both LGTM (highest signal, ~2× cost) |

**When to pay for dual** is principled: in-Claude is fine for ground-truth checks (`tsc`/`git`/reflog can't share a blind spot); dual is recommended for the semantic/judgment findings where home-model blind spots actually bite.

---

## How review & audit work (the shared-registry core)

The quality surface is **two entry points over one rule registry** — the cleanest illustration of "gates run on data, not vibes."

```
                 skills/_shared/check-registry.json   (30 checks)
                 each row: lane · verdict_authority · base_confidence · detection
                          │
         ┌────────────────┴────────────────┐
         ▼                                 ▼
   /blitz:review                      /blitz:audit
   precision · per-change             recall · pre-release
   both lanes, semantic single-pass   both lanes, semantic AGGREGATED
   --min-confidence high              --min-confidence low
   FP-verify inline                   FP-verify panel (refute + majority vote)
         └───────────────┬─────────────────┘
                         ▼
   agents/critic.md  +  agents/research-critic.md  (read-only, registry-driven)
```

Three ideas do the work:

- **Two orthogonal lanes, always both.** A *deterministic* lane (grep/AST/tsc/git/import-graph — zero false positives) and a *semantic* lane (LLM agents reasoning about behavior). They catch **disjoint** bug classes — a deleted test has no semantic signature; a wrong answer-key has no structural one — so running only one ships errors.
- **Verdict-flip asymmetry.** Each check's `verdict_authority` is *derived* from its lane + severity: ground-truth checks may flip a verdict to REJECT (and bypass confidence triage — a fact isn't ranked); judgment checks may only annotate. This neutralizes the self-critique paradox, where an over-eager opinion-critic hallucinates flaws.
- **Confidence, by skill bias.** `review` is precision-biased (suppress low-confidence advisories — it runs constantly); `audit` is recall-biased (report everything, ranked, and *aggregate* — a finding flagged by ≥2 independent agents is high-confidence; one re-read-and-refute panel drops the hallucinations). Nothing becomes a blocker without reproducing evidence.

`completeness-gate` and `integration-check` are now `review --only completeness|wiring`; the 5-pillar `audit` engine carries the aggregation + FP-verify + recall instrumentation. Detection patterns live in the registry — no skill or agent body duplicates a grep.

---

## Skill Catalog (37)

### Orchestrators

| Skill | What it does | Invocation |
|---|---|---|
| **next** | Reads sprint/roadmap/carry-forward state, recommends (or `--loop` auto-dispatches) the next action. | `/blitz:next [--loop]` |
| **ask** | Classifies a vague request and routes it via decision tree. | `/blitz:ask <request>` |
| **sprint** | Full cycle: plan → implement → review. `--loop` aliases `/blitz:next --loop`. | `/blitz:sprint [--plan-only\|--skip-review\|--loop\|--gaps\|--resume]` |
| **implement** | Thin dispatcher to sprint-dev. | `/blitz:implement [--sprint N\|--resume]` |
| **review** | Consolidated **precision** gate — both lanes, confidence gate, FP-verify, critic; `--only` runs a folded concern. | `/blitz:review [--sprint N\|--only completeness\|wiring\|framework\|full\|--dual]` |
| **audit** | Consolidated **recall** deep audit — 5 pillars + aggregation + FP-verify panel + coverage boundary. | `/blitz:audit [scope\|--min-confidence low\|high\|--dual]` |
| **ship** | review → review --only completeness → quality-metrics → release → notify. | `/blitz:ship [version]` |

### Sprint lifecycle

| Skill | What it does | Invocation |
|---|---|---|
| **research** | Parallel research agents → `docs/_research/<date>_<topic>.md` with quantified `scope:` YAML; research-critic verifies citations + quoted spans. | `/blitz:research <topic>` |
| **roadmap** | Phased roadmaps; `extend` ingests new research into the carry-forward registry. | `/blitz:roadmap [full\|refresh\|extend\|status]` |
| **sprint-plan** | Plans a sprint from unblocked epics; reads `carry-forward.jsonl` as mandatory input; spawns GitHub issues. | `/blitz:sprint-plan [--sprint N\|--gaps]` |
| **sprint-dev** | Spawns backend/frontend/test agents in isolated worktrees; Monitor-driven; merges per-role branches on completion. | `/blitz:sprint-dev [--sprint N\|--resume\|--mode …]` |
| **sprint-review** | The `review` *engine*: 5 auto-gates + 4 reviewer agents + critic + the 8-invariant carry-forward hard gate. | `/blitz:sprint-review [--sprint N]` |

### Code quality — 2 gates, 2 tools, over the registry

| Skill | Role | Invocation |
|---|---|---|
| **review** / **audit** | the two registry-driven entry points (above) — precision gate / recall deep-audit | — |
| **code-doctor** | framework-API anti-patterns (Firestore/VueFire/Vue 3/Pinia); review embeds the scan, `--fix` stays here | `/blitz:code-doctor [--fix\|--scan]` |
| **code-sweep** | convention-discovered standards + monotonic ratchet; loop-safe continuous improvement | `/blitz:code-sweep [--loop\|--category <n>\|--deep]` |
| **ui-audit** | cross-page semantic + data-quality + UX invariants (orthogonal domain) | `/blitz:ui-audit [full\|data\|consistency\|--loop]` |
| **quality-metrics** | metric trends over time (orthogonal observability) | `/blitz:quality-metrics [collect\|dashboard\|trend\|compare]` |
| **perf-profile** | bundle / runtime / Lighthouse vs baseline (orthogonal) | `/blitz:perf-profile [bundle\|runtime\|lighthouse]` |
| **dep-health** | `npm audit` + outdated + license (orthogonal) | `/blitz:dep-health [audit\|upgrade\|report]` |

### Core development

| Skill | What it does | Invocation |
|---|---|---|
| **ui-build** | Discover → Analyze → Design → Implement → Refine; vision-critique loop via design-critic. | `/blitz:ui-build <feature>` |
| **design-extract** | Extracts brownfield design tokens → portable `DESIGN.md`. | `/blitz:design-extract` |
| **browse** | Playwright testing — console/network errors + screenshots; loop-safe. | `/blitz:browse [full\|page <path>\|fix\|--loop]` |
| **refactor** | Snapshot tests, refactor one piece at a time, revert on any regression. | `/blitz:refactor <target> <goal>` |
| **test-gen** | Tests in project conventions (Vitest/Jest), AAA + factories. | `/blitz:test-gen <file>` |
| **fix-issue** | GitHub issue → research → fix with tests → close via `gh`. | `/blitz:fix-issue <#>` |
| **migrate** | Framework/library migrations; atomic verified steps. | `/blitz:migrate <target>` |
| **bootstrap** | Greenfield scaffold or feature/package into an existing project. | `/blitz:bootstrap <type> <name>` |
| **quick** | Small targeted edits without sprint ceremony. | `/blitz:quick <request>` |

### Documentation & release

| Skill | What it does | Invocation |
|---|---|---|
| **doc-gen** | API/component docs, Mermaid diagrams, CHANGELOG from commits. | `/blitz:doc-gen [api\|components\|architecture\|changelog\|full]` |
| **release** | Semver, CHANGELOG, GitHub release. | `/blitz:release [prepare\|verify\|publish\|rollback]` |

### Analysis & meta

| Skill | What it does | Invocation |
|---|---|---|
| **codebase-map** | 4-dim brownfield onboarding map → `CODEBASE-MAP.md`. | `/blitz:codebase-map` |
| **compress** | Terse-rewrites markdown (preserves code/URLs/tables); `.original` backup. | `/blitz:compress <file>` |
| **retrospective** | Mines activity-feed + diffs → safety-classified self-improvement proposals. | `/blitz:retrospective` |
| **setup** | Detects CLAUDE.md ↔ skill conflicts; validates permissions/stack. | `/blitz:setup` |
| **health** | Plugin structural integrity (hooks, sessions, locks, frontmatter). | `/blitz:health` |
| **conform** | Migrates a project's blitz runtime artifacts to current schemas. | `/blitz:conform [dir] [--fix]` |
| **todo** | Tracks todos in `.cc-sessions/todos.jsonl` with `file:line`. | `/blitz:todo [add\|list\|resolve]` |
| **worktree-prune** | Safely deletes stale agent-spawned branches (dry-run default). | `/blitz:worktree-prune [--apply --merged-only]` |

### At a glance

- **Loop-safe** (4): browse, code-sweep, next, ui-audit
- **Read-only by default** (6): conform, design-extract, health, perf-profile, setup, worktree-prune
- **Multi-agent super-orchestrators** (slash-invoked): sprint-dev, sprint-plan, sprint-review, research, audit, quality-metrics, code-sweep, code-doctor, ui-audit
- **Pure chainers**: sprint, ship, fix-issue, ui-build, review, bootstrap, conform, setup, browse, perf-profile, next

---

## Agent Catalog (10)

Three roles. **Builder agents** are spawned by skills via `Agent({isolation: "worktree"})` — each gets its own auto-cleaned branch. **Critic agents** are read-only adversarial reviewers at gate points. The **orchestrator** is the main-thread router.

### Builder agents (6)

| Agent | Model | Role |
|---|---|---|
| **backend-dev** | sonnet | Cloud Functions v2 / Zod / Firestore; numbered flow (Auth → Validate → Logic → Audit → Return). |
| **frontend-dev** | sonnet | Vue 3 `<script setup>` / Pinia; adapts to Tailwind / Quasar / Vuetify. |
| **test-writer** | sonnet | Vitest/Jest, AAA + factories. |
| **reviewer** | sonnet | OWASP top-10 + pattern violations; writes findings incrementally. |
| **architect** | sonnet | Read-only structural analysis — coupling, cohesion, circular deps. |
| **doc-writer** | haiku | API docs, ADRs, README sections (mechanical → cheaper model). |

### Critic agents (3) — adversarial reviewers

| Agent | Model | Role | Verdict |
|---|---|---|---|
| **critic** | sonnet | Registry-driven pre-`PASS` reviewer: 20-detector taxonomy + ratchet + acceptance-checks + reflog/rename scans. **Verdict-flip asymmetry** — ground-truth → REJECT, judgment → annotate. Halts at first reject. | `LGTM \| REJECT` |
| **research-critic** | sonnet | Probes every cited URL (LIVE/DEAD/LIKELY_HALLUCINATED/UNKNOWN), verifies quoted spans (Deterministic Quoting) + grounds quantified claims; `scope:` claim with no resolvable cite is a blocker. | `PASS \| UNVERIFIED \| CITATIONS_MISSING` |
| **design-critic** | sonnet | Vision-based aesthetic scorer against `DESIGN.md`; 5 dimensions. | `PASS \| ITERATE \| REWORK` |

### Orchestrator (1)

| Agent | Model | Role |
|---|---|---|
| **orchestrator** | sonnet | Read-only main-thread router (no Write/Edit/Agent — cannot spawn subagents). Surfaces in-flight state from `HANDOFF.json` + activity feed, routes to a `/blitz:*` skill. `BLITZ_DISABLE_ORCHESTRATOR=1` to opt out. |

### Typed agent definitions

Drop typed agent YAML into `.claude/agents/` to scope MCP server access per agent (sprint-dev auto-detects at spawn): `blitz-backend-dev.md` (firebase), `blitz-frontend-dev.md` (playwright), `blitz-test-writer.md` (read-only).

---

## Carry-Forward Registry

`.cc-sessions/carry-forward.jsonl` is the backbone of the cycle — an append-only ledger that tracks quantified scope claims across sprints so none is silently dropped. It's *why* the conveyor belt holds.

### Lifecycle

```
provisional → active → partial → complete
                 │         │         ▲
                 └─ rolls over ──────┘  (≥3 sprints → LOOP_ESCALATE, human review)
```

A claim enters `provisional` from research, becomes `active` when a sprint adopts it, `partial` when some acceptance checks pass, and `complete` only when all do. Every reader follows one canonical Reader Algorithm; writers append, never rewrite.

### Quality ratchet

Eight monotonic metrics (type errors, test count, mocks-in-src, `as any` count, …) are persisted and **may only improve**. A regression without a covering carry-forward entry auto-reverts. `type_errors > 0` is an absolute floor — it can never ratchet up.

---

## Worktree Lifecycle

Builder agents run in isolated git worktrees on per-role branches (`sprint-N/{backend,frontend,tests,…}`). A spawn-time collision guard prevents reusing a dirty branch; sprint-dev Phase 4.4 merges and deletes them; `/blitz:worktree-prune` sweeps any stragglers (dry-run by default, `--merged-only` is always safe). Stale-branch count is itself a ratchet metric.

---

## Token Budget

Model routing follows a 60/35/5 Haiku/Sonnet/Opus matrix: cheap mechanical work (docs) on Haiku, the bulk of builder/reviewer work on Sonnet, orchestration reasoning on Opus. Prompt caching (1-hr TTL) and lazy MCP/skill loading keep cost down; agents reply with a structured JSON contract rather than echoing findings. See [`skills/_shared/token-budget.md`](skills/_shared/token-budget.md).

---

## Architecture

```
blitz-cc/
├── .claude-plugin/
│   ├── plugin.json              # plugin manifest (main-thread agent = orchestrator)
│   ├── marketplace.json         # marketplace listing
│   └── settings.json            # { "agent": "orchestrator" }
├── agents/                      # 10 agents (6 builder · 3 critic · 1 orchestrator)
├── skills/
│   ├── <name>/SKILL.md          # 37 skills (Anthropic-canonical, auto-discovered)
│   └── _shared/                 # 29 shared protocol files + check-registry.json
├── hooks/
│   ├── hooks.json               # 16 events
│   └── scripts/                 # 37 scripts: 36 hook-wired + critic-gemini.sh utility
├── scripts/                     # detect-stack, version-sync, plugin-structure validators
└── installer/                   # npx blitz-cc CLI
```

Skills are auto-discovered from `skills/<name>/SKILL.md` — no central registry. Every SKILL.md satisfies a frontmatter contract (third-person description ≤1024 chars, body ≤500 lines, required fields, the verbatim OUTPUT STYLE snippet) enforced by `skill-frontmatter-validate.sh`.

### Runtime artifacts

Everything mutable lives under `.cc-sessions/` (gitignored): `activity-feed.jsonl` (cross-session event log), `carry-forward.jsonl` (scope ledger), `HANDOFF.json` (compaction/resume), `ratchet.json` (quality floors), session registration + locks, `developer-profile.json` (autonomy). This is the machine's memory.

### Conforming after upgrades

`/blitz:conform` detects schema drift in a project's `.cc-sessions/` + sprint artifacts after a blitz upgrade and migrates them idempotently (`--fix`). Read-only by default.

---

## Hook Reference (37 scripts, 16 events)

Hooks are *the* enforcement layer — they fire on tool calls the model can't talk its way around. Across 16 events (`SessionStart`, `UserPromptExpansion`, `PreToolUse`, `PostToolUse`, `PreCompact`, `PostCompact`, `TaskCompleted`, `TeammateIdle`, `SubagentStart`, `SubagentStop`, `PostToolBatch`, `PostToolUseFailure`, `StopFailure`, `PermissionRequest`, `WorktreeCreate`, `WorktreeRemove`) they handle file protection, auto-format/lint/test, commit validation (frontmatter lint, version sync, link rot, **registry schema lint**), context monitoring, activity-feed logging, and the **7 anti-shortcut blockers** (5 P0 + 2 P1). Full index grouped by event: [`hooks/scripts/README.md`](hooks/scripts/README.md).

### Environment overrides

`BLITZ_DISABLE_ORCHESTRATOR`, `BLITZ_DISPATCH` (auto\|workflow\|agent), `BLITZ_USE_GEMINI_CRITIC`, `BLITZ_DUAL_CRITIC`, `BLITZ_OVERRIDE_NO_VERIFY`, `BLITZ_AUDIT_CONFIDENCE_THRESHOLD` — each documented at its point of use.

---

## Shared Protocols (29)

All skills share 29 protocol files in [`skills/_shared/`](skills/_shared/) that define cross-cutting behavior — so the machine's parts agree on contracts instead of each re-inventing them. The load-bearing ones:

- **session-protocol.md** — multi-session safety (locks, conflict matrix, autonomy levels)
- **check-registry.json / check-registry.md** — the single source of truth for every review/audit check (lane, verdict authority, confidence, detection)
- **shortcut-taxonomy.md** — human-readable view of the 20-detector catalog (13 reject, 7 advisory)
- **carry-forward-registry.md** — the scope-ledger Reader Algorithm + writer contract
- **spawn-protocol.md** / **workflow-dispatch.md** — agent fan-out + the opt-in `Workflow` dispatch path
- **ratchet-protocol.md** — 8 monotonic metrics + auto-revert
- **terse-output.md** — the output style + canonical exemptions

---

## Model Profiles

`.claude-plugin/model-profiles.json` records the per-agent model defaults (the 60/35/5 routing). Builder/reviewer agents pin `sonnet`, `doc-writer` pins `haiku`, and skills inherit the session model unless they override — set explicitly so a `[1m]`-context parent never accidentally drags a worker onto the wrong tier.

---

## Installer CLI

`npx blitz-cc@latest` (source in `installer/`) detects the stack, registers the plugin + marketplace, writes permissions, wires hooks, and copies typed agent definitions. `--yes` for non-interactive; a pure-bash `install.sh` fallback exists for Node-less environments. `uninstall.js` reverses it.

---

## Contributing

Blitz develops *itself* through its own cycle — this README's structure, the review/audit consolidation, and the count you're reading were produced by sprints that ran `/blitz:sprint-review` and the adversarial critic on their own output. Fork-friendly: `/blitz:conform --scope plugin` audits structural drift, and the frontmatter + link + registry validators run on every commit.

---

## Acknowledgments

The clarification-gate principles are adapted from [multica-ai/andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills) (MIT). Effectiveness research (two-lane detection, multi-review aggregation, the self-critique paradox, citation-grounding) is cited in `docs/consolidation/review-audit/effectiveness-research.md`.

---

## License

MIT — see [LICENSE](LICENSE).
