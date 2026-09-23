#!/usr/bin/env bash
# critic-external.sh — Cross-Model Critic (CMC), provider-pluggable.
#
# Invokes a non-Claude CLI agent as an alternative or paired adversarial
# reviewer for check (critic pre-pass), research-critic, or design-critic.
# Per arxiv 2604.19049, a critic from a different model family catches
# blindspots the home model has on its own work.
#
# Usage:
#   critic-external.sh --mode <pre-pass|research|design> [--provider NAME]
#                      [--panel a,b] [--prompt-file PATH] [--target PATH] [--stdin]
#                      [--plan SLUG] [--tasks IDS] [--base SHA]
#   critic-external.sh --mode pre-pass --plan user-profiles --tasks T-001,T-002 --base <sha>
#   echo "<prompt>" | critic-external.sh --mode pre-pass --provider agy --stdin
#
# Providers:
#   gemini   — Google Gemini CLI       (prompt on stdin)
#   agy      — Antigravity CLI         (prompt in argv; --add-dir fallback when large)
#   copilot  — GitHub Copilot CLI      (prompt in argv; no tools granted)
#   codex    — OpenAI Codex CLI        (prompt on stdin; read-only sandbox)
#
# Modes:
#   pre-pass — check critic pre-pass (replaces or pairs with agents/critic.md).
#              With no --stdin/--prompt-file the prompt is built here: the
#              MODE: reject / PLAN / TASKS / BASE header critic.md requires,
#              the agent body, and `git diff BASE` of the working tree.
#              --plan and --tasks default to none; --base defaults to the
#              merge-base with origin/HEAD, else HEAD~1.
#   research — research-skill Phase 3.2.5 (pairs with agents/research-critic.md)
#   design   — ui-build Phase 5.4.2 (vision; requires a multimodal provider)
#
# Env:
#   BLITZ_CRITIC_PROVIDER — default provider when --provider is absent (default: gemini)
#   BLITZ_CRITIC_PANEL    — comma-separated providers; runs each and merges verdicts
#   BLITZ_<P>_BIN         — override a provider binary (P = GEMINI | AGY | COPILOT | CODEX)
#   BLITZ_<P>_MODEL       — model id for that provider (codex: unset uses the
#                           model in ~/.codex/config.toml)
#   BLITZ_<P>_FLAGS       — extra flags, one per line (never space-split: a single
#                           value must not be able to inject a second flag such as
#                           --system-prompt and force an unconditional LGTM)
#   BLITZ_CRITIC_ARG_CAP  — bytes above which the prompt is handed over as a file
#                           instead of argv (default 100000; Linux caps one argv
#                           string at 128 KiB and the CLI dies with E2BIG)
#
# Output:
#   One provider  — that provider's canonical JSON, exactly as the in-Claude
#                   critic agent would emit it (verdict + issues + summary).
#   Panel         — {verdict, rule, providers[], issues[], errors[], summary}.
#                   Rule: any REJECT blocks. A provider that fails to answer is
#                   recorded in errors[] and does not block on its own.
#
# Exit:
#   0   — verdict LGTM | PASS (panel: at least one verdict, none rejecting)
#   2   — verdict REJECT | CITATIONS_MISSING | UNVERIFIED | REWORK | ITERATE
#         (panel: any of these)
#   1   — invocation failure (binary missing, malformed reply, parse error;
#         panel: no provider produced a valid verdict; also a NEEDS_CONTEXT or
#         BLOCKED reply that carries no verdict)
#
# Every prompt is prefixed with the plugin's paths: the critic bodies cite
# scripts/tasks.sh and /_shared/check-registry.json, which live in the plugin,
# not in the repo under review. Without them the external critic stops with
# BLOCKED dependency-missing, or cites rule ids it could not look up.

set -euo pipefail
SCRIPT_NAME="$(basename "$0")"
BLITZ_ROOT="${BLITZ_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
ARG_CAP="${BLITZ_CRITIC_ARG_CAP:-100000}"

MODE=""
PROMPT_FILE=""
TARGET_PATH=""
PANEL=""
PROVIDER=""
USE_STDIN=0
PLAN=""
TASKS=""
BASE=""

