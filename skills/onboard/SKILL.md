---
name: onboard
description: "Sets a project up for blitz: scaffolds a new Vue/Nuxt/Firebase app or package, or maps an existing repo into CODEBASE-MAP.md. Use for 'new project', 'scaffold', 'set up a Nuxt app', 'add a package', 'I inherited this repo', 'map the codebase', or when no CODEBASE-MAP.md exists."
argument-hint: "[--greenfield <name>|--map] [--package <name>]"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebSearch, ToolSearch, Agent
model: inherit
compatibility: ">=2.1.271"
---
> **Session:** this skill inherits the session model. Recommended: opus, effort medium. Set once (`claude --model opus --effort medium` or `/model`, `/effort`) — switching mid-session resets the prompt cache. Current effort: `${CLAUDE_EFFORT}`.

## Project Context
!`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`

## Additional Resources
- Artifacts the rest of the loop reads (`docs/plans/`, `docs/solutions/`, `.cc-sessions/`): [/_shared/loop.md](/_shared/loop.md)
- Package install policy (resolve to registry latest, never a version from memory) — applies to every `pnpm add` / `npm install` here: [/_shared/security.md](/_shared/security.md) §Package Install Policy
- Spawn contract, `Explore` type, budget block: [/_shared/agents.md](/_shared/agents.md) §1.2, §3.3
- Session record and activity feed: [/_shared/sessions.md](/_shared/sessions.md) §2, §9
- Scaffold trees, convention detection, file templates, map checklists, dimension prompt: [references/main.md](references/main.md)

---

# Onboard

Make a directory ready for the blitz loop. Two modes, one skill: **greenfield** scaffolds a working Vue/Nuxt (+ optional Firebase) app or a monorepo package; **map** reads an existing repo and writes `CODEBASE-MAP.md` (Technology, Architecture, Quality, Concerns, Recommendations). Both end with the same shape of artifacts so `/blitz:plan` has something to read.

Arguments: `--greenfield <name>` forces a new project named `<name>`; `--map` forces the mapper; `--package <name>` adds one package to an existing workspace. With no flags, Phase 0 decides.

Preamble: claim the session record (`skill: onboard`, `working_on: "<mode> <name>"`), set `SESSION_TMP_DIR`, run `startup-validate.sh`, print the recent-feed summary ([sessions.md](/_shared/sessions.md) §2 steps 1–7). Append `skill_start` to the activity feed. Never arm `gate.json`; `rm -f .cc-sessions/sessions/${CLAUDE_SESSION_ID}/gate.json` if one is left over.

---

## SAFETY RULES (NON-NEGOTIABLE)

1. **Never overwrite an existing file without explicit confirmation.** `[ -f "<path>" ]` before every Write; on a hit, ask skip or overwrite.
2. **Never generate placeholder code.** No `TODO`, `FIXME`, empty bodies, `throw new Error('not implemented')`. Every scaffolded file compiles and its test passes ([quality.reference.md](/_shared/quality.reference.md) §Definition of Done).
3. **Never install a framework or large library without confirmation.** Small dev deps (types, test utils) are fine.
4. **Existing conventions win** over best practice when they conflict.
5. **TypeScript always**, unless the project is JS-only.
6. **Map mode is read-only** except for `CODEBASE-MAP.md` and `${SESSION_TMP_DIR}/`.

---

## Phase 0: MODE — Pick greenfield, map, or package

```bash
MODE=""
case "$ARGUMENTS" in *--greenfield*) MODE=greenfield ;; *--map*) MODE=map ;; *--package*) MODE=package ;; esac
if [ -z "$MODE" ]; then
  if [ ! -f package.json ] && [ ! -d src ] && [ ! -d app ] && [ ! -d pages ]; then MODE=greenfield
  else MODE=map; fi
fi
echo "[onboard] mode=$MODE"
```

| Mode | Trigger | Produces |
|---|---|---|
| `greenfield` | `--greenfield <name>`, or no `package.json` and no `src/`/`app/`/`pages/` | a running app skeleton, `docs/plans/`, `docs/solutions/`, settings, `.gitignore`, first commit |
| `map` | `--map`, or an existing project | `CODEBASE-MAP.md` at the repo root |
| `package` | `--package <name>` (requires a workspace: `pnpm-workspace.yaml`, `workspaces` in `package.json`, `nx.json`, `turbo.json`, `lerna.json`) | `packages/<name>/` matching the workspace's conventions |

`--greenfield` inside a non-empty directory: ask once whether to scaffold into it anyway (existing files are never overwritten). `--package` without a workspace: ask for the workspace root and package manager; if there is none, stop and suggest `--greenfield`. `--map` on an empty directory: write a minimal map noting the empty repo and stop.

Log `decision` with `detail: {choice: "<mode>", reason: "<signal>"}`. Then follow **§G** (greenfield, package) or **§M** (map).

---

## §G Greenfield and package

