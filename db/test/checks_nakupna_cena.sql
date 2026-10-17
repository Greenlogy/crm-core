-- Kontroly 0056: nákupná cena portfólia pre rok dodávky „platí od“ dňa (dnes alebo spätne od 1. 1. 2026) – iba admin a Nákup;
-- BL, PL a zdroj dňa ostanú; snímkam zmlúv sa doplní iba chýbajúca cena; marža zmluvy s poslednou cenou, pridaná hodnota
-- sa nemení; marža ponuky spárovanej so zmluvou zmrazená ku dňu spárovania; história zmien; príznak obídenia nepomôže.
-- Spúšťa sa iba cez db/test/run.sh po checks_provizie.sql (pomocné funkcie c_ zo série S, p_ zo série P, f_ zo série F).
-- Roky dodávky 2095, 2096 (iné testy ich nepoužívajú) a 2027 (ponuka a zmluva série F).

GRANT EXECUTE ON FUNCTION market_price_portfolio_set(uuid, date, integer, numeric), market_price_portfolio_history(uuid) TO crm_rls_test;

-- ============================================================================
-- N1. Práva a rozsah: obchodník ani schvaľovateľ cien nie; Nákup a admin áno; deň od 1. 1. 2026 do dnes
-- ============================================================================
SET LOCAL ROLE crm_rls_test;
DO $$
DECLARE
  u integer;
BEGIN
  FOREACH u IN ARRAY ARRAY[1, 4, 5] LOOP
    PERFORM pg_temp.c_as(pg_temp.c_id(u));
    BEGIN
      PERFORM market_price_portfolio_set(crm_default_org(), crm_today(), 2095, 70);
      RAISE EXCEPTION 'CHYBA: nákupnú cenu zadal používateľ %', u;
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
  END LOOP;
  PERFORM pg_temp.c_as(pg_temp.c_id(6));
  BEGIN
    PERFORM market_price_portfolio_set(crm_default_org(), crm_today() + 1, 2095, 70);
    RAISE EXCEPTION 'CHYBA: budúci deň';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    PERFORM market_price_portfolio_set(crm_default_org(), '2025-12-31', 2095, 70);
    RAISE EXCEPTION 'CHYBA: pred 1. 1. 2026';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    PERFORM market_price_portfolio_set(crm_default_org(), '2026-03-02', 2095, -1);
    RAISE EXCEPTION 'CHYBA: záporná cena';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  -- obídenie strážcu príznakom funkcie nepomôže
  PERFORM pg_temp.c_as(pg_temp.c_id(4));
  PERFORM set_config('crm.market_price_portfolio', 'on', true);
  BEGIN
    INSERT INTO market_price_daily (org_id, on_date, delivery_year, portfolio_eur_mwh) VALUES (crm_default_org(), crm_today(), 2095, 1);
    RAISE EXCEPTION 'CHYBA: príznak nákupnej ceny použil používateľ';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM set_config('crm.market_price_portfolio', '', true);
  PERFORM pg_temp.c_as(NULL);
  PERFORM set_config('app.require_user', '', true);
  RAISE NOTICE 'OK: N1 nákupnú cenu portfólia zadá iba admin a Nákup; deň od 1. 1. 2026 do dnes; príznak funkcie používateľovi nepomôže';
END;
$$;
RESET ROLE;

-- ============================================================================
-- N2. Spätne: BL, PL a zdroj dňa (Montel) ostanú, pôvodný záznam ako opravený; rovnaká hodnota nič nemení; platí do ďalšej ceny
-- ============================================================================
INSERT INTO market_price_daily (org_id, on_date, delivery_year, bl_eur_mwh, pl_eur_mwh, source)
VALUES (crm_default_org(), '2026-03-02', 2095, 50, 60, 'historia');
SET LOCAL ROLE crm_rls_test;
DO $$
DECLARE
  r jsonb;
