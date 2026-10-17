-- Kontroly modulu 5, fáza F6, krok 1 (0047): ceny z Workera Montel – denný beh (BL / PL rokov dodávky, 12-mesačný SPOT
-- priemer), ručne zadaná cena dňa sa neprepíše, odhad portfólia sa prenesie, história od 1. 1. 2026 (iba admin, dni s cenou
-- sa nemenia), práva: surové BL, PL, históriu a SPOT priemer v tabuľkách vidí iba admin a kto vidí maržu firmy; obchodník
-- dostane iba cenu pre obchodníka a SPOT priemer cez funkcie.
-- S6 (0048): admin zmaže ručne zadanú cenu dňa s dôvodom; ďalší beh ju načíta z Montelu.
-- Spúšťa sa iba cez db/test/run.sh po checks_zmluvy_obchody.sql (rola crm_rls_test).
-- Vlastné záznamy: …-0000000c00xx používatelia; roky dodávky 2091–2094 (iné testy ich nepoužívajú).

-- ============================================================================
-- Príprava (vlastník databázy)
-- ============================================================================

CREATE FUNCTION pg_temp.c_id(p_n integer) RETURNS uuid LANGUAGE sql AS $f$
  SELECT ('00000000-0000-4000-8000-0000000c00' || lpad(p_n::text, 2, '0'))::uuid
$f$;
CREATE FUNCTION pg_temp.c_as(p_user uuid) RETURNS text LANGUAGE sql AS $f$
  SELECT set_config('app.require_user', 'on', true) || set_config('app.user_id', coalesce(p_user::text, ''), true)
$f$;
-- platný riadok ceny dňa a roka
CREATE FUNCTION pg_temp.c_row(p_on date, p_year integer) RETURNS market_price_daily LANGUAGE sql AS $f$
  SELECT * FROM market_price_daily
   WHERE org_id = crm_default_org() AND on_date = p_on AND delivery_year = p_year AND corrected_at IS NULL
$f$;

-- 1 interný obchodník, 2 externý obchodník, 3 admin, 4 schvaľovateľ cien, 5 Servis (bez marže), 6 Nákup (tím vidí maržu firmy)
INSERT INTO app_user (id, email, name, team_id, status, seller_type, is_admin)
SELECT x.id::uuid, x.email, x.name, t.id, 'aktivny', x.st::seller_type, x.adm
  FROM (VALUES
    ('00000000-0000-4000-8000-0000000c0001', 'obchodnik.spot@example.test', 'Obchodník S', 'sales_internal', 'obchodnik', false),
    ('00000000-0000-4000-8000-0000000c0002', 'externy.spot@example.test', 'Externý S', 'sales_external', 'obchodnik', false),
    ('00000000-0000-4000-8000-0000000c0003', 'admin.spot@example.test', 'Admin S', 'sales_internal', NULL, true),
    ('00000000-0000-4000-8000-0000000c0004', 'schvalovatel.spot@example.test', 'Schvaľovateľ S', 'sales_internal', NULL, false),
    ('00000000-0000-4000-8000-0000000c0005', 'servis.spot@example.test', 'Servis S', 'servis', NULL, false),
    ('00000000-0000-4000-8000-0000000c0006', 'nakup.spot@example.test', 'Nákup S', 'nakup', NULL, false)
  ) AS x(id, email, name, team, st, adm)
  JOIN team t ON t.code = x.team;
UPDATE app_user SET approves_prices = true WHERE id = '00000000-0000-4000-8000-0000000c0004';
INSERT INTO app_user_org (user_id, org_id)
SELECT id, crm_default_org() FROM app_user WHERE id::text LIKE '00000000-0000-4000-8000-0000000c00%'
ON CONFLICT DO NOTHING;

-- práva ako aplikácia (app-role.sql, 0047)
GRANT SELECT ON market_price_daily, market_price_history_v, trader_price_today_v, spot_average_daily, job_run TO crm_rls_test;
GRANT INSERT ON market_price_daily TO crm_rls_test;
GRANT EXECUTE ON FUNCTION market_price_daily_run(jsonb, numeric, jsonb), market_price_history_import(jsonb), spot_average_on(uuid, date),
  trader_price(uuid, smallint, date), market_price_manual_remove(uuid, text) TO crm_rls_test;

