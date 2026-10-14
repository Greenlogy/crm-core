-- Kontroly modulu Zmluvy, fáza F1 (0023): typ predajcu a „schvaľuje ceny“, marža firmy a „vidieť všetky zmluvy“,
-- cenové parametre s históriou, trhové ceny a cena pre obchodníka, preklady importov, plán výkupu lokálneho zdroja,
-- cenová regulácia s dátumom, variant tarifu produktu.
-- Spúšťa sa iba cez db/test/run.sh (po checks_cenniky.sql – používa rolu crm_rls_test a obchodníka 0011).
-- Prejde aj s inými dátami: práva modulu Zmluvy si nastaví v transakcii testu, trhové ceny zapisuje pre rok 2099,
-- parametre overuje k dátumom vo februári 2026 (minulosť smie meniť iba vlastník databázy).

-- Používatelia: 4001 Sales_internal so „schvaľuje ceny“ (obchodný riaditeľ), 4002 Nákup, 4003 Servis, 4004 Marketing;
-- 0011 Sales_internal bez príznaku (seed.sql); admin = peter@greenlogy.com (0006).
INSERT INTO app_user (id, email, name, team_id, status, seller_type, approves_prices)
SELECT v.id::uuid, v.email, v.name, t.id, 'aktivny', v.st::seller_type, v.ap
  FROM (VALUES
    ('00000000-0000-4000-8000-000000004001', 'riaditel.z0@example.test', 'Obchodný riaditeľ Z0', 'sales_internal', 'manazer', true),
    ('00000000-0000-4000-8000-000000004002', 'nakup.z0@example.test',    'Nákup Z0',             'nakup',          NULL,      false),
    ('00000000-0000-4000-8000-000000004003', 'servis.z0@example.test',   'Servis Z0',            'servis',         NULL,      false),
    ('00000000-0000-4000-8000-000000004004', 'marketing.z0@example.test','Marketing Z0',         'marketing',      NULL,      false)
  ) AS v (id, email, name, team_code, st, ap)
  JOIN team t ON t.code = v.team_code;
INSERT INTO app_user_org (user_id, org_id)
SELECT u, crm_default_org() FROM unnest(ARRAY['00000000-0000-4000-8000-000000004001', '00000000-0000-4000-8000-000000004002',
                                             '00000000-0000-4000-8000-000000004003', '00000000-0000-4000-8000-000000004004']::uuid[]) AS u;

-- Východiskové práva modulu Zmluvy po 0023 (admin ich na Teste môže meniť – v teste sa nastavia v transakcii)
UPDATE team_permission p
   SET view_scope = CASE WHEN t.code IN ('sales_internal', 'sales_external') THEN 'iba_svoje' ELSE 'vsetko' END::access_scope,
       edit_scope = CASE t.code WHEN 'ceo' THEN 'vsetko' WHEN 'nakup' THEN 'vsetko' WHEN 'servis' THEN 'vsetko'
                                WHEN 'sales_internal' THEN 'iba_svoje' WHEN 'sales_external' THEN 'iba_svoje'
                                ELSE 'nic' END::access_scope,
       can_import = t.code IN ('ceo', 'nakup', 'servis'),
       can_see_company_margin = t.code IN ('ceo', 'nakup', 'marketing')
  FROM team t
 WHERE t.id = p.team_id AND p.module = 'zmluvy';

-- Pomocná funkcia: platné EIC (kontrolná číslica dopočítaná)
CREATE FUNCTION pg_temp.z_eic(p_prefix text) RETURNS text LANGUAGE plpgsql AS $f$
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

-- Z0-1. Poistky: externý tím nedostane maržu firmy ani člena, ktorý schvaľuje ceny; marža iba v module Zmluvy
DO $$
DECLARE
  v_team uuid;
BEGIN
  BEGIN
    UPDATE team_permission p SET can_see_company_margin = true
      FROM team t WHERE t.id = p.team_id AND t.code = 'sales_external' AND p.module = 'zmluvy';
    RAISE EXCEPTION 'CHYBA: externý tím dostal maržu firmy';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    UPDATE team_permission p SET can_see_company_margin = true
      FROM team t WHERE t.id = p.team_id AND t.code = 'ceo' AND p.module = 'obchod';
    RAISE EXCEPTION 'CHYBA: marža firmy mimo modulu Zmluvy';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  INSERT INTO team (code, name) VALUES ('test_z0', 'Test Z0') RETURNING id INTO v_team;
  UPDATE team_permission SET view_scope = 'iba_svoje', edit_scope = 'nic' WHERE team_id = v_team;
  INSERT INTO app_user (id, email, name, team_id, status, approves_prices)
  VALUES ('00000000-0000-4000-8000-000000004009', 'tim.z0@example.test', 'Tím Z0', v_team, 'aktivny', true);
  BEGIN
    UPDATE team SET is_external = true WHERE id = v_team;
    RAISE EXCEPTION 'CHYBA: tím so schvaľovateľom cien sa stal externým';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  RAISE NOTICE 'OK: Z0-1 poistky externého tímu (marža firmy, schvaľuje ceny), marža iba v module Zmluvy';
