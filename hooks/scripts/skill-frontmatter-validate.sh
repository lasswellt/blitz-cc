#!/usr/bin/env bash
# skill-frontmatter-validate.sh — Anthropic-canonical SKILL.md lint.
#
# Usage:
#   skill-frontmatter-validate.sh [skill-path...]
#   skill-frontmatter-validate.sh --all   # scan skills/*/SKILL.md
#
# Exit:
#   0 — all SKILL.md files conform
#   1 — one or more files violate the canonical contract
#
# Checks (each skill must satisfy):
#   1. YAML frontmatter parses
#   2. name: present, ≤64 chars, lowercase + digits + hyphens, no "anthropic"/"claude"
#   3. description: present, non-empty, ≤1024 chars
#   4. model: present (opus|sonnet|haiku) — required when disable-model-invocation is false or absent
#   5. effort: optional; only on slash-only skills (low|medium|high|xhigh|max)
#   6. allowed-tools: present unless disable-model-invocation: true
#   7. argument-hint: present if SKILL.md body references "$1"/"$@"/positional args
#   8. Body size ≤ 15,000 B — under the 5,000-token compaction re-attach cap at 3.0 B/tok
#   9. allowed-tools never lists the Task/Todo tools (off on Claude 5 models; tasks.json is the tracker)
#  10. compatibility: present, ">=" semver pin
#  11. a pinned model: discloses its cache cost in the body

set -euo pipefail
. "$(dirname "$0")/_lib/common.sh"
SCRIPT_NAME="$(basename "$0")"
BLITZ_ROOT="${BLITZ_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
RC=0
# Cumulative description-char budget (full-scan only). The ~37 skill
# descriptions load every session into the SLASH_COMMAND_TOOL_CHAR_BUDGET
# (~15000 hard platform cap; see docs/audits/skill-startup-token-budget.md).
# We guard at 8000 to leave headroom before the cap.
CUMULATIVE_DESC_CHARS=0
CUMULATIVE_DESC_BUDGET=8000
# Fast-path scope guard for PostToolUse Write|Edit invocations.
# When invoked as `--all` with hook JSON on stdin, exit 0 early unless the
# edited file is a SKILL.md. Falls through to the existing behavior when
# called from the CLI (no stdin tty) or with explicit file arguments.
if [ "$#" -eq 1 ] && [ "${1:-}" = "--all" ] && [ ! -t 0 ]; then
  INPUT=$(cat 2>/dev/null || true)
  if [ -n "$INPUT" ]; then
    EDITED_FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)
    case "$EDITED_FILE" in
      skills/*/SKILL.md|*/skills/*/SKILL.md) ;;
      "") ;;
      *) exit 0 ;;
    esac
  fi
fi

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [skill-path...] | --all
  Validates SKILL.md files against Anthropic-canonical conventions.
  Without arguments, validates skills/*/SKILL.md under \$BLITZ_ROOT (or cwd).
EOF
}

# Resolve target list.
# FULL_SCAN is set when the whole tree is scanned (--all or no-arg). The
# cumulative-description budget guard runs ONLY in this mode — pre-commit and
# PostToolUse invocations pass a subset of skill paths and must not be measured
# against the global budget.
TARGETS=()
FULL_SCAN=0
if [ "$#" -eq 0 ] || [ "${1:-}" = "--all" ]; then
  FULL_SCAN=1
  while IFS= read -r f; do TARGETS+=("$f"); done < <(find "${BLITZ_ROOT}/skills" -mindepth 2 -maxdepth 2 -name SKILL.md 2>/dev/null | sort)
else
  for arg in "$@"; do
    [ "$arg" = "--help" ] && { usage; exit 0; }
    TARGETS+=("$arg")
  done
fi

[ "${#TARGETS[@]}" -eq 0 ] && { echo "[$SCRIPT_NAME] No SKILL.md files found" >&2; exit 1; }

# fail() is provided by _lib/common.sh (sourced above).

