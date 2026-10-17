-- Kontroly modulu 5, fáza F7 (0053): provízie – vznik a podmienky (dátum prechodu, „počítať provízie“, Sales portál),
-- základ zo zmlúv obchodu (záporná PH = 0 €, neurčito 12 mesiacov, trvanie, neúplný základ), prepočet bez uplatnenia,
-- vyrovnanie po uplatnení iba pri spárovaní / zrušení spárovania a zmene štádia (import nič nemení), uplatnenie
-- (číslo CMSN, súčet ≥ 0, admin za obchodníka, kópia), zrušenie listu, preradenie, stráženie, viditeľnosť (RLS);
-- 0054: fronta prepočtov a poradie zámkov, interné funkcie nie pre crm_app / crm_public, príznak „vidí všetky provízie“ iba admin.
-- Spúšťa sa iba cez db/test/run.sh po checks_domov.sql (pomocné funkcie séria B, rola crm_rls_test).
-- Vlastné záznamy: …-0000000a70xx používatelia, a71xx firmy, a72xx OOM, a73xx obchody, a75xx zmluvy.

-- ============================================================================
-- Príprava (vlastník databázy)
-- ============================================================================

CREATE FUNCTION pg_temp.p_id(p_kind text, p_n integer) RETURNS uuid LANGUAGE sql AS $f$
  SELECT ('00000000-0000-4000-8000-0000000' || CASE p_kind WHEN 'u' THEN 'a70' WHEN 'f' THEN 'a71' WHEN 'oom' THEN 'a72'
                                                            WHEN 'd' THEN 'a73' ELSE 'a75' END || lpad(p_n::text, 2, '0'))::uuid
$f$;
CREATE FUNCTION pg_temp.p_eic(p_n integer) RETURNS text LANGUAGE plpgsql AS $f$
DECLARE
  l text;
  c text;
BEGIN
  FOREACH l IN ARRAY string_to_array('KLMNPQRSTUVW', NULL) LOOP
    FOREACH c IN ARRAY string_to_array('0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ', NULL) LOOP
      IF eic_is_valid('24ZZS000ZPRO' || l || lpad(p_n::text, 2, '0') || c) THEN
        RETURN '24ZZS000ZPRO' || l || lpad(p_n::text, 2, '0') || c;
      END IF;
    END LOOP;
  END LOOP;
END;
$f$;
CREATE FUNCTION pg_temp.p_as(p_user uuid) RETURNS text LANGUAGE sql AS $f$
  SELECT set_config('app.require_user', CASE WHEN p_user IS NULL THEN '' ELSE 'on' END, true)
      || set_config('app.user_id', coalesce(p_user::text, ''), true)
$f$;
-- obchod vo Vyjednávaní (vlastník databázy), OOM obchodu
CREATE FUNCTION pg_temp.p_deal(p_n integer, p_company integer, p_owner integer, p_ooms integer[]) RETURNS uuid
LANGUAGE plpgsql AS $f$
DECLARE
  o integer;
BEGIN
  INSERT INTO deal (id, company_id, pipeline_id, stage_id, name, owner_id, source_code, supply_start)
  VALUES (pg_temp.p_id('d', p_n), pg_temp.p_id('f', p_company), pg_temp.b_pipe('b2b_dodavka'), pg_temp.b_stage('b2b_dodavka', 'prilezitost'),
          'P' || p_n, pg_temp.p_id('u', p_owner), 'web', '2027-01-01');
  FOREACH o IN ARRAY p_ooms LOOP
    INSERT INTO deal_oom (deal_id, oom_id) VALUES (pg_temp.p_id('d', p_n), pg_temp.p_id('oom', o));
  END LOOP;
  UPDATE deal SET stage_id = pg_temp.b_stage('b2b_dodavka', 'vyjednavanie') WHERE id = pg_temp.p_id('d', p_n);
  RETURN pg_temp.p_id('d', p_n);
END;
$f$;
-- podpísaná zmluva z importu (čaká na párovanie): OOM po 30 MWh VT, FIX cena za celé obdobie; p_to NULL = neurčito
CREATE FUNCTION pg_temp.p_contract(p_n integer, p_company integer, p_type text, p_ooms integer[], p_price numeric,
                                   p_from date DEFAULT '2027-01-01', p_to date DEFAULT '2027-12-31') RETURNS uuid
LANGUAGE plpgsql AS $f$
DECLARE
  o    integer;
  v_im uuid;
BEGIN
  INSERT INTO contract_import (org_id, user_id, op_file_name) VALUES (crm_default_org(), pg_temp.p_id('u', 2), 'f7-test.xlsx') RETURNING id INTO v_im;
  PERFORM set_config('app.contract_import_id', v_im::text, true);
  INSERT INTO contract (id, number, company_id, type, phase, valid_from, valid_to, signed_on, owner_id)
  VALUES (pg_temp.p_id('z', p_n), 'P7-' || p_n, pg_temp.p_id('f', p_company), p_type::contract_type, 'podpisana', p_from, p_to,
          crm_today(), pg_temp.p_id('u', 1));
  FOREACH o IN ARRAY p_ooms LOOP
    INSERT INTO contract_oom (contract_id, oom_id, qty_vt_mwh, product_id, valid_from, valid_to)
    VALUES (pg_temp.p_id('z', p_n), pg_temp.p_id('oom', o), 30, (SELECT id FROM product WHERE code = 'green_1t'), p_from, p_to);
    INSERT INTO contract_price (contract_id, oom_id, slot, product_id, price_model, valid_from, valid_to, price_vt_eur_mwh)
    VALUES (pg_temp.p_id('z', p_n), pg_temp.p_id('oom', o), 'komodita', (SELECT id FROM product WHERE code = 'green_1t'),
            'fix', p_from, p_to, p_price);
  END LOOP;
  PERFORM contract_basis_refresh(pg_temp.p_id('z', p_n));
  PERFORM set_config('app.contract_import_id', '', true);
  RETURN pg_temp.p_id('z', p_n);
END;
$f$;
-- spárovanie a zrušenie spárovania adminom (ako v aplikácii)
CREATE FUNCTION pg_temp.p_pick(p_contract integer, p_deal integer) RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  PERFORM pg_temp.p_as(pg_temp.p_id('u', 2));
  PERFORM contract_deal_pick(pg_temp.p_id('z', p_contract), pg_temp.p_id('d', p_deal));
  PERFORM pg_temp.p_as(NULL);
END;
$f$;
CREATE FUNCTION pg_temp.p_unlink(p_contract integer) RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  PERFORM pg_temp.p_as(pg_temp.p_id('u', 2));
  PERFORM contract_deal_unlink(pg_temp.p_id('z', p_contract), 'test F7');
  PERFORM pg_temp.p_as(NULL);
END;
$f$;
-- očakávaný základ zmluvy: (cena − hranica ku dňu podpisu) × 30 MWh × počet OOM za každý rok
CREATE FUNCTION pg_temp.p_base(p_contract integer, p_price numeric, p_ooms integer DEFAULT 1) RETURNS numeric LANGUAGE sql AS $f$
  SELECT round(sum((p_price - b.trader_price) * 30 * p_ooms), 2) FROM contract_year_basis b WHERE b.contract_id = pg_temp.p_id('z', p_contract)
$f$;
CREATE FUNCTION pg_temp.p_row(p_deal integer, p_status text DEFAULT 'caka') RETURNS commission LANGUAGE sql AS $f$
  SELECT * FROM commission WHERE deal_id = pg_temp.p_id('d', p_deal) AND status = p_status::commission_status ORDER BY created_at DESC LIMIT 1
$f$;

-- Trhové ceny dnes pre roky 2027 a 2028 (cena pre obchodníka ku dňu podpisu); rok 2093 bez cien (neúplný základ)
SELECT set_config('crm.market_price_correction', 'on', true);
UPDATE market_price_daily SET corrected_at = now()
 WHERE org_id = crm_default_org() AND delivery_year IN (2027, 2028) AND on_date = crm_today() AND corrected_at IS NULL;
SELECT set_config('crm.market_price_correction', '', true);
INSERT INTO market_price_daily (org_id, on_date, delivery_year, bl_eur_mwh, pl_eur_mwh, portfolio_eur_mwh, source) VALUES
  (crm_default_org(), crm_today(), 2027, 95, 110, 96, 'rucne'),
  (crm_default_org(), crm_today(), 2028, 90, 105, 92, 'rucne');

-- tím predajcov s províziami „iba svoje“
INSERT INTO team (id, name, code, description)
VALUES ('00000000-0000-4000-8000-0000000a7000', 'Test predajcovia P', 'test_predajcovia_p', 'testy 0053');
UPDATE team_permission SET view_scope = 'iba_svoje', edit_scope = 'iba_svoje'
 WHERE team_id = '00000000-0000-4000-8000-0000000a7000' AND module IN ('obchod', 'zakaznici', 'odberne_miesta', 'zmluvy');
UPDATE team_permission SET view_scope = 'iba_svoje', edit_scope = 'nic'
 WHERE team_id = '00000000-0000-4000-8000-0000000a7000' AND module = 'provizie';

