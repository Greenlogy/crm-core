-- Kontroly modulu 5, fáza F3 (0039): šablóny ponúk a ich verzie, ceny VIWA z cenníka, dokument ponuky (premenné,
-- zlúčené riadky bez EIC a interných hodnôt), PDF a odkaz (iba odtlačok, nový odkaz iba vlastník alebo admin),
-- verejné funkcie pre rolu crm_public (zobrazenie, otvorenia, akceptácia s odtlačkom znenia, dvojklik, po platnosti),
-- ručná akceptácia, zrušenie akceptácie adminom, zablokovaná verzia a jej odblokovanie.
-- Spúšťa sa iba cez db/test/run.sh po checks_ponuky.sql (pomocné funkcie série B, rola crm_rls_test).
-- Vlastné záznamy: …-0000000a00xx používatelia, a01xx firmy, a02xx OOM, a03xx obchody, a04xx kontakty.

-- ============================================================================
-- Príprava (vlastník databázy)
-- ============================================================================

CREATE FUNCTION pg_temp.d_id(p_kind text, p_n integer) RETURNS uuid LANGUAGE sql AS $f$
  SELECT ('00000000-0000-4000-8000-0000000' || CASE p_kind WHEN 'u' THEN 'a00' WHEN 'f' THEN 'a01' WHEN 'oom' THEN 'a02'
                                                            WHEN 'd' THEN 'a03' ELSE 'a04' END || lpad(p_n::text, 2, '0'))::uuid
$f$;
CREATE FUNCTION pg_temp.d_eic(p_n integer) RETURNS text LANGUAGE plpgsql AS $f$
DECLARE
  l text;
  c text;
BEGIN
  FOREACH l IN ARRAY string_to_array('KLMNPQRSTUVW', NULL) LOOP
    FOREACH c IN ARRAY string_to_array('0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ', NULL) LOOP
      IF eic_is_valid('24ZZS000PDFA' || l || lpad(p_n::text, 2, '0') || c) THEN
        RETURN '24ZZS000PDFA' || l || lpad(p_n::text, 2, '0') || c;
      END IF;
    END LOOP;
  END LOOP;
END;
$f$;

-- 1 obchodník (vlastník), 2 interný obchodník (môže upravovať všetky obchody), 3 admin
INSERT INTO app_user (id, email, name, team_id, status, seller_type, is_admin, phone, job_title)
SELECT x.id::uuid, x.email, x.name, t.id, 'aktivny', x.st::seller_type, x.adm, '+421 900 000 001', 'obchodník'
  FROM (VALUES
    ('00000000-0000-4000-8000-0000000a0001', 'obchodnik.d@example.test', 'Obchodník D', 'test_predajcovia_b', 'obchodnik', false),
    ('00000000-0000-4000-8000-0000000a0002', 'interny.d@example.test', 'Interný D', 'sales_internal', 'obchodnik', false),
    ('00000000-0000-4000-8000-0000000a0003', 'admin.d@example.test', 'Admin D', 'sales_internal', NULL, true),
    ('00000000-0000-4000-8000-0000000a0004', 'schvalovatel.d@example.test', 'Schvaľovateľ D', 'sales_internal', NULL, false)
  ) AS x(id, email, name, team, st, adm)
  JOIN team t ON t.code = x.team;
UPDATE app_user SET approves_prices = true WHERE id = '00000000-0000-4000-8000-0000000a0004';
INSERT INTO app_user_org (user_id, org_id)
SELECT id, crm_default_org() FROM app_user WHERE id::text LIKE '00000000-0000-4000-8000-0000000a00%';

INSERT INTO company (id, name, ico, ic_dph, address, is_customer, owner_id) VALUES
  (pg_temp.d_id('f', 1), 'PDF Test D1 s.r.o.', '99999991', 'SK2099999991', 'Priemyselná 8, 036 01 Martin', true, pg_temp.d_id('u', 1)),
  (pg_temp.d_id('f', 2), 'VIWA Test D2 s.r.o.', '99999992', NULL, 'Hlavná 1, 010 01 Žilina', true, pg_temp.d_id('u', 1));
INSERT INTO contact (id, first_name, last_name, title, email, mobile, is_household)
VALUES (pg_temp.d_id('k', 1), 'Pavol', 'Testovací', 'Ing.', 'pavol.d@example.test', '+421 900 111 222', false);

-- OOM 1, 2 NN 20 MWh; 3 VN 200 MWh (firma D1); 4 výroba 100 kW (firma D2); 5 NN 30 MWh (firma D1, ručná akceptácia)
INSERT INTO oom (id, company_id, eic, type, status, voltage_level, planned_consumption_vt_mwh, source_power_kw)
SELECT pg_temp.d_id('oom', n), pg_temp.d_id('f', CASE WHEN n = 4 THEN 2 ELSE 1 END), pg_temp.d_eic(n),
       (CASE WHEN n = 4 THEN 'vyroba' ELSE 'spotreba' END)::oom_type, 'pripravovane',
       CASE WHEN n = 3 THEN 'vn' ELSE 'nn' END::voltage_level, CASE n WHEN 3 THEN 200 WHEN 4 THEN NULL WHEN 5 THEN 30 WHEN 6 THEN 25 ELSE 20 END,
       CASE WHEN n = 4 THEN 100 END
  FROM generate_series(1, 6) n;

INSERT INTO deal (id, company_id, pipeline_id, stage_id, name, owner_id, source_code, supply_start) VALUES
  (pg_temp.d_id('d', 1), pg_temp.d_id('f', 1), pg_temp.b_pipe('b2b_dodavka'), pg_temp.b_stage('b2b_dodavka', 'prilezitost'),
   'D1 2027', pg_temp.d_id('u', 1), 'web', '2027-01-01'),
  (pg_temp.d_id('d', 2), pg_temp.d_id('f', 2), pg_temp.b_pipe('green_viwa'), pg_temp.b_stage('green_viwa', 'prilezitost'),
   'D2 VIWA', pg_temp.d_id('u', 1), 'web', '2027-01-01'),
  (pg_temp.d_id('d', 3), pg_temp.d_id('f', 1), pg_temp.b_pipe('b2b_dodavka'), pg_temp.b_stage('b2b_dodavka', 'prilezitost'),
   'D3 ručne', pg_temp.d_id('u', 1), 'web', '2027-01-01'),
  (pg_temp.d_id('d', 4), pg_temp.d_id('f', 1), pg_temp.b_pipe('b2b_dodavka'), pg_temp.b_stage('b2b_dodavka', 'prilezitost'),
   'D4 pokuta', pg_temp.d_id('u', 1), 'web', '2027-01-01');
