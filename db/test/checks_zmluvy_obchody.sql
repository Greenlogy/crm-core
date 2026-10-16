-- Kontroly modulu 5, fáza F5 (0045): podklady pre zmluvu (uloženie k firme / kontaktu / OOM, rozdelenie NN / VN, úplnosť,
-- práva), párovanie zmlúv z importu (iba po zapnutí deal_matching; Akceptácia s akceptovaným variantom, Vyjednávanie
-- s OOM obchodu bez kontroly cien, Vyhraté s ďalšou zmluvou VN, nejednoznačná zhoda, domácnosť bez obchodu), príznak
-- „Cena iná ako v ponuke“, výnimka z ponuky → zmluva, ručné rozhodnutia a zrušenie spárovania.
-- Spúšťa sa iba cez db/test/run.sh po checks_emaily.sql (pomocné funkcie série B, rola crm_rls_test).
-- Vlastné záznamy: …-0000000f00xx používatelia, f01xx firmy, f02xx OOM, f03xx obchody, f04xx kontakty, f05xx zmluvy.

-- ============================================================================
-- Príprava (vlastník databázy)
-- ============================================================================

CREATE FUNCTION pg_temp.f_id(p_kind text, p_n integer) RETURNS uuid LANGUAGE sql AS $f$
  SELECT ('00000000-0000-4000-8000-0000000' || CASE p_kind WHEN 'u' THEN 'f00' WHEN 'f' THEN 'f01' WHEN 'oom' THEN 'f02'
                                                            WHEN 'd' THEN 'f03' WHEN 'k' THEN 'f04' ELSE 'f05' END || lpad(p_n::text, 2, '0'))::uuid
$f$;
CREATE FUNCTION pg_temp.f_eic(p_n integer) RETURNS text LANGUAGE plpgsql AS $f$
DECLARE
  l text;
  c text;
BEGIN
  FOREACH l IN ARRAY string_to_array('KLMNPQRSTUVW', NULL) LOOP
    FOREACH c IN ARRAY string_to_array('0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ', NULL) LOOP
      IF eic_is_valid('24ZZS000ZMOB' || l || lpad(p_n::text, 2, '0') || c) THEN
        RETURN '24ZZS000ZMOB' || l || lpad(p_n::text, 2, '0') || c;
      END IF;
    END LOOP;
  END LOOP;
END;
$f$;
CREATE FUNCTION pg_temp.f_as(p_user uuid) RETURNS text LANGUAGE sql AS $f$
  SELECT set_config('app.require_user', 'on', true) || set_config('app.user_id', coalesce(p_user::text, ''), true)
$f$;
-- obchod v štádiu (vlastník databázy smie založiť obchod v ľubovoľnom štádiu); OOM obchodu
CREATE FUNCTION pg_temp.f_deal(p_n integer, p_company integer, p_stage text, p_ooms integer[], p_kind text DEFAULT 'b2b_dodavka') RETURNS uuid
LANGUAGE plpgsql AS $f$
DECLARE
  o integer;
BEGIN
  INSERT INTO deal (id, company_id, pipeline_id, stage_id, name, owner_id, source_code, supply_start)
  VALUES (pg_temp.f_id('d', p_n), pg_temp.f_id('f', p_company), pg_temp.b_pipe(p_kind), pg_temp.b_stage(p_kind, 'prilezitost'),
          'F' || p_n, pg_temp.f_id('u', 1), 'web', '2027-01-01');
  FOREACH o IN ARRAY p_ooms LOOP
    INSERT INTO deal_oom (deal_id, oom_id) VALUES (pg_temp.f_id('d', p_n), pg_temp.f_id('oom', o));
  END LOOP;
  UPDATE deal SET stage_id = pg_temp.b_stage(p_kind, p_stage) WHERE id = pg_temp.f_id('d', p_n);
  RETURN pg_temp.f_id('d', p_n);
END;
$f$;
-- akceptovaný variant: ponuka s FIX 2027 pre zadané OOM a ceny (vlastník databázy zapíše variant priamo)
CREATE FUNCTION pg_temp.f_accept(p_deal integer, p_ooms integer[], p_prices numeric[]) RETURNS uuid
LANGUAGE plpgsql AS $f$
DECLARE
  v_offer uuid;
  v_var   uuid;
  i       integer;
BEGIN
  PERFORM set_config('app.require_user', 'on', true);
  PERFORM set_config('app.user_id', pg_temp.f_id('u', 1)::text, true);
  v_offer := offer_create(pg_temp.f_id('d', p_deal));
  PERFORM set_config('app.user_id', '', true);
  PERFORM set_config('app.require_user', '', true);
  v_var := (SELECT id FROM offer_variant WHERE offer_id = v_offer);
  DELETE FROM offer_item WHERE variant_id = v_var;
  FOR i IN 1..cardinality(p_ooms) LOOP
    INSERT INTO offer_item (variant_id, oom_id, year, slot, product_id, price_model, price_vt_eur_mwh)
    VALUES (v_var, pg_temp.f_id('oom', p_ooms[i]), 2027, 'komodita', (SELECT id FROM product WHERE code = 'green_1t'), 'fix', p_prices[i]);
  END LOOP;
  UPDATE deal SET accepted_variant_id = v_var WHERE id = pg_temp.f_id('d', p_deal);
  RETURN v_var;
END;
$f$;
-- zmluva z importu (ako contract_import_one): app.contract_import_id nastavený → po zapnutí párovania čaká na párovanie
CREATE FUNCTION pg_temp.f_contract(p_n integer, p_company integer, p_type text, p_ooms integer[], p_prices numeric[], p_person uuid DEFAULT NULL)
RETURNS uuid LANGUAGE plpgsql AS $f$
DECLARE
  i    integer;
  v_im uuid;
