-- Kontroly ročnej bilancie zmlúv (0027): 6 príkladov zo zadania modulu 4 (časť 13) na halier, neúplný rok (mesiace / 12),
-- zmluva kratšia ako 12 mesiacov cez dva roky, manažér (odhad portfólia ku dňu podpisu), cenník bez príznaku „Pod
-- hranicou“ (otázka 30), výnimka (hranica z databázy, schválenie, párovanie so zmluvou, Použitá, expirovaná sa
-- nespáruje), prepis minimálneho aditívu výkupu Nákupom, práva (obchodník nevidí maržu ani snímku).
-- Spúšťa sa iba cez db/test/run.sh po checks_zmluvy_import.sql. Predpoklad: skripty cenníkov 2026 a podnikatelia-2026,
-- východiskové cenové parametre z 0023/0027. Trhové ceny rokov 2026 a neskôr (aj z Montelu, F6) sa v transakcii testu
-- označia ako opravené a nahradia testovacími (na konci sa všetko vráti).

-- Trhové ceny: deň podpisu 12. 10. 2026 (BL 95, PL 110 → cena pre obchodníka 2027 = 106; odhad portfólia 97),
-- dnes (odhad portfólia 2027 = 96, cena FVE 70), pred podpisom domácnosti (odhad portfólia 2026 = 200)
SELECT set_config('crm.market_price_correction', 'on', true);
UPDATE market_price_daily SET corrected_at = now()
 WHERE org_id = crm_default_org() AND delivery_year >= 2026 AND corrected_at IS NULL;
SELECT set_config('crm.market_price_correction', '', true);
INSERT INTO market_price_daily (org_id, on_date, delivery_year, bl_eur_mwh, pl_eur_mwh, portfolio_eur_mwh, spot_fve_eur_mwh, source) VALUES
  (crm_default_org(), '2026-10-12', 2027, 95, 110, 97, NULL, 'historia'),
  (crm_default_org(), crm_today(), 2027, 95, 110, 96, 70, 'rucne'),
  (crm_default_org(), '2025-11-28', 2026, NULL, NULL, 200, NULL, 'historia');

-- Obchodník (7001), manažér (7002), firma a domácnosť obchodníka
INSERT INTO app_user (id, email, name, team_id, status, seller_type)
SELECT '00000000-0000-4000-8000-000000007001', 'obchodnik.z3@example.test', 'Obchodník Z3', t.id, 'aktivny', 'obchodnik'
  FROM team t WHERE t.code = 'sales_internal';
INSERT INTO app_user (id, email, name, team_id, status, seller_type)
SELECT '00000000-0000-4000-8000-000000007002', 'manazer.z3@example.test', 'Manažér Z3', t.id, 'aktivny', 'manazer'
  FROM team t WHERE t.code = 'sales_internal';
INSERT INTO app_user_org (user_id, org_id) VALUES
  ('00000000-0000-4000-8000-000000007001', crm_default_org()), ('00000000-0000-4000-8000-000000007002', crm_default_org());
INSERT INTO company (id, name, ico, is_customer, owner_id) VALUES
  ('00000000-0000-4000-8000-000000007101', 'Bilancia Z3 s.r.o.', '99999931', true, '00000000-0000-4000-8000-000000007001');
INSERT INTO company (id, name, ico, is_customer, owner_id) VALUES
  ('00000000-0000-4000-8000-000000007103', 'Výnimka Z3 s.r.o.', '99999932', true, '00000000-0000-4000-8000-000000007001');
INSERT INTO contact (id, first_name, last_name, email, is_household, owner_id) VALUES
  ('00000000-0000-4000-8000-000000007102', 'Domácnosť', 'Bilancia Z3', 'bilancia.z3@example.test', true, '00000000-0000-4000-8000-000000007001');

CREATE FUNCTION pg_temp.z3_eic(p_n integer) RETURNS text LANGUAGE plpgsql AS $f$
DECLARE
  l text;
  c text;
