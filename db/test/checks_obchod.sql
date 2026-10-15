-- Kontroly modulu 5, fáza F1 (0032): štádiá a povinné údaje, znovuotvorenie s dôvodom, vlastník zákazníka (konflikt,
-- zákazník bez vlastníka), jedno OOM v jednom otvorenom obchode (výnimka Obnova), OOM pri prehre, pridelenie firmy,
-- RLS „iba svoje“ (vlastné obchody a obchody na vlastných zákazníkoch), časová os, nočný beh (ďalší krok).
-- Spúšťa sa iba cez db/test/run.sh po checks_objem_xm.sql (rola crm_rls_test z checks_zakaznici.sql).
-- Vlastné záznamy: používatelia …-0000000090xx, firmy …-0000000091xx, OOM …-0000000092xx, dealy …-0000000093xx,
-- zmluvy …-0000000094xx. Predajcovia sú v testovacom tíme s „iba svoje“ (do externého tímu sa používateľ zatiaľ
-- priradiť nedá – crm_external_ready); pravidlá „iba svoje“ sú pre interný aj externý tím rovnaké.

-- ============================================================================
-- Príprava (vlastník databázy)
-- ============================================================================

INSERT INTO team (id, name, code, description)
VALUES ('00000000-0000-4000-8000-000000009000', 'Test predajcovia B', 'test_predajcovia_b', 'testy 0032');
UPDATE team_permission SET view_scope = 'iba_svoje', edit_scope = 'iba_svoje'
 WHERE team_id = '00000000-0000-4000-8000-000000009000' AND module IN ('obchod', 'zakaznici', 'odberne_miesta');

INSERT INTO app_user (id, email, name, team_id, status, approves_assignments)
SELECT x.id::uuid, x.email, x.name, t.id, 'aktivny', x.appr
  FROM (VALUES
    ('00000000-0000-4000-8000-000000009001', 'predajca.a.b@example.test', 'Predajca A', 'test_predajcovia_b', false),
    ('00000000-0000-4000-8000-000000009002', 'predajca.b.b@example.test', 'Predajca B', 'test_predajcovia_b', false),
    ('00000000-0000-4000-8000-000000009003', 'riaditel.b@example.test',   'Obchodný riaditeľ B', 'sales_internal', false),
    ('00000000-0000-4000-8000-000000009004', 'schvalovatel.b@example.test', 'Schvaľovateľ B', 'marketing', true),
    ('00000000-0000-4000-8000-000000009005', 'servis.b@example.test',     'Servis B', 'servis', false),
    ('00000000-0000-4000-8000-000000009006', 'predajca.c.b@example.test', 'Predajca C', 'test_predajcovia_b', false)
  ) AS x(id, email, name, team, appr)
  JOIN team t ON t.code = x.team;
INSERT INTO app_user_org (user_id, org_id)
SELECT id, crm_default_org() FROM app_user WHERE id::text LIKE '00000000-0000-4000-8000-0000000090%';

INSERT INTO company (id, name, ico, is_customer, owner_id) VALUES
  ('00000000-0000-4000-8000-000000009101', 'Firma A B1 s.r.o.',    '99999981', true, '00000000-0000-4000-8000-000000009001'),
  ('00000000-0000-4000-8000-000000009102', 'Firma B B1 s.r.o.',    '99999982', true, '00000000-0000-4000-8000-000000009002'),
  ('00000000-0000-4000-8000-000000009103', 'Bez vlastníka B1 a.s.', '99999983', true, NULL),
  ('00000000-0000-4000-8000-000000009105', 'Firma A2 B1 s.r.o.',   '99999985', true, '00000000-0000-4000-8000-000000009001');
INSERT INTO contact (id, first_name, last_name, email, is_household, owner_id) VALUES
  ('00000000-0000-4000-8000-000000009104', 'Domácnosť', 'B1', 'domacnost.b1@example.test', true, '00000000-0000-4000-8000-000000009001');

CREATE FUNCTION pg_temp.b_eic(p_n integer) RETURNS text LANGUAGE plpgsql AS $f$
DECLARE
  l text;
  c text;
BEGIN
  FOREACH l IN ARRAY string_to_array('KLMNPQRSTUVW', NULL) LOOP
    FOREACH c IN ARRAY string_to_array('0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ', NULL) LOOP
      IF eic_is_valid('24ZZS000OBCH' || l || lpad(p_n::text, 2, '0') || c) THEN
        RETURN '24ZZS000OBCH' || l || lpad(p_n::text, 2, '0') || c;
      END IF;
    END LOOP;
  END LOOP;
END;
$f$;
CREATE FUNCTION pg_temp.b_id(p_kind text, p_n integer) RETURNS uuid LANGUAGE sql AS $f$
  SELECT ('00000000-0000-4000-8000-0000000' || CASE p_kind WHEN 'u' THEN '090' WHEN 'f' THEN '091' WHEN 'oom' THEN '092'
                                                            WHEN 'd' THEN '093' ELSE '094' END || lpad(p_n::text, 2, '0'))::uuid
$f$;
CREATE FUNCTION pg_temp.b_pipe(p_kind text) RETURNS uuid LANGUAGE sql AS $f$
  SELECT id FROM pipeline WHERE kind = p_kind::deal_kind AND org_id IS NULL
                            AND name IN ('B2B dodávka', 'B2B výkup', 'Green VIWA B2B', 'B2C')
$f$;
CREATE FUNCTION pg_temp.b_stage(p_kind text, p_code text) RETURNS uuid LANGUAGE sql AS $f$
  SELECT id FROM pipeline_stage WHERE pipeline_id = pg_temp.b_pipe(p_kind) AND code = p_code::deal_stage_code
$f$;
-- OOM zákazníka (firma), Pripravované, plánovaná spotreba VT
CREATE FUNCTION pg_temp.b_oom(p_n integer, p_company integer, p_vt numeric DEFAULT 10, p_deal integer DEFAULT NULL)
RETURNS uuid LANGUAGE sql AS $f$
  INSERT INTO oom (id, company_id, eic, type, status, planned_consumption_vt_mwh, created_from_deal_id)
  VALUES (pg_temp.b_id('oom', p_n), pg_temp.b_id('f', p_company), pg_temp.b_eic(p_n), 'spotreba', 'pripravovane', p_vt,
          CASE WHEN p_deal IS NOT NULL THEN pg_temp.b_id('d', p_deal) END)
  RETURNING id
$f$;

DO $$
BEGIN
  PERFORM pg_temp.b_oom(1, 1);    -- Firma A
  PERFORM pg_temp.b_oom(2, 1);
  PERFORM pg_temp.b_oom(3, 2);    -- Firma B
END;
$$;

-- Matica práv (Peter 15. 10.: overiť, nemeniť): Sales_external = „iba svoje“ v obchode, zákazníkoch, OOM, zmluvách
DO $$
DECLARE
  r record;
