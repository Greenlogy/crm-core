-- Kontroly modulu 5, fáza F4 (0042): šablóny e-mailov, profil do podpisu a fotka, predvyplnený e-mail k ponuke
-- (zhrnutie variantov, oslovenie), odolné odoslanie (odosiela sa → ID z Gmailu → Odoslaná, dokončenie behom na
-- pozadí, nikdy znova), jediná kontrola čítania Gmailu a denník čítania, prijaté odpovede a sledovanie vlákien,
-- pripomienka platnosti, potvrdenie akceptácie a interné e-maily z crm@, viditeľnosť.
-- Spúšťa sa iba cez db/test/run.sh po checks_ponuky_f3.sql (pomocné funkcie série B, rola crm_rls_test).
-- Vlastné záznamy: …-0000000e00xx používatelia, e01xx firmy, e02xx OOM, e03xx obchody, e04xx kontakty.

-- ============================================================================
-- Príprava (vlastník databázy)
-- ============================================================================

CREATE FUNCTION pg_temp.e_id(p_kind text, p_n integer) RETURNS uuid LANGUAGE sql AS $f$
  SELECT ('00000000-0000-4000-8000-0000000' || CASE p_kind WHEN 'u' THEN 'e00' WHEN 'f' THEN 'e01' WHEN 'oom' THEN 'e02'
                                                            WHEN 'd' THEN 'e03' ELSE 'e04' END || lpad(p_n::text, 2, '0'))::uuid
$f$;
CREATE FUNCTION pg_temp.e_eic(p_n integer) RETURNS text LANGUAGE plpgsql AS $f$
DECLARE
  l text;
  c text;
BEGIN
  FOREACH l IN ARRAY string_to_array('KLMNPQRSTUVW', NULL) LOOP
    FOREACH c IN ARRAY string_to_array('0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ', NULL) LOOP
      IF eic_is_valid('24ZZS000MAIL' || l || lpad(p_n::text, 2, '0') || c) THEN
        RETURN '24ZZS000MAIL' || l || lpad(p_n::text, 2, '0') || c;
      END IF;
    END LOOP;
  END LOOP;
END;
$f$;
-- vytvorí a pripraví FIX ponuku (jedna OOM, 125 €/MWh na rok 2027) ako vlastník obchodu
CREATE FUNCTION pg_temp.e_offer(p_deal integer, p_oom integer) RETURNS uuid LANGUAGE plpgsql AS $f$
DECLARE
  v_offer uuid := offer_create(pg_temp.e_id('d', p_deal));
  v_var   uuid := (SELECT id FROM offer_variant WHERE offer_id = v_offer);
BEGIN
  DELETE FROM offer_item WHERE variant_id = v_var;
  INSERT INTO offer_item (variant_id, oom_id, year, slot, product_id, price_model, price_vt_eur_mwh)
  VALUES (v_var, pg_temp.e_id('oom', p_oom), 2027, 'komodita', (SELECT id FROM product WHERE code = 'green_1t'), 'fix', 125);
  RETURN v_offer;
END;
$f$;
-- nastaví prihláseného používateľa (NULL = beh na pozadí); vráti text, aby sa dal použiť aj v DECLARE pred ďalšími
-- premennými (tie sa vyhodnotia pod RLS)
CREATE FUNCTION pg_temp.e_as(p_user uuid) RETURNS text LANGUAGE sql AS $f$
  SELECT set_config('app.require_user', 'on', true) || set_config('app.user_id', coalesce(p_user::text, ''), true)
$f$;

-- 1 obchodník (vlastník), 2 admin, 3 marketing, 4 schvaľovateľ
INSERT INTO app_user (id, email, name, team_id, status, seller_type, is_admin, phone, job_title)
SELECT x.id::uuid, x.email, x.name, t.id, 'aktivny', x.st::seller_type, x.adm, '+421 900 000 101', 'obchodník'
  FROM (VALUES
    ('00000000-0000-4000-8000-0000000e0001', 'obchodnik.e@example.test', 'Obchodník E', 'test_predajcovia_b', 'obchodnik', false),
    ('00000000-0000-4000-8000-0000000e0002', 'admin.e@example.test', 'Admin E', 'sales_internal', NULL, true),
    ('00000000-0000-4000-8000-0000000e0003', 'marketing.e@example.test', 'Marketing E', 'marketing', NULL, false),
    ('00000000-0000-4000-8000-0000000e0004', 'schvalovatel.e@example.test', 'Schvaľovateľ E', 'sales_internal', NULL, false)
  ) AS x(id, email, name, team, st, adm)
  JOIN team t ON t.code = x.team;
UPDATE app_user SET approves_prices = true WHERE id = '00000000-0000-4000-8000-0000000e0004';
INSERT INTO app_user_org (user_id, org_id)
SELECT id, crm_default_org() FROM app_user WHERE id::text LIKE '00000000-0000-4000-8000-0000000e00%';

INSERT INTO company (id, name, ico, address, is_customer, owner_id) VALUES
  (pg_temp.e_id('f', 1), 'Mail Test E1 s.r.o.', '88880051', 'Priemyselná 9, 036 01 Martin', true, pg_temp.e_id('u', 1));
INSERT INTO contact (id, first_name, last_name, email, is_household, salutation) VALUES
  (pg_temp.e_id('k', 1), 'Eva', 'Testovacia', 'Eva.E@Example.test', false, 'Pozdravujem, pani Testovacia'),
  (pg_temp.e_id('k', 2), 'Jozef', 'Bezoslovenia', 'jozef.e@example.test', false, NULL);

INSERT INTO oom (id, company_id, eic, type, status, voltage_level, planned_consumption_vt_mwh)
SELECT pg_temp.e_id('oom', n), pg_temp.e_id('f', 1), pg_temp.e_eic(n), 'spotreba', 'pripravovane', 'nn', 30
  FROM generate_series(1, 5) n;

-- 1 odoslanie a dokončenie, 2 obnova behom na pozadí, 3 neisté odoslanie, 4 pripomienka (SPOT), 5 akceptácia a potvrdenie
INSERT INTO deal (id, company_id, pipeline_id, stage_id, name, owner_id, source_code, supply_start)
SELECT pg_temp.e_id('d', n), pg_temp.e_id('f', 1), pg_temp.b_pipe('b2b_dodavka'), pg_temp.b_stage('b2b_dodavka', 'prilezitost'),
       'E' || n || ' 2027', pg_temp.e_id('u', 1), 'web', '2027-01-01'
  FROM generate_series(1, 5) n;
INSERT INTO deal_oom (deal_id, oom_id) SELECT pg_temp.e_id('d', n), pg_temp.e_id('oom', n) FROM generate_series(1, 5) n;
INSERT INTO deal_contact (deal_id, contact_id, is_primary)
SELECT pg_temp.e_id('d', n), pg_temp.e_id('k', CASE WHEN n = 3 THEN 2 ELSE 1 END), true FROM generate_series(1, 5) n;

-- práva ako aplikácia (app-role.sql, 0042)
GRANT SELECT, INSERT, UPDATE, DELETE ON email_template_version, user_photo TO crm_rls_test;
GRANT SELECT ON email_thread, email_message, mailbox_access_log, gmail_mailbox_state, email_outbox TO crm_rls_test;
-- funkcie z migrácií po 0040 nemá PUBLIC – testovacia rola ich dostane ako crm_app (predvolené práva)
GRANT EXECUTE ON FUNCTION user_profile_set(uuid, text, text, text, text), email_signature(uuid), user_photo_get(uuid),
  email_template_variables(), email_template_check(text, text), crm_email_template_editor(), email_template_publish(uuid),
  email_addr_list_ok(jsonb, integer), email_thread_visible(uuid), email_message_visible(uuid, email_status, uuid),
  email_fmt_time(timestamptz, offer_language), email_fill(text, jsonb), email_compose_offer(uuid, text),
  email_draft_save(uuid, jsonb), email_draft_delete(uuid), crm_background_only(),
  email_send_prepare(uuid, uuid, text, text, text), email_send_recorded(uuid, uuid, text, text, text, timestamptz),
  email_send_complete(uuid), email_send_failed(uuid, uuid, text), email_retry(uuid), email_pending_recover(),
  email_queue_claim(integer), email_outbox_claim(integer), email_outbox_result(uuid, uuid, text, text),
  gmail_read_authorize(uuid, text, text, text, text), offer_acceptance_confirmation_off(uuid), email_watch_threads(integer), email_thread_checked(uuid, text, text),
  email_message_received(uuid, jsonb) TO crm_rls_test;