END;
$$;

GRANT SELECT, INSERT, UPDATE, DELETE ON price_parameter, market_price_daily, import_alias, oom_price_regulation_change
  TO crm_rls_test;
GRANT SELECT, UPDATE ON app_user TO crm_rls_test;
GRANT SELECT ON trader_price_today_v, market_price_history_v, team_permission, product, lookup_value TO crm_rls_test;
GRANT SELECT, UPDATE ON oom TO crm_rls_test;
SET LOCAL ROLE crm_rls_test;

-- Z0-2. Marža firmy a „vidieť všetky zmluvy“: tím alebo „schvaľuje ceny“ (Peter: obchodný riaditeľ v Sales_internal)
DO $$
BEGIN
  PERFORM set_config('app.require_user', 'on', true);

  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-000000000011', true);   -- Sales_internal bez príznaku
  ASSERT NOT crm_approves_prices() AND NOT crm_can_see_margin() AND NOT crm_sees_all_contracts(),
         'obchodník bez príznaku nevidí maržu ani všetky zmluvy';
  UPDATE app_user SET approves_prices = true WHERE id = '00000000-0000-4000-8000-000000000011';
  ASSERT NOT (SELECT approves_prices FROM app_user WHERE id = '00000000-0000-4000-8000-000000000011'),
         'obchodník si príznak „schvaľuje ceny“ nenastaví';

  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-000000004001', true);   -- Sales_internal + príznak
  ASSERT crm_scope('zmluvy', 'view') = 'iba_svoje', 'tím Sales_internal má „iba svoje“';
  ASSERT crm_approves_prices() AND crm_can_see_margin() AND crm_sees_all_contracts(),
         'obchodný riaditeľ v Sales_internal vidí maržu a všetky zmluvy';

  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-000000004002', true);   -- Nákup
  ASSERT crm_can_see_margin() AND crm_sees_all_contracts() AND NOT crm_approves_prices(), 'Nákup: marža, všetky zmluvy';
  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-000000004003', true);   -- Servis
  ASSERT NOT crm_can_see_margin() AND crm_sees_all_contracts() AND crm_can_import('zmluvy'), 'Servis: bez marže, všetky, import';
  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-000000004004', true);   -- Marketing
  ASSERT crm_can_see_margin() AND NOT crm_can_import('zmluvy'), 'Marketing: marža, bez importu';

  PERFORM set_config('app.user_id', '', true);
  ASSERT NOT crm_can_see_margin() AND NOT crm_sees_all_contracts(), 'aplikácia bez používateľa nič';
  PERFORM set_config('app.require_user', '', true);
  RAISE NOTICE 'OK: Z0-2 marža firmy a všetky zmluvy (tím alebo „schvaľuje ceny“ aj v Sales_internal; bez príznaku nie)';
END;
$$;

-- Z0-3. Cenové parametre: história, kto mení, „platí od“ iba dnes a neskôr, riadok sa nemení
DO $$
DECLARE
  v_org uuid := crm_default_org();
  v_id  uuid;
  n     integer;
