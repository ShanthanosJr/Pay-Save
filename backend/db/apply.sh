#!/usr/bin/env bash
# Applies pending db/migrations/*.sql in order, tracked in schema_migrations.
# Uses DATABASE_URL with local psql, else `docker compose exec` from the repo root.
set -euo pipefail
cd "$(dirname "$0")"

run_sql() { # stdin: SQL
  if [ -n "${DATABASE_URL:-}" ] && command -v psql >/dev/null 2>&1; then
    psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -qtA -f -
  else
    (cd ../.. && docker compose exec -T postgres psql -U payandsave -d payandsave -v ON_ERROR_STOP=1 -qtA -f -)
  fi
}

run_sql <<'SQL'
CREATE TABLE IF NOT EXISTS schema_migrations (name TEXT PRIMARY KEY, applied_at TIMESTAMPTZ NOT NULL DEFAULT now());
-- databases created before tracking existed already have 0001
INSERT INTO schema_migrations (name)
  SELECT '0001_init.sql' WHERE to_regclass('public.users') IS NOT NULL ON CONFLICT DO NOTHING;
SQL

for f in migrations/*.sql; do
  name=$(basename "$f")
  if [ -n "$(echo "SELECT 1 FROM schema_migrations WHERE name = '$name'" | run_sql)" ]; then
    echo "skip $name"
    continue
  fi
  echo "applying $name"
  run_sql < "$f"
  echo "INSERT INTO schema_migrations (name) VALUES ('$name')" | run_sql
done
