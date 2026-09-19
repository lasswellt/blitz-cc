#!/usr/bin/env bash
# Scaffold: a two-file TypeScript-free node project with no docs/plans/. A one-sentence
# change that touches one file must take build's inline path (no plan, no dev agent).
set -euo pipefail
git init -q .
git config user.email eval@example.com
git config user.name eval
cat > package.json <<'JSON'
{ "name": "eval-fixture", "version": "0.1.0", "private": true,
  "scripts": { "test": "node --test", "type-check": "echo 'no tsc in fixture'" } }
JSON
mkdir -p src .cc-sessions
cat > src/greet.js <<'JS'
export function greet(name) {
  return 'Hello, ' + name;
}
JS
cat > src/greet.test.js <<'JS'
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { greet } from './greet.js';
test('greet', () => { assert.equal(greet('Ada'), 'Hello, Ada'); });
JS
: > .cc-sessions/activity-feed.jsonl
git add -A
git commit -q -m "fixture: greet"
