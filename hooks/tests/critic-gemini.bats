#!/usr/bin/env bats
# Tests for hooks/scripts/critic-gemini.sh — regression coverage for #17
# (gemini CLI stderr noise merged into stdout via 2>&1 broke jq JSON parsing).
# Requires: bats-core (https://github.com/bats-core/bats-core)

load '_helpers'

SCRIPT="$HOOKS_DIR/critic-gemini.sh"

setup() {
  STUB_DIR="$(mktemp -d)"
  # Fake gemini: consume the piped prompt (so the upstream printf does not
  # SIGPIPE under `set -o pipefail`), emit the capability warnings the real
  # CLI prints to STDERR, then print the canned reply ($BLITZ_TEST_REPLY) to
  # STDOUT. Optional $BLITZ_TEST_STDOUT_NOISE simulates gemini-cli #21433
  # (startup noise leaking to stdout before the JSON).
  cat > "$STUB_DIR/gemini" <<'STUB'
#!/usr/bin/env bash
cat >/dev/null
printf 'Warning: True color (24-bit) support not detected. Using a terminal with true color enabled will result in a better visual experience.\n' >&2
printf 'Ripgrep is not available. Falling back to GrepTool.\n' >&2
[ -n "${BLITZ_TEST_STDOUT_NOISE:-}" ] && printf '%s\n' "$BLITZ_TEST_STDOUT_NOISE"
printf '%s\n' "$BLITZ_TEST_REPLY"
STUB
  chmod +x "$STUB_DIR/gemini"
  export BLITZ_GEMINI_BIN="$STUB_DIR/gemini"
}

teardown() {
  [ -n "${STUB_DIR:-}" ] && rm -rf "$STUB_DIR"
}

# Run critic-gemini.sh in --stdin mode with a canned gemini reply.
run_critic() {
  BLITZ_TEST_REPLY="$1" run bash -c \
    "printf 'review this' | bash '$SCRIPT' --mode pre-pass --stdin"
}

@test "stderr capability warnings do not break JSON parsing (LGTM → exit 0)" {
  run_critic '{"verdict":"LGTM","summary":"ok","issues":[]}'
  [ "$status" -eq 0 ]
  # stdout must be valid JSON with the warnings stripped.
  echo "$output" | jq -e '.verdict == "LGTM"'
}

@test "REJECT reply exits 2 with clean JSON" {
  run_critic '{"verdict":"REJECT","summary":"bad","issues":[{"severity":"blocker","where":"x","what":"broken"}]}'
  [ "$status" -eq 2 ]
  echo "$output" | jq -e '.verdict == "REJECT"'
}

@test "brace inside a JSON string value is not truncated (issue #17 awk guard)" {
  # The issue's suggested brace-counting backstop would truncate this reply at
  # the in-string `}`. The line-based guard must keep it intact.
  run_critic '{"verdict":"REJECT","summary":"s","issues":[{"severity":"blocker","where":"f.ts","what":"unbalanced } brace in user code"}]}'
  [ "$status" -eq 2 ]
  echo "$output" | jq -e '.issues[0].what == "unbalanced } brace in user code"'
}

@test "stdout noise before the JSON is stripped (gemini-cli #21433)" {
  BLITZ_TEST_STDOUT_NOISE='Loaded cached credentials.' \
    run_critic '{"verdict":"LGTM","summary":"ok","issues":[]}'
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.verdict == "LGTM"'
}

@test "non-JSON gemini reply still fails closed (exit 1)" {
  run_critic 'totally not json'
  [ "$status" -eq 1 ]
}
