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

python3 - "$REGISTRY" "$ROOT" <<'PY'
import json, sys, os, re, shlex

path = sys.argv[1]
root = sys.argv[2] if len(sys.argv) > 2 else "."
try:
    d = json.load(open(path))
except Exception as e:
    print(f"check-registry-validate: invalid JSON: {e}", file=sys.stderr)
    sys.exit(1)

errors = []
warnings = []
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

    # 4b. command executability (advisory WARNINGS — never fails the gate, so
    #     prose-described regex/counter rows and out-of-package script gaps don't
    #     hard-block; surfaces the R3-CR-01/02 class: bare binaries that don't
    #     ship + dangling scripts/ references). Conservative, two parts:
    #   (a) leading-token of a shell-runnable row resolves to a hyphenated bare
    #       binary (e.g. blitz-import-graph) that is not a known tool/builtin and
    #       not a repo path -> warn. Only checked for git/regex/tsc rows whose
    #       leading token has executable shape; `command`/`counter` rows hold
    #       inspection predicates / operational signals, not shell lines.
    #   (b) any scripts/*.sh referenced anywhere in the command must exist -> warn.
    cmd = det.get("command", "")
    if dt != "semantic":
        SAFE_TOOLS = {
            "grep", "git", "tsc", "npx", "jq", "node", "wc", "test",
            "find", "sed", "awk", "cat", "echo", "head", "tail", "sort",
            "uniq", "python3", "bash", "sh", "rg", "ls", "diff", "xargs",
        }
        # Leading-binary heuristic only on literal-command types — `regex`
        # detection.command is a pattern/prose rule-pack, not a shell invocation.
        if dt in {"command", "import-graph"}:
            first = cmd.strip().split("|")[0].strip()
            try:
                head = (shlex.split(first) or [""])[0]
            except ValueError:
                head = first.split()[0] if first.split() else ""
            # executable shape: hyphenated lowercase name (blitz-import-graph,
            # detect-stack) or a relative path — but NOT a known safe tool.
            looks_binary = bool(re.fullmatch(r"[a-z][a-z0-9]*(?:-[a-z0-9]+)+", head))
            if (looks_binary and head not in SAFE_TOOLS
                    and not os.path.isfile(os.path.join(root, head))):
                warnings.append(
                    f"{cid}: detection.command leading token {head!r} looks like a bare binary "
                    f"that does not ship (not a known tool or repo path)"
                )
        # (b) any scripts/*.sh anywhere in the command must exist
        for m in re.findall(r"(scripts/[\w./-]+\.sh)", cmd):
            # Resolve against both repo-root scripts/ and hooks/scripts/ so a
            # reference like `hooks/scripts/foo.sh` (captured as `scripts/foo.sh`)
            # is not a false "missing" positive.
            if not (os.path.isfile(os.path.join(root, m))
                    or os.path.isfile(os.path.join(root, "hooks", m))):
                warnings.append(f"{cid}: detection.command references missing script {m!r}")

# 5. confidence_gate.reject_bypass present (facts bypass the min-confidence gate)
if "reject_bypass" not in (d.get("confidence_gate") or {}):
    errors.append("confidence_gate.reject_bypass missing")

if warnings:
    print(f"check-registry-validate: {len(warnings)} command-executability warning(s) in {path}:", file=sys.stderr)
    for w in warnings:
        print(f"  ! {w}", file=sys.stderr)

if errors:
    print(f"check-registry-validate: {len(errors)} violation(s) in {path}:", file=sys.stderr)
    for e in errors:
        print(f"  - {e}", file=sys.stderr)
    sys.exit(1)

det_adv = [c["id"] for c in checks if c["id"].startswith("det-") and c["verdict_authority"] == "advisory"]
print(f"check-registry-validate: OK — {len(checks)} checks, derivation clean, "
      f"{len(det_adv)} advisory detectors {det_adv}")
PY
