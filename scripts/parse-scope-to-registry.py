#!/usr/bin/env python3
"""Parse scope: YAML from research doc frontmatter and emit carry-forward.jsonl lines."""
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path


def extract_frontmatter(path: Path) -> str:
    text = path.read_text()
    m = re.match(r"^---\n(.*?)\n---\n", text, re.DOTALL)
    return m.group(1) if m else ""


def parse_scope_entries(fm: str) -> list[dict]:
    if "scope:" not in fm:
        return []
    lines = fm.splitlines()
    i = next((j for j, l in enumerate(lines) if l.strip() == "scope:"), -1)
    if i < 0:
        return []
    entries = []
    cur = None
    j = i + 1
    while j < len(lines):
        line = lines[j]
        if not line.startswith("  "):
            break
        stripped = line.rstrip()
        if stripped.startswith("  - id:"):
            if cur:
                entries.append(cur)
            cur = {"id": stripped.split(":", 1)[1].strip(), "_raw": [stripped]}
        elif cur is not None:
            cur["_raw"].append(stripped)
        j += 1
    if cur:
        entries.append(cur)
    for e in entries:
        raw = "\n".join(e["_raw"])
        mu = re.search(r"^    unit:\s*(\S+)", raw, re.M)
        mt = re.search(r"^    target:\s*(\d+)", raw, re.M)
        md = re.search(r"^    description:\s*\|\n((?:      .*\n?)+)", raw, re.M)
        ma = re.search(r"^    acceptance:\n((?:      .*\n?)+)", raw, re.M)
        e["unit"] = mu.group(1) if mu else "files"
        e["target"] = int(mt.group(1)) if mt else 0
        e["description"] = (
            re.sub(r"^      ", "", md.group(1), flags=re.M).strip() if md else ""
        )
        e["acceptance_raw"] = ma.group(1) if ma else ""
        del e["_raw"]
    return entries


def parse_acceptance(raw: str) -> list:
    results = []
    for line in raw.splitlines():
        s = line.strip()
        if s.startswith("- shell:"):
            results.append({"shell": s.split(":", 1)[1].strip().strip('"').strip("'")})
        elif s.startswith("- grep_absent:"):
            val = s.split(":", 1)[1].strip().strip('"').strip("'")
            results.append({"grep_absent": val})
        elif s.startswith("- grep_present:"):
            results.append({"grep_present_block": True})
        elif s.startswith("pattern:") and results and "grep_present_block" in results[-1]:
            results[-1]["pattern"] = s.split(":", 1)[1].strip().strip('"').strip("'")
        elif s.startswith("min:") and results and "grep_present_block" in results[-1]:
            results[-1]["min"] = int(s.split(":", 1)[1].strip())
    out = []
    for r in results:
        if "grep_present_block" in r:
            out.append({"grep_present": {"pattern": r.get("pattern", ""), "min": r.get("min", 1)}})
        else:
            out.append(r)
    return out


def existing_ids(path: Path) -> set:
    """Collect ids already present in the append-only registry (dedup guard)."""
    ids = set()
    if not path.exists():
        return ids
    for raw in path.read_text().splitlines():
        raw = raw.strip()
        if not raw:
            continue
        try:
            obj = json.loads(raw)
        except json.JSONDecodeError:
            continue
        rid = obj.get("id")
        if rid is not None:
            ids.add(rid)
    return ids


def main():
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    registry = Path(".cc-sessions/carry-forward.jsonl")
    # Append-only contract (sprint-contracts.md:38): never truncate. Dedup new
    # entry ids against ids already on disk — roadmap extend-mode hard-fails on
    # duplicate ids, so we skip (do not re-emit) any id that already exists.
    seen = existing_ids(registry)
    all_lines = []
    activity_lines = []
    session = sys.argv[1] if len(sys.argv) > 1 else "cli-unknown"
    for doc_path in sys.argv[2:]:
        p = Path(doc_path)
        fm = extract_frontmatter(p)
        entries = parse_scope_entries(fm)
        for e in entries:
            if e["id"] in seen:
                continue  # already in registry — skip (append-only, no dup ids)
            seen.add(e["id"])
            acc = parse_acceptance(e["acceptance_raw"])
            line = {
                "id": e["id"],
                "ts": ts,
                "event": "created",
                "source": {"doc": str(p), "anchor": "#scope"},
                "parent": {"capability": None, "epic": None},
                "scope": {
                    "unit": e["unit"],
                    "target": e["target"],
                    "description": e["description"],
                    "acceptance": acc,
                },
                "delivered": {"unit": e["unit"], "actual": 0, "last_sprint": None},
                "coverage": 0.0,
                "status": "active",
                "last_touched": {"sprint": None, "date": ts},
                "rollover_count": 0,
                "notes": "Created by roadmap full-mode Phase 1.1.5",
            }
            all_lines.append(json.dumps(line))
            activity_lines.append(
                json.dumps(
                    {
                        "ts": ts,
                        "session": session,
                        "skill": "roadmap",
                        "event": "registry_write",
                        "message": f"Ingested scope entry {e['id']} from {p}",
                        "detail": {"registry_id": e["id"], "unit": e["unit"], "target": e["target"]},
                    }
                )
            )
    registry.parent.mkdir(parents=True, exist_ok=True)
    # Append only the new lines; never truncate the append-only registry.
    if all_lines:
        with open(registry, "a") as f:
            f.write("\n".join(all_lines) + "\n")
    if activity_lines:
        with open(".cc-sessions/activity-feed.jsonl", "a") as f:
            f.write("\n".join(activity_lines) + "\n")
    print(f"wrote {len(all_lines)} registry entries")


if __name__ == "__main__":
    main()
