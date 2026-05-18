#!/usr/bin/env bats
#
# audit-detection-roundtrip.bats — integration smoke for sprint-13 / E-022
#
# Validates that the Phase 0.8 / 0.9b / 0.9c detection bash from
# skills/next/SKILL.md fires correctly on fixture audit + scope-limit state.
#
# Each test runs in BATS_TEST_TMPDIR to avoid mutating real
# docs/audits/, .cc-sessions/, sprint-registry.json, or SCOPE-LIMIT.md.

load _helpers

setup() {
  command -v jq >/dev/null || skip "jq not installed"
  TMPDIR=$(mktemp -d)
  cd "$TMPDIR"
  mkdir -p docs/_research docs/audits .cc-sessions
  : > .cc-sessions/carry-forward.jsonl
}

teardown() {
  rm -rf "$TMPDIR"
}

# ---------------------------------------------------------------------------
# Test 1 — Phase 0.8 UNINGESTED detects fixture audit -epics.md
# ---------------------------------------------------------------------------

@test "Phase 0.8 UNINGESTED detects fixture docs/audits/*-epics.md" {
  # roadmap-registry must exist and be older than the fixture
  touch -t 202001010000 roadmap-registry.json

  cat > docs/audits/audit-2099-01-01-epics.md <<'EOF'
---
scope:
  - id: cf-test-fixture-001
    unit: epics
    target: 1
    description: |
      Test fixture epic
    acceptance: []
---
# Proposed Epics — Test Fixture
EOF

  # Inline the Phase 0.8 detection from skills/next/SKILL.md
  INGESTED_IDS=$(jq -rs '[group_by(.id)[] | max_by(.ts).id] | join("\n")' \
    .cc-sessions/carry-forward.jsonl 2>/dev/null || echo "")
  UNINGESTED=$({ find docs/_research -name '*.md' -newer roadmap-registry.json 2>/dev/null;
                  find docs/audits -name '*-epics.md' -newer roadmap-registry.json 2>/dev/null; } \
    | while read f; do
        IDS=$(grep -o 'id: cf-[^ ]*' "$f" 2>/dev/null | awk '{print $2}')
        if [ -z "$IDS" ]; then echo "$f"; continue; fi
        for id in $IDS; do
          echo "$INGESTED_IDS" | grep -qx "$id" || { echo "$f"; break; }
        done
      done)
  UNINGESTED_COUNT=$(echo "$UNINGESTED" | grep -c '.' 2>/dev/null || echo 0)

  [[ "$UNINGESTED_COUNT" -ge 1 ]]
  echo "$UNINGESTED" | grep -q "audit-2099-01-01-epics.md"
}

# ---------------------------------------------------------------------------
# Test 2 — Phase 0.9b UNSPRINTIFIED_AUDIT_COUNT > 0 on fresh audit index
# ---------------------------------------------------------------------------