BEGIN
  INSERT INTO contract_import (org_id, user_id, op_file_name) VALUES (crm_default_org(), pg_temp.f_id('u', 1), 'f5-test.xlsx') RETURNING id INTO v_im;
  PERFORM set_config('app.contract_import_id', v_im::text, true);
  INSERT INTO contract (id, number, company_id, person_id, type, phase, valid_from, valid_to, signed_on, owner_id)
  VALUES (pg_temp.f_id('z', p_n), 'F5-' || p_n, CASE WHEN p_person IS NULL THEN pg_temp.f_id('f', p_company) END, p_person,
          p_type::contract_type, 'podpisana', '2027-01-01', '2027-12-31', crm_today(), pg_temp.f_id('u', 1));
  FOR i IN 1..cardinality(p_ooms) LOOP
    INSERT INTO contract_oom (contract_id, oom_id, qty_vt_mwh, product_id)
    VALUES (pg_temp.f_id('z', p_n), pg_temp.f_id('oom', p_ooms[i]), 30, (SELECT id FROM product WHERE code = 'green_1t'));
    INSERT INTO contract_price (contract_id, oom_id, slot, product_id, price_model, valid_from, valid_to, price_vt_eur_mwh)
    VALUES (pg_temp.f_id('z', p_n), pg_temp.f_id('oom', p_ooms[i]), 'komodita', (SELECT id FROM product WHERE code = 'green_1t'),
            'fix', '2027-01-01', '2027-12-31', p_prices[i]);
  END LOOP;
  PERFORM set_config('app.contract_import_id', '', true);
  RETURN pg_temp.f_id('z', p_n);
END;
$f$;

-- 1 obchodník (vlastník zákazníkov), 2 admin, 3 schvaľovateľ cien, 4 iný obchodník, 5 Servis, 6 Nákup
INSERT INTO app_user (id, email, name, team_id, status, seller_type, is_admin)
SELECT x.id::uuid, x.email, x.name, t.id, 'aktivny', x.st::seller_type, x.adm
  FROM (VALUES
    ('00000000-0000-4000-8000-0000000f0001', 'obchodnik.f@example.test', 'Obchodník F', 'test_predajcovia_b', 'obchodnik', false),
    ('00000000-0000-4000-8000-0000000f0002', 'admin.f@example.test', 'Admin F', 'sales_internal', NULL, true),
    ('00000000-0000-4000-8000-0000000f0003', 'schvalovatel.f@example.test', 'Schvaľovateľ F', 'sales_internal', NULL, false),
    ('00000000-0000-4000-8000-0000000f0004', 'iny.f@example.test', 'Iný obchodník F', 'test_predajcovia_b', 'obchodnik', false),
    ('00000000-0000-4000-8000-0000000f0005', 'servis.f@example.test', 'Servis F', 'servis', NULL, false),
    ('00000000-0000-4000-8000-0000000f0006', 'nakup.f@example.test', 'Nákup F', 'nakup', NULL, false)
  ) AS x(id, email, name, team, st, adm)
  JOIN team t ON t.code = x.team;
UPDATE app_user SET approves_prices = true WHERE id = '00000000-0000-4000-8000-0000000f0003';
INSERT INTO app_user_org (user_id, org_id)
SELECT id, crm_default_org() FROM app_user WHERE id::text LIKE '00000000-0000-4000-8000-0000000f00%'
ON CONFLICT DO NOTHING;

INSERT INTO company (id, name, ico, address, is_customer, owner_id) VALUES
  (pg_temp.f_id('f', 1), 'Zmluvy Test F1 s.r.o.', '88880061', 'Hlavná 5, 010 01 Žilina', true, pg_temp.f_id('u', 1)),
  (pg_temp.f_id('f', 2), 'Zmluvy Test F2 s.r.o.', '88880062', 'Hlavná 6, 010 01 Žilina', true, pg_temp.f_id('u', 1)),
  (pg_temp.f_id('f', 3), 'Zmluvy Test F3 s.r.o.', '88880063', 'Hlavná 7, 010 01 Žilina', true, NULL);
INSERT INTO contact (id, first_name, last_name, email, phone, is_household) VALUES
  (pg_temp.f_id('k', 1), 'Zuzana', 'Zástupcová', 'zuzana.f@example.test', '+421 900 333 444', false),
  (pg_temp.f_id('k', 2), 'Dušan', 'Domácnosť', 'dusan.f@example.test', NULL, true);
INSERT INTO company_contact (company_id, contact_id) VALUES (pg_temp.f_id('f', 1), pg_temp.f_id('k', 1));
INSERT INTO lookup_value (list_code, code, label, sort_order) VALUES
  ('predchadzajuci_dodavatel', 'f5_test_a', 'Dodávateľ F5 A', 901), ('predchadzajuci_dodavatel', 'f5_test_b', 'Dodávateľ F5 B', 902);

-- OOM: 1, 2 NN a 3 VN (firma F1); 4, 5 NN (firma F2); 6, 7 NN (firma F3); 8 domácnosť
INSERT INTO oom (id, company_id, person_id, eic, type, status, voltage_level, planned_consumption_vt_mwh)
SELECT pg_temp.f_id('oom', n), CASE WHEN n = 8 THEN NULL ELSE pg_temp.f_id('f', CASE WHEN n <= 3 THEN 1 WHEN n <= 5 THEN 2 ELSE 3 END) END,
       CASE WHEN n = 8 THEN pg_temp.f_id('k', 2) END, pg_temp.f_eic(n), 'spotreba', 'pripravovane',
       CASE WHEN n = 3 THEN 'vn' ELSE 'nn' END::voltage_level, 30
  FROM generate_series(1, 8) n;

