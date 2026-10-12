-- Kontroly modulu Zákazníci (migrácie 0004 a 0005) nad dátami zo seed.sql + vlastnými.
-- Všetko je vymyslené. Pevné uuid s prefixom 00000000-0000-4000-8000-00000001….
-- Spúšťa sa iba cez db/test/run.sh (transakcia sa na konci vráti, aj dočasná rola crm_rls_test).

-- Externý tím je v databáze zatiaľ zamknutý (crm_external_ready = false, 0006). Test ho odomkne
-- iba vo svojej transakcii, ktorá sa na konci vráti.
CREATE OR REPLACE FUNCTION crm_external_ready() RETURNS boolean LANGUAGE sql IMMUTABLE AS $$ SELECT true $$;

-- Používatelia: vedenie (tím CEO), dvaja externí obchodníci (tím Sales_external)
INSERT INTO app_user (id, email, name, team_id, status)
SELECT v.id::uuid, v.email, v.name, t.id, 'aktivny'
  FROM (VALUES
    ('00000000-0000-4000-8000-000000001001', 'vedenie@example.test', 'Testovacie Vedenie', 'ceo'),
    ('00000000-0000-4000-8000-000000001002', 'externy.a@example.test', 'Externý A', 'sales_external'),
    ('00000000-0000-4000-8000-000000001003', 'externy.b@example.test', 'Externý B', 'sales_external')
  ) AS v (id, email, name, team_code)
  JOIN team t ON t.code = v.team_code;
INSERT INTO app_user_org (user_id, org_id)
SELECT u.id, crm_default_org() FROM app_user u
 WHERE u.id IN ('00000000-0000-4000-8000-000000001002', '00000000-0000-4000-8000-000000001003');

-- Štádiá B2C pipeline: otvorené a prehraté
INSERT INTO pipeline_stage (id, pipeline_id, name, sort_order, probability, outcome) VALUES
  ('00000000-0000-4000-8000-000000001021', '00000000-0000-4000-8000-000000000502', 'Ponuka',    2, 0.50, 'otvoreny'),
  ('00000000-0000-4000-8000-000000001022', '00000000-0000-4000-8000-000000000502', 'Prehraté',  7, 0.00, 'prehrany');

-- Z1. Firma: povinný názov, aspoň jedno označenie, viac označení naraz
DO $$
BEGIN
  BEGIN
    INSERT INTO company (name, ico) VALUES ('  ', '11111111');
    RAISE EXCEPTION 'CHYBA: firma s prázdnym názvom prešla';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK: firma s prázdnym názvom odmietnutá';
  END;
  BEGIN
    INSERT INTO company (name, ico, is_customer) VALUES ('Bez označenia', '11111112', false);
    RAISE EXCEPTION 'CHYBA: firma bez označenia prešla';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK: firma bez označenia (zákazník/partner/dodávateľ) odmietnutá';
  END;
  INSERT INTO company (id, name, ico, is_customer, is_partner) VALUES
    ('00000000-0000-4000-8000-000000001101', 'Partner a zákazník s.r.o.', '11111113', true, true);
  INSERT INTO company (id, name, ico, is_customer, is_partner) VALUES
    ('00000000-0000-4000-8000-000000001102', 'Iba partner s.r.o.', '11111114', false, true);
  ASSERT (SELECT status FROM company WHERE id = '00000000-0000-4000-8000-000000001101') = 'marketingovy_kontakt',
         'nový zákazník má mať stav marketingovy_kontakt';
  ASSERT (SELECT status FROM company WHERE id = '00000000-0000-4000-8000-000000001102') IS NULL,
         'partner, ktorý nie je zákazník, nemá stav';
  RAISE NOTICE 'OK: firma môže byť partner aj zákazník; nový zákazník = marketingový kontakt, partner bez stavu';
END;
$$;

