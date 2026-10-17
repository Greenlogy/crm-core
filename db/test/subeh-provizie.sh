#!/usr/bin/env bash
# Test súbehu provízií (0054) – IBA na dočasnom lokálnom Postgrese (127.0.0.1 / localhost), nikdy na Neone.
# Vytvorí kópiu databázy (CREATE DATABASE … TEMPLATE), založí v nej obchody so zmluvami a províziami (COMMIT) a naraz spustí
# 6 spojení: import cien v poradí obchodov, import v opačnom poradí, nočný prepočet, frontu, párovanie / zrušenie spárovania
# zmluvy (štádium) a uplatnenie + zrušenie listu. Na konci spočíta deadlocky a overí, že čakajúce provízie zodpovedajú
# zmluvám; overí, že preskočený obchod sa nestratí, a opakovanie uplatnenia po deadlocku (api/test/retry-db.test.ts).
# Kópiu databázy zmaže.
#
# Použitie: PGHOST=127.0.0.1 PGPORT=54353 PGUSER=crm_owner ./db/test/subeh-provizie.sh crm [kola]
#   crm   = lokálna databáza s migráciami (vzor; nemení sa)
#   kola  = počet kôl každého spojenia (predvolene 15)

set -uo pipefail
export PATH="/Applications/Postgres.app/Contents/Versions/latest/bin:$PATH"
SRC="${1:?Zadajte lokálnu databázu (vzor), napr. crm}"
ROUNDS="${2:-15}"
case "${PGHOST:-}" in
  127.0.0.1|localhost) ;;
  *) echo "Iba lokálny Postgres (PGHOST=127.0.0.1 alebo localhost)." >&2; exit 1 ;;
esac
DB="${SRC}_subeh"
TMP="$(mktemp -d)"
# SUBEH_KEEP=1: kópia ostane (napr. na lokálne vyskúšanie obrazoviek proti nej); inak sa na konci zmaže
trap 'rm -rf "$TMP"; [[ "${SUBEH_KEEP:-}" == "1" ]] || dropdb --if-exists "$DB" >/dev/null 2>&1' EXIT
dropdb --if-exists "$DB" >/dev/null 2>&1
createdb -T "$SRC" "$DB" || exit 1
export PGDATABASE="$DB"

# ---------------------------------------------------------------------------
# Príprava: obchodník a admin, firma, 12 vyhratých obchodov, každý so zmluvou A (párne poradie) a B; provízie
# ---------------------------------------------------------------------------
psql -X -q -v ON_ERROR_STOP=1 <<'SQL' || exit 1
BEGIN;
CREATE TEMP TABLE ids AS SELECT n, ('00000000-0000-4000-8000-000000a79' || lpad(n::text, 3, '0'))::uuid AS id FROM generate_series(0, 999) n;
INSERT INTO app_user (id, email, name, team_id, status, seller_type, is_admin, commission_enabled)
SELECT (SELECT id FROM ids WHERE n = 1), 'subeh.obchodnik@example.test', 'Súbeh obchodník', t.id, 'aktivny', 'obchodnik', false, true FROM team t WHERE t.code = 'sales_internal';
INSERT INTO app_user (id, email, name, team_id, status, is_admin)
SELECT (SELECT id FROM ids WHERE n = 2), 'subeh.admin@example.test', 'Súbeh admin', t.id, 'aktivny', true FROM team t WHERE t.code = 'sales_internal';
INSERT INTO app_user_org (user_id, org_id) SELECT id, crm_default_org() FROM ids WHERE n IN (1, 2);
INSERT INTO company (id, name, ico, is_customer, owner_id) VALUES ((SELECT id FROM ids WHERE n = 10), 'Súbeh s.r.o.', '88889901', true, (SELECT id FROM ids WHERE n = 1));
SELECT set_config('crm.market_price_correction', 'on', true);
UPDATE market_price_daily SET corrected_at = now() WHERE delivery_year = 2027 AND on_date = crm_today() AND corrected_at IS NULL;
SELECT set_config('crm.market_price_correction', '', true);
INSERT INTO market_price_daily (org_id, on_date, delivery_year, bl_eur_mwh, pl_eur_mwh, portfolio_eur_mwh, source)
VALUES (crm_default_org(), crm_today(), 2027, 95, 110, 96, 'rucne');
UPDATE app_setting SET value = to_jsonb(crm_today() - 30) WHERE key = 'commission_crm_from';
UPDATE app_setting SET value = 'true' WHERE key = 'deal_matching';
DO $$
DECLARE
  k integer;
  e text;
  c text;
  l text;
  v_im uuid;
  v_pipe uuid := (SELECT id FROM pipeline WHERE kind = 'b2b_dodavka' AND org_id IS NULL AND name = 'B2B dodávka');