-- práva ako aplikácia (app-role.sql, 0045)
GRANT SELECT ON deal_contract_input TO crm_rls_test;
GRANT EXECUTE ON FUNCTION deal_contract_input_save(uuid, jsonb), deal_contract_input_view(uuid), deal_contract_input_missing(uuid),
  crm_contract_input_editor(deal), iban_ok(text), email_list_ok(text[]), contract_deal_candidates(uuid), contract_unmatched(),
  crm_contract_match_editor(contract), contract_deal_pick(uuid, uuid), contract_deal_none(uuid, text), contract_deal_unlink(uuid, text),
  contract_deal_kind(contract_type), contract_offer_price_text(price_model, numeric, numeric, numeric, numeric) TO crm_rls_test;

-- ============================================================================
-- F0. Podklady pre zmluvu: uloženie k firme, zástupcovi, OOM a obchodu; NN a VN zvlášť; úplnosť; práva
-- ============================================================================
SELECT pg_temp.f_deal(1, 1, 'akceptacia', ARRAY[1, 3]);
SELECT pg_temp.f_accept(1, ARRAY[1, 3], ARRAY[125, 118]::numeric[]);
DO $$
BEGIN
  ASSERT iban_ok('SK31 1200 0000 1987 4263 7541') AND NOT iban_ok('SK31 1200 0000 1987 4263 7542') AND NOT iban_ok('xx'), 'IBAN kontrolná číslica';
  RAISE NOTICE 'OK: F0 IBAN kontrolná číslica';
END;
$$;
SET LOCAL ROLE crm_rls_test;
DO $$
DECLARE
  v jsonb;
BEGIN
  PERFORM pg_temp.f_as(pg_temp.f_id('u', 1));
  v := deal_contract_input_view(pg_temp.f_id('d', 1));
  ASSERT jsonb_array_length(v->'contracts') = 2 AND v->'contracts'->0->>'group' = 'nn' AND v->'contracts'->1->>'group' = 'vn',
         'dve zmluvy NN a VN: ' || (v->'contracts')::text;
  ASSERT v->'contracts'->1->'prices'->0->>'text' = '118,00 €/MWh', 'cena VN';
  ASSERT (v->'completeness'->>'filled')::int < (v->'completeness'->>'total')::int AND v->'completeness'->'missing' ? 'IBAN', 'chýba IBAN';
  BEGIN
    PERFORM deal_contract_input_save(pg_temp.f_id('d', 1), '{"company": {"bank_account": "SK31 1200 0000 1987 4263 7542"}}');
    RAISE EXCEPTION 'CHYBA: zlý IBAN';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    PERFORM deal_contract_input_save(pg_temp.f_id('d', 1), '{"ooms": [{"oom_id": "00000000-0000-4000-8000-0000000f0204", "has_ims": true}]}');
    RAISE EXCEPTION 'CHYBA: OOM mimo obchodu';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  PERFORM deal_contract_input_save(pg_temp.f_id('d', 1), jsonb_build_object(
    'company', jsonb_build_object('bank_account', 'sk31 1200 0000 1987 4263 7541', 'billing_emails', jsonb_build_array('Faktury@Example.test', ''),
                                  'vat_payer', true, 'social_enterprise', false, 'contract_name', 'Zmluvy Test F1 s.r.o., v zastúpení'),
    'representative', jsonb_build_object('contact_id', pg_temp.f_id('k', 1), 'position', 'konateľka'),
    'contract', jsonb_build_object('billing_period', 'mesacne', 'auto_prolong', true, 'product_line', 'Greenlogy'),
    'ooms', jsonb_build_array(
      jsonb_build_object('oom_id', pg_temp.f_id('oom', 1), 'property_relation', 'vlastnik', 'has_ims', true, 'previous_supplier', 'f5_test_a'),
      jsonb_build_object('oom_id', pg_temp.f_id('oom', 3), 'property_relation', 'najomca', 'has_ims', false, 'previous_supplier', 'f5_test_b'))));
  ASSERT (SELECT (bank_account, billing_emails, vat_payer, contract_name) FROM company WHERE id = pg_temp.f_id('f', 1))
         = ROW('SK3112000000198742637541'::text, ARRAY['faktury@example.test'], true, 'Zmluvy Test F1 s.r.o., v zastúpení'::text), 'firma';
  ASSERT (SELECT position FROM contact WHERE id = pg_temp.f_id('k', 1)) = 'konateľka', 'zástupca';
  ASSERT (SELECT (property_relation, has_ims, previous_supplier) FROM oom WHERE id = pg_temp.f_id('oom', 3)) = ROW('najomca'::text, false, 'f5_test_b'::text), 'OOM';
  v := deal_contract_input_view(pg_temp.f_id('d', 1));
  ASSERT v->'completeness'->>'filled' = v->'completeness'->>'total', 'všetko doplnené: ' || (v->'completeness')::text;
  ASSERT v->'header'->>'billing_period_label' = 'Mesačne' AND v->'representative'->>'position' = 'konateľka'
         AND v->'contracts'->0->'ooms'->0->>'property_relation_label' = 'Vlastník nehnuteľnosti', 'zobrazenie';
  BEGIN
    PERFORM deal_contract_input_save(pg_temp.f_id('d', 1), '{"contract": {"feed_in_calc_model": "neznamy"}}');
    RAISE EXCEPTION 'CHYBA: neznámy model';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  -- iný obchodník podklady nezmení; Servis a Nákup áno
  PERFORM pg_temp.f_as(pg_temp.f_id('u', 4));
  BEGIN
    PERFORM deal_contract_input_save(pg_temp.f_id('d', 1), '{"contract": {"auto_prolong": false}}');
    RAISE EXCEPTION 'CHYBA: cudzí obchodník zmenil podklady';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM pg_temp.f_as(pg_temp.f_id('u', 5));
  PERFORM deal_contract_input_save(pg_temp.f_id('d', 1), '{"contract": {"auto_prolong": false}}');
  PERFORM pg_temp.f_as(pg_temp.f_id('u', 6));
  PERFORM deal_contract_input_save(pg_temp.f_id('d', 1), '{"contract": {"auto_prolong": true}}');
  ASSERT (SELECT auto_prolong FROM deal_contract_input WHERE deal_id = pg_temp.f_id('d', 1)), 'Nákup uložil';
  PERFORM pg_temp.f_as(NULL);
  RAISE NOTICE 'OK: F0 podklady: dve zmluvy NN a VN, IBAN s kontrolnou číslicou, údaje k firme / zástupcovi / OOM / obchodu, úplnosť, číselníky; cudzí obchodník nie, Servis a Nákup áno';
