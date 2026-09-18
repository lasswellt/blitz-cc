#!/usr/bin/env bash
# Scaffold: a tiny project with a roadmap + epic registry (one planned, unblocked epic),
# an empty session dir, and NO sprint-registry.json / sprints/ — decision-tree row 6c.
set -euo pipefail
git init -q .
git config user.email eval@example.com
git config user.name eval
cat > package.json <<'JSON'
{ "name": "eval-fixture", "version": "0.1.0", "private": true, "scripts": { "test": "echo ok" } }
JSON
cat > roadmap-registry.json <<'JSON'
{
  "generated": "2026-09-01T00:00:00Z",
  "phases": 1,
  "epics": 1,
  "estimated_stories": 3,
  "critical_path_length": 1,
  "phase_summary": [ { "phase": 1, "name": "Foundation", "epic_count": 1, "story_estimate": 3, "status": "planned" } ]
}
JSON
cat > epic-registry.json <<'JSON'
{
  "epics": [
    {
      "id": "E001",
      "title": "Health endpoint",
      "phase": 1,
      "domain": "backend",
      "status": "planned",
      "depends_on": [],
      "estimated_stories": 3,
      "source_research_doc": "docs/_research/2026-09-01_health-endpoint.md",
      "registry_entries": [],
      "acceptance_criteria_count": 0,
      "acceptance_criteria_met": 0,
      "acceptance_criteria_waived": 0,
      "coverage": 0.0,
      "carry_forward_count": 0
    }
  ],
  "dependency_graph": { "E001": [] },
  "phases": { "1": { "name": "Foundation", "epics": ["E001"], "status": "planned" } }
}
JSON
mkdir -p .cc-sessions docs/_research
printf '# Health endpoint\n\nAdd GET /health returning build info.\n' > docs/_research/2026-09-01_health-endpoint.md
: > .cc-sessions/activity-feed.jsonl
git add -A
git commit -q -m "fixture: roadmap, no sprints"