BEGIN
  FOREACH l IN ARRAY string_to_array('KLMNPQRSTUVW', NULL) LOOP
    FOREACH c IN ARRAY string_to_array('0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ', NULL) LOOP
      IF eic_is_valid('24ZZS000BILA' || l || lpad(p_n::text, 2, '0') || c) THEN
        RETURN '24ZZS000BILA' || l || lpad(p_n::text, 2, '0') || c;
      END IF;
    END LOOP;
  END LOOP;
END;
$f$;
CREATE FUNCTION pg_temp.z3_id(p_kind text, p_n integer) RETURNS uuid LANGUAGE sql AS $f$
  SELECT ('00000000-0000-4000-8000-0000000' || CASE p_kind WHEN 'oom' THEN '72' ELSE '73' END || lpad(p_n::text, 3, '0'))::uuid
$f$;
-- OOM firmy Z3 (alebo domácnosti), pri výrobe výkon, kategória zdroja a ručný plán výkupu
CREATE FUNCTION pg_temp.z3_oom(p_n integer, p_type text DEFAULT 'spotreba', p_power numeric DEFAULT NULL,
                               p_feed numeric DEFAULT NULL, p_cat text DEFAULT NULL, p_person boolean DEFAULT false) RETURNS uuid
LANGUAGE sql AS $f$
  INSERT INTO oom (id, company_id, person_id, eic, type, status, source_power_kw, source_category, planned_feed_in_mwh,
                   planned_feed_in_manual)
  VALUES (pg_temp.z3_id('oom', p_n), CASE WHEN p_person THEN NULL ELSE '00000000-0000-4000-8000-000000007101'::uuid END,
          CASE WHEN p_person THEN '00000000-0000-4000-8000-000000007102'::uuid END, pg_temp.z3_eic(p_n), p_type::oom_type,
          'pripravovane', p_power, p_cat::oom_source_category, p_feed, p_feed IS NOT NULL)
  RETURNING id
$f$;
-- Zmluva (vlastník databázy = ako import)
CREATE FUNCTION pg_temp.z3_k(p_n integer, p_type text, p_from date, p_to date, p_signed date,
                             p_owner uuid DEFAULT '00000000-0000-4000-8000-000000007001', p_list boolean DEFAULT false,
                             p_person boolean DEFAULT false, p_package text DEFAULT NULL,
                             p_company uuid DEFAULT '00000000-0000-4000-8000-000000007101') RETURNS uuid LANGUAGE sql AS $f$
  INSERT INTO contract (id, number, company_id, person_id, type, phase, valid_from, valid_to, signed_on, owner_id, list_price, viwa_package)
  VALUES (pg_temp.z3_id('k', p_n), 'Z3-' || p_n, CASE WHEN p_person THEN NULL ELSE p_company END,
          CASE WHEN p_person THEN '00000000-0000-4000-8000-000000007102'::uuid END, p_type::contract_type, 'podpisana',
          p_from, p_to, p_signed, p_owner, p_list, p_package)
  RETURNING id
$f$;
CREATE FUNCTION pg_temp.z3_ko(p_k integer, p_o integer, p_vt numeric, p_nt numeric DEFAULT 0, p_product text DEFAULT NULL,
                              p_power numeric DEFAULT NULL) RETURNS void LANGUAGE sql AS $f$
  INSERT INTO contract_oom (contract_id, oom_id, qty_vt_mwh, qty_nt_mwh, product_id, source_power_kw)
  VALUES (pg_temp.z3_id('k', p_k), pg_temp.z3_id('oom', p_o), p_vt, p_nt, (SELECT id FROM product WHERE code = p_product), p_power)
$f$;
-- Individuálna cena komodity pre všetky OOM zmluvy
CREATE FUNCTION pg_temp.z3_price(p_k integer, p_model text, p_value numeric, p_from date, p_to date,
                                 p_product text DEFAULT 'green_1t') RETURNS void LANGUAGE sql AS $f$
  INSERT INTO contract_price (contract_id, oom_id, slot, product_id, price_model, valid_from, valid_to,
                              price_vt_eur_mwh, additive_eur_mwh, additive_pct)
  SELECT co.contract_id, co.oom_id, 'komodita', (SELECT id FROM product WHERE code = p_product), p_model::price_model, p_from, p_to,
         CASE WHEN p_model = 'fix' THEN p_value END, CASE WHEN p_model IN ('spot_plus_eur', 'spot_minus_eur') THEN p_value END,
         CASE WHEN p_model = 'spot_minus_pct' THEN p_value END
    FROM contract_oom co WHERE co.contract_id = pg_temp.z3_id('k', p_k)
