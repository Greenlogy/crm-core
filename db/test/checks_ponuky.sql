-- Kontroly modulu 5, fáza F2 (0036, 0037): pracovné dni a platnosť, číslovanie, ponuka a varianty, výpočet pridanej
-- hodnoty (cena pre obchodníka, manažér = odhad portfólia, minimálny aditív, výnimka), snímka ku dňu verzie,
-- stráženie zmien, schvaľovanie (výnimka 3 dni, rizikový zákazník 30 dní / zhoršenie, predĺženie), označenie ako
-- odoslaná (kanál, čas, FIX zo starého dňa, posun obchodu iba dopredu), nová verzia, percento provízie s históriou, RLS.
-- Spúšťa sa iba cez db/test/run.sh po checks_audit_rls.sql (používatelia série B, rola crm_rls_test).
-- Vlastné záznamy: používatelia …-0000000095xx, firmy …-0000000096xx, OOM …-0000000097xx, obchody …-0000000098xx.

-- ============================================================================
-- Príprava (vlastník databázy)
-- ============================================================================

INSERT INTO app_user (id, email, name, team_id, status, approves_prices, seller_type)
SELECT x.id::uuid, x.email, x.name, t.id, 'aktivny', x.appr, x.st::seller_type
  FROM (VALUES
    ('00000000-0000-4000-8000-000000009501', 'schvalovatel.cien.c@example.test', 'Schvaľovateľ cien C', 'sales_internal', true, NULL),
    ('00000000-0000-4000-8000-000000009502', 'manazer.c@example.test', 'Manažér C', 'test_predajcovia_b', false, 'manazer'),
    ('00000000-0000-4000-8000-000000009503', 'obchodnik.c@example.test', 'Obchodník C', 'test_predajcovia_b', false, 'obchodnik'),
    -- interný obchodník: vidí všetky obchody (Sales_internal), nevidí maržu firmy ani odhad portfólia (0038)
    ('00000000-0000-4000-8000-000000009504', 'obchodnik.int.c@example.test', 'Obchodník interný C', 'sales_internal', false, 'obchodnik')
  ) AS x(id, email, name, team, appr, st)
  JOIN team t ON t.code = x.team;
INSERT INTO app_user_org (user_id, org_id)
SELECT id, crm_default_org() FROM app_user WHERE id::text LIKE '00000000-0000-4000-8000-0000000095%';

INSERT INTO company (id, name, ico, is_customer, owner_id) VALUES
  ('00000000-0000-4000-8000-000000009601', 'Ponuka C1 s.r.o.', '99999971', true, '00000000-0000-4000-8000-000000009503'),
  ('00000000-0000-4000-8000-000000009602', 'Manažér C2 s.r.o.', '99999972', true, '00000000-0000-4000-8000-000000009502');

CREATE FUNCTION pg_temp.c_id(p_kind text, p_n integer) RETURNS uuid LANGUAGE sql AS $f$
  SELECT ('00000000-0000-4000-8000-0000000' || CASE p_kind WHEN 'u' THEN '095' WHEN 'f' THEN '096' WHEN 'oom' THEN '097' ELSE '098' END
          || lpad(p_n::text, 2, '0'))::uuid
$f$;
CREATE FUNCTION pg_temp.c_eic(p_n integer) RETURNS text LANGUAGE plpgsql AS $f$
DECLARE
  l text;
  c text;
BEGIN
  FOREACH l IN ARRAY string_to_array('KLMNPQRSTUVW', NULL) LOOP
    FOREACH c IN ARRAY string_to_array('0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ', NULL) LOOP
      IF eic_is_valid('24ZZS000PONK' || l || lpad(p_n::text, 2, '0') || c) THEN
        RETURN '24ZZS000PONK' || l || lpad(p_n::text, 2, '0') || c;
      END IF;
    END LOOP;
  END LOOP;
END;
$f$;
-- OOM: 1, 2 (NN), 3 (VN) firmy C1; 4 firmy C2
INSERT INTO oom (id, company_id, eic, type, status, voltage_level, planned_consumption_vt_mwh)
SELECT pg_temp.c_id('oom', n), pg_temp.c_id('f', CASE WHEN n = 4 THEN 2 ELSE 1 END), pg_temp.c_eic(n), 'spotreba', 'pripravovane',
       CASE WHEN n = 3 THEN 'vn' ELSE 'nn' END::voltage_level, CASE n WHEN 3 THEN 200 ELSE 20 END
  FROM generate_series(1, 4) n;

-- Trhové ceny dňa pre rok 2027: BL 100, PL 120 → cena pre obchodníka (100×80 + 120×20)/100 + 4 + 4 = 112; portfólio 105
INSERT INTO market_price_daily (org_id, on_date, delivery_year, bl_eur_mwh, pl_eur_mwh, portfolio_eur_mwh, source)
VALUES (crm_default_org(), crm_today(), 2027, 100, 120, 105, 'rucne');

-- Obchody: 1 = C1 (obchodník C), 2 = C2 (manažér C)
INSERT INTO deal (id, company_id, pipeline_id, stage_id, name, owner_id, source_code, supply_start) VALUES
  (pg_temp.c_id('d', 1), pg_temp.c_id('f', 1), pg_temp.b_pipe('b2b_dodavka'), pg_temp.b_stage('b2b_dodavka', 'prilezitost'),
   'C1 2027', pg_temp.c_id('u', 3), 'web', '2027-01-01'),
  (pg_temp.c_id('d', 2), pg_temp.c_id('f', 2), pg_temp.b_pipe('b2b_dodavka'), pg_temp.b_stage('b2b_dodavka', 'prilezitost'),
   'C2 2027', pg_temp.c_id('u', 2), 'web', '2027-01-01');
INSERT INTO deal_oom (deal_id, oom_id) VALUES
  (pg_temp.c_id('d', 1), pg_temp.c_id('oom', 1)), (pg_temp.c_id('d', 1), pg_temp.c_id('oom', 2)),
  (pg_temp.c_id('d', 1), pg_temp.c_id('oom', 3)), (pg_temp.c_id('d', 2), pg_temp.c_id('oom', 4));

-- ============================================================================
-- C0. Pracovné dni a platnosť ponuky
-- ============================================================================
DO $$
DECLARE
  o uuid := crm_default_org();
BEGIN
  ASSERT next_working_day(o, '2026-10-16') = '2026-10-19', 'piatok → pondelok';
  ASSERT next_working_day(o, '2026-12-31') = '2027-01-04', '31. 12. → 4. 1. (sviatok 1. 1. a víkend)';
  ASSERT next_working_day(o, '2027-01-05') = '2027-01-07', '6. 1. sviatok';
  ASSERT offer_default_valid_until(o, '2026-10-16 10:00+02', true) = '2026-10-19 16:00+02', 'FIX: piatok 10:00 → pondelok 16:00';
  ASSERT offer_default_valid_until(o, '2026-10-16 17:30+02', true) = '2026-10-19 16:00+02', 'FIX: piatok 17:30 → pondelok 16:00';
  -- 31. 12. 2026 je v teste firemné voľno (checks_nastavenia.sql) → platí aj firemné voľno spoločnosti
  ASSERT offer_default_valid_until(o, '2026-12-30 09:00+01', true) = '2027-01-04 16:00+01', 'FIX: 30. 12. → 4. 1. (Silvester firemné voľno)';
  ASSERT offer_default_valid_until(o, '2026-12-31 09:00+01', true) = '2027-01-04 16:00+01', 'FIX: 31. 12. → 4. 1.';
  ASSERT offer_default_valid_until(o, '2026-10-14 09:00+02', false) = '2026-10-28 16:00+01', 'SPOT: 14 dní (streda → streda)';
  ASSERT offer_default_valid_until(o, '2026-10-17 09:00+02', false) = '2026-11-02 16:00+01', 'SPOT: 14. deň nedeľa (31. 10.) → pondelok 2. 11.';
  ASSERT working_days_before(o, '2026-10-19', 2) = '2026-10-15', '2 pracovné dni pred pondelkom = štvrtok';
  RAISE NOTICE 'OK: C0 pracovné dni a sviatky, platnosť FIX do 16:00 nasledujúceho pracovného dňa, SPOT 14 dní s posunom, pripomienka 2 pracovné dni pred';
