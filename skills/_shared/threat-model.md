# Threat Model — Blitz Containment Posture (canonical owner)

> **Canonical owner (O-style)** for Blitz's security posture. Promoted from the containment research pass (`docs/security/containment/`) — see that directory for the derivation, the Anthropic source article, the surface map, the gap analysis, the self-audit, and the external best-practice cross-check.
>
> Grounded in Anthropic, "How we contain Claude across products" (2026-05-25), cross-checked against OWASP (LLM / Agentic / MCP Top 10), CaMeL (arXiv 2503.18813), the dual-LLM / Spotlighting pattern, the memory-poisoning literature (MINJA / MemoryGraft / Zombie Agents), and NIST's agent identity/authorization direction.
>
> Right-sized for a Claude Code-class HITL developer tool — **not** a hosted service or sealed-VM product (§6 Scope).

This document organizes Blitz's scattered tactical guards (`block-*.sh`, `pre-edit-guard.sh`, orchestrator `[0:200]` caps) into one auditable posture: **risk type × defense layer**, ordered by the **environment-first principle**, defended along **four trust boundaries**. New security guards register against it; `/blitz:audit --pillar security` audits against it.

---

## 1. The model — three risks × three layers

| Risk type (who originates harm) | Definition |
|---|---|
| **User misuse** | A user — maliciously or carelessly — directs the agent to do something harmful. |
| **Model misbehavior** | The agent takes a harmful action no one asked for. |
| **External attacker** | The agent is attacked through external vectors: tools, files, network, fetched content. |

| Defense layer | Nature | Blitz instances |
|---|---|---|
| **Environment** | **Deterministic boundary** — hard limit on reach, holds regardless of cause. | `block-*.sh`, `pre-edit-guard.sh`, `disallowed-tools`, startup-validate, `[0:200]` caps, platform auto-mode hard-deny. |
| **Model** | **Probabilistic** — steers behavior; never a guarantee. | skill SAFETY-RULES prose, completion/DoD gates, critic 20-detector, reviewers, output-style. |
| **External content** | The **attack-surface** layer; mitigated by least-privilege + live inspection. | content-inspection (research/research-critic), MCP tool-return/description inspection, research-critic liveness. |

Authoritative cell-by-cell mapping: [`docs/security/containment/blitz-surface-map.md`](../../docs/security/containment/blitz-surface-map.md).

---

## 2. The environment-first principle (the ordering rule)

> "The deterministic boundary is what gets hit when everything probabilistic misses." — source article

**Rule:** Blitz's deterministic guards are the boundary. Model-layer behavior (skill prose, critic reasoning, gates) is defense-in-depth on top of that boundary — never the boundary itself.

**Why (reasoning chain — do not terse-compress):** Blitz now runs on a highly aligned model (Opus 4.8 honesty gains), making "the model will notice" tempting. The article's two most instructive incidents — an employee phished into running a malicious prompt, and exfiltration through an approved domain — were both egress events where the model layer had *nothing anomalous to catch*, because the instruction came from the legitimate user or through a permitted channel. Only the environment boundary held. OWASP states the same in general form: prompt injection has "no known complete mitigation — only layered defenses." Therefore:

- A new control is **valid containment** only if it has a deterministic component (a hook, schema check, tool grant, cap, hash). "The agent is instructed to be careful" is not containment.
- Persistent-state validation (TB-2) and fetched-content inspection (TB-4) are **deterministic scan + small-fast classifier** steps (Haiku per [token-budget.md](token-budget.md)), not "the reasoning model will spot the injection." Per the article, the classifier "can be a small, fast model; it doesn't need to be the one doing the reasoning."

---

## 3. The four trust boundaries

Everything below is **untrusted-by-default**.

### TB-1 — Project-local state is untrusted inbound data
Files a cloned/opened repo controls: `.cc-sessions/*.json`, `activity-feed.jsonl`, developer/model profiles, **CLAUDE.md**, the carry-forward registry. Treat them like an inbound internet request, not trusted local config.
- **Enforced by:** `session-start.sh` caps + scans before echo (Gap 5); `session-protocol.md` startup validates before load (Gap 1); `pre-edit-guard.sh` blocks edits to secret/key/lock files.
- **Guards against:** pre-trust parse, persistent poisoning.

### TB-2 — Persistent `.cc-sessions/` state is untrusted across sessions
The same directory across time: an injection in the carry-forward registry or feed is **reloaded every session** and, for carry-forward, **auto-injected into the next sprint** (`sprint-plan` consumes it as mandatory input — high blast radius because it *drives work*). Memory-poisoning attacks are **temporally decoupled** — poison planted now can trigger sprints later (MemoryGraft / Zombie Agents).
- **Enforced by:** session-startup validation (Gap 1) — schema-conform + injection scan + `provenance` tag `{source, write_session, first_seen_sprint}`; quarantine, don't silently load; re-verify carry-forward entries older than 2 sprints ([research-critic.md](../../agents/research-critic.md) §2.7 cadence, extended). Generalizes the existing `rollover_count >= 3` escalation.
- **Guards against:** persistent poisoning, belief drift.

