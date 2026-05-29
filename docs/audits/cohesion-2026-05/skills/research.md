---
unit: skills/research
kind: research
verdict: needs-tightening
removable_lines: 55
created: 2026-05-28
---

# Audit: skills/research

## A. Identity & Boundaries

**One-sentence purpose:** Spawn 2-4 parallel research agents, collect and validate findings, synthesize a structured `docs/_research/<date>_<topic>.md` consumable by `/blitz:roadmap extend`.

**Description vs body alignment:** Verified match. Frontmatter description accurately captures domain, library, codebase agents + `scope:` YAML + roadmap ingestion.

**Overlaps with other skills/agents:**

| Overlap | Skill/Agent | Type |
|---------|-------------|------|
| Web search + synthesis | `skills/deep-research` (platform `/deep-research` skill, not a Blitz skill) | **Legitimate layering** — Blitz adds codebase-analyst, infra-analyst, `scope:` registry contract, `research-critic` citation probe, state-handoff pipeline position; platform `/deep-research` has no stack-awareness or registry output |
| Citation adversarial probing | `agents/research-critic.md` | **Legitimate layering** — research-critic is spawned by research (§3.2.5); not a competing skill |
| Topic scoping + clarification | `skills/ask` | **Legitimate layering** — ask is a pre-step; research does not reimplement it |
| Roadmap ingestion of `scope:` | `skills/roadmap` | **Legitimate boundary** — produces artifacts consumed by roadmap; no functional overlap |

No true duplication found among Blitz skills.

**Native platform overlap (platform-delta.md v2026-05-28):**

> "Adversarial verification built into `/deep-research` workflow: independent agents refute each other's findings, votes converge before reporting" — platform-delta.md row 2 (2026-05-28)

The native `/deep-research` workflow now implements parallel agents + adversarial verification natively. Blitz `/blitz:research` adds:
- `codebase-analyst` agent (no web search, stack-aware; native `/deep-research` has no equivalent)
- `scope:` YAML registry contract consumed by `roadmap extend` (pipeline-specific; native tool has no output contract)
- `infra-analyst` conditional spawn
- `research-critic` citation validation wired into Phase 3
- `carry-forward.jsonl` entries for sprint-review Invariant 1

**Verdict for native overlap:** **keep** — the codebase-analyst + registry pipeline contract justify retention over delegation. Delegating to native `/deep-research` loses the carry-forward chain.

---

## B. Cohesion

**Cited _shared protocols:**

| Protocol | Cited | Followed / Restated |
|----------|-------|---------------------|
| `session-protocol.md` | §0.0 | Followed by reference — no inline restatement |
| `verbose-progress.md` | §0.0 | Followed by reference |
| `spawn-protocol.md` | §1.3, §2.1 | Followed — §2.1 copies the `classify_output()` bash function inline (see drift risk below) |
| `token-budget.md` | §1.2 | Followed by reference; model routing table summarized inline but cites source |
| `carry-forward-registry.md` | §3.1.1 | Followed by reference; `scope:` format repeated inline (intentional — output contract must be self-contained for synthesis phase) |
| `definition-of-done.md` | opening | Followed by reference |
| `terse-output.md` | §3.1, OUTPUT STYLE snippet | Canonical snippet **present verbatim** — Invariant 5 satisfied |
| `workflow-dispatch.md` | §1.2.6 | Followed by reference |
| `state-handoff.md` | implicit | Produces artifacts matching `state-handoff.md §research` exactly: `docs/_research/<YYYY-MM-DD>_<slug>.md` + optional `scope:` block |

**Drift risk — `classify_output()` inline copy (§2.1):** The 15-line bash function is reproduced verbatim from `spawn-protocol.md §8`. If `spawn-protocol.md` updates the classifier, research won't inherit it. Should be replaced with `source`/`import` reference or a note pointing to canonical location.

**Cross-refs live + accurate:** All `/_shared/` paths verified present on disk. `references/main.md` exists. No dead links detected.

**Pipeline chain (end-to-end trace):**

