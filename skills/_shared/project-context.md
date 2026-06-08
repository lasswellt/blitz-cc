# Canonical Project Context Block

Source of truth for the `## Project Context` heading + `detect-stack.sh` invocation. The script is **referenced by 29 of 38 SKILL.md files** (via `detect-stack.sh`); of those, **27 carry the exact canonical Project Context block** below (the other 2 reference the script in body text or a bespoke block — see lists below).

**Why this file exists**: 27 SKILL.md files carry the identical 2-line canonical block below. The block cannot be eliminated — Claude Code's skill loader needs each SKILL.md to declare its own context-injection commands at load time. This file is the **author-time dedup target** (Pattern A from `agent-orchestration.md` §How Orchestrators Use This Fragment): one source-of-truth for the canonical wording; each SKILL.md still carries its own copy, but updates land here first and propagate manually.

**Surfaced by**: 2026-05-16 audit-FP-prevention blind retest (`docs/_research/2026-05-16_audit-agent-fp-prevention.md` test follow-up, Finding 2, Confidence 85, count refined from claimed 30/38 to actual 29/38 via independent falsification).

---

## Canonical block — Project Context with stack detection

For SKILL.md files that need the auto-detected stack profile injected at load time. Paste verbatim immediately after the YAML frontmatter. Tag the block with `<!-- import: from _shared/project-context.md §Canonical block — Project Context with stack detection -->` so future audits recognize the duplication as intentional.

```markdown
## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`
```

Skills currently carrying this exact canonical block (verified 2026-05-16, count = 27 — distinct from the 29 SKILL.md that reference `detect-stack.sh` anywhere):
- `skills/bootstrap` `code-doctor` `code-sweep` `audit` `codebase-map`
- `skills/dep-health` `doc-gen` `fix-issue` `health` `migrate`
- `skills/next` `perf-profile` `quality-metrics` `quick` `refactor`
- `skills/release` `research` `retrospective` `roadmap` `setup`
- `skills/sprint-dev` `sprint-plan` `sprint-review` `test-gen` `ui-audit`
- `skills/ui-build` `browse`

Skills intentionally WITHOUT the block (9 files — verified absent, do NOT add):
- `ask` `compress` `conform` `implement` `review` `ship` `sprint` `todo` — thin orchestrator/routing skills that don't need stack-profile context
- `design-extract` — has its own bespoke `## Project Context` body (describes its own detection logic via `package.json`, `tailwind.config.*`, `vite.config.*`, `tsconfig.json`); do NOT replace with canonical block

When updating the canonical wording: change this file first, then propagate to the 29 SKILL.md files in a single commit. Sprint-review can grep for drift:

```bash
# Detect drift between canonical wording and inline copies
CANONICAL='!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`'
EXPECTED_FILES=29
ACTUAL=$(grep -l 'detect-stack\.sh' skills/*/SKILL.md | wc -l)
[ "$ACTUAL" = "$EXPECTED_FILES" ] || echo "DRIFT: $ACTUAL/$EXPECTED_FILES files carry canonical Project Context block"
```

Note: `grep -l ... | wc -l` (file count), NOT `grep -rn ... | wc -l` (hit count). `health/SKILL.md` has 2 mentions of `detect-stack.sh` — one in the canonical block, one in body text — which would inflate a hit-count to 30.

---

## Related

- [`skill-cross-references.md`](skill-cross-references.md) — analogous dedup target for the Additional Resources block.
- [`agent-orchestration.md`](agent-orchestration.md) — analogous dedup target for recurring Agent() prompt sections.
- `${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh` — the actual script invoked by the canonical block.
