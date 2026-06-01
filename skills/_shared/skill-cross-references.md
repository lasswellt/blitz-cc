# Canonical Skill Cross-References

Source of truth for cross-protocol reference blocks that appear in multiple SKILL.md files.

**Why this file exists**: 6 SKILL.md files (audit, codebase-map, doc-gen, fix-issue, quality-metrics, research) carry an identical 2-line "Additional Resources" block pointing to `spawn-protocol.md` + `terse-output.md`. The block cannot be eliminated — Claude Code's skill loader needs each SKILL.md to declare its own resources for context discovery. This file is the **author-time dedup target** (Pattern A from `agent-prompt-boilerplate.md` §How Orchestrators Use This Fragment): one source-of-truth for the canonical wording; each SKILL.md still carries its own copy, but updates land here first and propagate manually.

**Surfaced by**: 2026-05-16 audit-FP-prevention test (`docs/_research/2026-05-16_audit-agent-fp-prevention.md` test run, Finding 1, Confidence 88).

---

## Canonical block — Spawn + Output Style cross-refs

For SKILL.md files that (a) spawn subagents AND (b) follow the canonical output style. Paste verbatim under the `## Additional Resources` heading. Tag the block with `<!-- import: from _shared/skill-cross-references.md §Canonical block — Spawn + Output Style cross-refs -->` so future audits recognize the duplication as intentional.

```markdown
## Additional Resources
- For subagent spawning (type selection, workload sizing, HEARTBEAT/PARTIAL, waves), see [spawn-protocol.md](/_shared/spawn-protocol.md)
- For output style (terse-technical, preservation rules), see [/_shared/terse-output.md](/_shared/terse-output.md)
```

Skills currently carrying this block (verified 2026-05-16):
- `skills/audit/SKILL.md`
- `skills/codebase-map/SKILL.md`
- `skills/doc-gen/SKILL.md`
- `skills/fix-issue/SKILL.md`
- `skills/quality-metrics/SKILL.md`
- `skills/research/SKILL.md`

When updating the canonical wording: change this file first, then propagate to the 6 SKILL.md files in a single commit. Sprint-review can grep for divergence:

```bash
# Detect drift between canonical wording and inline copies
CANONICAL="For subagent spawning (type selection, workload sizing, HEARTBEAT/PARTIAL, waves), see \[spawn-protocol.md\]"
EXPECTED_FILES=6
ACTUAL=$(grep -rl "$CANONICAL" skills/ --include="SKILL.md" | wc -l)
[ "$ACTUAL" = "$EXPECTED_FILES" ] || echo "DRIFT: $ACTUAL/$EXPECTED_FILES files carry canonical Additional Resources block"
```

---

## Adding new canonical blocks

When the same multi-line cross-reference block appears in ≥4 SKILL.md files, extract it here:

1. Verify the duplication is **verbatim** (`grep -rl '<unique-substring>'`); structurally-similar-but-different blocks belong inline.
2. Add a new `## Canonical block — <name>` section here.
3. Add the `<!-- import: from _shared/skill-cross-references.md §<name> -->` marker comment immediately above each inline copy.
4. List the carrying SKILL.md files explicitly in the canonical section.

**Anti-pattern**: do NOT extract blocks that look similar across skills but have one-line differences. Each SKILL.md's Additional Resources legitimately diverges when the skill has additional skill-specific shared-protocol refs (carry-forward, story-frontmatter, etc.). The dedup target is only for the 2-line spawn+style pair shared across the 6 files above.

---

## Related

- [`agent-prompt-boilerplate.md`](agent-prompt-boilerplate.md) — analogous dedup target for recurring Agent() prompt sections (BUDGET, HEARTBEAT, PARTIAL, CONFIRMATION, Self-Falsification).
- [`spawn-protocol.md`](spawn-protocol.md) — the destination of the canonical block's first line.
- [`terse-output.md`](terse-output.md) — the destination of the canonical block's second line.
