#!/usr/bin/env bash
# PreToolUse hook — validates staged files before git commit
# Exit 0 = allow, Exit 2 = block
set -euo pipefail

# Read the hook input from stdin
INPUT=$(cat)

# Extract the command from the tool input
COMMAND=$(echo "$INPUT" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(data.get('tool_input', {}).get('command', ''))
" 2>/dev/null || true)

# Only trigger if the command contains 'git commit'
if [[ "$COMMAND" != *"git commit"* ]]; then
  exit 0
fi

# Get staged files (Added, Copied, Modified)
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null || true)

if [[ -z "$STAGED_FILES" ]]; then
  exit 0
fi

BLOCKED=0
WARNED=0

# --- Check for secret/sensitive files ---
while IFS= read -r file; do
  [[ -z "$file" ]] && continue
  basename_file=$(basename "$file")
  dir_file=$(dirname "$file")

  # .env files (but not .env.example or .env.development)
  if [[ "$basename_file" =~ ^\.env$ || "$basename_file" =~ ^\.env\. ]]; then
    if [[ "$basename_file" != ".env.example" && \
          "$basename_file" != ".env.development" && \
          "$basename_file" != ".env.test" && \
          "$basename_file" != ".env.production.example" ]]; then
      echo "BLOCKED: Secret file staged: $file" >&2
      BLOCKED=$((BLOCKED + 1))
      continue
    fi
  fi

  # Files with secret/credential in the name
  if [[ "$basename_file" == *secret* || "$basename_file" == *credential* ]]; then
    echo "BLOCKED: Sensitive file staged: $file" >&2
    BLOCKED=$((BLOCKED + 1))
    continue
  fi

  # Key/certificate files
  if [[ "$basename_file" =~ \.(pem|key)$ ]]; then
    echo "BLOCKED: Key file staged: $file" >&2
    BLOCKED=$((BLOCKED + 1))
    continue
  fi

  # Service account JSON files
  if [[ "$basename_file" =~ ^service-account.*\.json$ ]]; then
    echo "BLOCKED: Service account file staged: $file" >&2
    BLOCKED=$((BLOCKED + 1))
    continue
  fi
done <<< "$STAGED_FILES"

# If secret files found, block the commit
if [[ "$BLOCKED" -gt 0 ]]; then
  echo "Commit blocked: $BLOCKED secret/sensitive file(s) in staging area." >&2
  exit 2
fi

# --- Check for banned code patterns (warn, don't block) ---
BANNED_PATTERNS=(
  'return \{\}'
  'return \[\]'
  'return null'
  "throw new Error\('Not implemented'\)"
  "throw new Error\('TODO'\)"
  '//\s*TODO:\s*implement'
  '//\s*FIXME'
  '//\s*PLACEHOLDER'
  '//\s*STUB'
  'console\.log'
  'catch\s*\([^)]*\)\s*\{\s*\}'
  '\(\)\s*=>\s*\{\s*\}'
)

BANNED_LABELS=(
  "return {} placeholder"
  "return [] placeholder"
  "return null placeholder"
  "throw Not implemented"
  "throw TODO"
  "TODO: implement"
  "FIXME"
  "PLACEHOLDER"
  "STUB"
  "console.log"
  "empty catch block"
  "no-op handler"
)

while IFS= read -r file; do
  [[ -z "$file" ]] && continue
  # Only check source files for code patterns
  if [[ ! "$file" =~ \.(ts|tsx|js|jsx|vue|py|rb|go|rs|java)$ ]]; then
    continue
  fi
  [[ ! -f "$file" ]] && continue

  for i in "${!BANNED_PATTERNS[@]}"; do
    matches=$(grep -nE "${BANNED_PATTERNS[$i]}" "$file" 2>/dev/null || true)
    if [[ -n "$matches" ]]; then
      while IFS= read -r match; do
        lineno="${match%%:*}"
        echo "WARNING: ${BANNED_LABELS[$i]} — $file:$lineno" >&2
        WARNED=$((WARNED + 1))
      done <<< "$matches"
    fi
  done
done <<< "$STAGED_FILES"

