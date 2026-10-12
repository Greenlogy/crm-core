-- Testovacie dáta modulu Odberné miesta pre Test (Neon dev) – iba vymyslené údaje.
-- 10 zákazníkov a 20 OOM so znakom „TEST“: všetky stavy, prepis, odchod a návrat, zaseknutý prechod,
-- OOM bez povinných údajov, firma s FVE (výrobca), zariadenia, kontaktná osoba pri OOM.
-- Spúšťa sa iba cez db/test-data/oom-test.sh (jedna transakcia). Zmazanie: oom-test-delete.sql.
-- Pevné id s predponou 7e570000-… (7e57 = „test“), aby sa dali presne zmazať.

\set ON_ERROR_STOP on
\o /dev/null
BEGIN;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM oom WHERE id::text LIKE '7e570000-%')
     OR EXISTS (SELECT 1 FROM company WHERE id::text LIKE '7e570000-%')
     OR EXISTS (SELECT 1 FROM contact WHERE id::text LIKE '7e570000-%') THEN
    RAISE EXCEPTION 'Testovacie dáta OOM už existujú. Najprv ich zmaž (oom-test.sh dev zmaz).';
  END IF;
END;
$$;

-- EIC s platnou kontrolnou číslicou: '24ZZS9TEST' + 5 číslic + kontrolný znak
-- (ak by kontrolný znak vyšiel „-“, ktorý na konci nesmie byť, použije sa predpona '24ZZS9TESX')
CREATE FUNCTION pg_temp.eic(n integer) RETURNS text LANGUAGE plpgsql AS $f$
DECLARE
  b text;
  c text;
BEGIN
  FOREACH b IN ARRAY ARRAY['24ZZS9TEST', '24ZZS9TESX'] LOOP
    FOREACH c IN ARRAY string_to_array('0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ', NULL) LOOP
      IF eic_is_valid(b || lpad(n::text, 5, '0') || c) THEN RETURN b || lpad(n::text, 5, '0') || c; END IF;
    END LOOP;
  END LOOP;
  RAISE EXCEPTION 'EIC pre % bez platnej kontrolnej číslice', n;
END;
$f$;

