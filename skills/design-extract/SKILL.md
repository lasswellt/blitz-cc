---
name: design-extract
description: "Extracts design tokens, typography, palette, and component samples from an existing project into a portable DESIGN.md (Google Labs Apache-2.0 spec). Bootstraps brownfield projects so ui-build and design-critic share a common aesthetic source-of-truth. Use when the user says 'extract design system', 'build DESIGN.md', or before the first /blitz:ui-build run."
argument-hint: "[--from <path>] [--out DESIGN.md]"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
model: sonnet
effort: low
compatibility: ">=2.1.117"
---
<!-- compatibility floor >=2.1.117 (vs project majority >=2.1.71): requires
     holistic-machine orchestrator for the DESIGN.md handoff to ui-build,
     frontend-design, and design-critic. -->

OUTPUT STYLE: terse-technical per /_shared/terse-output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.

## Project Context

Stack profile auto-detected from `package.json`, `tailwind.config.*`, `vite.config.*`, `tsconfig.json`, and presence of CSS files in `src/`.

## Additional Resources

- DESIGN.md spec (Google Labs, Apache 2.0): https://github.com/google-labs-code/design.md
- Frontend-design heuristics paraphrase: [`/_shared/frontend-design-heuristics.md`](/_shared/frontend-design-heuristics.md)
- Token-budget protocol: [`/_shared/token-budget.md`](/_shared/token-budget.md)
- Definition of done: [`/_shared/definition-of-done.md`](/_shared/definition-of-done.md)

---

# design-extract Skill

Reads a brownfield project's existing design system and emits `DESIGN.md`. Runs once at project bootstrap; subsequent runs are idempotent (read existing DESIGN.md, surface drift, propose updates).

---

## Phase 0: SESSION

Follow [`session-protocol.md`](/_shared/session-protocol.md). Register session.

## Phase 1: SOURCE DETECTION

Read these files (skip if absent):

```bash
test -f package.json && jq -r '.dependencies + .devDependencies | keys[]' package.json | head -30
test -f tailwind.config.js -o -f tailwind.config.ts -o -f tailwind.config.cjs && cat tailwind.config.*
test -f vite.config.ts && grep -E "import|plugins" vite.config.ts | head
ls src/styles/ src/assets/styles/ src/css/ 2>/dev/null | head
find src -maxdepth 4 -name '*.css' -o -name '*.scss' 2>/dev/null | head -10
```

Identify:
- **CSS framework**: Tailwind / Quasar / Vuetify / vanilla / CSS-in-JS (which library)
- **Token files**: where CSS variables, Tailwind theme extends, or design-token JSON live
- **Font sources**: `<link>` tags in `index.html`, `@font-face` declarations, Tailwind `fontFamily` extends
- **Color palette**: Tailwind `colors` extends, CSS `:root` variables, theme JSON

## Phase 2: TOKEN EXTRACTION

For each source:

### 2.1 Tailwind config

```bash
node -e "
  const config = require('./tailwind.config.js');
  const theme = config.theme?.extend || config.theme || {};
  console.log(JSON.stringify({
    colors: theme.colors || {},
    fontFamily: theme.fontFamily || {},
    fontSize: theme.fontSize || {},
    spacing: theme.spacing || {},
    borderRadius: theme.borderRadius || {}
  }, null, 2));
" 2>/dev/null || echo "(no parsable Tailwind config)"
```

### 2.2 CSS variables

```bash
grep -hE '\s*--[a-z][a-z0-9-]*\s*:' $(find src -name '*.css' 2>/dev/null) | sort -u | head -60
```

### 2.3 Component-level color/font usage (sample)

```bash
# Most-used color tokens
grep -rhoE 'text-(red|blue|green|yellow|purple|pink|orange|gray|slate|zinc)-[0-9]{3}|bg-(red|blue|green|yellow|purple|pink|orange|gray|slate|zinc)-[0-9]{3}' src/ 2>/dev/null | sort | uniq -c | sort -rn | head -10

# Font-family declarations in source
grep -rhE "font-family:\s*[^;]+" src/ 2>/dev/null | sort -u | head -10
```