$f$;
CREATE FUNCTION pg_temp.z3_ready(p_k integer) RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  PERFORM contract_price_list_sync(pg_temp.z3_id('k', p_k));
  PERFORM contract_basis_refresh(pg_temp.z3_id('k', p_k));
END;
$f$;

-- Z3-1. Príklady zo zadania (časť 13) na halier
DO $$
DECLARE
  r record;
BEGIN
  -- 1. Firma FIX, 17 OOM, 21,3 MWh, 133 €/MWh 2027, obchodník; cena pre obchodníka 106, odhad portfólia dnes 96
  PERFORM pg_temp.z3_k(1, 'dodavka_firma_nn', '2027-01-01', '2027-12-31', '2026-10-12');
  FOR n IN 1..17 LOOP
    PERFORM pg_temp.z3_oom(n);
    PERFORM pg_temp.z3_ko(1, n, CASE WHEN n = 17 THEN 1.3 ELSE 1.25 END, 0, 'green_1t');
  END LOOP;
  PERFORM pg_temp.z3_price(1, 'fix', 133, '2027-01-01', '2027-12-31');
  PERFORM pg_temp.z3_ready(1);
  SELECT * INTO r FROM contract_year_calc(pg_temp.z3_id('k', 1), 2027);
  ASSERT r.volume_mwh = 21.3 AND r.revenue_eur = 2832.90 AND r.cost_eur = 2257.80, 'príklad 1: objem, výnos, náklad ' || r::text;
  ASSERT r.added_value_eur = 575.10 AND r.margin_eur = 1808.10 AND r.fees_eur = 1020.00 AND r.tranche = 'FIX',
         'príklad 1: pridaná hodnota 575,10, marža 1 808,10 – ' || r::text;
  ASSERT r.trader_price = 106 AND r.basis_stored AND r.basis_source = 'vypocet', 'príklad 1: snímka ceny pre obchodníka 106';

  -- 2. Firma SPOT + aditív 9 €, 2 OOM, 50 MWh, obchodník (minimálny aditív 6)
  PERFORM pg_temp.z3_k(2, 'dodavka_firma_nn', '2027-01-01', '2027-12-31', '2026-10-12');
  PERFORM pg_temp.z3_oom(18); PERFORM pg_temp.z3_oom(19);
  PERFORM pg_temp.z3_ko(2, 18, 25, 0, 'green_1t'); PERFORM pg_temp.z3_ko(2, 19, 25, 0, 'green_1t');
  PERFORM pg_temp.z3_price(2, 'spot_plus_eur', 9, '2027-01-01', '2027-12-31');
  PERFORM pg_temp.z3_ready(2);
  SELECT * INTO r FROM contract_year_calc(pg_temp.z3_id('k', 2), 2027);
  ASSERT r.added_value_eur = 150.00 AND r.margin_eur = 570.00 AND r.tranche = 'SPOT', 'príklad 2: 150 / 570 – ' || r::text;

  -- 3. Domácnosť s energopomocou, DD2, 3 MWh, 2026 (cenník ANO 89,4875; energopomoc 72,40; OM 1,50 a ZEM 1,50 mesačne)
  PERFORM pg_temp.z3_k(3, 'dodavka_domacnost', '2026-01-01', NULL, '2025-12-01', p_list => true, p_person => true);
  PERFORM pg_temp.z3_oom(20, p_person => true);
  PERFORM pg_temp.z3_ko(3, 20, 3, 0, 'green_dd2_ano');
  PERFORM pg_temp.z3_ready(3);
  SELECT * INTO r FROM contract_year_calc(pg_temp.z3_id('k', 3), 2026);
  ASSERT r.added_value_eur = 51.26 AND r.margin_eur = 87.26 AND r.tranche = 'SEAS', 'príklad 3: 51,26 / 87,26 – ' || r::text;

  -- 4. VIWA Plus, výrobné OOM 10 kW, 12 MWh (odhad aditívu 20, účet 6,90, 0,20 €/kW)
  PERFORM pg_temp.z3_oom(21, 'vyroba', 10, 12);
  PERFORM pg_temp.z3_k(4, 'viwa', '2027-01-01', NULL, '2026-10-12', p_package => 'plus');
  PERFORM pg_temp.z3_ko(4, 21, 0, 0, NULL, 10);
  PERFORM pg_temp.z3_ready(4);
  SELECT * INTO r FROM contract_year_calc(pg_temp.z3_id('k', 4), 2027);
  ASSERT r.added_value_eur = 240.00 AND r.margin_eur = 346.80, 'príklad 4: 240 / 346,80 – ' || r::text;

  -- 5. Výkup lokálny zdroj 10 kW, aditív 30 € (plán výkupu 10 × 4 × 365 × 0,1 = 1,46 MWh)
  PERFORM pg_temp.z3_oom(22, 'vyroba', 10, NULL, 'lokalny_zdroj');
  PERFORM pg_temp.z3_k(5, 'vykup', '2027-01-01', NULL, '2026-10-12');
  PERFORM pg_temp.z3_ko(5, 22, 0);
  PERFORM pg_temp.z3_price(5, 'spot_minus_eur', 30, '2027-01-01', NULL, 'vykup_b2b');
  PERFORM pg_temp.z3_ready(5);
  SELECT * INTO r FROM contract_year_calc(pg_temp.z3_id('k', 5), 2027);
  ASSERT r.volume_mwh = 1.46 AND r.added_value_eur = 43.80, 'príklad 5: 43,80 – ' || r::text;

  -- 6. Výkup SPOT − 10 %, 100 MWh, očakávaná cena FVE 70 €/MWh
  PERFORM pg_temp.z3_oom(23, 'vyroba', 500, 100);
  PERFORM pg_temp.z3_k(6, 'vykup', '2027-01-01', NULL, '2026-10-12');
  PERFORM pg_temp.z3_ko(6, 23, 0);
  PERFORM pg_temp.z3_price(6, 'spot_minus_pct', 10, '2027-01-01', NULL, 'vykup_b2b');
  PERFORM pg_temp.z3_ready(6);
  SELECT * INTO r FROM contract_year_calc(pg_temp.z3_id('k', 6), 2027);
  ASSERT r.added_value_eur = 700.00 AND r.margin_eur = 700.00, 'príklad 6: 700 – ' || r::text;
  -- výkup s pevnou cenou: nákup = predaj → pridaná hodnota a marža 0 (otázka 33)
  PERFORM pg_temp.z3_oom(24, 'vyroba', 100, 50);
  PERFORM pg_temp.z3_k(7, 'vykup', '2027-01-01', '2027-12-31', '2026-10-12');
  PERFORM pg_temp.z3_ko(7, 24, 0);
  PERFORM pg_temp.z3_price(7, 'fix', 93, '2027-01-01', '2027-12-31', 'vykup_b2b');
  PERFORM pg_temp.z3_ready(7);
  SELECT * INTO r FROM contract_year_calc(pg_temp.z3_id('k', 7), 2027);
  ASSERT r.added_value_eur = 0 AND r.margin_eur = 0 AND r.revenue_eur = 4650.00 AND r.missing IS NULL, 'výkup FIX: 0 / 0 – ' || r::text;
  RAISE NOTICE 'OK: Z3-1 príklady zo zadania na halier (FIX 575,10 / 1 808,10; SPOT 150 / 570; energopomoc 51,26 / 87,26; VIWA 240 / 346,80; LZ 43,80; výkup −10 %% 700), výkup s pevnou cenou 0 / 0';