CREATE FUNCTION pg_temp.id(n integer) RETURNS uuid LANGUAGE sql IMMUTABLE AS $f$
  SELECT ('7e570000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid
$f$;

-- OOM s povinnými údajmi pre Aktívne (pds/sadzba podľa parametra)
CREATE FUNCTION pg_temp.oom(p_n integer, p_company integer, p_person integer, p_type oom_type, p_status oom_status,
                            p_name text, p_street text, p_city text, p_zip text, p_pds text, p_tariff text,
                            p_from date, p_vt numeric, p_nt numeric, p_feed numeric DEFAULT NULL)
RETURNS uuid LANGUAGE plpgsql AS $f$
BEGIN
  INSERT INTO oom (id, company_id, person_id, eic, type, status, name, address_street, address_city, address_zip,
                   pds, pds_tariff, voltage_level, metering_type, phases, breaker_a, supply_from,
                   planned_consumption_vt_mwh, planned_consumption_nt_mwh, planned_feed_in_mwh,
                   billing_period, advance_payment_method, switch_notice_required, switch_confirmed_on)
  VALUES (pg_temp.id(p_n), CASE WHEN p_company IS NOT NULL THEN pg_temp.id(p_company) END,
          CASE WHEN p_person IS NOT NULL THEN pg_temp.id(p_person) END,
          pg_temp.eic(p_n), p_type, p_status, p_name, p_street, p_city, p_zip,
          p_pds, p_tariff, 'nn', 'c', 3, 25, p_from, p_vt, p_nt, p_feed,
          'rocne_s_odkladom', 'splatkovy_kalendar_11_mesiacov',
          false, CASE WHEN p_status = 'aktivne' THEN p_from - 20 END);
  RETURN pg_temp.id(p_n);
END;
$f$;

-- ---------------------------------------------------------------------------
-- Zákazníci (vlastník Peter; Agro, Stavmont a Zbúraná: Eva)
-- ---------------------------------------------------------------------------

INSERT INTO company (id, name, ico, is_customer, owner_id, address) VALUES
  (pg_temp.id(101), 'TEST Kovovýroba Váh a.s.', '99000101', true,
   (SELECT id FROM app_user WHERE email = 'peter@greenlogy.com'), 'Priemyselná 12, 014 01 Bytča'),
  (pg_temp.id(102), 'TEST Obec Lietava', '99000102', true,
   (SELECT id FROM app_user WHERE email = 'peter@greenlogy.com'), 'Lietava 1, 013 18 Lietava'),
  (pg_temp.id(103), 'TEST Agro Turiec s.r.o.', '99000103', true,
   (SELECT id FROM app_user WHERE email = 'eva@greenlogy.com'), 'Hlavná 5, 040 01 Košice'),
  (pg_temp.id(104), 'TEST Stavmont s.r.o.', '99000104', true,
   (SELECT id FROM app_user WHERE email = 'eva@greenlogy.com'), 'Bratislavská 40, 917 01 Trnava'),
  (pg_temp.id(108), 'TEST Návratová s.r.o.', '99000108', true,
   (SELECT id FROM app_user WHERE email = 'peter@greenlogy.com'), 'Nitrianska 3, 949 01 Nitra'),
  (pg_temp.id(109), 'TEST Zbúraná s.r.o.', '99000109', true,
   (SELECT id FROM app_user WHERE email = 'eva@greenlogy.com'), 'Staničná 9, 955 01 Topoľčany');

INSERT INTO contact (id, first_name, last_name, email, phone, is_household, owner_id, address) VALUES
  (pg_temp.id(105), 'TEST Ján', 'Horváth', 'test.horvath@example.test', NULL, true,
   (SELECT id FROM app_user WHERE email = 'peter@greenlogy.com'), 'Hlavná 15, 014 01 Bytča'),
  (pg_temp.id(106), 'TEST Lenka', 'Kováčová', 'test.kovacova@example.test', NULL, true,
   (SELECT id FROM app_user WHERE email = 'peter@greenlogy.com'), 'Hlavná 15, 014 01 Bytča'),
  (pg_temp.id(107), 'TEST Mária', 'Nováková', 'test.novakova@example.test', NULL, true,
   (SELECT id FROM app_user WHERE email = 'peter@greenlogy.com'), 'Lipová 7, 917 01 Trnava'),
  (pg_temp.id(110), 'TEST Peter', 'Malý', 'test.maly@example.test', NULL, true,
   (SELECT id FROM app_user WHERE email = 'peter@greenlogy.com'), 'Záhradná 2, 040 01 Košice'),
  -- technik vo firme Kovovýroba (kontaktná osoba pri OOM)
  (pg_temp.id(111), 'TEST Igor', 'Technik', NULL, '+421 900 000 111', false, NULL, NULL);
INSERT INTO company_contact (company_id, contact_id, roles, is_main_contact) VALUES
  (pg_temp.id(101), pg_temp.id(111), '{technik}', true);

-- ---------------------------------------------------------------------------
-- OOM (20)
-- ---------------------------------------------------------------------------

-- Kovovýroba: hala (Aktívne), FVE na streche (Aktívne, výroba → firma je výrobca), sklad bez prechodu (Pripravované)
SELECT pg_temp.oom(1, 101, NULL, 'spotreba', 'aktivne', 'Hala A', 'Priemyselná 12', 'Bytča', '01401', 'ssd', 'ssd_c2', '2024-01-01', 1100, 312);
SELECT pg_temp.oom(2, 101, NULL, 'vyroba', 'aktivne', 'Strecha A – FVE 99 kWp', 'Priemyselná 12', 'Bytča', '01401', 'ssd', 'ssd_c2', '2024-06-01', NULL, NULL, 96);
UPDATE oom SET source_kind = 'fve', source_category = 'lokalny_zdroj', source_power_kw = 99, inverter_power_kw = 90,
               panels_power_kw = 99, feed_in_contract_type = 'lokalny_zdroj_eur' WHERE id = pg_temp.id(2);
INSERT INTO oom (id, company_id, eic, type, status, name, address_city) VALUES
  (pg_temp.id(20), pg_temp.id(101), pg_temp.eic(20), 'spotreba', 'pripravovane', 'Sklad B', 'Bytča');
INSERT INTO oom_contact (oom_id, contact_id, roles) VALUES (pg_temp.id(1), pg_temp.id(111), '{technik_prevadzky}');

-- Obec Lietava: 5 Aktívnych, Kultúrny dom Pripravované bez povinných údajov (zmena potvrdená, dodávka začala)
SELECT pg_temp.oom(3, 102, NULL, 'spotreba', 'aktivne', 'ZŠ Lietava', 'Lietava 120', 'Lietava', '01318', 'ssd', 'ssd_c2', '2025-01-01', 46.5, 11.8);
SELECT pg_temp.oom(4, 102, NULL, 'spotreba', 'aktivne', 'Verejné osvetlenie', 'Lietava', 'Lietava', '01318', 'ssd', 'ssd_c10', '2025-01-01', 41, NULL);
SELECT pg_temp.oom(5, 102, NULL, 'spotreba', 'aktivne', 'Obecný úrad', 'Lietava 1', 'Lietava', '01318', 'ssd', 'ssd_c2', '2025-01-01', 12.4, 3.1);
SELECT pg_temp.oom(6, 102, NULL, 'spotreba', 'aktivne', 'Hasičská zbrojnica', 'Lietava 44', 'Lietava', '01318', 'ssd', 'ssd_c1', '2025-01-01', 4.2, NULL);
SELECT pg_temp.oom(19, 102, NULL, 'spotreba', 'aktivne', 'Materská škola', 'Lietava 121', 'Lietava', '01318', 'ssd', 'ssd_c2', '2025-01-01', 18.0, 6.2);
INSERT INTO oom (id, company_id, eic, type, status, name, address_city, supply_from, switch_notice_required, switch_confirmed_on) VALUES
  (pg_temp.id(7), pg_temp.id(102), pg_temp.eic(7), 'spotreba', 'pripravovane', 'Kultúrny dom', 'Lietava', '2026-10-01', false, '2026-09-20');

-- Agro Turiec: dva zaseknuté prechody (výpoveď bez akceptácie 25 dní; akceptácia bez potvrdenia 20 dní)
SELECT pg_temp.oom(8, 103, NULL, 'spotreba', 'pripravovane', 'Prevádzka Košice', 'Hlavná 5', 'Košice', '04001', 'vsd', 'vsd_d3', '2027-02-01', 160, 52);
UPDATE oom SET switch_notice_required = true, switch_notice_sent_on = crm_today() - 25 WHERE id = pg_temp.id(8);
SELECT pg_temp.oom(9, 103, NULL, 'spotreba', 'pripravovane', 'Sklad Prešov', 'Levočská 10', 'Prešov', '08001', 'vsd', 'vsd_x3_c2', '2027-02-01', 80, NULL);
UPDATE oom SET switch_notice_required = true, switch_notice_sent_on = crm_today() - 35,
               switch_notice_accepted_on = crm_today() - 20 WHERE id = pg_temp.id(9);

-- Stavmont: odišiel ku konkurencii 31. 3. 2026 (Bývalý zákazník)
SELECT pg_temp.oom(10, 104, NULL, 'spotreba', 'aktivne', 'Sklad Trnava', 'Bratislavská 40', 'Trnava', '91701', 'zsd', 'zsd_c2_x3', '2023-01-01', 160, 52.5);
SELECT oom_set_status(pg_temp.id(10), 'odidene', '2026-03-31');

-- Horváth → Kováčová: prepis od 1. 10. 2026 (príklad 4, dátum v minulosti); Kováčová má aj vlastnú garáž
SELECT pg_temp.oom(11, NULL, 105, 'spotreba', 'aktivne', 'Rodinný dom, Hlavná 15', 'Hlavná 15', 'Bytča', '01401', 'ssd', 'ssd_d2', '2025-01-01', 3.1, 1.7);
SELECT oom_transfer(pg_temp.id(11), NULL, pg_temp.id(106), '2026-10-01');
SELECT pg_temp.oom(12, NULL, 106, 'spotreba', 'aktivne', 'Garáž, Hlavná 15', 'Hlavná 15', 'Bytča', '01401', 'ssd', 'ssd_d1', '2026-01-01', 0.8, NULL);

-- Nováková: Pripravované od 1. 1. 2027, všetky kroky hotové → Cron ju 1. 1. 2027 aktivuje (príklad 1)
SELECT pg_temp.oom(13, NULL, 107, 'spotreba', 'pripravovane', 'Rodinný dom, Lipová 7', 'Lipová 7', 'Trnava', '91701', 'zsd', 'zsd_d2', '2027-01-01', 2.6, 1.3);
UPDATE oom SET switch_notice_required = true, switch_notice_sent_on = '2026-09-01', switch_notice_accepted_on = '2026-09-15',
               switch_confirmed_on = '2026-10-01' WHERE id = pg_temp.id(13);

-- Návratová: dielňa odišla 30. 6. 2025 a vracia sa od 1. 1. 2027 (dve obdobia); sklad = sharing Aktívne
SELECT pg_temp.oom(14, 108, NULL, 'spotreba', 'aktivne', 'Dielňa', 'Nitrianska 3', 'Nitra', '94901', 'zsd', 'zsd_c2_x3', '2023-01-01', 58, 14);
SELECT oom_set_status(pg_temp.id(14), 'odidene', '2025-06-30');
SELECT oom_reconnect(pg_temp.id(14), pg_temp.id(108), NULL, '2027-01-01');
UPDATE oom SET supply_from = '2027-01-01', switch_notice_sent_on = '2026-10-05' WHERE id = pg_temp.id(14);
SELECT pg_temp.oom(15, 108, NULL, 'sharing', 'aktivne', 'Sklad – zdieľanie', 'Nitrianska 5', 'Nitra', '94901', 'zsd', 'zsd_d3', '2025-01-01', 21, NULL, 4.5);

-- Zbúraná: OOM zrušené 31. 12. 2025 (Zrušený zákazník, archív)
SELECT pg_temp.oom(16, 109, NULL, 'spotreba', 'aktivne', 'Stará hala', 'Staničná 9', 'Topoľčany', '95501', 'zsd', 'zsd_c1', '2022-01-01', 85, 20);
SELECT oom_set_status(pg_temp.id(16), 'zrusene', '2025-12-31');

-- Malý: dom (spotreba) a FVE na dome (výroba → domácnosť výrobca), zariadenia
SELECT pg_temp.oom(17, NULL, 110, 'spotreba', 'aktivne', 'Rodinný dom', 'Záhradná 2', 'Košice', '04001', 'vsd', 'vsd_d2', '2025-03-01', 5.4, 2.2);
SELECT pg_temp.oom(18, NULL, 110, 'vyroba', 'aktivne', 'FVE na dome 10 kWp', 'Záhradná 2', 'Košice', '04001', 'vsd', 'vsd_d2', '2025-03-01', NULL, NULL, 9);
UPDATE oom SET source_kind = 'fve', source_category = 'maly_zdroj', source_power_kw = 10, inverter_power_kw = 10,
               panels_power_kw = 10.4, feed_in_contract_type = 'lokalny_zdroj_pct' WHERE id = pg_temp.id(18);
INSERT INTO oom_device (oom_id, device_type, brand, model, power_kw, capacity_kwh, count) VALUES
  (pg_temp.id(17), 'tepelne_cerpadlo', 'TEST Značka', 'TČ 8', 8, NULL, 1),
  (pg_temp.id(17), 'wallbox', 'TEST Značka', 'WB 11', 11, NULL, 1),
  (pg_temp.id(18), 'striedac', 'TEST Značka', 'Hybrid 10', 10, NULL, 1),
  (pg_temp.id(18), 'panely', 'TEST Značka', 'Panel 435 W', 0.435, NULL, 24),
  (pg_temp.id(18), 'bateria', 'TEST Značka', 'Batéria 10', NULL, 10, 1);

-- Kontrola: 10 zákazníkov, 20 OOM
DO $$
BEGIN
  ASSERT (SELECT count(*) FROM oom WHERE id::text LIKE '7e570000-%') = 20, 'má byť 20 OOM';
  ASSERT (SELECT count(*) FROM company WHERE id::text LIKE '7e570000-%')
       + (SELECT count(*) FROM contact WHERE id::text LIKE '7e570000-%' AND is_household) = 10, 'má byť 10 zákazníkov';
END;
$$;

COMMIT;
\o

SELECT o.status AS stav, count(*) AS oom FROM oom o WHERE o.id::text LIKE '7e570000-%' GROUP BY 1 ORDER BY 1;
SELECT name AS zakaznik, status AS stav_zakaznika, is_producer AS vyrobca, is_former_customer AS byvaly
  FROM customer_v WHERE id::text LIKE '7e570000-%' ORDER BY name;