BEGIN
  FOR r IN SELECT p.module, p.view_scope, p.edit_scope FROM team_permission p JOIN team t ON t.id = p.team_id
            WHERE t.code = 'sales_external' AND p.module IN ('obchod', 'zakaznici', 'odberne_miesta', 'zmluvy') LOOP
    ASSERT (r.view_scope, r.edit_scope) = ('iba_svoje'::access_scope, 'iba_svoje'::access_scope),
           format('Sales_external %s: %s / %s', r.module, r.view_scope, r.edit_scope);
  END LOOP;
  ASSERT (SELECT view_scope FROM team_permission p JOIN team t ON t.id = p.team_id
           WHERE t.code = 'sales_external' AND p.module = 'provizie') = 'iba_svoje', 'Sales_external provízie iba svoje';
  ASSERT (SELECT count(*) FROM pipeline WHERE org_id IS NULL AND name IN ('B2B dodávka', 'B2B výkup', 'Green VIWA B2B', 'B2C')) = 4,
         '4 pipelines z migrácie';
  ASSERT (SELECT count(*) FROM pipeline_stage WHERE pipeline_id = pg_temp.b_pipe('b2b_dodavka') AND code IS NOT NULL) = 6,
         '6 systémových štádií';
  ASSERT (SELECT probability FROM pipeline_stage WHERE id = pg_temp.b_stage('b2b_dodavka', 'akceptacia')) = 0.90, 'Akceptácia 90 %';
  RAISE NOTICE 'OK: B0 pipelines a 6 systémových štádií; Sales_external má v obchode, zákazníkoch, OOM a zmluvách „iba svoje“';
END;
$$;

-- Nová pipeline dostane systémové štádiá; systémové štádium nejde archivovať, kód nejde meniť
DO $$
DECLARE
  v_p uuid;
BEGIN
  INSERT INTO pipeline (name, kind) VALUES ('Test pipeline B0', 'b2b_dodavka') RETURNING id INTO v_p;
  ASSERT (SELECT count(*) FROM pipeline_stage WHERE pipeline_id = v_p AND code IS NOT NULL) = 6, 'nová pipeline – 6 štádií';
  BEGIN
    UPDATE pipeline_stage SET archived_at = now() WHERE pipeline_id = v_p AND code = 'vyjednavanie';
    RAISE EXCEPTION 'CHYBA: systémové štádium archivované';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    UPDATE pipeline_stage SET code = 'akceptacia' WHERE pipeline_id = v_p AND code = 'vyjednavanie';
    RAISE EXCEPTION 'CHYBA: kód štádia zmenený';
  EXCEPTION WHEN check_violation OR unique_violation THEN NULL;
  END;
  BEGIN
    INSERT INTO pipeline_stage (pipeline_id, name, sort_order, outcome) VALUES (v_p, 'Druhé vyhraté', 95, 'vyhrany');
    RAISE EXCEPTION 'CHYBA: stage pridaná adminom s výsledkom vyhraný';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  UPDATE pipeline_stage SET name = 'Ponuka odoslaná' WHERE pipeline_id = v_p AND code = 'cenova_ponuka';
  RAISE NOTICE 'OK: B0 nová pipeline so systémovými štádiami; kód a archivácia systémového štádia sú zamknuté, premenovať sa dá';
END;
$$;

GRANT SELECT, INSERT, UPDATE, DELETE ON deal, deal_oom, deal_contact TO crm_rls_test;
GRANT SELECT ON deal_event, approval_request, pipeline, pipeline_stage, lookup_value, app_user, notification TO crm_rls_test;
GRANT SELECT, UPDATE ON company, contact TO crm_rls_test;
GRANT SELECT, INSERT, UPDATE ON oom TO crm_rls_test;
GRANT UPDATE ON approval_request TO crm_rls_test;   -- aby sa overilo, že zápis aj tak nepustí RLS (žiadna politika)
SET LOCAL ROLE crm_rls_test;

-- ============================================================================
-- B1. Štádiá: povinné údaje, Akceptácia a Vyhraté iba systém, prehra s dôvodom, znovuotvorenie s dôvodom
-- ============================================================================
DO $$
DECLARE
  d uuid := pg_temp.b_id('d', 1);
