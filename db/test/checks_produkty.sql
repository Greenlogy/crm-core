-- Kontroly modulu Produkty a cenníky, časť 1 (0019): produkt, párovanie so sadzbami v rozsahu PDS,
-- návrh produktov pre OOM, číselník sadzieb (C11, skrytá ZSD C1), cenová regulácia ANO/NIE, práva, audit.
-- Spúšťa sa iba cez db/test/run.sh (po checks_oom.sql – používa rolu crm_rls_test a českého obchodníka 2501).

-- Pomocné funkcie: platné EIC (kontrolná číslica dopočítaná) a OOM s PDS a sadzbou
CREATE FUNCTION pg_temp.t_eic(p_prefix text) RETURNS text LANGUAGE plpgsql AS $f$
DECLARE
  c text;
BEGIN
  FOREACH c IN ARRAY string_to_array('0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ-', NULL) LOOP
    IF eic_is_valid(p_prefix || c) THEN
      RETURN p_prefix || c;
    END IF;
  END LOOP;
  RAISE EXCEPTION 'EIC pre % sa nedá dopočítať', p_prefix;
END;
$f$;

CREATE FUNCTION pg_temp.t_pom(p_n integer, p_company uuid, p_person uuid, p_pds text, p_tariff text,
                              p_regulation boolean, p_nt numeric DEFAULT NULL) RETURNS uuid
LANGUAGE sql AS $f$
  INSERT INTO oom (company_id, person_id, eic, type, status, pds, pds_tariff, price_regulation,
                   planned_consumption_vt_mwh, planned_consumption_nt_mwh)
  VALUES (p_company, p_person, pg_temp.t_eic('24ZZS000TEST8' || lpad(p_n::text, 2, '0')), 'spotreba', 'pripravovane',
          p_pds, p_tariff, p_regulation, 10, p_nt)
  RETURNING id
$f$;

-- Kandidáti ako text „kód:rank“ (doplnková položka s „+“), zoradené ako ich vráti funkcia
CREATE FUNCTION pg_temp.t_cand(p_oom uuid) RETURNS text LANGUAGE sql AS $f$
  SELECT coalesce(string_agg(p.code || ':' || c.rank || CASE WHEN c.is_addon THEN '+' ELSE '' END, ' '
                             ORDER BY c.is_addon, c.rank, p.code), '')
    FROM product_candidates(p_oom) c JOIN product p ON p.id = c.product_id
$f$;

-- P1. Produkt: kontroly, nemazanie, nemenný kód
DO $$
DECLARE
  v_id uuid;
BEGIN
  INSERT INTO product (org_id, code, name, category, segment, vat_rate, price_models)
  VALUES (crm_default_org(), 'test_p1', 'Test P1', 'vbattery', 'domacnost', 23.00, '{cennik}')
  RETURNING id INTO v_id;
  ASSERT (SELECT status = 'predava_sa' AND tariff_type = 'netyka_sa' FROM product WHERE id = v_id), 'východiskový stav a tarif';

  BEGIN
    DELETE FROM product WHERE id = v_id;
    RAISE EXCEPTION 'CHYBA: produkt sa dal zmazať (vlastník)';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    UPDATE product SET code = 'test_p1_iny' WHERE id = v_id;
    RAISE EXCEPTION 'CHYBA: kód produktu sa dal zmeniť';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  UPDATE product SET status = 'ukonceny' WHERE id = v_id;   -- ukončenie áno

  BEGIN
    INSERT INTO product (org_id, code, name, category, segment, price_models)
    VALUES (crm_default_org(), 'test_p1_bez_dph', 'Bez DPH', 'zem', 'domacnost', '{cennik}');
    RAISE EXCEPTION 'CHYBA: produkt bez DPH prešiel';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  INSERT INTO product (org_id, code, name, category, segment, price_models)
  VALUES (crm_default_org(), 'test_p1_solar', 'Solar', 'instalacia_fve', 'domacnost', '{cena_diela}');   -- FVE bez DPH áno
  BEGIN
    INSERT INTO product (org_id, code, name, category, segment, vat_rate, price_models)
    VALUES (crm_default_org(), 'test_p1_dielo', 'Dielo', 'dodavka_firma', 'firma', 19.00, '{fix,cena_diela}');
    RAISE EXCEPTION 'CHYBA: cena diela mimo inštalácie FVE prešla';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    INSERT INTO product (org_id, code, name, category, segment, vat_rate, price_models)
    VALUES (crm_default_org(), 'test_p1_bez_modelu', 'Bez modelu', 'dodavka_firma', 'firma', 19.00, '{}');
    RAISE EXCEPTION 'CHYBA: produkt bez cenového modelu prešiel';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    INSERT INTO product (org_id, code, name, category, segment, vat_rate, price_models)
    VALUES (crm_default_org(), 'test_p1_dodavatel', 'Dodávateľ', 'dodavka_firma', 'dodavatel', 19.00, '{fix}');
    RAISE EXCEPTION 'CHYBA: segment dodávateľ prešiel';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  RAISE NOTICE 'OK: produkt (nemaže sa ani vlastníkom, kód sa nemení, DPH, cena diela, cenové modely, segment)';
