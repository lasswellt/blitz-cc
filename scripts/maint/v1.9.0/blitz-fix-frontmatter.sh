#!/usr/bin/env bash
# One-shot fix script: add `effort:` + OUTPUT STYLE snippet to all SKILL.md files
# that need them. Idempotent — re-running is a no-op once compliant.

set -u
BLITZ_ROOT="${BLITZ_ROOT:-/home/tom/development/blitz}"
SNIPPET='OUTPUT STYLE: terse-technical per /_shared/output.md. Drop articles, fillers, pleasantries, hedging. Preserve verbatim: code fences, inline code, URLs, file paths, commands, grep patterns, YAML/JSON, headings, table rows, error codes, dates, version numbers. No preamble. No trailing summary of work already evident in the diff or tool output. Format: fragments OK.'

# Per-skill effort inference (orchestrators=low, single-pass tools=medium, multi-phase=high)
declare -A EFFORT=(
  [ask]=low [next]=low [quick]=low [health]=low [todo]=low
  [sprint]=low [implement]=low [review]=low [ship]=low
  [bootstrap]=medium [research]=high [fix-issue]=medium
  [refactor]=medium [test-gen]=medium [doc-gen]=medium
  [retrospective]=medium [roadmap]=high [setup]=low [compress]=low
  [code-sweep]=high [code-doctor]=high [codebase-audit]=high
  [codebase-map]=medium [completeness-gate]=medium
  [quality-metrics]=medium [integration-check]=medium
  [ui-build]=high [ui-audit]=high [browse]=high
  [perf-profile]=medium [dep-health]=medium [migrate]=high [release]=medium
  [sprint-plan]=high [sprint-dev]=high [sprint-review]=high
)

CHANGED=0
for f in "$BLITZ_ROOT"/skills/*/SKILL.md; do
  name=$(basename "$(dirname "$f")")
  effort="${EFFORT[$name]:-medium}"
  needs_effort=0; needs_snippet=0

  # Check effort presence
  awk '/^---$/{c++;next} c==1 && /^effort:/{found=1;exit} c>=2{exit} END{exit !found}' "$f" \
    || needs_effort=1

  # Check snippet presence in body (after second ---)
  awk '/^---$/{c++;next} c>=2 && /OUTPUT STYLE: (terse-technical|lite|full|ultra) per \/_shared\/terse-output\.md/{found=1;exit} END{exit !found}' "$f" \
    || needs_snippet=1

  [ "$needs_effort" -eq 0 ] && [ "$needs_snippet" -eq 0 ] && continue

  # Build new content
  python3 - "$f" "$effort" "$needs_effort" "$needs_snippet" "$SNIPPET" <<'PY'
import sys, re, pathlib
path = pathlib.Path(sys.argv[1])
effort = sys.argv[2]
need_effort = sys.argv[3] == "1"
need_snippet = sys.argv[4] == "1"
snippet = sys.argv[5]

text = path.read_text()
parts = text.split("---\n", 2)
if len(parts) < 3:
    print(f"  ! skipping {path}: malformed frontmatter", file=sys.stderr)
    sys.exit(0)
_pre, fm, body = parts

# Insert effort: after model: line, or before closing frontmatter
if need_effort:
    if re.search(r'^model:', fm, re.M):
        fm = re.sub(r'(^model:.*$)', r'\1\neffort: ' + effort, fm, count=1, flags=re.M)
    else:
        fm = fm.rstrip("\n") + f"\neffort: {effort}\n"

# Insert OUTPUT STYLE snippet at top of body
if need_snippet:
    # Skip past any leading blank lines and "Project Context" / "Additional Resources" blocks,
    # insert just before the first H1 heading or after Additional Resources block.
    lines = body.split("\n")
    insert_at = None
    in_additional = False
    for i, ln in enumerate(lines):
        if ln.strip().startswith("## Additional Resources"):
            in_additional = True
            continue
        if in_additional and ln.startswith("---"):
            insert_at = i
            break
        if in_additional and ln.startswith("## ") and not ln.startswith("## Additional"):
            insert_at = i
            break
        if ln.startswith("# ") and insert_at is None:
            insert_at = i
            break
    if insert_at is None:
        insert_at = 0
    lines.insert(insert_at, "")
    lines.insert(insert_at + 1, snippet)
    lines.insert(insert_at + 2, "")
    body = "\n".join(lines)

new_text = "---\n" + fm + "---\n" + body
path.write_text(new_text)
print(f"  ✓ {path.name}: effort={'+' if need_effort else '·'} snippet={'+' if need_snippet else '·'}")
PY
  CHANGED=$((CHANGED+1))
done

echo "Updated $CHANGED SKILL.md files."
