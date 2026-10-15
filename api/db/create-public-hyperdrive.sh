#!/usr/bin/env bash
# Vytvorí Hyperdrive crm-ponuka-dev pre Worker crm-ponuka (verejná stránka ponuky) z DATABASE_URL_DEV_PUBLIC
# (rola crm_public – iba schéma verejne, zapisuje ju api/db/create-public-role.sh).
# Použitie: ./api/db/create-public-hyperdrive.sh
# Vypíše iba ID nového Hyperdrive (nie je tajné, patrí do ponuka/wrangler.toml). Pripojenie sa nevypisuje.
# Pozor: wrangler dostane pripojenie ako parameter príkazu (lokálne krátko viditeľné v zozname procesov).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WRANGLER="$ROOT/api/node_modules/.bin/wrangler"
NAME="crm-ponuka-dev"

URL="$( { grep -E '^DATABASE_URL_DEV_PUBLIC=' "$ROOT/.dev.vars" || true; } | head -n 1 | cut -d= -f2- | sed -e 's/^["'\'']//' -e 's/["'\'']$//')"
[[ -n "$URL" ]] || { echo "V .dev.vars chýba DATABASE_URL_DEV_PUBLIC (najprv api/db/create-public-role.sh)." >&2; exit 1; }

# Hyperdrive potrebuje priame pripojenie (nie pooler) a sslmode; channel_binding vynecháme.
URL="$(DB_URL="$URL" node -e '
  const u = new URL(process.env.DB_URL);
  u.hostname = u.hostname.replace("-pooler", "");
  u.searchParams.delete("channel_binding");
  process.stdout.write(u.toString());
')"

cd "$ROOT/api"
set +e
# Cache vypnutá: stránka ponuky musí hneď ukázať akceptáciu a počítať otvorenia (zápis vo funkcii).
OUT="$("$WRANGLER" hyperdrive create "$NAME" --connection-string="$URL" --caching-disabled 2>&1)"
CODE=$?
set -e
unset URL

if [[ $CODE -ne 0 ]]; then
  echo "Vytvorenie Hyperdrive zlyhalo (kód $CODE):" >&2
  printf '%s\n' "$OUT" | grep -viE 'postgres(ql)?://|password' | grep -iE 'error|✘|failed|already' | head -n 5 >&2
  exit 1
fi
ID="$(printf '%s\n' "$OUT" | grep -oE '[0-9a-f]{32}' | head -n 1 || true)"
echo "Hyperdrive $NAME vytvorený (rola crm_public, cache vypnutá). ID: ${ID:-pozri v Cloudflare → Hyperdrive}"