END;
$$;
RESET ROLE;

-- ============================================================================
-- F1. Párovanie vypnuté (počiatočný kmeň zmlúv): nová zmluva sa nepáruje ani nezobrazí v Nespárovaných
-- ============================================================================
UPDATE app_setting SET value = 'false' WHERE key = 'deal_matching';
SELECT pg_temp.f_contract(1, 1, 'dodavka_firma_nn', ARRAY[1], ARRAY[125]::numeric[]);
DO $$
BEGIN
  ASSERT (SELECT deal_match FROM contract WHERE id = pg_temp.f_id('z', 1)) IS NULL, 'bez párovania';
  ASSERT (contract_deal_match_pending()->>'auto')::int = 0, 'nič na párovanie';
  ASSERT NOT EXISTS (SELECT 1 FROM jsonb_array_elements(contract_unmatched()) x WHERE (x->>'contract_id')::uuid = pg_temp.f_id('z', 1)), 'nie v Nespárovaných';
  RAISE NOTICE 'OK: F1 kým je deal_matching vypnuté, zmluvy z importu sa nepárujú ani nezobrazia v Nespárovaných';
END;
$$;
DELETE FROM contract_price WHERE contract_id = pg_temp.f_id('z', 1);
DELETE FROM contract_oom WHERE contract_id = pg_temp.f_id('z', 1);
DELETE FROM contract_year_basis WHERE contract_id = pg_temp.f_id('z', 1);
DELETE FROM contract_flag WHERE contract_id = pg_temp.f_id('z', 1);
DELETE FROM contract WHERE id = pg_temp.f_id('z', 1);
UPDATE app_setting SET value = 'true' WHERE key = 'deal_matching';

-- ============================================================================
-- F2. Akceptácia: zhoda EIC s akceptovaným variantom → spárované, Vyhraté, časová os; výnimka z ponuky → zmluva;
--     výnimka modulu 4 sa pre spárovanú zmluvu nepoužije; druhá zmluva VN sa pripojí k vyhratému obchodu
-- ============================================================================
-- schválená výnimka ponuky pre rok 2027 (NN) a schválená výnimka modulu 4 toho istého zákazníka
INSERT INTO approval_request (id, org_id, kind, deal_id, offer_id, reason, requested_by, status, decided_by, decided_at)
SELECT '00000000-0000-4000-8000-0000000f0601', crm_default_org(), 'vynimka_ceny', pg_temp.f_id('d', 1), v.offer_id, 'test F5',
       pg_temp.f_id('u', 1), 'schvalena', pg_temp.f_id('u', 3), now()
  FROM deal d JOIN offer_variant v ON v.id = d.accepted_variant_id WHERE d.id = pg_temp.f_id('d', 1);
INSERT INTO approval_price_item (approval_id, variant_id, year, price_model, voltage_group, requested_value, threshold_value, approved_value,
                                 threshold_source, scope)
SELECT '00000000-0000-4000-8000-0000000f0601', d.accepted_variant_id, 2027, 'fix', 'nn', 125, 126, 125, 'cena_pre_obchodnika', '{}'
  FROM deal d WHERE d.id = pg_temp.f_id('d', 1);
INSERT INTO price_exception (id, company_id, years, price_model, requested_value, threshold_value, reason, requested_by, status,
                             decided_by, decided_at, valid_until)
VALUES ('00000000-0000-4000-8000-0000000f0602', pg_temp.f_id('f', 1), ARRAY[2027::smallint], 'fix', 110, 126, 'modul 4', pg_temp.f_id('u', 1),
        'schvalena', pg_temp.f_id('u', 3), now(), crm_today() + 30);
SELECT pg_temp.f_contract(2, 1, 'dodavka_firma_nn', ARRAY[1], ARRAY[125]::numeric[]);
DO $$
DECLARE
  r jsonb;