BEGIN
  PERFORM set_config('app.require_user', 'on', true);

  -- obchodník tabuľku nečíta a nezapíše
  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-000000000011', true);
  ASSERT (SELECT count(*) FROM price_parameter) = 0, 'obchodník nečíta cenové parametre';
  BEGIN
    INSERT INTO price_parameter (org_id, code, valid_from, value) VALUES (v_org, 'nasa_marza', crm_today() + 1, 5);
    RAISE EXCEPTION 'CHYBA: obchodník zapísal cenový parameter';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  -- obchodný riaditeľ: história k dátumu, nový parameter od zajtra, minulosť nie, LZ a energopomoc nie
  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-000000004001', true);
  ASSERT price_param(v_org, 'pomer_bl_pct', '2026-02-05') = 80, 'pomer BL/PL k 5. 2. 2026';
  ASSERT price_param(v_org, 'nakup_energopomoc', '2026-02-05', 2026::smallint) = 72.40, 'energopomoc 2026';
  ASSERT price_param(v_org, 'viwa_aditiv_plus', '2025-12-01') = 20, 'VIWA Plus od 1. 10. 2025';
  ASSERT price_param(v_org, 'nasa_marza', '2025-12-01') IS NULL, 'pred 1. 1. 2026 marža nie je';

  SELECT count(*) INTO n FROM audit_log;
  INSERT INTO price_parameter (org_id, code, valid_from, value, note)
  VALUES (v_org, 'rizikova_prirazka', crm_today() + 30, 5, 'test Z0') RETURNING id INTO v_id;
  ASSERT (SELECT changed_by FROM price_parameter WHERE id = v_id) = '00000000-0000-4000-8000-000000004001', 'autor zmeny';
  ASSERT (SELECT count(*) FROM audit_log WHERE table_name = 'price_parameter' AND record_id = v_id
            AND source = 'aplikacia' AND changed_by = '00000000-0000-4000-8000-000000004001') = 1, 'zmena v audite';
  UPDATE price_parameter SET value = 4.5 WHERE id = v_id;                       -- budúci riadok smie autor opraviť
  ASSERT (SELECT value FROM price_parameter WHERE id = v_id) = 4.5, 'oprava budúceho parametra';
  BEGIN
    INSERT INTO price_parameter (org_id, code, valid_from, value) VALUES (v_org, 'nasa_marza', crm_today() - 1, 5);
    RAISE EXCEPTION 'CHYBA: parameter s minulým dátumom';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    INSERT INTO price_parameter (org_id, code, valid_from, value) VALUES (v_org, 'min_aditiv_vykup_lz', crm_today() + 1, 1);
    RAISE EXCEPTION 'CHYBA: obchodný riaditeľ zmenil minimálny aditív výkupu LZ';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    UPDATE price_parameter SET value = 99 WHERE org_id = v_org AND code = 'pomer_bl_pct' AND valid_from = '2026-01-01';
    RAISE EXCEPTION 'CHYBA: platný parameter sa zmenil';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    INSERT INTO price_parameter (org_id, code, valid_from, value) VALUES (v_org, 'pomer_bl_pct', crm_today() + 1, 101);
    RAISE EXCEPTION 'CHYBA: pomer BL nad 100 %%';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  DELETE FROM price_parameter WHERE id = v_id;                                   -- zrušenie plánovanej zmeny autorom
  ASSERT NOT EXISTS (SELECT 1 FROM price_parameter WHERE id = v_id), 'autor zrušil budúci parameter';

  -- admin smie aj minimálny aditív výkupu LZ (od zajtra); cudzí budúci riadok nezmení
  PERFORM set_config('app.user_id', (SELECT id FROM app_user WHERE lower(email) = 'peter@greenlogy.com')::text, true);
  INSERT INTO price_parameter (org_id, code, valid_from, value) VALUES (v_org, 'min_aditiv_vykup_lz', crm_today() + 1, 1)
  RETURNING id INTO v_id;
  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-000000004001', true);
  BEGIN
    UPDATE price_parameter SET value = 2 WHERE id = v_id;
    RAISE EXCEPTION 'CHYBA: cudzí budúci parameter sa zmenil';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  PERFORM set_config('app.user_id', '', true);
  PERFORM set_config('app.require_user', '', true);
  RAISE NOTICE 'OK: Z0-3 cenové parametre (história, kto mení, platí od dnes a neskôr, nemenný riadok, audit)';
END;
$$;
RESET ROLE;

-- Z0-4. Trhové ceny a cena pre obchodníka: história iba vlastník, obchodník vidí iba výsledok
INSERT INTO market_price_daily (org_id, on_date, delivery_year, bl_eur_mwh, pl_eur_mwh, portfolio_eur_mwh, source)
VALUES (crm_default_org(), '2026-02-02', 2099, 95, 110, 96, 'historia');   -- vlastník databázy (skript histórie)
SET LOCAL ROLE crm_rls_test;
DO $$
DECLARE
  v_org uuid := crm_default_org();
  v_exp numeric;