-- 0044
GRANT SELECT ON user_signature, user_signature_image TO crm_rls_test;
GRANT EXECUTE ON FUNCTION email_salutation(uuid, offer_language), user_signature_set(uuid, text, text, text, jsonb),
  user_signature_images_get(uuid) TO crm_rls_test;

-- ============================================================================
-- E0. Šablóny e-mailov: prvé verzie, premenné, mení admin a Marketing, platná sa nemení
-- ============================================================================
DO $$
BEGIN
  ASSERT (SELECT count(*) FROM email_template_version WHERE org_id = crm_default_org()) = 12, '6 druhov × 2 jazyky';
  ASSERT (SELECT count(*) FROM email_template_version WHERE org_id = crm_default_org() AND language = 'sk' AND status = 'platna') = 6, 'SK platné';
  ASSERT (SELECT count(*) FROM email_template_version WHERE org_id = crm_default_org() AND language = 'en' AND status = 'navrh') = 6, 'EN návrh';
  ASSERT (SELECT subject FROM email_template_version WHERE org_id = crm_default_org() AND code = 'ponuka_dodavka' AND language = 'sk')
         = 'Cenová ponuka «číslo ponuky» – «názov zákazníka»', 'predmet podľa e-mailu obchodníkov';
  ASSERT email_template_check('x', '«neznáma» «podpis»') LIKE 'Neznáma premenná%', 'neznáma premenná';
  ASSERT email_template_check('x', 'bez podpisu') LIKE '%«podpis»%', 'podpis povinný';
  ASSERT email_template_check('«odkaz na ponuku»', '«podpis»') LIKE '%nepatria do predmetu%', 'odkaz nie v predmete';
  ASSERT email_template_check('Ponuka «číslo ponuky»', '«oslovenie», «zhrnutie variantov» «platnosť» «odkaz na ponuku» «podpis»') IS NULL, 'platný text';
  RAISE NOTICE 'OK: E0 prvé verzie šablón e-mailov (SK platné, EN návrh), kontrola premenných a podpisu';
END;
$$;
SET LOCAL ROLE crm_rls_test;
DO $$
DECLARE
  v_sk  email_template_version;
  v_new uuid;
BEGIN
  PERFORM pg_temp.e_as(pg_temp.e_id('u', 1));
  SELECT * INTO v_sk FROM email_template_version WHERE org_id = crm_default_org() AND code = 'ponuka_dodavka' AND language = 'sk';
  ASSERT v_sk.id IS NOT NULL, 'obchodník šablónu číta';
  BEGIN
    INSERT INTO email_template_version (org_id, code, language, name, subject, body)
    VALUES (crm_default_org(), 'ponuka_dodavka', 'sk', 'x', 'x', '«podpis»');
    RAISE EXCEPTION 'CHYBA: obchodník založil šablónu e-mailu';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM pg_temp.e_as(pg_temp.e_id('u', 3));
  BEGIN
    UPDATE email_template_version SET subject = 'zmena' WHERE id = v_sk.id;
    RAISE EXCEPTION 'CHYBA: platná šablóna e-mailu zmenená';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    INSERT INTO email_template_version (org_id, code, language, name, subject, body)
    VALUES (crm_default_org(), 'ponuka_dodavka', 'sk', 'x', 'x', '«zlá» «podpis»');
    RAISE EXCEPTION 'CHYBA: šablóna s neznámou premennou';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  INSERT INTO email_template_version (org_id, code, language, name, subject, body, status)
  VALUES (crm_default_org(), 'ponuka_dodavka', 'sk', v_sk.name, v_sk.subject, replace(v_sk.body, 'ďakujeme', 'srdečne ďakujeme'), 'platna')
  RETURNING id INTO v_new;
  ASSERT (SELECT (status, version) FROM email_template_version WHERE id = v_new) = ROW('navrh'::text, 2::smallint), 'Marketing: nová verzia je návrh v2';
  PERFORM email_template_publish(v_new);
  ASSERT (SELECT status FROM email_template_version WHERE id = v_sk.id) = 'nahradena', 'v1 nahradená';
  ASSERT (SELECT status FROM email_template_version WHERE id = v_new) = 'platna', 'v2 platná';
  PERFORM pg_temp.e_as(NULL);
  RAISE NOTICE 'OK: E0 šablónu e-mailu číta každý, mení admin a Marketing (nie obchodník); platná sa nemení; nová verzia = návrh, zverejnenie nahradí platnú';
END;
$$;

-- ============================================================================
-- E1. Profil do podpisu: mení používateľ sám alebo admin; fotka do 300 kB, odtlačok, iba vlastná (alebo admin)
-- ============================================================================
DO $$
BEGIN
  PERFORM pg_temp.e_as(pg_temp.e_id('u', 1));
  PERFORM user_profile_set(pg_temp.e_id('u', 1), '+421 41 000 000', ' +421 900 000 102 ', 'obchodník pre firmy',
                           'https://www.linkedin.com/in/obchodnik-e');
  ASSERT (SELECT (mobile, linkedin_url) FROM app_user WHERE id = pg_temp.e_id('u', 1))
         = ROW('+421 900 000 102'::text, 'https://www.linkedin.com/in/obchodnik-e'::text), 'profil uložený';
  BEGIN
    PERFORM user_profile_set(pg_temp.e_id('u', 3), NULL, NULL, NULL, NULL);
    RAISE EXCEPTION 'CHYBA: obchodník zmenil cudzí profil';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    PERFORM user_profile_set(pg_temp.e_id('u', 1), NULL, NULL, NULL, 'javascript:alert(1)');
    RAISE EXCEPTION 'CHYBA: neplatný LinkedIn';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  INSERT INTO user_photo (user_id, mime, data) VALUES (pg_temp.e_id('u', 1), 'image/png', '\x89504e47'::bytea);
  ASSERT (SELECT sha256 = encode(sha256('\x89504e47'::bytea), 'hex') AND updated_by = pg_temp.e_id('u', 1)
            FROM user_photo WHERE user_id = pg_temp.e_id('u', 1)), 'odtlačok a kto';
  BEGIN
    INSERT INTO user_photo (user_id, mime, data) VALUES (pg_temp.e_id('u', 3), 'image/png', '\x00'::bytea);
    RAISE EXCEPTION 'CHYBA: fotka inému používateľovi';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    UPDATE user_photo SET data = decode(repeat('00', 307201), 'hex') WHERE user_id = pg_temp.e_id('u', 1);
    RAISE EXCEPTION 'CHYBA: fotka nad 300 kB';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  ASSERT (email_signature(pg_temp.e_id('u', 1))->>'has_photo')::boolean AND email_signature(pg_temp.e_id('u', 1))->>'mobile' = '+421 900 000 102', 'podpis';
  PERFORM pg_temp.e_as(pg_temp.e_id('u', 2));
  PERFORM user_profile_set(pg_temp.e_id('u', 1), '+421 41 000 000', '+421 900 000 102', 'obchodník', NULL);
  INSERT INTO user_photo (user_id, mime, data) VALUES (pg_temp.e_id('u', 3), 'image/jpeg', '\xffd8ff'::bytea);
  PERFORM pg_temp.e_as(pg_temp.e_id('u', 3));
  ASSERT (SELECT count(*) FROM user_photo) = 1, 'Marketing vidí iba svoju fotku';
  PERFORM pg_temp.e_as(NULL);
  RAISE NOTICE 'OK: E1 profil a fotka: sám alebo admin, LinkedIn iba https, fotka do 300 kB s odtlačkom, podpis z profilu';
END;
$$;

-- ============================================================================
-- E2. Predvyplnený e-mail k ponuke: zhrnutie variantov, oslovenie z kontaktu (inak „Dobrý deň“), adresát
-- ============================================================================
DO $$
DECLARE
  v_offer uuid;
  v_var   uuid;
  c       jsonb;
  v_num   text;
