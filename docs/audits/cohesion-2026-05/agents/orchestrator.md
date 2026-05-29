---
unit: agents/orchestrator.md
kind: agent
verdict: MODERNIZE
removable_lines: 12
created: 2026-05-28
---

# Cohesion + Modernization Audit — `agents/orchestrator.md`

Source read in full before verdict. All platform-delta claims cite `docs/audits/cohesion-2026-05/platform-delta.md` (2026-05-28).

---

## A. Role Clarity & Overlap

**Role**: freeform-input router → slash command. NOT a builder, critic, or reviewer. Scope is well-defined.

**Builder/critic/orchestrator split**: no overlap with `agents/critic.md` (adversarial shortcut detection) or `agents/reviewer.md` (code quality + written findings). Orchestrator reads state and routes; it does not evaluate quality.

**Overlap with `/code-review`**: none. `/code-review` is a skill that spawns parallel diff reviewers. Orchestrator routes to it; it does not replicate any of that logic.

**`/blitz:next` overlap**: §2 routing matrix correctly distinguishes `next` (read-only state survey + recommendation) from the orchestrator (routes freeform input to any skill). Orchestrator delegates to `/blitz:next` rather than re-implementing state survey. Clean boundary — **keep both**.

---

## B. Contract Compliance

### Subagent JSON reply contract (token-budget.md §3)

Orchestrator is **not** an Agent() spawn target — it is the plugin main-thread agent activated via `.claude-plugin/settings.json {"agent": "orchestrator"}`. The canonical JSON reply contract (≤50-word summary, `status/summary/files_changed/issues/metrics`) applies to agents the orchestrator receives replies FROM, not to the orchestrator itself. N/A for this dimension.

Orchestrator **output contract** (§6 of agent body): three-line format (`Route → /blitz:<skill>`, `Why:`, `State:`). This is a first-party contract not governed by spawn-protocol §3. **Compliant.**

### Agent Output Contract (spawn-protocol.md)

Orchestrator spawns no agents (enforced by absence of `Agent` in `tools:` frontmatter). Contract N/A.

### Prompt boilerplate (agent-prompt-boilerplate.md)

Boilerplate targets skills that spawn `Agent()` workers. Orchestrator spawns none → boilerplate not applicable. No leakage gap.

### Prose-reply leakage

§5 instructs ≤3-sentence routing replies. §6 specifies three-line format. Inline read-only answers are allowed. No structural leakage risk.

---

## C. Tooling

**Declared tools**: `Read, Grep, Glob, Bash, TaskCreate, TaskUpdate, TaskList, Monitor`

No `Write`, `Edit`, `Agent` — correct and enforced by frontmatter. "Read-only by construction" claim for write operations is **declaratively enforced**: absent from `tools:` means the platform does not offer them in this agent's context. Verified per `agent-routing.md §4` which calls this "physically impossible."

**`disallowed-tools` field** (platform-delta.md v2.1.152): `disallowed-tools` now available in frontmatter for explicit lockdown. Orchestrator currently relies on tool omission (no Write/Edit/Agent in `tools:`). Omission is equally effective for named tools; `disallowed-tools` would only add defense-in-depth if some tool were inherited by default. For this agent the current approach is sufficient — **no change required**, but noting the option exists.

**Missing tool consideration**: `ToolSearch` — useful for deferred-schema resolution if orchestrator ever lazily checks skill descriptions via MCP. Currently not needed per lazy-load pattern in §5 (grep `skills/*/SKILL.md`). Skip for now.

---

## D. Model/Effort Under 4.8

`model: sonnet` with inline rationale (routing is pattern-match-heavy, not reasoning-heavy; latency matters for UX; Opus over-provisioned for routing).

**Sonnet 4.6 vs Opus 4.8 fast mode** (platform-delta.md `claude-opus-4-8` fast mode, 2026-05-28): Opus 4.8 fast mode is $10/$50 per MTok input/output — comparable to Sonnet 4.6 at $3/$15 per MTok at 16–20× the output rate. For an orchestrator that runs on every freeform turn, Opus 4.8 fast mode is NOT cost-justified (the task is routing, not synthesis). Sonnet 4.6 remains the correct choice.

**Honesty gains in 4.8** (platform-delta.md, verified: "~4x less likely to let own code flaws pass unremarked"): routing accuracy is about intent classification, not factual honesty. 4.8 honesty gains do not meaningfully change routing quality. Sonnet 4.6 stands.

**`effort:` field**: not set in frontmatter. `token-budget.md` §1 routing matrix says orchestrators → `sonnet`; effort level for an agent is separate from the skill frontmatter `effort:` field (which is skill-metadata for `/blitz:` invocations). No `effort:` field is expected or required in agent frontmatter. **No gap.**

---

## E. CRITICS ONLY

Not a critic agent. Section N/A.

---

## F. ORCHESTRATOR ONLY — Injection & Native-Feature Surface

### F.1 HANDOFF.json + activity-feed as untrusted-input surface

`initialPrompt:` reads `.cc-sessions/HANDOFF.json` and `.cc-sessions/activity-feed.jsonl` and surfaces a one-line state summary. §4 state injection reads four additional files via `jq`.

