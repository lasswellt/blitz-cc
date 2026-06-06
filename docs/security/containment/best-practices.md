# Best-Practices Cross-Check — Blitz Containment vs. the External Consensus

> Second research pass (web, May 2026). Cross-checks the Anthropic-article-derived Blitz design (`containment-model.md`, `gap-fixes.md`) against the wider industry/academic consensus on agent containment. Verdict per area: **does Blitz's design match consensus, and where does consensus add something concrete?**
>
> Headline: the Anthropic model is **not idiosyncratic** — it converges with OWASP, CaMeL, the dual-LLM/Spotlighting pattern, the memory-poisoning literature, and NIST's agent-authorization direction. The cross-check sharpens three of the five gaps (1, 2, 3) and confirms the framing of the other two (4, 5).

---

## 1. The external corpus (what the field currently says)

### 1.1 OWASP — LLM Top 10 (2025) + Agentic Top 10 + MCP Top 10
- **Prompt injection is #1 for the second edition**, direct or indirect (via "a retrieved document, tool output, or web page"). "Prompt injection has no known complete mitigation — only layered defenses such as privilege minimization, output validation, and human oversight for sensitive actions." → confirms Blitz's **layered + environment-first** posture; there is no silver bullet, so the deterministic boundary is load-bearing.
- New 2025 entry **System Prompt Leakage** — extraction of internal rules/logic. → relevant to Blitz: skill prose and the orchestrator routing matrix are partly system-prompt; the `[0:200]` caps and structured replies limit leakage blast radius.
- **OWASP Agentic Top 10 (late 2025)**: "When a model can browse the web, execute code, query databases, and call APIs, the blast radius of a single prompt injection or excessive agency vulnerability expands dramatically." → blast-radius is the right ordering axis (Blitz's `SYNTHESIS.md` orders by it). **Excessive Agency** ↔ Blitz Gap 4 (over-permissioned agents).
- **OWASP MCP Top 10 (2025)** — first MCP risk classification. Names **Tool Poisoning** ("attackers plant malicious instructions inside tool descriptions and metadata. The model reads them. The user does not."), **Prompt Injection via tool output**, and **Rug Pulls** (an approved tool silently updates to malicious behavior). → directly relevant to Blitz's MCP tool returns (Gap 3) and to the *static* surface: a poisoned MCP tool *description* is read at registration, not just at return.
- MCP spec **2025-11-25**: OAuth 2.1 for remote servers + **incremental scope consent** ("request only the minimum access needed for each operation rather than all permissions upfront"). → the protocol-level expression of Blitz Gap 4's **allowlist-as-capability-grant / least privilege**.

Sources: [OWASP LLM01:2025 Prompt Injection](https://genai.owasp.org/llmrisk/llm01-prompt-injection/) · [OWASP Top 10 for LLMs 2025 (PDF)](https://owasp.org/www-project-top-10-for-large-language-model-applications/assets/PDF/OWASP-Top-10-for-LLMs-v2025.pdf) · [OWASP Top 10 for Agentic Applications (Promptfoo)](https://www.promptfoo.dev/docs/red-team/owasp-agentic-ai/) · [MCP Security Vulnerabilities 2026 (Practical DevSecOps)](https://www.practical-devsecops.com/mcp-security-vulnerabilities/) · [MCP Threat Modeling — Tool Poisoning (arXiv 2603.22489)](https://arxiv.org/abs/2603.22489) · [Agentic MCP Security Best Practices (CSA)](https://labs.cloudsecurityalliance.org/agentic/agentic-mcp-security-best-practices-v1/)

### 1.2 CaMeL — "Defeating Prompt Injections by Design" (capability-based)
- "CaMeL's trust boundary lives in the **interpreter, not in the prompt**" — extracts control + data flow from the trusted query so "untrusted data retrieved by the LLM can never impact the program flow."
- Capabilities = **metadata tags attached to each value**, tracking "**who is allowed to read** a piece of data and **the source that the data came from**." Fine-grained policies govern what each value can do.
- AgentDojo: 77% of tasks solved **with provable security** vs 84% undefended — a small utility cost for a hard guarantee.
- "Multi-agent systems face acute trust-exploitation risks, with peer-to-peer interactions bypassing safety mechanisms… Indirect prompt injection is the primary attack vector."

Sources: [Defeating Prompt Injections by Design (arXiv 2503.18813)](https://arxiv.org/abs/2503.18813) · [Operationalizing CaMeL for enterprise (arXiv 2505.22852)](https://arxiv.org/pdf/2505.22852) · [CaMeL explainer (Simon Willison)](https://simonw.substack.com/p/camel-offers-a-promising-new-direction)

### 1.3 Dual-LLM / Spotlighting / Data marking (the structural pattern)
- **Dual-LLM** (Willison 2023; Microsoft "Spotlighting" + "Information Flow Control"): a **privileged orchestration model** that decides tool calls, separated from a **quarantined model** that "reads attacker-controlled bytes but holds no tool-calling capability and cannot alter the plan. A schema-validated channel passes only structured extractions between them, never raw untrusted content."
- **Spotlighting / data marking** (arXiv 2403.14720): transform untrusted input to carry "a reliable and continuous signal of its provenance" — "negligible detrimental impact on task performance while providing a robust defense against indirect prompt injection."

Sources: [Design Patterns for Securing LLM Agents (Willison, 2025-06-13)](https://simonwillison.net/2025/Jun/13/prompt-injection-design-patterns/) · [Design Patterns for Securing LLM Agents (arXiv 2506.08837)](https://arxiv.org/html/2506.08837v2) · [Spotlighting (arXiv 2403.14720)](https://arxiv.org/abs/2403.14720)

### 1.4 Memory-poisoning literature (persistent state)
- **MINJA** (arXiv 2601.05504): query-only memory injection, ">95% injection success, 70% attack success" via bridging steps + progressive shortening.
- **MemoryGraft** (arXiv 2512.16962): benign-looking ingestion artifacts induce a poisoned RAG store → "persistent behavioral drift across sessions."
- **Zombie Agents** (arXiv 2602.15654): agent reads a poisoned source during a benign task, writes the payload into long-term memory via its normal update process; payload "retrieved or carried forward" later triggers unauthorized tool behavior.
- Key insight: memory attacks are **temporally decoupled** — "poison planted today executes weeks later when semantically triggered." Existing defenses "detect malicious actions, not corrupted beliefs." New primitives needed: **memory contracts, belief-drift detection, context-provenance tracking.**

Sources: [Memory Poisoning Attack and Defense / MINJA (arXiv 2601.05504)](https://arxiv.org/abs/2601.05504) · [MemoryGraft (arXiv 2512.16962)](https://arxiv.org/pdf/2512.16962) · [Zombie Agents (arXiv 2602.15654)](https://arxiv.org/pdf/2602.15654)

### 1.5 NIST — agent identity & authorization (the standards direction)
- Concept paper "Accelerating the Adoption of Software and AI Agent Identity and Authorization" (Feb 5 2026): direction is "**least privilege, just-in-time access, task-scoped privileges, and action-level approvals** for high-impact decisions."
- Draws on SP 800-207 (Zero Trust), SP 800-63-4 (Digital Identity), NISTIR 8587 (token protection).
- SP 800-53 **control overlays for AI agents** will address "least-privilege tool access, agent action containment, **multi-agent trust boundaries**, and chain-of-custody logging."

Sources: [NIST AI Agent Standards Initiative (WorkOS)](https://workos.com/blog/nist-ai-agent-standards-initiative-explained) · [NIST seeking input on agent identity & authorization (Hogan Lovells)](https://www.hoganlovells.com/en/publications/shaping-the-future-of-ai-security-nist-seeking-input-on-agent-identity-authorization) · [Agentic AI Governance — NIST overlays (CSA, PDF)](https://labs.cloudsecurityalliance.org/wp-content/uploads/2026/03/governance-nist-ai-agent-standards-agentic-governance-v1-csa-styled.pdf)

---

## 2. Convergence map — Anthropic article ↔ external consensus

| Anthropic article concept | External corroboration | Agreement |
|---|---|---|
| Environment-first; deterministic boundary primary | OWASP "no complete mitigation — layered defenses"; CaMeL "trust boundary in the interpreter not the prompt" | **Strong** |
| Allowlist = capability grant (AP-3) | CaMeL capabilities-as-tags; NIST least-privilege/task-scoped; MCP incremental scope consent; OWASP Excessive Agency | **Strong** |
| Sub-agent trust escalation (AP-6) | CaMeL "who can read + source of data" tags; NIST "multi-agent trust boundaries"; dual-LLM privileged/quarantined split | **Strong** |
| Tool output as attack surface (AP-5) | OWASP MCP Tool Poisoning; Spotlighting/data-marking; dual-LLM schema-validated channel | **Strong** |
| Persistent-state poisoning (AP-4) | MINJA / MemoryGraft / Zombie Agents; "context-provenance tracking" | **Strong** + adds temporal-decoupling insight |
| Startup classifier "small, fast model" | Spotlighting "negligible task impact"; dual-LLM quarantined reader | **Strong** |

**Conclusion:** the Blitz design built from the Anthropic article lands on the same primitives the broader field is converging toward. No design change is *required*. Three concrete *sharpenings* follow.

---

## 3. Sharpenings to fold into the gap fixes

### S-1 → Gap 1 (persistent state): adopt provenance + temporal-decoupling framing
The memory-poisoning literature adds two things the article only gestures at:
1. **Temporal decoupling** — a carry-forward registry poison is *worse* than a one-session injection because it "executes weeks later when semantically triggered" (Zombie Agents) and Blitz's carry-forward is explicitly *carried across sprints*. This raises Gap 1's blast-radius justification from "reloaded each session" to "reloaded **and** sprintified **and** sleeper-triggerable."
2. **Context-provenance tracking** (the field's named defense) — Gap 1 should tag each loaded persistent-state value with its **source + write-session id** (a lightweight CaMeL-style capability tag), not just schema-check it. Belief-drift / re-verification across sprints already has a Blitz analogue: research-critic §2.7 "carry-forward citation drift re-verification." Gap 1 should reuse that re-verify cadence for non-citation carry-forward entries too.

**Net amendment:** Gap 1 validator adds a `provenance` tag (`{source, write_session, first_seen_sprint}`) per carry-forward entry; `/blitz:next` re-verifies entries older than 2 sprints (extend research-critic §2.7 to all carry-forward, not just citations).

### S-2 → Gap 2 (sub-agent trust): name the dual-LLM pattern Blitz already half-implements
Blitz's architecture **is** the dual-LLM/Spotlighting pattern, mostly by accident:
- Orchestrator = privileged model; it cannot use `Agent()` (subagents-cannot-spawn-subagents, agent-orchestration.md:392) — so it is structurally the planner.
- Sub-agents = the quarantined readers of untrusted content; they return **structured JSON only** (spawn-protocol §9) — that is the "schema-validated channel carrying only structured extractions."

The one missing piece vs. the canonical pattern: the quarantined reader should hold **no plan-altering capability**, and its output should carry a **provenance tag**. Gap 2's `source_trust: "untrusted"` is exactly the CaMeL "source of data" capability tag. **Amendment:** document in `agent-orchestration.md` that Blitz's orchestrator+sub-agent split is a dual-LLM information-flow-control boundary; the `source_trust` tag is its capability label. Cite CaMeL + Willison.

### S-3 → Gap 3 (content inspection): use data-marking, and inspect tool *descriptions* not just *returns*
Two additions from OWASP-MCP + Spotlighting:
1. **Data marking** (Spotlighting) is the validated mechanism for the `[UNTRUSTED-CONTENT]` delimiter — adopt the technique by name (transform untrusted spans to carry a continuous provenance signal), with the cited "negligible task impact" reassurance.
2. **Tool poisoning** means the attack surface includes the MCP tool **description/metadata read at registration**, not only the tool's return value. Gap 3 should inspect **both**: (a) tool returns (already designed), (b) tool descriptions/metadata when an MCP server is loaded (new). Blitz lazy-loads MCP via ToolSearch (agent-orchestration.md) — the inspection hooks there. **Rug-pull** defense: hash tool descriptions on first approval; re-inspect on change.

**Amendment:** Gap 3 adds (a) Spotlighting data-marking as the delimiter technique, (b) MCP tool-description inspection at ToolSearch-load + a description-hash rug-pull check.

### Gaps 4 & 5 — confirmed, no design change
- **Gap 4** is directly the NIST least-privilege + CaMeL capability + MCP incremental-scope-consent consensus. The capability-grant audit framing is exactly right. (Optional: cite NIST SP 800-207 zero-trust as the standards anchor in the audit output.)
- **Gap 5** — pre-trust parsing — has no specific external literature beyond the article's own incident; the `[0:200]` cap + defer design stands.

---

## 4. One honest caveat (research-critic discipline)

CaMeL's provable-security guarantee comes from a **real interpreter** mediating data/control flow (77% task completion, measurable utility cost). Blitz does **not** have that interpreter and is **not** claiming provable security — Blitz's `source_trust` tags and `[0:200]` caps are *defense-in-depth heuristics in the spirit of* CaMeL capabilities, not a formal capability system. Stating this prevents over-claiming: Blitz right-sizes the *principle* (provenance tagging, structured channels) without the *machinery* (a mediating interpreter), consistent with `threat-model.md` §6 scope discipline. The dual-LLM split Blitz already has is the closest structural match and is the honest thing to lean on.

---

## 5. Cross-references
- `containment-model.md` — Anthropic model these best-practices corroborate.
- `gap-fixes.md` — Gaps 1/2/3 carry the S-1/S-2/S-3 amendments + these citations.
- `threat-model.md` §6 — scope discipline (why Blitz adopts principle not machinery).
- `SYNTHESIS.md` — amendments fold into Epics 1/2/3 acceptance.
