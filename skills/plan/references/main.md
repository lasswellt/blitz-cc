# Plan — references

Companion to [SKILL.md](../SKILL.md). Two sections: the research-agent prompts that Phase 2 spawns, and the verify-command template table that Phase 3 draws from. Canonical spawn boilerplate (preamble, budget block, write-as-you-go) is in [/_shared/agents.reference.md](/_shared/agents.reference.md) §3; the blocks below inline it so a prompt can be pasted whole.

Variables the main thread substitutes before spawning: `${SLUG}`, `${GOAL}` (the design summary from Phase 1, ≤15 lines), `${OUTCOMES}` (the numbered outcome list), `${STACK_PROFILE}` (the `detect-stack.sh` output), `${CODEBASE_INVENTORY}` (`git ls-files | head -200` or the `onboard` map), `${OUT_DIR}` (`.cc-sessions/sessions/${CLAUDE_SESSION_ID}/plan-${SLUG}`, created with `mkdir -p` first). Resolve every variable with Bash before spawning; never hand an agent a literal placeholder path.

---

## Research-agent prompts

**Workload class for every plan researcher: Medium** ([agents.reference.md](/_shared/agents.reference.md) §3.3). Every prompt below opens with this block:

```
You are a general-purpose agent with Write access. Your task is INCOMPLETE
if ${OUT_DIR}/research-<name>.md does not exist and is non-empty when you finish.
Resolve any ${VAR} in the path with Bash before your first write; never
write to a literal placeholder path.

BUDGET (Medium — skills/_shared/agents.reference.md §3.3):
- Max file reads: 15
- Max web searches: 8 (0 for the codebase analyst)
- Max tool calls: 25 (at 20, finish the current step and reply)
- Max output: 250 lines
- Wall-clock: 5 minutes

WRITE-AS-YOU-GO (MANDATORY):
1. Before your first tool call, stub the output file with `# IN PROGRESS`.
2. After each outcome analyzed, append findings to the file immediately.
3. Never accumulate in memory and write once at the end.

OUTPUT STYLE: terse-technical. No fillers, pleasantries, hedging. Preserve
verbatim: code fences, inline code, URLs, file paths, commands, grep patterns,
YAML/JSON, headings, table rows, error codes, dates, version numbers. No
preamble. No trailing summary. Fragments OK.

CONFIRMATION: emit one line "<name>: <N items written>". Do not echo findings.
```

Spawn each with `Agent` (`subagent_type: general-purpose`). `Explore` cannot write files and fails silently; never use it here.

### Domain researcher

```
You are the domain-researcher for plan ${SLUG}.

[Workload block above.]

RESEARCH FOCUS: External APIs, domain standards, protocols, and patterns relevant to the goal.

GOAL:
${GOAL}

OUTCOMES:
${OUTCOMES}

INSTRUCTIONS:
1. For each outcome, identify external APIs, services, or protocols involved.
2. Research current best practices, authentication patterns, rate limits, and error handling.
3. Look for official documentation, migration guides, and known gotchas.
4. Write findings to: ${OUT_DIR}/research-domain.md — stub the file first, then append as you go.

OUTPUT FORMAT:
## Outcome: <n> — <outcome text>
### External Dependencies
- <API/service name>: <key findings>
### Patterns & Best Practices
- <pattern>: <recommendation>
### Risks & Gotchas
- <issue>: <mitigation>
```

### Library researcher

```
You are the library-researcher for plan ${SLUG}.

[Workload block above.]

RESEARCH FOCUS: Package ecosystem, library versions, compatibility, migration paths, and implementation examples.

GOAL:
${GOAL}

OUTCOMES:
${OUTCOMES}

DETECTED STACK:
${STACK_PROFILE}

INSTRUCTIONS:
1. For each outcome, identify required packages and their current stable versions.
2. Check compatibility with the detected stack (especially framework version).
3. Find implementation examples, especially for complex integrations.
4. Note any required peer dependencies or breaking changes.
5. Write findings to: ${OUT_DIR}/research-library.md