-- Z2. Osoba: meno, priezvisko, e-mail alebo telefón, tvar e-mailu, povinné is_household
DO $$
BEGIN
  BEGIN
    INSERT INTO contact (first_name, email, is_household) VALUES ('Bez', 'bez@example.test', true);
    RAISE EXCEPTION 'CHYBA: osoba bez priezviska prešla';
  EXCEPTION WHEN not_null_violation THEN
    RAISE NOTICE 'OK: osoba bez priezviska odmietnutá';
  END;
  BEGIN
    INSERT INTO contact (first_name, last_name, is_household) VALUES ('Bez', 'Kontaktu', true);
    RAISE EXCEPTION 'CHYBA: osoba bez e-mailu a telefónu prešla';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK: osoba bez e-mailu a telefónu odmietnutá';
  END;
  BEGIN
    INSERT INTO contact (first_name, last_name, email, is_household) VALUES ('Zlý', 'Email', 'nie-je-email', true);
    RAISE EXCEPTION 'CHYBA: zlý e-mail prešiel';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK: e-mail bez tvaru x@y.z odmietnutý';
  END;
  BEGIN
    INSERT INTO contact (first_name, last_name, email) VALUES ('Bez', 'Príznaku', 'priznak@example.test');
    RAISE EXCEPTION 'CHYBA: osoba bez is_household prešla';
  EXCEPTION WHEN not_null_violation THEN
    RAISE NOTICE 'OK: osoba bez rozhodnutia domácnosť/kontakt vo firme odmietnutá';
  END;
  BEGIN
    INSERT INTO contact (first_name, last_name, email, is_household, marketing_opt_out_at)
    VALUES ('Bez', 'Zdroja', 'zdroj@example.test', true, now());
    RAISE EXCEPTION 'CHYBA: nechce marketing bez zdroja prešlo';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK: „nechce marketing“ bez zdroja odmietnuté';
  END;
END;
$$;

-- Z3. Normalizácia telefónu
DO $$
BEGIN
  ASSERT normalize_phone('0905 123 456')      = '+421905123456', '0905 123 456';
  ASSERT normalize_phone('+421 905 123 456')  = '+421905123456', '+421 905 123 456';
  ASSERT normalize_phone('00421 905/123-456') = '+421905123456', '00421 905/123-456';
  ASSERT normalize_phone('421905123456')      = '+421905123456', '421905123456';
  ASSERT normalize_phone('905123456')         = '+421905123456', '905123456';
  ASSERT normalize_phone('02/123 456 78')     = '+421212345678', '02/123 456 78';
  ASSERT normalize_phone('+420 601 123 456')  = '+420601123456', '+420 601 123 456';
  ASSERT normalize_phone('  ') IS NULL, 'prázdny telefón';
  RAISE NOTICE 'OK: telefón v rôznych zápisoch → +421905123456';
END;
$$;

-- Z4. Duplicity: e-mail bez ohľadu na veľkosť písmen, telefón v inom zápise, IČO bez núl
DO $$
DECLARE
  r record;
BEGIN
  INSERT INTO contact (id, first_name, last_name, mobile, is_household) VALUES
    ('00000000-0000-4000-8000-000000001201', 'Mária', 'Telefónna', '0905 123 456', true);

  SELECT * INTO r FROM contact_duplicate_check(' JAN.Testovaci@EXAMPLE.test ', NULL);
  ASSERT r.match_on = 'email' AND r.contact_id = '00000000-0000-4000-8000-000000000201', 'duplicita e-mailu';
  ASSERT r.owner_name = 'Testovací Obchodník', 'vlastník pri duplicite e-mailu';

  SELECT * INTO r FROM contact_duplicate_check(NULL, '+421 905 123 456');
  ASSERT r.match_on = 'telefon' AND r.contact_id = '00000000-0000-4000-8000-000000001201', 'duplicita telefónu';

  ASSERT NOT EXISTS (SELECT 1 FROM contact_duplicate_check('nikto@example.test', '0911 000 000')), 'falošná duplicita';

  SELECT * INTO r FROM company_ico_check('SK', '123456');
  ASSERT r.company_exists AND r.company_id = '00000000-0000-4000-8000-000000000101', 'IČO 123456 = 00123456';
  ASSERT NOT EXISTS (SELECT 1 FROM company_ico_check('SK', '99999999')), 'neexistujúce IČO';

  -- rovnaký e-mail sa dá uložiť (iba upozornenie)
  INSERT INTO contact (first_name, last_name, email, is_household)
  VALUES ('Ján', 'Druhý', 'jan.testovaci@example.test', true);
  RAISE NOTICE 'OK: duplicita podľa e-mailu, telefónu aj IČO nájdená; rovnaký e-mail sa nevynucuje';