## Phase 3: AESTHETIC INFERENCE

From the extracted tokens, infer:

- **Tone**: which of 13 tones from [`/_shared/frontend-design-heuristics.md`](/_shared/frontend-design-heuristics.md) §2 best matches the existing system. Be specific: a Tailwind project with `slate-900` + serif body + lots of whitespace is likely `editorial/magazine` or `luxury/refined`.
- **Typography pair**: identify display + body fonts from extracted font-family list. If only one font found, mark "single-font system" and recommend a body or display addition for DESIGN.md output.
- **Accent color**: which color appears most often in CTA/active-state classes. That's the de-facto accent.
- **Motion vocabulary**: grep for `transition-`, `animate-`, `motion.`, `useMotion`. Classify present pattern (or "static").
- **Composition density**: count average components per page (`grep -c '<.*v-' src/pages/*.vue`). High density (>15) → "controlled density"; low (<8) → "generous whitespace".

If inference is ambiguous (two tones equally plausible), do NOT guess — emit a `## Open questions` section in DESIGN.md asking the user.

## Phase 4: EMIT DESIGN.md

Write to `DESIGN.md` at the repo root (or `--out` argument path). Use this template:

```markdown
# DESIGN.md

> Project design system source-of-truth. Generated by /blitz:design-extract on YYYY-MM-DD.
> Spec: https://github.com/google-labs-code/design.md

## Tone

<chosen tone from §2 of frontend-design-heuristics.md>

**Why**: <one sentence citing the strongest extracted signal>

## Typography

- **Display**: <font name>, fallback: <chain>
- **Body**: <font name>, fallback: <chain>
- **Scale**: <comma-separated sizes derived from extracted tokens>
- **Banned (project-specific)**: any font in §7 NEVER list of frontend-design-heuristics.md
- **Source**: <how the font is loaded — Google Fonts <link>, @font-face in app.css, Tailwind extend, etc.>

## Color

- **Dominant**: <CSS var or hex>
- **Accent**: <CSS var or hex> (single accent unless system requires multi)
- **Status colors** (only if system requires): success / warning / danger / info
- **Hardcoded colors found**: <count> — see §Open questions if >0
- **Source**: <Tailwind extend / :root variables / theme JSON>

## Motion

- **Vocabulary**: <one of: staggered reveals on enter | parallax on scroll | micro-interactions on hover | none/static>
- **prefers-reduced-motion**: <yes/no — required if any motion present>

## Composition

- **Density**: <generous whitespace | controlled density>
- **Default radii**: <single value or scale>
- **Grid**: <columns, gutter, breakpoints from Tailwind config>

## Open questions

<list any inference ambiguities the extract surfaced; user resolves before next ui-build run>

## Drift signals (auto-populated by sprint-review)

<file:line evidence of code drifting from this DESIGN.md — populated by sprint-review Phase 3.6, NOT by this skill on first run>
```

## Phase 5: VERIFICATION

Confirm DESIGN.md is consumable:

```bash
test -f DESIGN.md
grep -E '^## (Tone|Typography|Color|Motion|Composition)' DESIGN.md | wc -l   # must be 5
```

Activity-feed log:

```bash
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "{\"ts\":\"$TS\",\"session\":\"$CLAUDE_SESSION_ID\",\"skill\":\"design-extract\",\"event\":\"task_complete\",\"message\":\"DESIGN.md emitted\",\"detail\":{\"files\":[\"DESIGN.md\"]}}" >> .cc-sessions/activity-feed.jsonl
```

## Phase 6: REPORT

Tell the user:
- Which tone was inferred and why (one-line citation).
- Which typography pair was extracted (or "single-font — recommend pairing").
- Any open questions requiring resolution.
- Next step: `/blitz:ui-build` will now consume DESIGN.md instead of re-discovering tokens every run.

---

## Definition of Done

- [ ] `DESIGN.md` exists at repo root
- [ ] Five canonical sections present (Tone, Typography, Color, Motion, Composition)
- [ ] Each section has either a definite value OR an entry in Open questions
- [ ] Activity-feed entry written
- [ ] No source files modified — this skill is read-only on the codebase