BEGIN
  INSERT INTO contract_import (org_id, user_id, op_file_name) VALUES (crm_default_org(), (SELECT id FROM ids WHERE n = 2), 'subeh.xlsx') RETURNING id INTO v_im;
  FOR k IN 1..12 LOOP
    FOR i IN 0..1 LOOP
      e := NULL;
      FOREACH l IN ARRAY string_to_array('KLMNPQRSTUVW', NULL) LOOP
        FOREACH c IN ARRAY string_to_array('0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ', NULL) LOOP
          IF e IS NULL AND eic_is_valid('24ZZS000ZSUB' || l || lpad((k * 2 + i)::text, 2, '0') || c) THEN
            e := '24ZZS000ZSUB' || l || lpad((k * 2 + i)::text, 2, '0') || c;
          END IF;
        END LOOP;
      END LOOP;
      INSERT INTO oom (id, company_id, eic, type, status, voltage_level, planned_consumption_vt_mwh)
      VALUES ((SELECT id FROM ids WHERE n = 100 + k * 2 + i), (SELECT id FROM ids WHERE n = 10), e, 'spotreba', 'pripravovane', 'nn', 30);
    END LOOP;
    INSERT INTO deal (id, company_id, pipeline_id, stage_id, name, owner_id, source_code, supply_start)
    VALUES ((SELECT id FROM ids WHERE n = 300 + k), (SELECT id FROM ids WHERE n = 10), v_pipe,
            (SELECT id FROM pipeline_stage WHERE pipeline_id = v_pipe AND code = 'prilezitost'), 'Súbeh ' || k, (SELECT id FROM ids WHERE n = 1), 'web', '2027-01-01');
    INSERT INTO deal_oom (deal_id, oom_id) VALUES ((SELECT id FROM ids WHERE n = 300 + k), (SELECT id FROM ids WHERE n = 100 + k * 2)),
                                                  ((SELECT id FROM ids WHERE n = 300 + k), (SELECT id FROM ids WHERE n = 101 + k * 2));
    UPDATE deal SET stage_id = (SELECT id FROM pipeline_stage WHERE pipeline_id = v_pipe AND code = 'vyjednavanie') WHERE id = (SELECT id FROM ids WHERE n = 300 + k);
    FOR i IN 0..1 LOOP
      PERFORM set_config('app.contract_import_id', v_im::text, true);
      INSERT INTO contract (id, number, company_id, type, phase, valid_from, valid_to, signed_on, owner_id)
      VALUES ((SELECT id FROM ids WHERE n = 500 + k * 2 + i), 'SUB-' || k || CASE i WHEN 0 THEN 'A' ELSE 'B' END, (SELECT id FROM ids WHERE n = 10),
              'dodavka_firma_nn', 'podpisana', '2027-01-01', '2027-12-31', crm_today(), (SELECT id FROM ids WHERE n = 1));
      INSERT INTO contract_oom (contract_id, oom_id, qty_vt_mwh, product_id, valid_from, valid_to)
      VALUES ((SELECT id FROM ids WHERE n = 500 + k * 2 + i), (SELECT id FROM ids WHERE n = 100 + k * 2 + i), 30, (SELECT id FROM product WHERE code = 'green_1t'), '2027-01-01', '2027-12-31');
      INSERT INTO contract_price (contract_id, oom_id, slot, product_id, price_model, valid_from, valid_to, price_vt_eur_mwh)
      VALUES ((SELECT id FROM ids WHERE n = 500 + k * 2 + i), (SELECT id FROM ids WHERE n = 100 + k * 2 + i), 'komodita', (SELECT id FROM product WHERE code = 'green_1t'),
              'fix', '2027-01-01', '2027-12-31', 130 + k);
      PERFORM contract_basis_refresh((SELECT id FROM ids WHERE n = 500 + k * 2 + i));
      PERFORM set_config('app.contract_import_id', '', true);
      PERFORM set_config('app.require_user', 'on', true);
      PERFORM set_config('app.user_id', (SELECT id FROM ids WHERE n = 2)::text, true);
      PERFORM contract_deal_pick((SELECT id FROM ids WHERE n = 500 + k * 2 + i), (SELECT id FROM ids WHERE n = 300 + k));
      PERFORM set_config('app.user_id', '', true);
      PERFORM set_config('app.require_user', '', true);
    END LOOP;
  END LOOP;
END;
$$;
COMMIT;
SELECT commission_queue_run();
SQL
echo "Príprava: $(psql -XAtc "SELECT count(*) || ' obchodov s províziou' FROM commission WHERE deal_id::text LIKE '00000000-0000-4000-8000-000000a79%' AND status = 'caka'")"

ID="'00000000-0000-4000-8000-000000a79' || lpad(%s::text, 3, '0')"
id() { echo "('00000000-0000-4000-8000-000000a79' || lpad(($1)::text, 3, '0'))::uuid"; }