@test "Phase 0.9b UNSPRINTIFIED_AUDIT_COUNT > 0 on unsprintified audit index" {
  # Empty sprint registry — nothing sprintified yet
  echo '{"sprints":[]}' > sprint-registry.json

  cat > docs/audits/audit-2099-01-01-index.json <<'EOF'
{
  "audit_date": "2099-01-01",
  "proposed_epics": [
    {"id": "EPIC-A99", "theme": "test", "pillar": "test", "status": "proposed"}
  ]
}
EOF

  # Inline the Phase 0.9b detection
  LAST_SHIPPED=$(jq -r '[.sprints[] | select(.shipped_date != null) | .shipped_date] | sort | last' \
    sprint-registry.json 2>/dev/null || echo "1970-01-01T00:00:00Z")
  # null becomes literal "null" string from jq — coerce
  [ "$LAST_SHIPPED" = "null" ] && LAST_SHIPPED="1970-01-01T00:00:00Z"

  SPRINTIFIED_IDS=$(jq -r '[.sprints[].epics[]?] | map(select(startswith("EPIC-A"))) | unique | .[]' \
    sprint-registry.json 2>/dev/null | sort -u)

  SPRINTIFIED_AUDITS=$(jq -r '[.sprints[] | .audit_source // empty] | unique | .[]' \
    sprint-registry.json 2>/dev/null)

  UNSPRINTIFIED_AUDIT_COUNT=0
  for f in docs/audits/*-index.json; do
    [ -f "$f" ] || continue
    file_ts=$(date -r "$f" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "1970-01-01T00:00:00Z")
    [ "$file_ts" \> "$LAST_SHIPPED" ] || continue
    audit_basename=$(basename "$f" -index.json).md
    echo "$SPRINTIFIED_AUDITS" | grep -qF "$audit_basename" && continue
    n=$(jq --argjson sprintified "$(printf '%s\n' $SPRINTIFIED_IDS | jq -Rs 'split("\n") | map(select(. != ""))')" \
      '[.proposed_epics[] | select(.id != null) | select((.status // "proposed") == "proposed") | select(.id as $i | $sprintified | index($i) | not)] | length' \
      "$f" 2>/dev/null || echo 0)
    UNSPRINTIFIED_AUDIT_COUNT=$((UNSPRINTIFIED_AUDIT_COUNT + n))
  done

  [[ "$UNSPRINTIFIED_AUDIT_COUNT" -ge 1 ]]
}

# ---------------------------------------------------------------------------
# Test 3 — Phase 0.9c SCOPE_LIMIT_ACTIVE=1 with valid future expires_after
# ---------------------------------------------------------------------------

@test "Phase 0.9c SCOPE_LIMIT_ACTIVE=1 with future expires_after" {
  cat > SCOPE-LIMIT.md <<'EOF'
---
declared_at: 2026-05-18
declared_by: operator
scope: full-codebase
reason: |
  Test fixture.
expires_after: 2099-12-31
---
# Scope Limit Declaration
EOF

  # Inline Phase 0.9c detection
  SCOPE_LIMIT_ACTIVE=0
  if [ -f SCOPE-LIMIT.md ]; then
    EXPIRES=$(awk '/^expires_after:/ {print $2; exit}' SCOPE-LIMIT.md | tr -d '"'"'")
    if [ -z "$EXPIRES" ]; then
      :  # malformed
    elif [ "$(date -u +%Y-%m-%d)" \< "$EXPIRES" ]; then
      SCOPE_LIMIT_ACTIVE=1
    fi
  fi

  [[ "$SCOPE_LIMIT_ACTIVE" -eq 1 ]]
}

# ---------------------------------------------------------------------------
# Test 4 — Phase 0.9c SCOPE_LIMIT_ACTIVE=0 with past expires_after
# ---------------------------------------------------------------------------

@test "Phase 0.9c SCOPE_LIMIT_ACTIVE=0 with past expires_after" {
  cat > SCOPE-LIMIT.md <<'EOF'
---
declared_at: 2020-01-01
declared_by: operator
scope: full-codebase
reason: |
  Expired fixture.
expires_after: 2020-01-02
---
# Scope Limit Declaration
EOF

  SCOPE_LIMIT_ACTIVE=0
  if [ -f SCOPE-LIMIT.md ]; then
    EXPIRES=$(awk '/^expires_after:/ {print $2; exit}' SCOPE-LIMIT.md | tr -d '"'"'")
    if [ -z "$EXPIRES" ]; then
      :
    elif [ "$(date -u +%Y-%m-%d)" \< "$EXPIRES" ]; then
      SCOPE_LIMIT_ACTIVE=1
    fi
  fi

  [[ "$SCOPE_LIMIT_ACTIVE" -eq 0 ]]
}

# ---------------------------------------------------------------------------
# Test 5 — Phase 0.9c SCOPE_LIMIT_ACTIVE=0 with malformed (missing expires_after)
# ---------------------------------------------------------------------------

@test "Phase 0.9c SCOPE_LIMIT_ACTIVE=0 when expires_after missing (malformed)" {
  cat > SCOPE-LIMIT.md <<'EOF'
---
declared_at: 2026-05-18
declared_by: operator
scope: full-codebase
reason: |
  Missing expires_after.
---
# Scope Limit Declaration
EOF

  SCOPE_LIMIT_ACTIVE=0
  if [ -f SCOPE-LIMIT.md ]; then
    EXPIRES=$(awk '/^expires_after:/ {print $2; exit}' SCOPE-LIMIT.md | tr -d '"'"'")
    if [ -z "$EXPIRES" ]; then
      :  # malformed — do not activate
    elif [ "$(date -u +%Y-%m-%d)" \< "$EXPIRES" ]; then
      SCOPE_LIMIT_ACTIVE=1
    fi
  fi

  [[ "$SCOPE_LIMIT_ACTIVE" -eq 0 ]]
}

# ---------------------------------------------------------------------------
# Test 6 — Phase 0.9c SCOPE_LIMIT_ACTIVE=1 with QUOTED expires_after (regression)
# ---------------------------------------------------------------------------

@test "Phase 0.9c SCOPE_LIMIT_ACTIVE=1 with quoted expires_after YAML" {
  cat > SCOPE-LIMIT.md <<'EOF'
---
declared_at: 2026-05-18
declared_by: operator
scope: full-codebase
reason: |
  Quoted YAML date.
expires_after: "2099-12-31"
---
# Scope Limit Declaration
EOF

  SCOPE_LIMIT_ACTIVE=0
  if [ -f SCOPE-LIMIT.md ]; then
    EXPIRES=$(awk '/^expires_after:/ {print $2; exit}' SCOPE-LIMIT.md | tr -d '"'"'")
    if [ -z "$EXPIRES" ]; then
      :
    elif [ "$(date -u +%Y-%m-%d)" \< "$EXPIRES" ]; then
      SCOPE_LIMIT_ACTIVE=1
    fi
  fi

  [[ "$SCOPE_LIMIT_ACTIVE" -eq 1 ]]
}