-- 1 obchodník A, 2 admin, 3 obchodný riaditeľ (Sales_internal, „vidí všetky provízie“), 4 asistent (Sales_internal),
-- 5 Servis, 6 Nákup, 7 obchodník B, 8 obchodník C (provízie vypnuté), 9 CEO (tím „Provízie – všetko“)
INSERT INTO app_user (id, email, name, team_id, status, seller_type, is_admin)
SELECT x.id::uuid, x.email, x.name, t.id, 'aktivny', x.st::seller_type, x.adm
  FROM (VALUES
    ('00000000-0000-4000-8000-0000000a7001', 'obchodnik.a.p@example.test', 'Obchodník A P', 'test_predajcovia_p', 'obchodnik', false),
    ('00000000-0000-4000-8000-0000000a7002', 'admin.p@example.test', 'Admin P', 'sales_internal', NULL, true),
    ('00000000-0000-4000-8000-0000000a7003', 'riaditel.p@example.test', 'Riaditeľ P', 'sales_internal', NULL, false),
    ('00000000-0000-4000-8000-0000000a7004', 'asistent.p@example.test', 'Asistent P', 'sales_internal', NULL, false),
    ('00000000-0000-4000-8000-0000000a7005', 'servis.p@example.test', 'Servis P', 'servis', NULL, false),
    ('00000000-0000-4000-8000-0000000a7006', 'nakup.p@example.test', 'Nákup P', 'nakup', NULL, false),
    ('00000000-0000-4000-8000-0000000a7007', 'obchodnik.b.p@example.test', 'Obchodník B P', 'test_predajcovia_p', 'obchodnik', false),
    ('00000000-0000-4000-8000-0000000a7008', 'obchodnik.c.p@example.test', 'Obchodník C P', 'test_predajcovia_p', 'obchodnik', false),
    ('00000000-0000-4000-8000-0000000a7009', 'ceo.p@example.test', 'CEO P', 'ceo', NULL, false)
  ) AS x(id, email, name, team, st, adm)
  JOIN team t ON t.code = x.team;
INSERT INTO app_user_org (user_id, org_id)
SELECT id, crm_default_org() FROM app_user WHERE id::text LIKE '00000000-0000-4000-8000-0000000a70%'
ON CONFLICT DO NOTHING;
UPDATE app_user SET approves_prices = true, sees_all_commissions = true WHERE id = pg_temp.p_id('u', 3);
UPDATE app_user SET commission_enabled = true WHERE id IN (pg_temp.p_id('u', 1), pg_temp.p_id('u', 7));

-- firmy: 1, 2, 4 obchodníka A, 3 obchodníka C; OOM 1, 2 NN a 3 VN (firma 1), 4 (firma 3), 5 (firma 2), 6, 7, 10 (firma 1), 8, 9 (firma 4)
INSERT INTO company (id, name, ico, address, is_customer, owner_id) VALUES
  (pg_temp.p_id('f', 1), 'Provízie Test P1 s.r.o.', '88880071', 'Hlavná 1, 010 01 Žilina', true, pg_temp.p_id('u', 1)),
  (pg_temp.p_id('f', 2), 'Provízie Test P2 s.r.o.', '88880072', 'Hlavná 2, 010 01 Žilina', true, pg_temp.p_id('u', 1)),
  (pg_temp.p_id('f', 3), 'Provízie Test P3 s.r.o.', '88880073', 'Hlavná 3, 010 01 Žilina', true, pg_temp.p_id('u', 8)),
  (pg_temp.p_id('f', 4), 'Provízie Test P4 s.r.o.', '88880074', 'Hlavná 4, 010 01 Žilina', true, pg_temp.p_id('u', 1));
INSERT INTO oom (id, company_id, eic, type, status, voltage_level, planned_consumption_vt_mwh)
SELECT pg_temp.p_id('oom', n),
       pg_temp.p_id('f', CASE WHEN n IN (1, 2, 3, 6, 7, 10) THEN 1 WHEN n = 4 THEN 3 WHEN n = 5 THEN 2 ELSE 4 END),
       pg_temp.p_eic(n), 'spotreba', 'pripravovane', CASE WHEN n = 3 THEN 'vn' ELSE 'nn' END::voltage_level, 30
  FROM generate_series(1, 10) n;

UPDATE app_setting SET value = 'true' WHERE key = 'deal_matching';
UPDATE app_setting SET value = 'null' WHERE key = 'commission_crm_from';

-- práva ako aplikácia (app-role.sql, 0053): tabuľky iba čítať, funkcie pre aplikáciu
GRANT SELECT ON commission, commission_claim, commission_legacy_override TO crm_rls_test;
GRANT EXECUTE ON FUNCTION crm_commission_sees_all(), crm_commission_visible(uuid, uuid), commission_list(uuid, commission_status, text),
  commission_summary(uuid), commission_claim_create(uuid, uuid[]), commission_claim_void(uuid, text), commission_reassign(uuid, uuid, text),
  commission_legacy_allow(uuid, text), user_commission_enabled_set(uuid, boolean), commission_settings_set(date, uuid[]) TO crm_rls_test;

-- ============================================================================
-- P0. Dátum prechodu: prázdny = provízie z CRM vypnuté (úprava A); po nastavení ich založí nočná poistka
-- ============================================================================
SELECT pg_temp.p_deal(1, 1, 1, ARRAY[1, 3]);
SELECT pg_temp.p_contract(1, 1, 'dodavka_firma_nn', ARRAY[1], 126);
SELECT pg_temp.p_pick(1, 1);
DO $$
DECLARE
  r jsonb;
  c commission;
BEGIN
  ASSERT (SELECT s.code FROM deal d JOIN pipeline_stage s ON s.id = d.stage_id WHERE d.id = pg_temp.p_id('d', 1)) = 'vyhrane', 'obchod Vyhraté';
  ASSERT NOT EXISTS (SELECT 1 FROM commission WHERE deal_id = pg_temp.p_id('d', 1)), 'bez dátumu prechodu žiadna provízia';
  -- dátum prechodu po dnešku: obchod vyhratý dnes províziu nemá
  UPDATE app_setting SET value = to_jsonb(crm_today() + 1) WHERE key = 'commission_crm_from';
  r := commission_daily();
  ASSERT NOT EXISTS (SELECT 1 FROM commission WHERE deal_id = pg_temp.p_id('d', 1)), 'vyhraté pred dátumom prechodu – bez provízie';
  -- admin nastaví dátum prechodu (funkcia), nočná poistka províziu založí
  PERFORM pg_temp.p_as(pg_temp.p_id('u', 7));
  BEGIN
    PERFORM commission_settings_set('2026-10-01', '{}');
    RAISE EXCEPTION 'CHYBA: nastavenia zmenil obchodník';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM pg_temp.p_as(pg_temp.p_id('u', 2));
  PERFORM commission_settings_set('2026-10-01', ARRAY[pg_temp.p_id('u', 3)]);
  PERFORM pg_temp.p_as(NULL);
  ASSERT (SELECT value FROM app_setting WHERE key = 'commission_crm_from') = '"2026-10-01"'
     AND (SELECT value FROM app_setting WHERE key = 'commission_claim_cc') = jsonb_build_array(pg_temp.p_id('u', 3)), 'nastavenia uložené';
  r := commission_daily();
  ASSERT (r->>'provizie_zmena')::int >= 1, 'nočná poistka: ' || r::text;
  c := pg_temp.p_row(1);
  ASSERT c.id IS NOT NULL AND c.kind = 'provizia' AND c.user_id = pg_temp.p_id('u', 1) AND c.source = 'crm', 'provízia vznikla: ' || to_jsonb(c)::text;
  ASSERT c.base_eur = pg_temp.p_base(1, 126) AND c.base_eur > 0 AND c.base_missing IS NULL, 'základ = (cena − hranica) × 30: ' || c.base_eur || ' / ' || pg_temp.p_base(1, 126);
  ASSERT c.pct = user_commission_pct(pg_temp.p_id('u', 1), crm_today()), 'percento v deň Vyhraté';
  ASSERT c.target_eur = round(c.base_eur * c.pct / 100, 2) AND c.amount_eur = c.target_eur, 'cieľ a položka';
  ASSERT c.duration_years = 1 AND c.volume_mwh = 30 AND c.won_at = crm_today(), 'trvanie 1 rok, objem, dátum';
  -- vypnutie dátumu prechodu existujúcu províziu nezruší
  UPDATE app_setting SET value = 'null' WHERE key = 'commission_crm_from';
  PERFORM commission_daily();
  ASSERT (pg_temp.p_row(1)).id IS NOT NULL, 'existujúca provízia ostáva';
  UPDATE app_setting SET value = '"2026-10-01"' WHERE key = 'commission_crm_from';
  RAISE NOTICE 'OK: P0 dátum prechodu: prázdny = vypnuté, vyhraté pred ním bez provízie; nastaví iba admin; provízia = PH zmluvy × percento v deň Vyhraté';
END;
$$;

