-- Kontroly modulu Zmluvy, jadro (0025): stav zmluvy, nástupníctvo a prekrytie na OOM (Petrove scenáre: retencia,
-- retencia počas prolongácie, čiastočný nástupca, prepis, doba neurčitá v rámci druhu, skutočné prekrytie, zrušenie
-- nástupcu), ceny, ochrana stĺpcov z Office portálu, RLS „iba svoje“ (zákazník aj uzatvoril) a „schvaľuje ceny“,
-- výnimky z ceny, stav zákazníka „Čakajúci“.
-- Spúšťa sa iba cez db/test/run.sh po checks_zmluvy_priprava.sql (používa pg_temp.z_eic, rolu crm_rls_test,
-- používateľov 0011 – vlastní Alfu, 4001 – Sales_internal so „schvaľuje ceny“, 4004 – Marketing a práva modulu Zmluvy
-- nastavené v transakcii testu). Dátumy sú pevné a stav sa počíta k zadanému dňu.

-- Obchodník B (Sales_internal), firma Beta B (vlastník B), domácnosť B (vlastník B)
INSERT INTO app_user (id, email, name, team_id, status)
SELECT '00000000-0000-4000-8000-000000005001', 'obchodnik.b.z1@example.test', 'Obchodník B Z1', t.id, 'aktivny'
  FROM team t WHERE t.code = 'sales_internal';
INSERT INTO app_user_org (user_id, org_id) VALUES ('00000000-0000-4000-8000-000000005001', crm_default_org());
INSERT INTO company (id, name, ico, is_customer, owner_id) VALUES
  ('00000000-0000-4000-8000-000000005101', 'Beta Z1 s.r.o.', '99999911', true, '00000000-0000-4000-8000-000000005001');
INSERT INTO contact (id, first_name, last_name, email, is_household, owner_id) VALUES
  ('00000000-0000-4000-8000-000000005102', 'Domácnosť', 'Z1', 'domacnost.z1@example.test', true, '00000000-0000-4000-8000-000000005001');

-- OOM: 1–9 firmy Alfa (vlastník 0011), 10 Beta; 7 výrobné
-- EIC s platnou kontrolnou číslicou (pri predpone, kde vychádza „-“, sa skúsi ďalšie písmeno)
CREATE FUNCTION pg_temp.z1_eic(p_n integer) RETURNS text LANGUAGE plpgsql AS $f$
DECLARE
  l text;
  c text;
BEGIN
  FOREACH l IN ARRAY string_to_array('KLMNPQRSTUVW', NULL) LOOP
    FOREACH c IN ARRAY string_to_array('0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ', NULL) LOOP
      IF eic_is_valid('24ZZS000TEST' || l || lpad(p_n::text, 2, '0') || c) THEN
        RETURN '24ZZS000TEST' || l || lpad(p_n::text, 2, '0') || c;
      END IF;
    END LOOP;
  END LOOP;
END;
$f$;
CREATE FUNCTION pg_temp.z1_oom(p_n integer, p_company uuid, p_type text DEFAULT 'spotreba') RETURNS uuid LANGUAGE sql AS $f$
  INSERT INTO oom (id, company_id, eic, type, status)
  VALUES (('00000000-0000-4000-8000-0000000052' || lpad(p_n::text, 2, '0'))::uuid, p_company,
          pg_temp.z1_eic(p_n), p_type::oom_type, 'pripravovane')
  RETURNING id
$f$;
SELECT pg_temp.z1_oom(n, '00000000-0000-4000-8000-000000000101', CASE WHEN n = 7 THEN 'vyroba' ELSE 'spotreba' END)
  FROM generate_series(1, 9) n;
SELECT pg_temp.z1_oom(10, '00000000-0000-4000-8000-000000005101');

-- Zmluva (vlastník databázy = ako import) a OOM v nej
CREATE FUNCTION pg_temp.z1_k(p_n integer, p_company uuid, p_type text, p_phase text, p_from date, p_to date, p_signed date,
                             p_owner uuid DEFAULT NULL, p_person uuid DEFAULT NULL) RETURNS uuid LANGUAGE sql AS $f$
  INSERT INTO contract (id, number, company_id, person_id, type, phase, valid_from, valid_to, signed_on, owner_id)
  VALUES (('00000000-0000-4000-8000-0000000053' || lpad(p_n::text, 2, '0'))::uuid, 'Z1-' || p_n, p_company, p_person,
          p_type::contract_type, p_phase::contract_phase, p_from, p_to, p_signed, p_owner)
  RETURNING id
