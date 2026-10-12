-- Kontroly modulu Nastavenia (migrácie 0006–0008) nad dátami zo seed.sql a checks_zakaznici.sql + vlastnými.
-- Všetko je vymyslené. Pevné uuid s prefixom 00000000-0000-4000-8000-00000002….
-- Spúšťa sa iba cez db/test/run.sh, po checks_zakaznici.sql (používa jeho rolu crm_rls_test
-- a odomknutý externý tím); transakcia sa na konci vráti.

-- N1. Východiskové údaje
DO $$
BEGIN
  ASSERT (SELECT legal_name || '/' || country || '/' || currency || '/' || status FROM org WHERE is_default)
       = 'Greenlogy a.s./SK/EUR/aktivna', 'predvolená spoločnosť';
  ASSERT (SELECT count(*) FROM org) = 3, '3 spoločnosti (SK aktívna, CZ a HR pripravované)';
  ASSERT (SELECT array_agg(code ORDER BY code) FROM team)
       = '{ceo,marketing,nakup,sales_external,sales_internal,servis}', 'tímy';
  ASSERT (SELECT array_agg(code ORDER BY code) FROM team WHERE all_orgs) = '{ceo,marketing,nakup}', 'všetky spoločnosti';
  ASSERT (SELECT count(*) FROM team_permission) = 42, '6 tímov × 7 modulov';
  ASSERT NOT EXISTS (SELECT 1 FROM team_permission p JOIN team t ON t.id = p.team_id
                      WHERE t.code = 'ceo' AND NOT (p.view_scope = 'vsetko' AND p.edit_scope = 'vsetko'
                                                    AND p.can_archive AND p.can_export)), 'CEO má všetko';
  ASSERT (SELECT view_scope || '/' || edit_scope FROM team_permission p JOIN team t ON t.id = p.team_id
           WHERE t.code = 'sales_external' AND p.module = 'zakaznici') = 'iba_svoje/iba_svoje', 'Sales_external Zákazníci';
  ASSERT NOT EXISTS (SELECT 1 FROM team_permission p JOIN team t ON t.id = p.team_id
                      WHERE t.is_external AND 'vsetko' IN (p.view_scope, p.edit_scope)), 'externý bez „všetko“';
  ASSERT (SELECT edit_scope FROM team_permission p JOIN team t ON t.id = p.team_id
           WHERE t.code = 'nakup' AND p.module = 'zmluvy') = 'vsetko', 'Nákup upravuje zmluvy a ceny';
  ASSERT (SELECT string_agg(t.code || '=' || p.view_scope, ',' ORDER BY t.code)
            FROM team_permission p JOIN team t ON t.id = p.team_id WHERE p.module = 'provizie')
       = 'ceo=vsetko,marketing=nic,nakup=nic,sales_external=iba_svoje,sales_internal=iba_svoje,servis=nic',
         'Provízie: CEO všetko, obchodníci iba svoje, ostatní nič';
  ASSERT (SELECT count(*) FROM team_permission p JOIN team t ON t.id = p.team_id
           WHERE t.code <> 'ceo' AND (p.can_archive OR p.can_export)) = 0, 'archivovať a exportovať iba CEO';
  ASSERT (SELECT t.code || '/' || u.is_admin || '/' || u.status FROM app_user u JOIN team t ON t.id = u.team_id
           WHERE lower(u.email) = 'peter@greenlogy.com') = 'ceo/true/aktivny', 'Peter: CEO, admin, aktívny';
  ASSERT (SELECT t.code || '/' || u.is_admin || '/' || u.status FROM app_user u JOIN team t ON t.id = u.team_id
           WHERE lower(u.email) = 'eva@greenlogy.com') = 'marketing/true/aktivny', 'Eva: Marketing, admin, aktívna';
  ASSERT (SELECT array_agg(o.code) FROM app_user_org uo JOIN app_user u ON u.id = uo.user_id JOIN org o ON o.id = uo.org_id
           WHERE lower(u.email) = 'eva@greenlogy.com') = '{greenlogy_sk}', 'Eva: Greenlogy a.s.';
  ASSERT (SELECT count(*) FROM org_work_hours
           WHERE org_id = crm_default_org() AND work_from = '07:30' AND work_to = '15:30') = 5, 'Po–Pi 7:30–15:30';
  ASSERT (SELECT count(*) FROM business_calendar WHERE org_id = crm_default_org()) = 1096, 'kalendár SK 2026–2028';
  ASSERT (SELECT count(*) FROM lookup_value WHERE list_code = 'rola_kontaktu' AND is_system) = 3, '3 systémové roly';
  RAISE NOTICE 'OK: východiskové údaje: Greenlogy a.s., 6 tímov s právami, admini Peter a Eva, pracovný čas, roly kontaktu';
END;
$$;

-- N2. Práva tímu: poistka externého tímu, upravovať najviac toľko ako vidieť, nový tím
DO $$
DECLARE
  v_team uuid;
