# Validation — agent: critic (v1.16.0 cohesion+DW)

File: `agents/critic.md`
Verdict: **cohesive**

## A1 — Frontmatter + reply contract — PASS
- `hooks/scripts/agent-frontmatter-validate.sh agents/critic.md` → `OK: 1 agent .md files conform`, exit 0.
- Validator (script lines 26, 127) asserts forbidden fields `hooks/mcpServers/permissionMode` absent (silently-stripped class) — none present in `agents/critic.md:1-21`. `model: sonnet` (line 18) ∈ {opus,sonnet,haiku}; `tools: Read, Grep, Glob, Bash` (line 16) non-empty.
- OUTPUT STYLE snippet verbatim at `agents/critic.md:29` (matches validator SNIPPET_RE `terse-technical per /_shared/terse-output.md`).
- Reply contract: `agents/critic.md:205-218` returns `{status, summary≤50w, files_changed, issues, next_blocked_by, verdict}` — field-for-field matches spawn-protocol §9 (`skills/_shared/spawn-protocol.md:539-543`) + token-budget §3 (`skills/_shared/token-budget.md:71,79-83`). `summary` capped "≤50 words" (line 210); token-budget cap is ≤50 words/≤400 chars — honored.

## A2 — Read-only enforcement — PASS
- ENFORCED via `tools:` allowlist: `agents/critic.md:16` = `Read, Grep, Glob, Bash` — NO Write, NO Edit, NO Agent. Tool-level enforcement, not prose-only.
- Prose corroborates (defense-in-depth) at lines 27 ("no Write, Edit, or Agent tools") and 227. Note: `Bash` is present, so write capability is technically reachable via shell (`>`/`tee`); the allowlist blocks the Write/Edit tools but not Bash redirection. This is the standard blitz read-only-agent posture (same as reviewer/research-critic) — acceptable; flagged as residual, not a fail.

## A3 — Orchestrator injection guard — N/A (critic is not the orchestrator)

## A4 — Orchestrator routing completeness — N/A (critic is not the orchestrator)

## A5 — Critic detector re-justification (19 vs 20 reconciliation) — PASS
Reconciliation: `skills/_shared/shortcut-taxonomy.md:18-37` defines **20** detectors (rows 1–20). `agents/critic.md:50` "Shortcut taxonomy (19 detectors)" = the 19 deterministic/structural detectors run INLINE in §2.1–2.8. Detector **#20** (audit-FP, "Unverified pattern-match claim") is split out into §2.9 (`agents/critic.md:183-199`) as **advisory (P3), non-blocking**. codebase-audit cites "detector #20" (`skills/codebase-audit/SKILL.md:215,219`). So 19+1(advisory)=20 — counts are consistent, not contradictory. The "8 critic checks" in the LGTM summary (`agents/critic.md:220`) = the 8 reject-checklist sections §2.1–2.8 (2.9 is advisory). All three numbers (19/20/8) are internally coherent.

Per-detector KEEP vs THIN (Opus 4.8 self-correction behavior per system card: strong on type-safety/build-correctness self-checks, weaker on cross-commit git-history forensics and adversarial self-review of its own prior work):

