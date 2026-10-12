#!/usr/bin/env bash
# Vyprázdni Test (Neon vetva dev): zmaže dáta, ponechá zoznam migrácií, pracovný kalendár
# a Nastavenia (ak už existujú). Podrobnosti v db/empty-test.sql. Iba dev, nikdy main.
#
# Použitie: ./db/empty-test.sh --skuska          urobí a skontroluje všetko, na konci ROLLBACK (nič nezmaže)
#           ./db/empty-test.sh                   zmaže (po potvrdení napísaním „dev“)
#           ./db/empty-test.sh --rola-prototypu  iba zruší rolu crm_prototype_ro (prototyp potom prestane fungovať)
#
# Pripojenie sa číta z .dev.vars (DATABASE_URL_DEV) a odovzdáva sa iba cez premenné libpq, nikdy sa nevypisuje.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VARS_FILE="$ROOT/.dev.vars"
export PATH="/Applications/Postgres.app/Contents/Versions/latest/bin:$PATH"

MODE="ostre"
case "${1:-}" in
  "")               ;;
  --skuska)         MODE="skuska" ;;
  --rola-prototypu) MODE="rola" ;;
  *) echo "Použitie: ./db/empty-test.sh [--skuska | --rola-prototypu]" >&2; exit 1 ;;
esac

URL="$(grep -E '^DATABASE_URL_DEV=' "$VARS_FILE" | head -n 1 | cut -d= -f2- | sed -e 's/^["'\'']//' -e 's/["'\'']$//')"
if [[ -z "$URL" ]]; then
  echo "V .dev.vars chýba DATABASE_URL_DEV." >&2
  exit 1
fi

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

if [[ "$MODE" != "skuska" ]]; then
  if [[ "$MODE" == "rola" ]]; then
    echo "POZOR: zruší sa rola crm_prototype_ro na vetve dev. Prototyp (Worker crm-core) potom nebude mať prístup k databáze." >&2
  else
    echo "POZOR: zmažú sa všetky dáta na vetve dev (Test). Odporúčanie: najprv ./db/empty-test.sh --skuska" >&2
  fi
  read -r -p "Pre pokračovanie napíš 'dev': " CONFIRM
  if [[ "$CONFIRM" != "dev" ]]; then
    echo "Zrušené." >&2
    exit 1
  fi
fi

if [[ "$MODE" == "rola" ]]; then
  psql -X -q -P pager=off -v ON_ERROR_STOP=1 <<'SQL'
BEGIN;
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'crm_prototype_ro') THEN
    RAISE NOTICE 'Rola crm_prototype_ro neexistuje, nič sa nemení.';
    RETURN;
  END IF;
  EXECUTE format('REVOKE CONNECT ON DATABASE %I FROM crm_prototype_ro', current_database());
  REVOKE ALL ON ALL TABLES IN SCHEMA public FROM crm_prototype_ro;
  REVOKE USAGE ON SCHEMA public FROM crm_prototype_ro;
  ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE SELECT ON TABLES FROM crm_prototype_ro;
  DROP ROLE crm_prototype_ro;
  RAISE NOTICE 'Rola crm_prototype_ro zrušená.';
END;
$$;
COMMIT;
SQL
  echo "Riadok DATABASE_URL_DEV_RO v .dev.vars už neplatí; zmaž ho ručne."
  exit 0
fi

SKUSKA=false
[[ "$MODE" == "skuska" ]] && SKUSKA=true
psql -X -q -P pager=off -v ON_ERROR_STOP=1 -v skuska="$SKUSKA" -f "$ROOT/db/empty-test.sql"