INSERT INTO deal_oom (deal_id, oom_id) VALUES
  (pg_temp.d_id('d', 1), pg_temp.d_id('oom', 1)), (pg_temp.d_id('d', 1), pg_temp.d_id('oom', 2)),
  (pg_temp.d_id('d', 1), pg_temp.d_id('oom', 3)), (pg_temp.d_id('d', 2), pg_temp.d_id('oom', 4)),
  (pg_temp.d_id('d', 3), pg_temp.d_id('oom', 5)), (pg_temp.d_id('d', 4), pg_temp.d_id('oom', 6));
INSERT INTO deal_contact (deal_id, contact_id, is_primary) VALUES (pg_temp.d_id('d', 1), pg_temp.d_id('k', 1), true);

-- práva ako aplikácia (app-role.sql, 0039)
GRANT SELECT, INSERT, UPDATE, DELETE ON offer_template_version TO crm_rls_test;
GRANT SELECT ON offer_acceptance, offer_page_stat, offer_asset TO crm_rls_test;
-- funkcie z migrácií po 0040 nemá PUBLIC – testovacia rola ich dostane ako crm_app (predvolené práva)
GRANT EXECUTE ON FUNCTION offer_acceptance_confirmation_set(uuid, text, text), offer_acceptance_for_confirmation(uuid) TO crm_rls_test;

-- ============================================================================
-- D0. Šablóny: prvé verzie, kontrola premenných, iba admin, verzie a zverejnenie
-- ============================================================================
DO $$
BEGIN
  ASSERT (SELECT count(*) FROM offer_template_version WHERE org_id = crm_default_org()) = 6, '3 druhy × 2 jazyky';
  ASSERT (SELECT count(*) FROM offer_template_version WHERE org_id = crm_default_org() AND language = 'sk' AND status = 'platna') = 3, 'SK platné';
  ASSERT (SELECT count(*) FROM offer_template_version WHERE org_id = crm_default_org() AND language = 'en' AND status = 'navrh') = 3, 'EN návrh';
  ASSERT offer_template_check('{"cenova_ponuka": {"nadpis": "3", "text": "«neznáma»"}}') LIKE 'Neznáma premenná%', 'neznáma premenná';
  ASSERT offer_template_check(jsonb_build_object('hlavicka', jsonb_build_object('text', 'x'), 'udaje', jsonb_build_object('text', 'x'),
           'predmet', jsonb_build_object('text', 'x'), 'platnost', jsonb_build_object('text', 'x'), 'objednavka', jsonb_build_object('text', 'x'),
           'cenova_ponuka', jsonb_build_object('text', '«tabuľka variantov» [[spot]]x'))) LIKE '%nie je uzavretý%', 'neuzavretý blok';
  RAISE NOTICE 'OK: D0 prvé verzie šablón (SK platné, EN návrh), kontrola premenných a blokov';
END;
$$;
SET LOCAL ROLE crm_rls_test;
DO $$
DECLARE
  v_sk  offer_template_version;
  v_new uuid;
BEGIN
  PERFORM set_config('app.require_user', 'on', true);
  PERFORM set_config('app.user_id', pg_temp.d_id('u', 1)::text, true);
  SELECT * INTO v_sk FROM offer_template_version WHERE org_id = crm_default_org() AND kind = 'dodavka' AND language = 'sk' AND status = 'platna';
  ASSERT EXISTS (SELECT 1 FROM offer_template_version WHERE id = v_sk.id), 'obchodník šablónu číta';
  BEGIN
    INSERT INTO offer_template_version (org_id, kind, language, sections) VALUES (crm_default_org(), 'dodavka', 'sk', v_sk.sections);
    RAISE EXCEPTION 'CHYBA: obchodník založil šablónu';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM set_config('app.user_id', pg_temp.d_id('u', 3)::text, true);
  BEGIN
    UPDATE offer_template_version SET note = 'zmena' WHERE id = v_sk.id;
    RAISE EXCEPTION 'CHYBA: platná šablóna zmenená';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    INSERT INTO offer_template_version (org_id, kind, language, sections)
    VALUES (crm_default_org(), 'dodavka', 'sk', jsonb_set(v_sk.sections, '{predmet,text}', '"«zlá premenná»"'));
    RAISE EXCEPTION 'CHYBA: šablóna s neznámou premennou';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  INSERT INTO offer_template_version (org_id, kind, language, sections, defaults, status)
  VALUES (crm_default_org(), 'dodavka', 'sk', jsonb_set(v_sk.sections, '{predmet,text}', '"2.1 Upravený predmet ponuky."'), v_sk.defaults, 'platna')
  RETURNING id INTO v_new;
  ASSERT (SELECT (status, version) FROM offer_template_version WHERE id = v_new) = ROW('navrh'::text, 2::smallint), 'nová verzia je návrh v2';
  PERFORM offer_template_publish(v_new);
  ASSERT (SELECT status FROM offer_template_version WHERE id = v_sk.id) = 'nahradena', 'v1 nahradená';
  ASSERT (SELECT status FROM offer_template_version WHERE id = v_new) = 'platna', 'v2 platná';
  PERFORM set_config('app.user_id', '', true);
  PERFORM set_config('app.require_user', '', true);
  RAISE NOTICE 'OK: D0 šablónu číta každý, mení iba admin; platná sa nemení; neznáma premenná neprejde; nová verzia = návrh, zverejnenie nahradí platnú';
END;
$$;

-- ============================================================================
-- D1. Ceny VIWA z cenníka (balík, mesačný poplatok účtu, €/kW) – ak je na databáze cenník VIWA
-- ============================================================================
DO $$
DECLARE
  v_offer uuid;
  v_var   uuid;
  doc     jsonb;
BEGIN
  PERFORM set_config('app.require_user', 'on', true);
  PERFORM set_config('app.user_id', pg_temp.d_id('u', 1)::text, true);
  v_offer := offer_create(pg_temp.d_id('d', 2));
  v_var := (SELECT id FROM offer_variant WHERE offer_id = v_offer);
  IF NOT EXISTS (SELECT 1 FROM price_list_item i JOIN product p ON p.id = i.product_id JOIN price_list_version pv ON pv.id = i.version_id
                  WHERE p.code = 'viwa_plus' AND pv.status = 'schvalena' AND pv.valid_from <= '2027-01-01'
                    AND (pv.valid_to IS NULL OR pv.valid_to >= '2027-01-01')) THEN
    RAISE NOTICE 'D1 preskočené: na databáze nie je schválený cenník VIWA';
  ELSE
    ASSERT (SELECT count(*) FROM offer_item WHERE variant_id = v_var AND slot = 'viwa_ucet') = 1, 'mesačný poplatok účtu';
    ASSERT (SELECT count(*) FROM offer_item WHERE variant_id = v_var AND slot = 'viwa_kw' AND fee_kw_eur_month IS NOT NULL) = 1, '€/kW pre OOM';
    ASSERT NOT EXISTS (SELECT 1 FROM offer_variant_values(v_var) WHERE missing IS NOT NULL), 'VIWA bez chýbajúcej ceny';
    doc := offer_document(v_offer);
    ASSERT (doc->'variants'->0->'viwa'->>'coefficient')::numeric = 0.80, 'koeficient Plus 0,80: ' || (doc->'variants'->0->'viwa')::text;
    ASSERT doc->'vars'->>'koeficient' = '0,80', 'premenná koeficient';
    ASSERT doc->'template'->>'order_title' = 'PRIJATIE PONUKY', 'VIWA: prijatie ponuky, nie záväzná objednávka';
    UPDATE offer_variant SET viwa_package = 'pro' WHERE id = v_var;
    ASSERT (SELECT (offer_document(v_offer)->'variants'->0->'viwa'->>'coefficient')::numeric) = 0.85, 'zmena balíka → Pro 0,85';
    RAISE NOTICE 'OK: D1 VIWA: poplatok účtu, €/kW a koeficient z programu položky cenníka, zmena balíka prepočíta';
  END IF;
  PERFORM set_config('app.user_id', '', true);
  PERFORM set_config('app.require_user', '', true);
