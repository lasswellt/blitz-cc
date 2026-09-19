#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/_lib/common.sh"

# Post-edit format + lint hook
# Auto-formats edited files (prettier or biome), then lints the code files
# (eslint or biome) and prints remaining lint output as context. Always exits 0.

# Read the hook input from stdin
INPUT=$(cat)

# Extract the file path from the tool input
FILE_PATH=$(blitz_extract file_path)

if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

# Only format supported file types
if [[ ! "$FILE_PATH" =~ \.(ts|tsx|js|jsx|vue|css|scss|json|md|html|yaml|yml)$ ]]; then
  exit 0
fi

# Check that the file actually exists
if [[ ! -f "$FILE_PATH" ]]; then
  exit 0
fi

find_project_root() {
  local dir
  dir=$(dirname "$FILE_PATH")
  while [[ "$dir" != "/" ]]; do
    [[ -f "$dir/package.json" ]] && { echo "$dir"; return 0; }
    dir=$(dirname "$dir")
  done
  return 1
}

PROJECT_ROOT=$(find_project_root) || exit 0

# Toolchain cache — avoids repeated jq+stat work across post-edit-format/lint.
# Cache schema: {"<project_root>": {"mtime": <int>, "formatter": "<cmd|none>", "linter": "<cmd|none>"}}
TOOLCHAIN_CACHE=".cc-sessions/toolchain-cache.json"
toolchain_cached_formatter() {
  [[ ! -f "$TOOLCHAIN_CACHE" ]] && return 1
  [[ ! -f "$PROJECT_ROOT/package.json" ]] && return 1
  local pkg_mtime cached_mtime cached_fmt
  pkg_mtime=$(stat -c '%Y' "$PROJECT_ROOT/package.json" 2>/dev/null || stat -f '%m' "$PROJECT_ROOT/package.json" 2>/dev/null || echo 0)
  cached_mtime=$(jq -r --arg root "$PROJECT_ROOT" '.[$root].mtime // 0' "$TOOLCHAIN_CACHE" 2>/dev/null || echo 0)
  [[ "$pkg_mtime" != "$cached_mtime" ]] && return 1
  cached_fmt=$(jq -r --arg root "$PROJECT_ROOT" '.[$root].formatter // ""' "$TOOLCHAIN_CACHE" 2>/dev/null || echo "")
  [[ -z "$cached_fmt" ]] && return 1
  printf '%s' "$cached_fmt"
  return 0
}
toolchain_write_formatter() {
  local fmt="$1" pkg_mtime
  mkdir -p .cc-sessions
  pkg_mtime=$(stat -c '%Y' "$PROJECT_ROOT/package.json" 2>/dev/null || stat -f '%m' "$PROJECT_ROOT/package.json" 2>/dev/null || echo 0)
  local tmp=$(mktemp -p .cc-sessions .toolchain.XXXXXX 2>/dev/null) || return 0
  local existing="{}"
  [[ -f "$TOOLCHAIN_CACHE" ]] && existing=$(cat "$TOOLCHAIN_CACHE" 2>/dev/null || echo "{}")
  printf '%s' "$existing" | jq --arg root "$PROJECT_ROOT" --argjson mt "$pkg_mtime" --arg f "$fmt" \
    '. + {($root): ((.[$root] // {}) + {mtime: $mt, formatter: $f})}' > "$tmp" 2>/dev/null \
    && mv "$tmp" "$TOOLCHAIN_CACHE" || rm -f "$tmp"
}

# Detect formatter and run it
detect_and_format() {
  # Warm-cache fast path
  local cached
  if cached=$(toolchain_cached_formatter); then
    case "$cached" in
      none) return ;;
      prettier-config|prettier-dep) command -v npx &>/dev/null && npx --yes prettier --write "$FILE_PATH" 2>/dev/null; return ;;
      biome) command -v npx &>/dev/null && npx --yes @biomejs/biome format --write "$FILE_PATH" 2>/dev/null; return ;;
    esac
  fi

  # Check for Prettier
  if [[ -f "$PROJECT_ROOT/.prettierrc" || \
        -f "$PROJECT_ROOT/.prettierrc.js" || \
        -f "$PROJECT_ROOT/.prettierrc.cjs" || \
        -f "$PROJECT_ROOT/.prettierrc.mjs" || \
        -f "$PROJECT_ROOT/.prettierrc.json" || \
        -f "$PROJECT_ROOT/.prettierrc.yaml" || \
        -f "$PROJECT_ROOT/.prettierrc.yml" || \
        -f "$PROJECT_ROOT/.prettierrc.toml" || \
        -f "$PROJECT_ROOT/prettier.config.js" || \
        -f "$PROJECT_ROOT/prettier.config.cjs" || \
        -f "$PROJECT_ROOT/prettier.config.mjs" ]]; then
    # Prettier config file found
    toolchain_write_formatter "prettier-config"
    if command -v npx &>/dev/null; then
      npx --yes prettier --write "$FILE_PATH" 2>/dev/null
      return
    fi
  fi

  # Check for prettier in package.json dependencies
  if [[ -f "$PROJECT_ROOT/package.json" ]] && \
     jq -e '(.devDependencies.prettier // .dependencies.prettier) != null' "$PROJECT_ROOT/package.json" &>/dev/null; then
    toolchain_write_formatter "prettier-dep"
    if command -v npx &>/dev/null; then
      npx prettier --write "$FILE_PATH" 2>/dev/null
      return
    fi
  fi

  # Check for Biome
  if [[ -f "$PROJECT_ROOT/biome.json" || -f "$PROJECT_ROOT/biome.jsonc" ]]; then
    toolchain_write_formatter "biome"
    if command -v npx &>/dev/null; then
      npx --yes @biomejs/biome format --write "$FILE_PATH" 2>/dev/null
      return
    fi
  fi

  # No formatter detected — cache that fact to skip future jq calls
  toolchain_write_formatter "none"
}

