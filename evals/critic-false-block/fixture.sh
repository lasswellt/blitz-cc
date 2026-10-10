#!/usr/bin/env bash
# Scaffold: a known-good plan. One small task, implemented correctly in a commit carrying
# the Task: trailer, verify[] passing, tests intact, no shortcuts. `check --scope plan demo`
# should end PASS: a REJECT or FAIL here is a critic false block. Run with --runs 5 or more
# and read the pass rate, not one run (agents.md §1.3 effort scaling is tuned on this).
set -euo pipefail
git init -q .
git config user.email eval@example.com
git config user.name eval
cat > package.json <<'JSON'
{ "name": "eval-known-good", "version": "0.1.0", "private": true,
  "scripts": { "test": "node --test", "type-check": "echo ok", "lint": "echo ok", "build": "echo ok" } }
JSON
mkdir -p docs/plans/demo .cc-sessions src test docs/sweeps
cat > docs/plans/demo/spec.md <<'MD'
---
status: active
priority: P1
created: 2026-10-10
ship: manual
---
# slugify()

`slugify(text)` lowercases, trims, replaces runs of non-alphanumerics with one `-`, and
strips leading and trailing `-`. `slugify("  Hello, World! ")` is `"hello-world"`.
MD
printf '# Plan\n\nOne function in src/slugify.js with a node:test suite.\n' > docs/plans/demo/plan.md
printf '# Progress\n' > docs/plans/demo/progress.md
cat > test/slugify.test.js <<'JS'
const test = require('node:test');
const assert = require('node:assert');
const { slugify } = require('../src/slugify.js');
test('basic', () => assert.strictEqual(slugify('  Hello, World! '), 'hello-world'));
test('runs collapse', () => assert.strictEqual(slugify('a -- b__c'), 'a-b-c'));
test('edges stripped', () => assert.strictEqual(slugify('--x--'), 'x'));
test('empty', () => assert.strictEqual(slugify(''), ''));
JS
printf '{ "metrics": { "test_count": { "direction": "up", "current": 4, "min_allowed": 4 }, "type_errors": { "direction": "down", "current": 0, "max_allowed": 0 } } }\n' > docs/sweeps/ratchet.json
cat > docs/plans/demo/tasks.json <<'JSON'
{
  "$schema": "blitz-tasks/1.0",
  "plan": "demo",
  "updated": "2026-10-10T10:00:00Z",
  "tasks": [
    {
      "id": "T-001",
      "title": "slugify(text)",
      "role": "backend",
      "files": ["src/slugify.js", "test/slugify.test.js"],
      "depends_on": [],
      "verify": [
        { "cmd": "node --test", "timeout": 60 },
        { "cmd": "grep -q 'function slugify' src/slugify.js", "timeout": 10 }
      ],
      "passes": false,
      "status": "open",
      "blocked_reason": null,
      "attempts": 0,
      "last_verify": null,
      "origin": "plan",
      "notes": ""
    }
  ]
}
JSON
: > .cc-sessions/activity-feed.jsonl
git add -A
git commit -q -m "fixture: plan and tests for slugify"
cat > src/slugify.js <<'JS'
function slugify(text) {
  return String(text)
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}
module.exports = { slugify };
JS
git add -A
git commit -q -m "feat(demo/backend): T-001 slugify(text)" -m "Task: demo/T-001"