END;
$$;

GRANT SELECT, INSERT, UPDATE, DELETE ON offer, offer_variant, offer_item, user_commission_rate TO crm_rls_test;
-- položky výnimky a snímku hraníc aplikácia nečíta (app-role.sql, 0038) – testovacia rola ich tiež nedostane
SET LOCAL ROLE crm_rls_test;

-- ============================================================================
-- C1. Založenie ponuky, číslo, variant, snímka hraníc, stráženie
-- ============================================================================
DO $$
DECLARE
  v_offer uuid;
  v_var   uuid;
  o       offer;
  n       integer;
BEGIN
  PERFORM set_config('app.require_user', 'on', true);
  PERFORM set_config('app.user_id', pg_temp.c_id('u', 3)::text, true);
  BEGIN
    INSERT INTO offer (deal_id, number, kind) VALUES (pg_temp.c_id('d', 1), 'P26-999999', 'dodavka');
    RAISE EXCEPTION 'CHYBA: ponuka vložená priamo';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  v_offer := offer_create(pg_temp.c_id('d', 1));
  SELECT * INTO o FROM offer WHERE id = v_offer;
  ASSERT o.number ~ ('^P' || to_char(crm_today(), 'YY') || '-[0-9]{6}$') AND o.version = 1 AND o.status = 'koncept'
         AND o.kind = 'dodavka' AND NOT o.household AND o.priced_on = crm_today(), 'ponuka: ' || o.number;
  BEGIN
    PERFORM offer_create(pg_temp.c_id('d', 1));
    RAISE EXCEPTION 'CHYBA: druhá ponuka obchodu';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  SELECT id INTO v_var FROM offer_variant WHERE offer_id = v_offer;
  ASSERT (SELECT (price_kind, supply_from, supply_to, name) FROM offer_variant WHERE id = v_var)
         = ROW('fix'::offer_price_kind, '2027-01-01'::date, '2027-12-31'::date, 'FIX 2027'::text), 'variant A FIX 2027';
  BEGIN
    UPDATE offer SET status = 'odoslana' WHERE id = v_offer;
    RAISE EXCEPTION 'CHYBA: stav zmenený priamo';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  -- ceny: NN 118 €/MWh, VN 111 €/MWh (pod hranicou 112)
  INSERT INTO offer_item (variant_id, oom_id, year, slot, product_id, price_model, price_vt_eur_mwh)
  SELECT v_var, pg_temp.c_id('oom', g), 2027, 'komodita', (SELECT id FROM product WHERE code = 'green_1t'), 'fix',
         CASE WHEN g = 3 THEN 111 ELSE 118 END
    FROM generate_series(1, 3) g;
  BEGIN
    INSERT INTO offer_item (variant_id, oom_id, year, slot, product_id, price_model, price_vt_eur_mwh)
    VALUES (v_var, pg_temp.c_id('oom', 4), 2027, 'komodita', (SELECT id FROM product WHERE code = 'green_1t'), 'fix', 120);
    RAISE EXCEPTION 'CHYBA: cena pre OOM mimo obchodu';
  EXCEPTION WHEN check_violation OR no_data_found THEN NULL;
  END;
  BEGIN
    INSERT INTO offer_item (variant_id, oom_id, year, slot, product_id, price_model, price_vt_eur_mwh)
    VALUES (v_var, pg_temp.c_id('oom', 1), 2028, 'komodita', (SELECT id FROM product WHERE code = 'green_1t'), 'fix', 120);
    RAISE EXCEPTION 'CHYBA: rok mimo obdobia';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    INSERT INTO offer_item (variant_id, oom_id, year, slot, product_id, price_model, price_vt_eur_mwh)
    VALUES (v_var, pg_temp.c_id('oom', 1), 2027, 'zem', (SELECT id FROM product WHERE code = 'dodavka_b2b'), 'fix', 120);
    RAISE EXCEPTION 'CHYBA: produkt, ktorý sa nepredáva';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  -- najviac 5 variantov
  FOR n IN 2..5 LOOP
    PERFORM offer_variant_add(v_offer, 'spot');
  END LOOP;
  BEGIN
    PERFORM offer_variant_add(v_offer, 'spot');
    RAISE EXCEPTION 'CHYBA: šiesty variant';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  DELETE FROM offer_variant WHERE offer_id = v_offer AND sort_order > 2;
  ASSERT (SELECT count(*) FROM offer_variant WHERE offer_id = v_offer) = 2, 'zmazané varianty C–E';
  PERFORM set_config('app.user_id', '', true);
  PERFORM set_config('app.require_user', '', true);
  RAISE NOTICE 'OK: C1 ponuka iba funkciou, číslo P%%-000000, variant A FIX 2027 zo začiatku dodávky obchodu, jedna ponuka na obchod, stav iba CRM, ceny iba pre OOM obchodu a roky obdobia, najviac 5 variantov';
END;
$$;

-- ============================================================================
-- C2. Výpočet: cena pre obchodníka, minimálny aditív, manažér = odhad portfólia, odhad provízie
-- ============================================================================
DO $$
DECLARE
  v_offer uuid := (SELECT id FROM offer WHERE deal_id = pg_temp.c_id('d', 1));
  v_a     uuid;
  v_b     uuid;
  r       record;
  v_off2  uuid;
  v_m     uuid;
BEGIN
  PERFORM set_config('app.require_user', 'on', true);
  PERFORM set_config('app.user_id', pg_temp.c_id('u', 3)::text, true);
  SELECT id INTO v_a FROM offer_variant WHERE offer_id = v_offer AND sort_order = 1;
  SELECT id INTO v_b FROM offer_variant WHERE offer_id = v_offer AND sort_order = 2;
  -- A: NN 2 × 20 MWh × (118 − 112) = 240; VN 200 × (111 − 112) = −200 (pod hranicou)
  SELECT * INTO r FROM offer_variant_values(v_a) WHERE oom_id = pg_temp.c_id('oom', 1);
  ASSERT (r.threshold, r.threshold_source, r.volume_mwh, r.added_value_eur) = (112, 'cena_pre_obchodnika', 20, 120), 'NN OOM 1: ' || r::text;
  ASSERT r.margin_eur IS NULL, 'obchodník nevidí maržu firmy';
  SELECT * INTO r FROM offer_variant_values(v_a) WHERE oom_id = pg_temp.c_id('oom', 3);
  ASSERT r.below AND r.added_value_eur = -200 AND r.voltage_group = 'vn', 'VN pod hranicou: ' || r::text;
  SELECT * INTO r FROM offer_variant_summary(v_a) WHERE year IS NULL;
  ASSERT (r.added_value_eur, r.commission_pct, r.commission_eur) = (40, 40, 16), 'súhrn A: PH 40, provízia 40 % = 16: ' || r::text;
  -- B: SPOT + 9 € pri všetkých OOM (na neurčito = 12 mesiacov), minimálny aditív obchodníka 6 → (9 − 6) × 240 = 720
  INSERT INTO offer_item (variant_id, oom_id, year, slot, product_id, price_model, additive_eur_mwh)
  SELECT v_b, pg_temp.c_id('oom', n), NULL, 'komodita', (SELECT id FROM product WHERE code = 'green_1t'), 'spot_plus_eur', 9
    FROM generate_series(1, 3) n;
  SELECT * INTO r FROM offer_variant_summary(v_b) WHERE year IS NULL;
  ASSERT (r.volume_mwh, r.added_value_eur) = (240, 720), 'súhrn B SPOT: ' || r::text;
  -- kontrola ponuky: potrebná výnimka iba pre A / 2027 / FIX / VN
  ASSERT (SELECT jsonb_array_length(offer_check(v_offer)->'needs')) = 1, 'jedna potrebná výnimka';
  ASSERT (SELECT n->>'voltage_group' = 'vn' AND (n->>'requested_value')::numeric = 111 AND (n->>'threshold_value')::numeric = 112
            FROM jsonb_array_elements(offer_check(v_offer)->'needs') n), 'výnimka VN 2027: žiadaná 111, hranica 112';

  -- manažér: hranica FIX = odhad portfólia 105 (odpoveď 3)
  PERFORM set_config('app.user_id', pg_temp.c_id('u', 2)::text, true);
  v_off2 := offer_create(pg_temp.c_id('d', 2));
  SELECT id INTO v_m FROM offer_variant WHERE offer_id = v_off2;
  INSERT INTO offer_item (variant_id, oom_id, year, slot, product_id, price_model, price_vt_eur_mwh)
  VALUES (v_m, pg_temp.c_id('oom', 4), 2027, 'komodita', (SELECT id FROM product WHERE code = 'green_1t'), 'fix', 110);
  SELECT * INTO r FROM offer_variant_values(v_m);
  ASSERT (r.threshold, r.threshold_source, r.added_value_eur, r.below) = (105, 'odhad_portfolia', 100, false), 'manažér: ' || r::text;
  PERFORM set_config('app.user_id', '', true);
  PERFORM set_config('app.require_user', '', true);
  RAISE NOTICE 'OK: C2 PH = (cena − cena pre obchodníka) × objem, SPOT (aditív − minimálny aditív) × 12 mesiacov, manažér FIX = odhad portfólia, odhad provízie 40 %%, kontrola nájde výnimku VN 2027';