-- ============================================================================
-- P1. Vznik a základ: „počítať provízie“ vypnuté; záporná PH = 0 €; neurčito = 12 mesiacov; dva roky; neúplný základ;
--     prepočet pri zmene zmluvy, kým nie je uplatnená
-- ============================================================================
SELECT pg_temp.p_deal(2, 3, 8, ARRAY[4]);
SELECT pg_temp.p_contract(2, 3, 'dodavka_firma_nn', ARRAY[4], 150);
SELECT pg_temp.p_pick(2, 2);
SELECT pg_temp.p_deal(3, 2, 1, ARRAY[5]);
SELECT pg_temp.p_contract(3, 2, 'dodavka_firma_nn', ARRAY[5], 60);
SELECT pg_temp.p_pick(3, 3);
SELECT pg_temp.p_deal(4, 1, 1, ARRAY[6]);
SELECT pg_temp.p_contract(4, 1, 'dodavka_firma_nn', ARRAY[6], 206, '2027-01-01', NULL);
SELECT pg_temp.p_pick(4, 4);
SELECT pg_temp.p_deal(5, 1, 1, ARRAY[7]);
SELECT pg_temp.p_contract(5, 1, 'dodavka_firma_nn', ARRAY[7], 160, '2027-01-01', '2028-12-31');
SELECT pg_temp.p_pick(5, 5);
SELECT pg_temp.p_deal(6, 4, 1, ARRAY[8]);
SELECT pg_temp.p_contract(6, 4, 'dodavka_firma_nn', ARRAY[8], 160, '2093-01-01', '2093-12-31');
SELECT pg_temp.p_pick(6, 6);
-- chýbajúca cena pre obchodníka ku dňu podpisu (snímka bez hranice)
UPDATE contract_year_basis SET trader_price = NULL WHERE contract_id = pg_temp.p_id('z', 6);
SELECT commission_queue_run();
DO $$
DECLARE
  c commission;
  v numeric;
BEGIN
  ASSERT NOT EXISTS (SELECT 1 FROM commission WHERE deal_id = pg_temp.p_id('d', 2)), 'vlastník bez „počítať provízie“ – bez provízie';
  c := pg_temp.p_row(3);
  ASSERT c.base_eur < 0 AND c.target_eur = 0 AND c.amount_eur = 0 AND c.status = 'caka', 'záporná PH = 0 €: ' || to_jsonb(c)::text;
  c := pg_temp.p_row(4);
  ASSERT c.duration_years IS NULL AND c.base_eur = pg_temp.p_base(4, 206) AND c.volume_mwh = 30,
         'neurčito: prvých 12 mesiacov (iba 2027), trvanie neurčito: ' || to_jsonb(c)::text;
  ASSERT (SELECT count(*) FROM contract_year_basis WHERE contract_id = pg_temp.p_id('z', 4)) = 1, 'neurčito: snímka iba 2027';
  c := pg_temp.p_row(5);
  ASSERT c.duration_years = 2 AND c.volume_mwh = 60 AND c.base_eur = pg_temp.p_base(5, 160)
     AND (SELECT count(*) FROM contract_year_basis WHERE contract_id = pg_temp.p_id('z', 5)) = 2, 'dva roky: ' || to_jsonb(c)::text;
  c := pg_temp.p_row(6);
  ASSERT c.base_missing = 'chýba cena pre obchodníka k ' || to_char(crm_today(), 'DD.MM.YYYY') || ' (zmluva P7-6, rok 2093)',
         'neúplný základ s dátumom: ' || coalesce(c.base_missing, '–');
  ASSERT EXISTS (SELECT 1 FROM notification WHERE user_id = pg_temp.p_id('u', 2) AND kind = 'provizia_chyba_cena'
                    AND deal_id = pg_temp.p_id('d', 6) AND detail = c.base_missing), 'upozornenie adminovi (doplniť cenu)';
  PERFORM commission_daily();
  ASSERT (SELECT count(*) FROM notification WHERE user_id = pg_temp.p_id('u', 2) AND kind = 'provizia_chyba_cena' AND deal_id = pg_temp.p_id('d', 6)) = 1,
         'upozornenie raz'; 
  -- zmena ceny zmluvy z importu prepočíta čakajúcu províziu
  PERFORM set_config('app.contract_import_id', (SELECT id::text FROM contract_import ORDER BY created_at DESC LIMIT 1), true);
  UPDATE contract_price SET price_vt_eur_mwh = 136 WHERE contract_id = pg_temp.p_id('z', 1);
  PERFORM set_config('app.contract_import_id', '', true);
  -- 0054: import provízie nezamyká ani neprepočítava – obchod je vo fronte, prepočíta ho beh na pozadí
  ASSERT (pg_temp.p_row(1)).base_eur = pg_temp.p_base(1, 126)
     AND EXISTS (SELECT 1 FROM commission_queue WHERE deal_id = pg_temp.p_id('d', 1)), 'zmena bilancie → fronta, provízia zatiaľ nezmenená';
  ASSERT (commission_queue_run()->>'fronta_spracovane')::int >= 1, 'fronta spracovaná';
  ASSERT NOT EXISTS (SELECT 1 FROM commission_queue WHERE deal_id = pg_temp.p_id('d', 1)), 'fronta prázdna';
  c := pg_temp.p_row(1);
  v := pg_temp.p_base(1, 136);
  ASSERT c.base_eur = v AND c.amount_eur = round(v * c.pct / 100, 2) AND c.recalculated_at IS NOT NULL, 'prepočet po zmene ceny: ' || to_jsonb(c)::text;
  -- vrátiť cenu 126
  PERFORM set_config('app.contract_import_id', (SELECT id::text FROM contract_import ORDER BY created_at DESC LIMIT 1), true);
  UPDATE contract_price SET price_vt_eur_mwh = 126 WHERE contract_id = pg_temp.p_id('z', 1);
  PERFORM set_config('app.contract_import_id', '', true);
  PERFORM commission_queue_run();
  ASSERT (pg_temp.p_row(1)).base_eur = pg_temp.p_base(1, 126), 'späť na 126';
  RAISE NOTICE 'OK: P1 vypnuté provízie bez provízie; záporná PH = 0 €; neurčito 12 mesiacov; dva roky; neúplný základ; prepočet pri zmene zmluvy';
END;
$$;

-- ============================================================================
-- P2. Uplatnenie: cudzí obchodník nie, neúplný základ nie, číslo CMSN, kópia; uplatnená sa neprepočíta (import)
-- ============================================================================
DO $$
DECLARE
  v_claim uuid;
  k       commission_claim;
  c1      commission := pg_temp.p_row(1);
  c3      commission := pg_temp.p_row(3);
BEGIN
  PERFORM pg_temp.p_as(pg_temp.p_id('u', 7));
  BEGIN
    PERFORM commission_claim_create(pg_temp.p_id('u', 1), ARRAY[c1.id]);
    RAISE EXCEPTION 'CHYBA: cudzí obchodník uplatnil';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    PERFORM commission_claim_create(pg_temp.p_id('u', 7), ARRAY[c1.id]);
    RAISE EXCEPTION 'CHYBA: uplatnil cudziu províziu ako svoju';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  PERFORM pg_temp.p_as(pg_temp.p_id('u', 1));
  BEGIN
    PERFORM commission_claim_create(pg_temp.p_id('u', 1), ARRAY[(pg_temp.p_row(6)).id]);
    RAISE EXCEPTION 'CHYBA: neúplný základ uplatnený';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    PERFORM commission_claim_create(pg_temp.p_id('u', 1), ARRAY[c3.id]);
    RAISE EXCEPTION 'CHYBA: list iba s nulovou províziou';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  v_claim := commission_claim_create(pg_temp.p_id('u', 1), ARRAY[c1.id, c3.id]);
  PERFORM pg_temp.p_as(NULL);
  SELECT * INTO k FROM commission_claim WHERE id = v_claim;
  ASSERT k.number ~ ('^CMSN-' || extract(year FROM crm_today()) || '-[0-9]{4}$') AND k.user_id = pg_temp.p_id('u', 1)
     AND k.created_by = pg_temp.p_id('u', 1) AND k.total_eur = c1.amount_eur AND k.by_duration = jsonb_build_object('1', c1.amount_eur),
         'list: ' || to_jsonb(k)::text;
  ASSERT (SELECT count(*) FROM commission WHERE claim_id = v_claim AND status = 'uplatnena') = 2, 'položky uplatnené';
  ASSERT EXISTS (SELECT 1 FROM notification WHERE user_id = pg_temp.p_id('u', 3) AND kind = 'provizny_list' AND commission_claim_id = v_claim
                    AND detail NOT LIKE '%€%'), 'kópia príjemcovi (bez sumy)';
  ASSERT NOT EXISTS (SELECT 1 FROM notification WHERE user_id = pg_temp.p_id('u', 1) AND commission_claim_id = v_claim), 'obchodník sám – bez upozornenia';
  -- import po uplatnení nič nemení
  PERFORM set_config('app.contract_import_id', (SELECT id::text FROM contract_import ORDER BY created_at DESC LIMIT 1), true);
  UPDATE contract_price SET price_vt_eur_mwh = 146 WHERE contract_id = pg_temp.p_id('z', 1);
  PERFORM set_config('app.contract_import_id', '', true);
  PERFORM commission_daily();
  ASSERT NOT EXISTS (SELECT 1 FROM commission WHERE deal_id = pg_temp.p_id('d', 1) AND status = 'caka'), 'po uplatnení import ani nočný beh vyrovnanie netvoria';
  ASSERT (SELECT (amount_eur, base_eur) FROM commission WHERE id = c1.id) = ROW(c1.amount_eur, c1.base_eur), 'uplatnená sa nezmenila';
  PERFORM set_config('app.contract_import_id', (SELECT id::text FROM contract_import ORDER BY created_at DESC LIMIT 1), true);
  UPDATE contract_price SET price_vt_eur_mwh = 126 WHERE contract_id = pg_temp.p_id('z', 1);
  PERFORM set_config('app.contract_import_id', '', true);
  RAISE NOTICE 'OK: P2 uplatnenie: iba vlastné čakajúce, neúplný základ nie, iba nulová nie; číslo CMSN, kópia bez sumy; import po uplatnení nič nemení';