BEGIN
  ASSERT (SELECT deal_match FROM contract WHERE id = pg_temp.f_id('z', 2)) = 'caka', 'po zapnutí čaká na párovanie';
  r := contract_deal_match_pending();
  ASSERT (SELECT (deal_id, deal_match, offer_variant_id IS NOT NULL) FROM contract WHERE id = pg_temp.f_id('z', 2))
         = ROW(pg_temp.f_id('d', 1), 'auto'::text, true), 'spárované automaticky: ' || r::text;
  ASSERT (SELECT s.code FROM deal d JOIN pipeline_stage s ON s.id = d.stage_id WHERE d.id = pg_temp.f_id('d', 1)) = 'vyhrane', 'obchod Vyhraté';
  ASSERT EXISTS (SELECT 1 FROM deal_event WHERE deal_id = pg_temp.f_id('d', 1) AND kind = 'zmluva_sparovana'
                   AND detail->>'number' = 'F5-2' AND NOT (detail->>'bez_ponuky')::boolean), 'časová os';
  ASSERT NOT EXISTS (SELECT 1 FROM contract_flag WHERE contract_id = pg_temp.f_id('z', 2) AND code::text = 'cena_ina_ako_v_ponuke'), 'rovnaká cena – bez príznaku';
  ASSERT EXISTS (SELECT 1 FROM price_exception WHERE contract_id = pg_temp.f_id('z', 2) AND status = 'pouzita'
                   AND approval_request_id = '00000000-0000-4000-8000-0000000f0601' AND requested_value = 125 AND threshold_value = 126),
         'výnimka z ponuky na zmluve';
  ASSERT (SELECT x.approval_request_id FROM contract_year_basis b JOIN price_exception x ON x.id = b.exception_id
           WHERE b.contract_id = pg_temp.f_id('z', 2) AND b.year = 2027) = '00000000-0000-4000-8000-0000000f0601', 'hranica zmluvy z výnimky ponuky';
  ASSERT (SELECT status FROM price_exception WHERE id = '00000000-0000-4000-8000-0000000f0602') = 'schvalena', 'výnimka modulu 4 nepoužitá';
  ASSERT NOT EXISTS (SELECT 1 FROM notification WHERE kind = 'vynimka_nova' AND price_exception_id IN
                       (SELECT id FROM price_exception WHERE approval_request_id IS NOT NULL)), 'prevzatá výnimka nie je nová žiadosť';
  RAISE NOTICE 'OK: F2 Akceptácia: zhoda EIC s akceptovaným variantom → spárované, Vyhraté, časová os; výnimka z ponuky Použitá a hranica zmluvy; výnimka modulu 4 sa nepoužije';
END;
$$;
SELECT pg_temp.f_contract(3, 1, 'dodavka_firma_vn', ARRAY[3], ARRAY[118]::numeric[]);
DO $$
BEGIN
  PERFORM contract_deal_match_pending();
  ASSERT (SELECT (deal_id, deal_match) FROM contract WHERE id = pg_temp.f_id('z', 3)) = ROW(pg_temp.f_id('d', 1), 'auto'::text), 'VN k vyhratému obchodu';
  ASSERT NOT EXISTS (SELECT 1 FROM price_exception WHERE contract_id = pg_temp.f_id('z', 3) AND approval_request_id IS NOT NULL), 'výnimka NN nie na VN';
  RAISE NOTICE 'OK: F2 druhá zmluva (VN) sa pripojí k vyhratému obchodu; výnimka pre NN na ňu neprejde';
END;
$$;

-- ============================================================================
-- F3. Cena iná ako v ponuke: príznak s rokom a cenami, upozornenie obchodníkovi a schvaľovateľom; uzatvára schvaľovateľ s poznámkou
-- ============================================================================
SELECT pg_temp.f_deal(2, 2, 'akceptacia', ARRAY[4]);
SELECT pg_temp.f_accept(2, ARRAY[4], ARRAY[121]::numeric[]);
SELECT pg_temp.f_contract(4, 2, 'dodavka_firma_nn', ARRAY[4], ARRAY[119]::numeric[]);
DO $$
BEGIN
  PERFORM contract_deal_match_pending();
  ASSERT (SELECT deal_id FROM contract WHERE id = pg_temp.f_id('z', 4)) = pg_temp.f_id('d', 2), 'spárované';
  ASSERT (SELECT detail FROM contract_flag WHERE contract_id = pg_temp.f_id('z', 4) AND code::text = 'cena_ina_ako_v_ponuke' AND year = 2027)
         LIKE 'Rok 2027 – %ponuka 121,00 €/MWh, zmluva 119,00 €/MWh', 'príznak s cenami';
  ASSERT EXISTS (SELECT 1 FROM notification WHERE kind = 'cena_ina_ako_v_ponuke' AND user_id = pg_temp.f_id('u', 1) AND deal_id = pg_temp.f_id('d', 2))
     AND EXISTS (SELECT 1 FROM notification WHERE kind = 'cena_ina_ako_v_ponuke' AND user_id = pg_temp.f_id('u', 3)), 'upozornenie obchodník + schvaľovateľ';
  RAISE NOTICE 'OK: F3 cena iná ako v ponuke: príznak s rokom a cenami, upozornenie obchodníkovi a schvaľovateľom';
END;
$$;
GRANT SELECT, UPDATE ON contract_flag TO crm_rls_test;
SET LOCAL ROLE crm_rls_test;
DO $$
DECLARE
  _u     text := pg_temp.f_as(pg_temp.f_id('u', 3));
  v_flag uuid := (SELECT id FROM contract_flag WHERE contract_id = pg_temp.f_id('z', 4) AND code::text = 'cena_ina_ako_v_ponuke');
BEGIN
  ASSERT v_flag IS NOT NULL, 'schvaľovateľ príznak vidí';
  PERFORM pg_temp.f_as(pg_temp.f_id('u', 1));
  BEGIN
    UPDATE contract_flag SET resolved_at = now(), resolved_by = pg_temp.f_id('u', 1), resolved_note = 'ok' WHERE id = v_flag;
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  ASSERT (SELECT resolved_at FROM contract_flag WHERE id = v_flag) IS NULL OR NOT EXISTS (SELECT 1 FROM contract_flag WHERE id = v_flag),
         'obchodník príznak neuzavrel';
  PERFORM pg_temp.f_as(pg_temp.f_id('u', 3));
  BEGIN
    UPDATE contract_flag SET resolved_at = now(), resolved_by = pg_temp.f_id('u', 3) WHERE id = v_flag;
    RAISE EXCEPTION 'CHYBA: uzavretie bez poznámky';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  UPDATE contract_flag SET resolved_at = now(), resolved_by = pg_temp.f_id('u', 3), resolved_note = 'dohodnutá zľava' WHERE id = v_flag;
  ASSERT (SELECT resolved_note FROM contract_flag WHERE id = v_flag) = 'dohodnutá zľava', 'schvaľovateľ uzavrel s poznámkou';
  PERFORM pg_temp.f_as(NULL);
  RAISE NOTICE 'OK: F3 príznak uzatvára iba schvaľovateľ cien s poznámkou';