END;
$$;

-- Snímka ku dňu verzie: zmena BL/PL neskôr ponuku nemení; schvaľovateľ cien vidí maržu
RESET ROLE;
UPDATE market_price_daily SET bl_eur_mwh = 200 WHERE org_id = crm_default_org() AND on_date = crm_today() AND delivery_year = 2027;
SET LOCAL ROLE crm_rls_test;
DO $$
DECLARE
  v_a uuid := (SELECT v.id FROM offer_variant v JOIN offer o ON o.id = v.offer_id WHERE o.deal_id = pg_temp.c_id('d', 1) AND v.sort_order = 1);
  r   record;
BEGIN
  PERFORM set_config('app.require_user', 'on', true);
  PERFORM set_config('app.user_id', pg_temp.c_id('u', 1)::text, true);   -- schvaľovateľ cien vidí všetky obchody a maržu
  SELECT * INTO r FROM offer_variant_values(v_a) WHERE oom_id = pg_temp.c_id('oom', 1);
  ASSERT r.threshold = 112, 'snímka ku dňu verzie (BL sa zmenilo): ' || r::text;
  ASSERT r.margin_eur = (118 - 105) * 20, 'marža firmy (komodita − odhad portfólia) pre schvaľovateľa: ' || r::text;
  PERFORM set_config('app.user_id', pg_temp.b_id('u', 6)::text, true);   -- predajca C série B
  ASSERT NOT EXISTS (SELECT 1 FROM offer WHERE deal_id = pg_temp.c_id('d', 1)), 'cudziu ponuku nevidí';
  ASSERT NOT EXISTS (SELECT 1 FROM offer_variant_values(v_a)), 'ani jej hodnoty';
  BEGIN
    PERFORM 1 FROM offer_year_basis;
    RAISE EXCEPTION 'CHYBA: snímka hraníc čitateľná';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM set_config('app.user_id', '', true);
  PERFORM set_config('app.require_user', '', true);
  RAISE NOTICE 'OK: C2 snímka hraníc sa po zmene BL/PL nemení; marža iba s právom; cudziu ponuku ani hodnoty nevidno';
END;
$$;
RESET ROLE;
UPDATE market_price_daily SET bl_eur_mwh = 100 WHERE org_id = crm_default_org() AND on_date = crm_today() AND delivery_year = 2027;
SET LOCAL ROLE crm_rls_test;

-- ============================================================================
-- C3. Schvaľovanie výnimky, pripravenie, označenie ako odoslanej
-- ============================================================================
DO $$
DECLARE
  v_offer uuid := (SELECT id FROM offer WHERE deal_id = pg_temp.c_id('d', 1));
  v_a     uuid := (SELECT id FROM offer_variant WHERE offer_id = (SELECT id FROM offer WHERE deal_id = pg_temp.c_id('d', 1)) AND sort_order = 1);
  v_req   uuid;
  v_until timestamptz;
  r       record;
BEGIN
  PERFORM set_config('app.require_user', 'on', true);
  PERFORM set_config('app.user_id', pg_temp.c_id('u', 3)::text, true);
  BEGIN
    PERFORM offer_prepare(v_offer);
    RAISE EXCEPTION 'CHYBA: pripravená ponuka pod hranicou';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    PERFORM offer_mark_sent(v_offer, now(), 'osobne', NULL);
    RAISE EXCEPTION 'CHYBA: odoslaný koncept';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  ASSERT approval_request_offer(v_offer, 'zákazník má ponuku od konkurencie') = 'caka_na_schvalenie', 'žiadosť';
  SELECT id INTO v_req FROM approval_request WHERE offer_id = v_offer AND kind = 'vynimka_ceny';
  ASSERT (SELECT status FROM offer WHERE id = v_offer) = 'caka_na_schvalenie', 'ponuka čaká';
  BEGIN
    PERFORM offer_mark_sent(v_offer, now(), 'osobne', NULL);
    RAISE EXCEPTION 'CHYBA: odoslaná ponuka čakajúca na schválenie';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    PERFORM approval_decide(v_req, true, NULL);
    RAISE EXCEPTION 'CHYBA: obchodník schválil výnimku';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  -- schvaľovateľ cien: schválená hranica 110,50 (nižšia ako žiadaná 111); vyššia ako žiadaná nejde
  PERFORM set_config('app.user_id', pg_temp.c_id('u', 1)::text, true);
  ASSERT EXISTS (SELECT 1 FROM notification WHERE approval_id = v_req AND kind = 'schvalenie_nove'), 'schvaľovateľ upozornený';
  BEGIN
    PERFORM approval_decide(v_req, true, NULL, jsonb_build_array(jsonb_build_object('variant_id', v_a, 'year', 2027,
              'price_model', 'fix', 'voltage_group', 'vn', 'approved_value', 111.5)));
    RAISE EXCEPTION 'CHYBA: schválená hranica nad žiadanou cenou';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  PERFORM approval_decide(v_req, true, 'v poriadku', jsonb_build_array(jsonb_build_object('variant_id', v_a, 'year', 2027,
            'price_model', 'fix', 'voltage_group', 'vn', 'approved_value', 110.5)));
  ASSERT (SELECT valid_until BETWEEN now() + interval '71 hours' AND now() + interval '73 hours' FROM approval_request WHERE id = v_req),
         'výnimka platí 3 dni';
  PERFORM set_config('app.user_id', pg_temp.c_id('u', 3)::text, true);
  ASSERT (SELECT status FROM offer WHERE id = v_offer) = 'pripravena', 'po schválení pripravená';
  SELECT * INTO r FROM offer_variant_values(v_a) WHERE oom_id = pg_temp.c_id('oom', 3);
  ASSERT (r.threshold, r.threshold_source, r.added_value_eur, r.below) = (110.5, 'vynimka', 100, false), 'VN s výnimkou: ' || r::text;
  ASSERT EXISTS (SELECT 1 FROM notification WHERE approval_id = v_req AND kind = 'schvalenie_rozhodnutie'), 'obchodník upozornený';

  -- FIX zo včerajška: odoslať nejde (prepočítať)
  RESET ROLE;
  UPDATE offer SET priced_on = crm_today() - 1 WHERE id = v_offer;
  SET LOCAL ROLE crm_rls_test;
  BEGIN
    PERFORM offer_mark_sent(v_offer, now(), 'osobne', NULL);
    RAISE EXCEPTION 'CHYBA: FIX zo starého dňa odoslaná';
  EXCEPTION WHEN check_violation THEN
    ASSERT SQLERRM LIKE '%prepočítajte%', SQLERRM;
  END;
  RESET ROLE;
  UPDATE offer SET priced_on = crm_today() WHERE id = v_offer;
  SET LOCAL ROLE crm_rls_test;
  BEGIN
    PERFORM offer_mark_sent(v_offer, now(), NULL, NULL);
    RAISE EXCEPTION 'CHYBA: bez kanála';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    PERFORM offer_mark_sent(v_offer, now() + interval '1 day', 'osobne', NULL);
    RAISE EXCEPTION 'CHYBA: čas v budúcnosti';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  v_until := offer_mark_sent(v_offer, now(), 'email_mimo_crm', 'poslané z Outlooku');
  ASSERT v_until = offer_default_valid_until(crm_default_org(), now(), true), 'platnosť FIX od času odoslania';
  ASSERT (SELECT (status, sent_channel) FROM offer WHERE id = v_offer) = ROW('odoslana'::offer_status, 'email_mimo_crm'::offer_send_channel), 'odoslaná';
  ASSERT (SELECT s.code FROM deal d JOIN pipeline_stage s ON s.id = d.stage_id WHERE d.id = pg_temp.c_id('d', 1)) = 'cenova_ponuka',
         'obchod z Príležitosti do Cenovej ponuky';
  ASSERT EXISTS (SELECT 1 FROM deal_event WHERE deal_id = pg_temp.c_id('d', 1) AND kind = 'ponuka_odoslana'
                   AND detail->>'channel' = 'email_mimo_crm'), 'odoslanie v časovej osi';
  ASSERT EXISTS (SELECT 1 FROM audit_log WHERE table_name = 'offer' AND record_id = v_offer AND diff ? 'sent_at'), 'odoslanie v audite';
  BEGIN
    UPDATE offer_item SET price_vt_eur_mwh = 130 WHERE variant_id = v_a AND oom_id = pg_temp.c_id('oom', 1);
    RAISE EXCEPTION 'CHYBA: zmenená odoslaná ponuka';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    DELETE FROM offer WHERE id = v_offer;
    RAISE EXCEPTION 'CHYBA: zmazaná odoslaná ponuka';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  PERFORM set_config('app.user_id', '', true);
  PERFORM set_config('app.require_user', '', true);
  RAISE NOTICE 'OK: C3 pod hranicou → žiadosť, čaká; schvaľuje iba schvaľovateľ cien, hranica ≤ žiadaná, platí 3 dni; pripravená; FIX zo včerajška a bez kanála neodíde; odoslaná s kanálom, platnosť od času odoslania, obchod do Cenovej ponuky, časová os a audit; odoslaná sa nemení ani nemaže';
