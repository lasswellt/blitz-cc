#!/usr/bin/env bash
# Version sync checker
# ────────────────────
# Reads the authoritative version from .claude-plugin/plugin.json and
# verifies that every other file referencing a plugin version is in
# sync. Emits human-readable warnings to stderr for any drift found.
#
# Exit codes:
#   0 — all references in sync (or no version references found at all)
#   1 — drift detected (caller decides whether to block)
#
# Usage:
#   scripts/check-version-sync.sh          # check from repo root
#   scripts/check-version-sync.sh --quiet  # exit code only, no output
#
# Called by:
#   - hooks/scripts/pre-commit-validate.sh (on git commit, warns only)
#   - can be invoked manually or by the release skill

set -euo pipefail

QUIET=0
if [[ "${1:-}" == "--quiet" ]]; then
  QUIET=1
fi

log() {
  [[ "$QUIET" -eq 1 ]] && return 0
  echo "$@" >&2
}

# Find repo root — works whether called from root or a subdirectory
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT" || exit 0

# --- 1. Read the authoritative version from plugin.json ---
PLUGIN_JSON=".claude-plugin/plugin.json"
if [[ ! -f "$PLUGIN_JSON" ]]; then
  # Not a blitz plugin repo — nothing to check
  exit 0
fi

AUTHORITATIVE=$(grep -oE '"version"[[:space:]]*:[[:space:]]*"[^"]+"' "$PLUGIN_JSON" \
  | head -1 \
  | sed -E 's/.*"([^"]+)"$/\1/')

if [[ -z "$AUTHORITATIVE" ]]; then
  log "WARNING: could not parse version from $PLUGIN_JSON"
  exit 0
fi

DRIFT=0

# --- 2. Check .claude-plugin/marketplace.json (plugin entry version) ---
MARKETPLACE=".claude-plugin/marketplace.json"
if [[ -f "$MARKETPLACE" ]]; then
  # Marketplace manifest wraps plugin version inside plugins[].version
  MK_VERSION=$(grep -oE '"version"[[:space:]]*:[[:space:]]*"[^"]+"' "$MARKETPLACE" \
    | head -1 \
    | sed -E 's/.*"([^"]+)"$/\1/')
  if [[ -n "$MK_VERSION" && "$MK_VERSION" != "$AUTHORITATIVE" ]]; then
    log "  drift: $MARKETPLACE has \"version\": \"$MK_VERSION\" (expected $AUTHORITATIVE)"
    DRIFT=$((DRIFT + 1))
  fi
fi

# --- 3. Check installer/install.sh banner ---
INSTALL_SH="installer/install.sh"
if [[ -f "$INSTALL_SH" ]]; then
  # Matches a banner like: "Claude Code Plugin Installer · v1.1.1"
  BANNER_VERSION=$(grep -oE 'Installer[[:space:]]*·[[:space:]]*v[0-9]+\.[0-9]+\.[0-9]+' "$INSTALL_SH" \
    | head -1 \
    | sed -E 's/.*v//')
  if [[ -n "$BANNER_VERSION" && "$BANNER_VERSION" != "$AUTHORITATIVE" ]]; then
    log "  drift: $INSTALL_SH banner is v$BANNER_VERSION (expected v$AUTHORITATIVE)"
    DRIFT=$((DRIFT + 1))
  fi
fi

# --- 4. Check installer/package.json (.version) ---
INSTALLER_PKG="installer/package.json"
if [[ -f "$INSTALLER_PKG" ]]; then
  # Prefer jq; fall back to a grep/sed parse if jq is unavailable.
  if command -v jq >/dev/null 2>&1; then
    PKG_VERSION=$(jq -r '.version // empty' "$INSTALLER_PKG" 2>/dev/null || echo "")
  else
    PKG_VERSION=$(grep -oE '"version"[[:space:]]*:[[:space:]]*"[^"]+"' "$INSTALLER_PKG" \
      | head -1 \
      | sed -E 's/.*"([^"]+)"$/\1/')
  fi
  if [[ -n "$PKG_VERSION" && "$PKG_VERSION" != "$AUTHORITATIVE" ]]; then
    log "  drift: $INSTALLER_PKG has \"version\": \"$PKG_VERSION\" (expected $AUTHORITATIVE)"
    DRIFT=$((DRIFT + 1))
  fi
fi

# --- 5. Check installer/src/constants.js (VERSION const) ---
CONSTANTS_JS="installer/src/constants.js"
if [[ -f "$CONSTANTS_JS" ]]; then
  # Matches: const VERSION = '2.4.4';  (single or double quotes)
  CONST_VERSION=$(grep -oE "VERSION[[:space:]]*=[[:space:]]*['\"][0-9]+\.[0-9]+\.[0-9]+['\"]" "$CONSTANTS_JS" \
    | head -1 \
    | sed -E "s/.*['\"]([0-9]+\.[0-9]+\.[0-9]+)['\"].*/\1/")
  if [[ -n "$CONST_VERSION" && "$CONST_VERSION" != "$AUTHORITATIVE" ]]; then
    log "  drift: $CONSTANTS_JS has VERSION = '$CONST_VERSION' (expected $AUTHORITATIVE)"
    DRIFT=$((DRIFT + 1))
  fi
fi

# --- 6. Summary ---
if [[ "$DRIFT" -gt 0 ]]; then
  log ""
  log "Version drift detected: $DRIFT file(s) out of sync with $PLUGIN_JSON (v$AUTHORITATIVE)."
  log "Fix: update the drifted file(s) to match, then re-stage and retry the commit."
  exit 1
fi

# All references in sync (or no version references found)
exit 0
