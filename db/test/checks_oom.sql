-- Kontroly modulu Odberné miesta (0013): EIC, typy, povinné údaje, číselníky, väzba v čase
-- (prepis, odchod, návrat, časový rez), kroky prechodu, kontaktné osoby, spoločnosť, audit.
-- Spúšťa sa iba cez db/test/run.sh (po seed.sql a checks_nastavenia.sql – používa českú firmu 2203).

-- O1. EIC: kontrolná číslica, normalizácia; typ veľkoobchod neexistuje
DO $$
BEGIN
  ASSERT eic_is_valid('10YSK-SEPS-----K'), 'EIC SEPS (ENTSO-E) je platné';
  ASSERT NOT eic_is_valid('24ZSS4100078132P'), 'zlá kontrolná číslica';
  ASSERT NOT eic_is_valid('24ZZS000TEST01'), 'krátke EIC';

  BEGIN
    PERFORM pg_temp.t_oom(NULL, '00000000-0000-4000-8000-000000000102', NULL, '24ZZS000TEST700A', 'spotreba', 'pripravovane');
    RAISE EXCEPTION 'CHYBA: EIC so zlou kontrolnou číslicou prešlo';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  -- malé písmená a medzery sa upravia
  PERFORM pg_temp.t_oom('00000000-0000-4000-8000-000000003001', '00000000-0000-4000-8000-000000000102', NULL,
                        ' 24zzs000 test700s', 'spotreba', 'pripravovane');
  ASSERT (SELECT eic FROM oom WHERE id = '00000000-0000-4000-8000-000000003001') = '24ZZS000TEST700S', 'normalizácia EIC';

  BEGIN
    PERFORM 'velkoobchod'::oom_type;
    RAISE EXCEPTION 'CHYBA: typ veľkoobchod ešte existuje';
  EXCEPTION WHEN invalid_text_representation THEN NULL;
  END;
  RAISE NOTICE 'OK: EIC (kontrolná číslica, normalizácia), typ veľkoobchod zrušený';
END;
$$;

-- O2. Povinné údaje pre Aktívne, zákazník a stav iba cez väzbu, sadzba patrí PDS
DO $$
DECLARE
  v_id constant uuid := '00000000-0000-4000-8000-000000003002';
BEGIN
  INSERT INTO oom (id, company_id, eic, type, status)
  VALUES (v_id, '00000000-0000-4000-8000-000000000102', '24ZZS000TEST701Q', 'spotreba', 'pripravovane');
  ASSERT (SELECT count(*) FROM oom_customer WHERE oom_id = v_id AND valid_to IS NULL AND status = 'pripravovane') = 1,
         'nové OOM má otvorenú väzbu Pripravované';

  BEGIN
    PERFORM oom_set_status(v_id, 'aktivne');
    RAISE EXCEPTION 'CHYBA: Aktívne bez povinných údajov prešlo';
  EXCEPTION WHEN check_violation THEN
    ASSERT SQLERRM LIKE '%PDS%sadzba distribúcie%plánovaná spotreba%', SQLERRM;
  END;

  BEGIN
    INSERT INTO oom (company_id, eic, type, status)
    VALUES ('00000000-0000-4000-8000-000000000102', '24ZZS000TEST702O', 'spotreba', 'odidene');
    RAISE EXCEPTION 'CHYBA: nové OOM v stave Odídené prešlo';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  BEGIN
    UPDATE oom SET status = 'aktivne' WHERE id = v_id;
    RAISE EXCEPTION 'CHYBA: priama zmena stavu prešla';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    UPDATE oom SET company_id = '00000000-0000-4000-8000-000000000101' WHERE id = v_id;
    RAISE EXCEPTION 'CHYBA: priama zmena zákazníka prešla';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  INSERT INTO lookup_value (list_code, parent_code, label) VALUES ('sadzba_distribucie', 'ssd', 'Z9');
  ASSERT EXISTS (SELECT 1 FROM lookup_value WHERE list_code = 'sadzba_distribucie' AND code = 'ssd_z9'), 'kód sadzby s PDS';
  BEGIN
    UPDATE oom SET pds = 'zsd', pds_tariff = 'ssd_c2' WHERE id = v_id;
    RAISE EXCEPTION 'CHYBA: sadzba iného PDS prešla';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    INSERT INTO lookup_value (list_code, label) VALUES ('sadzba_distribucie', 'Bez PDS');
    RAISE EXCEPTION 'CHYBA: sadzba bez PDS prešla';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    UPDATE oom SET billing_period = 'dvojtyzdenne' WHERE id = v_id;
    RAISE EXCEPTION 'CHYBA: neznáma hodnota číselníka prešla';
  EXCEPTION WHEN foreign_key_violation THEN NULL;
  END;

  UPDATE oom SET address_city = 'Žilina', address_zip = '01001', pds = 'zsd', pds_tariff = 'zsd_d2',
                 voltage_level = 'nn', supply_from = '2026-01-01', planned_consumption_vt_mwh = 50,
                 billing_period = 'mesacne', switch_notice_sent_on = '2025-10-01',
                 switch_notice_accepted_on = '2025-10-20', switch_confirmed_on = '2025-11-10'
   WHERE id = v_id;
  PERFORM oom_set_status(v_id, 'aktivne');
  ASSERT (SELECT status FROM oom WHERE id = v_id) = 'aktivne', 'Pripravované → Aktívne s údajmi';
  RAISE NOTICE 'OK: povinné údaje pre Aktívne, zákazník a stav iba cez väzbu, číselníky a sadzba podľa PDS';
END;
$$;

-- O2b. Číselníky z HubSpotu (Peter 12. 10.)
DO $$
BEGIN
  ASSERT (SELECT count(*) FROM lookup_value WHERE list_code = 'pds') = 17, 'PDS: 3 + 14 miestnych DS';
  ASSERT (SELECT reg_no FROM lookup_value WHERE list_code = 'pds' AND code = 'zsd') = '36361518', 'IČO ZSD';
  ASSERT (SELECT array_agg(parent_code) FROM lookup_value WHERE list_code = 'sadzba_distribucie' AND label = 'C2-X3') = '{zsd}', 'C2-X3 iba ZSD';
  ASSERT (SELECT array_agg(parent_code) FROM lookup_value WHERE list_code = 'sadzba_distribucie' AND label = 'X3-C2') = '{vsd}', 'X3-C2 iba VSD';
  ASSERT NOT EXISTS (SELECT 1 FROM lookup_value WHERE list_code = 'sadzba_distribucie' AND label LIKE 'VBATTERY%'), 'VBATTERY nie je sadzba';
  ASSERT (SELECT count(*) FROM lookup_value WHERE list_code = 'fakturacne_obdobie') = 3, 'fakturačné obdobie: 3 režimy';
  ASSERT (SELECT count(*) FROM lookup_value WHERE list_code = 'sposob_zaloh') = 5, 'spôsob záloh: 5';
  ASSERT EXISTS (SELECT 1 FROM lookup_value WHERE list_code = 'typ_merania' AND code = 'n'), 'typ merania N';
  ASSERT 'biomasa'::source_kind IS NOT NULL AND 'bioplyn'::source_kind IS NOT NULL, 'bioplyn aj biomasa';
  RAISE NOTICE 'OK: číselníky OOM (PDS s IČO, sadzby podľa PDS, fakturácia, zálohy, meranie, druh zdroja)';