END;
$$;

-- ============================================================================
-- C4. Nová verzia, posun obchodu iba dopredu, zamietnutie, skrátenie a predĺženie platnosti, prepadnutá výnimka
-- ============================================================================
DO $$
DECLARE
  v_offer uuid := (SELECT id FROM offer WHERE deal_id = pg_temp.c_id('d', 1) AND version = 1);
  v_new   uuid;
  v_req   uuid;
  o       offer;
  v_until timestamptz;
BEGIN
  PERFORM set_config('app.require_user', 'on', true);
  PERFORM set_config('app.user_id', pg_temp.c_id('u', 3)::text, true);
  -- obchod do Vyjednávania; nová verzia ho pri odoslaní nevráti
  UPDATE deal SET stage_id = pg_temp.b_stage('b2b_dodavka', 'vyjednavanie') WHERE id = pg_temp.c_id('d', 1);
  v_new := offer_new_version(v_offer);
  SELECT * INTO o FROM offer WHERE id = v_new;
  ASSERT (o.number, o.version, o.status) = ((SELECT number FROM offer WHERE id = v_offer), 2, 'koncept'::offer_status), 'verzia /2';
  ASSERT offer_display_number(o) LIKE '%/2', 'zobrazené číslo /2';
  ASSERT (SELECT status FROM offer WHERE id = v_offer) = 'odoslana', 'stará verzia platí, kým nová neodíde';
  ASSERT (SELECT count(*) FROM offer_variant WHERE offer_id = v_new) = 2, 'kópia variantov';
  -- výnimka z verzie 1 prejde na verziu 2 (3-dňová lehota, rovnaký rozsah, cena 111 ≥ schválených 110,50 – 0038)
  ASSERT jsonb_array_length(offer_check(v_new)->'needs') = 0, 'nová verzia preberie platnú výnimku';
  UPDATE offer_item SET price_vt_eur_mwh = 113 WHERE variant_id IN (SELECT id FROM offer_variant WHERE offer_id = v_new)
     AND oom_id = pg_temp.c_id('oom', 3);
  ASSERT offer_prepare(v_new) = 'pripravena', 'bez výnimky pripravená';
  PERFORM offer_mark_sent(v_new, now(), 'osobne', NULL);
  ASSERT (SELECT (status, replaced_by_id) FROM offer WHERE id = v_offer) = ROW('nahradena'::offer_status, v_new), 'stará Nahradená';
  ASSERT (SELECT s.code FROM deal d JOIN pipeline_stage s ON s.id = d.stage_id WHERE d.id = pg_temp.c_id('d', 1)) = 'vyjednavanie',
         'obchod ostal vo Vyjednávaní (iba dopredu)';
  -- skrátenie obchodníkom, predĺženie iba schválením
  SELECT valid_until INTO v_until FROM offer WHERE id = v_new;
  BEGIN
    PERFORM offer_shorten(v_new, v_until + interval '1 day');
    RAISE EXCEPTION 'CHYBA: obchodník predĺžil';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  PERFORM offer_shorten(v_new, v_until - interval '1 hour');
  v_req := approval_request_extend(v_new, v_until + interval '7 days', 'zákazník čaká na rozhodnutie predstavenstva');
  PERFORM set_config('app.user_id', pg_temp.c_id('u', 1)::text, true);
  PERFORM approval_decide(v_req, true, NULL);
  ASSERT (SELECT valid_until FROM offer WHERE id = v_new) = v_until + interval '7 days', 'predĺžená schválením';
  PERFORM set_config('app.user_id', pg_temp.c_id('u', 3)::text, true);
  PERFORM offer_reject(v_new, 'zákazník ostáva u dodávateľa');
  ASSERT (SELECT status FROM offer WHERE id = v_new) = 'zamietnuta', 'zamietnutá';
  ASSERT offer_state((SELECT o2 FROM offer o2 WHERE o2.id = v_new)) = 'zamietnuta', 'stav';
  PERFORM set_config('app.user_id', '', true);
  PERFORM set_config('app.require_user', '', true);
  RAISE NOTICE 'OK: C4 nová verzia /2 (stará platí do odoslania novej, potom Nahradená), platná výnimka prejde, obchod sa nevracia; skrátenie áno, predĺženie iba schválením; zamietnutie';
END;
$$;

-- Prepadnutá výnimka (po 3 dňoch) a vypršaná ponuka
DO $$
DECLARE
  v_offer uuid;
  v_var   uuid;
  v_req   uuid;
BEGIN
  PERFORM set_config('app.require_user', 'on', true);
  PERFORM set_config('app.user_id', pg_temp.c_id('u', 2)::text, true);
  v_offer := (SELECT id FROM offer WHERE deal_id = pg_temp.c_id('d', 2));
  v_var := (SELECT id FROM offer_variant WHERE offer_id = v_offer);
  UPDATE offer_item SET price_vt_eur_mwh = 100 WHERE variant_id = v_var;   -- pod 105 (portfólio)
  PERFORM approval_request_offer(v_offer, 'strategický zákazník');
  v_req := (SELECT id FROM approval_request WHERE offer_id = v_offer AND kind = 'vynimka_ceny' AND status = 'caka');
  PERFORM set_config('app.user_id', pg_temp.c_id('u', 1)::text, true);
  PERFORM approval_decide(v_req, true, NULL);
  PERFORM set_config('app.user_id', '', true);
  PERFORM set_config('app.require_user', '', true);