$f$;
CREATE FUNCTION pg_temp.z1_ko(p_k integer, p_o integer, p_qty numeric DEFAULT 10) RETURNS void LANGUAGE sql AS $f$
  INSERT INTO contract_oom (contract_id, oom_id, qty_vt_mwh)
  VALUES (('00000000-0000-4000-8000-0000000053' || lpad(p_k::text, 2, '0'))::uuid,
          ('00000000-0000-4000-8000-0000000052' || lpad(p_o::text, 2, '0'))::uuid, p_qty)
$f$;
CREATE FUNCTION pg_temp.z1_id(p_k integer) RETURNS uuid LANGUAGE sql AS $f$
  SELECT ('00000000-0000-4000-8000-0000000053' || lpad(p_k::text, 2, '0'))::uuid
$f$;
CREATE FUNCTION pg_temp.z1_row(p_k integer, p_o integer) RETURNS contract_oom LANGUAGE sql AS $f$
  SELECT * FROM contract_oom WHERE contract_id = pg_temp.z1_id(p_k)
                               AND oom_id = ('00000000-0000-4000-8000-0000000052' || lpad(p_o::text, 2, '0'))::uuid
$f$;

-- Z1-1. Stav zmluvy a stav zákazníka „Čakajúci“
DO $$
DECLARE
  k contract;
  a uuid := '00000000-0000-4000-8000-000000000101';
BEGIN
  PERFORM pg_temp.z1_k(1, a, 'dodavka_firma_nn', 'caka_na_podpis', '2027-01-01', '2027-12-31', NULL);
  SELECT * INTO k FROM contract WHERE id = pg_temp.z1_id(1);
  ASSERT contract_state(k, '2026-10-14') = 'v_priprave', 'v príprave';
  UPDATE contract SET phase = 'podpisana', signed_on = '2026-10-10' WHERE id = k.id;
  SELECT * INTO k FROM contract WHERE id = k.id;
  ASSERT contract_state(k, '2026-10-14') = 'podpisana', 'podpísaná s budúcou účinnosťou';
  ASSERT contract_state(k, '2027-05-01') = 'ucinna', 'účinná';
  ASSERT contract_state(k, '2028-01-01') = 'skoncena', 'skončená po účinnosti';
  UPDATE contract SET crm_valid_to = '2028-12-31' WHERE id = k.id;
  SELECT * INTO k FROM contract WHERE id = k.id;
  ASSERT contract_effective_to(k) = '2028-12-31' AND contract_state(k, '2028-06-01') = 'ucinna', 'prolongácia posunie koniec';
  UPDATE contract SET phase = 'ukoncena', crm_valid_to = NULL WHERE id = k.id;
  SELECT * INTO k FROM contract WHERE id = k.id;
  ASSERT contract_state(k, '2027-05-01') = 'skoncena', 'ukončená v Office portáli';
  UPDATE contract SET phase = 'odmietnuta' WHERE id = k.id;
  SELECT * INTO k FROM contract WHERE id = k.id;
  ASSERT contract_state(k, '2027-05-01') = 'odmietnuta', 'odmietnutá';

  -- domácnosť bez OOM s podpísanou zmluvou s budúcou účinnosťou = Čakajúci zákazník
  PERFORM pg_temp.z1_k(2, NULL, 'dodavka_domacnost', 'podpisana', '2027-01-01', NULL, '2026-10-01',
                       NULL, '00000000-0000-4000-8000-000000005102');
  ASSERT customer_status_calc(NULL, '00000000-0000-4000-8000-000000005102', '2026-10-14') = 'cakajuci_zakaznik',
         'podpísaná zmluva s budúcou účinnosťou = Čakajúci zákazník';
  RAISE NOTICE 'OK: Z1-1 stav zmluvy (v príprave, podpísaná, účinná, skončená, prolongácia, ukončená, odmietnutá), Čakajúci zákazník';
