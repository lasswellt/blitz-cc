#!/usr/bin/env bash
# Schema lint for skills/_shared/check-registry.json (blitz-check-registry/2.0).
# Asserts the verdict_authority derivation invariant, detection presence + type,
# and row-count floor. Mitigates risks.md R2 (registry single-point-of-drift) and
# R5 (lane-tag mis-classification). Exit 0 = pass, 1 = fail.
#
# Usage: check-registry-validate.sh [path-to-registry.json]
set -euo pipefail

ROOT="${CLAUDE_PLUGIN_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
REGISTRY="${1:-${ROOT}/skills/_shared/check-registry.json}"

if [[ ! -f "$REGISTRY" ]]; then
  echo "check-registry-validate: registry not found: $REGISTRY" >&2
  exit 1
fi

python3 - "$REGISTRY" <<'PY'
import json, sys

path = sys.argv[1]
try:
    d = json.load(open(path))
except Exception as e:
    print(f"check-registry-validate: invalid JSON: {e}", file=sys.stderr)
    sys.exit(1)

errors = []
checks = d.get("checks", [])

# 1. row-count floor (20 detectors + 5 pillars + O2/O3/fw = 30 today; floor at 20)
if len(checks) < 20:
    errors.append(f"too few checks: {len(checks)} (<20)")

ALLOWED_TYPES = {"git", "regex", "tsc", "ast", "import-graph", "counter", "command", "semantic"}
DET_TYPES = ALLOWED_TYPES - {"semantic"}

seen_ids = set()
for c in checks:
    cid = c.get("id", "<no-id>")
    if cid in seen_ids:
        errors.append(f"{cid}: duplicate id")
    seen_ids.add(cid)

    lane = c.get("lane")
    sev = c.get("severity")
    va = c.get("verdict_authority")
    det = c.get("detection") or {}

    # 2. verdict_authority derivation invariant
    expected = "reject" if (lane == "deterministic" and sev in {"P0", "P1", "P2"}) else "advisory"
    if va != expected:
        errors.append(f"{cid}: verdict_authority={va!r} but derivation expects {expected!r} (lane={lane}, sev={sev})")

    # 3. detection presence
    if "type" not in det or "command" not in det:
        errors.append(f"{cid}: missing detection.type or detection.command")
        continue

    # 4. detection.type allowed + lane consistency
    dt = det["type"]
    if dt not in ALLOWED_TYPES:
        errors.append(f"{cid}: detection.type={dt!r} not in {sorted(ALLOWED_TYPES)}")
    if lane == "deterministic" and dt not in DET_TYPES:
        errors.append(f"{cid}: deterministic lane must not use detection.type={dt!r}")
    if lane == "semantic" and dt != "semantic":
        errors.append(f"{cid}: semantic lane must use detection.type=='semantic', got {dt!r}")

# 5. confidence_gate.reject_bypass present (facts bypass the min-confidence gate)
if "reject_bypass" not in (d.get("confidence_gate") or {}):
    errors.append("confidence_gate.reject_bypass missing")

if errors:
    print(f"check-registry-validate: {len(errors)} violation(s) in {path}:", file=sys.stderr)
    for e in errors:
        print(f"  - {e}", file=sys.stderr)
    sys.exit(1)

det_adv = [c["id"] for c in checks if c["id"].startswith("det-") and c["verdict_authority"] == "advisory"]
print(f"check-registry-validate: OK — {len(checks)} checks, derivation clean, "
      f"{len(det_adv)} advisory detectors {det_adv}")
PY
