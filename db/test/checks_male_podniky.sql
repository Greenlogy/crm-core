-- Kontroly 0029: malý podnik a hranica 30 MWh (zmluvy aj XM Trade, súbežne účinné zmluvy, presne 30 = ostáva, 30,001 =
-- vyradiť, nesúlad, chýbajúca plánovaná spotreba, neregulovaný zákazník), upozornenie v importe, nočný beh (denník,
-- upozornenie raz za rok), bod 3 (vyradený nad 30 MWh = „Chýba cena“, nie chyba behu), uzatváranie príznakov
-- („Pod hranicou“ iba schvaľovateľ s poznámkou, „Chýba cena“ iba databáza, príznak sa dá iba uzavrieť).
-- Spúšťa sa iba cez db/test/run.sh po checks_zmluvy_nocny_beh.sql (používa obchodníka Z4 7501 a schvaľovateľa 4001).
-- Kontroly sa pozerajú iba na vlastné záznamy (…-00000000780x firmy, …-0000000078xxx OOM, …-0000000079xxx zmluvy).

INSERT INTO company (id, name, ico, is_customer, owner_id)
SELECT ('00000000-0000-4000-8000-00000000780' || n)::uuid, 'Malý podnik Z5-' || n || ' s.r.o.', '9999995' || n, true,
       '00000000-0000-4000-8000-000000007501'
  FROM generate_series(1, 6) n;

CREATE FUNCTION pg_temp.z5_eic(p_n integer) RETURNS text LANGUAGE plpgsql AS $f$
DECLARE
  l text;
  c text;
BEGIN
  FOREACH l IN ARRAY string_to_array('KLMNPQRSTUVW', NULL) LOOP
    FOREACH c IN ARRAY string_to_array('0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ', NULL) LOOP
      IF eic_is_valid('24ZZS000MAPO' || l || lpad(p_n::text, 2, '0') || c) THEN
        RETURN '24ZZS000MAPO' || l || lpad(p_n::text, 2, '0') || c;
      END IF;
    END LOOP;
  END LOOP;
END;
$f$;
CREATE FUNCTION pg_temp.z5_id(p_kind text, p_n integer) RETURNS uuid LANGUAGE sql AS $f$
  SELECT ('00000000-0000-4000-8000-0000000' || CASE p_kind WHEN 'oom' THEN '78' ELSE '79' END || lpad(p_n::text, 3, '0'))::uuid
$f$;
CREATE FUNCTION pg_temp.z5_co(p_c integer) RETURNS uuid LANGUAGE sql AS $f$
  SELECT ('00000000-0000-4000-8000-00000000780' || p_c)::uuid
$f$;
-- OOM firmy p_c s plánovanou spotrebou z XM Trade (NULL = chýba) a reguláciou
CREATE FUNCTION pg_temp.z5_oom(p_n integer, p_c integer, p_xm numeric, p_reg boolean DEFAULT true) RETURNS void LANGUAGE sql AS $f$
  INSERT INTO oom (id, company_id, eic, type, status, price_regulation, planned_consumption_vt_mwh)
  VALUES (pg_temp.z5_id('oom', p_n), pg_temp.z5_co(p_c), pg_temp.z5_eic(p_n), 'spotreba', 'pripravovane', p_reg, p_xm)
$f$;
-- Zmluva firmy p_c (malý podnik s cenníkom DMP1, alebo individuálna Green 1T) s jedným OOM a množstvom
CREATE FUNCTION pg_temp.z5_k(p_n integer, p_c integer, p_o integer, p_qty numeric, p_from date, p_to date,
                             p_small boolean DEFAULT true) RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  INSERT INTO contract (id, number, company_id, type, phase, valid_from, valid_to, signed_on, owner_id, list_price, small_business)
  VALUES (pg_temp.z5_id('k', p_n), 'Z5-' || p_n, pg_temp.z5_co(p_c), 'dodavka_firma_nn', 'podpisana', p_from, p_to,
          p_from - 60, '00000000-0000-4000-8000-000000007501', p_small, p_small);
  INSERT INTO contract_oom (contract_id, oom_id, qty_vt_mwh, product_id)
  VALUES (pg_temp.z5_id('k', p_n), pg_temp.z5_id('oom', p_o), p_qty,
          (SELECT id FROM product WHERE code = CASE WHEN p_small THEN 'green_dmp1' ELSE 'green_1t' END));
  PERFORM contract_price_list_sync(pg_temp.z5_id('k', p_n));
END;
$f$;
CREATE FUNCTION pg_temp.z5_state(p_c integer) RETURNS text LANGUAGE sql AS $f$
  SELECT state FROM small_business_volume('2027-06-01', pg_temp.z5_co(p_c))
$f$;

-- Z5-1. Objem a stav k 1. 6. 2027
DO $$
DECLARE
  r record;
