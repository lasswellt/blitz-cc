#!/usr/bin/env bash
set -uo pipefail
# design-lane availability gate (DEP-1).
#
# Classifies the design pillar's two lanes and reports loudly so a run can
# NEVER return silent-green when the semantic (vendored impeccable) lane did
# not execute. The deterministic regex lane needs nothing external and always
# runs; the semantic lane needs impeccable resolved FROM THE TARGET PROJECT
# (the repo under review), pinned to $PIN.
#
# impeccable is never a dependency of the Blitz plugin itself. It resolves from
# the target project first (npx runs a local bin before anything on PATH), then
# from a global install (`npm i -g impeccable@$PIN`), which makes the semantic
# lane available in every project on the machine. npx finds a global bin on
# PATH, so the registry rows' `npx impeccable detect` run it unchanged. Its
# optional puppeteer dependency is only for rendered-URL mode; the file-mode
# `detect` the rows use needs no browser. This script never installs anything.
#
# BLITZ_IMPECCABLE_GLOBAL_ROOT overrides the global node_modules directory
# (default: `npm root -g`); tests point it at an empty dir to stay hermetic.
#
# Usage:  scripts/design/preflight.sh [TARGET_DIR]   (default: $PWD)
# Output: one `DESIGN_LANE_STATUS …` line on stdout (machine-readable);
#         a `DESIGN_LANE_UNAVAILABLE: …` line on stderr when the semantic lane
#         is unavailable. Exit code is always 0 — the caller decides gating.

PIN="2.3.2"
TARGET="${1:-$PWD}"
status_det="OK"          # blitz regex rows — always runnable
status_sem="UNKNOWN"     # vendored impeccable rows
reason=""

# Deterministic tier just needs grep (always present).
if ! command -v grep >/dev/null 2>&1; then
  echo "DESIGN_LANE_STATUS deterministic=UNAVAILABLE semantic=UNKNOWN reason=\"grep missing\""
  echo "DESIGN_DETERMINISTIC_UNAVAILABLE: grep not found" >&2
  exit 0
fi

# Semantic tier: impeccable must resolve to the exact pin — from the target
# project if it has its own copy (that is the one npx will run), else globally.
source=""
if ! command -v node >/dev/null 2>&1; then
  status_sem="UNKNOWN"; reason="node not found — cannot resolve impeccable"
elif resolved=$(node -e "try{process.stdout.write(require(require.resolve('impeccable/package.json',{paths:[process.argv[1]]})).version)}catch(e){process.exit(1)}" "$TARGET" 2>/dev/null); then
  source="project"
  if [ "$resolved" = "$PIN" ]; then
    status_sem="OK"
  else
    status_sem="VERSION_MISMATCH"
    reason="impeccable resolved ${resolved} in target project, expected ${PIN} — run: npm i -D impeccable@${PIN}"
  fi
else
  groot="${BLITZ_IMPECCABLE_GLOBAL_ROOT-$(npm root -g 2>/dev/null)}"
  gver=""
  if [ -n "$groot" ] && [ -f "$groot/impeccable/package.json" ]; then
    gver=$(node -e "try{process.stdout.write(require(process.argv[1]).version)}catch(e){process.exit(1)}" "$groot/impeccable/package.json" 2>/dev/null || true)
  fi
  if [ -n "$gver" ]; then
    source="global"
    if [ "$gver" = "$PIN" ]; then
      status_sem="OK"
    else
      status_sem="VERSION_MISMATCH"
      reason="impeccable resolved ${gver} globally, expected ${PIN} — run: npm i -g impeccable@${PIN}"
    fi
  else
    status_sem="ABSENT"
    reason="impeccable not in target project or installed globally — install: npm i -D impeccable@${PIN} (this project) or npm i -g impeccable@${PIN} (every project)"
  fi
fi

echo "DESIGN_LANE_STATUS deterministic=${status_det} semantic=${status_sem}${source:+ source=${source}}${reason:+ reason=\"$reason\"}"
if [ "$status_sem" != "OK" ]; then
  echo "DESIGN_LANE_UNAVAILABLE: semantic (vendored impeccable) lane skipped — ${reason}. Deterministic regex rows still ran." >&2
fi
exit 0
