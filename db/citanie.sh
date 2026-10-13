#!/usr/bin/env bash
# Spustí SQL súbor IBA NA ČÍTANIE na Neon vetve dev, main alebo skuska (dočasná skúšobná vetva z main).
# Režim iba na čítanie sa zapne už pri pripojení (default_transaction_read_only = on): zápis databáza odmietne.
# Použitie: ./db/citanie.sh dev|main|skuska <súbor.sql>
# Pripojenie sa číta z .dev.vars (DATABASE_URL_DEV / _MAIN / _SKUSKA) a odovzdáva sa iba cez premenné libpq, nikdy sa nevypisuje.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="/Applications/Postgres.app/Contents/Versions/latest/bin:$PATH"

[[ $# -eq 2 && -f "$2" ]] || { echo "Použitie: ./db/citanie.sh dev|main|skuska <súbor.sql>" >&2; exit 1; }
case "$1" in
  dev)    VAR_NAME="DATABASE_URL_DEV" ;;
  main)   VAR_NAME="DATABASE_URL_MAIN" ;;
  skuska) VAR_NAME="DATABASE_URL_SKUSKA" ;;
  *)      echo "Cieľ: dev, main alebo skuska." >&2; exit 1 ;;
esac

URL="$(grep -E "^${VAR_NAME}=" "$ROOT/.dev.vars" | head -n 1 | cut -d= -f2- | sed -e 's/^["'\'']//' -e 's/["'\'']$//' || true)"
[[ -n "$URL" ]] || { echo "V .dev.vars chýba $VAR_NAME." >&2; exit 1; }

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
export PGOPTIONS="-c default_transaction_read_only=on"

psql -X -q -v ON_ERROR_STOP=1 -f "$2"
