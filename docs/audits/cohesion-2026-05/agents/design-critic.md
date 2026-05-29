---
unit: agents/design-critic.md
kind: agent
verdict: MODERNIZE
removable_lines: 0
created: 2026-05-28
---

# Audit: agents/design-critic.md

## A. Role Clarity & Overlap

**Role**: Vision-based aesthetic scorer. Reads screenshots, returns scored JSON verdict.

**Scope boundaries — verified**:
- `critic.md` → code/logic adversarial review; no visual scoring. No overlap.
- `research-critic.md` → adversarial claim verification. No overlap.
- `/code-review` (platform-delta.md v2.1.152) → diff-level code quality; no screenshot capability.
- `blitz:ui-audit` skill → structural/accessibility/semantic HTML audit; `design-critic` scores aesthetics, not structure. Distinct.
- `ui-build Phase 5.4` → caller of design-critic; design-critic is the subprocess, not a competing role.

**Verdict**: role is clean. No retiring overlap with any other agent or platform native.

---

## B. Contract Compliance

### JSON Reply Contract (token-budget.md §3)

Agent declares `"Return ONLY this JSON, nothing else"` (line 68). Contract shape at lines 70–92 includes `status`, `summary`, `files_changed`, `issues`, `next_blocked_by`. Missing `metrics` key — acceptable per token-budget.md §3 ("optional but encouraged for agents that touch code"; design-critic is read-only, so omission is correct).

**`summary` field**: defined as `"≤50 words: one-line verdict + headline weakness"` (line 72). Contract compliant.

**prose-reply leakage**: OUTPUT STYLE snippet present verbatim at lines 33–34. No prose leakage path. `"files_changed": []` hardcoded empty — correct for read-only agent.

**`issues[].where`**: `"screenshot:<viewport>"` (line 78). token-budget.md §3 specifies `"path:line"` format. Design-critic legitimately has no file path — screenshot viewport is the correct locator. Minor schema deviation but semantically justified for this agent type.

### Agent Output Contract (spawn-protocol.md)

Not spawner — is a spawnee. Output contract fulfilled: JSON-only reply, no prose. `maxTurns: 15` set (line 18).

### Prompt Boilerplate (agent-prompt-boilerplate.md)

agent-prompt-boilerplate.md targets orchestrator skills that spawn `Agent()`. design-critic is a leaf agent spawned by ui-build; it does not spawn subagents. Boilerplate inapplicable. No gap.

---

## C. Tooling

**Declared tools** (line 16): `Read, Grep, Glob, Bash`

**Correctness**:
- `Read` — needed to read DESIGN.md and heuristics files before scoring.
- `Grep` — needed to search for DESIGN.md or tone tokens.
- `Glob` — needed to locate screenshot files.
- `Bash` — RISK: Bash grants shell execution. Design-critic is declared read-only (line 7: "Read-only — never modifies source files"). Bash is not limited to read-only operations at the tool level.

**`disallowed-tools` enforcement** (platform-delta.md v2.1.152):  
"read-only by construction" is **asserted in prose only** — not enforced declaratively. The agent's system prompt says "You have no Write or Edit tools" (line 31), which is accurate for those specific tools. However `Bash` allows `tee`, `cp`, `curl -o`, `git commit`, etc. No `disallowed-tools` frontmatter is present.

**Recommended fix**: Add `disallowed-tools: [Write, Edit, Bash]` (replace Bash with explicit read-only shell if screenshot reading requires it) OR narrow Bash use to screenshot loading only and document the specific commands.

Actually: screenshots at `/tmp/ui-build-screenshots/*.png` require no Bash — `Read` handles image files per platform. `Glob` finds paths. `Bash` appears unnecessary entirely for this agent's task. Its presence only widens the attack surface.

**Assessment**: Bash is unneeded and should be removed. Read-only claim is currently unenforceable declaratively.

---

## D. Model/Effort Under 4.8

**Current**: `model: sonnet` (line 18). No `effort:` field.

token-budget.md model routing matrix: "Plan-check / critic → sonnet; adversarial review needs reasoning, not depth." Design-critic is a critic variant. `sonnet` is correct.

4.8 honesty gains (platform-delta.md row: `claude-opus-4-8` ~4× less likely to let own code flaws pass unremarked) apply to **code review** fidelity, not visual aesthetic scoring. Design-critic scores screenshots — honesty improvements are irrelevant to this agent's task. Model assignment unchanged.

`effort:` missing from frontmatter. Not a hard failure (agents/ are not skills), but token-budget.md §1 says every agent definition MUST set `model:` explicitly — that requirement is met. `effort:` is a SKILL.md concern; agent frontmatter has no `effort:` field in the schema.

---

## E. Critic Re-Justification (4.8 honesty lens)

design-critic evaluates **visual aesthetics** via screenshot interpretation. 4.8 honesty improvements are about code-flaw self-reporting; they do not affect visual scoring subjectivity. Each detector below is re-examined:

### 2.1 Prompt Adherence
**KEEP.** Structural check: does the page type match the brief? Model-side visual interpretation, but the check is deterministic — "was a landing page produced when a landing page was requested?" Not affected by 4.8 honesty. Low false-negative rate regardless of model version.

### 2.2 Aesthetic Fit
**KEEP.** Checks tone match against DESIGN.md. Deterministic reference: if DESIGN.md says "luxury/refined" and the screenshot uses chunky borders, that's a factual mismatch. 4.8 honesty makes the model less likely to rationalize the mismatch as acceptable. This detector benefits from 4.8 — keep, do not cut.

### 2.3 Visual Polish
**KEEP.** Spacing rhythm, alignment, typography hierarchy. Structural/deterministic signals visible in screenshots. 4.8 does not eliminate AI over-grading of polish; this detector guards against it. Keep.

### 2.4 UX
**KEEP.** Visual affordances, scan-ability, primary action clarity — perceptual, structural questions. 4.8 honesty slightly improves self-reporting of missing affordances but not enough to retire the explicit check. Keep.

### 2.5 Creative Distinction
**KEEP — highest priority detector.** Penalizes generic AI output patterns (Inter/Roboto, purple-on-white gradients, all-rounded, all-centered). This is the detector 4.8 is LEAST likely to fix on its own: the model generating UI is the same model that might rate its own output "distinctive." Explicit third-party scoring is the only check. No reduction warranted. "Score ruthlessly" instruction (line 64) is correct and should stay.

**Net detector verdict**: all 5 dimensions justified. No cuts warranted. 4.8 improves Aesthetic Fit fidelity modestly; all others are structural/perceptual, not honesty-dependent.

---

## F. Not Applicable

design-critic is not an orchestrator. HANDOFF.json / activity-feed injection surface analysis skipped.

---

## Top Edits (leverage-ranked)

1. **Remove `Bash` from `tools:`** — unneeded, breaks read-only enforcement. Add `disallowed-tools: [Write, Edit, Bash]` for declarative lockdown (platform-delta.md v2.1.152).
2. **Update `model: sonnet` → `model: claude-sonnet-4-6`** — explicit model ID per platform-delta.md (model IDs 2026-05-28 row); prevents implicit re-routing when alias changes.
3. **Add `effort: low`** — agent frontmatter convention; design-critic is a leaf scorer, not a multi-step planner. Aligns with token-budget.md §1 "explicit model: in every spawn."
4. **Document `issues[].where` deviation** — add inline comment noting viewport format replaces path:line for screenshot locators, so future reviewers don't flag it as a schema error.
