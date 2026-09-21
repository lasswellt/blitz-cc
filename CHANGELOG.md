# Changelog

All notable changes to the blitz plugin are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Release process

Bump `.claude-plugin/plugin.json` (`version`, `description`) and `.claude-plugin/marketplace.json` (`version`) together, add a section here, and run `scripts/check-version-sync.sh` and `scripts/gen-catalog.sh --check` (no numeric inventory in prose; the catalog is generated). `/blitz:ship` does this.

## [Unreleased]

_Nothing yet._

## [3.8.0] — 2026-09-20 · impeccable can be installed once, globally

### Added
- **The semantic design lane accepts a global impeccable.** `scripts/design/preflight.sh` resolved impeccable only from the project under review, so every UI repo needed its own `npm i -D impeccable@2.3.2` before `check --only design` or `audit --pillar design` could run the semantic rows. It now falls back to a global install at the pin (`npm i -g impeccable@2.3.2`), and the status line records which copy it found: `semantic=OK source=project|global`. The project's own copy still wins, because it is the one `npx` runs; a global copy at the wrong version reports `VERSION_MISMATCH source=global` with a `-g` install hint.
- The registry rows needed no change: `npx impeccable detect` finds a global bin on `PATH`, verified from a project with no local copy.
- `BLITZ_IMPECCABLE_GLOBAL_ROOT` overrides the global `node_modules` directory (default `npm root -g`). The design-pillar suite points it at an empty directory, so a machine-wide install cannot satisfy cases that model a bare project, and three new cases cover global-at-pin, global-at-wrong-version, and project-beats-global.

### Changed
- **The "never global" rationale no longer held.** The recorded decision kept impeccable out of the plugin because its detector was "browser/puppeteer-class". In 2.3.2 puppeteer is an *optional* dependency used only for rendered-URL mode; the file-mode `detect` the registry rows invoke parses HTML/CSS with no browser, verified by running it with puppeteer's Chromium download blocked. It still never ships inside the plugin; a user opting in globally is a different thing from every plugin install dragging it along.
- `doctor` reports `INFO` only when preflight finds impeccable in neither place, instead of whenever the project's `devDependencies` lack it. `check` and `audit` references describe the two-place resolution.

### Notes
- Validators exit 0; `bats hooks/tests/` is 289/289.

## [3.7.1] — 2026-09-20 · an explicit critic flag beats ambient env

### Fixed
- **`critic-external.sh` let `BLITZ_CRITIC_PANEL` override an explicit `--provider`.** 3.7.0 resolved the provider list env-first, so once a panel was set globally in `settings.json` — the recommended way to enable it — every single-provider invocation silently became the full panel. That included `critic-gemini.sh`, which exists precisely to pin `--provider gemini`. Resolution is now flag-first: `--panel`, `--provider`, `BLITZ_CRITIC_PANEL`, `BLITZ_CRITIC_PROVIDER`, then `gemini`.
- **The critic test suite was not hermetic.** It passed in 3.7.0 only because the release was tested before the panel env existed on the machine. `setup()` now unsets the `BLITZ_CRITIC_*` selection variables, and a regression case pins `--provider copilot` under an ambient `BLITZ_CRITIC_PANEL=agy,copilot` and asserts a single-provider reply.

### Notes
- Found by running the suite with native bats after enabling the panel globally: the exact configuration 3.7.0 recommends. Validators exit 0; `bats hooks/tests/` is 286/286 with the panel env set.

## [3.7.0] — 2026-09-20 · the cross-model critic takes any model family

### Added
- **`hooks/scripts/critic-external.sh` — the Cross-Model Critic is provider-pluggable.** It was Gemini-only. It now hands the critic agent's body to any of three non-Claude CLIs and holds each to the same JSON reply contract and the same exit codes (0 LGTM, 2 REJECT, 1 failure):

  | Provider | CLI | Default model | Prompt delivery |
  |---|---|---|---|
  | `gemini` | Google Gemini CLI | `gemini-2.5-pro` | stdin |
  | `agy` | Antigravity | `gemini-3.1-pro-high` | argv, `--disable-slash-commands` |
  | `copilot` | GitHub Copilot CLI | `auto` | argv, no tools granted |

  Selection: `BLITZ_CRITIC_PROVIDER=<p>` replaces the in-Claude critic, `BLITZ_CRITIC_PANEL=agy,copilot` fans out to several, `BLITZ_DUAL_CRITIC=1` pairs in-Claude with the external one. `BLITZ_USE_GEMINI_CRITIC=1` keeps working as an alias for the gemini provider.
- **Panel rule: any REJECT blocks.** A blindspot only needs one family to catch it, so a single rejection fails the gate. A provider that cannot answer is recorded in `errors[]` and never decides the verdict alone; when *no* provider answers, the run exits 1 rather than reporting a clean gate. The merged reply carries `{verdict, rule, summary, issues, providers[], errors[]}`.
- **Per-provider configuration.** `BLITZ_<P>_BIN`, `BLITZ_<P>_MODEL` and `BLITZ_<P>_FLAGS` for `GEMINI`, `AGY` and `COPILOT`. Flags stay newline-split, never space-split — one env value must not be able to inject a second flag such as a system-prompt override that returns LGTM unconditionally.
- **An oversize prompt is handed over as a file.** Linux caps a single argv string at 128 KiB (`MAX_ARG_STRLEN`) and neither `agy` nor `copilot` reads the prompt from stdin, so a large diff would have died with `E2BIG`. Above `BLITZ_CRITIC_ARG_CAP` (default 100,000 bytes) the prompt is written to the run's temp dir and passed by reference with `--add-dir`.
- **`hooks/tests/critic-external.bats`** — 14 cases: per-provider verdict mapping, the argv contract for each CLI (copilot is never given `--allow-all-tools`; agy always gets `--disable-slash-commands`), flag-injection resistance, the oversize-prompt fallback, and all four panel outcomes.

### Changed
- **`critic-gemini.sh` is now a shim** that pins `critic-external.sh --provider gemini`. Its flags, env vars and exit codes are unchanged and its original test suite passes against it untouched.
- `agents/critic.md` §8, `agents/research-critic.md`, `agents/design-critic.md`, `skills/check` and the hook index describe provider selection rather than a Gemini path.

### Notes
- Verified live against both new CLIs, not only stubs: `agy` and `copilot` each rejected a function whose body contradicted its documented contract, and the panel merged both rejections with `rule: any-reject-blocks`.
- Validators all exit 0; `bats hooks/tests/` is 285/285.

## [3.6.0] — 2026-09-20 · two validators were wrong about valid input; README rewritten

### Fixed
- **`validate-plugin-structure.sh` rejected every workflow script.** It ran `node --check` on `workflows/*.js` raw. A workflow legally uses top-level `await` and top-level `return` because the runtime evaluates it inside an async wrapper, so node — treating the file as a module on the strength of its `export` — failed all three with `Illegal return statement`. The check now parses the wrapped form and quotes node's error when it genuinely fails. Stripping `export` alone is not enough: that fixes `return` and then trips on `await`.
- **`gen-catalog.sh` truncated descriptions with `cut -c1-240`, which counts bytes.** It sliced the em dash in `test-writer`'s description in half. The mangled bytes were already committed in `docs/CATALOG.md`, so `--check` reported a staleness that regenerating could never resolve — the buggy generator reproduced it every run. Truncation is by character now, and the catalog is regenerated.

### Changed
- **README rewritten.** It opens with the failure mode the plugin exists to prevent — an agent reporting success it did not earn — and states the four invariants that replace self-report with structure, each next to the thing that enforces it. The enforcement layer is now organised by hook event rather than by guard name, the `next` decision rows are stated in full, and the shared-protocol section documents the `.reference.md` split. No behaviour changed.
- **`marketplace.json` still described the plugin as Vue/Nuxt/Firebase-only.** `plugin.json` was repositioned as language-agnostic in 3.x and the marketplace entry was never updated, so the storefront copy contradicted the toolchain table. Both descriptions now lead with the polyglot loop and mention the Vue/Nuxt/Firebase lanes as depth on top.

### Notes
- Validators and the bats suite are green on this release: all six exit 0, `bats hooks/tests/` is 271/271.

## [3.5.1] — 2026-09-20 · reconcile the three token measurements

### Fixed
- Six `references/main.md` files carried 2–3 duplicate `## Moved from SKILL.md` headings, one per run of the section mover. Consolidated, and `check-section-refs.sh` now fails on a repeat so it cannot happen a third time.

### Notes
- **Three distinct loads were being reported as one number.** A skill invocation costs differently depending on what it reaches for, and the three do not move together:

  | | `/blitz:build` | `/blitz:check` | Governs |
  |---|---|---|---|
  | Post-compaction re-attach (body only, **hard cap 5,000**) | **3,569 tok** | **3,475 tok** | Whether the skill keeps its verdict, gate and report after a summary |
  | Typical (skill + the protocol contracts it names) | 13,652 | 7,658 | What a normal invocation costs |
  | Worst (+ its own `references/main.md`) | 20,176 | 15,889 | An invocation that opens every link |

  The audit's Phase 2 target was written against the **worst** column, which moving body content into `references/` cannot improve — the bytes are relocated inside the same sum. That move is exactly what fixes the re-attach cap, the only column the platform actually enforces. 3.4.0 and 3.5.0 optimised the first column while the third was being quoted, which is why `check` looked like it regressed from 14,138 to 16,025 tokens while its real truncation risk halved. Recorded in the audit with the full reconciliation.

## [3.5.0] — 2026-09-20 · measure tokens properly; the 3.4.0 cap was unsafe

3.4.0 claimed six skill bodies now fit the 5,000-token compaction cap. The claim rested on a bytes÷4 estimate, and bytes÷4 is wrong in the unsafe direction for this content.

