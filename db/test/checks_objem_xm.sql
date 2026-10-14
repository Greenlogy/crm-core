-- Kontroly 0030: objem zmluvy (Office portal) vs. plánovaná spotreba OOM (XM Trade) – rozdiel nad 5 % (presne 5 % nie,
-- +6 % a −6 % áno), súčet viacerých OOM, chýbajúca plánovaná spotreba, krátka zmluva (XM × mesiace / 12), domácnosť áno,
-- výkup nie, skončená zmluva nie; nočný beh (denník, upozornenie obchodníkovi a schvaľovateľom raz, znova po zmene
-- objemu); upozornenie v importe.
-- Spúšťa sa iba cez db/test/run.sh po checks_male_podniky.sql (obchodník Z4 7501, schvaľovateľ 4001).
-- Kontroly sa pozerajú iba na vlastné záznamy (firma …-000000008201, OOM …-0000000080xxx, zmluvy …-0000000081xxx).

INSERT INTO company (id, name, ico, is_customer, owner_id) VALUES
  ('00000000-0000-4000-8000-000000008201', 'Objem Z6 s.r.o.', '99999961', true, '00000000-0000-4000-8000-000000007501');
INSERT INTO contact (id, first_name, last_name, email, is_household, owner_id) VALUES
  ('00000000-0000-4000-8000-000000008202', 'Domácnosť', 'Objem Z6', 'objem.z6@example.test', true, '00000000-0000-4000-8000-000000007501');

CREATE FUNCTION pg_temp.z6_eic(p_n integer) RETURNS text LANGUAGE plpgsql AS $f$
DECLARE
  l text;
  c text;
BEGIN
  FOREACH l IN ARRAY string_to_array('KLMNPQRSTUVW', NULL) LOOP
    FOREACH c IN ARRAY string_to_array('0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ', NULL) LOOP
      IF eic_is_valid('24ZZS000OBXM' || l || lpad(p_n::text, 2, '0') || c) THEN
        RETURN '24ZZS000OBXM' || l || lpad(p_n::text, 2, '0') || c;
      END IF;
    END LOOP;
  END LOOP;
END;
$f$;
CREATE FUNCTION pg_temp.z6_id(p_kind text, p_n integer) RETURNS uuid LANGUAGE sql AS $f$
  SELECT ('00000000-0000-4000-8000-0000000' || CASE p_kind WHEN 'oom' THEN '80' ELSE '81' END || lpad(p_n::text, 3, '0'))::uuid
$f$;
-- OOM firmy (alebo domácnosti) s plánovanou spotrebou VT z XM Trade (NULL = chýba), typ spotreba / výroba
CREATE FUNCTION pg_temp.z6_oom(p_n integer, p_xm numeric, p_person boolean DEFAULT false, p_type text DEFAULT 'spotreba')
RETURNS void LANGUAGE sql AS $f$
  INSERT INTO oom (id, company_id, person_id, eic, type, status, planned_consumption_vt_mwh, planned_feed_in_mwh)
  VALUES (pg_temp.z6_id('oom', p_n), CASE WHEN NOT p_person THEN '00000000-0000-4000-8000-000000008201'::uuid END,
          CASE WHEN p_person THEN '00000000-0000-4000-8000-000000008202'::uuid END, pg_temp.z6_eic(p_n), p_type::oom_type,
          'pripravovane', p_xm, CASE WHEN p_type = 'vyroba' THEN p_xm END)
$f$;
CREATE FUNCTION pg_temp.z6_k(p_n integer, p_from date, p_to date, p_type text DEFAULT 'dodavka_firma_nn', p_person boolean DEFAULT false)
RETURNS void LANGUAGE sql AS $f$
  INSERT INTO contract (id, number, company_id, person_id, type, phase, valid_from, valid_to, signed_on, owner_id)
  VALUES (pg_temp.z6_id('k', p_n), 'Z6-' || p_n, CASE WHEN NOT p_person THEN '00000000-0000-4000-8000-000000008201'::uuid END,
          CASE WHEN p_person THEN '00000000-0000-4000-8000-000000008202'::uuid END, p_type::contract_type, 'podpisana',
          p_from, p_to, p_from - 60, '00000000-0000-4000-8000-000000007501')
$f$;
CREATE FUNCTION pg_temp.z6_ko(p_k integer, p_o integer, p_qty numeric) RETURNS void LANGUAGE sql AS $f$
  INSERT INTO contract_oom (contract_id, oom_id, qty_vt_mwh, product_id)
  VALUES (pg_temp.z6_id('k', p_k), pg_temp.z6_id('oom', p_o), p_qty, (SELECT id FROM product WHERE code = 'green_1t'))
