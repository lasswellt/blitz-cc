# Skill Validation: codebase-audit — v1.16.0

**Validated**: 2026-05-28  
**Files**: `skills/codebase-audit/SKILL.md`, `skills/codebase-audit/references/main.md`  
**Validator model**: claude-sonnet-4-6

---

## V1 — Frontmatter Contract

**Verdict: PASS**

Script output: `hooks/scripts/skill-frontmatter-validate.sh skills/codebase-audit/SKILL.md` → `[skill-frontmatter-validate.sh] OK: 1 SKILL.md files conform`

Manual confirmation:
- `name: codebase-audit` — present (SKILL.md:2)
- `description:` — 278 chars (≤1024). Third-person ("Comprehensive 5-pillar code-quality audit…"). (SKILL.md:3)
- `model: opus` — present (SKILL.md:5)
- `effort: high` — present (SKILL.md:6)
- `compatibility: ">=2.1.71"` — present (SKILL.md:7)
- `allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebSearch, ToolSearch, Agent` — present (SKILL.md:4)

All fields valid; script confirms conformance.

---

## V2 — OUTPUT STYLE Snippet (Invariant 5)

**Verdict: PASS** (SKILL.md); **note** on references/main.md (non-blocking)

SKILL.md line 23 byte-compared against canonical (`skills/_shared/terse-output.md` §Canonical Snippet): **exact match**.

```
SKILL.md:23 == canonical → MATCH
```

`references/main.md` lines 79-83 contain the OUTPUT STYLE text inside an agent prompt template (fenced code block), but it is word-wrapped across 5 lines rather than the canonical single line. `terse-output.md` scope is "Every SKILL.md and every `agents/*.md`" — `references/main.md` is neither; the validator does not check it. However, agents receiving the wrapped prompt see a line-broken variant rather than the canonical one-liner. This is a stylistic concern only (content is identical; `skill-frontmatter-validate.sh` does not flag it) and is advisory.

---

## V3 — Shared-Protocol Citations Resolve

**Verdict: PASS**

`hooks/scripts/markdown-link-validate.sh skills/codebase-audit/SKILL.md` → `markdown-link-validate: OK (397 link(s) checked)`

All `/_shared/` citations verified to exist on disk:

| Citation | File | Status |
|---|---|---|
| `/_shared/session-protocol.md` | `skills/_shared/session-protocol.md` | OK |
| `/_shared/verbose-progress.md` | `skills/_shared/verbose-progress.md` | OK |
| `/_shared/terse-output.md` | `skills/_shared/terse-output.md` | OK |
| `/_shared/spawn-protocol.md` | `skills/_shared/spawn-protocol.md` | OK |
| `/_shared/workflow-dispatch.md` | `skills/_shared/workflow-dispatch.md` | OK |
| `/_shared/carry-forward-registry.md` | `skills/_shared/carry-forward-registry.md` | OK |
| `/_shared/context-management.md` | `skills/_shared/context-management.md` | OK |

`references/main.md` links also confirmed clean by the same link-validator run.

---

## V4 — Canonical-Owner Compliance

**Verdict: PASS**

`codebase-audit` is an **owner** of the audit→roadmap pipeline hand-off (it produces `audit-YYYYMMDD-epics.md` with `scope:` frontmatter). Bidirectional check:

- **Codebase-audit cites roadmap** as consumer: Phase 3.3a (`skills/codebase-audit/SKILL.md:360`) explicitly instructs: "Every `audit-YYYYMMDD-epics.md` file MUST open with a `scope:` YAML frontmatter block … canonical contract for `/blitz:roadmap extend` ingestion".
- **Roadmap cites codebase-audit** as producer: `skills/roadmap/SKILL.md:76` reads "see `skills/codebase-audit/SKILL.md` Phase 3.3a for the writer contract" and line 80 has an explicit block message naming `/blitz:codebase-audit`.

Bidirectional citation confirmed. No restated logic — roadmap owns the `extend` ingestion path; codebase-audit only defines its output format and cross-references roadmap for ingestion. PASS.

---

## V5 — Pipeline I/O Composition

**Verdict: PASS** (with gap noted)

Traced chain: `codebase-audit` → `docs/audits/audit-YYYYMMDD-epics.md` → `roadmap extend`

- **Producer output** (SKILL.md Phase 3.3a): writes `audit-YYYYMMDD-epics.md` with `scope:` YAML frontmatter block; schema per Phase 3.3 template (id, unit, target, description, acceptance fields). Also writes `audit-YYYYMMDD-index.json` (not consumed by roadmap) and `audit-YYYYMMDD.md` (not consumed by roadmap).
- **Consumer input** (roadmap SKILL.md:73-76): globs `**/docs/audits/*-epics.md`, reads `scope:` block per same protocol as research docs, and ingests via Phase 1.1.5. Explicitly rejects the full report and index — only `-epics.md` files are consumed. Confirmed at `skills/roadmap/SKILL.md:76`.
- **Composition gap**: `skills/_shared/state-handoff.md` has no `codebase-audit` section — the pipeline hand-off (codebase-audit → roadmap) is undocumented in the canonical table. The chain is real and functional (documented bidirectionally in the two SKILL.md files), but state-handoff.md §Pipeline Handoff Table is incomplete. This is a **protocol doc gap**, not a functional defect.

