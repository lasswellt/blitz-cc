#!/usr/bin/env bash
# test-selector.sh — pick the test files impacted by a set of changed files (E-043 S2).
#
# Usage: test-selector.sh [--base <git-ref>] [--full] [--json] [files...]
#   files: args, or stdin one per line; when neither is given, uses
#          `git diff --name-only <base>..HEAD` + staged + unstaged changes.
#   Output: `<test-file>\t<reasons>` per line (reasons: sibling, graph,
#           recent-fail, co-change, full — comma-joined when several apply).
#   --json: {"mode","changed","selected":[{file,reasons}],"total_test_files",
#            "selection_ratio","graph","full_reason"}
#
# Sources (union):
#   1. sibling  — <name>.test.<ext> / <name>.spec.<ext> / __tests__/<name>.<ext>
#                 (moved here from hooks/scripts/post-edit-test.sh)
#   2. graph    — reverse import closure changed -> test files. Vitest: static
#                 python3 resolver (relative imports + tsconfig `paths` + Nuxt
#                 `~/`, `@/`, `~~/`, `@@/`); `vitest list` cannot take an
#                 arbitrary file list without executing (only --changed <git-ref>),
#                 so the static graph is preferred for determinism.
#                 Jest: `npx jest --findRelatedTests --listTests <files>`.
#   3. recent-fail — journal: test files that failed in the last 5 runs
#   4. co-change   — journal: test files that failed in any run whose `changed`
#                    intersects the current changed set
# --full (or auto-full): every test file, tagged `full`. Auto-full when the
# changed set touches package.json / lockfiles / vitest|vite|jest config /
# tsconfig* / test setup files, exceeds 40 files, or meta.json
# escaped_failures_recent has a non-zero entry in the last 3 sprint-review runs.
# Cold start (no journal) -> sibling + graph only. Never fails: on any error the
# --full set is printed and a note goes to stderr.
# Dependencies: bash, python3, git (optional), npx (jest graph only).
set -uo pipefail

BASE="${SPRINT_BASE:-HEAD}" FULL=0 JSON=0
FILES=()
while [ $# -gt 0 ]; do
  case "$1" in
    --base) BASE="${2:-HEAD}"; shift ;;
    --full) FULL=1 ;;
    --json) JSON=1 ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    --) shift; while [ $# -gt 0 ]; do FILES+=("$1"); shift; done; break ;;
    *) FILES+=("$1") ;;
  esac
  shift
done

ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
SESSIONS_DIR="${SESSIONS_DIR:-$ROOT/.cc-sessions}"
CWD=$(pwd)

