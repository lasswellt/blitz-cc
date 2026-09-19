#!/usr/bin/env bash
# Scaffold: a .cc-sessions dir with one open session record and one PENDING inbox line
# for it (the hook-written shape from hooks/scripts/_lib/common.sh blitz_inbox_append).
set -euo pipefail
git init -q .
mkdir -p .cc-sessions/sessions
cat > .cc-sessions/sessions/build-a1b2c3d4.json <<'JSON'
{"session_id":"build-a1b2c3d4","skill":"build","status":"active","started":"2026-09-18T10:00:00Z","last_heartbeat":"2026-09-18T10:05:00Z","pid":0,"cwd":"."}
JSON
cat > .cc-sessions/inbox.jsonl <<'JSON'
{"ts":"2026-09-18T10:05:00Z","id":"inb-0badf00d","source":"hook","kind":"permission_denied","session":"build-a1b2c3d4","text":"Permission denied for Bash(npm publish) — build needs an operator decision","status":"pending"}
JSON
cat > .cc-sessions/activity-feed.jsonl <<'JSON'
{"ts":"2026-09-18T10:00:00Z","session":"build-a1b2c3d4","skill":"build","event":"session_start","message":"build demo T-001","detail":{}}
{"ts":"2026-09-18T10:05:00Z","session":"build-a1b2c3d4","skill":"build","event":"permission_denied","message":"Bash(npm publish) denied","detail":{}}
JSON