END;
$$;

-- zmena odhadu aditívu VIWA (iba pre pridanú hodnotu) koeficient v ponuke nemení
RESET ROLE;
INSERT INTO price_parameter (org_id, code, valid_from, value)
SELECT crm_default_org(), 'viwa_aditiv_pro', crm_today(), 40
 WHERE EXISTS (SELECT 1 FROM offer o JOIN offer_variant v ON v.offer_id = o.id
                WHERE o.deal_id = pg_temp.d_id('d', 2) AND v.viwa_package = 'pro');
DO $$
DECLARE
  v_offer uuid := (SELECT id FROM offer WHERE deal_id = pg_temp.d_id('d', 2));
BEGIN
  IF EXISTS (SELECT 1 FROM offer_item i JOIN offer_variant v ON v.id = i.variant_id WHERE v.offer_id = v_offer AND i.slot = 'viwa_ucet') THEN
    ASSERT contract_param(crm_default_org(), 'viwa_aditiv_pro', crm_today()) = 40, 'nový odhad aditívu';
    ASSERT (offer_document_internal(v_offer)->'variants'->0->'viwa'->>'coefficient')::numeric = 0.85,
           'koeficient ostal 0,85 (zmluvná podmienka balíka): ' || (offer_document_internal(v_offer)->'variants'->0->'viwa')::text;
    RAISE NOTICE 'OK: D1 zmena odhadu aditívu VIWA nezmení koeficient v ponuke';
  END IF;
END;
$$;
SET LOCAL ROLE crm_rls_test;

-- ============================================================================
-- D2. Dokument ponuky: premenné, zlúčené riadky, bez EIC a interných hodnôt; EN návrh neodíde
-- ============================================================================
DO $$
DECLARE
  v_offer uuid;
  v_var   uuid;
  doc     jsonb;
  r       jsonb;
BEGIN
  PERFORM set_config('app.require_user', 'on', true);
  PERFORM set_config('app.user_id', pg_temp.d_id('u', 1)::text, true);
  v_offer := offer_create(pg_temp.d_id('d', 1));
  v_var := (SELECT id FROM offer_variant WHERE offer_id = v_offer);
  -- NN 120 (dve OOM → jeden riadok), VN 118
  INSERT INTO offer_item (variant_id, oom_id, year, slot, product_id, price_model, price_vt_eur_mwh)
  SELECT v_var, pg_temp.d_id('oom', n), 2027, 'komodita', (SELECT id FROM product WHERE code = 'green_1t'), 'fix', CASE WHEN n = 3 THEN 118 ELSE 120 END
    FROM generate_series(1, 3) n;
  doc := offer_document(v_offer);
  ASSERT doc->'template'->>'status' = 'platna', 'šablóna SK platná';
  ASSERT jsonb_array_length(doc->'variants'->0->'rows') = 2, 'NN zlúčené do jedného riadku: ' || (doc->'variants'->0->'rows')::text;
  SELECT x INTO r FROM jsonb_array_elements(doc->'variants'->0->'rows') x WHERE x->>'voltage_group' = 'nn';
  ASSERT (r->>'oom_count')::int = 2 AND (r->>'volume_mwh')::numeric = 40 AND r->'prices'->0->>'text' = '120,00 €/MWh', 'riadok NN: ' || r::text;
  ASSERT doc->'vars'->>'názov' = 'PDF Test D1 s.r.o.' AND doc->'vars'->>'IČ DPH' = 'SK2099999991'
         AND doc->'vars'->>'kontakt meno' = 'Ing. Pavol Testovací' AND doc->'vars'->>'obchodník telefón' = '+421 900 000 001', 'premenné: ' || (doc->'vars')::text;
  ASSERT doc->'vars'->>'zmluvná pokuta' = '50,00' AND doc->'vars'->>'objem' = '240,0' AND doc->'vars'->>'flexibilita' = 'plnej flexibility'
         AND doc->'vars'->>'splatnosť faktúr' = '14 dní' AND doc->'vars'->>'platnosť čas' = '16:00', 'predvolené hodnoty: ' || (doc->'vars')::text;
  ASSERT NOT EXISTS (SELECT 1 FROM jsonb_array_elements(doc->'sections') s WHERE (s->>'text') ~ '«(?!tabuľka variantov)' OR (s->>'text') LIKE '%[[%'),
         'všetky premenné a bloky doplnené';
  ASSERT NOT EXISTS (SELECT 1 FROM jsonb_array_elements(doc->'sections') s WHERE s->>'key' = 'cenova_ponuka' AND s->>'text' LIKE '%ISOT%'),
         'FIX bez bodov o SPOT';
  ASSERT doc->'variants'->0->>'terms' LIKE '%variant A · FIX 2027%' AND doc->'variants'->0->>'terms' LIKE '%50,00 €%', 'znenie objednávky';
  ASSERT doc->'variants'->0->>'terms_sha256' = offer_terms_sha(doc->'variants'->0->>'terms'), 'odtlačok znenia';
  ASSERT doc::text NOT LIKE '%' || pg_temp.d_eic(1) || '%' AND doc::text NOT LIKE '%' || pg_temp.d_eic(3) || '%', 'dokument bez EIC';
  ASSERT doc::text !~ '(threshold|margin|added_value|trader_price|portfolio|commission)', 'dokument bez interných hodnôt';
  -- SPOT variant doplní body 3.4–3.6
  PERFORM offer_variant_add(v_offer, 'spot');
  ASSERT (SELECT bool_or(s->>'text' LIKE '%ISOT OKTE zvýšená o aditív%') FROM jsonb_array_elements(offer_document(v_offer)->'sections') s), 'SPOT body';
  DELETE FROM offer_variant WHERE offer_id = v_offer AND sort_order = 2;
  -- zmluvná pokuta pri ponuke (premenné pole)
  UPDATE offer SET penalty_eur_mwh = 45 WHERE id = v_offer;
  ASSERT offer_document(v_offer)->'vars'->>'zmluvná pokuta' = '45,00', 'zmluvná pokuta z ponuky';
  UPDATE offer SET penalty_eur_mwh = NULL WHERE id = v_offer;
  -- EN: náhľad z návrhu šablóny
  UPDATE offer SET language = 'en' WHERE id = v_offer;
  doc := offer_document(v_offer);
  ASSERT doc->'template'->>'status' = 'navrh' AND doc->'vars'->>'flexibilita' = 'full' AND doc->'vars'->>'objem' = '240.0', 'EN náhľad: ' || (doc->'vars')::text;
  UPDATE offer SET language = 'sk' WHERE id = v_offer;
  -- kto obchod nevidí, dokument nedostane
  PERFORM set_config('app.user_id', pg_temp.b_id('u', 6)::text, true);
  ASSERT offer_document(v_offer) IS NULL, 'cudzí obchodník dokument nevidí';
  PERFORM set_config('app.user_id', '', true);
  PERFORM set_config('app.require_user', '', true);
  RAISE NOTICE 'OK: D2 dokument: premenné z firmy, kontaktu a obchodníka, predvolené podmienky, NN zlúčené, bez EIC a interných hodnôt, SPOT body iba pri SPOT, pokuta z ponuky, EN náhľad z návrhu, cudzí nevidí';
