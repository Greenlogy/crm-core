-- migrate:up

-- 0044_emaily_podpis_oslovenie – modul 5, F4 (Peter 16. 10., body 1–3 po teste):
-- 1. Vlastný podpis e-mailu (vložený cez Ctrl+V alebo HTML kód): kód ho vyčistí, obrázky uloží k podpisu (cid:),
--    databáza ešte raz odmietne skripty, udalosti, vonkajšie obrázky a štýly s url(). Mení používateľ sám alebo admin.
-- 2. Oslovenie: pri kontakte voľba pán / pani / neuvádzať → „Dobrý deň, pán Mráz“ (bez titulu); vlastné oslovenie má
--    prednosť. Pán alebo pani vyberá obchodník (z mena sa nehádá). Doterajšie „Pán“ / „Pani“ sa prevedú na voľbu.
-- 3. Kontrola odpovedí: vlákna s aktivitou za posledné 2 dni každú minútu, staršie (do 30 dní) raz za 15 minút.

-- ============================================================================
-- 2. Oslovenie
-- ============================================================================

ALTER TABLE contact ADD COLUMN address_form text CHECK (address_form IN ('pan', 'pani'));
COMMENT ON COLUMN contact.address_form IS 'oslovenie v e-maile: pan / pani / NULL = neuvádzať („Dobrý deň“); vyberá obchodník – 0044';
COMMENT ON COLUMN contact.salutation IS 'vlastné oslovenie v e-maile (má prednosť pred pán / pani), napr. „Ahoj Pavol“; prázdne = podľa address_form – 0042, 0044';

UPDATE contact SET address_form = 'pan', salutation = NULL WHERE lower(btrim(salutation, ' ,')) IN ('pán', 'pan');
UPDATE contact SET address_form = 'pani', salutation = NULL WHERE lower(btrim(salutation, ' ,')) = 'pani';

-- Oslovenie kontaktu (práva volajúceho – kto kontakt nevidí, dostane predvolené oslovenie)
CREATE FUNCTION email_salutation(p_contact uuid, p_lang offer_language) RETURNS text
LANGUAGE sql STABLE AS $$
  SELECT coalesce(
           nullif(btrim(k.salutation), ''),
           CASE p_lang
             WHEN 'en' THEN CASE k.address_form WHEN 'pan' THEN 'Dear Mr ' || btrim(k.last_name)
                                                WHEN 'pani' THEN 'Dear Ms ' || btrim(k.last_name)
                                                ELSE 'Dear Sir or Madam' END
             ELSE 'Dobrý deň' || CASE k.address_form WHEN 'pan' THEN ', pán ' || btrim(k.last_name)
                                                     WHEN 'pani' THEN ', pani ' || btrim(k.last_name)
                                                     ELSE '' END
           END)
    FROM (SELECT 1) one
    LEFT JOIN contact k ON k.id = p_contact
$$;

CREATE OR REPLACE FUNCTION email_offer_vars(p_offer uuid) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT jsonb_build_object(
           'oslovenie', email_salutation(coalesce(o.contact_id, d.person_id), o.language),
           'názov zákazníka', coalesce(c.name, btrim(p.first_name || ' ' || p.last_name)),
           'číslo ponuky', offer_display_number(o),
           'zhrnutie variantov', offer_variants_summary_text(o.id),
           'obchodník', u.name)
    FROM offer o
    JOIN deal d ON d.id = o.deal_id
    JOIN app_user u ON u.id = d.owner_id
    LEFT JOIN company c ON c.id = d.company_id
    LEFT JOIN contact p ON p.id = d.person_id
   WHERE o.id = p_offer
$$;

-- ============================================================================
-- 1. Vlastný podpis
-- ============================================================================

CREATE TABLE user_signature (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),   -- audit_row potrebuje id
  user_id      uuid NOT NULL UNIQUE REFERENCES app_user (id) ON DELETE CASCADE,
  mode         text NOT NULL DEFAULT 'profil' CHECK (mode IN ('profil', 'vlastny')),
  html         text CHECK (html IS NULL OR (
                 length(html) <= 100000
                 AND html !~* '<\s*/?\s*(script|iframe|frame|object|embed|applet|form|input|button|textarea|select|meta|link|base|style|svg|math|video|audio|source)\M'
                 AND html !~* '\son[a-z]+\s*='
                 AND html !~* '(javascript|vbscript|data)\s*:'
                 AND html !~* 'url\s*\('
                 AND html !~* 'expression\s*\('
                 AND html !~* '\ssrc\s*=\s*["'']?(?!["'']|cid:)')),
  text_version text CHECK (text_version IS NULL OR length(text_version) <= 20000),
  updated_by   uuid REFERENCES app_user (id),
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  CHECK (mode = 'profil' OR (html IS NOT NULL AND btrim(html) <> ''))
);
COMMENT ON TABLE user_signature IS 'podpis e-mailu: z profilu alebo vlastný HTML (vyčistený; obrázky iba cid: z user_signature_image) – 0044';
CREATE TRIGGER trg_audit AFTER INSERT OR UPDATE OR DELETE ON user_signature FOR EACH ROW EXECUTE FUNCTION audit_row();
CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON user_signature FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE user_signature_image (
  user_id    uuid NOT NULL REFERENCES app_user (id) ON DELETE CASCADE,
  cid        text NOT NULL CHECK (cid ~ '^sig[1-5]$'),
  mime       text NOT NULL CHECK (mime IN ('image/png', 'image/jpeg', 'image/gif')),
  data       bytea NOT NULL CHECK (octet_length(data) <= 307200),
  sha256     text NOT NULL CHECK (sha256 ~ '^[0-9a-f]{64}$'),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, cid)
);
COMMENT ON TABLE user_signature_image IS 'obrázky vlastného podpisu (najviac 5, do 300 kB) – v e-maile ako vložené prílohy cid:, bez načítania zvonka – 0044';

