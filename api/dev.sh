#!/usr/bin/env bash
# Lokálne spustenie API (wrangler dev) proti Neon dev s rolou iba na čítanie.
# Použitie: cd ~/projects/greenlogy/crm-core/api && ./dev.sh
# Pripojenie sa číta z ../.dev.vars (DATABASE_URL_DEV_RO) a nevypisuje sa. Nič sa nenasadzuje.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
URL="$(grep -E '^DATABASE_URL_DEV_RO=' "$ROOT/.dev.vars" | head -n 1 | cut -d= -f2- | sed -e 's/^["'\'']//' -e 's/["'\'']$//')"
if [[ -z "$URL" ]]; then
  echo "V .dev.vars chýba DATABASE_URL_DEV_RO (krok 3: api/db/create-prototype-role.sh)." >&2
  exit 1
fi

# postgres.js by parameter channel_binding poslal serveru ako nastavenie – odstránime ho.
CLOUDFLARE_HYPERDRIVE_LOCAL_CONNECTION_STRING_HYPERDRIVE="$(DB_URL="$URL" node -e '
  const u = new URL(process.env.DB_URL);
  u.searchParams.delete("channel_binding");
  process.stdout.write(u.toString());
')"
export CLOUDFLARE_HYPERDRIVE_LOCAL_CONNECTION_STRING_HYPERDRIVE
unset URL

exec "$ROOT/api/node_modules/.bin/wrangler" dev --port 8787 "$@"
