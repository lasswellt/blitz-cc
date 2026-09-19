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

# --- 3. Check Claude Code floor citations against .claude-plugin/compat.json ---
COMPAT_JSON=".claude-plugin/compat.json"
if [[ -f "$COMPAT_JSON" ]]; then
  CC_MIN=$(python3 -c "import json;print(json.load(open('$COMPAT_JSON'))['cc_min'])" 2>/dev/null || true)
  ALLOWED=$(python3 -c "
import json; d=json.load(open('$COMPAT_JSON'))
vals={d['cc_min'], d.get('cc_min_slash','')} | set(d.get('features',{}).values())
print(' '.join(sorted(v for v in vals if v)))" 2>/dev/null || true)
  CITED=$(python3 -c "import json;print(' '.join(json.load(open('$COMPAT_JSON')).get('cited_in',[])))" 2>/dev/null || true)
  for f in $CITED; do
    [[ -f "$f" ]] || continue
    while IFS= read -r ver; do
      [[ -z "$ver" ]] && continue
      case " $ALLOWED " in
        *" $ver "*) ;;
        *) log "  drift: $f cites Claude Code $ver — not cc_min ($CC_MIN) nor a feature floor in $COMPAT_JSON"
           DRIFT=$((DRIFT + 1)) ;;
      esac
    done < <(grep -oE '2\.1\.[0-9]{2,3}' "$f" | sort -u)
  done
  # The effective floor must be stated verbatim in the consumer-facing files.
  for f in README.md .claude-plugin/plugin.json; do
    [[ -f "$f" ]] || continue
    if ! grep -q "$CC_MIN" "$f"; then
      log "  drift: $f does not state the effective floor $CC_MIN"
      DRIFT=$((DRIFT + 1))
    fi
  done
fi

# --- 7. Summary ---
if [[ "$DRIFT" -gt 0 ]]; then
  log ""
  log "Version drift detected: $DRIFT file(s) out of sync with $PLUGIN_JSON (v$AUTHORITATIVE)."
  log "Fix: update the drifted file(s) to match, then re-stage and retry the commit."
  exit 1
fi

# All references in sync (or no version references found)
exit 0