BEGIN
  PERFORM set_config('app.require_user', 'on', true);

  -- príklad zo zadania: BL 95, PL 110 → (95 × 80 + 110 × 20) / 100 + 4 + 4 = 106
  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-000000000011', true);
  ASSERT trader_price(v_org, 2099::smallint, '2026-02-05') = 106.0000, 'cena pre obchodníka 106,00 (3 dni po cene)';
  ASSERT trader_price(v_org, 2099::smallint, '2026-02-12') IS NULL, 'cena staršia ako 7 dní sa nepoužije';
  ASSERT (SELECT count(*) FROM market_price_daily) = 0, 'obchodník nevidí BL/PL ani odhad portfólia';
  ASSERT (SELECT count(*) FROM trader_price_today_v) = 0, 'obchodník nevidí zložky ceny';
  BEGIN
    INSERT INTO market_price_daily (org_id, on_date, delivery_year, bl_eur_mwh, pl_eur_mwh)
    VALUES (v_org, crm_today(), 2099, 1, 1);
    RAISE EXCEPTION 'CHYBA: obchodník zadal trhové ceny';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  -- obchodný riaditeľ: dnešné ceny áno, minulý deň nie, mazanie nie; zdroj vždy „ručne“
  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-000000004001', true);
  INSERT INTO market_price_daily (org_id, on_date, delivery_year, bl_eur_mwh, pl_eur_mwh, source)
  VALUES (v_org, crm_today(), 2099, 100, 120, 'cockpit');
  ASSERT (SELECT source = 'rucne' AND changed_by = '00000000-0000-4000-8000-000000004001'
            FROM market_price_daily WHERE org_id = v_org AND on_date = crm_today() AND delivery_year = 2099), 'ručné zadanie';
  v_exp := round((100 * price_param(v_org, 'pomer_bl_pct', crm_today()) + 120 * (100 - price_param(v_org, 'pomer_bl_pct', crm_today()))) / 100
                 + price_param(v_org, 'rizikova_prirazka', crm_today()) + price_param(v_org, 'nasa_marza', crm_today()), 4);
  ASSERT (SELECT trader_price_eur_mwh FROM trader_price_today_v WHERE org_id = v_org AND delivery_year = 2099) = v_exp,
         'obrazovka 29: cena pre obchodníka dnes';
  BEGIN
    INSERT INTO market_price_daily (org_id, on_date, delivery_year, bl_eur_mwh, pl_eur_mwh) VALUES (v_org, crm_today() - 1, 2099, 1, 1);
    RAISE EXCEPTION 'CHYBA: trhová cena za minulý deň z aplikácie';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    UPDATE market_price_daily SET bl_eur_mwh = 1 WHERE org_id = v_org AND on_date = '2026-02-02' AND delivery_year = 2099;
    RAISE EXCEPTION 'CHYBA: história trhových cien sa zmenila';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    DELETE FROM market_price_daily WHERE org_id = v_org AND on_date = crm_today() AND delivery_year = 2099;
    RAISE EXCEPTION 'CHYBA: trhová cena sa zmazala';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    UPDATE market_price_daily SET bl_eur_mwh = 101 WHERE org_id = v_org AND on_date = crm_today() AND delivery_year = 2099;
    RAISE EXCEPTION 'CHYBA: dnešná trhová cena sa prepísala (oprava má byť nový záznam)';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  -- Oprava ceny dňa (0024): nový záznam pre ten istý deň platí, pôvodný ostane v histórii „opravené“ s menom a časom
  INSERT INTO market_price_daily (org_id, on_date, delivery_year, bl_eur_mwh, pl_eur_mwh)
  VALUES (v_org, crm_today(), 2099, 110, 120);
  ASSERT (SELECT count(*) FROM market_price_history_v WHERE org_id = v_org AND on_date = crm_today() AND delivery_year = 2099) = 2,
         'história má pôvodný aj opravný záznam';
  ASSERT (SELECT is_corrected AND corrected_by = '00000000-0000-4000-8000-000000004001' AND corrected_at IS NOT NULL
                 AND corrected_by_name = 'Obchodný riaditeľ Z0' AND bl_eur_mwh = 100
            FROM market_price_history_v WHERE org_id = v_org AND on_date = crm_today() AND delivery_year = 2099 AND is_corrected),
         'pôvodný záznam označený „opravené“, kto a kedy';
  ASSERT (SELECT count(*) FROM audit_log a JOIN market_price_daily m ON m.id = a.record_id
           WHERE a.table_name = 'market_price_daily' AND m.org_id = v_org AND m.on_date = crm_today() AND m.delivery_year = 2099
             AND a.changed_by = '00000000-0000-4000-8000-000000004001') = 3,
         'audit: pôvodný zápis, oprava a označenie opravené';
  v_exp := round((110 * price_param(v_org, 'pomer_bl_pct', crm_today()) + 120 * (100 - price_param(v_org, 'pomer_bl_pct', crm_today()))) / 100
                 + price_param(v_org, 'rizikova_prirazka', crm_today()) + price_param(v_org, 'nasa_marza', crm_today()), 4);
  ASSERT trader_price(v_org, 2099::smallint, crm_today()) = v_exp, 'oprava zmenila cenu pre obchodníka v ten deň';
  ASSERT (SELECT trader_price_eur_mwh = v_exp AND bl_eur_mwh = 110 FROM trader_price_today_v
           WHERE org_id = v_org AND delivery_year = 2099), 'obrazovka 29 ukazuje opravenú cenu';

  PERFORM set_config('app.user_id', '', true);
  PERFORM set_config('app.require_user', '', true);
  RAISE NOTICE 'OK: Z0-4 trhové ceny a cena pre obchodníka (106,00; 7 dní; obchodník iba výsledok; dnes a neskôr; nemažú sa; oprava novým záznamom s históriou a auditom)';
