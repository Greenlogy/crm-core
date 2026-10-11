-- Testovacie dáta jadra. Všetko je vymyslené, žiadne osobné údaje zákazníkov.
-- Spúšťa sa iba na vetve dev cez db/test/run.sh (v transakcii, ktorá sa na konci vráti).
-- Pevné uuid (prefix 00000000-0000-4000-8000-) uľahčujú odkazy v checks.sql.

-- Používateľ a tím
INSERT INTO team (id, name) VALUES
  ('00000000-0000-4000-8000-000000000001', 'Sales_internal');
INSERT INTO app_user (id, email, name, role, team_id) VALUES
  ('00000000-0000-4000-8000-000000000011', 'obchodnik@example.test', 'Testovací Obchodník', 'obchodnik',
   '00000000-0000-4000-8000-000000000001');

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

-- OOM všetkých typov
INSERT INTO oom (id, company_id, person_id, eic, type, status, segment, name,
                 planned_consumption_vt_mwh, planned_consumption_nt_mwh, planned_feed_in_mwh,
                 source_power_kw, source_kind, source_type) VALUES
  ('00000000-0000-4000-8000-000000000301', '00000000-0000-4000-8000-000000000101', NULL,
   '24ZZS0000TEST001', 'spotreba', 'aktivne', 'firma', 'Alfa – sklad', 120.000, 30.000, NULL, NULL, NULL, NULL),
  ('00000000-0000-4000-8000-000000000302', NULL, '00000000-0000-4000-8000-000000000201',
   '24ZZS0000TEST002', 'vyroba', 'aktivne', 'domacnost', 'Testovací – FVE strecha', NULL, NULL, 8.500,
   10.000, 'fve', 'virtualna_bateria'),
  ('00000000-0000-4000-8000-000000000303', '00000000-0000-4000-8000-000000000101', NULL,
   '24ZZS0000TEST003', 'sharing', 'neaktivne', 'firma', 'Alfa – zdieľanie', 15.000, NULL, 5.000, NULL, NULL, NULL),
  ('00000000-0000-4000-8000-000000000304', '00000000-0000-4000-8000-000000000101', NULL,
   '24ZZS0000TEST004', 'velkoobchod', 'zrusene', 'firma', 'Alfa – veľkoobchod', 900.000, NULL, NULL, NULL, NULL, NULL);

-- Produkty
INSERT INTO product (id, code, name, kind, pricing_model, unit, list_price) VALUES
  ('00000000-0000-4000-8000-000000000401', 'TEST_E_1T_FIX', 'Test elektrina 1T FIX', 'dodavka', 'fix', 'eur_mwh', 189.0000),
  ('00000000-0000-4000-8000-000000000402', 'TEST_E_OM', 'Test poplatok za OM', 'poplatok', NULL, 'eur_mesiac', 3.0000);

-- Pipelines a štádiá
INSERT INTO pipeline (id, name) VALUES
  ('00000000-0000-4000-8000-000000000501', 'Test B2B elektrina'),
  ('00000000-0000-4000-8000-000000000502', 'Test B2C elektrina');
INSERT INTO pipeline_stage (id, pipeline_id, name, sort_order, probability, is_closed, is_won) VALUES
  ('00000000-0000-4000-8000-000000000511', '00000000-0000-4000-8000-000000000501', 'Príležitosť', 1, 0.10, false, false),
  ('00000000-0000-4000-8000-000000000512', '00000000-0000-4000-8000-000000000501', 'Vyhraté',     6, 1.00, true,  true),
  ('00000000-0000-4000-8000-000000000521', '00000000-0000-4000-8000-000000000502', 'Vyhraté',     6, 1.00, true,  true);

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