END;
$$;

-- Z5. Roly vo firme
DO $$
BEGIN
  ASSERT (SELECT roles FROM company_contact
           WHERE company_id = '00000000-0000-4000-8000-000000000101'
             AND contact_id = '00000000-0000-4000-8000-000000000202') = '{statutar,decision_maker}',
         'Eva má 2 roly v Alfe';
  BEGIN
    UPDATE company_contact SET roles = '{riaditel}'
     WHERE company_id = '00000000-0000-4000-8000-000000000101';
    RAISE EXCEPTION 'CHYBA: neznáma rola prešla';
  EXCEPTION WHEN foreign_key_violation THEN
    RAISE NOTICE 'OK: osoba má vo firme viac rolí, rola mimo číselníka odmietnutá';
  END;
END;
$$;

-- Z6. Domácnosť: kontakt vo firme sa stane domácnosťou, keď je zákazníkom na deale
DO $$
BEGIN
  ASSERT (SELECT status FROM contact WHERE id = '00000000-0000-4000-8000-000000000202') IS NULL,
         'kontakt vo firme nemá stav';
  INSERT INTO deal (id, person_id, pipeline_id, stage_id, name) VALUES
    ('00000000-0000-4000-8000-000000001301', '00000000-0000-4000-8000-000000000202',
     '00000000-0000-4000-8000-000000000502', '00000000-0000-4000-8000-000000001021', 'Eva – dom');
  ASSERT (SELECT is_household FROM contact WHERE id = '00000000-0000-4000-8000-000000000202'),
         'Eva má byť domácnosť';
  ASSERT (SELECT status::text || '/' || status_source::text FROM contact
           WHERE id = '00000000-0000-4000-8000-000000000202') = 'marketingovy_kontakt/vypocet',
         'nová domácnosť má východiskový stav';
  DELETE FROM deal WHERE id = '00000000-0000-4000-8000-000000001301';
  ASSERT (SELECT is_household FROM contact WHERE id = '00000000-0000-4000-8000-000000000202'),
         'is_household sa nesmie automaticky zrušiť';
  RAISE NOTICE 'OK: osoba na deale sa stane domácnosťou (Ján Kováč, starosta), príznak sa nezruší';
END;
$$;

-- Z7. Výpočet stavu – pani Nováková (príklad 10.1)
DO $$
DECLARE
  n   constant uuid := '00000000-0000-4000-8000-000000001401';
  t   constant date := '2026-10-11';