### G1 DISCOVER — Conventions and stack

**Package mode** — scan the workspace before planning anything:

```bash
find . -path '*/components/*' -name '*.vue' -o -path '*/stores/*' -name '*.ts' | grep -v node_modules | head -20
find . -name '*.test.*' -o -name '*.spec.*' | grep -v node_modules | head -20
ls packages/*/package.json packages/*/tsconfig.json 2>/dev/null | head
```

Extract file naming, directory grouping, component style, store syntax, test location and naming, import aliases, package manager (detection table and fallbacks: [references/main.md](references/main.md) §Convention Detection). Read 2–3 exemplar files per category to confirm; a sibling package's `package.json` and `tsconfig.json` are the templates.

**Greenfield mode** — the Project Context block above already reports what `detect-stack.sh` can see (usually nothing). Confirm the stack once:

```
Project Setup: <name>
  Framework:  Vue 3 + Vite  |  Nuxt 3
  UI:         Tailwind CSS  |  Quasar  |  Vuetify  |  None
  Backend:    Firebase (Auth, Firestore, Functions)  |  None
  Testing:    Vitest (+ @firebase/rules-unit-testing when Backend=Firebase)
  Pkg mgr:    pnpm (preferred)  |  npm  |  yarn

  Confirm choices? [y/n]
```

Defaults when the operator says "just pick": Nuxt 3, Tailwind, no backend, Vitest, pnpm. When `UI != None`, add `impeccable` to `devDependencies` so `/blitz:ui-audit` and `/blitz:check --only design` have their semantic lane in this project (target-project dependency, never a plugin one; resolve to registry latest).

### G2 DESIGN — Plan the file set

Build the planned file list from the stack (trees in [references/main.md](references/main.md) §Scaffold Trees) and print it before creating anything:

```
Onboard Plan: <mode> "<name>"
  Files to create:
    1. package.json
    2. nuxt.config.ts | vite.config.ts
    3. tsconfig.json, vitest.config.ts
    4. app.vue + pages/index.vue | src/App.vue + src/main.ts + src/router/index.ts
    5. stores/app.ts, composables/useAsync.ts, types/index.ts
    6. tests/app.test.ts
    7. docs/plans/.gitkeep, docs/solutions/.gitkeep
    8. .claude/settings.json, .gitignore, README.md
    9. (firebase.json, firestore.rules, functions/ when Backend=Firebase)
  Existing files at any path: <none | list → skip/overwrite?>

  Proceed? [y/n]
```

Package mode plans `packages/<name>/{package.json, tsconfig.json, vitest.config.ts, src/index.ts, tests/index.test.ts}` plus the workspace registration (`pnpm-workspace.yaml` glob already covers it, or add the path). Wait for confirmation.

### G3 IMPLEMENT — Generate real files

Writes the real files the onboarding produces, never placeholders. File list and templates: [references/main.md](references/main.md) §G3 IMPLEMENT.

### G4 VERIFY — Type-check, lint, test

```bash
npx tsc --noEmit --pretty false 2>&1 | tail -20          # or npx vue-tsc --noEmit
npx eslint <new-files> 2>&1 | tail -20
npx vitest run --reporter=dot 2>&1 | tail -20
```

Log a `verification` feed line per command with `result: pass|fail`. Fix and re-run; **maximum 3 fix iterations per failing check**. Gate before G5:

| Criterion | Check | Required |
|---|---|---|
| Every planned file exists | `[ -f ]` loop over the G2 list | yes |
| Type-check exits 0 | command above | yes |
| Lint on new files exits 0 | command above | yes |
| Tests pass | `vitest run` | yes |
| No placeholders | `! grep -rnE 'TODO|FIXME|not implemented' <new-files>` | yes |
| Route reachable (greenfield) | `pages/index.vue` or router entry present | yes |
| `docs/plans/`, `docs/solutions/`, `.gitignore` entries present | `ls`, `grep -q '.cc-sessions/' .gitignore` | yes |

After 3 failed attempts on any criterion, report partial success and stop:

```
Onboard Partial: <mode> "<name>"
  Files created: N/M   Passing criteria: X/Y
  Failed: - <criterion>: <one-line reason>
  Manual fixes: 1. <specific>  2. <specific>
```

### G5 COMMIT and REPORT

Greenfield: `git init` if needed (`git rev-parse --git-dir` fails), default branch `main`, then one commit `chore: scaffold <name> (<stack>)`. Package: one commit `feat(<name>): scaffold package`. Never `--no-verify`; never commit if G4 failed.

```
Onboard Complete: <mode> "<name>"
  Stack: <framework> + <ui> + <backend> · <pkg mgr>
  Files created: N   Type-check: PASS   Lint: PASS   Tests: PASS (N/N)
  Settings: .claude/settings.json (worktree.baseRef: head)
  Commit: <sha>

  Next: /blitz:research <topic> or /blitz:plan <slug>
        /blitz:doctor to confirm the harness is wired
```