END;
$$;

-- ============================================================================
-- D3. Odoslanie: PDF raz, šablóna sa zafixuje, odkaz (iba odtlačok), nový odkaz iba vlastník alebo admin
-- ============================================================================
DO $$
DECLARE
  v_offer uuid := (SELECT id FROM offer WHERE deal_id = pg_temp.d_id('d', 1) AND version = 1);
  o       offer;
BEGIN
  PERFORM set_config('app.require_user', 'on', true);
  PERFORM set_config('app.user_id', pg_temp.d_id('u', 1)::text, true);
  BEGIN
    PERFORM offer_attach_pdf(v_offer, 'ponuky/' || crm_default_org() || '/2026/P26-000001.pdf', repeat('a', 64));
    RAISE EXCEPTION 'CHYBA: PDF pri koncepte';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  ASSERT offer_prepare(v_offer) = 'pripravena', 'pripravená';
  PERFORM offer_mark_sent(v_offer, now(), 'email_mimo_crm', NULL);
  SELECT * INTO o FROM offer WHERE id = v_offer;
  PERFORM offer_attach_pdf(v_offer, 'ponuky/' || crm_default_org() || '/2026/' || o.number || '.pdf', repeat('b', 64));
  ASSERT (SELECT template_version_id IS NOT NULL AND pdf_sha256 = repeat('b', 64) FROM offer WHERE id = v_offer), 'PDF a šablóna uložené';
  BEGIN
    PERFORM offer_attach_pdf(v_offer, 'ponuky/' || crm_default_org() || '/2026/' || o.number || '.pdf', repeat('c', 64));
    RAISE EXCEPTION 'CHYBA: PDF prepísané';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  PERFORM offer_link_set(v_offer, encode(sha256('token-1'::bytea), 'hex'));
  -- interný obchodník smie obchod upravovať, ale nový odkaz nie
  PERFORM set_config('app.user_id', pg_temp.d_id('u', 2)::text, true);
  BEGIN
    PERFORM offer_link_set(v_offer, encode(sha256('token-x'::bytea), 'hex'));
    RAISE EXCEPTION 'CHYBA: nový odkaz od nevlastníka';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM set_config('app.user_id', pg_temp.d_id('u', 3)::text, true);
  PERFORM offer_link_set(v_offer, encode(sha256('token-2'::bytea), 'hex'));
  ASSERT (SELECT link_hash FROM offer WHERE id = v_offer) = encode(sha256('token-2'::bytea), 'hex'), 'admin vytvoril nový odkaz';
  ASSERT (SELECT valid_until FROM offer WHERE id = v_offer) = o.valid_until, 'platnosť sa nezmenila';
  ASSERT EXISTS (SELECT 1 FROM deal_event WHERE offer_id = v_offer AND kind = 'ponuka_odkaz'), 'nový odkaz v časovej osi';
  ASSERT EXISTS (SELECT 1 FROM audit_log WHERE table_name = 'offer' AND record_id = v_offer AND diff ? 'link_hash'), 'nový odkaz v audite';
  -- rozpracovaná verzia 2 (D4: akceptácia verzie 1 ju zablokuje)
  PERFORM set_config('app.user_id', pg_temp.d_id('u', 1)::text, true);
  PERFORM offer_new_version(v_offer);
  PERFORM set_config('app.user_id', '', true);
  PERFORM set_config('app.require_user', '', true);
  RAISE NOTICE 'OK: D3 PDF iba pri odoslaní a raz (šablóna sa zafixuje), odkaz iba ako odtlačok, nový odkaz vlastník/admin (nie iný obchodník), platnosť nezmenená, časová os a audit';
END;
$$;
RESET ROLE;

-- verejná rola (ako crm_public z api/db/public-role.sql)
CREATE ROLE crm_public_test NOLOGIN;
GRANT crm_public_test TO CURRENT_USER WITH SET TRUE, INHERIT FALSE;
GRANT USAGE ON SCHEMA verejne TO crm_public_test;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA verejne TO crm_public_test;

-- ============================================================================
-- D4. Verejná stránka: zobrazenie, otvorenia bez IP, akceptácia s odtlačkom, dvojklik
-- ============================================================================
SET LOCAL ROLE crm_public_test;
DO $$
DECLARE
  h    text := encode(sha256('token-2'::bytea), 'hex');
  v    jsonb;
  var  jsonb;
  r    jsonb;
  n    integer;
