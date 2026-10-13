#!/usr/bin/env bash
# Naplnenie modulu 3 na Teste (Neon dev): 40 produktov, 105 párovaní so sadzbami, 6 cenníkov 2026 z PDF
# (db/seed/cenniky-2026.sql). Beží ako vlastník databázy v jednej transakcii; ceny s DPH sa na konci porovnajú s PDF.
# Na main sa zatiaľ nespúšťa (až po schválení na Teste).
#
# Použitie: ./db/seed/cenniky-2026.sh dev --skuska   urobí a skontroluje všetko, na konci ROLLBACK (nič neuloží)
#           ./db/seed/cenniky-2026.sh dev            uloží
#
# Pripojenie sa číta z .dev.vars (DATABASE_URL_DEV) a odovzdáva sa iba cez premenné libpq, nikdy sa nevypisuje.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export PATH="/Applications/Postgres.app/Contents/Versions/latest/bin:$PATH"

usage() {
  echo "Použitie: ./db/seed/cenniky-2026.sh dev [--skuska]" >&2
  exit 1
}
[[ $# -ge 1 && "$1" == "dev" ]] || usage
END="COMMIT"
case "${2:-}" in
  "")       ;;
  --skuska) END="ROLLBACK" ;;
  *)        usage ;;
esac

URL="$(grep -E '^DATABASE_URL_DEV=' "$ROOT/.dev.vars" | head -n 1 | cut -d= -f2- | sed -e 's/^["'\'']//' -e 's/["'\'']$//')"
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

{
  echo 'BEGIN;'
  echo "\\i $ROOT/db/seed/cenniky-2026.sql"
  echo "$END;"
} | psql -X -q -v ON_ERROR_STOP=1
if [[ "$END" == "ROLLBACK" ]]; then
  echo "Skúška hotová: všetko prešlo, nič sa neuložilo (ROLLBACK)."
else
  echo "Uložené."
fi
