#!/usr/bin/env bash
# Testy databázy jadra na vetve dev: seed.sql + checks.sql + checks_zakaznici.sql + checks_nastavenia.sql
# + checks_zakaznici_zapis.sql + checks_oom.sql + checks_produkty.sql
# + checks_cenniky.sql
# v jednej transakcii, ktorá sa na konci vráti (na dev neostanú testovacie dáta).
# Testy počítajú iba vlastné záznamy (pevné id 00000000-0000-4000-8000-…, východiskové tímy) – prejdú aj na databáze
# s inými dátami (testovacie OOM, cenníky 2026, zmeny admina v Nastaveniach).
# Použitie: ./db/test/run.sh            (dev)
#           ./db/test/run.sh skuska     (dočasná skúšobná vetva z main, DATABASE_URL_SKUSKA)
# Na main sa testy nespúšťajú.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VARS_FILE="$ROOT/.dev.vars"
export PATH="/Applications/Postgres.app/Contents/Versions/latest/bin:$PATH"

case "${1:-dev}" in
  dev)    VAR_NAME="DATABASE_URL_DEV" ;;
  skuska) VAR_NAME="DATABASE_URL_SKUSKA" ;;
  *)      echo "Testy iba na dev alebo skuska (nikdy na main)." >&2; exit 1 ;;
esac
URL="$(grep -E "^${VAR_NAME}=" "$VARS_FILE" | head -n 1 | cut -d= -f2- | sed -e 's/^["'\'']//' -e 's/["'\'']$//' || true)"
if [[ -z "$URL" ]]; then
  echo "V .dev.vars chýba $VAR_NAME." >&2
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
\i $ROOT/db/test/checks_zakaznici.sql
\i $ROOT/db/test/checks_nastavenia.sql
\i $ROOT/db/test/checks_zakaznici_zapis.sql
\i $ROOT/db/test/checks_oom.sql
\i $ROOT/db/test/checks_produkty.sql
\i $ROOT/db/test/checks_cenniky.sql
ROLLBACK;
\echo 'Všetky kontroly prešli. Transakcia vrátená, neostali testovacie dáta.'
SQL