BEGIN
  BEGIN
    PERFORM 1 FROM public.offer;
    RAISE EXCEPTION 'CHYBA: verejná rola číta tabuľku';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    PERFORM public.offer_document_internal('00000000-0000-4000-8000-000000000000');
    RAISE EXCEPTION 'CHYBA: verejná rola volá internú funkciu';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  -- ani funkcie s právami vlastníka bez kontroly používateľa (odhad portfólia), ani s cudzou identitou
  BEGIN
    PERFORM public.contract_market_value(public.crm_default_org(), 2027::smallint, current_date, 'portfolio');
    RAISE EXCEPTION 'CHYBA: verejná rola číta odhad portfólia';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM set_config('app.user_id', pg_temp.d_id('u', 3)::text, true);
  BEGIN
    PERFORM public.offer_document((SELECT '00000000-0000-4000-8000-000000000000'::uuid));
    RAISE EXCEPTION 'CHYBA: verejná rola ako admin';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM set_config('app.user_id', '', true);
  ASSERT verejne.ponuka_zobrazit(encode(sha256('token-1'::bytea), 'hex'))->>'mode' = 'neplatny', 'starý odkaz neplatí';
  ASSERT verejne.ponuka_zobrazit('zly')->>'mode' = 'neplatny', 'nezmyselný odkaz';
  v := verejne.ponuka_zobrazit(h);
  ASSERT v->>'mode' = 'aktivna' AND (v->'pdf')::boolean, 'aktívna s PDF';
  ASSERT v::text NOT LIKE '%' || 'PDFA' || '%', 'bez EIC';
  ASSERT v::text !~ '(threshold|margin|added_value|trader_price|portfolio|commission|link_hash)', 'bez interných hodnôt';
  ASSERT v->'seller'->>'phone' = '+421 900 000 001', 'kontakt obchodníka';
  PERFORM verejne.ponuka_zobrazit(h);
  ASSERT verejne.ponuka_pdf(h)->>'pdf_key' LIKE 'ponuky/%', 'PDF na stiahnutie';
  var := v->'document'->'variants'->0;
  BEGIN
    PERFORM verejne.ponuka_akceptovat(h, (var->>'id')::uuid, 'Pavol Testovací', 'konateľ', '192.0.2.10', 'test', repeat('0', 64));
    RAISE EXCEPTION 'CHYBA: akceptácia s iným znením';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    PERFORM verejne.ponuka_akceptovat(h, (var->>'id')::uuid, ' ', 'konateľ', '192.0.2.10', 'test', var->>'terms_sha256');
    RAISE EXCEPTION 'CHYBA: akceptácia bez mena';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  r := verejne.ponuka_akceptovat(h, (var->>'id')::uuid, 'Pavol Testovací', 'konateľ', '192.0.2.10', 'Mozilla/5.0 test', var->>'terms_sha256');
  ASSERT (r->>'ok')::boolean AND NOT (r->>'repeated')::boolean, 'akceptované: ' || left(r::text, 300);
  ASSERT r->>'terms_sha256' = var->>'terms_sha256' AND r->>'ip' = '192.0.2.10' AND r->>'terms_text' LIKE 'POTVRDENIE O PRIJATÍ PONUKY%'
         AND r->>'confirmation_key' ~ '^potvrdenia/[0-9a-f-]{36}/2026/P26-[0-9]{6}-[0-9a-f]{8}\.pdf$' AND NOT (r->>'confirmation_stored')::boolean,
         'údaje pre potvrdenie: ' || coalesce(r->>'confirmation_key', '–');
  -- potvrdenie v PDF (0041): uloží sa raz, s kľúčom z databázy, iba k akceptácii tejto ponuky
  BEGIN
    PERFORM verejne.ponuka_potvrdenie_ulozit(h, (r->>'acceptance_id')::uuid, r->>'confirmation_key' || 'x', repeat('c', 64));
    RAISE EXCEPTION 'CHYBA: potvrdenie s iným kľúčom';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    PERFORM verejne.ponuka_potvrdenie_ulozit(encode(sha256('token-1'::bytea), 'hex'), (r->>'acceptance_id')::uuid, r->>'confirmation_key', repeat('c', 64));
    RAISE EXCEPTION 'CHYBA: potvrdenie cez iný odkaz';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  ASSERT verejne.ponuka_potvrdenie_pdf(h) IS NULL, 'kým nie je uložené, nič';
  PERFORM verejne.ponuka_potvrdenie_ulozit(h, (r->>'acceptance_id')::uuid, r->>'confirmation_key', repeat('c', 64));
  BEGIN
    PERFORM verejne.ponuka_potvrdenie_ulozit(h, (r->>'acceptance_id')::uuid, r->>'confirmation_key', repeat('d', 64));
    RAISE EXCEPTION 'CHYBA: potvrdenie prepísané';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  ASSERT verejne.ponuka_potvrdenie_pdf(h)->>'pdf_key' = r->>'confirmation_key', 'uložené potvrdenie na stiahnutie';
  r := verejne.ponuka_akceptovat(h, (var->>'id')::uuid, 'Pavol Testovací', 'konateľ', '192.0.2.10', 'Mozilla/5.0 test', var->>'terms_sha256');
  ASSERT (r->>'repeated')::boolean AND (r->>'confirmation_stored')::boolean, 'dvojklik vráti ten istý výsledok (potvrdenie už uložené)';
  v := verejne.ponuka_zobrazit(h);
  ASSERT v->>'mode' = 'len_citanie' AND v->>'reason' = 'akceptovana' AND v->'document'->'acceptance'->>'signer_name' = 'Pavol Testovací'
         AND NOT (v->'document'->'variants'->0 ? 'terms'), 'po akceptácii len čítanie s potvrdením: ' || (v->'document'->'acceptance')::text;
  RAISE NOTICE 'OK: D4 verejná rola má iba schému verejne – nevidí tabuľky, interné funkcie, odhad portfólia ani s cudzím app.user_id; starý a zlý odkaz neplatí; stránka bez EIC a interných hodnôt; PDF; akceptácia iba so zhodným znením a menom; dvojklik; potom len čítanie';
END;
$$;
RESET ROLE;
DO $$
DECLARE
  v_offer uuid := (SELECT id FROM offer WHERE deal_id = pg_temp.d_id('d', 1) AND version = 1);
  a       offer_acceptance;
BEGIN
  SELECT * INTO a FROM offer_acceptance WHERE offer_id = v_offer;
  ASSERT (a.method, a.ip, a.signer_function, a.offer_pdf_sha256) = ROW('klik'::text, '192.0.2.10'::inet, 'konateľ'::text, repeat('b', 64)),
         'záznam akceptácie: ' || a::text;
  ASSERT a.confirmation_pdf_sha256 = repeat('c', 64) AND a.confirmation_pdf_key LIKE 'potvrdenia/%', 'odtlačok uloženého potvrdenia v DB';
  ASSERT a.terms_sha256 = offer_terms_sha(a.terms_text) AND a.terms_text LIKE 'POTVRDENIE O PRIJATÍ PONUKY%', 'znenie a odtlačok uložené';
  ASSERT (SELECT open_count FROM offer_page_stat WHERE offer_id = v_offer) = 3, 'počet otvorení (bez IP)';
  ASSERT (SELECT count(*) FROM deal_event WHERE offer_id = v_offer AND kind = 'ponuka_otvorena') = 1, 'prvé otvorenie raz v časovej osi';
  ASSERT (SELECT status FROM offer WHERE id = v_offer) = 'akceptovana', 'ponuka akceptovaná';
  ASSERT (SELECT blocked_by_offer_id FROM offer WHERE deal_id = pg_temp.d_id('d', 1) AND version = 2) = v_offer, 'verzia 2 zablokovaná akceptáciou';
  ASSERT (SELECT s.code FROM deal d JOIN pipeline_stage s ON s.id = d.stage_id WHERE d.id = pg_temp.d_id('d', 1)) = 'akceptacia', 'obchod v Akceptácii';
  RAISE NOTICE 'OK: D4 záznam akceptácie (klik, IP, funkcia, znenie s odtlačkom, odtlačok PDF), otvorenia, ponuka a obchod v Akceptácii';
