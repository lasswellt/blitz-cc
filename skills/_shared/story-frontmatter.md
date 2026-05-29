# Story Frontmatter Contract

Canonical YAML frontmatter schema for sprint stories. Single source of truth for the producer (`sprint-plan`) and consumers (`sprint-dev`, `sprint-review`, `quick`, gap-closure path).

**Why this doc exists.** The schema previously lived in `skills/sprint-plan/reference.md` Story File Format section, but consumers cited it indirectly. When sprint-plan emitted a field, sprint-dev had no shared spec to validate against; when sprint-dev expected a field, sprint-plan had no shared spec to enforce. This file is the single authoritative contract — both producer and consumer link here.

**Companion protocols:**
- [carry-forward-registry.md](carry-forward-registry.md) — Defines `registry_entries` semantics and the writer contract.
- [state-handoff.md](state-handoff.md) — Defines which file consumes which field, end-to-end across the sprint pipeline.
- [definition-of-done.md](definition-of-done.md) — `done:` and `verify:` fields are executable DoD checks.

---

## File path & naming

```
sprints/sprint-${SPRINT_NUMBER}/stories/S${SPRINT_NUMBER}-${SEQ}-<slug>.md
```

- `${SPRINT_NUMBER}`: integer (1, 2, …); no zero padding on the directory.
- `${SEQ}`: zero-padded 3-digit sequence within the sprint (`001`, `002`, …, `999`). Gap-closure stories use the `G` prefix: `G001`, `G002`, ….
- `<slug>`: kebab-case, ≤ 6 words, derived from `title:`.
- The filename `id` segment (`S${SPRINT_NUMBER}-${SEQ}`) MUST equal the `id:` frontmatter field.

---

## Canonical Schema (standard story)

```yaml
---
# ─── Identity (required) ─────────────────────────────────────────────────
id: "S1-001"                          # Sprint number + zero-padded seq
title: "Create user profile schema"   # Imperative, ≤ 80 chars
epic: "E003"                          # Parent epic ID from epic-registry.json
type: "standard"                      # standard | gap-closure | spike

# ─── Lifecycle (required) ────────────────────────────────────────────────
status: "planned"                     # planned | in-progress | done | blocked | dropped
priority: "high"                      # high | medium | low
points: 3                             # Fibonacci: 1, 2, 3, 5, 8

# ─── Dependencies & assignment (required) ────────────────────────────────
depends_on: []                        # Story ids this blocks on (e.g., ["S1-000"])
assigned_agent: "backend-dev"         # backend-dev | frontend-dev | test-writer | infra-dev

# ─── Scope contract (required) ───────────────────────────────────────────
files:                                # Files this story creates or modifies
  - "src/models/user-profile.ts"
verify:                               # Shell commands; ALL must pass for done
  - "npx tsc --noEmit"
  - "npx vitest run src/schemas/user-profile.test.ts"
done: "UserProfile schema exists, validates correctly, and has passing tests"

# ─── Tracing (required) ──────────────────────────────────────────────────
research_refs: []                     # Format: "<agent-role>:<finding-anchor>"
github_issue: null                    # Populated after issue creation
carry_forward: false                  # true if rolled over from a previous sprint

# ─── Registry link (optional but recommended) ────────────────────────────
registry_entries:                     # Carry-forward registry ids this story advances
  - id: "cf-2026-04-02-modal-consistency"
    delta: 10                         # Integer units toward scope.target

# ─── Acceptance checks (optional; consumed by critic + sprint-review) ────
acceptance_checks:                    # Executable predicates; ALL must pass before PASS
  - type: "grep_present"
    pattern: "export.*useUserProfileStore"
    file: "src/stores/user-profile.ts"
    min: 1
    message: "store must export useUserProfileStore"
  - type: "grep_absent"
    pattern: "TODO|FIXME|Not implemented"
    file: "src/stores/user-profile.ts"
    message: "no placeholders in store"
  - type: "shell"
    command: "npx tsc --noEmit 2>&1 | grep -c 'error TS' || true"
    assert_eq: "0"
    message: "zero type errors"
  - type: "ast_absent"
    node: "TSAsExpression[typeAnnotation.type='TSAnyKeyword']"
    file: "src/stores/user-profile.ts"
    message: "no `as any` in store"

# ─── Design quality (optional; consumed by ui-build Phase 5.4.2) ─────────
design_quality: "skip"                # skip | standard | high — drives design-critic spawning

# ─── Source traceability (gap-closure only) ──────────────────────────────
source_finding:                       # OMIT unless type == "gap-closure"
  report: "sprint-review"             # sprint-review | review | STATE.md
  severity: "high"                    # high | medium | low
  description: "Original finding text"
---
```

---

