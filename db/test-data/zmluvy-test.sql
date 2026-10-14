-- Testovacie zmluvy pre nočný beh (modul 4, F4) na Teste (Neon dev) – iba vymyslené údaje so znakom „TEST“.
-- Na každý prípad aspoň jedna zmluva: prolongácia, odídené OOM pred koncom, zmluva bez aktívneho OOM (Ukončená),
-- upozornenie 4 mesiace pred koncom, nástupca (retencia), zmena cenovej regulácie, nový cenník,
-- malý podnik nad 30 MWh a do 30 MWh (0029), objem zmluvy ≠ XM Trade o viac ako 5 % (0030).
-- Dátumy sú odvodené od dneška (crm_today()), na konci sa vypíšu dátumy, ku ktorým beh spustiť.
-- Spúšťa sa iba cez db/test-data/zmluvy-test.sh (jedna transakcia). Zmazanie: zmluvy-test-delete.sql.
-- Pevné id s predponou 7e570000-0000-4000-9000-… (7e57 = „test“), čísla zmlúv TEST-NB-…, aby sa dali presne zmazať.
-- Cenník a produkt „TEST – nočný beh“ ostávajú aj po zmazaní (schválená verzia cenníka sa nemaže); ďalšie
-- „vytvor“ ich použije znova a pridá novú verziu.

\set ON_ERROR_STOP on
\o /dev/null
BEGIN;
SET LOCAL app.change_source = 'system';

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM contract WHERE id::text LIKE '7e570000-0000-4000-9000-%' OR number LIKE 'TEST-NB-%')
     OR EXISTS (SELECT 1 FROM oom WHERE id::text LIKE '7e570000-0000-4000-9000-%')
     OR EXISTS (SELECT 1 FROM company WHERE id::text LIKE '7e570000-0000-4000-9000-%')
     OR EXISTS (SELECT 1 FROM contact WHERE id::text LIKE '7e570000-0000-4000-9000-%') THEN
    RAISE EXCEPTION 'Testovacie zmluvy nočného behu už existujú. Najprv ich zmaž (zmluvy-test.sh dev zmaz).';
  END IF;
END;
$$;

CREATE FUNCTION pg_temp.id(n integer) RETURNS uuid LANGUAGE sql IMMUTABLE AS $f$
  SELECT ('7e570000-0000-4000-9000-' || lpad(n::text, 12, '0'))::uuid
$f$;
-- EIC s platnou kontrolnou číslicou: '24ZZS9TESN' + 5 číslic + kontrolný znak
CREATE FUNCTION pg_temp.eic(n integer) RETURNS text LANGUAGE plpgsql AS $f$
DECLARE
  b text;
  c text;
BEGIN
  FOREACH b IN ARRAY ARRAY['24ZZS9TESN', '24ZZS9TESM'] LOOP
    FOREACH c IN ARRAY string_to_array('0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ', NULL) LOOP
      IF eic_is_valid(b || lpad(n::text, 5, '0') || c) THEN RETURN b || lpad(n::text, 5, '0') || c; END IF;
    END LOOP;
  END LOOP;
  RAISE EXCEPTION 'EIC pre % bez platnej kontrolnej číslice', n;
END;
$f$;
CREATE FUNCTION pg_temp.peter() RETURNS uuid LANGUAGE sql STABLE AS $f$
  SELECT id FROM app_user WHERE email = 'peter@greenlogy.com'
$f$;
-- OOM spotreby firmy (101) alebo domácnosti (102); Odídené cez oom_set_status
CREATE FUNCTION pg_temp.oom(n integer, p_household boolean DEFAULT false, p_regulation boolean DEFAULT NULL,
                            p_left boolean DEFAULT false, p_company integer DEFAULT 101, p_xm numeric DEFAULT NULL)
RETURNS uuid LANGUAGE plpgsql AS $f$
BEGIN
  INSERT INTO oom (id, company_id, person_id, eic, type, status, name, price_regulation, address_city, planned_consumption_vt_mwh)
  VALUES (pg_temp.id(n), CASE WHEN NOT p_household THEN pg_temp.id(p_company) END, CASE WHEN p_household THEN pg_temp.id(102) END,
          pg_temp.eic(n), 'spotreba', 'pripravovane', 'TEST OOM nočný beh ' || n, p_regulation, 'Bytča', p_xm);
  IF p_left THEN
    PERFORM oom_set_status(pg_temp.id(n), 'odidene', crm_today());
  END IF;
  RETURN pg_temp.id(n);