### Fixed
- **The 18,000-byte cap assumed 4.0 bytes/token and was therefore too loose.** For Claude, English prose runs ~3.6–4.0 B/tok; markdown dense with tables, code blocks, paths and CLI flags runs ~3.0–3.5. A body is safe only while Claude's real ratio stays **above** `body_bytes / 5000`. After 3.4.0 the worst crossover was **3.50 B/tok** (`audit`), meaning eight skills were still over the cap under any plausible dense-markdown ratio. The cap is now **15,000 B** (5,000 tokens at 3.0 B/tok, the pessimistic floor) and nine skills were cut further. Worst crossover is now **2.98 B/tok**.

  | Skill | 3.4.0 crossover | now |
  |---|---|---|
  | `audit` | 3.50 B/tok | **2.81** |
  | `onboard` | 3.49 | **2.63** |
  | `ui-build` | 3.46 | **2.28** |
  | `research` | 3.42 | **2.98** |
  | `check` | 3.40 | **2.78** |
  | `next` | 3.31 | **2.73** |
  | `doctor` | 3.25 | **2.98** |
  | `build` | 3.22 | **2.86** |
  | `plan` | 2.99 | **2.73** |

  Verbatim as before: 15 more sections moved into `references/`, and a line-level check confirms nothing was lost.
- Five relative paths broke in the move: three self-links to `references/main.md` from inside it, one `../../docs/…` that reaches `skills/` rather than the repo root from one level deeper, and one sibling addressed as `references/x.md` from inside `references/`. `check-section-refs.sh` now names the whole class rather than the instances.

### Added
- **`scripts/count-tokens.sh`** — authoritative counts via `messages.count_tokens`, the only accurate counter for Claude (counts are model-specific). Caches by content hash in `.cc-sessions/token-counts.json` so unchanged files cost nothing. `--calibrate` prints measured bytes-per-token and the safe cap at the worst observed ratio, which is how the 15,000 B proxy should eventually be replaced with a measurement. Exits 3 with byte estimates clearly marked `UNVERIFIED` when no credential is available, rather than silently degrading.
- CI runs the real count when `ANTHROPIC_API_KEY` is present and skips otherwise, so forks are not broken by a missing secret.
- Four tests: the byte cap, a crossover assertion (no skill may depend on a ratio at or above 3.0), the credential-absent behaviour of the counter, and a guard that **no local BPE tokenizer is ever used**.

### Notes
- **`tiktoken` and `gpt-tokenizer` are prohibited, not merely discouraged.** They are OpenAI's tokenizer and undercount Claude by ~15–20% on prose and by more on code — exactly the content measured here. Anthropic publishes no offline tokenizer for current models, so an exact count requires a credential and a network call; everything else in this repo is a calibrated proxy and is labelled as one. The guard test matches *use* (`import`, `require`, a dependency entry), not mention, so the prohibition can be documented in prose.
- The token figures in this repository remain **unverified estimates** until someone runs `scripts/count-tokens.sh --calibrate` with a credential. The margins above are derived from a pessimistic assumed ratio, not measurement.

## [3.4.0] — 2026-09-19 · skill bodies fit the compaction budget

Six skills were silently truncated after every compaction. Validation passed the whole time, because the guard measured the wrong thing.

### Fixed
- **The skill-body cap was a line count, and lines are not what the platform measures.** `check` passed the 500-line rule at 295 lines while being 40% over the limit that actually bites. After auto-compaction Claude Code re-attaches the most recent invocation of each skill keeping only the **first 5,000 tokens** of each, sharing a 25,000-token budget across them. Six bodies exceeded it, and because markdown puts terminal phases last, what was being cut was the ending: `check` lost **Phase 5 VERDICT AND REPORT**, `build` lost the **Gate, Recovery and Report**, `doctor` lost `--fix` and REPORT, `audit` lost all of Phase 3, `research` lost citation validation and REPORT. Exactly what a long session needs, and a long session is when compaction fires. This is the failure mode [security.md](skills/_shared/security.md) already cites: constraints dropped by summarization are violated 30–59% of the time.

  | Skill | Before | After | Cut |
  |---|---|---|---|
  | `audit` | 6,975 tok | **4,370** | −37% |
  | `check` | 6,973 | **4,248** | −39% |
  | `doctor` | 6,270 | **4,059** | −35% |
  | `build` | 6,230 | **4,025** | −35% |
  | `research` | 5,961 | **4,280** | −28% |
  | `next` | 4,898 | **4,142** | −15% |

  **These figures are bytes÷4 estimates, not measured token counts, and 3.5.0 shows the margin they implied was not real.**

  Every terminal phase now sits between ~2,840 and ~4,172 tokens, comfortably inside the cut point. The restructure is verbatim: 22 sections moved into `references/`, each replaced by a contract summary and a pointer at its original position, and a line-level check confirms nothing was lost from any of the six.

- Six links in `references/main.md` files resolved to `references/references/main.md`. They arrived with the moved sections, where the relative path had been correct.

### Changed
- `skill-frontmatter-validate.sh` check 8 is now a byte budget (18,000 B ≈ 4,500 tok, `BLITZ_SKILL_BODY_CAP`) instead of a 500-line cap, with headroom because table- and code-dense markdown tokenizes nearer 3.5 bytes/token than 4, so the estimate understates. The failure message names the remedy: move mid-body detail out, keep the closing phases in.
- `check-section-refs.sh` gains a self-link rule: a file linking to itself by its own basename is what a section move leaves behind.

### Added
- Two tests: every `SKILL.md` body under the cap, and the closing sections specifically inside the 5,000-token cut point. The second matters more — "under the cap" does not by itself guarantee the ending survives.

## [3.3.3] — 2026-09-19 · reference integrity + the polyglot eval

A sweep of what none of the earlier passes had looked at.

### Fixed
- **30 section citations stopped resolving when the protocols split.** The head/reference split moved sections between files, and `agents.md §3`, `security.md §5`, `sessions.md §9` and 27 more kept naming the head after their section had moved. `markdown-link-validate.sh` passed the whole time, because in every case the *link* resolved and only the `§N` beside it was wrong. Retargeted across 10 skills, 5 agents and one workflow, plus 14 bare `(§N)` self-references inside the heads.
- **Markdown links injected into a fenced ASCII tree** in `sessions.md`, where they do not render and wreck the alignment. Now plain `(reference §9)` prose.
- Two protocol heads had drifted over their byte caps (`loop.md` 9,559 B, `agents.md` 8,233 B) from content this release cycle added. The cap did its job and blocked the commit; the detail moved to the references rather than the caps moving.

### Added
- **`scripts/check-section-refs.sh`** — asserts every `§N` citation resolves in the file it names, catches the `)§44.1` / `)§RatchetRatchet` doubling signature, and flags a protocol link inside a fenced block. Wired into CI and `pre-commit-validate.sh`. Three separate rounds of this class of breakage shipped past link validation; it needed its own check. Deliberately narrow on the fenced-link rule: a fence often holds a *template of output a skill writes*, where markdown links are correct, so only `_shared` protocol links are flagged.
- **`evals/polyglot-ratchet`** — the eval suite's 8th case and the first that is not Node-shaped. A Python + Rust repo with **no `package.json`** and a real type error in each language. Graders assert the toolchain resolver ran, that `npm`/`npx`/`tsc`/`eslint` were **not** run against a repo with no Node project, and that both diagnostics were reported rather than fixed. Every previous eval would have passed while the loop silently regressed to Node-only.

## [3.3.2] — 2026-09-19 · acceptance-criteria pass

A criterion-by-criterion re-test of the migration plan. Phases 0, 1, 3, 4 and 5 now pass on evidence; Phase 2's numeric targets do not, and the reason is recorded rather than engineered around.

### Fixed
- **37 mangled section citations across 12 files**, shipped in 3.2.0. The mechanical link retarget emitted its capture group twice and swallowed the preceding space, producing `)§44.1` where `) §4.1` was meant, and `)§RatchetRatchet` for `) §Ratchet`. Link validation passed throughout, because the link resolved and only the trailing prose was wrong. `markdown-link-validate.sh` now fails on the pattern, with a mutation test proving the guard fires.
- **The spawn prompt never actually shrank.** 3.2.0 moved the invariant spec into `SubagentStart` and left the same content pasted in `build/references/main.md`, so every spawn carried it twice. The template now holds only each item's variable half (the project's own never-edit additions, the `--parallel` branch line): **3,928 → 1,917 bytes, a 51% cut**, with the standing 4.7 KB arriving from the hook identically every time. The package-install rule moved into the invariant with it.
- `security.md` head compacted from 11,286 to 6,108 bytes: one rule row per trust boundary, with each boundary's enforcement detail moved to the reference. Lossless, checked line by line.

### Added
- **`tasks.sh verify <plan> --changed <paths>`** — selective post-merge re-verify, the Phase 5 acceptance criterion, which did not exist. After a parallel wave merges, it re-runs only the `done` tasks whose `files[]` the merged paths touch. A clean textual merge is not a semantic one, and `git merge-tree` cannot see the difference. A failing task is demoted to `in_progress` and enters the fix queue; untouched tasks are not re-run. Verified end to end on a mixed Rust + Python two-branch wave: both touched tasks re-verified with their own checkers, the third skipped, and a break planted after the merge correctly caught and demoted.
- 9 tests: 5 for `verify --changed` (selection, prefix matching in both directions, the caught-break case, the no-op case, the usage error) and 4 for whole-project lane behaviour.

### Notes
- **Phase 2's ≤12K/≤14K targets are not met** (`build` 16,313, `check` 15,036). They were written before the work and conflated the protocol load F-06 measured with the skill body it never touched. On F-06's actual subject the five protocols `build` loads went **32,631 → 9,892 tokens, a 69% cut**; `build/SKILL.md` alone is 6,421 tokens, so ≤12K would leave ~4.5 KB per protocol contract. Hitting the number means cutting contract content skills obey. Recorded in the audit rather than engineered around.

## [3.3.1] — 2026-09-19 · close the gaps the audit's own implementation left

A completeness pass over 3.0.2–3.3.0 found six things the migration claimed but had not actually wired.

