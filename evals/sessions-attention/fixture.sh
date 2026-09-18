#!/usr/bin/env bash
# Scaffold: a .cc-sessions dir with one open session record and one PENDING inbox line
# for it (the hook-written shape from hooks/scripts/_lib/common.sh blitz_inbox_append).
set -euo pipefail
git init -q .
mkdir -p .cc-sessions/sessions
cat > .cc-sessions/sessions/sprint-dev-a1b2c3d4.json <<'JSON'
{"session_id":"sprint-dev-a1b2c3d4","skill":"sprint-dev","status":"active","started":"2026-09-18T10:00:00Z","last_heartbeat":"2026-09-18T10:05:00Z","pid":0,"cwd":"."}
JSON
cat > .cc-sessions/inbox.jsonl <<'JSON'
{"ts":"2026-09-18T10:05:00Z","id":"inb-0badf00d","source":"hook","kind":"permission_denied","session":"sprint-dev-a1b2c3d4","text":"Permission denied for Bash(npm publish) — sprint-dev needs an operator decision","status":"pending"}
JSON
cat > .cc-sessions/activity-feed.jsonl <<'JSON'
{"ts":"2026-09-18T10:00:00Z","session":"sprint-dev-a1b2c3d4","skill":"sprint-dev","event":"session_start","message":"sprint 3 implementation","detail":{}}
{"ts":"2026-09-18T10:05:00Z","session":"sprint-dev-a1b2c3d4","skill":"sprint-dev","event":"permission_denied","message":"Bash(npm publish) denied","detail":{}}
JSON
