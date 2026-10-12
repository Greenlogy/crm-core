#!/usr/bin/env bash
# Vytvorí rolu crm_app (aplikácia CRM) na Neon vetve dev a overí ju.
# Použitie: ./api/db/create-app-role.sh               rola ešte neexistuje: vytvorí ju, nastaví práva, zapíše .dev.vars
#           ./api/db/create-app-role.sh --prava       iba znova nastaví práva (po migrácii s novými tabuľkami)
#           ./api/db/create-app-role.sh --nove-heslo  nové heslo existujúcej roly a nový riadok v .dev.vars
#
# 1. vygeneruje heslo (nikdy sa nevypisuje, neprechádza argumentmi príkazov),
# 2. vytvorí rolu a spustí api/db/app-role.sql (práva),
# 3. zapíše DATABASE_URL_DEV_APP do .dev.vars,
# 4. overí pod novou rolou: bez používateľa nevidí nič, s používateľom áno, audit nezmaže.
# Predpoklad: migrácia 0009 na dev. Iba dev. .dev.vars nesmie byť počas behu otvorený v editore s neuloženými zmenami.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VARS_FILE="$ROOT/.dev.vars"
ROLE="crm_app"
export PATH="/Applications/Postgres.app/Contents/Versions/latest/bin:$PATH"

MODE="nova"
case "${1:-}" in
  "")           ;;
  --prava)      MODE="prava" ;;
  --nove-heslo) MODE="heslo" ;;
  *) echo "Použitie: ./api/db/create-app-role.sh [--prava | --nove-heslo]" >&2; exit 1 ;;
esac

if [[ "$MODE" == "nova" ]] && grep -qE '^DATABASE_URL_DEV_APP=' "$VARS_FILE"; then
  echo "DATABASE_URL_DEV_APP už v .dev.vars je, nič nemením (práva: --prava, heslo: --nove-heslo)." >&2
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

# --- iba práva ---
if [[ "$MODE" == "prava" ]]; then
  (
    eval "$(libpq_env "$DEV_URL")"
    psql -X -q -P pager=off -v ON_ERROR_STOP=1 -f "$ROOT/api/db/app-role.sql"
  )
  echo "Práva roly $ROLE nastavené znova."
  exit 0
fi

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
  if [[ "$MODE" == "heslo" ]]; then
    [[ "$EXISTS" == "1" ]] || { echo "Rola $ROLE neexistuje – spusti skript bez parametra." >&2; exit 1; }
    # Heslo ide cez stdin, nie cez argument.
    printf "ALTER ROLE %s PASSWORD '%s';\n" "$ROLE" "$PASSWORD" | psql -X -q -v ON_ERROR_STOP=1
    exit 0
  fi
  if [[ "$EXISTS" == "1" ]]; then
    echo "Rola $ROLE už existuje, nič nemením (nové heslo: --nove-heslo)." >&2
    exit 1
  fi
  printf "CREATE ROLE %s LOGIN NOBYPASSRLS PASSWORD '%s';\n" "$ROLE" "$PASSWORD" | psql -X -q -v ON_ERROR_STOP=1
  psql -X -q -P pager=off -v ON_ERROR_STOP=1 -f "$ROOT/api/db/app-role.sql"
)
if [[ "$MODE" == "heslo" ]]; then echo "Rola $ROLE má nové heslo."; else echo "Rola $ROLE vytvorená, práva nastavené."; fi

# --- 3. Zápis do .dev.vars ---
APP_URL="$(DB_URL="$DEV_URL" APP_USER="$ROLE" APP_PASS="$PASSWORD" node -e '
  const u = new URL(process.env.DB_URL);
  u.username = process.env.APP_USER;
  u.password = process.env.APP_PASS;
  process.stdout.write(u.toString());
')"
# Starý riadok (ak je) sa nahradí; ostatné riadky ostávajú.
TMP="$(mktemp)"
grep -vE '^DATABASE_URL_DEV_APP=' "$VARS_FILE" >"$TMP" || true
printf 'DATABASE_URL_DEV_APP=%s\n' "$APP_URL" >>"$TMP"
cat "$TMP" >"$VARS_FILE"
rm -f "$TMP"
unset PASSWORD
echo "DATABASE_URL_DEV_APP zapísané do .dev.vars."

# --- 4. Overenie pod novou rolou ---
PETER_ID="$(eval "$(libpq_env "$DEV_URL")"; psql -X -At -c "SELECT id FROM app_user WHERE lower(email) = 'peter@greenlogy.com'")"
eval "$(libpq_env "$APP_URL")"
unset APP_URL DEV_URL

N="$(psql -X -At -v ON_ERROR_STOP=1 -c 'SELECT count(*) FROM app_user')"
[[ "$N" == "0" ]] || { echo "CHYBA: bez prihláseného používateľa rola vidí $N používateľov." >&2; exit 1; }
echo "Bez používateľa: nevidí nič (správne)."

N="$(psql -X -At -v ON_ERROR_STOP=1 -c "SET app.user_id = '$PETER_ID'; SELECT count(*) FROM app_user" | tail -n 1)"
[[ "$N" -ge 1 ]] || { echo "CHYBA: s prihláseným Petrom rola nevidí používateľov." >&2; exit 1; }
echo "S používateľom (Peter): vidí $N používateľov (správne)."

if psql -X -q -c "DELETE FROM audit_log WHERE false" >/dev/null 2>&1; then
  echo "CHYBA: rola smie mazať audit!" >&2
  exit 1
fi
echo "Mazanie auditu: zamietnuté (správne)."

if psql -X -q -c "SELECT 1 FROM schema_migrations LIMIT 1" >/dev/null 2>&1; then
  echo "CHYBA: rola vidí zoznam migrácií!" >&2
  exit 1
fi
echo "Zoznam migrácií: neprístupný (správne)."

N="$(psql -X -At -c "SET app.require_user = ''; SELECT count(*) FROM app_user" 2>/dev/null | tail -n 1 || true)"
if [[ "$N" != "0" ]]; then
  echo "CHYBA: po vypnutí app.require_user rola vidí $N používateľov (chýba migrácia 0009?)." >&2
  exit 1
fi
echo "Vypnutie app.require_user: nepomôže (správne)."
