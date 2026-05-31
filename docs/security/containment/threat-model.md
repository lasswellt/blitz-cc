# Blitz Threat Model — Containment Posture (design record)

> **Status: PROMOTED.** The canonical, live version now lives at [`skills/_shared/threat-model.md`](../../../skills/_shared/threat-model.md) (Epic 0 complete). That file is the O-style canonical owner cited by the `block-*.sh` guards, `spawn-protocol.md`, `session-protocol.md`, `orchestrator.md`, and `/blitz:audit`. This document is retained as the **design record** from the research pass — the reasoning that produced the posture. Edit the `_shared` version for live behavior; keep this for provenance.

> Grounded in `containment-model.md` (Anthropic, "How we contain Claude across products", 2026-05-25). Right-sized for a Claude Code-class HITL developer tool — **not** claude.ai or Cowork (see §6 Scope).

---

## 1. Purpose

Blitz is itself an agent system: 37 skills, 10 agents, worktree/sub-agent spawning, hooks on tool boundaries, persistent `.cc-sessions/` + CLAUDE.md state reloaded every session, and agents that fetch external content. It has accumulated **scattered tactical guards** (`block-*.sh`, `pre-edit-guard.sh`, orchestrator `[0:200]` caps) but **no unifying threat model**. This document is that model: it organizes the existing guards by **risk type × layer**, states the principle that orders them, defines the **trust boundaries**, and declares canonical ownership so new guards register against it instead of scattering.

---

## 2. The environment-first principle (the ordering rule)

> "The deterministic boundary is what gets hit when everything probabilistic misses." — source article

**Rule:** Blitz's deterministic guards are the boundary. Model-layer behavior (skill prose, critic reasoning, completion gates) is defense-in-depth on top of that boundary — **never the boundary itself.**

**Why this rule, stated plainly (not terse — reasoning chain must survive):** Blitz now runs on a highly aligned model (Opus 4.8 honesty gains), and it is tempting to treat "the model will notice" as sufficient. The article's two most instructive incidents — the employee phish and the allowlist disclosure — were both egress events where *the model layer had nothing anomalous to catch*, because the instruction came from the legitimate user (AP-2) or through an approved channel (AP-3). Only the environment boundary held. Therefore:

- A new control is **valid** only if it has a deterministic component (a hook, a schema check, a tool grant, a cap). A control that is *only* "the agent is instructed to be careful" does not count as containment.
- Persistent-state validation (Gap 1) and fetched-content inspection (Gap 3) are designed as **deterministic schema/scan steps plus a small-fast-model classifier**, not as "the reasoning model will spot the injection." The classifier is Haiku-class per `token-budget.md` — it "doesn't need to be the one doing the reasoning."

---

## 3. The four trust boundaries

Everything below is **untrusted-by-default**. Each boundary names what enforces it (today, or per the gap fix).

### TB-1 — Project-local state is untrusted inbound data
Files a cloned/opened repo controls: `.cc-sessions/*.json`, `activity-feed.jsonl`, developer/model profiles, **CLAUDE.md**, the carry-forward registry. Treat them the way you'd treat an inbound internet request, not trusted local config.
- **Enforced by:** `session-start.sh` must cap + schema-check before echoing (Gap 5); session-protocol startup must validate before loading (Gap 1).
- **Anti-pattern guarded:** AP-1 (pre-trust parse), AP-4 (persistent poisoning).

### TB-2 — Persistent `.cc-sessions/` state is untrusted across sessions
The same directory, viewed across the time axis: an injection that lands in the carry-forward registry or feed is **reloaded every session** and, for carry-forward, **auto-injected into the next sprint** (`sprint-plan` reads it as mandatory input — high blast radius because it *drives work*).
- **Enforced by:** session-startup validation (Gap 1) — schema-conform + injection-marker scan; quarantine, don't silently load. Generalizes the existing `rollover_count >= 3` escalation.
- **Anti-pattern guarded:** AP-4.