BEGIN
  PERFORM pg_temp.e_as(pg_temp.e_id('u', 1));
  v_offer := pg_temp.e_offer(1, 1);
  -- SPOT + 8 €/MWh ako druhý variant
  v_var := offer_variant_add(v_offer, 'spot');
  DELETE FROM offer_item WHERE variant_id = v_var AND slot = 'komodita';
  INSERT INTO offer_item (variant_id, oom_id, year, slot, product_id, price_model, additive_eur_mwh)
  VALUES (v_var, pg_temp.e_id('oom', 1), 2027, 'komodita', (SELECT id FROM product WHERE code = 'green_1t'), 'spot_plus_eur', 8);
  PERFORM pg_temp.e_as(NULL);
  RESET ROLE;
  ASSERT offer_variants_summary_text(v_offer) = 'FIX na rok 2027 a SPOT + 8,00 €/MWh', 'zhrnutie: ' || offer_variants_summary_text(v_offer);
  SET LOCAL ROLE crm_rls_test;
  PERFORM pg_temp.e_as(pg_temp.e_id('u', 1));
  DELETE FROM offer_item WHERE variant_id = v_var;
  DELETE FROM offer_variant WHERE id = v_var;
  ASSERT offer_prepare(v_offer) = 'pripravena', 'pripravená';
  v_num := (SELECT offer_display_number(o) FROM offer o WHERE id = v_offer);
  c := email_compose_offer(v_offer);
  ASSERT c->>'subject' = 'Cenová ponuka ' || v_num || ' – Mail Test E1 s.r.o.', 'predmet: ' || (c->>'subject');
  ASSERT c->>'body' LIKE 'Pozdravujem, pani Testovacia,%srdečne ďakujeme%ponuku FIX na rok 2027 na odkaze%Platí do «platnosť».%«odkaz na ponuku»%«podpis»',
         'text (platná v2 od Marketingu): ' || (c->>'body');
  ASSERT c->'to' = '["eva.e@example.test"]'::jsonb, 'adresát z kontaktnej osoby (malé písmená): ' || (c->'to')::text;
  -- bez oslovenia pri kontakte „Dobrý deň“
  v_var := pg_temp.e_offer(3, 3);
  c := email_compose_offer(v_var);
  ASSERT c->>'body' LIKE 'Dobrý deň,%', 'predvolené oslovenie: ' || left(c->>'body', 60);
  ASSERT c->'to' = '["jozef.e@example.test"]'::jsonb, 'adresát obchodu 3';
  -- cudzí obchodník e-mail k ponuke nepripraví
  PERFORM set_config('app.user_id', pg_temp.b_id('u', 6)::text, true);
  BEGIN
    PERFORM email_compose_offer(v_offer);
    RAISE EXCEPTION 'CHYBA: cudzí obchodník pripravil e-mail';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM pg_temp.e_as(NULL);
  RAISE NOTICE 'OK: E2 predvyplnený e-mail: predmet, oslovenie z kontaktu (inak Dobrý deň), zhrnutie variantov (FIX na rok 2027 a SPOT + 8,00 €/MWh), adresát; cudzí nie';
END;
$$;

-- ============================================================================
-- E3. Odoslanie ponuky e-mailom: odosiela sa (jednorazový kľúč) → ID z Gmailu → Odoslaná; idempotencia, zámok ponuky,
--     obnova behom na pozadí, neisté odoslanie sa nikdy neopakuje, odmietnutie vráti koncept
-- ============================================================================
DO $$
DECLARE
  _u      text := pg_temp.e_as(pg_temp.e_id('u', 2));
  v_offer uuid := (SELECT id FROM offer WHERE deal_id = pg_temp.e_id('d', 1));
  o       offer;
  v_msg   uuid;
  k1      uuid := gen_random_uuid();
  p       jsonb;
  c       jsonb;
  v_key   text;
  v_hash  text := encode(sha256('token-e1'::bytea), 'hex');
BEGIN
  PERFORM pg_temp.e_as(pg_temp.e_id('u', 1));
  SELECT * INTO o FROM offer WHERE id = v_offer;
  v_key := 'ponuky/' || o.org_id || '/2026/' || o.number || '.pdf';
  c := email_compose_offer(v_offer);
  v_msg := email_draft_save(NULL, jsonb_build_object('kind', 'ponuka', 'offer_id', v_offer, 'template_version_id', c->>'template_version_id',
                                                     'to', c->'to', 'subject', c->>'subject', 'body', c->>'body'));
  ASSERT (SELECT (status, created_by) FROM email_message WHERE id = v_msg) = ROW('koncept'::email_status, pg_temp.e_id('u', 1)), 'koncept';
  BEGIN
    PERFORM email_send_prepare(v_msg, k1, v_key, repeat('a', 64), v_hash);
    RAISE EXCEPTION 'CHYBA: odoslanie bez zapnutého Gmailu';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  PERFORM pg_temp.e_as(NULL);
END;
$$;
RESET ROLE;
UPDATE app_user SET gmail_enabled = true WHERE id = '00000000-0000-4000-8000-0000000e0001';
SET LOCAL ROLE crm_rls_test;
DO $$
DECLARE
  _u      text := pg_temp.e_as(pg_temp.e_id('u', 1));
  v_offer uuid := (SELECT id FROM offer WHERE deal_id = pg_temp.e_id('d', 1));
  o       offer;
  v_msg   uuid := (SELECT id FROM email_message WHERE offer_id = (SELECT id FROM offer WHERE deal_id = pg_temp.e_id('d', 1)));
  k1      uuid := gen_random_uuid();
  p       jsonb;
  r       jsonb;
  v_key   text;
  v_hash  text := encode(sha256('token-e1'::bytea), 'hex');
BEGIN
  PERFORM pg_temp.e_as(pg_temp.e_id('u', 1));
  SELECT * INTO o FROM offer WHERE id = v_offer;
  v_key := 'ponuky/' || o.org_id || '/2026/' || o.number || '.pdf';
  BEGIN
    PERFORM email_send_prepare(v_msg, k1, 'iny/' || o.number || '.pdf', repeat('a', 64), v_hash);
    RAISE EXCEPTION 'CHYBA: PDF mimo úložiska ponúk';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  p := email_send_prepare(v_msg, k1, v_key, repeat('a', 64), v_hash);
  ASSERT (p->>'fresh')::boolean AND p->>'status' = 'odosiela_sa' AND p->>'mailbox' = 'obchodnik.e@example.test', 'odosiela sa: ' || p::text;
  ASSERT p->>'body' ~ 'Platí do \d\d\. \d\d\. \d{4}, 16:00\.' AND p->>'body' LIKE '%«odkaz na ponuku»%«podpis»', 'platnosť doplnená, odkaz a podpis doplní kód';
  ASSERT p->'attachments'->0->>'key' = v_key AND p->>'gmail_thread_id' IS NULL, 'príloha PDF, nové vlákno';
  -- dvojklik / opakovaná požiadavka s rovnakým kľúčom: nič nové, kód neodošle znova
  ASSERT NOT (email_send_prepare(v_msg, k1, v_key, repeat('a', 64), v_hash)->>'fresh')::boolean, 'rovnaký kľúč → fresh = false';
  BEGIN
    PERFORM email_send_prepare(v_msg, gen_random_uuid(), v_key, repeat('a', 64), v_hash);
    RAISE EXCEPTION 'CHYBA: druhé odoslanie s iným kľúčom';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  -- počas odosielania sa ponuka nemení
  BEGIN
    UPDATE offer_variant SET name = 'zmena' WHERE offer_id = v_offer;
    RAISE EXCEPTION 'CHYBA: variant zmenený počas odosielania';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    UPDATE offer SET custom = '{}' WHERE id = v_offer;
    RAISE EXCEPTION 'CHYBA: ponuka zmenená počas odosielania';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  ASSERT (SELECT (status, pdf_key, link_hash) FROM offer WHERE id = v_offer) = ROW('pripravena'::offer_status, NULL::text, NULL::text), 'ponuka ešte Pripravená';
  BEGIN
    PERFORM email_send_recorded(v_msg, gen_random_uuid(), 'abc123def4560001', 'abc123def4560001', '<e1@mail.gmail.com>', now());
    RAISE EXCEPTION 'CHYBA: zápis ID s cudzím kľúčom';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    PERFORM email_send_complete(v_msg);
    RAISE EXCEPTION 'CHYBA: dokončenie bez ID z Gmailu';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  PERFORM email_send_recorded(v_msg, k1, 'abc123def4560001', 'abc123def4560001', '<e1@mail.gmail.com>', now());
  PERFORM email_send_recorded(v_msg, k1, 'abc123def4560001', 'abc123def4560001', '<e1@mail.gmail.com>', now());
  BEGIN
    PERFORM email_send_recorded(v_msg, k1, 'abc123def4560002', 'abc123def4560001', '<e1@mail.gmail.com>', now());
    RAISE EXCEPTION 'CHYBA: iné ID správy';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    PERFORM email_send_failed(v_msg, k1, 'chyba');
    RAISE EXCEPTION 'CHYBA: odmietnutie po odoslaní';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  r := email_send_complete(v_msg);
  ASSERT r->>'status' = 'odoslany' AND r->>'offer_error' IS NULL, 'dokončené: ' || r::text;
  SELECT * INTO o FROM offer WHERE id = v_offer;
  ASSERT (o.status, o.sent_channel, o.sent_by, o.pdf_key, o.pdf_sha256, o.link_hash, o.link_created_by, o.template_version_id IS NOT NULL)
         = ROW('odoslana'::offer_status, 'crm'::offer_send_channel, pg_temp.e_id('u', 1), v_key, repeat('a', 64), v_hash, pg_temp.e_id('u', 1), true),
         'ponuka Odoslaná cez CRM s PDF a odkazom';
  ASSERT EXISTS (SELECT 1 FROM deal_event WHERE offer_id = v_offer AND kind = 'ponuka_odoslana' AND user_id = pg_temp.e_id('u', 1)
                    AND detail->>'channel' = 'crm'), 'časová os';
  ASSERT (SELECT (t.gmail_thread_id, t.watch_until) FROM email_thread t JOIN email_message m ON m.thread_id = t.id WHERE m.id = v_msg)
         = ROW('abc123def4560001'::text, crm_today() + 30), 'vlákno z Gmailu sa sleduje 30 dní';
  ASSERT (email_send_complete(v_msg)->>'already')::boolean, 'opakované dokončenie nič nezmení';
  BEGIN
    UPDATE email_message SET subject = 'x' WHERE id = v_msg;
    RAISE EXCEPTION 'CHYBA: aplikácia mení e-mail priamo';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    PERFORM offer_mark_sent(v_offer, now(), 'crm', NULL);
    RAISE EXCEPTION 'CHYBA: kanál crm ručne';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  PERFORM pg_temp.e_as(NULL);
  RAISE NOTICE 'OK: E3 odoslanie: bez Gmailu nie; odosiela sa s kľúčom (opakovanie fresh = false, iný kľúč nie); ponuka zamknutá; ID z Gmailu raz; dokončenie: Odoslaná (crm), PDF, odkaz, šablóna, časová os, sledovanie 30 dní; opakovanie nič nezmení';
