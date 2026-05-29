---
name: audit
description: "Consolidated recall-biased deep audit (pre-release). Canonical entry point for the 5-pillar codebase audit (Architecture/Performance/Security/Maintainability/Robustness) hardened with both detection lanes from the shared check-registry, Multi-Review aggregation (≥2 independent agents → high confidence), an adversarial FP-verify panel (re-read + refute + majority vote), and recall instrumentation (coverage_boundary). Reports everything ranked (--min-confidence low). Forwards to the codebase-audit engine. Use for 'audit codebase', 'full code review', 'comprehensive quality audit', 'find tech debt', 'security audit', or before a major release."
argument-hint: "[scope] [--min-confidence low|high] [--dual] -- recall-biased 5-pillar deep audit (aggregation + FP-verify panel + deterministic lane + coverage boundary); forwards to codebase-audit engine; --dual adds cross-model agreers for the security pillar"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebSearch, ToolSearch, Agent
disable-model-invocation: false
model: opus
effort: high
compatibility: ">=2.1.71"
---


OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.

# Audit — Consolidated Recall Deep Audit

The pre-release deep audit. **Recall-biased**: runs rarely, so a missed bug is expensive — it reports everything ranked, dropping only disproven findings. Companion: [`/blitz:review`](../review/SKILL.md) is the per-change precision gate that suppresses the low-confidence findings audit re-surfaces.

This is the canonical name for the audit; the engine is **codebase-audit** ([SKILL.md](../codebase-audit/SKILL.md)), which holds the 5-pillar fan-out plus the recall-hardening phases (1.D deterministic lane, 2.0 Multi-Review aggregation, 2.5 adversarial FP-verify panel, 3.5 coverage_boundary). Checks are selected from [`/_shared/check-registry.json`](/_shared/check-registry.json) (`consolidated_target ∈ {audit, both}`).

**Session registration**: follow [session-protocol.md](/_shared/session-protocol.md) §Session Registration before any other work.

**Verbose progress is mandatory.** Follow [verbose-progress.md](/_shared/verbose-progress.md). Print `[audit]` status at every phase + dispatch. Log `skill_start`/`skill_complete` to the activity feed.

## Flag Parsing

- `[scope]` — path or `all` (default: full repo).
- `--min-confidence {low|high}` — report band (default `low` ≥0.0: report everything ranked by `effective_confidence`; recall bias). Refuted findings (`fp_factor == 0`) are always dropped.
- `--dual` — set `BLITZ_DUAL_CRITIC=1` (cross-model agreers + critic for the security pillar; recommended pre-release per the self-critique paradox).

## Execution

Invoke the **codebase-audit** skill with the parsed context. It runs Phase 0 (inventory) → Phase 1.0 dispatch gate (Workflow|Agent per [workflow-dispatch.md](/_shared/workflow-dispatch.md)) → Phase 1.D + 1.S pillar agents → Phase 2.0 aggregation → Phase 2.5 FP-verify panel → Phase 2.6 confidence filter → Phase 3 scorecard + roadmap epics → Phase 3.5 coverage_boundary → Phase 4 report. `BLITZ_DUAL_CRITIC=1` routes the critic cross-model.

## Output

- 5-pillar health scorecard + findings ranked by `effective_confidence` (high = ≥2-agreer + FP-verified).
- `coverage_boundary` — what was NOT checked (honest recall limit).
- Roadmap epic proposals (`scope:` frontmatter) + `index.json` for `/blitz:roadmap extend`.