END;
$$;
RESET ROLE;
UPDATE approval_request SET valid_until = now() - interval '1 minute'
 WHERE offer_id = (SELECT id FROM offer WHERE deal_id = pg_temp.c_id('d', 2)) AND kind = 'vynimka_ceny';
SET LOCAL ROLE crm_rls_test;
DO $$
DECLARE
  v_offer uuid := (SELECT id FROM offer WHERE deal_id = pg_temp.c_id('d', 2));
BEGIN
  PERFORM set_config('app.require_user', 'on', true);
  PERFORM set_config('app.user_id', pg_temp.c_id('u', 2)::text, true);
  ASSERT (SELECT status FROM offer WHERE id = v_offer) = 'pripravena', 'pripravená pred prepadnutím';
  BEGIN
    PERFORM offer_mark_sent(v_offer, now(), 'osobne', NULL);
    RAISE EXCEPTION 'CHYBA: odoslaná s prepadnutou výnimkou';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  PERFORM set_config('app.user_id', '', true);
  PERFORM set_config('app.require_user', '', true);
  RAISE NOTICE 'OK: C4 výnimka prepadne po 3 dňoch – ponuka sa nedá odoslať';
END;
$$;
RESET ROLE;
DO $$
DECLARE
  o offer;
BEGIN
  SELECT * INTO o FROM offer WHERE deal_id = pg_temp.c_id('d', 1) AND version = 1;
  o.status := 'odoslana';
  o.valid_until := now() - interval '1 minute';
  ASSERT offer_state(o) = 'vyprsana', 'po platnosti Vypršaná (počíta sa)';
  RAISE NOTICE 'OK: C4 stav Vypršaná sa počíta z platnosti';
END;
$$;

-- ============================================================================
-- C5. Rizikový zákazník: schválenie pre celý obchod 30 dní, kým sa údaje nezhoršia
-- ============================================================================
INSERT INTO deal (id, company_id, pipeline_id, stage_id, name, owner_id, source_code, supply_start) VALUES
  (pg_temp.c_id('d', 3), pg_temp.c_id('f', 1), pg_temp.b_pipe('b2b_vykup'), pg_temp.b_stage('b2b_vykup', 'prilezitost'),
   'C1 výkup', pg_temp.c_id('u', 3), 'web', '2027-01-01');
UPDATE oom SET planned_feed_in_mwh = 50 WHERE id = pg_temp.c_id('oom', 1);
INSERT INTO deal_oom (deal_id, oom_id) VALUES (pg_temp.c_id('d', 3), pg_temp.c_id('oom', 1));
UPDATE company SET insolvency_kind = 'konkurz', insolvency_since = '2026-10-01' WHERE id = pg_temp.c_id('f', 1);
SET LOCAL ROLE crm_rls_test;
DO $$
DECLARE
  v_offer uuid;
  v_var   uuid;
  v_req   uuid;
BEGIN
  PERFORM set_config('app.require_user', 'on', true);
  PERFORM set_config('app.user_id', pg_temp.c_id('u', 3)::text, true);
  v_offer := offer_create(pg_temp.c_id('d', 3));
  v_var := (SELECT id FROM offer_variant WHERE offer_id = v_offer);
  ASSERT (SELECT kind FROM offer WHERE id = v_offer) = 'vykup' AND (SELECT price_kind FROM offer_variant WHERE id = v_var) = 'spot', 'výkup SPOT';
  INSERT INTO offer_item (variant_id, oom_id, year, slot, product_id, price_model, additive_eur_mwh)
  VALUES (v_var, pg_temp.c_id('oom', 1), NULL, 'komodita', (SELECT id FROM product WHERE code = 'vykup_b2b'), 'spot_minus_eur', 8);
  ASSERT (offer_check(v_offer)->>'risk_needs_approval')::boolean, 'konkurz → schválenie';
  PERFORM approval_request_offer(v_offer, 'zákazník platí vopred');
  v_req := (SELECT id FROM approval_request WHERE deal_id = pg_temp.c_id('d', 3) AND kind = 'rizikovy_zakaznik');
  PERFORM set_config('app.user_id', pg_temp.c_id('u', 1)::text, true);
  PERFORM approval_decide(v_req, true, NULL);
  ASSERT (SELECT valid_until BETWEEN now() + interval '29 days' AND now() + interval '31 days' FROM approval_request WHERE id = v_req), '30 dní';
  PERFORM set_config('app.user_id', pg_temp.c_id('u', 3)::text, true);
  ASSERT (SELECT status FROM offer WHERE id = v_offer) = 'pripravena', 'po schválení rizika pripravená';
  PERFORM set_config('app.user_id', '', true);
  PERFORM set_config('app.require_user', '', true);
END;
$$;
RESET ROLE;
UPDATE company SET debts = '[{"veritel": "Daňový úrad", "suma_eur": 5000}]', has_debts = true WHERE id = pg_temp.c_id('f', 1);
DO $$
BEGIN
  ASSERT (offer_check((SELECT id FROM offer WHERE deal_id = pg_temp.c_id('d', 3)))->>'risk_needs_approval')::boolean,
         'nový dlh → schválenie rizika treba znova';
  RAISE NOTICE 'OK: C5 rizikový zákazník (konkurz): schválenie pre obchod 30 dní; nový dlh ho zruší';
END;
$$;
UPDATE company SET insolvency_kind = NULL, insolvency_since = NULL, debts = '[]', has_debts = NULL WHERE id = pg_temp.c_id('f', 1);

-- ============================================================================
-- C6. Percento provízie s históriou (odpoveď 4)
-- ============================================================================
SET LOCAL ROLE crm_rls_test;
DO $$
BEGIN
  PERFORM set_config('app.require_user', 'on', true);
  ASSERT user_commission_pct(pg_temp.c_id('u', 3)) = 40, 'predvolene 40 %';
  PERFORM set_config('app.user_id', pg_temp.c_id('u', 3)::text, true);
  BEGIN
    INSERT INTO user_commission_rate (user_id, valid_from, pct) VALUES (pg_temp.c_id('u', 3), crm_today(), 60);
    RAISE EXCEPTION 'CHYBA: obchodník si zmenil percento';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM set_config('app.user_id', pg_temp.c_id('u', 1)::text, true);   -- obchodný riaditeľ (schvaľuje ceny)
  BEGIN
    INSERT INTO user_commission_rate (user_id, valid_from, pct) VALUES (pg_temp.c_id('u', 3), crm_today() - 1, 45);
    RAISE EXCEPTION 'CHYBA: percento so spätnou platnosťou';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  INSERT INTO user_commission_rate (user_id, valid_from, pct) VALUES (pg_temp.c_id('u', 3), crm_today(), 45);
  INSERT INTO user_commission_rate (user_id, valid_from, pct) VALUES (pg_temp.c_id('u', 3), crm_today() + 30, 50);
  ASSERT user_commission_pct(pg_temp.c_id('u', 3)) = 45 AND user_commission_pct(pg_temp.c_id('u', 3), crm_today() + 31) = 50, 'história';
  BEGIN
    UPDATE user_commission_rate SET pct = 99 WHERE user_id = pg_temp.c_id('u', 3) AND valid_from = crm_today();
    RAISE EXCEPTION 'CHYBA: percento prepísané';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  DELETE FROM user_commission_rate WHERE user_id = pg_temp.c_id('u', 3) AND valid_from = crm_today() + 30;
  ASSERT EXISTS (SELECT 1 FROM audit_log WHERE table_name = 'user_commission_rate'), 'audit';
  PERFORM set_config('app.user_id', '', true);
  PERFORM set_config('app.require_user', '', true);
  RAISE NOTICE 'OK: C6 percento provízie: predvolene 40 %%, mení obchodný riaditeľ / admin od dnes, história a audit, riadok sa nemení';