END;
$$;

-- Z1-2. Nástupníctvo a prekrytie (doplnok a, odpoveď 16)
DO $$
DECLARE
  a uuid := '00000000-0000-4000-8000-000000000101';
  b uuid := '00000000-0000-4000-8000-000000005101';
  r contract_oom;
  k contract;
BEGIN
  -- Retencia bez prekrytia: nová od 1. 1. 2027 nadväzuje → väzba predošlá, stará sa neskracuje
  PERFORM pg_temp.z1_k(10, a, 'dodavka_firma_nn', 'podpisana', '2026-01-01', '2026-12-31', '2025-12-01');
  PERFORM pg_temp.z1_ko(10, 1);
  PERFORM pg_temp.z1_k(11, a, 'dodavka_firma_nn', 'podpisana', '2027-01-01', '2027-12-31', '2026-11-15');
  PERFORM pg_temp.z1_ko(11, 1);
  ASSERT (SELECT previous_contract_id FROM contract WHERE id = pg_temp.z1_id(11)) = pg_temp.z1_id(10), 'retencia: predošlá zmluva';
  ASSERT (pg_temp.z1_row(10, 1)).valid_to = '2026-12-31' AND (pg_temp.z1_row(10, 1)).successor_id IS NULL, 'retencia: stará nezmenená';

  -- Retencia počas prolongácie: stará do 31. 12. 2026, sprolongovaná do 31. 12. 2027 s cenou; nová od 1. 4. 2027
  PERFORM pg_temp.z1_k(12, a, 'dodavka_firma_nn', 'podpisana', '2026-01-01', '2026-12-31', '2025-12-01');
  PERFORM pg_temp.z1_ko(12, 2);
  UPDATE contract SET crm_valid_to = '2027-12-31' WHERE id = pg_temp.z1_id(12);
  ASSERT (pg_temp.z1_row(12, 2)).valid_to = '2027-12-31', 'prolongácia posunula OOM';
  INSERT INTO contract_price (contract_id, oom_id, slot, product_id, price_model, valid_from, valid_to, price_vt_eur_mwh, source)
  VALUES (pg_temp.z1_id(12), (pg_temp.z1_row(12, 2)).oom_id, 'komodita', (SELECT id FROM product WHERE code = 'test_z0_vo'),
          'fix', '2027-01-01', '2027-12-31', 164, 'prolongacia');
  INSERT INTO contract_flag (contract_id, code) VALUES (pg_temp.z1_id(12), 'sprolongovane_bez_ceny');
  PERFORM pg_temp.z1_k(13, a, 'dodavka_firma_nn', 'podpisana', '2027-04-01', '2027-12-31', '2027-03-01');
  PERFORM pg_temp.z1_ko(13, 2);
  r := pg_temp.z1_row(12, 2);
  ASSERT r.valid_to = '2027-03-31' AND r.successor_id = pg_temp.z1_id(13), 'prolongácia skrátená deň pred nástupcom';
  ASSERT (SELECT valid_to FROM contract_price WHERE contract_id = pg_temp.z1_id(12)) = '2027-03-31', 'cena prolongácie skrátená';
  ASSERT (SELECT previous_contract_id FROM contract WHERE id = pg_temp.z1_id(13)) = pg_temp.z1_id(12), 'nástupca: predošlá';
  ASSERT (SELECT crm_valid_to FROM contract WHERE id = pg_temp.z1_id(12)) = '2027-03-31', 'koniec starej zmluvy podľa CRM';
  ASSERT (SELECT resolved_at IS NOT NULL FROM contract_flag WHERE contract_id = pg_temp.z1_id(12) AND code = 'sprolongovane_bez_ceny'),
         'príznak Sprolongované bez novej ceny uzavretý';

  -- Čiastočný nástupca: 3 OOM sprolongované, nová zmluva iba na 1 OOM
  PERFORM pg_temp.z1_k(14, a, 'dodavka_firma_nn', 'podpisana', '2026-01-01', '2026-12-31', '2025-12-01');
  PERFORM pg_temp.z1_ko(14, 3); PERFORM pg_temp.z1_ko(14, 4); PERFORM pg_temp.z1_ko(14, 5);
  UPDATE contract SET crm_valid_to = '2027-12-31' WHERE id = pg_temp.z1_id(14);
  PERFORM pg_temp.z1_k(15, a, 'dodavka_firma_nn', 'podpisana', '2027-06-01', '2027-12-31', '2027-05-01');
  PERFORM pg_temp.z1_ko(15, 3);
  ASSERT (pg_temp.z1_row(14, 3)).valid_to = '2027-05-31', 'čiastočný: skrátené iba prenesené OOM';
  ASSERT (pg_temp.z1_row(14, 4)).valid_to = '2027-12-31' AND (pg_temp.z1_row(14, 5)).valid_to = '2027-12-31', 'čiastočný: ostatné OOM bežia';
  ASSERT (SELECT crm_valid_to FROM contract WHERE id = pg_temp.z1_id(14)) = '2027-12-31', 'čiastočný: koniec zmluvy podľa zvyšných OOM';

  -- Prepis počas prolongácie: iný zákazník na tom istom OOM
  PERFORM pg_temp.z1_k(16, a, 'dodavka_firma_nn', 'podpisana', '2026-01-01', '2026-12-31', '2025-12-01');
  PERFORM pg_temp.z1_ko(16, 6);
  UPDATE contract SET crm_valid_to = '2027-12-31' WHERE id = pg_temp.z1_id(16);
  PERFORM pg_temp.z1_k(17, b, 'dodavka_firma_nn', 'podpisana', '2027-06-01', '2027-12-31', '2027-05-15');
  PERFORM pg_temp.z1_ko(17, 6);
  ASSERT (pg_temp.z1_row(16, 6)).valid_to = '2027-05-31', 'prepis: stará zmluva skončí deň pred novou';
  ASSERT (SELECT previous_contract_id FROM contract WHERE id = pg_temp.z1_id(17)) = pg_temp.z1_id(16), 'prepis: predošlá zmluva';

  -- Doba neurčitá v rámci druhu: výkup na neurčito; dodávka ho neskráti, VIWA áno
  PERFORM pg_temp.z1_k(18, a, 'vykup', 'podpisana', '2026-01-01', NULL, '2025-12-01');
  PERFORM pg_temp.z1_ko(18, 7);
  PERFORM pg_temp.z1_k(19, a, 'dodavka_firma_nn', 'podpisana', '2026-06-01', NULL, '2026-05-01');
  PERFORM pg_temp.z1_ko(19, 7);
  ASSERT (pg_temp.z1_row(18, 7)).valid_to IS NULL, 'dodávka neskráti výkup (iný druh)';
  PERFORM pg_temp.z1_k(20, a, 'viwa', 'podpisana', '2026-09-01', NULL, '2026-08-15');
  PERFORM pg_temp.z1_ko(20, 7);
  ASSERT (pg_temp.z1_row(18, 7)).valid_to = '2026-08-31' AND (pg_temp.z1_row(18, 7)).successor_id = pg_temp.z1_id(20),
         'VIWA ukončí výkup na neurčito';
  ASSERT (pg_temp.z1_row(19, 7)).valid_to IS NULL, 'VIWA dodávku nechá';
  ASSERT (SELECT crm_valid_to FROM contract WHERE id = pg_temp.z1_id(18)) = '2026-08-31', 'výkup skončí podľa CRM';

  -- Skutočné prekrytie účinností z Office portálu = chyba
  PERFORM pg_temp.z1_k(21, a, 'dodavka_firma_nn', 'podpisana', '2026-01-01', '2026-12-31', '2025-12-01');
  PERFORM pg_temp.z1_ko(21, 8);
  PERFORM pg_temp.z1_k(22, a, 'dodavka_firma_nn', 'podpisana', '2026-06-01', '2027-05-31', '2026-05-01');
  BEGIN
    PERFORM pg_temp.z1_ko(22, 8);
    RAISE EXCEPTION 'CHYBA: skutočné prekrytie prešlo';
  EXCEPTION WHEN check_violation THEN
    NULL;
  END;
  -- zmluva v príprave sa prekrývať smie
  PERFORM pg_temp.z1_k(23, a, 'dodavka_firma_nn', 'rozpracovana', '2026-06-01', '2027-05-31', NULL);
  PERFORM pg_temp.z1_ko(23, 8);
  -- jej podpis by bol prekrytím → chyba a fáza ostane
  BEGIN
    UPDATE contract SET phase = 'podpisana' WHERE id = pg_temp.z1_id(23);
    RAISE EXCEPTION 'CHYBA: podpis prekrývajúcej zmluvy prešiel';
  EXCEPTION WHEN check_violation THEN
    NULL;
  END;
  -- novšia zmluva podpísaná skôr ako stará na neurčito = chyba
  PERFORM pg_temp.z1_k(24, a, 'dodavka_firma_nn', 'podpisana', '2026-02-01', NULL, '2026-05-01');
  PERFORM pg_temp.z1_ko(24, 9);
  PERFORM pg_temp.z1_k(25, a, 'dodavka_firma_nn', 'podpisana', '2026-06-01', NULL, '2026-01-01');
  BEGIN
    PERFORM pg_temp.z1_ko(25, 9);
    RAISE EXCEPTION 'CHYBA: nástupca podpísaný skôr prešiel';
  EXCEPTION WHEN check_violation THEN
    NULL;
  END;

  -- Zrušenie nástupcu: stará zmluva dostane „Na kontrolu“, skrátenie ostane
  UPDATE contract SET phase = 'odmietnuta' WHERE id = pg_temp.z1_id(13);
  ASSERT (SELECT count(*) FROM contract_flag WHERE contract_id = pg_temp.z1_id(12) AND code = 'kontrola_importu'
            AND resolved_at IS NULL) = 1, 'zrušený nástupca: príznak Na kontrolu';
  ASSERT (pg_temp.z1_row(12, 2)).valid_to = '2027-03-31', 'skrátenie sa samo nevráti';
  RAISE NOTICE 'OK: Z1-2 nástupníctvo (retencia, retencia počas prolongácie, čiastočný nástupca, prepis, neurčito v rámci druhu – VIWA ukončí výkup, nie dodávku; skutočné prekrytie a podpis skôr = chyba; zmluva v príprave sa prekrýva; zrušenie nástupcu = Na kontrolu)';
