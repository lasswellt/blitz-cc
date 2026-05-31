#!/usr/bin/env bash
set -euo pipefail

# Pre-edit guard hook
# Blocks edits to protected files.
# Containment: environment-layer enforcement of TB-1 (project-local secrets/keys/locks untrusted).
# Canonical posture: /_shared/threat-model.md §3 TB-1.
# Reads JSON from stdin with tool_input.file_path.
# Exit 0 = allow, Exit 2 = block.

# Read the hook input from stdin
INPUT=$(cat)

# Extract the file path from the tool input
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

if [[ -z "$FILE_PATH" ]]; then
  # No file path found — allow (might be a non-file operation)
  exit 0
fi

# Get just the filename for pattern matching
FILENAME=$(basename "$FILE_PATH")

# --- Protected file patterns ---

# Block .env files (except .env.development and .env.example)
if [[ "$FILENAME" =~ ^\.env ]]; then
  if [[ "$FILENAME" == ".env.development" || "$FILENAME" == ".env.example" ]]; then
    exit 0
  fi
  echo "BLOCKED: Editing $FILENAME is not allowed. Only .env.development and .env.example may be edited." >&2
  exit 2
fi

# Block lock files
if [[ "$FILENAME" == "package-lock.json" || \
      "$FILENAME" == "pnpm-lock.yaml" || \
      "$FILENAME" == "yarn.lock" || \
      "$FILENAME" == "bun.lockb" || \
      "$FILENAME" == "composer.lock" || \
      "$FILENAME" == "Gemfile.lock" || \
      "$FILENAME" == "poetry.lock" ]]; then
  echo "BLOCKED: Editing lock file $FILENAME is not allowed. Use the package manager to update dependencies." >&2
  exit 2
fi

# Block secret/key files
if [[ "$FILENAME" =~ \.(pem|key|p12|pfx|keystore|jks)$ || \
      "$FILENAME" == "credentials.json" || \
      "$FILENAME" == "service-account.json" || \
      "$FILENAME" =~ ^.*serviceAccount.*\.json$ || \
      "$FILENAME" =~ ^.*secret.*\.json$ ]]; then
  echo "BLOCKED: Editing secret/key file $FILENAME is not allowed." >&2
  exit 2
fi

# Block git internals
if [[ "$FILE_PATH" == *"/.git/"* || "$FILE_PATH" == ".git/"* ]]; then
  echo "BLOCKED: Editing git internal files is not allowed." >&2
  exit 2
fi

# Block node_modules
if [[ "$FILE_PATH" == *"/node_modules/"* || "$FILE_PATH" == "node_modules/"* ]]; then
  echo "BLOCKED: Editing files inside node_modules is not allowed." >&2
  exit 2
fi

# Agent role boundary check — warn if agent edits outside its domain
AGENT_TYPE=$(echo "$INPUT" | jq -r '.agent_type // empty' 2>/dev/null || true)
if [[ -n "$AGENT_TYPE" ]]; then
  case "$AGENT_TYPE" in
    *frontend*)
      if [[ "$FILE_PATH" == *"/functions/"* || "$FILE_PATH" == *"/backend/"* ]]; then
        echo "WARNING: frontend agent editing backend file: $FILE_PATH" >&2
      fi
      ;;
    *backend*)
      if [[ "$FILE_PATH" == *"/components/"* || "$FILE_PATH" == *"/pages/"* || "$FILE_PATH" == *"/layouts/"* ]]; then
        echo "WARNING: backend agent editing frontend file: $FILE_PATH" >&2
      fi
      ;;
  esac
fi

# All checks passed — allow the edit
exit 0