END;
$$;
RESET ROLE;

-- ============================================================================
-- C7. Výnimka pri novej verzii (0038): prejde v 3-dňovej lehote, pri rovnakom rozsahu a cene ≥ schválenej hranice
-- ============================================================================
-- firma C3 (interný obchodník), OOM 5 (firma C1, NN 20 MWh) a 6 (firma C3, NN 20 MWh), obchody 4 (obchodník C) a 5 (interný)
INSERT INTO company (id, name, ico, is_customer, owner_id) VALUES
  ('00000000-0000-4000-8000-000000009603', 'Interný C3 s.r.o.', '99999973', true, '00000000-0000-4000-8000-000000009504');
INSERT INTO oom (id, company_id, eic, type, status, voltage_level, planned_consumption_vt_mwh)
SELECT pg_temp.c_id('oom', n), pg_temp.c_id('f', CASE WHEN n = 5 THEN 1 ELSE 3 END), pg_temp.c_eic(n), 'spotreba', 'pripravovane',
       'nn', 20
  FROM generate_series(5, 6) n;
INSERT INTO deal (id, company_id, pipeline_id, stage_id, name, owner_id, source_code, supply_start) VALUES
  (pg_temp.c_id('d', 4), pg_temp.c_id('f', 1), pg_temp.b_pipe('b2b_dodavka'), pg_temp.b_stage('b2b_dodavka', 'prilezitost'),
   'C1 2027 verzie', pg_temp.c_id('u', 3), 'web', '2027-01-01'),
  (pg_temp.c_id('d', 5), pg_temp.c_id('f', 3), pg_temp.b_pipe('b2b_dodavka'), pg_temp.b_stage('b2b_dodavka', 'prilezitost'),
   'C3 2027', pg_temp.c_id('u', 4), 'web', '2027-01-01');
INSERT INTO deal_oom (deal_id, oom_id) VALUES (pg_temp.c_id('d', 4), pg_temp.c_id('oom', 5)), (pg_temp.c_id('d', 5), pg_temp.c_id('oom', 6));
SET LOCAL ROLE crm_rls_test;
DO $$
DECLARE
  v1    uuid;
  v2    uuid;
  var1  uuid;
  var2  uuid;
  v_req uuid;
  v_vol numeric;
  r     record;
BEGIN
  PERFORM set_config('app.require_user', 'on', true);
  PERFORM set_config('app.user_id', pg_temp.c_id('u', 3)::text, true);
  v1 := offer_create(pg_temp.c_id('d', 4));
  var1 := (SELECT id FROM offer_variant WHERE offer_id = v1);
  INSERT INTO offer_item (variant_id, oom_id, year, slot, product_id, price_model, price_vt_eur_mwh)
  VALUES (var1, pg_temp.c_id('oom', 5), 2027, 'komodita', (SELECT id FROM product WHERE code = 'green_1t'), 'fix', 111);
  ASSERT approval_request_offer(v1, 'konkurencia') = 'caka_na_schvalenie', 'žiadosť o výnimku 111 < 112';
  v_req := (SELECT id FROM approval_request WHERE offer_id = v1 AND kind = 'vynimka_ceny');
  PERFORM set_config('app.user_id', pg_temp.c_id('u', 1)::text, true);
  PERFORM approval_decide(v_req, true, NULL);
  PERFORM set_config('app.user_id', pg_temp.c_id('u', 3)::text, true);
  PERFORM offer_mark_sent(v1, now(), 'osobne', NULL);

  -- nová verzia v lehote: výnimka prejde (časová os to zaznačí)
  v2 := offer_new_version(v1);
  var2 := (SELECT id FROM offer_variant WHERE offer_id = v2);
  ASSERT jsonb_array_length(offer_check(v2)->'needs') = 0, 'výnimka prešla na novú verziu';
  SELECT * INTO r FROM offer_variant_values(var2);
  ASSERT (r.threshold_source, r.exception_value, r.below) = ('vynimka', 111, false), 'nová verzia s výnimkou: ' || r::text;
  ASSERT EXISTS (SELECT 1 FROM deal_event WHERE offer_id = v2 AND kind = 'ponuka_verzia' AND detail->>'exceptions_carried' = '1'),
         'prenesená výnimka v časovej osi';
  ASSERT (SELECT count(*) FROM approval_price_detail(v_req)) = 1, 'detail žiadosti bez kópie z novej verzie';

  -- (b) cena pod schválenou hranicou → nové schválenie
  UPDATE offer_item SET price_vt_eur_mwh = 110 WHERE variant_id = var2;
  ASSERT (SELECT (n->>'requested_value')::numeric FROM jsonb_array_elements(offer_check(v2)->'needs') n) = 110,
         'cena 110 pod schválenou hranicou 111 → schválenie';
  UPDATE offer_item SET price_vt_eur_mwh = 111 WHERE variant_id = var2;
  ASSERT jsonb_array_length(offer_check(v2)->'needs') = 0, 'cena späť na 111';

  -- (c) zmena objemu OOM alebo obdobia (roky) → nové schválenie; odoslaná verzia si výnimku ponechá
  v_vol := (SELECT planned_vt_mwh FROM deal_oom WHERE deal_id = pg_temp.c_id('d', 4));
  UPDATE deal_oom SET planned_vt_mwh = coalesce(v_vol, 20) + 10 WHERE deal_id = pg_temp.c_id('d', 4);
  ASSERT jsonb_array_length(offer_check(v2)->'needs') = 1, 'zmenený objem → nové schválenie';
  ASSERT (SELECT threshold_source FROM offer_variant_values(var1)) = 'vynimka', 'odoslaná verzia si výnimku ponechá';
  UPDATE deal_oom SET planned_vt_mwh = v_vol WHERE deal_id = pg_temp.c_id('d', 4);
  ASSERT jsonb_array_length(offer_check(v2)->'needs') = 0, 'objem späť';
  UPDATE offer_variant SET supply_from = '2027-02-01' WHERE id = var2;
  ASSERT jsonb_array_length(offer_check(v2)->'needs') = 1, 'zmenené obdobie → nové schválenie';
  UPDATE offer_variant SET supply_from = '2027-01-01' WHERE id = var2;
  ASSERT jsonb_array_length(offer_check(v2)->'needs') = 0, 'obdobie späť';

  -- prepočet na dnešné ceny odpojí prevzatú výnimku; stará verzia a žiadosť ostanú
  PERFORM offer_reprice(v2);
  ASSERT jsonb_array_length(offer_check(v2)->'needs') = 1, 'po prepočte nové schválenie';
  ASSERT (SELECT status FROM approval_request WHERE id = v_req) = 'schvalena', 'žiadosť starej verzie ostala schválená';
  ASSERT (SELECT threshold_source FROM offer_variant_values(var1)) = 'vynimka', 'stará verzia s výnimkou';
  DELETE FROM offer WHERE id = v2;
  PERFORM set_config('app.user_id', '', true);
  PERFORM set_config('app.require_user', '', true);
  RAISE NOTICE 'OK: C7 výnimka prejde na novú verziu (časová os), cena pod schválenou hranicou, zmena objemu alebo obdobia a prepočet → nové schválenie; odoslaná verzia si výnimku ponechá; detail žiadosti bez kópií';
END;
$$;
-- (a) po 3-dňovej lehote výnimka neprejde (lehota končí v čase odoslania verzie 1)
RESET ROLE;
UPDATE approval_request SET valid_until = now()
 WHERE kind = 'vynimka_ceny' AND offer_id = (SELECT id FROM offer WHERE deal_id = pg_temp.c_id('d', 4) AND version = 1);