END;
$$;

-- Z3-2. Neúplný rok (mesiace / 12), zmluva kratšia ako 12 mesiacov cez dva roky, manažér, cenník pod hranicou bez príznaku
DO $$
DECLARE
  r record;
BEGIN
  -- 1. 9. 2026 – 31. 12. 2027, 12 MWh: rok 2026 = 4/12
  PERFORM pg_temp.z3_oom(30);
  PERFORM pg_temp.z3_k(10, 'dodavka_firma_nn', '2026-09-01', '2027-12-31', '2026-08-01');
  PERFORM pg_temp.z3_ko(10, 30, 12, 0, 'green_1t');
  PERFORM pg_temp.z3_price(10, 'fix', 120, '2026-09-01', '2027-12-31');
  PERFORM pg_temp.z3_ready(10);
  SELECT * INTO r FROM contract_year_calc(pg_temp.z3_id('k', 10), 2026);
  ASSERT r.months = 4 AND r.volume_mwh = 4.000, 'neúplný rok 2026 = 4/12 – ' || r::text;
  SELECT * INTO r FROM contract_year_calc(pg_temp.z3_id('k', 10), 2027);
  ASSERT r.months = 12 AND r.volume_mwh = 12.000, 'celý rok 2027';

  -- 1. 10. 2026 – 31. 3. 2027, 10 MWh: nedelí sa na rok, 2026 = 5, 2027 = 5
  PERFORM pg_temp.z3_oom(31);
  PERFORM pg_temp.z3_k(11, 'dodavka_firma_nn', '2026-10-01', '2027-03-31', '2026-09-01');
  PERFORM pg_temp.z3_ko(11, 31, 10, 0, 'green_1t');
  PERFORM pg_temp.z3_price(11, 'fix', 120, '2026-10-01', '2027-03-31');
  PERFORM pg_temp.z3_ready(11);
  ASSERT (SELECT volume_mwh FROM contract_year_calc(pg_temp.z3_id('k', 11), 2026)) = 5.000
     AND (SELECT volume_mwh FROM contract_year_calc(pg_temp.z3_id('k', 11), 2027)) = 5.000, 'krátka zmluva 5 + 5 MWh';

  -- manažér: náklad pridanej hodnoty = odhad portfólia ku dňu podpisu (97), marža = dnešný (96)
  PERFORM pg_temp.z3_oom(32);
  PERFORM pg_temp.z3_k(12, 'dodavka_firma_nn', '2027-01-01', '2027-12-31', '2026-10-12', '00000000-0000-4000-8000-000000007002');
  PERFORM pg_temp.z3_ko(12, 32, 10, 0, 'green_1t');
  PERFORM pg_temp.z3_price(12, 'fix', 100, '2027-01-01', '2027-12-31');
  PERFORM pg_temp.z3_ready(12);
  SELECT * INTO r FROM contract_year_calc(pg_temp.z3_id('k', 12), 2027);
  ASSERT r.added_value_eur = 30.00 AND r.margin_eur = 100.00,
         'manažér: (100 − 97) × 10 = 30; marža (100 − 96) × 10 + 5 × 12 = 100 – ' || r::text;
  ASSERT r.portfolio_eur_mwh = 96 AND r.portfolio_on = crm_today() AND NOT r.portfolio_stale, 'marža z dnešného odhadu s dátumom';

  -- malý podnik s cenníkom pod odhadom portfólia ku dňu podpisu (200): pridaná hodnota < 0, ale bez príznaku (otázka 30)
  PERFORM pg_temp.z3_oom(33);
  PERFORM pg_temp.z3_k(13, 'dodavka_firma_nn', '2026-01-01', '2026-12-31', '2025-12-01', p_list => true);
  PERFORM pg_temp.z3_ko(13, 33, 5, 0, 'green_dmp1');
  PERFORM pg_temp.z3_ready(13);
  SELECT * INTO r FROM contract_year_calc(pg_temp.z3_id('k', 13), 2026);
  ASSERT r.added_value_eur < 0 AND r.model = 'cennik', 'cenník pod odhadom portfólia – ' || r::text;
  ASSERT NOT EXISTS (SELECT 1 FROM contract_flag WHERE contract_id = pg_temp.z3_id('k', 13) AND code = 'pod_hranicou_bez_vynimky'),
         'cenník bez príznaku Pod hranicou';
  RAISE NOTICE 'OK: Z3-2 neúplný rok 4/12, krátka zmluva 5 + 5 MWh, manažér (odhad ku dňu podpisu / dnešný s dátumom), cenník pod hranicou bez príznaku';
