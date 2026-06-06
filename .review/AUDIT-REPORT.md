# Blitz Plugin Read-Only Audit — Report

**Target:** blitz v2.3.2 (`lasswellt/blitz-cc`) · **Generated from** `.review/registry.json` · CLI 2.1.160

## 1. Executive summary

**Verdict: HEALTHY.** No blockers. The plugin loads clean, all repo gates pass, and structural/security invariants hold. Findings are cohesiveness polish (trigger collisions) and two portability/robustness items.

| Gate | Result |
|---|---|
| `claude plugin validate --strict` (manifest) | ✅ clean (exit 0) |
| `validate-plugin-structure.sh` | ✅ 284 checks, 0 errors |
| `check-count-sync.sh` | ✅ clean |
| `check-version-sync.sh` | ✅ clean |
| Hook-trust invariant (no eval/source of project content) | ✅ holds |

**Census (disk = counts.json, no drift):** 37 skills · 10 agents · 38 hook scripts (35 wired / 2 sub-invoked / 1 critic-spawned) · 16 events · 32 shared · 1 output-style · 0 bundled MCP/LSP/theme · 0 commands dir.

**Findings by severity:** 0 blocker · 4 high · 8 med · 42 low · 2 info. (35 of the lows are one systemic issue — unquoted `${CLAUDE_PLUGIN_ROOT}` repeated per hook — rolled up as a single cross-cutting med.)

**Fix first (top 5):**
1. **`initialPrompt` on orchestrator (HIGH)** — not on the documented agent field allowlist; if runtime ignores it the boot state-summary silently no-ops. Confirm support or move logic into the system-prompt body.
2. **Trigger collisions (3× HIGH)** — `review`/`sprint-review`, `ship`/`release`, and the bare-`audit`/`security audit` overload need reciprocal `use-X-when` boundaries.
3. **No authoritative engine minimum (MED)** — declare `>=2.1.117` in plugin.json; orchestrator + 9 recent hook events silently no-op on 2.1.71–2.1.116.
4. **Unquoted `${CLAUDE_PLUGIN_ROOT}` ×38 (MED)** — quote in hooks.json; breaks on install paths with spaces.
5. **Orphan agents `architect`,`doc-writer` (MED)** — defined but spawned by no skill; wire the natural caller or document as orchestrator-only.

## 2. Scorecard (worst-first)

| Score | Component | Type | blocker/high |
|---|---|---|---|
| 79 | `agent:orchestrator` | agent | 1 |
| 88 | `skill:audit` | skill | 0 |
| 88 | `skill:release` | skill | 0 |
| 88 | `skill:review` | skill | 0 |
| 88 | `skill:ship` | skill | 0 |
| 90 | `skill:sprint-review` | skill | 0 |
| 91 | `agent:architect` | agent | 0 |
| 91 | `agent:doc-writer` | agent | 0 |
| 91 | `manifest:plugin.json` | manifest | 0 |
| 94 | `skill:browse` | skill | 0 |
| 94 | `skill:codebase-map` | skill | 0 |
| 94 | `skill:dep-health` | skill | 0 |

_Components not listed scored ≥96 with no blocker/high (clean frontmatter, least-privilege tools, resolved shared-refs)._

## 3. Blocker & high findings

### `agent:orchestrator` — HIGH (best-practice)
- **loc:** `agents/orchestrator.md:frontmatter (initialPrompt)`
- **issue:** Uses `initialPrompt` (boot state-summary: read HANDOFF.json + activity-feed, surface one-line state). `initialPrompt` is NOT on the documented plugin-agent field allowlist (name,description,model,effort,maxTurns,tools,disallowedTools,skills,memory,background,isolation). `claude plugin validate --strict` validates the manifest only and does not check agent .md frontmatter, so it neither flags nor confirms it. If the installed runtime ignores the field, the relied-on boot state-summary silently no-ops.
- **fix:** Confirm against current Claude Code agent docs whether `initialPrompt` is supported on plugin agents. If unsupported, move the boot-summary behavior into the orchestrator system prompt body (it already documents the same logic) so it does not depend on an unrecognized frontmatter key.

