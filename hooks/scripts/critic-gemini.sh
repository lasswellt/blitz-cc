#!/usr/bin/env bash
# critic-gemini.sh — back-compat shim over critic-external.sh.
#
# The Cross-Model Critic used to be Gemini-only. It is now provider-pluggable
# (gemini | agy | copilot | codex) and lives in critic-external.sh; this wrapper pins
# the gemini provider so existing callers, flags (--mode, --prompt-file,
# --target, --stdin), env (BLITZ_GEMINI_BIN / _MODEL / _FLAGS) and exit codes
# (0 LGTM, 2 REJECT, 1 failure) keep working unchanged.
#
# New callers should invoke critic-external.sh directly.

set -euo pipefail
exec "$(dirname "$0")/critic-external.sh" --provider gemini "$@"
