#!/usr/bin/env bash
# Testovacie zmluvy a ručný nočný beh modulu Zmluvy (F4) – iba Neon vetva dev (Test), nikdy main (Ostré).
# Použitie: ./db/test-data/zmluvy-test.sh dev vytvor                 vymyslené zmluvy TEST-NB-… (zmluvy-test.sql)
#           ./db/test-data/zmluvy-test.sh dev zmaz                   zmaže iba ich (zmluvy-test-delete.sql)
#           ./db/test-data/zmluvy-test.sh dev beh RRRR-MM-DD         nočný beh (OOM aj zmluvy) k dátumu, uloží sa
#           ./db/test-data/zmluvy-test.sh dev nanecisto RRRR-MM-DD   to isté, vypíše zmeny a vráti ich (ROLLBACK)
# Beh k dátumu ide cez vlastníka databázy (aplikácia dátum podstrčiť nevie) a mení všetky zmluvy a OOM na Teste,
# nielen testovacie – preto najprv „nanecisto“. Pripojenie sa číta z .dev.vars (DATABASE_URL_DEV) a nevypisuje sa.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DIR="$ROOT/db/test-data"
export PATH="/Applications/Postgres.app/Contents/Versions/latest/bin:$PATH"

usage() {
  echo "Použitie: ./db/test-data/zmluvy-test.sh dev vytvor|zmaz|beh RRRR-MM-DD|nanecisto RRRR-MM-DD" >&2
  exit 1
}
[[ $# -ge 2 ]] || usage
if [[ "$1" != "dev" ]]; then
  echo "Skript beží iba na vetve dev (Test). Na main (Ostré) ani inú vetvu sa nespúšťa." >&2
  exit 1
fi
RUN_DATE=""
END=""
case "$2" in
  vytvor)    [[ $# -eq 2 ]] || usage; FILE="$DIR/zmluvy-test.sql" ;;
  zmaz)      [[ $# -eq 2 ]] || usage; FILE="$DIR/zmluvy-test-delete.sql" ;;
  beh)       [[ $# -eq 3 && "$3" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || usage; RUN_DATE="$3"; END="COMMIT" ;;
  nanecisto) [[ $# -eq 3 && "$3" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || usage; RUN_DATE="$3"; END="ROLLBACK" ;;
  *)         usage ;;
esac

read_var() {
  grep -E "^$1=" "$ROOT/.dev.vars" | head -n 1 | cut -d= -f2- | sed -e 's/^["'\'']//' -e 's/["'\'']$//' || true
}
URL="$(read_var DATABASE_URL_DEV)"
if [[ -z "$URL" ]]; then
  echo "V .dev.vars chýba DATABASE_URL_DEV." >&2
  exit 1
fi
# Poistka: DATABASE_URL_DEV nesmie ukazovať na ten istý server (vetvu) ako DATABASE_URL_MAIN
MAIN_URL="$(read_var DATABASE_URL_MAIN)"
if [[ -n "$MAIN_URL" ]]; then
  SAME="$(A="$URL" B="$MAIN_URL" node -e '
    const a = new URL(process.env.A), b = new URL(process.env.B);
    console.log(a.hostname === b.hostname && a.pathname === b.pathname ? "ano" : "nie");')"
  unset MAIN_URL
  if [[ "$SAME" != "nie" ]]; then
    echo "DATABASE_URL_DEV ukazuje na rovnakú databázu ako DATABASE_URL_MAIN (Ostré) – skript sa nespustí." >&2
    exit 1
  fi
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

if [[ -n "$RUN_DATE" ]]; then
  psql -X -q -v ON_ERROR_STOP=1 -v d="$RUN_DATE" -v end="$END" -f "$DIR/zmluvy-test-run.sql"
else
  psql -X -q -f "$FILE"
fi