END;
$$;

-- Z3-3. Výnimka: FIX 104 pod cenou pre obchodníka 106 → príznak; žiadosť (hranica z databázy), schválenie, spárovanie
GRANT SELECT, INSERT, UPDATE ON price_exception TO crm_rls_test;
DO $$
BEGIN
  PERFORM pg_temp.z3_oom(40);
  PERFORM pg_temp.z3_k(20, 'dodavka_firma_nn', '2027-01-01', '2027-12-31', crm_today(), p_company => '00000000-0000-4000-8000-000000007103');
  PERFORM pg_temp.z3_ko(20, 40, 50, 0, 'green_1t');
  PERFORM pg_temp.z3_price(20, 'fix', 104, '2027-01-01', '2027-12-31');
  PERFORM pg_temp.z3_ready(20);
  ASSERT (SELECT added_value_eur FROM contract_year_calc(pg_temp.z3_id('k', 20), 2027)) = -100.00, 'pod hranicou: (104 − 106) × 50';
  ASSERT EXISTS (SELECT 1 FROM contract_flag WHERE contract_id = pg_temp.z3_id('k', 20) AND code = 'pod_hranicou_bez_vynimky'
                    AND year = 2027 AND resolved_at IS NULL), 'príznak Pod hranicou bez výnimky 2027';
