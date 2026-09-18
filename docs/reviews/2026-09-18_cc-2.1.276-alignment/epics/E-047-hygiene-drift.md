---
id: E-047
title: "Hygiene drift"
status: implemented
implemented_in: "2.5.0"
priority: P0
phase: 1
domain: docs
depends_on: []
cc_floor: ""
estimated_stories: 6
source_research_doc: docs/reviews/2026-09-18_cc-2.1.276-alignment/README.md
registry_entries: []
---

# E-047 Hygiene drift

**Why.** Small, cheap, and first: every later epic changes counts, versions, and headings, so the assertions that catch drift must be in place before they land.

## Stories

### S1 README and CI counts
- **Files:** `README.md:61,304,308,434,436`; `.github/workflows/ci.yml:24,27`.
- **Change:** "Agent Catalog (10)" → 11 with an `infra-dev` row; "Builder agents (6)" → 7; "Shared Protocols (12)" → 13 and "share 12 protocol files" → 13; add `html-template-helper.md` to the "Plus:" list; fix the `#shared-protocols-12` anchor. Drop hard-coded counts from CI step names.
- **Acceptance:** `check-count-sync.sh` green after S2.

### S2 Count-sync assertions for headings
- **Files:** `scripts/check-count-sync.sh` §4.
- **Change:** add `assert_prose` rows for README `Agent Catalog \((\d+)\)`, `Builder agents \((\d+)\)`, `Shared Protocols \((\d+)\)`, `Skill Catalog \((\d+)\)`, `Hook Reference \((\d+) scripts, (\d+) events\)`; `hooks/scripts/README.md` `(\d+) scripts wired`; `CLAUDE.md` `(\d+) hook scripts`.
- **Acceptance:** deliberately editing a heading count fails the script.

### S3 Hook README counts
- **Files:** `hooks/scripts/README.md:3,136`.
- **Change:** 36 → 38 (then the E-040 count); reconcile the blocker list on line 136 with line 3.

### S4 Release 2.5.0 stub
- **Files:** `CHANGELOG.md`; `.claude-plugin/plugin.json`, `marketplace.json`; `installer/package.json`, `installer/src/constants.js`, `installer/install.sh`.
- **Change:** move `[Unreleased]` (four review rounds) into `## [2.5.0] — <date> · Claude Code 2.1.276 alignment` when E-040/E-041/E-044 land; until then keep `[Unreleased]` but add the review link (done in this session).

### S5 Tracked research
- **Files:** new `docs/research/` (tracked); citations in `skills/_shared/agent-orchestration.md`, `worktree-lifecycle.md`, `sprint-contracts.md`, `html-template-helper.md`, `CHANGELOG.md`; `hooks/scripts/markdown-link-validate.sh`.
- **Change:** copy the research docs cited from shipped protocol files (`2026-05-30_parallel-claude-sessions.md`, `2026-05-28_dynamic-workflows…`, `2026-06-07_html-output-adoption.md`, `2026-05-01_autonomous-blitz-quality-efficiency.md`, `2026-06-07_1m-context-credits-on-loop.md`, `2026-04-08_sprint-carryforward-registry.md`, `2026-05-17_worktree-lifecycle.md`, `2026-05-16_github-accessibility…`) into `docs/research/`; rewrite citations; keep `docs/_research/` gitignored as scratch. Extend the link validator to `docs/`.
- **Acceptance:** every `docs/_research/` citation in a tracked file resolves to a tracked path.

### S6 Epic numbering map
- **Files:** new `docs/EPICS.md`.
- **Change:** one table mapping the roadmap scheme (E-001…E-047) to the containment scheme (`docs/security/containment/SYNTHESIS.md` Epic 0..N) via `E-SEC-N` aliases. No renumbering of existing docs. Also reconcile `agent-orchestration.md:1116` ("11 slash-only super-orchestrators") with README "At a glance" (9).

## Verification
- `check-count-sync.sh && check-version-sync.sh && markdown-link-validate.sh && validate-plugin-structure.sh`.

## Risks
- None material; this epic is prerequisite hygiene.