BEGIN
  -- 1: 20 MWh zmluvy aj XM → ostáva; 2: presne 30 → ostáva; 3: 30,001 → vyradiť
  PERFORM pg_temp.z5_oom(1, 1, 20); PERFORM pg_temp.z5_k(1, 1, 1, 20, '2027-01-01', '2027-12-31');
  PERFORM pg_temp.z5_oom(2, 2, 30); PERFORM pg_temp.z5_k(2, 2, 2, 30, '2027-01-01', '2027-12-31');
  PERFORM pg_temp.z5_oom(3, 3, 30.001); PERFORM pg_temp.z5_k(3, 3, 3, 30.001, '2027-01-01', '2027-12-31');
  -- 4: dve OOM v dvoch súbežných zmluvách 15 + 16 = 31 (XM 14 + 15 = 29) → nesúlad; skončená zmluva 50 MWh sa nepočíta
  PERFORM pg_temp.z5_oom(4, 4, 14); PERFORM pg_temp.z5_oom(5, 4, 15); PERFORM pg_temp.z5_oom(6, 4, 50);
  PERFORM pg_temp.z5_k(4, 4, 4, 15, '2027-01-01', '2027-12-31');
  PERFORM pg_temp.z5_k(5, 4, 5, 16, '2027-03-01', '2027-12-31');
  PERFORM pg_temp.z5_k(6, 4, 6, 50, '2026-01-01', '2026-12-31');
  -- 5: neregulovaný zákazník 40 MWh (individuálna cena, OOM bez regulácie) → bez stavu
  PERFORM pg_temp.z5_oom(7, 5, 40, NULL); PERFORM pg_temp.z5_k(7, 5, 7, 40, '2027-01-01', '2027-12-31', false);
  -- 6: zmluvy 35 MWh, XM Trade bez plánovanej spotreby → vyradiť
  PERFORM pg_temp.z5_oom(8, 6, NULL); PERFORM pg_temp.z5_k(8, 6, 8, 35, '2027-01-01', '2027-12-31');

  ASSERT pg_temp.z5_state(1) = 'ostava' AND pg_temp.z5_state(2) = 'ostava' AND pg_temp.z5_state(3) = 'vyradit',
         '20 a 30 MWh ostáva, 30,001 vyradiť: ' || concat_ws(' / ', pg_temp.z5_state(1), pg_temp.z5_state(2), pg_temp.z5_state(3));
  SELECT * INTO r FROM small_business_volume('2027-06-01', pg_temp.z5_co(4));
  ASSERT r.state = 'nesulad' AND r.contract_mwh = 31 AND r.xm_mwh = 29 AND r.oom_count = 2,
         'súbežné zmluvy 15 + 16, skončená sa nepočíta, XM 29 → nesúlad – ' || r::text;
  ASSERT (SELECT state FROM small_business_volume('2027-02-01', pg_temp.z5_co(4))) = 'ostava', 'k 1. 2. iba prvá zmluva (15 MWh)';
  ASSERT pg_temp.z5_state(5) IS NULL, 'neregulovaný zákazník bez stavu';
  SELECT * INTO r FROM small_business_volume('2027-06-01', pg_temp.z5_co(6));
  ASSERT r.state = 'vyradit' AND r.message LIKE '%XM Trade bez plánovanej spotreby%', 'XM chýba: ' || r.message;
  ASSERT (SELECT message FROM small_business_volume('2027-06-01', pg_temp.z5_co(3))) LIKE 'Pozor: ročný objem nad 30 MWh (zmluvy 30,001 MWh, XM Trade 30,001 MWh)%nemá nárok na regulovaný cenník%'
     AND (SELECT message FROM small_business_volume('2027-06-01', pg_temp.z5_co(1))) LIKE '%zákazník ostáva v cenovej regulácii.',
         'texty hlášok';
  ASSERT mwh_text(30) = '30' AND mwh_text(30.001) = '30,001' AND mwh_text(24.5) = '24,5', 'formát MWh';
  RAISE NOTICE 'OK: Z5-1 objem zmlúv a XM Trade k dňu: 30 MWh ostáva, 30,001 vyradiť, súbežné zmluvy, nesúlad, XM chýba, neregulovaný bez stavu';
END;
$$;

-- Z5-2. Import: upozornenie riadku zmluvy nad 30 MWh (náhľad aj uloženie)
DO $$
DECLARE
  v_res jsonb;
BEGIN
  v_res := contract_import_small_business(jsonb_build_object('contracts', jsonb_build_array(
             jsonb_build_object('contract_id', pg_temp.z5_id('k', 3), 'warnings', '[]'::jsonb),
             jsonb_build_object('contract_id', pg_temp.z5_id('k', 1), 'warnings', '["iné"]'::jsonb),
             jsonb_build_object('action', 'chyba'))));
  ASSERT v_res #>> '{contracts,0,warnings,0}' LIKE 'Pozor: ročný objem nad 30 MWh%'
     AND v_res #> '{contracts,1,warnings}' = '["iné"]' AND v_res #> '{contracts,2}' = '{"action": "chyba"}',
         'import: upozornenie iba pri zmluve nad 30 MWh – ' || v_res::text;
  RAISE NOTICE 'OK: Z5-2 upozornenie v importe zmlúv';
END;
$$;

-- Z5-3. Nočný beh: zmluvy v denníku, upozornenie obchodníkovi raz za rok; bod 3 – vyradený nad 30 MWh = „Chýba cena“
DO $$
DECLARE
  r jsonb;
