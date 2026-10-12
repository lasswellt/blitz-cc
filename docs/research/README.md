# Research provenance

Earlier releases of the shared protocols, agents and skills cited research documents under `docs/_research/` (for example `2026-05-30_parallel-claude-sessions.md`, `2026-05-28_dynamic-workflows-blitz-adoption.md`, `2026-05-01_autonomous-blitz-quality-efficiency.md`). Those citations have been removed from the shipped text; where a rule survived, the rule now stands on its own.

`docs/_research/` is the **scratch output directory of `/blitz:research`** and is gitignored (`.gitignore`), so documents there live only on the machine that produced them. The tracked set this directory holds today is `2026-10-10_agentic-loop-alignment/` (eight notes behind releases 3.11.0 through 3.13.0).

Research that a shipped protocol depends on belongs in this directory (`docs/research/`, tracked). Two rules:

1. When a protocol change is justified by a research doc, copy that doc here in the same commit and cite the tracked path.
2. `docs/_research/` remains the working directory for `/blitz:research` on consumer projects; the plugin repo commits only what its own protocols cite.

Tracked reviews (this directory's sibling): [docs/reviews/](../reviews/).