## Field Contract (Producer / Consumer Matrix)

Required = R, Optional = O, Conditional = C (required iff condition).

| Field | Type | Producer (writer) | Consumer (reader) | R/O |
|---|---|---|---|---|
| `id` | string | sprint-plan Phase 3.2 | sprint-dev (worktree naming, registry write), sprint-review (story status sweep) | R |
| `title` | string | sprint-plan Phase 3.2 | sprint-dev (commit messages), sprint-review (report) | R |
| `epic` | string | sprint-plan Phase 3.2 | sprint-dev (epic-registry lookup), sprint-review (Invariant 3) | R |
| `type` | enum | sprint-plan Phase 3.2 | sprint-dev (assignment), sprint-review (gap-closure handling) | R |
| `status` | enum | sprint-plan (= `planned`); sprint-dev (`in-progress`/`done`/`blocked`); sprint-review (`done`/`dropped`) | All sprint-family skills | R |
| `priority` | enum | sprint-plan Phase 3.2 | sprint-dev (wave ordering tie-break) | R |
| `points` | int | sprint-plan Phase 3.2 | sprint-review (velocity report), quality-metrics | R |
| `depends_on` | string[] | sprint-plan Phase 3.4 (dependency graph) | sprint-dev (wave computation) | R |
| `assigned_agent` | enum | sprint-plan Phase 3.3 (partition logic) | sprint-dev (agent dispatch) | R |
| `files` | string[] | sprint-plan Phase 3.2 | sprint-dev (worktree scope), sprint-review (file-touched audit), code-sweep | R |
| `verify` | string[] | sprint-plan Phase 3.2 | sprint-dev (story-done gate), review | R |
| `done` | string | sprint-plan Phase 3.2 | sprint-review (acceptance) | R |
| `research_refs` | string[] | sprint-plan Phase 3.2 | sprint-dev (read findings during impl), sprint-review (Invariant 1) | R |
| `github_issue` | int\|null | sprint-plan Phase 4.4 (after issue create); never sprint-dev | sprint-review (link in report), ship | R (nullable) |
| `carry_forward` | bool | sprint-plan Phase 0 step 8 (if injected from prior sprint) | sprint-review Phase 3.6 Invariant 4 (cross-check) | R |
| `registry_entries` | object[] | sprint-plan Phase 4.1 (link stories to scope) | sprint-dev Phase 3.2 step 1a (writes `progress` event) | O |
| `registry_entries[*].id` | string | sprint-plan | sprint-dev (registry id validation; hard-fail on unknown) | R if `registry_entries` present |
| `registry_entries[*].delta` | int | sprint-plan | sprint-dev (passed as `delivered.actual` increment) | O (defaults to `len(files)`) |
| `source_finding` | object | sprint-plan `--gaps` mode | sprint-review (gap-closure traceability) | C (required iff `type == "gap-closure"`) |
| `acceptance_checks` | object[] | sprint-plan Phase 3.2 (recommended), or sprint-dev Phase 3 if missing and adding | `agents/critic.md` §2.5, `sprint-review` Phase 3.6 Invariant 7 (executable predicates) | O |
| `acceptance_checks[*].type` | enum | sprint-plan / sprint-dev | critic + sprint-review (dispatcher) | R if `acceptance_checks` present |
| `acceptance_checks[*].message` | string | sprint-plan / sprint-dev | critic (failure surfacing) | R if `acceptance_checks` present |
| `design_quality` | enum | sprint-plan (UI stories only) | `ui-build` Phase 5.4.2 (design-critic spawning) | O (default `skip`) |

**Producer hard rules.** `sprint-plan` is the only skill that creates story files. `sprint-dev` may transition `status` and append a `progress_notes` block to the body, but MUST NOT add or remove frontmatter fields outside `status`, `github_issue`, `progress_notes`, and `acceptance_checks` (sprint-dev MAY add executable checks if absent and the implementation has settled). `sprint-review` may transition `status` to `done` or `dropped` only.

### Acceptance check types

The four `type:` values map to executable predicates. Critic (`agents/critic.md` §2.5) and sprint-review Phase 3.6 Invariant 7 dispatch on `type` and run each in turn. Failure of any check → REJECT verdict.

| Type | Required fields | Optional fields | Predicate |
|---|---|---|---|
| `grep_present` | `pattern`, `file` | `min` (default 1) | `grep -cE '<pattern>' <file>` returns count `≥ min` |
| `grep_absent` | `pattern`, `file` | — | `grep -E '<pattern>' <file>` returns no match (exit 1) |
| `shell` | `command`, `assert_eq` | — | running `<command>` produces stdout exactly equal to `<assert_eq>` (after rstrip) |
| `ast_absent` | `node`, `file` | — | tree-sitter / AST query for `<node>` on `<file>` returns zero matches |

