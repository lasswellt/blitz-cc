#!/usr/bin/env bats
# scripts/ci-local.sh must run every gate the CI `validate` job runs, so a branch
# can be checked before its PR opens (CI runs only on main pushes and PRs).

ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

validate_job() { awk '/^  validate:/{f=1; next} /^  [a-z-]+:$/{f=0} f' "$ROOT/.github/workflows/ci.yml"; }

@test "every script the validate job runs is run by ci-local.sh" {
  local missing=0
  while IFS= read -r path; do
    grep -qF "$path" "$ROOT/scripts/ci-local.sh" || { echo "ci-local.sh does not run: $path"; missing=1; }
  done < <(validate_job | grep -oE '(hooks/scripts|scripts)/[A-Za-z0-9_./-]+\.sh' | grep -v 'count-tokens.sh' | sort -u)
  [ "$missing" -eq 0 ]
}

@test "the non-script gates (bats, node --check, mod, Cisco scanner, CLAUDE.md size, impeccable attribution) are mirrored" {
  for needle in 'bats' 'node --check' 'claude plugin validate mods/blitz-guard' 'claude plugin test mods/blitz-guard' 'skill-scanner scan-all skills' 'wc -l < .claude/CLAUDE.md' \
                'docs/integrations/impeccable/LICENSE-APACHE-2.0.txt' '"source": "impeccable@'; do
    validate_job | grep -qF -- "$needle" || { echo "CI no longer runs: $needle (update this test)"; return 1; }
    grep -qF -- "$needle" "$ROOT/scripts/ci-local.sh" || { echo "ci-local.sh does not run: $needle"; return 1; }
  done
}
