#!/usr/bin/env bash
# Lokálne spustenie API (wrangler dev) proti Neon dev s rolou aplikácie crm_app.
# Použitie: cd ~/projects/greenlogy/crm-core/api && ./dev.sh
#           CRM_DEV_EMAIL=eva@greenlogy.com ./dev.sh   (prihlásiť sa ako iný používateľ CRM)
# Lokálne nie je Cloudflare Access: prihlásený je CRM_DEV_EMAIL (predvolene peter@greenlogy.com),
# platí iba pre localhost (api/src/auth.ts).
# Pripojenie sa číta z ../.dev.vars (DATABASE_URL_DEV_APP, rola crm_app) a nevypisuje sa. Nič sa nenasadzuje.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
URL="$(grep -E '^DATABASE_URL_DEV_APP=' "$ROOT/.dev.vars" | head -n 1 | cut -d= -f2- | sed -e 's/^["'\'']//' -e 's/["'\'']$//')"
if [[ -z "$URL" ]]; then
  echo "V .dev.vars chýba DATABASE_URL_DEV_APP (api/db/create-app-role.sh)." >&2
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

# Kľúče Finstatu (modul 5): iba riadky FINSTAT_* z ../.dev.vars cez dočasný súbor (nie argumenty – neboli by
# vidieť v zozname procesov); ostatné tajomstvá (HubSpot, pripojenia) sa do lokálneho Workera neodovzdávajú.
FIN_ENV="$(mktemp)"
chmod 600 "$FIN_ENV"
trap 'rm -f "$FIN_ENV"' EXIT
grep -E '^FINSTAT_(API_KEY|PRIVATE_KEY|LEVEL)=' "$ROOT/.dev.vars" > "$FIN_ENV" || true

"$ROOT/api/node_modules/.bin/wrangler" dev --port 8787 \
  --env-file "$FIN_ENV" \
  --var "DEV_USER_EMAIL:${CRM_DEV_EMAIL:-peter@greenlogy.com}" "$@"
