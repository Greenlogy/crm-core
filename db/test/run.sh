#!/usr/bin/env bash
# Testy databázy jadra na vetve dev: seed.sql + checks.sql v jednej transakcii,
# ktorá sa na konci vráti (na dev neostanú testovacie dáta).
# Použitie: ./db/test/run.sh
# Na main sa testy nespúšťajú.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VARS_FILE="$ROOT/.dev.vars"
export PATH="/Applications/Postgres.app/Contents/Versions/latest/bin:$PATH"

URL="$(grep -E '^DATABASE_URL_DEV=' "$VARS_FILE" | head -n 1 | cut -d= -f2- | sed -e 's/^["'\'']//' -e 's/["'\'']$//')"
if [[ -z "$URL" ]]; then
  echo "V .dev.vars chýba DATABASE_URL_DEV." >&2
  exit 1
fi

# Pripojenie cez premenné prostredia libpq, aby sa nezobrazilo v zozname procesov ani vo výpise.
eval "$(DB_URL="$URL" node -e '
  const u = new URL(process.env.DB_URL);
  const q = (v) => "\x27" + String(v).replace(/\x27/g, "\x27\\\x27\x27") + "\x27";
  const env = {
    PGHOST: u.hostname,
    PGPORT: u.port || "5432",
    PGUSER: decodeURIComponent(u.username),
    PGPASSWORD: decodeURIComponent(u.password),
    PGDATABASE: decodeURIComponent(u.pathname.slice(1)),
    PGSSLMODE: u.searchParams.get("sslmode") || "require",
  };
  for (const [k, v] of Object.entries(env)) console.log(`export ${k}=${q(v)}`);
')"
unset URL
psql -X -q -v ON_ERROR_STOP=1 <<SQL
\set QUIET on
SET client_min_messages = notice;
BEGIN;
\i $ROOT/db/test/seed.sql
\echo 'Testovacie dáta nahrané.'
\i $ROOT/db/test/checks.sql
ROLLBACK;
\echo 'Všetky kontroly prešli. Transakcia vrátená, na dev neostali testovacie dáta.'
SQL