END;
$$;

-- ============================================================================
-- D5. Zrušenie akceptácie adminom; zablokovaná verzia ostáva zablokovaná, odblokuje vlastník
-- ============================================================================
SET LOCAL ROLE crm_rls_test;
DO $$
DECLARE
  v_offer uuid := (SELECT id FROM offer WHERE deal_id = pg_temp.d_id('d', 1) AND version = 1);
  v_acc   uuid := (SELECT id FROM offer_acceptance WHERE offer_id = (SELECT id FROM offer WHERE deal_id = pg_temp.d_id('d', 1) AND version = 1));
BEGIN
  PERFORM set_config('app.require_user', 'on', true);
  PERFORM set_config('app.user_id', pg_temp.d_id('u', 1)::text, true);
  BEGIN
    INSERT INTO offer_acceptance (offer_id, variant_id, org_id, method, accepted_at, signer_name, signer_function, ip, terms_text, terms_sha256)
    SELECT offer_id, variant_id, org_id, 'klik', now(), 'x', 'y', '192.0.2.1', 'x', repeat('0', 64) FROM offer_acceptance WHERE id = v_acc;
    RAISE EXCEPTION 'CHYBA: akceptácia zapísaná priamo';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    PERFORM offer_acceptance_revoke(v_acc, 'omyl');
    RAISE EXCEPTION 'CHYBA: obchodník zrušil akceptáciu';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM set_config('app.user_id', pg_temp.d_id('u', 3)::text, true);
  BEGIN
    PERFORM offer_acceptance_revoke(v_acc, ' ');
    RAISE EXCEPTION 'CHYBA: zrušenie bez dôvodu';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  PERFORM set_config('app.user_id', '', true);
  PERFORM set_config('app.require_user', '', true);
END;
$$;
-- verzia 2 (založená v D3) je zablokovaná akceptáciou verzie 1 (D4)
DO $$
DECLARE
  v_offer uuid := (SELECT id FROM offer WHERE deal_id = pg_temp.d_id('d', 1) AND version = 1);
  v2      uuid := (SELECT id FROM offer WHERE deal_id = pg_temp.d_id('d', 1) AND version = 2);
  v_acc   uuid := (SELECT id FROM offer_acceptance WHERE offer_id = (SELECT id FROM offer WHERE deal_id = pg_temp.d_id('d', 1) AND version = 1));
BEGIN
  PERFORM set_config('app.require_user', 'on', true);
  PERFORM set_config('app.user_id', pg_temp.d_id('u', 3)::text, true);
  PERFORM offer_acceptance_revoke(v_acc, 'zákazník akceptoval omylom iný variant');
  ASSERT (SELECT revoked_at IS NOT NULL AND revoke_reason LIKE 'zákazník%' FROM offer_acceptance WHERE id = v_acc), 'zrušená s dôvodom';
  ASSERT (SELECT status FROM offer WHERE id = v_offer) = 'odoslana', 'ponuka späť Odoslaná';
  ASSERT (SELECT (s.code, d.accepted_variant_id IS NULL) FROM deal d JOIN pipeline_stage s ON s.id = d.stage_id WHERE d.id = pg_temp.d_id('d', 1))
         = ROW('vyjednavanie'::deal_stage_code, true), 'obchod vo Vyjednávaní bez variantu';
  ASSERT EXISTS (SELECT 1 FROM deal_event WHERE offer_id = v_offer AND kind = 'akceptacia_zrusena'), 'zrušenie v časovej osi';
  -- verzia 2 ostáva zablokovaná; odblokuje iba vlastník obchodu alebo admin
  ASSERT (SELECT bool_or(e LIKE '%zablokovaná%') FROM jsonb_array_elements_text(offer_check(v2)->'errors') e), 'verzia 2 stále zablokovaná';
  PERFORM set_config('app.user_id', pg_temp.d_id('u', 2)::text, true);
  BEGIN
    PERFORM offer_unblock(v2);
    RAISE EXCEPTION 'CHYBA: odblokoval iný obchodník';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM set_config('app.user_id', pg_temp.d_id('u', 1)::text, true);
  PERFORM offer_unblock(v2);
  ASSERT NOT (SELECT coalesce(bool_or(e LIKE '%zablokovaná%'), false) FROM jsonb_array_elements_text(offer_check(v2)->'errors') e), 'odblokovaná';
  DELETE FROM offer WHERE id = v2;
  PERFORM set_config('app.user_id', '', true);
  PERFORM set_config('app.require_user', '', true);
  RAISE NOTICE 'OK: D5 akceptáciu nezapíše aplikácia priamo; ruší iba admin s dôvodom; ponuka Odoslaná, obchod Vyjednávanie; zablokovaná verzia ostáva, odblokuje vlastník (nie iný obchodník)';
END;
$$;
RESET ROLE;
-- po platnosti: zrušená akceptácia vráti ponuku, ktorá sa zobrazí ako Vypršaná; verejná akceptácia nejde
UPDATE offer SET valid_until = now() - interval '1 hour' WHERE deal_id = pg_temp.d_id('d', 1) AND version = 1;
SET LOCAL ROLE crm_public_test;
DO $$
DECLARE
  h text := encode(sha256('token-2'::bytea), 'hex');
  v jsonb := verejne.ponuka_zobrazit(encode(sha256('token-2'::bytea), 'hex'));
BEGIN
  ASSERT v->>'mode' = 'len_citanie' AND v->>'reason' = 'vyprsana', 'po platnosti len čítanie: ' || (v->>'mode') || ' ' || (v->>'reason');
  BEGIN
    PERFORM verejne.ponuka_akceptovat(h, (v->'document'->'variants'->0->>'id')::uuid, 'Pavol', 'konateľ', '192.0.2.10', 'test', repeat('0', 64));
    RAISE EXCEPTION 'CHYBA: akceptácia po platnosti';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
