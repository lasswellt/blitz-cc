---
name: code-doctor
description: "Framework-API correctness audit for Firestore, VueFire, Vue 3, and Pinia. Detects anti-patterns, misuse, dead exports, and duplication. Read-only by default; --fix applies low-risk fixes. Use when the user says 'code-doctor', 'audit firestore', 'pinia anti-patterns', or sees framework-API warnings in logs."
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Agent
model: opus
effort: low
compatibility: ">=2.1.71"
argument-hint: "[scope] [--scan|--fix|--fix-all] [--rules firestore,vuefire,vue,pinia,dead,duplication]"
paths:
  - "**/*.vue"
  - "**/firestore.rules"
  - "**/firebase.json"
  - "**/stores/**/*.{ts,js}"
  - "**/*.firestore.{ts,js}"
---

<!-- import: from _shared/project-context.md §Canonical block — Project Context with stack detection -->
## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

## Additional Resources
- For rule tables, severity matrix, fix recipes, JSON schema, and ratchet protocol, see [references/main.md](references/main.md) — load on-demand, only the sections you need
- For output style (terse-technical, preservation rules), see [/_shared/terse-output.md](/_shared/terse-output.md)
- For session registration and activity feed, see [/_shared/session-protocol.md](/_shared/session-protocol.md)
- For verbose progress format, see [/_shared/verbose-progress.md](/_shared/verbose-progress.md)


OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.

---

**Terse exemptions (LITE intensity):** severity:critical `message` field — full sentences required. Resume terse on other severities.

---

# Code Doctor Skill

Detect framework-API anti-patterns, misuse, dead exports, and duplication candidates in the project. Default mode is read-only (`--scan`). Apply low-risk auto-fixes with `--fix`. Execute every phase in order.

---

## Safety Rules (non-negotiable)

1. **Never modify files in `--scan` mode** (the default).
2. **Never auto-fix without explicit `--fix` or `--fix-all`.**
3. `--fix` applies only rules where `auto_fix: true` in references/main.md.
4. `--fix-all` applies all fixable rules; print `⚠ fix-all mode: modifying files` before any edit.
5. Never suppress `// code-doctor-ignore` comments silently — log each suppression in the report.
6. If ratchet detects a count regression (new violations since last run), print `⚠ RATCHET FAIL` and list the increased rule ids.

---

## Phase 0: INIT — Register Session + Parse Args

### 0.1 Session Registration

Follow [session-protocol.md](/_shared/session-protocol.md) §Session Registration and [verbose-progress.md](/_shared/verbose-progress.md):
- Generate `SESSION_ID = "code-doctor-<8-char-hex>"`
- Create `SESSION_TMP_DIR = ".cc-sessions/${SESSION_ID}/tmp/"`
- Check for conflicting sessions on overlapping scopes
- Log `skill_start` to `.cc-sessions/activity-feed.jsonl`

Print:
```
[code-doctor] Phase 0: INIT
[code-doctor]   ├─ session: <SESSION_ID>
```

### 0.2 Parse Arguments

From ARGUMENTS:
- **scope**: directory or glob (default: `src/` if it exists, else `.`)
- **mode**: `--scan` (default), `--fix`, `--fix-all`
- **rule sets**: `--rules <comma-list>` (default: all applicable sets)
- **no-confirm**: `--no-confirm` skips LLM judge in Phase 2
- **config**: read `.code-doctor.json` if present (see references/main.md §E)

### 0.3 Detect Applicable Rule Sets

```bash
# Check package.json for framework dependencies
grep -E '"firebase"|"firestore"' package.json 2>/dev/null && echo "HAS_FIRESTORE"
grep -E '"vuefire"' package.json 2>/dev/null && echo "HAS_VUEFIRE"
grep -E '"vue"' package.json 2>/dev/null && echo "HAS_VUE"
grep -E '"pinia"' package.json 2>/dev/null && echo "HAS_PINIA"
```

Only load and run rule sets whose dependency is detected. If `--rules` is specified, further filter to those sets.

Print which rule sets will run:
```
[code-doctor]   ├─ rule sets: firestore, vuefire, vue, pinia (dead, duplication)
[code-doctor]   └─ mode: scan (read-only) ✓
```

---

## Phase 1: SCAN — Run Grep Rules

### 1.1 Load Rule Table

Read the **Rule Table** section of references/main.md. Extract only the rows for active rule sets.

### 1.2 Execute Grep Rules

For each rule in the active set:

```bash
# Example for rule F5
grep -rn "\.docs\.map(d\s*=>\s*d\.data()" --include="*.ts" --include="*.vue" <scope>
```

Collect findings: `{ ruleId, file, line, matchedText, severity }`.

For rules that require **context checking** (e.g., F2: `onSnapshot` without `onUnmounted` in same file, F6: `getDocs(collection(` without `query(` wrapping):
```bash
# Check if onSnapshot exists without onUnmounted in same file
for f in $(grep -rl "onSnapshot(" --include="*.vue" <scope>); do
  grep -L "onUnmounted" "$f" && echo "MISSING_CLEANUP: $f"
done
```

Apply inline suppression: skip findings on lines containing `// code-doctor-ignore: <ruleId>`.

