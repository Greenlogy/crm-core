#!/usr/bin/env bash
# Prepojí existujúci Hyperdrive crm-core-dev (ID z api/wrangler.toml) na aktuálne DATABASE_URL_DEV_RO.
# Použitie: ./api/db/update-hyperdrive.sh
# Na obnovu po zmene vetvy dev (napr. nová vetva po zmazaní 12. 10. 2026). Worker netreba znova nasadzovať.
# Pripojenie sa číta z .dev.vars (DATABASE_URL_DEV_RO). Výstup wranglera sa nezobrazuje.
# Pozor: wrangler dostane pripojenie ako parameter príkazu (lokálne krátko viditeľné v zozname procesov).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TOML="$ROOT/api/wrangler.toml"
WRANGLER="$ROOT/api/node_modules/.bin/wrangler"

ID="$(grep -A2 '^\[\[hyperdrive\]\]' "$TOML" | grep -oE '[0-9a-f]{32}' | head -n 1 || true)"
[[ -n "$ID" && "$ID" != "00000000000000000000000000000000" ]] || { echo "V wrangler.toml chýba ID Hyperdrive." >&2; exit 1; }

URL="$( { grep -E '^DATABASE_URL_DEV_RO=' "$ROOT/.dev.vars" || true; } | head -n 1 | cut -d= -f2- | sed -e 's/^["'\'']//' -e 's/["'\'']$//')"
[[ -n "$URL" ]] || { echo "V .dev.vars chýba DATABASE_URL_DEV_RO (najprv api/db/create-prototype-role.sh)." >&2; exit 1; }

# Hyperdrive potrebuje priame pripojenie (nie pooler) a sslmode; channel_binding vynecháme.
URL="$(DB_URL="$URL" node -e '
  const u = new URL(process.env.DB_URL);
  u.hostname = u.hostname.replace("-pooler", "");
  u.searchParams.delete("channel_binding");
  process.stdout.write(u.toString());
')"

cd "$ROOT/api"
set +e
OUT="$("$WRANGLER" hyperdrive update "$ID" --connection-string="$URL" 2>&1)"
CODE=$?
set -e
unset URL

if [[ $CODE -ne 0 ]]; then
  # Chybové hlásenie bez riadkov, ktoré by mohli obsahovať pripojenie.
  echo "Aktualizácia Hyperdrive zlyhala (kód $CODE):" >&2
  printf '%s\n' "$OUT" | grep -viE 'postgres(ql)?://|password' | grep -iE 'error|✘|failed' | head -n 5 >&2
  exit 1
fi
echo "Hyperdrive $ID prepojený na aktuálnu vetvu dev (rola z DATABASE_URL_DEV_RO)."
