#!/usr/bin/env bash
# check-section-refs.sh — assert every "§N" citation resolves in the file it names.
#
# The head/reference split moved sections between files. Three separate rounds of
# breakage survived `markdown-link-validate.sh`, because in every case the LINK
# resolved and only the section citation beside it was wrong:
#   1. ")§44.1" and ")§RatchetRatchet" — a retarget that repeated its capture group
#   2. "agents.md §3" where §3 now lives in agents.reference.md
#   3. markdown links injected into a fenced ASCII tree, where they do not render
#
# Exit 0 clean, 1 on any unresolved citation.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
command -v python3 >/dev/null 2>&1 || { echo "check-section-refs: python3 required" >&2; exit 0; }

python3 - <<'PY'
import re, glob, sys

NAMES = ["loop", "agents", "quality", "sessions", "security", "output"]

def sections(path):
    out = set()
    try:
        fh = open(path)
    except OSError:
        return out
    for l in fh:
        m = re.match(r'^#{2,4} (?:(\d+)\.|([A-Z][^\n]*))', l)
        if m:
            out.add(m.group(1) if m.group(1) else m.group(2).strip().rstrip('.').split('(')[0].strip())
    return out

HEAD = {n: sections(f"skills/_shared/{n}.md") for n in NAMES}
REF  = {n: sections(f"skills/_shared/{n}.reference.md") for n in NAMES}
bad = []

# 1. A citation naming <name>.md whose section lives only in <name>.reference.md.
targets = [f for f in glob.glob("skills/**/*.md", recursive=True)
           + glob.glob("agents/*.md") + glob.glob("workflows/*.js")]
for fp in targets:
    for i, line in enumerate(open(fp).read().split("\n"), 1):
        for m in re.finditer(r'_shared/(' + "|".join(NAMES) + r')\.md\)?[^\n]{0,14}?§\s*(\d+)', line):
            name, n = m.group(1), m.group(2)
            if n not in HEAD[name] and n in REF[name]:
                bad.append(f"{fp}:{i}: cites {name}.md §{n}, but §{n} is in {name}.reference.md")

# 2. A bare "§N" inside a protocol head whose section moved to its reference.
for n_ in NAMES:
    p = f"skills/_shared/{n_}.md"
    for i, line in enumerate(open(p).read().split("\n"), 1):
        for m in re.finditer(r'§\s*(\d+)', line):
            sec = m.group(1)
            if sec in HEAD[n_] or sec not in REF[n_]:
                continue
            after = line[m.end():m.end() + 45]
            before = line[max(0, m.start() - 50):m.start()]
            if "reference.md" in after or "reference.md" in before or "reference " in before[-12:]:
                continue
            bad.append(f"{p}:{i}: bare §{sec} resolves only in {n_}.reference.md")

# 3. A protocol link injected into a fenced block. Narrow on purpose: a fence
# often holds a TEMPLATE of output a skill writes, where markdown links are
# correct and intended (doc-gen's README Contents section, for one). Only a
# link to a _shared protocol is always wrong there, and that is the mistake the
# head/reference retarget actually made, in an ASCII directory tree.
for fp in glob.glob("skills/_shared/*.md"):
    fenced = False
    for i, line in enumerate(open(fp).read().split("\n"), 1):
        if line.startswith("```"):
            fenced = not fenced
            continue
        if fenced and re.search(r'\]\([a-z]+\.(reference\.)?md\)', line):
            bad.append(f"{fp}:{i}: protocol link inside a fenced block does not render; use plain prose")

# 3b. A file linking to itself by its own basename. This arrives whenever a
# section is MOVED between files: the link was correct where it was written and
# resolves to <dir>/<dir>/<file> in its new home. Link checking catches the
# broken path, but only after the move ships, so assert it here too.
for fp in glob.glob("skills/*/references/main.md") + glob.glob("skills/_shared/*.md"):
    base = fp.split("/")[-1]
    parent = fp.split("/")[-2]
    for i, line in enumerate(open(fp).read().split("\n"), 1):
        if re.search(r'\]\(' + re.escape(f"{parent}/{base}") + r'\)', line):
            bad.append(f"{fp}:{i}: links to itself as {parent}/{base}; a moved section kept its old relative path")

# 3c. A relative path inside references/ that still has SKILL.md's depth. A
# moved section's "../../docs/x.md" and "references/y.md" were both correct one
# directory up; neither is here. Link checking finds these, but only for paths
# that happen to miss — this names the pattern.
for fp in glob.glob("skills/*/references/*.md"):
    for i, line in enumerate(open(fp).read().split("\n"), 1):
        if re.search(r'\]\(references/', line):
            bad.append(f"{fp}:{i}: 'references/...' inside references/ — a moved section kept SKILL.md's depth")
        if re.search(r'\]\(\.\./\.\./(docs|skills|agents|hooks|scripts)/', line):
            bad.append(f"{fp}:{i}: '../../' inside references/ reaches skills/, not the repo root — use '../../../'")

# 4. A doubled or unspaced citation, the 3.2.0 retarget signature.
for fp in glob.glob("skills/**/*.md", recursive=True) + glob.glob("agents/*.md"):
    for i, line in enumerate(open(fp).read().split("\n"), 1):
        if re.search(r'\)§', line):
            bad.append(f"{fp}:{i}: ')§' — needs a space before the section")
        if re.search(r'§(\d+)\1(?![0-9])', line):
            bad.append(f"{fp}:{i}: doubled section number")

if bad:
    print(f"check-section-refs: {len(bad)} unresolved citation(s):", file=sys.stderr)
    for b in bad[:40]:
        print(f"  {b}", file=sys.stderr)
    sys.exit(1)
print("check-section-refs: OK")
PY
