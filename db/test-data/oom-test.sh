#!/usr/bin/env bash
# Testovacie dáta modulu Odberné miesta (vymyslené, so znakom „TEST“) – iba Neon vetva dev (Test).
# Použitie: ./db/test-data/oom-test.sh dev vytvor            10 zákazníkov a 20 OOM (oom-test.sql)
#           ./db/test-data/oom-test.sh dev zmaz              zmaže ich (oom-test-delete.sql)
#           ./db/test-data/oom-test.sh dev beh 2026-11-01    nočný beh OOM k dátumu (plány + aktivácia)
#             – na vyskúšanie plánovaných zmien bez čakania do noci; mení všetky OOM na Teste
# Pripojenie sa číta z .dev.vars (DATABASE_URL_DEV) a nevypisuje sa. Na main sa nespúšťa.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DIR="$ROOT/db/test-data"
export PATH="/Applications/Postgres.app/Contents/Versions/latest/bin:$PATH"

usage() {
  echo "Použitie: ./db/test-data/oom-test.sh dev vytvor|zmaz|beh RRRR-MM-DD" >&2
  exit 1
}
[[ $# -ge 2 && "$1" == "dev" ]] || usage
RUN_DATE=""
case "$2" in
  vytvor) [[ $# -eq 2 ]] || usage; FILE="$DIR/oom-test.sql" ;;
  zmaz)   [[ $# -eq 2 ]] || usage; FILE="$DIR/oom-test-delete.sql" ;;
  beh)    [[ $# -eq 3 && "$3" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || usage; RUN_DATE="$3" ;;
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

if [[ -n "$RUN_DATE" ]]; then
  # premenná :'d' sa dosadí iba pri čítaní zo vstupu (nie pri -c)
  echo "SELECT oom_daily_run_at(:'d'::date) AS vysledok;" | psql -X -q -v ON_ERROR_STOP=1 -v d="$RUN_DATE"
else
  psql -X -q -f "$FILE"
fi