BEGIN
  PERFORM set_config('app.require_user', 'on', true);
  PERFORM set_config('app.user_id', pg_temp.b_id('u', 1)::text, true);

  BEGIN
    INSERT INTO deal (company_id, pipeline_id, stage_id, name, owner_id, source_code)
    VALUES (pg_temp.b_id('f', 1), pg_temp.b_pipe('b2b_dodavka'), pg_temp.b_stage('b2b_dodavka', 'cenova_ponuka'),
            'Rovno ponuka', pg_temp.b_id('u', 1), 'web');
    RAISE EXCEPTION 'CHYBA: nový obchod mimo Príležitosti';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    INSERT INTO deal (company_id, pipeline_id, stage_id, name, owner_id, source_code)
    VALUES (pg_temp.b_id('f', 1), pg_temp.b_pipe('b2b_dodavka'), pg_temp.b_stage('b2b_dodavka', 'prilezitost'),
            'Bez zdroja', pg_temp.b_id('u', 1), 'neznamy');
    RAISE EXCEPTION 'CHYBA: neznámy zdroj';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  INSERT INTO deal (id, company_id, pipeline_id, stage_id, name, owner_id, source_code)
  VALUES (d, pg_temp.b_id('f', 1), pg_temp.b_pipe('b2b_dodavka'), pg_temp.b_stage('b2b_dodavka', 'prilezitost'),
          'Firma A 2027', pg_temp.b_id('u', 1), 'odporucanie');
  ASSERT EXISTS (SELECT 1 FROM deal_event WHERE deal_id = d AND kind = 'zalozenie'), 'udalosť založenia';

  BEGIN
    UPDATE deal SET stage_id = pg_temp.b_stage('b2b_dodavka', 'cenova_ponuka') WHERE id = d;
    RAISE EXCEPTION 'CHYBA: Cenová ponuka bez OOM';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  INSERT INTO deal_oom (deal_id, oom_id) VALUES (d, pg_temp.b_id('oom', 1));
  ASSERT (SELECT planned_vt_mwh FROM deal_oom WHERE deal_id = d) = 10, 'objem predvyplnený z OOM';
  UPDATE deal SET stage_id = pg_temp.b_stage('b2b_dodavka', 'cenova_ponuka') WHERE id = d;
  BEGIN
    UPDATE deal_oom SET planned_vt_mwh = 0 WHERE deal_id = d;
    RAISE EXCEPTION 'CHYBA: obchod v ponuke bez objemu';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    DELETE FROM deal_oom WHERE deal_id = d;
    RAISE EXCEPTION 'CHYBA: obchod v ponuke bez OOM';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  UPDATE deal SET stage_id = pg_temp.b_stage('b2b_dodavka', 'vyjednavanie') WHERE id = d;
  BEGIN
    UPDATE deal SET stage_id = pg_temp.b_stage('b2b_dodavka', 'akceptacia') WHERE id = d;
    RAISE EXCEPTION 'CHYBA: Akceptácia ručne';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    UPDATE deal SET stage_id = pg_temp.b_stage('b2b_dodavka', 'vyhrane') WHERE id = d;
    RAISE EXCEPTION 'CHYBA: Vyhraté ručne obchodníkom';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    UPDATE deal SET stage_id = pg_temp.b_stage('b2b_dodavka', 'prehrane') WHERE id = d;
    RAISE EXCEPTION 'CHYBA: prehra bez dôvodu';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    UPDATE deal SET stage_id = pg_temp.b_stage('b2b_dodavka', 'prehrane'), lost_reason_code = 'ine' WHERE id = d;
    RAISE EXCEPTION 'CHYBA: „iné“ bez poznámky';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  UPDATE deal SET stage_id = pg_temp.b_stage('b2b_dodavka', 'prehrane'), lost_reason_code = 'cena',
                  closed_at = '2020-01-01' WHERE id = d;   -- closed_at nastaví databáza, nie aplikácia
  ASSERT (SELECT closed_at > now() - interval '1 minute' FROM deal WHERE id = d), 'closed_at nastavila databáza';
  BEGIN
    UPDATE deal SET stage_id = pg_temp.b_stage('b2b_dodavka', 'prilezitost') WHERE id = d;
    RAISE EXCEPTION 'CHYBA: uzavretý obchod presunutý bez znovuotvorenia';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    PERFORM set_config('app.deal_reopen', d::text, true);   -- aplikácia si príznak nastaviť nevie
    UPDATE deal SET stage_id = pg_temp.b_stage('b2b_dodavka', 'prilezitost') WHERE id = d;
    RAISE EXCEPTION 'CHYBA: znovuotvorenie cez príznak relácie z aplikácie';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  PERFORM set_config('app.deal_reopen', '', true);
  BEGIN
    PERFORM deal_reopen(d, '  ');
    RAISE EXCEPTION 'CHYBA: znovuotvorenie bez dôvodu';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  PERFORM set_config('app.user_id', pg_temp.b_id('u', 3)::text, true);   -- riaditeľ: nie je vlastník ani admin
  BEGIN
    PERFORM deal_reopen(d, 'zákazník sa ozval');
    RAISE EXCEPTION 'CHYBA: prehratý obchod otvoril iný ako vlastník';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM set_config('app.user_id', pg_temp.b_id('u', 1)::text, true);
  PERFORM deal_reopen(d, 'zákazník sa ozval');
  ASSERT (SELECT (s.code, d2.closed_at, d2.lost_reason_code) FROM deal d2 JOIN pipeline_stage s ON s.id = d2.stage_id WHERE d2.id = d)
         = ROW('prilezitost'::deal_stage_code, NULL::timestamptz, NULL::text), 'znovuotvorený: Príležitosť, bez dôvodu prehry';
  ASSERT EXISTS (SELECT 1 FROM deal_event WHERE deal_id = d AND kind = 'znovuotvorenie' AND reason = 'zákazník sa ozval'),
         'znovuotvorenie s dôvodom v časovej osi';
  ASSERT (SELECT count(*) FROM deal_event WHERE deal_id = d AND kind = 'stadium') = 3, 'zmeny štádia v časovej osi';
  PERFORM set_config('app.user_id', '', true);
  PERFORM set_config('app.require_user', '', true);
  RAISE NOTICE 'OK: B1 štádiá: Príležitosť pri založení, OOM a objem od Cenovej ponuky, Akceptácia a Vyhraté iba systém, prehra s dôvodom, znovuotvorenie iba vlastník s dôvodom';
END;
$$;

RESET ROLE;
-- Vyhratý obchod (systém) znova otvorí iba admin
DO $$
DECLARE
  d uuid := pg_temp.b_id('d', 2);
BEGIN
  INSERT INTO deal (id, company_id, pipeline_id, stage_id, name, owner_id, source_code)
  VALUES (d, pg_temp.b_id('f', 1), pg_temp.b_pipe('b2b_dodavka'), pg_temp.b_stage('b2b_dodavka', 'vyhrane'),
          'Firma A vyhraté', pg_temp.b_id('u', 1), 'web');
  PERFORM set_config('app.user_id', pg_temp.b_id('u', 1)::text, true);
  BEGIN
    PERFORM deal_reopen(d, 'omyl');
    RAISE EXCEPTION 'CHYBA: vyhratý obchod otvoril obchodník';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM set_config('app.user_id', (SELECT id FROM app_user WHERE lower(email) = 'peter@greenlogy.com')::text, true);
  PERFORM deal_reopen(d, 'zmluva spárovaná omylom');
  ASSERT (SELECT closed_at FROM deal WHERE id = d) IS NULL, 'admin vyhraté otvoril';
  PERFORM set_config('app.user_id', '', true);
  RAISE NOTICE 'OK: B1 vyhratý obchod znova otvorí iba admin';
END;
$$;
SET LOCAL ROLE crm_rls_test;

