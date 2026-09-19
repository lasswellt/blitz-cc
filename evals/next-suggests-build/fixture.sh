#!/usr/bin/env bash
# Scaffold: a tiny project with one active plan (docs/plans/demo) holding a single open
# task with an unmet-free dependency list, no inbox, no kill switch — next row 2.
# tasks.json is written through the plugin's scripts/tasks.sh (the only sanctioned writer)
# when the plugin root is discoverable; otherwise the same schema is written verbatim.
set -euo pipefail
git init -q .
git config user.email eval@example.com
git config user.name eval
cat > package.json <<'JSON'
{ "name": "eval-fixture", "version": "0.1.0", "private": true, "scripts": { "test": "echo ok" } }
JSON
mkdir -p docs/plans/demo .cc-sessions src
cat > docs/plans/demo/spec.md <<'MD'
---
status: active
priority: P1
created: 2026-09-18
ship: manual
---
# Health endpoint

Add GET /health returning build info.
MD
printf '# Plan\n\nOne handler in src/health.ts, exported from src/index.ts.\n' > docs/plans/demo/plan.md
printf '# Progress\n' > docs/plans/demo/progress.md
TASKS_SH="${CLAUDE_PLUGIN_ROOT:-}/scripts/tasks.sh"
if [ -x "$TASKS_SH" ]; then
  bash "$TASKS_SH" init demo
  bash "$TASKS_SH" add demo --id T-001 --title "GET /health handler" --role backend \
    --files src/health.ts --origin plan \
    --verify-cmd "test -f src/health.ts::10" \
    --verify-cmd "grep -q 'export function health' src/health.ts::10"
else
  cat > docs/plans/demo/tasks.json <<'JSON'
{
  "$schema": "blitz-tasks/1.0",
  "plan": "demo",
  "updated": "2026-09-18T10:00:00Z",
  "tasks": [
    {
      "id": "T-001",
      "title": "GET /health handler",
      "role": "backend",
      "files": ["src/health.ts"],
      "depends_on": [],
      "verify": [
        { "cmd": "test -f src/health.ts", "timeout": 10 },
        { "cmd": "grep -q 'export function health' src/health.ts", "timeout": 10 }
      ],
      "passes": false,
      "status": "open",
      "blocked_reason": null,
      "attempts": 0,
      "last_verify": { "ts": "", "ok": false, "failed": "", "tail": "" },
      "origin": "plan",
      "notes": ""
    }
  ]
}
JSON
fi
: > .cc-sessions/activity-feed.jsonl
git add -A
git commit -q -m "fixture: one active plan, one open task"