END;
$$;
RESET ROLE;

-- ============================================================================
-- F4. Vyjednávanie: EIC zmluvy na obchode → spárované bez akceptovanej ponuky, ceny sa nekontrolujú
-- ============================================================================
SELECT pg_temp.f_deal(3, 2, 'vyjednavanie', ARRAY[5]);
-- obchod vo Vyjednávaní už má ponuku (neakceptovanú) s inou cenou – kontrola cien sa aj tak nerobí
SELECT pg_temp.f_accept(3, ARRAY[5], ARRAY[120]::numeric[]);
UPDATE deal SET accepted_variant_id = NULL WHERE id = pg_temp.f_id('d', 3);
-- výnimka modulu 4 toho istého zákazníka sa na spárovanú zmluvu nepoužije
INSERT INTO price_exception (id, company_id, years, price_model, requested_value, threshold_value, reason, requested_by, status,
                             decided_by, decided_at, valid_until)
VALUES ('00000000-0000-4000-8000-0000000f0603', pg_temp.f_id('f', 2), ARRAY[2027::smallint], 'fix', 99, 126, 'modul 4', pg_temp.f_id('u', 1),
        'schvalena', pg_temp.f_id('u', 3), now(), crm_today() + 30);
SELECT pg_temp.f_contract(5, 2, 'dodavka_firma_nn', ARRAY[5], ARRAY[99]::numeric[]);
DO $$
BEGIN
  PERFORM contract_deal_match_pending();
  ASSERT (SELECT (deal_id, deal_match, offer_variant_id) FROM contract WHERE id = pg_temp.f_id('z', 5))
         = ROW(pg_temp.f_id('d', 3), 'auto'::text, NULL::uuid), 'spárované bez variantu';
  ASSERT EXISTS (SELECT 1 FROM deal_event WHERE deal_id = pg_temp.f_id('d', 3) AND kind = 'zmluva_sparovana'
                   AND detail->>'text' = 'spárované bez akceptovanej ponuky'), 'časová os bez ponuky';
  ASSERT NOT EXISTS (SELECT 1 FROM contract_flag WHERE contract_id = pg_temp.f_id('z', 5) AND code::text = 'cena_ina_ako_v_ponuke'), 'ceny sa nekontrolujú';
  ASSERT (SELECT status FROM price_exception WHERE id = '00000000-0000-4000-8000-0000000f0603') = 'schvalena'
     AND NOT EXISTS (SELECT 1 FROM contract_year_basis WHERE contract_id = pg_temp.f_id('z', 5) AND exception_id IS NOT NULL),
         'výnimka modulu 4 sa na spárovanú zmluvu nepoužije';
  ASSERT (SELECT s.code FROM deal d JOIN pipeline_stage s ON s.id = d.stage_id WHERE d.id = pg_temp.f_id('d', 3)) = 'vyhrane', 'Vyhraté';
  RAISE NOTICE 'OK: F4 Vyjednávanie: všetky EIC zmluvy na obchode → spárované bez akceptovanej ponuky (časová os), ceny sa nekontrolujú';
END;
$$;

-- ============================================================================
-- F5. Nejednoznačná zhoda (Akceptácia aj Vyjednávanie) a žiadna zhoda → Nespárované, upozornenie raz
--     (vlastník zákazníka, inak admin); domácnosť bez obchodu B2C → Bez obchodu
-- ============================================================================
SELECT pg_temp.f_deal(4, 3, 'akceptacia', ARRAY[6]);
SELECT pg_temp.f_accept(4, ARRAY[6], ARRAY[120]::numeric[]);
-- druhý obchod toho istého zákazníka vo Vyjednávaní s rovnakým OOM (vlastník databázy obíde pravidlo OOM v jednom obchode)
SELECT pg_temp.f_deal(5, 3, 'prilezitost', ARRAY[]::integer[]);
ALTER TABLE deal_oom DISABLE TRIGGER trg_deal_oom_rules;
INSERT INTO deal_oom (deal_id, oom_id, org_id) VALUES (pg_temp.f_id('d', 5), pg_temp.f_id('oom', 6), crm_default_org());
ALTER TABLE deal_oom ENABLE TRIGGER trg_deal_oom_rules;
UPDATE deal SET stage_id = pg_temp.b_stage('b2b_dodavka', 'vyjednavanie') WHERE id = pg_temp.f_id('d', 5);
SELECT pg_temp.f_contract(6, 3, 'dodavka_firma_nn', ARRAY[6], ARRAY[120]::numeric[]);
SELECT pg_temp.f_contract(7, 3, 'dodavka_firma_nn', ARRAY[7], ARRAY[120]::numeric[]);
SELECT pg_temp.f_contract(8, NULL, 'dodavka_domacnost', ARRAY[8], ARRAY[150]::numeric[], pg_temp.f_id('k', 2));
-- obchod pridelil firme vlastníka; na skúšku upozornenia bez vlastníka ho odoberieme
DO $$
BEGIN
  PERFORM set_config('app.user_id', pg_temp.f_id('u', 2)::text, true);   -- admin smie meniť vlastníka
  UPDATE company SET owner_id = NULL WHERE id = pg_temp.f_id('f', 3);
  PERFORM set_config('app.user_id', '', true);
