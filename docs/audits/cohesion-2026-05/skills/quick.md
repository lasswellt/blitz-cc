---
unit: skills/quick
kind: skill
verdict: needs-tightening
removable_lines: 10
created: 2026-05-28
---

# Audit: skills/quick/SKILL.md

## A. Identity & Boundaries

**Purpose (one sentence):** Apply a single small ad-hoc change (≤5 files, no new packages, no new architecture) without sprint ceremony.

**Description vs body:** Match. Description's "Do NOT use for multi-file refactors, new features, or anything that needs tests" aligns with body Guardrails. Minor gap: body says "if a matching test file exists, run related tests" (Phase 2 step 2) — description says "anything that needs tests goes through sprint-dev", which is about writing new tests, not running existing ones. Not a contradiction; still clear.

**Overlap inventory:**

| Skill/Agent | Overlap surface | Judgment |
|---|---|---|
| `fix-issue` | Single-issue bug fix, verify, commit | Legitimate layering: `fix-issue` reads a GitHub issue, may span multiple files, runs full test suite; `quick` is intent-driven freeform with hard ≤5-file scope |
| `refactor` | Single-file code changes | Legitimate: `refactor` is scope-unbounded and touches architecture; `quick` explicitly defers to `refactor` for anything bigger |
| `sprint-dev` | Code edits + type-check + commit | Legitimate: `sprint-dev` requires story files, manifest, agents; `quick` is ceremony-free |

No true duplication found.

---

## B. Cohesion

**_shared protocols cited:**
- `_shared/project-context.md` — cited via `<!-- import: -->` marker and `!` shell invocation. ✓ follows; does not restate inline.
- `_shared/package-install-policy.md` — cited in Additional Resources. ✓ follows; does not restate.
- `_shared/terse-output.md` — OUTPUT STYLE snippet present (line 21). ✓ verbatim canonical match.
- `_shared/definition-of-done.md` — referenced in Guardrails (line 76). ✓ live ref, not restated.

**Protocols NOT cited but potentially relevant:**
- `session-protocol.md` — explicitly exempted inline ("No session protocol"). Intentional; documented at line 27–29. Acceptable for a lightweight skill.
- `verbose-progress.md` — explicitly exempted inline ("Verbose progress exemption"); carve-out noted. CLAUDE.md freeform logging still applies per line 29. Acceptable.
- `state-handoff.md` — `quick` is off-pipeline (not in the bootstrap→ship chain); produces no handoff artifact. Correct; no contract needed.
- `story-frontmatter.md` — N/A; `quick` does not produce stories.

**Cross-refs:**
- `/_shared/project-context.md` — live path assumption (not verified by this audit; inferred from consistent use across other skills).
- `/_shared/package-install-policy.md` — same; inferred live.
- `/_shared/definition-of-done.md` — same.

**Invariant 5 (OUTPUT STYLE snippet):** Present verbatim at line 21. ✓

**Pipeline chain:** `quick` is terminal / one-shot. Emits: edited files + optional commit. No downstream skill consumes `quick` output by contract. Chain tracing N/A.

---

## C. Conciseness

**Line count:** 77 lines vs 500-line cap. Well within budget.

**Anti-laziness prose candidates (mark for deletion):**

| Lines | Quoted text | Failure mode it guarded | Deletable? |
|---|---|---|---|
| 26 | `"No session protocol. No activity feed logging. No agents. Just do the work."` | Model previously added session overhead to lightweight skills | Yes — redundant with description's "without the full sprint ceremony" + the absence of those phases. 4.8 honesty means this won't be added back silently. |
| 27–29 | `"**No session protocol…** **Verbose progress exemption:**…"` block | Same as above + model adding verbose checkpoints | Consolidate to one line or delete; the body phases already omit these steps, which is the actual enforcement |
| 63–64 | `"**If verification fails**, fix the issue. Max 3 attempts, then report the failure to the user."` | Model previously looping silently or giving up without reporting | Borderline; 3-attempt cap is concrete and opinionation worth keeping. Keep. |

Estimated **removable lines: 10** (the two bold "No …" lines + the `---` separator between them and Phase 0, tightenable to a single-sentence carve-out note).