CREATE POLICY user_signature_select ON user_signature FOR SELECT USING (user_id = crm_active_user_id() OR crm_is_admin());
ALTER TABLE user_signature ENABLE ROW LEVEL SECURITY;
CREATE POLICY user_signature_image_select ON user_signature_image FOR SELECT USING (user_id = crm_active_user_id() OR crm_is_admin());
ALTER TABLE user_signature_image ENABLE ROW LEVEL SECURITY;

-- Uloženie podpisu (sám alebo admin): režim, vyčistené HTML, textová verzia, obrázky [{cid, mime, data_base64}] –
-- obrázky sa nahradia celé; každý cid v HTML musí mať obrázok
CREATE FUNCTION user_signature_set(p_user uuid, p_mode text, p_html text, p_text text, p_images jsonb) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  i      jsonb;
  v_cid  text;
  v_data bytea;
BEGIN
  IF crm_active_user_id() IS NULL OR NOT (p_user = crm_active_user_id() OR crm_is_admin()) THEN
    RAISE EXCEPTION 'Podpis mení používateľ sám alebo admin.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF p_mode NOT IN ('profil', 'vlastny') THEN
    RAISE EXCEPTION 'Neznámy druh podpisu.' USING ERRCODE = 'check_violation';
  END IF;
  IF jsonb_typeof(coalesce(p_images, '[]')) <> 'array' OR jsonb_array_length(coalesce(p_images, '[]')) > 5 THEN
    RAISE EXCEPTION 'Podpis môže mať najviac 5 obrázkov.' USING ERRCODE = 'check_violation';
  END IF;
  IF p_mode = 'vlastny' THEN
    FOR v_cid IN SELECT m[1] FROM regexp_matches(coalesce(p_html, ''), 'cid:([A-Za-z0-9]+)', 'g') m LOOP
      IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(coalesce(p_images, '[]')) x WHERE x->>'cid' = v_cid) THEN
        RAISE EXCEPTION 'Podpis odkazuje na chýbajúci obrázok.' USING ERRCODE = 'check_violation';
      END IF;
    END LOOP;
  END IF;
  INSERT INTO user_signature (user_id, mode, html, text_version, updated_by)
  VALUES (p_user, p_mode, nullif(p_html, ''), nullif(p_text, ''), crm_active_user_id())
  ON CONFLICT (user_id) DO UPDATE SET mode = excluded.mode, html = excluded.html, text_version = excluded.text_version,
                                      updated_by = excluded.updated_by;
  DELETE FROM user_signature_image WHERE user_id = p_user;
  FOR i IN SELECT * FROM jsonb_array_elements(coalesce(p_images, '[]')) LOOP
    v_data := decode(i->>'data_base64', 'base64');
    INSERT INTO user_signature_image (user_id, cid, mime, data, sha256)
    VALUES (p_user, i->>'cid', i->>'mime', v_data, encode(sha256(v_data), 'hex'));
  END LOOP;
END;
$$;

-- Obrázky vlastného podpisu pre kód (aj beh na pozadí bez používateľa)
CREATE FUNCTION user_signature_images_get(p_user uuid) RETURNS TABLE (cid text, mime text, data bytea)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT i.cid, i.mime, i.data FROM user_signature_image i
    JOIN user_signature s ON s.user_id = i.user_id AND s.mode = 'vlastny'
   WHERE i.user_id = p_user
   ORDER BY i.cid
$$;

-- Podpis pre kód: z profilu, alebo vlastný (custom_html, custom_text)
CREATE OR REPLACE FUNCTION email_signature(p_user uuid) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT jsonb_build_object(
           'name', u.name, 'job_title', u.job_title, 'email', u.email, 'phone', u.phone, 'mobile', u.mobile,
           'linkedin', u.linkedin_url, 'company', coalesce(g.legal_name, 'Greenlogy a.s.'), 'address', g.address,
           'company_phone', g.support_phone, 'web', coalesce(g.web, 'www.greenlogy.com'),
           'has_photo', EXISTS (SELECT 1 FROM user_photo p WHERE p.user_id = u.id),
           'mode', coalesce(s.mode, 'profil'),
           'custom_html', CASE WHEN s.mode = 'vlastny' THEN s.html END,
           'custom_text', CASE WHEN s.mode = 'vlastny' THEN s.text_version END)
    FROM app_user u
    LEFT JOIN org g ON g.id = crm_default_org()
    LEFT JOIN user_signature s ON s.user_id = u.id
   WHERE u.id = p_user
