#!/usr/bin/env node
/**
 * E2 vendoring generator — emits Blitz `design`-pillar rows into
 * skills/_shared/check-registry.json from impeccable's antipattern registry,
 * plus the new Layer-1 raw-value family + Layer-2 Tailwind conformance rows.
 *
 * Engine decision (locked): the 41 impeccable-provided rows shell out to
 *   npx impeccable detect --json --gpt --gemini ${TARGETS}
 * (one run; review filters the JSON output by detection.filter == antipattern id).
 * The 6 new rows use native regex commands.
 *
 * Provenance: vendored rows carry source: impeccable@2.3.2 ... (Apache-2.0).
 * Idempotent: aborts if design-* rows already present.
 *
 * Usage: node scripts/maint/design/gen-design-rows.mjs [impeccable-antipatterns.mjs] [--write]
 *   default impeccable path: /tmp/impeccable-src/cli/engine/registry/antipatterns.mjs
 */
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const AP_PATH = process.argv[2] && !process.argv[2].startsWith('--')
  ? process.argv[2]
  : '/tmp/impeccable-src/cli/engine/registry/antipatterns.mjs';
const WRITE = process.argv.includes('--write');
const REGISTRY = path.resolve('skills/_shared/check-registry.json');

const DETECT_CMD = 'npx impeccable detect --json --gpt --gemini ${TARGETS}';

// The 2 rules whose ban reconciles per adapter (Layer 1). Every relaxFor carries a cite.
const RECONCILED = {
  'bounce-easing': {
    relaxFor: ['tailwind-md3', 'quasar'],
    cite: 'M3 Expressive spring motion (emphasized-* overshoot curves); Quasar Animate.css bounceIn/Out vocabulary',
  },
  'gpt-thin-border-wide-shadow': {
    relaxFor: ['tailwind', 'tailwind-md3', 'vuetify', 'quasar'],
    cite: 'stack elevation systems: TW shadow-*, MD3 levels 0-5 + tonal surface-container-*, Vuetify elevation prop, Quasar shadow-1..24',
  },
};
// a11y-hard rules → P2 (deterministic P2 derives to reject). Everything else P3/advisory.
const A11Y_REJECT = new Set(['low-contrast']);

function deriveVA(lane, sev) {
  return lane === 'deterministic' && ['P0', 'P1', 'P2'].includes(sev) ? 'reject' : 'advisory';
}

function vendorRow(ap) {
  const layer = RECONCILED[ap.id] ? 1 : 0;
  const severity = A11Y_REJECT.has(ap.id) ? 'P2' : 'P3';
  return {
    id: `design-${ap.id}`,
    name: ap.name,
    lane: 'deterministic',
    pillar: 'design',
    layer,
    adapter: 'universal',
    base_confidence: 0.7,
    severity,
    verdict_authority: deriveVA('deterministic', severity),
    detection: { type: 'command', command: DETECT_CMD, filter: ap.id },
    enforcement: ['skill:review --only design', 'skill:audit --pillar design'],
    owner: 'impeccable',
    consolidated_target: 'both',
    escape_hatch: 'documented intentional brand system in DESIGN.md',
    reconciliation: RECONCILED[ap.id] || null,
    source: `impeccable@2.3.2 cli/engine/registry/antipatterns.mjs#${ap.id} (re-grounded, framework-adaptive)`,
    notes: `Vendored Layer ${layer} ${ap.category} rule. ${(ap.description || '').slice(0, 90)}`,
  };
}

function newRow(id, layer, adapter, name, command, reconciliation, notes, severity = 'P3', dtype = 'regex') {
  return {
    id, name, lane: 'deterministic', pillar: 'design', layer, adapter,
    base_confidence: 0.65, severity, verdict_authority: deriveVA('deterministic', severity),
    detection: { type: dtype, command },
    enforcement: ['skill:review --only design', 'skill:audit --pillar design'],
    owner: 'blitz', consolidated_target: 'both',
    escape_hatch: 'documented intentional brand system in DESIGN.md',
    reconciliation: reconciliation || null,
    source: 'blitz framework-adaptive design pillar (new authorship; inspired by impeccable conformanceRules)',
    notes,
  };
}

