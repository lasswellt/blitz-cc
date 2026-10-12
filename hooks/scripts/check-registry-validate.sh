#!/usr/bin/env bash
# Schema lint for skills/_shared/check-registry.json (blitz-check-registry/2.0).
# Asserts the verdict_authority derivation invariant, detection presence + type,
# the axis enums (lane, pillar, severity, consolidated_target, stacks, and layer /
# adapter on design rows), the detector_count metadata (every stored number is
# recomputed from the rows), the Apache-2.0 attribution block and the source tag on
# every vendored impeccable row, and a row-count floor. Mitigates risks.md R2
# (registry single-point-of-drift) and R5 (lane-tag mis-classification), and
# enforces docs/integrations/impeccable/ATTRIBUTION.md §3 and §5.
# Exit 0 = pass, 1 = fail.
#
# Usage: check-registry-validate.sh [path-to-registry.json]
set -euo pipefail

# The script ships inside the plugin, so its own location names the plugin root even
# when the caller's cwd is a scratch directory or another repository.
SELF_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ROOT="${CLAUDE_PLUGIN_ROOT:-$SELF_ROOT}"
REGISTRY="${1:-${ROOT}/skills/_shared/check-registry.json}"

if [[ ! -f "$REGISTRY" ]]; then
  echo "check-registry-validate: registry not found: $REGISTRY" >&2
  exit 1
fi

python3 - "$REGISTRY" "$ROOT" <<'PY'
import json, sys, os, re, shlex
from collections import Counter

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
if not isinstance(checks, list):
    print("check-registry-validate: checks must be a list", file=sys.stderr)
    sys.exit(1)

# 1. row-count floor: a truncated or half-written registry must not pass.
if len(checks) < 20:
    errors.append(f"too few checks: {len(checks)} (<20)")

# Axis enums. Documented in skills/_shared/quality.reference.md §Axes and in this
# registry's own field_contract; a new value is added in both places first.
LANES = {"deterministic", "semantic"}
PILLARS = {"architecture", "performance", "security", "maintainability", "robustness",
           "shortcut", "wiring", "completeness", "framework", "design"}
SEVERITIES = {"P0", "P1", "P2", "P3"}
TARGETS = {"check", "audit", "both", "orthogonal"}
LAYERS = {0, 1, 2}
ADAPTERS = {"universal", "tailwind", "tailwind-md3", "vuetify", "quasar"}
ALLOWED_TYPES = {"git", "regex", "tsc", "ast", "import-graph", "counter", "command", "semantic"}
DET_TYPES = ALLOWED_TYPES - {"semantic"}

# stacks: "*" plus the ids `scripts/toolchain.sh stacks` can emit, read from the same
# table the script uses so the two cannot drift. The builtin list is only a fallback
# for a copy of the validator that runs without the templates directory.
STACK_TABLE = os.path.join(root, "templates", "toolchain.default.json")
FALLBACK_STACKS = {"node", "deno", "python", "rust", "go", "jvm", "ruby", "dotnet", "php", "elixir", "swift"}
try:
    STACKS = {s["id"] for s in json.load(open(STACK_TABLE))["stacks"]}
except Exception as e:
    warnings.append(f"stack table {STACK_TABLE} unreadable ({e}); using the builtin stack list")
    STACKS = set(FALLBACK_STACKS)
STACKS.add("*")

# Vendored rows (docs/integrations/impeccable/ATTRIBUTION.md §3): owner impeccable, and
# the detection shells out to `impeccable detect`. Their source tag must name the
# upstream version, the rule id, the license and the attribution file.
VENDORED_SOURCE_RX = re.compile(r"^impeccable@(\d+\.\d+\.\d+) \S+#[A-Za-z0-9_.-]+ \(.*\)$")
attribution = d.get("attribution")
notice_version = None
if not isinstance(attribution, dict):
    errors.append("attribution block missing (Apache-2.0 §4(b) notice for the vendored impeccable rows)")
else:
    notice = attribution.get("notice")
    if not isinstance(notice, str) or not all(s in notice for s in ("pbakaus/impeccable@", "Apache-2.0", "ATTRIBUTION.md")):
        errors.append("attribution.notice must name pbakaus/impeccable@<version>, Apache-2.0 and ATTRIBUTION.md")
    else:
        m = re.search(r"pbakaus/impeccable@(\d+\.\d+\.\d+)", notice)
        notice_version = m.group(1) if m else None
        if notice_version is None:
            errors.append("attribution.notice does not pin an impeccable version (impeccable@X.Y.Z)")
    lic = attribution.get("license")
    if not isinstance(lic, str) or not lic:
        errors.append("attribution.license must be the path of the vendored Apache-2.0 text")
    elif not os.path.isfile(os.path.join(root, lic)):
        warnings.append(f"attribution.license {lic!r} not found under {root} (CI checks the file itself)")

def is_vendored(c):
    det = c.get("detection") or {}
    return c.get("owner") == "impeccable" or "impeccable detect" in str(det.get("command", ""))