BEGIN
  BEGIN
    UPDATE team_permission SET view_scope = 'vsetko'
     WHERE module = 'zakaznici' AND team_id = (SELECT id FROM team WHERE code = 'sales_external');
    RAISE EXCEPTION 'CHYBA: externý tím dostal „všetko“';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK: externý tím nedostane „všetko“ (poistka)';
  END;
  BEGIN
    UPDATE team SET is_external = true WHERE code = 'servis';
    RAISE EXCEPTION 'CHYBA: tím s „všetko“ sa stal externým';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK: tím s právom „všetko“ nemôže byť externý';
  END;
  BEGIN
    UPDATE team_permission SET edit_scope = 'vsetko', view_scope = 'iba_svoje'
     WHERE module = 'servis' AND team_id = (SELECT id FROM team WHERE code = 'servis');
    RAISE EXCEPTION 'CHYBA: upravovať viac ako vidieť prešlo';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK: upravovať nemožno viac, ako tím vidí';
  END;
  INSERT INTO team (name, code) VALUES ('Dodávatelia', 'dodavatelia') RETURNING id INTO v_team;
  ASSERT (SELECT count(*) FILTER (WHERE view_scope = 'nic' AND edit_scope = 'nic') FROM team_permission
           WHERE team_id = v_team) = 7, 'nový tím má 7 modulov s „nič“';
  RAISE NOTICE 'OK: nový tím dostane všetky moduly s právom „nič“';
END;
$$;

-- N3. Používatelia: externý nie je admin, externý tím zamknutý, posledný admin, prihlásenie
INSERT INTO app_user (id, email, name, team_id, status)
SELECT '00000000-0000-4000-8000-000000002001', 'servis@example.test', 'Testovací Servis', t.id, 'aktivny'
  FROM team t WHERE t.code = 'servis';
INSERT INTO app_user (id, email, name, team_id)        -- pozvaný
SELECT '00000000-0000-4000-8000-000000002002', 'Novy.Obchodnik@Example.test', 'Nový Obchodník', t.id
  FROM team t WHERE t.code = 'sales_internal';
INSERT INTO app_user_org (user_id, org_id) VALUES
  ('00000000-0000-4000-8000-000000002001', crm_default_org()),
  ('00000000-0000-4000-8000-000000002002', crm_default_org());

DO $$
DECLARE
  r record;
  n bigint;
BEGIN
  BEGIN
    INSERT INTO app_user (email, name, team_id, is_admin)
    SELECT 'ext.admin@example.test', 'Externý Admin', id, true FROM team WHERE code = 'sales_external';
    RAISE EXCEPTION 'CHYBA: externý admin prešiel';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK: člen externého tímu nemôže byť admin';
  END;

  -- externý tím je bez odomknutia zamknutý (OOM, dealy… ešte nemajú RLS)
  CREATE OR REPLACE FUNCTION crm_external_ready() RETURNS boolean LANGUAGE sql IMMUTABLE AS $f$ SELECT false $f$;
  BEGIN
    UPDATE app_user SET team_id = (SELECT id FROM team WHERE code = 'sales_external')
     WHERE id = '00000000-0000-4000-8000-000000002002';
    RAISE EXCEPTION 'CHYBA: priradenie do externého tímu pred odomknutím prešlo';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK: do externého tímu nemožno priradiť, kým nie sú hotové politiky ďalších modulov';
  END;
  CREATE OR REPLACE FUNCTION crm_external_ready() RETURNS boolean LANGUAGE sql IMMUTABLE AS $f$ SELECT true $f$;

  BEGIN
    UPDATE app_user SET is_admin = false WHERE is_admin;   -- Peter aj Eva naraz
    RAISE EXCEPTION 'CHYBA: posledný admin zrušený';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK: CRM má vždy aspoň jedného aktívneho admina';
  END;

  -- prihlásenie: pozvaný → aktívny, e-mail bez ohľadu na veľkosť písmen
  SELECT * INTO r FROM app_user_login(' novy.obchodnik@example.TEST ');
  ASSERT r.user_id = '00000000-0000-4000-8000-000000002002' AND r.status = 'aktivny', 'prvé prihlásenie';
  SELECT count(*) INTO n FROM audit_log WHERE record_id = '00000000-0000-4000-8000-000000002002';
  PERFORM app_user_login('novy.obchodnik@example.test');
  ASSERT (SELECT count(*) FROM audit_log WHERE record_id = '00000000-0000-4000-8000-000000002002') = n,
         'ďalšie prihlásenie (iba last_login_at) nemá ísť do auditu';
  ASSERT NOT EXISTS (SELECT 1 FROM app_user_login('nikto@example.test')), 'neznámy e-mail';
  RAISE NOTICE 'OK: prihlásenie: pozvaný sa stane aktívnym, čas prihlásenia mimo auditu, neznámy e-mail nič';
END;
$$;

-- N4. Deaktivácia s odovzdaním (príklad 6)
INSERT INTO company (id, name, ico, owner_id) VALUES
  ('00000000-0000-4000-8000-000000002101', 'Odovzdávaná s.r.o.', '66666601', '00000000-0000-4000-8000-000000002002');
INSERT INTO contact (id, first_name, last_name, email, is_household, owner_id) VALUES
  ('00000000-0000-4000-8000-000000002102', 'Odovzdaná', 'Domácnosť', 'odovzdana@example.test', true,
   '00000000-0000-4000-8000-000000002002');