-- ============================================================================
-- B2. Zákazník a vlastník
-- ============================================================================
DO $$
BEGIN
  PERFORM set_config('app.require_user', 'on', true);
  PERFORM set_config('app.user_id', pg_temp.b_id('u', 1)::text, true);
  BEGIN
    INSERT INTO deal (company_id, pipeline_id, stage_id, name, owner_id, source_code)
    VALUES (pg_temp.b_id('f', 2), pg_temp.b_pipe('b2b_dodavka'), pg_temp.b_stage('b2b_dodavka', 'prilezitost'),
            'Cudzia firma', pg_temp.b_id('u', 1), 'web');
    RAISE EXCEPTION 'CHYBA: obchod na firme iného obchodníka';
  EXCEPTION WHEN check_violation THEN
    ASSERT SQLERRM LIKE '%Predajca B%pridelenie%', 'hláška s menom vlastníka: ' || SQLERRM;
  END;
  BEGIN
    INSERT INTO deal (company_id, pipeline_id, stage_id, name, owner_id, source_code)
    VALUES (pg_temp.b_id('f', 1), pg_temp.b_pipe('b2b_dodavka'), pg_temp.b_stage('b2b_dodavka', 'prilezitost'),
            'Pre kolegu', pg_temp.b_id('u', 2), 'web');
    RAISE EXCEPTION 'CHYBA: obchodník založil obchod pre iného';
  EXCEPTION WHEN insufficient_privilege OR check_violation THEN NULL;
  END;
  BEGIN
    INSERT INTO deal (company_id, pipeline_id, stage_id, name, owner_id, source_code)
    VALUES (pg_temp.b_id('f', 1), pg_temp.b_pipe('b2c_dodavka'), pg_temp.b_stage('b2c_dodavka', 'prilezitost'),
            'Firma v B2C', pg_temp.b_id('u', 1), 'web');
    RAISE EXCEPTION 'CHYBA: firma v pipeline B2C';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    INSERT INTO deal (person_id, pipeline_id, stage_id, name, owner_id, source_code)
    VALUES (pg_temp.b_id('f', 4), pg_temp.b_pipe('b2b_dodavka'), pg_temp.b_stage('b2b_dodavka', 'prilezitost'),
            'Osoba v B2B', pg_temp.b_id('u', 1), 'web');
    RAISE EXCEPTION 'CHYBA: domácnosť v pipeline B2B';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  INSERT INTO deal (person_id, pipeline_id, stage_id, name, owner_id, source_code)
  VALUES (pg_temp.b_id('f', 4), pg_temp.b_pipe('b2c_dodavka'), pg_temp.b_stage('b2c_dodavka', 'prilezitost'),
          'Domácnosť FVE', pg_temp.b_id('u', 1), 'web');

  -- firma bez vlastníka → vlastníkom sa stane obchodník obchodu
  INSERT INTO deal (id, company_id, pipeline_id, stage_id, name, owner_id, source_code)
  VALUES (pg_temp.b_id('d', 3), pg_temp.b_id('f', 3), pg_temp.b_pipe('b2b_dodavka'),
          pg_temp.b_stage('b2b_dodavka', 'prilezitost'), 'Bez vlastníka', pg_temp.b_id('u', 1), 'web');
  ASSERT (SELECT owner_id FROM company WHERE id = pg_temp.b_id('f', 3)) = pg_temp.b_id('u', 1), 'vlastník z obchodu';
  ASSERT EXISTS (SELECT 1 FROM deal_event WHERE deal_id = pg_temp.b_id('d', 3) AND kind = 'zakaznik_vlastnik'), 'udalosť';

  -- vlastníka firmy priamo nezmení ani s príznakom relácie
  BEGIN
    PERFORM set_config('app.owner_assign', 'on', true);
    UPDATE company SET owner_id = pg_temp.b_id('u', 1) WHERE id = pg_temp.b_id('f', 1) AND owner_id IS NOT NULL;
    UPDATE company SET owner_id = pg_temp.b_id('u', 2) WHERE id = pg_temp.b_id('f', 1);
    RAISE EXCEPTION 'CHYBA: obchodník zmenil vlastníka firmy cez príznak relácie';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM set_config('app.owner_assign', '', true);

  BEGIN
    UPDATE deal SET owner_id = pg_temp.b_id('u', 2) WHERE id = pg_temp.b_id('d', 3);
    RAISE EXCEPTION 'CHYBA: obchodník zmenil vlastníka obchodu';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  -- obchodný riaditeľ (Sales_internal „všetko“) vlastníka obchodu zmení a obchod na cudzej firme založí
  PERFORM set_config('app.user_id', pg_temp.b_id('u', 3)::text, true);
  UPDATE deal SET owner_id = pg_temp.b_id('u', 6) WHERE id = pg_temp.b_id('d', 3);
  ASSERT EXISTS (SELECT 1 FROM deal_event WHERE deal_id = pg_temp.b_id('d', 3) AND kind = 'vlastnik'), 'udalosť vlastníka';
  INSERT INTO deal (company_id, pipeline_id, stage_id, name, owner_id, source_code)
  VALUES (pg_temp.b_id('f', 2), pg_temp.b_pipe('b2b_dodavka'), pg_temp.b_stage('b2b_dodavka', 'prilezitost'),
          'Riaditeľ pre A na firme B', pg_temp.b_id('u', 1), 'partner');
  PERFORM set_config('app.user_id', '', true);
  PERFORM set_config('app.require_user', '', true);
  RAISE NOTICE 'OK: B2 cudzí zákazník → pridelenie (hláška s menom), zákazník bez vlastníka → vlastník obchodu, B2C iba osoba, vlastníka obchodu mení iba vedenie / riaditeľ';
END;
$$;

-- ============================================================================
-- B3. OOM: jedno v jednom otvorenom obchode (výnimka Obnova), OOM z obchodu pri prehre
-- ============================================================================
RESET ROLE;
DO $$
BEGIN
  -- zmluva Firmy A s OOM 1 (Obnova k nej) a zmluva s OOM 6 (OOM na zmluve sa pri prehre nezruší)
  INSERT INTO contract (id, number, company_id, type, phase, valid_from, valid_to, signed_on, owner_id) VALUES
    (pg_temp.b_id('k', 1), 'B3-1', pg_temp.b_id('f', 1), 'dodavka_firma_nn', 'podpisana', '2026-01-01', '2026-12-31', '2025-11-01', pg_temp.b_id('u', 1)),
    (pg_temp.b_id('k', 2), 'B3-2', pg_temp.b_id('f', 1), 'dodavka_firma_nn', 'rozpracovana', '2027-01-01', '2027-12-31', NULL, pg_temp.b_id('u', 1));
  INSERT INTO contract_oom (contract_id, oom_id, qty_vt_mwh) VALUES (pg_temp.b_id('k', 1), pg_temp.b_id('oom', 1), 10);
  -- obchod Obnova (zakladá nočný beh = kód databázy)
  INSERT INTO deal (id, company_id, pipeline_id, stage_id, name, owner_id, source_code, previous_contract_id)
  VALUES (pg_temp.b_id('d', 10), pg_temp.b_id('f', 1), pg_temp.b_pipe('b2b_dodavka'), pg_temp.b_stage('b2b_dodavka', 'prilezitost'),
          'Obnova – B3-1', pg_temp.b_id('u', 1), 'obnova', pg_temp.b_id('k', 1));
  INSERT INTO deal_oom (deal_id, oom_id) VALUES (pg_temp.b_id('d', 10), pg_temp.b_id('oom', 1));   -- OOM 1 je aj v obchode 1
  BEGIN
    INSERT INTO deal (company_id, pipeline_id, stage_id, name, owner_id, source_code, previous_contract_id)
    VALUES (pg_temp.b_id('f', 1), pg_temp.b_pipe('b2b_dodavka'), pg_temp.b_stage('b2b_dodavka', 'prilezitost'),
            'Druhá obnova', pg_temp.b_id('u', 1), 'obnova', pg_temp.b_id('k', 1));
    RAISE EXCEPTION 'CHYBA: dve otvorené Obnovy k jednej zmluve';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;
END;
$$;
SET LOCAL ROLE crm_rls_test;
DO $$
DECLARE
  d4 uuid := pg_temp.b_id('d', 4);
  d5 uuid := pg_temp.b_id('d', 5);