SET LOCAL ROLE crm_rls_test;
DO $$
DECLARE
  v1 uuid := (SELECT id FROM offer WHERE deal_id = pg_temp.c_id('d', 4) AND version = 1);
  v3 uuid;
BEGIN
  PERFORM set_config('app.require_user', 'on', true);
  PERFORM set_config('app.user_id', pg_temp.c_id('u', 3)::text, true);
  v3 := offer_new_version(v1);
  ASSERT jsonb_array_length(offer_check(v3)->'needs') = 1, 'po lehote nové schválenie';
  ASSERT (SELECT threshold_source FROM offer_variant_values((SELECT id FROM offer_variant WHERE offer_id = v1))) = 'vynimka',
         'verzia 1 odoslaná v lehote si výnimku ponechá';
  -- rozpracovaná verzia čaká na schválenie (C8: akceptácia starej verzie ju zablokuje)
  ASSERT approval_request_offer(v3, 'nová cena') = 'caka_na_schvalenie', 'verzia čaká na schválenie';
  PERFORM set_config('app.user_id', '', true);
  PERFORM set_config('app.require_user', '', true);
  RAISE NOTICE 'OK: C7 po 3-dňovej lehote výnimka na novú verziu neprejde';
END;
$$;

-- ============================================================================
-- C8. Akceptácia starej verzie počas prípravy novej (0038): nová sa zablokuje, vlastník dostane upozornenie
-- ============================================================================
RESET ROLE;
DO $$
DECLARE
  v1   offer := (SELECT o FROM offer o WHERE o.deal_id = pg_temp.c_id('d', 4) AND o.version = 1);
  v3   uuid := (SELECT id FROM offer WHERE deal_id = pg_temp.c_id('d', 4) AND status = 'caka_na_schvalenie');
  var1 uuid := (SELECT id FROM offer_variant WHERE offer_id = (SELECT id FROM offer WHERE deal_id = pg_temp.c_id('d', 4) AND version = 1));
BEGIN
  -- akceptáciu volá kód databázy (F3: klik zákazníka na stránke ponuky alebo ručný záznam obchodníka)
  BEGIN
    PERFORM offer_accept_apply(v3, (SELECT id FROM offer_variant WHERE offer_id = v3));
    RAISE EXCEPTION 'CHYBA: akceptovaná neodoslaná verzia';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    PERFORM offer_accept_apply(v1.id, var1, v1.valid_until);
    RAISE EXCEPTION 'CHYBA: akceptovaná po platnosti';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  PERFORM offer_accept_apply(v1.id, var1, now());
  ASSERT (SELECT status FROM offer WHERE id = v1.id) = 'akceptovana', 'verzia 1 akceptovaná';
  ASSERT (SELECT status FROM offer WHERE id = v3) = 'koncept', 'rozpracovaná verzia späť do konceptu';
  ASSERT NOT EXISTS (SELECT 1 FROM approval_request WHERE offer_id = v3 AND status = 'caka'), 'čakajúca žiadosť zrušená';
  ASSERT (SELECT (d.accepted_variant_id, s.code) FROM deal d JOIN pipeline_stage s ON s.id = d.stage_id WHERE d.id = pg_temp.c_id('d', 4))
         = ROW(var1, 'akceptacia'::deal_stage_code), 'obchod v Akceptácii s variantom';
  ASSERT EXISTS (SELECT 1 FROM notification WHERE user_id = pg_temp.c_id('u', 3) AND kind = 'ponuka_zablokovana'
                   AND deal_id = pg_temp.c_id('d', 4)), 'vlastník upozornený na zablokovanú verziu';
  ASSERT EXISTS (SELECT 1 FROM notification WHERE user_id = pg_temp.c_id('u', 3) AND kind = 'ponuka_akceptovana'), 'upozornenie na akceptáciu';
  ASSERT EXISTS (SELECT 1 FROM deal_event WHERE offer_id = v3 AND kind = 'ponuka_zablokovana'), 'zablokovanie v časovej osi';
  ASSERT EXISTS (SELECT 1 FROM deal_event WHERE offer_id = v1.id AND kind = 'ponuka_akceptovana'), 'akceptácia v časovej osi';
END;
$$;
SET LOCAL ROLE crm_rls_test;
DO $$
DECLARE
  v1 uuid := (SELECT id FROM offer WHERE deal_id = pg_temp.c_id('d', 4) AND version = 1);
  v3 uuid := (SELECT id FROM offer WHERE deal_id = pg_temp.c_id('d', 4) AND version = 2);
BEGIN
  PERFORM set_config('app.require_user', 'on', true);
  PERFORM set_config('app.user_id', pg_temp.c_id('u', 3)::text, true);
  ASSERT (SELECT bool_or(e LIKE '%akceptoval%') FROM jsonb_array_elements_text(offer_check(v3)->'errors') e), 'kontrola hlási akceptáciu';
  BEGIN
    PERFORM offer_prepare(v3);
    RAISE EXCEPTION 'CHYBA: zablokovaná verzia pripravená';
  EXCEPTION WHEN check_violation THEN
    ASSERT SQLERRM LIKE '%akceptoval%', SQLERRM;
  END;
  BEGIN
    PERFORM approval_request_offer(v3, 'skúsim znova');
    RAISE EXCEPTION 'CHYBA: žiadosť zo zablokovanej verzie';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    PERFORM offer_mark_sent(v3, now(), 'osobne', NULL);
    RAISE EXCEPTION 'CHYBA: zablokovaná verzia odoslaná';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    PERFORM offer_new_version(v1);
    RAISE EXCEPTION 'CHYBA: nová verzia z akceptovanej';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  PERFORM set_config('app.user_id', '', true);
  PERFORM set_config('app.require_user', '', true);
  RAISE NOTICE 'OK: C8 akceptácia iba odoslanej verzie v platnosti; obchod do Akceptácie; rozpracovaná verzia späť do konceptu, žiadosť zrušená, nedá sa pripraviť, poslať na schválenie ani odoslať; upozornenie a časová os';
END;
$$;

-- ============================================================================
-- C9. Skryté hodnoty (0038): interný obchodník nevidí odhad portfólia (hranicu manažéra), maržu ani snímku hraníc
-- ============================================================================
-- vlastná ponuka interného obchodníka s výnimkou (hranica = cena pre obchodníka, tú vidí)
DO $$
DECLARE
  v_off uuid;
  v_req uuid;
BEGIN
  PERFORM set_config('app.require_user', 'on', true);
  PERFORM set_config('app.user_id', pg_temp.c_id('u', 4)::text, true);
  v_off := offer_create(pg_temp.c_id('d', 5));
  INSERT INTO offer_item (variant_id, oom_id, year, slot, product_id, price_model, price_vt_eur_mwh)
  VALUES ((SELECT id FROM offer_variant WHERE offer_id = v_off), pg_temp.c_id('oom', 6), 2027, 'komodita',
          (SELECT id FROM product WHERE code = 'green_1t'), 'fix', 111);
  PERFORM approval_request_offer(v_off, 'konkurencia');
  v_req := (SELECT id FROM approval_request WHERE offer_id = v_off AND kind = 'vynimka_ceny');
  PERFORM set_config('app.user_id', pg_temp.c_id('u', 1)::text, true);
  PERFORM approval_decide(v_req, true, NULL);
  PERFORM set_config('app.user_id', '', true);
  PERFORM set_config('app.require_user', '', true);
END;
$$;
RESET ROLE;
-- položky výnimky ponuky manažéra (hranica 105 = odhad portfólia) na porovnanie
CREATE TEMP TABLE c_manager_items ON COMMIT DROP AS
SELECT i.id, i.threshold_value, i.threshold_source FROM approval_price_item i
  JOIN offer_variant v ON v.id = i.variant_id JOIN offer o ON o.id = v.offer_id
 WHERE o.deal_id = pg_temp.c_id('d', 2);