---

## V6 — Dynamic-Workflows Wiring

**Verdict: PASS**

Full V6 check (DW-WIRED pilot skill):

**1. Dispatch gate (Phase 1.0, SKILL.md:106-111)**

```bash
case "${BLITZ_DISPATCH:-auto}" in
  agent)    USE_WORKFLOW=false ;;
  workflow) USE_WORKFLOW=true ;;    # force; error if Workflow tool absent
  *)        USE_WORKFLOW=maybe ;;   # auto: use Workflow iff tool present
esac
```

Three-way gate matches `workflow-dispatch.md` contract: `auto` → capability-test, `workflow` → force+error-if-absent, `agent` → legacy path. `USE_WORKFLOW=maybe` as the "auto" sentinel is intentional — the narrative (SKILL.md:114) resolves it: "`USE_WORKFLOW` truthy AND `Workflow` tool available → §1.1-W". In bash, `maybe` is non-empty (truthy) and the secondary tool-presence check gates actual dispatch. Correct.

**2. Workflow + Agent() paths produce identical findings files** — SKILL.md:103 states "Two dispatch paths produce identical findings files under `${AUDIT_RUN}/findings/`". Both paths use the same roster table (SKILL.md:163-172) with identical output paths. PASS.

**3. Hybrid boundary** — SKILL.md:117 explicitly: "All filesystem I/O (Phase 0 inventory, Phase 2 report, ratchet.json, activity-feed) stays in this skill's main-thread Bash — the `Workflow` script touches none of it." The JS script body (SKILL.md:124-129) contains no filesystem calls, no `Date.now()`, no `Math.random()`, no `.cc-sessions` writes. PASS.

**4. Fallback** — SKILL.md:115: "else, or on ANY `Workflow` failure → fall back to §1.1 (`Agent()` path). Never hard-fail." Matches contract. PASS.

**5. Activity-feed dispatch logging** — SKILL.md:116: "Log the chosen path to the activity-feed: `detail.dispatch: "workflow"|"agent"`." PASS.

**6. agent() prompts carry OUTPUT STYLE + schema + opts.model** — SKILL.md:127: `agent(a.prompt, { label: a.name, phase: 'Audit', model: 'sonnet', schema: args.findingsSchema })`. Model explicit (prevents `[1m]` inheritance per SKILL.md:132). Schema present. SKILL.md:131 mandates OUTPUT STYLE in each `a.prompt`. PASS.

**Minor observation**: `USE_WORKFLOW=maybe` is an unconventional sentinel for a boolean flag. A comment clarifying "truthy; actual availability checked at call site" would prevent future confusion, but this is advisory only.

---

## V7 — Disallowed-Tools Gap

**Verdict: N/A** (not read-only-by-construction)

`codebase-audit` writes findings files, audit reports, epic proposals, and index JSON (`docs/audits/`, `${AUDIT_RUN}/`). It is explicitly a write-heavy skill. No `disallowed-tools` declaration is needed. SKILL.md:4 declares `allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebSearch, ToolSearch, Agent` — all appropriate. The read-only hardening check (like `health`) does not apply.

---

## V8 — Body-Line Budget

**Verdict: PASS**

Body line count (from second `---` fence to EOF): **466 lines**.

Hard limit: 500. Target: 450. Count: 466 — within hard limit, 16 lines over soft target. No violation.

Command used: `awk '/^---$/{count++; if(count==2){start=NR; next}} start && NR>start{print}' SKILL.md | wc -l` → 466.

---

## V9 — Spawn-Idiom Consistency

**Verdict: N/A** (TeamCreate/SendMessage not declared)

`allowed-tools` (SKILL.md:4) does not include `TeamCreate` or `SendMessage`. Skill uses the canonical `Agent` tool for subagent spawning per spawn-protocol.md. No blessed-exception check required. PASS/N/A.

---

## Skill Verdict

**cohesive**

All 9 checks pass (V7 and V9 are N/A by construction). No contract violations, no delegation breaks, no DW wiring defects. One advisory (state-handoff.md protocol doc gap for the codebase-audit → roadmap chain) and one stylistic note (OUTPUT STYLE word-wrapped in references/main.md agent template).

---

## Highest-Leverage Fix

Add a `codebase-audit` section to `skills/_shared/state-handoff.md` §Pipeline Handoff Table documenting the producer/consumer chain (`codebase-audit` → `docs/audits/audit-YYYYMMDD-epics.md` → `roadmap extend`) so the pipeline contract is canonical and verifiable by the integration-check hook alongside the sprint pipeline entries.