# ---------------------------------------------------------------------------
# Spojenia (každé kolo = jedna transakcia cez viac obchodov, krátke pauzy zvyšujú prekrytie)
# ---------------------------------------------------------------------------
gen_import() {   # $1 = A (0) / B (1), $2 = asc / desc
  for r in $(seq "$ROUNDS"); do
    cat <<SQL
DO \$\$
DECLARE k integer;
BEGIN
  PERFORM set_config('app.contract_import_id', (SELECT id::text FROM contract_import WHERE op_file_name = 'subeh.xlsx'), true);
  FOR k IN SELECT g FROM generate_series(1, 12) g ORDER BY g $( [[ "$2" == desc ]] && echo DESC ) LOOP
    UPDATE contract_price SET price_vt_eur_mwh = price_vt_eur_mwh + 0.01 WHERE contract_id = $(id "500 + k * 2 + $1");
    PERFORM pg_sleep(0.003);
  END LOOP;
END;
\$\$;
SQL
  done
}
gen_import 0 asc  > "$TMP/s1.sql"
gen_import 1 desc > "$TMP/s2.sql"
for r in $(seq "$ROUNDS"); do echo "SELECT commission_daily();"; done > "$TMP/s3.sql"
for r in $(seq $((ROUNDS * 3))); do echo "SELECT commission_queue_run(); SELECT pg_sleep(0.01);"; done > "$TMP/s4.sql"
for r in $(seq "$ROUNDS"); do
  cat <<SQL
DO \$\$
DECLARE k integer := 1 + ($r * 5) % 12;
BEGIN
  PERFORM set_config('app.require_user', 'on', true);
  PERFORM set_config('app.user_id', $(id 2)::text, true);
  PERFORM contract_deal_unlink($(id "500 + k * 2 + 1"), 'súbeh');
END;
\$\$;
DO \$\$
DECLARE k integer := 1 + ($r * 5) % 12;
BEGIN
  PERFORM set_config('app.require_user', 'on', true);
  PERFORM set_config('app.user_id', $(id 2)::text, true);
  PERFORM contract_deal_pick($(id "500 + k * 2 + 1"), $(id "300 + k"));
END;
\$\$;
SQL
done > "$TMP/s5.sql"
for r in $(seq "$ROUNDS"); do
  cat <<SQL
DO \$\$
DECLARE v uuid;
BEGIN
  PERFORM set_config('app.require_user', 'on', true);
  PERFORM set_config('app.user_id', $(id 1)::text, true);
  v := commission_claim_create($(id 1), ARRAY(SELECT id FROM commission WHERE user_id = $(id 1) AND status = 'caka' AND amount_eur > 0));
  PERFORM pg_sleep(0.02);
  PERFORM set_config('app.user_id', $(id 2)::text, true);
  PERFORM commission_claim_void(v, 'súbeh test');
EXCEPTION WHEN check_violation OR no_data_found THEN NULL;   -- nič na uplatnenie: neprekáža
END;
\$\$;
SQL
done > "$TMP/s6.sql"

for s in 1 2 3 4 5 6; do
  psql -X -q -v ON_ERROR_STOP=0 -f "$TMP/s$s.sql" > "$TMP/s$s.out" 2> "$TMP/s$s.err" &
done
wait

DEADLOCKS=$(cat "$TMP"/s*.err | grep -c "deadlock detected")
OTHER=$(cat "$TMP"/s*.err | grep "ERROR" | grep -vc "deadlock detected")
echo "Deadlocky: $DEADLOCKS, iné chyby: $OTHER"
cat "$TMP"/s*.err | grep "ERROR" | grep -v "deadlock detected" | sort | uniq -c | head -5

# ---------------------------------------------------------------------------
# Konzistencia po dobehnutí fronty a nočného prepočtu
# ---------------------------------------------------------------------------
psql -X -q -v ON_ERROR_STOP=1 <<SQL || exit 1
SELECT commission_queue_run();
SELECT commission_daily();
DO \$\$
DECLARE
  r   record;
  bad integer := 0;
