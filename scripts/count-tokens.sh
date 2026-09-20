#!/usr/bin/env bash
# count-tokens.sh — authoritative Claude token counts for files.
#
# Uses the Messages API `count_tokens` endpoint, which is the only accurate
# counter for Claude models: counts are model-specific and the endpoint is
# stateless, so a file is counted on its own.
#
# DO NOT substitute tiktoken, gpt-tokenizer or any local BPE library. Those are
# OpenAI's tokenizer: they undercount Claude by roughly 15-20% on typical text
# and by more on code and non-English input, which is exactly the content this
# repository measures. Anthropic publishes no offline tokenizer for current
# models, so an exact count needs a credential and a network call.
#
# Needs a credential: ANTHROPIC_API_KEY, ANTHROPIC_AUTH_TOKEN, or a profile
# from `ant auth login`. Without one it exits 3 and prints the byte estimate
# so the caller can degrade deliberately rather than silently.
#
# Results are cached by content hash in .cc-sessions/token-counts.json, so a
# re-run over unchanged files makes no API calls.
#
# Usage:
#   count-tokens.sh <file>...            print "<tokens>\t<path>" per file
#   count-tokens.sh --skills             every skills/*/SKILL.md body
#   count-tokens.sh --calibrate          print measured bytes-per-token
#   count-tokens.sh --json <file>...     machine-readable
#
# Exit: 0 counted · 3 no credential (estimates printed to stderr) · 2 usage
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
MODEL="${BLITZ_COUNT_MODEL:-claude-opus-5}"

[ "$#" -eq 0 ] && { echo "usage: count-tokens.sh {<file>...|--skills|--calibrate} [--json]" >&2; exit 2; }

MODE="files"; JSON=0; declare -a FILES=()
for a in "$@"; do
  case "$a" in
    --skills)    MODE="skills" ;;
    --calibrate) MODE="calibrate" ;;
    --json)      JSON=1 ;;
    *)           FILES+=("$a") ;;
  esac
done
if [ "$MODE" != "files" ]; then
  while IFS= read -r f; do FILES+=("$f"); done < <(ls skills/*/SKILL.md 2>/dev/null)
fi
[ "${#FILES[@]}" -eq 0 ] && { echo "count-tokens: no files" >&2; exit 2; }

python3 - "$MODEL" "$MODE" "$JSON" "${FILES[@]}" <<'PY'
import hashlib, json, os, re, sys

model, mode, want_json = sys.argv[1], sys.argv[2], sys.argv[3] == "1"
paths = sys.argv[4:]
CACHE = ".cc-sessions/token-counts.json"

def body_of(path, text):
    # A SKILL.md's frontmatter is not part of the body the compaction cap
    # applies to; everything else is counted whole.
    if path.endswith("SKILL.md"):
        m = re.match(r'^---\n.*?\n---\n(.*)$', text, re.S)
        if m:
            return m.group(1)
    return text

cache = {}
try:
    with open(CACHE) as fh:
        cache = json.load(fh).get("counts", {})
except Exception:
    pass

items = []
for p in paths:
    try:
        with open(p) as fh:
            t = body_of(p, fh.read())
    except OSError as e:
        print(f"count-tokens: {p}: {e}", file=sys.stderr)
        continue
    key = hashlib.sha256((model + "\0" + t).encode()).hexdigest()
    items.append((p, t, key))

def no_credential(reason):
    # The SDK resolves credentials lazily, so an unauthenticated environment
    # surfaces on the first request rather than at construction. Either way the
    # answer is the same: say so loudly and print byte estimates clearly marked
    # as NOT token counts, so a caller degrades deliberately.
    print("count-tokens: no usable credential; cannot produce real counts.", file=sys.stderr)
    print(f"  {reason}", file=sys.stderr)
    print("  Set ANTHROPIC_API_KEY / ANTHROPIC_AUTH_TOKEN, or run `ant auth login`, then re-run.", file=sys.stderr)
    print("  Below are BYTE ESTIMATES, not token counts. They understate dense", file=sys.stderr)
    print("  markdown: a local BPE library would too, which is why none is used.", file=sys.stderr)
    for pp, tt, _ in items:
        print(f"  ~{len(tt) // 4}\t{pp}\t({len(tt)}B / 4, UNVERIFIED)", file=sys.stderr)
    sys.exit(3)

client = None
if [i for i in items if i[2] not in cache]:
    try:
        from anthropic import Anthropic
        client = Anthropic()
    except Exception as e:
        no_credential(f"{type(e).__name__}: {str(e)[:150]}")

for p, t, key in items:
    if key in cache:
        continue
    try:
        r = client.messages.count_tokens(model=model, messages=[{"role": "user", "content": t}])
        cache[key] = r.input_tokens
    except Exception as e:
        msg = str(e)
        if "authentication" in msg.lower() or "api_key" in msg.lower() or "401" in msg:
            no_credential(f"{type(e).__name__}: {msg[:150]}")
        print(f"count-tokens: {p}: {type(e).__name__}: {msg[:150]}", file=sys.stderr)
        sys.exit(3)

os.makedirs(".cc-sessions", exist_ok=True)
tmp = CACHE + ".tmp"
with open(tmp, "w") as fh:
    json.dump({"$schema": "blitz-token-counts/1.0", "model": model, "counts": cache}, fh, indent=2)
os.replace(tmp, CACHE)

rows = [{"path": p, "tokens": cache[k], "bytes": len(t),
         "bytes_per_token": round(len(t) / cache[k], 3) if cache[k] else None}
        for p, t, k in items]

if mode == "calibrate":
    tb = sum(r["bytes"] for r in rows); tt = sum(r["tokens"] for r in rows)
    ratio = tb / tt if tt else 0
    if want_json:
        print(json.dumps({"model": model, "bytes": tb, "tokens": tt, "bytes_per_token": round(ratio, 3),
                          "files": rows}, indent=2))
    else:
        print(f"model            {model}")
        print(f"files            {len(rows)}")
        print(f"total bytes      {tb}")
        print(f"total tokens     {tt}")
        print(f"bytes per token  {ratio:.3f}   (the bytes/4 heuristic assumes 4.000)")
        lo = min(r["bytes_per_token"] for r in rows if r["bytes_per_token"])
        hi = max(r["bytes_per_token"] for r in rows if r["bytes_per_token"])
        print(f"range            {lo:.3f} - {hi:.3f}")
        print(f"\nSafe body cap for a 5000-token limit at the WORST observed ratio:"
              f" {int(5000 * lo)} bytes")
elif want_json:
    print(json.dumps(rows, indent=2))
else:
    for r in sorted(rows, key=lambda r: -r["tokens"]):
        print(f'{r["tokens"]}\t{r["path"]}\t({r["bytes_per_token"]} B/tok)')
PY
