#!/usr/bin/env bash
# markdown-link-validate.sh — warn on broken relative .md links.
#
# Dual-mode:
#   - With hook JSON on stdin (PreToolUse/Bash): only fires on `git commit`,
#     warns on broken links but exits 0 (commit-allowed).
#   - Without JSON on stdin: scans the whole skills/ tree, exits 1 on any
#     broken link (CI / manual verification mode).
#
# Skips: fenced code blocks, inline code, http(s) URLs, anchor-only refs,
# /_shared plugin-absolute links, .original backups, _research/ docs.
#
# Why a script and not a hook-only script: the same checker can be invoked
# manually (`bash hooks/scripts/markdown-link-validate.sh`) or wired into
# pre-commit-validate.sh as a non-blocking warn.

set -euo pipefail

HOOK_MODE=0
if [[ ! -t 0 ]]; then
  INPUT="$(cat || true)"
  if [[ -n "$INPUT" ]] && echo "$INPUT" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
    HOOK_MODE=1
    COMMAND=$(echo "$INPUT" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(data.get('tool_input', {}).get('command', ''))
" 2>/dev/null || true)
    if [[ "$COMMAND" != *"git commit"* ]]; then
      exit 0
    fi
  fi
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

python3 - <<'PY'
import pathlib, re, sys
broken = []
checked = 0
for f in pathlib.Path("skills").rglob("*.md"):
    if ".original" in f.name or "_research" in str(f): continue
    text = f.read_text(errors="replace")
    text = re.sub(r'```.*?```', '', text, flags=re.S)
    text = re.sub(r'`[^`]+`', '', text)
    for m in re.finditer(r'\[([^\]]+)\]\(((?!http|#|/_shared|mailto)[^)#]+\.md)(#[^)]+)?\)', text):
        link = m.group(2)
        target = (f.parent / link).resolve()
        checked += 1
        if not target.exists():
            broken.append((str(f), link))

if broken:
    print(f"markdown-link-validate: {len(broken)} broken link(s) across {checked} checked", file=sys.stderr)
    for f, link in broken:
        print(f"  {f}  →  {link}", file=sys.stderr)
    sys.exit(1)

# Stay quiet in hook mode; report when invoked manually.
import os
if os.environ.get("HOOK_MODE") != "1":
    print(f"markdown-link-validate: OK ({checked} link(s) checked)")
sys.exit(0)
PY
PY_EXIT=$?

if [[ "$HOOK_MODE" -eq 1 ]]; then
  # Warn-only in hook mode — never block a commit on link rot
  exit 0
fi

exit "$PY_EXIT"
