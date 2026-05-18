# Terse Output Protocol

Blitz's output-compression directive for skills and spawned agents. Inspired by the caveman-mode pattern (MIT, github.com/JuliusBrussee/caveman) and internalized here so blitz has no runtime dependency on external plugins.

**Purpose:** reduce model output tokens 20–40% without sacrificing technical accuracy. Applies to orchestrator-to-user prose, agent-to-orchestrator reports, findings summaries, decision rationale. Does NOT apply to structured artifacts, code, or exact-match payloads.

## Canonical Snippet

Every SKILL.md and every `agents/*.md` must contain this exact one-line directive verbatim. `skill-frontmatter-validate.sh` and `agent-frontmatter-validate.sh` hash-compare each file's OUTPUT STYLE line against this canonical source. Drift between the canonical and a deployed copy fails the validator.

<!-- canonical-output-style-start -->
OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.
<!-- canonical-output-style-end -->

Agents may extend the canonical snippet with a trailing addendum (e.g., `agents/critic.md` appends "No apologies. No 'I'll now check…' prose. Only findings or LGTM."). Extensions are out of scope for the hash check — only the canonical line above is enforced byte-identical. Future stricter enforcement could compare a hash of the extended block bounded by `<!-- output-style-extend: <agent> -->` / `<!-- end-extend -->` markers.

---

## Core rule

Speak technical-first, filler-free. Format preferred: `[subject] [verb] [reason]. [next action].`

**Drop:**
- Articles (a / an / the) where the meaning is unambiguous without them
- Fillers: *just, really, basically, actually, simply, quite, very*
- Pleasantries and preambles: *sure, certainly, I'd be happy to, let me*
- Hedging: *it seems, perhaps, maybe, arguably, somewhat*
- Trailing summaries of work already evident in the diff or tool output

**Keep:**
- Exact technical vocabulary and proper nouns
- Code (verbatim)
- File paths, URLs, commands, CLI flags
- Version numbers, dates, error codes
- Numbers, identifiers, grep patterns
- Headings and list structure

---

## Intensity levels

| Level | Description | When to use |
|---|---|---|
| `lite` | Drop fillers and pleasantries; keep full sentences | Default for user-facing orchestrator output |
| `full` | Fragments allowed; articles dropped; telegraphic | Agent-to-orchestrator reports; verification summaries |
| `ultra` | Maximum compression; symbol shorthand allowed | Internal checkpoint markers; bulk status lines |

Skills SHOULD declare an intended level in their SKILL.md frontmatter (`output_style: lite|full|ultra`). Default when unspecified: `lite`.

---

## Intensity override precedence

When an Agent() spawn or skill invocation interpolates the active intensity, resolve in this order (first hit wins):

1. **Environment variable:** `BLITZ_OUTPUT_INTENSITY=lite|full|ultra` — session-scoped override, typically set for one `/loop` run.
2. **Developer profile:** `.cc-sessions/developer-profile.json` top-level `output_intensity` field — per-user/per-repo preference that survives sessions.
3. **Skill frontmatter:** `output_intensity: lite|full|ultra` in the SKILL.md frontmatter — per-skill declaration.
4. **Output-style field:** the legacy `output_style:` frontmatter field (treated as an alias of `output_intensity`).
5. **Default:** `lite`.

The active intensity is what gets substituted into the canonical `spawn-protocol.md` §7 OUTPUT STYLE snippet when agents spawn. See `spawn-protocol.md` for the interpolation point.

---

## Preservation boundary (non-negotiable)

Never compress:

1. Fenced code blocks (` ``` ... ``` `) and inline code (`` `...` ``)
2. YAML frontmatter and JSON bodies
3. File paths and URLs
4. Grep patterns, regex strings, exact-match phrases inside tables
5. Commit messages and PR descriptions (rendered verbatim elsewhere)
6. Scope blocks, registry entries, DoD checklists — every field must parse
7. Commands the user might copy-paste
8. Error messages and stack traces quoted for diagnosis

If compression would alter any of the above, write the original form. Correctness dominates brevity.

---

## Auto-pause conditions

Temporarily drop terse mode and write normally when:

- Reporting a security warning or credential risk
- Confirming an irreversible action (delete, force-push, drop-table)
- The user appears confused by prior terse output (explicit ask for clarification)
- Explaining a non-obvious root cause where compressed prose would lose the reasoning chain

Resume terse mode on the next response.

---

## Canonical Exemptions List

Authoritative — overrides any per-skill exemption declarations. Skills MUST NOT redefine the exemption set in their SKILL.md frontmatter; if a skill thinks it needs a new exemption category, propose it here first.

Sections in any agent or skill output that ALWAYS use full-prose (LITE intensity) regardless of the active intensity level:

| Section type | Examples | Why exempt |
|---|---|---|
| **Safety rules** | "Never run X against prod", "Never bypass Y", security warnings, credential-handling guidance | Compressed safety language has caused real incidents (e.g., a "use --no-verify only when needed" terse line that dropped the only-when-needed condition). |
| **Root cause analyses** | Bug post-mortems, "why did this break", architectural decision records | The reasoning chain is the value; compression loses it. |
| **Risks and trade-offs** | Research doc §Risks, Open Questions, ADR §Consequences | Same reason as root cause — the qualifier matters. |
| **Destructive-op confirmations** | `rm -rf`, `git push --force`, `drop table`, `kubectl delete`, package uninstall | Irreversibility demands a full sentence + reasoning chain. The user's "yes" is binding. |
| **First-time onboarding** | README quickstart sections, bootstrap output to a fresh user, error-message remediation | New users need full sentences; terse output fails the "reader picks up cold" test. |
| **Migration notices** | Breaking-change descriptions in CHANGELOG, deprecation warnings, upgrade-required prompts | Users skim; full prose ensures the action is unmissable. |

**How to apply.** When a skill's output crosses an exemption category, that section drops to LITE intensity for the duration of the section. Resume the active intensity at the next non-exempt section. Mark the boundary explicitly if the section is more than ~3 lines:

```markdown
<!-- exempt: safety -->
This operation is destructive. It will delete the production database
backup. There is no automated rollback. Type the database name to confirm.
<!-- /exempt -->
```

**Audit.** sprint-review Phase 3.6 grep-checks for `<!-- exempt: ` markers in agent prompt templates and skill outputs; missing markers around safety/destructive content is a WARN, present-but-misused markers are a BLOCKER.

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

1. **Spawn protocol** — every Agent() prompt template should append: *"Output style: terse-technical per `/_shared/terse-output.md`. Preserve code, paths, commands, structured fields verbatim. No preamble, no trailing summary."* See `spawn-protocol.md`.

2. **SKILL.md Additional Resources** — skills that produce user-facing output should list this file alongside `context-management.md`.

3. **`/blitz:compress`** — the file-compression skill applies these same rules to rewrite markdown files at author time. This doc is the reference spec for that skill.

---

## Credit

The directive structure, intensity tiers, and preservation-rule framing are adapted from caveman-mode (JuliusBrussee/caveman, MIT). The integration surface (spawn-protocol injection, SKILL.md references, file-rewriter skill) is blitz-specific.