Skip to **Final** below.

---

## §M Map an existing repo

### M1 INVENTORY — One scan, shared by every agent

Keep this in the main thread so four agents do not each re-grep the tree:

```bash
mkdir -p "${SESSION_TMP_DIR}"
find . \( -name '*.ts' -o -name '*.tsx' -o -name '*.vue' -o -name '*.js' -o -name '*.jsx' \) \
  -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/dist/*' -not -path '*/.output/*' \
  > "${SESSION_TMP_DIR}/source-files.txt"
find . -maxdepth 3 -type d -not -path '*/node_modules/*' -not -path '*/.git/*' | sort > "${SESSION_TMP_DIR}/dir-tree.txt"
for f in package.json pnpm-workspace.yaml nx.json turbo.json lerna.json tsconfig.json firebase.json; do
  [ -f "$f" ] && cp "$f" "${SESSION_TMP_DIR}/config-${f}"
done
wc -l < "${SESSION_TMP_DIR}/source-files.txt"
```

If `source-files.txt` is empty: write a minimal `CODEBASE-MAP.md` ("empty repository, N config files") and go to M4.

### M2 DIMENSIONS — Four `Explore` agents, one message

Four read-only `Explore` agents (haiku), all dispatched in one message, each writing its `map-*.md` verbatim as it returns. Dimension roster, prompts and caps: [references/main.md](references/main.md) §M2 DIMENSIONS.

### M3 GATE and SYNTHESIZE

```bash
MISSING=0
for d in technology architecture quality concerns; do
  [ -s "${SESSION_TMP_DIR}/map-$d.md" ] || { echo "MISSING: $d" >&2; MISSING=$((MISSING+1)); }
done
```

`MISSING ≥ 2` → abort with the list; a two-dimension map misleads. `MISSING == 1` after the retry → emit that section as `> not analyzed — dimension agent failed` rather than omitting it. Treat any `PARTIAL: true` marker inside a file as known-incomplete and carry its `MISSING:` items into Recommendations.

Then think across dimensions (this is the only place the main thread adds value beyond concatenation): high coverage on the wrong layer, an architecture that fights the stack, a concern that compounds an architectural gap. Write `CODEBASE-MAP.md` at the repo root:

```markdown
# Codebase Map — <project-name>

Generated: <ISO-8601> · blitz onboard · Overall: <score>/5

## Technology
<map-technology.md>
## Architecture
<map-architecture.md>
## Quality
<map-quality.md>
## Concerns
<map-concerns.md>
## Recommendations
1. [High] <cross-dimensional item — file paths, one line of why>
2. [Medium] …
3. [Low] …
```

Overall = Technology×0.2 + Architecture×0.3 + Quality×0.3 + Concerns×0.2 (rubric in [references/main.md](references/main.md) §Quality Scoring Rubric). Each Recommendation names a path; a recommendation without a path is dropped.

If `docs/plans/` or `docs/solutions/` is missing, say so in the report; do not create them in map mode (that is `plan`'s job on first run). If `.claude/settings.json` lacks `worktree.baseRef`, print the one-line suggestion from G3.

### M4 REPORT

```
Onboard Map Complete
  Dimensions: N/4   Files inventoried: N   Overall: n.n/5
  Concerns flagged: N   Recommendations: N
  Output: CODEBASE-MAP.md

  Next: /blitz:audit for findings as tasks, or /blitz:plan <slug>
        /blitz:doctor to confirm the harness is wired
```

Remove `${SESSION_TMP_DIR}/map-*.md`; keep the inventory files for a re-run.

If `CLAUDE.md` (or `AGENTS.md`) exists without a `## Testing` heading, append the G3 Testing block and say so in the report; if neither file exists, write `CLAUDE.md` with the stack line from `detect-stack.sh`, the three commands, and the block. Never rewrite existing sections.

---

## Final

Patch `working_on` to `done: <mode> <name|map>`, log `skill_end` with `detail: {status, summary}`. Never set `status` or `state` on the session record.

---

## Error Recovery

| Situation | Action |
|---|---|
| Naming convention undetectable | kebab-case files, PascalCase components, `*.test.ts` co-located |
| Framework undetectable in package mode | ask once; never guess a framework |
| File already exists at a planned path | ask skip/overwrite; never silently overwrite |
| Type-check fails on generated code | fix imports and types, ≤3 rounds, then partial report |
| No test runner in the workspace | scaffold `vitest.config.ts` for the package only; say so |
| Package manager unknown | pnpm; fall back to npm when pnpm is absent |
| `git init` refused or no git | report; skip the commit, keep the files |
| 2+ dimensions failed | abort per M3; never ship a half-map silently |
| 1 dimension failed after retry | placeholder section with the explicit not-analyzed line |
| `Agent` tool unavailable | run the four checklists sequentially on the main thread with the same caps |