END;
$$;

-- ============================================================================
-- P3. Vyrovnanie po uplatnení: spárovanie druhej zmluvy (+), zrušenie jej spárovania (0 → zrušené),
--     zrušenie poslednej zmluvy a návrat štádia (−); záporná položka sa samostatne neuplatní; admin za obchodníka
-- ============================================================================
SELECT pg_temp.p_contract(7, 1, 'dodavka_firma_vn', ARRAY[3], 116);
SELECT pg_temp.p_pick(7, 1);
DO $$
DECLARE
  c1      commission := (SELECT c FROM commission c WHERE deal_id = pg_temp.p_id('d', 1) AND status = 'uplatnena');
  v       commission;
  v_claim uuid;
BEGIN
  v := pg_temp.p_row(1);
  ASSERT v.kind = 'vyrovnanie' AND v.target_eur = round((pg_temp.p_base(1, 126) + pg_temp.p_base(7, 116)) * v.pct / 100, 2)
     AND v.amount_eur = v.target_eur - c1.amount_eur AND v.amount_eur > 0, 'vyrovnanie po druhej zmluve: ' || to_jsonb(v)::text;
  ASSERT EXISTS (SELECT 1 FROM notification WHERE user_id = pg_temp.p_id('u', 1) AND kind = 'provizia_vyrovnanie' AND deal_id = pg_temp.p_id('d', 1)
                    AND detail NOT LIKE '%P1%'), 'upozornenie o vyrovnaní (bez názvu obchodu)';
  PERFORM pg_temp.p_unlink(7);
  ASSERT NOT EXISTS (SELECT 1 FROM commission WHERE deal_id = pg_temp.p_id('d', 1) AND status = 'caka'), 'rozdiel 0 – vyrovnanie zrušené';
  ASSERT (SELECT status FROM commission WHERE id = v.id) = 'zrusena', 'zrušené vyrovnanie ostáva v histórii';
  PERFORM pg_temp.p_unlink(1);
  ASSERT (SELECT s.code FROM deal d JOIN pipeline_stage s ON s.id = d.stage_id WHERE d.id = pg_temp.p_id('d', 1)) = 'vyjednavanie', 'obchod späť vo Vyjednávaní';
  v := pg_temp.p_row(1);
  ASSERT v.kind = 'vyrovnanie' AND v.target_eur = 0 AND v.amount_eur = -c1.amount_eur
     AND (SELECT count(*) FROM commission WHERE deal_id = pg_temp.p_id('d', 1) AND status = 'caka') = 1, 'záporné vyrovnanie: ' || to_jsonb(v)::text;
  PERFORM pg_temp.p_as(pg_temp.p_id('u', 1));
  BEGIN
    PERFORM commission_claim_create(pg_temp.p_id('u', 1), ARRAY[v.id]);
    RAISE EXCEPTION 'CHYBA: samostatné záporné vyrovnanie';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  -- admin uplatní za obchodníka: neurčito (kladné) + záporné vyrovnanie, súčet ≥ 0
  PERFORM pg_temp.p_as(pg_temp.p_id('u', 2));
  v_claim := commission_claim_create(pg_temp.p_id('u', 1), ARRAY[(pg_temp.p_row(4)).id, v.id]);
  PERFORM pg_temp.p_as(NULL);
  ASSERT (SELECT (created_by, user_id, total_eur) FROM commission_claim WHERE id = v_claim)
         = ROW(pg_temp.p_id('u', 2), pg_temp.p_id('u', 1), (SELECT sum(amount_eur) FROM commission WHERE claim_id = v_claim)), 'admin za obchodníka';
  ASSERT (SELECT by_duration FROM commission_claim WHERE id = v_claim) ? 'neurcito', 'skupina neurčito';
  ASSERT EXISTS (SELECT 1 FROM notification WHERE user_id = pg_temp.p_id('u', 1) AND kind = 'provizny_list' AND commission_claim_id = v_claim),
         'obchodník dostal upozornenie, že za neho uplatnil admin';
  RAISE NOTICE 'OK: P3 vyrovnanie po uplatnení: druhá zmluva +, zrušenie spárovania 0 / −, záporné samostatne nie; admin uplatní za obchodníka (kto uplatnil)';
END;
$$;

-- ============================================================================
-- P4. Zrušenie listu: iba admin s dôvodom; položky späť na Čaká a prepočet; číslo sa znova nepoužije
-- ============================================================================
DO $$
DECLARE
  k      commission_claim := (SELECT k FROM commission_claim k WHERE user_id = pg_temp.p_id('u', 1) AND created_by = pg_temp.p_id('u', 2));
  c4     commission;
  v_next uuid;
BEGIN
  PERFORM pg_temp.p_as(pg_temp.p_id('u', 3));
  BEGIN
    PERFORM commission_claim_void(k.id, 'chyba v liste');
    RAISE EXCEPTION 'CHYBA: list zrušil neadmin';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM pg_temp.p_as(pg_temp.p_id('u', 2));
  BEGIN
    PERFORM commission_claim_void(k.id, ' x ');
    RAISE EXCEPTION 'CHYBA: krátky dôvod';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  PERFORM commission_claim_void(k.id, 'chyba v liste');
  BEGIN
    PERFORM commission_claim_void(k.id, 'znova');
    RAISE EXCEPTION 'CHYBA: zrušené dvakrát';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  PERFORM pg_temp.p_as(NULL);
  ASSERT (SELECT (voided_by, void_reason) FROM commission_claim WHERE id = k.id) = ROW(pg_temp.p_id('u', 2), 'chyba v liste'::text), 'list zrušený';
  ASSERT NOT EXISTS (SELECT 1 FROM commission WHERE claim_id = k.id), 'položky bez listu';
  c4 := pg_temp.p_row(4);
  ASSERT c4.amount_eur = c4.target_eur AND c4.amount_eur > 0, 'neurčito späť na Čaká';
  ASSERT (pg_temp.p_row(1)).amount_eur = -(SELECT amount_eur FROM commission WHERE deal_id = pg_temp.p_id('d', 1) AND status = 'uplatnena'),
         'záporné vyrovnanie späť na Čaká (prvý list ostáva uplatnený)';
  ASSERT (SELECT count(*) FROM commission WHERE deal_id = pg_temp.p_id('d', 1) AND status = 'caka') = 1, 'stále jedna čakajúca na obchod';
  ASSERT EXISTS (SELECT 1 FROM notification WHERE user_id = pg_temp.p_id('u', 1) AND kind = 'provizny_list_zruseny' AND commission_claim_id = k.id), 'upozornenie';
  PERFORM pg_temp.p_as(pg_temp.p_id('u', 1));
  v_next := commission_claim_create(pg_temp.p_id('u', 1), ARRAY[c4.id]);
  PERFORM pg_temp.p_as(NULL);
  ASSERT (SELECT number FROM commission_claim WHERE id = v_next) > k.number, 'nové číslo, zrušené sa nepoužije';
  -- po uplatnení sa k obchodu spáruje ďalšia zmluva (vyrovnanie čaká); zrušenie listu ich spojí do jednej čakajúcej
  PERFORM pg_temp.p_contract(10, 1, 'dodavka_firma_nn', ARRAY[10], 146);
  PERFORM pg_temp.p_pick(10, 4);
  ASSERT (pg_temp.p_row(4)).kind = 'vyrovnanie', 'vyrovnanie po ďalšej zmluve';
  PERFORM pg_temp.p_as(pg_temp.p_id('u', 2));
  PERFORM commission_claim_void(v_next, 'späť pre test');
  PERFORM pg_temp.p_as(NULL);
  ASSERT (SELECT count(*) FROM commission WHERE deal_id = pg_temp.p_id('d', 4) AND status = 'caka') = 1
     AND (pg_temp.p_row(4)).id = c4.id
     AND (pg_temp.p_row(4)).amount_eur = round((pg_temp.p_base(4, 206) + pg_temp.p_base(10, 146)) * c4.pct / 100, 2),
         'po zrušení listu jedna čakajúca s celou províziou: ' || to_jsonb(pg_temp.p_row(4))::text;
  RAISE NOTICE 'OK: P4 zrušenie listu iba admin s dôvodom a raz; položky späť na Čaká s prepočtom, stále jedna na obchod; číslo sa nepoužije znova';
END;
$$;

-- ============================================================================
-- P5. Preradenie (admin s dôvodom); nový vlastník provízie ju uplatní, pôvodný nie
-- ============================================================================
DO $$
DECLARE
  c4 commission := pg_temp.p_row(4);