BEGIN
  INSERT INTO contact (id, first_name, last_name, email, is_household) VALUES
    (n, 'Anna', 'Nováková', 'anna.novakova@example.test', true);
  ASSERT customer_status_calc(NULL, n, t) = 'marketingovy_kontakt', 'bez dealu';

  INSERT INTO deal (id, person_id, pipeline_id, stage_id, name) VALUES
    ('00000000-0000-4000-8000-000000001411', n, '00000000-0000-4000-8000-000000000502',
     '00000000-0000-4000-8000-000000001021', 'Nováková – dodávka');
  ASSERT customer_status_calc(NULL, n, t) = 'zaujemca', 'otvorený deal';

  INSERT INTO offer (id, deal_id) VALUES ('00000000-0000-4000-8000-000000001412', '00000000-0000-4000-8000-000000001411');
  ASSERT customer_status_calc(NULL, n, t) = 'zaujemca', 'koncept ponuky nie je odoslaná ponuka';
  UPDATE offer SET status = 'odoslana', sent_at = '2026-10-10 10:00+02' WHERE id = '00000000-0000-4000-8000-000000001412';
  ASSERT customer_status_calc(NULL, n, t) = 'ponuka', 'odoslaná ponuka';

  INSERT INTO contract (id, deal_id, person_id, number, status, valid_from) VALUES
    ('00000000-0000-4000-8000-000000001413', '00000000-0000-4000-8000-000000001411', n,
     'TEST-NOVAKOVA', 'podpisana', '2027-01-01');
  ASSERT customer_status_calc(NULL, n, t) = 'cakajuci_zakaznik', 'podpísaná zmluva od 1. 1. 2027';
  ASSERT customer_status_calc(NULL, n, '2027-01-01') <> 'cakajuci_zakaznik', 'od účinnosti už nie čakajúci';

  PERFORM pg_temp.t_oom('00000000-0000-4000-8000-000000001414', NULL, n, '24ZZS000TEST4011', 'spotreba', 'pripravovane');
  ASSERT customer_status_calc(NULL, n, t) = 'cakajuci_zakaznik', 'pripravované OOM';
  PERFORM oom_set_status('00000000-0000-4000-8000-000000001414', 'aktivne');
  ASSERT customer_status_calc(NULL, n, t) = 'zakaznik', 'aktívne OOM';
  ASSERT NOT customer_is_former_calc(NULL, n), 'Nováková nie je bývalá';
  RAISE NOTICE 'OK: Nováková: marketingový kontakt → záujemca → ponuka → čakajúci (zmluva, OOM Pripravované) → zákazník';
END;
$$;

-- Z8. Výpočet stavu – bývalý, vracajúci sa, prepadnutý záujemca, zrušený, súbeh
DO $$
DECLARE
  h   constant uuid := '00000000-0000-4000-8000-000000001501';  -- Horváth, odišiel
  k   constant uuid := '00000000-0000-4000-8000-000000001504';  -- nový odberateľ po prepise
  l   constant uuid := '00000000-0000-4000-8000-000000001502';  -- Lukáč, prepadnutý deal
  z   constant uuid := '00000000-0000-4000-8000-000000001503';  -- zrušená firma
  t   constant date := '2026-10-11';
