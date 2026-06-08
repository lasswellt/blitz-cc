# Blitz Surface Map — Security Artifacts in the Risk × Layer Matrix

> Companion to the security posture in [`skills/_shared/security.md`](../../../skills/_shared/security.md) (the containment model that promoted from this research pass). Classifies **what Blitz already has** before adding anything. Every cell is filled from the live tree (file:line confirmed 2026-05-31). Thin/empty cells are named as gaps.

The point of this map: Blitz already has substantial environment-layer machinery. The integration is *not* "add more checks" — it is (1) name the framework that organizes the existing guards, and (2) close the specific empty cells.

---

## 1. The filled matrix

Rows = risk type (who originates harm). Columns = defense layer. `★` = a confirmed gap (each fix-designed as an epic in [`SYNTHESIS.md`](SYNTHESIS.md)).

### User misuse

| Environment (deterministic) | Model (probabilistic) | External content |
|---|---|---|
| `block-destructive-git.sh` — blocks `reset --hard`, `clean -fd`, `checkout -- .`, `push --force` to main on dirty tree (head comment + :11+) | skill SAFETY-RULES prose (15+ skills, per cohesion SYNTHESIS:55) | n/a |
| `block-destructive-sql.sh` (det-18) | completion/DoD gates (`sprint-contracts.md`) | |
| `block-no-verify.sh` (det-02) — blocks `--no-verify` commit bypass | clarification gate (CLAUDE.md) | |
| `pre-edit-guard.sh` — blocks `.env`, lock files, `*.pem/*.key`, `credentials.json`, `.git/`, `node_modules/` (pre-edit-guard.sh:26-66) | autonomy levels (session-lifecycle.md:91-102) | |
| Platform auto-mode hard-deny (~20 rules) — inherited, not reimplemented | | |

### Model misbehavior

| Environment (deterministic) | Model (probabilistic) | External content |
|---|---|---|
| `block-test-deletion.sh` (det-01) | `agents/critic.md` — 20-detector shortcut taxonomy | n/a |
| `block-test-disabling.sh` | reviewer agents (`review:security-reviewer`, audit sec-a/sec-b) | |
| `block-as-any-insertion.sh` | output-style enforcement (Invariant 5) | |
| `post-edit-typecheck-block.sh` | ratchet auto-revert on regression (`quality-engine.md`) | |
| `disallowed-tools` — **declared by `health/SKILL.md` only** (v1.16.0 VERDICT:116) ★ | | |
| ratchet 8 monotonic metrics (sprint-review Inv 6) | | |

### External attacker

| Environment (deterministic) | Model (probabilistic) | External content |
|---|---|---|
| orchestrator `[0:200]` injection caps on activity-feed + HANDOFF fields (orchestrator.md:146-149) | research-critic URL liveness — LIVE/DEAD/HALLUCINATED/UNKNOWN (research-critic.md §2.1) | **★ GAP 3 — no injection/content inspection of fetched pages, READMEs, MCP returns** |
| `session-start.sh` echoes the SAME HANDOFF/feed fields **uncapped** (session-start.sh:22-52) ★ **inconsistent with orchestrator** | injection-resistance (model-inherited) | research-critic verifies *citations*, not *payload safety* |
| spawn-protocol structured-JSON reply contract (§8/§9) — limits free-text blast radius | | **★ GAP 2 — sub-agent output has no stated trust level** |

---

## 2. The gaps, read off the matrix

| Gap | Cell | What's missing | Article anti-pattern |
|---|---|---|---|
| **Gap 1** | persistent state (cuts across all rows) | `.cc-sessions/*.json`, activity feed, profiles, **carry-forward registry** read into context each session with **no integrity/injection check** | AP-4 persistent-state poisoning |
| **Gap 2** | External attacker × External content | sub-agent reply trust level undefined; output trusted because it "came from us" | AP-6 multi-agent trust escalation |
| **Gap 3** | External attacker × External content (empty) | fetched URLs/READMEs/MCP returns enter context with no content inspection | AP-5 tool output as attack surface |
| **Gap 4** | Model misbehavior × Environment (thin) | `allowed-tools` treated as on/off lists, not capability grants; only 1 artifact declares `disallowed-tools` | AP-3 allowlist-as-capability-grant |
| **Gap 5** | User misuse / all × Environment | `SessionStart` hooks parse project-local `.cc-sessions/` files pre-trust, echo uncapped | AP-1 pre-trust config execution |

