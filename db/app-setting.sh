#!/usr/bin/env bash
# Nastavenie systému (tabuľka app_setting, migrácia 0014) na Neon vetve dev alebo main.
# Použitie: ./db/app-setting.sh dev|main                          vypíše nastavenia
#           ./db/app-setting.sh dev|main customer_status_auto on  zapne prepínač (pri prepočte stavu
#                                                                  zákazníka hneď prepočíta všetkých)
#           ./db/app-setting.sh dev|main customer_status_auto off vypne prepínač
# Pripojenie sa číta z .dev.vars (DATABASE_URL_DEV / DATABASE_URL_MAIN), nikdy sa nevypisuje.
# Mení sa ako vlastník databázy; audit zapíše zmenu so zdrojom „Systém“.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VARS_FILE="$ROOT/.dev.vars"
export PATH="/Applications/Postgres.app/Contents/Versions/latest/bin:$PATH"

usage() {
  echo "Použitie: ./db/app-setting.sh dev|main [kľúč on|off]" >&2
  exit 1
}

[[ $# -eq 1 || $# -eq 3 ]] || usage
case "$1" in
  dev)  VAR_NAME="DATABASE_URL_DEV" ;;
  main) VAR_NAME="DATABASE_URL_MAIN" ;;
  *)    usage ;;
esac

URL="$(grep -E "^${VAR_NAME}=" "$VARS_FILE" | head -n 1 | cut -d= -f2- | sed -e 's/^["'\'']//' -e 's/["'\'']$//')"
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

if [[ $# -eq 3 ]]; then
  KEY="$2"
  case "$3" in
    on)  VALUE=true ;;
    off) VALUE=false ;;
    *)   usage ;;
  esac
  [[ "$KEY" =~ ^[a-z][a-z0-9_]{1,62}$ ]] || usage
  if [[ "$1" == "main" ]]; then
    read -r -p "Meníš nastavenie na OSTROM (main): $KEY = $VALUE. Pokračovať? (ano/nie) " ANS
    [[ "$ANS" == "ano" ]] || { echo "Zrušené."; exit 1; }
  fi
  psql -X -q -v ON_ERROR_STOP=1 -v key="$KEY" -v val="$VALUE" <<'SQL'
BEGIN;
SET LOCAL app.change_source = 'system';
SELECT count(*) AS n FROM app_setting WHERE key = :'key' \gset
\if :n
  UPDATE app_setting SET value = to_jsonb(:'val'::boolean) WHERE key = :'key';
  SELECT CASE WHEN :'key' = 'customer_status_auto' AND :'val'::boolean
              THEN 'Prepočítaní zákazníci (zmenený stav): ' || customer_refresh_all()
              ELSE 'Nastavené.' END AS vysledok;
  COMMIT;
\else
  \echo 'Neznáme nastavenie.'
  ROLLBACK;
\endif
SQL
fi

psql -X -q -c "SELECT key AS nastavenie, value AS hodnota, updated_at AS zmenene FROM app_setting ORDER BY key"
