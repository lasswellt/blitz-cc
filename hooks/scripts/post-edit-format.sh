#!/usr/bin/env bash
# post-edit-format.sh — PostToolUse on Write|Edit.
#
# Formats the edited file, then lints it and prints remaining lint output as
# context for the model. Always exits 0: a formatting or lint failure must
# never block an edit.
#
# Language-agnostic by construction. This script knows no extensions, no
# tools and no config filenames. It asks scripts/toolchain.sh to resolve the
# `format` and `lint` lanes for the edited path and runs whatever comes back.
# Adding a language means adding rows to templates/toolchain.default.json.
set -uo pipefail
. "$(dirname "$0")/_lib/common.sh"

INPUT=$(cat)
FILE_PATH=$(blitz_extract file_path)
[ -z "$FILE_PATH" ] && exit 0
[ -f "$FILE_PATH" ] || exit 0

[ "${BLITZ_DISABLE_POST_EDIT_FORMAT:-0}" = "1" ] && exit 0

TOOLCHAIN="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}/scripts/toolchain.sh"
[ -x "$TOOLCHAIN" ] || [ -f "$TOOLCHAIN" ] || exit 0

# Resolve relative to the project root so marker files (package.json,
# pyproject.toml, Cargo.toml) are found. cwd follows the worktree; that is
# correct here, since the toolchain of a worktree is the toolchain of its
# checkout.
ROOT=$(blitz_find_root 2>/dev/null || true)
[ -n "$ROOT" ] && cd "$ROOT" 2>/dev/null || true

# Format: output is the tool's own chatter, which is noise. Discard stdout,
# keep the resolution line off the transcript.
bash "$TOOLCHAIN" run format "$FILE_PATH" >/dev/null 2>/dev/null || true

# Lint: remaining diagnostics ARE the signal. Print them so the model sees
# what its edit left behind.
LINT_OUT=$(bash "$TOOLCHAIN" run lint "$FILE_PATH" 2>/dev/null || true)
if [ -n "$LINT_OUT" ]; then
  # Cap the echo: a lint run over a whole crate can emit thousands of lines,
  # and this is advisory context, not a report.
  printf '%s\n' "$LINT_OUT" | head -c "${BLITZ_LINT_ECHO_CAP:-4000}"
fi

exit 0
