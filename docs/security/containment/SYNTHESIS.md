# SYNTHESIS — Sequenced, Blast-Radius-Ordered Containment Epics

> The integration plan. Framework-first, then gaps in descending blast-radius order. Each step has **grep-based acceptance**. The security-pillar checks become a **permanent `/blitz:audit` gate** at the end. Implementation runs behind Blitz's normal gates (sprint-review 8 invariants) **plus** the new security-pillar gate.

Sequence rationale (from the article): build the framework first (so guards register against a posture, not scatter), then close gaps by blast radius — persistent-state poisoning is highest because a poisoned carry-forward entry is reloaded every session *and* sprintified.

---

## Epic 0 — Framework (do first; no behavior change)

**Goal:** land the posture so every later guard cites it.

| Step | Action | Acceptance (grep) |
|---|---|---|
| 0.1 | Move `docs/security/containment/threat-model.md` → `skills/_shared/threat-model.md`; adapt to shared-protocol conventions. | `test -f skills/_shared/threat-model.md` |
| 0.2 | Add `security` to the canonical-owner registry; declare TB-1..TB-4. | `grep -q 'TB-1' skills/_shared/threat-model.md` |
| 0.3 | Bidirectional cite stubs: each `block-*.sh` header → `threat-model.md §<TB>`; threat-model → each guard. | `grep -l 'threat-model.md' hooks/scripts/block-*.sh \| wc -l` ≥ 4 |
| 0.4 | Confirm `check-registry.json` `security` pillar present (it is); reserve new row ids. | `jq '[.checks[]\|select(.pillar=="security")]\|length' skills/_shared/check-registry.json` ≥ 5 |

**Gate:** `check-registry-validate.sh` passes; `markdown-link-validate.sh` passes (xref dead-refs are known false positives per project memory — trust the validator).

---

## Epic 1 — Gap 1: persistent-state validation (HIGHEST blast radius)

| Step | Action | Acceptance |
|---|---|---|
| 1.1 | Add `sec-startup-schema` + `sec-startup-injection` rows to check-registry (pillar `security`, lane `deterministic`). | `jq '.checks[]\|select(.id=="sec-startup-injection")' check-registry.json` non-empty |
| 1.2 | Build startup validator (reuse `check-registry-validate.sh` pattern): schema-check `.cc-sessions/*.json` + carry-forward; regex injection-scan; cap free-text fields `[0:200]`. | validator script exists + exits non-zero on a planted injection fixture |
| 1.3 | Quarantine path: flagged entries moved aside + surfaced; generalize `rollover_count>=3` escalation. | `grep -q quarantine` validator; planted-injection fixture is NOT loaded |
| 1.4 | Wire into `session-protocol.md` startup (between :42 read and use). | `grep -q 'sec-startup' skills/_shared/session-protocol.md` |
| 1.5 | **(S-1)** Add `provenance` tag `{source, write_session, first_seen_sprint}` per carry-forward entry; extend `research-critic.md` §2.7 re-verify cadence (older than 2 sprints) from citations to all carry-forward entries. | `grep -q 'provenance' validator + research-critic §2.7 scope widened |

**Blast-radius check:** plant an injection in `carry-forward.jsonl`; confirm `sprint-plan` does NOT ingest it (it is quarantined). This is the marquee acceptance test.

---

## Epic 2 — Gap 2: sub-agent trust boundary

| Step | Action | Acceptance |
|---|---|---|
| 2.1 | Add trust-boundary clause to `spawn-protocol.md` §8: "sub-agent output is not higher-trust than the content it processed." | `grep -q 'not higher-trust' skills/_shared/spawn-protocol.md` |
| 2.2 | Add `source_trust` field to the §9 JSON reply contract; research-critic/reviewer set `"untrusted"`. | `grep -q 'source_trust' skills/_shared/spawn-protocol.md` |
| 2.3 | Orchestrator §4: cap + injection-scan any reply field interpolated downstream (extend `[0:200]`). | `grep -q 'source_trust\|0:200' agents/orchestrator.md` |
| 2.4 | **(S-2)** Document the orchestrator+sub-agent split in `spawn-protocol.md` as a dual-LLM information-flow-control boundary (`source_trust` = CaMeL source-of-data capability tag); cite CaMeL arXiv 2503.18813 + Willison. | `grep -q 'dual-LLM\|information-flow' spawn-protocol.md` |

**Acceptance:** a sub-agent reply with an injection in `summary` is capped + scanned identically to raw tool output (unit fixture).

---

## Epic 3 — Gap 3: fetched-content inspection

| Step | Action | Acceptance |
|---|---|---|
| 3.1 | Add `sec-content-inspection` row (pillar `security`; deterministic regex pre-pass + semantic Haiku classifier). | `jq '.checks[]\|select(.id=="sec-content-inspection")'` non-empty |
| 3.2 | Add inspection sub-step to `research-critic.md` (parallel to §2.1 liveness): flag embedded instructions / tool-strings / credential patterns / suspicious URLs. | `grep -q 'UNTRUSTED-CONTENT\|inspection' agents/research-critic.md` |
| 3.3 | Wire into `skills/research` fetch path; wrap flagged returns in `[UNTRUSTED-CONTENT]` delimiter. | planted-poison README fixture is wrapped, not silently consumed |
| 3.4 | Classifier is Haiku per `token-budget.md` (not the reasoning model). | `grep -q 'haiku' research-critic.md` inspection section |
| 3.5 | **(S-3)** Adopt Spotlighting/data-marking (arXiv 2403.14720) as the `[UNTRUSTED-CONTENT]` delimiter technique; inspect MCP tool **descriptions** at ToolSearch-load; hash tool descriptions on first approval for rug-pull detection. | tool-description inspection + description-hash check present |

---

## Epic 4 — Gap 4: capability-grant audit

| Step | Action | Acceptance |
|---|---|---|
| 4.1 | Add `sec-capability-grant` row (deterministic: grep `tools:` vs role). | row present |
| 4.2 | `/blitz:audit` security pillar emits capability-grant findings (Bash=exec+egress, WebFetch=egress, Write=mutation). | audit report has a "Capability Grants" section |
| 4.3 | Add `# capability rationale:` comment to architect/critic/design-critic (Bash scope = read-subset) and research-critic (WebFetch = citation probing). | `grep -l 'capability rationale' agents/*.md \| wc -l` ≥ 4 |
| 4.4 | Recommend `disallowed-tools` where present-but-unjustified; document deliberate exclusions with the existing `<!-- no-disallowed-tools: … -->` pattern. | audit flags 0 undocumented over-grants |