---

## 3. What Blitz already does RIGHT (credit where due)

The article repeatedly names mitigations Blitz **already implements** — the integration builds on these, doesn't replace them:

1. **Structured-facts-not-raw-text** (AP-6 mitigation): spawn-protocol's canonical JSON reply (`{status, summary≤50w, files_changed, issues, …}`, §9) already forces sub-agents to return typed facts, not raw prose. Gap 2 *labels* the trust level; it does not invent the structure.
2. **Injection caps**: orchestrator.md:146-149 already truncates skill-written fields to `[0:200]` with an explicit "injection-surface guard; Opus 4.8 ASR regression" rationale. Gap 1/2/5 *extend this same principle* to startup and sub-agent paths.
3. **Deterministic environment layer**: 7 `block-*.sh` hooks + `pre-edit-guard.sh` are a genuine deterministic boundary that complements (does not reimplement) the platform auto-mode hard-deny groups ([`security.md`](../../../skills/_shared/security.md) §6 Scope).
4. **A registry-driven check system**: `check-registry.json` already has a `security` pillar (det-06 env-fallback, det-07 hardcoded-creds, det-15 localhost-ports, det-18 destructive-sql, sem-sec) + `check-registry-validate.sh`. New security checks register here — no new subsystem.
5. **A startup-classifier seed**: the `rollover_count >= 3` → human-review escalation (carry-forward) is a primitive startup classifier. Gap 1 generalizes it.

---

## 4. Surface inventory (file:line index)

| Artifact | Path | Layer | Role |
|---|---|---|---|
| destructive-git guard | `hooks/scripts/block-destructive-git.sh` | env | user-misuse |
| destructive-sql guard | `hooks/scripts/block-destructive-sql.sh` | env | user-misuse (det-18) |
| no-verify guard | `hooks/scripts/block-no-verify.sh` | env | user-misuse (det-02) |
| test-deletion guard | `hooks/scripts/block-test-deletion.sh` | env | model-misbehavior (det-01) |
| test-disabling guard | `hooks/scripts/block-test-disabling.sh` | env | model-misbehavior |
| as-any guard | `hooks/scripts/block-as-any-insertion.sh` | env | model-misbehavior |
| typecheck block | `hooks/scripts/post-edit-typecheck-block.sh` | env | model-misbehavior |
| pre-edit protections | `hooks/scripts/pre-edit-guard.sh:26-66` | env | secrets/locks/git/node_modules |
| session-start hook | `hooks/scripts/session-start.sh:18-55` | env (★ Gap 5) | reads/echoes project-local state at `SessionStart` (hooks.json:37-42) |
| orchestrator injection caps | `agents/orchestrator.md:146-149` | env | external-attacker `[0:200]` |
| session startup state read | `skills/_shared/session-lifecycle.md:42,72,76,82` | — (★ Gap 1) | reads ALL `.cc-sessions/*.json` + feed + profiles unvalidated |
| sub-agent reply contract | `skills/_shared/agent-orchestration.md:441-554` | (★ Gap 2) | structured JSON; no trust label |
| URL-health check | `agents/research-critic.md:76-103` | ext-content (★ Gap 3 boundary) | liveness, not payload safety |
| check registry | `skills/_shared/check-registry.json` | all | security pillar exists |
| registry validator | `hooks/scripts/check-registry-validate.sh` | — | the validator pattern Gap 1 reuses |
| agent tool grants | `agents/*.md` `tools:` | env (★ Gap 4) | capability surface |

---

## 5. Cross-references
- [`skills/_shared/security.md`](../../../skills/_shared/security.md) — the canonical security posture / containment model these cells instantiate, and the owner of this map (§1 cites it for the cell-by-cell mapping).
- [`SYNTHESIS.md`](SYNTHESIS.md) — the sequenced integration plan; each `★` gap is confirmed and fix-designed as a blast-radius-ordered epic (folds the former standalone gap analysis and self-audit).