END;
$$;
RESET ROLE;
UPDATE offer SET valid_until = now() - interval '31 days' WHERE deal_id = pg_temp.d_id('d', 1) AND version = 1;
SET LOCAL ROLE crm_public_test;
DO $$
BEGIN
  ASSERT verejne.ponuka_zobrazit(encode(sha256('token-2'::bytea), 'hex'))->>'mode' = 'neplatny', 'po 30 dňoch odkaz neplatí';
  ASSERT verejne.ponuka_pdf(encode(sha256('token-2'::bytea), 'hex')) IS NULL, 'ani PDF';
  RAISE NOTICE 'OK: D5 po platnosti len čítanie (Vypršaná) a bez akceptácie; po 30 dňoch odkaz ani PDF neplatí';
END;
$$;
RESET ROLE;
DO $$
BEGIN
  ASSERT offer_state((SELECT o FROM offer o WHERE o.deal_id = pg_temp.d_id('d', 1) AND o.version = 1)) = 'vyprsana', 'stav Vypršaná';
END;
$$;

-- ============================================================================
-- D6. Ručná akceptácia (kanál, meno, funkcia, čas, kto zaznačil; podpísané PDF voliteľné); zrušenie pri Vyhraté nejde
-- ============================================================================
SET LOCAL ROLE crm_rls_test;
DO $$
DECLARE
  v_offer uuid;
  v_var   uuid;
  o       offer;
  v_acc   uuid;
BEGIN
  PERFORM set_config('app.require_user', 'on', true);
  PERFORM set_config('app.user_id', pg_temp.d_id('u', 1)::text, true);
  v_offer := offer_create(pg_temp.d_id('d', 3));
  v_var := (SELECT id FROM offer_variant WHERE offer_id = v_offer);
  INSERT INTO offer_item (variant_id, oom_id, year, slot, product_id, price_model, price_vt_eur_mwh)
  VALUES (v_var, pg_temp.d_id('oom', 5), 2027, 'komodita', (SELECT id FROM product WHERE code = 'green_1t'), 'fix', 125);
  PERFORM offer_prepare(v_offer);
  PERFORM offer_mark_sent(v_offer, now(), 'osobne', NULL);
  SELECT * INTO o FROM offer WHERE id = v_offer;
  BEGIN
    PERFORM offer_accept_manual(v_offer, v_var, 'Ján Test', 'konateľ', now(), NULL, NULL, NULL);
    RAISE EXCEPTION 'CHYBA: ručná akceptácia bez kanála';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    PERFORM offer_accept_manual(v_offer, v_var, 'Ján Test', '', now(), 'telefon', NULL, NULL);
    RAISE EXCEPTION 'CHYBA: ručná akceptácia bez funkcie';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    PERFORM offer_accept_manual(v_offer, v_var, 'Ján Test', 'konateľ', now() + interval '1 day', 'telefon', NULL, NULL);
    RAISE EXCEPTION 'CHYBA: ručná akceptácia v budúcnosti';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    PERFORM offer_accept_manual(v_offer, v_var, 'Ján Test', 'konateľ', now(), 'podpisane_pdf', NULL, 'iny/subor.pdf');
    RAISE EXCEPTION 'CHYBA: neplatný kľúč podpísaného PDF';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  v_acc := offer_accept_manual(v_offer, v_var, 'Ján Test', 'konateľ', now(), 'podpisane_pdf', 'podpísané na stretnutí',
                               'podpisane/' || crm_default_org() || '/2026/' || o.number || '-0123abcd.pdf');
  ASSERT (SELECT (method, channel, recorded_by, ip IS NULL) FROM offer_acceptance WHERE id = v_acc)
         = ROW('rucne'::text, 'podpisane_pdf'::text, pg_temp.d_id('u', 1), true), 'ručná akceptácia: kanál a kto zaznačil';
  ASSERT (SELECT status FROM offer WHERE id = v_offer) = 'akceptovana', 'akceptovaná';
  -- potvrdenie ručnej akceptácie ukladá aplikácia (kľúč z databázy), iba raz
  ASSERT offer_acceptance_for_confirmation(v_acc)->>'method' = 'rucne', 'údaje pre potvrdenie ručnej akceptácie';
  PERFORM offer_acceptance_confirmation_set(v_acc, offer_acceptance_for_confirmation(v_acc)->>'confirmation_key', repeat('e', 64));
  BEGIN
    PERFORM offer_acceptance_confirmation_set(v_acc, offer_acceptance_for_confirmation(v_acc)->>'confirmation_key', repeat('f', 64));
    RAISE EXCEPTION 'CHYBA: potvrdenie ručnej akceptácie prepísané';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    PERFORM offer_acceptance_confirmation_attach(v_acc, 'x', repeat('f', 64));
    RAISE EXCEPTION 'CHYBA: aplikácia volá internú funkciu';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM set_config('app.user_id', '', true);
  PERFORM set_config('app.require_user', '', true);
END;
$$;
RESET ROLE;
UPDATE deal SET stage_id = pg_temp.b_stage('b2b_dodavka', 'vyhrane') WHERE id = pg_temp.d_id('d', 3);
SET LOCAL ROLE crm_rls_test;
DO $$
BEGIN
  PERFORM set_config('app.require_user', 'on', true);
  PERFORM set_config('app.user_id', pg_temp.d_id('u', 3)::text, true);
  BEGIN
    PERFORM offer_acceptance_revoke((SELECT a.id FROM offer_acceptance a JOIN offer o ON o.id = a.offer_id WHERE o.deal_id = pg_temp.d_id('d', 3)), 'omyl');
    RAISE EXCEPTION 'CHYBA: zrušená akceptácia pri spárovanej zmluve';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  PERFORM set_config('app.user_id', '', true);
  PERFORM set_config('app.require_user', '', true);
  RAISE NOTICE 'OK: D6 ručná akceptácia: povinný kanál, meno, funkcia, čas nie v budúcnosti, podpísané PDF iba z úložiska ponúk, zapíše kto zaznačil; pri Vyhraté sa akceptácia nezruší';
END;
$$;
RESET ROLE;

-- ============================================================================
-- D7. Zmluvná pokuta: zvýšiť smie obchodník, zníženie pod predvolenú hodnotu šablóny schvaľuje schvaľovateľ cien (3 dni)
-- ============================================================================
SET LOCAL ROLE crm_rls_test;
DO $$
DECLARE
  v_offer uuid;
  v_req   uuid;
  n       jsonb;
