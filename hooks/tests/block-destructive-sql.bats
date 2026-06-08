#!/usr/bin/env bats
# Tests for hooks/scripts/block-destructive-sql.sh (PreToolUse on Bash)
# Blocks destructive SQL through DB CLIs (psql/mysql/sqlite3/mongosh/redis-cli);
# exempts genuine migration invocations (-f .../migrations/..., knex/prisma/etc).

load '_helpers'

@test "blocks psql -c DROP TABLE" {
  assert_blocks "block-destructive-sql.sh" \
    "$(fake_tool_input 'psql -c "DROP TABLE x"')"
}

@test "blocks DROP behind a -- migrations/ SQL comment (SEC-R2-02)" {
  # The exemption must be scoped to a real migration FORM; a `-- migrations/`
  # comment inside the SQL string must NOT exempt the DROP.
  assert_blocks "block-destructive-sql.sh" \
    "$(fake_tool_input 'psql -c "DROP TABLE y; -- migrations/"')"
}

@test "blocks TRUNCATE" {
  assert_blocks "block-destructive-sql.sh" \
    "$(fake_tool_input 'psql -c "TRUNCATE TABLE users"')"
}

@test "allows knex migrate:up (migration tool subcommand)" {
  assert_allows "block-destructive-sql.sh" \
    "$(fake_tool_input 'knex migrate:up')"
}

@test "allows psql -f db/migrations/001.sql (migration file)" {
  assert_allows "block-destructive-sql.sh" \
    "$(fake_tool_input 'psql -f db/migrations/001.sql')"
}

@test "allows non-DB-CLI commands" {
  assert_allows "block-destructive-sql.sh" "$(fake_tool_input 'npm run db:seed')"
}