### Fixed
- **`check`'s own gates were still Node-only.** The gate table hardcoded `npm run type-check`/`npx tsc`, `npm run lint`/`npx eslint` and `npm run build`. 3.1.0 made the *hooks* language-agnostic and left the *gate* behind, so a Python or Rust repo ran the full check pipeline with three empty gates. Gates now come from the toolchain table and run once per detected stack. A lane with no row is recorded `skipped` with its reason, never as a pass.
- **`README.md` still sold the plugin as "tuned for Vue/Nuxt + Firebase"** in its tagline and a `Supported Stacks` table listing only Vue, Quasar, Vuetify, Firebase, Pinia and VueFire. 3.1.0 rewrote `plugin.json` and left the README, which is the larger storefront. Replaced with the real stack matrix, the `.blitz-toolchain.json` override (documented user-facing for the first time), and the LSP section. The Vue/Nuxt/Firebase support is still there and still real; it is now described as the framework-specific extras it is, tagged `stacks: ["node"]` and skipped elsewhere.
- **The LSP capability was inert.** 3.1.0 shipped `.lsp.json` and the `LSP` tool but no skill told Claude to prefer it. `research` Phase 2 and `onboard`'s map dimensions now carry the preference ladder: workspace symbol search → `goToDefinition` → `findReferences` first, `Grep`/`Glob` + `Read --offset` as the fallback when the tool is inactive, including in cloud sessions where Claude Code does not start plugin language servers at all.
- **`det-11`/`det-12` referenced `${BLITZ_PROBE_FILE}`, which was set nowhere.** They happened to work by accident: an empty file argument matched any row. A bare `toolchain.sh run <lane>` now explicitly means "every detected stack's tool", which is what a whole-project check wants in a polyglot repo, and a test asserts no registry row references an undefined variable.
- **Whole-project lanes were attributed to the wrong stack.** `test` and `build` rows match any extension, so without a stack filter the first stack in table order won every lookup and a Rust repo's test lane resolved to `pytest`. `resolve` takes an optional stack, and `lanes`/`run` use it.
- The deterministic check lane now actually dispatches to `haiku`. 3.2.0 added the routing-matrix row and never wired it into `check` Phase 1, which also now reads each row's verdict through its `detection.exit` contract instead of "non-zero means fail".

### Added
- `test` and `build` lanes in the toolchain table (15 rows across 9 stacks), so the full gate set is data-driven, not just format/lint/typecheck.
- Four tests covering stack attribution, the stack filter, whole-project runs, and the undefined-variable regression.

## [3.3.0] — 2026-09-19 · gate evidence + exit-code contract

Audit: [docs/reviews/2026-09-19_agentic-architecture-audit/README.md](docs/reviews/2026-09-19_agentic-architecture-audit/README.md) §7 (F-14).

### Added
- **Per-command verify evidence.** `tasks.sh verify` records `last_verify.runs[]`: one entry per command that actually ran, with `cmd`, `exit`, `duration_ms`, `tail` (capped at 2 KB via `BLITZ_VERIFY_EVIDENCE_CAP`) and `recorded_at`. Before this the record held only the first failing command's 200-char tail, so a reviewer had to re-run the suite to see what a verdict rested on. This is what makes `cannot_verify` a defensible reviewer answer rather than a shrug.
- **An exit-code contract per deterministic registry row.** "Non-zero means fail" is wrong for most of them: a `grep` detector **passes** when it finds nothing, which is exit 1, and a row ending in `wc -l` always exits 0 so its verdict is the number it prints. Each row now carries `detection.exit`: `{"pass":[0],…}` for a command, `{"pass":[1],…}` for a grep-family tail, or `{"verdict":"stdout"}` for a counter. `det-17` and `det-18` describe operational signals rather than commands and carry no contract. `error` is reported distinctly from `finding`: a detector that cannot run is unknown, and scoring it clean is how a lane goes green on a machine missing the tool.
- `docs/plans/<slug>/check-report.json` (schema `blitz-check-report/1.0`): the machine-readable sibling of `check-report.md`, with per-lane `selected`/`ran`/`pass`/`finding`/`error` counts, the project's `stacks`, findings, `cannot_verify[]`, the critic verdict and task tallies, so CI and evals assert on a run without parsing prose.

### Notes
- F-14 (consolidating the six `Bash` PreToolUse guards) is **closed without change**. The audit flagged the fan-out as unmeasured; measured, all eight guards on one non-`git commit` Bash call cost ~156 ms total, about 20 ms each. That does not justify refactoring eight independently tested guards into one dispatcher, and the early-exit paths are already in place.

## [3.2.0] — 2026-09-19 · token economics + cache routing

Audit: [docs/reviews/2026-09-19_agentic-architecture-audit/README.md](docs/reviews/2026-09-19_agentic-architecture-audit/README.md) §5 (F-06, F-12, F-13, F-15).

### Changed
- **The six shared protocols split into a contract head and an on-demand reference.** They totalled 141 KB, and one `/blitz:build` that followed its own cross-references pulled ~41.5K tokens of protocol before reading a line of project code — 20% of the window. Each `skills/_shared/<name>.md` now holds only what every consumer must obey and links `<name>.reference.md` for the rest. The split is verbatim: no content was rewritten or dropped, and a line-level check confirms every original line still exists.

  | Path | Before | After |
  |---|---|---|
  | `/blitz:build` protocol load | 41,571 tok | **19,154 tok** |
  | `/blitz:check` protocol load | 47,296 tok | **14,138 tok** |
  | Six protocol heads | 141,238 B | **50,925 B** |

- `check-registry.json` is queried, never read. The selection contract in [quality.reference.md](skills/_shared/quality.reference.md) now carries a `jq` selector returning only the ids and commands a run needs, instead of pulling 98 KB (~24K tokens) into context to obtain a handful of rows. The selector also drops rows whose `stacks[]` does not match the project, so a Go repository runs 34 of 97 rows rather than all of them.
- `pre-commit-validate.sh` enforces a byte cap per protocol head and blocks a commit that regrows one, with the remedy in the message. Without it the heads drift back.

### Added
- `skills/_shared/spawn-invariant.md` and `hooks/scripts/subagent-context.sh`: the invariant half of the `dev`/`test-writer` spawn spec (never-edit list, reply contract and status enum, commit format, output style, stop conditions, mock policy) now arrives through `SubagentStart.additionalContext` instead of being pasted into every prompt. The platform states the injected copy stays in place and leaves the subagent's prompt cache intact, re-injecting only after the subagent's own auto-compaction. The rule it encodes: anything that varies per call goes in the prompt, anything that does not goes in `additionalContext`. A test asserts the block is byte-identical across spawns, because a timestamp or session id in there would defeat the point.
- `experimental.cacheTtl: 1h` on `critic`, `design-critic` and `research-critic`. Subagents fall outside the main-conversation TTL bucket and get five minutes by default, so a critic re-spawned per fix round paid a cold prefix from round 2 on. All five blitz agents now set it, and a test keeps it that way.
- Model routing gains a deterministic-lane row: running a registry row's `detection.command` and reporting `{id, exit_code, stderr_head}` is bookkeeping, so it routes to `haiku`; the semantic lane and the verdict stay on the session model.
- `skill-frontmatter-validate.sh` rule 11: a skill that pins `model:` must disclose the cost in its body. A pinned model makes that turn a model switch with zero cache hits across the whole conversation, which can be the right trade for a rare slash-only skill but must be a stated decision. `ship` already disclosed it; `migrate` did not, and now does.

## [3.1.0] — 2026-09-19 · language agnosticism + code intelligence

Audit: [docs/reviews/2026-09-19_agentic-architecture-audit/README.md](docs/reviews/2026-09-19_agentic-architecture-audit/README.md) §6 (F-07…F-11, F-15).

### Fixed
- **The type-error ratchet was a silent no-op outside TypeScript.** `post-edit-typecheck-block.sh` opened with `[[ -f tsconfig.json ]] || exit 0`, so the plugin's headline anti-regression mechanism did nothing in Python, Rust, Go, JVM, Ruby or .NET repositories. It now resolves the project's checker from the toolchain table and ratchets its diagnostic count. Verified blocking a `mypy` regression and a `cargo check` regression.
- **Formatting and linting were JS-only.** `post-edit-format.sh` carried the extension allowlist `ts|tsx|js|jsx|vue|css|scss|json|md|html|ya?ml` and hardcoded prettier/biome/eslint detection across 199 lines. It is now 45 lines that ask the toolchain table and run what comes back.
- **The anti-shortcut test guards only understood JS test names.** `block-test-disabling.sh` and `block-test-deletion.sh` scoped themselves to `*.test.*` / `*.spec.*`, so `@pytest.mark.skip`, `t.Skip(`, `#[ignore]`, `@Disabled` and `[Ignore]` passed unchallenged, as did deleting `test_auth.py` or `auth_test.go`. Both now recognise the naming conventions of Python, Go, Rust, Ruby, JVM, .NET, Elixir and PHP, and the `blitz:skip-pinned:` escape hatch is accepted behind `#`, `--` and `;` comment openers as well as `//`.
- **The first edit in any repo with pre-existing diagnostics was blocked.** The baseline read defaulted to `0` rather than "no floor recorded", so the ratchet refused work over errors the edit did not cause. It now records the floor on first run and blocks only on a genuine increase.
- **Only the first marker of each stack was ever tested.** The detector joined a stack's markers with a newline inside a line-based read loop, so a Python project identified by `setup.cfg` rather than `pyproject.toml` went undetected. Detection now iterates one line per (stack, marker) pair.
- Registry rows carried JS-only patterns under universal ids: `det-11`/`det-12` shelled out to `npx tsc` and now delegate to the toolchain typecheck lane; `det-03` recognises `unittest.mock`/`@patch`/`Mockito`/`mockall`/`gomock`; `det-09` recognises `raise NotImplementedError`/`unimplemented!`/`todo!`; `det-01`, `det-13` and `det-14` scan `test_*.py`, `*_test.go`, `*_test.rs`, `*_spec.rb`, `*Test.java` and `*Tests.cs` alongside the JS globs.
- `plugin.json` described the plugin as "Agentic development loop for Vue/Nuxt + Firebase" in a 1,421-character block, and led its keywords with `vue`, `nuxt`, `firebase`. Now 506 characters, loop-first, polyglot keywords.