END;
$$;

-- P2. Číselník sadzieb: nové sadzby, rozsahy PDS, skrytá ZSD C1 (nejde vybrať na OOM ani importom)
DO $$
DECLARE
  v_res jsonb;
  n     integer;
BEGIN
  ASSERT (SELECT count(*) FROM lookup_value WHERE list_code = 'sadzba_distribucie' AND hidden_at IS NULL
           AND code IN ('zsd_d4', 'zsd_d5', 'zsd_d6', 'zsd_d7', 'zsd_d8', 'zsd_c11', 'vsd_d4', 'vsd_d5', 'vsd_d6',
                        'vsd_d7', 'vsd_d8', 'vsd_c9', 'vsd_c11', 'ssd_d7', 'ssd_c11')) = 15, 'pridané sadzby';
  ASSERT tariff_base('zsd_c2_x3', 'zsd') = 'c2_x3' AND tariff_base('ssd_c11', 'ssd') = 'c11'
         AND tariff_base('ssd_c1', 'zsd') IS NULL, 'kód sadzby bez PDS';
  ASSERT oom_tariff_scope('zsd') = 'zsd' AND oom_tariff_scope('vsd') = 'vsd' AND oom_tariff_scope('ssd') = 'spolocne'
         AND oom_tariff_scope('enstra') = 'spolocne', 'rozsah PDS';
  BEGIN
    INSERT INTO tariff_scope (code, name) VALUES ('druhy_spolocny', 'Druhý spoločný');
    RAISE EXCEPTION 'CHYBA: druhý spoločný rozsah prešiel';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;
  BEGIN
    INSERT INTO tariff_scope (code, name, pds_code) VALUES ('nezname', 'Neznáme', 'nezname_pds');
    RAISE EXCEPTION 'CHYBA: rozsah s neznámym PDS prešiel';
  EXCEPTION WHEN foreign_key_violation THEN NULL;
  END;

  -- ZSD C1: na dev ju môže ešte používať testovacie OOM (0019 ju potom neskryje) – test ju skryje v transakcii
  n := (SELECT count(*) FROM oom WHERE pds_tariff = 'zsd_c1');
  IF (SELECT hidden_at FROM lookup_value WHERE code = 'zsd_c1') IS NULL THEN
    RAISE NOTICE 'POZOR: ZSD C1 nie je skrytá (0019 ju neskryla, lebo ju vtedy používalo OOM; teraz % OOM) – test ju skryje iba v transakcii', n;
    UPDATE lookup_value SET hidden_at = now() WHERE code = 'zsd_c1';
  END IF;
  BEGIN
    PERFORM pg_temp.t_pom(1, '00000000-0000-4000-8000-000000000102', NULL, 'zsd', 'zsd_c1', true);
    RAISE EXCEPTION 'CHYBA: skrytá sadzba ZSD C1 sa dala vybrať na OOM';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  v_res := oom_import_run(crm_default_org(), jsonb_build_array(jsonb_build_object(
             'row', 2, 'eic', pg_temp.t_eic('24ZZS000TEST802'), 'ico', '12345678',
             'fields', jsonb_build_object('type', 'spotreba', 'pds', 'ZSD', 'pds_tariff', 'C1'))), false);
  ASSERT v_res -> 'rows' -> 0 ->> 'action' = 'chyba' AND v_res -> 'rows' -> 0 ->> 'error' LIKE '%skrytá%',
         'import ZSD C1: ' || (v_res -> 'rows' -> 0)::text;
  BEGIN
    INSERT INTO product_tariff (product_id, scope_code, tariff_code)
    VALUES ('00000000-0000-4000-8000-000000000401', 'zsd', 'c1');
    RAISE EXCEPTION 'CHYBA: párovanie na skrytú sadzbu prešlo';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    INSERT INTO product_tariff (product_id, scope_code, tariff_code)
    VALUES ('00000000-0000-4000-8000-000000000401', 'zsd', 'c4');   -- ZSD nemá C4
    RAISE EXCEPTION 'CHYBA: párovanie na sadzbu mimo PDS prešlo';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  RAISE NOTICE 'OK: sadzby C11, D4–D8, C9, D7; rozsahy PDS; ZSD C1 skrytá – nejde na OOM, importom ani do párovania';
