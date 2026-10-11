#!/usr/bin/env bash
# Spustí SQL súbor na Neon vetve dev (iba dev, nikdy main). Pre vzorku prototypu (modul 2).
# Použitie: ./sample/psql-dev.sh <súbor.sql>
# Pripojenie sa číta z .dev.vars (DATABASE_URL_DEV) a odovzdáva sa iba cez premenné libpq, nikdy sa nevypisuje.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
VARS_FILE="$ROOT/.dev.vars"
export PATH="/Applications/Postgres.app/Contents/Versions/latest/bin:$PATH"

[[ $# -eq 1 && -f "$1" ]] || { echo "Použitie: ./sample/psql-dev.sh <súbor.sql>" >&2; exit 1; }

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

# Výstup INSERT/DELETE potlačený (-q); pri chybe sa transakcia vráti a skript skončí s chybou.
psql -X -q -v ON_ERROR_STOP=1 -f "$1"
echo "Hotovo: $(basename "$1")"
