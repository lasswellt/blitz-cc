#!/usr/bin/env python3
"""
S1-004 batch edit — append a terse-output.md reference to the Additional
Resources block of every SKILL.md that has one. Idempotent: safe to re-run.

Usage: python3 scripts/add-terse-output-reference.py [--check]

--check : exit 0 if all files already have the reference, else exit 1. No writes.

MISS files (no Additional Resources section) are intentionally exempt — these
are thin orchestrators (ask, sprint, implement, review, ship) and lightweight
utilities (todo, health, quick, next, bootstrap, code-sweep, refactor) that
either route to other skills or produce minimal narrative output.
"""
from __future__ import annotations
import sys
import pathlib

LINE = "- For output style (terse-technical, preservation rules), see [/_shared/output.md](/_shared/output.md)"
ANCHOR = "## Additional Resources"

def process(path: pathlib.Path, check: bool) -> str:
    text = path.read_text()
    if "terse-output.md" in text:
        return "skip"
    if ANCHOR not in text:
        return "miss"
    if check:
        return "needs-edit"

    # Find the Additional Resources section and the end of its bullet list.
    lines = text.splitlines(keepends=True)
    out = []
    i = 0
    inserted = False
    while i < len(lines):
        out.append(lines[i])
        if lines[i].startswith(ANCHOR) and not inserted:
            # Copy bullets until a non-bullet line (blank or new heading).
            i += 1
            while i < len(lines) and (lines[i].startswith("- ") or lines[i].strip() == ""):
                # Write bullets through, but insert our line just before the first blank
                if lines[i].strip() == "":
                    out.append(LINE + "\n")
                    inserted = True
                    out.append(lines[i])
                    i += 1
                    break
                out.append(lines[i])
                i += 1
            continue
        i += 1

    if not inserted:
        return "no-anchor-end"

    path.write_text("".join(out))
    return "edited"

def main() -> int:
    check = "--check" in sys.argv
    root = pathlib.Path("skills")
    results: dict[str, list[str]] = {"edited": [], "skip": [], "miss": [], "needs-edit": [], "no-anchor-end": []}
    for skill_md in sorted(root.glob("*/SKILL.md")):
        status = process(skill_md, check)
        results[status].append(str(skill_md))
    for status, paths in results.items():
        if paths:
            print(f"[{status}] {len(paths)}")
            for p in paths:
                print(f"  {p}")
    if check and results["needs-edit"]:
        return 1
    return 0

if __name__ == "__main__":
    sys.exit(main())