END;
$$;

-- O3. Kroky prechodu po poradí
DO $$
BEGIN
  BEGIN
    UPDATE oom SET switch_notice_accepted_on = '2025-09-01' WHERE id = '00000000-0000-4000-8000-000000003002';
    RAISE EXCEPTION 'CHYBA: akceptácia pred odoslaním prešla';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    UPDATE oom SET switch_notice_required = false WHERE id = '00000000-0000-4000-8000-000000003002';
    RAISE EXCEPTION 'CHYBA: „bez výpovede“ s dátumami výpovede prešlo';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  RAISE NOTICE 'OK: kroky prechodu po poradí';
END;
$$;

-- O4. Prepis (zadanie OOM, príklad 4): Horváth → Kováčová od 1. 11. 2026, časový rez
DO $$
DECLARE
  h   constant uuid := '00000000-0000-4000-8000-000000003101';
  k   constant uuid := '00000000-0000-4000-8000-000000003102';
  o   constant uuid := '00000000-0000-4000-8000-000000003103';
  t   constant date := '2026-12-15';
  v_link oom_customer;
BEGIN
  INSERT INTO contact (id, first_name, last_name, email, is_household) VALUES
    (h, 'Ján', 'Horvátha', 'jan.horvatha@example.test', true),
    (k, 'Lenka', 'Kováčová', 'lenka.kovacova@example.test', true);
  PERFORM pg_temp.t_oom(o, NULL, h, '24ZZS000TEST703M', 'spotreba', 'aktivne');
  INSERT INTO oom_contact (oom_id, contact_id, roles) VALUES (o, h, '{kontaktna_osoba}');

  BEGIN
    PERFORM oom_transfer(o, NULL, h, '2026-11-01');
    RAISE EXCEPTION 'CHYBA: prepis na toho istého zákazníka prešiel';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    PERFORM oom_transfer(o, NULL, k, '2024-12-01');
    RAISE EXCEPTION 'CHYBA: prepis pred začiatkom väzby prešiel';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  PERFORM oom_transfer(o, NULL, k, '2026-11-01');

  ASSERT (SELECT person_id = k AND status = 'aktivne' FROM oom WHERE id = o), 'OOM patrí Kováčovej, Aktívne';
  SELECT * INTO v_link FROM oom_customer WHERE oom_id = o AND person_id = h;
  ASSERT v_link.valid_from = '2025-01-01' AND v_link.valid_to = '2026-10-31'
     AND v_link.status = 'prepisane' AND v_link.end_reason = 'prepis', 'Horváth: 1. 1. 2025 – 31. 10. 2026 Prepísané';
  ASSERT (SELECT person_id FROM oom_customer_at(o, '2026-03-01')) = h, 'k 1. 3. 2026 Horváth';
  ASSERT (SELECT person_id FROM oom_customer_at(o, '2026-12-01')) = k, 'k 1. 12. 2026 Kováčová';
  ASSERT NOT EXISTS (SELECT 1 FROM oom_customer_at(o, '2024-06-01')), 'pred prvou väzbou nikto';
  ASSERT customer_status_calc(NULL, h, t) = 'zruseny_zakaznik', 'Horváth: jediné OOM Prepísané';
  ASSERT customer_status_calc(NULL, k, t) = 'zakaznik', 'Kováčová: Zákazník';
  ASSERT NOT EXISTS (SELECT 1 FROM oom_contact WHERE oom_id = o), 'kontaktné osoby starého zákazníka odobraté';

  BEGIN
    UPDATE oom_customer SET valid_to = '2026-09-30' WHERE id = v_link.id;
    RAISE EXCEPTION 'CHYBA: zmena uzavretej väzby prešla';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    INSERT INTO oom_customer (oom_id, person_id, org_id, valid_from, status)
    VALUES (o, h, crm_default_org(), '2026-12-01', 'aktivne');
    RAISE EXCEPTION 'CHYBA: druhá otvorená / prekrývajúca sa väzba prešla';
  EXCEPTION WHEN unique_violation OR exclusion_violation THEN NULL;
  END;
  RAISE NOTICE 'OK: prepis Horváth → Kováčová, časový rez, stav oboch, uzavretá väzba sa nemení';
END;
$$;

-- O5. Odchod a návrat na to isté EIC (dve obdobia), príznak bývalý
DO $$
DECLARE
  f  constant uuid := '00000000-0000-4000-8000-000000003201';
  o  constant uuid := '00000000-0000-4000-8000-000000003202';
  t  constant date := '2026-10-12';
BEGIN
  INSERT INTO company (id, name, ico, is_customer) VALUES (f, 'Návratová s.r.o.', '45454545', true);
  PERFORM pg_temp.t_oom(o, f, NULL, '24ZZS000TEST704K', 'spotreba', 'aktivne', '2023-01-01');
  ASSERT NOT customer_is_former_calc(f, NULL), 'pred odchodom nie je bývalý';

  PERFORM oom_set_status(o, 'odidene', '2025-12-31');
  ASSERT (SELECT status FROM oom WHERE id = o) = 'odidene', 'OOM Odídené';
  ASSERT customer_status_calc(f, NULL, t) = 'byvaly_zakaznik', 'Bývalý zákazník';
  ASSERT customer_is_former_calc(f, NULL), 'príznak bývalý z uzavretej väzby (odchod)';

  BEGIN
    PERFORM oom_set_status(o, 'zrusene', '2026-01-31');
    RAISE EXCEPTION 'CHYBA: zmena stavu bez otvorenej väzby prešla';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    PERFORM oom_reconnect(o, f, NULL, '2025-12-31');
    RAISE EXCEPTION 'CHYBA: návrat pred koncom predošlého obdobia prešiel';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  PERFORM oom_reconnect(o, f, NULL, '2027-01-01');
  ASSERT (SELECT count(*) FROM oom_customer WHERE oom_id = o) = 2, 'dve obdobia';
  ASSERT (SELECT status = 'pripravovane' AND supply_from IS NULL AND switch_notice_sent_on IS NULL
            FROM oom WHERE id = o), 'návrat: Pripravované, kroky prechodu vynulované';
  ASSERT customer_status_calc(f, NULL, t) = 'cakajuci_zakaznik', 'vracajúci sa: Čakajúci';
  ASSERT customer_is_former_calc(f, NULL), 'vracajúci sa ostáva bývalý';
  ASSERT NOT EXISTS (SELECT 1 FROM oom_customer_at(o, '2026-06-01')), 'medzi obdobiami nikomu';
  ASSERT (SELECT status FROM oom_customer_at(o, '2024-06-01')) = 'odidene', 'k 1. 6. 2024 prvé obdobie';

  BEGIN
    PERFORM oom_reconnect(o, f, NULL, '2027-06-01');
    RAISE EXCEPTION 'CHYBA: druhý návrat pri otvorenej väzbe prešiel';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  RAISE NOTICE 'OK: odchod uzavrie väzbu, návrat = nové obdobie, bývalý, časový rez medzi obdobiami';
