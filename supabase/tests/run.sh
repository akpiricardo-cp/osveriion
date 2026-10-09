#!/usr/bin/env bash
# Rejoue les migrations sur un PostgreSQL local (hors Supabase), puis chaque scénario
# de test sur une base neuve. S'arrête au premier échec (code de sortie non nul).
# Usage : PGURL=postgres://postgres@localhost:5432/postgres ./supabase/tests/run.sh [fichier…]
set -euo pipefail
PGURL=${PGURL:-postgres://postgres@localhost:5432/postgres}
DB=veriion_test
TEST_URL="${PGURL%/*}/$DB"
cd "$(dirname "$0")/../.."

fresh_db() {
  psql "$PGURL" -qc "drop database if exists $DB" -qc "create database $DB" >/dev/null
  for f in supabase/tests/00_supabase_stub.sql supabase/migrations/*.sql supabase/seed.sql; do
    if ! out=$(psql "$TEST_URL" -v ON_ERROR_STOP=1 -q -f "$f" 2>&1); then
      echo "✘ Échec en appliquant $f"; echo "$out" | grep -E "ERROR|ERREUR" | head -5; exit 1
    fi
  done
}

files=("$@")
[ ${#files[@]} -eq 0 ] && files=(supabase/tests/[1-9]*_*.sql)

fresh_db
echo "✔ Migrations appliquées"
for t in "${files[@]}"; do
  fresh_db
  if ! out=$(psql "$TEST_URL" -v ON_ERROR_STOP=1 -q -f "$t" 2>&1); then
    echo "✘ $(basename "$t")"; echo "$out" | grep -E "ERROR|ERREUR|NOTICE" | tail -15; exit 1
  fi
  if echo "$out" | grep -q "ERREUR"; then
    echo "✘ $(basename "$t")"; echo "$out" | grep "ERREUR"; exit 1
  fi
  echo "✔ $(basename "$t") ($(echo "$out" | grep -c "OK :" || true) contrôles)"
done
psql "$PGURL" -qc "drop database if exists $DB" >/dev/null
echo "✔ Tous les scénarios passent"