BEGIN
  PERFORM set_config('app.require_user', 'on', true);
  PERFORM set_config('app.user_id', pg_temp.b_id('u', 1)::text, true);
  -- druhý bežný obchod dodávky s OOM 1 (je v obchode 1 a v Obnove) → chyba; výkup s tým istým OOM áno
  INSERT INTO deal (id, company_id, pipeline_id, stage_id, name, owner_id, source_code)
  VALUES (d4, pg_temp.b_id('f', 1), pg_temp.b_pipe('b2b_dodavka'), pg_temp.b_stage('b2b_dodavka', 'prilezitost'),
          'Firma A druhý', pg_temp.b_id('u', 1), 'web');
  BEGIN
    INSERT INTO deal_oom (deal_id, oom_id) VALUES (d4, pg_temp.b_id('oom', 1));
    RAISE EXCEPTION 'CHYBA: OOM v dvoch bežných otvorených obchodoch';
  EXCEPTION WHEN check_violation THEN
    ASSERT SQLERRM LIKE '%Predajca A%', 'hláška s vlastníkom: ' || SQLERRM;
  END;
  INSERT INTO deal (id, company_id, pipeline_id, stage_id, name, owner_id, source_code)
  VALUES (d5, pg_temp.b_id('f', 1), pg_temp.b_pipe('b2b_vykup'), pg_temp.b_stage('b2b_vykup', 'prilezitost'),
          'Firma A výkup', pg_temp.b_id('u', 1), 'web');
  INSERT INTO deal_oom (deal_id, oom_id) VALUES (d5, pg_temp.b_id('oom', 1));
  BEGIN
    UPDATE deal SET source_code = 'obnova' WHERE id = d4;
    RAISE EXCEPTION 'CHYBA: zdroj Obnova nastavil obchodník';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    INSERT INTO deal_oom (deal_id, oom_id) VALUES (d4, pg_temp.b_id('oom', 3));   -- OOM Firmy B nevidí
    RAISE EXCEPTION 'CHYBA: pridané cudzie OOM';
  EXCEPTION WHEN no_data_found OR foreign_key_violation THEN NULL;
  END;

  -- OOM založené pri obchode 4: 4 (iba tu → zruší sa), 5 (aj vo výkupe 5 → ostane), 6 (na zmluve → ostane)
  PERFORM pg_temp.b_oom(4, 1, 5, 4);
  PERFORM pg_temp.b_oom(5, 1, 5, 4);
  PERFORM pg_temp.b_oom(6, 1, 5, 4);
  INSERT INTO deal_oom (deal_id, oom_id) VALUES (d4, pg_temp.b_id('oom', 4)), (d4, pg_temp.b_id('oom', 5)), (d4, pg_temp.b_id('oom', 6)),
                                                (d5, pg_temp.b_id('oom', 5));
  BEGIN
    INSERT INTO oom (company_id, eic, type, status, created_from_deal_id)
    VALUES (pg_temp.b_id('f', 1), pg_temp.b_eic(7), 'spotreba', 'pripravovane', pg_temp.b_id('d', 3));   -- obchod inej firmy
    RAISE EXCEPTION 'CHYBA: OOM z obchodu iného zákazníka';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  PERFORM set_config('app.user_id', '', true);
  PERFORM set_config('app.require_user', '', true);
END;
$$;
RESET ROLE;
INSERT INTO contract_oom (contract_id, oom_id, qty_vt_mwh) VALUES (pg_temp.b_id('k', 2), pg_temp.b_id('oom', 6), 5);
SET LOCAL ROLE crm_rls_test;
DO $$
DECLARE
  d4 uuid := pg_temp.b_id('d', 4);
BEGIN
  PERFORM set_config('app.require_user', 'on', true);
  PERFORM set_config('app.user_id', pg_temp.b_id('u', 1)::text, true);
  UPDATE deal SET stage_id = pg_temp.b_stage('b2b_dodavka', 'prehrane'), lost_reason_code = 'nereaguje' WHERE id = d4;
  ASSERT (SELECT status FROM oom WHERE id = pg_temp.b_id('oom', 4)) = 'zrusene', 'OOM iba z prehratého obchodu → Zrušené';
  ASSERT (SELECT status FROM oom WHERE id = pg_temp.b_id('oom', 5)) = 'pripravovane', 'OOM v inom otvorenom obchode ostáva';
  ASSERT (SELECT status FROM oom WHERE id = pg_temp.b_id('oom', 6)) = 'pripravovane', 'OOM na zmluve ostáva';
  ASSERT (SELECT status FROM oom WHERE id = pg_temp.b_id('oom', 1)) = 'pripravovane', 'OOM nezaložené obchodom ostáva';
  ASSERT EXISTS (SELECT 1 FROM deal_event WHERE deal_id = d4 AND kind = 'oom_zrusene' AND oom_id = pg_temp.b_id('oom', 4)),
         'zrušenie OOM v časovej osi';
  BEGIN
    INSERT INTO deal_oom (deal_id, oom_id) VALUES (d4, pg_temp.b_id('oom', 2));
    RAISE EXCEPTION 'CHYBA: OOM pridané do uzavretého obchodu';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    INSERT INTO oom (company_id, eic, type, status, created_from_deal_id)
    VALUES (pg_temp.b_id('f', 1), pg_temp.b_eic(8), 'spotreba', 'pripravovane', d4);
    RAISE EXCEPTION 'CHYBA: OOM z uzavretého obchodu';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  PERFORM set_config('app.user_id', '', true);
  PERFORM set_config('app.require_user', '', true);
  RAISE NOTICE 'OK: B3 OOM najviac v jednom otvorenom obchode dodávky (výnimka Obnova, výkup zvlášť), jedna Obnova k zmluve, prehra zruší iba OOM z obchodu bez zmluvy a iného obchodu';
END;
$$;

-- ============================================================================
-- B4. Pridelenie firmy
-- ============================================================================
DO $$
DECLARE
  v_req uuid;