$f$;
CREATE FUNCTION pg_temp.z6(p_k integer) RETURNS record LANGUAGE sql AS $f$
  SELECT (d.over, d.diff_pct, d.contract_mwh, d.xm_mwh, d.oom_over, d.xm_missing, d.months, d.message)
    FROM contract_volume_diff('2027-06-01', pg_temp.z6_id('k', p_k)) d
$f$;

-- Z6-1. Pravidlo 5 %
DO $$
DECLARE
  d record;
BEGIN
  -- 1: 10 / 10; 2: 10,5 / 10 (presne 5 %); 3: 10,6 / 10 (+6 %); 4: 9,4 / 10 (−6 %)
  PERFORM pg_temp.z6_oom(1, 10); PERFORM pg_temp.z6_k(1, '2027-01-01', '2027-12-31'); PERFORM pg_temp.z6_ko(1, 1, 10);
  PERFORM pg_temp.z6_oom(2, 10); PERFORM pg_temp.z6_k(2, '2027-01-01', '2027-12-31'); PERFORM pg_temp.z6_ko(2, 2, 10.5);
  PERFORM pg_temp.z6_oom(3, 10); PERFORM pg_temp.z6_k(3, '2027-01-01', '2027-12-31'); PERFORM pg_temp.z6_ko(3, 3, 10.6);
  PERFORM pg_temp.z6_oom(4, 10); PERFORM pg_temp.z6_k(4, '2027-01-01', '2027-12-31'); PERFORM pg_temp.z6_ko(4, 4, 9.4);
  -- 5: dve OOM 10/10 a 12/10 → 22 / 20 = +10 %, rozdiel pri 1 z 2 OOM
  PERFORM pg_temp.z6_oom(5, 10); PERFORM pg_temp.z6_oom(6, 10); PERFORM pg_temp.z6_k(5, '2027-01-01', '2027-12-31');
  PERFORM pg_temp.z6_ko(5, 5, 10); PERFORM pg_temp.z6_ko(5, 6, 12);
  -- 6: XM Trade chýba pri jednom OOM → neporovnáva sa
  PERFORM pg_temp.z6_oom(7, 10); PERFORM pg_temp.z6_oom(8, NULL); PERFORM pg_temp.z6_k(6, '2027-01-01', '2027-12-31');
  PERFORM pg_temp.z6_ko(6, 7, 30); PERFORM pg_temp.z6_ko(6, 8, 30);
  -- 7: krátka zmluva 6 mesiacov, 5 MWh za obdobie vs. XM 10 / rok → 5 / 5 v tolerancii
  PERFORM pg_temp.z6_oom(9, 10); PERFORM pg_temp.z6_k(7, '2027-01-01', '2027-06-30'); PERFORM pg_temp.z6_ko(7, 9, 5);
  -- 8: domácnosť 4 / 3 → +33,3 %
  PERFORM pg_temp.z6_oom(10, 3, true); PERFORM pg_temp.z6_k(8, '2027-01-01', NULL, 'dodavka_domacnost', true);
  PERFORM pg_temp.z6_ko(8, 10, 4);
  -- 9: výkup (výroba) – nehodnotí sa; 10: skončená zmluva 2026 – nehodnotí sa
  PERFORM pg_temp.z6_oom(11, 10, false, 'vyroba'); PERFORM pg_temp.z6_k(9, '2027-01-01', '2027-12-31', 'vykup');
  PERFORM pg_temp.z6_ko(9, 11, 50);
  PERFORM pg_temp.z6_oom(12, 10); PERFORM pg_temp.z6_k(10, '2026-01-01', '2026-12-31'); PERFORM pg_temp.z6_ko(10, 12, 50);

  SELECT * INTO d FROM pg_temp.z6(1) AS (over boolean, pct numeric, k numeric, x numeric, oo int, xm int, m int, msg text);
  ASSERT NOT d.over AND d.pct = 0 AND d.msg LIKE '%v tolerancii 5 %%', '10 / 10 – ' || d::text;
  SELECT * INTO d FROM pg_temp.z6(2) AS (over boolean, pct numeric, k numeric, x numeric, oo int, xm int, m int, msg text);
  ASSERT NOT d.over AND d.pct = 5.0, 'presne 5 % nie – ' || d::text;
  SELECT * INTO d FROM pg_temp.z6(3) AS (over boolean, pct numeric, k numeric, x numeric, oo int, xm int, m int, msg text);
  ASSERT d.over AND d.pct = 6.0
     AND d.msg = 'Objem podľa zmluvy 10,6 MWh, podľa XM Trade 10 MWh (+6,0 %) – rozdiel nad 5 %, overte zmluvné množstvo (ovplyvňuje pridanú hodnotu a províziu).',
         '+6 % – ' || d::text;
  SELECT * INTO d FROM pg_temp.z6(4) AS (over boolean, pct numeric, k numeric, x numeric, oo int, xm int, m int, msg text);
  ASSERT d.over AND d.pct = -6.0 AND d.msg LIKE '%(−6,0 %%)%', '−6 % – ' || d::text;
  SELECT * INTO d FROM pg_temp.z6(5) AS (over boolean, pct numeric, k numeric, x numeric, oo int, xm int, m int, msg text);
  ASSERT d.over AND d.k = 22 AND d.x = 20 AND d.oo = 1 AND d.msg LIKE '%rozdiel pri 1 z 2 OOM%', 'dve OOM – ' || d::text;
  SELECT * INTO d FROM pg_temp.z6(6) AS (over boolean, pct numeric, k numeric, x numeric, oo int, xm int, m int, msg text);
  ASSERT NOT d.over AND d.x IS NULL AND d.xm = 1 AND d.msg LIKE 'XM Trade bez plánovanej spotreby pri 1 z 2 OOM%', 'XM chýba – ' || d::text;
  SELECT * INTO d FROM pg_temp.z6(7) AS (over boolean, pct numeric, k numeric, x numeric, oo int, xm int, m int, msg text);
  ASSERT NOT d.over AND d.m = 6 AND d.x = 5, 'krátka zmluva – ' || d::text;
  SELECT * INTO d FROM pg_temp.z6(8) AS (over boolean, pct numeric, k numeric, x numeric, oo int, xm int, m int, msg text);
  ASSERT d.over AND d.pct = 33.3, 'domácnosť – ' || d::text;
  ASSERT NOT EXISTS (SELECT 1 FROM contract_volume_diff('2027-06-01', pg_temp.z6_id('k', 9)))
     AND NOT EXISTS (SELECT 1 FROM contract_volume_diff('2027-06-01', pg_temp.z6_id('k', 10))), 'výkup a skončená zmluva nie';
  RAISE NOTICE 'OK: Z6-1 objem vs. XM Trade: 5 %% nie, ±6 %% áno, súčet OOM, XM chýba, krátka zmluva, domácnosť; výkup a skončená nie';