| # | Detector | Class | Rationale (Opus 4.8 behavior) |
|---|---|---|---|
| 1 | Deleted failing tests | KEEP | git `--diff-filter=D` forensic; model won't re-derive deleted files from its own context. Structural. |
| 2 | `--no-verify` bypass | KEEP | reflog/history scan; out-of-context evidence. Structural. |
| 3 | Mock count grows in src/ | KEEP | cross-commit delta vs ratchet; deterministic count, not self-evident to generator. |
| 4 | `as any` / `@ts-ignore` proliferation | THIN-ish→KEEP | Opus 4.8 self-flags `as any` while writing, but the diff-delta gate catches the case where the *author agent* rationalized it. KEEP for adversarial cross-check. |
| 5 | Swallow-and-continue catch | THIN | Opus 4.8 reliably self-corrects empty/log-only catch on review; covered by completeness-gate. Low marginal critic value. |
| 6 | Env-var fallbacks hiding config | KEEP | regex near secret/key/token — security-sensitive, deterministic; model self-correction inconsistent on config-masking. |
| 7 | Hardcoded credentials | KEEP | entropy/secret detection — security floor; never rely on generator self-restraint. Structural. |
| 8 | Commented-out failing assertions | KEEP | diff-grep forensic of *deletion-by-comment*; not visible from model's clean-state view. |
| 9 | `throw new Error('Not implemented')` | THIN | Opus 4.8 self-flags stubs on review; fully covered by completeness-gate. Marginal. |
| 10 | `return {}`/`return []` stubs | THIN | Same — completeness-gate owns it; Opus 4.8 self-corrects placeholder returns. |
| 11 | Hallucinated APIs/symbols | KEEP | tsc + import-resolution = ground truth; LLMs (incl. Opus 4.8) still hallucinate plausible APIs. Highest-value KEEP. |
| 12 | Claiming done on broken build | KEEP | tsc-error delta = objective; author agent's "done" claim is exactly what critic must distrust. |
| 13 | `.skip`/`.only`/`xit` | KEEP | grep on test files; cheap, deterministic, catches silent test-disabling. |
| 14 | Test file renamed away | KEEP | `--diff-filter=R` forensic; invisible to generator's content view. Structural. |
| 15 | Hardcoded localhost/ports | KEEP | env-portability + security; deterministic grep, model self-correction unreliable. |
| 16 | Orphaned files never imported | KEEP | import-graph traversal; structural, not derivable from local edit context. |
| 17 | Infinite correction loop | KEEP | consecutive-fix-failure counter — runtime/state signal a model cannot self-observe. |
| 18 | Destructive SQL outside migration | KEEP | safety floor (DROP/DELETE); never delegate to model judgment. Hook-backed. |
| 19 | `git reset --hard` on dirty tree | KEEP | safety floor; working-tree state external to model context. Hook-backed. |
| 20 | Unverified pattern-match claim (audit FP) | KEEP (advisory) | meta-check on *audit findings* — Opus 4.8 over-trusts its own grep counts; inverse-query/excerpt requirement is exactly the self-blindspot a critic must enforce. Correctly P3-advisory. |

THIN cuts identified (5, 9, 10): all redundant with completeness-gate and within Opus 4.8 self-correction range, but cheap greps with near-zero false-positive cost. Recommend retaining (defense-in-depth) but they could be de-emphasized to advisory if critic latency becomes a concern. No detector is mis-classified or hallucinated; all 20 trace to shortcut-taxonomy rows with provenance citations.

## A6 — DW agent-prompt parity — PASS
Premise check: critic is NOT dispatched via `Workflow`. Workflow pilot status (`skills/_shared/workflow-dispatch.md:80,82`): `codebase-audit` = **WIRED (pilot)** dispatching its 10 pillar agents; `sprint-review` = **candidate (narrow)**, NOT wired. The critic is spawned at sprint-review Phase 3.6 via `Agent()` (`subagent_type: "blitz:critic"`, `skills/sprint-review/references/main.md:711-713`) or via `critic-gemini.sh` (CMC). No `agent()`/Workflow call dispatches the critic today.
- The shared invariant (`workflow-dispatch.md:55-58`) requires any future `agent()` critic dispatch to carry IDENTICAL contract (OUTPUT STYLE snippet + JSON schema). The contract source is centralized and structurally unavoidable: critic-gemini.sh "lifts this agent's body verbatim" (`agents/critic.md:237`), and the sprint-review spawn prompt embeds "Output style: terse-technical per /_shared/terse-output.md" + canonical JSON reply with verdict (`references/main.md:713`). The OUTPUT STYLE snippet lives once in `agents/critic.md:29`; both dispatch paths inherit it from the agent body, so parity is structural (verified), not aspirational.
- sprint-review's documented future Workflow path (`workflow-dispatch.md:82`) specifies "single critic `agent()` + `schema`" — i.e., it would use the SDK `schema:` option that supersedes freeform `jq`, while the OUTPUT STYLE snippet remains mandatory per the §53-58 prompt invariants (sprint-review Invariant 5 blocks PASS if missing). Contract carries identically.

## Final verdict: cohesive
Frontmatter conforms, reply contract matches both canonical sources, read-only enforced at tool-allowlist level, detector counts (19/20/8) fully reconciled with no hallucinated detectors, and critic prompt parity holds across both current dispatch paths (Agent + Gemini-CMC) with the OUTPUT STYLE snippet single-sourced from the agent body.

## Single highest-leverage fix
Change `agents/critic.md:50` heading from "Shortcut taxonomy (19 detectors)" to "Shortcut taxonomy (19 blocking detectors; #20 advisory — §2.9)" so the 19-vs-20 split is self-documenting at the point of first reference, eliminating the recurring reconciliation burden (codebase-audit cites "#20"; reviewers repeatedly flag the apparent 19↔20 mismatch).