-- ============================================================================
-- S0. Práva na funkcie a tabuľky: import cien iba cez funkcie vlastníka; aplikácia nezapisuje do SPOT priemeru
-- ============================================================================
DO $$
BEGIN
  ASSERT NOT has_function_privilege('crm_rls_test', 'market_price_import(uuid, date, jsonb, text, boolean)', 'EXECUTE'), 'interný import (test)';
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'crm_app') THEN
    ASSERT NOT has_function_privilege('crm_app', 'market_price_import(uuid, date, jsonb, text, boolean)', 'EXECUTE'), 'interný import (aplikácia)';
    ASSERT has_function_privilege('crm_app', 'market_price_daily_run(jsonb, numeric, jsonb)', 'EXECUTE')
       AND has_function_privilege('crm_app', 'market_price_history_import(jsonb)', 'EXECUTE')
       AND has_function_privilege('crm_app', 'spot_average_on(uuid, date)', 'EXECUTE'), 'aplikácia spúšťa beh, históriu a SPOT priemer';
    ASSERT NOT has_table_privilege('crm_app', 'spot_average_daily', 'INSERT') AND NOT has_table_privilege('crm_app', 'spot_average_daily', 'UPDATE'),
           'aplikácia nezapisuje SPOT priemer (app-role.sql)';
  END IF;
  -- ukladajú sa iba hodnoty, nie odpovede Montelu
  ASSERT NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name IN ('spot_average_daily', 'market_price_daily')
                      AND data_type IN ('json', 'jsonb', 'text') AND column_name NOT IN ('source', 'removed_reason')), 'bez uložených odpovedí';
  RAISE NOTICE 'OK: S0 import cien iba cez funkcie vlastníka, aplikácia nezapisuje SPOT priemer, ukladajú sa iba hodnoty';
END;
$$;

-- ============================================================================
-- S1. Denný beh: iba na pozadí; BL / PL rokov → zdroj cockpit; neplatné riadky sa vynechajú; rovnaké hodnoty sa nezapíšu znova;
--     nové hodnoty v ten istý deň nahradia predošlé; SPOT priemer; denník behov
-- ============================================================================
SET LOCAL ROLE crm_rls_test;
DO $$
BEGIN
  PERFORM pg_temp.c_as(pg_temp.c_id(3));
  BEGIN
    PERFORM market_price_daily_run('[{"year": 2091, "bl": 1, "pl": 1}]', 50);
    RAISE EXCEPTION 'CHYBA: denný beh cien spustil prihlásený používateľ (admin)';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM pg_temp.c_as(NULL);
  PERFORM set_config('app.require_user', '', true);
END;
$$;
RESET ROLE;
DO $$
DECLARE
  v_runs integer := (SELECT count(*) FROM job_run WHERE job = 'ceny');
  r      jsonb;
  m      market_price_daily;
BEGIN
  r := market_price_daily_run('[{"year": 2091, "bl": 95.123456, "pl": 110, "extra": "x"}, {"year": 2092, "bl": 90, "pl": 105},
                                {"year": 2093, "bl": 90}, {"year": 2094, "bl": -1, "pl": 5}, {"year": 1999, "bl": 1, "pl": 1}]', 101.5);
  ASSERT r = '{"ceny": 2, "spot": 1}', 'zapísané 2 roky a SPOT: ' || r::text;
  m := pg_temp.c_row(crm_today(), 2091);
  ASSERT m.bl_eur_mwh = 95.1235 AND m.pl_eur_mwh = 110 AND m.source = 'cockpit' AND m.changed_by IS NULL, 'BL / PL 2091 zo zdroja cockpit';
  ASSERT pg_temp.c_row(crm_today(), 2093) IS NULL AND pg_temp.c_row(crm_today(), 2094) IS NULL, 'neúplný a záporný riadok sa vynechá';
  ASSERT (SELECT avg_12m_eur_mwh FROM spot_average_daily WHERE org_id = crm_default_org() AND on_date = crm_today()) = 101.5, 'SPOT priemer';
  ASSERT (SELECT count(*) FROM job_run WHERE job = 'ceny') = v_runs + 1, 'beh v denníku';

  -- 13:00 bez zmeny: nič nové
  r := market_price_daily_run('[{"year": 2091, "bl": 95.1235, "pl": 110}, {"year": 2092, "bl": 90, "pl": 105}]', 101.5);
  ASSERT r->>'ceny' = '0', 'rovnaké hodnoty sa nezapíšu znova: ' || r::text;
  ASSERT (SELECT count(*) FROM market_price_daily WHERE org_id = crm_default_org() AND on_date = crm_today() AND delivery_year = 2091) = 1, 'jeden riadok';

  -- 13:00 nový settlement: nahradí ranný (ranný ostane v histórii ako opravený)
  r := market_price_daily_run('[{"year": 2092, "bl": 91, "pl": 106}]', 102);
  ASSERT r->>'ceny' = '1' AND (pg_temp.c_row(crm_today(), 2092)).bl_eur_mwh = 91, 'nová hodnota dňa';
  ASSERT (SELECT count(*) FROM market_price_daily WHERE org_id = crm_default_org() AND on_date = crm_today() AND delivery_year = 2092
            AND corrected_at IS NOT NULL AND bl_eur_mwh = 90) = 1, 'ranná hodnota v histórii';
  ASSERT (SELECT avg_12m_eur_mwh FROM spot_average_daily WHERE org_id = crm_default_org() AND on_date = crm_today()) = 102, 'SPOT priemer aktualizovaný';
  RAISE NOTICE 'OK: S1 denný beh: iba na pozadí; BL / PL zo zdroja cockpit; neplatné riadky vynechané; bez duplicít; nová hodnota dňa nahradí rannú; SPOT priemer; denník';