END;
$$;

-- Z1-3. Ceny zmluvy
DO $$
DECLARE
  v_prod uuid;
  v_list uuid;
  v_ver  uuid;
  v_item uuid;
  k uuid := pg_temp.z1_id(10);
  o uuid := (pg_temp.z1_row(10, 1)).oom_id;
BEGIN
  INSERT INTO product (org_id, code, name, category, segment, vat_rate, tariff_type, price_models)
  VALUES (crm_default_org(), 'test_z1_cennik', 'Z1 cenník', 'dodavka_firma', 'firma', 19, 'jednotarif', '{cennik,fix}')
  RETURNING id INTO v_prod;
  INSERT INTO price_list (org_id, code, name, segment) VALUES (crm_default_org(), 'test_z1_list', 'Z1', 'firma') RETURNING id INTO v_list;
  INSERT INTO price_list_version (price_list_id, name, valid_from) VALUES (v_list, 'Z1', '2026-01-01') RETURNING id INTO v_ver;
  INSERT INTO price_list_item (version_id, product_id, price_vt_eur_mwh, fee_oom_eur_month) VALUES (v_ver, v_prod, 100, 5)
  RETURNING id INTO v_item;
  PERFORM price_list_version_approve(v_ver);

  INSERT INTO contract_price (contract_id, oom_id, slot, product_id, price_model, price_list_item_id, valid_from, valid_to,
                              price_vt_eur_mwh, fee_eur_month, vat_rate)
  VALUES (k, o, 'komodita', v_prod, 'cennik', v_item, '2026-01-01', '2026-06-30', 100, 5, 19);
  BEGIN
    INSERT INTO contract_price (contract_id, oom_id, slot, product_id, price_model, price_list_item_id, valid_from, valid_to,
                                price_vt_eur_mwh, fee_eur_month, vat_rate)
    VALUES (k, o, 'komodita', v_prod, 'cennik', v_item, '2026-07-01', '2026-12-31', 101, 5, 19);
    RAISE EXCEPTION 'CHYBA: cenníková cena so zlou kópiou prešla';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    INSERT INTO contract_price (contract_id, oom_id, slot, product_id, price_model, valid_from, valid_to, price_vt_eur_mwh)
    VALUES (k, o, 'komodita', v_prod, 'fix', '2026-06-01', '2026-12-31', 120);
    RAISE EXCEPTION 'CHYBA: dve ceny komodity v jednom období';
  EXCEPTION WHEN exclusion_violation THEN NULL;
  END;
  BEGIN
    INSERT INTO contract_price (contract_id, oom_id, slot, product_id, price_model, valid_from, valid_to)
    VALUES (k, o, 'komodita', v_prod, 'fix', '2026-07-01', '2026-12-31');
    RAISE EXCEPTION 'CHYBA: FIX bez ceny';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    INSERT INTO contract_price (contract_id, oom_id, slot, product_id, price_model, valid_from, price_vt_eur_mwh)
    VALUES (k, NULL, 'komodita', v_prod, 'fix', '2026-07-01', 120);
    RAISE EXCEPTION 'CHYBA: komodita bez OOM';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    INSERT INTO contract_price (contract_id, oom_id, slot, product_id, price_model, valid_from, price_vt_eur_mwh)
    VALUES (k, (pg_temp.z1_row(12, 2)).oom_id, 'komodita', v_prod, 'fix', '2026-07-01', 120);
    RAISE EXCEPTION 'CHYBA: cena pre OOM, ktoré nie je v zmluve';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  INSERT INTO contract_price (contract_id, oom_id, slot, product_id, price_model, valid_from, valid_to, price_vt_eur_mwh)
  VALUES (k, o, 'komodita', v_prod, 'fix', '2026-07-01', '2026-12-31', 120);                -- ďalšie obdobie áno
  INSERT INTO contract_price (contract_id, oom_id, slot, product_id, price_model, valid_from, valid_to, fee_eur_month)
  VALUES (pg_temp.z1_id(20), NULL, 'viwa_ucet', (SELECT id FROM product WHERE code = 'test_z0_vo'), 'cennik' , '2026-09-01', NULL, 6.9);
  RAISE EXCEPTION 'CHYBA: cenník bez položky prešiel';