END;
$f$;
CREATE FUNCTION pg_temp.k(n integer, p_number text, p_type text, p_from date, p_to date, p_prolong boolean,
                          p_household boolean DEFAULT false, p_list boolean DEFAULT false, p_company integer DEFAULT 101)
RETURNS uuid LANGUAGE sql AS $f$
  INSERT INTO contract (id, number, company_id, person_id, type, phase, valid_from, valid_to, signed_on, owner_id,
                        list_price, auto_prolong, note, small_business)
  VALUES (pg_temp.id(n), p_number, CASE WHEN NOT p_household THEN pg_temp.id(p_company) END,
          CASE WHEN p_household THEN pg_temp.id(102) END, p_type::contract_type, 'podpisana', p_from, p_to,
          least(p_from - 30, crm_today()), pg_temp.peter(), p_list, p_prolong, 'TEST nočný beh', p_list AND NOT p_household)
  RETURNING id
$f$;
CREATE FUNCTION pg_temp.ko(p_k integer, p_o integer, p_product text, p_vt numeric DEFAULT 10, p_nt numeric DEFAULT 0)
RETURNS void LANGUAGE sql AS $f$
  INSERT INTO contract_oom (contract_id, oom_id, qty_vt_mwh, qty_nt_mwh, product_id)
  VALUES (pg_temp.id(p_k), pg_temp.id(p_o), p_vt, p_nt, (SELECT id FROM product WHERE code = p_product))
$f$;
-- Individuálna cena FIX (pri dvojtarife aj NT) pre všetky OOM zmluvy
CREATE FUNCTION pg_temp.fix(p_k integer, p_from date, p_to date) RETURNS void LANGUAGE sql AS $f$
  INSERT INTO contract_price (contract_id, oom_id, slot, product_id, price_model, valid_from, valid_to,
                              price_vt_eur_mwh, price_nt_eur_mwh, op_product_name)
  SELECT co.contract_id, co.oom_id, 'komodita', co.product_id, 'fix', p_from, p_to, 140,
         CASE WHEN co.qty_nt_mwh > 0 THEN 120 END, 'TEST'
    FROM contract_oom co WHERE co.contract_id = pg_temp.id(p_k)
$f$;
CREATE FUNCTION pg_temp.ready(p_k integer) RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  PERFORM contract_price_list_sync(pg_temp.id(p_k));
  PERFORM contract_after_price_change(pg_temp.id(p_k));
END;
$f$;

-- Zákazníci: firma a domácnosť (vlastník Peter)
INSERT INTO company (id, name, ico, is_customer, owner_id, address) VALUES
  (pg_temp.id(101), 'TEST Nočný beh s.r.o.', '99000201', true, pg_temp.peter(), 'Priemyselná 1, 014 01 Bytča'),
  (pg_temp.id(103), 'TEST Malý podnik nad 30 s.r.o.', '99000203', true, pg_temp.peter(), 'Hlavná 3, 014 01 Bytča'),
  (pg_temp.id(104), 'TEST Malý podnik do 30 s.r.o.', '99000204', true, pg_temp.peter(), 'Hlavná 4, 014 01 Bytča');
INSERT INTO contact (id, first_name, last_name, email, is_household, owner_id, address) VALUES
  (pg_temp.id(102), 'TEST Nočná', 'Domácnosť', 'test.nocny.beh@example.test', true, pg_temp.peter(), 'Hlavná 1, 014 01 Bytča');

DO $$
DECLARE
  t      date := crm_today();
  y0     date := date_trunc('year', crm_today())::date;
  y1     date := (date_trunc('year', crm_today()) + interval '1 year')::date;
  e4     date := (date_trunc('month', crm_today()) + interval '5 months')::date - 1;
  m1     date := (date_trunc('month', crm_today()) + interval '1 month')::date;
  v_list uuid;
  v_prod uuid;
  v_ver  uuid;
  v_last price_list_version;
  v_new  uuid;