END;
$$;

-- obnova: ID z Gmailu zapísané, dokončenie zlyhalo → beh na pozadí dokončí; bez ID → Chyba, nikdy znova
DO $$
DECLARE
  v_o2   uuid;
  v_o3   uuid;
  m2     uuid;
  m3     uuid;
  m4     uuid;
  k2     uuid := gen_random_uuid();
  k3     uuid := gen_random_uuid();
  k4     uuid := gen_random_uuid();
  r      jsonb;
  v_n    integer;
BEGIN
  PERFORM pg_temp.e_as(pg_temp.e_id('u', 1));
  v_o2 := pg_temp.e_offer(2, 2);
  PERFORM offer_prepare(v_o2);
  m2 := email_draft_save(NULL, jsonb_build_object('kind', 'ponuka', 'offer_id', v_o2, 'to', '["eva.e@example.test"]'::jsonb,
                                                  'subject', 'Ponuka', 'body', 'Dobrý deň, «odkaz na ponuku» «podpis»'));
  PERFORM email_send_prepare(m2, k2, 'ponuky/' || crm_default_org() || '/2026/' || (SELECT number FROM offer WHERE id = v_o2) || '.pdf', repeat('b', 64), encode(sha256('token-e2'::bytea), 'hex'));
  PERFORM email_send_recorded(m2, k2, 'abc123def4560002', 'abc123def4560002', NULL, now());
  -- (kód tu „spadne“ – email_send_complete sa nezavolá)
  v_o3 := (SELECT id FROM offer WHERE deal_id = pg_temp.e_id('d', 3));
  PERFORM offer_prepare(v_o3);
  m3 := email_draft_save(NULL, jsonb_build_object('kind', 'ponuka', 'offer_id', v_o3, 'to', '["jozef.e@example.test"]'::jsonb,
                                                  'subject', 'Ponuka', 'body', '«odkaz na ponuku» «podpis»'));
  PERFORM email_send_prepare(m3, k3, 'ponuky/' || crm_default_org() || '/2026/' || (SELECT number FROM offer WHERE id = v_o3) || '.pdf', repeat('c', 64), encode(sha256('token-e3'::bytea), 'hex'));
  -- (Gmail neodpovedal – nie je isté, či odišiel)
  -- voľný e-mail z karty firmy: Gmail ho odmietol → koncept s chybou
  m4 := email_draft_save(NULL, jsonb_build_object('company_id', pg_temp.e_id('f', 1), 'to', '["eva.e@example.test"]'::jsonb,
                                                  'subject', 'Otázka', 'body', 'Dobrý deň «podpis»'));
  PERFORM email_send_prepare(m4, k4);
  PERFORM email_send_failed(m4, k4, '400 invalidArgument');
  ASSERT (SELECT (status, send_key, error) FROM email_message WHERE id = m4) = ROW('koncept'::email_status, NULL::uuid, '400 invalidArgument'::text), 'odmietnutý → koncept';
  BEGIN
    PERFORM email_pending_recover();
    RAISE EXCEPTION 'CHYBA: obnova s prihláseným používateľom';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM pg_temp.e_as(NULL);
END;
$$;
RESET ROLE;
UPDATE email_message SET sending_started_at = now() - interval '20 minutes'
 WHERE offer_id = (SELECT id FROM offer WHERE deal_id = '00000000-0000-4000-8000-0000000e0303');
SET LOCAL ROLE crm_rls_test;
DO $$
DECLARE
  _u      text := pg_temp.e_as(pg_temp.e_id('u', 2));
  v_o2 uuid := (SELECT id FROM offer WHERE deal_id = pg_temp.e_id('d', 2));
  v_o3 uuid := (SELECT id FROM offer WHERE deal_id = pg_temp.e_id('d', 3));
  m3   uuid;
  r    jsonb;
BEGIN
  PERFORM pg_temp.e_as(NULL);
  r := email_pending_recover();
  ASSERT (r->>'dokoncene')::int >= 1 AND (r->>'neiste')::int >= 1, 'obnova: ' || r::text;
  PERFORM pg_temp.e_as(pg_temp.e_id('u', 1));
  ASSERT (SELECT (status, sent_channel, link_hash) FROM offer WHERE id = v_o2)
         = ROW('odoslana'::offer_status, 'crm'::offer_send_channel, encode(sha256('token-e2'::bytea), 'hex')), 'beh na pozadí dokončil podľa ID z Gmailu: ' || coalesce((SELECT status::text || ' ' || coalesce(error, '') FROM email_message WHERE offer_id = v_o2), '?');
  ASSERT (SELECT status FROM email_message WHERE offer_id = v_o2) = 'odoslany', 'e-mail 2 Odoslaný';
  SELECT id INTO m3 FROM email_message WHERE offer_id = v_o3;
  ASSERT (SELECT status FROM email_message WHERE id = m3) = 'chyba' AND (SELECT status FROM offer WHERE id = v_o3) = 'pripravena',
         'bez ID: Chyba, ponuka ostáva Pripravená';
  ASSERT EXISTS (SELECT 1 FROM notification WHERE user_id = pg_temp.e_id('u', 1) AND kind = 'email_chyba' AND deal_id = pg_temp.e_id('d', 3)), 'upozornenie obchodníkovi';
  PERFORM pg_temp.e_as(NULL);
  ASSERT email_queue_claim(50) = '[]'::jsonb OR NOT EXISTS (SELECT 1 FROM jsonb_array_elements(email_queue_claim(50)) x WHERE (x->>'id')::uuid = m3),
         'neisté odoslanie sa nikdy neodošle znova';
  ASSERT (email_pending_recover()->>'neiste')::int = 0, 'druhý beh nič';
  PERFORM pg_temp.e_as(pg_temp.e_id('u', 1));
  PERFORM email_retry(m3);
  ASSERT (SELECT (status, attempts) FROM email_message WHERE id = m3) = ROW('koncept'::email_status, 0::smallint), 'po kontrole Odoslaných späť do konceptu';
  PERFORM pg_temp.e_as(NULL);
  RAISE NOTICE 'OK: E3 obnova: s ID z Gmailu beh na pozadí dokončí ponuku; bez ID po 15 min Chyba + upozornenie, nikdy znova; obchodník po kontrole vráti do konceptu; odmietnutie Gmailom vráti koncept; obnovu nespustí používateľ';
END;
$$;

-- ============================================================================
-- E4. Čítanie Gmailu: jediná kontrola (vlákno CRM v schránke, metóda, sledované vlákno / známa správa), denník
-- ============================================================================
DO $$
DECLARE
  _u      text := pg_temp.e_as(pg_temp.e_id('u', 2));
  v_th  uuid := (SELECT t.id FROM email_thread t WHERE t.gmail_thread_id = 'abc123def4560001');
  v_n   bigint;
