#!/usr/bin/env bash
# Écrit supabase/schema/schema.sql : l'état courant du schéma « public » (tables,
# fonctions, politiques, triggers) après toutes les migrations. C'est la référence
# lisible de ce qui est en vigueur ; la CI vérifie qu'il est à jour.
# Usage : PGURL=postgres://postgres@localhost:5432/postgres [PG_DUMP="pg_dump"] ./scripts/dump-schema.sh
set -euo pipefail
cd "$(dirname "$0")/.."
PGURL=${PGURL:-postgres://postgres@localhost:5432/postgres}
PG_DUMP=${PG_DUMP:-pg_dump}
DB=veriion_schema
URL="${PGURL%/*}/$DB"
psql "$PGURL" -qc "drop database if exists $DB" -qc "create database $DB" >/dev/null
for f in supabase/tests/00_supabase_stub.sql supabase/migrations/*.sql; do
  psql "$URL" -v ON_ERROR_STOP=1 -q -f "$f" >/dev/null 2>&1 || { echo "✘ $f"; exit 1; }
done
{
  echo "-- Schéma de référence de VERIION OS (généré par scripts/dump-schema.sh, ne pas modifier à la main)."
  $PG_DUMP "$URL" --schema-only --schema=public --no-owner --no-privileges --no-comments \
    | grep -v '^-- Dumped \|^SET \|^SELECT pg_catalog.set_config\|^\\\(un\)\?restrict '
} > supabase/schema/schema.sql
psql "$PGURL" -qc "drop database if exists $DB" >/dev/null
echo "✔ supabase/schema/schema.sql ($(grep -c '^CREATE FUNCTION' supabase/schema/schema.sql) fonctions, $(grep -c '^CREATE POLICY' supabase/schema/schema.sql) politiques)"