Print progress per category:
```
[code-doctor] Phase 1: SCAN
[code-doctor]   ├─ firestore rules (10)... 3 findings
[code-doctor]   ├─ vuefire rules (5)... 1 finding
[code-doctor]   ├─ vue rules (5)... 2 findings
[code-doctor]   ├─ pinia rules (5)... 0 findings
[code-doctor]   ├─ dead export check... 1 finding
[code-doctor]   └─ duplication check... 0 findings
```

### 1.3 Dead Export Detection (rule D1)

```bash
# Find all exported symbols
grep -rn "^export " --include="*.ts" <scope> | grep -v "export \*" | grep -v "export type"

# For each export, check if it's imported anywhere
# Flag exports with 0 import matches across the scope
```

### 1.4 Duplication Detection (rule DUP1)

Use a rolling hash approach via Bash: extract 5-line windows from `.ts`/`.vue` files, flag windows that appear verbatim in 2+ files. Limit to max 20 duplication findings to avoid noise.

---

## Phase 2: JUDGE — LLM Confirm Critical Findings

Skip this phase if `--no-confirm` flag is set or if there are no critical findings.

For each `severity: critical` finding, spawn a single `Agent` (subagent_type: general-purpose, model: sonnet) with a tight prompt:

```
You are a code reviewer. Confirm if this is a real violation of rule <ruleId>.

Rule: <rule description from references/main.md>
File: <file path>
Relevant code (±10 lines around line <line>):
<code excerpt>

Answer: YES (real violation) or NO (false positive), one line, then a one-sentence reason.
```

Update finding: if agent says NO, set `confirmed: false` and exclude from report counts (but still list as "dismissed" in report appendix).

Print:
```
[code-doctor] Phase 2: JUDGE
[code-doctor]   ├─ 2 critical findings sent to LLM judge
[code-doctor]   └─ 2 confirmed, 0 dismissed
```

---

## Phase 3: REPORT — Write Audit Document + Ratchet

### 3.1 Build Report

Group confirmed findings by severity: critical → major → minor.

For each finding, include:
- `file:line` — exact location
- Rule id + description
- Matched code (1–3 lines)
- Fix recipe from references/main.md

### 3.2 Write Audit Document

```bash
mkdir -p docs/_audits
```

Write to `docs/_audits/YYYY-MM-DD_code-doctor.md` using the schema from references/main.md §D.

### 3.3 Console Output

Print a compact findings table:

```
[code-doctor] Phase 3: REPORT
[code-doctor]
[code-doctor]   CRITICAL (2)
[code-doctor]   ├─ F2  src/composables/useOrders.vue:14 — onSnapshot without cleanup
[code-doctor]   └─ V1  src/pages/Dashboard.vue:8 — useCollection outside setup
[code-doctor]
[code-doctor]   MAJOR (3)
[code-doctor]   ├─ F5  src/stores/orders.ts:42 — .docs.map(d => d.data()) loses id
[code-doctor]   ├─ F6  src/services/db.ts:17 — unbounded getDocs(collection(...))
[code-doctor]   └─ G1  src/components/OrderList.vue:23 — v-if + v-for same element
[code-doctor]
[code-doctor]   MINOR (1)
[code-doctor]   └─ V3  src/plugins/firebase.ts:3 — useFirestore() called 3× in file
[code-doctor]
[code-doctor]   Report: docs/_audits/YYYY-MM-DD_code-doctor.md
```

### 3.4 Ratchet

Read `.cc-sessions/code-doctor-ledger.jsonl` (last entry). Compare current counts.

If any severity count **increased**:
```
[code-doctor] ⚠ RATCHET FAIL — new violations since last run:
[code-doctor]   major: 2 → 3 (+1) — new: F6 in src/services/db.ts:17
```

Append new ledger entry regardless:
```json
{"ts":"<ISO>","session":"<SESSION_ID>","critical":2,"major":3,"minor":1}
```

---

## Phase 4: FIX (opt-in)

Skip entirely if mode is `--scan` (default).

### 4.1 Determine Fix Scope

- `--fix`: apply only rules with `auto_fix: true` in references/main.md (F5, V3, P2)
- `--fix-all`: apply all rules with a `fix_recipe` — print `⚠ fix-all mode: modifying files` first

### 4.2 Apply Fixes

For each fixable finding:
1. Read the file
2. Apply the fix recipe from references/main.md using Edit tool
3. Log `file_change` to activity feed

Print per fix:
```
[code-doctor]   ├─ FIXED V3 src/plugins/firebase.ts:3 — deduplicated useFirestore() calls
```

### 4.3 Re-scan After Fix

Run a targeted grep for the fixed rule ids to verify the fix removed the violation. If any remain, log as `fix_partial` and instruct the user to review manually.

---

## Phase 5: COMPLETE

Log `skill_complete` to activity feed:
```json
{"event":"skill_complete","message":"code-doctor scan complete","detail":{"critical":<n>,"major":<n>,"minor":<n>,"fixed":<n>}}
```

Print:
```
[code-doctor] Done. <critical> critical · <major> major · <minor> minor
[code-doctor] Next: fix critical issues manually — run /blitz:code-doctor --fix for auto-fixable minors
```

If there are critical findings, suggest `/blitz:refactor` for the extraction candidates or direct file editing for Firestore fixes.