INSERT INTO deal (id, company_id, pipeline_id, stage_id, name, owner_id) VALUES
  ('00000000-0000-4000-8000-000000002103', '00000000-0000-4000-8000-000000002101',
   '00000000-0000-4000-8000-000000000501', '00000000-0000-4000-8000-000000000511', 'Otvorený deal',
   '00000000-0000-4000-8000-000000002002'),
  ('00000000-0000-4000-8000-000000002104', '00000000-0000-4000-8000-000000002101',
   '00000000-0000-4000-8000-000000000501', '00000000-0000-4000-8000-000000000512', 'Vyhraný deal',
   '00000000-0000-4000-8000-000000002002');

DO $$
DECLARE
  r record;
  v_peter uuid := (SELECT id FROM app_user WHERE lower(email) = 'peter@greenlogy.com');
BEGIN
  BEGIN
    UPDATE app_user SET status = 'deaktivovany', deactivated_at = now()
     WHERE id = '00000000-0000-4000-8000-000000002002';
    RAISE EXCEPTION 'CHYBA: deaktivácia bez odovzdania prešla';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK: priama deaktivácia vlastníka zákazníkov odmietnutá';
  END;

  -- neadmin deaktivovať nesmie
  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-000000002001', true);
  BEGIN
    PERFORM app_user_deactivate('00000000-0000-4000-8000-000000002002', '00000000-0000-4000-8000-000000000011');
    RAISE EXCEPTION 'CHYBA: neadmin deaktivoval';
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'OK: deaktivovať môže iba admin';
  END;

  PERFORM set_config('app.user_id', v_peter::text, true);
  BEGIN
    PERFORM app_user_deactivate('00000000-0000-4000-8000-000000002002', NULL);
    RAISE EXCEPTION 'CHYBA: deaktivácia bez nového vlastníka prešla';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK: bez nového vlastníka sa deaktivácia nedokončí';
  END;
  SELECT * INTO r FROM app_user_deactivate('00000000-0000-4000-8000-000000002002', '00000000-0000-4000-8000-000000000011');
  ASSERT (r.companies, r.contacts, r.open_deals) = (1, 1, 1), format('počty odovzdania %s', r);
  ASSERT (SELECT owner_id FROM company WHERE id = '00000000-0000-4000-8000-000000002101')
       = '00000000-0000-4000-8000-000000000011', 'firma odovzdaná';
  ASSERT (SELECT owner_id FROM deal WHERE id = '00000000-0000-4000-8000-000000002103')
       = '00000000-0000-4000-8000-000000000011', 'otvorený deal odovzdaný';
  ASSERT (SELECT owner_id FROM deal WHERE id = '00000000-0000-4000-8000-000000002104')
       = '00000000-0000-4000-8000-000000002002', 'uzavretý deal ostáva pôvodnému obchodníkovi';
  ASSERT (SELECT status FROM app_user WHERE id = '00000000-0000-4000-8000-000000002002') = 'deaktivovany', 'stav';
  ASSERT (SELECT user_id IS NULL AND status = 'deaktivovany' FROM app_user_login('novy.obchodnik@example.test')),
         'deaktivovaný sa neprihlási';
  PERFORM set_config('app.user_id', '', true);
  RAISE NOTICE 'OK: deaktivácia odovzdá firmy, osoby a otvorené dealy; deaktivovaný sa neprihlási';
END;
$$;

-- N5. Krajina a identifikátor firmy, spoločnosť na záznamoch
DO $$
DECLARE
  v_cz  uuid := (SELECT id FROM org WHERE code = 'greenlogy_cz');
  r     record;
BEGIN
  INSERT INTO company (id, name, ico, country) VALUES
    ('00000000-0000-4000-8000-000000002201', 'Hrvatska d.o.o.', '12345678901', 'HR'),
    ('00000000-0000-4000-8000-000000002202', 'Česká s.r.o.', '00123456', 'CZ');   -- rovnaké číslo ako Alfa (SK)
  BEGIN
    INSERT INTO company (name, ico, country) VALUES ('Krátky OIB', '12345678', 'HR');
    RAISE EXCEPTION 'CHYBA: OIB s 8 číslicami prešiel';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK: HR OIB musí mať 11 číslic';
  END;
  BEGIN
    INSERT INTO company (name, ico, country) VALUES ('Dlhé IČO', '12345678901', 'SK');
    RAISE EXCEPTION 'CHYBA: SK IČO s 11 číslicami prešlo';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK: SK IČO musí mať 8 číslic';
  END;
  BEGIN
    INSERT INTO company (name, ico, country) VALUES ('Duplicita CZ', '00123456', 'CZ');
    RAISE EXCEPTION 'CHYBA: duplicitné CZ IČO prešlo';
  EXCEPTION WHEN unique_violation THEN
    RAISE NOTICE 'OK: krajina + identifikátor je unikátny (rovnaké číslo v SK a CZ je dovolené)';
  END;
  ASSERT (SELECT country FROM company WHERE id = '00000000-0000-4000-8000-000000000101') = 'SK', 'predvolená krajina SK';
  INSERT INTO company (id, name, ico, org_id) VALUES
    ('00000000-0000-4000-8000-000000002203', 'Firma českej spoločnosti', '77777701', v_cz);
  ASSERT (SELECT country FROM company WHERE id = '00000000-0000-4000-8000-000000002203') = 'CZ',
         'krajina podľa spoločnosti';
  SELECT * INTO r FROM company_ico_check('HR', '123 456 789 01');
  ASSERT r.company_id = '00000000-0000-4000-8000-000000002201', 'hľadanie OIB';
  SELECT * INTO r FROM company_ico_check('CZ', '123456');
  ASSERT r.company_id = '00000000-0000-4000-8000-000000002202' AND r.org_name = 'Greenlogy a.s.', 'hľadanie CZ IČO';
  RAISE NOTICE 'OK: identifikátor podľa krajiny (SK/CZ 8, HR 11 číslic), krajina z firmy alebo spoločnosti';