EXCEPTION WHEN check_violation THEN
  IF SQLERRM LIKE 'CHYBA%' THEN RAISE; END IF;
  RAISE NOTICE 'OK: Z1-3 ceny (kópia položky schváleného cenníka, zlá kópia nie, prekrytie nie, FIX bez ceny nie, komodita bez OOM nie, OOM mimo zmluvy nie, cenník bez položky nie)';
END;
$$;

-- Z1-4. RLS „iba svoje“ (zákazník aj uzatvoril), „schvaľuje ceny“, ochrana stĺpcov, výnimky
-- cena pre obchodníka 2029 dnes (hranicu výnimky dopĺňa databáza, 0027): BL 95, PL 110 → 106 pri východiskových parametroch;
-- rok 2029 nemá žiadna testovacia zmluva, výnimka sa so zmluvou nespáruje
INSERT INTO market_price_daily (org_id, on_date, delivery_year, bl_eur_mwh, pl_eur_mwh, source)
SELECT crm_default_org(), crm_today(), 2029, 95, 110, 'rucne'
 WHERE NOT EXISTS (SELECT 1 FROM market_price_daily WHERE org_id = crm_default_org() AND on_date = crm_today()
                      AND delivery_year = 2029 AND corrected_at IS NULL AND bl_eur_mwh IS NOT NULL);