BEGIN
  v_n := (SELECT count(*) FROM mailbox_access_log);   -- ako admin (_u): celý denník
  PERFORM pg_temp.e_as(NULL);
  ASSERT gmail_read_authorize(pg_temp.e_id('u', 1), 'abc123def4560001', NULL, 'threads.get', 'full') = v_th, 'beh na pozadí: threads.get sledovaného vlákna';
  BEGIN
    PERFORM gmail_read_authorize(pg_temp.e_id('u', 1), 'abc123def4560001', NULL, 'messages.list', 'full');
    RAISE EXCEPTION 'CHYBA: list';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    PERFORM gmail_read_authorize(pg_temp.e_id('u', 1), 'ffff00000001', NULL, 'threads.get', 'full');
    RAISE EXCEPTION 'CHYBA: cudzie vlákno';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    PERFORM gmail_read_authorize(pg_temp.e_id('u', 2), 'abc123def4560001', NULL, 'threads.get', 'full');
    RAISE EXCEPTION 'CHYBA: cudzia schránka';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    PERFORM gmail_read_authorize(NULL, 'abc123def4560001', NULL, 'threads.get', 'full');
    RAISE EXCEPTION 'CHYBA: schránka crm@';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    PERFORM gmail_read_authorize(pg_temp.e_id('u', 1), 'abc123def4560001', 'abc123def4560001', 'messages.get', 'full');
    RAISE EXCEPTION 'CHYBA: beh na pozadí messages.get';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM pg_temp.e_as(pg_temp.e_id('u', 1));
  ASSERT gmail_read_authorize(pg_temp.e_id('u', 1), 'abc123def4560001', 'abc123def4560001', 'messages.get', 'full') = v_th, 'používateľ: známa správa';
  BEGIN
    PERFORM gmail_read_authorize(pg_temp.e_id('u', 1), 'abc123def4560001', 'abc123def4560001', 'attachments.get', 'full');
    RAISE EXCEPTION 'CHYBA: attachments.get';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    PERFORM gmail_read_authorize(pg_temp.e_id('u', 1), 'abc123def4560001', 'abc123def4560001', 'messages.get', 'raw');
    RAISE EXCEPTION 'CHYBA: formát raw (celý MIME s prílohami)';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    PERFORM gmail_read_authorize(pg_temp.e_id('u', 1), 'abc123def4560001', NULL, 'threads.get', 'raw');
    RAISE EXCEPTION 'CHYBA: formát raw';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    PERFORM gmail_read_authorize(pg_temp.e_id('u', 1), 'abc123def4560001', 'ffff00000002', 'messages.get', 'full');
    RAISE EXCEPTION 'CHYBA: neznáma správa';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    PERFORM gmail_read_authorize(pg_temp.e_id('u', 1), 'abc123def4560001', NULL, 'threads.get', 'full');
    RAISE EXCEPTION 'CHYBA: používateľ threads.get';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM set_config('app.user_id', pg_temp.b_id('u', 6)::text, true);
  BEGIN
    PERFORM gmail_read_authorize(pg_temp.e_id('u', 1), 'abc123def4560001', 'abc123def4560001', 'messages.get', 'full');
    RAISE EXCEPTION 'CHYBA: cudzí obchodník číta schránku';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  ASSERT (SELECT count(*) FROM mailbox_access_log) = 0, 'denník vidí iba admin';
  PERFORM pg_temp.e_as(pg_temp.e_id('u', 2));
  ASSERT (SELECT count(*) FROM mailbox_access_log) = v_n + 2, 'zapísané iba 2 povolené čítania';
  ASSERT (SELECT (user_id, method, format, gmail_message_id) FROM mailbox_access_log ORDER BY id DESC LIMIT 1)
         = ROW(pg_temp.e_id('u', 1), 'messages.get'::text, 'full'::text, 'abc123def4560001'::text), 'kto, metóda, formát, správa';
  ASSERT (SELECT user_id IS NULL AND method = 'threads.get' FROM mailbox_access_log ORDER BY id DESC OFFSET 1 LIMIT 1), 'beh na pozadí bez používateľa';
  BEGIN
    DELETE FROM mailbox_access_log;
    RAISE EXCEPTION 'CHYBA: aplikácia maže denník';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM pg_temp.e_as(NULL);
  RAISE NOTICE 'OK: E4 čítanie Gmailu: iba threads.get a messages.get (nie attachments.get, nie formát raw), iba vlákno CRM v danej schránke (nie crm@), beh na pozadí iba threads.get, používateľ iba známa správa vo viditeľnom vlákne; každé čítanie v denníku (vidí admin)';
END;
$$;
RESET ROLE;
DO $$
BEGIN
  BEGIN
    UPDATE mailbox_access_log SET method = 'threads.get';
    RAISE EXCEPTION 'CHYBA: denník zmenený';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    DELETE FROM mailbox_access_log;
    RAISE EXCEPTION 'CHYBA: denník zmazaný';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    TRUNCATE mailbox_access_log;
    RAISE EXCEPTION 'CHYBA: denník vyprázdnený';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  RAISE NOTICE 'OK: E4 denník čítania nezmení ani nezmaže ani vlastník databázy';
END;
$$;
SET LOCAL ROLE crm_rls_test;

-- ============================================================================
-- E5. Odpovede: sledované vlákna, uloženie raz, predĺženie sledovania, upozornenie; chyby schránky → admin
-- ============================================================================
DO $$
DECLARE
  _u      text := pg_temp.e_as(pg_temp.e_id('u', 2));
  v_th  uuid := (SELECT t.id FROM email_thread t WHERE t.gmail_thread_id = 'abc123def4560001');
  w     jsonb;
  v1    uuid;
  i     integer;
BEGIN
  PERFORM pg_temp.e_as(pg_temp.e_id('u', 1));
  BEGIN
    PERFORM email_watch_threads(50);
    RAISE EXCEPTION 'CHYBA: zoznam vlákien pre používateľa';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM pg_temp.e_as(NULL);
  w := email_watch_threads(200);
  ASSERT EXISTS (SELECT 1 FROM jsonb_array_elements(w) x WHERE (x->>'thread_id')::uuid = v_th AND x->'known' ? 'abc123def4560001'), 'sledované vlákno: ' || w::text;
  v1 := email_message_received(v_th, jsonb_build_object('gmail_message_id', 'abc123def45600a1', 'rfc_message_id', '<odpoved@example.test>',
          'from', 'Eva.E@Example.test', 'from_name', 'Eva Testovacia', 'to', '["obchodnik.e@example.test"]'::jsonb,
          'subject', 'Re: Cenová ponuka', 'body_text', 'Ďakujem, pozriem.', 'at', now()));
  ASSERT email_message_received(v_th, jsonb_build_object('gmail_message_id', 'abc123def45600a1', 'subject', 'iné')) = v1, 'uloží sa raz';
  PERFORM pg_temp.e_as(pg_temp.e_id('u', 1));
  ASSERT (SELECT (status, kind, from_addr) FROM email_message WHERE id = v1) = ROW('prijaty'::email_status, 'odpoved'::text, 'eva.e@example.test'::text), 'prijatá odpoveď';
  ASSERT EXISTS (SELECT 1 FROM notification WHERE user_id = pg_temp.e_id('u', 1) AND kind = 'ponuka_odpoved' AND deal_id = pg_temp.e_id('d', 1)), 'upozornenie';
  PERFORM pg_temp.e_as(NULL);
  PERFORM email_thread_checked(v_th, 'ok');
  FOR i IN 1..3 LOOP
    PERFORM email_thread_checked(v_th, 'chyba', '401 invalid_grant');
  END LOOP;
  PERFORM email_thread_checked(v_th, 'chyba', '401 invalid_grant');
  PERFORM pg_temp.e_as(pg_temp.e_id('u', 2));
  ASSERT (SELECT count(*) FROM notification WHERE kind = 'gmail_chyba' AND user_id = pg_temp.e_id('u', 2)) = 1, 'po 3 chybách upozornenie adminovi raz';
  ASSERT (SELECT consecutive_errors FROM gmail_mailbox_state WHERE mailbox = pg_temp.e_id('u', 1)::text) = 4, 'stav schránky';
  PERFORM pg_temp.e_as(NULL);
  PERFORM email_thread_checked(v_th, 'ok');
  PERFORM email_thread_checked(v_th, 'nenajdene');
  ASSERT (SELECT watch_until FROM email_thread WHERE id = v_th) IS NULL, 'zmazané vlákno sa prestane sledovať';
  BEGIN
    PERFORM gmail_read_authorize(pg_temp.e_id('u', 1), 'abc123def4560001', NULL, 'threads.get', 'full');
    RAISE EXCEPTION 'CHYBA: čítanie nesledovaného vlákna';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  RAISE NOTICE 'OK: E5 odpovede: zoznam vlákien iba beh na pozadí; odpoveď raz, upozornenie vlastníkovi; 3 chyby schránky → admin raz; nesledované vlákno sa nečíta';