END;
$$;

DO $$
DECLARE
  v_cz  uuid := (SELECT id FROM org WHERE code = 'greenlogy_cz');
BEGIN
  -- OOM, deal a zmluva preberajú spoločnosť od zákazníka
  ASSERT (SELECT org_id FROM deal WHERE id = '00000000-0000-4000-8000-000000000601') = crm_default_org(), 'deal';
  INSERT INTO oom (id, company_id, eic, type, status) VALUES
    ('00000000-0000-4000-8000-000000002301', '00000000-0000-4000-8000-000000002203', '24ZZS000TEST901I', 'spotreba', 'pripravovane');
  ASSERT (SELECT org_id FROM oom WHERE id = '00000000-0000-4000-8000-000000002301') = v_cz, 'OOM českej firmy';
  BEGIN
    INSERT INTO deal (company_id, org_id, pipeline_id, stage_id, name) VALUES
      ('00000000-0000-4000-8000-000000000101', v_cz, '00000000-0000-4000-8000-000000000501',
       '00000000-0000-4000-8000-000000000511', 'Deal v cudzej spoločnosti');
    RAISE EXCEPTION 'CHYBA: deal v inej spoločnosti ako zákazník prešiel';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK: deal musí patriť spoločnosti zákazníka';
  END;

  -- osoba v inej spoločnosti = nový záznam (odpoveď 1)
  INSERT INTO contact (id, first_name, last_name, email, is_household, org_id) VALUES
    ('00000000-0000-4000-8000-000000002302', 'Ján', 'Testovací', 'jan.testovaci@example.test', false, v_cz);
  BEGIN
    INSERT INTO company_contact (company_id, contact_id) VALUES
      ('00000000-0000-4000-8000-000000000101', '00000000-0000-4000-8000-000000002302');
    RAISE EXCEPTION 'CHYBA: osoba z CZ vo firme SK prešla';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK: osoba a firma musia byť z jednej spoločnosti';
  END;
  INSERT INTO company_contact (company_id, contact_id, roles) VALUES
    ('00000000-0000-4000-8000-000000002203', '00000000-0000-4000-8000-000000002302', '{statutar}');
  -- duplicita osoby iba v rámci spoločnosti
  ASSERT NOT EXISTS (SELECT 1 FROM contact_duplicate_check('jan.testovaci@example.test', NULL)
                      WHERE contact_id = '00000000-0000-4000-8000-000000002302'), 'SK kontrola nevidí CZ osobu';
  ASSERT (SELECT array_agg(contact_id) FROM contact_duplicate_check('jan.testovaci@example.test', NULL, v_cz))
       = '{00000000-0000-4000-8000-000000002302}', 'CZ kontrola nájde iba CZ osobu';
  BEGIN
    UPDATE company SET org_id = crm_default_org() WHERE id = '00000000-0000-4000-8000-000000002203';
    RAISE EXCEPTION 'CHYBA: zmena spoločnosti firmy s väzbami prešla';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK: firma s väzbami nezmení spoločnosť';
  END;
  RAISE NOTICE 'OK: OOM, deal a zmluva preberajú spoločnosť zákazníka; duplicita osoby iba v rámci spoločnosti';
END;
$$;

-- N6. Číselníky a roly kontaktu (odpoveď 2)
DO $$
BEGIN
  BEGIN
    UPDATE lookup_value SET label = 'Konateľ' WHERE list_code = 'rola_kontaktu' AND code = 'statutar';
    RAISE EXCEPTION 'CHYBA: systémová hodnota premenovaná';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK: systémovú rolu nemožno premenovať';
  END;
  BEGIN
    UPDATE lookup_value SET hidden_at = now() WHERE list_code = 'rola_kontaktu' AND code = 'fakturacia';
    RAISE EXCEPTION 'CHYBA: systémová hodnota skrytá';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK: systémovú rolu nemožno skryť';
  END;
  BEGIN
    DELETE FROM lookup_value WHERE list_code = 'rola_kontaktu' AND code = 'technik';
    RAISE EXCEPTION 'CHYBA: hodnota číselníka zmazaná';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK: hodnota číselníka sa nemaže';
  END;

  INSERT INTO lookup_value (list_code, label) VALUES ('rola_kontaktu', 'Energetik'), ('zdroj_kontaktu', 'Odporúčanie');
  ASSERT (SELECT code FROM lookup_value WHERE label = 'Odporúčanie') = 'odporucanie', 'kód z názvu';
  UPDATE company_contact SET roles = '{kontaktna_osoba,energetik}'
   WHERE company_id = '00000000-0000-4000-8000-000000000102' AND contact_id = '00000000-0000-4000-8000-000000000202';
  UPDATE lookup_value SET hidden_at = now() WHERE list_code = 'rola_kontaktu' AND code = 'technik';
  BEGIN
    UPDATE company_contact SET roles = roles || '{technik}'
     WHERE company_id = '00000000-0000-4000-8000-000000000102' AND contact_id = '00000000-0000-4000-8000-000000000202';
    RAISE EXCEPTION 'CHYBA: skrytá rola vybraná';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK: skrytú hodnotu nemožno nanovo vybrať';
  END;
  UPDATE contact SET source = 'odporucanie' WHERE id = '00000000-0000-4000-8000-000000000201';
  UPDATE lookup_value SET hidden_at = now() WHERE code = 'odporucanie';
  UPDATE contact SET phone = '0905 000 111' WHERE id = '00000000-0000-4000-8000-000000000201';  -- skrytý zdroj ostáva
  BEGIN
    UPDATE contact SET source = 'neznamy' WHERE id = '00000000-0000-4000-8000-000000000201';
    RAISE EXCEPTION 'CHYBA: zdroj mimo číselníka prešiel';
  EXCEPTION WHEN foreign_key_violation THEN
    RAISE NOTICE 'OK: zdroj kontaktu iba z číselníka; skrytá hodnota na starom zázname ostáva';
  END;