### Added
- `templates/toolchain.default.json` (schema `blitz-toolchain/1.0`) and `scripts/toolchain.sh`: 11 stacks and 34 rows across the `format`, `lint` and `typecheck` lanes. Rows are data and the script is the only executor, so adding a language means adding rows, never adding a script. A row is used only when its stack marker is present, its `when`/`whenDep` config exists, and its `probe` command succeeds, so a missing tool is a silent skip rather than a failure.
- `.blitz-toolchain.json` lets a project `disable` rows or `prefer` an order. It may **not** supply a `cmd`: per [security.md](skills/_shared/security.md) TB-1 the checkout is untrusted inbound data, and an argv read from repo content would be arbitrary execution on every edit. A test asserts a `cmd` planted there is ignored.
- `.cc-sessions/typecheck-baseline.json` is schema 2, keyed by toolchain row id, so a polyglot repo ratchets each language independently and a Python edit cannot reset the TypeScript floor. Schema-1 files migrate on first write.
- `stacks[]` on all 97 check-registry rows (`["*"]` or `["node"]`), so `check` can select rows that apply to the project instead of running Vue/Firestore and `npx impeccable` detectors everywhere.
- `detect-stack.sh` reports `Language stacks` and `Toolchain lanes` computed fresh on every call (the 1 h cache covers only the Node design-adapter profile), and recognises Cargo/Go workspaces, Maven, Gradle, uv, poetry, pipenv, bundler, composer, pytest, cargo test and go test.
- **LSP servers.** `.lsp.json` + `lspServers` in the manifest configure TypeScript, Python, Rust and Go language servers, giving Claude the `LSP` tool: `goToDefinition`, `findReferences`, hover types and workspace symbol search instead of grep-and-read-the-whole-file. Each server's binary is a `userConfig` option, so it can be pointed at a custom path or cleared to yield to another plugin's server. Two caveats are documented in `doctor` D-317: Claude Code does not start plugin language servers in cloud sessions, and when two enabled servers declare the same extension the first registered wins.
- `doctor` §3.9: **D-316** (every detected stack resolves a `typecheck` row, else it has no ratchet) and **D-317** (language-server binaries on `PATH`).
- `hooks/tests/toolchain.bats`: 20 tests covering stack detection, row resolution and its gates, the override schema and its security boundary, the per-lane ratchet across first run / regression / recovery, and the test guards under Python, Go and Rust.

## [3.0.2] — 2026-09-19 · worktree contract fix

Audit: [docs/reviews/2026-09-19_agentic-architecture-audit/README.md](docs/reviews/2026-09-19_agentic-architecture-audit/README.md).

### Fixed
- **Installing blitz broke git worktrees in the consumer's project (P0).** `hooks.json` registered a `WorktreeCreate` hook whose handler only logged. Per the platform contract, configuring `WorktreeCreate` *replaces* git worktree creation entirely, the hook must print the created directory to stdout, and "if the hook fails or produces no path, worktree creation fails with an error". The handler printed nothing and created nothing, so `claude --worktree`, every `isolation: worktree` subagent (including `build --parallel` waves), and background-session isolation all failed wherever blitz was installed. A registered hook also made the platform skip `.worktreeinclude`, so gitignored `.env` files stopped reaching worktrees. The registration and `hooks/scripts/worktree-create.sh` are removed; blitz registers no `WorktreeCreate` hook.
- The removed handler read `worktree_path` and `branch` from the event payload. Neither field exists on `WorktreeCreate` (its only event-specific field is `name`), so the stale-branch collision guard was unreachable and had never fired.
- `agents.md` §6 documented the contract inverted on both events: it claimed `WorktreeCreate` hooks merely "abort creation or override the path", and that `WorktreeRemove` exit codes are ignored. A non-zero `WorktreeRemove` exit fails the removal when the directory still exists; `worktree-remove.sh` always exits 0 and its branch cleanup is best-effort.

### Added
- `doctor` §3.8: **D-314** (no `worktree-agent-*` / `worktree-build-*` branch ahead of `origin/HEAD`, no foreign `WorktreeCreate` hook in project settings) and **D-315** (`.worktreeinclude` present when the repo has gitignored `.env*` or secrets files, `fix:auto`). This is where the removed collision guard now runs, as a pre-flight rather than a creation veto.
- `build` Phase 0.4 refuses `--parallel` on a stale agent branch or a foreign `WorktreeCreate` hook and falls back to sequential with the reason printed.
- `hooks/tests/worktree.bats`: 7 tests keeping `WorktreeCreate` deregistered, asserting `worktree-remove.sh` never exits non-zero, and failing if any hook script reads a `WorktreeCreate` payload. The event had no test coverage before, which is how the P0 shipped.
- `hooks/scripts/README.md` records the events blitz deliberately does not register, with the contract that makes each one unsafe to observe.

## [3.0.1] — 2026-09-19 · validation round

Review: [docs/reviews/2026-09-19_v3-agentic-restructure/README.md](docs/reviews/2026-09-19_v3-agentic-restructure/README.md) §7. Platform claims re-fetched from code.claude.com (2.1.277), field evidence from June to September 2026 re-checked, and a contract audit across scripts, skills, agents, workflows, and evals.

### Fixed
- **The loop did not run as documented.** `workflows/build-wave.js` required `{agents, storySchema}` while every caller passes `{plan, wave, tasks, replySchema}`, so every `build --parallel` Workflow dispatch threw; `next --loop` never set `BLITZ_AUTONOMOUS` or passed `--autonomous`, so `build` stopped at the first task boundary. Both fixed; `hooks/tests/workflows.bats` loads every workflow against the documented args shape.
- The Stop-hook block cap is 5 (`stopHookBlockCap`), not 8: `max_blocks` defaults to 4 and is clamped there, so the gate exhausts and logs before the platform stops honoring it.
- `tasks.sh set … status=open` was re-blocked by the circuit breaker; the breaker is skipped when the same call sets `status` or `blocked_reason`, and the documented recipe is `status=open attempts=0`. `add` validates `--origin`.
- `next-state.sh` orders active plans by `priority`, then `created`, then slug (the prose said so; the code sorted by slug) and emits `plan_priority` on every row. `loop.md` names `sessions_waiting`, an object `next_task`, `init`/`next`/`list --json`, `cmd::<seconds>`, `attempts=+1`, and the kill switch on row 0, matching the scripts.
- `startup-validate.sh` flags an empty `verify[]`; `session-start.sh` re-pins the gate path, never-edit list, and mock policy on compaction resume (Governance Decay: constraints dropped by summarization are violated 30–59% of the time).
- `check --fix` arms lint with `--max-warnings=0` in both sites; `check` states the `MODE:`/`PLAN:`/`TASKS:`/`BASE:` header lines the critic requires; the registry no longer targets `quality-metrics` or `SPRINT_BASE`; every skill declares `compatibility: ">=2.1.271"`; feed events use `skill_end`; research citations point at `docs/research/`.
- Eval suite: an unquoted `description:` containing `": "` made the runner refuse the whole suite (now caught by `validate-plugin-structure.sh`); `tool_used: Skill` graders removed from slash-prompt cases.

### Added
- `critic --mode reject` authors one held-out check per task from `spec.md` (never from `verify[]`), runs it, and REJECTs on failure; `check-report.md` records them. Registry row `check:test-tamper` (deterministic, P1) flags deleted or trivialized assertions, snapshot rewrites, `.skip`/`.only` insertions, and a falling assertion count in the diff's test files.
- `critic --mode survey` may answer `cannot_verify[]`; `check` runs the command or records a `Ruling:` before the gate.
- `onboard` writes a `## Testing` block into `CLAUDE.md` (or `AGENTS.md`, which 2.1.277 reads when `CLAUDE.md` is absent): mock only true externals, never `src/`, emulators for Firebase, done means `tasks.sh verify`.
- `security.md` names Plugin4Shell (disclosed 2026-09-18, fixed in 2.1.179), the GitHub-hosted marketplace, `--accept-command`, and npm integrity verification; `compat.json` records the floors.

### Changed
- Review doc: contradiction register corrected (skill listing truncates `description` + `when_to_use` at 1,536 chars per skill; `/init` and `/security-review` are Skill-tool invokable; `/verify` is slash-only and replaced at the repo root by its recorded recipe; `.claude/loop.md` confirmed with its 25 KB cap); the unverifiable "95% of tasks" quote is withdrawn in favor of the docs' qualified 7× figure; evidence table carries the June to September 2026 sources; a "not adopted" list records what was considered.
- First live eval run: `tasks-guard` 1.0. Bash-granting cases need the OS sandbox.

## [3.0.0] — 2026-09-19 · agentic restructure

Review: [docs/reviews/2026-09-19_v3-agentic-restructure/README.md](docs/reviews/2026-09-19_v3-agentic-restructure/README.md). The plugin drops its sprint layer (sprints, stories, epics, roadmaps, retrospectives, the carry-forward registry, story points, the deviation tiers, LLM-executed locks) and keeps the agentic harness: guards, gates, registry, critics, sessions, the loop. Breaking: no compatibility aliases; `/blitz:doctor --migrate` converts a project's `sprints/` and carry-forward state into `docs/plans/`.

### Added
- **The loop:** `plan` (spike / bounded / architectural classification, interview unless `--autonomous`, reads `docs/solutions/` and `docs/plans/BACKLOG.md`, verify templates per stack), `build` (inline path for a one-sentence change; one fresh-context `dev` per task; fix rounds ≤3 then a fresh opus agent; circuit breaker at three attempts; `--parallel` waves over disjoint files with a `git merge-tree` pre-check; `--issue N`), `check` (gates, TIA, anti-mock, `tasks.sh verify` per task, critic survey then adversarial reject; `--fix`, `--comment`, `--security`, `--mutation`), `learn` (rulings, check reports, and `Task:` commits → `docs/solutions/`), `next` rewritten over a deterministic `scripts/next-state.sh` with six rows and a headless-safe `--loop`.
- **Structural done:** `docs/plans/<slug>/tasks.json` (`blitz-tasks/1.0`) written only by `scripts/tasks.sh` (`init|add|list|set|verify|next`; refuses empty or test-only `verify[]`); `hooks/scripts/tasks-guard.sh` denies Write, Edit, and shell writes to it; `startup-validate.sh` schema-checks and injection-scans `tasks.json` and `docs/solutions/` (OWASP ASI06).
- **Kill switch:** `.cc-sessions/STOP` makes `kill-switch.sh` deny every tool call.
- **Generated catalog:** `scripts/gen-catalog.sh` writes `docs/CATALOG.md` and `--check` fails CI on a stale catalog, a dead `/blitz:<name>` reference, or a numeric inventory claim. `scripts/gen-review-md.sh` exports registry P0/P1 rows as `REVIEW.md`.
- **doctor** (health + setup + conform): checks `worktree.baseRef`, Task-tools absence, bash on Windows, `subagentPromptCacheTtl`, `crossSessionInbound`; writers `--loop-md`, `--review-md`, `--ci` (`templates/blitz-check.yml`, a `claude-code-action` workflow that runs `/blitz:check --scope diff --comment`); `--migrate`.
- Agents `dev` (role by prompt, never-edit list, status enum `DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED`) and `critic --mode reject|survey`. Protocols `loop.md`, `sessions.md`, `agents.md`, `quality.md`, `output.md`. `skills/test-gen/references/deterministic-tests.md` with a mocking policy. Evals `build-inline`, `check-gate`, `tasks-guard`. bats suites `tasks`, `next-state`, `tasks-guard`, `kill-switch`.