END;
$$;

-- ============================================================================
-- S2. Ručne zadaná cena dňa sa neprepíše; ručne zadaná nákupná cena portfólia (bez BL / PL) sa prenesie do ceny z Montelu
--     (0056: nákupnú cenu portfólia zadáva iba admin a Nákup funkciou market_price_portfolio_set, nie schvaľovateľ cien)
-- ============================================================================
GRANT EXECUTE ON FUNCTION market_price_portfolio_set(uuid, date, integer, numeric) TO crm_rls_test;
SET LOCAL ROLE crm_rls_test;
DO $$
BEGIN
  PERFORM pg_temp.c_as(pg_temp.c_id(4));                    -- schvaľovateľ cien
  BEGIN
    INSERT INTO market_price_daily (org_id, on_date, delivery_year, bl_eur_mwh, pl_eur_mwh, portfolio_eur_mwh)
    VALUES (crm_default_org(), crm_today(), 2091, 80, 90, 85);
    RAISE EXCEPTION 'CHYBA: schvaľovateľ cien zadal nákupnú cenu portfólia';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  INSERT INTO market_price_daily (org_id, on_date, delivery_year, bl_eur_mwh, pl_eur_mwh)
  VALUES (crm_default_org(), crm_today(), 2091, 80, 90);
  INSERT INTO market_price_daily (org_id, on_date, delivery_year, spot_fve_eur_mwh)
  VALUES (crm_default_org(), crm_today(), 2093, 60);
  PERFORM pg_temp.c_as(pg_temp.c_id(6));                    -- Nákup
  PERFORM market_price_portfolio_set(crm_default_org(), crm_today(), 2093, 77);
  PERFORM pg_temp.c_as(pg_temp.c_id(4));
  -- prihlásený používateľ nemôže obísť strážcu nastavením príznaku importu
  PERFORM set_config('crm.market_price_import', 'on', true);
  BEGIN
    INSERT INTO market_price_daily (org_id, on_date, delivery_year, bl_eur_mwh, pl_eur_mwh) VALUES (crm_default_org(), crm_today() - 3, 2091, 1, 1);
    RAISE EXCEPTION 'CHYBA: používateľ zapísal cenu do minulosti cez príznak importu';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    INSERT INTO market_price_daily (org_id, on_date, delivery_year, bl_eur_mwh, pl_eur_mwh) VALUES (crm_default_org(), crm_today(), 2092, 1, 1);
    RAISE EXCEPTION 'CHYBA: používateľ zapísal cenu so zdrojom Montelu cez príznak importu';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM set_config('crm.market_price_import', '', true);
  PERFORM set_config('crm.market_price_correction', 'on', true);
  BEGIN
    INSERT INTO market_price_daily (org_id, on_date, delivery_year, bl_eur_mwh, pl_eur_mwh) VALUES (crm_default_org(), crm_today(), 2092, 1, 1);
    RAISE EXCEPTION 'CHYBA: používateľ použil príznak opravy';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM set_config('crm.market_price_correction', '', true);
  PERFORM pg_temp.c_as(NULL);
  PERFORM set_config('app.require_user', '', true);
END;
$$;
RESET ROLE;
DO $$
DECLARE
  r jsonb;
  m market_price_daily;