BEGIN
  INSERT INTO contact (id, first_name, last_name, email, is_household) VALUES
    (h, 'Peter', 'Horváth', 'peter.horvath@example.test', true),
    (l, 'Lukáš', 'Lukáč', 'lukas.lukac@example.test', true),
    (k, 'Klára', 'Nová', 'klara.nova@example.test', true);
  INSERT INTO company (id, name, ico) VALUES (z, 'Zbúraná s.r.o.', '22222222');

  -- bývalý: jediné OOM odídené
  PERFORM pg_temp.t_oom(NULL, NULL, h, '24ZZS000TEST501Y', 'spotreba', 'odidene');
  ASSERT customer_status_calc(NULL, h, t) = 'byvaly_zakaznik', 'odídené OOM';
  ASSERT customer_is_former_calc(NULL, h), 'Horváth je bývalý';

  -- bývalý s novou ponukou → Ponuka s príznakom bývalý (čl. 12)
  INSERT INTO deal (id, person_id, pipeline_id, stage_id, name) VALUES
    ('00000000-0000-4000-8000-000000001511', h, '00000000-0000-4000-8000-000000000502',
     '00000000-0000-4000-8000-000000001021', 'Horváth – návrat');
  INSERT INTO offer (deal_id, status, sent_at) VALUES ('00000000-0000-4000-8000-000000001511', 'odoslana', now());
  ASSERT customer_status_calc(NULL, h, t) = 'ponuka', 'bývalý s ponukou';

  -- vracajúci sa: nová zmluva do budúcna → Čakajúci s príznakom bývalý (čl. 13)
  INSERT INTO contract (deal_id, person_id, number, status, valid_from) VALUES
    ('00000000-0000-4000-8000-000000001511', h, 'TEST-HORVATH', 'caka_na_zaradenie', '2027-03-01');
  ASSERT customer_status_calc(NULL, h, t) = 'cakajuci_zakaznik', 'vracajúci sa zákazník';
  ASSERT customer_is_former_calc(NULL, h), 'vracajúci sa ostáva bývalý';

  -- prepadnutý záujemca, nikdy nebol zákazník → marketingový kontakt (čl. 12)
  INSERT INTO deal (person_id, pipeline_id, stage_id, name) VALUES
    (l, '00000000-0000-4000-8000-000000000502', '00000000-0000-4000-8000-000000001022', 'Lukáč – prehraté');
  ASSERT customer_status_calc(NULL, l, t) = 'marketingovy_kontakt', 'prepadnutý deal';

  -- zrušený: všetky OOM zrušené alebo prepísané
  PERFORM pg_temp.t_oom(NULL, z, NULL, '24ZZS000TEST502W', 'spotreba', 'zrusene');
  PERFORM oom_transfer(pg_temp.t_oom(NULL, z, NULL, '24ZZS000TEST503U', 'spotreba', 'aktivne'), NULL, k, '2026-01-01');
  ASSERT customer_status_calc(z, NULL, t) = 'zruseny_zakaznik', 'všetky OOM zrušené/prepísané';

  -- súbeh: Alfa má aktívne OOM aj zmluvu od 2027 → ostáva Zákazník (príklad 10.2)
  ASSERT customer_status_calc('00000000-0000-4000-8000-000000000101', NULL, t) = 'zakaznik', 'Alfa';

  BEGIN
    PERFORM customer_status_calc(z, h, t);
    RAISE EXCEPTION 'CHYBA: výpočet pre firmu aj osobu naraz prešiel';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM LIKE 'CHYBA%' THEN RAISE; END IF;
  END;
  RAISE NOTICE 'OK: bývalý, bývalý s ponukou, vracajúci sa (čakajúci + bývalý), prepadnutý, zrušený, súbeh';
END;
$$;

-- Z9. Uložený stav: čas zmeny a príznak bývalý
DO $$
BEGIN
  UPDATE contact SET status_changed_at = '2026-01-01 00:00+01'
   WHERE id = '00000000-0000-4000-8000-000000001501';
  UPDATE contact SET status = 'byvaly_zakaznik', status_source = 'hubspot'
   WHERE id = '00000000-0000-4000-8000-000000001501';
  ASSERT (SELECT is_former_customer AND status_changed_at = now() FROM contact
           WHERE id = '00000000-0000-4000-8000-000000001501'), 'byvaly → is_former_customer, čas zmeny';
  UPDATE contact SET status = 'ponuka' WHERE id = '00000000-0000-4000-8000-000000001501';
  ASSERT (SELECT is_former_customer FROM contact WHERE id = '00000000-0000-4000-8000-000000001501'),
         'príznak bývalý ostáva pri stave Ponuka';
  RAISE NOTICE 'OK: zmena stavu zapíše čas; stav Bývalý nastaví príznak, ktorý ostáva';
END;
$$;

