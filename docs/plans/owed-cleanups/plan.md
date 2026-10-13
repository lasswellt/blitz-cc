# Plan: owed-cleanups

## Architecture
Bounded. Two independent tracks: the agents.md split (T-001 move, T-002 retarget citations) and the validator widening (T-003). T-002 depends on T-001 because `check-section-refs.sh` fails between the move and the retarget. Rejected: leaving stub headings at §1.3/§1.5 in agents.md (keeps old citations valid but adds a hop and bytes); moving §1.1 roster instead (smaller and the most read part of the head).

## File map
- `skills/_shared/agents.md` → drop §1.3, §1.5; one-line pointers in §1 intro
- `skills/_shared/agents.reference.md` → add §11 Model routing matrix, §12 Visibility
- 17 skill/agent/json files → citations `agents.md §1.3|§1.5` → `agents.reference.md §11|§12`
- `hooks/scripts/markdown-link-validate.sh` → file list + `CITE_BAD` grep include `docs/`, `CHANGELOG*.md`
- `hooks/tests/markdown-link-validate.bats` → new

## Coverage
n/a: bounded

## Risks
- T-002 touches 18 files, above the 1–3 file sizing; it is one mechanical pattern, verified by a grep_absent and `check-section-refs.sh`.
- `CITE_BAD` widening may flag historical changelog lines; if so, exclude the changelogs from that grep only and say so in the commit.

## Solutions consulted
None (`docs/solutions/` and `docs/plans/BACKLOG.md` absent).

## Research
None (bounded). Inline survey: section byte sizes of agents.md, citation counts, trial run of the widened validator.