END;
$$;

-- Z6-2. Import a nočný beh
DO $$
DECLARE
  r     jsonb;
  v_res jsonb;
BEGIN
  v_res := contract_import_small_business(jsonb_build_object('contracts', jsonb_build_array(
             jsonb_build_object('contract_id', pg_temp.z6_id('k', 3), 'warnings', '[]'::jsonb),
             jsonb_build_object('contract_id', pg_temp.z6_id('k', 1), 'warnings', '[]'::jsonb))));
  ASSERT v_res #>> '{contracts,0,warnings,0}' LIKE 'Objem podľa zmluvy 10,6 MWh%' AND v_res #> '{contracts,1,warnings}' = '[]',
         'import: upozornenie iba pri rozdiele nad 5 % – ' || v_res::text;

  r := contract_daily_run_at('2027-06-01');
  ASSERT r -> 'objem_xm' -> 'zmluvy' ?& ARRAY['Z6-3', 'Z6-4', 'Z6-5', 'Z6-8']
     AND NOT (r -> 'objem_xm' -> 'zmluvy' ?| ARRAY['Z6-1', 'Z6-2', 'Z6-6', 'Z6-7', 'Z6-9', 'Z6-10']),
         'denník: zmluvy s rozdielom nad 5 % – ' || (r -> 'objem_xm')::text;
  ASSERT (SELECT array_agg(user_id ORDER BY user_id) FROM notification
           WHERE contract_id = pg_temp.z6_id('k', 3) AND kind = 'objem_xm')
         @> ARRAY['00000000-0000-4000-8000-000000004001', '00000000-0000-4000-8000-000000007501']::uuid[],
         'upozornenie obchodníkovi a schvaľovateľovi cien';
  r := contract_daily_run_at('2027-06-02');
  ASSERT (SELECT count(DISTINCT detail) FROM notification WHERE contract_id = pg_temp.z6_id('k', 3) AND kind = 'objem_xm') = 1
     AND (SELECT count(*) FROM notification WHERE contract_id = pg_temp.z6_id('k', 3) AND kind = 'objem_xm'
             AND user_id = '00000000-0000-4000-8000-000000007501') = 1, 'bez zmeny objemu znova nie';
  UPDATE oom SET planned_consumption_vt_mwh = 9 WHERE id = pg_temp.z6_id('oom', 3);
  r := contract_daily_run_at('2027-06-03');
  ASSERT (SELECT count(DISTINCT detail) FROM notification WHERE contract_id = pg_temp.z6_id('k', 3) AND kind = 'objem_xm') = 2,
         'po zmene objemu v XM Trade nové upozornenie';
  RAISE NOTICE 'OK: Z6-2 import, nočný beh: denník, upozornenie obchodníkovi a schvaľovateľom raz, znova po zmene objemu';
END;
$$;
