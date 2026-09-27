#!/usr/bin/env bash
# Rejoue les migrations sur un PostgreSQL local (hors Supabase) puis les scénarios de test.
# Usage : PGURL=postgres://postgres@localhost:5432/postgres ./supabase/tests/run.sh
set -euo pipefail
PGURL=${PGURL:-postgres://postgres@localhost:5432/postgres}
DB=veriion_test
psql "$PGURL" -qc "drop database if exists $DB" -c "create database $DB"
TEST_URL="${PGURL%/*}/$DB"
for f in supabase/tests/00_supabase_stub.sql supabase/migrations/*.sql supabase/seed.sql; do
  psql "$TEST_URL" -v ON_ERROR_STOP=1 -q -f "$f" >/dev/null
done
echo "✔ Migrations appliquées"
psql "$TEST_URL" -v ON_ERROR_STOP=1 -q -f supabase/tests/10_permissions_scenario.sql | grep -E "NOTICE|ERREUR" || true
psql "$PGURL" -qc "drop database if exists $DB" -c "create database $DB" >/dev/null
for f in supabase/tests/00_supabase_stub.sql supabase/migrations/*.sql supabase/seed.sql; do
  psql "$TEST_URL" -v ON_ERROR_STOP=1 -q -f "$f" >/dev/null
done
psql "$TEST_URL" -v ON_ERROR_STOP=1 -q -f supabase/tests/20_insert_returning.sql >/dev/null && echo "✔ Scénarios d'écriture OK"
psql "$PGURL" -qc "drop database if exists $DB" -c "create database $DB" >/dev/null
for f in supabase/tests/00_supabase_stub.sql supabase/migrations/*.sql supabase/seed.sql; do
  psql "$TEST_URL" -v ON_ERROR_STOP=1 -q -f "$f" >/dev/null
done
psql "$TEST_URL" -v ON_ERROR_STOP=1 -q -f supabase/tests/30_drive_messaging.sql >/dev/null && echo "✔ Scénarios Drive & messagerie OK"
psql "$PGURL" -qc "drop database if exists $DB" >/dev/null
psql "$PGURL" -qc "create database $DB" >/dev/null
for f in supabase/tests/00_supabase_stub.sql supabase/migrations/*.sql supabase/seed.sql; do
  psql "$TEST_URL" -v ON_ERROR_STOP=1 -q -f "$f" >/dev/null
done
psql "$TEST_URL" -v ON_ERROR_STOP=1 -q -f supabase/tests/40_collab_notifications.sql >/dev/null && echo "✔ Scénarios co-édition & notifications OK"
psql "$PGURL" -qc "drop database if exists $DB" >/dev/null
psql "$PGURL" -qc "create database $DB" >/dev/null
for f in supabase/tests/00_supabase_stub.sql supabase/migrations/*.sql supabase/seed.sql; do
  psql "$TEST_URL" -v ON_ERROR_STOP=1 -q -f "$f" >/dev/null
done
psql "$TEST_URL" -v ON_ERROR_STOP=1 -q -f supabase/tests/50_access_code.sql | grep -E "NOTICE|ERREUR" || true
psql "$PGURL" -qc "drop database if exists $DB" >/dev/null
psql "$PGURL" -qc "create database $DB" >/dev/null
for f in supabase/tests/00_supabase_stub.sql supabase/migrations/*.sql supabase/seed.sql; do
  psql "$TEST_URL" -v ON_ERROR_STOP=1 -q -f "$f" >/dev/null
done
psql "$TEST_URL" -v ON_ERROR_STOP=1 -q -f supabase/tests/60_holding.sql | grep -E "NOTICE|ERREUR" || true
psql "$PGURL" -qc "drop database if exists $DB" >/dev/null
