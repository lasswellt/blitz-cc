#!/usr/bin/env bash
# PostToolUse hook — runs matching tests after file edits
# Always exits 0 (non-blocking)
set -uo pipefail

# Read the hook input from stdin
INPUT=$(cat)

# Extract the file path from the tool input
FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)

# Skip if no file path
if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

# Only trigger for JS/TS/Vue source files
if [[ ! "$FILE_PATH" =~ \.(ts|tsx|js|jsx|vue)$ ]]; then
  exit 0
fi

# Skip if the edited file IS a test file
BASENAME=$(basename "$FILE_PATH")
DIR=$(dirname "$FILE_PATH")

if [[ "$BASENAME" =~ \.(test|spec)\. ]] || [[ "$DIR" == *"__tests__"* ]]; then
  exit 0
fi

# Strip extension to get the base name for test file matching
NAME_NO_EXT="${BASENAME%.*}"

# Find matching test file by checking patterns in order
TEST_FILE=""

# 1. Same directory: name.test.ts, name.spec.ts, name.test.tsx
for pattern in "${NAME_NO_EXT}.test.ts" "${NAME_NO_EXT}.spec.ts" "${NAME_NO_EXT}.test.tsx" "${NAME_NO_EXT}.spec.tsx" "${NAME_NO_EXT}.test.js" "${NAME_NO_EXT}.spec.js" "${NAME_NO_EXT}.test.jsx"; do
  if [[ -f "$DIR/$pattern" ]]; then
    TEST_FILE="$DIR/$pattern"
    break
  fi
done

# 2. __tests__/ sibling directory
if [[ -z "$TEST_FILE" ]]; then
  for pattern in "${NAME_NO_EXT}.test.ts" "${NAME_NO_EXT}.spec.ts" "${NAME_NO_EXT}.test.tsx" "${NAME_NO_EXT}.test.js"; do
    if [[ -f "$DIR/__tests__/$pattern" ]]; then
      TEST_FILE="$DIR/__tests__/$pattern"
      break
    fi
  done
fi

# 3. For .vue files: also check name.test.ts, name.spec.ts (already covered above)

# No test file found — exit silently
if [[ -z "$TEST_FILE" ]]; then
  exit 0
fi

# Find project root by walking up looking for package.json
find_project_root() {
  local dir="$1"
  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/package.json" ]]; then
      echo "$dir"
      return 0
    fi
    dir=$(dirname "$dir")
  done
  return 1
}

PROJECT_ROOT=$(find_project_root "$DIR") || exit 0

# Detect test runner from package.json
TEST_RUNNER="jest"
if [[ -f "$PROJECT_ROOT/package.json" ]]; then
  if grep -qE '"vitest"' "$PROJECT_ROOT/package.json" 2>/dev/null; then
    TEST_RUNNER="vitest"
  fi
fi

# Run the matching test with a timeout
echo "Running test: $TEST_FILE"
if [[ "$TEST_RUNNER" == "vitest" ]]; then
  timeout 30s npx vitest run "$TEST_FILE" 2>&1 || true
else
  timeout 30s npx jest "$TEST_FILE" 2>&1 || true
fi

# Always exit 0 — test failure should not block edits
exit 0
