#!/usr/bin/env bash
# critic-gemini.sh — Cross-Model Critic (CMC) wrapper.
#
# Invokes the Gemini CLI as an alternative or paired adversarial reviewer
# for sprint-review Invariant 7, research-critic, or design-critic. Per
# arxiv 2604.19049, a critic from a different model family catches
# blindspots the home model has on its own work — research-critic.md flagged
# this as future work; this script implements it.
#
# Usage:
#   critic-gemini.sh --mode <pre-pass|research|design> [--prompt-file PATH] [--target PATH]
#   echo "<prompt>" | critic-gemini.sh --mode pre-pass --stdin
#
# Modes:
#   pre-pass — sprint-review Invariant 7 (replaces or pairs with agents/critic.md)
#   research — research-skill Phase 3.2.5 (replaces or pairs with agents/research-critic.md)
#   design   — ui-build Phase 5.4.2 (vision; requires gemini multimodal support)
#
# Env:
#   BLITZ_GEMINI_BIN   — override gemini binary (default: gemini)
#   BLITZ_GEMINI_MODEL — model id (default: gemini-2.5-pro)
#   BLITZ_GEMINI_FLAGS — extra flags appended to the gemini invocation
#
# Output:
#   Canonical JSON to stdout matching the contract of the corresponding
#   in-Claude critic agent (verdict + issues + summary fields).
#
# Exit:
#   0   — verdict LGTM | PASS
#   2   — verdict REJECT | CITATIONS_MISSING (sprint-review treats as block)
#   1   — invocation failure (gemini missing, malformed reply, parse error)

set -euo pipefail
SCRIPT_NAME="$(basename "$0")"
BLITZ_ROOT="${BLITZ_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
GEMINI_BIN="${BLITZ_GEMINI_BIN:-gemini}"
GEMINI_MODEL="${BLITZ_GEMINI_MODEL:-gemini-2.5-pro}"
# Read BLITZ_GEMINI_FLAGS as a newline-delimited list (one flag per line).
# This prevents word-splitting (e.g. --system-prompt "arg") from injecting
# multiple flags from a single env-var value — which could override the critic
# system prompt and return LGTM unconditionally.
#
# Use while+read (bash 3.2-compatible) instead of mapfile (bash 4+) since
# macOS ships bash 3.2 by default. Empty lines are skipped.
GEMINI_FLAGS=()
while IFS= read -r _flag; do
  [ -n "$_flag" ] && GEMINI_FLAGS+=("$_flag")
done < <(printf '%s\n' "${BLITZ_GEMINI_FLAGS:-}")

MODE=""
PROMPT_FILE=""
TARGET_PATH=""
USE_STDIN=0

usage() {
  sed -n '2,32p' "$0" | sed 's|^# \{0,1\}||'
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --mode)        MODE="$2"; shift 2 ;;
    --prompt-file) PROMPT_FILE="$2"; shift 2 ;;
    --target)      TARGET_PATH="$2"; shift 2 ;;
    --stdin)       USE_STDIN=1; shift ;;
    --help|-h)     usage; exit 0 ;;
    *) echo "[$SCRIPT_NAME] unknown arg: $1" >&2; exit 1 ;;
  esac
done

[ -z "$MODE" ] && { echo "[$SCRIPT_NAME] --mode required (pre-pass | research | design)" >&2; exit 1; }
case "$MODE" in pre-pass|research|design) ;; *) echo "[$SCRIPT_NAME] invalid mode: $MODE" >&2; exit 1;; esac

if ! command -v "$GEMINI_BIN" >/dev/null 2>&1; then
  echo "[$SCRIPT_NAME] gemini binary not found: $GEMINI_BIN. Install via 'npm i -g @google/gemini-cli' or set BLITZ_GEMINI_BIN." >&2
  exit 1
fi

# Build the prompt body.
PROMPT_BODY=""
if [ "$USE_STDIN" -eq 1 ]; then
  PROMPT_BODY="$(cat)"