### cross-cutting — HIGH (cohesiveness) · scope: skill:review, skill:sprint-review
- **issue:** Verbatim trigger overlap: 'review sprint N','run review','check quality' (sprint-review even claims 'audit sprint'). Hand-off ('review delegates to sprint-review') is one-directional and buried; neither carries a reciprocal use-X-when boundary.
- **fix:** review: 'per-change/pre-commit precision review of a diff; for the full end-of-sprint 8-invariant gate use sprint-review.' sprint-review: 'full end-of-sprint gate; for lightweight per-change review use /blitz:review.'

### cross-cutting — HIGH (cohesiveness) · scope: skill:ship, skill:release
- **issue:** ship and release list the exact same triggers 'cut a release','release v1.X'. release notes it is 'composed by ship' (weak); ship has no clause for when to prefer release alone.
- **fix:** Keep 'cut a release'/'release vX' on ship (full gated chain); release owns 'publish/tag/rollback' in isolation. Add reciprocal boundaries.

### cross-cutting — HIGH (cohesiveness) · scope: skill:audit, skill:dep-health, skill:code-doctor, skill:ui-audit, skill:sprint-review
- **issue:** Bare 'audit'/'security audit' overloaded across 5 components with no shared object-noun key. Object nouns mostly disambiguate (deps->dep-health, firestore->code-doctor, consistency->ui-audit, sprint->sprint-review, codebase->audit) but bare 'audit' and 'security audit' genuinely collide between audit (5-pillar incl Security) and dep-health (CVE scan).
- **fix:** audit: narrow security claim to 'source-code security'; route dependency CVE to dep-health. Add object-noun routing note; bare 'audit' with no object -> /blitz:ask.

## 4. Cohesiveness findings

### Trigger-collision matrix (worst-first)

| Sev | Cluster | Boundary fix |
|---|---|---|
| high | review, sprint-review | review: 'per-change/pre-commit precision review of a diff; for the full end-of-sprint 8-invariant gate use sprint-review.' sprint-review: 'f |
| high | ship, release | Keep 'cut a release'/'release vX' on ship (full gated chain); release owns 'publish/tag/rollback' in isolation. Add reciprocal boundaries. |
| high | audit, dep-health, code-doctor, ui-audit, sprint-review | audit: narrow security claim to 'source-code security'; route dependency CVE to dep-health. Add object-noun routing note; bare 'audit' with  |
| med | sprint, implement, sprint-dev | sprint: 'only for full plan->implement->review cycle; for implementation-only use /blitz:implement.' implement: mark as thin alias of sprint |
| med | research, codebase-map, architect, audit | Add inverse one-liners: codebase-map=onboarding map, architect=structural/dep-graph, audit=quality/tech-debt. |
| med | browse, ui-audit | Remove/qualify 'visual audit' on browse to 'visual smoke test'; ui-audit owns cross-page data consistency. |

### Naming
- Name-adjacency cluster. Verified disambiguators are accurate (critic vs reviewer; research-critic vs critic). All resolve to distinct ids. Gap: reviewer has no 'Different from...' clause; test-gen/test-writer & doc-gen/doc-writer skill/agent pairs lack 'I am the worker agent' markers.

### Routing graph (verified)
- **Dangling edges: 0.** No agent declares `skills:` frontmatter. All 14 skills naming worker agents reference existing agents. Orchestrator's 37 `/blitz:<skill>` targets all exist on disk.
- **Orphan agents:** `architect`, `doc-writer` (spawned by no skill — see §3/backlog).
- **Shared-ref integrity:** 0 dangling `/_shared/*` refs; 1 orphan (`scheduling.md`).

