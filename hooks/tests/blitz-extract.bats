#!/usr/bin/env bats
# Tests for blitz_extract() in hooks/scripts/_lib/common.sh

load '_helpers'

setup() {
  . "$HOOKS_DIR/_lib/common.sh"
}

@test "extracts top-level field" {
  INPUT='{"session_id":"sess-123","agent_id":"agent-abc"}'
  export INPUT
  result=$(blitz_extract session_id)
  [ "$result" = "sess-123" ]
}

@test "extracts nested tool_input field" {
  INPUT='{"tool_input":{"file_path":"hooks/test.sh"}}'
  export INPUT
  result=$(blitz_extract file_path)
  [ "$result" = "hooks/test.sh" ]
}

@test "returns empty on missing field" {
  INPUT='{"foo":"bar"}'
  export INPUT
  result=$(blitz_extract nonexistent_field)
  [ -z "$result" ]
}

@test "handles field value with spaces" {
  INPUT='{"session_id":"my session id"}'
  export INPUT
  result=$(blitz_extract session_id)
  [ "$result" = "my session id" ]
}

@test "handles empty INPUT" {
  INPUT='{}'
  export INPUT
  result=$(blitz_extract session_id)
  [ -z "$result" ]
}

@test "blitz_session_id returns cli-<8hex> format" {
  result=$(blitz_session_id)
  [[ "$result" =~ ^cli-[0-9a-f]{8,}$ ]]
}

@test "handles field value with embedded double-quote" {
  # JSON-escaped: file_path = 'a"b.txt' — adversarial filename
  INPUT='{"tool_input":{"file_path":"a\"b.txt"}}'
  export INPUT
  result=$(blitz_extract file_path)
  [ "$result" = 'a"b.txt' ]
}

@test "handles field value with embedded newline" {
  # JSON-escaped \n; jq -r decodes to a real newline in $result
  INPUT='{"tool_input":{"file_path":"line1\nline2"}}'
  export INPUT
  result=$(blitz_extract file_path)
  # Compare against the two-line string built from a real newline
  expected=$(printf 'line1\nline2')
  [ "$result" = "$expected" ]
}

@test "handles field value with embedded backslash" {
  # Shell '\\' = 2 chars sent to jq; JSON \\ decodes to one literal backslash.
  INPUT='{"tool_input":{"file_path":"a\\b\\c"}}'
  export INPUT
  result=$(blitz_extract file_path)
  [ "$result" = 'a\b\c' ]
}

@test "rejects field name with shell metachar (injection guard)" {
  INPUT='{"foo":"bar"}'
  export INPUT
  # Field name containing '/' or quote would be a jq-filter-injection attempt.
  # blitz_extract validates against [a-zA-Z_][a-zA-Z0-9_]* and returns empty.
  result=$(blitz_extract 'foo) | .evil' 2>/dev/null || true)
  [ -z "$result" ]
}

@test "rejects field name starting with digit (identifier guard)" {
  INPUT='{"0":"bar"}'
  export INPUT
  result=$(blitz_extract 0field 2>/dev/null || true)
  [ -z "$result" ]
}
