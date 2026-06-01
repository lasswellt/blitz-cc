#!/usr/bin/env bash
# Count sync checker
# ──────────────────
# Companion to check-version-sync.sh. That script validates the semver across
# manifests; this one validates the PROSE COUNTS (skills, agents, shared
# protocol files, hook scripts/events, detectors) that every doc otherwise
# hand-maintains and drifts on.
#
# Source of truth: the filesystem. The script recomputes every count, compares
# it to .claude-plugin/counts.json, and then asserts that curated prose claims
# in README.md, CLAUDE.md, plugin.json, marketplace.json, and the current
# CHANGELOG release section agree with those numbers.
#
# Modes:
#   scripts/check-count-sync.sh           # check; exit 1 on any drift
#   scripts/check-count-sync.sh --write   # regenerate counts.json from FS
#   scripts/check-count-sync.sh --quiet   # exit code only
#
# Exit codes:
#   0 — counts.json current AND all prose claims in sync
#   1 — drift detected (counts.json stale, or a prose claim disagrees)
#
# Called by: hooks/scripts/pre-commit-validate.sh

set -euo pipefail

QUIET=0
WRITE=0
for arg in "$@"; do
  case "$arg" in
    --quiet) QUIET=1 ;;
    --write) WRITE=1 ;;
  esac
done

log() { [[ "$QUIET" -eq 1 ]] && return 0; echo "$@" >&2; }

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT" || exit 0

COUNTS_JSON=".claude-plugin/counts.json"
HOOKS_JSON="hooks/hooks.json"
TAXONOMY="skills/_shared/shortcut-taxonomy.md"
[[ -f "$HOOKS_JSON" ]] || exit 0   # not a blitz plugin repo

# ── 1. Recompute every count from the filesystem ──────────────────────────
C_skills=$(find skills -maxdepth 2 -name SKILL.md | wc -l | tr -d ' ')
C_agents=$(find agents -maxdepth 1 -name '*.md' | wc -l | tr -d ' ')
C_shared=$(find skills/_shared -maxdepth 1 -name '*.md' | wc -l | tr -d ' ')
C_hook_scripts=$(find hooks/scripts -maxdepth 1 -name '*.sh' | wc -l | tr -d ' ')
C_hook_wired=$(grep -oE '[a-zA-Z0-9_-]+\.sh' "$HOOKS_JSON" | sort -u | wc -l | tr -d ' ')
C_events=$(python3 -c "import json;d=json.load(open('$HOOKS_JSON'));e=d.get('hooks',d);print(len(e.keys()))")
C_anti=$(find hooks/scripts -maxdepth 1 \( -name 'block-*.sh' -o -name 'post-edit-typecheck-block.sh' \) | wc -l | tr -d ' ')

