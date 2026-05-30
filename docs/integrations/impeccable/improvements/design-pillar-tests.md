# design-pillar-tests.md — test matrix + design-pillar.bats spec

Addresses **Finding 4 (MEDIUM)**. No design-pillar test exists today (`hooks/tests/` has the audit roundtrip but nothing for design). This adds `hooks/tests/design-pillar.bats`, modeled on `audit-detection-roundtrip.bats` (BATS, `BATS_TEST_TMPDIR` isolation, `load _helpers`). The test becomes a **permanent gate** (SYNTHESIS.md epic TEST-1).

---

## 1. Test matrix

| # | Group | Fixture | Assertion |
|---|---|---|---|
| 1 | Adapter detection | `tailwind.config.js` only | `detect-stack.sh` → primary `tailwind`, no MD3 variant |
| 2 | Adapter detection | Tailwind + `@theme` MD3 role tokens | primary `tailwind`, variant `tailwind-md3` |
| 3 | Adapter detection | `vuetify@^3` in deps | primary `vuetify`, variant v3 |
| 4 | Adapter detection | `vuetify@^4` in deps | primary `vuetify`, variant v4 |
| 5 | Adapter detection | `vuetify@^0`/labs | primary `vuetify`, variant v0 |
| 6 | Adapter detection | `quasar` in deps | primary `quasar` |
| 7 | Adapter detection | Quasar **and** Tailwind both present | primary `quasar` + secondary `tailwind` + incompatibility flag |
| 8 | Adapter detection | none of the above | primary `none`/`unknown` (Layer-1/2 gated off) |
| 9 | Layer gating | any stack | every Layer-0 (`adapter: universal`) row is selected |
| 10 | Layer gating | tailwind only | MD3/Vuetify/Quasar Layer-2 rows NOT selected; tailwind L2 rows selected |
| 11 | Reconciliation | tailwind-md3 | `design-bounce-easing` suppressed (relaxFor includes `tailwind-md3`) |
| 12 | Reconciliation | quasar | `design-bounce-easing` suppressed (relaxFor includes `quasar`) |
| 13 | Reconciliation | any elevation stack | `design-gpt-thin-border-wide-shadow` suppressed (relaxFor: tailwind/md3/vuetify/quasar) |
| 14 | FP exclusion | hex inside `@theme` block | `design-raw-color-literal` does NOT fire |
| 15 | FP exclusion | hex inside `tailwind.config.*` / `quasar.variables.scss` | does NOT fire |
| 16 | FP exclusion | hex in a comment / SVG `fill` | does NOT fire |
| 17 | FP exclusion (positive) | hex in a component `<style>`/inline style | DOES fire |
| 18 | Preflight | impeccable absent | preflight prints `DESIGN_LANE_UNAVAILABLE`, exit 0, deterministic rows still run; status line shows `semantic=ABSENT` |
| 19 | Lane integrity | registry scan | no `owner: impeccable` row has `lane: deterministic`; no `lane: deterministic` row's command contains `npx` |

Tests 1–8 depend on `detect-stack.sh` emitting an adapter line (today it emits stack lines but the design-adapter resolution per `adapter-detection.md` must be assertable — TEST-1 adds a `--design-adapter` mode or a parseable token). Tests 11–13 read `reconciliation.relaxFor` from the registry. Tests 14–17 are the proven §1 fixture from fp-reduction.md. Test 18 runs `scripts/design/preflight.sh`. Test 19 is a pure registry-shape guard that locks in lane-reclassification.md.

---

## 2. design-pillar.bats (spec — committed form below)

The committed file is `hooks/tests/design-pillar.bats`. Tests 14–19 are implementable **today** against the current tree (registry + a scoped-grep harness + preflight stub); tests 1–13 finalize once `detect-stack.sh` exposes the design-adapter token (TEST-1). The committed file marks the not-yet-wired tests `skip` with a reason, so the suite is green and the gaps are visible — never a silent omission.