-- Z10. customer_v: živnostník (príklad 10.5), segment, partner, dodávateľ
DO $$
BEGIN
  INSERT INTO company (id, name, ico, is_producer) VALUES
    ('00000000-0000-4000-8000-000000001601', 'Ján Kováč – stolárstvo', '33333333', true);
  INSERT INTO contact (id, first_name, last_name, phone, is_household) VALUES
    ('00000000-0000-4000-8000-000000001602', 'Ján', 'Kováč', '0907 111 222', true);
  INSERT INTO company_contact (company_id, contact_id, is_main_contact, roles) VALUES
    ('00000000-0000-4000-8000-000000001601', '00000000-0000-4000-8000-000000001602', true, '{statutar}');

  ASSERT (SELECT count(*) FROM customer_v WHERE name LIKE 'Ján Kováč%') = 2, 'Kováč: 2 riadky';
  ASSERT (SELECT segment_label FROM customer_v WHERE id = '00000000-0000-4000-8000-000000001601') = 'Firma · výrobca',
         'segment Firma · výrobca';
  ASSERT (SELECT segment_label FROM customer_v WHERE id = '00000000-0000-4000-8000-000000001602') = 'Domácnosť',
         'segment Domácnosť';
  ASSERT EXISTS (SELECT 1 FROM customer_v WHERE id = '00000000-0000-4000-8000-000000001101'), 'partner a zákazník je v zozname';
  ASSERT NOT EXISTS (SELECT 1 FROM customer_v WHERE id = '00000000-0000-4000-8000-000000001102'), 'iba partner nie je v zozname';
  ASSERT NOT EXISTS (SELECT 1 FROM customer_v WHERE id = '00000000-0000-4000-8000-000000000103'), 'iba dodávateľ nie je v zozname';
  ASSERT (SELECT active_oom_count || '/' || annual_mwh FROM customer_v
           WHERE id = '00000000-0000-4000-8000-000000000101') = '1/150.000', 'Alfa: 1 aktívne OOM, 150 MWh';
  RAISE NOTICE 'OK: customer_v: Ján Kováč 2 riadky, segmenty, partner/dodávateľ, počet OOM a MWh';
END;
$$;

-- Z11. Archív: kontakt zrušenej firmy (čl. 13)
DO $$
BEGIN
  UPDATE company SET status = 'zruseny_zakaznik', status_source = 'hubspot'
   WHERE id = '00000000-0000-4000-8000-000000001503';
  INSERT INTO contact (id, first_name, last_name, email, is_household) VALUES
    ('00000000-0000-4000-8000-000000001701', 'Iba', 'Zrušená', 'iba.zrusena@example.test', false),
    ('00000000-0000-4000-8000-000000001702', 'Aj', 'Aktívna', 'aj.aktivna@example.test', false),
    ('00000000-0000-4000-8000-000000001703', 'Zrušená', 'Domácnosť', 'zrusena.domacnost@example.test', true);
  INSERT INTO company_contact (company_id, contact_id) VALUES
    ('00000000-0000-4000-8000-000000001503', '00000000-0000-4000-8000-000000001701'),
    ('00000000-0000-4000-8000-000000001503', '00000000-0000-4000-8000-000000001702'),
    ('00000000-0000-4000-8000-000000000102', '00000000-0000-4000-8000-000000001702');
  UPDATE contact SET status = 'zruseny_zakaznik', status_source = 'hubspot'
   WHERE id = '00000000-0000-4000-8000-000000001703';

  ASSERT (SELECT archived FROM customer_v WHERE id = '00000000-0000-4000-8000-000000001503'), 'zrušená firma v archíve';
  ASSERT (SELECT archived AND NOT marketing_allowed FROM contact_v WHERE id = '00000000-0000-4000-8000-000000001701'),
         'iba kontakt zrušenej firmy je skrytý';
  ASSERT (SELECT NOT archived FROM contact_v WHERE id = '00000000-0000-4000-8000-000000001702'),
         'kontakt s inou aktívnou firmou ostáva';
  ASSERT (SELECT archived FROM contact_v WHERE id = '00000000-0000-4000-8000-000000001703'),
         'zrušená domácnosť je v archíve';
  ASSERT (SELECT NOT archived AND marketing_allowed FROM contact_v WHERE id = '00000000-0000-4000-8000-000000000201'),
         'aktívna domácnosť je viditeľná';

  UPDATE contact SET marketing_opt_out_at = now(), marketing_opt_out_source = 'telefon'
   WHERE id = '00000000-0000-4000-8000-000000000201';
  ASSERT (SELECT NOT marketing_allowed FROM contact_v WHERE id = '00000000-0000-4000-8000-000000000201'),
         'nechce marketing';
  RAISE NOTICE 'OK: archív: zrušená firma a jej výlučný kontakt skryté, kontakt s aktívnou firmou ostáva; nechce marketing';
END;
$$;