BEGIN
  -- firma 3 (30,001 MWh) vyradená z regulácie od 1. 3. 2027: nie chyba behu, ale „Chýba cena“ s textom
  PERFORM oom_price_regulation_set(pg_temp.z5_id('oom', 3), false, '2027-03-01');
  r := contract_daily_run_at('2027-06-01');
  ASSERT r -> 'maly_podnik' -> 'zmluvy' ?& ARRAY['Z5-3', 'Z5-4', 'Z5-5', 'Z5-8']
     AND NOT (r -> 'maly_podnik' -> 'zmluvy' ?| ARRAY['Z5-1', 'Z5-2', 'Z5-7']), 'denník: zmluvy nad 30 MWh / nesúlad – ' || r::text;
  ASSERT (SELECT count(*) FROM notification n JOIN contract k ON k.id = n.contract_id
           WHERE n.kind = 'maly_podnik' AND k.company_id = pg_temp.z5_co(3) AND n.ref_date = '2027-01-01'
             AND n.user_id = '00000000-0000-4000-8000-000000007501' AND n.detail LIKE 'Zmluva Z5-3: Pozor%') = 1,
         'upozornenie obchodníkovi';
  ASSERT NOT EXISTS (SELECT 1 FROM job_run j, jsonb_array_elements(j.errors) e
                      WHERE j.run_date = '2027-06-01' AND e ->> 'zmluva' = pg_temp.z5_id('k', 3)::text),
         'vyradenie nad 30 MWh nie je chyba behu';
  ASSERT (SELECT detail FROM contract_flag WHERE contract_id = pg_temp.z5_id('k', 3) AND code = 'chyba_cena' AND resolved_at IS NULL)
         LIKE '%vyradený z cenovej regulácie od 1. 3. 2027 – treba novú cenu%', 'Chýba cena s textom vyradenia';
  r := contract_daily_run_at('2027-06-02');
  ASSERT (SELECT count(*) FROM notification n JOIN contract k ON k.id = n.contract_id
           WHERE n.kind = 'maly_podnik' AND k.company_id = pg_temp.z5_co(3)) = 1, 'upozornenie raz za rok';
  RAISE NOTICE 'OK: Z5-3 nočný beh: denník, upozornenie raz za rok, vyradený nad 30 MWh = Chýba cena (nie chyba behu)';
END;
$$;

-- Z5-4. Uzatváranie príznakov z aplikácie
SET LOCAL ROLE crm_rls_test;
DO $$
DECLARE
  v_flag uuid;
  v_miss uuid;
BEGIN
  PERFORM set_config('app.require_user', 'on', true);
  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-000000007501', true);
  SELECT id INTO v_flag FROM contract_flag
   WHERE contract_id = pg_temp.z4_id('k', 1) AND code = 'pod_hranicou_bez_vynimky' AND resolved_at IS NULL;
  SELECT id INTO v_miss FROM contract_flag
   WHERE contract_id = pg_temp.z5_id('k', 3) AND code = 'chyba_cena' AND resolved_at IS NULL;
  ASSERT v_flag IS NOT NULL AND v_miss IS NOT NULL, 'príznaky na skúšku';
  BEGIN
    UPDATE contract_flag SET resolved_at = now(), resolved_by = crm_active_user_id(), resolved_note = 'ok' WHERE id = v_flag;
    RAISE EXCEPTION 'CHYBA: obchodník uzavrel Pod hranicou';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    UPDATE contract_flag SET resolved_at = now(), resolved_by = crm_active_user_id() WHERE id = v_miss;
    RAISE EXCEPTION 'CHYBA: Chýba cena uzavretá ručne';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    UPDATE contract_flag SET code = 'kontrola_importu' WHERE id = v_miss;
    RAISE EXCEPTION 'CHYBA: zmenený druh príznaku';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-000000004001', true);
  BEGIN
    UPDATE contract_flag SET resolved_at = now(), resolved_by = crm_active_user_id() WHERE id = v_flag;
    RAISE EXCEPTION 'CHYBA: Pod hranicou bez poznámky';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  UPDATE contract_flag SET resolved_at = now(), resolved_by = crm_active_user_id(), resolved_note = 'cena schválená ústne, Z5'
   WHERE id = v_flag;
  ASSERT FOUND, 'schvaľovateľ s poznámkou uzavrie Pod hranicou (aj pri cudzej zmluve)';
  PERFORM set_config('app.user_id', '', true);
  PERFORM set_config('app.require_user', '', true);
END;
$$;
RESET ROLE;
DO $$
BEGIN
  ASSERT (SELECT resolved_note FROM contract_flag
           WHERE contract_id = pg_temp.z4_id('k', 1) AND code = 'pod_hranicou_bez_vynimky' AND resolved_at IS NOT NULL
           ORDER BY resolved_at DESC LIMIT 1) = 'cena schválená ústne, Z5', 'poznámka uložená';
  RAISE NOTICE 'OK: Z5-4 príznaky: Pod hranicou iba schvaľovateľ s poznámkou, Chýba cena iba databáza, príznak sa dá iba uzavrieť';
END;
$$;