GRANT SELECT ON c_manager_items TO crm_rls_test;
DO $$
BEGIN
  ASSERT (SELECT count(*) FROM c_manager_items WHERE threshold_value = 105 AND threshold_source = 'odhad_portfolia') = 1,
         'ponuka manažéra má položku výnimky s hranicou 105 z odhadu portfólia';
  ASSERT NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'offer_item'
                        AND column_name ~ '(threshold|portfolio|margin|trader|basis|risk)'),
         'offer_item obsahuje iba ceny (bez hranice, odhadu portfólia a marže)';
END;
$$;
SET LOCAL ROLE crm_rls_test;
DO $$
DECLARE
  v_m   uuid := (SELECT v.id FROM offer_variant v JOIN offer o ON o.id = v.offer_id WHERE o.deal_id = pg_temp.c_id('d', 2));
  v_off uuid := (SELECT id FROM offer WHERE deal_id = pg_temp.c_id('d', 2));
  v_own uuid := (SELECT id FROM offer WHERE deal_id = pg_temp.c_id('d', 5));
  r     record;
BEGIN
  PERFORM set_config('app.require_user', 'on', true);
  -- kontrola: schvaľovateľ cien a manažér hranicu z odhadu portfólia vidia
  PERFORM set_config('app.user_id', pg_temp.c_id('u', 1)::text, true);
  ASSERT EXISTS (SELECT 1 FROM audit_log WHERE table_name = 'approval_price_item' AND record_id IN (SELECT id FROM c_manager_items)),
         'schvaľovateľ vidí audit položky výnimky manažéra';
  PERFORM set_config('app.user_id', pg_temp.c_id('u', 2)::text, true);
  ASSERT (SELECT threshold FROM offer_variant_values(v_m)) = 105, 'manažér vidí svoju hranicu';
  ASSERT (SELECT threshold_value FROM approval_price_detail((SELECT id FROM approval_request WHERE offer_id = v_off AND kind = 'vynimka_ceny'))) = 105,
         'manažér vidí hranicu vo svojej žiadosti';

  -- interný obchodník (vidí všetky obchody, nie maržu)
  PERFORM set_config('app.user_id', pg_temp.c_id('u', 4)::text, true);
  ASSERT EXISTS (SELECT 1 FROM offer WHERE id = v_off), 'ponuku manažéra vidí';
  ASSERT EXISTS (SELECT 1 FROM offer_item WHERE variant_id = v_m), 'ceny ponuky manažéra vidí';
  SELECT * INTO r FROM offer_variant_values(v_m);
  ASSERT r.threshold IS NULL AND r.threshold_source = 'odhad_portfolia' AND r.margin_eur IS NULL,
         'hodnoty variantu manažéra bez hranice a marže: ' || r::text;
  ASSERT (SELECT bool_and(n->'threshold_value' = 'null'::jsonb) FROM jsonb_array_elements(offer_check(v_off)->'needs') n)
         AND jsonb_array_length(offer_check(v_off)->'needs') = 1, 'kontrola ponuky manažéra bez hranice';
  ASSERT NOT EXISTS (SELECT 1 FROM approval_price_detail((SELECT id FROM approval_request WHERE offer_id = v_off AND kind = 'vynimka_ceny'))),
         'detail cudzej žiadosti nevidí';
  -- Sales_internal smie upravovať aj obchod manažéra: sám požiada o výnimku – hranica (odhad portfólia) ostane skrytá
  ASSERT approval_request_offer(v_off, 'zastupujem manažéra') = 'caka_na_schvalenie', 'žiadosť interného obchodníka';
  ASSERT (SELECT threshold_value IS NULL AND requested_value = 100
            FROM approval_price_detail((SELECT id FROM approval_request WHERE offer_id = v_off AND kind = 'vynimka_ceny' AND status = 'caka'))),
         'detail vlastnej žiadosti bez hranice z odhadu portfólia';
  ASSERT EXISTS (SELECT 1 FROM audit_log WHERE table_name = 'approval_request'
                    AND record_id = (SELECT id FROM approval_request WHERE offer_id = v_off AND kind = 'vynimka_ceny' AND status = 'caka')),
         'audit vlastnej žiadosti vidí';
  ASSERT NOT EXISTS (SELECT 1 FROM audit_log WHERE table_name = 'approval_price_item'
                        AND audit_diff_value(diff, 'approval_id')::uuid
                            = (SELECT id FROM approval_request WHERE offer_id = v_off AND kind = 'vynimka_ceny' AND status = 'caka')),
         'audit položky vlastnej žiadosti s hranicou z odhadu portfólia nevidí';
  BEGIN
    PERFORM 1 FROM approval_price_item;
    RAISE EXCEPTION 'CHYBA: položky výnimky čitateľné priamo';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    PERFORM 1 FROM offer_year_basis;
    RAISE EXCEPTION 'CHYBA: snímka hraníc čitateľná';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  -- audit: ponuku manažéra aj vlastnú vidí, hranicu z odhadu portfólia, odhad portfólia ani maržu v starých ani nových hodnotách nie
  ASSERT EXISTS (SELECT 1 FROM audit_log WHERE table_name = 'offer' AND record_id = v_off), 'audit ponuky manažéra vidí';
  ASSERT EXISTS (SELECT 1 FROM audit_log WHERE table_name = 'offer_item'
                    AND audit_diff_value(diff, 'variant_id')::uuid = v_m), 'audit cien ponuky manažéra vidí';
  ASSERT EXISTS (SELECT 1 FROM audit_log WHERE table_name = 'offer' AND record_id = v_own), 'audit vlastnej ponuky vidí';
  ASSERT EXISTS (SELECT 1 FROM audit_log WHERE table_name = 'approval_price_item'
                    AND audit_diff_value(diff, 'threshold_source') = 'cena_pre_obchodnika'
                    AND (audit_diff_value(diff, 'threshold_value'))::numeric = 112), 'audit vlastnej výnimky (hranica = cena pre obchodníka) vidí';
  ASSERT NOT EXISTS (SELECT 1 FROM audit_log WHERE table_name = 'approval_price_item' AND record_id IN (SELECT id FROM c_manager_items)),
         'audit položky výnimky manažéra nevidí';
  ASSERT NOT EXISTS (SELECT 1 FROM audit_log a
                      WHERE a.diff ?| ARRAY['portfolio_eur_mwh', 'margin_eur', 'margin_cost_eur', 'risk_premium', 'our_margin']
                         OR audit_diff_value(a.diff, 'threshold_source') = 'odhad_portfolia'
                         OR a.table_name IN ('offer_year_basis', 'contract_year_basis', 'price_parameter', 'market_price_daily')),
         'žiadny viditeľný záznam auditu s odhadom portfólia, maržou alebo rizikovou prirážkou';

  -- externý predajca série B ponuku manažéra ani jej ceny nevidí
  PERFORM set_config('app.user_id', pg_temp.b_id('u', 6)::text, true);
  ASSERT NOT EXISTS (SELECT 1 FROM offer_item WHERE variant_id = v_m), 'externý predajca cudzie ceny nevidí';
  ASSERT NOT EXISTS (SELECT 1 FROM audit_log WHERE table_name IN ('offer', 'offer_variant', 'offer_item')
                        AND (record_id = v_off OR audit_diff_value(diff, 'variant_id')::uuid = v_m OR audit_diff_value(diff, 'offer_id')::uuid = v_off)),
         'ani ich audit';
  PERFORM set_config('app.user_id', '', true);
  PERFORM set_config('app.require_user', '', true);
  RAISE NOTICE 'OK: C9 interný obchodník vidí ponuku manažéra a jej audit, nie hranicu z odhadu portfólia (hodnoty, kontrola, detail, audit), maržu ani snímku; položky výnimky iba funkciou; offer_item iba ceny; externý predajca nič';
END;
$$;
RESET ROLE;
