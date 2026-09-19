# Design-system extraction → DESIGN.md

Run by `/blitz:ui-build` Phase 1 when no `DESIGN.md` exists at the repo root (or when the user asks to "extract design system" / "build DESIGN.md"). Reads a brownfield project's existing design system and emits `DESIGN.md` (Google Labs Apache-2.0 spec: https://github.com/google-labs-code/design.md) so `ui-build` and `design-critic` share one aesthetic source of truth. Idempotent: with an existing `DESIGN.md`, read it, surface drift, propose updates instead of overwriting. Read-only on the codebase — the only file written is `DESIGN.md` (or `--out <path>`).

Tone palette + NEVER list: [`references-regrounded.md` §8.1](../../../docs/integrations/impeccable/references-regrounded.md). Evaluation criteria the critic grades against: [`/_shared/design-criteria.md`](/_shared/design-criteria.md).

---

## Step 1: Source detection

Read these files (skip if absent):

```bash
test -f package.json && jq -r '.dependencies + .devDependencies | keys[]' package.json | head -30
test -f tailwind.config.js -o -f tailwind.config.ts -o -f tailwind.config.cjs && cat tailwind.config.*
test -f vite.config.ts && grep -E "import|plugins" vite.config.ts | head
ls src/styles/ src/assets/styles/ src/css/ 2>/dev/null | head
find src -maxdepth 4 -name '*.css' -o -name '*.scss' 2>/dev/null | head -10
```

Identify:
- **CSS framework / adapter**: read the `Adapter Stack` block from `scripts/detect-stack.sh` (primary + variant — Vuetify v3/v4/v0, Tailwind v3/v4, tailwind-md3, Quasar); fall back to Tailwind / Quasar / Vuetify / vanilla / CSS-in-JS detection.
- **Token files**: where CSS variables, Tailwind theme extends, or design-token JSON live
- **Font sources**: `<link>` tags in `index.html`, `@font-face` declarations, Tailwind `fontFamily` extends
- **Color palette**: Tailwind `colors` extends, CSS `:root` variables, theme JSON

## Step 2: Token extraction

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

## Step 3: Aesthetic inference

From the extracted tokens, infer:

- **Tone**: which of the 13 tones in [`references-regrounded.md` §8.1](../../../docs/integrations/impeccable/references-regrounded.md) best matches the existing system. Be specific: a Tailwind project with `slate-900` + serif body + lots of whitespace is likely `editorial/magazine` or `luxury/refined`.
- **Typography pair**: identify display + body fonts from the extracted font-family list. If only one font is found, mark "single-font system" and recommend a body or display addition for the DESIGN.md output.
- **Accent color**: which color appears most often in CTA/active-state classes. That is the de-facto accent.
- **Motion vocabulary**: grep for `transition-`, `animate-`, `motion.`, `useMotion`. Classify the present pattern (or "static").
- **Composition density**: count average components per page (`grep -c '<.*v-' src/pages/*.vue`). High density (>15) → "controlled density"; low (<8) → "generous whitespace".

If inference is ambiguous (two tones equally plausible), do NOT guess — emit a `## Open questions` section in DESIGN.md asking the user.

## Step 4: Emit DESIGN.md

Write to `DESIGN.md` at the repo root (or the `--out` path). Template:

```markdown
# DESIGN.md

> Project design system source-of-truth. Extracted by /blitz:ui-build on YYYY-MM-DD.
> Spec: https://github.com/google-labs-code/design.md

## Stack

<adapter (primary) + variant from the `scripts/detect-stack.sh` Adapter Stack block; e.g. `vuetify (v4)`, `tailwind-md3`, `quasar`. Determines the token surface ui-build + design-critic target.>

## Tone

<chosen tone from the 13-tone palette in references-regrounded.md §8.1>

**Why**: <one sentence citing the strongest extracted signal>

## Typography

- **Display**: <font name>, fallback: <chain>
- **Body**: <font name>, fallback: <chain>
- **Scale**: <comma-separated sizes derived from extracted tokens>
- **Banned (project-specific)**: any font flagged by the Layer 0 detector (`overused-font`) — see references-regrounded.md §8.1
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

<list any inference ambiguities the extract surfaced; user resolves before the next ui-build run>

## Drift signals (auto-populated by /blitz:check --only design)

<file:line evidence of code drifting from this DESIGN.md — populated by `check`, NOT by the extraction on first run>
```

## Step 5: Verification

Confirm DESIGN.md is consumable, then log to the activity feed:

```bash
test -f DESIGN.md
grep -E '^## (Tone|Typography|Color|Motion|Composition)' DESIGN.md | wc -l   # must be 5
. "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/_lib/common.sh"
blitz_log_event ui-build decision "DESIGN.md extracted" '{"choice":"extract","files":["DESIGN.md"]}'
```

## Step 6: Report, then continue Phase 1

Tell the user in ≤4 lines: the inferred tone and why (one-line citation), the typography pair (or "single-font — recommend pairing"), open questions needing resolution. `ui-build` Phase 1.1 now reads `DESIGN.md` instead of re-discovering tokens every run.

Done when: `DESIGN.md` exists at the repo root with the five canonical sections (Tone, Typography, Color, Motion, Composition), each holding a definite value or an Open-questions entry; a feed line was written; no source file was modified.