END;
$$;

-- O6. Kontaktné osoby pri OOM a spoločnosť
DO $$
DECLARE
  o  constant uuid := '00000000-0000-4000-8000-000000000301';   -- Alfa – sklad
BEGIN
  INSERT INTO oom_contact (oom_id, contact_id, roles)
  VALUES (o, '00000000-0000-4000-8000-000000000202', '{spravca_budovy,technik_prevadzky}');
  BEGIN
    INSERT INTO oom_contact (oom_id, contact_id) VALUES (o, '00000000-0000-4000-8000-000000000201');
    RAISE EXCEPTION 'CHYBA: osoba mimo firmy zákazníka prešla';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    UPDATE oom_contact SET roles = '{riaditel_vesmiru}' WHERE oom_id = o;
    RAISE EXCEPTION 'CHYBA: neznáma rola pri OOM prešla';
  EXCEPTION WHEN foreign_key_violation THEN NULL;
  END;
  ASSERT (SELECT count(*) FROM contact_oom_v WHERE oom_id = o) >= 1, 'contact_oom_v funguje';

  -- prepis na zákazníka inej spoločnosti nejde
  BEGIN
    PERFORM oom_transfer(o, '00000000-0000-4000-8000-000000002203', NULL, '2026-11-01');
    RAISE EXCEPTION 'CHYBA: prepis do inej spoločnosti prešiel';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  RAISE NOTICE 'OK: kontaktné osoby (osoba firmy, roly z číselníka), prepis iba v rámci spoločnosti';
END;
$$;

-- O7. Audit väzieb a kontaktných osôb
DO $$
BEGIN
  ASSERT (SELECT count(*) FROM audit_log WHERE table_name = 'oom_customer'
           AND record_id IN (SELECT id FROM oom_customer WHERE oom_id = '00000000-0000-4000-8000-000000003103')) >= 3,
         'audit: založenie, uzavretie a nová väzba pri prepise';
  ASSERT EXISTS (SELECT 1 FROM audit_log WHERE table_name = 'oom_contact' AND action = 'delete'), 'audit odobratej kontaktnej osoby';
  RAISE NOTICE 'OK: audit väzieb a kontaktných osôb';
END;
$$;

-- ============================================================================
-- 0014: prepočet zákazníka, aktivácia, pohľady
-- ============================================================================

-- O8. Firma s OOM = zákazník; prepínač vypnutý = stav sa nemení; zapnutý = prepočet
DO $$
DECLARE
  f  constant uuid := '00000000-0000-4000-8000-000000003301';
  n  constant uuid := '00000000-0000-4000-8000-000000003302';
BEGIN
  ASSERT NOT crm_setting_on('customer_status_auto'), 'prepínač je v testoch vypnutý (seed.sql)';
  INSERT INTO company (id, name, ico, is_customer, is_partner) VALUES (f, 'Iba partner s.r.o.', '46464646', false, true);
  INSERT INTO contact (id, first_name, last_name, email, is_household) VALUES
    (n, 'Mária', 'Novákova', 'maria.novakova@example.test', true);
  PERFORM pg_temp.t_oom('00000000-0000-4000-8000-000000003303', f, NULL, '24ZZS000TEST705I', 'spotreba', 'pripravovane');
  ASSERT (SELECT is_customer FROM company WHERE id = f), 'firma s OOM dostala označenie zákazník';
  PERFORM pg_temp.t_oom('00000000-0000-4000-8000-000000003304', NULL, n, '24ZZS000TEST706G', 'spotreba', 'pripravovane', '2027-01-01');
  ASSERT (SELECT status FROM contact WHERE id = n) = 'marketingovy_kontakt', 'vypnutý prepínač: stav sa nemení';

  UPDATE app_setting SET value = 'true' WHERE key = 'customer_status_auto';
  ASSERT customer_refresh_all() >= 2, 'prepočet všetkých zmenil aspoň firmu a Novákovú';
  ASSERT (SELECT status = 'cakajuci_zakaznik' AND status_source = 'vypocet' FROM contact WHERE id = n), 'Nováková: Čakajúci (výpočet)';
  ASSERT (SELECT status FROM company WHERE id = f) = 'cakajuci_zakaznik', 'firma: Čakajúci';
  ASSERT EXISTS (SELECT 1 FROM audit_log WHERE table_name = 'contact' AND record_id = n AND source = 'system'
                  AND diff ? 'status'), 'zmena stavu v audite ako Systém';
  RAISE NOTICE 'OK: firma s OOM = zákazník; prepínač vypnutý / zapnutý; prepočet všetkých; audit Systém';
END;
$$;

-- O9. Aktivácia: hneď pri uložení, denne k dátumu, bez povinných údajov nie (príklad 1: Nováková)
DO $$
DECLARE
  n  constant uuid := '00000000-0000-4000-8000-000000003302';
  o  constant uuid := '00000000-0000-4000-8000-000000003304';   -- Nováková, dodávka od 1. 1. 2027
  f  constant uuid := '00000000-0000-4000-8000-000000003301';   -- firma (iba partner → zákazník)
  fo constant uuid := '00000000-0000-4000-8000-000000003303';   -- jej OOM, dodávka od 1. 1. 2025