END;
$$;
DO $$
DECLARE
  c jsonb;
BEGIN
  PERFORM contract_deal_match_pending();
  ASSERT (SELECT deal_match FROM contract WHERE id = pg_temp.f_id('z', 6)) = 'caka', 'nejednoznačná zhoda → Nespárované';
  c := contract_deal_candidates(pg_temp.f_id('z', 6));
  ASSERT (SELECT count(*) FROM jsonb_array_elements(c) x WHERE (x->>'ok')::boolean) = 2, 'dvaja kandidáti: ' || c::text;
  ASSERT (SELECT deal_match FROM contract WHERE id = pg_temp.f_id('z', 7)) = 'caka', 'žiadna zhoda → Nespárované';
  ASSERT (SELECT (deal_match, deal_id) FROM contract WHERE id = pg_temp.f_id('z', 8)) = ROW('bez_obchodu'::text, NULL::uuid), 'domácnosť → Bez obchodu';
  -- firma F3 nemá vlastníka → admini
  ASSERT EXISTS (SELECT 1 FROM notification WHERE kind = 'nesparovana_zmluva' AND contract_id = pg_temp.f_id('z', 6) AND user_id = pg_temp.f_id('u', 2)), 'admin upozornený';
  ASSERT NOT EXISTS (SELECT 1 FROM notification WHERE kind = 'nesparovana_zmluva' AND contract_id = pg_temp.f_id('z', 6) AND user_id = pg_temp.f_id('u', 1)), 'obchodník nie (nie je vlastník zákazníka)';
  PERFORM contract_deal_match_pending();
  ASSERT (SELECT count(*) FROM notification WHERE kind = 'nesparovana_zmluva' AND contract_id = pg_temp.f_id('z', 6) AND user_id = pg_temp.f_id('u', 2)) = 1, 'upozornenie raz';
  RAISE NOTICE 'OK: F5 Akceptácia aj Vyjednávanie = nejednoznačné → Nespárované; žiadna zhoda → Nespárované; upozornenie raz (bez vlastníka zákazníka adminom); domácnosť → Bez obchodu';
END;
$$;
-- s vlastníkom zákazníka ide upozornenie jemu
DO $$
BEGIN
  PERFORM set_config('app.user_id', pg_temp.f_id('u', 2)::text, true);   -- admin smie meniť vlastníka
  UPDATE company SET owner_id = pg_temp.f_id('u', 1) WHERE id = pg_temp.f_id('f', 3);
  PERFORM set_config('app.user_id', '', true);
END;
$$;
UPDATE contract SET deal_match_notified_at = NULL WHERE id = pg_temp.f_id('z', 7);
DO $$
BEGIN
  PERFORM contract_deal_match_pending();
  ASSERT EXISTS (SELECT 1 FROM notification WHERE kind = 'nesparovana_zmluva' AND contract_id = pg_temp.f_id('z', 7) AND user_id = pg_temp.f_id('u', 1)), 'vlastník zákazníka';
  RAISE NOTICE 'OK: F5 upozornenie na nespárovanú zmluvu vlastníkovi zákazníka';
END;
$$;

-- ============================================================================
-- F6. Ručne: vybrať obchod / Bez obchodu (vlastník zákazníka alebo admin), zrušiť spárovanie (admin s dôvodom); Nespárované podľa práv
-- ============================================================================
SET LOCAL ROLE crm_rls_test;
DO $$
DECLARE
  u jsonb;
BEGIN
  PERFORM pg_temp.f_as(pg_temp.f_id('u', 1));
  u := contract_unmatched();
  ASSERT EXISTS (SELECT 1 FROM jsonb_array_elements(u) x WHERE (x->>'contract_id')::uuid = pg_temp.f_id('z', 6) AND (x->>'can_decide')::boolean), 'vlastník vidí a rozhoduje';
  PERFORM pg_temp.f_as(pg_temp.f_id('u', 4));
  ASSERT NOT EXISTS (SELECT 1 FROM jsonb_array_elements(contract_unmatched()) x WHERE (x->>'contract_id')::uuid = pg_temp.f_id('z', 6)), 'cudzí nevidí';
  BEGIN
    PERFORM contract_deal_pick(pg_temp.f_id('z', 6), pg_temp.f_id('d', 4));
    RAISE EXCEPTION 'CHYBA: cudzí vybral obchod';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM pg_temp.f_as(pg_temp.f_id('u', 1));
  BEGIN
    PERFORM contract_deal_pick(pg_temp.f_id('z', 6), pg_temp.f_id('d', 1));
    RAISE EXCEPTION 'CHYBA: obchod iného zákazníka';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  PERFORM contract_deal_pick(pg_temp.f_id('z', 6), pg_temp.f_id('d', 4));
  PERFORM contract_deal_none(pg_temp.f_id('z', 7), 'zmluva z webu');
  BEGIN
    PERFORM contract_deal_unlink(pg_temp.f_id('z', 6), 'omyl');
    RAISE EXCEPTION 'CHYBA: obchodník zrušil spárovanie';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM pg_temp.f_as(pg_temp.f_id('u', 2));
  BEGIN
    PERFORM contract_deal_unlink(pg_temp.f_id('z', 2), ' ');
    RAISE EXCEPTION 'CHYBA: bez dôvodu';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  PERFORM pg_temp.f_as(NULL);
  RAISE NOTICE 'OK: F6 ručne: obchod vyberá vlastník zákazníka alebo admin (iba ten istý zákazník a druh), Bez obchodu; zrušenie iba admin s dôvodom; Nespárované podľa práv';
