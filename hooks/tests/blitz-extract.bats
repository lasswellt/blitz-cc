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