BEGIN
  UPDATE oom SET switch_notice_sent_on = '2026-09-01', switch_notice_accepted_on = '2026-09-15',
                 switch_confirmed_on = '2026-10-01' WHERE id = o;
  ASSERT (SELECT status FROM oom WHERE id = o) = 'pripravovane', 'dodávka ešte nezačala';
  ASSERT oom_activate_due_at('2026-12-31') = 0, 'k 31. 12. 2026 nič';
  ASSERT oom_activate_due_at('2027-01-01') = 1, 'k 1. 1. 2027 jedno OOM';
  ASSERT (SELECT status FROM oom WHERE id = o) = 'aktivne', 'Nováková: OOM Aktívne';
  ASSERT (SELECT status FROM contact WHERE id = n) = 'zakaznik', 'Nováková: Zákazník automaticky';
  ASSERT EXISTS (SELECT 1 FROM audit_log WHERE table_name = 'oom_customer' AND source = 'system'
                  AND diff -> 'status' ->> 'new' = 'aktivne'), 'aktivácia v audite ako Systém';

  -- okamžite pri uložení (začiatok dodávky už nastal)
  UPDATE oom SET switch_notice_required = false, switch_confirmed_on = '2024-12-15' WHERE id = fo;
  ASSERT (SELECT status FROM oom WHERE id = fo) = 'aktivne', 'okamžitá aktivácia pri uložení';
  ASSERT (SELECT status FROM company WHERE id = f) = 'zakaznik', 'firma: Zákazník';

  -- bez povinných údajov sa neaktivuje, v zozname je značka
  INSERT INTO oom (id, company_id, eic, type, status, supply_from, switch_notice_required, switch_confirmed_on)
  VALUES ('00000000-0000-4000-8000-000000003305', f, '24ZZS000TEST707E', 'spotreba', 'pripravovane',
          '2025-01-01', false, '2024-12-01');
  ASSERT (SELECT status FROM oom WHERE id = '00000000-0000-4000-8000-000000003305') = 'pripravovane', 'bez údajov ostáva Pripravované';
  ASSERT oom_activate_due_at('2027-06-01') = 0, 'denná aktivácia ho preskočí';
  ASSERT (SELECT 'PDS' = ANY (active_missing) FROM oom_v WHERE id = '00000000-0000-4000-8000-000000003305'),
         'oom_v: chýbajúce údaje';

  ASSERT NOT has_function_privilege('crm_rls_test', 'oom_activate_due_at(date)', 'EXECUTE'), 'aktivácia k dátumu nie pre aplikáciu';
  ASSERT has_function_privilege('crm_rls_test', 'oom_activate_due()', 'EXECUTE'), 'denná aktivácia áno';
  RAISE NOTICE 'OK: aktivácia k dátumu, hneď pri uložení, bez údajov nie; stav zákazníka automaticky; práva';
END;
$$;

-- O10. Segment výrobca, prepis s prepočtom oboch, odchod
DO $$
DECLARE
  v  constant uuid := '00000000-0000-4000-8000-000000003401';   -- firma s FVE (príklad 3)
  w  constant uuid := '00000000-0000-4000-8000-000000003402';   -- firma, FVE zrušená
  h  constant uuid := '00000000-0000-4000-8000-000000003403';
  k  constant uuid := '00000000-0000-4000-8000-000000003404';
  o  constant uuid := '00000000-0000-4000-8000-000000003405';
BEGIN
  INSERT INTO company (id, name, ico, is_customer) VALUES
    (v, 'Kovovýroba Test a.s.', '47474747', true),
    (w, 'Zrušená FVE s.r.o.', '48484848', true);
  PERFORM pg_temp.t_oom(NULL, v, NULL, '24ZZS000TEST708C', 'spotreba', 'aktivne');
  PERFORM pg_temp.t_oom('00000000-0000-4000-8000-000000003406', v, NULL, '24ZZS000TEST709A', 'vyroba', 'aktivne');
  ASSERT (SELECT is_producer FROM company WHERE id = v), 'firma s FVE: výrobca';
  ASSERT (SELECT segment_label FROM customer_v WHERE id = v) = 'Firma · výrobca', 'segment v zozname';
  PERFORM oom_set_status('00000000-0000-4000-8000-000000003406', 'odidene', '2026-06-30');
  ASSERT (SELECT is_producer FROM company WHERE id = v), 'odídená FVE: ostáva výrobca';

  PERFORM pg_temp.t_oom(NULL, w, NULL, '24ZZS000TEST710P', 'vyroba', 'zrusene');
  ASSERT NOT (SELECT is_producer FROM company WHERE id = w), 'zrušená FVE: nie výrobca';
  ASSERT (SELECT status FROM company WHERE id = w) = 'zruseny_zakaznik', 'zrušená: Zrušený zákazník';

  -- prepis prepočíta oboch (príklad 4)
  INSERT INTO contact (id, first_name, last_name, email, is_household) VALUES
    (h, 'Jozef', 'Predávajúci', 'jozef.p@example.test', true),
    (k, 'Kamila', 'Kupujúca', 'kamila.k@example.test', true);
  PERFORM pg_temp.t_oom(o, NULL, h, '24ZZS000TEST711N', 'spotreba', 'aktivne');
  ASSERT (SELECT status FROM contact WHERE id = h) = 'zakaznik', 'predávajúci: Zákazník';
  PERFORM oom_transfer(o, NULL, k, '2026-11-01');
  ASSERT (SELECT status FROM contact WHERE id = h) = 'zruseny_zakaznik', 'predávajúci po prepise: Zrušený';
  ASSERT (SELECT status FROM contact WHERE id = k) = 'zakaznik', 'kupujúca: Zákazník';
  ASSERT (SELECT transferred_from_name = 'Jozef Predávajúci' AND transferred_on = '2026-11-01' FROM oom_v WHERE id = o),
         'oom_v: prepis od';

  -- odchod → Bývalý s príznakom
  PERFORM oom_set_status(o, 'odidene', '2027-03-31');
  ASSERT (SELECT status = 'byvaly_zakaznik' AND is_former_customer FROM contact WHERE id = k), 'kupujúca po odchode: Bývalý';
  RAISE NOTICE 'OK: výrobca (aj odídená FVE, nie zrušená), prepis prepočíta oboch, odchod = Bývalý';
END;
$$;

-- O11. Pohľady: customer_v z väzieb, contact_oom_v z dvoch zdrojov, prechod sa zasekol
DO $$
DECLARE
  o  constant uuid := '00000000-0000-4000-8000-000000003501';