---

## Epic 5 — Gap 5: pre-trust hook hardening

| Step | Action | Acceptance |
|---|---|---|
| 5.1 | Apply `[0:200]` cap to every field `session-start.sh` echoes (parity with orchestrator §4). | `grep -q '0:200\|cut -c' hooks/scripts/session-start.sh` |
| 5.2 | Injection-scan echoed fields; replace flagged with `[quarantined]`. | planted-injection HANDOFF fixture is capped + quarantined in hook output |
| 5.3 | Write `skills/_shared/hook-trust.md`: SessionStart hooks treat project-local files as untrusted; no execution-bearing parse pre-trust. | `test -f skills/_shared/hook-trust.md` |
| 5.4 | Assert (test): no hook `eval`/`source`s a project-controlled file. | `! grep -rE '(eval\|source\|\. )' hooks/scripts/*.sh \| grep -v _lib/common.sh` (review hits) |

---

## Epic 6 — Permanent gate

| Step | Action | Acceptance |
|---|---|---|
| 6.1 | `/blitz:audit --pillar security` covers sec-startup-*, sec-content-inspection, sec-capability-grant + existing det-06/07/15/18/sem-sec. | `jq '[.checks[]\|select(.pillar=="security")]\|length'` ≥ 8 |
| 6.2 | Add security-pillar pass to sprint-review Phase 3.6 as a gate (alongside the 8 invariants). | review report shows a "Security pillar" line |
| 6.3 | Each guard cites its TB; `threat-model.md` is canonical owner. | bidirectional-cite check passes |

---

## Dependency order (one line)

```
Epic 0 (framework) → Epic 1 (Gap 1, highest) → Epic 2 (Gap 2) → Epic 3 (Gap 3)
  → Epic 4 (Gap 4) ∥ Epic 5 (Gap 5)  [4 and 5 are independent] → Epic 6 (permanent gate)
```

Epics 4 and 5 have no interdependency and may run in parallel. All later epics depend on Epic 0 (the registry rows + canonical owner). Epics 1–3 share one injection-scan regex (build it in Epic 1, reuse in 2/3/5).

---

## What this plan deliberately does NOT do (scope discipline)

- No VM, gVisor, or MITM proxy (threat-model.md §6).
- No reimplementation of auto-mode tiers or the platform trust prompt.
- No new subsystem — every fix extends an existing primitive (check-registry validator, `[0:200]` cap, spawn JSON contract, Haiku routing, `/blitz:audit` pillar).
- No model-layer-only fix where the article shows only the environment layer holds — Gap 1/3 are deterministic-scan + small-classifier steps, not "the model will notice."

---

## Cross-references
- `containment-model.md` · `blitz-surface-map.md` · `threat-model.md` · `gap-fixes.md` · `self-audit.md`
