# output reference

Detail split out of [output.md](output.md) so the contract every skill loads stays small. The compression rule, its intensity levels, and the preservation boundary that never compresses lives there; everything below is loaded on demand.

---

## Canonical Exemptions List

Authoritative — overrides any per-skill exemption declarations. Skills MUST NOT redefine the exemption set in their SKILL.md frontmatter; if a skill thinks it needs a new exemption category, propose it here first.

Sections in any agent or skill output that ALWAYS use full-prose (LITE intensity) regardless of the active intensity level:

| Section type | Examples | Why exempt |
|---|---|---|
| **Safety rules** | "Never run X against prod", "Never bypass Y", security warnings, credential-handling guidance | Compressed safety language has caused real incidents (e.g., a "use --no-verify only when needed" terse line that dropped the only-when-needed condition). |
| **Root cause analyses** | Bug post-mortems, "why did this break", architectural decision records | The reasoning chain is the value; compression loses it. |
| **Risks and trade-offs** | Research doc §Risks, Open Questions, `plan.md` §Risks, ADR §Consequences | Same reason as root cause — the qualifier matters. |
| **Destructive-op confirmations** | `rm -rf`, `git push --force`, `drop table`, `kubectl delete`, package uninstall | Irreversibility demands a full sentence + reasoning chain. The user's "yes" is binding. |
| **First-time onboarding** | README quickstart sections, `onboard` output to a fresh user, error-message remediation | New users need full sentences; terse output fails the "reader picks up cold" test. |
| **Migration notices** | Breaking-change descriptions in CHANGELOG, deprecation warnings, upgrade-required prompts | Users skim; full prose ensures the action is unmissable. |

**How to apply.** When a skill's output crosses an exemption category, that section drops to LITE intensity for the duration of the section. Resume the active intensity at the next non-exempt section. Mark the boundary explicitly if the section is more than ~3 lines:

```markdown
<!-- exempt: safety -->
This operation is destructive. It will delete the production database
backup. There is no automated rollback. Type the database name to confirm.
<!-- /exempt -->
```

**Audit.** `check` grep-checks for `<!-- exempt: ` markers in agent prompt templates and skill outputs; missing markers around safety/destructive content is a WARN, present-but-misused markers are a BLOCKER.

---

## Examples

| Verbose (before) | Terse (after) |
|---|---|
| "I'd be happy to take a look at that bug. Let me search the codebase and find where the issue might be." | "Investigating bug. Searching codebase." |
| "It seems like the problem is basically that the cache isn't being invalidated when the user updates their profile." | "Cache not invalidated on profile update." |
| "I've completed the refactor. Here's a summary of what I changed: I updated three files to use the new API, removed the deprecated helper, and added tests." | "Refactor done. Three files migrated to new API, deprecated helper removed, tests added." |
| "Sure! In order to fix this, we should probably just add a null check." | "Add null check." |

---

## Integration points in blitz

1. **Spawn prompts** — every Agent() prompt template carries the single `Output:` line from §Enforcement. See [agents.md](/_shared/agents.md).
2. **SKILL.md Additional Resources** — skills that produce user-facing output should list this file alongside [sessions.md](/_shared/sessions.md).
3. **Output style** — `output-styles/terse-technical.md` is the platform-level enforcement; this file is the reference spec it summarizes.

## Credit

The directive structure, intensity tiers, and preservation-rule framing are adapted from caveman-mode (JuliusBrussee/caveman, MIT). The integration surface (spawn-prompt line, SKILL.md references, forced output style) is blitz-specific.

---

# Verbose Progress Protocol

All skills MUST emit verbose progress output so the user always knows what is happening. This protocol defines the standard format for progress reporting; the cross-instance activity feed that accompanies it is specified in [sessions.md](/_shared/sessions.md).

---

## Activity Feed (Cross-Instance)

Skills append loop/skill-level events (`skill_start`, `decision`, `verification`, `skill_end`) to `.cc-sessions/activity-feed.jsonl` so other Claude Code instances can see what is happening. The line schema, `session` id rule, and required event set live in [sessions.md](/_shared/sessions.md); do not restate them here. Per-edit logging is OpenTelemetry's job, not the feed's.

## Integration with Session Protocol

This protocol extends (not replaces) [sessions.md](/_shared/sessions.md): session registration writes `skill_start`, session cleanup writes `skill_end`, and conflict detection also reads the feed for recent context. All skills that reference sessions.md should also follow this verbose-progress protocol.

## Related protocols

- [sessions.md](/_shared/sessions.md) — session registration, conflict matrix, activity feed / inbox / mailbox line schemas.
- [agents.md](/_shared/agents.md) — spawn prompt contract that carries the `Output:` line.
- `output-styles/terse-technical.md` — the forced output style that enforces this protocol.