END;
$$;

-- P3. Návrh produktov pre OOM (zadanie čl. 5, príklady 1, 4, 8; Peter 13. 10.)
DO $$
DECLARE
  f   constant uuid := '00000000-0000-4000-8000-000000000102';   -- firma (Obec Betová)
  h   constant uuid := '00000000-0000-4000-8000-000000000201';   -- domácnosť
  v_p uuid;
  i   integer;
  o   uuid;
BEGIN
  -- Testy počítajú iba vlastné záznamy: skutočné produkty (napr. z cenníkov 2026 na Teste) sa v transakcii testu
  -- dočasne vyradia z návrhu (Dobieha) a na konci bloku vrátia.
  CREATE TEMP TABLE t_vyradene ON COMMIT DROP AS
    SELECT id FROM product WHERE code NOT LIKE 't\_%' AND status = 'predava_sa';
  UPDATE product SET status = 'dobieha' WHERE id IN (SELECT id FROM t_vyradene);

  -- Katalóg testu: DD2 ANO / NIE, ZEM, DMP1–DMP11 a produkt iba so spoločnými riadkami
  FOR v_p, i IN
    INSERT INTO product (org_id, code, name, category, segment, vat_rate, tariff_type, price_models, price_regulation)
    VALUES (crm_default_org(), 't_dd2_ano', 'T DD2 ANO', 'dodavka_domacnost', 'domacnost', 19, 'jednotarif', '{cennik,spot_plus_eur}', true),
           (crm_default_org(), 't_dd2_nie', 'T DD2 NIE', 'dodavka_domacnost', 'domacnost', 19, 'jednotarif', '{cennik,spot_plus_eur}', false),
           (crm_default_org(), 't_zem', 'T ZEM', 'zem', 'domacnost', 19, 'netyka_sa', '{cennik}', NULL)
    RETURNING id, 0
  LOOP
    INSERT INTO product_tariff (product_id, scope_code, tariff_code)
    SELECT v_p, s, 'd2' FROM unnest(ARRAY['zsd', 'vsd', 'spolocne']) s;
  END LOOP;
  INSERT INTO product (org_id, code, name, category, segment, vat_rate, tariff_type, price_models)
  VALUES (crm_default_org(), 't_iba_spolocne', 'T iba spoločné', 'dodavka_domacnost', 'domacnost', 19, 'jednotarif', '{cennik}')
  RETURNING id INTO v_p;
  INSERT INTO product_tariff (product_id, scope_code, tariff_code) VALUES (v_p, 'spolocne', 'd2');

  FOR i IN 1..11 LOOP
    INSERT INTO product (org_id, code, name, category, segment, vat_rate, tariff_type, price_models, price_regulation)
    VALUES (crm_default_org(), 't_dmp' || lpad(i::text, 2, '0'), 'T DMP' || i, 'dodavka_maly_podnik', 'firma', 19,
            CASE WHEN i BETWEEN 4 AND 8 THEN 'dvojtarif' WHEN i = 9 THEN 'nemerany' ELSE 'jednotarif' END::tariff_type,
            '{cennik}', true)
    RETURNING id INTO v_p;
    IF i IN (9, 11) THEN
      INSERT INTO product_tariff (product_id, scope_code, tariff_code)
      SELECT v_p, s, 'c' || i FROM unnest(ARRAY['zsd', 'vsd', 'spolocne']) s;
    ELSE
      INSERT INTO product_tariff (product_id, scope_code, tariff_code)
      VALUES (v_p, 'zsd', 'c2_x3'), (v_p, 'vsd', 'x3_c2'), (v_p, 'spolocne', 'c' || i);
    END IF;
  END LOOP;

  -- SSD + C1 → DMP1 (jediný, vyplní sa sám)
  o := pg_temp.t_pom(10, f, NULL, 'ssd', 'ssd_c1', true);
  ASSERT pg_temp.t_cand(o) = 't_dmp01:1', 'SSD C1: ' || pg_temp.t_cand(o);
  ASSERT (SELECT is_only FROM product_candidates(o)), 'SSD C1: DMP1 sa vyplní sám';

  -- ZSD + C2-X3 + NT > 0 → DMP4–DMP8 navrchu, potom DMP1–3 a DMP10; vyberá obchodník
  o := pg_temp.t_pom(11, f, NULL, 'zsd', 'zsd_c2_x3', true, 4);
  ASSERT pg_temp.t_cand(o) = 't_dmp04:1 t_dmp05:1 t_dmp06:1 t_dmp07:1 t_dmp08:1 t_dmp01:2 t_dmp02:2 t_dmp03:2 t_dmp10:2',
         'ZSD C2-X3 s NT: ' || pg_temp.t_cand(o);
  ASSERT NOT EXISTS (SELECT 1 FROM product_candidates(o) WHERE is_only), 'ZSD C2-X3: nič sa nevyplní samo';
  -- bez NT navrchu jednotarifné
  o := pg_temp.t_pom(12, f, NULL, 'zsd', 'zsd_c2_x3', true);
  ASSERT pg_temp.t_cand(o) = 't_dmp01:1 t_dmp02:1 t_dmp03:1 t_dmp10:1 t_dmp04:2 t_dmp05:2 t_dmp06:2 t_dmp07:2 t_dmp08:2',
         'ZSD C2-X3 bez NT: ' || pg_temp.t_cand(o);
  -- VSD X3-C2 rovnako
  o := pg_temp.t_pom(13, f, NULL, 'vsd', 'vsd_x3_c2', true, 1);
  ASSERT (SELECT count(*) FROM product_candidates(o)) = 9, 'VSD X3-C2: 9 produktov';

  -- ZSD + C11 → DMP11
  o := pg_temp.t_pom(14, f, NULL, 'zsd', 'zsd_c11', true);
  ASSERT pg_temp.t_cand(o) = 't_dmp11:1', 'ZSD C11: ' || pg_temp.t_cand(o);
  ASSERT (SELECT is_only FROM product_candidates(o)), 'ZSD C11: DMP11 sa vyplní sám';

  -- PDS s vlastným rozsahom nepoužije spoločné riadky: ZSD D2 bez „iba spoločné“, SSD D2 s ním
  o := pg_temp.t_pom(15, NULL, h, 'zsd', 'zsd_d2', false);
  ASSERT pg_temp.t_cand(o) = 't_dd2_nie:1 t_zem:1+', 'ZSD D2 NIE: ' || pg_temp.t_cand(o);
  ASSERT (SELECT is_only FROM product_candidates(o) c JOIN product p ON p.id = c.product_id WHERE p.code = 't_dd2_nie'),
         'ZSD D2 NIE: DD2 NIE sa vyplní sám';
  o := pg_temp.t_pom(16, NULL, h, 'ssd', 'ssd_d2', false);
  ASSERT pg_temp.t_cand(o) = 't_dd2_nie:1 t_iba_spolocne:1 t_zem:1+', 'SSD D2 NIE: ' || pg_temp.t_cand(o);

  -- Domácnosť s nevyplnenou reguláciou → ANO aj NIE, vyberá obchodník
  o := pg_temp.t_pom(17, NULL, h, 'zsd', 'zsd_d2', NULL);
  ASSERT pg_temp.t_cand(o) = 't_dd2_ano:1 t_dd2_nie:1 t_zem:1+', 'D2 nevyplnená: ' || pg_temp.t_cand(o);
  ASSERT NOT EXISTS (SELECT 1 FROM product_candidates(o) WHERE is_only), 'D2 nevyplnená: nič sa nevyplní samo';

  -- Firma bez nároku (NIE) → žiadny DMP; ukončený produkt sa neponúka
  o := pg_temp.t_pom(18, f, NULL, 'ssd', 'ssd_c1', false);
  ASSERT pg_temp.t_cand(o) = '', 'firma NIE: ' || pg_temp.t_cand(o);
  UPDATE product SET status = 'dobieha' WHERE code = 't_dmp11';
  o := pg_temp.t_pom(19, f, NULL, 'ssd', 'ssd_c11', true);
  ASSERT pg_temp.t_cand(o) = '', 'dobiehajúci produkt sa neponúka: ' || pg_temp.t_cand(o);
  UPDATE product SET status = 'predava_sa' WHERE id IN (SELECT id FROM t_vyradene);
  RAISE NOTICE 'OK: návrh produktov (SSD C1 → DMP1, ZSD C2-X3 + NT → DMP4–8 navrchu, ZSD C11 → DMP11, rozsah PDS, regulácia ANO/NIE/nevyplnená, stav)';