END;
$$;

-- Z0-5. Preklady importov: normalizácia, systémové aliasy, preklad, kontrola cieľa, iba admin
DO $$
DECLARE
  v_org   uuid := crm_default_org();
  v_admin uuid := (SELECT id FROM app_user WHERE lower(email) = 'peter@greenlogy.com');
  a       import_alias;
BEGIN
  ASSERT import_name_norm('VBattery  - V') = import_name_norm('vbattery - v'), 'viac medzier';
  ASSERT import_name_norm('TDO 4 ') = 'tdo 4', 'orezanie';
  ASSERT import_name_norm('Západoslovenská distribučná') = 'zapadoslovenska distribucna', 'diakritika';
  ASSERT import_name_norm('GREEN_1T_INDIVIDUAL_2027') = 'green_1t_individual_rrrr', 'rok v názve produktu';
  ASSERT import_name_norm('2026_GREENVYR_AK [EUR]') = 'rrrr_greenvyr_ak [eur]', 'rok na začiatku';
  ASSERT import_name_norm('24X-ZSE-PDS----5') = '24x-zse-pds----5', 'EIC PDS bez zmeny';
  ASSERT import_name_norm('X4-D2') = 'x4-d2', 'sadzba';

  -- systémové aliasy z migrácie (existujú; admin ich na Teste môže skryť, preto bez podmienky „neskrytý“)
  ASSERT EXISTS (SELECT 1 FROM import_alias WHERE is_system AND kind = 'produkt_op' AND name_norm = 'green_2t_vyk_individual_rrrr'
                   AND target = 'fix' AND target_extra ->> 'tariff' = '2t_vyk'), 'GREEN_2T_VYK_INDIVIDUAL = FIX 2T vykurovanie';
  ASSERT EXISTS (SELECT 1 FROM import_alias WHERE is_system AND kind = 'sadzba' AND name_norm = 'x4-d2' AND target = 'd2'), 'X4-D2 = D2';
  ASSERT EXISTS (SELECT 1 FROM import_alias WHERE is_system AND kind = 'sadzba' AND name_norm = 'd3 aktiv /byvala d5/' AND target = 'd3'), 'D3 Aktiv = D3';
  ASSERT EXISTS (SELECT 1 FROM import_alias WHERE is_system AND kind = 'sadzba' AND name_norm = 'x2 /vn/' AND target = 'x2'), 'X2 /VN/ = X2';
  ASSERT EXISTS (SELECT 1 FROM import_alias WHERE is_system AND kind = 'pds' AND target = 'zsd'
                   AND name_norm = import_name_norm('Západoslovenská distribučná (24X-ZSE-PDS----5)')), 'Sústava ZSD';
  ASSERT EXISTS (SELECT 1 FROM import_alias WHERE is_system AND kind = 'typ_merania' AND name_norm = 'typ merania a' AND target = 'a'), 'typ merania A';
  ASSERT EXISTS (SELECT 1 FROM import_alias WHERE is_system AND kind = 'fakturacne_obdobie' AND name_norm = 'rok' AND target = 'rocne'), 'Rok = ročne';

  -- preklad: alias zdroja má prednosť pred spoločným, skrytý sa nepoužije, neznámy = NULL
  INSERT INTO import_alias (org_id, source, kind, name_sample, target) VALUES
    (v_org, 'vsetky',        'iny', 'Test Z0 Názov', 'spolocny'),
    (v_org, 'office_portal', 'iny', 'TEST z0  názov', 'op');
  a := import_alias_resolve(v_org, 'office_portal', 'iny', 'test Z0 nazov ');
  ASSERT a.target = 'op', 'alias zdroja má prednosť';
  a := import_alias_resolve(v_org, 'xm_trade', 'iny', 'Test Z0 Názov');
  ASSERT a.target = 'spolocny', 'spoločný alias pre iný zdroj';
  UPDATE import_alias SET hidden_at = now() WHERE org_id = v_org AND kind = 'iny' AND source = 'office_portal' AND target = 'op';
  a := import_alias_resolve(v_org, 'office_portal', 'iny', 'Test Z0 Názov');
  ASSERT a.target = 'spolocny', 'skrytý alias sa nepoužije';
  ASSERT (import_alias_resolve(v_org, 'office_portal', 'iny', 'Neznámy Z0')).id IS NULL, 'neznámy názov = NULL';

  -- kontrola cieľa (vlastník): neexistujúca sadzba, produkt a PDS sa neuložia
  BEGIN
    INSERT INTO import_alias (org_id, source, kind, name_sample, target) VALUES (v_org, 'vsetky', 'sadzba', 'Z0 sadzba', 'd99');
    RAISE EXCEPTION 'CHYBA: alias na neexistujúcu sadzbu';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    INSERT INTO import_alias (org_id, source, kind, name_sample, target) VALUES (v_org, 'vsetky', 'produkt_oom', 'Z0 produkt', 'neexistuje_z0');
    RAISE EXCEPTION 'CHYBA: alias na neexistujúci produkt';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    INSERT INTO import_alias (org_id, source, kind, name_sample, target) VALUES (v_org, 'vsetky', 'produkt_op', 'Z0 model', 'cena_diela');
    RAISE EXCEPTION 'CHYBA: alias na model cena diela';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    INSERT INTO import_alias (org_id, source, kind, name_sample, target) VALUES (v_org, 'vsetky', 'sadzba', 'x4-D2  ', 'd2');
    RAISE EXCEPTION 'CHYBA: duplicitný alias (iný zápis toho istého názvu)';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;
  RAISE NOTICE 'OK: Z0-5a preklady (normalizácia, systémové aliasy, prednosť zdroja, skrytý, neznámy, kontrola cieľa)';