BEGIN
  FOR r IN SELECT d.id,
                  coalesce((SELECT sum(amount_eur) FROM commission WHERE deal_id = d.id AND status IN ('caka', 'uplatnena')), 0) AS total,
                  (SELECT pct FROM commission WHERE deal_id = d.id AND status <> 'zrusena' ORDER BY created_at LIMIT 1) AS pct,
                  (SELECT base_eur FROM commission_deal_base(d.id)) AS base,
                  (SELECT count(*) FROM commission WHERE deal_id = d.id AND status = 'uplatnena') AS claimed
             FROM deal d WHERE d.id::text LIKE '00000000-0000-4000-8000-000000a79%' LOOP
    -- bez uplatnenia: čakajúca = cieľ zo zmlúv; s uplatnením (zamrznuté) aspoň jedna nezrušená položka
    IF r.claimed = 0 AND r.total <> round(greatest(r.base, 0) * r.pct / 100, 2) THEN
      bad := bad + 1;
      RAISE NOTICE 'Nesúhlasí obchod %: % vs %', r.id, r.total, round(greatest(r.base, 0) * r.pct / 100, 2);
    END IF;
  END LOOP;
  ASSERT NOT EXISTS (SELECT deal_id FROM commission WHERE status = 'caka' AND deal_id IS NOT NULL GROUP BY deal_id HAVING count(*) > 1), 'najviac jedna čakajúca';
  ASSERT bad = 0, 'provízie nezodpovedajú zmluvám: ' || bad;
  RAISE NOTICE 'OK: konzistencia – najviac jedna čakajúca na obchod, provízie bez uplatnenia zodpovedajú zmluvám';
END;
\$\$;
SQL
[[ "$DEADLOCKS" == "0" ]] || { echo "CHYBA: deadlock pri súbehu."; exit 2; }
echo "OK: súbeh bez deadlocku."

# ---------------------------------------------------------------------------
# Preskočený (obsadený) obchod sa nestratí (0055): spojenie A drží obchod 1, fronta ho preskočí a nechá vo fronte;
# stará položka (> 1 h) sa ohlási v denníku behov a adminom raz; po uvoľnení ju ďalší beh spracuje
# ---------------------------------------------------------------------------
DEAL1="$(id 301)"
psql -X -q -v ON_ERROR_STOP=1 -c "INSERT INTO commission_queue (deal_id, created_at) VALUES ($DEAL1, now() - interval '2 hours')" || exit 1
psql -X -q -c "BEGIN; SELECT 1 FROM deal WHERE id = $DEAL1 FOR NO KEY UPDATE; SELECT pg_sleep(4); COMMIT;" >/dev/null 2>&1 &
HOLDER=$!
sleep 1
psql -X -q -v ON_ERROR_STOP=1 <<SQL || exit 1
DO \$\$
DECLARE
  r1 jsonb;
  r2 jsonb;
  n0 integer := (SELECT count(*) FROM job_run WHERE job = 'provizie');
BEGIN
  r1 := commission_queue_run();
  ASSERT (r1->>'fronta_preskocene')::int = 1 AND EXISTS (SELECT 1 FROM commission_queue WHERE deal_id = $DEAL1), 'preskočený ostal vo fronte: ' || r1::text;
  ASSERT (r1->>'fronta_stara')::int = 1 AND (SELECT count(*) FROM job_run WHERE job = 'provizie') = n0 + 1, 'stará položka v denníku';
  RAISE NOTICE 'OK: obsadený obchod preskočený, ostal vo fronte, stará položka ohlásená';
END;
\$\$;
SQL
psql -X -q -v ON_ERROR_STOP=1 <<SQL || exit 1
DO \$\$
DECLARE
  r jsonb := commission_queue_run();
BEGIN
  ASSERT (r->>'fronta_preskocene')::int = 1 AND (r->>'fronta_stara')::int = 0, 'druhý beh: znova preskočený, bez nového hlásenia: ' || r::text;
  ASSERT (SELECT count(*) FROM notification WHERE kind = 'provizie_fronta' AND user_id = $(id 2)) = 1, 'upozornenie adminovi raz';
  RAISE NOTICE 'OK: druhý beh – položka stále vo fronte, ohlásená iba raz';
END;
\$\$;
SQL
wait "$HOLDER"
psql -X -q -v ON_ERROR_STOP=1 <<SQL || exit 1
DO \$\$
DECLARE
  r jsonb := commission_queue_run();
BEGIN
  ASSERT (r->>'fronta_preskocene')::int = 0 AND NOT EXISTS (SELECT 1 FROM commission_queue WHERE deal_id = $DEAL1), 'po uvoľnení spracovaná: ' || r::text;
  RAISE NOTICE 'OK: po uvoľnení obchodu sa položka spracovala – nestratila sa';
END;
\$\$;
SQL
echo "OK: preskočený obchod sa nestratil."

# ---------------------------------------------------------------------------
# Opakovanie po deadlocku v API (withRetry) so skutočnou databázou: jeden list, jedno číslo CMSN (api/test/retry-db.test.ts)
# ---------------------------------------------------------------------------
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
( cd "$ROOT/api" && CRM_TEST_DB_URL="postgres://${PGUSER}@${PGHOST}:${PGPORT:-5432}/${DB}" node --test test/retry-db.test.ts 2>&1 | grep -E "^(✔|✖|ℹ (pass|fail|skipped))" ) || exit 1