END;
$$;
RESET ROLE;
-- staré vlákno (posledná aktivita pred 31 dňami) sa nečíta
UPDATE email_thread SET watch_until = crm_today() + 30 WHERE gmail_thread_id = 'abc123def4560002';
DO $$
DECLARE
  v_th uuid := (SELECT id FROM email_thread WHERE gmail_thread_id = 'abc123def4560002');
BEGIN
  ASSERT (SELECT watch_until FROM email_thread WHERE id = v_th) = crm_today() + 30, 'sledované';
  UPDATE email_thread SET watch_until = crm_today() - 1 WHERE id = v_th;
  ASSERT NOT EXISTS (SELECT 1 FROM jsonb_array_elements(email_watch_threads(200)) x WHERE (x->>'thread_id')::uuid = v_th), 'po 30 dňoch nie je v zozname';
  RAISE NOTICE 'OK: E5 vlákno bez aktivity 30 dní sa nesleduje';
END;
$$;

-- ============================================================================
-- E6. Pripomienka platnosti: 2 pracovné dni pred koncom, iba SPOT a VIWA, raz; koncept v schránke obchodníka
-- ============================================================================
DO $$
DECLARE
  v_offer uuid;
  v_var   uuid;
  v_end   date := next_working_day(crm_default_org(), crm_today() + 10);
  v_rem   date;
  v_fix   uuid := (SELECT id FROM offer WHERE deal_id = pg_temp.e_id('d', 2));
  m       email_message;
BEGIN
  v_rem := working_days_before(crm_default_org(), v_end, 2);
  PERFORM set_config('app.require_user', 'on', true);
  PERFORM set_config('app.user_id', pg_temp.e_id('u', 1)::text, true);
  v_offer := offer_create(pg_temp.e_id('d', 4));
  v_var := offer_variant_add(v_offer, 'spot');
  DELETE FROM offer_item WHERE variant_id IN (SELECT id FROM offer_variant WHERE offer_id = v_offer AND id <> v_var);
  DELETE FROM offer_variant WHERE offer_id = v_offer AND id <> v_var;
  PERFORM set_config('app.user_id', '', true);
  PERFORM set_config('app.require_user', '', true);
  UPDATE offer SET status = 'odoslana', sent_at = now(), sent_channel = 'osobne', valid_until = (v_end + time '16:00') AT TIME ZONE 'Europe/Bratislava'
   WHERE id = v_offer;
  UPDATE offer SET valid_until = (v_end + time '16:00') AT TIME ZONE 'Europe/Bratislava' WHERE id = v_fix;
  PERFORM deal_daily_run_at(v_rem - 1);
  ASSERT NOT EXISTS (SELECT 1 FROM email_message WHERE offer_id = v_offer AND kind = 'pripomienka_platnosti'), 'deň pred termínom ešte nie';
  PERFORM deal_daily_run_at(v_rem);
  SELECT * INTO m FROM email_message WHERE offer_id = v_offer AND kind = 'pripomienka_platnosti';
  ASSERT m.status = 'koncept' AND m.created_by IS NULL AND m.to_addrs = '["eva.e@example.test"]'::jsonb
         AND m.subject LIKE 'Platnosť cenovej ponuky % končí ' || to_char(v_end, 'DD. MM. YYYY') || ', 16:00', 'koncept pripomienky: ' || row_to_json(m)::text;
  ASSERT (SELECT mailbox_user_id FROM email_thread WHERE id = m.thread_id) = pg_temp.e_id('u', 1), 'v schránke obchodníka';
  ASSERT EXISTS (SELECT 1 FROM notification WHERE user_id = pg_temp.e_id('u', 1) AND kind = 'ponuka_pripomienka' AND deal_id = pg_temp.e_id('d', 4)), 'upozornenie';
  ASSERT NOT EXISTS (SELECT 1 FROM email_message WHERE offer_id = v_fix AND kind = 'pripomienka_platnosti'), 'FIX bez pripomienky';
  PERFORM deal_daily_run_at(v_rem + 1);
  ASSERT (SELECT count(*) FROM email_message WHERE offer_id = v_offer AND kind = 'pripomienka_platnosti') = 1, 'raz';
  RAISE NOTICE 'OK: E6 pripomienka platnosti: od 2. pracovného dňa pred koncom, iba SPOT/VIWA (nie FIX), raz, koncept v schránke obchodníka s upozornením';
END;
$$;
SET LOCAL ROLE crm_rls_test;
DO $$
DECLARE
  _u      text := pg_temp.e_as(pg_temp.e_id('u', 1));
  m   uuid := (SELECT m.id FROM email_message m JOIN offer o ON o.id = m.offer_id
                WHERE o.deal_id = pg_temp.e_id('d', 4) AND m.kind = 'pripomienka_platnosti');
  p   jsonb;
BEGIN
  PERFORM pg_temp.e_as(pg_temp.e_id('u', 1));
  ASSERT EXISTS (SELECT 1 FROM email_message WHERE id = m), 'obchodník vidí koncept pripomienky';
  p := email_send_prepare(m, gen_random_uuid());
  ASSERT (p->>'fresh')::boolean AND p->'attachments' = '[]'::jsonb, 'pripomienka jedným klikom, bez prílohy a odkazu';
  PERFORM pg_temp.e_as(pg_temp.e_id('u', 2));
  ASSERT EXISTS (SELECT 1 FROM email_message WHERE id = m), 'admin vidí odosielaný e-mail';
  PERFORM pg_temp.e_as(NULL);
  RAISE NOTICE 'OK: E6 koncept pripomienky odošle obchodník jedným klikom';
END;
$$;

-- ============================================================================
-- E7. Potvrdenie akceptácie zákazníkovi (zo schránky obchodníka do vlákna ponuky, inak crm@ s Reply-To) a interné
--     e-maily z crm@ (akceptácia obchodníkovi)
-- ============================================================================
DO $$
DECLARE
  _u      text := pg_temp.e_as(pg_temp.e_id('u', 2));
  v_offer uuid := (SELECT id FROM offer WHERE deal_id = pg_temp.e_id('d', 1));
  v_var   uuid := (SELECT id FROM offer_variant WHERE offer_id = (SELECT id FROM offer WHERE deal_id = pg_temp.e_id('d', 1)));
  v_acc   uuid;
  m       email_message;
  q       jsonb;
  x       jsonb;
  ob      jsonb;
BEGIN
  PERFORM pg_temp.e_as(pg_temp.e_id('u', 1));
  v_acc := offer_accept_manual(v_offer, v_var, 'Eva Testovacia', 'konateľka', now(), 'telefon', NULL, NULL);
  ASSERT NOT EXISTS (SELECT 1 FROM email_message WHERE acceptance_id = v_acc), 'bez PDF potvrdenia ešte nie';
  PERFORM offer_acceptance_confirmation_set(v_acc, offer_acceptance_for_confirmation(v_acc)->>'confirmation_key', repeat('d', 64));
  PERFORM pg_temp.e_as(NULL);
  RESET ROLE;
  SELECT * INTO m FROM email_message WHERE acceptance_id = v_acc;
  ASSERT m.status = 'v_rade' AND m.from_addr = 'obchodnik.e@example.test' AND m.reply_to IS NULL
         AND m.thread_id = (SELECT thread_id FROM email_message WHERE offer_id = v_offer AND kind = 'ponuka'), 'zo schránky obchodníka do vlákna ponuky';
  ASSERT m.to_addrs = '["eva.e@example.test"]'::jsonb AND m.attachments->0->>'kind' = 'potvrdenie' AND m.attachments->0->>'sha256' = repeat('d', 64)
         AND m.body_text LIKE 'Pozdravujem, pani Testovacia,%' AND m.body_text LIKE '%(variant %', 'adresát, PDF potvrdenia, text: ' || m.body_text;
  SET LOCAL ROLE crm_rls_test;
  q := email_queue_claim(50);
  SELECT e INTO x FROM jsonb_array_elements(q) e WHERE (e->>'id')::uuid = m.id;
  ASSERT x->>'status' = 'odosiela_sa' AND x->>'send_key' IS NOT NULL AND x->>'gmail_thread_id' = 'abc123def4560001'
         AND x->'references' ? '<e1@mail.gmail.com>', 'prevzaté z fronty s kľúčom, do vlákna: ' || x::text;
  ASSERT NOT EXISTS (SELECT 1 FROM jsonb_array_elements(email_queue_claim(50)) e WHERE (e->>'id')::uuid = m.id), 'druhý beh ho neprevezme';
  PERFORM email_send_recorded(m.id, (x->>'send_key')::uuid, 'abc123def45600c1', 'abc123def4560001', '<potvrdenie@mail.gmail.com>', now());
  ASSERT email_send_complete(m.id)->>'status' = 'odoslany', 'potvrdenie odoslané';
  -- interný e-mail z crm@ obchodníkovi (akceptácia)
  ob := email_outbox_claim(50);
  SELECT e INTO x FROM jsonb_array_elements(ob) e WHERE e->>'kind' = 'ponuka_akceptovana' AND e->>'to' = 'obchodnik.e@example.test';
  ASSERT x IS NOT NULL AND x->>'deal_id' = pg_temp.e_id('d', 1)::text, 'interný e-mail o akceptácii: ' || ob::text;
  PERFORM email_outbox_result((x->>'id')::uuid, (x->>'send_key')::uuid, 'abc123def45600d1', NULL);
  PERFORM email_outbox_result((x->>'id')::uuid, (x->>'send_key')::uuid, 'abc123def45600d2', NULL);
  RESET ROLE;
  ASSERT (SELECT (status, gmail_message_id) FROM email_outbox WHERE id = (x->>'id')::uuid) = ROW('odoslany'::text, 'abc123def45600d1'::text), 'raz';
  ASSERT NOT EXISTS (SELECT 1 FROM email_outbox o JOIN notification n ON n.id = o.notification_id WHERE n.kind NOT IN ('schvalenie_nove', 'schvalenie_rozhodnutie', 'ponuka_akceptovana')),
         'z crm@ iba schválenia a akceptácia';
  SET LOCAL ROLE crm_rls_test;
  RAISE NOTICE 'OK: E7 potvrdenie akceptácie: po uložení PDF do fronty, zo schránky obchodníka do vlákna ponuky s PDF; prevzatie raz; interný e-mail z crm@ o akceptácii, výsledok raz';