BEGIN
  PERFORM pg_temp.p_as(pg_temp.p_id('u', 3));
  BEGIN
    PERFORM commission_reassign(pg_temp.p_id('d', 4), pg_temp.p_id('u', 7), 'odchod obchodníka');
    RAISE EXCEPTION 'CHYBA: preradil neadmin';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM pg_temp.p_as(pg_temp.p_id('u', 2));
  BEGIN
    PERFORM commission_reassign(pg_temp.p_id('d', 4), pg_temp.p_id('u', 7), '');
    RAISE EXCEPTION 'CHYBA: bez dôvodu';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  PERFORM commission_reassign(pg_temp.p_id('d', 4), pg_temp.p_id('u', 7), 'odchod obchodníka');
  PERFORM pg_temp.p_as(NULL);
  ASSERT (SELECT (user_id, reassigned_from, reassigned_by, reassign_reason) FROM commission WHERE id = c4.id)
         = ROW(pg_temp.p_id('u', 7), pg_temp.p_id('u', 1), pg_temp.p_id('u', 2), 'odchod obchodníka'::text), 'preradené';
  ASSERT (SELECT count(*) FROM notification WHERE kind = 'provizia_preradena' AND deal_id = pg_temp.p_id('d', 4)) = 2, 'upozornenie obom';
  -- nočná poistka preradenie nevráti
  PERFORM commission_daily();
  ASSERT (pg_temp.p_row(4)).user_id = pg_temp.p_id('u', 7), 'preradenie platí aj po prepočte';
  PERFORM pg_temp.p_as(pg_temp.p_id('u', 1));
  BEGIN
    PERFORM commission_claim_create(pg_temp.p_id('u', 1), ARRAY[c4.id]);
    RAISE EXCEPTION 'CHYBA: pôvodný obchodník uplatnil preradenú';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  PERFORM pg_temp.p_as(NULL);
  RAISE NOTICE 'OK: P5 preradenie iba admin s dôvodom, upozornenie obom, platí po prepočte; pôvodný obchodník ju neuplatní';
END;
$$;

-- ============================================================================
-- P6. Sales portál (úprava B): zhoda podľa EIC a obdobia aj podľa ID dealu z HubSpotu → bez provízie z CRM,
--     upozornenie adminom raz, admin povolí s dôvodom; história sa nemení
-- ============================================================================
INSERT INTO commission (id, org_id, user_id, status, won_at, duration_years, volume_mwh, base_eur, pct, target_eur, amount_eur, source,
                        legacy_id, legacy_hubspot_deal_id, legacy_deal_name, legacy_eics, legacy_supply_from, legacy_supply_to)
VALUES ('00000000-0000-4000-8000-0000000a7601', crm_default_org(), pg_temp.p_id('u', 1), 'caka', '2026-09-20', 1, 30, 900, 40, 360, 360,
        'sales_portal', 'fs-p7-1', '999000111', 'Portál P8', ARRAY[pg_temp.p_eic(2)], '2027-01-01', '2027-12-31'),
       ('00000000-0000-4000-8000-0000000a7602', crm_default_org(), pg_temp.p_id('u', 1), 'caka', '2026-09-21', 1, 30, 500, 40, 200, 200,
        'sales_portal', 'fs-p7-2', '999000222', 'Portál P9', NULL, NULL, NULL);
SELECT pg_temp.p_deal(8, 1, 1, ARRAY[2]);
SELECT pg_temp.p_contract(8, 1, 'dodavka_firma_nn', ARRAY[2], 126);
SELECT pg_temp.p_pick(8, 8);
SELECT pg_temp.p_deal(9, 4, 1, ARRAY[9]);
UPDATE deal SET hubspot_id = '999000222' WHERE id = pg_temp.p_id('d', 9);
SELECT pg_temp.p_contract(9, 4, 'dodavka_firma_nn', ARRAY[9], 126, '2029-01-01', '2029-12-31');
SELECT pg_temp.p_pick(9, 9);
DO $$
BEGIN
  ASSERT NOT EXISTS (SELECT 1 FROM commission WHERE deal_id = pg_temp.p_id('d', 8)), 'EIC + obdobie zo Sales portálu – bez provízie';
  ASSERT NOT EXISTS (SELECT 1 FROM commission WHERE deal_id = pg_temp.p_id('d', 9)), 'rovnaký deal z HubSpotu – bez provízie';
  ASSERT EXISTS (SELECT 1 FROM notification WHERE user_id = pg_temp.p_id('u', 2) AND kind = 'provizia_duplicita' AND deal_id = pg_temp.p_id('d', 8)),
         'upozornenie adminovi';
  PERFORM commission_daily();
  ASSERT (SELECT count(*) FROM notification WHERE user_id = pg_temp.p_id('u', 2) AND kind = 'provizia_duplicita' AND deal_id = pg_temp.p_id('d', 8)) = 1, 'raz';
  -- iné obdobie toho istého EIC sa nezhoduje
  UPDATE commission SET legacy_supply_from = '2025-01-01', legacy_supply_to = '2025-12-31' WHERE id = '00000000-0000-4000-8000-0000000a7601';
  RAISE EXCEPTION 'CHYBA: história sa zmenila';
EXCEPTION WHEN insufficient_privilege THEN
  RAISE NOTICE 'OK: P6a zhoda so Sales portálom (EIC + obdobie, ID dealu) – bez provízie, upozornenie adminom raz; história sa nemení';
END;
$$;
DO $$
DECLARE
  c commission;
BEGIN
  PERFORM pg_temp.p_as(pg_temp.p_id('u', 1));
  BEGIN
    PERFORM commission_legacy_allow(pg_temp.p_id('d', 8), 'iné obdobie');
    RAISE EXCEPTION 'CHYBA: povolil obchodník';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM pg_temp.p_as(pg_temp.p_id('u', 2));
  ASSERT commission_legacy_allow(pg_temp.p_id('d', 8), 'iný obchod toho istého OOM'), 'povolené a založené';
  PERFORM pg_temp.p_as(NULL);
  c := pg_temp.p_row(8);
  ASSERT c.id IS NOT NULL AND c.source = 'crm' AND c.base_eur = pg_temp.p_base(8, 126), 'provízia po povolení';
  ASSERT (SELECT legacy_commission_id FROM commission_legacy_override WHERE deal_id = pg_temp.p_id('d', 8)) = '00000000-0000-4000-8000-0000000a7601', 'záznam povolenia';
  -- čakajúcu províziu zo Sales portálu obchodník uplatní v CRM (mení sa iba stav a list)
  PERFORM pg_temp.p_as(pg_temp.p_id('u', 1));
  PERFORM commission_claim_create(pg_temp.p_id('u', 1), ARRAY['00000000-0000-4000-8000-0000000a7602'::uuid]);
  PERFORM pg_temp.p_as(NULL);
  ASSERT (SELECT (status, amount_eur) FROM commission WHERE id = '00000000-0000-4000-8000-0000000a7602') = ROW('uplatnena'::commission_status, 200::numeric),
         'história uplatnená s pôvodnou sumou';
  RAISE NOTICE 'OK: P6b admin povolí províziu napriek zhode s dôvodom; čakajúca provízia zo Sales portálu sa dá uplatniť s pôvodnou sumou';
END;
$$;

-- ============================================================================
-- P7. Stráženie: uplatnená a zrušená sa nemenia, nič sa nemaže; list sa nemení; obchod mimo Vyhraté bez uplatnenia → Zrušená
-- ============================================================================
DO $$
DECLARE
  v_c uuid := (SELECT id FROM commission WHERE deal_id = pg_temp.p_id('d', 1) AND status = 'uplatnena');
  v_k uuid := (SELECT claim_id FROM commission WHERE id = v_c);
BEGIN
  BEGIN
    UPDATE commission SET amount_eur = amount_eur + 1 WHERE id = v_c;
    RAISE EXCEPTION 'CHYBA: uplatnená zmenená';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    DELETE FROM commission WHERE id = v_c;
    RAISE EXCEPTION 'CHYBA: zmazaná';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    UPDATE commission_claim SET total_eur = 1 WHERE id = v_k;
    RAISE EXCEPTION 'CHYBA: list zmenený';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    UPDATE commission SET status = 'zrusena' WHERE id = v_c;
    RAISE EXCEPTION 'CHYBA: uplatnená zrušená bez listu';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  UPDATE commission_claim SET pdf_key = 'provizie/test.pdf', emailed_at = now() WHERE id = v_k;
  BEGIN
    UPDATE commission_claim SET pdf_key = 'provizie/iny.pdf' WHERE id = v_k;
    RAISE EXCEPTION 'CHYBA: PDF prepísané';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  -- obchod 5 (bez uplatnenia) mimo Vyhraté → položka Zrušená; zrušená sa nemení
  PERFORM pg_temp.p_unlink(5);
  ASSERT NOT EXISTS (SELECT 1 FROM commission WHERE deal_id = pg_temp.p_id('d', 5) AND status = 'caka')
     AND EXISTS (SELECT 1 FROM commission WHERE deal_id = pg_temp.p_id('d', 5) AND status = 'zrusena'), 'mimo Vyhraté → Zrušená';
  BEGIN
    UPDATE commission SET amount_eur = 5 WHERE deal_id = pg_temp.p_id('d', 5) AND status = 'zrusena';
    RAISE EXCEPTION 'CHYBA: zrušená zmenená';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  -- opätovné spárovanie: nová provízia
  PERFORM pg_temp.p_pick(5, 5);
  ASSERT (pg_temp.p_row(5)).id IS NOT NULL AND (pg_temp.p_row(5)).base_eur = pg_temp.p_base(5, 160), 'po opätovnom Vyhraté nová položka';
  RAISE NOTICE 'OK: P7 stráženie: uplatnená, zrušená a list sa nemenia, nič sa nemaže, PDF sa neprepisuje; mimo Vyhraté → Zrušená, nové Vyhraté → nová';