usage() {
  awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "$0"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --mode)        MODE="$2"; shift 2 ;;
    --provider)    PROVIDER="$2"; shift 2 ;;
    --panel)       PANEL="$2"; shift 2 ;;
    --prompt-file) PROMPT_FILE="$2"; shift 2 ;;
    --target)      TARGET_PATH="$2"; shift 2 ;;
    --stdin)       USE_STDIN=1; shift ;;
    --plan)        PLAN="$2"; shift 2 ;;
    --tasks)       TASKS="$2"; shift 2 ;;
    --base)        BASE="$2"; shift 2 ;;
    --help|-h)     usage; exit 0 ;;
    *) echo "[$SCRIPT_NAME] unknown arg: $1" >&2; exit 1 ;;
  esac
done

[ -z "$MODE" ] && { echo "[$SCRIPT_NAME] --mode required (pre-pass | research | design)" >&2; exit 1; }
case "$MODE" in pre-pass|research|design) ;; *) echo "[$SCRIPT_NAME] invalid mode: $MODE" >&2; exit 1;; esac

# Provider list. An explicit flag always beats ambient env: --panel, then
# --provider, then BLITZ_CRITIC_PANEL, then BLITZ_CRITIC_PROVIDER, then the
# gemini default. The order matters — with a panel set globally in settings.json,
# env-first resolution would silently turn critic-gemini.sh (which passes
# --provider gemini) or any one-off --provider run into the full panel.
PROVIDERS=()
if [ -n "$PANEL" ]; then
  IFS=',' read -r -a PROVIDERS <<< "$PANEL"
elif [ -n "$PROVIDER" ]; then
  PROVIDERS=("$PROVIDER")
elif [ -n "${BLITZ_CRITIC_PANEL:-}" ]; then
  IFS=',' read -r -a PROVIDERS <<< "$BLITZ_CRITIC_PANEL"
else
  PROVIDERS=("${BLITZ_CRITIC_PROVIDER:-gemini}")
fi

for p in "${PROVIDERS[@]}"; do
  case "$p" in
    gemini|agy|copilot|codex) ;;
    *) echo "[$SCRIPT_NAME] unknown provider: $p (gemini | agy | copilot | codex)" >&2; exit 1 ;;
  esac
done

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# ---------------------------------------------------------------- prompt body
PROMPT_BODY=""
if [ "$USE_STDIN" -eq 1 ]; then
  PROMPT_BODY="$(cat)"
elif [ -n "$PROMPT_FILE" ]; then
  [ ! -f "$PROMPT_FILE" ] && { echo "[$SCRIPT_NAME] prompt file not found: $PROMPT_FILE" >&2; exit 1; }
  PROMPT_BODY="$(cat "$PROMPT_FILE")"
else
  # Default per-mode prompt: lift the in-Claude agent's body verbatim, so the
  # external critic is held to the same contract as the one it replaces.
  case "$MODE" in
    pre-pass) AGENT_FILE="${BLITZ_ROOT}/agents/critic.md" ;;
    research) AGENT_FILE="${BLITZ_ROOT}/agents/research-critic.md" ;;
    design)   AGENT_FILE="${BLITZ_ROOT}/agents/design-critic.md" ;;
  esac
  [ ! -f "$AGENT_FILE" ] && { echo "[$SCRIPT_NAME] agent file missing: $AGENT_FILE" >&2; exit 1; }
  PROMPT_BODY="$(awk '/^---$/{c++; next} c>=2{print}' "$AGENT_FILE")"
  # critic.md answers NEEDS_CONTEXT without its header, so the default
  # pre-pass prompt carries the header and the diff the in-Claude critic gets.
  if [ "$MODE" = "pre-pass" ]; then
    if [ -z "$BASE" ]; then
      BASE="$(git merge-base HEAD origin/HEAD 2>/dev/null || git rev-parse --verify -q HEAD~1 2>/dev/null || true)"
    fi
    [ -z "$BASE" ] && { echo "[$SCRIPT_NAME] --base required: no origin/HEAD merge-base or HEAD~1 here" >&2; exit 1; }
    PATCH="$(git --no-pager diff "$BASE" 2>/dev/null)" || {
      echo "[$SCRIPT_NAME] git diff $BASE failed — run from the repo under review" >&2; exit 1; }
    PROMPT_BODY="MODE: reject