BEGIN
  ASSERT (SELECT active_oom_count || '/' || annual_mwh FROM customer_v
           WHERE id = '00000000-0000-4000-8000-000000000101') = '1/150.000', 'Alfa: 1 aktívne OOM, 150 MWh (z väzieb)';

  -- Eva: osoba na deale Alfy (deal) + kontaktná osoba pri OOM 301 (O6, ručne)
  ASSERT (SELECT sources FROM contact_oom_v
           WHERE contact_id = '00000000-0000-4000-8000-000000000202'
             AND oom_id = '00000000-0000-4000-8000-000000000301') = '{deal,rucne}', 'Eva pri sklade: deal aj ručne';
  ASSERT (SELECT roles FROM contact_oom_v
           WHERE contact_id = '00000000-0000-4000-8000-000000000202'
             AND oom_id = '00000000-0000-4000-8000-000000000301') = '{spravca_budovy,technik_prevadzky}', 'roly pri OOM';

  -- zaseknutý prechod: výpoveď odoslaná pred 20 dňami bez akceptácie (lehota 14)
  PERFORM pg_temp.t_oom(o, '00000000-0000-4000-8000-000000000102', NULL, '24ZZS000TEST712L', 'spotreba', 'pripravovane');
  UPDATE oom SET switch_notice_sent_on = crm_today() - 20 WHERE id = o;
  ASSERT (SELECT switch_stuck FROM oom_v WHERE id = o), 'prechod sa zasekol (20 > 14 dní)';
  UPDATE org SET oom_switch_accept_days = 30 WHERE id = crm_default_org();
  ASSERT NOT (SELECT switch_stuck FROM oom_v WHERE id = o), 'lehota spoločnosti 30 dní: ešte nie';
  UPDATE oom SET switch_notice_accepted_on = crm_today() - 1 WHERE id = o;
  ASSERT NOT (SELECT switch_stuck FROM oom_v WHERE id = o), 'po akceptácii nie';
  ASSERT (SELECT pds_label = 'ZSD' AND planned_mwh = 10 FROM oom_v WHERE id = o), 'oom_v: PDS a objem';
  RAISE NOTICE 'OK: customer_v z väzieb, contact_oom_v (deal + ručne, roly), prechod sa zasekol podľa lehoty spoločnosti';
END;
$$;

-- ============================================================================
-- 0015: „iba svoje“ (RLS), úprava Aktívnych OOM, import, mazanie
-- Dočasná rola crm_rls_test (checks_zakaznici.sql) – bez práv vlastníka, ako aplikácia.
-- Používatelia: 0011 Sales_internal (vlastní Alfu), 1002 / 1003 Sales_external A / B,
-- nový Servis 3901 a Marketing 3902; admin = peter@greenlogy.com (0006).
-- ============================================================================

INSERT INTO app_user (id, email, name, team_id, status)
SELECT v.id::uuid, v.email, v.name, t.id, 'aktivny'
  FROM (VALUES
    ('00000000-0000-4000-8000-000000003901', 'servis.oom@example.test', 'Servis OOM', 'servis'),
    ('00000000-0000-4000-8000-000000003902', 'marketing.oom@example.test', 'Marketing OOM', 'marketing')
  ) AS v (id, email, name, team_code)
  JOIN team t ON t.code = v.team_code;
INSERT INTO app_user_org (user_id, org_id) VALUES
  ('00000000-0000-4000-8000-000000003901', crm_default_org()),
  ('00000000-0000-4000-8000-000000003902', crm_default_org());

-- Údaje externého A a B (ako vlastník): OOM firmy A (Aktívne), domácnosť B, OOM domácnosti A na prepis
INSERT INTO contact (id, first_name, last_name, email, is_household, owner_id) VALUES
  ('00000000-0000-4000-8000-000000003911', 'Domácnosť', 'Externého B', 'dom.ext.b@example.test', true,
   '00000000-0000-4000-8000-000000001003');
SELECT pg_temp.t_oom('00000000-0000-4000-8000-000000003921', '00000000-0000-4000-8000-000000001801', NULL,
                     '24ZZS000TEST720M', 'spotreba', 'aktivne');
SELECT pg_temp.t_oom('00000000-0000-4000-8000-000000003922', NULL, '00000000-0000-4000-8000-000000001802',
                     '24ZZS000TEST721K', 'spotreba', 'aktivne');

GRANT SELECT, INSERT, UPDATE ON oom, oom_customer, oom_device, oom_contact, oom_import, oom_planned_change TO crm_rls_test;
GRANT DELETE ON oom_device, oom_contact TO crm_rls_test;
GRANT SELECT ON supplier_switch, oom_v, contact_oom_v, org, lookup_value, lookup_list, team_permission,
                deal_oom, contract_price, offer_item, conversation, deal, deal_contact TO crm_rls_test;
SET LOCAL ROLE crm_rls_test;

-- O12. Externý A: iba svoje OOM, cudzie EIC nenájde, založí iba svojmu zákazníkovi
DO $$
DECLARE
  r record;
  n integer;
BEGIN
  PERFORM set_config('app.require_user', 'on', true);
  ASSERT (SELECT count(*) FROM oom) = 0, 'aplikácia bez používateľa vidí OOM';

  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-000000001002', true);
  ASSERT (SELECT array_agg(eic ORDER BY eic) FROM oom) = '{24ZZS000TEST720M,24ZZS000TEST721K}',
         format('externý A: OOM %s', (SELECT array_agg(eic ORDER BY eic) FROM oom));
  ASSERT (SELECT count(*) FROM oom_v) = 2, 'externý A: oom_v iba svoje';
  ASSERT NOT EXISTS (SELECT 1 FROM oom WHERE eic = '24ZZS000TEST001H'), 'externý A: cudzie EIC nenájde';
  SELECT * INTO r FROM oom_eic_check('24zzs000test001h');
  ASSERT r.oom_exists AND r.oom_id IS NULL AND r.owner_name = 'Testovací Obchodník', 'duplicita EIC: iba existuje + vlastník';
  SELECT * INTO r FROM oom_eic_check('24ZZS000TEST720M');
  ASSERT r.oom_id = '00000000-0000-4000-8000-000000003921', 'duplicita EIC: svoje OOM s id';
  ASSERT (SELECT count(*) FROM oom_device) = 0 AND (SELECT count(*) FROM oom_contact) = 0, 'externý A: cudzie zariadenia a osoby nie';

  -- založí OOM svojmu zákazníkovi, cudziemu nie
  PERFORM pg_temp.t_oom('00000000-0000-4000-8000-000000003923', '00000000-0000-4000-8000-000000001801', NULL,
                        '24ZZS000TEST722I', 'spotreba', 'pripravovane');
  BEGIN
    PERFORM pg_temp.t_oom(NULL, '00000000-0000-4000-8000-000000000101', NULL, '24ZZS000TEST723G', 'spotreba', 'pripravovane');
    RAISE EXCEPTION 'CHYBA: externý založil OOM cudziemu zákazníkovi';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  -- Pripravované svoje upraví; Aktívne nie (nemá právo upravovať Aktívne OOM)
  UPDATE oom SET name = 'Hala 2' WHERE id = '00000000-0000-4000-8000-000000003923';
  BEGIN
    UPDATE oom SET breaker_a = 63 WHERE id = '00000000-0000-4000-8000-000000003921';
    RAISE EXCEPTION 'CHYBA: externý upravil Aktívne OOM';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    INSERT INTO oom_device (oom_id, device_type) VALUES ('00000000-0000-4000-8000-000000003921', 'wallbox');
    RAISE EXCEPTION 'CHYBA: externý pridal zariadenie Aktívnemu OOM';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  INSERT INTO oom_device (oom_id, device_type) VALUES ('00000000-0000-4000-8000-000000003923', 'wallbox');

  -- cudzie OOM nezmení (0 riadkov), na cudzieho zákazníka neprepíše
  UPDATE oom SET name = 'Hack' WHERE id = '00000000-0000-4000-8000-000000000301';
  GET DIAGNOSTICS n = ROW_COUNT;
  ASSERT n = 0, 'externý zmenil cudzie OOM';
  BEGIN
    PERFORM oom_transfer('00000000-0000-4000-8000-000000003921', '00000000-0000-4000-8000-000000000101', NULL, '2026-11-01');
    RAISE EXCEPTION 'CHYBA: externý prepísal OOM na cudzieho zákazníka';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  -- import nesmie
  ASSERT NOT crm_can_import('odberne_miesta'), 'externý nesmie importovať';
  BEGIN
    INSERT INTO oom_import (org_id, user_id, file_name, row_count, created_count, updated_count, error_count, status)
    VALUES (crm_default_org(), '00000000-0000-4000-8000-000000001002', 'a.xlsx', 1, 1, 0, 0, 'ulozeny');
    RAISE EXCEPTION 'CHYBA: externý zapísal import';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  -- externý B nevidí nič z A
  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-000000001003', true);
  ASSERT (SELECT count(*) FROM oom) = 0, 'externý B vidí cudzie OOM';
  RAISE NOTICE 'OK: RLS OOM: iba svoje, cudzie EIC iba „existuje“, založí iba svojmu, Aktívne neupraví, prepis na cudzieho nie, import nie';