**DRY candidates:** None found. Additional Resources pattern (package-install-policy link) is correctly delegated, not restated.

---

## D. Modernization

**Native primitive overlaps (platform-delta.md citations):**

| Claim | Platform delta entry | Verdict | Tradeoff |
|---|---|---|---|
| `npm run type-check` hardcoded in Phase 0 / Phase 2 | N/A — no native substitute | **Keep** | Blitz convention; project-specific; not a platform primitive. |
| `effort: low` + `model: sonnet` | `claude-opus-4-8` fast mode: $10/$50/MTok, 2.5× speed (`fast-mode-2026-02-01 beta`); model IDs current as of 2026-05-28: `claude-sonnet-4-6` (platform-delta.md row 38) | `model: sonnet` resolves to `claude-sonnet-4-6` ✓ — correct alias. Fast mode not applicable: `quick` is CLI-only, fast mode is Claude API-only. **Keep current model/effort.** | Opus fast mode would be over-powered + API-only for a low-effort CLI skill. |
| Prose guard "Max 5 files → warn user" | `disallowed-tools` frontmatter field (v2.1.152, platform-delta.md row 27) | Prose guard is not tool-based; can't be declarative `disallowed-tools`. **Keep prose.** | `disallowed-tools` removes tools from Claude's pool; can't encode file-count logic. |
| Exemption from session-protocol + verbose-progress | Native: no equivalent automatic exemption mechanism | **Keep inline exemption note** (condensed) | Platform doesn't expose per-skill protocol opt-out; prose is the only mechanism. |

**Model/effort sanity:**
- `model: sonnet` → resolves to `claude-sonnet-4-6`. Correct per platform-delta.md row 38.
- `effort: low` — appropriate for a ≤5-file change. ✓
- No workflow trigger risk: `quick` has no "workflow" keyword in prompt body; `effort: low` ≠ `ultracode` (platform-delta.md row 17). ✓

---

## E. Correctness

- `compatibility: ">=2.1.71"` — no known reason this is wrong; no deprecated flags used. **Unverified** (no changelog cross-check performed; inferred safe given no exotic features).
- `npm run type-check` — assumes npm project. Consistent with stack detection in Phase 0 (`detect-stack.sh`). Acceptable.
- `npm run test -- --run <matching-test-file>` — Vitest-style flag. Works for Vitest; breaks for Jest (`--testPathPattern`). Low risk for `quick`'s scope; no fix needed unless project type detection runs first.
- No dead flags, broken paths, or stale version refs found.
- `allowed-tools: Read, Write, Edit, Bash, Glob, Grep` — complete and appropriate for a file-edit skill. No over-permission.
- Single-agent, slash-invoked — `subagents-cannot-spawn-subagents` constraint irrelevant here. Dynamic Workflows (platform-delta.md row 1) don't change the calculus; `quick` correctly stays slash-invoked.
- `argument-hint` field present — correct UX signal for a direct-task skill.

---

## F. Verdict

**`needs-tightening`**

Skill is coherent, well-scoped, and within all caps. No duplication. Two issues:

1. Anti-laziness prose in lines 26–29 is deletable under 4.8 honesty.
2. `npm run test -- --run` is Vitest-specific; minor but worth a conditional note.

### Top Edits (highest leverage)

1. **Delete/compress lines 26–29.** Replace the two bold "No session protocol…" + "Verbose progress exemption:" block with a single one-line note: `<!-- exemptions: session-protocol, verbose-progress — intentional for lightweight scope -->`. Saves ~8 lines of anti-laziness prose that 4.8 no longer needs.

2. **Qualify the test command** in Phase 2 step 2: add `# Vitest` comment and a note that Jest projects use `--testPathPattern` — or defer to `detect-stack.sh` output. 2-line change; prevents silent test-skip on Jest repos.

3. **Add `disallowed-tools` frontmatter** for tools that could widen scope (e.g., `TaskCreate`, `Agent`, `EnterWorktree`): reinforces the "No agents" guarantee declaratively rather than only in prose (platform-delta.md v2.1.152 row 27).