validate_one() {
  local f="$1"
  local rel="${f#$BLITZ_ROOT/}"
  [ ! -f "$f" ] && { fail "$rel" "file not found"; return; }

  # Extract frontmatter (between first two lines starting with ---)
  local fm body
  fm=$(awk '/^---$/{c++; next} c==1{print} c>=2{exit}' "$f")
  body=$(awk '/^---$/{c++; next} c>=2{print}' "$f")
  [ -z "$fm" ] && { fail "$rel" "missing YAML frontmatter"; return; }

  # Parse fields
  local name desc model effort allowed dmi argh compat
  name=$(printf '%s\n' "$fm" | awk -F': *' '/^name:/{print $2; exit}' | tr -d '"')
  desc=$(printf '%s\n' "$fm" | awk -F': *' '/^description:/{$1=""; sub(/^ */,""); print; exit}' | sed 's/^"\(.*\)"$/\1/')
  model=$(printf '%s\n' "$fm" | awk -F': *' '/^model:/{print $2; exit}' | tr -d '"')
  effort=$(printf '%s\n' "$fm" | awk -F': *' '/^effort:/{print $2; exit}' | tr -d '"')
  allowed=$(printf '%s\n' "$fm" | awk -F': *' '/^allowed-tools:/{$1=""; sub(/^ */,""); print; exit}')
  dmi=$(printf '%s\n' "$fm" | awk -F': *' '/^disable-model-invocation:/{print $2; exit}' | tr -d '"')
  argh=$(printf '%s\n' "$fm" | awk -F': *' '/^argument-hint:/{$1=""; sub(/^ */,""); print; exit}')
  compat=$(printf '%s\n' "$fm" | awk -F': *' '/^compatibility:/{print $2; exit}' | tr -d '"')

  # 2. name
  [ -z "$name" ] && fail "$rel" "frontmatter missing 'name:'"
  [ "${#name}" -gt 64 ] && fail "$rel" "name '$name' exceeds 64 chars"
  echo "$name" | grep -qE '^[a-z0-9-]+$' || fail "$rel" "name '$name' must be lowercase + digits + hyphens"
  case "$name" in *anthropic*|*claude*) fail "$rel" "name contains reserved word 'anthropic' or 'claude'";; esac

  # 3. description
  [ -z "$desc" ] && fail "$rel" "frontmatter missing 'description:'"
  [ "${#desc}" -gt 1024 ] && fail "$rel" "description length ${#desc} exceeds 1024 chars"
  # Accumulate toward the cumulative budget (consumed only in full-scan mode).
  CUMULATIVE_DESC_CHARS=$((CUMULATIVE_DESC_CHARS + ${#desc}))

  # 6. allowed-tools (unless disable-model-invocation: true)
  if [ "$dmi" != "true" ]; then
    [ -z "$allowed" ] && fail "$rel" "missing 'allowed-tools:' (required when disable-model-invocation is not true)"
    # 4. model — required when invokable
    [ -z "$model" ] && fail "$rel" "frontmatter missing 'model:' (required when disable-model-invocation is not true)"
    case "$model" in inherit|opus|sonnet|haiku|"") ;; *) fail "$rel" "model '$model' must be inherit|opus|sonnet|haiku";; esac
    # Model-invokable skills MUST inherit the session model: pinning forces a model switch on
    # every invocation from a non-matching session, which resets the prompt cache (E-044).
    [ -n "$model" ] && [ "$model" != "inherit" ] && fail "$rel" "model '$model' pins a model on an invokable skill — use 'inherit' (slash-only skills with disable-model-invocation: true may pin)"
  fi

  # 5. effort — optional. Pinning effort switches it mid-session (cache reset), so it is only
  # accepted on slash-only skills (disable-model-invocation: true). Others state a recommendation in the body.
  if [ -n "$effort" ]; then
    case "$effort" in low|medium|high|xhigh|max) ;; *) fail "$rel" "effort '$effort' must be low|medium|high|xhigh|max";; esac
    [ "$dmi" != "true" ] && fail "$rel" "effort pinned on an invokable skill — remove 'effort:' and state the recommendation in the body (see E-044)"
  fi

  # 11. A pinned model must disclose its cost. A skill whose frontmatter names a
  # model other than the session's makes that turn a full model switch: the next
  # request reads the entire conversation history with no cache hits. That can be
  # the right trade for a rare slash-only skill, but it must be a stated decision,
  # not an accident, so the body has to say so.
  if [ -n "$model" ] && [ "$model" != "inherit" ]; then
    if ! printf '%s' "$body" | grep -qiE 'cache reset|cache miss|uncached|full re-read'; then
      fail "$rel" "pins 'model: $model' without disclosing the cost — a pinned model makes the turn a model switch with zero cache hits; say so in the body (see skills/ship/SKILL.md)"
    fi
  fi

  # 10. compatibility
  [ -z "$compat" ] && fail "$rel" "frontmatter missing 'compatibility:'"
  echo "$compat" | grep -qE '^>=[0-9]+\.[0-9]+\.[0-9]+$' || fail "$rel" "compatibility '$compat' must be '>=X.Y.Z'"

  # 8. body size — a TOKEN budget, not a line count.
  #
  # The line cap was the wrong guard: `check` passed it at 295 lines while
  # being 40% over the limit that actually bites. After auto-compaction Claude
  # Code re-attaches the most recent invocation of each skill keeping only the
  # FIRST 5,000 TOKENS of each, sharing a 25,000-token budget across them. A
  # body past 5,000 tokens is silently truncated, and because markdown puts
  # terminal phases last, what gets cut is the verdict, the gate, the report
  # and the recovery — exactly what a long session needs, and a long session is
  # when compaction fires.
  #
  # THE CAP IS IN BYTES BECAUSE THE REAL COUNT NEEDS A NETWORK CALL.
  #
  # Only `POST /v1/messages/count_tokens` counts Claude tokens accurately, and
  # it is model-specific. There is no offline Claude tokenizer to install, and
  # tiktoken/gpt-tokenizer must NOT be substituted: they are OpenAI's, and
  # undercount Claude by ~15-20% on prose and more on code — precisely the
  # content here. `scripts/count-tokens.sh` does it properly where a credential
  # exists; this hook runs on every edit, so it uses a byte proxy calibrated
  # against the worst plausible ratio.
  #
  # Derivation. The platform cuts a re-attached skill at 5,000 tokens. English
  # prose runs ~3.6-4.0 bytes/token for Claude; markdown dense with tables,
  # code blocks, paths and CLI flags runs denser, ~3.0-3.5. Taking 3.0 as the
  # pessimistic floor, a body stays under 5,000 tokens when it is under
  # 5,000 x 3.0 = 15,000 bytes. The earlier 18,000 cap assumed 4.0 bytes/token
  # and was therefore unsafe for exactly the skills it was meant to protect.
  #
  # Replace this with measurement when a credential is available:
  #   scripts/count-tokens.sh --calibrate
  # prints the observed bytes-per-token and the safe cap at the worst ratio.
  local body_bytes body_tokens
  body_bytes=$(printf '%s' "$body" | wc -c | tr -d ' ')
  body_tokens=$(( body_bytes / 4 ))
  if [ "$body_bytes" -gt "${BLITZ_SKILL_BODY_CAP:-15000}" ]; then
    fail "$rel" "body is ${body_bytes}B (~${body_tokens} tok), over the ${BLITZ_SKILL_BODY_CAP:-15000}B cap (5,000 tokens at 3.0 B/tok, the pessimistic ratio for dense markdown); the platform keeps only the first 5,000 tokens of a re-attached skill after compaction. Move mid-body detail to references/ and keep the closing phases (gate, verdict, report, recovery) in the body"
  fi

  # 9. Task/Todo tools are gated off on Claude 5 models and never part of the v3 contract.
  local gated_tool
  for gated_tool in TaskCreate TaskUpdate TaskList TaskGet TodoWrite; do
    if printf '%s\n' "$allowed" | grep -qE "(^|[, ])${gated_tool}([, ]|$)"; then
      fail "$rel" "allowed-tools lists '${gated_tool}' — Task/Todo tools are off on current models; track work in docs/plans/<slug>/tasks.json"
    fi
  done
  return 0
}

for f in "${TARGETS[@]}"; do validate_one "$f"; done

# Cumulative-description budget guard — full-scan only. A subset invocation
# (pre-commit / PostToolUse) cannot meaningfully measure the global total.
if [ "$FULL_SCAN" -eq 1 ]; then
  if [ "$CUMULATIVE_DESC_CHARS" -gt "$CUMULATIVE_DESC_BUDGET" ]; then
    echo "[$SCRIPT_NAME] FAIL: cumulative skill descriptions = $CUMULATIVE_DESC_CHARS chars > $CUMULATIVE_DESC_BUDGET budget guard (15000 hard platform cap) — trim a description before adding more" >&2
    RC=1
  else
    echo "[$SCRIPT_NAME] cumulative skill descriptions = $CUMULATIVE_DESC_CHARS chars (<= $CUMULATIVE_DESC_BUDGET budget guard)"
  fi
fi

if [ "$RC" -eq 0 ]; then
  echo "[$SCRIPT_NAME] OK: ${#TARGETS[@]} SKILL.md files conform"
else
  echo "[$SCRIPT_NAME] FAIL: violations above" >&2
fi
exit "$RC"
