# Research provenance

Shared protocols, agents, and skills cite research documents under `docs/_research/` (for example `2026-05-30_parallel-claude-sessions.md`, `2026-05-28_dynamic-workflows-blitz-adoption.md`, `2026-05-01_autonomous-blitz-quality-efficiency.md`, `2026-04-08_sprint-carryforward-registry.md`, `2026-05-17_worktree-lifecycle.md`, `2026-05-16_github-accessibility-agent-patterns.md`, `2026-06-07_html-output-adoption.md`).

`docs/_research/` is the **scratch output directory of `/blitz:research`** and is gitignored (`.gitignore`), so those documents live only on the machine that produced them. Citations of that form are provenance notes, not links; the markdown link validator does not resolve them.

Research that a shipped protocol depends on belongs in this directory (`docs/research/`, tracked). Two rules:

1. When a protocol change is justified by a research doc, copy that doc here in the same commit and cite the tracked path.
2. `docs/_research/` remains the working directory for `/blitz:research` on consumer projects; the plugin repo commits only what its own protocols cite.

Tracked reviews (this directory's sibling): [docs/reviews/](../reviews/).