END;
$$;
SET LOCAL ROLE crm_rls_test;
DO $$
DECLARE
  v_exc uuid;
BEGIN
  PERFORM set_config('app.require_user', 'on', true);
  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-000000007001', true);
  INSERT INTO price_exception (company_id, years, price_model, requested_value, threshold_value, reason)
  VALUES ('00000000-0000-4000-8000-000000007103', '{2027}', 'fix', 103, 0, 'konkurenčná ponuka Z3') RETURNING id INTO v_exc;
  ASSERT (SELECT threshold_value FROM price_exception WHERE id = v_exc) = 106, 'hranica = cena pre obchodníka dnes (nie zo žiadosti)';
  ASSERT (SELECT margin_eur FROM contract_year_calc(pg_temp.z3_id('k', 20), 2027)) IS NULL
     AND (SELECT added_value_eur FROM contract_year_calc(pg_temp.z3_id('k', 20), 2027)) = -100.00,
         'obchodník vidí pridanú hodnotu, nie maržu';
  BEGIN
    PERFORM count(*) FROM contract_year_basis;
    RAISE EXCEPTION 'CHYBA: snímka čitateľná pre aplikáciu';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    UPDATE contract SET vykup_min_additive = 5 WHERE id = pg_temp.z3_id('k', 6);
    RAISE EXCEPTION 'CHYBA: obchodník zmenil minimálny aditív výkupu';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  -- schvaľovateľ (4001, „schvaľuje ceny“)
  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-000000004001', true);
  UPDATE price_exception SET status = 'schvalena', decision_note = 'ok Z3' WHERE id = v_exc;
  PERFORM set_config('app.user_id', '', true);
  PERFORM set_config('app.require_user', '', true);
END;
$$;
RESET ROLE;
DO $$
DECLARE
  r record;
  e price_exception;