BEGIN
  PERFORM set_config('app.require_user', 'on', true);
  PERFORM set_config('app.user_id', pg_temp.b_id('u', 2)::text, true);
  BEGIN
    PERFORM approval_request_assign(pg_temp.b_id('f', 1), '');
    RAISE EXCEPTION 'CHYBA: žiadosť bez dôvodu';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  v_req := approval_request_assign(pg_temp.b_id('f', 1), 'zákazník ma oslovil sám');
  BEGIN
    PERFORM approval_request_assign(pg_temp.b_id('f', 1), 'znova');
    RAISE EXCEPTION 'CHYBA: druhá čakajúca žiadosť';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    PERFORM approval_request_assign(pg_temp.b_id('f', 2), 'vlastná');
    RAISE EXCEPTION 'CHYBA: žiadosť o vlastnú firmu';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  ASSERT EXISTS (SELECT 1 FROM approval_request WHERE id = v_req), 'žiadateľ vidí svoju žiadosť';
  BEGIN
    UPDATE approval_request SET status = 'schvalena' WHERE id = v_req;
    IF FOUND THEN
      RAISE EXCEPTION 'CHYBA: žiadateľ si žiadosť schválil zápisom';
    END IF;
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    PERFORM approval_decide(v_req, true, NULL);
    RAISE EXCEPTION 'CHYBA: obchodník schválil';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  PERFORM set_config('app.user_id', pg_temp.b_id('u', 1)::text, true);   -- pôvodný vlastník žiadosť vidí, schváliť nemôže
  ASSERT EXISTS (SELECT 1 FROM approval_request WHERE id = v_req), 'pôvodný vlastník vidí žiadosť';
  PERFORM set_config('app.user_id', pg_temp.b_id('u', 6)::text, true);
  ASSERT NOT EXISTS (SELECT 1 FROM approval_request WHERE id = v_req), 'iný obchodník žiadosť nevidí';

  PERFORM set_config('app.user_id', pg_temp.b_id('u', 4)::text, true);
  ASSERT EXISTS (SELECT 1 FROM notification WHERE approval_id = v_req AND kind = 'schvalenie_nove'), 'schvaľovateľ dostal upozornenie';
  BEGIN
    PERFORM approval_decide(v_req, false, '');
    RAISE EXCEPTION 'CHYBA: zamietnutie bez poznámky';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  PERFORM approval_decide(v_req, true, 'v poriadku');
  PERFORM set_config('app.user_id', '', true);
  PERFORM set_config('app.require_user', '', true);
END;
$$;
RESET ROLE;
DO $$
BEGIN
  ASSERT (SELECT owner_id FROM company WHERE id = pg_temp.b_id('f', 1)) = pg_temp.b_id('u', 2), 'firma pridelená žiadateľovi';
  ASSERT EXISTS (SELECT 1 FROM notification WHERE user_id = pg_temp.b_id('u', 2) AND kind = 'schvalenie_rozhodnutie'), 'žiadateľ upozornený';
  ASSERT EXISTS (SELECT 1 FROM notification WHERE user_id = pg_temp.b_id('u', 1) AND kind = 'pridelenie_firmy'), 'pôvodný vlastník upozornený';
  ASSERT (SELECT status FROM approval_request WHERE company_id = pg_temp.b_id('f', 1)) = 'schvalena', 'žiadosť schválená';
  ASSERT EXISTS (SELECT 1 FROM audit_log WHERE table_name = 'company' AND record_id = pg_temp.b_id('f', 1)
                   AND diff ? 'owner_id'), 'zmena vlastníka v audite';
  -- vlastnú žiadosť schvaľovateľ neschváli
  PERFORM set_config('app.user_id', pg_temp.b_id('u', 4)::text, true);
  INSERT INTO approval_request (org_id, kind, company_id, from_owner_id, reason, requested_by)
  VALUES (crm_default_org(), 'pridelenie_firmy', pg_temp.b_id('f', 2), pg_temp.b_id('u', 2), 'test', pg_temp.b_id('u', 4));
  BEGIN
    PERFORM approval_decide((SELECT id FROM approval_request WHERE requested_by = pg_temp.b_id('u', 4)), true, NULL);
    RAISE EXCEPTION 'CHYBA: vlastná žiadosť schválená';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM set_config('app.user_id', '', true);
  RAISE NOTICE 'OK: B4 pridelenie firmy: žiadosť s dôvodom, schvaľuje iba príznak „schvaľuje pridelenie firmy“ (nie vlastnú), vlastník sa zmení, žiadateľ a pôvodný vlastník upozornení, audit';
END;
$$;

-- ============================================================================
-- B5. RLS „iba svoje“: vlastné obchody a obchody na vlastných zákazníkoch
-- ============================================================================
-- obchod predajcu B na firme A2, ktorú vlastní predajca A (založí riaditeľ)
INSERT INTO deal (id, company_id, pipeline_id, stage_id, name, owner_id, source_code)
VALUES (pg_temp.b_id('d', 20), pg_temp.b_id('f', 5), pg_temp.b_pipe('b2b_dodavka'), pg_temp.b_stage('b2b_dodavka', 'prilezitost'),
        'B na firme A2', pg_temp.b_id('u', 2), 'web');
SET LOCAL ROLE crm_rls_test;
DO $$
DECLARE
  x uuid := pg_temp.b_id('d', 20);
  n integer;
BEGIN
  PERFORM set_config('app.require_user', 'on', true);
  PERFORM set_config('app.user_id', pg_temp.b_id('u', 1)::text, true);
  ASSERT EXISTS (SELECT 1 FROM deal WHERE id = x), 'A vidí obchod na svojej firme';
  ASSERT EXISTS (SELECT 1 FROM deal_event WHERE deal_id = x), 'aj jeho časovú os';
  ASSERT EXISTS (SELECT 1 FROM deal WHERE id = pg_temp.b_id('d', 3)), 'A vidí obchod predajcu C na firme, ktorú vlastní';
  PERFORM set_config('app.user_id', pg_temp.b_id('u', 2)::text, true);
  ASSERT EXISTS (SELECT 1 FROM deal WHERE id = x), 'B vidí svoj obchod';
  PERFORM set_config('app.user_id', pg_temp.b_id('u', 6)::text, true);
  ASSERT NOT EXISTS (SELECT 1 FROM deal WHERE id = x), 'C cudzí obchod nevidí';
  ASSERT NOT EXISTS (SELECT 1 FROM deal_oom WHERE deal_id = pg_temp.b_id('d', 1)), 'ani jeho OOM';
  ASSERT NOT EXISTS (SELECT 1 FROM deal_event WHERE deal_id = x), 'ani časovú os';
  UPDATE deal SET name = 'prepísané' WHERE id = x;
  GET DIAGNOSTICS n = ROW_COUNT;
  ASSERT n = 0, 'C cudzí obchod nezmení';
  BEGIN
    INSERT INTO deal (company_id, pipeline_id, stage_id, name, owner_id, source_code)
    VALUES (pg_temp.b_id('f', 5), pg_temp.b_pipe('b2b_dodavka'), pg_temp.b_stage('b2b_dodavka', 'prilezitost'),
            'C na firme A2', pg_temp.b_id('u', 6), 'web');
    RAISE EXCEPTION 'CHYBA: C založil obchod na cudzej firme';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  PERFORM set_config('app.user_id', pg_temp.b_id('u', 5)::text, true);   -- Servis: vidí všetko, nemení
  ASSERT EXISTS (SELECT 1 FROM deal WHERE id = x), 'Servis vidí';
  UPDATE deal SET name = 'servis' WHERE id = x;
  GET DIAGNOSTICS n = ROW_COUNT;
  ASSERT n = 0, 'Servis obchod nezmení';
  PERFORM set_config('app.user_id', pg_temp.b_id('u', 3)::text, true);   -- riaditeľ (Sales_internal „všetko“)
  SELECT count(*) INTO n FROM deal WHERE id::text LIKE '00000000-0000-4000-8000-0000000093%';
  ASSERT n = 7, format('riaditeľ vidí všetky testovacie obchody s pevným id (%s)', n);
  PERFORM set_config('app.user_id', pg_temp.b_id('u', 4)::text, true);   -- schvaľovateľ pridelenia (Marketing) vidí všetko
  ASSERT EXISTS (SELECT 1 FROM deal WHERE id = x), 'schvaľovateľ vidí';
  PERFORM set_config('app.user_id', '', true);
  ASSERT NOT EXISTS (SELECT 1 FROM deal), 'bez používateľa nič';
  PERFORM set_config('app.require_user', '', true);
  RAISE NOTICE 'OK: B5 RLS: predajca vidí vlastné obchody a obchody na svojich zákazníkoch (aj OOM a časovú os), cudzie nie; Servis číta; riaditeľ a schvaľovateľ všetko; bez používateľa nič';