END;
$$;
RESET ROLE;
-- zrušenie spárovania obchodu, ktorý má iba túto zmluvu: obchod späť do Akceptácie, výnimky a príznaky zmluvy preč
DO $$
BEGIN
  ASSERT (SELECT (deal_id, deal_match, deal_matched_by) FROM contract WHERE id = pg_temp.f_id('z', 6))
         = ROW(pg_temp.f_id('d', 4), 'rucne'::text, pg_temp.f_id('u', 1)), 'ručne spárované';
  ASSERT (SELECT deal_match FROM contract WHERE id = pg_temp.f_id('z', 7)) = 'bez_obchodu', 'bez obchodu';
  PERFORM set_config('app.require_user', 'on', true);
  PERFORM set_config('app.user_id', pg_temp.f_id('u', 2)::text, true);
  PERFORM contract_deal_unlink(pg_temp.f_id('z', 4), 'nesprávny obchod');
  PERFORM set_config('app.user_id', '', true);
  PERFORM set_config('app.require_user', '', true);
  ASSERT (SELECT (deal_id, deal_match) FROM contract WHERE id = pg_temp.f_id('z', 4)) = ROW(NULL::uuid, 'caka'::text), 'zmluva späť medzi nespárované';
  ASSERT (SELECT s.code FROM deal d JOIN pipeline_stage s ON s.id = d.stage_id WHERE d.id = pg_temp.f_id('d', 2)) = 'akceptacia', 'obchod späť v Akceptácii';
  ASSERT EXISTS (SELECT 1 FROM deal_event WHERE deal_id = pg_temp.f_id('d', 2) AND kind = 'zmluva_odparovana' AND detail->>'reason' = 'nesprávny obchod'), 'časová os';
  -- výnimky z ponuky pri zmluve F5-2 ostávajú, kým sa nezruší jej spárovanie
  PERFORM set_config('app.require_user', 'on', true);
  PERFORM set_config('app.user_id', pg_temp.f_id('u', 2)::text, true);
  PERFORM contract_deal_unlink(pg_temp.f_id('z', 2), 'test výnimky');
  PERFORM set_config('app.user_id', '', true);
  PERFORM set_config('app.require_user', '', true);
  ASSERT NOT EXISTS (SELECT 1 FROM price_exception WHERE contract_id = pg_temp.f_id('z', 2) AND approval_request_id IS NOT NULL), 'výnimka z ponuky zrušená';
  ASSERT (SELECT s.code FROM deal d JOIN pipeline_stage s ON s.id = d.stage_id WHERE d.id = pg_temp.f_id('d', 1)) = 'vyhrane', 'obchod s ďalšou zmluvou (VN) ostáva Vyhraté';
  -- posledná zmluva obchodu spárovaná vo Vyjednávaní (bez akceptovanej ponuky): obchod späť do Vyjednávania, aj keby
  -- medzitým mal akceptovaný variant
  UPDATE deal SET accepted_variant_id = (SELECT v.id FROM offer_variant v JOIN offer o ON o.id = v.offer_id WHERE o.deal_id = pg_temp.f_id('d', 3) LIMIT 1)
   WHERE id = pg_temp.f_id('d', 3);
  PERFORM set_config('app.require_user', 'on', true);
  PERFORM set_config('app.user_id', pg_temp.f_id('u', 2)::text, true);
  PERFORM contract_deal_unlink(pg_temp.f_id('z', 5), 'test vyjednávania');
  -- posledná spárovaná zmluva obchodu 1 (VN): späť do Akceptácie
  PERFORM contract_deal_unlink(pg_temp.f_id('z', 3), 'test poslednej zmluvy');
  PERFORM set_config('app.user_id', '', true);
  PERFORM set_config('app.require_user', '', true);
  ASSERT (SELECT s.code FROM deal d JOIN pipeline_stage s ON s.id = d.stage_id WHERE d.id = pg_temp.f_id('d', 3)) = 'vyjednavanie',
         'spárované bez akceptovanej ponuky → späť do Vyjednávania';
  ASSERT (SELECT s.code FROM deal d JOIN pipeline_stage s ON s.id = d.stage_id WHERE d.id = pg_temp.f_id('d', 1)) = 'akceptacia',
         'posledná zmluva s akceptovaným variantom → späť do Akceptácie';
  ASSERT EXISTS (SELECT 1 FROM deal_event WHERE deal_id = pg_temp.f_id('d', 3) AND kind = 'zmluva_odparovana' AND detail->>'stage' = 'vyjednavanie'), 'časová os so štádiom';
  RAISE NOTICE 'OK: F6 zrušenie spárovania: s ďalšou spárovanou zmluvou ostáva Vyhraté; posledná zmluva → späť do štádia spárovania (Akceptácia / Vyjednávanie); výnimka z ponuky zrušená, časová os';
END;
$$;

-- ============================================================================
-- F7. Práva funkcií: interné nie sú pre aplikáciu
-- ============================================================================
DO $$
BEGIN
  ASSERT NOT has_function_privilege('crm_rls_test', 'contract_deal_link(uuid, uuid, text, uuid)', 'EXECUTE')
     AND NOT has_function_privilege('crm_rls_test', 'contract_deal_match_pending()', 'EXECUTE')
     AND NOT has_function_privilege('crm_rls_test', 'contract_offer_exceptions(uuid)', 'EXECUTE'), 'interné funkcie';
  RAISE NOTICE 'OK: F7 párovanie a prenos výnimiek spúšťa iba import (interné funkcie nie sú pre aplikáciu)';
END;
$$;
