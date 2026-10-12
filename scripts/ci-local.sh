#!/usr/bin/env bash
# ci-local.sh: run the CI `validate` job (.github/workflows/ci.yml) locally, step for step.
#
# CI runs only on pushes to main and on pull requests, so a branch is first
# checked when its PR opens. This script runs the same gates before you commit.
# hooks/tests/ci-local.bats fails when ci.yml's validate job names a script this
# file does not run, so the two cannot drift apart silently.
#
# Skipped here, with a note: the token-count step (needs ANTHROPIC_API_KEY; it is
# advisory in CI too), the Cisco scanner when `skill-scanner` is not installed,
# and the mod step when the `claude` CLI is absent.
#
# Usage: scripts/ci-local.sh [--fast]   (--fast skips the bats suites)
# Exit: 0 every gate passed · 1 one or more failed (all are run; failures listed)
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
FAST=0; [ "${1:-}" = "--fast" ] && FAST=1
FAILED=()

step() {  # step <name> <command...>
  local name="$1"; shift
  if "$@" </dev/null >/tmp/blitz-ci-local.$$ 2>&1; then
    printf 'ok    %s\n' "$name"
  else
    printf 'FAIL  %s\n' "$name"; tail -15 /tmp/blitz-ci-local.$$ | sed 's/^/      /'
    FAILED+=("$name")
  fi
}

attribution_gate() {  # mirrors the CI "impeccable attribution" step (ATTRIBUTION.md §5)
  test -f docs/integrations/impeccable/LICENSE-APACHE-2.0.txt \
    && test "$(grep -c '"source": "impeccable@' skills/_shared/check-registry.json)" -gt 0
}

step "SKILL.md frontmatter"              bash hooks/scripts/skill-frontmatter-validate.sh skills/*/SKILL.md
step "Agent frontmatter"                 bash hooks/scripts/agent-frontmatter-validate.sh agents/*.md
step "Check-registry schema"             bash hooks/scripts/check-registry-validate.sh
step "impeccable attribution"            attribution_gate
step "Markdown links + anchors"          bash hooks/scripts/markdown-link-validate.sh
step "Section references resolve"        bash scripts/check-section-refs.sh
step ".claude/CLAUDE.md size (<=200)"    test "$(wc -l < .claude/CLAUDE.md)" -le 200
step "Version-reference sync"            bash scripts/check-version-sync.sh
step "Plugin structure"                  bash scripts/validate-plugin-structure.sh
step "Workflow JS syntax"                bash -c 'for f in workflows/*.js; do node --check "$f" || exit 1; done'
step "Catalog, dead refs, inventory"     bash scripts/gen-catalog.sh --check
step "Skill/script supply-chain scan"    bash scripts/skill-scan.sh
if command -v skill-scanner >/dev/null 2>&1; then
  step "Cisco skill-scanner (offline)"   skill-scanner scan-all skills --recursive --use-behavioral --format json --output /tmp/blitz-skill-scanner.json --fail-on-severity high
else
  echo "skip  Cisco skill-scanner (pipx install cisco-ai-skill-scanner==2.2.2 to run it)"
fi
if command -v claude >/dev/null 2>&1; then
  step "blitz-guard mod: validate"       claude plugin validate mods/blitz-guard
  step "blitz-guard mod: tests"          claude plugin test mods/blitz-guard
else
  echo "skip  blitz-guard mod (no claude CLI)"
fi
echo "skip  skill body token counts (needs ANTHROPIC_API_KEY; advisory in CI)"
if [ "$FAST" -eq 0 ]; then
  BATS="$(command -v bats || true)"
  if [ -z "$BATS" ]; then
    echo "FAIL  bats not installed (CI installs it; locally: apt-get install bats or npm i -g bats)"; FAILED+=("bats missing")
  else
    step "Hook tests (bats, CI=true)"    env CI=true "$BATS" hooks/tests/   # GitHub Actions sets CI=true
    step "Link resolver tests"           bash hooks/scripts/tests/test-link-resolver.sh
    # GitHub's runners resolve `awk` to gawk; a mawk host misses gawk-only warnings.
    if command -v gawk >/dev/null 2>&1 && ! awk --version 2>/dev/null | grep -q 'GNU Awk'; then
      GAWK_DIR=$(mktemp -d); ln -s "$(command -v gawk)" "$GAWK_DIR/awk"
      step "Hook tests under gawk"       env PATH="$GAWK_DIR:$PATH" CI=true "$BATS" hooks/tests/
      rm -rf "$GAWK_DIR"
    fi
  fi
fi
rm -f /tmp/blitz-ci-local.$$

if [ "${#FAILED[@]}" -gt 0 ]; then
  echo "ci-local: ${#FAILED[@]} gate(s) failed: ${FAILED[*]}"; exit 1
fi
echo "ci-local: all gates passed"