BEGIN
  PERFORM pg_temp.c_as(pg_temp.c_id(6));
  r := market_price_portfolio_set(crm_default_org(), '2026-03-02', 2095, 70);
  ASSERT (r->>'zmena')::boolean AND r->>'plati_do' IS NULL, 'prvá cena: ' || r::text;
  r := market_price_portfolio_set(crm_default_org(), '2026-03-02', 2095, 70);
  ASSERT NOT (r->>'zmena')::boolean, 'rovnaká hodnota nič nemení';
  PERFORM pg_temp.c_as(pg_temp.c_id(3));
  PERFORM market_price_portfolio_set(crm_default_org(), '2026-03-09', 2095, 75);
  r := market_price_portfolio_set(crm_default_org(), '2026-03-02', 2095, 71);
  ASSERT r->>'plati_do' = '2026-03-08', 'platí do dňa pred ďalšou cenou: ' || r::text;
  ASSERT (SELECT count(*) FROM market_price_portfolio_history(crm_default_org()) h WHERE h.delivery_year = 2095) = 2
     AND (SELECT value FROM market_price_portfolio_history(crm_default_org()) h WHERE h.delivery_year = 2095 AND h.is_current) = 75, 'história zmien';
  PERFORM pg_temp.c_as(pg_temp.c_id(1));
  ASSERT NOT EXISTS (SELECT 1 FROM market_price_portfolio_history(crm_default_org())), 'obchodník históriu nákupných cien nevidí';
  PERFORM pg_temp.c_as(NULL);
  PERFORM set_config('app.require_user', '', true);
END;
$$;
RESET ROLE;
DO $$
DECLARE
  m market_price_daily := (SELECT m FROM market_price_daily m WHERE on_date = '2026-03-02' AND delivery_year = 2095 AND corrected_at IS NULL);
BEGIN
  ASSERT (m.bl_eur_mwh, m.pl_eur_mwh, m.portfolio_eur_mwh, m.source, m.changed_by) = (50::numeric, 60::numeric, 71::numeric, 'historia'::text, pg_temp.c_id(3)),
         'BL / PL a zdroj ostali, cena a kto: ' || to_jsonb(m)::text;
  ASSERT (SELECT count(*) FROM market_price_daily WHERE on_date = '2026-03-02' AND delivery_year = 2095 AND corrected_at IS NOT NULL) = 2, 'pôvodné záznamy opravené';
  ASSERT (SELECT value FROM contract_market_value(crm_default_org(), 2095, '2026-03-05', 'portfolio')) = 71
     AND (SELECT value FROM contract_market_value(crm_default_org(), 2095, '2026-03-10', 'portfolio')) = 75, 'platnosť od dňa po ďalšiu cenu';
  RAISE NOTICE 'OK: N2 spätná nákupná cena: BL, PL a zdroj dňa ostanú, pôvodný záznam opravený, rovnaká hodnota nič, platí do ďalšej ceny; história zmien (obchodník nie)';
END;
$$;

-- ============================================================================
-- N3. Snímka zmluvy podpísanej v deň bez ceny sa doplní, existujúca sa nemení; marža s poslednou cenou, pridaná hodnota rovnaká
-- ============================================================================
SELECT pg_temp.p_contract(20, 1, 'dodavka_firma_nn', ARRAY[10], 140, '2096-01-01', '2096-12-31');
UPDATE contract SET signed_on = '2026-03-05' WHERE id = pg_temp.p_id('z', 20);
DELETE FROM contract_year_basis WHERE contract_id = pg_temp.p_id('z', 20);
SELECT contract_basis_refresh(pg_temp.p_id('z', 20));
DO $$
DECLARE
  r      jsonb;
  pv0    numeric;
  m90    numeric;
  m100   numeric;