BEGIN
  ASSERT (pg_temp.c_row(crm_today(), 2091)).source = 'rucne', 'ručná cena dňa';
  r := market_price_daily_run('[{"year": 2091, "bl": 99, "pl": 120}, {"year": 2093, "bl": 70, "pl": 75}]', NULL);
  ASSERT r = '{"ceny": 1, "spot": 0}', 'iba rok 2093: ' || r::text;
  m := pg_temp.c_row(crm_today(), 2091);
  ASSERT m.bl_eur_mwh = 80 AND m.source = 'rucne', 'ručná BL / PL ostala';
  m := pg_temp.c_row(crm_today(), 2093);
  ASSERT m.bl_eur_mwh = 70 AND m.pl_eur_mwh = 75 AND m.portfolio_eur_mwh = 77 AND m.spot_fve_eur_mwh = 60 AND m.source = 'cockpit',
         'cena z Montelu s preneseným odhadom portfólia a SPOT pre FVE: ' || m::text;
  ASSERT (SELECT avg_12m_eur_mwh FROM spot_average_daily WHERE org_id = crm_default_org() AND on_date = crm_today()) = 102, 'bez SPOT sa priemer nemení';
  RAISE NOTICE 'OK: S2 ručne zadaná cena dňa ostane; ručný odhad portfólia a SPOT pre FVE sa prenesú; príznak importu používateľovi nepomôže';
END;
$$;

-- ============================================================================
-- S3. História od 1. 1. 2026: iba admin; dni s cenou sa nemenia; dni mimo obdobia sa vynechajú; zdroj historia
-- ============================================================================
INSERT INTO market_price_daily (org_id, on_date, delivery_year, bl_eur_mwh, pl_eur_mwh, source)
VALUES (crm_default_org(), '2026-03-03', 2094, 50, 60, 'cockpit');
SET LOCAL ROLE crm_rls_test;
DO $$
DECLARE
  v_days jsonb := '[{"on_date": "2026-03-02", "rows": [{"year": 2094, "bl": 51, "pl": 61}]},
                    {"on_date": "2026-03-03", "rows": [{"year": 2094, "bl": 52, "pl": 62}]},
                    {"on_date": "2025-12-31", "rows": [{"year": 2094, "bl": 53, "pl": 63}]}]';
  u integer;
  r jsonb;
BEGIN
  FOREACH u IN ARRAY ARRAY[1, 2, 4, 5, 6] LOOP
    PERFORM pg_temp.c_as(pg_temp.c_id(u));
    BEGIN
      PERFORM market_price_history_import(v_days);
      RAISE EXCEPTION 'CHYBA: históriu načítal používateľ %', u;
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
  END LOOP;
  PERFORM pg_temp.c_as(pg_temp.c_id(3));
  r := market_price_history_import(v_days);
  ASSERT r = '{"dni": 2, "riadky": 1}', 'história: ' || r::text;
  ASSERT (SELECT bl_eur_mwh FROM market_price_daily WHERE on_date = '2026-03-02' AND delivery_year = 2094 AND corrected_at IS NULL AND source = 'historia') = 51,
         'deň bez ceny doplnený (admin ho vidí)';
  ASSERT (SELECT bl_eur_mwh FROM market_price_daily WHERE on_date = '2026-03-03' AND delivery_year = 2094 AND corrected_at IS NULL) = 50, 'deň s cenou sa nemení';
  ASSERT NOT EXISTS (SELECT 1 FROM market_price_daily WHERE on_date = '2025-12-31' AND delivery_year = 2094), 'pred 1. 1. 2026 nič';
  r := market_price_history_import(v_days);
  ASSERT r->>'riadky' = '0', 'opakované načítanie nič nemení';
  PERFORM pg_temp.c_as(NULL);
  PERFORM set_config('app.require_user', '', true);
  RAISE NOTICE 'OK: S3 história: iba admin (nie obchodník, externý, schvaľovateľ, Servis, Nákup); dni s cenou sa nemenia; od 1. 1. 2026; opakovane bez zmeny';
END;
$$;
RESET ROLE;

-- ============================================================================
-- S4. Obchodník (interný aj externý) a tím bez marže (Servis): nevidí BL, PL, históriu ani SPOT priemer v tabuľkách; dostane cenu
--     pre obchodníka a SPOT priemer cez funkcie. Admin, schvaľovateľ cien a tím s maržou firmy vidia surové hodnoty.
-- ============================================================================
CREATE TEMP TABLE c_expected AS
SELECT round((80 * price_param(crm_default_org(), 'pomer_bl_pct', crm_today()) + 90 * (100 - price_param(crm_default_org(), 'pomer_bl_pct', crm_today()))) / 100
             + price_param(crm_default_org(), 'rizikova_prirazka', crm_today()) + price_param(crm_default_org(), 'nasa_marza', crm_today()), 4) AS p2091;