END;
$$;

-- O13. Interný obchodník, Servis, Marketing; história po prepise
DO $$
DECLARE
  n integer;
BEGIN
  -- interný: vidí všetko, Aktívne neupraví (ani zariadenie), Pripravované áno
  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-000000000011', true);
  ASSERT (SELECT count(*) FROM oom) = (SELECT count(*) FROM oom_v), 'interný: oom aj oom_v';
  ASSERT EXISTS (SELECT 1 FROM oom WHERE id = '00000000-0000-4000-8000-000000003921'), 'interný vidí aj OOM externého';
  BEGIN
    UPDATE oom SET breaker_a = 40 WHERE id = '00000000-0000-4000-8000-000000000301';
    RAISE EXCEPTION 'CHYBA: interný upravil Aktívne OOM';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    INSERT INTO oom_device (oom_id, device_type) VALUES ('00000000-0000-4000-8000-000000000301', 'bateria');
    RAISE EXCEPTION 'CHYBA: interný pridal zariadenie Aktívnemu OOM';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  UPDATE oom SET name = 'Alfa – zdieľanie 2' WHERE id = '00000000-0000-4000-8000-000000000303';
  GET DIAGNOSTICS n = ROW_COUNT;
  ASSERT n = 1, 'interný upraví Pripravované';

  -- Servis: Aktívne upraví, zariadenie pridá; prepíše domácnosť A na domácnosť B (príklad 4)
  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-000000003901', true);
  UPDATE oom SET breaker_a = 40 WHERE id = '00000000-0000-4000-8000-000000000301';
  INSERT INTO oom_device (oom_id, device_type) VALUES ('00000000-0000-4000-8000-000000000301', 'bateria');
  PERFORM oom_transfer('00000000-0000-4000-8000-000000003922', NULL, '00000000-0000-4000-8000-000000003911', '2026-11-01');

  -- Marketing: vidí, nemení (0 riadkov)
  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-000000003902', true);
  ASSERT EXISTS (SELECT 1 FROM oom WHERE id = '00000000-0000-4000-8000-000000000301'), 'marketing vidí';
  UPDATE oom SET name = 'Marketing' WHERE id = '00000000-0000-4000-8000-000000000303';
  GET DIAGNOSTICS n = ROW_COUNT;
  ASSERT n = 0, 'marketing zmenil OOM';

  -- externý A po prepise: OOM ani novú odberateľku nevidí, svoju väzbu (história) áno
  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-000000001002', true);
  ASSERT NOT EXISTS (SELECT 1 FROM oom WHERE id = '00000000-0000-4000-8000-000000003922'), 'A nevidí prepísané OOM';
  ASSERT (SELECT array_agg(status) FROM oom_customer WHERE oom_id = '00000000-0000-4000-8000-000000003922') = '{prepisane}',
         'A vidí iba svoju väzbu (Prepísané), nie novú odberateľku';
  -- externý B vidí OOM aj celú históriu (meno A mu RLS osôb neukáže)
  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-000000001003', true);
  ASSERT (SELECT count(*) FROM oom_customer WHERE oom_id = '00000000-0000-4000-8000-000000003922') = 2, 'B vidí obe väzby';
  ASSERT (SELECT transferred_from_name IS NULL AND customer_name = 'Domácnosť Externého B' FROM oom_v
           WHERE id = '00000000-0000-4000-8000-000000003922'), 'B: meno predošlého zákazníka skryté';
  PERFORM set_config('app.user_id', '', true);
  RAISE NOTICE 'OK: interný (Aktívne nie, Pripravované áno), Servis (Aktívne áno, prepis), Marketing iba číta, história po prepise';
END;
$$;

-- O14. Import (Servis) a mazanie OOM (admin, bez väzieb)
DO $$
DECLARE
  v_import uuid;
  v_admin  uuid;