END;
$$;

-- N7. Vlastné polia
INSERT INTO custom_field_section (id, entity, name) VALUES
  ('00000000-0000-4000-8000-000000002401', 'osoba', 'Technické vybavenie');
INSERT INTO custom_field (id, entity, label, field_type, section_id, filterable, edit_access, ref_entity, org_id) VALUES
  ('00000000-0000-4000-8000-000000002411', 'osoba', 'Má tepelné čerpadlo', 'ano_nie', '00000000-0000-4000-8000-000000002401', true, 'vsetky_timy', NULL, NULL),
  ('00000000-0000-4000-8000-000000002412', 'osoba', 'Typ striedača', 'vyber', '00000000-0000-4000-8000-000000002401', true, 'vybrane_timy', NULL, NULL),
  ('00000000-0000-4000-8000-000000002413', 'osoba', 'Odporučil', 'odkaz', NULL, false, 'vsetky_timy', 'osoba', NULL),
  ('00000000-0000-4000-8000-000000002414', 'osoba', 'Výkon FVE kW', 'cislo', NULL, false, 'vsetky_timy', NULL, NULL),
  ('00000000-0000-4000-8000-000000002415', 'osoba', 'Revízia do', 'datum', NULL, false, 'vsetky_timy', NULL, NULL),
  ('00000000-0000-4000-8000-000000002416', 'osoba', 'Poznámka pre servis', 'dlhy_text', NULL, false, 'vsetky_timy', NULL, NULL),
  ('00000000-0000-4000-8000-000000002417', 'osoba', 'Záujmy', 'vyber_viac', NULL, false, 'vsetky_timy', NULL, NULL),
  ('00000000-0000-4000-8000-000000002418', 'osoba', 'Iba v Česku', 'text', NULL, false, 'vsetky_timy', NULL,
   (SELECT id FROM org WHERE code = 'greenlogy_cz'));
INSERT INTO custom_field_team (field_id, team_id)
SELECT '00000000-0000-4000-8000-000000002412', id FROM team WHERE code IN ('servis', 'nakup');
INSERT INTO custom_field_option (id, field_id, label) VALUES
  ('00000000-0000-4000-8000-000000002421', '00000000-0000-4000-8000-000000002412', 'Huawei'),
  ('00000000-0000-4000-8000-000000002422', '00000000-0000-4000-8000-000000002412', 'Fronius'),
  ('00000000-0000-4000-8000-000000002423', '00000000-0000-4000-8000-000000002417', 'Batéria'),
  ('00000000-0000-4000-8000-000000002424', '00000000-0000-4000-8000-000000002417', 'Wallbox');

DO $$
DECLARE
  jan  constant uuid := '00000000-0000-4000-8000-000000000201';
  r    audit_log;