## 5. Completeness, version-gating & external deps
- **Stop hook:** not wired (StopFailure + SubagentStop are, as logging stubs); undocumented omission, plausibly intentional (low).
- **Terse-output:** no gaps — all 37 SKILL.md carry the OUTPUT STYLE snippet; output-style exists.
- **Version-gating:** no single engine minimum; orchestrator needs >=2.1.117, 9 wired events postdate 2.1.71. Recommend declaring `>=2.1.117`.
- **External deps (undeclared in plugin.json.dependencies):** Playwright MCP (browse/ui-build/ui-audit/design-critic), Gemini CLI (critic-gemini.sh, opt-in via env). Both genuinely external/unbundled; Gemini egress correctly opt-in. Document as prerequisites (info).

## 6. Prioritized remediation backlog

| # | Action | Sev | Effort | Risk if skipped |
|---|---|---|---|---|
| 1 | Confirm/replace orchestrator `initialPrompt` (move boot-summary into system-prompt body if unsupported) | high | S | Boot state-summary silently no-ops; orchestrator loses session-resume UX |
| 2 | Add reciprocal boundaries: review↔sprint-review, ship↔release | high | S | Freeform requests misroute between front-door and engine |
| 3 | Narrow audit security claim + add object-noun routing for the 'audit' overload | high | M | 'security audit'/'audit X' misroutes across 5 skills |
| 4 | Declare authoritative `>=2.1.117` engine minimum in plugin.json | med | S | Consumers on 2.1.71–2.1.116 silently lose orchestrator + 9 events |
| 5 | Quote `"${CLAUDE_PLUGIN_ROOT}"` across hooks.json (38) | med | S | Hooks break on install paths with spaces |
| 6 | Wire architect/doc-writer to real callers or document as orchestrator-only | med | M | Two agents unreachable if orchestrator disabled |
| 7 | Add boundaries: sprint↔implement, research/codebase-map/architect, browse↔ui-audit | med | M | Secondary misroutes |
| 8 | Link /_shared/scheduling.md from loop-capable skills; add worker-agent markers (reviewer/test-writer/doc-writer) | low | S | Orphan doc + missing disambiguators |
| 9 | Document Playwright/Gemini external deps; add Stop-hook rationale note | info | S | Portability/clarity |

## 7. Appendix — full findings dump