BEGIN
  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-000000003901', true);
  v_admin := (SELECT id FROM app_user WHERE email = 'peter@greenlogy.com');   -- až s používateľom (RLS)
  ASSERT crm_can_import('odberne_miesta'), 'Servis smie importovať';
  INSERT INTO oom_import (org_id, user_id, file_name, row_count, created_count, updated_count, error_count, status)
  VALUES (crm_default_org(), '00000000-0000-4000-8000-000000003901', 'obec-lietava.xlsx', 52, 46, 3, 3, 'ulozeny')
  RETURNING id INTO v_import;
  PERFORM set_config('app.import_id', v_import::text, true);
  UPDATE oom SET breaker_a = 63 WHERE id = '00000000-0000-4000-8000-000000000301';
  PERFORM set_config('app.import_id', '', true);
  PERFORM set_config('test.import_id', v_import::text, true);
  BEGIN
    UPDATE oom_import SET row_count = 1 WHERE id = v_import;
    IF FOUND THEN RAISE EXCEPTION 'CHYBA: záznam importu sa dal zmeniť'; END IF;
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-000000003902', true);
  ASSERT (SELECT count(*) FROM oom_import) = 0, 'marketing nevidí importy';
  PERFORM set_config('app.user_id', v_admin::text, true);
  ASSERT (SELECT count(*) FROM oom_import) = 1, 'admin vidí importy';

  -- mazanie: Servis nie, admin iba bez väzieb
  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-000000003901', true);
  BEGIN
    PERFORM oom_delete('00000000-0000-4000-8000-000000003923');
    RAISE EXCEPTION 'CHYBA: Servis zmazal OOM';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM set_config('app.user_id', v_admin::text, true);
  BEGIN
    PERFORM oom_delete('00000000-0000-4000-8000-000000000301');
    RAISE EXCEPTION 'CHYBA: zmazané OOM s dealom';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  ASSERT oom_delete('00000000-0000-4000-8000-000000003923') = '24ZZS000TEST722I', 'admin zmazal OOM bez väzieb (aj so zariadením)';
  PERFORM set_config('app.user_id', '', true);
  PERFORM set_config('app.require_user', '', true);
  RAISE NOTICE 'OK: import (právo, záznam sa nemení, viditeľnosť), mazanie OOM iba admin a bez väzieb';
END;
$$;

RESET ROLE;

-- O15. Audit importu a mazania (ako vlastník)
DO $$
BEGIN
  ASSERT EXISTS (SELECT 1 FROM audit_log WHERE table_name = 'oom' AND source = 'import'
                  AND import_id = current_setting('test.import_id')::uuid
                  AND (diff -> 'breaker_a' ->> 'new')::numeric = 63), 'zmena z importu v audite so zdrojom import';
  ASSERT EXISTS (SELECT 1 FROM audit_log WHERE table_name = 'oom' AND action = 'delete'
                  AND diff ->> 'eic' = '24ZZS000TEST722I'), 'zmazané OOM v audite s obsahom';
  ASSERT NOT EXISTS (SELECT 1 FROM oom WHERE id = '00000000-0000-4000-8000-000000003923'), 'OOM zmazané';
  ASSERT (SELECT can_import AND can_edit_active_oom FROM team_permission p JOIN team t ON t.id = p.team_id
           WHERE t.code = 'nakup' AND p.module = 'odberne_miesta'), 'Nákup: import a Aktívne';
  ASSERT (SELECT NOT can_import AND NOT can_edit_active_oom AND edit_scope = 'vsetko' FROM team_permission p
            JOIN team t ON t.id = p.team_id WHERE t.code = 'sales_internal' AND p.module = 'odberne_miesta'),
         'Sales_internal: upravuje, bez importu a Aktívnych';
  BEGIN
    UPDATE team_permission SET can_edit_active_oom = true WHERE module = 'zakaznici';
    RAISE EXCEPTION 'CHYBA: právo Aktívne OOM v inom module';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  RAISE NOTICE 'OK: audit importu a mazania, východiskové práva modulu Odberné miesta';
END;
$$;

-- ============================================================================
-- 0016: plánované zmeny (prepis, odchod, zrušenie k budúcemu dátumu), nočný beh, EIC v histórii
-- ============================================================================

-- O16. Plán odchodu, blokovanie, zmena dátumu, vykonanie nočným behom (ako vlastník = služba)
DO $$
DECLARE
  f  constant uuid := '00000000-0000-4000-8000-000000004001';
  n  constant uuid := '00000000-0000-4000-8000-000000004002';
  p1 constant uuid := '00000000-0000-4000-8000-000000004011';
  p2 constant uuid := '00000000-0000-4000-8000-000000004012';
  p3 constant uuid := '00000000-0000-4000-8000-000000004013';
  p4 constant uuid := '00000000-0000-4000-8000-000000004014';
  v_plan uuid;
  r      jsonb;