BEGIN
  ASSERT (SELECT key FROM custom_field WHERE id = '00000000-0000-4000-8000-000000002411') = 'ma_tepelne_cerpadlo',
         'kľúč z názvu';
  UPDATE contact SET custom = jsonb_build_object(
           'ma_tepelne_cerpadlo', true,
           'typ_striedaca', '00000000-0000-4000-8000-000000002421',
           'odporucil', '00000000-0000-4000-8000-000000000202',
           'vykon_fve_kw', 9.5,
           'revizia_do', '2027-03-31',
           'zaujmy', jsonb_build_array('00000000-0000-4000-8000-000000002423', '00000000-0000-4000-8000-000000002424'))
   WHERE id = jan;

  -- audit po jednotlivých poliach
  SELECT * INTO r FROM audit_log WHERE table_name = 'contact' AND record_id = jan ORDER BY id DESC LIMIT 1;
  ASSERT r.diff -> 'custom.ma_tepelne_cerpadlo' = '{"old": null, "new": true}'::jsonb, format('audit %s', r.diff);
  ASSERT NOT r.diff ? 'custom', 'audit nemá celý JSON';

  -- filter cez GIN index
  ASSERT (SELECT count(*) FROM contact WHERE custom @> '{"ma_tepelne_cerpadlo": true}') = 1, 'filter áno/nie';

  BEGIN
    UPDATE contact SET custom = custom || '{"vykon_fve_kw": "veľa"}' WHERE id = jan;
    RAISE EXCEPTION 'CHYBA: text v číselnom poli prešiel';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK: zlý typ hodnoty odmietnutý';
  END;
  BEGIN
    UPDATE contact SET custom = custom || '{"revizia_do": "2027-02-30"}' WHERE id = jan;
    RAISE EXCEPTION 'CHYBA: neplatný dátum prešiel';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK: neplatný dátum odmietnutý';
  END;
  BEGIN
    UPDATE contact SET custom = custom || '{"neexistuje": 1}' WHERE id = jan;
    RAISE EXCEPTION 'CHYBA: neznáme pole prešlo';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK: neznáme pole odmietnuté';
  END;
  BEGIN
    UPDATE contact SET custom = custom || '{"typ_striedaca": "00000000-0000-4000-8000-000000002423"}' WHERE id = jan;
    RAISE EXCEPTION 'CHYBA: hodnota výberu iného poľa prešla';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK: hodnota výberu musí patriť poľu';
  END;
  BEGIN
    UPDATE contact SET custom = custom || '{"iba_v_cesku": "x"}' WHERE id = jan;
    RAISE EXCEPTION 'CHYBA: pole inej spoločnosti prešlo';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK: pole českej spoločnosti nemožno vyplniť na slovenskej osobe';
  END;

  -- skrytá hodnota výberu: ostáva, nedá sa nanovo vybrať
  UPDATE custom_field_option SET hidden_at = now() WHERE id IN ('00000000-0000-4000-8000-000000002421',
                                                                '00000000-0000-4000-8000-000000002422');
  UPDATE contact SET custom = custom || '{"vykon_fve_kw": 10}' WHERE id = jan;
  BEGIN
    UPDATE contact SET custom = custom || '{"typ_striedaca": "00000000-0000-4000-8000-000000002422"}' WHERE id = jan;
    RAISE EXCEPTION 'CHYBA: skrytá hodnota výberu vybraná';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK: skrytá hodnota výberu ostáva na zázname, nanovo sa vybrať nedá';
  END;

  -- odkaz: cieľ existuje a je z tej istej spoločnosti (Peter 12. 10.)
  BEGIN
    UPDATE contact SET custom = custom || '{"odporucil": "00000000-0000-4000-8000-000000009999"}' WHERE id = jan;
    RAISE EXCEPTION 'CHYBA: odkaz na neexistujúci záznam prešiel';
  EXCEPTION WHEN foreign_key_violation THEN
    RAISE NOTICE 'OK: odkaz na neexistujúci záznam odmietnutý';
  END;
  BEGIN
    UPDATE contact SET custom = custom || '{"odporucil": "00000000-0000-4000-8000-000000002302"}' WHERE id = jan;
    RAISE EXCEPTION 'CHYBA: odkaz na osobu inej spoločnosti prešiel';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK: odkaz na záznam inej spoločnosti odmietnutý';
  END;

  -- archivované pole: hodnota ostáva, meniť sa nedá; definícia sa nemaže ani nemení typ
  UPDATE custom_field SET archived_at = now() WHERE id = '00000000-0000-4000-8000-000000002414';
  UPDATE contact SET phone = '0905 000 222' WHERE id = jan;
  ASSERT (SELECT custom -> 'vykon_fve_kw' FROM contact WHERE id = jan) = '10', 'hodnota archivovaného poľa ostáva';
  BEGIN
    UPDATE contact SET custom = custom || '{"vykon_fve_kw": 11}' WHERE id = jan;
    RAISE EXCEPTION 'CHYBA: archivované pole zmenené';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK: archivované pole sa nedá meniť, údaje ostávajú';
  END;
  BEGIN
    UPDATE custom_field SET field_type = 'text' WHERE id = '00000000-0000-4000-8000-000000002411';
    RAISE EXCEPTION 'CHYBA: typ poľa s hodnotami zmenený';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK: typ poľa s hodnotami sa nemení';
  END;
  BEGIN
    UPDATE custom_field SET key = 'tc' WHERE id = '00000000-0000-4000-8000-000000002411';
    RAISE EXCEPTION 'CHYBA: kľúč poľa zmenený';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK: kľúč poľa sa nemení';
  END;
  BEGIN
    DELETE FROM custom_field WHERE id = '00000000-0000-4000-8000-000000002416';
    RAISE EXCEPTION 'CHYBA: pole zmazané';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK: pole sa nemaže, iba archivuje';
  END;
END;
$$;

-- N8. Pipelines a stage
DO $$
BEGIN
  ASSERT (SELECT is_closed AND NOT is_won FROM pipeline_stage WHERE id = '00000000-0000-4000-8000-000000001022'),
         'prehraný = uzavretý, nie vyhraný';
  ASSERT (SELECT is_closed AND is_won FROM pipeline_stage WHERE id = '00000000-0000-4000-8000-000000000512'),
         'vyhraný = uzavretý aj vyhraný';
  BEGIN
    INSERT INTO pipeline (name, kind) VALUES ('Test B2B elektrina', 'b2b_dodavka');
    RAISE EXCEPTION 'CHYBA: rovnaký názov pipeline prešiel';
  EXCEPTION WHEN unique_violation THEN
    RAISE NOTICE 'OK: názov pipeline je unikátny v rámci spoločnosti';
  END;
  INSERT INTO pipeline (name, kind, org_id)
  SELECT 'Test B2B elektrina', 'b2b_dodavka', id FROM org WHERE code = 'greenlogy_cz';
  BEGIN
    DELETE FROM pipeline_stage WHERE id = '00000000-0000-4000-8000-000000001022';
    RAISE EXCEPTION 'CHYBA: stage zmazaná';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK: stage sa nemaže, iba archivuje; rovnaký názov pipeline v inej spoločnosti áno';
  END;
