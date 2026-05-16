# Cross-Session Knowledge Protocol

`KNOWLEDGE.md` is a project-local, append-only file at `.cc-sessions/KNOWLEDGE.md` that captures lessons learned across sprints. It is injected into autonomous-loop dispatches (sprint --loop, code-sweep --loop) so subsequent runs benefit from prior failures and successes.

Inspired by GSD-2's KNOWLEDGE.md pattern.

**Why this doc exists**: blitz already has `developer-profile.json` (per-developer preferences) and the activity-feed (per-session log). KNOWLEDGE.md fills the gap: project-local, durable, lesson-oriented memory that survives session compaction and informs future dispatches without re-discovering the same constraints.

---

## 1. File location and shape

`.cc-sessions/KNOWLEDGE.md` — git-ignored by default. One markdown file with append-only entries. Maximum 500 lines (compress past entries when exceeded; see §5).

Each entry has this structure:

```markdown
## <YYYY-MM-DD> · <one-line lesson title>

**Context**: where/when this came up (sprint id, file path, agent role).
**Lesson**: 1–3 sentences. The non-obvious thing learned.
**How to apply**: when future dispatches should consult this lesson.

---
```

Example:

```markdown
## 2026-04-22 · Vue 3 ref unwrap in templates breaks <Suspense>

**Context**: sprint-3, src/pages/Dashboard.vue, frontend-dev wave 2.
**Lesson**: <Suspense> children that use `ref()` directly in template auto-unwrap,
  but only after first resolution. During the pending state, `.value` access is
  required even in template, otherwise undefined errors fire on initial render.
**How to apply**: any sprint-dev story that touches a <Suspense> boundary should
  preflight by checking ref usage in the affected template.

---
```

Entries are paragraphs, not bullet lists. Lessons should be the kind of thing a senior engineer would write in their personal notebook.

---

## 2. When to write an entry

Every autonomous-loop dispatch that hits one of these signals MUST append:

- **Failure recovered after >1 retry** — if a fix that worked is non-obvious, capture it. Future dispatches save the round-trip.
- **Surprising codebase invariant** — "this looks like X but actually means Y." Future dispatches avoid the wrong assumption.
- **Cross-cutting constraint** — "any change to module A must also touch B." Future dispatches discover this in advance.
- **Library/version gotcha** — "framework X v3.2 breaks pattern Y." Captures expensive-to-rediscover knowledge.
- **Architecture decision** — "we picked option B over A because Z." Future dispatches avoid revisiting the decision.

Do NOT write entries for:

- One-off bugs already fixed (the fix is in git; the commit message explains it).
- Style preferences (those go in `developer-profile.json`).
- Per-task progress (that's the activity-feed).

---

## 3. When to read

Autonomous-loop orchestrators (sprint --loop, code-sweep --loop, sprint-dev) MUST inject KNOWLEDGE.md (or its relevant slice) into every dispatch prompt:

```
PRIOR LESSONS (from .cc-sessions/KNOWLEDGE.md, last 30 days):
<paste the last N entries whose 'How to apply' overlaps the current task>
```

Slice strategy: grep entries by topic keywords from the current task. If the task touches `src/stores/auth.ts`, surface entries that mention `auth`, `pinia`, or `stores/`.

Skills that don't run autonomously (one-shot slash commands) MAY read but are not required to.

---

## 4. Writers

| Writer | When | What to capture |
|---|---|---|
| `sprint-dev` (auto-loop) | After successful fix that took >1 attempt | The actual fix + why first attempts failed |
| `sprint-review` | When ratchet metrics surface a structural issue | The pattern, not the specific files |
| `retrospective` | At sprint close | Sprint-level lessons (pace, blockers, surprises) |
| `code-doctor` | When a framework misuse is discovered | The pattern + correct alternative |
| `migrate` | After successful library upgrade | Breaking-change gotcha + workaround |
| `test-writer` | After HARD_SPEC fix succeeded OR per-spec budget exhausted | The HARD_SPEC signals that tripped + the deterministic recipe that resolved (or the failure mode that exhausted the budget). Per `agents/test-writer.md` Spec Fix Mode classifier. |

Other skills MAY write opportunistically.

---

## 5. Pruning (compress when >500 lines)

When KNOWLEDGE.md exceeds 500 lines, the next sprint-review run MUST:

1. Read the file.
2. Group entries by month + topic.
3. For entries older than 90 days that have not been referenced in any dispatch since (check via `grep -l '<entry-title>' .cc-sessions/activity-feed.jsonl`), compress them: keep title + lesson, drop context + how-to-apply.
4. Archive entries older than 365 days to `.cc-sessions/KNOWLEDGE.archive.md`.

Goal: KNOWLEDGE.md stays ≤500 lines and high-signal. Old lessons are not deleted, just archived.

---

## 6. Privacy / portability

KNOWLEDGE.md is `.gitignore`d by default. It contains project-local lessons that may include file paths, internal naming, or constraint reasoning that should not leak to a public repo.

To share lessons across team members, the team should curate a separate `docs/engineering-notes.md` (committed) and copy generalizable lessons there.

---

## 7. Bootstrap

Run once at project setup:

```bash
mkdir -p .cc-sessions
[ -f .cc-sessions/KNOWLEDGE.md ] || cat > .cc-sessions/KNOWLEDGE.md <<'MD'
# Project Knowledge — cross-session lessons learned

Append-only. See skills/_shared/knowledge-protocol.md for format and rules.

---
MD

grep -q '^\.cc-sessions/KNOWLEDGE\.md$' .gitignore 2>/dev/null \
  || echo '.cc-sessions/KNOWLEDGE.md' >> .gitignore
```

`/blitz:bootstrap` and `/blitz:setup` SHOULD run this idempotently.

---

## Related

- [`spawn-protocol.md`](./spawn-protocol.md) §3 — autonomous-loop subagent prompts
- [`session-protocol.md`](./session-protocol.md) — session lifecycle
- [`carry-forward-registry.md`](./carry-forward-registry.md) — durable per-deliverable state (different concern: registry tracks scope; KNOWLEDGE tracks lessons)
- `skills/retrospective/SKILL.md` — primary writer
- `docs/_research/2026-05-01_autonomous-blitz-quality-efficiency.md` §3.2 — research basis