END;
$$;
-- obchodník bez Gmailu: potvrdenie z crm@ s Reply-To; zrušená akceptácia sa neodošle
RESET ROLE;
UPDATE app_user SET gmail_enabled = false WHERE id = '00000000-0000-4000-8000-0000000e0001';
SET LOCAL ROLE crm_rls_test;
DO $$
DECLARE
  v_offer uuid;
  v_var   uuid;
  v_acc   uuid;
  m       email_message;
BEGIN
  PERFORM pg_temp.e_as(pg_temp.e_id('u', 1));
  v_offer := pg_temp.e_offer(5, 5);
  v_var := (SELECT id FROM offer_variant WHERE offer_id = v_offer);
  PERFORM offer_prepare(v_offer);
  PERFORM offer_mark_sent(v_offer, now(), 'email_mimo_crm', NULL);
  -- voľba „Poslať zákazníkovi potvrdenie“ vypnutá: potvrdenie sa neposiela, v časovej osi záznam (raz)
  v_acc := offer_accept_manual(v_offer, v_var, 'Eva Testovacia', 'konateľka', now(), 'email', NULL, NULL);
  PERFORM offer_acceptance_confirmation_off(v_acc);
  PERFORM offer_acceptance_confirmation_off(v_acc);
  PERFORM offer_acceptance_confirmation_set(v_acc, offer_acceptance_for_confirmation(v_acc)->>'confirmation_key', repeat('f', 64));
  ASSERT (SELECT count(*) FROM deal_event WHERE offer_id = v_offer AND kind = 'potvrdenie_neodoslane') = 1, 'v časovej osi raz';
  BEGIN
    PERFORM offer_acceptance_confirmation_off(v_acc);
    RAISE EXCEPTION 'CHYBA: vypnutie po uložení potvrdenia';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  PERFORM pg_temp.e_as(NULL);
  RESET ROLE;
  ASSERT NOT EXISTS (SELECT 1 FROM email_message WHERE acceptance_id = v_acc), 'voľba vypnutá → potvrdenie sa neposiela';
  -- tá istá akceptácia so zapnutou voľbou (predvolené): po uložení PDF sa potvrdenie zaradí do fronty
  UPDATE offer_acceptance SET send_confirmation = true WHERE id = v_acc;
  UPDATE offer_acceptance SET confirmation_pdf_key = confirmation_pdf_key WHERE id = v_acc;
  SELECT * INTO m FROM email_message WHERE acceptance_id = v_acc;
  ASSERT m.status = 'v_rade' AND m.from_addr = 'crm@greenlogy.com' AND m.reply_to = 'obchodnik.e@example.test'
         AND (SELECT mailbox_user_id FROM email_thread WHERE id = m.thread_id) IS NULL, 'z crm@ s Reply-To na obchodníka';
  UPDATE offer_acceptance SET revoked_at = now(), revoked_by = '00000000-0000-4000-8000-0000000e0002', revoke_reason = 'test' WHERE id = v_acc;
  SET LOCAL ROLE crm_rls_test;
  ASSERT NOT EXISTS (SELECT 1 FROM jsonb_array_elements(email_queue_claim(50)) e WHERE (e->>'id')::uuid = m.id), 'zrušená akceptácia sa neodošle';
  RESET ROLE;
  ASSERT (SELECT status FROM email_message WHERE id = m.id) = 'chyba', 'stav Chyba';
  SET LOCAL ROLE crm_rls_test;
  RAISE NOTICE 'OK: E7 ručná akceptácia s vypnutou voľbou: bez potvrdenia, záznam v časovej osi; so zapnutou a bez Gmailu potvrdenie z crm@greenlogy.com s Reply-To na obchodníka; zrušená akceptácia sa neodošle';
END;
$$;

-- ============================================================================
-- E8. Viditeľnosť a práva: cudzí obchodník nevidí vlákna ani správy, koncept iba autor; aplikácia nezapisuje priamo;
--     interné funkcie nie sú pre aplikáciu
-- ============================================================================
DO $$
DECLARE
  v_draft uuid;
BEGIN
  PERFORM pg_temp.e_as(pg_temp.e_id('u', 1));
  ASSERT (SELECT count(*) FROM email_thread WHERE deal_id = pg_temp.e_id('d', 1)) >= 1, 'vlastník vidí vlákno';
  v_draft := email_draft_save(NULL, jsonb_build_object('deal_id', pg_temp.e_id('d', 1), 'to', '[]'::jsonb, 'subject', 'rozpracované', 'body', '«podpis»'));
  BEGIN
    PERFORM email_draft_save(NULL, jsonb_build_object('deal_id', pg_temp.e_id('d', 1), 'to', '["zlá adresa"]'::jsonb));
    RAISE EXCEPTION 'CHYBA: zlá adresa';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    INSERT INTO email_message (org_id, thread_id, direction, status, kind)
    SELECT org_id, id, 'odchadzajuca', 'koncept', 'volny' FROM email_thread WHERE deal_id = pg_temp.e_id('d', 1) LIMIT 1;
    RAISE EXCEPTION 'CHYBA: priamy zápis e-mailu';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM set_config('app.user_id', pg_temp.b_id('u', 6)::text, true);
  ASSERT NOT EXISTS (SELECT 1 FROM email_thread WHERE deal_id IN (SELECT pg_temp.e_id('d', n) FROM generate_series(1, 5) n)), 'cudzí nevidí vlákna';
  ASSERT NOT EXISTS (SELECT 1 FROM email_message m JOIN offer o ON o.id = m.offer_id WHERE o.deal_id = pg_temp.e_id('d', 1)), 'cudzí nevidí správy';
  BEGIN
    PERFORM email_draft_delete(v_draft);
    RAISE EXCEPTION 'CHYBA: cudzí zmazal koncept';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM pg_temp.e_as(pg_temp.e_id('u', 2));
  ASSERT EXISTS (SELECT 1 FROM email_message WHERE kind = 'odpoved' AND thread_id IN (SELECT id FROM email_thread WHERE deal_id = pg_temp.e_id('d', 1))), 'admin vidí odpoveď';
  ASSERT NOT EXISTS (SELECT 1 FROM email_message WHERE id = v_draft), 'koncept vidí iba autor';
  PERFORM pg_temp.e_as(pg_temp.e_id('u', 1));
  PERFORM email_draft_delete(v_draft);
  ASSERT NOT EXISTS (SELECT 1 FROM email_message WHERE id = v_draft), 'koncept zmazaný';
  PERFORM pg_temp.e_as(NULL);
  ASSERT NOT has_function_privilege('crm_rls_test', 'offer_mark_sent_apply(offer, timestamptz, offer_send_channel, text, uuid)', 'EXECUTE')
     AND NOT has_function_privilege('crm_rls_test', 'email_confirmation_queue(uuid)', 'EXECUTE')
     AND NOT has_function_privilege('crm_rls_test', 'gmail_mailbox_result(uuid, text)', 'EXECUTE')
     AND NOT has_function_privilege('crm_rls_test', 'email_send_payload(uuid)', 'EXECUTE'), 'interné funkcie nie sú pre aplikáciu';
  RAISE NOTICE 'OK: E8 vlákna a správy podľa obchodu (cudzí nie, admin áno), koncept iba autor, adresy sa kontrolujú, aplikácia nezapisuje e-maily priamo, interné funkcie nie sú pre aplikáciu';