-- Z12. Vlastníka mení iba vedenie (tím CEO) a admin
DO $$
BEGIN
  PERFORM set_config('app.user_id', '', true);
  BEGIN
    UPDATE company SET owner_id = '00000000-0000-4000-8000-000000001001'
     WHERE id = '00000000-0000-4000-8000-000000000101';
    RAISE EXCEPTION 'CHYBA: zmena vlastníka bez používateľa prešla';
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'OK: zmena vlastníka bez používateľa (a mimo crm_sync) odmietnutá';
  END;

  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-000000000011', true);  -- obchodník
  BEGIN
    UPDATE contact SET owner_id = NULL WHERE id = '00000000-0000-4000-8000-000000000201';
    RAISE EXCEPTION 'CHYBA: obchodník zmenil vlastníka';
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'OK: obchodník vlastníka nezmení';
  END;
  UPDATE contact SET phone = '0905 999 888' WHERE id = '00000000-0000-4000-8000-000000000201';

  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-000000001001', true);  -- tím CEO
  UPDATE company SET owner_id = '00000000-0000-4000-8000-000000001001'
   WHERE id = '00000000-0000-4000-8000-000000000101';
  ASSERT (SELECT owner_id FROM company WHERE id = '00000000-0000-4000-8000-000000000101')
       = '00000000-0000-4000-8000-000000001001', 'vedenie zmenilo vlastníka';
  UPDATE company SET owner_id = '00000000-0000-4000-8000-000000000011'
   WHERE id = '00000000-0000-4000-8000-000000000101';
  PERFORM set_config('app.user_id', '', true);
  RAISE NOTICE 'OK: vlastníka zmení vedenie; ostatné údaje upraví aj obchodník';
END;
$$;

-- Z13. RLS: externý obchodník = tím Sales_external s „iba svoje“ (čl. 6, 12) – dočasná rola bez práv vlastníka
INSERT INTO company (id, name, ico, owner_id) VALUES
  ('00000000-0000-4000-8000-000000001801', 'Firma Externého A', '44444444', '00000000-0000-4000-8000-000000001002');
INSERT INTO contact (id, first_name, last_name, email, is_household, owner_id) VALUES
  ('00000000-0000-4000-8000-000000001802', 'Domácnosť', 'Externého A', 'dom.ext.a@example.test', true,
   '00000000-0000-4000-8000-000000001002'),
  ('00000000-0000-4000-8000-000000001803', 'Kontakt', 'Firmy A', 'kontakt.a@example.test', false, NULL);
-- Eva je kontaktom aj na firme externého A
INSERT INTO company_contact (company_id, contact_id) VALUES
  ('00000000-0000-4000-8000-000000001801', '00000000-0000-4000-8000-000000001803'),
  ('00000000-0000-4000-8000-000000001801', '00000000-0000-4000-8000-000000000202');

DO $$
BEGIN
  PERFORM set_config('test.companies', (SELECT count(*) FROM company)::text, true);
  PERFORM set_config('test.contacts', (SELECT count(*) FROM contact)::text, true);
END;
$$;

CREATE ROLE crm_rls_test NOLOGIN;
-- PostgreSQL 16+: tvorca roly do nej môže prepnúť, iba ak si ju pridelí s voľbou SET (Neon nie je superuser).
GRANT crm_rls_test TO CURRENT_USER WITH SET TRUE, INHERIT FALSE;
GRANT SELECT, INSERT, UPDATE ON company, contact, company_contact TO crm_rls_test;
GRANT SELECT ON oom, oom_customer, activity, app_user, customer_v, contact_v, custom_field TO crm_rls_test;
GRANT INSERT ON audit_log TO crm_rls_test;
SET LOCAL ROLE crm_rls_test;

DO $$
DECLARE
  r record;
  n integer;
