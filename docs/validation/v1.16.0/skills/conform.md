---
unit: conform
date: 2026-05-28
validator: claude-sonnet-4-6
verdict: needs-hardening
highest_leverage_fix: "Add `disallowed-tools: Edit, Write, NotebookEdit` (default read-only path has no enforcement; prose Safety Rule 1 is insufficient)"
---

# conform — v1.16.0 Cohesion+DW Validation

## V1 — Frontmatter contract

**PASS**

`hooks/scripts/skill-frontmatter-validate.sh skills/conform/SKILL.md` → `[skill-frontmatter-validate.sh] OK: 1 SKILL.md files conform`

Manual verification:
- `name: conform` ✓
- `description:` 555 chars (≤1024) ✓; third-person ("Conforms blitz runtime artifacts…") ✓
- `model: opus` ✓
- `effort: low` ✓
- `compatibility: ">=2.1.71"` ✓
- `allowed-tools: Read, Write, Edit, Bash, Glob, Grep` ✓ (invokable, field present)

---

## V2 — OUTPUT STYLE snippet

**PASS**

Canonical snippet (between `canonical-output-style-start` / `canonical-output-style-end` markers in `skills/_shared/terse-output.md`) compared byte-for-byte against `skills/conform/SKILL.md` line 13. Shell comparison returned `MATCH`.

`SKILL.md:13` contains the exact one-line directive verbatim.

---

## V3 — Shared-protocol citations resolve

**PASS**

`hooks/scripts/markdown-link-validate.sh skills/conform/SKILL.md` → `markdown-link-validate: OK (397 link(s) checked)`

Links in SKILL.md (sample): `/_shared/verbose-progress.md`, `/_shared/session-protocol.md`, `/_shared/carry-forward-registry.md`, `/_shared/story-frontmatter.md`, `/_shared/state-handoff.md`, `references/main.md` — all resolve per validator.

---

## V4 — Canonical-owner compliance

**N/A**

`conform` is classified as "Router / chainer" in `skills/_shared/agent-routing.md:27`. It does not delegate to any O1–O5 canonical owner and is not itself a canonical owner in the quality-matrix sense. It is a standalone maintenance skill invoked out-of-band (referenced from `sprint-review` only as a recovery suggestion at `skills/sprint-review/SKILL.md:450`). No bidirectional owner contract applies.

---

## V5 — Pipeline I/O composition

**N/A**

`conform` is not a node in the canonical sprint pipeline (`bootstrap → research → roadmap → sprint-plan → sprint-dev → sprint-review → ship`). It is invoked ad-hoc as a recovery/maintenance tool. It consumes pre-existing artifacts (`.cc-sessions/`, `sprints/`, `docs/roadmap/`, `STATE.md`) produced by the normal pipeline but is not a declared producer/consumer in `skills/_shared/state-handoff.md` (grep confirms: no "conform" entry). No I/O composition tracing required.

---

## V6 — Dynamic-Workflows wiring

**N/A**

`conform` is not `codebase-audit` or `research`. DW wiring check does not apply.

---

## V7 — Disallowed-tools gap

**FAIL — needs-hardening**

`conform` is read-only by default; `--fix` is the explicit opt-in for writes. This is exactly the pattern the rubric targets.

Evidence:
- `SKILL.md:4`: `allowed-tools: Read, Write, Edit, Bash, Glob, Grep` — `Write` and `Edit` declared.
- `SKILL.md:265`: Safety Rule 1 — "No writes without `--fix`." — prose-only enforcement.
- No `disallowed-tools:` field present anywhere in `skills/conform/SKILL.md`.

Comparison: `skills/health/SKILL.md:6` declares `disallowed-tools: Edit, Write, NotebookEdit` and is unconditionally read-only. `conform` is read-only by default but write-capable with `--fix`. The comparable precedent for opt-in write skills is `dep-health`, which documents the exclusion explicitly via a `<!-- no-disallowed-tools: ... -->` comment (`dep-health/SKILL.md:11`).

**Gap**: `conform` has neither `disallowed-tools:` enforcement for the default path NOR a `<!-- no-disallowed-tools: ... -->` comment explaining the deliberate omission. The prose Safety Rule is not machine-enforced. A model running without `--fix` still has `Edit` and `Write` in its allowed toolset and could write accidentally.

**Fix**: Either (a) add `disallowed-tools: Edit, Write, NotebookEdit` and rely on the `--fix` argument being parsed before any tool is called (if the skill's Phase 0 argument parsing reliably gates tool use before any edit attempt), or (b) add a `<!-- no-disallowed-tools: ... -->` comment citing why the full toolset must remain available (e.g., "Write/Edit needed by --fix mode; disallowed-tools would break that path"). Option (b) is the lower-friction fix; option (a) is stronger but would require verifying Phase 0 PARSE guards all writes before any edit path is reachable.

---

## V8 — Body-line budget

**PASS**

`wc -l skills/conform/SKILL.md` → 284 total lines. Frontmatter occupies lines 1–10 (second `---` at line 10). Body = lines 11–284 = **274 lines**. Well within the 500-line hard limit and 450-line target.

---

## V9 — Spawn-idiom consistency

**N/A**

`allowed-tools: Read, Write, Edit, Bash, Glob, Grep` — no `TeamCreate` or `SendMessage` declared. `conform` does not spawn agents. No spawn-idiom review required.

---

## Skill verdict

**needs-hardening**

One gap: default read-only path has no machine-enforced `disallowed-tools` constraint and no explanatory comment documenting the deliberate omission. All other checks pass.

## Highest-leverage fix

Add `<!-- no-disallowed-tools: Write/Edit needed by --fix mode; disallowed-tools:[Edit,Write] would break that path — see dep-health/SKILL.md for pattern -->` immediately after the `allowed-tools:` line in the frontmatter, or add `disallowed-tools: Edit, Write, NotebookEdit` if Phase 0 PARSE is confirmed to gate all writes before any edit path is reachable in default (read-only) mode.