```
/blitz:research auth-strategy
  → writes docs/_research/2026-05-28_auth-strategy.md
  → optional: scope: YAML block in frontmatter
/blitz:roadmap extend
  → Phase 1.1.5: reads docs/_research/*.md, ingests scope: entries
  → writes .cc-sessions/carry-forward.jsonl (event: created)
/blitz:sprint-plan Phase 0 step 8
  → reads carry-forward.jsonl → mandatory inputs
```

Chain verified against `state-handoff.md §research` (lines 37-50). Output shapes match what downstream consumers expect. ✅

**OUTPUT STYLE snippet:** Present verbatim at SKILL.md line 26. Invariant 5 satisfied.

---

## C. Conciseness

**Body line count:** 490 / 500 cap — within limit but at 98%.

**Removable prose (anti-laziness nudges / defensive restatements):**

1. **§1.3 step "Do NOT skip phases" header** (line 33): Defensive "execute every phase in order. Do NOT skip phases." — guards against old-model shortcutting. With Opus 4.8 honesty gains (platform-delta.md, `claude-opus-4-8 / 2026-05-28`), this prompt-level nudge is redundant. ~2 lines removable.

2. **§1.2 model routing rationale** (lines 95-95): "retrieval-class workloads… → Haiku 4.5 (12× cheaper than Sonnet, comparable hallucination rate per arxiv 2604.03173)" — belongs in `token-budget.md`, not in each skill. Already cited; the inline rationale is DRY violation. ~3 lines removable.

3. **§2.2 cost commentary** (lines 264-265): "costs ~100K input tokens (~$0.30 at Sonnet rates)... saves ~$0.26/run, 22% of total cost" — cost figures are stale the moment models change. Belongs in `token-budget.md §cost-model` not inline. ~3 lines removable.

4. **§1.2.5 inline savings estimate** (line 115): "Saves ~$0.10/run on ~40% of runs (token-economics §9 Gap 6)" — same issue, stale cost inline. ~1 line removable.

5. **§4.1 Output Summary** ASCII box template (lines 456-465): 10-line canned output template. The format adds no information not already in the phase description; it's a visual formatting guide that pads line count. With model honesty improvements, not needed. ~10 lines removable.

6. **Phase 4.2 Follow-Up Suggestions table** (lines 471-481): 10-line table listing obvious next-skill routing. Partially duplicates `state-handoff.md §research` pipeline position. Could be reduced to 2-line cross-ref. ~8 lines removable.

7. **`references/main.md` "Agent Output Format (legacy)"** section (lines 444-471): Explicitly labeled "legacy — agents now use REPLY CONTRACT JSON". Dead code. ~28 lines removable in references file (not counted in SKILL.md 490 total, but contributes to maintenance burden).

**Total removable from SKILL.md:** ~37 lines.
**Total removable from references/main.md:** ~28 lines (legacy section only).
**Reported figure (SKILL.md scope):** 37 (conservative; references not in SKILL.md line count).

**Content belonging in shared protocol:** model-routing cost rationale (§1.2, §2.2, §1.2.5) → `token-budget.md`.

---

## D. Modernization

**Native primitive overlap:**

1. **Parallel agent orchestration (§1.3-W):** The `Workflow` dispatch path (§1.2.6, §1.3-W) already maps to native orchestration (platform-delta.md row 1: "JS script fans work across dozens–hundreds of parallel subagents", v2.1.154+). The `BLITZ_DISPATCH` capability gate is correct — keep the dual-path with agent fallback.

2. **Adversarial verification (§2.3, `web-researcher` contrarian role):** Native `/deep-research` now has built-in adversarial verification (platform-delta.md row 2). Blitz keeps explicit `web-researcher` contrarian role for codebase-specific research where native `/deep-research` has no stack agent. **Keep** — tradeoff: losing the explicit role would remove arxiv 2604.02923 heterogeneous framing (35.9% disagreement rate) for codebase findings.

3. **`disallowed-tools` frontmatter** (platform-delta.md v2.1.152): `codebase-analyst` has `Max Web Searches: 0` enforced only by prompt instruction. Could be enforced declaratively via `disallowed-tools: WebSearch, WebFetch` for that sub-agent spawn. Currently only prose. Opportunity but not critical.

