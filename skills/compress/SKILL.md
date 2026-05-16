---
name: compress
description: "Rewrites a markdown or plain-text file into terse form to reduce input tokens when the file is loaded. Preserves code, URLs, paths, commands, headings, tables, YAML, and JSON verbatim. Writes a .original backup before modifying the source. Use when the user says 'compress this file', 'shrink this doc', 'reduce tokens in <file>', 'make this terse', or when a research doc / SKILL.md gets too long."
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
model: sonnet
effort: low
compatibility: ">=2.1.71"
---

## Additional Resources
- For the output-compression rules, preservation boundary, and examples, see [/_shared/terse-output.md](/_shared/terse-output.md)
- For the structural validator (run after compression), see `hooks/scripts/reference-compression-validate.sh`


OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.

---

# Compress Skill

Rewrite a target markdown or text file into terse form following the blitz Terse Output Protocol. This is an **author-time** transform: it modifies files in the repo, saves a backup, and runs structural validation. It is not a runtime compression layer — the compressed file is what ships.

## Inputs

One or more file paths. Supported extensions: `.md`, `.txt`, `.rst`, or extensionless text files. The skill refuses to operate on: `.py`, `.js`, `.ts`, `.json`, `.yaml`, `.yml`, `.toml`, `.sh`, or any file already matching `*.original` / `*.original.md`.

## Phase 0 — Register and validate

0.1 Register session per [session-protocol.md](/_shared/session-protocol.md) and [verbose-progress.md](/_shared/verbose-progress.md). Generate SESSION_ID, log `skill_start` to `.cc-sessions/activity-feed.jsonl`.

0.2 Validate inputs. For each target:
  - File exists and is readable.
  - Extension is allowed (reject code/config files with a clear message).
  - No existing `<file>.original` sibling (if present, it means the file was already compressed — skip with a notice, do not re-compress).
  - File size ≤ 500KB (soft safety limit).
  - **Classify by size for Phase 2 mode selection** (see [spawn-protocol.md §2 Output Size](/_shared/spawn-protocol.md#output-size-and-single-write-budget)):
    - `≤ 40 KB`: single-Write mode (Phase 2.4 below)
    - `> 40 KB`: sectioned-Edit mode (Phase 2.5 below) — single Write exceeds sonnet per-call budget, will time out at ~7 min with zero output

0.3 If any target is rejected, list the rejected files and continue with accepted ones. If zero targets remain, exit with a summary.

## Phase 1 — Backup

1.1 For each accepted target, write a backup to `<file>.original` (preserving the original extension order: `references/main.md` → `references/main.md.original`). Use Read + Write. Never skip this step.

1.2 Verify the backup: its byte count must match the source. If not, abort with error.

## Phase 2 — Compress

2.1 Read the target file. Apply the Terse Output Protocol at `full` intensity:
  - Drop articles, fillers, pleasantries, hedging (per `/_shared/terse-output.md`).
  - Rewrite verbose constructions to fragments where grammatical loss is acceptable.
  - Preserve all elements in the "Preservation boundary" list verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON blocks, table cells that contain patterns or identifiers, headings (exact text), dates, version numbers, error codes.

2.2 Specific preservation rules, enforced mechanically:
  - Every line starting with ` ``` ` in the original MUST appear unchanged in the output at a corresponding position.
  - Every `http(s)://...` URL in the original MUST appear in the output (set equality).
  - Every heading line (`^#+ `) in the original MUST appear in the output with identical text.
  - Every table row (lines starting with `|`) MUST remain a table row in the output; row count must match.
  - Any text inside backticks `` ` `` must remain verbatim.
  - Any value that looks like a grep pattern (contains regex metacharacters or is referenced as "pattern" / "regex" nearby) MUST remain verbatim — when in doubt, preserve.

2.3 If the source file contains any of these markers anywhere, ABORT compression with a clear explanation: "File contains exact-match agent prompt or grep-pattern content — classified UNSAFE, refusing to compress. See caveman-compress input-side research for classification."
  - Literal string `agent prompt template` (heading or bold)
  - Heading text `Grep Patterns by Check`
  - Frontmatter field `output_style: exact` (opt-out signal)

2.4 **Single-Write mode** (`≤ 40 KB` target): Write the compressed content back to the target file path in one Write call.

2.5 **Sectioned-Edit mode** (`> 40 KB` target): do NOT issue a single Write. Instead:
  - Identify section boundaries (top-level `^## ` headings) in the source.
  - For each section, issue one Edit call replacing the verbose section text with its compressed equivalent. Preserve heading line + structural elements per 2.2.
  - Process sections in document order so prior Edits remain unique-matchable.
  - Per-Edit output stays under ~8 KB (sonnet per-call budget); ~10-20 Edits for a 40-70 KB file is normal.
  - **Anchor**: a single-Write compress on `skills/ui-audit/references/main.md` (70 KB) ran 7m36s with zero output before timing out. The successful `skills/sprint-review/references/main.md` pass (35 KB) used 20 Edits across 14 sections.

## Phase 3 — Validate

3.1 Run the structural validator on the compressed pair:
```bash
bash hooks/scripts/reference-compression-validate.sh
```

3.2 If validation fails:
  - Print the drift report from the validator.
  - **Restore** the original: `mv <file>.original <file>` (delete the backup to return to pre-compress state).
  - Mark this target as FAILED in the summary.
  - Continue to the next target.

3.3 If validation passes, target is COMPLETE.

## Phase 4 — Report

4.1 Write a summary to the user:
```
compress: <N> file(s) processed
  complete: <list>
  rejected: <list with reason>
  failed:   <list with validator drift>
  skipped:  <list already having .original backup>
```

4.2 Log `skill_complete` to the activity feed with the file list.

4.3 Do NOT git-commit automatically. The operator commits both `<file>` and `<file>.original` together after reviewing.

---

## Invocation examples

```
/blitz:compress skills/research/references/main.md
/blitz:compress docs/guides/onboarding.md docs/guides/architecture.md
```

## Error recovery

- **Target is a code or config file**: reject with extension-based error. Do not attempt.
- **Target already has `.original` sibling**: skip with notice. To re-compress, operator must manually delete the backup first.
- **Validation drift after compression**: auto-restore from backup and mark FAILED. Operator must investigate before retrying.
- **File exceeds 500KB**: reject. This is a safety rail — oversized files suggest the source-of-truth is misplaced (generated files, logs, etc).
- **File 40-500KB**: auto-route to sectioned-Edit mode (Phase 2.5). Do not attempt single-Write — it will time out with zero output.
- **Source file contains UNSAFE markers (2.3)**: refuse with classification reference. Operator may override by removing the markers, but the refusal is the default.

## Testing

After building this skill, smoke-test with:
```bash
# Create a test file
mkdir -p /tmp/compress-test && cat > /tmp/compress-test/sample.md <<'EOF'
# Sample

This is basically just a really simple test file that we're using to verify that the compression works correctly.

- https://example.com must survive
- `/usr/bin/env` must survive
- ```code``` block must survive

| Col | Val |
|---|---|
| a | 1 |
EOF

# Invoke compression, confirm .original exists and validator passes
```

## Relationship to upstream caveman

The compression approach, preservation rules, and `.original` backup convention are modeled on caveman-compress (JuliusBrussee/caveman, MIT). This blitz-native reimplementation removes the external Python runtime dependency, integrates with blitz's hook validator, and respects blitz's UNSAFE-classification markers for agent-prompt content.
