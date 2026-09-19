#!/usr/bin/env bash
# Scaffold: an active plan whose single task has a verify[] that cannot pass (the handler
# file is missing) and status open. `check --scope plan demo` must run tasks.sh verify,
# report the failed task as a finding, and end with a FAIL verdict — never mark it done.
set -euo pipefail
git init -q .
git config user.email eval@example.com
git config user.name eval
cat > package.json <<'JSON'
{ "name": "eval-fixture", "version": "0.1.0", "private": true,
  "scripts": { "test": "echo 'no tests'", "type-check": "echo ok", "lint": "echo ok", "build": "echo ok" } }
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
printf '# Plan\n\nOne handler in src/health.ts.\n' > docs/plans/demo/plan.md
printf '# Progress\n' > docs/plans/demo/progress.md
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
      "attempts": 1,
      "last_verify": { "ts": "2026-09-18T10:00:00Z", "ok": false, "failed": "test -f src/health.ts", "tail": "" },
      "origin": "plan",
      "notes": ""
    }
  ]
}
JSON
: > .cc-sessions/activity-feed.jsonl
git add -A
git commit -q -m "fixture: plan with an unverifiable task"
