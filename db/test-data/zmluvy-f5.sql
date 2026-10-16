-- Vygenerované z db/test-data/zmluvy-f5-vytvor.cjs – NEUPRAVOVAŤ RUČNE. Spúšťa ./db/test-data/zmluvy-f5.sh dev vytvor.
-- Testovacie obchody a ponuky pre skúšku párovania zmlúv (F5) so zhodnými EIC a cenami ako zmluvy-f5-office-portal.xlsx.
-- Vymyslené firmy (IČO 99999905–07) a OOM (EIC 24ZZS99TESTF…). Obchodník = e-mail v premennej psql owner.
\set ON_ERROR_STOP on
BEGIN;
SELECT set_config('f5.owner', :'owner', true) \gset
DO $f5$
DECLARE
  v_user  uuid := (SELECT id FROM app_user WHERE lower(email) = lower(current_setting('f5.owner')) AND status = 'aktivny');
  v_org   uuid := crm_default_org();
  v_offer uuid;
  v_var   uuid;
  r       record;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'Chýba aktívny používateľ – zadajte e-mail obchodníka.';
  END IF;
  IF EXISTS (SELECT 1 FROM company WHERE id IN ('00000000-0000-4000-9000-000000005101', '00000000-0000-4000-9000-000000005102', '00000000-0000-4000-9000-000000005103') OR ico IN ('99999905', '99999906', '99999907')) THEN
    RAISE EXCEPTION 'Testovacie dáta F5 už existujú – najprv ./db/test-data/zmluvy-f5.sh dev zmaz';
  END IF;
  INSERT INTO company (id, name, ico, dic, ic_dph, address, is_customer, owner_id, country) VALUES
    ('00000000-0000-4000-9000-000000005101', 'Testovacia Epsilon s.r.o.', '99999905', '2099999905', 'SK2099999905', 'Testovacia 5, 999 01 Skúšobná Ves', true, v_user, 'SK'),
    ('00000000-0000-4000-9000-000000005102', 'Testovacia Zeta s.r.o.', '99999906', '2099999906', 'SK2099999906', 'Testovacia 5, 999 01 Skúšobná Ves', true, v_user, 'SK'),
    ('00000000-0000-4000-9000-000000005103', 'Testovacia Théta s.r.o.', '99999907', '2099999907', 'SK2099999907', 'Testovacia 5, 999 01 Skúšobná Ves', true, v_user, 'SK');
  INSERT INTO oom (id, company_id, eic, type, status, voltage_level, planned_consumption_vt_mwh) VALUES
    ('00000000-0000-4000-9000-000000005201', '00000000-0000-4000-9000-000000005101', '24ZZS99TESTFA01K', 'spotreba', 'pripravovane', 'nn', 30),
    ('00000000-0000-4000-9000-000000005202', '00000000-0000-4000-9000-000000005101', '24ZZS99TESTFA02I', 'spotreba', 'pripravovane', 'vn', 200),
    ('00000000-0000-4000-9000-000000005203', '00000000-0000-4000-9000-000000005102', '24ZZS99TESTFA03G', 'spotreba', 'pripravovane', 'nn', 25),
    ('00000000-0000-4000-9000-000000005204', '00000000-0000-4000-9000-000000005101', '24ZZS99TESTFA04E', 'spotreba', 'pripravovane', 'nn', 15),
    ('00000000-0000-4000-9000-000000005205', '00000000-0000-4000-9000-000000005103', '24ZZS99TESTFA05C', 'spotreba', 'pripravovane', 'nn', 20);

  -- obchody: 1 Epsilon (Akceptácia, NN + VN), 2 Zeta (Akceptácia, cena 125), 3 Théta (Vyjednávanie, bez ponuky)
  INSERT INTO deal (id, company_id, pipeline_id, stage_id, name, owner_id, source_code, supply_start, org_id)
  SELECT x.id::uuid, x.company::uuid, p.id, s.id, x.name, v_user, 'vlastny_kontakt', '2027-01-01', v_org
    FROM (VALUES ('00000000-0000-4000-9000-000000005301', '00000000-0000-4000-9000-000000005101', 'TEST F5 Epsilon 2027 (NN + VN)'),
                 ('00000000-0000-4000-9000-000000005302', '00000000-0000-4000-9000-000000005102', 'TEST F5 Zeta 2027 (iná cena)'),
                 ('00000000-0000-4000-9000-000000005303', '00000000-0000-4000-9000-000000005103', 'TEST F5 Théta 2027 (Vyjednávanie)')) x(id, company, name)
    JOIN pipeline p ON p.kind = 'b2b_dodavka' AND p.archived_at IS NULL AND (p.org_id IS NULL OR p.org_id = v_org)
    JOIN pipeline_stage s ON s.pipeline_id = p.id AND s.code = 'prilezitost';
  INSERT INTO deal_oom (deal_id, oom_id) VALUES
    ('00000000-0000-4000-9000-000000005301', '00000000-0000-4000-9000-000000005201'), ('00000000-0000-4000-9000-000000005301', '00000000-0000-4000-9000-000000005202'), ('00000000-0000-4000-9000-000000005302', '00000000-0000-4000-9000-000000005203'), ('00000000-0000-4000-9000-000000005303', '00000000-0000-4000-9000-000000005205');
  UPDATE deal d SET stage_id = s.id FROM pipeline_stage s
   WHERE d.id = '00000000-0000-4000-9000-000000005303' AND s.pipeline_id = d.pipeline_id AND s.code = 'vyjednavanie';

  -- ponuky s FIX 2027 podľa OOM, odoslané a ručne akceptované (obchod prejde do Akceptácie)
  FOR r IN SELECT * FROM (VALUES ('00000000-0000-4000-9000-000000005301'::uuid), ('00000000-0000-4000-9000-000000005302'::uuid)) x(deal_id) LOOP
    PERFORM set_config('app.user_id', v_user::text, true);
    v_offer := offer_create(r.deal_id);
    PERFORM set_config('app.user_id', '', true);
    v_var := (SELECT id FROM offer_variant WHERE offer_id = v_offer ORDER BY sort_order LIMIT 1);
    DELETE FROM offer_item WHERE variant_id = v_var;
    INSERT INTO offer_item (variant_id, oom_id, year, slot, product_id, price_model, price_vt_eur_mwh)
    SELECT v_var, x.oom_id, 2027, 'komodita', (SELECT id FROM product WHERE code = 'green_1t'), 'fix', o.price
      FROM deal_oom x JOIN (VALUES ('00000000-0000-4000-9000-000000005201'::uuid, 120), ('00000000-0000-4000-9000-000000005202'::uuid, 110), ('00000000-0000-4000-9000-000000005203'::uuid, 125)) o(oom_id, price) ON o.oom_id = x.oom_id
     WHERE x.deal_id = r.deal_id;
    UPDATE offer SET status = 'odoslana', sent_at = now(), sent_by = v_user, sent_channel = 'osobne',
                     valid_until = now() + interval '14 days', sent_note = 'test F5'
     WHERE id = v_offer;
    PERFORM set_config('app.user_id', v_user::text, true);
    PERFORM offer_accept_manual(v_offer, v_var, 'Ján Skúšobný', 'konateľ', now(), 'telefon', 'test F5', NULL);
    PERFORM set_config('app.user_id', '', true);
  END LOOP;
  RAISE NOTICE 'Založené: 3 firmy, 5 OOM, 3 obchody (2 v Akceptácii s ponukou, 1 vo Vyjednávaní).';
END;
$f5$;
COMMIT;
