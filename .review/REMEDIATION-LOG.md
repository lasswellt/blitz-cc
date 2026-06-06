# Remediation Log — blitz v2.3.2

Scope: **highs only** (4 findings). Date: 2026-06-01. Committed on `main`.

Gates after each change: `claude plugin validate --strict` ✅ · `check-count-sync.sh` ✅ · `check-version-sync.sh` ✅ · `skill-frontmatter-validate.sh` ✅ · `agent-frontmatter-validate.sh` ✅.

## 1. `agent:orchestrator` initialPrompt (HIGH → resolved)
- **File:** `agents/orchestrator.md`
- Confirmed via docs (https://code.claude.com/docs/en/plugins-reference): supported plugin-agent fields are `name, description, model, effort, maxTurns, tools, disallowedTools, skills, memory, background, isolation`. `initialPrompt` is **not** supported → silently ignored → boot state-summary never fired.
- **Change:** removed `initialPrompt:` frontmatter; added `## 0. On session start (boot state-summary)` section to system-prompt body with the same logic (read HANDOFF.json ≤24h + activity-feed last 30 lines → one-line summary).

## 2. `review` ↔ `sprint-review` collision (HIGH → resolved)
- **Before:** review claimed `'review sprint N'`; sprint-review claimed `'check quality'`,`'run review'` — verbatim overlap, one-directional buried hand-off.
- **After:** review = per-change/pre-commit front door + explicit "for the full end-of-sprint 8-invariant gate use /blitz:sprint-review". sprint-review dropped `'check quality'`/`'run review'`, kept sprint-scoped triggers, added "for per-change review use /blitz:review".

## 3. `ship` ↔ `release` collision (HIGH → resolved)
- **Before:** both listed `'cut a release'`,`'release v1.X'` verbatim.
- **After:** ship keeps those (full gated chain) + boundary to release. release dropped the two shared triggers, kept `'publish release'`/`'tag and ship'`/`'rollback release'`/`'prepare changelog'`, added "for the full pre-release chain use /blitz:ship".

## 4. `audit` overload (HIGH → resolved)
- **Before:** `'security audit'` collided with dep-health (CVE scan).
- **After:** narrowed to `'source-code security audit'`; appended object-noun routing: codebase→audit, deps/CVEs→dep-health, Firestore/Vue/Pinia→code-doctor, cross-page UI→ui-audit, sprint→sprint-review, bare→ask.

## Med batch (2026-06-01) — 8 findings resolved

Gates after batch: `plugin validate --strict` ✅ · count-sync ✅ · version-sync ✅ · `validate-plugin-structure.sh` ✅ 284/0 · frontmatter lint ✅.

5. **Version-gating / no engine minimum (MED → resolved).** Docs confirm plugin.json has **no** `engines`/`compatibility` field (optional fields: displayName, version, description, author, homepage, repository, license, keywords, dependencies, defaultEnabled) — adding one fails `--strict`. Raising the 35 skill floors to 2.1.117 would falsify their true standalone requirement (they run on 2.1.71 via slash). **Fix:** surfaced the effective minimum in `plugin.json` `description` (recognized free-text field): ">=2.1.117 for orchestrator + recent hook events; /blitz:* skills on >=2.1.71; health >=2.1.152."
6. **Unquoted `${CLAUDE_PLUGIN_ROOT}` ×38 (MED → resolved).** Docs: shell-form hooks must wrap `"${CLAUDE_PLUGIN_ROOT}"`. Quoted all 38 `command` values in `hooks/hooks.json`. The repo's own `scripts/validate-plugin-structure.sh` assumed the unquoted form and broke — taught it to strip quotes before resolving (`script_only="${script_only//\"/}"`).
7. **`sprint` ↔ `implement` ↔ `sprint-dev` (MED → resolved).** sprint desc: "only full plan→implement→review cycle; for impl-only use /blitz:implement or /blitz:sprint-dev." implement marked thin router (identical to sprint-dev).
8. **`research`/`codebase-map`/`architect`/`audit` "analyze" (MED → resolved).** codebase-map desc: "structural/dep-graph → architect agent; quality/tech-debt → /blitz:audit."
9. **`browse` ↔ `ui-audit` "visual audit" (MED → resolved).** browse: 'visual audit' → 'visual smoke test' + "cross-page data → /blitz:ui-audit."
10. **Orphan agents `architect`, `doc-writer` (MED → resolved).** Added body `> Invocation:` notes documenting them as orchestrator-only freeform targets (not skill-wired by design; doc-gen/codebase-map use general-purpose dimension agents).

Files: `.claude-plugin/plugin.json`, `hooks/hooks.json`, `scripts/validate-plugin-structure.sh`, `skills/{sprint,implement,codebase-map,browse}/SKILL.md`, `agents/{architect,doc-writer}.md`.

## Low/info batch (2026-06-01) — all remaining findings resolved

Gates: `plugin validate --strict` ✅ · count-sync ✅ · version-sync ✅ · structure 284/0 ✅ · frontmatter + markdown-link lint ✅.

11. **`color` ×4 (LOW → resolved).** Removed `color:` from critic, design-critic, orchestrator, research-critic (strict allowlist conformance).
12. **`scheduling.md` orphan (LOW → resolved).** Linked from `skills/next` and `skills/code-sweep` (loop-capable skills).
13. **Worker-agent disambiguators (LOW → resolved).** reviewer: added "spawned by /blitz:review·sprint-review; Different from critic/review". test-writer: "spawned by /blitz:test-gen". doc-writer: "spawned via /blitz:doc-gen".
14. **Stop-hook (LOW → resolved).** Added "Stop — intentionally not wired" rationale section to `hooks/scripts/README.md`.
15. **External deps (INFO → resolved).** Documented Playwright MCP + Gemini CLI in `plugin.json` description (`dependencies` is plugin-only; can't hold external tools).
16. **Per-hook unquoted `${CLAUDE_PLUGIN_ROOT}` ×35 (LOW → resolved).** Already fixed by the med quoting batch.
17. **count-sync integrity (INFO → acknowledged).** Clean + CI-enforced; no action.
18. **Per-component version-gating twin (MED → resolved).** Same as med #5 — effective min surfaced in plugin.json description.

Files: `agents/{critic,design-critic,orchestrator,research-critic,reviewer,test-writer,doc-writer}.md`, `skills/{next,code-sweep}/SKILL.md`, `hooks/scripts/README.md`, `.claude-plugin/plugin.json`.

## Final state
**0 open findings.** All 4 high + 8 med + low/info resolved or acknowledged across 3 commits on `main`.