const NEW_ROWS = [
  newRow('design-raw-color-literal', 1, 'universal', 'Raw color literal (use a role token)',
    "grep -rnE '#[0-9a-fA-F]{3,8}' ${TARGETS} --include=*.vue --include=*.css --include=*.scss",
    null, 'Layer 1 token-discipline. Raw hex where a color-role token exists; adapter-resolved at firing. Never relaxed.'),
  newRow('design-raw-radius', 1, 'universal', 'Raw border-radius (use a shape token)',
    "grep -rnE 'border-radius:[[:space:]]*[0-9]+(px|rem)' ${TARGETS} --include=*.vue --include=*.css --include=*.scss",
    null, 'Layer 1 token-discipline. Arbitrary radius where a shape-scale token exists; defers to stack tokens.'),
  newRow('design-raw-spacing', 1, 'universal', 'Raw spacing literal (use a spacing token)',
    "grep -rnE '(margin|padding|gap):[[:space:]]*[0-9]+(px|rem)' ${TARGETS} --include=*.vue --include=*.css --include=*.scss",
    null, 'Layer 1 token-discipline. Arbitrary spacing where a spacing-scale token exists.'),
  newRow('design-tw-legacy-v3-class', 2, 'tailwind', 'Tailwind v3 legacy class',
    "grep -rnE 'bg-gradient-to-|bg-\\[--|@tailwind[[:space:]]+base' ${TARGETS} --include=*.vue --include=*.html --include=*.css",
    null, 'Layer 2 Tailwind conformance. v3 classes renamed in v4 (bg-gradient-to-*->bg-linear-*, bg-[--var]->bg-(--var), @tailwind base->@import).'),
  newRow('design-tw-apply-overuse', 2, 'tailwind', 'Tailwind @apply overuse',
    "grep -rnc '@apply' ${TARGETS} --include=*.css --include=*.vue",
    null, 'Layer 2 Tailwind conformance. v4 discourages @apply for component abstractions; extract a component.'),
  newRow('design-tw-arbitrary-color', 2, 'tailwind', 'Tailwind arbitrary color value',
    "grep -rnE 'bg-\\[#|text-\\[#|border-\\[#' ${TARGETS} --include=*.vue --include=*.html",
    null, 'Layer 2 Tailwind conformance. Arbitrary [#hex] where a @theme --color-* token exists (advisory escape-hatch).'),
];

// E4 — Layer-2 conformance for the other 3 adapters + the quasar+tailwind incompatibility.
// tailwind-md3 is a composite: it ALSO fires the tailwind L2 rows via firing-logic composition.
const E4_ROWS = [
  newRow('design-md3-role-conformance', 2, 'tailwind-md3', 'MD3 color-role conformance',
    "grep -rnE '(color|background-color):[[:space:]]*(#|rgb)' ${TARGETS} --include=*.vue --include=*.css",
    null, 'Layer 2 MD3. Raw color where an --md-sys-color-* role (+ on-* pair) should be used.'),
  newRow('design-md3-typescale-conformance', 2, 'tailwind-md3', 'MD3 type-scale conformance',
    "grep -rnE 'font-size:[[:space:]]*[0-9]' ${TARGETS} --include=*.vue --include=*.css",
    null, 'Layer 2 MD3. Raw font-size where an --md-sys-typescale-<role> token (15-role scale) should be used.'),
  newRow('design-md3-corner-conformance', 2, 'tailwind-md3', 'MD3 corner conformance',
    "grep -rnE 'border-radius:[[:space:]]*[0-9]' ${TARGETS} --include=*.vue --include=*.css",
    null, 'Layer 2 MD3. Raw radius where an --md-sys-shape-corner-* token (none..full) should be used.'),
  newRow('design-md3-elevation-conformance', 2, 'tailwind-md3', 'MD3 elevation conformance',
    "grep -rnE 'box-shadow:' ${TARGETS} --include=*.vue --include=*.css",
    null, 'Layer 2 MD3. Raw shadow where --md-elevation-level (0-5) or tonal surface-container-* should be used.'),
  newRow('design-vuetify-hardcoded-color', 2, 'vuetify', 'Vuetify hardcoded color in component',
    "grep -rnE '(color|background-color):[[:space:]]*(#|rgb)' ${TARGETS} --include=*.vue --include=*.css",
    null, 'Layer 2 Vuetify. Hardcoded color in a component (use rgb(var(--v-theme-*))). The theme colors{} config is exempt.'),
  newRow('design-vuetify-important-override', 2, 'vuetify', 'Vuetify !important override',
    "grep -rnE '!important' ${TARGETS} --include=*.vue --include=*.css",
    null, 'Layer 2 Vuetify. Fighting component defaults with !important; use props / theme / SASS variables instead.'),
  newRow('design-vuetify-v4-rgba-theme-var', 2, 'vuetify', 'Vuetify v4 rgba(var(--v-theme-*)) syntax',
    "grep -rnE 'rgba\\([[:space:]]*var\\(--v-theme-' ${TARGETS} --include=*.vue --include=*.css",
    null, 'Layer 2 Vuetify v4. rgba(var(--v-theme-*),a) breaks for transparent theme colors in v4; use color-mix().'),
  newRow('design-quasar-inline-hex', 2, 'quasar', 'Quasar inline hex outside variables.scss',
    "grep -rnE 'style=.*#[0-9a-fA-F]{3,6}' ${TARGETS} --include=*.vue",
    null, 'Layer 2 Quasar. Inline hex bypasses theming; use bg-primary / setCssVar (quasar.variables.scss is exempt).'),
  newRow('design-quasar-color-outside-brand', 2, 'quasar', 'Quasar color outside brand palette',
    "grep -rnE '(color|background-color):[[:space:]]*#' ${TARGETS} --include=*.vue --include=*.css",
    null, 'Layer 2 Quasar. Raw color outside the 8 brand vars + palette vocabulary; use $primary-family / bg-*/text-*.'),
  newRow('design-quasar-tailwind-coexist', 2, 'quasar', 'Quasar + Tailwind incompatibility',
    'scripts/detect-stack.sh | grep -q "Adapter conflict: quasar+tailwind"',
    null, 'Layer 2 Quasar. Build conflict: class collisions + unlayered-CSS specificity war; Quasar overrides Tailwind on <q-*>.',
    'P1', 'command'),
];