BEGIN
  INSERT INTO company (id, name, ico, is_customer) VALUES (f, 'Plánová s.r.o.', '49494949', true);
  INSERT INTO contact (id, first_name, last_name, email, is_household) VALUES (n, 'Nora', 'Nová', 'nora.nova@example.test', true);
  PERFORM pg_temp.t_oom(p1, f, NULL, '24ZZS000TEST730J', 'spotreba', 'aktivne');
  PERFORM pg_temp.t_oom(p2, f, NULL, '24ZZS000TEST731H', 'spotreba', 'aktivne');
  PERFORM pg_temp.t_oom(p3, f, NULL, '24ZZS000TEST732F', 'spotreba', 'aktivne');
  PERFORM pg_temp.t_oom(p4, f, NULL, '24ZZS000TEST733D', 'spotreba', 'aktivne');

  -- odchod k 31. 12. 2027 (posledný deň dodávky): zatiaľ sa nič nemení
  v_plan := oom_plan_change(p1, 'odchod', '2027-12-31');
  ASSERT v_plan IS NOT NULL, 'budúci odchod = plán';
  ASSERT (SELECT status FROM oom WHERE id = p1) = 'aktivne', 'stav sa do termínu nemení';
  ASSERT (SELECT plan_kind = 'odchod' AND plan_date = '2027-12-31' FROM oom_v WHERE id = p1), 'oom_v: plánovaný odchod';

  -- plán blokuje zmenu stavu a prepis, nie úpravu údajov
  BEGIN
    PERFORM oom_set_status(p1, 'zrusene', '2027-01-31');
    RAISE EXCEPTION 'CHYBA: zrušenie pri aktívnom pláne prešlo';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    PERFORM oom_transfer(p1, NULL, n, '2027-02-01');
    RAISE EXCEPTION 'CHYBA: prepis pri aktívnom pláne prešiel';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    PERFORM oom_plan_change(p1, 'zrusenie', '2027-06-30');
    RAISE EXCEPTION 'CHYBA: druhý plán prešiel';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  UPDATE oom SET name = 'Hala s plánom', breaker_a = 32 WHERE id = p1;

  -- zmena dátumu; beh deň pred vykonaním nič, v deň vykonania (deň po poslednom dni dodávky) áno
  PERFORM oom_plan_reschedule(v_plan, '2027-06-30');
  r := oom_daily_run_at('2027-06-30');
  ASSERT (r ->> 'plany_vykonane')::int = 0, format('30. 6. ešte nie: %s', r);
  r := oom_daily_run_at('2027-07-01');
  ASSERT (r ->> 'plany_vykonane')::int = 1, format('1. 7. vykonané: %s', r);
  ASSERT (SELECT status FROM oom WHERE id = p1) = 'odidene', 'OOM Odídené';
  ASSERT (SELECT valid_to FROM oom_customer WHERE oom_id = p1 AND end_reason = 'odchod') = '2027-06-30', 'posledný deň dodávky 30. 6.';
  ASSERT (SELECT status FROM oom_planned_change WHERE id = v_plan) = 'vykonana', 'plán vykonaný';
  ASSERT EXISTS (SELECT 1 FROM audit_log WHERE table_name = 'oom_planned_change' AND record_id = v_plan
                  AND source = 'system' AND diff -> 'status' ->> 'new' = 'vykonana'), 'vykonanie v audite ako Systém';

  -- prepis od 1. 3. 2027 (prvý deň nového odberateľa)
  v_plan := oom_plan_change(p2, 'prepis', '2027-03-01', NULL, n);
  r := oom_daily_run_at('2027-02-28');
  ASSERT (SELECT person_id IS NULL FROM oom WHERE id = p2), 'pred termínom ostáva firma';
  r := oom_daily_run_at('2027-03-01');
  ASSERT (SELECT person_id FROM oom WHERE id = p2) = n, 'od 1. 3. Nová';
  ASSERT (SELECT valid_from FROM oom_customer WHERE oom_id = p2 AND person_id = n) = '2027-03-01', 'väzba od 1. 3.';

  -- dátum v minulosti = hneď, bez plánu
  ASSERT oom_plan_change(p3, 'zrusenie', crm_today() - 1) IS NULL, 'minulý dátum: hneď';
  ASSERT (SELECT status FROM oom WHERE id = p3) = 'zrusene', 'zrušené hneď';
  ASSERT NOT EXISTS (SELECT 1 FROM oom_planned_change WHERE oom_id = p3), 'bez plánu';

  -- kontroly zadania
  BEGIN
    PERFORM oom_plan_change(p4, 'prepis', '2027-05-01', f, NULL);
    RAISE EXCEPTION 'CHYBA: prepis na toho istého zákazníka prešiel';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    PERFORM oom_plan_change(p4, 'odchod', '2020-01-01');
    RAISE EXCEPTION 'CHYBA: odchod pred začiatkom väzby prešiel';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  -- zlyhaný plán: OOM medzitým odišlo iným spôsobom (tu priamo v databáze) → „zlyhal“, stav bez zmeny
  v_plan := oom_plan_change(p4, 'prepis', '2027-05-01', NULL, n);
  UPDATE oom_customer SET valid_to = '2026-12-31', end_reason = 'odchod', status = 'odidene'
   WHERE oom_id = p4 AND valid_to IS NULL;
  r := oom_daily_run_at('2027-05-01');
  ASSERT (r ->> 'plany_zlyhali')::int = 1, format('zlyhal: %s', r);
  ASSERT (SELECT status = 'zlyhala' AND error LIKE 'Prepísať sa dá iba%' FROM oom_planned_change WHERE id = v_plan), 'dôvod zlyhania';
  ASSERT (SELECT plan_failed AND plan_kind IS NULL FROM oom_v WHERE id = p4), 'oom_v: plán zlyhal';
  ASSERT (SELECT person_id IS NULL AND status = 'odidene' FROM oom WHERE id = p4), 'stav bez zmeny';
  PERFORM oom_plan_cancel(v_plan);
  ASSERT NOT (SELECT plan_failed FROM oom_v WHERE id = p4), 'zrušený zlyhaný plán sa už neukazuje';
  RAISE NOTICE 'OK: plán odchodu a prepisu, blokovanie stavu (nie údajov), zmena dátumu, nočný beh, minulý dátum hneď, zlyhaný plán';
END;
$$;

SET LOCAL ROLE crm_rls_test;

-- O17. Externý A: plán na svojom OOM, nie prepis na cudzieho; B jeho plán nevidí; EIC v histórii
DO $$
DECLARE
  v_plan uuid;
  r      record;
BEGIN
  PERFORM set_config('app.require_user', 'on', true);
  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-000000001002', true);
  BEGIN
    PERFORM oom_plan_change('00000000-0000-4000-8000-000000003921', 'prepis', '2027-02-01',
                            '00000000-0000-4000-8000-000000000101', NULL);
    RAISE EXCEPTION 'CHYBA: externý naplánoval prepis na cudzieho zákazníka';
  EXCEPTION WHEN no_data_found THEN NULL;   -- cudzieho zákazníka nevidí: „Nový odberateľ neexistuje“
  END;
  BEGIN
    PERFORM oom_plan_change('00000000-0000-4000-8000-000000000301', 'odchod', '2027-12-31');
    RAISE EXCEPTION 'CHYBA: externý naplánoval odchod cudzieho OOM';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  v_plan := oom_plan_change('00000000-0000-4000-8000-000000003921', 'odchod', '2027-12-31');
  ASSERT (SELECT count(*) FROM oom_planned_change) = 1, 'A vidí svoj plán';
  PERFORM oom_plan_reschedule(v_plan, '2027-11-30');
  BEGIN
    PERFORM oom_daily_run_at('2027-12-01');
    RAISE EXCEPTION 'CHYBA: aplikácia spustila beh k dátumu';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  -- história po prepise (O13): A vidí EIC OOM, ktoré už patrí B
  SELECT * INTO r FROM oom_brief('00000000-0000-4000-8000-000000003922');
  ASSERT r.eic = '24ZZS000TEST721K', 'A: EIC v histórii po prepise';
  ASSERT NOT EXISTS (SELECT 1 FROM oom_brief('00000000-0000-4000-8000-000000000301')), 'A: cudzie OOM bez väzby nie';

  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-000000001003', true);
  ASSERT (SELECT count(*) FROM oom_planned_change) = 0, 'B nevidí plán A';
  BEGIN
    PERFORM oom_plan_cancel(v_plan);
    RAISE EXCEPTION 'CHYBA: B zrušil plán A';
  EXCEPTION WHEN no_data_found THEN NULL;
  END;

  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-000000001002', true);
  PERFORM oom_plan_cancel(v_plan);
  ASSERT (SELECT status FROM oom_planned_change WHERE id = v_plan) = 'zrusena', 'A zrušil svoj plán';
  PERFORM set_config('app.user_id', '', true);
  PERFORM set_config('app.require_user', '', true);
  RAISE NOTICE 'OK: plány a „iba svoje“ (vlastné áno, cudzie nie, beh k dátumu nie), EIC v histórii po prepise';
END;
$$;

RESET ROLE;
