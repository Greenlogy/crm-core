#!/usr/bin/env bash
# Spúšťač dbmate pre Neon vetvy dev a main.
# Použitie: ./db/dbmate.sh dev|main <príkaz dbmate> [parametre]
# Príklady: ./db/dbmate.sh dev status
#           ./db/dbmate.sh dev up
#           ./db/dbmate.sh main up
#
# Pripojenie sa číta z .dev.vars (DATABASE_URL_DEV / DATABASE_URL_MAIN)
# a odovzdáva sa iba cez premennú prostredia, nikdy sa nevypisuje.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VARS_FILE="$ROOT/.dev.vars"
DBMATE="$ROOT/node_modules/.bin/dbmate"

usage() {
  echo "Použitie: ./db/dbmate.sh dev|main <príkaz dbmate> [parametre]" >&2
  exit 1
}

[[ $# -ge 2 ]] || usage
TARGET="$1"
shift

case "$TARGET" in
  dev)  VAR_NAME="DATABASE_URL_DEV" ;;
  main) VAR_NAME="DATABASE_URL_MAIN" ;;
  *)    usage ;;
esac

if [[ ! -x "$DBMATE" ]]; then
  echo "dbmate nie je nainštalovaný. Spusti: cd \"$ROOT\" && npm install" >&2
  exit 1
fi

if [[ ! -f "$VARS_FILE" ]]; then
  echo "Chýba súbor .dev.vars s $VAR_NAME." >&2
  exit 1
fi

# Načíta iba jednu premennú, bez spúšťania obsahu súboru.
URL="$(grep -E "^${VAR_NAME}=" "$VARS_FILE" | head -n 1 | cut -d= -f2- | sed -e 's/^["'\'']//' -e 's/["'\'']$//')"
if [[ -z "$URL" ]]; then
  echo "V .dev.vars chýba $VAR_NAME." >&2
  exit 1
fi

if [[ "$TARGET" == "main" ]]; then
  echo "POZOR: príkaz 'dbmate $*' pôjde na PRODUKČNÚ vetvu main." >&2
  read -r -p "Pre pokračovanie napíš 'main': " CONFIRM
  if [[ "$CONFIRM" != "main" ]]; then
    echo "Zrušené." >&2
    exit 1
  fi
fi

# Databázu spravuje Neon: dbmate ju nesmie vytvárať ani mazať.
CMD="$1"
shift
case "$CMD" in
  create|drop)
    echo "Príkaz '$CMD' je zakázaný. Databázu spravuje Neon." >&2
    exit 1 ;;
  up)
    CMD="migrate" ;;  # up = create + migrate; create nechceme
esac

export DATABASE_URL="$URL"
exec "$DBMATE" \
  --env DATABASE_URL \
  --migrations-dir "$ROOT/db/migrations" \
  --schema-file "$ROOT/db/schema.sql" \
  "$CMD" "$@"