4. **Model IDs:** Frontmatter `model: opus` — no explicit version. With `claude-opus-4-8` current (platform-delta.md row `Model IDs current as of 2026-05-28`), and fast mode available at $10/$50 per MTok (vs $30/$150 for 4.7 fast mode), the orchestrator should specify `claude-opus-4-8`. Sub-agents use haiku/sonnet by routing; those IDs are current (`claude-haiku-4-5`, `claude-sonnet-4-6`). **Update `model: opus` → `model: claude-opus-4-8`** in frontmatter.

5. **Fast mode:** Research orchestrator is latency-visible (user waits on synthesis). `speed: "fast"` API param available for `claude-opus-4-8` (platform-delta.md `fast-mode-2026-02-01 beta header`). Not currently referenced. Low-risk addition to `token-budget.md` but no skill-level change required.

6. **`/goal` completion loop** (platform-delta.md v2.1.139): Not applicable — research is single-shot, not a condition-polling loop.

**`effort: high` + `model: opus` sane under 4.8?** Yes for orchestrator (synthesis + cross-agent reasoning warrants Opus). Sub-agents already routed to haiku/sonnet per token-budget. Correct.

---

## E. Correctness

**Stale version refs:**
- `compatibility: ">=2.1.71"` — skill uses Workflow tool (§1.2.6) which requires v2.1.154+. Minimum compatibility should be gated at `>=2.1.71` for Agent path only; the Workflow path requires `>=2.1.154`. The capability gate in §1.2.6 handles this at runtime, but the frontmatter `compatibility` field is misleading — it implies the full skill works at 2.1.71 when the Workflow path silently falls back. Not a hard error but worth noting.

**Model IDs:** `model: opus` in frontmatter is an alias; won't crash but misses fast-mode opt-in available for `claude-opus-4-8`. Update recommended.

**Dead flags:** `BLITZ_RESEARCH_NO_CRITIC=1` (§3.2.5) — note says "default-on for docs destined for `/blitz:roadmap` ingestion" but the flag name implies skipping. Confusing: `NO_CRITIC=1` skips critic but is called "default-on" — the default-on claim is for docs going to roadmap, meaning critic IS run by default unless suppressed. Wording is inverted / confusing; not a broken path.

**Paths:** All `/_shared/` refs and `references/main.md` verified present. No dead paths.

**`subagents-cannot-spawn-subagents` constraint:** Research spawns `agents/research-critic.md` in §3.2.5. If research is itself invoked as a subagent (e.g., from orchestrator), this violates the constraint. Current design is slash-invoked only (`/blitz:research`), which bypasses the orchestrator (per `agent-routing.md`). Constraint preserved. Dynamic Workflows (platform-delta.md row 1) do not change this — the Workflow JS `agent()` calls are native primitives, not Blitz `Agent()` tool calls, so the constraint is not triggered.

**`classify_output()` inline copy drift risk:** Already noted in §B. If `spawn-protocol.md §8` changes the PARTIAL detection logic, this copy will silently diverge.

---

## F. Verdict

**Verdict:** `needs-tightening`

**Top 3 highest-leverage edits:**

1. **Update `model: opus` → `model: claude-opus-4-8`** in SKILL.md frontmatter (platform-delta.md `Model IDs current as of 2026-05-28`; enables fast-mode path in `token-budget.md`).

2. **Delete §2.2 inline cost estimates + §1.2 inline cost rationale** (~7 lines) and replace with `<!-- token-budget.md §cost-model owns these figures -->`. Stale inline cost numbers create maintenance debt every model generation.

3. **Replace inline `classify_output()` copy in §2.1** with a `source`/reference call to `spawn-protocol.md §8` (or at minimum add a comment `# Copied from spawn-protocol.md §8 — keep in sync`). Drift here produces silent classification failures.

**Secondary (low-risk):** Delete `references/main.md §Agent Output Format (legacy)` (~28 lines, explicitly labeled dead code).