END;
$$;
RESET ROLE;

-- ============================================================================
-- B7. Nočný beh: upozornenie v deň ďalšieho kroku, raz; nový dátum = znova
-- ============================================================================
DO $$
DECLARE
  x uuid := pg_temp.b_id('d', 20);
BEGIN
  UPDATE deal SET next_step = 'Zavolať', next_step_on = '2027-03-01' WHERE id = x;
  PERFORM deal_daily_run_at('2027-02-28');
  ASSERT NOT EXISTS (SELECT 1 FROM notification WHERE deal_id = x AND kind = 'dalsi_krok'), 'deň pred krokom nič';
  PERFORM deal_daily_run_at('2027-03-01');
  PERFORM deal_daily_run_at('2027-03-01');
  ASSERT (SELECT count(*) FROM notification WHERE deal_id = x AND kind = 'dalsi_krok' AND user_id = pg_temp.b_id('u', 2)) = 1,
         'upozornenie vlastníkovi raz';
  -- používateľ posunie krok → príznak sa vynuluje, v nový deň znova
  SET LOCAL ROLE crm_rls_test;
  PERFORM set_config('app.require_user', 'on', true);
  PERFORM set_config('app.user_id', pg_temp.b_id('u', 2)::text, true);
  UPDATE deal SET next_step_on = '2027-03-05', next_step_notified_on = '2027-03-05' WHERE id = x;
  PERFORM set_config('app.user_id', '', true);
  PERFORM set_config('app.require_user', '', true);
  RESET ROLE;
  ASSERT (SELECT next_step_notified_on FROM deal WHERE id = x) IS NULL, 'príznak upozornenia nastavuje iba nočný beh';
  PERFORM deal_daily_run_at('2027-03-05');
  ASSERT (SELECT count(*) FROM notification WHERE deal_id = x AND kind = 'dalsi_krok') = 2, 'nový dátum = nové upozornenie';
  ASSERT EXISTS (SELECT 1 FROM job_run WHERE job = 'obchody' AND run_date = '2027-03-05'), 'záznam behu';
  RAISE NOTICE 'OK: B7 nočný beh: ďalší krok v daný deň raz, po zmene dátumu znova; príznak mení iba beh';
END;
$$;

-- ============================================================================
-- B6. Finstat (0033): výstrahy, overenie firmy, cache 24 h, denný limit
-- ============================================================================
DO $$
DECLARE
  r jsonb;
BEGIN
  -- údaje Finstatu zapíše ten, kto firmu vidí; mení iba stĺpce Finstatu
  PERFORM set_config('app.user_id', pg_temp.b_id('u', 2)::text, true);
  PERFORM company_apply_finstat(pg_temp.b_id('f', 2), jsonb_build_object(
    'revenue_eur', 1250000, 'profit_eur', -15000, 'finance_year', 2025, 'employees_range', '25-49',
    'z_score', 0.84, 'payment_rating', 'X', 'insolvency_kind', 'konkurz', 'insolvency_since', '2026-09-01',
    'debts', '[{"veritel": "Sociálna poisťovňa", "suma_eur": 1240}]'::jsonb, 'has_debts', true));
  PERFORM set_config('app.user_id', '', true);
  r := company_risk(pg_temp.b_id('f', 2));
  ASSERT r->'warnings' = '["dlhy", "konkurz", "rating_x", "z_skore"]'::jsonb, 'výstrahy: ' || r::text;
  ASSERT (r->>'needs_approval')::boolean, 'konkurz / X → schválenie';
  ASSERT r->>'z_band' = 'riziko', 'pásmo Z-skóre';
  ASSERT EXISTS (SELECT 1 FROM audit_log WHERE table_name = 'company' AND record_id = pg_temp.b_id('f', 2)
                   AND source = 'synchronizacia' AND diff ? 'z_score'), 'audit zápisu Finstatu';

  UPDATE company SET z_score = 1.5, payment_rating = 'C', insolvency_kind = NULL, has_debts = true, debts = '[]'
   WHERE id = pg_temp.b_id('f', 2);
  r := company_risk(pg_temp.b_id('f', 2));
  ASSERT r->'warnings' = '["dlhy"]'::jsonb AND NOT (r->>'needs_approval')::boolean AND r->>'z_band' = 'seda_zona',
         'iba dlhy: výstraha bez schválenia, šedá zóna: ' || r::text;
  UPDATE company SET z_score = 2.95, has_debts = false, payment_rating = 'E' WHERE id = pg_temp.b_id('f', 2);
  r := company_risk(pg_temp.b_id('f', 2));
  ASSERT r->'warnings' = '["rating_e"]'::jsonb AND (r->>'needs_approval')::boolean AND r->>'z_band' = 'stabilna', 'E → schválenie';

  BEGIN
    PERFORM set_config('app.user_id', pg_temp.b_id('u', 6)::text, true);
    PERFORM company_apply_finstat(pg_temp.b_id('f', 2), '{"z_score": 3}');
    RAISE EXCEPTION 'CHYBA: Finstat zapísaný na firmu, ktorú používateľ nevidí';
  EXCEPTION WHEN no_data_found THEN NULL;
  END;
  PERFORM set_config('app.user_id', '', true);
  RAISE NOTICE 'OK: B6 výstrahy Finstatu (dlhy, konkurz, E/X, Z-skóre a pásma), schválenie iba konkurz a E/X, zápis iba pre toho, kto firmu vidí, audit';
END;
$$;

SET LOCAL ROLE crm_rls_test;
DO $$
DECLARE
  r jsonb;
  i integer;