END;
$$;

-- ============================================================================
-- P8. „Počítať provízie“ mení admin a schvaľovateľ cien; vypnutie platí pre nové obchody
-- ============================================================================
DO $$
BEGIN
  PERFORM pg_temp.p_as(pg_temp.p_id('u', 7));
  BEGIN
    PERFORM user_commission_enabled_set(pg_temp.p_id('u', 8), true);
    RAISE EXCEPTION 'CHYBA: zmenil obchodník';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM pg_temp.p_as(pg_temp.p_id('u', 3));
  PERFORM user_commission_enabled_set(pg_temp.p_id('u', 8), true);
  PERFORM pg_temp.p_as(NULL);
  ASSERT (SELECT commission_enabled FROM app_user WHERE id = pg_temp.p_id('u', 8)), 'zapnuté';
  -- nočná poistka založí províziu obchodu 2 (vyhratý po dátume prechodu)
  PERFORM commission_daily();
  ASSERT (pg_temp.p_row(2)).user_id = pg_temp.p_id('u', 8), 'po zapnutí vznikne';
  UPDATE app_user SET commission_enabled = false WHERE id = pg_temp.p_id('u', 8);
  PERFORM commission_daily();
  ASSERT (pg_temp.p_row(2)).id IS NOT NULL, 'vypnutie existujúcu nezruší';
  RAISE NOTICE 'OK: P8 „počítať provízie“ mení admin / schvaľovateľ cien, nie obchodník; platí pre nové obchody';
END;
$$;
INSERT INTO app_user (email, name, team_id, status) SELECT 'novy.p@example.test', 'Nový P', id, 'aktivny' FROM team WHERE code = 'test_predajcovia_p';
DO $$
BEGIN
  ASSERT NOT (SELECT commission_enabled FROM app_user WHERE email = 'novy.p@example.test'), 'nový používateľ: počítať provízie vypnuté (odpoveď 5)';
  RAISE NOTICE 'OK: P8b nový používateľ má „počítať provízie“ predvolene vypnuté';
END;
$$;

-- ============================================================================
-- P9. Viditeľnosť (úprava C): vlastné; všetky admin, „Provízie – všetko“ (CEO) a príznak (riaditeľ);
--     Back office, Nákup, asistent nič, hoci obchod vidia; aplikácia tabuľky nemení; interné funkcie nespustí
-- ============================================================================
SET LOCAL ROLE crm_rls_test;
DO $$
DECLARE
  n_all integer;
  s     jsonb;
BEGIN
  PERFORM pg_temp.p_as(pg_temp.p_id('u', 2));
  n_all := (SELECT count(*) FROM commission WHERE user_id::text LIKE '00000000-0000-4000-8000-0000000a70%');
  ASSERT n_all >= 8, 'admin vidí všetky: ' || n_all;
  PERFORM pg_temp.p_as(pg_temp.p_id('u', 9));
  ASSERT (SELECT count(*) FROM commission WHERE user_id::text LIKE '00000000-0000-4000-8000-0000000a70%') = n_all, 'CEO (tím „Provízie – všetko“) všetky';
  PERFORM pg_temp.p_as(pg_temp.p_id('u', 3));
  ASSERT (SELECT count(*) FROM commission WHERE user_id::text LIKE '00000000-0000-4000-8000-0000000a70%') = n_all, 'riaditeľ s príznakom všetky';
  PERFORM pg_temp.p_as(pg_temp.p_id('u', 1));
  ASSERT (SELECT count(*) FROM commission WHERE user_id <> pg_temp.p_id('u', 1)) = 0
     AND (SELECT count(*) FROM commission WHERE user_id = pg_temp.p_id('u', 1)) > 0, 'obchodník A iba svoje';
  ASSERT (SELECT count(*) FROM commission_claim WHERE user_id <> pg_temp.p_id('u', 1)) = 0, 'listy iba svoje';
  ASSERT NOT EXISTS (SELECT 1 FROM commission_list() l WHERE l.user_id <> pg_temp.p_id('u', 1)), 'zoznam iba svoje';
  ASSERT EXISTS (SELECT 1 FROM commission_list(NULL, 'zrusena') WHERE status = 'zrusena')
     AND NOT EXISTS (SELECT 1 FROM commission_list() WHERE status = 'zrusena'), 'zrušené iba na vyžiadanie';
  ASSERT (SELECT count(*) FROM commission_list(NULL, NULL, 'portál p9')) = 1, 'hľadanie (bez ohľadu na veľkosť písmen)';
  ASSERT (SELECT deal_name FROM commission_list() WHERE id = '00000000-0000-4000-8000-0000000a7602') = 'Portál P9', 'história s názvom dealu';
  s := commission_summary();
  ASSERT (s->>'unpaid_eur')::numeric = (SELECT sum(amount_eur) FROM commission WHERE status = 'caka')
     AND (s->>'year_eur')::numeric = (SELECT coalesce(sum(c.amount_eur), 0) FROM commission c JOIN commission_claim k ON k.id = c.claim_id
                                       WHERE c.status = 'uplatnena' AND k.created_at >= date_trunc('year', now())), 'súčty: ' || s::text;
  PERFORM pg_temp.p_as(pg_temp.p_id('u', 7));
  ASSERT (SELECT count(*) FROM commission WHERE user_id <> pg_temp.p_id('u', 7)) = 0
     AND EXISTS (SELECT 1 FROM commission WHERE deal_id = pg_temp.p_id('d', 4)), 'obchodník B vidí preradenú';
  ASSERT (SELECT deal_name FROM commission_list() WHERE deal_id = pg_temp.p_id('d', 4)) = 'P4', 'názov obchodu aj bez práva na obchod';
  ASSERT NOT EXISTS (SELECT 1 FROM deal WHERE id = pg_temp.p_id('d', 4)), 'obchod 4 obchodník B nevidí';
  -- Back office a Nákup vidia obchod, nie províziu
  FOREACH n_all IN ARRAY ARRAY[5, 6, 4] LOOP
    PERFORM pg_temp.p_as(pg_temp.p_id('u', n_all));
    ASSERT (SELECT count(*) FROM commission) = 0 AND (SELECT count(*) FROM commission_claim) = 0
       AND NOT EXISTS (SELECT 1 FROM commission_list()) AND (commission_summary()->>'unpaid_eur')::numeric = 0,
           'bez provízií: používateľ ' || n_all;
    IF n_all IN (5, 6) THEN
      ASSERT EXISTS (SELECT 1 FROM deal WHERE id = pg_temp.p_id('d', 1)), 'Servis / Nákup obchod vidí';
    END IF;
  END LOOP;
  -- aplikácia tabuľky nemení
  PERFORM pg_temp.p_as(pg_temp.p_id('u', 2));
  BEGIN
    UPDATE commission SET amount_eur = 1;
    RAISE EXCEPTION 'CHYBA: aplikácia zmenila províziu';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    PERFORM commission_sync(pg_temp.p_id('d', 1), true);
    RAISE EXCEPTION 'CHYBA: aplikácia spustila internú funkciu';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM pg_temp.p_as(NULL);
  RAISE NOTICE 'OK: P9 viditeľnosť: obchodník iba svoje (aj preradenú bez práva na obchod); admin, CEO a riaditeľ s príznakom všetky; Servis, Nákup a asistent nič, hoci obchod vidia; súčty; aplikácia nemení';
END;
$$;
RESET ROLE;
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'crm_app') THEN
    ASSERT NOT has_table_privilege('crm_app', 'commission', 'UPDATE') AND NOT has_table_privilege('crm_app', 'commission', 'INSERT')
       AND NOT has_table_privilege('crm_app', 'commission_claim', 'UPDATE') AND NOT has_table_privilege('crm_app', 'commission_legacy_override', 'INSERT')
       AND has_table_privilege('crm_app', 'commission', 'SELECT'), 'crm_app: provízie iba číta (app-role.sql)';
    ASSERT NOT has_function_privilege('crm_app', 'commission_sync(uuid, boolean)', 'EXECUTE')
       AND NOT has_function_privilege('crm_app', 'contract_year_calc_core(uuid, integer, date)', 'EXECUTE')
       AND NOT has_function_privilege('crm_app', 'commission_deal_base(uuid)', 'EXECUTE')
       AND has_function_privilege('crm_app', 'commission_claim_create(uuid, uuid[])', 'EXECUTE'), 'crm_app: interné funkcie nie';
  END IF;
  -- obal bilancie zmluvy: rovnaký výsledok ako jadro pre toho, kto zmluvu vidí; nič pre toho, kto nie
  ASSERT (SELECT to_jsonb(c) FROM contract_year_calc(pg_temp.p_id('z', 5), 2028) c)
       = (SELECT to_jsonb(c) FROM contract_year_calc_core(pg_temp.p_id('z', 5), 2028) c), 'obal = jadro';
  RAISE NOTICE 'OK: P9b crm_app provízie iba číta a interné funkcie nespustí; bilancia zmluvy cez obal rovnaká ako jadro';
END;
$$;