UPDATE contract SET owner_id = '00000000-0000-4000-8000-000000000011' WHERE id = pg_temp.z1_id(17);   -- Beta, uzavrel 0011
GRANT SELECT, INSERT, UPDATE, DELETE ON contract, contract_oom, contract_price, contract_flag, price_exception TO crm_rls_test;
GRANT SELECT ON contract_v, price_exception_v TO crm_rls_test;
SET LOCAL ROLE crm_rls_test;
DO $$
DECLARE
  n     integer;
  v_exc uuid;
  v_b   uuid;
BEGIN
  PERFORM set_config('app.require_user', 'on', true);

  -- 0011: vlastní Alfu → zmluvy Alfy; Beta iba zmluvu, ktorú uzavrel (Z1-17)
  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-000000000011', true);
  ASSERT EXISTS (SELECT 1 FROM contract WHERE id = pg_temp.z1_id(10)), 'obchodník vidí zmluvu svojho zákazníka';
  ASSERT EXISTS (SELECT 1 FROM contract WHERE id = pg_temp.z1_id(17)), 'obchodník vidí zmluvu, ktorú uzavrel pri cudzom zákazníkovi';
  ASSERT NOT EXISTS (SELECT 1 FROM contract WHERE id = pg_temp.z1_id(2)), 'cudziu zmluvu nevidí';
  ASSERT (SELECT count(*) FROM contract_oom WHERE contract_id = pg_temp.z1_id(2)) = 0, 'ani jej OOM';
  UPDATE contract SET note = 'test Z1' WHERE id = pg_temp.z1_id(10);
  ASSERT (SELECT note FROM contract WHERE id = pg_temp.z1_id(10)) = 'test Z1', 'poznámku CRM upraví';
  BEGIN
    UPDATE contract SET phase = 'ukoncena' WHERE id = pg_temp.z1_id(10);
    RAISE EXCEPTION 'CHYBA: obchodník zmenil fázu z Office portálu';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    INSERT INTO contract (number, company_id, type, phase) VALUES ('Z1-X', '00000000-0000-4000-8000-000000000101', 'dodavka_firma_nn', 'rozpracovana');
    RAISE EXCEPTION 'CHYBA: aplikácia založila zmluvu';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  UPDATE contract_oom SET qty_vt_mwh = 99 WHERE contract_id = pg_temp.z1_id(10);   -- RLS: aplikácia OOM v zmluve nemení
  ASSERT (SELECT qty_vt_mwh FROM contract_oom WHERE contract_id = pg_temp.z1_id(10)) = 10, 'aplikácia nezmenila OOM v zmluve';
  BEGIN
    INSERT INTO contract_oom (contract_id, oom_id) VALUES (pg_temp.z1_id(10), (SELECT oom_id FROM contract_oom WHERE contract_id = pg_temp.z1_id(11)));
    RAISE EXCEPTION 'CHYBA: aplikácia pridala OOM do zmluvy';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    UPDATE contract SET related_contract_id = pg_temp.z1_id(11) WHERE id = pg_temp.z1_id(10);
    RAISE EXCEPTION 'CHYBA: súvisiaca zmluva dodávka ↔ dodávka';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  UPDATE contract SET related_contract_id = pg_temp.z1_id(20) WHERE id = pg_temp.z1_id(19);           -- dodávka ↔ VIWA áno

  -- výnimka: obchodník pre svojho zákazníka áno, pre cudzieho nie; vlastnú neschváli
  INSERT INTO price_exception (company_id, years, price_model, requested_value, threshold_value, reason)
  VALUES ('00000000-0000-4000-8000-000000000101', '{2029}', 'fix', 103, 106, 'konkurenčná ponuka') RETURNING id INTO v_exc;
  ASSERT (SELECT requested_by FROM price_exception WHERE id = v_exc) = '00000000-0000-4000-8000-000000000011', 'autor';
  BEGIN
    INSERT INTO price_exception (company_id, years, price_model, requested_value, threshold_value, reason)
    VALUES ('00000000-0000-4000-8000-000000005101', '{2029}', 'fix', 103, 106, 'cudzí');
    RAISE EXCEPTION 'CHYBA: výnimka pre cudzieho zákazníka';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    UPDATE price_exception SET status = 'schvalena' WHERE id = v_exc;
    RAISE EXCEPTION 'CHYBA: obchodník schválil výnimku';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  -- obchodník B: cudziu výnimku nevidí, zmluvu Alfy nevidí, svoju domácnosť áno
  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-000000005001', true);
  ASSERT NOT EXISTS (SELECT 1 FROM price_exception WHERE id = v_exc), 'cudziu výnimku nevidí';
  ASSERT NOT EXISTS (SELECT 1 FROM contract WHERE id = pg_temp.z1_id(10)), 'zmluvu Alfy nevidí';
  ASSERT EXISTS (SELECT 1 FROM contract WHERE id = pg_temp.z1_id(2)), 'zmluvu svojej domácnosti vidí';

  -- 4001: Sales_internal so „schvaľuje ceny“ – vidí všetky zmluvy a výnimky, schváli cudziu, vlastnú nie
  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-000000004001', true);
  ASSERT EXISTS (SELECT 1 FROM contract WHERE id = pg_temp.z1_id(10)) AND EXISTS (SELECT 1 FROM contract WHERE id = pg_temp.z1_id(2)),
         'schvaľuje ceny: vidí cudzie zmluvy';
  ASSERT EXISTS (SELECT 1 FROM price_exception WHERE id = v_exc), 'schvaľuje ceny: vidí výnimky';
  UPDATE price_exception SET status = 'schvalena', decision_note = 'ok' WHERE id = v_exc;
  ASSERT (SELECT status = 'schvalena' AND decided_by = '00000000-0000-4000-8000-000000004001' AND valid_until = crm_today() + 30
            FROM price_exception WHERE id = v_exc), 'schválená na 30 dní';
  BEGIN
    UPDATE price_exception SET requested_value = 90 WHERE id = v_exc;
    RAISE EXCEPTION 'CHYBA: rozhodnutá výnimka sa zmenila';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  INSERT INTO price_exception (company_id, years, price_model, requested_value, threshold_value, reason)
  VALUES ('00000000-0000-4000-8000-000000005101', '{2027}', 'spot_plus_eur', 4, 6, 'riaditeľ') RETURNING id INTO v_b;
  BEGIN
    UPDATE price_exception SET status = 'zamietnuta' WHERE id = v_b;
    RAISE EXCEPTION 'CHYBA: vlastnú výnimku rozhodol';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  -- Marketing (tím „všetko“) vidí všetky; bez používateľa nič
  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-000000004004', true);
  ASSERT EXISTS (SELECT 1 FROM contract WHERE id = pg_temp.z1_id(2)), 'Marketing vidí všetky zmluvy';
  PERFORM set_config('app.user_id', '', true);
  ASSERT (SELECT count(*) FROM contract WHERE number LIKE 'Z1-%') = 0, 'bez používateľa nič';
  PERFORM set_config('app.require_user', '', true);
  RAISE NOTICE 'OK: Z1-4 RLS (zákazník aj uzatvoril; schvaľuje ceny v Sales_internal vidí všetky zmluvy a výnimky; bez príznaku nie), ochrana stĺpcov z Office portálu, súvisiaca zmluva, výnimky (autor, schválenie na 30 dní, vlastnú nie)';