// --- load impeccable antipatterns ---
const mod = await import(pathToFileURL(AP_PATH).href);
const ANTIPATTERNS = mod.ANTIPATTERNS || mod.default;
if (!Array.isArray(ANTIPATTERNS)) {
  console.error(`gen-design-rows: could not load ANTIPATTERNS from ${AP_PATH}`);
  process.exit(1);
}

const rows = [...ANTIPATTERNS.map(vendorRow), ...NEW_ROWS, ...E4_ROWS];
const byLayer = rows.reduce((a, r) => ((a[r.layer] = (a[r.layer] || 0) + 1), a), {});
const byAdapter = rows.reduce((a, r) => ((a[r.adapter] = (a[r.adapter] || 0) + 1), a), {});
console.error(`gen-design-rows: ${rows.length} design rows (by layer ${JSON.stringify(byLayer)}, by adapter ${JSON.stringify(byAdapter)})`);

if (!WRITE) {
  console.log(JSON.stringify(rows, null, 2));
  console.error('(dry run — pass --write to splice into the registry)');
  process.exit(0);
}

// --- textual splice into check-registry.json (clean, additions-only diff) ---
let text = fs.readFileSync(REGISTRY, 'utf8');
// incremental idempotency: add only rows not already in the registry (so re-runs add new adapters).
const existing = new Set([...text.matchAll(/"id":\s*"(design-[^"]+)"/g)].map((m) => m[1]));
const missing = rows.filter((r) => !existing.has(r.id));
if (!missing.length) {
  console.error(`gen-design-rows: all ${rows.length} design rows already present — nothing to add (idempotent).`);
  process.exit(2);
}
console.error(`gen-design-rows: ${existing.size} existing design rows; adding ${missing.length} new.`);
const ANCHOR = '\n  ],\n  "confidence_gate"';
if (!text.includes(ANCHOR)) {
  console.error('gen-design-rows: could not find the checks-array close anchor.');
  process.exit(1);
}
// each row pretty-printed at 4-space base indent; non-ASCII re-escaped to \uXXXX to match file style
const rowsText = missing
  .map((r) => '    ' + JSON.stringify(r, null, 2).split('\n').join('\n    '))
  .join(',\n')
  .replace(/[-￿]/g, (c) => '\\u' + c.charCodeAt(0).toString(16).padStart(4, '0'));
text = text.replace(ANCHOR, `,\n${rowsText}${ANCHOR}`);
// keep detector_count header honest (idempotent — annotate once)
if (!text.includes('design pillar')) {
  text = text.replace(/("revalidated":\s*")([^"]*)(")/, `$1$2 + design pillar (impeccable@2.3.2 + new L1/L2)$3`);
}
fs.writeFileSync(REGISTRY, text);
console.error(`gen-design-rows: spliced ${missing.length} rows into ${REGISTRY}`);