if [[ "$WARNED" -gt 0 ]]; then
  echo "Warning: $WARNED banned pattern(s) found in staged files (commit allowed)." >&2
fi

# --- Check for version-reference drift ---
# Runs on every commit. Warning-only on regular commits; blocks on commits
# that touch .claude-plugin/plugin.json (those are version-bump commits and
# drifted files in the same commit are an explicit bug).
VERSION_SYNC_SCRIPT="${CLAUDE_PLUGIN_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}/scripts/check-version-sync.sh"
# Fail loudly when the script is missing rather than silently skipping.
# Earlier silent `-x` guard let the version-drift gate no-op for an unknown
# duration when the script vanished. Surface the gap so it gets fixed.
if [[ ! -f "$VERSION_SYNC_SCRIPT" ]]; then
  echo "[pre-commit] WARN: $VERSION_SYNC_SCRIPT not found — version-drift gate disabled." >&2
  echo "[pre-commit]       Restore the script or remove this check from pre-commit-validate.sh." >&2
elif [[ ! -x "$VERSION_SYNC_SCRIPT" ]]; then
  echo "[pre-commit] WARN: $VERSION_SYNC_SCRIPT not executable — fix with chmod +x." >&2
fi
if [[ -x "$VERSION_SYNC_SCRIPT" ]]; then
  SYNC_EXIT=0
  SYNC_OUTPUT=$("$VERSION_SYNC_SCRIPT" 2>&1) || SYNC_EXIT=$?

  if [[ "$SYNC_EXIT" -ne 0 ]]; then
    echo "" >&2
    echo "$SYNC_OUTPUT" >&2

    # Is plugin.json in this commit? If yes, this is a bump commit — block.
    if echo "$STAGED_FILES" | grep -qF ".claude-plugin/plugin.json"; then
      echo "" >&2
      echo "BLOCKED: version-bump commit has drifted version references." >&2
      echo "  This commit stages .claude-plugin/plugin.json but other files are not in sync." >&2
      echo "  Update the drifted files listed above and re-stage, or skip this check" >&2
      echo "  with an explicit --no-verify if this is intentional." >&2
      exit 2
    fi

    # Non-bump commit: warn only. The drift will be fixed in a future commit.
    echo "  (This is a warning — commit allowed. Drift will be re-flagged on every commit until fixed.)" >&2
  fi
fi

# --- Check SKILL.md frontmatter conformance for staged SKILL.md files ---
STAGED_SKILLS=$(echo "$STAGED_FILES" | grep -E '^skills/[^/]+/SKILL\.md$' || true)
if [[ -n "$STAGED_SKILLS" ]]; then
  LINT_SCRIPT="${CLAUDE_PLUGIN_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}/hooks/scripts/skill-frontmatter-validate.sh"
  if [[ -x "$LINT_SCRIPT" ]]; then
    LINT_EXIT=0
    # shellcheck disable=SC2086
    LINT_OUTPUT=$(echo "$STAGED_SKILLS" | xargs "$LINT_SCRIPT" 2>&1) || LINT_EXIT=$?
    if [[ "$LINT_EXIT" -ne 0 ]]; then
      echo "" >&2
      echo "$LINT_OUTPUT" >&2
      echo "BLOCKED: SKILL.md frontmatter violations in staged files." >&2
      echo "  See /_shared/terse-output.md and /_shared/spawn-protocol.md §7 for canonical conventions." >&2
      exit 2
    fi
  fi
fi

# --- Check for broken markdown links (warn-only) ---
LINK_SCRIPT="${CLAUDE_PLUGIN_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}/hooks/scripts/markdown-link-validate.sh"
if [[ -x "$LINK_SCRIPT" ]]; then
  LINK_EXIT=0
  LINK_OUTPUT=$("$LINK_SCRIPT" 2>&1) || LINK_EXIT=$?
  if [[ "$LINK_EXIT" -ne 0 ]]; then
    echo "" >&2
    echo "$LINK_OUTPUT" >&2
    echo "  (Warning — commit allowed. Fix broken links and re-stage.)" >&2
  fi
fi

# No secrets found — allow the commit
exit 0