PLAN: ${PLAN:-none}
TASKS: ${TASKS:-none}
BASE: ${BASE}

${PROMPT_BODY}

---

## check.patch (git diff ${BASE})

\`\`\`diff
${PATCH}
\`\`\`"
  fi
fi

# Plugin paths the agent bodies cite. Prepended on every path, --stdin
# included: a caller that pipes the critic body in has the same gap.
PLUGIN_PATHS="PLUGIN_ROOT: ${BLITZ_ROOT}
Path resolution for this review: \`/_shared/\` is ${BLITZ_ROOT}/skills/_shared/ ;
\`scripts/tasks.sh\` is ${BLITZ_ROOT}/scripts/tasks.sh ; plan files
(\`docs/plans/\`, \`docs/sweeps/ratchet.json\`) are relative to the current
working directory, the repo under review. A missing ratchet baseline means the
first run: skip ratchet comparisons rather than blocking.

"
PROMPT_BODY="${PLUGIN_PATHS}${PROMPT_BODY}"

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

Branch / plan root: $TARGET_PATH
"
      ;;
  esac
fi

# Hard JSON-only directive — every one of these CLIs will otherwise wrap the
# reply in a markdown fence or a sentence of preamble.
JSON_DIRECTIVE='

---

CRITICAL OUTPUT REQUIREMENT: Return ONLY the canonical JSON described in the
"Output Format" section above. No markdown code fence. No preamble. No
trailing prose. The first character of your reply must be `{` and the last
character must be `}`. If you cannot satisfy this, return:
{"status":"failed","summary":"unable to comply with JSON-only contract","verdict":"REJECT","issues":[{"severity":"blocker","where":"critic-external","what":"reply contract violated"}]}'

FULL_PROMPT="${PROMPT_BODY}${CTX}${JSON_DIRECTIVE}"

# ------------------------------------------------------------------ providers
# Read a provider's extra flags as a newline-delimited list (one flag per line).
# Space-splitting would let a single env value inject a second flag — e.g. a
# system-prompt override that returns LGTM unconditionally. while+read keeps
# bash 3.2 (macOS) compatibility; mapfile would not.
read_flags() {  # read_flags <ENVVAR-NAME> — echoes nothing, fills PROVIDER_FLAGS
  PROVIDER_FLAGS=()
  local _raw _flag
  eval "_raw=\${$1:-}"
  while IFS= read -r _flag; do
    [ -n "$_flag" ] && PROVIDER_FLAGS+=("$_flag")
  done < <(printf '%s\n' "$_raw")
}

# Hand a large prompt over as a file: Linux caps a single argv string at 128 KiB
# (MAX_ARG_STRLEN) and neither agy nor copilot reads the prompt from stdin, so a
# big diff would kill the invocation with E2BIG. Both accept --add-dir.
prompt_or_pointer() {  # sets ARG_PROMPT and PROVIDER_EXTRA for an argv-only CLI
  ARG_PROMPT="$FULL_PROMPT"
  PROVIDER_EXTRA=()
  if [ "${#FULL_PROMPT}" -gt "$ARG_CAP" ]; then
    printf '%s\n' "$FULL_PROMPT" > "$WORK/critic-prompt.md"
    ARG_PROMPT="Read the file $WORK/critic-prompt.md and follow every instruction in it exactly. Return only the JSON it specifies, with no other output."
    PROVIDER_EXTRA=(--add-dir "$WORK")
  fi
}

invoke_provider() {  # invoke_provider <provider> — raw reply on stdout, diagnostics on stderr
  local provider="$1" bin model
  case "$provider" in
    gemini)
      bin="${BLITZ_GEMINI_BIN:-gemini}"
      model="${BLITZ_GEMINI_MODEL:-gemini-2.5-pro}"
      read_flags BLITZ_GEMINI_FLAGS
      command -v "$bin" >/dev/null 2>&1 || {
        echo "[$SCRIPT_NAME] gemini binary not found: $bin. Install via 'npm i -g @google/gemini-cli' or set BLITZ_GEMINI_BIN." >&2
        return 1; }
      # gemini appends stdin to --prompt, so the body never touches argv.
      printf '%s\n' "$FULL_PROMPT" | "$bin" --model "$model" --prompt "" ${PROVIDER_FLAGS[@]+"${PROVIDER_FLAGS[@]}"}
      ;;
    agy)
      bin="${BLITZ_AGY_BIN:-agy}"
      model="${BLITZ_AGY_MODEL:-gemini-3.1-pro-high}"
      read_flags BLITZ_AGY_FLAGS
      command -v "$bin" >/dev/null 2>&1 || {
        echo "[$SCRIPT_NAME] agy binary not found: $bin. Install the Antigravity CLI or set BLITZ_AGY_BIN." >&2
        return 1; }
      prompt_or_pointer
      # --disable-slash-commands: the diff under review is untrusted text, and a
      # line starting with / would otherwise expand as a slash command.
      "$bin" --print "$ARG_PROMPT" --model "$model" --output-format text \
        --disable-slash-commands ${PROVIDER_EXTRA[@]+"${PROVIDER_EXTRA[@]}"} ${PROVIDER_FLAGS[@]+"${PROVIDER_FLAGS[@]}"}
      ;;
    copilot)
      bin="${BLITZ_COPILOT_BIN:-copilot}"
      model="${BLITZ_COPILOT_MODEL:-auto}"
      read_flags BLITZ_COPILOT_FLAGS
      command -v "$bin" >/dev/null 2>&1 || {
        echo "[$SCRIPT_NAME] copilot binary not found: $bin. Install the GitHub Copilot CLI or set BLITZ_COPILOT_BIN." >&2
        return 1; }
      prompt_or_pointer
      # No --allow-all-tools: a critic reads and answers, it does not act. The
      # CLI asks for approval it cannot get and stops, which is the safe end.
      "$bin" --prompt "$ARG_PROMPT" --model "$model" --silent --log-level none \
        ${PROVIDER_EXTRA[@]+"${PROVIDER_EXTRA[@]}"} ${PROVIDER_FLAGS[@]+"${PROVIDER_FLAGS[@]}"}
      ;;
    codex)
      bin="${BLITZ_CODEX_BIN:-codex}"
      model="${BLITZ_CODEX_MODEL:-}"
      read_flags BLITZ_CODEX_FLAGS
      command -v "$bin" >/dev/null 2>&1 || {
        echo "[$SCRIPT_NAME] codex binary not found: $bin. Install via 'npm i -g @openai/codex' or set BLITZ_CODEX_BIN." >&2
        return 1; }
      PROVIDER_EXTRA=()
      [ -n "$model" ] && PROVIDER_EXTRA=(--model "$model")
      # Prompt on stdin (`-`), so no argv cap. --sandbox read-only: the critic may
      # read the repo and run git, never write to it. --ephemeral keeps review
      # sessions out of ~/.codex; exec prints only the final message on stdout.
      printf '%s\n' "$FULL_PROMPT" | "$bin" exec --sandbox read-only --ephemeral \
        --skip-git-repo-check --color never \
        ${PROVIDER_EXTRA[@]+"${PROVIDER_EXTRA[@]}"} ${PROVIDER_FLAGS[@]+"${PROVIDER_FLAGS[@]}"} -
      ;;
  esac
}

# Strip an optional markdown fence, then drop pre-JSON noise (credential lines,
# startup banners). Keeping from the first line that begins with `{` never
# truncates JSON content the way brace-counting does.
clean_reply() {
  sed -E '1{/^```(json)?$/d}; ${/^```$/d}' | awk '/^[[:space:]]*\{/{f=1} f'
}

# --------------------------------------------------------------------- run
run_one() {  # run_one <provider> — writes cleaned JSON to $WORK/<provider>.json
  local provider="$1"
  local err="$WORK/$provider.err" raw clean
  # stderr is captured separately, never merged: every one of these CLIs prints
  # capability warnings and credential notices that would corrupt the JSON.
  if ! raw="$(invoke_provider "$provider" 2>"$err")"; then
    echo "[$SCRIPT_NAME] $provider invocation failed:" >&2
    cat "$err" >&2
    return 1
  fi
  clean="$(printf '%s' "$raw" | clean_reply)"
  if ! printf '%s' "$clean" | jq -e . >/dev/null 2>&1; then
    echo "[$SCRIPT_NAME] $provider returned non-JSON reply:" >&2
    printf '%s\n' "$clean" >&2
    return 1
  fi
  printf '%s\n' "$clean" > "$WORK/$provider.json"
  return 0
}

if [ "${#PROVIDERS[@]}" -eq 1 ]; then
  provider="${PROVIDERS[0]}"
  run_one "$provider" || exit 1
  cat "$WORK/$provider.json"
  VERDICT="$(jq -r '.verdict // empty' "$WORK/$provider.json")"
  case "$VERDICT" in
    LGTM|PASS)
      exit 0 ;;
    REJECT|CITATIONS_MISSING|UNVERIFIED|REWORK|ITERATE)
      exit 2 ;;
    *)
      echo "[$SCRIPT_NAME] unrecognized verdict: '$VERDICT' — treating as failure" >&2
      exit 1 ;;
  esac
fi

# Panel: every provider runs, then any REJECT blocks. A provider that cannot
# answer is recorded and ignored — one broken CLI must not turn the gate green
# on its own, nor block a release on its own.
PANEL_JSON="$WORK/panel.json"
echo '{"providers":[],"errors":[]}' > "$PANEL_JSON"
for provider in "${PROVIDERS[@]}"; do
  if run_one "$provider"; then
    jq --arg p "$provider" --slurpfile r "$WORK/$provider.json" \
      '.providers += [{provider:$p, verdict:($r[0].verdict // "UNKNOWN"), summary:($r[0].summary // ""), issues:($r[0].issues // []), raw:$r[0]}]' \
      "$PANEL_JSON" > "$PANEL_JSON.tmp" && mv "$PANEL_JSON.tmp" "$PANEL_JSON"
  else
    jq --arg p "$provider" --arg e "$(tail -c 400 "$WORK/$provider.err" 2>/dev/null || echo 'invocation failed')" \
      '.errors += [{provider:$p, error:$e}]' \
      "$PANEL_JSON" > "$PANEL_JSON.tmp" && mv "$PANEL_JSON.tmp" "$PANEL_JSON"
  fi
done

jq '
  (.providers | map(select(.verdict as $v | ["REJECT","CITATIONS_MISSING","UNVERIFIED","REWORK","ITERATE"] | index($v)))) as $rejecting
  | {
      verdict: (if ($rejecting | length) > 0 then "REJECT"
                elif (.providers | length) > 0 then "LGTM"
                else "UNKNOWN" end),
      rule: "any-reject-blocks",
      summary: (if ($rejecting | length) > 0
                then (($rejecting | map(.provider) | join(", ")) + " rejected")
                elif (.providers | length) > 0
                then ((.providers | map(.provider) | join(", ")) + " found no blocker")
                else "no provider produced a verdict" end),
      issues: ($rejecting | map(.issues[]?)),
      providers: .providers,
      errors: .errors
    }' "$PANEL_JSON"

ANSWERED="$(jq -r '.providers | length' "$PANEL_JSON")"
REJECTED="$(jq -r '[.providers[] | select(.verdict == "REJECT" or .verdict == "CITATIONS_MISSING" or .verdict == "UNVERIFIED" or .verdict == "REWORK" or .verdict == "ITERATE")] | length' "$PANEL_JSON")"

if [ "$ANSWERED" -eq 0 ]; then
  echo "[$SCRIPT_NAME] no provider produced a valid verdict" >&2
  exit 1
fi
[ "$REJECTED" -gt 0 ] && exit 2
exit 0
