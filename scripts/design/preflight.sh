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
# impeccable is a dependency of the *target project*, not of the Blitz plugin
# (its detector is browser/puppeteer-class). This script never installs it; it
# only checks the target and emits an install hint when absent.
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

# Semantic tier: impeccable must resolve to the exact pin, FROM THE TARGET PROJECT.
if ! command -v node >/dev/null 2>&1; then
  status_sem="UNKNOWN"; reason="node not found — cannot resolve impeccable"
elif resolved=$(node -e "try{process.stdout.write(require(require.resolve('impeccable/package.json',{paths:[process.argv[1]]})).version)}catch(e){process.exit(1)}" "$TARGET" 2>/dev/null); then
  if [ "$resolved" = "$PIN" ]; then
    status_sem="OK"
  else
    status_sem="VERSION_MISMATCH"
    reason="impeccable resolved ${resolved} in target project, expected ${PIN} — run: npm i -D impeccable@${PIN}"
  fi
else
  status_sem="ABSENT"
  reason="impeccable not in target project — install: npm i -D impeccable@${PIN}"
fi

echo "DESIGN_LANE_STATUS deterministic=${status_det} semantic=${status_sem}${reason:+ reason=\"$reason\"}"
if [ "$status_sem" != "OK" ]; then
  echo "DESIGN_LANE_UNAVAILABLE: semantic (vendored impeccable) lane skipped — ${reason}. Deterministic regex rows still ran." >&2
fi
exit 0
