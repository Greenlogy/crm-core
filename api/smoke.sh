#!/usr/bin/env bash
# Skúšobné volanie všetkých endpointov bežiaceho API (./dev.sh). Iba čítanie.
# Použitie: cd ~/projects/greenlogy/crm-core/api && ./smoke.sh [http://localhost:8787]
# Odpovede ukladá do exports/prototyp/api/, do terminálu iba stavové kódy a počty.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE="${1:-http://localhost:8787}"
OUT="$ROOT/exports/prototyp/api"
mkdir -p "$OUT"

call() { # názov cesta
  local code
  code="$(curl -s -o "$OUT/$1.json" -w '%{http_code}' "$BASE$2")"
  echo "$code"
}

summary() { # názov – počty polí, ktoré sú zoznamy
  node -e '
    const d = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
    const parts = Object.entries(d).filter(([, v]) => Array.isArray(v)).map(([k, v]) => `${k} ${v.length}`);
    console.log(parts.join(", ") || (d.error ?? "ok"));
  ' "$OUT/$1.json"
}

pick() { # súbor výraz – vyberie ID bez vypisovania dát
  node -e '
    const d = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
    const v = new Function("d", "return " + process.argv[2])(d);
    process.stdout.write(String(v ?? ""));
  ' "$OUT/$1.json" "$2"
}

echo "health:      $(call health /api/health) $(summary health)"
echo "customers:   $(call customers '/api/customers') total $(pick customers 'd.total'), $(summary customers)"
echo "hľadanie:    $(call customers-q '/api/customers?q=a&segment=firma') total $(pick customers-q 'd.total')"

COMPANY="$(pick customers 'd.items.find(i => i.kind === "company" && i.oom_count > 1)?.id')"
PERSON="$(pick customers 'd.items.find(i => i.kind === "person")?.id')"
[[ -n "$PERSON" ]] || { call customers-p '/api/customers?segment=domacnost' >/dev/null; PERSON="$(pick customers-p 'd.items[0]?.id')"; }

echo "firma:       $(call company "/api/companies/$COMPANY") $(summary company)"
echo "domácnosť:   $(call person "/api/persons/$PERSON") $(summary person)"
OOM="$(pick company 'd.ooms[0]?.id')"
CONTRACT="$(pick company 'd.contracts[0]?.id')"
echo "OOM:         $(call oom "/api/oom/$OOM") $(summary oom)"
echo "zmluva:      $(call contract "/api/contracts/$CONTRACT") $(summary contract)"

echo "zlé ID:      $(call bad-id /api/oom/abc) (čakám 400)"
echo "neexistuje:  $(call missing /api/oom/00000000-0000-0000-0000-000000000000) (čakám 404)"
echo "zápis:       $(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/customers") (čakám 405)"
echo "Odpovede: exports/prototyp/api/"