OUTPUT FORMAT:
## Outcome: <n> — <outcome text>
### Required Packages
| Package | Version | Purpose | Compat Notes |
|---------|---------|---------|--------------|
### Implementation Examples
- <pattern>: <code reference or link>
### Migration / Breaking Changes
- <package>: <notes>
```

### Codebase analyst

```
You are the codebase-analyst for plan ${SLUG}.

[Workload block above; web searches: 0.]

RESEARCH FOCUS: Existing code patterns, reusable modules, integration points, and potential conflicts.

GOAL:
${GOAL}

OUTCOMES:
${OUTCOMES}

PROJECT STRUCTURE:
${CODEBASE_INVENTORY}

INSTRUCTIONS:
1. For each outcome, search the codebase for related existing code.
2. Identify reusable patterns (composables, utilities, components, schemas).
3. Map integration points where new code must connect to existing code.
4. Flag potential conflicts (naming collisions, import cycles, shared state).
5. Write findings to: ${OUT_DIR}/research-codebase.md

OUTPUT FORMAT:
## Outcome: <n> — <outcome text>
### Existing Patterns to Reuse
- <file path>: <what it provides>
### Integration Points
- <file path>: <how new code connects>
### Potential Conflicts
- <issue>: <description and suggestion>
### Suggested File Locations
- <new file path>: <rationale based on existing conventions>
```

### Infrastructure analyst (optional)

```
You are the infra-analyst for plan ${SLUG}.

[Workload block above.]

RESEARCH FOCUS: Cloud configuration, security rules, deployment pipeline, environment variables, and infrastructure requirements.

GOAL:
${GOAL}

OUTCOMES:
${OUTCOMES}

INSTRUCTIONS:
1. Review existing infrastructure config (firebase.json, cloud functions, CI/CD).
2. Identify infrastructure changes needed for the outcomes.
3. Check security rules for required updates.
4. Note any environment variables or secrets that must be configured.
5. Write findings to: ${OUT_DIR}/research-infra.md

OUTPUT FORMAT:
## Outcome: <n> — <outcome text>
### Infrastructure Changes Required
- <resource>: <change description>
### Security Rules Updates
- <rule>: <current state> -> <required state>
### Environment Configuration
- <variable>: <purpose and where to set it>
### Deployment Considerations
- <consideration>: <details>
```

### Reading the outputs

- Spot-check every file path and package version an agent reports before it enters `plan.md` (TB-3: agent output is not higher-trust than what it read).
- A missing or `# IN PROGRESS`-only file after one retry is a gap; record it under `plan.md` §Risks and pin the assumption with a `grep_present` verify on the task that depends on it.
- The `Suggested File Locations` section of the codebase analyst is the primary input to `--files` in Phase 3.

---

## Verify templates

Every `--verify-cmd` takes the form `"<cmd>::<timeout-seconds>"`. Substitute real paths; a `<placeholder>` in `tasks.json` is a planning defect. Behavior tasks pair a test row with at least one row from the non-test half (`tasks.sh add` enforces it).