detect_and_format

# --- Lint stage (code files only) ---
if [[ "$FILE_PATH" =~ \.(ts|tsx|js|jsx|vue)$ ]]; then
toolchain_cached_linter() {
  [[ ! -f "$TOOLCHAIN_CACHE" ]] && return 1
  [[ ! -f "$PROJECT_ROOT/package.json" ]] && return 1
  local pkg_mtime cached_mtime cached_lint
  pkg_mtime=$(stat -c '%Y' "$PROJECT_ROOT/package.json" 2>/dev/null || stat -f '%m' "$PROJECT_ROOT/package.json" 2>/dev/null || echo 0)
  cached_mtime=$(jq -r --arg root "$PROJECT_ROOT" '.[$root].mtime // 0' "$TOOLCHAIN_CACHE" 2>/dev/null || echo 0)
  [[ "$pkg_mtime" != "$cached_mtime" ]] && return 1
  cached_lint=$(jq -r --arg root "$PROJECT_ROOT" '.[$root].linter // ""' "$TOOLCHAIN_CACHE" 2>/dev/null || echo "")
  [[ -z "$cached_lint" ]] && return 1
  printf '%s' "$cached_lint"
  return 0
}
toolchain_write_linter() {
  local lint="$1" pkg_mtime
  mkdir -p .cc-sessions
  pkg_mtime=$(stat -c '%Y' "$PROJECT_ROOT/package.json" 2>/dev/null || stat -f '%m' "$PROJECT_ROOT/package.json" 2>/dev/null || echo 0)
  local tmp=$(mktemp -p .cc-sessions .toolchain.XXXXXX 2>/dev/null) || return 0
  local existing="{}"
  [[ -f "$TOOLCHAIN_CACHE" ]] && existing=$(cat "$TOOLCHAIN_CACHE" 2>/dev/null || echo "{}")
  printf '%s' "$existing" | jq --arg root "$PROJECT_ROOT" --argjson mt "$pkg_mtime" --arg l "$lint" \
    '. + {($root): ((.[$root] // {}) + {mtime: $mt, linter: $l})}' > "$tmp" 2>/dev/null \
    && mv "$tmp" "$TOOLCHAIN_CACHE" || rm -f "$tmp"
}

# Detect linter and run it
detect_and_lint() {
  # Warm-cache fast path
  local cached
  if cached=$(toolchain_cached_linter); then
    case "$cached" in
      none) return ;;
      eslint) [[ -n "$(command -v npx)" ]] && { local O; O=$(npx eslint --fix "$FILE_PATH" 2>&1 || true); [[ -n "$O" ]] && echo "$O"; }; return ;;
      biome) [[ -n "$(command -v npx)" ]] && { local O; O=$(npx --yes @biomejs/biome lint --fix "$FILE_PATH" 2>&1 || true); [[ -n "$O" ]] && echo "$O"; }; return ;;
    esac
  fi

  # Check for ESLint config files
  if [[ -f "$PROJECT_ROOT/.eslintrc" || \
        -f "$PROJECT_ROOT/.eslintrc.js" || \
        -f "$PROJECT_ROOT/.eslintrc.cjs" || \
        -f "$PROJECT_ROOT/.eslintrc.mjs" || \
        -f "$PROJECT_ROOT/.eslintrc.json" || \
        -f "$PROJECT_ROOT/.eslintrc.yaml" || \
        -f "$PROJECT_ROOT/.eslintrc.yml" || \
        -f "$PROJECT_ROOT/eslint.config.js" || \
        -f "$PROJECT_ROOT/eslint.config.cjs" || \
        -f "$PROJECT_ROOT/eslint.config.mjs" || \
        -f "$PROJECT_ROOT/eslint.config.ts" ]]; then
    toolchain_write_linter "eslint"
    if command -v npx &>/dev/null; then
      local OUTPUT
      OUTPUT=$(npx eslint --fix "$FILE_PATH" 2>&1) || true
      # Output remaining errors as context for the AI
      if [[ -n "$OUTPUT" ]]; then
        echo "$OUTPUT"
      fi
      return
    fi
  fi

  # Check for eslint in package.json dependencies
  if [[ -f "$PROJECT_ROOT/package.json" ]] && \
     jq -e '(.devDependencies.eslint // .dependencies.eslint) != null' "$PROJECT_ROOT/package.json" &>/dev/null; then
    toolchain_write_linter "eslint"
    if command -v npx &>/dev/null; then
      local OUTPUT
      OUTPUT=$(npx eslint --fix "$FILE_PATH" 2>&1) || true
      if [[ -n "$OUTPUT" ]]; then
        echo "$OUTPUT"
      fi
      return
    fi
  fi

  # Check for Biome
  if [[ -f "$PROJECT_ROOT/biome.json" || -f "$PROJECT_ROOT/biome.jsonc" ]]; then
    toolchain_write_linter "biome"
    if command -v npx &>/dev/null; then
      local OUTPUT
      OUTPUT=$(npx --yes @biomejs/biome lint --fix "$FILE_PATH" 2>&1) || true
      if [[ -n "$OUTPUT" ]]; then
        echo "$OUTPUT"
      fi
      return
    fi
  fi

  # No linter detected — cache that fact to skip future jq calls
  toolchain_write_linter "none"
}

detect_and_lint
fi

# Always exit 0 — formatting or lint failure should not block edits
exit 0
