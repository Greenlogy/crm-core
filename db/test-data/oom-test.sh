#!/usr/bin/env bash
# Testovacie dáta modulu Odberné miesta (vymyslené, so znakom „TEST“) – iba Neon vetva dev (Test).
# Použitie: ./db/test-data/oom-test.sh dev vytvor   10 zákazníkov a 20 OOM (oom-test.sql)
#           ./db/test-data/oom-test.sh dev zmaz     zmaže ich (oom-test-delete.sql)
# Pripojenie sa číta z .dev.vars (DATABASE_URL_DEV) a nevypisuje sa. Na main sa nespúšťa.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DIR="$ROOT/db/test-data"
export PATH="/Applications/Postgres.app/Contents/Versions/latest/bin:$PATH"

usage() {
  echo "Použitie: ./db/test-data/oom-test.sh dev vytvor|zmaz" >&2
  exit 1
}
[[ $# -eq 2 && "$1" == "dev" ]] || usage
case "$2" in
  vytvor) FILE="$DIR/oom-test.sql" ;;
  zmaz)   FILE="$DIR/oom-test-delete.sql" ;;
  *)      usage ;;
esac

URL="$(grep -E '^DATABASE_URL_DEV=' "$ROOT/.dev.vars" | head -n 1 | cut -d= -f2- | sed -e 's/^["'\'']//' -e 's/["'\'']$//')"
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

psql -X -q -f "$FILE"
