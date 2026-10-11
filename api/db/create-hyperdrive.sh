#!/usr/bin/env bash
# Vytvorí Hyperdrive crm-core-dev (Neon vetva dev, rola crm_prototype_ro – iba čítanie) a zapíše jeho ID do api/wrangler.toml.
# Použitie: ./api/db/create-hyperdrive.sh
# Pripojenie sa číta z .dev.vars (DATABASE_URL_DEV_RO). Výstup wranglera sa nezobrazuje, vypíše sa iba ID.
# Pozor: wrangler dostane pripojenie ako parameter príkazu (lokálne krátko viditeľné v zozname procesov).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
NAME="crm-core-dev"
TOML="$ROOT/api/wrangler.toml"
WRANGLER="$ROOT/api/node_modules/.bin/wrangler"

grep -q 'id = "00000000000000000000000000000000"' "$TOML" || { echo "V wrangler.toml už je ID Hyperdrive, nič nemením." >&2; exit 1; }

URL="$(grep -E '^DATABASE_URL_DEV_RO=' "$ROOT/.dev.vars" | head -n 1 | cut -d= -f2- | sed -e 's/^["'\'']//' -e 's/["'\'']$//')"
[[ -n "$URL" ]] || { echo "V .dev.vars chýba DATABASE_URL_DEV_RO." >&2; exit 1; }

# Hyperdrive potrebuje priame pripojenie (nie pooler) a sslmode; channel_binding vynecháme.
URL="$(DB_URL="$URL" node -e '
  const u = new URL(process.env.DB_URL);
  u.hostname = u.hostname.replace("-pooler", "");
  u.searchParams.delete("channel_binding");
  process.stdout.write(u.toString());
')"

cd "$ROOT/api"
set +e
OUT="$("$WRANGLER" hyperdrive create "$NAME" --connection-string="$URL" 2>&1)"
CODE=$?
set -e
unset URL
# Wrangler vypisuje ID ako JSON alebo ako riadok wrangler.toml (id = "…").
ID="$(printf '%s' "$OUT" | grep -oiE '"?id"? *[:=] *"[0-9a-f]{32}"' | head -n 1 | grep -oE '[0-9a-f]{32}' || true)"
if [[ $CODE -ne 0 || -z "$ID" ]]; then
  # Chybové hlásenie bez riadkov, ktoré by mohli obsahovať pripojenie.
  echo "Vytvorenie Hyperdrive zlyhalo (kód $CODE):" >&2
  printf '%s\n' "$OUT" | grep -viE 'postgres(ql)?://|password' | grep -iE 'error|✘|failed|already' | head -n 5 >&2
  exit 1
fi

sed -i '' "s/id = \"00000000000000000000000000000000\"/id = \"$ID\"/" "$TOML"
echo "Hyperdrive $NAME vytvorený, ID $ID zapísané do api/wrangler.toml."