END;
$$;

-- P4. Cenová regulácia ANO / NIE / nevyplnené (import cez API posiela true / false)
DO $$
DECLARE
  v_res jsonb;
  v_eic text := pg_temp.t_eic('24ZZS000TEST820');
BEGIN
  PERFORM set_config('app.user_id', (SELECT id FROM app_user WHERE email = 'peter@greenlogy.com')::text, true);
  ASSERT (SELECT data_type FROM information_schema.columns
           WHERE table_name = 'oom' AND column_name = 'price_regulation') = 'boolean', 'typ boolean';
  v_res := oom_import_run(crm_default_org(), jsonb_build_array(jsonb_build_object(
             'row', 2, 'eic', v_eic, 'ico', '12345678',
             'fields', jsonb_build_object('type', 'spotreba', 'price_regulation', true))), true, 't.xlsx',
             '{"riadkov": 1, "nove": 1, "zmena": 0, "bez_zmeny": 0, "chyba": 0}');
  ASSERT (SELECT price_regulation FROM oom WHERE eic = v_eic), 'import ANO: ' || v_res::text;
  v_res := oom_import_run(crm_default_org(), jsonb_build_array(jsonb_build_object(
             'row', 2, 'eic', v_eic, 'fields', jsonb_build_object('price_regulation', false))), false);
  ASSERT v_res -> 'rows' -> 0 ->> 'action' = 'zmena'
         AND v_res -> 'rows' -> 0 -> 'changes' -> 0 ->> 'old' = 'true'
         AND v_res -> 'rows' -> 0 -> 'changes' -> 0 ->> 'new' = 'false', 'import zmena ANO → NIE: ' || v_res::text;
  UPDATE oom SET price_regulation = NULL WHERE eic = v_eic;     -- nevyplnené smie byť
  PERFORM set_config('app.user_id', '', true);
  RAISE NOTICE 'OK: cenová regulácia boolean (ANO / NIE / nevyplnené), import a zmeny v náhľade';
