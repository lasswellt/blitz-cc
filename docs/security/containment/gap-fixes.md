# Gap Fixes — Five Containment Gaps, Confirmed and Designed

> Each gap maps one article failure pattern (`containment-model.md` §4) onto a **verified** Blitz surface (file:line, confirmed 2026-05-31), designs the fix using an **existing Blitz primitive**, and states the **blast-radius reduction** achieved. Specs only — implementation is `SYNTHESIS.md`.

Order = blast-radius descending (the sequence `SYNTHESIS.md` executes).

---

## Gap 1 (HIGH) — Persistent-state poisoning: session startup loads unvalidated state

**Anti-pattern:** AP-4. > "Product memory, CLAUDE.md files… reloaded each time the agent starts. Good classifiers on session startup will need to become more commonplace."

**Confirmed surface:**
- `skills/_shared/session-protocol.md:42` — "Read ALL `.cc-sessions/*.json` files." No integrity/injection check.
- `:72` reads `activity-feed.jsonl`; `:76` reads `model-profiles.json`; `:82` reads `developer-profile.json` — all unvalidated.
- The **carry-forward registry** (`.cc-sessions/carry-forward.jsonl`) is read unvalidated AND **auto-injects into the next sprint** — `sprint-plan` consumes it as mandatory input. Highest blast radius: a poisoned entry *drives real work*.
- Existing seed: `rollover_count >= 3` → human-review escalation is a primitive startup classifier.

**Fix design — session-startup validation step (deterministic + Haiku classifier):**
1. Before persistent state enters context, **schema-validate** each `.cc-sessions/*.json` and the carry-forward entries against their registry/session schemas (reuse the `check-registry-validate.sh` validator pattern — same shape, new schema set).
2. **Injection-marker scan** (deterministic regex, zero-LLM first pass): flag instruction-like strings, role-play directives ("ignore previous", "you are now"), tool-invocation strings, and URLs in fields that should hold *data* (e.g. a URL in `working_on`). Reuse the orchestrator `[0:200]` cap rationale (orchestrator.md:146) — cap every free-text field at load.
3. Flagged/malformed entries are **quarantined** (moved aside + surfaced to the user), not silently loaded. Generalize the existing `rollover_count >= 3` escalation into this path.
4. Optional Haiku-class second pass (per `token-budget.md`) only on entries the regex flags — "the classifier can be a small, fast model."

**Reuses:** `check-registry-validate.sh` pattern (validator); orchestrator `[0:200]` cap (field capping); `rollover_count` escalation (quarantine surfacing). New check-registry rows: `sec-startup-schema`, `sec-startup-injection` (pillar `security`, lane `deterministic`).

**Blast-radius reduction:** Closes the single highest-radius vector — a carry-forward injection that would otherwise be re-loaded every session AND sprintified into real work. Converts "trusted local config" into "validated inbound data" (TB-1, TB-2).

**Best-practice grounding (S-1, `best-practices.md`):** the memory-poisoning literature (MINJA arXiv 2601.05504 >95% injection / 70% ASR; MemoryGraft 2512.16962; Zombie Agents 2602.15654) shows persistent-state attacks are **temporally decoupled** — "poison planted today executes weeks later when semantically triggered." Carry-forward is *carried across sprints*, so the radius is reloaded **and** sprintified **and** sleeper-triggerable. The field's named defense is **context-provenance tracking**. **Amendment:** validator adds a `provenance` tag `{source, write_session, first_seen_sprint}` per carry-forward entry (a lightweight CaMeL-style capability tag, arXiv 2503.18813), and `/blitz:next` re-verifies entries older than 2 sprints by extending `research-critic.md` §2.7 (carry-forward drift re-verification) from citations to all carry-forward entries.

---

## Gap 2 (HIGH) — Multi-agent trust escalation: sub-agent output trust undefined

**Anti-pattern:** AP-6. > "If a sub-agent's output is treated as higher-trust than raw tool results, because such output came from 'us,' a new vector for prompt injection is introduced."

**Confirmed surface:**
- `skills/_shared/spawn-protocol.md:441-554` (§8 Output Contract, §9 Reply Contract) — defines the structured-JSON reply (`{status, summary≤50w, files_changed, issues, …}`). This **is** the article's "structured facts not raw text" mitigation — already in place. **Credit it.**
- But the protocol never states the trust *boundary*. Agents that ingest external content — `research-critic` (WebFetch, agents/research-critic.md:21), `reviewer` (diffs), `backend/frontend-dev` (files) — feed results up to the orchestrator with no trust label.
- Orchestrator caps activity-feed/HANDOFF at `[0:200]` (orchestrator.md:146-149) but **not** sub-agent replies.

**Fix design — explicit trust-boundary clause in spawn-protocol §8:**
1. State the rule: **sub-agent output is not higher-trust than the external content it processed.**
2. Agents that process untrusted input (research-critic, reviewer, and any that WebFetch/read untrusted files) add `source_trust: "untrusted"` to their JSON reply.
3. The orchestrator extends the `[0:200]` cap principle: **any reply field that will be interpolated into a downstream prompt or shell command** is capped + injection-scanned (same scan as Gap 1 step 2) — regardless of `source_trust`. `summary` and `issues[].what` are the interpolation-risk fields.
4. `files_changed[]` entries are treated as paths (validated against the worktree), never as instructions.