### Changed
- `PreCompact` HANDOFF carries plan, task, gate path, and the never-edit list; `session-start` prints them.
- Command guards match `Bash|PowerShell`; `post-edit-format.sh` absorbs lint; validators forbid Task tools in `allowed-tools`/`tools`, drop the OUTPUT STYLE snippet check, and cap cumulative skill descriptions at 8 000 chars (descriptions ≤300, triggers first, `name` equals the directory).
- `check-registry.json`: owners and targets name `check`/`build`; `o2-anti-mock` → `check:anti-mock`, `o3-wiring` → `build:integration`.
- `workflows/sprint-wave.js` → `build-wave.js` (agent `blitz:dev`); `review-fanout.js` takes `lenses` and `surveySchema`.
- `.gitignore` no longer lists `sprints/`, `docs/roadmap/`, `docs/retrospective/`, `docs/metrics/`, `docs/sweeps/`.
- Compaction guidance, CLAUDE.md, README, rules, and guides rewritten without inventory counts.

### Fixed
- `blitz_find_root` returned non-zero in a project without `.claude-plugin/`, which aborted any hook that logged an event (exit 1 = non-blocking), so the guards failed open in consumer projects. It now falls back to the git toplevel and always returns 0; bats covers the consumer shape for `tasks-guard.sh` and `kill-switch.sh`.
- `next-state.sh` treated a `check-report.md` written in the same second as `tasks.json` as stale.

### Removed
- Skills: `sprint`, `sprint-plan`, `sprint-dev`, `sprint-review`, `implement`, `quick`, `fix-issue`, `review`, `code-doctor`, `code-sweep`, `release`, `retrospective`, `roadmap`, `quality-metrics`, `ask`, `bootstrap`, `codebase-map`, `health`, `setup`, `conform`, `worktree-prune`, `compress`, `design-extract`.
- Agents: `orchestrator` (and `.claude-plugin/settings.json`), `architect`, `doc-writer`, `reviewer`, `backend-dev`, `frontend-dev`, `infra-dev`.
- Protocols: `sprint-contracts`, `session-lifecycle`, `agent-orchestration`, `quality-engine`, `terse-output`, `worktree-lifecycle`, `knowledge-protocol`, `skill-cross-references`, `project-context`, `session-report-template`, `html-template-helper`.
- Hooks: `workflow-guard`, `analysis-paralysis-guard`, `task-completed-validate`, `context-monitor`, `pre-edit-backup`, `reference-compression-validate`, `post-edit-lint`, `post-edit-activity-log`, `subagent-start`, `subagent-stop`, `post-tool-failure`, `permission-request`, `teammate-idle`, `post-compact-log`, `cwd-changed`, `model-switch-warn`; events `PostCompact`, `TeammateIdle`, `TaskCompleted`, `SubagentStart`, `SubagentStop`, `PostToolUseFailure`, `PermissionRequest`, `PreModelSwitch`, `CwdChanged`, `DirectoryAdded`.
- `installer/` and the npm publish workflow (install through the marketplace), `scripts/check-count-sync.sh`, `.claude-plugin/counts.json`, `.claude-plugin/model-profiles.json`, `scripts/maint/`, the registry backfill and scope-parser scripts, `scripts/validate-skill-output.sh`, eval `orchestrator-routing`.

### Rename table

| v2 | v3 |
|---|---|
| `/blitz:sprint`, `/blitz:sprint-dev`, `/blitz:implement`, `/blitz:quick` | `/blitz:build` |
| `/blitz:fix-issue N` | `/blitz:build --issue N` |
| `/blitz:sprint-plan`, `/blitz:roadmap` | `/blitz:plan` |
| `/blitz:review`, `/blitz:sprint-review` | `/blitz:check` |
| `/blitz:code-doctor` | `/blitz:check --only framework` |
| `/blitz:code-sweep` | `/blitz:check --scope repo` |
| `/blitz:release` | `/blitz:ship` |
| `/blitz:retrospective` | `/blitz:learn` |
| `/blitz:ask` | `/blitz:research --codebase` |
| `/blitz:bootstrap`, `/blitz:codebase-map` | `/blitz:onboard` |
| `/blitz:health`, `/blitz:setup` | `/blitz:doctor` |
| `/blitz:conform` | `/blitz:doctor --migrate` |
| `/blitz:worktree-prune` | `/blitz:sessions worktrees` |
| `/blitz:design-extract` | `/blitz:ui-build` (design-extract reference) |
| `/blitz:quality-metrics`, `/blitz:compress` | removed (`check` ratchet; output style) |
| `/blitz:sprint-wave` | `/blitz:build-wave` |
| `agents/backend-dev`, `frontend-dev`, `infra-dev` | `agents/dev` (role by prompt) |
| `agents/reviewer` | `agents/critic --mode survey` |
| `sprints/<n>/stories/*.md`, `carry-forward.jsonl` | `docs/plans/<slug>/tasks.json` |
| `STATE.md` | `docs/plans/<slug>/progress.md` |
| `todos.jsonl` | `docs/plans/BACKLOG.md` |
| `docs/_research/` | `docs/research/` |
| `session-lifecycle.md`, `agent-orchestration.md`, `quality-engine.md`, `terse-output.md`, `sprint-contracts.md` | `sessions.md`, `agents.md`, `quality.md`, `output.md`, `loop.md` |

## [2.5.0] — 2026-09-18 · Claude Code 2.1.276 alignment (E-040…E-047)

Review: [docs/reviews/2026-09-18_cc-2.1.276-alignment/README.md](docs/reviews/2026-09-18_cc-2.1.276-alignment/README.md). Effective floor moves to **Claude Code ≥2.1.271** (`.claude-plugin/compat.json`).