BEGIN
  PERFORM set_config('app.require_user', 'on', true);
  PERFORM set_config('app.user_id', pg_temp.d_id('u', 1)::text, true);
  v_offer := offer_create(pg_temp.d_id('d', 4));
  INSERT INTO offer_item (variant_id, oom_id, year, slot, product_id, price_model, price_vt_eur_mwh)
  VALUES ((SELECT id FROM offer_variant WHERE offer_id = v_offer), pg_temp.d_id('oom', 6), 2027, 'komodita',
          (SELECT id FROM product WHERE code = 'green_1t'), 'fix', 125);
  UPDATE offer SET penalty_eur_mwh = 60 WHERE id = v_offer;
  ASSERT jsonb_array_length(offer_check(v_offer)->'needs') = 0, 'vyššia pokuta bez schválenia';
  UPDATE offer SET penalty_eur_mwh = 40 WHERE id = v_offer;
  SELECT x INTO n FROM jsonb_array_elements(offer_check(v_offer)->'needs') x WHERE x->>'type' = 'pokuta';
  ASSERT (n->>'requested_value')::numeric = 40 AND (n->>'threshold_value')::numeric = 50, 'nižšia pokuta potrebuje schválenie: ' || coalesce(n::text, 'nič');
  BEGIN
    PERFORM offer_prepare(v_offer);
    RAISE EXCEPTION 'CHYBA: pripravená s nižšou pokutou bez schválenia';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  ASSERT approval_request_offer(v_offer, 'zákazník odmieta 50 €') = 'caka_na_schvalenie', 'žiadosť';
  v_req := (SELECT id FROM approval_request WHERE offer_id = v_offer AND kind = 'vynimka_ceny' AND status = 'caka');
  ASSERT (SELECT penalty_eur_mwh FROM approval_request WHERE id = v_req) = 40, 'žiadaná pokuta pri žiadosti';
  ASSERT NOT EXISTS (SELECT 1 FROM approval_price_detail(v_req)), 'bez položiek ceny';
  BEGIN
    PERFORM approval_decide(v_req, true, NULL);
    RAISE EXCEPTION 'CHYBA: obchodník schválil pokutu';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM set_config('app.user_id', pg_temp.d_id('u', 4)::text, true);
  PERFORM approval_decide(v_req, true, 'ok');
  PERFORM set_config('app.user_id', pg_temp.d_id('u', 1)::text, true);
  ASSERT (SELECT status FROM offer WHERE id = v_offer) = 'pripravena', 'po schválení pripravená';
  ASSERT jsonb_array_length(offer_check(v_offer)->'needs') = 0, 'schválená pokuta';
  PERFORM set_config('app.user_id', '', true);
  PERFORM set_config('app.require_user', '', true);
END;
$$;
RESET ROLE;
UPDATE approval_request SET valid_until = now() - interval '1 minute'
 WHERE offer_id = (SELECT id FROM offer WHERE deal_id = pg_temp.d_id('d', 4)) AND kind = 'vynimka_ceny';
DO $$
BEGIN
  ASSERT EXISTS (SELECT 1 FROM jsonb_array_elements(offer_check_internal((SELECT id FROM offer WHERE deal_id = pg_temp.d_id('d', 4)))->'needs') x
                  WHERE x->>'type' = 'pokuta'), 'po 3 dňoch treba pokutu schváliť znova';
  RAISE NOTICE 'OK: D7 zmluvná pokuta: vyššia bez schválenia, nižšia ako v šablóne iba so schválením (schvaľovateľ cien, spolu s výnimkou, platí 3 dni)';
END;
$$;

-- ============================================================================
-- D8. Izolácia verejnej roly (všetky objekty) a predvolené práva funkcií z budúcich migrácií
-- ============================================================================
DO $$
DECLARE
  r      text;
  v_fn   oid;
BEGIN
  FOREACH r IN ARRAY ARRAY['crm_public_test', 'crm_public'] LOOP
    CONTINUE WHEN NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r);
    ASSERT NOT has_schema_privilege(r, 'public', 'USAGE'), r || ': schéma public';
    ASSERT NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
                        WHERE n.nspname NOT IN ('pg_catalog', 'information_schema') AND n.nspname NOT LIKE 'pg_%temp%'
                          AND n.nspname NOT LIKE 'pg_toast%' AND c.relkind IN ('r', 'v', 'm', 'p', 'f')
                          AND has_schema_privilege(r, n.oid, 'USAGE') AND has_table_privilege(r, c.oid, 'SELECT')),
           r || ': číta tabuľku';
    ASSERT NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                        WHERE n.nspname NOT IN ('pg_catalog', 'information_schema', 'verejne') AND n.nspname NOT LIKE 'pg_%temp%'
                          AND has_schema_privilege(r, n.oid, 'USAGE') AND has_function_privilege(r, p.oid, 'EXECUTE')),
           r || ': spustí funkciu mimo schémy verejne';
    ASSERT (SELECT count(*) FROM pg_proc p WHERE p.pronamespace = 'verejne'::regnamespace AND has_function_privilege(r, p.oid, 'EXECUTE')) >= 3,
           r || ': funkcie stránky ponuky';
  END LOOP;
  -- funkcia budúcej migrácie (vytvorí vlastník databázy): aplikácia ju má, verejná rola nie (bez PUBLIC overuje
  -- checks_predvolene_prava.sql pred dočasným vrátením práv pre testy)
  CREATE FUNCTION public.d_test_buduca() RETURNS integer LANGUAGE sql AS 'SELECT 1';
  v_fn := 'public.d_test_buduca()'::regprocedure;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'crm_app') THEN
    ASSERT has_function_privilege('crm_app', v_fn, 'EXECUTE'), 'nová funkcia pre crm_app';
  END IF;
  ASSERT NOT has_schema_privilege('crm_public_test', 'public', 'USAGE'), 'novú funkciu verejná rola nespustí (bez schémy public)';
  DROP FUNCTION public.d_test_buduca();
  RAISE NOTICE 'OK: D8 verejná rola (aj crm_public, ak existuje): žiadna tabuľka ani funkcia mimo troch v schéme verejne; novú funkciu má aplikácia, verejná rola nie';
END;
$$;

-- ============================================================================
-- D9. Hlásenie chýbajúcej hranice (0041): manažér – odhad portfólia, obchodník – cena pre obchodníka
-- ============================================================================
DO $$
DECLARE
  v_m uuid := (SELECT v.id FROM offer_variant v JOIN offer o ON o.id = v.offer_id WHERE o.deal_id = pg_temp.c_id('d', 2));
BEGIN
  UPDATE offer_year_basis SET portfolio_eur_mwh = NULL WHERE variant_id = v_m;
  PERFORM set_config('app.user_id', pg_temp.c_id('u', 2)::text, true);
  ASSERT (SELECT missing FROM offer_variant_values(v_m) LIMIT 1) LIKE 'chýba nákupná cena portfólia (hranica manažéra)%',
         'manažér bez odhadu portfólia: ' || coalesce((SELECT missing FROM offer_variant_values(v_m) LIMIT 1), 'nič');
  PERFORM set_config('app.user_id', '', true);
  RAISE NOTICE 'OK: D9 manažér bez odhadu portfólia dostane hlásenie o odhade portfólia a radu ponuku prepočítať';
END;
$$;