BEGIN
  SELECT * INTO e FROM price_exception WHERE reason = 'konkurenčná ponuka Z3';
  ASSERT e.status = 'pouzita' AND e.contract_id = pg_temp.z3_id('k', 20), 'schválená výnimka spárovaná so zmluvou – Použitá';
  SELECT * INTO r FROM contract_year_calc(pg_temp.z3_id('k', 20), 2027);
  ASSERT r.exception_value = 103 AND r.added_value_eur = 50.00, 'hranica z výnimky: (104 − 103) × 50 = 50 – ' || r::text;
  ASSERT NOT EXISTS (SELECT 1 FROM contract_flag WHERE contract_id = pg_temp.z3_id('k', 20) AND code = 'pod_hranicou_bez_vynimky'
                        AND resolved_at IS NULL), 'príznak Pod hranicou uzavretý';

  -- expirovaná výnimka (platná do pred podpisom) sa nespáruje
  INSERT INTO price_exception (company_id, years, price_model, requested_value, threshold_value, reason, status, decided_at, valid_until)
  VALUES ('00000000-0000-4000-8000-000000007101', '{2028}', 'fix', 90, 106, 'expirovaná Z3', 'schvalena', now(), '2026-10-01');
  PERFORM pg_temp.z3_oom(41);
  PERFORM pg_temp.z3_k(21, 'dodavka_firma_nn', '2028-01-01', '2028-12-31', '2026-10-12');
  PERFORM pg_temp.z3_ko(21, 41, 10, 0, 'green_1t');
  PERFORM pg_temp.z3_price(21, 'fix', 91, '2028-01-01', '2028-12-31');
  PERFORM pg_temp.z3_ready(21);
  ASSERT (SELECT status FROM price_exception WHERE reason = 'expirovaná Z3') = 'schvalena'
     AND (SELECT exception_id FROM contract_year_calc(pg_temp.z3_id('k', 21), 2028)) IS NULL, 'expirovaná výnimka sa nespárovala';
  -- bez cien BL/PL 2028 ku dňu podpisu (od 2026) = Chýba cena pre obchodníka s rokom
  ASSERT EXISTS (SELECT 1 FROM contract_flag WHERE contract_id = pg_temp.z3_id('k', 21) AND code = 'chyba_cena' AND year = 2028
                    AND resolved_at IS NULL), 'Chýba cena pre obchodníka 2028';
  -- zmluva podpísaná pred 2026 bez ceny pre obchodníka: bez príznaku (otázka 26)
  PERFORM pg_temp.z3_oom(42);
  PERFORM pg_temp.z3_k(22, 'dodavka_firma_nn', '2026-01-01', '2026-12-31', '2025-11-01');
  PERFORM pg_temp.z3_ko(22, 42, 10, 0, 'green_1t');
  PERFORM pg_temp.z3_price(22, 'fix', 110, '2026-01-01', '2026-12-31');
  PERFORM pg_temp.z3_ready(22);
  ASSERT (SELECT added_value_eur FROM contract_year_calc(pg_temp.z3_id('k', 22), 2026)) IS NULL
     AND NOT EXISTS (SELECT 1 FROM contract_flag WHERE contract_id = pg_temp.z3_id('k', 22) AND resolved_at IS NULL AND year IS NOT NULL),
         'pred 2026 bez ceny pre obchodníka: pridaná hodnota –, bez príznaku';
  -- nákupná cena z HubSpotu (contract_purchase) doplní snímku
  INSERT INTO contract_purchase (contract_id, product_code, delivery_year, priced_on, price_eur_mwh)
  VALUES (pg_temp.z3_id('k', 22), 'GREEN_1T', 2026, '2025-11-01', 101);
  PERFORM contract_basis_refresh(pg_temp.z3_id('k', 22));
  SELECT * INTO r FROM contract_year_calc(pg_temp.z3_id('k', 22), 2026);
  ASSERT r.basis_source = 'hubspot' AND r.trader_price = 101 AND r.added_value_eur = 90.00, 'HubSpot: (110 − 101) × 10 – ' || r::text;

  -- Nákup prepíše minimálny aditív výkupu (vlastník = ako Nákup): príklad 6 → 700 − 5 × 100 = 200
  UPDATE contract SET vykup_min_additive = 5 WHERE id = pg_temp.z3_id('k', 6);
  ASSERT (SELECT added_value_eur FROM contract_year_calc(pg_temp.z3_id('k', 6), 2027)) = 200.00, 'prepis aditívu výkupu';
  BEGIN
    UPDATE contract SET vykup_min_additive = 5 WHERE id = pg_temp.z3_id('k', 1);
    RAISE EXCEPTION 'CHYBA: aditív výkupu pri zmluve o dodávke';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  ASSERT NOT has_table_privilege('crm_app', 'contract_year_basis', 'SELECT')
     AND has_column_privilege('crm_app', 'contract', 'vykup_min_additive', 'UPDATE'), 'práva aplikácie';
  RAISE NOTICE 'OK: Z3-3 výnimka (hranica z databázy, schválenie spáruje zmluvu, Použitá, PH z výnimky, príznak uzavretý; expirovaná nie), Chýba cena pre obchodníka od 2026, pred 2026 bez príznaku, cena z HubSpotu, prepis aditívu výkupu, práva';
END;
$$;