END;
$$;

SET LOCAL ROLE crm_rls_test;
DO $$
DECLARE
  v_org   uuid := crm_default_org();
  v_admin uuid := (SELECT id FROM app_user WHERE lower(email) = 'peter@greenlogy.com');
  v_sys   uuid;
BEGIN
  SELECT id INTO v_sys FROM import_alias WHERE is_system AND kind = 'sadzba' AND name_norm = 'x2 /vn/';   -- bez používateľa (služba)
  ASSERT v_sys IS NOT NULL, 'systémový preklad X2 /VN/ existuje';
  PERFORM set_config('app.require_user', 'on', true);

  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-000000000011', true);
  ASSERT (SELECT count(*) FROM import_alias WHERE id = v_sys) = 1, 'obchodník preklady číta (náhľad importu)';
  BEGIN
    INSERT INTO import_alias (org_id, source, kind, name_sample, target) VALUES (v_org, 'vsetky', 'iny', 'Z0 obchodník', 'x');
    RAISE EXCEPTION 'CHYBA: obchodník pridal preklad';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  PERFORM set_config('app.user_id', v_admin::text, true);
  INSERT INTO import_alias (org_id, source, kind, name_sample, target) VALUES (v_org, 'xm_trade', 'sadzba', 'Z0 D3 nová', 'd3');
  ASSERT (SELECT created_by FROM import_alias WHERE name_norm = 'z0 d3 nova') = v_admin, 'autor prekladu';
  BEGIN
    INSERT INTO import_alias (org_id, source, kind, name_sample, target, is_system) VALUES (v_org, 'vsetky', 'iny', 'Z0 systém', 'x', true);
    RAISE EXCEPTION 'CHYBA: admin založil systémový preklad';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    DELETE FROM import_alias WHERE id = v_sys;
    RAISE EXCEPTION 'CHYBA: systémový preklad sa zmazal';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    UPDATE import_alias SET target = 'x3_c2' WHERE id = v_sys;
    RAISE EXCEPTION 'CHYBA: systémový preklad zmenil cieľ';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  UPDATE import_alias SET hidden_at = now() WHERE id = v_sys;                     -- skryť smie
  ASSERT (SELECT hidden_at IS NOT NULL FROM import_alias WHERE id = v_sys), 'systémový preklad sa dá skryť';
  DELETE FROM import_alias WHERE name_norm = 'z0 d3 nova';                         -- vlastný zmazať smie

  PERFORM set_config('app.user_id', '', true);
  PERFORM set_config('app.require_user', '', true);
  RAISE NOTICE 'OK: Z0-5b preklady (číta každý, mení iba admin, systémové sa iba skryjú)';
END;
$$;
RESET ROLE;

-- Z0-6. Plán výkupu lokálneho zdroja: výpočet, ručný prepis, návrat výpočtu
DO $$
DECLARE
  v_id  uuid;
  v_id2 uuid;
