#!/usr/bin/env bash
set -uo pipefail
# Detect project tech stack for adaptive skill behavior
# Output is injected into skill context via !`${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh`
# Results are cached for 1 hour in .cc-sessions/stack-profile.cache

CACHE_FILE=".cc-sessions/stack-profile.cache"
CACHE_TTL=3600  # 1 hour in seconds

# Check cache: use if exists and not expired
if [ -f "$CACHE_FILE" ]; then
  if [ "$(uname)" = "Darwin" ]; then
    CACHE_MTIME=$(stat -f %m "$CACHE_FILE" 2>/dev/null || echo "0")
  else
    CACHE_MTIME=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo "0")
  fi
  NOW=$(date +%s)
  AGE=$(( NOW - CACHE_MTIME ))
  if [ "$AGE" -lt "$CACHE_TTL" ]; then
    cat "$CACHE_FILE"
    exit 0
  fi
fi

# Generate fresh detection
{
echo "## Detected Stack Profile"

# Framework
if [ -f "nuxt.config.ts" ] || [ -f "nuxt.config.js" ]; then
  echo "- **Framework**: Nuxt 3"
elif [ -f "vite.config.ts" ] || [ -f "vue.config.js" ]; then
  echo "- **Framework**: Vue 3 (Vite)"
else
  echo "- **Framework**: Unknown"
fi

# UI Framework (from package.json)
if [ -f "package.json" ]; then
  if grep -q '"tailwindcss"' package.json 2>/dev/null; then
    echo "- **UI Framework**: Tailwind CSS"
  elif grep -q '"quasar"' package.json 2>/dev/null; then
    echo "- **UI Framework**: Quasar"
  elif grep -q '"vuetify"' package.json 2>/dev/null; then
    echo "- **UI Framework**: Vuetify"
  else
    echo "- **UI Framework**: None detected"
  fi
fi

# Adapter Stack (design pillar) — precedence-correct selector.
# Spec: docs/integrations/impeccable/adapter-detection.md. Unlike the UI Framework
# block above, a component framework (Quasar/Vuetify) wins over Tailwind, and
# Quasar+Tailwind is flagged as an incompatibility rather than mislabeled Tailwind.
if [ -f "package.json" ]; then
  PKG="$(cat package.json)"
  _has() { printf '%s' "$PKG" | grep -q "\"$1\""; }
  _ver() { printf '%s' "$PKG" | tr ',' '\n' | grep -E "\"$1\"[[:space:]]*:" | grep -oE '[0-9]+' | head -1; }
  MD3=""
  if _has "@material/web" || _has "@material/material-color-utilities" || _has "material-color-utilities"; then
    MD3="dep"
  elif grep -rqsE -- "--md-sys-(color|typescale|shape)" src 2>/dev/null; then
    MD3="token"
  fi
  PRIMARY="none"; VARIANT=""; SECONDARY=""; SECONDARY_ID="none"; INCOMPAT=""; CONF="low"
  if _has "quasar"; then
    PRIMARY="quasar"; CONF="medium"
    { [ -f "quasar.config.js" ] || [ -f "quasar.config.ts" ] || [ -f "src/css/quasar.variables.scss" ]; } && CONF="high"
    _has "tailwindcss" && INCOMPAT="quasar+tailwind"
  elif _has "vuetify" || _has "@vuetify/v0"; then
    PRIMARY="vuetify"; CONF="medium"
    if _has "@vuetify/v0"; then VARIANT="v0"
    else case "$(_ver vuetify)" in 4) VARIANT="v4";; 3) VARIANT="v3";; *) VARIANT="v?";; esac; fi
    grep -rqs "createVuetify" src 2>/dev/null && CONF="high"
    _has "tailwindcss" && { SECONDARY="tailwind (layout only; color owned by Vuetify)"; SECONDARY_ID="tailwind"; }
  elif _has "tailwindcss" && [ -n "$MD3" ]; then
    PRIMARY="tailwind-md3"; CONF="high"
    case "$(_ver tailwindcss)" in 4) VARIANT="tw4";; 3) VARIANT="tw3";; esac
  elif _has "tailwindcss"; then
    PRIMARY="tailwind"; CONF="medium"
    case "$(_ver tailwindcss)" in 4) VARIANT="v4";; 3) VARIANT="v3";; esac
    grep -rqsE '@import +"tailwindcss"|@theme' src 2>/dev/null && CONF="high"
  fi
  echo "- **Adapter (primary)**: ${PRIMARY}${VARIANT:+ ($VARIANT)}"
  [ -n "$SECONDARY" ] && echo "- **Adapter (secondary)**: $SECONDARY"
  [ -n "$INCOMPAT" ] && echo "- **Adapter conflict**: $INCOMPAT — class collisions + unlayered-CSS specificity war; do NOT recommend Tailwind theming on Quasar"
  echo "- **Adapter confidence**: $CONF"
  # Normalized machine token (stable, single-line, parseable). variant codes
  # collapsed to vN/none; consumers (review --only design, audit --pillar design,
  # hooks/tests/design-pillar.bats) parse THIS line, not the prose above.
  TOK_VARIANT="${VARIANT:-none}"; TOK_VARIANT="${TOK_VARIANT/tw/v}"   # tw4->v4, tw3->v3
  echo "- **Design Adapter (token)**: \`DESIGN_ADAPTER primary=${PRIMARY} variant=${TOK_VARIANT} secondary=${SECONDARY_ID} incompat=${INCOMPAT:-none} confidence=${CONF}\`"
  echo "- **Design lanes**: Layer 0 universal slop always on; Layer 1/2 conformance gated to the primary${SECONDARY:+ + secondary}"
fi

# Firebase
if [ -f "firebase.json" ]; then
  echo "- **Backend**: Firebase/GCP"
  if [ -d "functions" ] || [ -d "backend/functions" ]; then
    echo "- **Cloud Functions**: Yes"
  fi
fi

# Monorepo / Build
if [ -f "nx.json" ]; then
  echo "- **Build System**: Nx monorepo"
elif [ -f "pnpm-workspace.yaml" ]; then
  echo "- **Build System**: pnpm workspaces"
elif [ -f "turbo.json" ]; then
  echo "- **Build System**: Turborepo"
else
  echo "- **Build System**: Single package"
fi

# Package manager
if [ -f "pnpm-lock.yaml" ]; then echo "- **Package Manager**: pnpm"
elif [ -f "yarn.lock" ]; then echo "- **Package Manager**: yarn"
elif [ -f "package-lock.json" ]; then echo "- **Package Manager**: npm"
fi

# Validation, testing, state
if [ -f "package.json" ]; then
  grep -q '"zod"' package.json 2>/dev/null && echo "- **Validation**: Zod"
  grep -q '"vitest"' package.json 2>/dev/null && echo "- **Testing**: Vitest"
  grep -q '"jest"' package.json 2>/dev/null && echo "- **Testing**: Jest"
  grep -q '"pinia"' package.json 2>/dev/null && echo "- **State**: Pinia"
  grep -q '"vuefire"' package.json 2>/dev/null && echo "- **Firestore Binding**: VueFire"
  grep -q '"xstate"' package.json 2>/dev/null && echo "- **State Machines**: XState"
fi

# Authorization
if [ -f "package.json" ]; then
  grep -q '"@openfga"' package.json 2>/dev/null && echo "- **Authorization**: OpenFGA"
fi
} | tee "$CACHE_FILE" 2>/dev/null || true

exit 0