GRANT SELECT ON c_expected TO crm_rls_test;
SET LOCAL ROLE crm_rls_test;
DO $$
DECLARE
  u integer;
  s record;
BEGIN
  FOREACH u IN ARRAY ARRAY[1, 2, 5] LOOP
    PERFORM pg_temp.c_as(pg_temp.c_id(u));
    ASSERT NOT crm_can_see_margin() AND NOT crm_is_admin(), 'bez marže ' || u;
    ASSERT (SELECT count(*) FROM market_price_daily) = 0, 'nevidí BL / PL ' || u;
    ASSERT (SELECT count(*) FROM market_price_history_v) = 0, 'nevidí históriu ' || u;
    ASSERT (SELECT count(*) FROM trader_price_today_v) = 0, 'nevidí zložky ceny ' || u;
    ASSERT (SELECT count(*) FROM spot_average_daily) = 0, 'nevidí tabuľku SPOT ' || u;
    ASSERT (SELECT count(*) FROM job_run WHERE job = 'ceny') = 0, 'nevidí denník cien ' || u;
    ASSERT trader_price(crm_default_org(), 2091::smallint, crm_today()) = (SELECT p2091 FROM c_expected), 'cena pre obchodníka z ručnej ceny ' || u;
    ASSERT trader_price(crm_default_org(), 2093::smallint, crm_today()) IS NOT NULL, 'cena pre obchodníka z Montelu ' || u;
    SELECT * INTO s FROM spot_average_on(crm_default_org(), crm_today());
    ASSERT s.avg_12m_eur_mwh = 102 AND s.on_date = crm_today(), 'SPOT priemer cez funkciu ' || u;
    ASSERT (SELECT avg_12m_eur_mwh FROM spot_average_on(crm_default_org(), crm_today() + 7)) = 102, 'SPOT priemer 7 dní dozadu';
    ASSERT NOT EXISTS (SELECT 1 FROM spot_average_on(crm_default_org(), crm_today() + 8)), 'starší ako 7 dní nie';
  END LOOP;
  -- bez prihlásenia nič
  PERFORM pg_temp.c_as(NULL);
  ASSERT NOT EXISTS (SELECT 1 FROM spot_average_on(crm_default_org(), crm_today())), 'bez prihlásenia bez SPOT';
  ASSERT trader_price(crm_default_org(), 2091::smallint, crm_today()) IS NULL, 'bez prihlásenia bez ceny';

  FOREACH u IN ARRAY ARRAY[3, 4, 6] LOOP
    PERFORM pg_temp.c_as(pg_temp.c_id(u));
    ASSERT (SELECT count(*) FROM market_price_daily WHERE delivery_year BETWEEN 2091 AND 2094) >= 5, 'surové BL / PL ' || u;
    ASSERT (SELECT count(*) FROM spot_average_daily WHERE on_date = crm_today()) = 1, 'tabuľka SPOT ' || u;
    ASSERT (SELECT count(*) FROM market_price_history_v WHERE delivery_year = 2092 AND is_corrected) = 1, 'história ' || u;
  END LOOP;
  PERFORM pg_temp.c_as(NULL);
  PERFORM set_config('app.require_user', '', true);
  RAISE NOTICE 'OK: S4 obchodník interný, externý a Servis: bez BL / PL, histórie, zložiek ceny a tabuľky SPOT; cena pre obchodníka a SPOT priemer cez funkcie; admin, schvaľovateľ a tím s maržou (Nákup) vidia surové hodnoty';
END;
$$;
RESET ROLE;

-- ============================================================================
-- S5. Chyba pri načítaní z Montelu: zapíše sa do denníka a admini dostanú upozornenie
-- ============================================================================
DO $$
DECLARE
  v_n integer := (SELECT count(*) FROM notification WHERE kind = 'nocny_beh_chyba' AND user_id = pg_temp.c_id(3));
  r   jsonb;
