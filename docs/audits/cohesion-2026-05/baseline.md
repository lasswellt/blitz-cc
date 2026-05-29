---
title: Pre-audit baseline
created: 2026-05-28
git: main @ 3d35e39 (tag v1.15.0)
---

# Baseline (captured before audit; proposed changes check against this)

## Inventory
- skills: 39 · agents: 10 · shared protocols: 28 · hook scripts: 36

## Validators
- `skill-frontmatter-validate.sh` — OK: 39 SKILL.md conform
- `agent-frontmatter-validate.sh` — OK: 10 agent .md conform
- `scripts/validate-plugin-structure.sh` — FAIL: 3 errors, 1 warning / 279 checks:
  - WARN `skills/roadmap/SKILL.md` exceeds 500 lines (508)
  - FAIL hooks.json "missing script" ×2 — validator mis-parses `... skill-frontmatter-validate.sh --all` / `agent-frontmatter-validate.sh --all` (the `--all` arg is read as part of the path). Scripts exist + pass. Validator-side false positive.
  - FAIL `hooks/scripts/_lib/common.sh is not executable` — sourced, not executed; non-exec is correct. Validator over-broad.

All four are pre-existing; none introduced by this audit. Track separately from audit findings.

## Note
`scope:` quantified-claim fields in this audit's outputs are remediation targets, not baselines.
