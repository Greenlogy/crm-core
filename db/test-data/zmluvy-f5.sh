#!/usr/bin/env bash
# Testovacie obchody a ponuky pre skúšku párovania zmlúv s obchodmi (modul 5, F5) – iba Neon vetva dev (Test), nikdy main.
# Použitie: ./db/test-data/zmluvy-f5.sh dev vytvor [e-mail obchodníka]   firmy, OOM, obchody, ponuky (zmluvy-f5.sql)
#           ./db/test-data/zmluvy-f5.sh dev zmaz                         zmaže iba testovacie dáta F5 vrátane importovaných
#                                                                        zmlúv 1129995001–06 (zmluvy-f5-delete.sql)
# Potom v CRM: Zmluvy → Import → db/test-data/zmluvy-f5-office-portal.xlsx + zmluvy-f5-xm-trade.xlsx naraz.
# Súbory a SQL vytvorí znova: node db/test-data/zmluvy-f5-vytvor.cjs. Pripojenie z .dev.vars (DATABASE_URL_DEV), nevypisuje sa.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DIR="$ROOT/db/test-data"
export PATH="/Applications/Postgres.app/Contents/Versions/latest/bin:$PATH"

usage() {
  echo "Použitie: ./db/test-data/zmluvy-f5.sh dev vytvor [e-mail obchodníka] | dev zmaz" >&2
  exit 1
}
[[ $# -ge 2 ]] || usage
if [[ "$1" != "dev" ]]; then
  echo "Skript beží iba na vetve dev (Test). Na main (Ostré) ani inú vetvu sa nespúšťa." >&2
  exit 1
fi
OWNER="${3:-peter@greenlogy.com}"
case "$2" in
  vytvor) FILE="$DIR/zmluvy-f5.sql" ;;
  zmaz)   [[ $# -eq 2 ]] || usage; FILE="$DIR/zmluvy-f5-delete.sql" ;;
  *)      usage ;;
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

psql -X -q -v owner="$OWNER" -f "$FILE"