BEGIN
  r := market_price_daily_run('[]', NULL, '[{"krok": "montel", "kod": "HTTP 502", "text": "/forwards/quotes"}]');
  ASSERT r = '{"ceny": 0, "spot": 0}', 'nič nezapísané';
  ASSERT EXISTS (SELECT 1 FROM job_run WHERE job = 'ceny' AND errors @> '[{"krok": "montel", "kod": "HTTP 502"}]' AND result = '{"ceny": 0, "spot": 0}'),
         'chyba v denníku';
  ASSERT (SELECT count(*) FROM notification WHERE kind = 'nocny_beh_chyba' AND user_id = pg_temp.c_id(3)) = v_n + 1, 'upozornenie adminovi';
  ASSERT NOT EXISTS (SELECT 1 FROM notification WHERE kind = 'nocny_beh_chyba' AND user_id = pg_temp.c_id(1)), 'obchodníkovi nie';
  RAISE NOTICE 'OK: S5 chyba z Montelu: v denníku behov a upozornenie adminom';
END;
$$;

-- ============================================================================
-- S6. Zmazanie ručne zadanej ceny dňa (0048): iba admin, s dôvodom, iba platná ručná cena; riadok ostane v histórii
--     (kto, kedy, dôvod) a v audite; ďalší beh cien deň načíta z Montelu
-- ============================================================================
SET LOCAL ROLE crm_rls_test;
DO $$
DECLARE
  v_manual uuid;
  v_auto   uuid;
  u        integer;
BEGIN
  PERFORM pg_temp.c_as(pg_temp.c_id(3));
  v_manual := (SELECT id FROM market_price_daily WHERE on_date = crm_today() AND delivery_year = 2091 AND corrected_at IS NULL);
  v_auto := (SELECT id FROM market_price_daily WHERE on_date = crm_today() AND delivery_year = 2092 AND corrected_at IS NULL);
  FOREACH u IN ARRAY ARRAY[1, 4, 6] LOOP
    PERFORM pg_temp.c_as(pg_temp.c_id(u));
    BEGIN
      PERFORM market_price_manual_remove(v_manual, 'test zmazania');
      RAISE EXCEPTION 'CHYBA: ručnú cenu zmazal používateľ %', u;
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
  END LOOP;
  PERFORM pg_temp.c_as(pg_temp.c_id(3));
  BEGIN
    PERFORM market_price_manual_remove(v_manual, '  ');
    RAISE EXCEPTION 'CHYBA: zmazanie bez dôvodu';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    PERFORM market_price_manual_remove(v_auto, 'cena z Montelu');
    RAISE EXCEPTION 'CHYBA: zmazaná cena z Montelu';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  PERFORM market_price_manual_remove(v_manual, ' preklep v BL ');
  ASSERT (SELECT corrected_by FROM market_price_daily WHERE id = v_manual) = pg_temp.c_id(3)
     AND (SELECT removed_reason FROM market_price_daily WHERE id = v_manual) = 'preklep v BL', 'kto a dôvod';
  ASSERT NOT EXISTS (SELECT 1 FROM market_price_daily WHERE on_date = crm_today() AND delivery_year = 2091 AND corrected_at IS NULL),
         'deň bez platnej ceny roka 2091';
  BEGIN
    PERFORM market_price_manual_remove(v_manual, 'znova');
    RAISE EXCEPTION 'CHYBA: zmazané dvakrát';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    UPDATE market_price_daily SET removed_reason = 'x y z' WHERE id = v_auto;
    RAISE EXCEPTION 'CHYBA: dôvod zapísaný mimo funkcie';
  EXCEPTION WHEN insufficient_privilege OR check_violation THEN NULL;
  END;
  PERFORM pg_temp.c_as(NULL);
  PERFORM set_config('app.require_user', '', true);
END;
$$;
RESET ROLE;
DO $$
DECLARE
  r jsonb;
BEGIN
  ASSERT EXISTS (SELECT 1 FROM audit_log a JOIN market_price_daily m ON m.id = a.record_id
                  WHERE a.table_name = 'market_price_daily' AND m.removed_reason = 'preklep v BL' AND a.action = 'update'
                    AND a.changed_by = pg_temp.c_id(3) AND a.diff::text LIKE '%preklep v BL%'), 'zmazanie v audite';
  r := market_price_daily_run('[{"year": 2091, "bl": 99, "pl": 120}]', NULL);
  ASSERT r->>'ceny' = '1' AND (pg_temp.c_row(crm_today(), 2091)).source = 'cockpit' AND (pg_temp.c_row(crm_today(), 2091)).bl_eur_mwh = 99,
         'ďalší beh načíta deň z Montelu';
  RAISE NOTICE 'OK: S6 zmazanie ručnej ceny dňa: iba admin, s dôvodom, iba platná ručná cena, raz; kto / kedy / dôvod v histórii a audite; ďalší beh načíta Montel';
END;
$$;
