-- Vygenerované z db/test-data/zmluvy-f5-vytvor.cjs – NEUPRAVOVAŤ RUČNE. Spúšťa ./db/test-data/zmluvy-f5.sh dev zmaz.
-- Zmaže iba testovacie dáta F5: zmluvy 1129995001–08, obchody (aj Obnova k zmluvám 07, 08), ponuky, OOM, firmy a domácnosť „Eva Pokusná“.
\set ON_ERROR_STOP on
BEGIN;
DO $f5$
DECLARE
  v_k uuid[] := ARRAY(SELECT id FROM contract WHERE number IN ('1129995001', '1129995002', '1129995003', '1129995004', '1129995005', '1129995006', '1129995007', '1129995008'));
  v_d uuid[] := ARRAY['00000000-0000-4000-9000-000000005301'::uuid, '00000000-0000-4000-9000-000000005302'::uuid, '00000000-0000-4000-9000-000000005303'::uuid, '00000000-0000-4000-9000-000000005304'::uuid]
                || ARRAY(SELECT d.id FROM deal d JOIN contract k ON k.id = d.previous_contract_id
                          WHERE k.number IN ('1129995007', '1129995008') AND d.source_code = 'obnova');
  v_o uuid[] := ARRAY(SELECT id FROM oom WHERE eic IN ('24ZZS99TESTFA01K', '24ZZS99TESTFA02I', '24ZZS99TESTFA03G', '24ZZS99TESTFA04E', '24ZZS99TESTFA05C', '24ZZS99TESTFA06A', '24ZZS99TESTFA078', '24ZZS99TESTFA086'));
  v_c uuid[] := ARRAY['00000000-0000-4000-9000-000000005101'::uuid, '00000000-0000-4000-9000-000000005102'::uuid, '00000000-0000-4000-9000-000000005103'::uuid, '00000000-0000-4000-9000-000000005104'::uuid];
  v_p uuid[] := ARRAY(SELECT o.person_id FROM oom o WHERE o.eic = '24ZZS99TESTFA06A' AND o.person_id IS NOT NULL);
  v_f uuid[];
BEGIN
  v_f := ARRAY(SELECT id FROM offer WHERE deal_id = ANY (v_d));
  DELETE FROM notification WHERE contract_id = ANY (v_k) OR deal_id = ANY (v_d);
  UPDATE deal SET previous_contract_id = NULL WHERE previous_contract_id = ANY (v_k);
  DELETE FROM contract_flag WHERE contract_id = ANY (v_k);
  DELETE FROM contract_year_basis WHERE contract_id = ANY (v_k);
  DELETE FROM price_exception WHERE contract_id = ANY (v_k);
  DELETE FROM contract_price WHERE contract_id = ANY (v_k);
  DELETE FROM contract_oom WHERE contract_id = ANY (v_k);
  DELETE FROM contract_import_change WHERE contract_id = ANY (v_k);
  DELETE FROM contract WHERE id = ANY (v_k);
  DELETE FROM email_outbox WHERE deal_id = ANY (v_d);
  DELETE FROM offer_acceptance WHERE offer_id = ANY (v_f);
  DELETE FROM offer_page_stat WHERE offer_id = ANY (v_f);
  DELETE FROM approval_price_item WHERE approval_id IN (SELECT id FROM approval_request WHERE deal_id = ANY (v_d));
  DELETE FROM approval_request WHERE deal_id = ANY (v_d);
  DELETE FROM email_message WHERE thread_id IN (SELECT id FROM email_thread WHERE deal_id = ANY (v_d));
  DELETE FROM email_thread WHERE deal_id = ANY (v_d);
  DELETE FROM offer_item WHERE variant_id IN (SELECT id FROM offer_variant WHERE offer_id = ANY (v_f));
  UPDATE deal SET accepted_variant_id = NULL WHERE id = ANY (v_d);
  DELETE FROM offer_variant WHERE offer_id = ANY (v_f);
  DELETE FROM offer WHERE id = ANY (v_f);
  DELETE FROM deal_contract_input WHERE deal_id = ANY (v_d);
  DELETE FROM deal_event WHERE deal_id = ANY (v_d);
  -- kontrola „obchod v štádiu ponuky musí mať OOM“ by zastavila mazanie OOM otvoreného obchodu – obchod sa maže celý
  ALTER TABLE deal_oom DISABLE TRIGGER trg_deal_oom_ready;
  DELETE FROM deal_oom WHERE deal_id = ANY (v_d);
  ALTER TABLE deal_oom ENABLE TRIGGER trg_deal_oom_ready;
  DELETE FROM deal_contact WHERE deal_id = ANY (v_d);
  DELETE FROM deal WHERE id = ANY (v_d);
  DELETE FROM oom_customer WHERE oom_id = ANY (v_o);
  DELETE FROM oom_contact WHERE oom_id = ANY (v_o);
  DELETE FROM oom_device WHERE oom_id = ANY (v_o);
  DELETE FROM oom_planned_change WHERE oom_id = ANY (v_o);
  DELETE FROM oom_price_regulation_change WHERE oom_id = ANY (v_o);
  DELETE FROM oom WHERE id = ANY (v_o);
  DELETE FROM company_contact WHERE company_id = ANY (v_c) OR contact_id = ANY (v_p);
  DELETE FROM company WHERE id = ANY (v_c);
  DELETE FROM contact WHERE id = ANY (v_p);
  RAISE NOTICE 'Zmazané testovacie dáta F5 (zmluvy %, obchody %, OOM %).', cardinality(v_k), cardinality(v_d), cardinality(v_o);
END;
$f5$;
COMMIT;