BEGIN
  INSERT INTO oom (company_id, eic, type, status, source_category, source_power_kw)
  VALUES ('00000000-0000-4000-8000-000000000101', pg_temp.z_eic('24ZZS000TESTZ01'), 'vyroba', 'pripravovane', 'lokalny_zdroj', 10)
  RETURNING id INTO v_id;
  ASSERT (SELECT planned_feed_in_mwh = 1.460 AND NOT planned_feed_in_manual FROM oom WHERE id = v_id), '10 kW → 1,460 MWh';
  UPDATE oom SET source_power_kw = 20 WHERE id = v_id;
  ASSERT (SELECT planned_feed_in_mwh FROM oom WHERE id = v_id) = 2.920, 'zmena výkonu prepočíta';
  UPDATE oom SET planned_feed_in_mwh = 5 WHERE id = v_id;
  ASSERT (SELECT planned_feed_in_mwh = 5 AND planned_feed_in_manual FROM oom WHERE id = v_id), 'ručný plán';
  UPDATE oom SET source_power_kw = 30 WHERE id = v_id;
  ASSERT (SELECT planned_feed_in_mwh FROM oom WHERE id = v_id) = 5, 'ručný plán sa so zmenou výkonu nemení';
  UPDATE oom SET planned_feed_in_manual = false WHERE id = v_id;
  ASSERT (SELECT planned_feed_in_mwh FROM oom WHERE id = v_id) = 4.380, '„Vrátiť výpočet“';
  UPDATE oom SET planned_feed_in_mwh = 9 WHERE id = v_id;
  UPDATE oom SET planned_feed_in_mwh = NULL WHERE id = v_id;
  ASSERT (SELECT planned_feed_in_mwh = 4.380 AND NOT planned_feed_in_manual FROM oom WHERE id = v_id), 'vyprázdnenie vráti výpočet';
  UPDATE oom SET planned_feed_in_mwh = 4.380 WHERE id = v_id;
  ASSERT (SELECT NOT planned_feed_in_manual FROM oom WHERE id = v_id), 'hodnota rovná vzorcu nie je ručná';

  INSERT INTO oom (company_id, eic, type, status, source_category, source_power_kw, planned_feed_in_mwh)
  VALUES ('00000000-0000-4000-8000-000000000101', pg_temp.z_eic('24ZZS000TESTZ02'), 'vyroba', 'pripravovane', 'lokalny_zdroj', 10, 7)
  RETURNING id INTO v_id2;
  ASSERT (SELECT planned_feed_in_mwh = 7 AND planned_feed_in_manual FROM oom WHERE id = v_id2), 'založenie s ručným plánom';
  UPDATE oom SET source_category = 'vyrobny_zdroj', planned_feed_in_manual = false WHERE id = v_id2;
  UPDATE oom SET source_power_kw = 50, planned_feed_in_mwh = 8 WHERE id = v_id2;
  ASSERT (SELECT planned_feed_in_mwh FROM oom WHERE id = v_id2) = 8, 'výrobný zdroj: plán sa nepočíta';
  ASSERT (SELECT NOT public_lighting FROM oom WHERE id = v_id), 'verejné osvetlenie východiskovo nie';
  RAISE NOTICE 'OK: Z0-6 plán výkupu lokálneho zdroja (1,460 MWh; ručný; návrat výpočtu; výrobný zdroj bez výpočtu)';
END;
$$;

-- Z0-7. Cenová regulácia s dátumom: dnes a minulosť hneď, budúci dátum zatiaľ nie, iba pri prístupe k OOM
DO $$
DECLARE
  v_id uuid := (SELECT id FROM oom WHERE eic = pg_temp.z_eic('24ZZS000TESTZ01'));
BEGIN
  PERFORM oom_price_regulation_set(v_id, true, crm_today() - 10);
  ASSERT (SELECT price_regulation FROM oom WHERE id = v_id), 'regulácia ANO zapísaná na OOM';
  ASSERT (SELECT value AND applied_at IS NOT NULL FROM oom_price_regulation_change
           WHERE oom_id = v_id AND valid_from = crm_today() - 10), 'história s dátumom';
  PERFORM oom_price_regulation_set(v_id, false, crm_today() - 10);
  ASSERT (SELECT count(*) FROM oom_price_regulation_change WHERE oom_id = v_id) = 1, 'ten istý dátum sa prepíše';
  ASSERT NOT (SELECT price_regulation FROM oom WHERE id = v_id), 'regulácia NIE';

  -- Budúca zmena (0024): na OOM sa ešte neprejaví, je „naplánovaná“; nočný beh ju uplatní v deň platnosti
  PERFORM oom_price_regulation_set(v_id, true, crm_today() + 5);
  ASSERT NOT (SELECT price_regulation FROM oom WHERE id = v_id), 'budúca zmena ešte neplatí';
  ASSERT (SELECT applied_at IS NULL FROM oom_price_regulation_change WHERE oom_id = v_id AND valid_from = crm_today() + 5),
         'budúca zmena je naplánovaná (neuplatnená)';
  ASSERT oom_price_regulation_apply(v_id, crm_today() + 4) AND NOT (SELECT price_regulation FROM oom WHERE id = v_id),
         'deň pred platnosťou sa nemení';
  ASSERT oom_price_regulation_apply(v_id, crm_today() + 5), 'v deň platnosti sa uplatní';
  ASSERT (SELECT price_regulation FROM oom WHERE id = v_id), 'regulácia ANO od dňa platnosti';
  ASSERT (SELECT applied_at IS NOT NULL FROM oom_price_regulation_change WHERE oom_id = v_id AND valid_from = crm_today() + 5),
         'uplatnená zmena má čas';

  -- staršia zmena zadaná neskôr neprebije novšiu: platí najneskoršia s dátumom do dneška
  UPDATE oom SET price_regulation = false WHERE id = v_id;
  DELETE FROM oom_price_regulation_change WHERE oom_id = v_id;
  PERFORM oom_price_regulation_set(v_id, false, crm_today() - 3);
  PERFORM oom_price_regulation_set(v_id, true, crm_today() - 20);
  ASSERT NOT (SELECT price_regulation FROM oom WHERE id = v_id), 'staršia zmena neprebila novšiu';

  -- zrušenie naplánovanej zmeny; uplatnenú zrušiť nejde
  PERFORM oom_price_regulation_set(v_id, true, crm_today() + 10);
  PERFORM oom_price_regulation_cancel((SELECT id FROM oom_price_regulation_change WHERE oom_id = v_id AND valid_from = crm_today() + 10));
  ASSERT NOT EXISTS (SELECT 1 FROM oom_price_regulation_change WHERE oom_id = v_id AND valid_from = crm_today() + 10), 'zrušená';
  BEGIN
    PERFORM oom_price_regulation_cancel((SELECT id FROM oom_price_regulation_change WHERE oom_id = v_id AND valid_from = crm_today() - 3));
    RAISE EXCEPTION 'CHYBA: zrušená uplatnená zmena';
  EXCEPTION WHEN no_data_found THEN NULL;
  END;

  -- nočný beh vracia počet uplatnených zmien regulácie
  ASSERT oom_daily_run_at(crm_today()) ? 'regulacia', 'nočný beh uplatňuje reguláciu';