-- ============================================================================
-- P10. Fronta a zámky (0054): uplatnenie dokončí frontu vybraných obchodov (suma je aktuálna); zrušenie listu
--      a preradenie berú zámok obchodu pred riadkom; nočný beh obchod, ktorý drží iná transakcia, preskočí
--      (súbeh viacerých spojení overuje db/test/subeh-provizie.sh na dočasnej databáze)
-- ============================================================================
DO $$
DECLARE
  c4      commission := pg_temp.p_row(4);
  v_claim uuid;
  v_new   numeric;
BEGIN
  -- zmena ceny zmluvy 10 obchodu 4 (import) a hneď uplatnenie: list má prepočítanú sumu
  PERFORM set_config('app.contract_import_id', (SELECT id::text FROM contract_import ORDER BY created_at DESC LIMIT 1), true);
  UPDATE contract_price SET price_vt_eur_mwh = 156 WHERE contract_id = pg_temp.p_id('z', 10);
  PERFORM set_config('app.contract_import_id', '', true);
  ASSERT EXISTS (SELECT 1 FROM commission_queue WHERE deal_id = pg_temp.p_id('d', 4)), 'obchod 4 vo fronte';
  v_new := round((pg_temp.p_base(4, 206) + pg_temp.p_base(10, 156)) * c4.pct / 100, 2);
  ASSERT v_new <> c4.amount_eur, 'test mení sumu';
  PERFORM pg_temp.p_as(pg_temp.p_id('u', 7));
  v_claim := commission_claim_create(pg_temp.p_id('u', 7), ARRAY[c4.id]);
  PERFORM pg_temp.p_as(NULL);
  ASSERT (SELECT total_eur FROM commission_claim WHERE id = v_claim) = v_new, 'list s prepočítanou sumou: ' || v_new;
  ASSERT NOT EXISTS (SELECT 1 FROM commission_queue WHERE deal_id = pg_temp.p_id('d', 4)), 'fronta obchodu dokončená';
  -- po uplatnení import nič nemení ani cez frontu
  PERFORM set_config('app.contract_import_id', (SELECT id::text FROM contract_import ORDER BY created_at DESC LIMIT 1), true);
  UPDATE contract_price SET price_vt_eur_mwh = 146 WHERE contract_id = pg_temp.p_id('z', 10);
  PERFORM set_config('app.contract_import_id', '', true);
  PERFORM commission_queue_run();
  ASSERT NOT EXISTS (SELECT 1 FROM commission WHERE deal_id = pg_temp.p_id('d', 4) AND status = 'caka'), 'uplatnená sa cez frontu nemení';
  -- nočný beh: počty v denníku vrátane preskočených (v jednej relácii sa nepreskočí nič – zámok je opakovateľný)
  ASSERT (commission_daily()->>'provizie_preskocene')::int = 0, 'nočný beh bez preskočených';
  RAISE NOTICE 'OK: P10 import iba do fronty; uplatnenie dokončí frontu a list má aktuálnu sumu; po uplatnení fronta nič nemení; nočný beh hlási preskočené';
END;
$$;

-- ============================================================================
-- P11. Interné funkcie nespustí aplikácia (crm_app) ani verejná rola (crm_public) – volanie skončí chybou
-- ============================================================================
GRANT crm_app TO CURRENT_USER WITH SET TRUE, INHERIT FALSE;
SET LOCAL ROLE crm_app;
DO $$
DECLARE
  f text;
  n integer := 0;
BEGIN
  -- s prihláseným používateľom (aplikácia); fronta je iba pre beh na pozadí (crm_background_only)
  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-0000000a7002', true);
  FOREACH f IN ARRAY ARRAY[
    'SELECT * FROM contract_year_calc_core(''00000000-0000-4000-8000-0000000a7501'', 2027)',
    'SELECT * FROM commission_deal_base(''00000000-0000-4000-8000-0000000a7301'')',
    'SELECT commission_sync(''00000000-0000-4000-8000-0000000a7301'', true)',
    'SELECT commission_legacy_match(''00000000-0000-4000-8000-0000000a7301'')',
    'SELECT commission_notify_admins(crm_default_org(), ''provizia_duplicita'', NULL, ''x'')',
    'SELECT commission_lock_deals(ARRAY[''00000000-0000-4000-8000-0000000a7301''::uuid])',
    'SELECT commission_queue_run()'] LOOP
    BEGIN
      EXECUTE f;
      RAISE EXCEPTION 'CHYBA: crm_app spustil: %', f;
    EXCEPTION WHEN insufficient_privilege THEN
      n := n + 1;
    END;
  END LOOP;
  ASSERT n = 7, 'všetky odmietnuté';
  BEGIN
    PERFORM count(*) FROM commission_queue;
    RAISE EXCEPTION 'CHYBA: crm_app číta frontu';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM set_config('app.user_id', '', true);
  RAISE NOTICE 'OK: P11a crm_app: jadro bilancie, prepočet, základ, zhoda so Sales portálom, upozornenia, zámky – permission denied; fronta iba bez používateľa';
END;
$$;
RESET ROLE;
-- verejná rola: testovacia crm_public_test (ako public-role.sql, z checks_ponuky_f3.sql); skutočná crm_public, ak existuje
SET LOCAL ROLE crm_public_test;
DO $$
BEGIN
  BEGIN
    PERFORM * FROM public.contract_year_calc_core('00000000-0000-4000-8000-0000000a7501', 2027);
    RAISE EXCEPTION 'CHYBA: verejná rola spustila jadro bilancie';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    PERFORM public.commission_list();
    RAISE EXCEPTION 'CHYBA: verejná rola spustila zoznam provízií';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  RAISE NOTICE 'OK: P11b verejná rola: jadro bilancie ani provízie – permission denied';
END;
$$;
RESET ROLE;
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'crm_public') THEN
    ASSERT NOT has_schema_privilege('crm_public', 'public', 'USAGE')
       AND NOT has_function_privilege('crm_public', 'contract_year_calc_core(uuid, integer, date)', 'EXECUTE')
       AND NOT has_function_privilege('crm_public', 'commission_sync(uuid, boolean)', 'EXECUTE')
       AND NOT has_function_privilege('crm_public', 'commission_queue_run()', 'EXECUTE'), 'crm_public: schéma public ani interné funkcie';
    RAISE NOTICE 'OK: P11c skutočná rola crm_public nemá schému public ani interné funkcie';
  ELSE
    RAISE NOTICE 'OK: P11c rola crm_public tu neexistuje (overí sa na dev)';
  END IF;
END;
$$;

-- ============================================================================
-- P12. „Vidí všetky provízie“ mení iba admin (audit); „počítať provízie“ admin alebo schvaľovateľ cien
-- ============================================================================
DO $$
BEGIN
  PERFORM pg_temp.p_as(pg_temp.p_id('u', 3));
  BEGIN
    UPDATE app_user SET sees_all_commissions = true WHERE id = pg_temp.p_id('u', 4);
    RAISE EXCEPTION 'CHYBA: príznak zmenil schvaľovateľ cien';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM user_commission_enabled_set(pg_temp.p_id('u', 4), true);   -- schvaľovateľ cien smie
  PERFORM pg_temp.p_as(pg_temp.p_id('u', 7));
  BEGIN
    UPDATE app_user SET commission_enabled = false WHERE id = pg_temp.p_id('u', 4);
    RAISE EXCEPTION 'CHYBA: počítať provízie zmenil obchodník';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM pg_temp.p_as(pg_temp.p_id('u', 2));
  UPDATE app_user SET sees_all_commissions = true WHERE id = pg_temp.p_id('u', 4);
  PERFORM pg_temp.p_as(NULL);
  ASSERT EXISTS (SELECT 1 FROM audit_log WHERE table_name = 'app_user' AND record_id = pg_temp.p_id('u', 4)
                    AND changed_by = pg_temp.p_id('u', 2) AND diff ? 'sees_all_commissions'), 'zmena príznaku v audite';
  RAISE NOTICE 'OK: P12 „vidí všetky provízie“ iba admin (v audite); „počítať provízie“ admin alebo schvaľovateľ cien, nie obchodník';
END;
$$;

-- ============================================================================
-- P13. Provízny list (0055): snímka položiek, dokument, PDF (kľúč raz), e-mail obchodníkovi a kópii s PDF;
--      zrušený list má PDF zrušenia so snímkou položiek; nevykreslené PDF dokončí beh na pozadí
-- ============================================================================
DO $$
DECLARE
  v_claim uuid;
  k       commission_claim;
  doc     jsonb;
  pend    jsonb;
  ob      jsonb;
  c5      commission := pg_temp.p_row(5);
