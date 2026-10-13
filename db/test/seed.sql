-- Testovacie dáta jadra. Všetko je vymyslené, žiadne osobné údaje zákazníkov.
-- Spúšťa sa iba na vetve dev cez db/test/run.sh (v transakcii, ktorá sa na konci vráti).
-- Pevné uuid (prefix 00000000-0000-4000-8000-) uľahčujú odkazy v checks.sql.

-- Prepočet stavu zákazníka (0014) je v testoch vypnutý, kým ho checks_oom.sql nezapne
-- (na dev môže byť zapnutý; transakcia testov sa na konci vráti).
UPDATE app_setting SET value = 'false' WHERE key = 'customer_status_auto';

-- Používateľ: tím Sales_internal z východiskových údajov (0006)
INSERT INTO app_user (id, email, name, team_id, status)
SELECT '00000000-0000-4000-8000-000000000011', 'obchodnik@example.test', 'Testovací Obchodník', t.id, 'aktivny'
  FROM team t WHERE t.code = 'sales_internal';
INSERT INTO app_user_org (user_id, org_id) VALUES ('00000000-0000-4000-8000-000000000011', crm_default_org());

-- Firmy (B2B): firma, obec (zákazník) a dodávateľ (iba dodávateľ, nie je zákazník)
INSERT INTO company (id, name, ico, is_customer, is_supplier, owner_id) VALUES
  ('00000000-0000-4000-8000-000000000101', 'Alfa Test s.r.o.', '00123456', true, false,
   '00000000-0000-4000-8000-000000000011'),
  ('00000000-0000-4000-8000-000000000102', 'Obec Betová', '12345678', true, false, NULL),
  ('00000000-0000-4000-8000-000000000103', 'Gama Dodávky a.s.', '87654321', false, true, NULL);

-- Osoby: domácnosť bez firmy a kontakt v dvoch firmách
INSERT INTO contact (id, first_name, last_name, email, is_household, owner_id) VALUES
  ('00000000-0000-4000-8000-000000000201', 'Ján', 'Testovací', 'jan.testovaci@example.test', true,
   '00000000-0000-4000-8000-000000000011'),
  ('00000000-0000-4000-8000-000000000202', 'Eva', 'Vzorová', 'eva.vzorova@example.test', false, NULL);
INSERT INTO company_contact (company_id, contact_id, is_main_contact, roles) VALUES
  ('00000000-0000-4000-8000-000000000101', '00000000-0000-4000-8000-000000000202', true,  '{statutar,decision_maker}'),
  ('00000000-0000-4000-8000-000000000102', '00000000-0000-4000-8000-000000000202', false, '{kontaktna_osoba}');

-- Pomocná funkcia testov: OOM s povinnými údajmi pre Aktívne. Odídené a Zrušené = Aktívne + uzavretie väzby k p_to.
CREATE FUNCTION pg_temp.t_oom(p_id uuid, p_company uuid, p_person uuid, p_eic text, p_type oom_type,
                              p_status oom_status, p_from date DEFAULT '2025-01-01', p_to date DEFAULT '2025-12-31')
RETURNS uuid LANGUAGE plpgsql AS $f$
DECLARE
  v_id uuid := coalesce(p_id, gen_random_uuid());
BEGIN
  INSERT INTO oom (id, company_id, person_id, eic, type, status, name, address_city, address_zip,
                   pds, pds_tariff, voltage_level, supply_from, planned_consumption_vt_mwh, planned_feed_in_mwh)
  VALUES (v_id, p_company, p_person, p_eic, p_type,
          CASE WHEN p_status = 'pripravovane' THEN 'pripravovane' ELSE 'aktivne' END::oom_status,
          'Test', 'Bytča', '01401', 'zsd', 'zsd_d2', 'nn', p_from,
          CASE WHEN p_type <> 'vyroba' THEN 10 END, CASE WHEN p_type = 'vyroba' THEN 5 END);
  IF p_status IN ('odidene', 'zrusene') THEN
    PERFORM oom_set_status(v_id, p_status, p_to);
  END IF;
  RETURN v_id;
END;
$f$;

-- OOM všetkých typov (Alfa: aktívne, pripravované zdieľanie, zrušené; Testovací: výroba)
INSERT INTO oom (id, company_id, person_id, eic, type, status, name, address_city, address_zip,
                 pds, pds_tariff, voltage_level, supply_from,
                 planned_consumption_vt_mwh, planned_consumption_nt_mwh, planned_feed_in_mwh,
                 source_power_kw, source_kind, source_category) VALUES
  ('00000000-0000-4000-8000-000000000301', '00000000-0000-4000-8000-000000000101', NULL,
   '24ZZS000TEST001H', 'spotreba', 'aktivne', 'Alfa – sklad', 'Bytča', '01401', 'zsd', 'zsd_d2', 'nn', '2025-01-01',
   120.000, 30.000, NULL, NULL, NULL, NULL),
  ('00000000-0000-4000-8000-000000000302', NULL, '00000000-0000-4000-8000-000000000201',
   '24ZZS000TEST002F', 'vyroba', 'aktivne', 'Testovací – FVE strecha', 'Bytča', '01401', 'zsd', 'zsd_d2', 'nn', '2025-01-01',
   NULL, NULL, 8.500, 10.000, 'fve', 'lokalny_zdroj'),
  ('00000000-0000-4000-8000-000000000303', '00000000-0000-4000-8000-000000000101', NULL,
   '24ZZS000TEST003D', 'sharing', 'pripravovane', 'Alfa – zdieľanie', NULL, NULL, NULL, NULL, NULL, NULL,
   15.000, NULL, 5.000, NULL, NULL, NULL),
  ('00000000-0000-4000-8000-000000000304', '00000000-0000-4000-8000-000000000101', NULL,
   '24ZZS000TEST004B', 'spotreba', 'aktivne', 'Alfa – zbúraná hala', 'Bytča', '01401', 'zsd', 'zsd_d2', 'nn', '2024-01-01',
   900.000, NULL, NULL, NULL, NULL, NULL);