elif [ -n "$PROMPT_FILE" ]; then
  [ ! -f "$PROMPT_FILE" ] && { echo "[$SCRIPT_NAME] prompt file not found: $PROMPT_FILE" >&2; exit 1; }
  PROMPT_BODY="$(cat "$PROMPT_FILE")"
else
  # Default per-mode prompt: lift the in-Claude agent's body verbatim.
  case "$MODE" in
    pre-pass) AGENT_FILE="${BLITZ_ROOT}/agents/critic.md" ;;
    research) AGENT_FILE="${BLITZ_ROOT}/agents/research-critic.md" ;;
    design)   AGENT_FILE="${BLITZ_ROOT}/agents/design-critic.md" ;;
  esac
  [ ! -f "$AGENT_FILE" ] && { echo "[$SCRIPT_NAME] agent file missing: $AGENT_FILE" >&2; exit 1; }
  # Strip frontmatter; keep body.
  PROMPT_BODY="$(awk '/^---$/{c++; next} c>=2{print}' "$AGENT_FILE")"
fi

# Append context per mode.
CTX=""
if [ -n "$TARGET_PATH" ]; then
  case "$MODE" in
    research|design)
      [ ! -f "$TARGET_PATH" ] && { echo "[$SCRIPT_NAME] target file not found: $TARGET_PATH" >&2; exit 1; }
      CTX="

---

## Target under review

Path: $TARGET_PATH

\`\`\`
$(cat "$TARGET_PATH")
\`\`\`
"
      ;;
    pre-pass)
      CTX="

---

## Target

Branch / sprint root: $TARGET_PATH
"
      ;;
  esac
fi

# Hard JSON-only directive — Gemini sometimes wraps replies in markdown fences.
JSON_DIRECTIVE='

---

CRITICAL OUTPUT REQUIREMENT: Return ONLY the canonical JSON described in the
"Output Format" section above. No markdown code fence. No preamble. No
trailing prose. The first character of your reply must be `{` and the last
character must be `}`. If you cannot satisfy this, return:
{"status":"failed","summary":"unable to comply with JSON-only contract","verdict":"REJECT","issues":[{"severity":"blocker","where":"critic-gemini","what":"reply contract violated"}]}'

FULL_PROMPT="${PROMPT_BODY}${CTX}${JSON_DIRECTIVE}"

# Invoke gemini in non-interactive (headless) mode. The CLI defaults to
# interactive — `-p/--prompt` is required to trigger headless. Long prompts
# go on stdin (gemini appends stdin to --prompt) so we don't hit shell
# arg-length limits.
RAW_REPLY="$(printf '%s\n' "$FULL_PROMPT" | "$GEMINI_BIN" --model "$GEMINI_MODEL" --prompt "" "${GEMINI_FLAGS[@]}" 2>&1)" || {
  echo "[$SCRIPT_NAME] gemini invocation failed:" >&2
  echo "$RAW_REPLY" >&2
  exit 1
}

# Strip optional markdown fence if Gemini wrapped despite the directive.
CLEAN_REPLY="$(printf '%s' "$RAW_REPLY" | sed -E '1{/^```(json)?$/d}; ${/^```$/d}')"

# Validate JSON.
if ! printf '%s' "$CLEAN_REPLY" | jq -e . >/dev/null 2>&1; then
  echo "[$SCRIPT_NAME] gemini returned non-JSON reply:" >&2
  printf '%s\n' "$CLEAN_REPLY" >&2
  exit 1
fi

# Extract verdict for exit code.
VERDICT="$(printf '%s' "$CLEAN_REPLY" | jq -r '.verdict // empty')"

# Emit cleaned JSON to stdout.
printf '%s\n' "$CLEAN_REPLY"

case "$VERDICT" in
  LGTM|PASS)
    exit 0 ;;
  REJECT|CITATIONS_MISSING|REWORK|ITERATE)
    exit 2 ;;
  *)
    echo "[$SCRIPT_NAME] unrecognized verdict: '$VERDICT' — treating as failure" >&2
    exit 1 ;;
esac