**Reuses:** spawn-protocol §9 JSON contract (the structure already exists); orchestrator `[0:200]` cap (extend to replies); Gap 1 injection scanner (shared regex).

**Blast-radius reduction:** A poisoned README that steers research-critic can no longer escalate by laundering through "trusted" sub-agent output — the orchestrator caps + scans it identically to raw tool output (TB-3).

**Best-practice grounding (S-2, `best-practices.md`):** Blitz's architecture already **is** the dual-LLM / Spotlighting information-flow-control pattern (Willison 2023; arXiv 2506.08837) — the orchestrator is the privileged planner (it *cannot* call `Agent()`, spawn-protocol.md:392), and sub-agents are quarantined readers returning structured JSON only (§9) = "a schema-validated channel carrying only structured extractions, never raw untrusted content." The missing piece is the **provenance tag**: `source_trust: "untrusted"` is exactly the CaMeL "source of data" capability label (arXiv 2503.18813), and NIST names "multi-agent trust boundaries" as a forthcoming SP 800-53 overlay. **Amendment:** document the orchestrator+sub-agent split in `spawn-protocol.md` as a dual-LLM boundary; cite CaMeL + Willison.

---

## Gap 3 (HIGH) — External tool/content output not inspected before entering context

**Anti-pattern:** AP-5. > "An audited connector isn't the same as audited data—a GitHub connector… can load a poisoned README straight into the model's context despite passing malware checks."

**Confirmed surface:**
- `agents/research-critic.md:76-103` — fetches every cited URL via WebFetch and classifies LIVE/DEAD/HALLUCINATED/UNKNOWN. This checks **citation liveness, not payload safety.** A LIVE page can still be poisoned.
- `skills/research/` does web research; fetched content enters context with no injection inspection.
- This is the **empty cell** in `blitz-surface-map.md` §1 (external-attacker × external-content).

**Fix design — content-inspection step for network-enabled returns (Haiku classifier):**
1. A small-fast-model (Haiku per `token-budget.md`) inspection pass on WebFetch returns, MCP tool returns, and fetched READMEs/docs **before** they enter the reasoning context.
2. Flag: embedded instructions ("ignore the above", "now run…"), tool-invocation strings, credential-shaped patterns (regex for keys/tokens), suspicious URL patterns (data-exfil endpoints, raw-paste hosts).
3. Flagged content is wrapped/quarantined with a `[UNTRUSTED-CONTENT]` delimiter and surfaced, not silently consumed. The reasoning model sees the flag.
4. Wire into research/research-critic (add an inspection sub-step parallel to §2.1 liveness) and any skill that ingests fetched content. Accept the latency tradeoff the article names — post-hoc logs show only "a successful authorized call," so inspection must be *live*.

**Reuses:** Haiku-class classifier pattern (`token-budget.md` 60/35/5 routing); research-critic's existing per-URL fetch loop (add inspection alongside liveness); Gap 1/2 injection regex (shared detector). New check-registry row: `sec-content-inspection` (pillar `security`, lane `semantic` for the classifier judgment + `deterministic` for the regex pre-pass).

**Blast-radius reduction:** Closes the only empty matrix cell. A poisoned page can no longer steer the agent silently into an authorized-looking exfiltration (TB-4).

**Best-practice grounding (S-3, `best-practices.md`):** the `[UNTRUSTED-CONTENT]` delimiter should use **Spotlighting / data-marking** by name (arXiv 2403.14720) — transform untrusted spans to carry a continuous provenance signal; the paper measures "negligible task impact." And **OWASP MCP Tool Poisoning** (arXiv 2603.22489) shows the surface includes the MCP tool **description/metadata read at registration**, not only the return value: "the model reads them; the user does not." **Amendment:** Gap 3 also inspects MCP tool descriptions at ToolSearch-load, and hashes tool descriptions on first approval to detect **rug-pulls** (a clean tool that silently updates to malicious behavior). MCP spec 2025-11-25 incremental-scope-consent is the upstream least-privilege complement.

---

## Gap 4 (MEDIUM) — Allowlist-as-capability-grant for tool permissions

**Anti-pattern:** AP-3. > "Every function reachable through any domain on an allowlist is now an attack surface."

**Confirmed surface:**
- `agents/*.md` `tools:` declarations. Read-only-by-role agents granted execution/egress capability:
  - `architect` → `Read, Glob, Grep, Bash` — **Bash = arbitrary command execution** on a strictly read-only analysis agent.
  - `critic` → `Read, Grep, Glob, Bash` — same; a read-only reviewer with shell exec.
  - `design-critic` → `Read, Grep, Glob, Bash` — same.
  - `research-critic` → `+ WebFetch` — network egress (justified by its job; document it).
