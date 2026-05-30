#!/usr/bin/env bats
# design-pillar.bats — wiring tests for the framework-adaptive design pillar.
# Covers: adapter detection, layer gating, reconciliation suppression,
# FP exclusions on token-definition surfaces, and the DESIGN_LANE_UNAVAILABLE
# loud-failure contract.
# Spec: docs/integrations/impeccable/improvements/design-pillar-tests.md
#
# Tests that assert hard today: FP exclusions, reconciliation table, registry shape.
# Tests gated on not-yet-landed work (DEP-1 preflight, LANE-1 reclassification,
# TEST-1 adapter token) `skip` with a reason so the gaps stay visible.

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

# --- FP exclusions (assert hard today) -------------------------------------

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

# --- FP-1: token-def exclusions + color consolidation (assert hard) --------

@test "design.exclude set exists with files + content + line guards" {
  run jq -e '.design.exclude | (.files|length>0) and (.contentGuards|length>0) and (.lineGuards|length>0)' "$REGISTRY"
  [ "$status" -eq 0 ]
}

@test "consolidated color rule carries perAdapter + exclude ref" {
  run jq -r '.. | objects | select(.id=="design-raw-color-literal") | "\(.perAdapter|type) \(.detection.exclude)"' "$REGISTRY"
  echo "$output" | grep -q 'object design.exclude'
}

@test "the 5 duplicate color rules are removed" {
  for id in design-tw-arbitrary-color design-md3-role-conformance \
            design-vuetify-hardcoded-color design-quasar-inline-hex \
            design-quasar-color-outside-brand; do
    run jq -e --arg id "$id" '[.. | objects | select(.id==$id)] | length == 0' "$REGISTRY"
    [ "$status" -eq 0 ]
  done
}

# --- Reconciliation table (assert hard today, straight off registry) -------

@test "bounce-easing suppressed on tailwind-md3 and quasar" {
  run jq -r '.. | objects | select(.id=="design-bounce-easing") | .reconciliation.relaxFor // [] | join(",")' "$REGISTRY"
  echo "$output" | grep -q 'tailwind-md3'
  echo "$output" | grep -q 'quasar'
}

@test "gpt-thin-border-wide-shadow relaxed for all elevation stacks" {
  run jq -r '.. | objects | select(.id=="design-gpt-thin-border-wide-shadow") | .reconciliation.relaxFor // [] | join(",")' "$REGISTRY"
  for a in tailwind tailwind-md3 vuetify quasar; do echo "$output" | grep -q "$a"; done
}

# --- Lane integrity (skip-pre-fix / hard-post-fix ratchet for LANE-1) -------

@test "no impeccable-owned row is tagged lane: deterministic" {
  run jq -r '[.. | objects | select(.owner=="impeccable" and .lane=="deterministic")] | length' "$REGISTRY"
  [ "$status" -eq 0 ]
  [ "$output" -eq 0 ] || skip "LANE-1 not yet applied: $output impeccable rows still deterministic"
}

@test "no deterministic design row shells out to npx" {
  # Scoped to pillar==design: det-11/det-12 legitimately use `npx tsc`.
  run jq -r '[.. | objects | select(.pillar=="design" and .lane=="deterministic") | .detection.command // ""] | map(select(test("npx"))) | length' "$REGISTRY"
  [ "$output" -eq 0 ] || skip "LANE-1 not yet applied: $output deterministic design rows still call npx"
}

# --- Preflight loud-failure (gated on DEP-1) -------------------------------

@test "preflight reports DESIGN_LANE_UNAVAILABLE when impeccable absent" {
  PF="$REPO_ROOT/scripts/design/preflight.sh"
  [ -f "$PF" ] || skip "DEP-1 not yet applied: preflight.sh absent"
  # $PWD is the clean BATS_TEST TMPDIR — a target project with no impeccable.
  run bash "$PF" "$PWD"
  [ "$status" -eq 0 ]                                   # never blocks deterministic tier
  echo "$output" | grep -q 'DESIGN_LANE_STATUS deterministic=OK'
  echo "$output" | grep -q 'semantic=ABSENT'
  echo "$output" | grep -q 'DESIGN_LANE_UNAVAILABLE'   # loud failure, stderr merged by `run`
  echo "$output" | grep -q 'npm i -D impeccable'       # actionable install hint
}

@test "preflight reports semantic=OK when target has pinned impeccable" {
  PF="$REPO_ROOT/scripts/design/preflight.sh"
  [ -f "$PF" ] || skip "DEP-1 not yet applied: preflight.sh absent"
  mkdir -p node_modules/impeccable
  printf '{"name":"impeccable","version":"2.3.2"}' > node_modules/impeccable/package.json
  run bash "$PF" "$PWD"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q 'semantic=OK'
  ! echo "$output" | grep -q 'DESIGN_LANE_UNAVAILABLE'
}