`grep_present` accepts directories in `file:` (recurses with `-r`).

`message:` is required on every entry — it's the human-readable surface text the critic uses when reporting REJECT.

### Validator implementation

Reference implementation lives in `agents/critic.md` §2.5 (consumes the schema) and the spec for sprint-review Phase 3.6 Invariant 7 (`skills/sprint-review/references/main.md`). Skills MAY emit additional check types via prefix `x-<vendor>-<type>` — unknown prefixes are skipped with a warning, not failed.

### Wiring with `verify:`

`verify:` is a story-local pre-commit gate (sprint-dev story-done check). `acceptance_checks:` is a critic-level pre-PASS gate (sprint-review). They overlap intentionally: `verify:` ensures the story implementation passes its own tests; `acceptance_checks:` ensures the artifact contains the right shape (specific symbols exported, no `as any`, etc.). Both must pass for sprint PASS; failure surfaces at different phases.

**Consumer hard rules.** Consumers MUST treat unknown fields as forward-compatible (don't reject), but MUST hard-fail on missing required fields. The `registry_entries` inference fallback (parent-epic pro-rata with `delta: 1`) lives in sprint-dev Phase 3.2 step 1a — see [carry-forward-registry.md](carry-forward-registry.md) §Writers.

---

## Body sections (required for `type: "standard"`)

```markdown
## Description
2-4 sentences explaining what this story delivers and why it matters.

## Acceptance Criteria
1. [ ] Specific, testable criterion one
2. [ ] Specific, testable criterion two

## Implementation Notes
- Key patterns to follow (reference existing code)
- Imports and dependencies needed
- Research findings that inform the approach

## Code Snippets
```typescript
// Starter type definition, function signature, or test skeleton
```

## Dependencies
- Blocks on: S1-000 (reason)
- Blocked by: nothing
```

For `type: "gap-closure"`, replace with:

```markdown
## Finding
<Original finding from the review/gate report>

## Root Cause
<Why this gap exists>

## Fix
<Specific change to make, referencing existing code patterns>

## Verification
<How to confirm the fix addresses the finding>
```

---

## Validation algorithm (sprint-dev Phase 0)

Sprint-dev MUST validate each story file before dispatching to agents. Hard-fail on any of the following:

```bash
# 1. Filename matches id field
basename "$story" .md | cut -d- -f1-2 == $(yq '.id' "$story")

# 2. All required fields present and non-empty
for field in id title epic type status priority points depends_on assigned_agent files verify done research_refs github_issue carry_forward; do
  yq -e ".${field}" "$story" >/dev/null || die "Missing required field: ${field}"
done

# 3. assigned_agent is in the recognized set
yq '.assigned_agent' "$story" =~ ^(backend-dev|frontend-dev|test-writer|infra-dev)$

# 4. depends_on entries reference real stories in this sprint
for dep in $(yq '.depends_on[]' "$story"); do
  test -f "sprints/sprint-${SPRINT}/stories/${dep}-"*.md || die "Dangling depends_on: ${dep}"
done

# 5. registry_entries[*].id values exist in .cc-sessions/carry-forward.jsonl
for rid in $(yq '.registry_entries[].id' "$story"); do
  jq -se --arg id "$rid" 'group_by(.id) | map(max_by(.ts)) | map(select(.id == $id)) | length > 0' \
    .cc-sessions/carry-forward.jsonl || die "Unknown registry id: ${rid}"
done

# 6. source_finding present iff type == gap-closure
[[ "$(yq '.type' "$story")" == "gap-closure" ]] && yq -e '.source_finding' "$story" >/dev/null
```

Validation failures are **BLOCKER** — sprint-dev MUST NOT dispatch any story until all stories in the sprint pass. Report all failures together; do not abort on the first.

---

## Anti-patterns

- **Don't create stories outside sprint-plan.** Manual story creation bypasses the partition logic, dependency graph, and registry linkage. If gap stories are needed mid-sprint, run `/blitz:sprint-plan --gaps`.
- **Don't promote `progress_notes` to frontmatter.** Body section, not metadata.
- **Don't omit `verify:` in favor of "see done field".** Verify is the executable contract; done is the human-readable summary.
- **Don't use `assigned_agent: "any"` or `null`.** The partition is deterministic — pick a role.
- **Don't skip `registry_entries` for stories that contribute to a quantified scope claim.** The inference fallback exists for safety, not as the default path. Sprint-review Invariant 2 will flag epics whose registry entries are stuck at `partial` because no story explicitly claimed delta.

---

## Related protocols

- [/_shared/terse-output.md](terse-output.md) — output-style directive. Story body sections are user-facing; follow LITE intensity.