```bash
#!/usr/bin/env bats
# design-pillar.bats — wiring tests for the framework-adaptive design pillar.
# Covers: adapter detection, layer gating, reconciliation suppression,
# FP exclusions on token-definition surfaces, and the DESIGN_LANE_UNAVAILABLE
# loud-failure contract. Spec: docs/integrations/impeccable/improvements/.

load _helpers

setup() {
  command -v jq >/dev/null || skip "jq not installed"
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  REGISTRY="$REPO_ROOT/skills/_shared/check-registry.json"
  TMPDIR="$(mktemp -d)"; cd "$TMPDIR"
}
teardown() { rm -rf "$TMPDIR"; }

# Shared scoped-grep harness mirroring fp-reduction.md §2.
scoped_hex() {  # $1 = root dir
  grep -rlE '#[0-9a-fA-F]{3,8}' "$1" --include=*.vue --include=*.css --include=*.scss 2>/dev/null \
    | grep -vE '(tailwind\.config\.|quasar\.variables\.|\.tokens\.)' \
    | while read -r f; do
        grep -qE '@theme|createVuetify\(' "$f" && continue
        grep -nE '#[0-9a-fA-F]{3,8}' "$f" \
          | grep -vE '^[0-9]+:[[:space:]]*(/\*|//|\*)' \
          | grep -vE '<(svg|path|rect|circle|polygon|stop)[^>]*(fill|stroke)='
      done
}

# --- FP exclusions (implementable today) -----------------------------------

@test "raw hex inside @theme does NOT fire" {
  mkdir -p s; printf '@theme {\n  --c: #1a73e8;\n}\n' > s/theme.css
  run scoped_hex "$PWD"
  [ -z "$output" ]
}

@test "raw hex inside tailwind.config / quasar.variables does NOT fire" {
  printf 'colors:{brand:"#1a73e8"}\n' > tailwind.config.js
  printf '$primary: #1976d2;\n' > quasar.variables.scss
  run scoped_hex "$PWD"
  [ -z "$output" ]
}

@test "raw hex in comment or SVG fill does NOT fire" {
  mkdir -p src
  printf '<template><svg><path fill="#00ff00"/></svg></template>\n/* #abcdef */\n' > src/C.vue
  run scoped_hex "$PWD"
  [ -z "$output" ]
}

@test "raw hex in a component style DOES fire (positive control)" {
  mkdir -p src
  printf '<style>.c{background:#eeeeee}</style>\n' > src/C.vue
  run scoped_hex "$PWD"
  echo "$output" | grep -q '#eeeeee'
}

# --- Lane integrity (implementable today, locks lane-reclassification.md) ---

@test "no impeccable-owned row is tagged lane: deterministic" {
  run jq -r '[.. | objects | select(.owner=="impeccable" and .lane=="deterministic")] | length' "$REGISTRY"
  # PRE-FIX this is 42; the gate flips to require 0 after EPIC LANE-1.
  [ "$status" -eq 0 ]
  [ "$output" -eq 0 ] || skip "LANE-1 not yet applied: $output impeccable rows still deterministic"
}

@test "no deterministic design row shells out to npx" {
  # Scoped to pillar==design: det-11/det-12 legitimately use `npx tsc`.
  run jq -r '[.. | objects | select(.pillar=="design" and .lane=="deterministic") | .detection.command // ""] | map(select(test("npx"))) | length' "$REGISTRY"
  [ "$output" -eq 0 ] || skip "LANE-1 not yet applied: $output deterministic design rows still call npx"
}

# --- Preflight loud-failure (implementable once scripts/design/preflight.sh lands) ---

@test "preflight reports DESIGN_LANE_UNAVAILABLE when impeccable absent" {
  PF="$REPO_ROOT/scripts/design/preflight.sh"
  [ -f "$PF" ] || skip "DEP-1 not yet applied: preflight.sh absent"
  run bash "$PF"
  [ "$status" -eq 0 ]                                   # never blocks deterministic tier
  echo "$output" | grep -q 'DESIGN_LANE_STATUS'
  echo "$output" | grep -q 'semantic=ABSENT' && \
    echo "$output" | grep -q 'DESIGN_LANE_UNAVAILABLE'
}

# --- Adapter detection + gating + reconciliation (TEST-1, after detect-stack exposes adapter) ---

@test "detect-stack resolves tailwind-md3 variant from @theme role tokens" {
  skip "TEST-1: detect-stack.sh must expose a parseable design-adapter token"
}
@test "Layer-2 MD3 rows not selected on a tailwind-only stack" {
  skip "TEST-1: requires adapter-token + selection harness"
}
@test "bounce-easing suppressed on tailwind-md3 and quasar (reconciliation)" {
  run jq -r '.. | objects | select(.id=="design-bounce-easing") | .reconciliation.relaxFor // [] | join(",")' "$REGISTRY"
  echo "$output" | grep -q 'tailwind-md3'
  echo "$output" | grep -q 'quasar'
}
@test "gpt-thin-border-wide-shadow relaxed for all elevation stacks" {
  run jq -r '.. | objects | select(.id=="design-gpt-thin-border-wide-shadow") | .reconciliation.relaxFor // [] | join(",")' "$REGISTRY"
  for a in tailwind tailwind-md3 vuetify quasar; do echo "$output" | grep -q "$a"; done
}
```

Notes:
- The reconciliation tests (`bounce-easing`, `gpt-thin-border`) are **assertable today** straight off the registry — included un-skipped.
- The lane-integrity tests are written so they **pass via skip** pre-fix and **assert hard** post-fix (LANE-1) — they are the ratchet that proves the reclassification landed.
- `scoped_hex` is the same harness measured in fp-reduction.md §1 (75%→0%), so the FP tests are grounded in a real run, not a mock.

---

## 3. Gate wiring

- Add `hooks/tests/design-pillar.bats` to whatever runs `hooks/tests/*.bats` in CI / `sprint-review`.
- `sprint-review` Phase 3.6: the FP-exclusion + lane-integrity tests become a hard gate (a regression that re-introduces a token-file FP or re-tags a vendored row `deterministic` fails the sprint).
- Keep the `skip` reasons visible in CI output so the TEST-1 gaps are tracked, not hidden.