### TB-3 — Sub-agent output is not higher-trust than the content it processed
A sub-agent that fetched a URL or read an untrusted file is a *conduit* for that content. Its reply is **not** trusted because it "came from us."
- **Enforced by:** spawn-protocol trust-boundary clause (Gap 2). Sub-agent output stays the structured-JSON contract (already §9) **and** is subject to the same `[0:200]`-style capping + injection scan as raw tool output before the orchestrator interpolates any field into a downstream prompt/command. Agents that process untrusted input tag their reply `source_trust: untrusted`.
- **Anti-pattern guarded:** AP-6.

### TB-4 — Fetched external content is untrusted before it enters reasoning context
WebFetch pages, MCP tool returns, fetched READMEs/docs — "an audited connector isn't the same as audited data."
- **Enforced by:** a content-inspection step (Gap 3) — Haiku-class classifier flags embedded instructions, tool-invocation strings, credential-shaped patterns, suspicious URLs, *before* the content reaches the reasoning model. Wired into research/research-critic and any skill ingesting fetched content.
- **Anti-pattern guarded:** AP-5.

---

## 4. Risk × layer mapping (Blitz)

Authoritative cross-reference: `blitz-surface-map.md` §1. Summary:

|                       | Environment (primary) | Model (defense-in-depth) | External content |
|-----------------------|------------------------|---------------------------|-------------------|
| **User misuse**       | block-* hooks, pre-edit-guard, platform hard-deny | SAFETY-RULES prose, autonomy levels | n/a |
| **Model misbehavior** | test/typecheck/as-any guards, ratchet revert, `disallowed-tools` (Gap 4) | critic 20-detector, reviewers | n/a |
| **External attacker** | orchestrator `[0:200]`, startup validation (Gap 1/5), sub-agent cap (Gap 2) | injection-resistance (inherited) | content inspection (Gap 3); research-critic liveness |

---

## 5. Canonical-owner declaration

Once moved to `skills/_shared/threat-model.md`, this file is the **canonical owner** of Blitz's security posture:

- **Cited by (bidirectional):** the `block-*.sh` guards (header comment → `threat-model.md §<TB>`); `spawn-protocol.md` §8/§9 (TB-3); `session-protocol.md` startup (TB-1/TB-2); `agents/orchestrator.md` §4 (TB-3 sub-agent handling, TB-4 untrusted-content tags); `/blitz:audit` security pillar.
- **Registration contract:** a new deterministic security guard MUST (1) cite the TB it enforces, (2) add a row to `check-registry.json` under `pillar: security`, (3) be reachable via `/blitz:audit --pillar security`.
- **O-style:** scattered guards stop being self-describing point fixes; they become enforcement points of one declared posture. This is the article's "defenses should overlap and complement" made auditable.

---

## 6. Scope (right-sizing — what Blitz does NOT do)

Blitz is a **Claude Code-class HITL plugin**, not a hosted service or a sealed-VM product (containment-model.md §7). Explicitly out of scope, with reason:

| Out of scope | Why |
|---|---|
| VMs / gVisor / hypervisor isolation | No deployment surface; Blitz runs inside Claude Code's sandbox. |
| MITM egress proxy (the Cowork fix) | No network infra in a plugin; Blitz cannot intercept syscalls. |
| Reimplementing auto-mode tiers / the ~20 hard-deny rules | Inherited from the Claude Code platform; Blitz's `block-*.sh` complement, not replace, them. |
| Enterprise governance (ISO 42001, six-agency guidance) | Applies to the org deploying Blitz, not to Blitz's own posture (containment-model.md §6.4). |
| Trust-prompt enforcement | Blitz relies on the platform's "Do you trust this folder?" prompt; Blitz's duty is to not parse-execute project config *before* it (Gap 5). |

**In scope** = exactly the layer Blitz controls: tool grants, persistent-state validation, sub-agent trust labeling, fetched-content inspection, deterministic guards. All expressible with existing primitives (hooks, check-registry, Haiku classifier agents, `[0:200]` capping).

---

## 7. Cross-references
- `containment-model.md` — the framework + primary sources.
- `blitz-surface-map.md` — every artifact in the matrix.
- `gap-fixes.md` — the four trust boundaries operationalized as five fixes.
- `self-audit.md` — honest findings against the live tree.
- `SYNTHESIS.md` — sequenced, blast-radius-ordered epics.