- **No agent declares `disallowed-tools`.** Per v1.16.0 VERDICT:116, only `health/SKILL.md` enforces at all across the whole suite.

**Fix design — capability-grant audit in `/blitz:audit` security pillar:**
1. For each skill/agent, ask: does `allowed-tools` grant a *capability* broader than its job? Frame output as **capability grants**, not tool toggles: `Bash` = exec+egress; `WebFetch` = network egress; `Write/Edit` = filesystem mutation.
2. Recommend `disallowed-tools` where a tool is present but unjustified — close the under-adoption gap (only `health` declares it).
3. For the read-only critics (architect, critic, design-critic): they need `Bash` for read-subset commands (`git log`, `grep`, `jq`) — recommend documenting the *intended* Bash scope and, where the platform supports it, narrowing. At minimum, an explicit `# capability rationale:` comment per agent (the orchestrator already models this at orchestrator.md:20-26).

**Reuses:** `/blitz:audit` security pillar (sec-a/sec-b agents already exist); the documented-exclusion-comment pattern already used (`<!-- no-disallowed-tools: … -->` in ui-audit/dep-health). New check-registry row: `sec-capability-grant` (pillar `security`, lane `deterministic` — grep `tools:` vs role).

**Best-practice grounding (`best-practices.md`):** this gap is the direct consensus pick — CaMeL capabilities-as-tags (arXiv 2503.18813), NIST "least privilege, just-in-time, task-scoped privileges" (Feb 2026 concept paper; SP 800-207 Zero Trust), MCP **incremental scope consent** (spec 2025-11-25), and OWASP Agentic **Excessive Agency** all name the same control. Audit output may cite SP 800-207 as the standards anchor. No design change — framing confirmed.

**Blast-radius reduction:** A compromised read-only critic (e.g. via Gap 3 poisoned content) can no longer use an over-broad `Bash` grant to exfiltrate — the grant is narrowed/justified, shrinking each agent's reachable attack surface.

---

## Gap 5 (MEDIUM) — Pre-trust config: hooks parsing project-local files at startup

**Anti-pattern:** AP-1. > "A cloned repo's `.claude/settings.json` defined a hook that ran during startup, before the trust prompt. Treat project-open, config-load… the way you'd treat any inbound request from the internet."

**Confirmed surface:**
- `hooks/scripts/session-start.sh` is wired to `SessionStart` (`hooks/hooks.json:37-42`).
- It reads `.cc-sessions/HANDOFF.json` and **echoes** `phase`/`sprint`/`branch`/`last_activity` into Claude's context (session-start.sh:22-38) and the activity feed `message`/`session`/`skill` fields (`:48-52`) — **uncapped**.
- **Inconsistency:** orchestrator.md:146-149 caps the *same* HANDOFF/feed fields at `[0:200]` with an explicit injection-guard rationale. The hook does not — the startup path is the weaker of the two on identical data.
- Honest scope: the hook **parses (jq) and echoes**; it does **not execute** project-controlled code (Blitz relies on the platform trust prompt for that). So this is the *milder* form of AP-1 — context-injection, not code-execution — but it is the same class.

**Fix design — cap + defer at the startup hook:**
1. Apply the orchestrator `[0:200]` cap to every field `session-start.sh` echoes — bring the startup path to parity with the §4 state-injection path.
2. Injection-marker scan (shared Gap 1 regex) on echoed fields; replace flagged content with `[quarantined: suspicious field]`.
3. Document the boundary in a new `skills/_shared/hook-trust.md` note: hooks that read project-local files at `SessionStart` treat them as untrusted inbound data; any *execution-bearing* parsing (none today — assert this) must defer until after the platform trust prompt.
4. Self-audit assertion to keep true: **no Blitz hook executes project-controlled content pre-trust.** (Confirmed today — `gap-fixes` Gap 5 + `self-audit.md` §3.)

**Reuses:** orchestrator `[0:200]` cap (apply verbatim); Gap 1 injection regex; existing hook-header-comment convention.

**Blast-radius reduction:** Removes the uncapped pre-trust injection channel; makes the startup path consistent with the already-hardened orchestrator path (TB-1).

---

## Summary table

| Gap | Article AP | Blitz surface (file:line) | Primitive reused | Trust boundary |
|---|---|---|---|---|
| 1 | AP-4 | session-protocol.md:42,72,76,82 + carry-forward | check-registry-validate + `[0:200]` + rollover escalation | TB-1, TB-2 |
| 2 | AP-6 | spawn-protocol.md:441-554 | spawn §9 JSON contract + `[0:200]` | TB-3 |
| 3 | AP-5 | research-critic.md:76-103; skills/research | Haiku classifier + research-critic fetch loop | TB-4 |
| 4 | AP-3 | agents/*.md `tools:` (architect/critic/design-critic Bash) | `/blitz:audit` security pillar + exclusion-comment pattern | — (capability) |
| 5 | AP-1 | session-start.sh:22-52 (hooks.json:37-42) | orchestrator `[0:200]` cap | TB-1 |