END;
$$;

-- P5. Práva: čítajú všetci aktívni (svoja spoločnosť), zapisuje iba admin; audit párovania
GRANT SELECT, INSERT, UPDATE, DELETE ON product, product_tariff, tariff_scope TO crm_rls_test;
GRANT SELECT ON oom, lookup_value TO crm_rls_test;
SET LOCAL ROLE crm_rls_test;

DO $$
DECLARE
  v_peter uuid := (SELECT id FROM app_user WHERE lower(email) = 'peter@greenlogy.com');
  v_p     uuid;
BEGIN
  PERFORM set_config('app.require_user', 'on', true);

  -- bez používateľa nič
  PERFORM set_config('app.user_id', '', true);
  ASSERT (SELECT count(*) FROM product) = 0, 'bez používateľa vidí produkty';

  -- obchodník (Sales_internal, SK) číta, nezapíše
  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-000000000011', true);
  ASSERT (SELECT count(*) FROM product WHERE code LIKE 't\_%') = 15, 'obchodník vidí produkty';
  ASSERT (SELECT count(*) FROM product_tariff) > 0 AND (SELECT count(*) FROM tariff_scope) = 3, 'obchodník vidí párovanie';
  BEGIN
    INSERT INTO product (org_id, code, name, category, segment, vat_rate, price_models)
    VALUES (crm_default_org(), 't_obchodnik', 'X', 'zem', 'domacnost', 19, '{cennik}');
    RAISE EXCEPTION 'CHYBA: obchodník založil produkt';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  UPDATE product SET name = 'zmena' WHERE code = 't_zem';
  ASSERT NOT FOUND, 'obchodník zmenil produkt';
  DELETE FROM product_tariff;
  ASSERT NOT FOUND, 'obchodník zmazal párovanie';
  BEGIN
    INSERT INTO tariff_scope (code, name, pds_code) VALUES ('ssd', 'SSD', 'ssd');
    RAISE EXCEPTION 'CHYBA: obchodník založil rozsah PDS';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  -- český obchodník nevidí slovenské produkty
  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-000000002501', true);
  ASSERT (SELECT count(*) FROM product) = 0, 'CZ obchodník vidí SK produkty';
  ASSERT (SELECT count(*) FROM product_tariff) = 0, 'CZ obchodník vidí SK párovanie';

  -- admin zakladá, mení a páruje; audit
  PERFORM set_config('app.user_id', v_peter::text, true);
  INSERT INTO product (org_id, code, name, category, segment, vat_rate, tariff_type, price_models, price_regulation)
  VALUES (crm_default_org(), 't_admin', 'T admin', 'dodavka_maly_podnik', 'firma', 19, 'jednotarif', '{cennik}', true)
  RETURNING id INTO v_p;
  UPDATE product SET status = 'dobieha' WHERE id = v_p;
  ASSERT FOUND, 'admin zmenil produkt';
  INSERT INTO product_tariff (product_id, scope_code, tariff_code) VALUES (v_p, 'spolocne', 'c3');
  DELETE FROM product_tariff WHERE product_id = v_p;
  ASSERT FOUND, 'admin zmazal párovanie';
  DELETE FROM product WHERE id = v_p;            -- bez politiky DELETE: nezmaže nič (vlastníka zastaví spúšťač, P1)
  ASSERT NOT FOUND AND EXISTS (SELECT 1 FROM product WHERE id = v_p), 'admin zmazal produkt';
  PERFORM set_config('app.user_id', '', true);
  PERFORM set_config('app.require_user', '', true);
END;
$$;

RESET ROLE;

DO $$
BEGIN
  ASSERT (SELECT count(*) FROM audit_log WHERE table_name = 'product_tariff' AND action = 'delete'
           AND changed_by = (SELECT id FROM app_user WHERE lower(email) = 'peter@greenlogy.com')) = 1, 'audit párovania';
  ASSERT EXISTS (SELECT 1 FROM audit_log WHERE table_name = 'product' AND action = 'update' AND diff ? 'status'), 'audit produktu';
  RAISE NOTICE 'OK: práva (čítajú aktívni svojej spoločnosti, zapisuje admin, nemaže nikto), audit produktu a párovania';
END;
$$;
