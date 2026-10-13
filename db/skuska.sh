#!/usr/bin/env bash
# Pomocník pre DOČASNÚ skúšobnú vetvu z main (overenie migrácií 0001–0022; plán 13. 10. 2026). Iba DATABASE_URL_SKUSKA.
# Použitie: ./db/skuska.sh rola   – rola crm_app bez prihlásenia (NOLOGIN, bez hesla) a jej práva (api/db/app-role.sql),
#                                   aby prešli testy, ktoré si rolu aplikácie berú (checks_cenniky C7). Nie pre Ostré.
# Pripojenie sa číta z .dev.vars a nevypisuje sa. Na dev ani main sa nespúšťa (iná premenná nie je podporovaná).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="/Applications/Postgres.app/Contents/Versions/latest/bin:$PATH"
[[ "${1:-}" == "rola" ]] || { echo "Použitie: ./db/skuska.sh rola" >&2; exit 1; }

URL="$(grep -E '^DATABASE_URL_SKUSKA=' "$ROOT/.dev.vars" | head -n 1 | cut -d= -f2- | sed -e 's/^["'\'']//' -e 's/["'\'']$//' || true)"
[[ -n "$URL" ]] || { echo "V .dev.vars chýba DATABASE_URL_SKUSKA." >&2; exit 1; }
URL_MAIN="$(grep -E '^DATABASE_URL_MAIN=' "$ROOT/.dev.vars" | head -n 1 | cut -d= -f2- | sed -e 's/^["'\'']//' -e 's/["'\'']$//' || true)"
URL_DEV="$(grep -E '^DATABASE_URL_DEV=' "$ROOT/.dev.vars" | head -n 1 | cut -d= -f2- | sed -e 's/^["'\'']//' -e 's/["'\'']$//' || true)"
host() { DB_URL="$1" node -e 'try { process.stdout.write(new URL(process.env.DB_URL).hostname) } catch {}'; }
if [[ "$(host "$URL")" == "$(host "$URL_MAIN")" || "$(host "$URL")" == "$(host "$URL_DEV")" ]]; then
  echo "DATABASE_URL_SKUSKA ukazuje na rovnaký server ako main alebo dev – zastavené." >&2
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
unset URL URL_MAIN URL_DEV

psql -X -q -v ON_ERROR_STOP=1 -c "DO \$\$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'crm_app') THEN CREATE ROLE crm_app NOLOGIN; END IF; END \$\$;"
psql -X -q -v ON_ERROR_STOP=1 -f "$ROOT/api/db/app-role.sql"
echo "Skúšobná vetva: rola crm_app (NOLOGIN) a jej práva nastavené."
