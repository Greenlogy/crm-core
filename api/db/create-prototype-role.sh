#!/usr/bin/env bash
# Vytvorí rolu crm_prototype_ro (iba čítanie) na Neon vetve dev a overí ju (modul 2, krok 3).
# Použitie: ./api/db/create-prototype-role.sh
#           ./api/db/create-prototype-role.sh --nove-heslo   (rola už existuje: nové heslo a nový riadok v .dev.vars)
#
# 1. vygeneruje heslo (nikdy sa nevypisuje, neprechádza argumentmi príkazov),
# 2. vytvorí rolu a spustí api/db/prototype-role.sql (práva),
# 3. zapíše DATABASE_URL_DEV_RO do .dev.vars,
# 4. overí: SELECT prejde, INSERT zlyhá.
# Iba dev. Ak rola alebo DATABASE_URL_DEV_RO už existuje, skript skončí bez zmeny (okrem --nove-heslo).
# .dev.vars nesmie byť počas behu otvorený v editore s neuloženými zmenami – editor by zápis prepísal.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VARS_FILE="$ROOT/.dev.vars"
ROLE="crm_prototype_ro"
export PATH="/Applications/Postgres.app/Contents/Versions/latest/bin:$PATH"
RESET=false
[[ "${1:-}" == "--nove-heslo" ]] && RESET=true

if ! $RESET && grep -qE '^DATABASE_URL_DEV_RO=' "$VARS_FILE"; then
  echo "DATABASE_URL_DEV_RO už v .dev.vars je, nič nemením." >&2
  exit 1
fi

DEV_URL="$(grep -E '^DATABASE_URL_DEV=' "$VARS_FILE" | head -n 1 | cut -d= -f2- | sed -e 's/^["'\'']//' -e 's/["'\'']$//')"
if [[ -z "$DEV_URL" ]]; then
  echo "V .dev.vars chýba DATABASE_URL_DEV." >&2
  exit 1
fi

# Pripojenie cez premenné libpq (nie je v zozname procesov ani vo výpise).
libpq_env() {
  DB_URL="$1" node -e '
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
  '
}

# 32 znakov [A-Za-z0-9] – bez znakov, ktoré treba v URL alebo SQL escapovať.
PASSWORD="$(node -e '
  const { randomInt } = require("node:crypto");
  const abc = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
  process.stdout.write(Array.from({ length: 32 }, () => abc[randomInt(abc.length)]).join(""));
')"
[[ ${#PASSWORD} -eq 32 ]] || { echo "Generovanie hesla zlyhalo." >&2; exit 1; }

# --- 1. a 2. Rola a práva (ako vlastník databázy) ---
(
  eval "$(libpq_env "$DEV_URL")"
  EXISTS="$(psql -X -At -c "SELECT 1 FROM pg_roles WHERE rolname = '$ROLE'")"
  if $RESET; then
    [[ "$EXISTS" == "1" ]] || { echo "Rola $ROLE neexistuje – spusti skript bez --nove-heslo." >&2; exit 1; }
    # Heslo ide cez stdin, nie cez argument.
    printf "ALTER ROLE %s PASSWORD '%s';\n" "$ROLE" "$PASSWORD" | psql -X -q -v ON_ERROR_STOP=1
    exit 0
  fi
  if [[ "$EXISTS" == "1" ]]; then
    echo "Rola $ROLE už existuje, nič nemením (nové heslo: --nove-heslo)." >&2
    exit 1
  fi
  printf "CREATE ROLE %s LOGIN PASSWORD '%s';\n" "$ROLE" "$PASSWORD" | psql -X -q -v ON_ERROR_STOP=1
  psql -X -q -v ON_ERROR_STOP=1 -f "$ROOT/api/db/prototype-role.sql"
)
if $RESET; then echo "Rola $ROLE má nové heslo."; else echo "Rola $ROLE vytvorená, práva nastavené."; fi

# --- 3. Zápis do .dev.vars ---
RO_URL="$(DB_URL="$DEV_URL" RO_USER="$ROLE" RO_PASS="$PASSWORD" node -e '
  const u = new URL(process.env.DB_URL);
  u.username = process.env.RO_USER;
  u.password = process.env.RO_PASS;
  process.stdout.write(u.toString());
')"
# Starý riadok (ak je) sa nahradí; ostatné riadky ostávajú.
TMP="$(mktemp)"
grep -vE '^DATABASE_URL_DEV_RO=' "$VARS_FILE" >"$TMP" || true
printf 'DATABASE_URL_DEV_RO=%s\n' "$RO_URL" >>"$TMP"
cat "$TMP" >"$VARS_FILE"
rm -f "$TMP"
unset PASSWORD
echo "DATABASE_URL_DEV_RO zapísané do .dev.vars."

# --- 4. Overenie pod novou rolou ---
eval "$(libpq_env "$RO_URL")"
unset RO_URL DEV_URL
COMPANIES="$(psql -X -At -v ON_ERROR_STOP=1 -c 'SELECT count(*) FROM company')"
echo "SELECT: OK (firiem: $COMPANIES)"
if psql -X -q -c "INSERT INTO team (name) VALUES ('test_zapisu')" >/dev/null 2>&1; then
  echo "CHYBA: INSERT prešiel, rola nie je iba na čítanie!" >&2
  exit 1
fi
echo "INSERT: zamietnutý (správne)."