BEGIN
  PERFORM pg_temp.p_as(pg_temp.p_id('u', 1));
  v_claim := commission_claim_create(pg_temp.p_id('u', 1), ARRAY[c5.id]);
  doc := commission_claim_document(v_claim);
  PERFORM pg_temp.p_as(NULL);
  SELECT * INTO k FROM commission_claim WHERE id = v_claim;
  ASSERT jsonb_array_length(k.items_snapshot) = 1 AND k.items_snapshot->0->>'deal_name' = 'P5'
     AND (k.items_snapshot->0->>'amount_eur')::numeric = c5.amount_eur, 'snímka položky: ' || k.items_snapshot::text;
  ASSERT doc->'claim'->>'number' = k.number AND doc->'seller'->>'name' = 'Obchodník A P' AND jsonb_array_length(doc->'items') = 1
     AND doc->'items'->0->>'customer_name' = 'Provízie Test P1 s.r.o.' AND doc->'org'->>'legal_name' IS NOT NULL, 'dokument: ' || doc::text;
  -- iný obchodník dokument nevidí; beh na pozadí áno
  PERFORM pg_temp.p_as(pg_temp.p_id('u', 7));
  ASSERT commission_claim_document(v_claim) IS NULL, 'cudzí obchodník dokument nevidí';
  PERFORM pg_temp.p_as(NULL);
  pend := commission_claim_pdf_pending(50);
  ASSERT EXISTS (SELECT 1 FROM jsonb_array_elements(pend) x WHERE x->>'id' = v_claim::text AND x->>'kind' = 'list'), 'čaká na PDF';
  BEGIN
    PERFORM commission_claim_pdf_set(v_claim, 'list', 'ponuky/zle.pdf', repeat('a', 64));
    RAISE EXCEPTION 'CHYBA: zlý kľúč';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  ASSERT commission_claim_pdf_set(v_claim, 'list', format('provizie/%s/%s/%s.pdf', k.org_id, left(k.number, 0) || split_part(k.number, '-', 2), k.number), repeat('a', 64)),
         'PDF uložené';
  ASSERT NOT commission_claim_pdf_set(v_claim, 'list', format('provizie/%s/%s/%s.pdf', k.org_id, split_part(k.number, '-', 2), k.number), repeat('b', 64)),
         'druhé uloženie nič nezmení';
  ASSERT (SELECT pdf_sha256 FROM commission_claim WHERE id = v_claim) = repeat('a', 64), 'odtlačok sa neprepísal';
  ASSERT (SELECT count(*) FROM email_outbox WHERE commission_claim_id = v_claim AND kind = 'provizny_list') = 2
     AND EXISTS (SELECT 1 FROM email_outbox WHERE commission_claim_id = v_claim AND user_id = pg_temp.p_id('u', 1))
     AND EXISTS (SELECT 1 FROM email_outbox WHERE commission_claim_id = v_claim AND user_id = pg_temp.p_id('u', 3)), 'e-mail obchodníkovi a kópii (raz)';
  ob := email_outbox_claim(50);
  ASSERT EXISTS (SELECT 1 FROM jsonb_array_elements(ob) x WHERE x->>'commission_claim_id' = v_claim::text AND x->>'pdf_key' LIKE 'provizie/%'
                    AND x->>'detail' = k.number), 'fronta e-mailov: PDF a číslo listu: ' || ob::text;
  -- zrušenie: položky späť na Čaká, PDF zrušenia so snímkou, e-mail zrušenia
  PERFORM pg_temp.p_as(pg_temp.p_id('u', 2));
  PERFORM commission_claim_void(v_claim, 'test PDF zrušenia');
  PERFORM pg_temp.p_as(NULL);
  doc := commission_claim_document(v_claim);
  ASSERT jsonb_array_length(doc->'items') = 1 AND doc->'claim'->>'void_reason' = 'test PDF zrušenia', 'dokument zrušenia so snímkou';
  ASSERT EXISTS (SELECT 1 FROM jsonb_array_elements(commission_claim_pdf_pending(50)) x WHERE x->>'id' = v_claim::text AND x->>'kind' = 'zrusenie'), 'čaká na PDF zrušenia';
  ASSERT commission_claim_pdf_set(v_claim, 'zrusenie', format('provizie/%s/%s/%s-zrusene.pdf', k.org_id, split_part(k.number, '-', 2), k.number), repeat('c', 64)), 'PDF zrušenia';
  ASSERT (SELECT count(*) FROM email_outbox WHERE commission_claim_id = v_claim AND kind = 'provizny_list_zruseny') = 2, 'e-mail zrušenia';
  ASSERT NOT EXISTS (SELECT 1 FROM jsonb_array_elements(commission_claim_pdf_pending(50)) x WHERE x->>'id' = v_claim::text), 'nič nečaká';
  -- prihlásený používateľ zoznam nevykreslených PDF nedostane
  PERFORM pg_temp.p_as(pg_temp.p_id('u', 2));
  ASSERT jsonb_array_length(commission_claim_pdf_pending(50)) = 0, 'pdf_pending iba beh na pozadí';
  PERFORM pg_temp.p_as(NULL);
  RAISE NOTICE 'OK: P13 provízny list: snímka položiek, dokument (iba kto list vidí), PDF raz s odtlačkom, e-mail obchodníkovi a kópii s PDF; zrušenie s PDF a e-mailom';
END;
$$;

SET LOCAL ROLE crm_app;
DO $$
DECLARE
  v_claim uuid := (SELECT id FROM commission_claim WHERE void_reason = 'test PDF zrušenia');
BEGIN
  PERFORM set_config('app.user_id', '', true);
  ASSERT commission_claim_document(v_claim) IS NOT NULL, 'beh na pozadí (crm_app bez používateľa) dokument vidí';
  ASSERT jsonb_typeof(commission_claim_pdf_pending(5)) = 'array', 'beh na pozadí smie zoznam PDF';
  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-0000000a7007', true);
  ASSERT commission_claim_document(v_claim) IS NULL, 'aplikácia s cudzím obchodníkom nie';
  PERFORM set_config('app.user_id', '', true);
  RAISE NOTICE 'OK: P13b beh na pozadí ako crm_app: dokument listu a zoznam PDF áno; prihlásený cudzí obchodník nie';
END;
$$;
RESET ROLE;

-- ============================================================================
-- P14. Fronta: položka staršia ako 1 hodina → denník behov a upozornenie adminom raz; potom sa spracuje
--      (preskočenie obsadeného obchodu medzi spojeniami overuje db/test/subeh-provizie.sh)
-- ============================================================================
DO $$
DECLARE
  r      jsonb;
  v_runs integer := (SELECT count(*) FROM job_run WHERE job = 'provizie');
BEGIN
  ASSERT commission_queue_alert() = 0, 'bez starej položky nič';
  INSERT INTO commission_queue (deal_id, created_at) VALUES (pg_temp.p_id('d', 5), now() - interval '2 hours');
  ASSERT commission_queue_alert() = 1, 'stará položka ohlásená';
  ASSERT (SELECT count(*) FROM job_run WHERE job = 'provizie') = v_runs + 1
     AND (SELECT errors->0->>'kod' FROM job_run WHERE job = 'provizie' ORDER BY created_at DESC LIMIT 1) = 'stara_polozka', 'zápis v denníku behov';
  ASSERT EXISTS (SELECT 1 FROM notification WHERE user_id = pg_temp.p_id('u', 2) AND kind = 'provizie_fronta'), 'upozornenie adminovi';
  ASSERT commission_queue_alert() = 0 AND (SELECT count(*) FROM job_run WHERE job = 'provizie') = v_runs + 1, 'raz, nie pri každom behu';
  r := commission_queue_run();
  ASSERT (r->>'fronta_spracovane')::int >= 1 AND NOT EXISTS (SELECT 1 FROM commission_queue WHERE deal_id = pg_temp.p_id('d', 5)), 'spracovaná: ' || r::text;
  RAISE NOTICE 'OK: P14 stará položka fronty: denník behov a upozornenie adminom raz; potom spracovaná';
END;
$$;

-- ============================================================================
-- P15. Opakovanie po deadlocku (API opakuje celú transakciu najviac raz): prvý pokus zlyhá po uplatnení, vráti sa celý
--      vrátane počítadla čísel – po opakovaní jeden list a čísla idú za sebou (žiadne dve čísla CMSN ani dva listy)
-- ============================================================================
DO $$
DECLARE
  c5     commission := pg_temp.p_row(5);
  v_last integer := (SELECT last_value FROM doc_counter WHERE kind = 'provizny_list' AND org_id = crm_default_org()
                       AND year = extract(year FROM crm_today()));
  v_n    integer := (SELECT count(*) FROM commission_claim WHERE user_id = pg_temp.p_id('u', 1));
  v_claim uuid;
BEGIN
  PERFORM pg_temp.p_as(pg_temp.p_id('u', 1));
  BEGIN   -- pokus 1 (ako transakcia API): uplatnenie prebehne, potom deadlock
    PERFORM commission_claim_create(pg_temp.p_id('u', 1), ARRAY[c5.id]);
    RAISE EXCEPTION 'deadlock (test)' USING ERRCODE = '40P01';
  EXCEPTION WHEN deadlock_detected THEN NULL;
  END;
  v_claim := commission_claim_create(pg_temp.p_id('u', 1), ARRAY[c5.id]);   -- pokus 2
  PERFORM pg_temp.p_as(NULL);
  ASSERT (SELECT count(*) FROM commission_claim WHERE user_id = pg_temp.p_id('u', 1)) = v_n + 1, 'jeden nový list';
  ASSERT (SELECT number FROM commission_claim WHERE id = v_claim) = format('CMSN-%s-%s', extract(year FROM crm_today()), lpad((v_last + 1)::text, 4, '0')),
         'číslo nasleduje hneď po poslednom (pokus 1 sa vrátil aj s počítadlom)';
  ASSERT (SELECT count(*) FROM commission WHERE id = c5.id AND claim_id = v_claim) = 1, 'položka na jednom liste';
  RAISE NOTICE 'OK: P15 opakovanie po deadlocku: jeden list, číslo bez medzery, položka na jednom liste';
END;
$$;