BEGIN
  -- 01 Prolongácia: firma FIX do konca roka s automatickou prolongáciou, OOM 1T a 2T
  PERFORM pg_temp.k(1, 'TEST-NB-01', 'dodavka_firma_nn', y0, y1 - 1, true);
  PERFORM pg_temp.oom(11); PERFORM pg_temp.oom(12);
  PERFORM pg_temp.ko(1, 11, 'green_1t'); PERFORM pg_temp.ko(1, 12, 'green_2t', 6, 4);
  PERFORM pg_temp.fix(1, y0, y1 - 1);
  -- 02 Odídené OOM pred koncom: predĺži sa iba Pripravované OOM
  PERFORM pg_temp.k(2, 'TEST-NB-02', 'dodavka_firma_nn', y0, y1 - 1, true);
  PERFORM pg_temp.oom(21); PERFORM pg_temp.oom(22, p_left => true);
  PERFORM pg_temp.ko(2, 21, 'green_1t'); PERFORM pg_temp.ko(2, 22, 'green_1t');
  PERFORM pg_temp.fix(2, y0, y1 - 1);
  -- 03 Bez aktívneho OOM: nepredĺži sa, fáza Ukončená, upozornenie obchodníkovi
  PERFORM pg_temp.k(3, 'TEST-NB-03', 'dodavka_firma_nn', y0, y1 - 1, true);
  PERFORM pg_temp.oom(31, p_left => true);
  PERFORM pg_temp.ko(3, 31, 'green_1t');
  PERFORM pg_temp.fix(3, y0, y1 - 1);
  -- 04 Upozornenie 4 mesiace pred koncom: firma bez prolongácie, koniec o 4–5 mesiacov
  PERFORM pg_temp.k(4, 'TEST-NB-04', 'dodavka_firma_nn', y0, e4, false);
  PERFORM pg_temp.oom(41);
  PERFORM pg_temp.ko(4, 41, 'green_1t');
  PERFORM pg_temp.fix(4, y0, e4);
  -- 05 + 06 Nástupca (retencia): stará do konca roka s prolongáciou, nová od 1. 1. na tom istom OOM
  PERFORM pg_temp.k(5, 'TEST-NB-05', 'dodavka_firma_nn', y0, y1 - 1, true);
  PERFORM pg_temp.oom(51);
  PERFORM pg_temp.ko(5, 51, 'green_1t');
  PERFORM pg_temp.fix(5, y0, y1 - 1);
  PERFORM pg_temp.k(6, 'TEST-NB-06', 'dodavka_firma_nn', y1, (y1 + interval '1 year')::date - 1, false);
  PERFORM pg_temp.ko(6, 51, 'green_1t');
  PERFORM pg_temp.fix(6, y1, (y1 + interval '1 year')::date - 1);
  -- 07 Zmena regulácie: domácnosť DD2 ANO na dobu neurčitú, od 1. dňa budúceho mesiaca NIE
  PERFORM pg_temp.k(7, 'TEST-NB-07', 'dodavka_domacnost', y0, NULL, false, true, true);
  PERFORM pg_temp.oom(71, true, true);
  PERFORM pg_temp.ko(7, 71, 'green_dd2_ano', 3);

  -- 08 Nový cenník: samostatný cenník a produkt „TEST – nočný beh“ (iba tejto zmluvy)
  SELECT id INTO v_prod FROM product WHERE code = 'test_nocny_beh' AND org_id = crm_default_org();
  IF v_prod IS NULL THEN
    INSERT INTO product (org_id, code, name, category, segment, vat_rate, tariff_type, price_models, status)
    SELECT crm_default_org(), 'test_nocny_beh', 'TEST – nočný beh (produkt)', 'dodavka_domacnost', 'domacnost', vat_rate,
           'jednotarif', '{cennik}', 'predava_sa'
      FROM product WHERE code = 'green_dd2_nie'
    RETURNING id INTO v_prod;
  END IF;
  SELECT id INTO v_list FROM price_list WHERE code = 'test_nocny_beh' AND org_id = crm_default_org();
  IF v_list IS NULL THEN
    INSERT INTO price_list (org_id, code, name, segment, description)
    VALUES (crm_default_org(), 'test_nocny_beh', 'TEST – nočný beh', 'domacnost', 'testovací cenník skriptu zmluvy-test.sh')
    RETURNING id INTO v_list;
    INSERT INTO price_list_version (price_list_id, name, valid_from, note)
    VALUES (v_list, 'TEST 1', y0, 'zmluvy-test.sh') RETURNING id INTO v_ver;
    INSERT INTO price_list_item (version_id, product_id, price_vt_eur_mwh, fee_oom_eur_month)
    VALUES (v_ver, v_prod, 150, 1.5);
    PERFORM price_list_version_approve(v_ver);
  END IF;
  PERFORM pg_temp.k(8, 'TEST-NB-08', 'dodavka_domacnost', y0, NULL, false, true, true);
  PERFORM pg_temp.oom(81, true);
  PERFORM pg_temp.ko(8, 81, 'test_nocny_beh', 3);

  -- 09 Malý podnik nad 30 MWh: DMP1 na dvoch OOM 18 + 15 MWh (XM Trade 18 + 15) → „treba vyradiť z regulácie“
  PERFORM pg_temp.k(9, 'TEST-NB-09', 'dodavka_firma_nn', y0, y1 - 1, false, false, true, 103);
  PERFORM pg_temp.oom(91, false, true, false, 103, 18); PERFORM pg_temp.oom(92, false, true, false, 103, 15);
  PERFORM pg_temp.ko(9, 91, 'green_dmp1', 18); PERFORM pg_temp.ko(9, 92, 'green_dmp1', 15);
  -- 10 Malý podnik do 30 MWh: DMP1 20 MWh (XM Trade 20) → „ostáva v regulácii“
  PERFORM pg_temp.k(10, 'TEST-NB-10', 'dodavka_firma_nn', y0, y1 - 1, false, false, true, 104);
  PERFORM pg_temp.oom(93, false, true, false, 104, 20);
  PERFORM pg_temp.ko(10, 93, 'green_dmp1', 20);

  -- 11 Objem ≠ XM Trade: firma 12 MWh v zmluve, XM Trade 10 MWh (+20 %) → upozornenie obchodníkovi a schvaľovateľom
  PERFORM pg_temp.k(11, 'TEST-NB-11', 'dodavka_firma_nn', y0, y1 - 1, false);
  PERFORM pg_temp.oom(94, p_xm => 10);
  PERFORM pg_temp.ko(11, 94, 'green_1t', 12);
  PERFORM pg_temp.fix(11, y0, y1 - 1);

  FOR n IN 1..11 LOOP
    PERFORM pg_temp.ready(n);
  END LOOP;

  -- až po cenách zmlúv: zmena regulácie (07) a nová verzia testového cenníka (08) – uplatní ich nočný beh
  PERFORM oom_price_regulation_set(pg_temp.id(71), false, m1);
  SELECT * INTO v_last FROM price_list_version
   WHERE price_list_id = v_list AND status = 'schvalena' ORDER BY valid_from DESC LIMIT 1;
  v_new := (price_list_version_copy(v_last.id, 'TEST od ' || to_char(greatest(t, v_last.valid_from + 1), 'DD. MM. YYYY'),
                                    greatest(t, v_last.valid_from + 1)) ->> 'version_id')::uuid;
  UPDATE price_list_item SET price_vt_eur_mwh = price_vt_eur_mwh + 10 WHERE version_id = v_new;
  PERFORM price_list_version_approve(v_new);

  CREATE TEMP TABLE t_dates AS
  SELECT * FROM (VALUES
    (1, 'nanecisto / beh ' || to_char(e4 - interval '4 months', 'YYYY-MM-DD'), 'TEST-NB-04: upozornenie 4 mesiace pred koncom'),
    (2, 'nanecisto / beh ' || to_char(m1, 'YYYY-MM-DD'), 'TEST-NB-07: regulácia NIE; TEST-NB-08: nový cenník platný od dneška → v denníku ako spätne zapísaný'),
    (3, 'nanecisto / beh ' || to_char(y1, 'YYYY-MM-DD'), 'TEST-NB-01 prolongácia, 02 odídené OOM, 03 Ukončená, 05/06 nástupca'),
    (4, 'nanecisto / beh ' || to_char(t, 'YYYY-MM-DD'), 'TEST-NB-09 malý podnik nad 30 MWh, TEST-NB-11 objem ≠ XM Trade (denník, upozornenia); karty TEST-NB-09, 10, 11: hlášky')
  ) AS x (poradie, prikaz, co_sa_stane);
END;
$$;

COMMIT;
\o

SELECT k.number AS zmluva, k.type AS typ, k.valid_from AS od, k.valid_to AS do, k.auto_prolong AS prolongacia,
       (SELECT count(*) FROM contract_oom co WHERE co.contract_id = k.id) AS oom
  FROM contract k WHERE k.id::text LIKE '7e570000-0000-4000-9000-%' ORDER BY k.number;
SELECT prikaz AS "Spusti (zmluvy-test.sh dev …)", co_sa_stane AS "Čo sa stane" FROM t_dates ORDER BY poradie;