END;
$$;

-- N9. Pracovný čas: firemné voľno posunie termín SLA
DO $$
DECLARE
  tz constant text := 'Europe/Bratislava';
BEGIN
  INSERT INTO org_day_off (org_id, date, kind, name)
  VALUES (crm_default_org(), '2026-10-13', 'firemne_volno', 'Testovacie voľno');
  -- piatok 15:00 + 24 h: bez voľna streda 15:00, s voľnom v utorok štvrtok 15:00
  ASSERT add_business_minutes(timestamp '2026-10-09 15:00' AT TIME ZONE tz, 1440)
       = timestamp '2026-10-15 15:00' AT TIME ZONE tz, 'SLA s firemným voľnom';
  ASSERT (SELECT note FROM business_calendar WHERE org_id = crm_default_org() AND date = '2026-10-13') = 'Testovacie voľno',
         'kalendár prepočítaný';
  BEGIN
    PERFORM add_business_minutes(now(), 60, (SELECT id FROM org WHERE code = 'greenlogy_cz'));
    RAISE EXCEPTION 'CHYBA: SLA bez kalendára CZ';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM LIKE 'CHYBA%' THEN RAISE; END IF;
  END;
  RAISE NOTICE 'OK: firemné voľno sa prejaví v SLA; spoločnosť bez sviatkov SLA nepočíta';
END;
$$;

-- ============================================================================
-- Práva v databáze (rola crm_rls_test z checks_zakaznici.sql, bez práv vlastníka)
-- ============================================================================

INSERT INTO app_user (id, email, name, team_id, status)
SELECT '00000000-0000-4000-8000-000000002501', 'cz.obchodnik@example.test', 'Český Obchodník', t.id, 'aktivny'
  FROM team t WHERE t.code = 'sales_internal';
INSERT INTO app_user_org (user_id, org_id)
SELECT '00000000-0000-4000-8000-000000002501', id FROM org WHERE code = 'greenlogy_cz';

GRANT SELECT, INSERT, UPDATE, DELETE ON org, org_bank_account, team, team_permission, app_user, app_user_org,
  org_work_hours, org_day_off, lookup_value, custom_field_team, custom_field_option TO crm_rls_test;
GRANT SELECT ON lookup_list, custom_field_section, pipeline, pipeline_stage, business_calendar,
  deal, contract, offer, deal_contact TO crm_rls_test;
GRANT SELECT, UPDATE, DELETE ON audit_log TO crm_rls_test;
SET LOCAL ROLE crm_rls_test;

DO $$
DECLARE
  v_peter  uuid := (SELECT id FROM app_user WHERE lower(email) = 'peter@greenlogy.com');
  n        integer;
