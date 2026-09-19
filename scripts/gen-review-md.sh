#!/usr/bin/env bash
# gen-review-md.sh — render a REVIEW.md for hosted Code Review from the check registry.
# Rows with severity P0/P1 (and P2 with --include-p2) become "Always check" items;
# CI-enforced checks are listed under "Do not report". Output to stdout, or --write <path>.
set -euo pipefail
ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
REG="$ROOT/skills/_shared/check-registry.json"
INCLUDE_P2=0; WRITE=""
while [ $# -gt 0 ]; do
  case "$1" in --include-p2) INCLUDE_P2=1; shift;; --write) WRITE="$2"; shift 2;; --registry) REG="$2"; shift 2;; *) echo "usage: gen-review-md.sh [--include-p2] [--write path]" >&2; exit 2;; esac
done
[ -f "$REG" ] || { echo "gen-review-md: registry not found: $REG" >&2; exit 1; }
sev='["P0","P1"]'; [ "$INCLUDE_P2" -eq 1 ] && sev='["P0","P1","P2"]'
render() {
  echo "# Review instructions"
  echo
  echo "Generated from the blitz check registry (\`scripts/gen-review-md.sh\`). Hosted Code Review reads this file; \`CLAUDE.md\` violations surface as nits on their own."
  echo
  echo "## What Important means here"
  echo
  echo "Reserve Important for findings that would break behavior, leak data, bypass a gate, or block a rollback. Style, naming, and refactoring suggestions are Nit at most. Report at most five Nits per review; say \"plus N similar items\" for the rest."
  echo
  echo "## Always check"
  echo
  jq -r --argjson sev "$sev" '.checks[] | select(.severity as $s | $sev | index($s) != null)
    | "- **\(.name)** (\(.id), \(.severity), \(.pillar)): \(.notes // "" | gsub("\n";" ") | .[0:160])\(if .escape_hatch then " Escape hatch: \(.escape_hatch)." else "" end)"' "$REG"
  echo
  echo "## Verification bar"
  echo
  echo "Behavior claims need a \`file:line\` citation in the source, not an inference from naming. A test that passes is not evidence on its own: check that at least one non-test check (grep, script, or end-to-end step) in the task's \`verify[]\` covers the behavior."
  echo
  echo "## Do not report"
  echo
  echo "- Anything CI already enforces: lint, formatting, type errors, deleted or skipped tests, \`--no-verify\`, destructive git or SQL (hook-blocked)."
  echo "- Generated files: \`docs/CATALOG.md\`, lockfiles, \`.cc-sessions/\`, \`docs/plans/*/tasks.json\` (written only by \`scripts/tasks.sh\`)."
  echo "- Test-only code that intentionally violates production rules."
  echo
  echo "## Re-review convergence"
  echo
  echo "After the first review, suppress new Nits and post Important findings only. Lead the summary with a one-line tally such as \`2 factual, 1 style\`, or \"No blocking issues\" when everything is a Nit."
}
if [ -n "$WRITE" ]; then render > "$WRITE"; echo "wrote $WRITE"; else render; fi