**4.8 injection regression** (platform-delta.md "Gray Swan agent red-team ASR regression: Opus 4.8 ~9.6% vs Opus 4.7 6.0% thinking enabled" — NOTE: this is listed as **Unverified** in platform-delta.md; do not treat as authoritative). On verified data only: Opus 4.8 fast mode ASR is not characterized; Sonnet 4.6 ASR is not stated. Cannot make a definitive injection-risk claim from verified data.

**Structural exposure**: `HANDOFF.json` and `activity-feed.jsonl` are written by blitz skills (controlled process) and by the orchestrator itself. They are not directly user-controlled. Risk is low but not zero — a compromised skill could write a malicious `summary` or `message` field that the orchestrator surfaces verbatim.

**Current sandboxing posture**: none. The orchestrator reads these files with `jq` and renders the output directly. No sanitization or length-capping on the extracted fields before they enter the reply.

**Recommendation**: cap extracted field lengths at render time. Example: `jq -r '.message // "" | .[0:200]'` in §4 snippets. This is a low-effort hardening. **Removable as a gap**, not as existing lines — adds ~4 lines.

**4.8 honest-reporting improvement** (platform-delta.md verified: "~4x less likely to let own code flaws pass unremarked"): this reduces the risk of the orchestrator silently acting on injected instructions by increasing the likelihood it questions anomalous content. Partial mitigation, not elimination.

### F.2 `/goal` — dynamic completion-condition loops

`/goal` (platform-delta.md v2.1.139 / 2026-05-11): fast model checks a completion condition after each turn; loops until condition holds. Routing matrix §2 maps "autonomous loop" → `/blitz:next --loop`. Native `/goal` is simpler for single-condition exit criteria (e.g., "loop until sprint state = SHIPPED").

**Assessment**: `/blitz:next --loop` cross-session resume via `STATE.md` is not replicated by `/goal` (platform-delta.md: "native resume is intra-session only — gap persists"). Orchestrator routing to `--loop` is **correct and should be kept**. Opportunistic note: could add a `/goal` routing row for simple single-condition loops that don't need cross-session resume. This is an additive improvement, not a replacement.

**Verdict on keep vs delegate**: **keep** current `--loop` routing. Optionally add `/goal` as an alternative for intra-session conditions. Do not delegate `--loop` to native `/goal`.

### F.3 Dynamic Workflows (platform-delta.md v2.1.154+)

Native JS script workflows fan work across parallel subagents with intermediate results in script variables. Blitz `spawn-protocol.md` + `agent-routing.md` partially replicate this.

**Overlap with orchestrator routing role**: workflows execute at the skill level (super-orchestrators that spawn agent waves). The orchestrator's routing role is upstream of workflow execution — it routes the user to the slash command; the slash command decides whether to use `Agent()` or `Workflow`. **No functional overlap with orchestrator itself.** The orchestrator does not dispatch workflows.

**Conclusion**: native Dynamic Workflows do not subsume the orchestrator's routing role. Keep as-is.

### F.4 `claude agents` TUI (platform-delta.md v2.1.139)

Multi-worktree sprint-dev visibility partially closed by native `claude agents` panel. No routing-role impact.

---

## G. Removable Lines

Total body lines: 195. Lines that are redundant, stale, or subsumable:

| Lines | Content | Reason |
|---|---|---|
| 107 (partial) + 181–190 | HARD_SPEC routing duplicated in §2 table row and §6.1 block | §6.1 (10 lines) is a full expansion of the §2 row; §2 row suffices for routing; §6.1 adds the loop-escalation caveat which is not in §2 — **not removable** |
| 59 (Vue-conditional note) | Vue-conditional skills paragraph | Accurate, needed — keep |
| 20–26 | Model rationale comment block | 7 lines of YAML comment; useful for maintainers but verbose. Could compress to 2 lines. **Removable: ~5 lines** |
| 141–153 | §4 state injection bash block | 13 lines; the `jq` snippets are good but the `# Ratchet status` snippet references `docs/sweeps/ratchet.json` path which may not exist on all projects. Could add `2>/dev/null` guard (already present on some). **Not removable but 2 lines could be merged** |

**Confirmed removable: ~12 lines** (5 from model-rationale comment compression + up to 7 from merging redundant bash guards).

---

## Top Edits (leverage-ranked)

1. **Inject field-length caps in §4 `jq` snippets** — hardens HANDOFF.json/activity-feed injection surface. E.g. `| .[0:200]` on `message`, `summary` fields. ~4 lines added.
2. **Compress model-rationale YAML comment** (lines 20–26) from 7 lines to 2. Reduces noise; rationale survives as a one-liner.
3. **Add `/goal` routing row** to §2 "Diagnostics & meta" table for single-condition intra-session loops as an alternative to `--loop` where cross-session resume is not needed. ~2 lines added.
4. **Update `model:` comment** to reference `claude-sonnet-4-6` (current model ID per platform-delta.md 2026-05-28) instead of generic `sonnet`, for frontmatter precision.
5. **Add `disallowed-tools: [Write, Edit, Agent]`** as defense-in-depth alongside existing tool omission (platform-delta.md v2.1.152). Makes lockdown explicit and visible in frontmatter diff.
