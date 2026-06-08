#!/usr/bin/env bash
# PreToolUse hook on Bash. Blocks destructive SQL fired through CLI tools
# (psql, mysql, sqlite3, mongosh, redis-cli with FLUSHDB/FLUSHALL).
#
# Real incidents:
#  - Cursor + Opus 4.6 deleted Railway production DB volume + backups
#    (https://www.osohq.com/developers/ai-agents-gone-rogue)
#  - Replit Rogue Agent DROP TABLE incident, July 2025
#
# Allows DROP/DELETE/TRUNCATE in migration files (path contains migrations/).
# Containment: environment-layer guard (user-misuse). Canonical posture: /_shared/security.md §2 (env-first).
# Exit 0 = allow, Exit 2 = block.
set -euo pipefail

INPUT="$(cat)"
CMD="$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")"

[[ -z "$CMD" ]] && exit 0

# Only inspect commands that look like DB CLIs
if ! echo "$CMD" | grep -qE '(^|[[:space:];&|])(psql|mysql|sqlite3|mongosh|redis-cli|wrangler[[:space:]]+d1)([[:space:]]|$)'; then
  exit 0
fi

# Migration runs are intentional — skip ONLY when the INVOCATION FORM is a
# migration, not when the string "migrations/" merely appears anywhere.
#
# SEC-R2-02: the old broad match exempted any command containing `migrations/`,
# so an SQL comment `-- migrations/` bypassed the DROP guard entirely. The
# exemption is now scoped to:
#   (a) a migration FILE passed via -f (psql -f db/migrations/001.sql), where
#       the path component contains a migrations/ directory; OR
#   (b) a migration TOOL subcommand at command position (knex migrate:*,
#       prisma migrate *, alembic upgrade, atlas schema, or a bare
#       `migrate up|down|run` runner).
# A path-only match (-f .../migrations/...) cannot be forged inside a SQL
# string passed via -c because -c carries the SQL, not a -f file path.
if echo "$CMD" | grep -qiE '(-f[[:space:]]+[^[:space:]]*migrations?/|(^|[[:space:];&|])migrate[[:space:]]+(up|down|run)([[:space:]]|$)|knex[[:space:]]+migrate|prisma[[:space:]]+migrate|alembic[[:space:]]+upgrade|atlas[[:space:]]+schema)'; then
  exit 0
fi

block() {
  cat >&2 <<EOF
BLOCKED: destructive SQL outside a migration context.

Pattern detected: $1

If this is a real schema change, write a migration file and run it through your
migration tool (knex/prisma/alembic/atlas/etc.). Ad-hoc DROP/DELETE/TRUNCATE on
production data is the autonomous-agent failure mode that has destroyed
production databases (Cursor+Opus / Railway, Replit Rogue Agent).

Override: USER may run the command directly in their own shell.
EOF
  exit 2
}

# DROP TABLE / DROP DATABASE / DROP SCHEMA
if echo "$CMD" | grep -qiE 'DROP[[:space:]]+(TABLE|DATABASE|SCHEMA|INDEX[[:space:]]+CONCURRENTLY)'; then
  block "DROP TABLE/DATABASE/SCHEMA"
fi

# DELETE FROM ... without WHERE (very rough heuristic; blocks the common case)
if echo "$CMD" | grep -qiE 'DELETE[[:space:]]+FROM[[:space:]]+[a-zA-Z_][a-zA-Z0-9_.]*[[:space:]]*(;|$|\")' \
    && ! echo "$CMD" | grep -qiE 'DELETE[[:space:]]+FROM[[:space:]]+[^;]*WHERE'; then
  block "DELETE FROM <table> with no WHERE clause"
fi

# TRUNCATE
if echo "$CMD" | grep -qiE 'TRUNCATE[[:space:]]+(TABLE[[:space:]]+)?[a-zA-Z_]'; then
  block "TRUNCATE"
fi

# Redis FLUSHDB / FLUSHALL
if echo "$CMD" | grep -qiE '(^|[[:space:]"'\''])(FLUSHDB|FLUSHALL)([[:space:]"'\'']|$)'; then
  block "FLUSHDB/FLUSHALL"
fi

# MongoDB drop / dropDatabase
if echo "$CMD" | grep -qE '\.drop(Database)?\(\)'; then
  block "Mongo .drop()/.dropDatabase()"
fi

exit 0