$$;

-- ============================================================================
-- 3. Kontrola odpovedí: nedávno aktívne vlákna každú minútu, staršie raz za 15 minút
-- ============================================================================

CREATE OR REPLACE FUNCTION email_watch_threads(p_limit integer DEFAULT 50) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  res jsonb;
BEGIN
  PERFORM crm_background_only();
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'thread_id', x.id, 'mailbox_user_id', x.mailbox_user_id, 'mailbox', x.email, 'gmail_thread_id', x.gmail_thread_id,
           'known', (SELECT coalesce(jsonb_agg(m.gmail_message_id), '[]') FROM email_message m
                      WHERE m.thread_id = x.id AND m.gmail_message_id IS NOT NULL))), '[]')
    INTO res
    FROM (SELECT t.id, t.mailbox_user_id, u.email, t.gmail_thread_id
            FROM email_thread t JOIN app_user u ON u.id = t.mailbox_user_id
           WHERE t.gmail_thread_id IS NOT NULL AND t.watch_until >= crm_today() AND u.status = 'aktivny' AND u.gmail_enabled
             AND (t.last_checked_at IS NULL
                  OR t.last_message_at > now() - interval '2 days'
                  OR t.last_checked_at < now() - interval '15 minutes')
           ORDER BY t.last_checked_at NULLS FIRST LIMIT greatest(least(p_limit, 200), 1)) x;
  RETURN res;
END;
$$;

REVOKE EXECUTE ON FUNCTION user_signature_images_get(uuid) FROM PUBLIC;

-- migrate:down

CREATE OR REPLACE FUNCTION email_watch_threads(p_limit integer DEFAULT 50) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  res jsonb;
BEGIN
  PERFORM crm_background_only();
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'thread_id', x.id, 'mailbox_user_id', x.mailbox_user_id, 'mailbox', x.email, 'gmail_thread_id', x.gmail_thread_id,
           'known', (SELECT coalesce(jsonb_agg(m.gmail_message_id), '[]') FROM email_message m
                      WHERE m.thread_id = x.id AND m.gmail_message_id IS NOT NULL))), '[]')
    INTO res
    FROM (SELECT t.id, t.mailbox_user_id, u.email, t.gmail_thread_id
            FROM email_thread t JOIN app_user u ON u.id = t.mailbox_user_id
           WHERE t.gmail_thread_id IS NOT NULL AND t.watch_until >= crm_today() AND u.status = 'aktivny' AND u.gmail_enabled
           ORDER BY t.last_checked_at NULLS FIRST LIMIT greatest(least(p_limit, 200), 1)) x;
  RETURN res;
END;
$$;

CREATE OR REPLACE FUNCTION email_signature(p_user uuid) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT jsonb_build_object(
           'name', u.name, 'job_title', u.job_title, 'email', u.email, 'phone', u.phone, 'mobile', u.mobile,
           'linkedin', u.linkedin_url, 'company', coalesce(g.legal_name, 'Greenlogy a.s.'), 'address', g.address,
           'company_phone', g.support_phone, 'web', coalesce(g.web, 'www.greenlogy.com'),
           'has_photo', EXISTS (SELECT 1 FROM user_photo p WHERE p.user_id = u.id))
    FROM app_user u
    LEFT JOIN org g ON g.id = crm_default_org()
   WHERE u.id = p_user
$$;

DROP FUNCTION user_signature_images_get(uuid);
DROP FUNCTION user_signature_set(uuid, text, text, text, jsonb);
DROP TABLE user_signature_image;
DROP TABLE user_signature;

CREATE OR REPLACE FUNCTION email_offer_vars(p_offer uuid) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT jsonb_build_object(
           'oslovenie', coalesce(nullif(btrim(k.salutation), ''), CASE o.language WHEN 'en' THEN 'Dear Sir or Madam' ELSE 'Dobrý deň' END),
           'názov zákazníka', coalesce(c.name, btrim(p.first_name || ' ' || p.last_name)),
           'číslo ponuky', offer_display_number(o),
           'zhrnutie variantov', offer_variants_summary_text(o.id),
           'obchodník', u.name)
    FROM offer o
    JOIN deal d ON d.id = o.deal_id
    JOIN app_user u ON u.id = d.owner_id
    LEFT JOIN company c ON c.id = d.company_id
    LEFT JOIN contact p ON p.id = d.person_id
    LEFT JOIN contact k ON k.id = coalesce(o.contact_id, d.person_id)
   WHERE o.id = p_offer
$$;
DROP FUNCTION email_salutation(uuid, offer_language);

UPDATE contact SET salutation = CASE address_form WHEN 'pan' THEN 'Pán' ELSE 'Pani' END
 WHERE address_form IS NOT NULL AND salutation IS NULL;
COMMENT ON COLUMN contact.salutation IS 'oslovenie v e-maile (napr. „Pozdravujem Vás, pani Hrobáriková“); prázdne = „Dobrý deň“ – 0042';
ALTER TABLE contact DROP COLUMN address_form;