END;
$$;
SET LOCAL ROLE crm_rls_test;
DO $$
BEGIN
  PERFORM set_config('app.require_user', 'on', true);
  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-000000004004', true);   -- Marketing: OOM iba vidí
  BEGIN
    PERFORM oom_price_regulation_set((SELECT id FROM oom WHERE eic = pg_temp.z_eic('24ZZS000TESTZ01')), true, crm_today());
    RAISE EXCEPTION 'CHYBA: regulácia bez práva upravovať OOM';
  EXCEPTION WHEN no_data_found OR insufficient_privilege THEN NULL;
  END;
  PERFORM set_config('app.user_id', '', true);
  PERFORM set_config('app.require_user', '', true);
  RAISE NOTICE 'OK: Z0-7 cenová regulácia s dátumom (história, prepis dňa, budúca naplánovaná a uplatnená nočným behom, zrušenie, staršia neprebije novšiu, bez práva nie)';
END;
$$;
RESET ROLE;

-- Z0-8. Variant tarifu produktu: vykurovanie iba dvojtarif, VO iba jednotarif; použitý produkt variant nemení
DO $$
DECLARE
  v_prod uuid;
  v_list uuid;
  v_ver  uuid;
BEGIN
  BEGIN
    INSERT INTO product (org_id, code, name, category, segment, vat_rate, tariff_type, tariff_variant, price_models)
    VALUES (crm_default_org(), 'test_z0_vo2t', 'Z0 VO 2T', 'dodavka_firma', 'firma', 19, 'dvojtarif', 'verejne_osvetlenie', '{cennik}');
    RAISE EXCEPTION 'CHYBA: verejné osvetlenie pri dvojtarife';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  INSERT INTO product (org_id, code, name, category, segment, vat_rate, tariff_type, tariff_variant, price_models)
  VALUES (crm_default_org(), 'test_z0_vo', 'Z0 1T VO', 'dodavka_firma', 'firma', 19, 'jednotarif', 'verejne_osvetlenie', '{cennik,fix,spot_plus_eur}')
  RETURNING id INTO v_prod;
  INSERT INTO price_list (org_id, code, name, segment) VALUES (crm_default_org(), 'test_z0_list', 'Z0 cenník', 'firma')
  RETURNING id INTO v_list;
  INSERT INTO price_list_version (price_list_id, name, valid_from) VALUES (v_list, 'Z0', crm_today() + 1) RETURNING id INTO v_ver;
  INSERT INTO price_list_item (version_id, product_id, price_vt_eur_mwh, fee_oom_eur_month) VALUES (v_ver, v_prod, 162, 5);
  BEGIN
    UPDATE product SET tariff_variant = NULL WHERE id = v_prod;
    RAISE EXCEPTION 'CHYBA: použitý produkt zmenil variant tarifu';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  RAISE NOTICE 'OK: Z0-8 variant tarifu (vykurovanie / VO podľa typu tarifu, použitý produkt ho nemení)';
END;
$$;