**`agent:architect`** (score 91)
- [med/cohesiveness] agents/architect.md: Defined and documented in spawn-protocol/token-budget/quality-matrix prose, but spawned by NO skill via subagent_type (doc-gen spawns general-purpose dimension agents; codebase-map's map-architecture 

**`agent:critic`** (score 97)
- [low/best-practice] agents/critic.md:frontmatter (color): Uses `color` — cosmetic field not on the documented agent allowlist; tolerated/ignored by runtime (not flagged by --strict, which is manifest-only).

**`agent:design-critic`** (score 97)
- [low/best-practice] agents/design-critic.md:frontmatter (color): Uses `color` — cosmetic field not on the documented agent allowlist; tolerated/ignored by runtime (not flagged by --strict, which is manifest-only).

**`agent:doc-writer`** (score 91)
- [med/cohesiveness] agents/doc-writer.md: Defined and documented in spawn-protocol/token-budget/quality-matrix prose, but spawned by NO skill via subagent_type (doc-gen spawns general-purpose dimension agents; codebase-map's map-architecture 

**`agent:orchestrator`** (score 79)
- [high/best-practice] agents/orchestrator.md:frontmatter (initialPrompt): Uses `initialPrompt` (boot state-summary: read HANDOFF.json + activity-feed, surface one-line state). `initialPrompt` is NOT on the documented plugin-agent field allowlist (name,description,model,effo
- [low/best-practice] agents/orchestrator.md:frontmatter (color): Uses `color` — cosmetic field not on the documented agent allowlist; tolerated/ignored by runtime (not flagged by --strict, which is manifest-only).

**`agent:research-critic`** (score 97)
- [low/best-practice] agents/research-critic.md:frontmatter (color): Uses `color` — cosmetic field not on the documented agent allowlist; tolerated/ignored by runtime (not flagged by --strict, which is manifest-only).

**`hook:agent-frontmatter-validate.sh`** (score 97)
- [low/best-practice] hooks/hooks.json: Command uses unquoted ${CLAUDE_PLUGIN_ROOT}; breaks if install path contains spaces (docs example quotes it).

**`hook:analysis-paralysis-guard.sh`** (score 97)
- [low/best-practice] hooks/hooks.json: Command uses unquoted ${CLAUDE_PLUGIN_ROOT}; breaks if install path contains spaces (docs example quotes it).

**`hook:blitz-prompt-expansion.sh`** (score 97)
- [low/best-practice] hooks/hooks.json: Command uses unquoted ${CLAUDE_PLUGIN_ROOT}; breaks if install path contains spaces (docs example quotes it).

**`hook:block-as-any-insertion.sh`** (score 97)
- [low/best-practice] hooks/hooks.json: Command uses unquoted ${CLAUDE_PLUGIN_ROOT}; breaks if install path contains spaces (docs example quotes it).

**`hook:block-destructive-git.sh`** (score 97)
- [low/best-practice] hooks/hooks.json: Command uses unquoted ${CLAUDE_PLUGIN_ROOT}; breaks if install path contains spaces (docs example quotes it).

**`hook:block-destructive-sql.sh`** (score 97)
- [low/best-practice] hooks/hooks.json: Command uses unquoted ${CLAUDE_PLUGIN_ROOT}; breaks if install path contains spaces (docs example quotes it).

**`hook:block-no-verify.sh`** (score 97)
- [low/best-practice] hooks/hooks.json: Command uses unquoted ${CLAUDE_PLUGIN_ROOT}; breaks if install path contains spaces (docs example quotes it).

**`hook:block-test-deletion.sh`** (score 97)
- [low/best-practice] hooks/hooks.json: Command uses unquoted ${CLAUDE_PLUGIN_ROOT}; breaks if install path contains spaces (docs example quotes it).

**`hook:block-test-disabling.sh`** (score 97)
- [low/best-practice] hooks/hooks.json: Command uses unquoted ${CLAUDE_PLUGIN_ROOT}; breaks if install path contains spaces (docs example quotes it).

**`hook:context-monitor.sh`** (score 97)
- [low/best-practice] hooks/hooks.json: Command uses unquoted ${CLAUDE_PLUGIN_ROOT}; breaks if install path contains spaces (docs example quotes it).

**`hook:markdown-link-validate.sh`** (score 97)
- [low/best-practice] hooks/hooks.json: Command uses unquoted ${CLAUDE_PLUGIN_ROOT}; breaks if install path contains spaces (docs example quotes it).

**`hook:permission-request.sh`** (score 97)
- [low/best-practice] hooks/hooks.json: Command uses unquoted ${CLAUDE_PLUGIN_ROOT}; breaks if install path contains spaces (docs example quotes it).

**`hook:post-compact-log.sh`** (score 97)
- [low/best-practice] hooks/hooks.json: Command uses unquoted ${CLAUDE_PLUGIN_ROOT}; breaks if install path contains spaces (docs example quotes it).

**`hook:post-edit-activity-log.sh`** (score 97)
- [low/best-practice] hooks/hooks.json: Command uses unquoted ${CLAUDE_PLUGIN_ROOT}; breaks if install path contains spaces (docs example quotes it).

**`hook:post-edit-format.sh`** (score 97)
- [low/best-practice] hooks/hooks.json: Command uses unquoted ${CLAUDE_PLUGIN_ROOT}; breaks if install path contains spaces (docs example quotes it).

**`hook:post-edit-lint.sh`** (score 97)
- [low/best-practice] hooks/hooks.json: Command uses unquoted ${CLAUDE_PLUGIN_ROOT}; breaks if install path contains spaces (docs example quotes it).

**`hook:post-edit-test.sh`** (score 97)
- [low/best-practice] hooks/hooks.json: Command uses unquoted ${CLAUDE_PLUGIN_ROOT}; breaks if install path contains spaces (docs example quotes it).

**`hook:post-edit-typecheck-block.sh`** (score 97)
- [low/best-practice] hooks/hooks.json: Command uses unquoted ${CLAUDE_PLUGIN_ROOT}; breaks if install path contains spaces (docs example quotes it).

**`hook:post-tool-batch.sh`** (score 97)
- [low/best-practice] hooks/hooks.json: Command uses unquoted ${CLAUDE_PLUGIN_ROOT}; breaks if install path contains spaces (docs example quotes it).

**`hook:post-tool-failure.sh`** (score 97)
- [low/best-practice] hooks/hooks.json: Command uses unquoted ${CLAUDE_PLUGIN_ROOT}; breaks if install path contains spaces (docs example quotes it).

**`hook:pre-commit-validate.sh`** (score 97)
- [low/best-practice] hooks/hooks.json: Command uses unquoted ${CLAUDE_PLUGIN_ROOT}; breaks if install path contains spaces (docs example quotes it).

**`hook:pre-compact-snapshot.sh`** (score 97)
- [low/best-practice] hooks/hooks.json: Command uses unquoted ${CLAUDE_PLUGIN_ROOT}; breaks if install path contains spaces (docs example quotes it).

**`hook:pre-edit-backup.sh`** (score 97)
- [low/best-practice] hooks/hooks.json: Command uses unquoted ${CLAUDE_PLUGIN_ROOT}; breaks if install path contains spaces (docs example quotes it).

**`hook:pre-edit-guard.sh`** (score 97)
- [low/best-practice] hooks/hooks.json: Command uses unquoted ${CLAUDE_PLUGIN_ROOT}; breaks if install path contains spaces (docs example quotes it).

**`hook:reference-compression-validate.sh`** (score 97)
- [low/best-practice] hooks/hooks.json: Command uses unquoted ${CLAUDE_PLUGIN_ROOT}; breaks if install path contains spaces (docs example quotes it).

**`hook:session-start.sh`** (score 97)
- [low/best-practice] hooks/hooks.json: Command uses unquoted ${CLAUDE_PLUGIN_ROOT}; breaks if install path contains spaces (docs example quotes it).

**`hook:skill-frontmatter-validate.sh`** (score 97)
- [low/best-practice] hooks/hooks.json: Command uses unquoted ${CLAUDE_PLUGIN_ROOT}; breaks if install path contains spaces (docs example quotes it).

**`hook:stop-failure.sh`** (score 97)
- [low/best-practice] hooks/hooks.json: Command uses unquoted ${CLAUDE_PLUGIN_ROOT}; breaks if install path contains spaces (docs example quotes it).

**`hook:subagent-start.sh`** (score 97)
- [low/best-practice] hooks/hooks.json: Command uses unquoted ${CLAUDE_PLUGIN_ROOT}; breaks if install path contains spaces (docs example quotes it).

**`hook:subagent-stop.sh`** (score 97)
- [low/best-practice] hooks/hooks.json: Command uses unquoted ${CLAUDE_PLUGIN_ROOT}; breaks if install path contains spaces (docs example quotes it).

**`hook:task-completed-validate.sh`** (score 97)
- [low/best-practice] hooks/hooks.json: Command uses unquoted ${CLAUDE_PLUGIN_ROOT}; breaks if install path contains spaces (docs example quotes it).

**`hook:teammate-idle.sh`** (score 97)
- [low/best-practice] hooks/hooks.json: Command uses unquoted ${CLAUDE_PLUGIN_ROOT}; breaks if install path contains spaces (docs example quotes it).

**`hook:workflow-guard.sh`** (score 97)
- [low/best-practice] hooks/hooks.json: Command uses unquoted ${CLAUDE_PLUGIN_ROOT}; breaks if install path contains spaces (docs example quotes it).

**`hook:worktree-create.sh`** (score 97)
- [low/best-practice] hooks/hooks.json: Command uses unquoted ${CLAUDE_PLUGIN_ROOT}; breaks if install path contains spaces (docs example quotes it).

**`hook:worktree-remove.sh`** (score 97)
- [low/best-practice] hooks/hooks.json: Command uses unquoted ${CLAUDE_PLUGIN_ROOT}; breaks if install path contains spaces (docs example quotes it).

**`shared:scheduling.md`** (score 97)
- [low/cohesiveness] skills/_shared/scheduling.md: Orphan: documents /loop and /schedule but no SKILL.md links to /_shared/scheduling.md, though 7 loop-capable skills (next, sprint, code-sweep, browse, ui-audit, sprint-plan, sprint-dev) reference loop

**`manifest:plugin.json`** (score 91)
- [med/version-gating] .claude-plugin/plugin.json: No authoritative engine minimum declared. Effective floor is implicit/inconsistent: lowest skill floor advertises >=2.1.71 but orchestrator main-thread activation needs >=2.1.117 and 9 wired hook even

### Cross-cutting
- [high/cohesiveness] skill:review, skill:sprint-review: Verbatim trigger overlap: 'review sprint N','run review','check quality' (sprint-review even claims 'audit sprint'). Hand-off ('review delegates to sprint-review') is one-directional and buried; neith
- [high/cohesiveness] skill:ship, skill:release: ship and release list the exact same triggers 'cut a release','release v1.X'. release notes it is 'composed by ship' (weak); ship has no clause for when to prefer release alone.
- [high/cohesiveness] skill:audit, skill:dep-health, skill:code-doctor, skill:ui-audit, skill:sprint-r: Bare 'audit'/'security audit' overloaded across 5 components with no shared object-noun key. Object nouns mostly disambiguate (deps->dep-health, firestore->code-doctor, consistency->ui-audit, sprint->
- [med/cohesiveness] skill:sprint, skill:implement, skill:sprint-dev: 'implement sprint'/'resume sprint' match all three. implement/sprint-dev is a benign alias; sprint vs the pair is a real fork (bare 'implement' should not trigger the full plan->implement->review cycl
- [med/cohesiveness] skill:research, skill:codebase-map, agent:architect, skill:audit: 'analyze this project/codebase' has no single owner across codebase-map (onboarding map), architect (coupling/dep-graph), audit (quality findings); research shares the verb 'analyze'.
- [med/cohesiveness] skill:browse, skill:ui-audit: 'visual audit' triggers both browse (functional smoke: console/network/screenshots) and ui-audit (semantic data consistency/role-leak).
- [low/naming] agent:reviewer, agent:critic, skill:review, agent:research-critic, agent:design-: Name-adjacency cluster. Verified disambiguators are accurate (critic vs reviewer; research-critic vs critic). All resolve to distinct ids. Gap: reviewer has no 'Different from...' clause; test-gen/tes
- [med/version-gating] manifest:plugin.json, .claude-plugin/settings.json, hooks/hooks.json: No single engine minimum. Orchestrator activation needs >=2.1.117; 9 wired events postdate 2.1.71 (TeammateIdle, PostToolBatch, PostToolUseFailure, StopFailure, WorktreeCreate, WorktreeRemove, Subagen
- [med/best-practice] hooks/hooks.json: All 38 ${CLAUDE_PLUGIN_ROOT} references in hooks.json are unquoted (0 quoted). Docs example quotes it; unquoted breaks on install paths containing spaces.
- [low/coverage] hooks/hooks.json: Plain `Stop` event not wired (StopFailure + SubagentStop are, as logging stubs). Omission is undocumented; turn-end persistence handled out-of-band via PreCompact + model-written activity-feed. Plausi
- [info/documentation] manifest:plugin.json: Undeclared external deps: Playwright MCP (browse, ui-build, ui-audit, design-critic) and Gemini CLI (critic-gemini.sh, opt-in via BLITZ_USE_GEMINI_CRITIC/BLITZ_DUAL_CRITIC). plugin.json.dependencies i
- [info/count-sync] all: counts.json (37/10/32/38/16) matches disk exactly; validate-plugin-structure (284 checks), check-count-sync, check-version-sync all PASS; plugin manifest strict-validates clean. No drift.