### Added
- **Session management v2 (E-041):** hook-owned session records at `.cc-sessions/sessions/<native session_id>.json` (SessionStart/PostToolBatch/Stop/SessionEnd); `blitz_agent_view` single parser for `claude agents --json` (real `state`/`status`/`waitingFor` schema); cross-session messaging in the conflict matrix (`SendMessage` + `notify_when_idle`, `LOOP_DEFER`); mailbox drained at turn end; inbox `.cc-sessions/inbox.jsonl` written by hooks and triaged by `/blitz:next` (`HEARTBEAT_OK`); new skill **`/blitz:sessions list|attention|dashboard --html|prune`** with `scripts/sessions-dashboard.sh`; `_lib/html.sh` holds `emit_html` once. Skills 37→38.
- **Eight hook events (E-040):** SessionEnd, Stop (non-blocking heartbeat + mailbox drain, then the conditional gate), Notification, PermissionDenied, PreModelSwitch, CwdChanged, DirectoryAdded, ConfigChange. Hook scripts 38→46, events 16→24; exec-form entries with `timeout` + `statusMessage`.
- **Verification stack (E-042):** `stop-gate.sh` deterministic Stop gate armed by sprint-dev / `next --loop` via `gate.json` (never fights a user `/goal`; stays under the platform's 8-block cap); sprint-dev prints the `/goal` companion line; sprint-review runs the recorded `/verify` recipe first; `/blitz:setup` seeds `.claude/skills/verify/SKILL.md`.
- **Test impact analysis v0 (E-043):** `scripts/test-listener.sh` (stateless, append-only journal, `runs_started == runs_recorded`), `scripts/test-selector.sh` (sibling + static import graph / jest related + journal recent-fail + co-change, `--full` fallbacks); heartbeat runs the selected set after edits; sprint-review calibrates with one full run (`escaped_failures`); advisory metrics `tia_escaped_failures`, `tia_selection_ratio`; `docs/guides/tia.md`.
- **Plugin evals + workflows (E-045):** `evals/` suite (5 cases) for `claude plugin eval`, advisory CI job; `workflows/sprint-wave.js`, `review-fanout.js`, `audit-sweep.js` extracted from skill prose.
- **Cloud posture (E-046):** `docs/guides/cloud-threads.md` (Projects threads, Routines, Desktop tasks, Channels, Remote Control); security TB-5 (cross-session and channel inbound is untrusted).
- `.claude/rules/skills.md`, `.claude/rules/hooks.md` (path-scoped authoring contracts); `docs/research/README.md`; `docs/EPICS.md`.

### Changed
- **Model economics (E-044):** every model-invokable skill is `model: inherit` with no pinned `effort` (validator-enforced; slash-only migrate/release/ship keep pins) — set model/effort once per session, the `PreModelSwitch` hook warns on cache busts. Builder agents + reviewer get `experimental.cacheTtl: 1h`; critics get `omitClaudeMd: true`. KNOWLEDGE.md / auto-memory / agent-memory division of labor in `knowledge-protocol.md` §8. CLAUDE.md trimmed 103→38 lines; CI guards ≤200.
- sprint-dev §3.2: `Monitor` re-armed per wave with a deadline (`persistent` was removed in CC 2.1.271); §3.2.2 peer sessions. `next` Phase 0.5 inbox triage; scheduling tiers rewritten (7-day CronCreate expiry, `.claude/loop.md`, Routines 1 h, Channels, `/goal`).
- Installer floor checks and messaging updated to 2.1.271; agent-teams wording retired.
- README/CI counts reconciled; `check-count-sync.sh` asserts headings; `check-version-sync.sh` asserts every Claude Code citation against `compat.json`.

### Fixed
- `blitz_log_event` dropped every event that carried a detail object (bash `${4:-{}}` parse); `pre-compact-snapshot.sh` emitted invalid `HANDOFF.json` under pipefail; agent-view overlay filtered a field that no longer exists (C2); `test-listener.sh` lock-recovery race on GNU stat.
- Carried from the pre-release review rounds (previously under `[Unreleased]`): inventory drift (shared 12→13), sprint-review Workflow `pipeline()` misuse, model-routing contradiction, missing `infra-dev` agent (10→11), security-hook bypasses, installer count drift, Workflow contract refresh, autonomous-loop `BLITZ_DISPATCH=agent` guard, prompt-cache guidance reframe, count-sync gate hardening, cumulative-description guard.

### Verify on a live account (not reproducible in this environment)
- `model: inherit` on an `opus[1m]` session must not re-trigger the 2.4.4 `sonnet[1m]` credits error.
- `claude plugin eval .` grader thresholds are advisory until the suite has run once.

## [2.4.4] — 2026-06-07 · fix [1m] inheritance on invokable skills

Bug-fix dot-release.

- **fix(skills): promote invokable skills to `model: opus`** — `next` + 9 others (`compress`, `dep-health`, `design-extract`, `health`, `quick`, `setup`, `test-gen`, `todo`, `worktree-prune`) declared `model: sonnet`. Invoked from an `opus[1m]` session they inherited `[1m]` → `sonnet[1m]`, which is credits-gated **separately** from Opus 1M (on every plan incl. Max) → `API Error: Usage credits required for 1M context`. `/blitz:next` broke while `/blitz:sprint` (already `model: opus` → `opus[1m]`) worked. Promoted to `opus` to match the sprint-family entry skills; heavy work still runs in spawned sonnet Agents (isolated, non-`[1m]` context). Per `docs/_research/2026-06-07_1m-context-credits-on-loop.md`. No change to skill/agent/hook counts (37/10/38).

## [2.4.3] — 2026-06-07 · conform wave-plan + gitignore hygiene

Maintenance dot-release.

- **conform: `wave-plan.json` entry** — `/blitz:conform` now inventories + shape-probes sprint-dev's `${SESSION_TMP_DIR}/wave-plan.json` (jq `.waves and .done and .derived_from`). Ephemeral/skip-if-absent, INFO-only, never MIGRATE (re-derived from STATE.md each run). Closes the last open question from `docs/_research/2026-06-07_cross-session-resume-plus-workflow.md` §8.
- **gitignore: skill-generated root artifacts** — root-anchored ignores for `CODEBASE-MAP.md`, `DESIGN.md`, `.ui-audit.json`, `.quality-metrics.json`, `KNOWLEDGE.md`, `todos.jsonl`, `.blitz-cache/`, `firebase-debug*.log` so running blitz skills in the plugin-dev repo can't accidentally commit generated output. Tracked `.ui-audit.json.example` fixture unaffected.

No change to skill/agent/hook counts (37/10/38).

## [2.4.2] — 2026-06-07 · Workflow dispatch adoption

Feature dot-release — extends the opt-in `Workflow` (dynamic-workflows) dispatch path to the remaining fan-out skills, with `Agent()` fallback preserved throughout. Research-backed (`docs/_research/2026-06-06_dynamic-workflows-claude-code.md`, `2026-06-07_cross-session-resume-plus-workflow.md`, `2026-06-07_deferred-resume-microopts.md`).

- **Workflow wiring (adoption table now all WIRED):** `sprint-plan` + `codebase-map` (flat pool → `parallel()`), `sprint-review` (reviewers → `parallel()`/`pipeline()`, critic → `agent({agentType,schema})`), `audit` refuter panel (per-finding nested `parallel()`).
- **sprint-dev cross-session resume + Workflow:** per-wave `parallel()` + `isolation:'worktree'`; lifted the `Agent()`-only resume guard — `STATE.md` is the durable journal, resume re-derives remaining waves (serialized `wave-plan.json`, pure Kahn sort) and dispatches each via `Workflow`. `resumeFromRunId` in-session-only; Resume Divergence Gate is the safety interlock.
- **Alt A — observability-only attempt counter:** `total_attempts` + `last_attempt_ts` mirrored to the STATE.md Blocked table (`Attempts`/`Last Attempt`). Diagnostic only — the circuit-breaker still resets per sprint run (Airflow-`clear` / CI-re-run model). Durable breaker counter, in-session `resumeFromRunId`, and idempotency tokens remain deferred behind documented trigger metrics.

No change to skill/agent/hook counts (37/10/38). Validators: skill-frontmatter, markdown-link (350), version-sync expected green.

## [2.4.1] — 2026-06-06 · compaction passes II–III

Maintenance/refactor pass — **zero behavior change** (validator-attested: skill-frontmatter, agent-frontmatter, markdown-link, check-registry, reference-compression, plugin-structure, count-sync, version-sync all exit 0; hook test suite 66/66). Skill semantics, hook wiring, agent roles, and flags are identical. Attacks the content pools v2.4.0 left untouched (`docs/`, `references/main.md`), plus changelog history and duplicated hook helpers.

**Tracked lines 54,803 → 42,301 (−12,502).**

- **`docs/` 91 → 14 files (11,408 → 1,854 lines).** Removed the uncited 51-file `docs/validation/v1.16.0/` snapshot (recoverable via `git tag validation-v1.16.0`) and archived design-process history across `consolidation/review-audit`, `integrations/harness-design`, `integrations/impeccable`, `security/containment` — keeping only runtime-cited references (`effectiveness-research.md`, `audit-spec.md`, `design-critic-upgrade.md`, `references-regrounded.md`, `detector-rebuild.md`, `blitz-surface-map.md`, the impeccable design pillar core + Apache-2.0 license/attribution). Every inbound link to a removed file rewritten in-commit.
- **`.review/` untracked + gitignored** — audit-skill generated output, not source (same category as the `.original` files v2.4.0 removed).
- **`counts.json` phrasing fix** — `canonical_phrasing.shared` now reads "12 shared protocol files".
- **`references/main.md` (12,718 → 12,708)** — collapsed two duplicated file-lock step-lists in `roadmap/references` to cite `session-lifecycle.md §File-Based Locking Protocol`. The hypothesized large de-boilerplating win did not materialize: the top reference files are dense skill-specific procedure protected by named-section SKILL.md contracts and the agent-prompt-payload invariant (intentional verbatim duplication), not boilerplate.
- **`agent-orchestration.md` (1,454 → 1,435)** — removed two HEARTBEAT/PARTIAL default blocks re-embedded in the boilerplate section, which already declared §3 canonical. No `_shared` file re-split.
- **`CHANGELOG.md` (870 → 201 lines, −87 KB)** — archived the 16 `1.x` releases (1.16.0 → 1.5.0) to `CHANGELOG-ARCHIVE.md` behind an "Older releases" pointer; kept `[Unreleased]`, the Release-Process header, and all `2.x` releases live so version-sync stays green.
- **`hooks/scripts/_lib/common.sh`** — hoisted the byte-identical `fail()` helper out of `agent-frontmatter-validate.sh` + `skill-frontmatter-validate.sh` (both already sourced common.sh). `find_project_root`/`block`/`validate_one`/`usage` left inline — not byte-identical across call sites (or semantically distinct from `blitz_find_root`). Hook-script count unchanged (38).

## [2.4.0] — 2026-06-06 · unification & slimming pass

Maintenance/refactor pass — **zero behavior change**. Reduces redundancy and lazy-loaded context across the suite. Skill semantics, hook wiring, agent roles, and flags are identical.

**`_shared/` protocols: 32 → 12 `.md` files** (+ `check-registry.json`). Fragmented single-concern protocols collapsed into cohesive docs so a skill loads one file per concern instead of many. All inbound cross-references rewritten mechanically; every linked anchor preserved:

- `terse-output.md` ← `verbose-progress.md` (canonical OUTPUT STYLE block untouched — validator-pinned).
- `agent-orchestration.md` ← `spawn-protocol`, `agent-prompt-boilerplate`, `agent-routing`, `agent-view-dispatch`, `workflow-dispatch`, `token-budget`.
- `session-lifecycle.md` ← `session-protocol`, `checkpoint-protocol`, `context-management`, `state-handoff`, `scheduling`.
- `sprint-contracts.md` ← `carry-forward-registry`, `story-frontmatter`, `definition-of-done`, `deviation-protocol`, `scope-limit-protocol`.
- `quality-engine.md` ← `check-registry.md`, `quality-matrix`, `shortcut-taxonomy`, `ratchet-protocol`, `deterministic-test-recipe` (the `check-registry.json` data file stays separate).
- `security.md` ← `threat-model`, `hook-trust`, `package-install-policy`.

> **Forking note:** if your fork references `skills/_shared/<old-name>.md` directly, repoint to the consolidated file above. Each consolidated file carries a top-of-file map listing what it absorbed; former section anchors are preserved.

**SKILL.md bodies de-boilerplated** — 11 oversized skills slimmed by 916 lines total (over-granular sub-phase numbering collapsed, prose tightened to terse-technical). Every distinct top-level Phase, command, safety block, and the verbatim OUTPUT STYLE line preserved.

**Cleanup** — dropped 17 tracked `*.original` compress backups (git history is the backup; pattern gitignored); fixed the retired `frontend-design-heuristics.md` link and the pre-existing CLAUDE.md 30-vs-32 shared-count drift.

No skills merged (quality surface + UX routers stay deliberately distinct per the `quality-engine.md` four-question test). Validators green: count-sync, version-sync, plugin-structure, skill/agent-frontmatter (OUTPUT STYLE hash resolves), markdown-link, check-registry, reference-compression.

## [2.3.5] — 2026-06-06 · critic-gemini stderr JSON fix

### Fixed
- **`critic-gemini.sh` stderr noise broke JSON parsing** (#17): line 146 captured gemini output with `2>&1`, merging the CLI's terminal-capability warnings ("True color (24-bit) support not detected", "Ripgrep is not available…") into the JSON on stdout, so `jq -e .` failed and the wrapper exited 1 — disabling the cross-model critic (gemini-only / dual-CMC modes). Now captures stderr to a tempfile (surfaced only on real invocation failure) and adds a line-based pre-JSON guard (`awk '/^[[:space:]]*\{/{f=1} f'`) as defense-in-depth for gemini-cli #21433 (startup messages leaking to stdout). Regression coverage: `hooks/tests/critic-gemini.bats` (5 tests, incl. brace-in-string non-truncation). Background: `docs/_research/2026-06-06_critic-gemini-stderr-json.md`.

## [2.3.4] — 2026-06-01 · argument-hint coverage + concision

### Fixed
- **argument-hint coverage**: added the field to the 7 arg-taking skills that lacked it (`audit`, `research`, `compress`, `sprint-dev`, `sprint-plan`, `sprint-review`, `ui-build`) — all 37 skills now show an autocomplete arg chip. Display-only field; no change to invocation or argument delivery.

### Changed
- **argument-hint concision**: trimmed the `-- <prose explanation>` tails from 15 hints (`review`, `browse`, `code-doctor`, `conform`, `dep-health`, `doc-gen`, `next`, `perf-profile`, `quality-metrics`, `roadmap`, `release`, `setup`, `ship`, `sprint`, `ui-audit`) to short chips, keeping every flag spelling. Aligns with the field's short-chip intent. Background: `docs/_research/2026-06-01_command-argument-hints.md`.

## [2.3.3] — 2026-06-01 · audit remediation + README rewrite

### Fixed
- **orchestrator boot summary**: removed unsupported `initialPrompt` frontmatter (silently ignored per the documented plugin-agent field allowlist) and folded the boot state-summary into the system-prompt body so it actually fires.
- **trigger collisions**: added reciprocal routing boundaries for `review`↔`sprint-review`, `ship`↔`release`, and the bare-`audit`/`security audit` overload (object-noun routing); secondary boundaries for `sprint`↔`implement`↔`sprint-dev`, `codebase-map`↔architect, `browse`↔`ui-audit`.
- **hook path robustness**: quoted all 38 `"${CLAUDE_PLUGIN_ROOT}"` command values in `hooks.json` (shell-form, install-paths-with-spaces safe); taught `scripts/validate-plugin-structure.sh` to strip the quotes when resolving.
- **version-gating**: surfaced the effective Claude Code minimum (`>=2.1.117`) in `plugin.json` description (no manifest `engines` field exists).
- **orphan agents**: documented `architect` + `doc-writer` as orchestrator-only freeform targets.
- de-orphaned `_shared/scheduling.md` (linked from `next` + `code-sweep`); removed unsupported `color` frontmatter from 4 agents; added worker-agent invocation markers (`reviewer`/`test-writer`/`doc-writer`); documented external deps (Playwright MCP, Gemini CLI).

### Changed
- **README**: full rewrite — corrected the ANSI Shadow ASCII banner; converted 4 ASCII diagrams to Mermaid (holistic-machine overview, the Blitz cycle, review/audit registry core, carry-forward lifecycle); corrected stale counts (shared protocols → 32, check-registry → 94 checks); dropped the nonexistent typed-agent-definitions section.

## [2.3.2] — 2026-05-31 · cohesion + count-drift cleanup

Plugin-wide cohesion pass: eliminated count/version drift, de-duplicated the routing surface, clarified maintenance-skill boundaries, and brought every SKILL.md body under 450 lines — without touching the holistic-machine contracts (orchestrator → skill → worktree-agent → registry-gated critic → disk-state). No skill merged, demoted, or deleted (all three overlap clusters resolved KEEP-SEPARATE), so this is a patch.

### Added
- **`.claude-plugin/counts.json`** — authoritative, filesystem-computed plugin inventory (skills, agents, shared protocol files, hook scripts/wired/sub-invoked/critic-spawned, events, detectors). Single source of truth for every prose count.
- **`scripts/check-count-sync.sh`** — recomputes counts from disk, asserts `counts.json` is current, and validates curated prose claims in `README.md` / `CLAUDE.md` / `plugin.json` / `marketplace.json`. Wired into `pre-commit-validate.sh` (blocks when a count-bearing doc is staged with drift). `--write` regenerates `counts.json`. Root-cause fix for the count drift `check-version-sync.sh` (semver-only) never caught.

### Changed
- **Count drift fixed** (`counts.json` truth): shared protocol files 29/30 → **32**; anti-shortcut detectors 19 → **20** (13 reject / 7 advisory); hook scripts 37 → **38** (35 event-wired, 2 sub-invoked, 1 critic-spawned); `skill-cross-references.md` `EXPECTED_FILES` off-by-one 7 → **6**.
- **Routing table de-duplicated** — `skills/ask` Phase 1 now reads `agents/orchestrator.md §2` as the canonical intent→skill map at runtime + a 6-row fallback; the divergent prose mirror (with its malformed `audit` row and stale `ship`/`migrate`/`/sprint cmd` slugs) is gone (123 → 107 lines).
- **Maintenance boundaries tightened** — reciprocal one-line statements added to `health` (read-only assert + runtime probes) and `conform` (`--fix` schema repair); `setup` (CLAUDE.md-rule conflicts) already orthogonal. No merge.
- **`implement` slimmed to pure dispatch** — re-declared sprint-dev flags + duplicated pre-flight removed; slug preserved (61 → 30 lines).
- **Conciseness pass** — 12 SKILL.md bodies relocated their largest non-startup blocks to `references/main.md` (verbatim, zero behavioral loss); all now ≤450 (was 450–496). `next` gained its first `references/main.md`.

### Removed
- **sprint-19 deprecation cutover finalized** — `completeness-gate` / `integration-check` standalone skill dirs were already removed; updated the live docs (`orchestrator §2`, `quality-matrix`) that still claimed "legacy slug still works" to reflect the completed sprint-20 cutover (use `/blitz:review --only completeness|wiring`). Historical validation/consolidation docs + CHANGELOG retain the old names by design. Fixed stale `det-01..19` → `det-01..20` range in `review`.

## [2.3.1] — 2026-05-31 · browse broken-wiring detection + interaction coverage

Ports the two functional (non-aesthetic) behaviors of v2.3.0's design-critic E2 live-navigation pattern into `/blitz:browse`. From research `docs/_research/2026-05-31_browse-live-navigation-e2.md` (R1 + R3); R2/R4/R5 deferred. Sprint 22.

### Added
- **Broken-wiring detection (R1)** — `skills/browse` Phase 3.5 / loop Phase 4.6: after each existing safe-allow-listed click (tabs / pagination / sort / accordion), a control that renders but produces no observable response (no a11y-tree change AND no route change AND no network request) is recorded as a `broken_wiring` finding — Warning, or Error when the inert control is a primary action. Couples the snapshot-diff with the network check to separate renders-but-inert from handler-fires-backend-404. False-positive guard for legitimately-inert clicks. New "Broken Wiring" report section + Error-Classification taxonomy row.
- **interaction_coverage schema (R3)** — additive per-page fields in `crawl-visited.json`: `interaction_coverage {safe_clicks, broken_wiring_checked, responsive_checked}` + `broken_wiring[]`. Non-breaking (existing readers unaffected). `responsive_checked` is a forward-compat placeholder for the deferred R2 opt-in responsive pass.

### Notes
- Rides **only** browse's existing safe-interaction allow-list — the 7 NON-NEGOTIABLE safety rules + "NEVER interact with" list are unchanged. No new tool grant (`browser_snapshot`/`browser_network_requests`/`browser_click` already loaded at Phase 1.2); `allowed-tools` frontmatter unchanged. `skills/browse/SKILL.md` 389/500 lines. Critic LGTM.

## [2.3.0] — 2026-05-31 · GAN-harness design-loop integration (E1–E5)

Closes the five deltas between blitz's design loop and the planner/generator/evaluator harness in [anthropic.com/engineering/harness-design-long-running-apps](https://www.anthropic.com/engineering/harness-design-long-running-apps). Blitz already had the architecture (sprint-plan → ui-build/sprint-dev → design-critic/critic); these are the deltas, not a rebuild. Specs: `docs/integrations/harness-design/`.

### Added
- **`skills/_shared/design-criteria.md`** — single-source 5-dimension design rubric, shared by the generator (steering) and evaluator (scoring). The criteria themselves steer the model off generic defaults before any evaluator cycle.
- **E1 criteria-as-steering** — `ui-build` Phase 3.0.1.1 carries the 5 dims ("museum quality") into generation, not just into the evaluator. Tone-conditional phrasing for informal tones.
- **E2 live-navigating evaluator** — `agents/design-critic.md` granted the Playwright navigation subset and navigates the live page before scoring (click primaries, exercise states, resize for responsive, read console). New `coverage_boundary` reply field; static-screenshot path retained as fallback (never silently passes interaction dims). `maxTurns` 15→30. `browser_run_code_unsafe`/`browser_evaluate` deliberately NOT granted (threat-model §5 posture).
- **E3 iterate + pivot** — `ui-build` Phase 5.4.2 flat-3 cap replaced with `ceiling = min(10, budget)`; refine-vs-pivot strategic decision after each evaluation (pivot space = the 13-tone menu).
- **E4 sprint-contract negotiation** — `sprint-dev` Phase 0.6: generator↔evaluator negotiate testable acceptance before code; persisted as co-owned `scope.acceptance`. Registered in `state-handoff.md`.
- **E5 capability-relative trigger** — `ui-build` `standard` tier evaluates only on edge-of-capability signals (novel aesthetic / interaction complexity / low generator confidence / deterministic-lane hits); `high` always evaluates. Re-examine per model release; cites the v1.16.0/cohesion/det-20 detector re-justification precedent.

### Changed
- `agents/design-critic.md` — "read screenshots, not source" → "read the rendered app, not the source" (input surface expands to live DOM; the source prohibition stands).

## [2.2.1] — 2026-05-30 · fix check-registry schema (v2.2.0 hotfix)

v2.2.0's LANE-1 re-laned 41 rows to `lane: semantic` but left `detection.type: command` and one `verdict_authority: reject` — which the `check-registry-validate` CI gate rejects (semantic rows must be `detection.type: semantic` + `verdict_authority: advisory`). The gate runs in CI only and was not run locally, so v2.2.0 shipped with a schema-invalid registry (red CI on `main`).

### Fixed
- `check-registry.json` — the 41 semantic design rows now carry `detection.type: "semantic"` (the `npx impeccable detect` command is retained on the row) and `verdict_authority: "advisory"` (`design-low-contrast` was `reject`). Registry passes `hooks/scripts/check-registry-validate.sh` (90 checks, derivation clean).
- `hooks/tests/design-pillar.bats` — added two guards that run the CI schema validator + assert every semantic design row is `type:semantic`/`advisory`, so this class of drift fails locally (suite 57→59).
- `.github/workflows/{ci,publish}.yml` — `actions/checkout` + `actions/setup-node` bumped `v4 → v5` (Node 24 compat; silences the Node 20 deprecation warning).

## [2.2.0] — 2026-05-30 · design-pillar reliability + precision hardening

Post-release hardening of the v2.1.0 design pillar. A validation pass found the absorption architecturally sound but with concrete reliability/precision gaps in the deterministic lane: an undeclared impeccable dependency that silently no-ops, 42 browser-rendered rows mislabeled `deterministic`, and regex rules that false-positive on the token definitions they protect. Fixed across five epics (`docs/integrations/impeccable/improvements/`), each gated by a new permanent test suite.

### Added
- `scripts/design/preflight.sh` — design-lane availability gate. Resolves impeccable **from the target project** (not the plugin; it's a browser/puppeteer-class dep), emits a machine-readable `DESIGN_LANE_STATUS` line, and fails **loud** (`DESIGN_LANE_UNAVAILABLE` + `npm i -D impeccable@2.3.2` hint) instead of silent-green when the semantic lane can't run. Exit 0 — the deterministic regex lane is never blocked.
- `scripts/detect-stack.sh` normalized `DESIGN_ADAPTER primary=… variant=… secondary=… incompat=… confidence=…` token — single parseable line consumers read instead of the prose block.
- 8 native blitz **deterministic** static rules (key-free, browser-free grep approximations of the impeccable slop tells): `bounce-easing-static`, `thin-border-wide-shadow-static`, `repeating-stripes-static`, `gradient-text-static`, `extreme-negative-tracking-static`, `tiny-text-static`, `all-caps-body-static`, `overused-font-static`.
- `check-registry.json` top-level `design.exclude` — token-definition exclusion set (file globs + content guards + line guards) applied to every deterministic design regex row before reporting; eliminates within-stack false positives on `@theme`/`tailwind.config`/`quasar.variables`/Vuetify-theme surfaces, comments, and SVG paint (measured 75%→0% FP on the raw-color-literal fixture).
- `hooks/tests/design-pillar.bats` — 22-test permanent gate: adapter-detection matrix, layer-gating selection harness, reconciliation suppression, FP exclusions, lane integrity, and the preflight loud-failure contract.

### Changed
- **41 vendored impeccable rows re-laned `deterministic` → `semantic`.** They are browser-rendered (require the impeccable package + a rendered DOM) — the deterministic tag was false. The genuinely deterministic design lane is now the blitz-authored grep rows only (`{ semantic: 41, deterministic: 19 }`; zero deterministic rows shell out to `npx`).
- **Gemini routing** — stripped impeccable's `--gpt --gemini` provider flags from all detector commands (the deterministic run is now key-free); the provider-gated tells route through `design-critic`'s gemini CLI, reusing the adversarial critic's `BLITZ_GEMINI_BIN`/`BLITZ_GEMINI_MODEL` env instead of a separate Gemini API key.
- `/blitz:review --only design` + `/blitz:audit --pillar design` — run the preflight first, parse the `DESIGN_ADAPTER` token + inclusion map, apply `design.exclude` + FP-verify before reporting.
- `scripts/maint/design/gen-design-rows.mjs` — dropped the silent `/tmp/impeccable-src` default (non-reproducible); the impeccable source path is now a required explicit arg.
- `skills/setup` + `skills/bootstrap` recommend `npm i -D impeccable@2.3.2` to the **target project** (the plugin never installs it).

### Removed
- 5 near-duplicate color rules (`tw-arbitrary-color`, `md3-role-conformance`, `vuetify-hardcoded-color`, `quasar-inline-hex`, `quasar-color-outside-brand`) folded into a single consolidated `design-raw-color-literal` carrying per-adapter messaging (`perAdapter`) + the `*.html` coverage. Design rows 57→60 (−5 color, +8 static).

### Fixed
- `installer/install.sh` curl install one-liner + `installer/src/index.js` docs link — corrected stale `lasswellt/blitz` → `lasswellt/blitz-cc` (the one-liner 404'd as written; the live remote/npm/homepage were already `blitz-cc`).
- `hooks/tests/_helpers.bash` — `fake_tool_input`/`fake_edit_input` were missing `tool_name`, so `block-test-deletion.sh` (which dispatches on it) fell through to allow instead of block — two long-standing test failures. Full `hooks/tests` suite now 57/57.

## [2.1.0] — 2026-05-30 · framework-adaptive design pillar (impeccable absorption)

Absorbed `pbakaus/impeccable@2.3.2` (Apache-2.0) as a **framework-adaptive design pillar**: a normalized 7-facet design model + pluggable adapters (Tailwind v4 · Tailwind+MD3 · Vuetify v4/v3/v0 · Quasar 2) that detect the project's UI stack and adapt guidance + conformance to it. Specs in `docs/integrations/impeccable/`; epics E0→E6 (`SYNTHESIS.md`). The universal AI-slop detection runs on any stack; per-adapter conformance fires only for the detected stack (no cross-stack false positives).

### Added
- `docs/integrations/impeccable/` — 8 spec docs (normalized-model, adapter-detection, framework-profiles, detector-rebuild, references-regrounded, migration-spec, ATTRIBUTION, SYNTHESIS) + vendored Apache-2.0 `LICENSE-APACHE-2.0.txt`.
- `check-registry.json` `design` pillar — **57 rows** (39 Layer-0 universal slop · 5 Layer-1 token-discipline · 13 Layer-2 adapter conformance), tagged by `layer`/`adapter` with per-adapter `reconciliation`; registry now 87 checks. Vendored from impeccable@2.3.2, re-grounded (Apache-2.0).
- `scripts/detect-stack.sh` Adapter Stack selector — primary + variant (Vuetify v3/v4/v0, Tailwind v3/v4, tailwind-md3) + secondary + incompatibility; component framework wins over Tailwind.
- `/blitz:review --only design` (precision) + `/blitz:audit --pillar design` (recall) + `design-critic` as the design pillar's semantic/vision lane. Deterministic detection shells out to `npx impeccable detect`.
- `scripts/maint/design/gen-design-rows.mjs` — idempotent registry-row generator (re-runnable against an impeccable checkout).

### Changed
- **Repository renamed** `lasswellt/cc-plugin-suite` → `lasswellt/blitz-cc` (matches the `blitz-cc` npm package). GitHub redirects the old URL; plugin-manifest `homepage`/`repository` + installer URLs updated to the new slug. The legacy `cc-plugin-suite@cc-plugin-suite` plugin-enablement key is retained for backward-compatibility.
- `ui-build` / `design-extract` / `ui-audit` made adapter-aware; `design-extract` DESIGN.md template gains a `## Stack` section; `quality-matrix` + orchestrator §2 route the design pillar.

### Removed
- `skills/_shared/frontend-design-heuristics.md` (122 lines) — superseded by the design pillar (normalized-model + `references-regrounded.md` §8.1 + the Layer-0 detector). Coverage proven in `migration-spec.md` §2; consumers redirected; `CLAUDE.md` reference updated.

## [2.0.0] — 2026-05-29 · review/audit consolidation (sprints 18–20)

Collapsed the 7-skill review/audit/quality surface into **2 entry points over a shared check registry**, grounded in the verified research in `docs/consolidation/review-audit/`.

### Added
- `skills/_shared/check-registry.json` (schema `blitz-check-registry/2.0`) + `check-registry.md` — single source of truth for every review/audit check: `lane` (deterministic|semantic), `verdict_authority` (reject|advisory, derived), `base_confidence`, `detection.{type,command}`, provenance. 30 checks (20 detectors + 5 semantic pillars + O2/O3/fw).
- `hooks/scripts/check-registry-validate.sh` — schema lint (verdict-authority derivation invariant + detection presence/type); wired into `pre-commit-validate.sh`.
- `/blitz:review` — consolidated **precision** front-door (two detection lanes, confidence gate + reject-bypass, FP-verify, `--only completeness|wiring|framework|full`).
- `/blitz:audit` — consolidated **recall** entry point with net-new flaw-finding: deterministic lane, Multi-Review aggregation (≥2 independent agreers → high confidence), adversarial FP-verify panel, and `coverage_boundary` recall instrumentation.

### Changed
- `agents/critic.md` — verdict-flip asymmetry (ground-truth → REJECT; advisory → annotate-only), reject-bypass of the confidence gate, FP-verify substep, principled CMC routing, registry-driven §2.1. Detector count reconciled to **20 catalogued (13 reject, 7 advisory)**.
- `agents/research-critic.md` — §2.5 claim-grounding promoted to a graded gate, `UNVERIFIED` first-class verdict, refuse-without-evidence for `scope:` claims, carry-forward citation-drift re-verification, corrected 4-way-taxonomy attribution.
- `shortcut-taxonomy.md` → human-readable view of the registry; `quality-matrix.md` rewritten for the 2-entry-point model.

### Removed (BREAKING)
- `skills/completeness-gate/` and `skills/integration-check/` — folded into `/blitz:review --only completeness` and `/blitz:review --only wiring`. Deprecation shims (sprint-19) removed in the sprint-20 cutover.
- `skills/codebase-audit/` — **renamed** to `skills/audit/` (the engine; `/blitz:audit` is the entry point). All ~50 references migrated. Skill count 39 → 37.


## Older releases

1.x and earlier moved to [CHANGELOG-ARCHIVE.md](CHANGELOG-ARCHIVE.md).
