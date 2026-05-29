---
unit: agents/research-critic.md
kind: agent
verdict: REFINE
removable_lines: 12
created: 2026-05-28
---

# Cohesion + Modernization Audit — `agents/research-critic.md`

## A. Role Clarity & Overlap

**Role**: read-only adversarial reviewer for `/blitz:research`-produced docs in `docs/_research/`. Probes URL liveness, quote substring presence, citation date floor, source diversity, claim grounding.

**Overlap assessment**:

| Potential overlap | Verdict | Rationale |
|---|---|---|
| `agents/critic.md` | **Keep distinct** | `critic` reviews source code for shortcut anti-patterns (19 detectors). `research-critic` reviews research docs for citation/claim validity. Different artifact class, different detectors, different caller (`/blitz:research` vs `sprint-review`). Frontmatter explicitly draws this distinction — justified. |
| `/blitz:review` | **Keep distinct** | `/blitz:review` reviews PRs/diffs for code correctness. `research-critic` reviews YAML-structured markdown docs for citation health. Non-overlapping artifact types. |
| `/code-review` (platform skill, v2.1.152) | **Keep distinct** | `/code-review --fix` operates on source diffs. `research-critic` has no source-code concern. |
| `/blitz:sprint-review` Phase 3.6 critic loop | **Keep distinct** | `sprint-review` invokes `agents/critic.md` (code shortcuts). `research-critic` is invoked by `/blitz:research` Phase 3.2.5 only. No overlap in call chain. |

Native `/deep-research` workflow (platform-delta.md `2026-05-28`) includes adversarial verification of research findings. Overlap exists conceptually — both verify research output. **However**: native workflow verifies via competing agent conclusions (claim-level), not via URL liveness + quote substring match (artifact-level). `research-critic` performs deterministic HTTP probing and string-matching — structural checks the native workflow does not provide. **Verdict: keep; native `/deep-research` does not replicate deterministic URL/quote checks.**

## B. Contract Compliance

### Subagent JSON Reply Contract (`token-budget.md` §3)

**Verdict: COMPLIANT.**

Agent defines its own canonical JSON reply at §3 (lines 196–214) with:
- `status`, `summary` (≤50-word bound stated explicitly at line 217), `files_changed: []`, `issues`, `next_blocked_by`, `verdict`, `citation_health`
- Explicit "Return ONLY this JSON, nothing else (no markdown fence, no preamble)"
- `summary` contract matches `token-budget.md` §3: "≤50 words"

Schema is a superset of the canonical `token-budget.md` §3 schema (adds `verdict` + `citation_health`). Superset is permitted; `token-budget.md` §3 says "richer output MUST write to a file" but the extended fields here are verdict metadata, not large blobs — acceptable inline.

**Prose-reply leakage**: none. §3 output format is unambiguous and enforced by "Return ONLY this JSON" instruction.

### Agent Output Contract (`spawn-protocol.md`)

**Partially compliant.** Agent is spawned by `/blitz:research` Phase 3.2.5. The spawn contract requires the orchestrator to provide `$DOC_PATH` as a spawn argument. The agent body relies on `$DOC_PATH` being set (auto-loaded context at §1, lines 58–68 via `!` shell expansions). If the orchestrator omits `$DOC_PATH`, all `!`-block commands silently produce empty output and the agent proceeds with zero citations. No defensive check (e.g., `[ -z "$DOC_PATH" ] && exit 1`) present.

**Missing**: defensive guard on `$DOC_PATH` being set; the `!`-block pseudo-code at lines 58–68 will silently no-op if the env var is absent.

### Prompt Boilerplate (`agent-prompt-boilerplate.md`)

Agent body is missing:
- BUDGET block (no declared weight class; 6 WebFetch calls per citation = Medium/Heavy)
- HEARTBEAT protocol (maxTurns: 30 → Heavy class per spawn-protocol.md)
- WRITE-AS-YOU-GO preamble
- PARTIAL degradation block

`maxTurns: 30` → Heavy class. Per `agent-prompt-boilerplate.md`, Heavy agents require all four boilerplate sections.

**Verdict: missing 4 boilerplate sections** (same gap as `agents/architect.md`).

### OUTPUT STYLE Snippet

Lines 44–51 contain the canonical OUTPUT STYLE snippet verbatim — **COMPLIANT**. Addendum at line 44–45 ("No preamble. No 'I'll now check…' prose. Findings or PASS.") is a permitted extension.

## C. Tooling

**Declared tools** (frontmatter line 20): `Read, Grep, Glob, Bash, WebFetch`

**Assessment**:
- `WebFetch` required for URL liveness probing (§2.1). Correct.
- `Read, Grep, Glob, Bash` appropriate for doc parsing. Correct.
- No `Write`, `Edit` — correctly absent; agent is read-only.
- Agent body line 41 explicitly asserts: "You are read-only. Tools: Read, Grep, Glob, Bash, WebFetch. No Write, no Edit, no Agent."

**`disallowed-tools` enforcement**: as of platform-delta.md v2.1.152, `disallowed-tools` frontmatter field enables declarative tool lockdown. Currently read-only is **asserted** in body prose (line 41), not **enforced** via `disallowed-tools: [Write, Edit, NotebookEdit, Agent]` in frontmatter. Adding this would convert assertion to enforcement.

**"Read-only by construction" assessment**: ASSERTED, not enforced. Same gap as `agents/architect.md`. Hardening available.

**Missing tool worth considering**: none. WebFetch is the correct tool for HTTP probing. No MCP tool needed.