seen_ids = set()
for c in checks:
    cid = c.get("id", "<no-id>")
    if not isinstance(cid, str) or not cid:
        errors.append("a row has no string id")
        cid = "<no-id>"
    if cid in seen_ids:
        errors.append(f"{cid}: duplicate id")
    seen_ids.add(cid)

    lane = c.get("lane")
    sev = c.get("severity")
    va = c.get("verdict_authority")
    det = c.get("detection") or {}

    # 2. axis enums
    if lane not in LANES:
        errors.append(f"{cid}: lane={lane!r} not in {sorted(LANES)}")
    if c.get("pillar") not in PILLARS:
        errors.append(f"{cid}: pillar={c.get('pillar')!r} not in {sorted(PILLARS)}")
    if sev not in SEVERITIES:
        errors.append(f"{cid}: severity={sev!r} not in {sorted(SEVERITIES)}")
    if c.get("consolidated_target") not in TARGETS:
        errors.append(f"{cid}: consolidated_target={c.get('consolidated_target')!r} not in {sorted(TARGETS)}")
    stacks = c.get("stacks")
    if not isinstance(stacks, list) or not stacks:
        errors.append(f"{cid}: stacks must be a non-empty list ([\"*\"] for every stack)")
    else:
        bad = [s for s in stacks if not isinstance(s, str) or s not in STACKS]
        if bad:
            errors.append(f"{cid}: stacks {bad!r} not in {sorted(STACKS)}")
    if c.get("pillar") == "design":
        if c.get("layer") not in LAYERS:
            errors.append(f"{cid}: design row layer={c.get('layer')!r} not in {sorted(LAYERS)}")
        if c.get("adapter") not in ADAPTERS:
            errors.append(f"{cid}: design row adapter={c.get('adapter')!r} not in {sorted(ADAPTERS)}")

    # 2a. source: required on every row; the vendored shape on impeccable rows
    src = c.get("source")
    if not isinstance(src, str) or not src.strip():
        errors.append(f"{cid}: source missing or empty (primary-source citation is required)")
    elif is_vendored(c):
        m = VENDORED_SOURCE_RX.match(src)
        if not m or "Apache-2.0" not in src or "docs/integrations/impeccable/ATTRIBUTION.md" not in src:
            errors.append(
                f"{cid}: vendored impeccable row needs source "
                f"'impeccable@<version> <upstream-path>#<rule-id> (...; Apache-2.0, see "
                f"docs/integrations/impeccable/ATTRIBUTION.md)', got {src!r}"
            )
        elif notice_version and m.group(1) != notice_version:
            errors.append(
                f"{cid}: source pins impeccable@{m.group(1)} but attribution.notice pins "
                f"impeccable@{notice_version}; re-vendor the rows or update the notice together"
            )

    # 3. verdict_authority derivation invariant
    expected = "reject" if (lane == "deterministic" and sev in {"P0", "P1", "P2"}) else "advisory"
    if va != expected:
        errors.append(f"{cid}: verdict_authority={va!r} but derivation expects {expected!r} (lane={lane}, sev={sev})")

    # 4. detection presence
    if "type" not in det or "command" not in det:
        errors.append(f"{cid}: missing detection.type or detection.command")
        continue

    # 5. detection.type allowed + lane consistency
    dt = det["type"]
    if dt not in ALLOWED_TYPES:
        errors.append(f"{cid}: detection.type={dt!r} not in {sorted(ALLOWED_TYPES)}")
    if lane == "deterministic" and dt not in DET_TYPES:
        errors.append(f"{cid}: deterministic lane must not use detection.type={dt!r}")
    if lane == "semantic" and dt != "semantic":
        errors.append(f"{cid}: semantic lane must use detection.type=='semantic', got {dt!r}")

    # 5a. impeccable exit contract. `impeccable detect` exits 0 with `[]` when
    #     clean and 2 with the findings JSON when it finds anything, the inverse
    #     of the generic command shape, where 2 means a broken detector. A row
    #     without its own contract has every finding scored as `error` and
    #     discarded, so only a clean run ever registers.
    if "impeccable detect" in det.get("command", ""):
        ex = det.get("exit") or {}
        if ex.get("pass") != [0] or ex.get("finding") != [2]:
            errors.append(
                f"{cid}: runs `impeccable detect` but detection.exit is {ex or 'absent'}; "
                f"it must declare pass:[0], finding:[2] (impeccable exits 2 on findings)"
            )

    # 5b. command executability (advisory WARNINGS; never fails the gate, so
    #     prose-described regex/counter rows and out-of-package script gaps don't
    #     hard-block; surfaces the R3-CR-01/02 class: bare binaries that don't
    #     ship + dangling scripts/ references). Conservative, two parts:
    #   (a) leading-token of a shell-runnable row resolves to a hyphenated bare
    #       binary (e.g. blitz-import-graph) that is not a known tool/builtin and
    #       not a repo path -> warn. Only checked for command/import-graph rows;
    #       `regex`/`counter` rows hold patterns or operational signals, not shell lines.
    #   (b) any scripts/*.sh referenced anywhere in the command must exist -> warn.
    cmd = det.get("command", "")
    if dt != "semantic":
        SAFE_TOOLS = {
            "grep", "git", "tsc", "npx", "jq", "node", "wc", "test",  # skill-scan: allow tool-name list, not a call
            "find", "sed", "awk", "cat", "echo", "head", "tail", "sort",
            "uniq", "python3", "bash", "sh", "rg", "ls", "diff", "xargs",
        }
        if dt in {"command", "import-graph"}:
            first = cmd.strip().split("|")[0].strip()
            try:
                head = (shlex.split(first) or [""])[0]
            except ValueError:
                head = first.split()[0] if first.split() else ""
            # executable shape: hyphenated lowercase name (blitz-import-graph,
            # detect-stack) or a relative path, and not a known safe tool.
            looks_binary = bool(re.fullmatch(r"[a-z][a-z0-9]*(?:-[a-z0-9]+)+", head))
            if (looks_binary and head not in SAFE_TOOLS
                    and not os.path.isfile(os.path.join(root, head))):
                warnings.append(
                    f"{cid}: detection.command leading token {head!r} looks like a bare binary "
                    f"that does not ship (not a known tool or repo path)"
                )
        for m in re.findall(r"(scripts/[\w./-]+\.sh)", cmd):
            # Resolve against both repo-root scripts/ and hooks/scripts/ so a
            # reference like `hooks/scripts/foo.sh` (captured as `scripts/foo.sh`)
            # is not a false "missing" positive.
            if not (os.path.isfile(os.path.join(root, m))
                    or os.path.isfile(os.path.join(root, "hooks", m))):
                warnings.append(f"{cid}: detection.command references missing script {m!r}")

