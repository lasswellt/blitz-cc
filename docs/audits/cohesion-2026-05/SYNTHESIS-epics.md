---
scope:
  - id: cf-2026-05-28-e-tool-1
    unit: epics
    target: 1
    description: |
      Fix the cohesion-audit's own xref resolver to understand the /_shared/ plugin-root
      convention + relative-link bases, so a re-run does not fabricate phantom dead-refs.
      NOT suite link edits (suite has 0 broken links). Reframed from §4.1 false-positive.
    acceptance:
      - shell: "bash hooks/scripts/markdown-link-validate.sh $(ls skills/*/SKILL.md agents/*.md skills/_shared/*.md skills/*/references/*.md) 2>&1 | grep -q 'OK'"
  - id: cf-2026-05-28-e-dup-1
    unit: epics
    target: 1
    description: |
      Changelog single-owner (O1/O5): skills/release owns commit-type map + Keep-a-Changelog
      emit; doc-gen `changelog` mode + ship Phase 2 delegate. Blast: doc-gen, ship, release.
    acceptance:
      - grep_absent: 'Keep a Changelog'
      - grep_present:
          pattern: 'release'
          min: 1
  - id: cf-2026-05-28-e-dup-2
    unit: epics
    target: 1
    description: |
      Anti-mock + wiring single-owner (O2/O3): completeness-gate owns placeholder scan;
      sprint-review 1.5.1 + code-sweep cite it; integration-check owns wiring (2.11/2.12 move
      out of completeness-gate). Blast: HIGH — quality-gate core; preserve Invariant 7.
    acceptance:
      - shell: "! grep -rn \"return {}\\|throw new Error('Not implemented')\" skills/sprint-review skills/code-sweep | grep -qv completeness-gate"
  - id: cf-2026-05-28-e-dup-3
    unit: epics
    target: 1
    description: |
      Routing-table single-owner (O4): agents/orchestrator.md §2 canonical; skills/ask Phase 1
      derives/cites. Eliminate independent maintenance surface. Blast: low.
    acceptance:
      - shell: "test $(grep -c 'Primary Skill\\|Intent Keywords' skills/ask/SKILL.md) -le 1"
  - id: cf-2026-05-28-e-dry-1
    unit: epics
    target: 1
    description: |
      sprint-dev DRY collapse (O12/O13/O14): both lock blocks -> 1-line session-protocol.md
      cites; drop carry-forward restatement; move per-wave caps to spawn-protocol.md §Heavy.
      Blast: low-medium — sprint-dev load-bearing; verify lock behavior unchanged.
    acceptance:
      - grep_absent: 'CHECK→ACQUIRE'
  - id: cf-2026-05-28-e-48-1
    unit: epics
    target: 1
    description: |
      token-budget.md model-string + fast-mode update: matrix -> claude-haiku-4-5 /
      claude-sonnet-4-6 / claude-opus-4-8; add fast-mode cost column; document effort
      low-vs-high split; note ultracode multi-workflow budget; re-affirm 60/35/5.
      Blast: medium — every model: field resolves to a current ID.
    acceptance:
      - grep_absent: 'opus-4\.7'
      - grep_present:
          pattern: 'claude-opus-4-8'
          min: 1
  - id: cf-2026-05-28-e-48-2
    unit: epics
    target: 1
    description: |
      Injection guards (§5.4): add `| .[0:200]` field caps to orchestrator.md jq snippets that
      render HANDOFF.json + activity-feed message/summary. Blast: trivial.
    acceptance:
      - grep_present:
          pattern: '0:200'
          min: 1
  - id: cf-2026-05-28-e-48-3
    unit: epics
    target: 1
    description: |
      disallowed-tools for genuinely read-only audit skills (dep-health, codebase-audit,
      integration-check, health, ui-audit, design-extract); bump compatibility >=2.1.152.
      Do NOT add to semantic-guard skills (refuted). Blast: low — additive frontmatter.
    acceptance:
      - grep_present:
          pattern: 'disallowed-tools'
          min: 1
  - id: cf-2026-05-28-e-omc-1
    unit: epics
    target: 1
    description: |
      Honesty-aware prose TRIM (§5.5), RUNS LAST. Compress old-model-compensation prose to
      1-line invariants; DELETE no detector/hook/structural guard. git tag pre-honesty-trim
      first. Blast: HIGH surface / low logic — readability only; revert = git revert.
    acceptance:
      - shell: "test $(ls hooks/scripts/*.sh | wc -l) -eq 36"
      - grep_present:
          pattern: 'ANTI-MOCK|BANNED:|never skip|report ALL'
          min: 1
  - id: cf-2026-05-28-r-1-security-review
    unit: epics
    target: 1
    description: |
      RESOLVE-THEN-DECIDE (O8): read security-review SKILL.md vs codebase-audit security
      pillars; if true dup, file a retire/merge epic. Spike — no code change until read.
    acceptance:
      - shell: "test -f docs/audits/cohesion-2026-05/R-1-security-review-decision.md"
  - id: cf-2026-05-28-r-2-learning-store
    unit: epics
    target: 1
    description: |
      RESOLVE-THEN-DECIDE (O16/O17): coordinate developer-profile.json <-> KNOWLEDGE.md
      ownership + ratchet-vs-quality-metrics metric boundary. Design note before code.
    acceptance:
      - shell: "test -f docs/audits/cohesion-2026-05/R-2-learning-store-decision.md"
---

# Cohesion Audit — Remediation Epics (ingestion artifact)

Machine-readable `scope:` contract for `/blitz:roadmap extend`, derived from
[`SYNTHESIS.md`](SYNTHESIS.md) §6. One entry per VALID epic. Ordering + blast notes
live in SYNTHESIS §6; dependency rationale: E-TOOL-1 first, E-OMC-1 LAST.

**Cancelled (phantom — NOT ingested):** E-XREF-1, E-XREF-2 — targeted non-existent
dead-refs (xref-resolver false positive; suite has 0 broken links). See SYNTHESIS §4.1.

| Epic | Concern | Blast | Order |
|---|---|---|---|
| E-TOOL-1 | fix audit xref resolver | tooling | pre-req |
| E-DUP-1 | changelog single-owner | doc-gen/ship/release | parallel |
| E-DUP-2 | anti-mock + wiring owner | quality-gate core | parallel (HIGH) |
| E-DUP-3 | routing-table owner | orchestrator/ask | parallel |
| E-DRY-1 | sprint-dev DRY collapse | sprint-dev | parallel |
| E-48-1 | model strings + fast-mode | all model: fields | parallel |
| E-48-2 | injection guards | orchestrator.md | parallel |
| E-48-3 | disallowed-tools read-only | 6 audit skills | parallel |
| E-OMC-1 | honesty-aware prose trim | ~25 skills + 6 agents | LAST |
| R-1 | security-review dup? | spike | resolve-then-decide |
| R-2 | learning-store ownership | spike | resolve-then-decide |
