# Setup Skill — Reference Material

Conflict catalog schema, pattern-matching rules, per-skill behavioral assumptions for `/blitz:setup` skill.

---

## Conflict Catalog Schema

File: `skills/setup/conflict-catalog.json`

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["version", "conflicts"],
  "properties": {
    "version": { "type": "string" },
    "conflicts": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["id", "patterns", "skills", "severity", "description", "fix"],
        "properties": {
          "id": { "type": "string", "description": "Stable identifier for the conflict, e.g., 'no-auto-commit'" },
          "patterns": {
            "type": "array",
            "items": { "type": "string", "description": "Regex patterns (case-insensitive) that match the user's stated rule" }
          },
          "skills": {
            "type": "array",
            "items": { "type": "string", "description": "Blitz skills whose behavior conflicts with this rule" }
          },
          "severity": { "enum": ["HIGH", "MEDIUM", "LOW"] },
          "description": { "type": "string", "description": "One-line summary of the conflict" },
          "fix": { "type": "string", "description": "Remediation suggestion shown to the user" }
        }
      }
    }
  }
}
```

---

## Pattern-Matching Rules

1. All patterns are **case-insensitive** regex matches against CLAUDE.md lines.
2. Anchor patterns to word boundaries where possible to reduce false positives (`\bnever\b` vs `never`).
3. Test each pattern against full CLAUDE.md content; multiple patterns per conflict ID are OR'd.
4. Line matching ANY pattern for conflict triggers finding.
5. Comments (`<!-- -->`) and code fences should be stripped before matching to avoid flagging documentation about blitz itself.

---

## Behavioral Assumptions in Blitz Skills

Reference table for what each skill does that may conflict with user's CLAUDE.md rules:

| Skill | Behavior | Severity potential |
|---|---|---|
| `sprint-dev` | Auto-commits per story: `feat(sprint-N/<role>): SN-XXX <title>` | HIGH |
| `sprint-dev` | Auto-pushes at wave boundaries and sprint completion | HIGH |
| `sprint-dev` | Creates worktree branches: `sprint-N/backend`, etc. | MEDIUM |
| `code-sweep --loop` | Auto-commits each fix: `sweep(<check_id>): <description>` | HIGH |
| `code-sweep --loop` | Auto-pushes after fix commit | HIGH |
| `release --publish` | Pushes branch + tag, creates GitHub release | HIGH |
| `fix-issue` | Commits fix using conventional commit format on a feature branch | MEDIUM |
| `sprint-review` | Auto-fixes common lint/type failures | MEDIUM |
| `ship` | Chains sprint-review → review --only completeness → release | HIGH |
| All skills | Default to `npm run test`, `npm run build`, `npm run lint` | MEDIUM (pnpm/bun/yarn users) |
| All orchestrators | Use `opus` model | LOW (cost-sensitive users) |
| Hooks | `pre-edit-guard.sh` blocks `.env*`, lock files | MEDIUM |
| `sprint-dev` | Commit format `feat(sprint-N/<role>): SN-XXX <title>` (no ticket refs) | MEDIUM |

---

## Remediation Strategies (for v1.4 `--fix` mode)

Not implemented in MVP. When `--fix` lands, each catalog entry's `fix` field will map to:
- Writing overrides to `.blitz.json` (e.g., `autoCommit: false`)
- Toggling skill invocation modes (`sprint-dev --mode checkpoint` instead of autonomous)
- Updating `~/.claude/settings.json` permissions

For MVP, `fix` field is advisory text only.

---

## Extending the Catalog

To add a new conflict pattern:

1. Add new object to `assets/conflict-catalog.json` following schema above.
2. Pick stable `id` (no spaces, lowercase-hyphenated).
3. Provide 2-4 regex patterns matching common phrasings of user rule.
4. List blitz skills affected.
5. Set severity based on behavior table above.
6. Write clear `fix` string telling user what override or flag resolves conflict.
7. If new conflict references skill behavior not documented above, also update behavioral assumptions table.

---

## Test Cases for Catalog Maintenance

When modifying catalog, run these test phrases against regex patterns:

| Phrase | Expected conflict id |
|---|---|
| "Never auto-commit" | no-auto-commit |
| "Always show the diff before committing" | no-auto-commit |
| "Don't push to remote without asking" | no-auto-push |
| "Never run npm scripts without asking" | no-unprompted-tests |
| "Use feature/<ticket>-<desc> branch naming" | custom-branch-naming |
| "Commits must reference Jira tickets" | custom-commit-format |
| "Always create a PR, never merge to main directly" | always-pr |
| "Never auto-fix code; only report findings" | no-auto-fix |
| "Use pnpm" | non-npm-package-manager |
| "Only use haiku to control costs" | model-preference |

CLAUDE.md containing all 10 phrases should produce 10 findings when scanned.