END;
$$;
RESET ROLE;

-- Z1-5. Výnimka Expirovaná a preklady fáz
DO $$
BEGIN
  UPDATE price_exception SET valid_until = crm_today() - 1 WHERE status = 'schvalena' AND reason = 'konkurenčná ponuka';
  ASSERT (SELECT state FROM price_exception_v WHERE reason = 'konkurenčná ponuka') = 'expirovana', 'Expirovaná po lehote';
  ASSERT (import_alias_resolve(crm_default_org(), 'office_portal', 'faza', 'Finálne podpísaná')).target = 'podpisana', 'fáza Finálne podpísaná';
  ASSERT (import_alias_resolve(crm_default_org(), 'office_portal', 'faza', '8')).target = 'ukoncena', 'fáza 8';
  ASSERT (import_alias_resolve(crm_default_org(), 'office_portal', 'faza', '9')).target = 'neuspesna', 'fáza 9';
  ASSERT (import_alias_resolve(crm_default_org(), 'office_portal', 'faza', 'Podpísaná')).target = 'podpisana', 'O10';
  BEGIN
    INSERT INTO import_alias (org_id, source, kind, name_sample, target) VALUES (crm_default_org(), 'office_portal', 'faza', 'Z1 fáza', 'aktivna');
    RAISE EXCEPTION 'CHYBA: preklad na neexistujúcu fázu';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  RAISE NOTICE 'OK: Z1-5 výnimka Expirovaná, preklady fáz Office portálu (O1, O10)';
END;
$$;
