#!/usr/bin/env bash
# test-link-resolver.sh — regression test for markdown-link-validate.sh
# convention-aware resolution (S14-001 / E-023). Locks in that /_shared/X
# links are NOT false-flagged (the 242-dead-ref artifact) AND that genuinely
# broken /_shared/ links ARE caught.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$REPO"
V=hooks/scripts/markdown-link-validate.sh
FIX=skills/__xref_test__
cleanup() { rm -rf "$FIX"; }
trap cleanup EXIT
fail() { echo "test-link-resolver: FAIL — $1" >&2; exit 1; }

# 1. Baseline: real suite is clean (0 broken).
bash "$V" </dev/null >/dev/null 2>&1 || fail "baseline suite has broken links"

mkdir -p "$FIX"

# 2. Positive control: a valid /_shared/ link must NOT be flagged dead.
printf '%s\n' '[ok](/_shared/spawn-protocol.md)' > "$FIX/good.md"
bash "$V" </dev/null >/dev/null 2>&1 || fail "/_shared/ convention link wrongly flagged dead"

# 3. Positive control: runtime-output path must be skipped (not flagged).
printf '%s\n' '[gen](docs/generated/x.md)' > "$FIX/runtime.md"
bash "$V" </dev/null >/dev/null 2>&1 || fail "runtime-output path wrongly flagged"

# 4. Negative control: a genuinely broken /_shared/ link MUST be flagged.
printf '%s\n' '[bad](/_shared/does-not-exist-xyz.md)' > "$FIX/bad.md"
if bash "$V" </dev/null >/dev/null 2>&1; then fail "broken /_shared/ link was NOT flagged"; fi

echo "test-link-resolver: PASS (convention-aware /_shared/ resolution + dead-link detection verified)"