BEGIN
  ASSERT (SELECT portfolio_eur_mwh FROM contract_year_basis WHERE contract_id = pg_temp.p_id('z', 20) AND year = 2096) IS NULL, 'snímka bez ceny';
  pv0 := (SELECT added_value_eur FROM contract_year_calc_core(pg_temp.p_id('z', 20), 2096));
  PERFORM pg_temp.p_as(pg_temp.p_id('u', 2));                -- admin série P
  r := market_price_portfolio_set(crm_default_org(), '2026-03-01', 2096, 88);
  ASSERT (r->>'zmluvy_doplnene')::int >= 1, 'zmluvy doplnené: ' || r::text;
  ASSERT (SELECT portfolio_eur_mwh FROM contract_year_basis WHERE contract_id = pg_temp.p_id('z', 20) AND year = 2096) = 88, 'snímka doplnená k dňu podpisu';
  PERFORM market_price_portfolio_set(crm_default_org(), '2026-03-03', 2096, 90);
  ASSERT (SELECT portfolio_eur_mwh FROM contract_year_basis WHERE contract_id = pg_temp.p_id('z', 20) AND year = 2096) = 88, 'existujúca snímka sa nemení';
  PERFORM pg_temp.p_as(NULL);                                -- maržu číta vlastník databázy (právo vidieť maržu)
  m90 := (SELECT margin_eur FROM contract_year_calc_core(pg_temp.p_id('z', 20), 2096));
  PERFORM pg_temp.p_as(pg_temp.p_id('u', 2));
  PERFORM market_price_portfolio_set(crm_default_org(), crm_today(), 2096, 100);
  PERFORM pg_temp.p_as(NULL);
  m100 := (SELECT margin_eur FROM contract_year_calc_core(pg_temp.p_id('z', 20), 2096));
  ASSERT m90 - m100 = 10 * 30, 'marža s poslednou cenou (90 → 100 na 30 MWh): ' || coalesce(m90::text, 'null') || ' / ' || coalesce(m100::text, 'null');
  ASSERT (SELECT added_value_eur FROM contract_year_calc_core(pg_temp.p_id('z', 20), 2096)) IS NOT DISTINCT FROM pv0, 'pridaná hodnota sa nezmenila';
  RAISE NOTICE 'OK: N3 snímka zmluvy podpísanej v deň bez ceny sa doplní, existujúca nie; marža s poslednou cenou; pridaná hodnota rovnaká';
END;
$$;

-- ============================================================================
-- N4. Marža ponuky spárovanej so zmluvou zmrazená ku dňu spárovania; marža zmluvy živá
-- ============================================================================
-- zmluva série F spárovaná s akceptovaným variantom (FIX 2027); deň spárovania posunutý dozadu
CREATE TEMP TABLE n4 AS SELECT id, offer_variant_id FROM contract
 WHERE number LIKE 'F5-%' AND deal_match IN ('auto', 'rucne') AND offer_variant_id IS NOT NULL ORDER BY number LIMIT 1;
UPDATE contract SET deal_matched_at = '2026-03-10 10:00+01' WHERE id = (SELECT id FROM n4);
DO $$
DECLARE
  v_k   uuid := (SELECT id FROM n4);
  v_var uuid := (SELECT offer_variant_id FROM n4);
  o1 numeric;
  o2 numeric;
  k1 numeric;
  k2 numeric;
BEGIN
  ASSERT v_var IS NOT NULL, 'zmluva série F spárovaná s variantom ponuky';
  PERFORM pg_temp.p_as(pg_temp.p_id('u', 2));
  PERFORM market_price_portfolio_set(crm_default_org(), '2026-03-05', 2027, 91);
  PERFORM pg_temp.p_as(NULL);
  o1 := (SELECT sum(margin_eur) FROM offer_variant_values_core(v_var));
  k1 := (SELECT margin_eur FROM contract_year_calc_core(v_k, 2027));
  PERFORM pg_temp.p_as(pg_temp.p_id('u', 2));
  PERFORM market_price_portfolio_set(crm_default_org(), crm_today(), 2027, 150);
  PERFORM pg_temp.p_as(NULL);
  o2 := (SELECT sum(margin_eur) FROM offer_variant_values_core(v_var));
  k2 := (SELECT margin_eur FROM contract_year_calc_core(v_k, 2027));
  ASSERT o1 IS NOT NULL AND o1 = o2, 'marža spárovanej ponuky sa nezmenila: ' || coalesce(o1::text, 'null') || ' / ' || coalesce(o2::text, 'null');
  ASSERT k1 <> k2, 'marža zmluvy sa prepočítala: ' || coalesce(k1::text, 'null') || ' / ' || coalesce(k2::text, 'null');
  RAISE NOTICE 'OK: N4 marža ponuky spárovanej so zmluvou zmrazená ku dňu spárovania; marža zmluvy s poslednou cenou';
END;
$$;