# stdin is consulted only when it is a pipe or a file (an inherited, open-but-idle
# stdin under a hook harness must not block the selector).
if [ ${#FILES[@]} -eq 0 ] && [ "$FULL" -eq 0 ] && { [ -p /dev/stdin ] || [ -f /dev/stdin ]; }; then
  while IFS= read -r line; do [ -n "$line" ] && FILES+=("$line"); done
fi
if [ ${#FILES[@]} -eq 0 ] && [ "$FULL" -eq 0 ]; then
  while IFS= read -r line; do [ -n "$line" ] && FILES+=("$ROOT/$line"); done < <(
    { git -C "$ROOT" diff --name-only "$BASE..HEAD" 2>/dev/null
      git -C "$ROOT" diff --name-only 2>/dev/null
      git -C "$ROOT" diff --name-only --cached 2>/dev/null; } | sort -u)
fi

# Fallback: full test-file set via find (used when the resolver itself errors).
full_fallback() {
  ( cd "$ROOT" && find . -type d \( -name node_modules -o -name .git -o -name dist -o -name .nuxt -o -name .output -o -name coverage \) -prune -o \
      -type f \( -regex '.*\.\(test\|spec\)\.\(ts\|tsx\|js\|jsx\|mts\|mjs\|cts\|cjs\)$' -o -path '*/__tests__/*' \) -print \
      | sed 's#^\./##' | sort -u | sed 's/$/\tfull/' )
}

OUT=$(python3 - "$ROOT" "$CWD" "$SESSIONS_DIR" "$FULL" "$JSON" "${FILES[@]+"${FILES[@]}"}" <<'PY'
import sys, os, re, json, glob, subprocess
root, cwd, sessions_dir, full_flag, json_flag = sys.argv[1:6]
files_in = sys.argv[6:]
root = os.path.realpath(root); full_flag = full_flag == "1"; json_flag = json_flag == "1"
SKIP_DIRS = {"node_modules", ".git", "dist", ".nuxt", ".output", "coverage", ".cc-sessions", ".claude"}
SRC_EXT = (".ts", ".tsx", ".mts", ".cts", ".js", ".jsx", ".mjs", ".cjs", ".vue")
TEST_RX = re.compile(r"(\.(test|spec)\.(ts|tsx|js|jsx|mts|mjs|cts|cjs)$)|(^|/)__tests__/[^/]+\.(ts|tsx|js|jsx|mts|mjs|cts|cjs)$")
FULL_RX = re.compile(r"(^|/)(package\.json|package-lock\.json|pnpm-lock\.yaml|yarn\.lock|bun\.lockb?|"
                     r"vitest[^/]*\.config[^/]*|vite\.config[^/]*|jest\.config[^/]*|tsconfig[^/]*\.json|"
                     r"setupTests\.[^/]+|vitest\.setup\.[^/]+|jest\.setup\.[^/]+|(test|tests|__tests__)/setup\.[^/]+)$")
notes = []

def rel(p):
    ap = p if os.path.isabs(p) else os.path.join(cwd, p)
    ap = os.path.realpath(ap)
    return os.path.relpath(ap, root) if ap.startswith(root + os.sep) or ap == root else p

changed = sorted({rel(f) for f in files_in if f.strip()})

# --- all source + test files ------------------------------------------------
all_files = []
for dp, dns, fns in os.walk(root):
    dns[:] = [d for d in dns if d not in SKIP_DIRS]
    for fn in fns:
        if fn.endswith(SRC_EXT):
            all_files.append(os.path.relpath(os.path.join(dp, fn), root))
all_set = set(all_files)
test_files = sorted(f for f in all_files if TEST_RX.search(f))
is_test = lambda f: bool(TEST_RX.search(f))

# --- runner detection --------------------------------------------------------
runner = None
try:
    pkg = json.load(open(os.path.join(root, "package.json")))
    deps = {**pkg.get("dependencies", {}), **pkg.get("devDependencies", {})}
    runner = "vitest" if "vitest" in deps else ("jest" if "jest" in deps else None)
except Exception:
    pass

# --- full triggers -----------------------------------------------------------
full_reason = "flag" if full_flag else None
if not full_reason and any(FULL_RX.search(c) for c in changed):
    full_reason = "config/lockfile/setup change"
if not full_reason and len(changed) > 40:
    full_reason = f"{len(changed)} changed files (>40)"
meta = {}
try:
    meta = json.load(open(os.path.join(sessions_dir, "test-journal.meta.json")))
except Exception:
    pass
def _esc(e):
    if isinstance(e, dict):
        return int(e.get("count", e.get("escaped_failures", 0)) or 0)
    try: return int(e)
    except Exception: return 0
recent_esc = [_esc(e) for e in (meta.get("escaped_failures_recent") or [])[-3:]]
if not full_reason and any(recent_esc):
    full_reason = "escaped failures in last 3 sprint-review runs"

selected = {}  # file -> [reasons]
def add(f, why):
    if f in all_set or os.path.isfile(os.path.join(root, f)):
        selected.setdefault(f, [])
        if why not in selected[f]: selected[f].append(why)

if full_reason:
    for t in test_files: add(t, "full")
else:
    # 1. sibling
    for c in changed:
        if is_test(c):
            add(c, "sibling"); continue
        d, b = os.path.split(c); stem = b.rsplit(".", 1)[0] if "." in b else b
        for ext in ("ts", "tsx", "js", "jsx", "mts", "mjs"):
            for cand in (f"{stem}.test.{ext}", f"{stem}.spec.{ext}", f"__tests__/{stem}.{ext}",
                         f"__tests__/{stem}.test.{ext}", f"__tests__/{stem}.spec.{ext}"):
                p = os.path.normpath(os.path.join(d, cand))
                if p in all_set: add(p, "sibling")
    # 2. graph
    graph_mode = "unavailable"
    src_changed = [c for c in changed if c.endswith(SRC_EXT)]
    if runner == "jest" and src_changed:
        try:
            r = subprocess.run(["npx", "jest", "--findRelatedTests", "--listTests", *src_changed],
                               cwd=root, capture_output=True, text=True, timeout=60)
            if r.returncode == 0:
                for line in r.stdout.splitlines():
                    line = line.strip()
                    if line: add(rel(line), "graph")
                graph_mode = "jest"
            else:
                notes.append("graph: jest --listTests failed; falling back to static graph")
        except Exception as e:
            notes.append(f"graph: jest unavailable ({e.__class__.__name__}); falling back to static graph")
    if graph_mode == "unavailable" and src_changed:
        # static import-graph resolver
        aliases = {}
        src_dir = "src" if os.path.isdir(os.path.join(root, "src")) else "."
        for a in ("~/", "@/"): aliases[a] = src_dir
        for a in ("~~/", "@@/"): aliases[a] = "."
        for tc in ("tsconfig.json", "jsconfig.json"):
            tp = os.path.join(root, tc)
            if not os.path.isfile(tp): continue
            try:
                txt = open(tp, encoding="utf-8", errors="replace").read()
                txt = re.sub(r"/\*.*?\*/", "", txt, flags=re.S)
                txt = re.sub(r"^\s*//.*$", "", txt, flags=re.M)
                txt = re.sub(r",(\s*[}\]])", r"\1", txt)
                co = json.loads(txt).get("compilerOptions", {})
                base = co.get("baseUrl", ".")
                for k, v in (co.get("paths") or {}).items():
                    if not v: continue
                    aliases[k.replace("*", "")] = os.path.normpath(os.path.join(base, v[0].replace("*", "")))
            except Exception:
                notes.append(f"graph: could not parse {tc} paths; using default aliases")
        IMPORT_RX = re.compile(r"""(?:\bimport\s*(?:[\w*{}\s,$]+\s*from\s*)?|\bexport\s*[\w*{}\s,$]+\s*from\s*|\brequire\s*\(\s*|\bimport\s*\(\s*)['"]([^'"\n]+)['"]""")
        EXTS = ["", ".ts", ".tsx", ".mts", ".cts", ".js", ".jsx", ".mjs", ".cjs", ".vue", ".d.ts"]
        def resolve(spec, frm):
            if spec.startswith("."):
                cand = os.path.normpath(os.path.join(os.path.dirname(frm), spec))
            else:
                hit = next((a for a in sorted(aliases, key=len, reverse=True) if spec.startswith(a)), None)
                if hit is None: return None
                cand = os.path.normpath(os.path.join(aliases[hit], spec[len(hit):]))
            for e in EXTS:
                if cand + e in all_set: return cand + e
            for e in EXTS[1:]:
                if os.path.join(cand, "index" + e) in all_set: return os.path.join(cand, "index" + e)
            return None
        rev = {}  # imported -> {importers}
        for f in all_files:
            try:
                txt = open(os.path.join(root, f), encoding="utf-8", errors="replace").read()
            except Exception:
                continue
            for spec in IMPORT_RX.findall(txt):
                tgt = resolve(spec, f)
                if tgt and tgt != f: rev.setdefault(tgt, set()).add(f)
        seen = set(); stack = [c for c in src_changed if c in all_set]
        while stack:
            cur = stack.pop()
            for imp in rev.get(cur, ()):
                if imp in seen: continue
                seen.add(imp)
                if is_test(imp): add(imp, "graph")
                stack.append(imp)
        graph_mode = "static"
    if graph_mode == "unavailable" and src_changed:
        sys.stderr.write("graph: unavailable\n")
    # 3 + 4. journal
    jpath = os.path.join(sessions_dir, "test-journal.jsonl")
    if os.path.isfile(jpath):
        rows = []
        for line in open(jpath, encoding="utf-8", errors="replace"):
            try: rows.append(json.loads(line))
            except Exception: pass
        run_order = []
        for r in rows:
            rid = r.get("run_id")
            if rid and rid not in run_order: run_order.append(rid)
        last5 = set(run_order[-5:])
        cset = set(changed)
        for r in rows:
            if r.get("result") != "fail": continue
            tf = r.get("test_file", "")
            if r.get("run_id") in last5: add(tf, "recent-fail")
            if cset.intersection(r.get("changed") or []): add(tf, "co-change")
    else:
        notes.append("journal: none (cold start) — sibling + graph only")

for n in notes: sys.stderr.write(n + "\n")
sel = sorted(selected)
if json_flag:
    print(json.dumps({"mode": "full" if full_reason else "selected", "full_reason": full_reason,
        "changed": changed, "selected": [{"file": f, "reasons": selected[f]} for f in sel],
        "total_test_files": len(test_files),
        "selection_ratio": (round(len(sel) / len(test_files), 3) if test_files else 0.0),
        "graph": (None if full_reason else globals().get("graph_mode")), "runner": runner}))
else:
    for f in sel: print(f + "\t" + ",".join(selected[f]))
PY
) ; RC=$?
if [ "$RC" -ne 0 ]; then
  echo "test-selector: resolver error (exit $RC); falling back to --full set" >&2
  full_fallback
  exit 0
fi
[ -n "$OUT" ] && printf '%s\n' "$OUT"
exit 0
