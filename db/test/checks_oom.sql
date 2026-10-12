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