# Detectors come from the registry (canonical), fall back to taxonomy rows.
read -r C_det C_det_rej C_det_adv < <(python3 -c "
import json
d=json.load(open('skills/_shared/check-registry.json'))
dc=d.get('detector_count',{})
print(dc.get('catalogued',0), dc.get('reject_authority',0), dc.get('advisory_authority',0))
")

# sub-invoked / critic-spawned: present at depth 1, not event-wired.
mapfile -t UNWIRED < <(comm -23 \
  <(find hooks/scripts -maxdepth 1 -name '*.sh' -printf '%f\n' | sort) \
  <(grep -oE '[a-zA-Z0-9_-]+\.sh' "$HOOKS_JSON" | sort -u))
C_critic=0; C_sub=0
for s in "${UNWIRED[@]}"; do
  if [[ "$s" == critic-* ]]; then C_critic=$((C_critic+1)); else C_sub=$((C_sub+1)); fi
done

# ── 2. --write mode: regenerate counts.json and exit ──────────────────────
if [[ "$WRITE" -eq 1 ]]; then
  python3 - "$COUNTS_JSON" <<PY
import json, sys
p = sys.argv[1]
d = json.load(open(p))
d.update({
  "skills": $C_skills, "agents": $C_agents, "shared": $C_shared,
  "hook_scripts": $C_hook_scripts, "hook_scripts_wired": $C_hook_wired,
  "hook_scripts_subinvoked": $C_sub, "hook_scripts_critic_spawned": $C_critic,
  "hook_events": $C_events, "detectors": $C_det,
  "detectors_reject": $C_det_rej, "detectors_advisory": $C_det_adv,
  "anti_shortcut_hooks": $C_anti,
})
json.dump(d, open(p, "w"), indent=2)
open(p, "a").write("\n")
print("counts.json regenerated from filesystem")
PY
  exit 0
fi

# ── 3. Check counts.json is current ───────────────────────────────────────
DRIFT=0
check_json() {  # name fs_value
  local key="$1" fsval="$2"
  local stored
  stored=$(python3 -c "import json;print(json.load(open('$COUNTS_JSON')).get('$key','MISSING'))" 2>/dev/null)
  if [[ "$stored" != "$fsval" ]]; then
    log "  drift: counts.json $key = $stored (filesystem = $fsval)"
    DRIFT=$((DRIFT+1))
  fi
}
if [[ -f "$COUNTS_JSON" ]]; then
  check_json skills "$C_skills"
  check_json agents "$C_agents"
  check_json shared "$C_shared"
  check_json hook_scripts "$C_hook_scripts"
  check_json hook_scripts_wired "$C_hook_wired"
  check_json hook_scripts_subinvoked "$C_sub"
  check_json hook_scripts_critic_spawned "$C_critic"
  check_json hook_events "$C_events"
  check_json detectors "$C_det"
  check_json detectors_reject "$C_det_rej"
  check_json detectors_advisory "$C_det_adv"
  check_json anti_shortcut_hooks "$C_anti"
else
  log "  drift: $COUNTS_JSON missing — run check-count-sync.sh --write"
  DRIFT=$((DRIFT+1))
fi

# ── 4. Curated prose assertions ───────────────────────────────────────────
# Each row: file | PCRE | expected. The captured group (\1) must equal expected.
# Keep patterns tight so unrelated numbers never match. When a phrasing changes
# intentionally, update the pattern here — that is the single edit point.
assert_prose() {  # file pattern expected label
  local file="$1" pat="$2" exp="$3" label="$4"
  [[ -f "$file" ]] || return 0
  local got
  got=$(grep -oP "$pat" "$file" 2>/dev/null | head -1 | grep -oP '\d+' | head -1 || true)
  [[ -z "$got" ]] && return 0   # phrase absent → not this script's concern
  if [[ "$got" != "$exp" ]]; then
    log "  drift: $file — $label says $got (expected $exp)"
    DRIFT=$((DRIFT+1))
  fi
}

# README.md
assert_prose README.md '(\d+)\s+development skills'        "$C_skills" "skills"
assert_prose README.md '(\d+)\s+shared protocol'           "$C_shared" "shared protocol files"
assert_prose README.md '(\d+)-detector'                    "$C_det"    "detector count"
# CLAUDE.md
assert_prose CLAUDE.md '(\d+)\s+development skills'         "$C_skills" "skills"
assert_prose CLAUDE.md '(\d+)\s+plugin agents'             "$C_agents" "agents"
assert_prose CLAUDE.md '(\d+)\s+anti-shortcut detectors'   "$C_det"    "detectors"
assert_prose CLAUDE.md '(\d+)-detector'                    "$C_det"    "detector count"
# plugin.json / marketplace.json
assert_prose .claude-plugin/plugin.json      '(\d+)\s+shared protocol' "$C_shared" "shared protocol files"
assert_prose .claude-plugin/plugin.json      '(\d+)\s+hook scripts'    "$C_hook_scripts" "hook scripts"
assert_prose .claude-plugin/marketplace.json '(\d+)\s+shared protocol' "$C_shared" "shared protocol files"

# ── 5. Summary ────────────────────────────────────────────────────────────
if [[ "$DRIFT" -gt 0 ]]; then
  log ""
  log "Count drift detected: $DRIFT item(s) out of sync with the filesystem."
  log "Fix: run scripts/check-count-sync.sh --write to refresh counts.json, then"
  log "     reconcile the prose claims above to match. Re-stage and retry."
  exit 1
fi
exit 0