### TB-3 — Sub-agent output is not higher-trust than the content it processed
A sub-agent that fetched a URL or read an untrusted file is a *conduit*. Its reply is not trusted because it "came from us." Blitz's architecture is structurally the **dual-LLM / information-flow-control** pattern: the orchestrator is the privileged planner (it *cannot* call `Agent()` — [spawn-protocol.md](spawn-protocol.md) §5) and sub-agents are quarantined readers returning **structured JSON only** (spawn-protocol §9) = a schema-validated channel carrying structured extractions, not raw untrusted content.
- **Enforced by:** spawn-protocol trust clause (Gap 2). Sub-agent output keeps the structured-JSON contract **and** any field interpolated into a downstream prompt/command is `[0:200]`-capped + injection-scanned like raw tool output. Agents processing untrusted input tag replies `source_trust: "untrusted"` (a CaMeL-style source-of-data capability label).
- **Guards against:** multi-agent trust escalation.

### TB-4 — Fetched external content is untrusted before it enters reasoning context
WebFetch pages, MCP tool returns **and tool descriptions**, fetched READMEs/docs — "an audited connector isn't the same as audited data." MCP tool poisoning hides instructions in tool metadata "the model reads; the user does not."
- **Enforced by:** content-inspection (Gap 3) — Haiku-class classifier + deterministic regex flag embedded instructions, tool-invocation strings, credential-shaped patterns, suspicious URLs *before* content reaches the reasoning model; untrusted spans wrapped with a **Spotlighting / data-marking** delimiter. MCP tool descriptions inspected at ToolSearch-load; description hash on first approval detects rug-pulls.
- **Guards against:** tool output as attack surface, indirect injection.

---

## 4. Risk × layer mapping (summary)

|                       | Environment (primary) | Model (defense-in-depth) | External content |
|-----------------------|------------------------|---------------------------|-------------------|
| **User misuse**       | block-* hooks, pre-edit-guard, platform hard-deny | SAFETY-RULES prose, autonomy levels | n/a |
| **Model misbehavior** | test/typecheck/as-any guards, ratchet revert, `disallowed-tools` | critic 20-detector, reviewers | n/a |
| **External attacker** | orchestrator `[0:200]`, startup-validate, sub-agent cap | injection-resistance (inherited) | content inspection; research-critic liveness |

---

## 5. Canonical-owner declaration + registration contract

This file is the canonical owner of Blitz's security posture. Bidirectional citations:
- `hooks/scripts/block-*.sh` + `pre-edit-guard.sh` + `session-start.sh` headers → cite this doc (environment-layer enforcement points).
- [spawn-protocol.md](spawn-protocol.md) §8/§9 (TB-3), [session-protocol.md](session-protocol.md) startup (TB-1/TB-2), [orchestrator.md](../../agents/orchestrator.md) §4 (TB-3/TB-4), [research-critic.md](../../agents/research-critic.md) (TB-4) cite this doc.

**Registration contract — a new deterministic security guard MUST:**
1. Cite the TB it enforces in its header/prose.
2. Add a row to [check-registry.json](check-registry.json) under `pillar: security`.
3. Be reachable via `/blitz:audit --pillar security`.

---

## 6. Scope (right-sizing — what Blitz does NOT do)

Blitz is a **Claude Code-class HITL plugin**; it inherits the platform's OS sandbox (Seatbelt/bubblewrap) + approval dialog and operates at the plugin layer above it.

| Out of scope | Why |
|---|---|
| VMs / gVisor / hypervisor isolation | No deployment surface; Blitz runs inside the platform sandbox. |
| MITM egress proxy | No network infra in a plugin; cannot intercept syscalls. |
| Reimplementing auto-mode tiers / ~20 hard-deny rules | Inherited from the platform; `block-*.sh` complement, not replace. |
| Formal capability interpreter (CaMeL's provable-security core) | Blitz has no mediating interpreter; `source_trust`/provenance tags are defense-in-depth heuristics *in the spirit of* CaMeL capabilities, **not** a formal guarantee. Stated to avoid over-claiming. |
| Enterprise governance (ISO 42001, six-agency guidance) | Applies to the org deploying Blitz, not Blitz's own posture. |
| Trust-prompt enforcement | Delegated to the platform's "Do you trust this folder?"; Blitz's duty is to not parse-execute project config before it (Gap 5; [hook-trust.md](hook-trust.md)). |

**In scope** = the layer Blitz controls: tool grants, persistent-state validation, sub-agent trust labeling, fetched-content inspection, deterministic guards — all expressible with existing primitives (hooks, check-registry, Haiku classifier agents, `[0:200]` capping).

---

## 7. Related protocols
- [session-protocol.md](session-protocol.md) — startup state read (TB-1/TB-2 enforcement point).
- [spawn-protocol.md](spawn-protocol.md) — sub-agent reply contract (TB-3).
- [hook-trust.md](hook-trust.md) — pre-trust parsing boundary (TB-1).
- [token-budget.md](token-budget.md) — Haiku-class classifier routing (TB-2/TB-4).
- [check-registry.json](check-registry.json) — `security` pillar checks.
- Derivation + research: [docs/security/containment/](../../docs/security/containment/) (`containment-model.md`, `blitz-surface-map.md`, `gap-fixes.md`, `self-audit.md`, `best-practices.md`, `SYNTHESIS.md`).
