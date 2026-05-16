---
name: quick
description: "Makes a small ad-hoc change (typo, one-line fix, single-file tweak) without the full sprint ceremony. Use when the user describes a tiny scoped change like 'fix the typo in X', 'change Y to Z in file foo', 'rename this var', 'tweak this string'. Do NOT use for multi-file refactors, new features, or anything that needs tests — those go through sprint-dev or refactor."
argument-hint: "<describe what you want to change>"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
model: sonnet
effort: low
compatibility: ">=2.1.71"
---

## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

## Additional Resources
- For package install policy (always resolve to registry latest, never invent versions from training memory), see [/_shared/package-install-policy.md](/_shared/package-install-policy.md). Even quick edits that add a single dep go through the policy.

---


OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.

# Quick Mode

Make a small, targeted change without sprint planning, session registration, or agent coordination. Use this for ad-hoc fixes, typos, config tweaks, and single-file changes.

**No session protocol. No activity feed logging. No agents. Just do the work.**

**Verbose progress exemption:** This skill intentionally skips verbose output. Freeform activity-feed logging from CLAUDE.md still applies.

---

## Phase 0: UNDERSTAND

1. **Parse the request.** Identify exactly what needs to change.
2. **Locate the target.** Find the file(s) that need modification. If more than 5 files need changes, warn the user that this may be too large for quick mode and suggest using a proper skill instead.
3. **Check build baseline.** Run a quick type-check to know the starting state:
   ```bash
   npm run type-check 2>&1 | tail -5
   ```

---

## Phase 1: IMPLEMENT

1. **Make the change.** Edit the file(s) directly. Follow existing code patterns.
2. **Keep scope tight.** Only change what was requested. Do not refactor surrounding code, add comments, or "improve" adjacent logic.

---

## Phase 2: VERIFY

1. **Type-check:**
   ```bash
   npm run type-check 2>&1 | tail -10
   ```
2. **Run related tests** (if a matching test file exists):
   ```bash
   # Find and run the test file matching the changed source file
   npm run test -- --run <matching-test-file> 2>&1 | tail -15
   ```
3. **If verification fails**, fix the issue. Max 3 attempts, then report the failure to the user.
4. **Commit** (if the user requested it or the change is clearly complete):
   ```bash
   git add <changed-files>
   git commit -m "fix(<scope>): <description>"
   ```

---

## Guardrails

- **Max 5 files.** If the change requires more, suggest `fix-issue`, `refactor`, or `sprint-dev` instead.
- **No new packages.** If the change requires `npm install`, suggest `research` or `sprint-plan` instead.
- **No new directories.** If the change requires new architecture, suggest `bootstrap` or `sprint-plan` instead.
- **Follow [Definition of Done](/_shared/definition-of-done.md).** Even in quick mode, no placeholder code, no TODO stubs, no empty handlers.