SELECT oom_set_status('00000000-0000-4000-8000-000000000304', 'zrusene', '2025-06-30');

-- Produkty
INSERT INTO product (id, org_id, code, name, category, segment, vat_rate, price_models) VALUES
  ('00000000-0000-4000-8000-000000000401', crm_default_org(), 'test_dodavka_b2b', 'Test dodávka B2B',
   'dodavka_firma', 'firma', 19.00, '{fix,spot_plus_eur}'),
  ('00000000-0000-4000-8000-000000000402', crm_default_org(), 'test_poplatok_om_b2b', 'Test mesačná platba za OM – firmy',
   'poplatok', 'firma', 19.00, '{cennik}');

-- Pipelines a štádiá
INSERT INTO pipeline (id, name, kind) VALUES
  ('00000000-0000-4000-8000-000000000501', 'Test B2B elektrina', 'b2b_dodavka'),
  ('00000000-0000-4000-8000-000000000502', 'Test B2C elektrina', 'b2c_dodavka');
INSERT INTO pipeline_stage (id, pipeline_id, name, sort_order, probability, outcome) VALUES
  ('00000000-0000-4000-8000-000000000511', '00000000-0000-4000-8000-000000000501', 'Príležitosť', 1, 0.10, 'otvoreny'),
  ('00000000-0000-4000-8000-000000000512', '00000000-0000-4000-8000-000000000501', 'Vyhraté',     6, 1.00, 'vyhrany'),
  ('00000000-0000-4000-8000-000000000521', '00000000-0000-4000-8000-000000000502', 'Vyhraté',     6, 1.00, 'vyhrany');

-- Dealy bez zadaného segmentu (prevezmú ho od zákazníka)
INSERT INTO deal (id, company_id, person_id, pipeline_id, stage_id, name, closed_at, owner_id) VALUES
  ('00000000-0000-4000-8000-000000000601', '00000000-0000-4000-8000-000000000101', NULL,
   '00000000-0000-4000-8000-000000000501', '00000000-0000-4000-8000-000000000512',
   'Alfa – dodávka 2027', '2026-09-15 10:00+02', '00000000-0000-4000-8000-000000000011'),
  ('00000000-0000-4000-8000-000000000602', NULL, '00000000-0000-4000-8000-000000000201',
   '00000000-0000-4000-8000-000000000502', '00000000-0000-4000-8000-000000000521',
   'Testovací – výkup FVE', '2026-09-20 14:00+02', '00000000-0000-4000-8000-000000000011');
INSERT INTO deal_oom (deal_id, oom_id) VALUES
  ('00000000-0000-4000-8000-000000000601', '00000000-0000-4000-8000-000000000301'),
  ('00000000-0000-4000-8000-000000000601', '00000000-0000-4000-8000-000000000303'),
  ('00000000-0000-4000-8000-000000000601', '00000000-0000-4000-8000-000000000304'),
  ('00000000-0000-4000-8000-000000000602', '00000000-0000-4000-8000-000000000302');
INSERT INTO deal_contact (deal_id, contact_id, role) VALUES
  ('00000000-0000-4000-8000-000000000601', '00000000-0000-4000-8000-000000000202', 'rozhodovatel'),
  ('00000000-0000-4000-8000-000000000602', '00000000-0000-4000-8000-000000000201', 'zakaznik');

-- Zmluva so zmluvnými a nákupnými cenami
INSERT INTO contract (id, deal_id, company_id, number, status, confirmed, valid_from, valid_to, signed_at) VALUES
  ('00000000-0000-4000-8000-000000000701', '00000000-0000-4000-8000-000000000601',
   '00000000-0000-4000-8000-000000000101', 'TEST-2026-0001', 'podpisana', true,
   '2027-01-01', '2028-12-31', '2026-09-15 10:00+02');
INSERT INTO contract_price (id, contract_id, oom_id, product_id, direction,
                            price_vt_eur_mwh, price_nt_eur_mwh, fee_oom_eur_month, valid_from, valid_to) VALUES
  ('00000000-0000-4000-8000-000000000711', '00000000-0000-4000-8000-000000000701',
   '00000000-0000-4000-8000-000000000301', '00000000-0000-4000-8000-000000000401', 'odber',
   125.0000, 98.5000, 3.00, '2027-01-01', NULL),
  ('00000000-0000-4000-8000-000000000712', '00000000-0000-4000-8000-000000000701',
   '00000000-0000-4000-8000-000000000303', '00000000-0000-4000-8000-000000000401', 'odber',
   125.0000, NULL, 3.00, '2027-01-01', NULL);
INSERT INTO contract_purchase (contract_id, product_code, delivery_year, priced_on, price_eur_mwh, cockpit_ref) VALUES
  ('00000000-0000-4000-8000-000000000701', 'SK BL CAL2027', 2027, '2026-09-14', 96.4000, 'TEST-TRANZA-1'),
  ('00000000-0000-4000-8000-000000000701', 'SK BL CAL2028', 2028, '2026-09-14', 89.1500, 'TEST-TRANZA-2');