# 6. confidence_gate.reject_bypass present (facts bypass the min-confidence gate)
if "reject_bypass" not in (d.get("confidence_gate") or {}):
    errors.append("confidence_gate.reject_bypass missing")

# 7. detector_count metadata: every stored number must equal what the rows compute.
#    The block is documentation that is guaranteed accurate, so a row added without
#    updating it fails here instead of drifting silently.
def expect(field, stored, computed):
    if stored != computed:
        errors.append(f"detector_count.{field}: stored {stored!r} but the rows compute {computed!r}")

dc = d.get("detector_count")
if not isinstance(dc, dict):
    errors.append("detector_count block missing")
else:
    det_rows = [c for c in checks if str(c.get("id", "")).startswith("det-")]
    design_rows = [c for c in checks if c.get("pillar") == "design"]
    by_layer = Counter(str(c.get("layer")) for c in design_rows)
    expect("catalogued", dc.get("catalogued"), len(det_rows))
    expect("reject_authority", dc.get("reject_authority"),
           sum(c.get("verdict_authority") == "reject" for c in det_rows))
    expect("advisory_authority", dc.get("advisory_authority"),
           sum(c.get("verdict_authority") == "advisory" for c in det_rows))
    expect("advisory_ids", dc.get("advisory_ids"),
           [c["id"] for c in det_rows if c.get("verdict_authority") == "advisory"])
    wr = dc.get("whole_registry") if isinstance(dc.get("whole_registry"), dict) else {}
    expect("whole_registry.rows", wr.get("rows"), len(checks))
    expect("whole_registry.reject", wr.get("reject"), sum(c.get("verdict_authority") == "reject" for c in checks))
    expect("whole_registry.advisory", wr.get("advisory"), sum(c.get("verdict_authority") == "advisory" for c in checks))
    dg = dc.get("design") if isinstance(dc.get("design"), dict) else {}
    expect("design.rows", dg.get("rows"), len(design_rows))
    expect("design.vendored", dg.get("vendored"), sum(is_vendored(c) for c in checks))
    expect("design.by_layer", dg.get("by_layer"), {k: by_layer[k] for k in sorted(by_layer)})

if warnings:
    print(f"check-registry-validate: {len(warnings)} warning(s) in {path}:", file=sys.stderr)
    for w in warnings:
        print(f"  ! {w}", file=sys.stderr)

if errors:
    print(f"check-registry-validate: {len(errors)} violation(s) in {path}:", file=sys.stderr)
    for e in errors:
        print(f"  - {e}", file=sys.stderr)
    sys.exit(1)

det_adv = [c["id"] for c in checks if c["id"].startswith("det-") and c["verdict_authority"] == "advisory"]
vendored = sum(is_vendored(c) for c in checks)
print(f"check-registry-validate: OK: {len(checks)} checks, derivation clean, enums clean, "
      f"detector_count matches the rows, {vendored} vendored rows carry the impeccable source tag, "
      f"{len(det_adv)} advisory detectors {det_adv}")
PY