BEGIN
  PERFORM set_config('app.require_user', 'on', true);

  -- N10. Deaktivovaný používateľ nevidí nič (ani Nastavenia)
  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-000000002002', true);
  ASSERT (SELECT count(*) FROM company) = 0, 'deaktivovaný vidí firmy';
  ASSERT (SELECT count(*) FROM contact) = 0, 'deaktivovaný vidí osoby';
  ASSERT (SELECT count(*) FROM company_contact) = 0, 'deaktivovaný vidí väzby';
  ASSERT (SELECT count(*) FROM customer_v) = 0, 'deaktivovaný vidí zoznam Zákazníci';
  ASSERT (SELECT count(*) FROM app_user) = 0, 'deaktivovaný vidí používateľov';
  ASSERT (SELECT count(*) FROM team_permission) = 0, 'deaktivovaný vidí práva';
  UPDATE contact SET phone = '0900 000 000' WHERE id = '00000000-0000-4000-8000-000000000201';
  GET DIAGNOSTICS n = ROW_COUNT;
  ASSERT n = 0, 'deaktivovaný zmenil osobu';
  RAISE NOTICE 'OK: deaktivovaný používateľ nevidí ani nezmení nič';

  -- N11. Sales_external nevidí cudzí záznam (navyše k Z13: aj firmy inej spoločnosti)
  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-000000001002', true);
  ASSERT NOT EXISTS (SELECT 1 FROM company WHERE owner_id IS DISTINCT FROM '00000000-0000-4000-8000-000000001002'),
         'externý vidí cudziu firmu';
  ASSERT NOT EXISTS (SELECT 1 FROM company WHERE id = '00000000-0000-4000-8000-000000000101'), 'externý vidí Alfu';
  ASSERT NOT EXISTS (SELECT 1 FROM contact WHERE id = '00000000-0000-4000-8000-000000000201'), 'externý vidí cudziu domácnosť';
  ASSERT (SELECT company_id FROM company_ico_check('SK', '00123456')) IS NULL, 'externý dostal id cudzej firmy';
  RAISE NOTICE 'OK: Sales_external nevidí cudzie firmy ani osoby, pri duplicite nedostane id';

  -- N12. Spoločnosti: český obchodník (Sales_internal, iba CZ) nevidí slovenských zákazníkov
  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-000000002501', true);
  ASSERT (SELECT array_agg(name ORDER BY name) FROM company) = '{"Firma českej spoločnosti"}',
         format('CZ obchodník vidí %s', (SELECT array_agg(name ORDER BY name) FROM company));
  ASSERT (SELECT array_agg(last_name) FROM contact) = '{Testovací}', 'CZ obchodník: iba CZ osoba';
  BEGIN
    INSERT INTO company (name, ico) VALUES ('SK firma od CZ obchodníka', '88888801');   -- predvolene SK
    RAISE EXCEPTION 'CHYBA: CZ obchodník založil SK firmu';
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'OK: obchodník nezaloží záznam v spoločnosti, ku ktorej nemá prístup';
  END;
  -- CEO (všetky spoločnosti) vidí obe
  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-000000001001', true);
  ASSERT (SELECT count(DISTINCT org_id) FROM company) = 2, 'CEO vidí SK aj CZ';
  RAISE NOTICE 'OK: prístup k spoločnostiam: CZ obchodník iba CZ, CEO všetky';

  -- N13. Vlastné pole len pre vybrané tímy: obchodník nie, servis áno
  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-000000000011', true);
  BEGIN
    UPDATE contact SET custom = custom - 'typ_striedaca' WHERE id = '00000000-0000-4000-8000-000000000201';
    RAISE EXCEPTION 'CHYBA: obchodník zmenil pole tímu Servis/Nákup';
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'OK: pole „Typ striedača“ nemení tím, ktorý ho nemá povolené';
  END;
  UPDATE contact SET custom = custom || '{"ma_tepelne_cerpadlo": false}' WHERE id = '00000000-0000-4000-8000-000000000201';
  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-000000002001', true);  -- Servis
  UPDATE contact SET custom = custom - 'typ_striedaca' WHERE id = '00000000-0000-4000-8000-000000000201';
  ASSERT (SELECT NOT custom ? 'typ_striedaca' FROM contact WHERE id = '00000000-0000-4000-8000-000000000201'),
         'servis vymazal pole';
  ASSERT (SELECT source FROM audit_log WHERE table_name = 'contact' ORDER BY id DESC LIMIT 1) = 'aplikacia',
         'zdroj zmeny aplikácia';
  RAISE NOTICE 'OK: vlastné pole: tímy, ktoré ho smú meniť, platia aj v databáze; zdroj zmeny v audite';

  -- N14. Nastavenia mení iba admin
  UPDATE team_permission SET can_export = true WHERE module = 'zakaznici'
     AND team_id = (SELECT id FROM team WHERE code = 'servis');
  GET DIAGNOSTICS n = ROW_COUNT;
  ASSERT n = 0, 'neadmin zmenil práva tímu';
  BEGIN
    INSERT INTO org_day_off (org_id, date, kind, name) VALUES (crm_default_org(), '2026-12-31', 'firemne_volno', 'Silvester');
    RAISE EXCEPTION 'CHYBA: neadmin pridal voľno';
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'OK: neadmin Nastavenia nezmení';
  END;
  PERFORM set_config('app.user_id', v_peter::text, true);
  UPDATE team_permission SET can_export = true WHERE module = 'zakaznici'
     AND team_id = (SELECT id FROM team WHERE code = 'servis');
  GET DIAGNOSTICS n = ROW_COUNT;
  ASSERT n = 1, 'admin nezmenil práva tímu';
  INSERT INTO org_day_off (org_id, date, kind, name) VALUES (crm_default_org(), '2026-12-31', 'firemne_volno', 'Silvester');
  BEGIN
    INSERT INTO org_day_off (org_id, date, kind, name) VALUES (crm_default_org(), '2026-12-30', 'statny_sviatok', 'Vymyslený');
    RAISE EXCEPTION 'CHYBA: admin pridal štátny sviatok';
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'OK: admin mení práva a firemné voľno; štátne sviatky iba migrácia';
  END;
  BEGIN
    INSERT INTO lookup_value (list_code, label, is_system) VALUES ('rola_kontaktu', 'Systémová od admina', true);
    RAISE EXCEPTION 'CHYBA: admin založil systémovú hodnotu';
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'OK: systémové hodnoty číselníka zakladá iba migrácia';
  END;

  -- N15. Audit sa nedá meniť ani mazať
  BEGIN
    UPDATE audit_log SET diff = '{}' WHERE id = (SELECT max(id) FROM audit_log);
    RAISE EXCEPTION 'CHYBA: audit zmenený';
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'OK: audit sa nedá zmeniť';
  END;
  BEGIN
    DELETE FROM audit_log WHERE id = (SELECT max(id) FROM audit_log);
    RAISE EXCEPTION 'CHYBA: audit zmazaný';
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'OK: audit sa nedá zmazať';
  END;

  PERFORM set_config('app.user_id', '', true);
  PERFORM set_config('app.require_user', '', true);
END;
$$;

RESET ROLE;