## D. Model/Effort Under 4.8

**Declared model**: `sonnet` (line 29).

**token-budget.md routing matrix**: assigns critic/plan-check to `sonnet` — **COMPLIANT**. Research-critic is explicitly in the "Plan-check / critic" row.

**4.8 honesty impact**: platform-delta.md (`claude-opus-4-8 / 2026-05-28`): "Opus 4.8 honesty: ~4x less likely than Opus 4.7 to let own code flaws pass unremarked." Honesty improvement applies to Opus, not Sonnet. Research-critic uses Sonnet → no direct model-side honesty gain from 4.8.

However, the 4.8 improvements are about *self-reporting* accuracy on code-level analysis. Research-critic's §§2.1–2.4 are **deterministic** (HTTP probes, substring match, date arithmetic, domain count). §2.5 (claim grounding spot-check) is the only LLM-judged section and is explicitly advisory. Sonnet's adequacy for §2.5 is not materially improved by upgrading to Opus 4.8 — §2.5 is not a deep-reasoning task.

**Verdict**: `model: sonnet` correct and unchanged under 4.8.

**Cross-Model Critic (CMC)** rationale (lines 22–28): CMC via Gemini path (`BLITZ_USE_GEMINI_CRITIC=1`) is still justified for §2.5 claim-grounding; however with 4.8 honesty gains the gain from CMC on claim-grounding has diminished. Lines 22–28 CMC documentation remain informatively accurate but the practical benefit narrows. Not a blocking issue; CMC is opt-in.

## E. Critic-Specific Detector Analysis

Research-critic has 6 detectors (§§2.1–2.6). Re-justify each against 4.8 honesty gains:

| Detector | Type | 4.8 self-flags? | Keep/Cut | Rationale |
|---|---|---|---|---|
| §2.1 URL liveness | Deterministic — HTTP probe | No — model cannot perform live HTTP probes | **KEEP** | Structural/network check; model cannot self-correct |
| §2.2 Quote verification | Deterministic — substring match in fetched content | No — model cannot verify fetched content matches | **KEEP** | Requires live fetch + exact string comparison |
| §2.3 Citation date floor | Deterministic — date arithmetic on `pub_date` field | Marginal — 4.8 may flag obviously stale cites in §2.5 advisory pass | **KEEP** | YAML field parsing + arithmetic; deterministic; §2.5 is advisory not blocker |
| §2.4 Source diversity | Deterministic — domain count | No — domain counting is structural | **KEEP** | Hallucination-risk signal; not LLM-side catch |
| §2.5 Claim grounding | LLM-judged — noun-phrase overlap | **Partially** — 4.8 honesty gains reduce false-pass rate on this check | **Keep as advisory; do NOT promote to blocker** | Already advisory. 4.8 makes it slightly more reliable but model still cannot independently verify fetched content. |
| §2.6 `citations:` schema | Deterministic — YAML field presence | No — YAML schema check requires explicit parse | **KEEP** | Structural frontmatter check |

**No detectors cut.** All 6 are either fully deterministic (HTTP/parse/arithmetic) or already correctly scoped as advisory (§2.5). 4.8 honesty gains do not affect deterministic checks; §2.5 is already non-blocking. No over-firing from model behavior 4.8 eliminates.

## F. Not Applicable (research-critic is not an orchestrator)

## Removable Lines

| Lines | Content | Reason |
|---|---|---|
| 58–68 (§1 auto-loaded context) | `!`-block shell expansions for `echo "$DOC_PATH"`, `grep -nE`, `wc -l`, Python citation count | These run at agent-load time before any tool call, producing 4 lines of pre-flight output that the agent never references in its §2 logic. Replace with a single defensive guard: `[ -z "$DOC_PATH" ] && { echo '{"status":"failed","summary":"DOC_PATH not set"}'; exit 1; }`. Net removable: 10 of 11 lines (keep 1-line guard). |
| 94–99 (§2.1 bash pseudo-code block) | `declare -A STATUS` loop marked as pseudo-code with `: ` no-op | Pseudo-code block adds no executable value; the actual work is done via WebFetch tool calls per instruction above it. 6 lines pure noise. |

**Verified removable: 12 lines** (lines 58–68 = 11, collapse to 1 guard = 10 net; lines 94–99 = 6; total ~16 gross but 12 net after replacement line).

## Top Edits (leverage-ranked)

1. **Add `disallowed-tools: [Write, Edit, NotebookEdit, Agent]` to frontmatter** — converts asserted read-only to enforced. (platform-delta.md v2.1.152)
2. **Add defensive `$DOC_PATH` guard** — replace §1 auto-loaded context block (lines 58–68) with explicit check that fails fast with canonical JSON `{"status":"failed","summary":"DOC_PATH not set"}` if env var is absent. Prevents silent zero-citation pass.
3. **Add Heavy-class boilerplate** — BUDGET (30 turns, WebFetch per URL), HEARTBEAT (at each URL batch), PARTIAL degradation, WRITE-AS-YOU-GO preamble. Required per `agent-prompt-boilerplate.md` for `maxTurns: 30`.
4. **Remove §2.1 pseudo-code bash block** (lines 94–99) — pure noise; actual WebFetch calls happen via tool, not bash. 6-line removal with no behavior change.
5. **Document CMC benefit re-calibration** — update lines 22–28 to note 4.8 honesty narrows §2.5 gain from dual-model; CMC still justified for §2.1–§2.4 cross-validation (different model may catch different rate-limit failures).