BEGIN
  PERFORM set_config('app.require_user', 'on', true);
  -- predajca C firmu B nevidí: dostane názov, vlastníka a vlastníkov otvorených obchodov, nie id ani zmluvy
  PERFORM set_config('app.user_id', pg_temp.b_id('u', 6)::text, true);
  r := company_check('99999982');
  ASSERT (r->>'exists')::boolean AND NOT (r->>'visible')::boolean, 'existuje, nevidí: ' || r::text;
  ASSERT r->>'owner_name' = 'Predajca B' AND NOT r ? 'company_id' AND NOT r ? 'contracts', 'iba vlastník bez detailu';
  ASSERT jsonb_array_length(r->'open_deals') >= 1 AND NOT (r->'open_deals'->0) ? 'name', 'otvorené obchody iba s vlastníkom';
  ASSERT NOT (company_check('12345670')->>'exists')::boolean, 'neznáme IČO';
  ASSERT (company_check('9999 9982')->>'exists')::boolean, 'IČO s medzerou';
  -- vlastník vidí všetko
  PERFORM set_config('app.user_id', pg_temp.b_id('u', 2)::text, true);
  r := company_check('99999982');
  ASSERT (r->>'visible')::boolean AND r->>'company_id' = pg_temp.b_id('f', 2)::text AND (r->>'owner_is_me')::boolean, 'vlastník';
  ASSERT r ? 'contracts' AND r ? 'risk', 'zmluvy a výstrahy';

  -- cache 24 h a denný limit (limit v teste 3)
  ASSERT finstat_cache_get('detail', '99999982') IS NULL, 'prázdna cache';
  PERFORM finstat_cache_put('detail', '99999982', '{"Name": "Firma B"}');
  ASSERT finstat_cache_get('detail', '99999982')->>'Name' = 'Firma B', 'z cache';
  PERFORM set_config('app.user_id', '', true);
  PERFORM set_config('app.require_user', '', true);
END;
$$;
RESET ROLE;
DO $$
DECLARE
  i integer;
  n integer := 0;
BEGIN
  UPDATE finstat_cache SET fetched_at = now() - interval '25 hours' WHERE kind = 'detail' AND key = '99999982';
  PERFORM set_config('app.user_id', pg_temp.b_id('u', 2)::text, true);
  ASSERT finstat_cache_get('detail', '99999982') IS NULL, 'po 24 h neplatná';
  INSERT INTO finstat_cache (kind, key, data, fetched_at) VALUES ('autocomplete', 'stara', '{}', now() - interval '8 days');
  PERFORM finstat_cache_put('autocomplete', 'alfa', '[]');
  ASSERT NOT EXISTS (SELECT 1 FROM finstat_cache WHERE key = 'stara'), 'staršie ako 7 dní zmazané';

  UPDATE app_setting SET value = '3' WHERE key = 'finstat_daily_limit';
  DELETE FROM finstat_usage WHERE day = crm_today();
  FOR i IN 1..5 LOOP
    IF finstat_request_allow() THEN n := n + 1; END IF;
  END LOOP;
  ASSERT n = 3, format('limit 3, povolených %s', n);
  PERFORM set_config('app.user_id', '', true);
  RAISE NOTICE 'OK: B6 overenie firmy: kto firmu nevidí, dostane iba vlastníka a vlastníkov obchodov; cache 24 h, mazanie po 7 dňoch, denný limit';
END;
$$;

-- ============================================================================
-- B8. 0034: žiadosť o pridelenie podľa IČO (firmu iného obchodníka žiadateľ nevidí), id firmy bez vlastníka
-- ============================================================================
INSERT INTO company (id, name, ico, is_customer, owner_id) VALUES
  ('00000000-0000-4000-8000-000000009106', 'Bez vlastníka B8 s.r.o.', '99999986', true, NULL);
SET LOCAL ROLE crm_rls_test;
DO $$
DECLARE
  r     jsonb;
  v_req uuid;
BEGIN
  PERFORM set_config('app.require_user', 'on', true);
  PERFORM set_config('app.user_id', pg_temp.b_id('u', 6)::text, true);   -- predajca C: firmu A2 (vlastník A) nevidí
  ASSERT NOT EXISTS (SELECT 1 FROM company WHERE id = pg_temp.b_id('f', 5)), 'C firmu A2 nevidí';
  ASSERT NOT (company_check('99999985') ? 'company_id'), 'id cudzej firmy ostáva skryté';
  v_req := approval_request_assign_ico('9999 9985', 'chcem ju obsluhovať');
  ASSERT EXISTS (SELECT 1 FROM approval_request WHERE id = v_req AND company_id = pg_temp.b_id('f', 5)
                   AND from_owner_id = pg_temp.b_id('u', 1)), 'žiadosť podľa IČO';
  BEGIN
    PERFORM approval_request_assign_ico('12345670', 'x');
    RAISE EXCEPTION 'CHYBA: žiadosť o neznáme IČO';
  EXCEPTION WHEN no_data_found THEN NULL;
  END;
  -- firma bez vlastníka: id sa vráti, obchod na nej založí a stane sa vlastníkom
  r := company_check('99999986');
  ASSERT r->>'company_id' = pg_temp.b_id('f', 6)::text AND NOT (r->>'visible')::boolean, 'id firmy bez vlastníka: ' || r::text;
  INSERT INTO deal (company_id, pipeline_id, stage_id, name, owner_id, source_code)
  VALUES (pg_temp.b_id('f', 6), pg_temp.b_pipe('b2b_dodavka'), pg_temp.b_stage('b2b_dodavka', 'prilezitost'),
          'C na firme bez vlastníka', pg_temp.b_id('u', 6), 'web');
  ASSERT (company_check('99999986')->>'owner_is_me')::boolean, 'C je vlastník';
  PERFORM set_config('app.user_id', '', true);
  PERFORM set_config('app.require_user', '', true);
  -- zápis Finstatu bez platobného ratingu ho na firme nezmaže (Finstat rating neposiela)
  PERFORM set_config('app.user_id', pg_temp.b_id('u', 2)::text, true);
  UPDATE company SET payment_rating = 'B' WHERE id = pg_temp.b_id('f', 2);
  PERFORM company_apply_finstat(pg_temp.b_id('f', 2), '{"z_score": 2.5}');
  ASSERT (SELECT payment_rating FROM company WHERE id = pg_temp.b_id('f', 2)) = 'B', 'rating ostal';
  PERFORM company_apply_finstat(pg_temp.b_id('f', 2), '{"payment_rating": "C"}');
  ASSERT (SELECT payment_rating FROM company WHERE id = pg_temp.b_id('f', 2)) = 'C', 'rating z údajov sa zapíše';
  RAISE NOTICE 'OK: B8 žiadosť o pridelenie podľa IČO bez prístupu k firme; firma bez vlastníka sa dá v overení vybrať a obchodom získať; Finstat nezmaže platobný rating';
END;
$$;
RESET ROLE;