| Kind | Template | Timeout | Use when |
|---|---|---|---|
| vitest file | `npx vitest run <file.test.ts> --reporter=dot` | 300 | the task adds or changes a unit/integration test (test runner; needs a partner below) |
| tsc | `npx tsc --noEmit --pretty false` | 180 | any TypeScript change; cheap, deterministic, non-test |
| grep_present | `grep -qE '<pattern>' <file>` | 10 | the task introduces a symbol: `export (const\|function\|class) <name>`, a route string `'/api/<path>'`, an env key `<KEY>=` in `.env.example`, a rules `match /<collection>/` |
| grep_absent | `! grep -nE 'TODO\|return \{\}' <file>` | 10 | every task that writes production code (anti-mock rules, [quality.reference.md](/_shared/quality.reference.md) §Definition of Done); extend the alternation with `Not implemented\|PLACEHOLDER` when the file is new |
| Firestore rules | `firebase emulators:exec --only firestore "npx vitest run <rules.test.ts>"` | 600 | `firestore.rules` changes; the test uses `@firebase/rules-unit-testing` and asserts both allow and deny |
| Cloud Functions | `firebase emulators:exec --only functions,firestore "npx vitest run <file.test.ts>"` | 600 | a callable/trigger changes; the test invokes it against the emulator, not a `vi.mock` of `firebase-admin` |
| Playwright | `npx playwright test <spec.ts>` | 600 | a user-visible flow changes; counts as non-test e2e evidence |
| route existence | `grep -qE "(get\|post\|put\|delete\|route)\(['\"]/<path>['\"]" <router-file>` | 10 | an HTTP route is added; pair with the handler's unit test |
| export existence | `node -e "const m=require('./<built-file>'); if(typeof m.<name>!=='function') process.exit(1)"` | 30 | a compiled entry point must expose `<name>`; for ESM/TS sources prefer the `grep_present` row |
| lint on files | `npx eslint <file1> <file2> --max-warnings 0` | 120 | any JS/TS change; use the project's lint command from `package.json` when it differs |
| bulk batch count | `[ "$(grep -rlE '<new-pattern>' <dir> \| wc -l)" -ge <n> ]` | 30 | a SPIDR split batch: proves the migration reached ≥ `<n>` files in `<dir>` |
| doc exists (spike) | `test -s docs/research/<date>_<slug>.md` | 5 | the only task of a spike plan; pass `--test-only-ok` is not needed (this is not a test runner) |
| shell script | `bash scripts/<check>.sh` | 120 | a bespoke check that exercises the change end to end (CLI output, generated file shape); the script lives in the repo, not in the command string |

### Composition rules

- Minimum for a backend task: test row + `tsc` + `grep_absent`.
- Minimum for a frontend task: test row (or Playwright) + `grep_present` on the component export + `grep_absent`.
- Minimum for an infra task: the emulator row that covers the change + `grep_present` on the rule/config key.
- Minimum for a `role: test` task: the test row alone with `--test-only-ok`, plus `--notes "test-only: <why no non-test check applies>"`.
- Order rows cheapest first (`grep` → `tsc` → unit test → emulator → Playwright); `tasks.sh verify` stops at the first failure and the 200-char tail is what `build` reads.
- Quote patterns for the shell that `tasks.sh verify` runs (`bash -c`); escape `{` `}` `|` inside `grep -E` alternations as shown.

---

## Moved from SKILL.md (body size)

Detail moved out of the skill body so it stays under the compaction re-attach cap (the platform keeps only the first 5,000 tokens of a re-attached skill). Behaviour is unchanged; the body links each block at its original position.

### 3.1.1 Bulk-task guard (SPIDR check)

After drafting each task but **before** accepting it, run the bulk-task guard (catches the "migrate 130 files via glob" anti-pattern).

**Reject or split** any task matching either criterion:

1. **File-count heuristic** (two-band):
   - `task.files.length > 5` AND the plan class is not `spike` — **mandatory split**.
   - `task.files.length` in `{4, 5}` — **soft warn**: append a `decision` line to the activity feed; allow only if no other task shares a parent directory with it.
   - `task.files.length` in `{1, 2, 3}` — **green**.

2. **Horizontal-scope language** — title or notes matches (case-insensitive):
   - `/all \w+ (files|components|modals|routes|tests|pages)/`
   - `/(via|using) (pattern|glob|regex)/`
   - `/across the codebase/`
   - `/every (file|component|store|route|test)/`
   - `/bulk (migrate|refactor|update|rename)/`

**Handling a match:**
- **Interactive:** pause. Offer a SPIDR Data-axis split (one task per parent directory) or downgrade the plan class to `spike`.
- **`--autonomous`:** auto-split by nearest parent directory; recursively split while a batch still has > 8 files. Each batch gets a `grep -c` verify that counts the migrated pattern in that directory, e.g. `[ "$(grep -rlE '<new-pattern>' src/<dir> | wc -l)" -ge <n> ]::30`. If there is no concrete file list, downgrade to spike. Append one `decision` feed line per split.
- **Never auto-accept a bulk task.** List every split in `plan.md` §Risks.