END;
$$;
RESET ROLE;

-- ============================================================================
-- E9. Oslovenie (pán / pani / neuvádzať, vlastné má prednosť, bez titulu), vlastný podpis (vyčistené HTML, obrázky
--     cid:), častejšia kontrola nedávno aktívnych vlákien (0044)
-- ============================================================================
UPDATE contact SET address_form = 'pan', salutation = NULL, title = 'Ing.' WHERE id = '00000000-0000-4000-8000-0000000e0402';
DO $$
BEGIN
  ASSERT email_salutation(pg_temp.e_id('k', 2), 'sk') = 'Dobrý deň, pán Bezoslovenia', 'pán + priezvisko, bez titulu: ' || email_salutation(pg_temp.e_id('k', 2), 'sk');
  ASSERT email_salutation(pg_temp.e_id('k', 2), 'en') = 'Dear Mr Bezoslovenia', 'EN';
  UPDATE contact SET address_form = 'pani' WHERE id = pg_temp.e_id('k', 2);
  ASSERT email_salutation(pg_temp.e_id('k', 2), 'sk') = 'Dobrý deň, pani Bezoslovenia', 'pani';
  UPDATE contact SET address_form = NULL WHERE id = pg_temp.e_id('k', 2);
  ASSERT email_salutation(pg_temp.e_id('k', 2), 'sk') = 'Dobrý deň' AND email_salutation(NULL, 'sk') = 'Dobrý deň', 'neuvádzať';
  ASSERT email_salutation(pg_temp.e_id('k', 1), 'sk') = 'Pozdravujem, pani Testovacia', 'vlastné oslovenie má prednosť';
  UPDATE contact SET address_form = 'pan' WHERE id = pg_temp.e_id('k', 2);
  ASSERT email_offer_vars((SELECT id FROM offer WHERE deal_id = pg_temp.e_id('d', 3)))->>'oslovenie' = 'Dobrý deň, pán Bezoslovenia', 'e-mail k ponuke';
  BEGIN
    UPDATE contact SET address_form = 'pán' WHERE id = pg_temp.e_id('k', 2);
    RAISE EXCEPTION 'CHYBA: neznáma voľba oslovenia';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  RAISE NOTICE 'OK: E9 oslovenie: pán / pani s priezviskom bez titulu, neuvádzať = Dobrý deň, vlastné má prednosť, EN, e-mail k ponuke';
END;
$$;
SET LOCAL ROLE crm_rls_test;
DO $$
DECLARE
  img jsonb := jsonb_build_array(jsonb_build_object('cid', 'sig1', 'mime', 'image/png', 'data_base64', encode('\x89504e47'::bytea, 'base64')));
  bad text;
BEGIN
  PERFORM pg_temp.e_as(pg_temp.e_id('u', 1));
  PERFORM user_signature_set(pg_temp.e_id('u', 1), 'vlastny', '<table><tr><td><img src="cid:sig1" width="80"></td><td style="color:#1b3a2b"><b>Obchodník E</b><br><a href="https://greenlogy.com">greenlogy.com</a></td></tr></table>', 'Obchodník E', img);
  ASSERT email_signature(pg_temp.e_id('u', 1))->>'mode' = 'vlastny' AND email_signature(pg_temp.e_id('u', 1))->>'custom_html' LIKE '%cid:sig1%', 'vlastný podpis';
  ASSERT (SELECT count(*) FROM user_signature_images_get(pg_temp.e_id('u', 1))) = 1, 'obrázok podpisu';
  FOREACH bad IN ARRAY ARRAY[
    '<script>alert(1)</script>', '<img src="https://sledovanie.example/px.gif">', '<img src=data:image/png;base64,AAA>',
    '<a href="javascript:alert(1)">x</a>', '<td onclick="x()">x</td>', '<div style="background:url(https://x.example/a.png)">x</div>',
    '<iframe src="cid:sig1"></iframe>', '<STYLE>td{}</STYLE>', '<img src=''//x.example/a.png''>'] LOOP
    BEGIN
      PERFORM user_signature_set(pg_temp.e_id('u', 1), 'vlastny', bad, 'x', img);
      RAISE EXCEPTION 'CHYBA: podpis prešiel: %', bad;
    EXCEPTION WHEN check_violation THEN NULL;
    END;
  END LOOP;
  BEGIN
    PERFORM user_signature_set(pg_temp.e_id('u', 1), 'vlastny', '<img src="cid:sig2">', 'x', img);
    RAISE EXCEPTION 'CHYBA: chýbajúci obrázok';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    PERFORM user_signature_set(pg_temp.e_id('u', 1), 'vlastny', '<b>x</b>', 'x',
      (SELECT jsonb_agg(jsonb_build_object('cid', 'sig' || n, 'mime', 'image/png', 'data_base64', 'AAAA')) FROM generate_series(1, 6) n));
    RAISE EXCEPTION 'CHYBA: 6 obrázkov';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    PERFORM user_signature_set(pg_temp.e_id('u', 3), 'vlastny', '<b>x</b>', 'x', '[]');
    RAISE EXCEPTION 'CHYBA: cudzí podpis';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    INSERT INTO user_signature (user_id, mode, html) VALUES (pg_temp.e_id('u', 1), 'vlastny', '<b>x</b>');
    RAISE EXCEPTION 'CHYBA: priamy zápis podpisu';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM pg_temp.e_as(pg_temp.e_id('u', 3));
  ASSERT NOT EXISTS (SELECT 1 FROM user_signature WHERE user_id = pg_temp.e_id('u', 1)), 'cudzí podpis nevidí';
  PERFORM pg_temp.e_as(pg_temp.e_id('u', 2));
  PERFORM user_signature_set(pg_temp.e_id('u', 1), 'profil', NULL, NULL, '[]');
  ASSERT email_signature(pg_temp.e_id('u', 1))->>'mode' = 'profil' AND email_signature(pg_temp.e_id('u', 1))->'custom_html' = 'null'::jsonb, 'admin vrátil podpis z profilu';
  ASSERT NOT EXISTS (SELECT 1 FROM user_signature_images_get(pg_temp.e_id('u', 1))), 'obrázky iba pri vlastnom podpise';
  PERFORM pg_temp.e_as(NULL);
  RAISE NOTICE 'OK: E9 vlastný podpis: sám alebo admin, obrázky iba cid: (najviac 5, každý cid má obrázok), bez skriptov, udalostí, vonkajších obrázkov, url() a štýlov; priamy zápis nie';
END;
$$;
RESET ROLE;
DO $$
DECLARE
  v_th uuid := (SELECT id FROM email_thread WHERE gmail_thread_id = 'abc123def4560002');
BEGIN
  UPDATE app_user SET gmail_enabled = true WHERE id = pg_temp.e_id('u', 1);
  UPDATE email_thread SET watch_until = crm_today() + 10, last_message_at = now() - interval '5 days', last_checked_at = now() - interval '5 minutes' WHERE id = v_th;
  ASSERT NOT EXISTS (SELECT 1 FROM jsonb_array_elements(email_watch_threads(200)) x WHERE (x->>'thread_id')::uuid = v_th), 'staré vlákno skontrolované pred 5 min – nie';
  UPDATE email_thread SET last_checked_at = now() - interval '16 minutes' WHERE id = v_th;
  ASSERT EXISTS (SELECT 1 FROM jsonb_array_elements(email_watch_threads(200)) x WHERE (x->>'thread_id')::uuid = v_th), 'staré vlákno po 15 min – áno';
  UPDATE email_thread SET last_message_at = now() - interval '1 hour', last_checked_at = now() - interval '1 minute' WHERE id = v_th;
  ASSERT EXISTS (SELECT 1 FROM jsonb_array_elements(email_watch_threads(200)) x WHERE (x->>'thread_id')::uuid = v_th), 'aktívne vlákno každú minútu';
  RAISE NOTICE 'OK: E9 kontrola odpovedí: vlákna s aktivitou za 2 dni každý beh (minúta), staršie raz za 15 minút';
END;
$$;

