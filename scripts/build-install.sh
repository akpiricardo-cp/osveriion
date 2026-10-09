#!/usr/bin/env bash
# Régénère supabase/install.sql : toutes les migrations, dans l'ordre, puis seed.sql.
set -euo pipefail
cd "$(dirname "$0")/.."
out=supabase/install.sql
{
  echo "-- ============================================================================="
  echo "-- VERIION OS — Installation complète (migrations + données initiales)"
  echo "-- Généré à partir de supabase/migrations/*.sql et supabase/seed.sql (npm run build:install)."
  echo "-- Collez ce fichier dans Supabase > SQL Editor et exécutez-le UNE fois."
  echo "-- ============================================================================="
  for f in supabase/migrations/*.sql supabase/seed.sql; do
    echo
    echo "-- >>>>>>>>>> $f"
    cat "$f"
  done
} > "$out"
echo "✔ $out régénéré ($(wc -l < "$out") lignes)"