BEGIN
  -- rola bez povinného používateľa (Cockpit, prototyp) vidí všetko
  ASSERT (SELECT count(*) FROM company) = current_setting('test.companies')::bigint, 'bez používateľa: všetky firmy';

  -- rola aplikácie (app.require_user = on) bez používateľa nevidí nič
  PERFORM set_config('app.require_user', 'on', true);
  ASSERT (SELECT count(*) FROM company) = 0, 'aplikácia bez používateľa vidí firmy';
  ASSERT (SELECT count(*) FROM contact) = 0, 'aplikácia bez používateľa vidí osoby';

  -- interný obchodník vidí všetko
  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-000000000011', true);
  ASSERT (SELECT count(*) FROM company) = current_setting('test.companies')::bigint, 'interný: všetky firmy';
  ASSERT (SELECT count(*) FROM contact) = current_setting('test.contacts')::bigint, 'interný: všetky osoby';

  -- externý A: svoja firma, svoja domácnosť, kontakty svojej firmy (aj Eva)
  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-000000001002', true);
  ASSERT (SELECT array_agg(name ORDER BY name) FROM company) = '{"Firma Externého A"}', 'externý A: firmy';
  ASSERT (SELECT array_agg(last_name ORDER BY last_name) FROM contact) = '{"Externého A","Firmy A",Vzorová}',
         format('externý A: osoby %s', (SELECT array_agg(last_name ORDER BY last_name) FROM contact));
  ASSERT (SELECT count(*) FROM company_contact) = 2, 'externý A: väzby iba svojej firmy (nie Eva v Alfe)';
  ASSERT (SELECT array_agg(name ORDER BY name) FROM customer_v) = '{"Domácnosť Externého A","Firma Externého A"}',
         format('externý A: zoznam Zákazníci %s (Eva je domácnosť, ale nie jeho)', (SELECT array_agg(name ORDER BY name) FROM customer_v));

  -- duplicita: „firma/osoba už existuje“ + vlastník, bez údajov
  SELECT * INTO r FROM company_ico_check('SK', '00123456');
  ASSERT r.company_exists AND r.company_id IS NULL AND r.owner_name = 'Testovací Obchodník', 'externý: cudzie IČO';
  SELECT * INTO r FROM company_ico_check('SK', '44444444');
  ASSERT r.company_id = '00000000-0000-4000-8000-000000001801', 'externý: svoje IČO s id';
  -- e-mail majú 2 osoby (Z4), externý nedostane id ani jednej
  ASSERT (SELECT count(*) FILTER (WHERE contact_id IS NULL) || '/' || count(*)
            FROM contact_duplicate_check('jan.testovaci@example.test', NULL)) = '2/2', 'externý: id cudzej osoby';
  ASSERT EXISTS (SELECT 1 FROM contact_duplicate_check('jan.testovaci@example.test', NULL)
                  WHERE owner_name = 'Testovací Obchodník'), 'externý: vlastník cudzej osoby';

  -- cudziu firmu nezmení (0 riadkov), cudzieho vlastníka nezapíše
  UPDATE company SET name = 'Hack' WHERE id = '00000000-0000-4000-8000-000000000101';
  GET DIAGNOSTICS n = ROW_COUNT;
  ASSERT n = 0, 'externý zmenil cudziu firmu';
  BEGIN
    INSERT INTO company (name, ico, owner_id)
    VALUES ('Pre iného', '55555555', '00000000-0000-4000-8000-000000000011');
    RAISE EXCEPTION 'CHYBA: externý založil firmu inému vlastníkovi';
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'OK: externý nezaloží firmu pre iného vlastníka';
  END;
  INSERT INTO company (name, ico, owner_id)
  VALUES ('Nová firma A', '55555556', '00000000-0000-4000-8000-000000001002');

  -- externý B nevidí nič z A
  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-000000001003', true);
  ASSERT (SELECT count(*) FROM company) = 0, 'externý B vidí cudzie firmy';
  ASSERT (SELECT count(*) FROM contact) = 0, 'externý B vidí cudzie osoby';

  PERFORM set_config('app.user_id', '', true);
  PERFORM set_config('app.require_user', '', true);
  RAISE NOTICE 'OK: RLS: externý vidí iba svoje, duplicita bez údajov, aplikácia bez používateľa nevidí nič';
END;
$$;

RESET ROLE;
