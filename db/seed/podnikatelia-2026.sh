#!/usr/bin/env bash
# Naplnenie modulu 4, F1 na Teste (Neon dev): produkty Green 1T / 2T / 2T Vykurovanie / 1T VO a VBattery V,
# Dodávka B2B → Dobieha, cenník „Podnikatelia nad 30 MWh“ od 1. 1. 2026 (verzie 1.–9. a od 1. 10. s rovnakými cenami), cenník „VBattery V (sharing)“ od 1. 1. 2026
# (bezplatne), cenník „VBattery AKU (dobieha)“ od 1. 1. 2026 (1,00 €) a preklady produktov pri OOM
# (db/seed/podnikatelia-2026.sql). Predpoklad: migrácie 0023, 0024 a db/seed/cenniky-2026.sh. Beží ako vlastník databázy
# v jednej transakcii; ceny s DPH sa na konci porovnajú s PDF.
# Na main sa zatiaľ nespúšťa (až po schválení na Teste).
#
# Použitie: ./db/seed/podnikatelia-2026.sh dev --skuska   urobí a skontroluje všetko, na konci ROLLBACK (nič neuloží)
#           ./db/seed/podnikatelia-2026.sh dev            uloží
#
# Pripojenie sa číta z .dev.vars (DATABASE_URL_DEV) a odovzdáva sa iba cez premenné libpq, nikdy sa nevypisuje.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export PATH="/Applications/Postgres.app/Contents/Versions/latest/bin:$PATH"

usage() {
  echo "Použitie: ./db/seed/podnikatelia-2026.sh dev [--skuska]" >&2
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
  echo "\\i $ROOT/db/seed/podnikatelia-2026.sql"
  echo "$END;"
} | psql -X -q -v ON_ERROR_STOP=1
if [[ "$END" == "ROLLBACK" ]]; then
  echo "Skúška hotová: všetko prešlo, nič sa neuložilo (ROLLBACK)."
else
  echo "Uložené."
fi