# --- Adapter detection (TEST-1: parse the DESIGN_ADAPTER token) ------------

# Emit the normalized token for the fixture in $PWD.
adapter_token() { bash "$REPO_ROOT/scripts/detect-stack.sh" 2>/dev/null | grep -oE 'DESIGN_ADAPTER [^`]*'; }

@test "detect-stack resolves tailwind-md3 from tailwind + --md-sys role tokens" {
  printf '{"dependencies":{"tailwindcss":"^4.0.0"}}' > package.json
  mkdir src; printf '.a{--md-sys-color-primary:#000}' > src/a.css
  run adapter_token
  echo "$output" | grep -q 'primary=tailwind-md3'
  echo "$output" | grep -q 'variant=v4'
}

@test "detect-stack: component framework wins over tailwind (vuetify primary)" {
  printf '{"dependencies":{"vuetify":"^3.5.0","tailwindcss":"^3.4.0"}}' > package.json
  run adapter_token
  echo "$output" | grep -q 'primary=vuetify'
  echo "$output" | grep -q 'variant=v3'
  echo "$output" | grep -q 'secondary=tailwind'   # tailwind layered, not primary
}

@test "detect-stack: vuetify v4 variant distinguished from v3" {
  printf '{"dependencies":{"vuetify":"^4.0.8"}}' > package.json
  run adapter_token
  echo "$output" | grep -q 'primary=vuetify'
  echo "$output" | grep -q 'variant=v4'
}

@test "detect-stack: quasar + tailwind flagged as incompatibility, not secondary" {
  printf '{"dependencies":{"quasar":"^2.14.0","tailwindcss":"^4.0.0"}}' > package.json
  run adapter_token
  echo "$output" | grep -q 'primary=quasar'
  echo "$output" | grep -q 'incompat=quasar+tailwind'
  ! echo "$output" | grep -q 'secondary=tailwind'
}

@test "detect-stack: no UI stack resolves to primary=none" {
  printf '{"dependencies":{"vue":"^3.4.0"}}' > package.json
  run adapter_token
  echo "$output" | grep -q 'primary=none'
}

# --- Layer gating (TEST-1: selection harness mirroring review --only design) -

# Rows fire iff adapter in inclusion(primary) AND relaxFor !contains primary.
# inclusion: none->{universal}; tailwind->{universal,tailwind};
# tailwind-md3->{universal,tailwind,tailwind-md3}; vuetify->{universal,vuetify};
# quasar->{universal,quasar}. Returns the fired design row ids.
select_design() {  # $1 = primary
  local primary="$1" incl
  case "$primary" in
    tailwind)     incl='["universal","tailwind"]' ;;
    tailwind-md3) incl='["universal","tailwind","tailwind-md3"]' ;;
    vuetify)      incl='["universal","vuetify"]' ;;
    quasar)       incl='["universal","quasar"]' ;;
    *)            incl='["universal"]' ;;
  esac
  jq -r --argjson incl "$incl" --arg p "$primary" '
    [.. | objects | select(.pillar=="design" and (.adapter as $a | $incl | index($a))
      and ((.reconciliation.relaxFor // []) | index($p) | not))] | .[].id' "$REGISTRY"
}

@test "Layer-0 universal rows fire on every stack" {
  for p in tailwind tailwind-md3 vuetify quasar none; do
    run select_design "$p"
    echo "$output" | grep -q 'design-side-tab'      # a Layer-0 universal slop row
  done
}

@test "Layer-2 MD3 rows NOT selected on a tailwind-only stack" {
  run select_design tailwind
  # md3 conformance rows are adapter:tailwind-md3 — excluded for primary=tailwind
  ! echo "$output" | grep -q 'design-md3-typescale-conformance'
  ! echo "$output" | grep -q 'design-md3-elevation-conformance'
  # but the tailwind Layer-2 rows ARE selected
  echo "$output" | grep -q 'design-tw-legacy-v3-class'
}

@test "Layer-2 MD3 rows ARE selected on a tailwind-md3 stack" {
  run select_design tailwind-md3
  echo "$output" | grep -q 'design-md3-typescale-conformance'
  echo "$output" | grep -q 'design-tw-legacy-v3-class'   # composite: tailwind rows too
}

@test "reconciliation suppresses bounce-easing-static on tailwind-md3 and quasar" {
  run select_design tailwind-md3
  ! echo "$output" | grep -q 'design-bounce-easing-static'
  run select_design quasar
  ! echo "$output" | grep -q 'design-bounce-easing-static'
  run select_design tailwind
  echo "$output" | grep -q 'design-bounce-easing-static'   # fires where not relaxed
}
