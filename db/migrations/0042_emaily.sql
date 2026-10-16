-- migrate:up

-- 0042_emaily – modul 5, fáza F4 (návrh DB časti 1.9, 1.10, 3, 28; zadanie 8): e-maily z CRM cez Gmail.
-- Profil do podpisu a pilot Gmailu, oslovenie pri kontakte, šablóny e-mailov s verziami, vlákna a správy, odolné
-- odoslanie (odosiela sa → ID správy z Gmailu → Odoslaná; nedokončené dokončí ďalší beh, nikdy neodošle znova),
-- fronta (potvrdenie akceptácie zákazníkovi, interné e-maily z crm@greenlogy.com), kontrola odpovedí iba vo vláknach
-- CRM (jediná kontrola gmail_read_authorize + denník čítania schránok), koncept pripomienky platnosti.
-- Interné funkcie: REVOKE … FROM PUBLIC a crm_app (predvolené práva 0040). Funkcie pre beh na pozadí (Cron)
-- spustí crm_app iba bez prihláseného používateľa.

-- ============================================================================
-- 1. Profil do podpisu, pilot Gmailu, oslovenie
-- ============================================================================

ALTER TABLE app_user
  ADD COLUMN gmail_enabled boolean NOT NULL DEFAULT false,
  ADD COLUMN mobile        text CHECK (mobile IS NULL OR length(mobile) <= 40),
  ADD COLUMN linkedin_url  text CHECK (linkedin_url IS NULL OR linkedin_url ~ '^https://([a-z]{2,3}\.)?linkedin\.com/[A-Za-z0-9_/%.-]{1,200}$');
COMMENT ON COLUMN app_user.gmail_enabled IS 'pilot: e-maily z CRM cez Gmail zo schránky používateľa (zapína admin postupne) – 0042';

-- Fotka do podpisu: zvlášť (binárne dáta nejdú do auditu používateľov); mení ju používateľ sám alebo admin
CREATE TABLE user_photo (
  user_id    uuid PRIMARY KEY REFERENCES app_user (id) ON DELETE CASCADE,
  mime       text NOT NULL CHECK (mime IN ('image/jpeg', 'image/png')),
  data       bytea NOT NULL CHECK (octet_length(data) <= 307200),
  sha256     text NOT NULL CHECK (sha256 ~ '^[0-9a-f]{64}$'),
  updated_by uuid REFERENCES app_user (id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE user_photo IS 'fotka do podpisu e-mailu (štvorec, do 300 kB) – bez auditu, kto a kedy je v updated_by / updated_at (0042)';

CREATE FUNCTION user_photo_guard() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP <> 'DELETE' THEN
    NEW.sha256 := encode(sha256(NEW.data), 'hex');
    NEW.updated_by := crm_active_user_id();
    NEW.updated_at := now();
  END IF;
  RETURN coalesce(NEW, OLD);
END;
$$;
CREATE TRIGGER trg_guard BEFORE INSERT OR UPDATE OR DELETE ON user_photo FOR EACH ROW EXECUTE FUNCTION user_photo_guard();

ALTER TABLE contact ADD COLUMN salutation text CHECK (salutation IS NULL OR length(salutation) <= 200);
COMMENT ON COLUMN contact.salutation IS 'oslovenie v e-maile (napr. „Pozdravujem Vás, pani Hrobáriková“); prázdne = „Dobrý deň“ – 0042';

-- Údaje profilu do podpisu mení používateľ sám alebo admin (fotka cez tabuľku user_photo a RLS)
CREATE FUNCTION user_profile_set(p_user uuid, p_phone text, p_mobile text, p_job_title text, p_linkedin text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF crm_active_user_id() IS NULL OR NOT (p_user = crm_active_user_id() OR crm_is_admin()) THEN
    RAISE EXCEPTION 'Profil mení používateľ sám alebo admin.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  UPDATE app_user SET phone = nullif(btrim(p_phone), ''), mobile = nullif(btrim(p_mobile), ''),
                      job_title = nullif(btrim(p_job_title), ''), linkedin_url = nullif(btrim(p_linkedin), '')
   WHERE id = p_user;
END;
$$;

-- Podpis e-mailu z profilu (pre kód; jednotný vzhľad): meno, funkcia, spoločnosť, adresa, telefóny, e-mail, web
CREATE FUNCTION email_signature(p_user uuid) RETURNS jsonb
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

-- Fotka do podpisu pre kód (aj beh na pozadí bez používateľa)
CREATE FUNCTION user_photo_get(p_user uuid) RETURNS TABLE (mime text, data bytea)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT mime, data FROM user_photo WHERE user_id = p_user
$$;

-- ============================================================================
-- 2. Šablóny e-mailov (časť 1.10): kód × jazyk, verzie Návrh / Platná / Nahradená; mení admin a Marketing
-- ============================================================================

CREATE TABLE email_template_version (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id       uuid NOT NULL REFERENCES org (id),
  code         text NOT NULL CHECK (code IN ('ponuka_dodavka', 'ponuka_vykup', 'ponuka_viwa', 'potvrdenie_akceptacie',
                                             'pripomienka_platnosti', 'volny')),
  language     offer_language NOT NULL,
  version      smallint NOT NULL,
  status       text NOT NULL DEFAULT 'navrh' CHECK (status IN ('navrh', 'platna', 'nahradena')),
  name         text NOT NULL CHECK (btrim(name) <> ''),
  subject      text NOT NULL,
  body         text NOT NULL,
  note         text,
  created_by   uuid REFERENCES app_user (id),
  published_at timestamptz,
  published_by uuid REFERENCES app_user (id),
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (org_id, code, language, version),
  CHECK ((status = 'navrh') = (published_at IS NULL))
);
CREATE UNIQUE INDEX email_template_platna_key ON email_template_version (org_id, code, language) WHERE status = 'platna';
CREATE UNIQUE INDEX email_template_navrh_key ON email_template_version (org_id, code, language) WHERE status = 'navrh';
COMMENT ON TABLE email_template_version IS 'šablóny e-mailov zákazníkom – platná verzia sa nemení, zmena = nová verzia (0042)';
CREATE TRIGGER trg_audit AFTER INSERT OR UPDATE OR DELETE ON email_template_version FOR EACH ROW EXECUTE FUNCTION audit_row();
CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON email_template_version FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE FUNCTION email_template_variables() RETURNS text[]
LANGUAGE sql IMMUTABLE AS $$
  SELECT ARRAY['oslovenie', 'názov zákazníka', 'číslo ponuky', 'zhrnutie variantov', 'platnosť', 'odkaz na ponuku', 'podpis',
               'obchodník', 'variant', 'dátum akceptácie']
$$;

CREATE FUNCTION email_template_check(p_subject text, p_body text) RETURNS text
LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE
  v text;
  t text := coalesce(p_subject, '') || E'\n' || coalesce(p_body, '');
BEGIN
  FOR v IN SELECT m[1] FROM regexp_matches(t, '«([^«»]*)»', 'g') m LOOP
    IF NOT v = ANY (email_template_variables()) THEN
      RETURN format('Neznáma premenná «%s».', v);
    END IF;
  END LOOP;
  IF (length(t) - length(replace(t, '«', ''))) <> (length(t) - length(replace(t, '»', ''))) THEN
    RETURN 'Neuzavretá premenná.';
  END IF;
  IF position('«podpis»' IN coalesce(p_body, '')) = 0 THEN
    RETURN 'Text musí obsahovať «podpis».';
  END IF;
  IF position('«' IN coalesce(p_subject, '')) > 0 AND p_subject ~ '«(podpis|odkaz na ponuku)»' THEN
    RETURN 'Podpis a odkaz nepatria do predmetu.';
  END IF;
  RETURN NULL;
END;
$$;

-- Šablóny e-mailov mení admin a tím Marketing
CREATE FUNCTION crm_email_template_editor() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT crm_is_admin() OR EXISTS (SELECT 1 FROM app_user u JOIN team t ON t.id = u.team_id
                                    WHERE u.id = crm_active_user_id() AND t.code = 'marketing')
$$;

CREATE FUNCTION email_template_guard() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  v_err text;
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF OLD.status <> 'navrh' AND NOT (crm_owner_session() OR crm_internal_call()) THEN
      RAISE EXCEPTION 'Zmazať sa dá iba návrh šablóny.' USING ERRCODE = 'check_violation';
    END IF;
    RETURN OLD;
  END IF;
  IF NOT (crm_owner_session() OR crm_internal_call()) THEN
    IF TG_OP = 'INSERT' THEN
      NEW.status := 'navrh';
      NEW.published_at := NULL;
      NEW.published_by := NULL;
      NEW.created_by := crm_active_user_id();
    ELSE
      IF OLD.status <> 'navrh' THEN
        RAISE EXCEPTION 'Platná šablóna sa nemení – uložte novú verziu.' USING ERRCODE = 'check_violation';
      END IF;
      IF (NEW.status, NEW.code, NEW.language, NEW.version, NEW.org_id, NEW.published_at)
         IS DISTINCT FROM (OLD.status, OLD.code, OLD.language, OLD.version, OLD.org_id, OLD.published_at) THEN
        RAISE EXCEPTION 'Druh, jazyk, verziu a stav šablóny mení iba CRM (zverejnenie).' USING ERRCODE = 'insufficient_privilege';
      END IF;
    END IF;
  END IF;
  IF TG_OP = 'INSERT' THEN
    NEW.version := coalesce((SELECT max(version) FROM email_template_version
                              WHERE org_id = NEW.org_id AND code = NEW.code AND language = NEW.language), 0) + 1;
  END IF;
  v_err := email_template_check(NEW.subject, NEW.body);
  IF v_err IS NOT NULL THEN
    RAISE EXCEPTION '%', v_err USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_guard BEFORE INSERT OR UPDATE OR DELETE ON email_template_version
  FOR EACH ROW EXECUTE FUNCTION email_template_guard();

CREATE FUNCTION email_template_publish(p_id uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  t email_template_version;
BEGIN
  IF NOT crm_email_template_editor() THEN
    RAISE EXCEPTION 'Šablóny e-mailov zverejňuje admin alebo Marketing.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  SELECT * INTO t FROM email_template_version WHERE id = p_id AND org_id = ANY (crm_user_orgs()) FOR UPDATE;
  IF NOT FOUND OR t.status <> 'navrh' THEN
    RAISE EXCEPTION 'Zverejniť sa dá iba návrh šablóny.' USING ERRCODE = 'check_violation';
  END IF;
  UPDATE email_template_version SET status = 'nahradena'
   WHERE org_id = t.org_id AND code = t.code AND language = t.language AND status = 'platna';
  UPDATE email_template_version SET status = 'platna', published_at = now(), published_by = crm_active_user_id() WHERE id = t.id;
END;
$$;

-- Prvé verzie: ponuka podľa dnešného e-mailu obchodníkov (Peter 16. 10.), ostatné návrh Clauda na kontrolu;
-- SK platné, EN návrh
INSERT INTO email_template_version (org_id, code, language, version, status, name, subject, body, note, published_at)
SELECT o.id, x.code, x.lang::offer_language, 1, x.status, x.name, x.subject, x.body,
       CASE WHEN x.code LIKE 'ponuka_%' THEN 'podľa dnešného e-mailu obchodníkov' ELSE 'návrh Clauda na kontrolu' END
       || CASE WHEN x.lang = 'en' THEN ' – preklad na kontrolu' ELSE '' END,
       CASE WHEN x.status = 'platna' THEN now() END
  FROM org o
 CROSS JOIN (
  SELECT c.code, l.lang, CASE WHEN l.lang = 'sk' THEN 'platna' ELSE 'navrh' END AS status,
         CASE l.lang WHEN 'sk' THEN c.name_sk ELSE c.name_en END AS name,
         CASE l.lang WHEN 'sk' THEN c.subject_sk ELSE c.subject_en END AS subject,
         CASE l.lang WHEN 'sk' THEN c.body_sk ELSE c.body_en END AS body
    FROM (VALUES ('sk'), ('en')) l(lang)
   CROSS JOIN (VALUES
    ('ponuka_dodavka', 'Ponuka – dodávka', 'Offer – supply'),
    ('ponuka_vykup', 'Ponuka – výkup', 'Offer – feed-in'),
    ('ponuka_viwa', 'Ponuka – Green VIWA', 'Offer – Green VIWA')
   ) n(code, name_sk, name_en)
   CROSS JOIN LATERAL (SELECT n.code, n.name_sk, n.name_en,
     'Cenová ponuka «číslo ponuky» – «názov zákazníka»' AS subject_sk,
     'Price offer «číslo ponuky» – «názov zákazníka»' AS subject_en,
     $t$«oslovenie»,

ďakujeme za Váš dopyt na cenovú ponuku pre Vašu firmu.
Posielam Vám ponuku «zhrnutie variantov» na odkaze nižšie. Ponuku si môžete pozrieť, stiahnuť v PDF a jedným klikom prijať. Platí do «platnosť».

«odkaz na ponuku»

V prípade otázok ma neváhajte kontaktovať.

S pozdravom
«podpis»$t$ AS body_sk,
     $t$«oslovenie»,

thank you for your request for a price offer for your company.
Please find the offer «zhrnutie variantov» at the link below. You can view it, download it as PDF and accept it with one click. It is valid until «platnosť».

«odkaz na ponuku»

If you have any questions, please do not hesitate to contact me.

Kind regards
«podpis»$t$ AS body_en) c
  UNION ALL
  SELECT c.code, l.lang, CASE WHEN l.lang = 'sk' THEN 'platna' ELSE 'navrh' END,
         CASE l.lang WHEN 'sk' THEN c.name_sk ELSE c.name_en END,
         CASE l.lang WHEN 'sk' THEN c.subject_sk ELSE c.subject_en END,
         CASE l.lang WHEN 'sk' THEN c.body_sk ELSE c.body_en END
    FROM (VALUES ('sk'), ('en')) l(lang)
   CROSS JOIN (VALUES
    ('potvrdenie_akceptacie', 'Potvrdenie akceptácie', 'Acceptance confirmation',
     'Potvrdenie prijatia ponuky «číslo ponuky» – «názov zákazníka»', 'Confirmation of acceptance – offer «číslo ponuky» – «názov zákazníka»',
     $t$«oslovenie»,

ďakujeme, Vaše prijatie cenovej ponuky «číslo ponuky» (variant «variant») sme zaznamenali «dátum akceptácie». Potvrdenie nájdete v prílohe.

V najbližších dňoch Vás budeme kontaktovať s ďalším postupom k uzavretiu zmluvy.

S pozdravom
«podpis»$t$,
     $t$«oslovenie»,

thank you – we have recorded your acceptance of price offer «číslo ponuky» (variant «variant») on «dátum akceptácie». Please find the confirmation attached.

We will contact you shortly about the next steps towards the contract.

Kind regards
«podpis»$t$),
    ('pripomienka_platnosti', 'Pripomienka platnosti', 'Validity reminder',
     'Platnosť cenovej ponuky «číslo ponuky» končí «platnosť»', 'Price offer «číslo ponuky» expires on «platnosť»',
     $t$«oslovenie»,

dovoľujem si Vám pripomenúť, že cenová ponuka «číslo ponuky» platí do «platnosť». Ponuku si môžete pozrieť a prijať na odkaze v pôvodnom e-maile.

V prípade otázok ma neváhajte kontaktovať.

S pozdravom
«podpis»$t$,
     $t$«oslovenie»,

may I remind you that price offer «číslo ponuky» is valid until «platnosť». You can view and accept it using the link in the original e-mail.

If you have any questions, please do not hesitate to contact me.

Kind regards
«podpis»$t$),
    ('volny', 'Voľný e-mail', 'Free e-mail', '', '',
     $t$«oslovenie»,



S pozdravom
«podpis»$t$,
     $t$«oslovenie»,



Kind regards
«podpis»$t$)
   ) c(code, name_sk, name_en, subject_sk, subject_en, body_sk, body_en)
 ) x;


CREATE POLICY email_template_select ON email_template_version FOR SELECT
  USING (crm_active_user_id() IS NOT NULL AND org_id = ANY (crm_user_orgs()));
CREATE POLICY email_template_write ON email_template_version
  USING (crm_email_template_editor() AND org_id = ANY (crm_user_orgs()))
  WITH CHECK (crm_email_template_editor() AND org_id = ANY (crm_user_orgs()));
ALTER TABLE email_template_version ENABLE ROW LEVEL SECURITY;

CREATE POLICY user_photo_select ON user_photo FOR SELECT USING (user_id = crm_active_user_id() OR crm_is_admin());
CREATE POLICY user_photo_write ON user_photo
  USING (user_id = crm_active_user_id() OR crm_is_admin())
  WITH CHECK (user_id = crm_active_user_id() OR crm_is_admin());
ALTER TABLE user_photo ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 3. Vlákna a správy (časť 1.9), denník čítania schránok, stav schránok, fronta interných e-mailov
-- ============================================================================

CREATE TYPE email_status AS ENUM ('koncept', 'v_rade', 'odosiela_sa', 'odoslany', 'chyba', 'prijaty');

-- zoznam adries (iba adresa, bez mena)
CREATE FUNCTION email_addr_list_ok(p jsonb, p_max integer) RETURNS boolean
LANGUAGE sql IMMUTABLE AS $$
  SELECT jsonb_typeof(p) = 'array' AND jsonb_array_length(p) <= p_max
     AND NOT EXISTS (SELECT 1 FROM jsonb_array_elements(p) e
                      WHERE jsonb_typeof(e) <> 'string' OR length(e #>> '{}') > 254
                         OR (e #>> '{}') !~ '^[^@[:space:]<>(),;:"]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
$$;

CREATE TABLE email_thread (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id          uuid NOT NULL REFERENCES org (id),
  mailbox_user_id uuid REFERENCES app_user (id),
  gmail_thread_id text CHECK (gmail_thread_id IS NULL OR gmail_thread_id ~ '^[0-9a-f]{6,32}$'),
  deal_id         uuid REFERENCES deal (id),
  company_id      uuid REFERENCES company (id),
  person_id       uuid REFERENCES contact (id),
  offer_id        uuid REFERENCES offer (id),
  subject         text NOT NULL DEFAULT '',
  watch_until     date,
  last_message_at timestamptz,
  last_checked_at timestamptz,
  created_by      uuid REFERENCES app_user (id),
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  CHECK (deal_id IS NOT NULL OR company_id IS NOT NULL OR person_id IS NOT NULL)
);
COMMENT ON TABLE email_thread IS 'vlákno e-mailov CRM v jednej schránke (mailbox_user_id NULL = crm@greenlogy.com); odpovede sa kontrolujú iba vo vláknach s watch_until ≥ dnes (aktivita za 30 dní) – 0042';
CREATE UNIQUE INDEX email_thread_gmail_key ON email_thread
  (coalesce(mailbox_user_id, '00000000-0000-0000-0000-000000000000'::uuid), gmail_thread_id) WHERE gmail_thread_id IS NOT NULL;
CREATE INDEX email_thread_watch_idx ON email_thread (watch_until) WHERE gmail_thread_id IS NOT NULL AND mailbox_user_id IS NOT NULL;
CREATE INDEX email_thread_deal_idx ON email_thread (deal_id);
CREATE INDEX email_thread_company_idx ON email_thread (company_id);
CREATE INDEX email_thread_person_idx ON email_thread (person_id);
CREATE INDEX email_thread_offer_idx ON email_thread (offer_id);
CREATE TRIGGER trg_audit AFTER INSERT OR UPDATE OR DELETE ON email_thread FOR EACH ROW EXECUTE FUNCTION audit_row();
CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON email_thread FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE email_message (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id             uuid NOT NULL REFERENCES org (id),
  thread_id          uuid NOT NULL REFERENCES email_thread (id),
  direction          text NOT NULL CHECK (direction IN ('odchadzajuca', 'prichadzajuca')),
  status             email_status NOT NULL,
  kind               text NOT NULL CHECK (kind IN ('ponuka', 'potvrdenie_akceptacie', 'pripomienka_platnosti', 'volny', 'odpoved')),
  offer_id           uuid REFERENCES offer (id),
  acceptance_id      uuid REFERENCES offer_acceptance (id),
  template_version_id uuid REFERENCES email_template_version (id),
  from_addr          text,
  from_name          text CHECK (from_name IS NULL OR length(from_name) <= 200),
  reply_to           text,
  to_addrs           jsonb NOT NULL DEFAULT '[]' CHECK (email_addr_list_ok(to_addrs, 100)),
  cc_addrs           jsonb NOT NULL DEFAULT '[]' CHECK (email_addr_list_ok(cc_addrs, 100)),
  subject            text NOT NULL DEFAULT '' CHECK (length(subject) <= 998),
  body_text          text NOT NULL DEFAULT '' CHECK (length(body_text) <= 200000),
  body_html          text CHECK (body_html IS NULL OR length(body_html) <= 500000),
  attachments        jsonb NOT NULL DEFAULT '[]' CHECK (jsonb_typeof(attachments) = 'array'),
  send_key           uuid UNIQUE,
  pending            jsonb,
  sending_started_at timestamptz,
  gmail_message_id   text CHECK (gmail_message_id IS NULL OR gmail_message_id ~ '^[0-9a-f]{6,32}$'),
  rfc_message_id     text CHECK (rfc_message_id IS NULL OR length(rfc_message_id) <= 998),
  sent_at            timestamptz,
  received_at        timestamptz,
  attempts           smallint NOT NULL DEFAULT 0,
  error              text,
  created_by         uuid REFERENCES app_user (id),
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),
  CHECK ((status = 'prijaty') = (direction = 'prichadzajuca')),
  CHECK (status NOT IN ('odoslany', 'prijaty') OR gmail_message_id IS NOT NULL),
  CHECK (status <> 'odosiela_sa' OR send_key IS NOT NULL),
  CHECK (kind <> 'ponuka' OR offer_id IS NOT NULL),
  CHECK (kind <> 'potvrdenie_akceptacie' OR acceptance_id IS NOT NULL),
  CHECK (from_addr IS NULL OR email_addr_list_ok(jsonb_build_array(from_addr), 1)),
  CHECK (reply_to IS NULL OR email_addr_list_ok(jsonb_build_array(reply_to), 1))
);
COMMENT ON TABLE email_message IS 'e-mail CRM: koncept, fronta, odosielanie (send_key, pending), odoslaný (ID z Gmailu) alebo prijatý; obsah sa po odoslaní nemení; bez auditu riadkov (telo e-mailu nejde do audit_log, stav a ID sú v riadku) – 0042';
COMMENT ON COLUMN email_message.pending IS 'odosielaná ponuka: pdf_key, pdf_sha256, link_hash – zapíšu sa k ponuke až po odoslaní (email_send_complete)';
CREATE UNIQUE INDEX email_message_gmail_key ON email_message (thread_id, gmail_message_id) WHERE gmail_message_id IS NOT NULL;
CREATE UNIQUE INDEX email_message_sending_offer_key ON email_message (offer_id) WHERE status = 'odosiela_sa' AND kind = 'ponuka';
CREATE UNIQUE INDEX email_message_reminder_key ON email_message (offer_id) WHERE kind = 'pripomienka_platnosti';
CREATE UNIQUE INDEX email_message_confirmation_key ON email_message (acceptance_id) WHERE kind = 'potvrdenie_akceptacie';
CREATE INDEX email_message_thread_idx ON email_message (thread_id, created_at);
CREATE INDEX email_message_offer_idx ON email_message (offer_id);
CREATE INDEX email_message_work_idx ON email_message (status, sending_started_at) WHERE status IN ('v_rade', 'odosiela_sa');
CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON email_message FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- odoslaný a prijatý e-mail sa nemení; zmazať sa dá iba koncept
CREATE FUNCTION email_message_guard() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF crm_owner_session() THEN
    RETURN coalesce(NEW, OLD);
  END IF;
  IF TG_OP = 'DELETE' THEN
    IF OLD.status <> 'koncept' THEN
      RAISE EXCEPTION 'Zmazať sa dá iba koncept e-mailu.' USING ERRCODE = 'check_violation';
    END IF;
    RETURN OLD;
  END IF;
  IF TG_OP = 'UPDATE' AND OLD.status IN ('odoslany', 'prijaty')
     AND (NEW.status, NEW.subject, NEW.body_text, NEW.body_html, NEW.to_addrs, NEW.cc_addrs, NEW.from_addr, NEW.attachments,
          NEW.gmail_message_id, NEW.sent_at, NEW.received_at, NEW.thread_id)
         IS DISTINCT FROM (OLD.status, OLD.subject, OLD.body_text, OLD.body_html, OLD.to_addrs, OLD.cc_addrs, OLD.from_addr,
                           OLD.attachments, OLD.gmail_message_id, OLD.sent_at, OLD.received_at, OLD.thread_id) THEN
    RAISE EXCEPTION 'Odoslaný alebo prijatý e-mail sa nemení.' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_guard BEFORE UPDATE OR DELETE ON email_message FOR EACH ROW EXECUTE FUNCTION email_message_guard();

-- Denník čítania schránok: iba pridávanie (kto, ktorá schránka, vlákno, správa, metóda, kedy); nemení sa ani nemaže
CREATE TABLE mailbox_access_log (
  id               bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  at               timestamptz NOT NULL DEFAULT now(),
  user_id          uuid REFERENCES app_user (id),
  mailbox_user_id  uuid NOT NULL REFERENCES app_user (id),
  method           text NOT NULL CHECK (method IN ('threads.get', 'messages.get', 'attachments.get')),
  gmail_thread_id  text NOT NULL,
  gmail_message_id text,
  thread_id        uuid NOT NULL REFERENCES email_thread (id)
);
COMMENT ON TABLE mailbox_access_log IS 'každé čítanie schránky cez Gmail API (user_id NULL = beh na pozadí); iba pridávanie – 0042';
CREATE INDEX mailbox_access_log_at_idx ON mailbox_access_log (at);
CREATE INDEX mailbox_access_log_mailbox_idx ON mailbox_access_log (mailbox_user_id, at);

CREATE FUNCTION mailbox_access_log_immutable() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'Denník čítania schránok sa nemení ani nemaže.' USING ERRCODE = 'insufficient_privilege';
END;
$$;
CREATE TRIGGER trg_immutable BEFORE UPDATE OR DELETE ON mailbox_access_log FOR EACH ROW EXECUTE FUNCTION mailbox_access_log_immutable();
CREATE TRIGGER trg_immutable_truncate BEFORE TRUNCATE ON mailbox_access_log FOR EACH STATEMENT EXECUTE FUNCTION mailbox_access_log_immutable();

-- Stav schránok (chyby Gmailu; po 3 chybách za sebou upozornenie adminom)
CREATE TABLE gmail_mailbox_state (
  mailbox            text PRIMARY KEY CHECK (mailbox = 'crm' OR mailbox ~ '^[0-9a-f-]{36}$'),
  consecutive_errors smallint NOT NULL DEFAULT 0,
  last_error         text,
  last_error_at      timestamptz,
  last_ok_at         timestamptz,
  alerted_at         timestamptz,
  updated_at         timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE gmail_mailbox_state IS 'stav schránky pre Gmail API: crm = crm@greenlogy.com, inak ID používateľa – 0042';

-- Fronta interných e-mailov z crm@greenlogy.com (odpoveď 5): nová žiadosť o schválenie, výsledok žiadosti, akceptácia ponuky
CREATE TABLE email_outbox (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  notification_id    uuid UNIQUE REFERENCES notification (id) ON DELETE SET NULL,
  user_id            uuid NOT NULL REFERENCES app_user (id),
  kind               text NOT NULL CHECK (kind IN ('schvalenie_nove', 'schvalenie_rozhodnutie', 'ponuka_akceptovana')),
  deal_id            uuid REFERENCES deal (id),
  approval_id        uuid,
  detail             text,
  status             text NOT NULL DEFAULT 'v_rade' CHECK (status IN ('v_rade', 'odosiela_sa', 'odoslany', 'chyba')),
  send_key           uuid UNIQUE,
  attempts           smallint NOT NULL DEFAULT 0,
  sending_started_at timestamptz,
  gmail_message_id   text CHECK (gmail_message_id IS NULL OR gmail_message_id ~ '^[0-9a-f]{6,32}$'),
  sent_at            timestamptz,
  error              text,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),
  CHECK (status <> 'odosiela_sa' OR send_key IS NOT NULL),
  CHECK (status <> 'odoslany' OR gmail_message_id IS NOT NULL)
);
COMMENT ON TABLE email_outbox IS 'interné e-maily z crm@greenlogy.com podľa upozornení (bez osobných údajov zákazníkov) – 0042';
CREATE INDEX email_outbox_work_idx ON email_outbox (status, created_at) WHERE status IN ('v_rade', 'odosiela_sa');
CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON email_outbox FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- nové druhy upozornení: odpoveď zákazníka, pripomienka platnosti (koncept), chyba schránky, chyba e-mailu
ALTER TABLE notification DROP CONSTRAINT notification_kind_check;
ALTER TABLE notification ADD CONSTRAINT notification_kind_check CHECK (kind IN (
  'konci_4_mesiace', 'sprolongovana', 'neprolongovana', 'pod_hranicou', 'vynimka_nova', 'vynimka_rozhodnutie',
  'nocny_beh_chyba', 'maly_podnik', 'objem_xm', 'dalsi_krok', 'schvalenie_nove', 'schvalenie_rozhodnutie',
  'pridelenie_firmy', 'ponuka_akceptovana', 'ponuka_zablokovana', 'akceptacia_zrusena',
  'ponuka_odpoved', 'ponuka_pripomienka', 'gmail_chyba', 'email_chyba'));

CREATE FUNCTION notification_email_outbox() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  INSERT INTO email_outbox (notification_id, user_id, kind, deal_id, approval_id, detail)
  SELECT NEW.id, NEW.user_id, NEW.kind, NEW.deal_id, NEW.approval_id, NEW.detail
   WHERE EXISTS (SELECT 1 FROM app_user u WHERE u.id = NEW.user_id AND u.status = 'aktivny');
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_email_outbox AFTER INSERT ON notification FOR EACH ROW
  WHEN (NEW.kind IN ('schvalenie_nove', 'schvalenie_rozhodnutie', 'ponuka_akceptovana'))
  EXECUTE FUNCTION notification_email_outbox();

-- ============================================================================
-- 4. Viditeľnosť (RLS): vlákna a správy podľa obchodu / zákazníka a schránky; koncept vidí iba autor;
--    denník čítania, fronta a stav schránok iba admin. Zápis iba cez funkcie.
-- ============================================================================

CREATE FUNCTION email_thread_visible(p_thread uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT EXISTS (
    SELECT 1 FROM email_thread t LEFT JOIN deal d ON d.id = t.deal_id
     WHERE t.id = p_thread AND crm_active_user_id() IS NOT NULL AND t.org_id = ANY (crm_user_orgs())
       AND (crm_is_admin() OR t.mailbox_user_id = crm_active_user_id()
            OR (d.id IS NOT NULL AND crm_deal_visible(d.company_id, d.person_id, d.owner_id))
            OR (t.deal_id IS NULL AND t.company_id IS NOT NULL AND crm_company_access(t.company_id, 'view'))
            OR (t.deal_id IS NULL AND t.company_id IS NULL AND crm_contact_access(t.person_id, 'view'))))
$$;

CREATE FUNCTION email_message_visible(p_thread uuid, p_status email_status, p_created_by uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT email_thread_visible(p_thread)
     AND (p_status <> 'koncept' OR p_created_by = crm_active_user_id()
          OR (p_created_by IS NULL AND EXISTS (SELECT 1 FROM email_thread t WHERE t.id = p_thread
                                                  AND t.mailbox_user_id = crm_active_user_id())))
$$;

CREATE POLICY email_thread_select ON email_thread FOR SELECT USING (email_thread_visible(id));
ALTER TABLE email_thread ENABLE ROW LEVEL SECURITY;
CREATE POLICY email_message_select ON email_message FOR SELECT USING (email_message_visible(thread_id, status, created_by));
ALTER TABLE email_message ENABLE ROW LEVEL SECURITY;
CREATE POLICY mailbox_access_log_select ON mailbox_access_log FOR SELECT USING (crm_is_admin());
ALTER TABLE mailbox_access_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY gmail_mailbox_state_select ON gmail_mailbox_state FOR SELECT USING (crm_is_admin());
ALTER TABLE gmail_mailbox_state ENABLE ROW LEVEL SECURITY;
CREATE POLICY email_outbox_select ON email_outbox FOR SELECT USING (crm_is_admin() OR user_id = crm_active_user_id());
ALTER TABLE email_outbox ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 5. Odoslanie ponuky: kontrola a zápis rozdelené, aby ich použilo aj dokončenie odoslania e-mailom
--    (správanie offer_mark_sent sa nemení)
-- ============================================================================

CREATE FUNCTION offer_send_check(o offer, p_sent_at timestamptz) RETURNS void
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  c     jsonb;
BEGIN
  IF o.status <> 'pripravena' THEN
    RAISE EXCEPTION 'Odoslať sa dá iba pripravená ponuka (nie koncept ani ponuka čakajúca na schválenie).' USING ERRCODE = 'check_violation';
  END IF;
  IF p_sent_at IS NULL OR p_sent_at > now() + interval '5 minutes' OR p_sent_at < o.created_at - interval '1 minute' THEN
    RAISE EXCEPTION 'Čas odoslania musí byť medzi vytvorením verzie a teraz.' USING ERRCODE = 'check_violation';
  END IF;
  c := offer_check(o.id);
  IF jsonb_array_length(c->'errors') > 0 OR jsonb_array_length(c->'needs') > 0 OR (c->>'risk_needs_approval')::boolean THEN
    RAISE EXCEPTION 'Ponuka potrebuje opravu alebo schválenie – pripravte ju znova.' USING ERRCODE = 'check_violation';
  END IF;
  IF EXISTS (SELECT 1 FROM offer_variant x WHERE x.offer_id = o.id AND x.price_kind IN ('fix', 'kombinacia'))
     AND o.priced_on < (p_sent_at AT TIME ZONE 'Europe/Bratislava')::date THEN
    RAISE EXCEPTION 'Ceny pre obchodníka sú z %. FIX ponuku prepočítajte na dnešné ceny.', to_char(o.priced_on, 'DD. MM. YYYY')
      USING ERRCODE = 'check_violation';
  END IF;
END;
$$;

CREATE FUNCTION offer_mark_sent_apply(o offer, p_sent_at timestamptz, p_channel offer_send_channel, p_note text, p_by uuid)
RETURNS timestamptz
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_fix   boolean;
  v_until timestamptz;
  v_stage uuid;
BEGIN
  IF o.status <> 'pripravena' THEN
    RAISE EXCEPTION 'Odoslať sa dá iba pripravená ponuka.' USING ERRCODE = 'check_violation';
  END IF;
  v_fix := EXISTS (SELECT 1 FROM offer_variant x WHERE x.offer_id = o.id AND x.price_kind IN ('fix', 'kombinacia'));
  v_until := offer_default_valid_until(o.org_id, p_sent_at, v_fix);
  UPDATE offer SET status = 'odoslana', sent_at = p_sent_at, sent_by = p_by, sent_channel = p_channel,
                   sent_note = nullif(btrim(p_note), ''), valid_until = v_until
   WHERE id = o.id;
  UPDATE offer SET status = 'nahradena', replaced_by_id = o.id
   WHERE org_id = o.org_id AND number = o.number AND id <> o.id AND status IN ('odoslana', 'otvorena', 'zamietnuta');
  -- obchod iba dopredu: z Príležitosti do Cenovej ponuky
  SELECT s2.id INTO v_stage
    FROM deal d JOIN pipeline_stage s ON s.id = d.stage_id
    JOIN pipeline_stage s2 ON s2.pipeline_id = d.pipeline_id AND s2.code = 'cenova_ponuka'
   WHERE d.id = o.deal_id AND s.code = 'prilezitost';
  IF v_stage IS NOT NULL THEN
    UPDATE deal SET stage_id = v_stage WHERE id = o.deal_id;
  END IF;
  IF v_stage IS NULL AND crm_setting_on('customer_status_auto') THEN
    PERFORM customer_refresh((SELECT company_id FROM deal WHERE id = o.deal_id), (SELECT person_id FROM deal WHERE id = o.deal_id));
  END IF;
  SELECT * INTO o FROM offer WHERE id = o.id;
  INSERT INTO deal_event (deal_id, org_id, kind, user_id, offer_id, detail)
  VALUES (o.deal_id, o.org_id, 'ponuka_odoslana', p_by, o.id,
          jsonb_build_object('number', o.number, 'version', o.version, 'channel', p_channel, 'sent_at', p_sent_at, 'valid_until', v_until));
  RETURN v_until;
END;
$$;

CREATE OR REPLACE FUNCTION offer_mark_sent(p_offer uuid, p_sent_at timestamptz, p_channel offer_send_channel, p_note text)
RETURNS timestamptz
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  o offer := offer_for_edit(p_offer);
BEGIN
  IF p_channel IS NULL THEN
    RAISE EXCEPTION 'Vyberte, ako bola ponuka odoslaná.' USING ERRCODE = 'check_violation';
  END IF;
  IF p_channel = 'crm' THEN
    RAISE EXCEPTION 'Odoslanie e-mailom z CRM zapíše CRM samo.' USING ERRCODE = 'check_violation';
  END IF;
  PERFORM offer_send_check(o, p_sent_at);
  RETURN offer_mark_sent_apply(o, p_sent_at, p_channel, p_note, crm_current_user_id());
END;
$$;

-- Počas odosielania e-mailom sa ponuka (ani jej varianty a položky) nemení – PDF a odkaz zodpovedajú odoslanému
CREATE FUNCTION offer_email_lock() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  r       jsonb := to_jsonb(CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END);
  v_offer uuid;
  v_msg   uuid;
BEGIN
  v_offer := CASE TG_TABLE_NAME WHEN 'offer' THEN (r->>'id')::uuid
                                WHEN 'offer_variant' THEN (r->>'offer_id')::uuid
                                ELSE (SELECT offer_id FROM offer_variant WHERE id = (r->>'variant_id')::uuid) END;
  SELECT id INTO v_msg FROM email_message WHERE offer_id = v_offer AND status = 'odosiela_sa' AND kind = 'ponuka';
  IF v_msg IS NOT NULL AND coalesce(current_setting('crm.email_send', true), '') <> v_msg::text THEN
    RAISE EXCEPTION 'Ponuka sa práve odosiela e-mailom – skúste to o chvíľu.' USING ERRCODE = 'check_violation';
  END IF;
  RETURN coalesce(NEW, OLD);
END;
$$;
CREATE TRIGGER trg_email_lock BEFORE UPDATE OR DELETE ON offer FOR EACH ROW EXECUTE FUNCTION offer_email_lock();
CREATE TRIGGER trg_email_lock BEFORE INSERT OR UPDATE OR DELETE ON offer_variant FOR EACH ROW EXECUTE FUNCTION offer_email_lock();
CREATE TRIGGER trg_email_lock BEFORE INSERT OR UPDATE OR DELETE ON offer_item FOR EACH ROW EXECUTE FUNCTION offer_email_lock();

-- ============================================================================
-- 6. Texty: zhrnutie variantov, premenné ponuky, doplnenie šablóny
-- ============================================================================

-- napr. „FIX na rok 2027 a SPOT + 8,00 €/MWh“ (obchodník ho v e-maile môže upraviť)
CREATE FUNCTION offer_variants_summary_text(p_offer uuid) RETURNS text
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  o     offer;
  v     offer_variant;
  lang  offer_language;
  parts text[] := '{}';
  yrs   integer[];
  ys    text;
  sp    record;
  n     integer;
  t     text;
BEGIN
  SELECT * INTO o FROM offer WHERE id = p_offer;
  lang := o.language;
  FOR v IN SELECT * FROM offer_variant WHERE offer_id = o.id ORDER BY sort_order LOOP
    SELECT array_agg(DISTINCT i.year ORDER BY i.year) INTO yrs
      FROM offer_item i WHERE i.variant_id = v.id AND i.slot = 'komodita' AND i.year IS NOT NULL;
    IF yrs IS NULL THEN
      yrs := ARRAY[extract(year FROM v.supply_from)::int]
             || CASE WHEN v.supply_to IS NOT NULL AND extract(year FROM v.supply_to) > extract(year FROM v.supply_from)
                     THEN ARRAY[extract(year FROM v.supply_to)::int] ELSE '{}'::int[] END;
    END IF;
    ys := CASE WHEN cardinality(yrs) = 1 THEN CASE lang WHEN 'en' THEN ' for ' ELSE ' na rok ' END || yrs[1]
               ELSE CASE lang WHEN 'en' THEN ' for ' ELSE ' na roky ' END || yrs[1] || '–' || yrs[cardinality(yrs)] END;
    t := CASE v.price_kind
           WHEN 'fix' THEN 'FIX' || ys
           WHEN 'kombinacia' THEN CASE lang WHEN 'en' THEN 'FIX and SPOT combination' ELSE 'kombinácia FIX a SPOT' END || ys
           WHEN 'cennik' THEN CASE lang WHEN 'en' THEN 'price list' ELSE 'cenník' END
           WHEN 'viwa' THEN 'Green VIWA' || coalesce(' ' || initcap(v.viwa_package), '')
           ELSE 'SPOT' END;
    IF v.price_kind = 'spot' THEN
      SELECT count(DISTINCT (i.price_model, i.additive_eur_mwh, i.additive_pct)) INTO n
        FROM offer_item i WHERE i.variant_id = v.id AND i.slot = 'komodita';
      IF n = 1 THEN
        SELECT i.price_model, i.additive_eur_mwh AS ad, i.additive_pct AS pct INTO sp
          FROM offer_item i WHERE i.variant_id = v.id AND i.slot = 'komodita' LIMIT 1;
        t := t || CASE sp.price_model
                    WHEN 'spot_plus_eur' THEN ' + ' || offer_fmt_num(sp.ad, 2, lang) || ' €/MWh'
                    WHEN 'spot_minus_eur' THEN ' − ' || offer_fmt_num(sp.ad, 2, lang) || ' €/MWh'
                    WHEN 'spot_minus_pct' THEN ' − ' || offer_fmt_num(sp.pct, 2, lang) || ' %'
                    ELSE '' END;
      END IF;
    END IF;
    parts := parts || t;
  END LOOP;
  n := cardinality(parts);
  RETURN CASE WHEN n = 0 THEN ''
              WHEN n = 1 THEN parts[1]
              ELSE array_to_string(parts[1:n - 1], ', ') || CASE lang WHEN 'en' THEN ' and ' ELSE ' a ' END || parts[n] END;
END;
$$;

CREATE FUNCTION email_fmt_time(p timestamptz, p_lang offer_language) RETURNS text
LANGUAGE sql STABLE AS $$
  SELECT to_char(p AT TIME ZONE 'Europe/Bratislava', CASE p_lang WHEN 'en' THEN 'DD/MM/YYYY, HH24:MI' ELSE 'DD. MM. YYYY, HH24:MI' END)
$$;

-- premenné e-mailu k ponuke (bez «platnosť», «odkaz na ponuku» a «podpis» – tie doplní odoslanie)
CREATE FUNCTION email_offer_vars(p_offer uuid) RETURNS jsonb
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

CREATE FUNCTION email_fill(p_text text, p_vars jsonb) RETURNS text
LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE
  k text;
  v text;
  r text := coalesce(p_text, '');
BEGIN
  FOR k, v IN SELECT key, value FROM jsonb_each_text(coalesce(p_vars, '{}')) LOOP
    r := replace(r, '«' || k || '»', coalesce(v, ''));
  END LOOP;
  RETURN r;
END;
$$;

CREATE FUNCTION email_template_current(p_org uuid, p_code text, p_lang offer_language) RETURNS email_template_version
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT * FROM email_template_version
   WHERE org_id = p_org AND code = p_code AND status = 'platna' AND language IN (p_lang, 'sk')
   ORDER BY (language = p_lang) DESC LIMIT 1
$$;

-- adresát e-mailu k ponuke: adresáti posledného odoslaného e-mailu s ponukou (rovnaké číslo), inak kontaktná osoba ponuky
CREATE FUNCTION email_offer_recipients(p_offer uuid) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT coalesce(
    (SELECT m.to_addrs FROM email_message m JOIN offer x ON x.id = m.offer_id JOIN offer o ON o.id = p_offer
      WHERE x.org_id = o.org_id AND x.number = o.number AND m.kind = 'ponuka' AND m.status = 'odoslany'
      ORDER BY m.sent_at DESC LIMIT 1),
    (SELECT jsonb_build_array(lower(btrim(k.email))) FROM offer o JOIN deal d ON d.id = o.deal_id
       JOIN contact k ON k.id = coalesce(o.contact_id, d.person_id)
      WHERE o.id = p_offer AND email_addr_list_ok(jsonb_build_array(lower(btrim(k.email))), 1)),
    '[]')
$$;

-- vlákno pre e-mail k ponuke v schránke: existujúce vlákno ponuky s rovnakým číslom, inak nové
CREATE FUNCTION email_thread_for_offer(p_offer uuid, p_mailbox uuid, p_subject text, p_by uuid) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  o offer;
  d deal;
  v uuid;
BEGIN
  SELECT * INTO o FROM offer WHERE id = p_offer;
  SELECT * INTO d FROM deal WHERE id = o.deal_id;
  SELECT t.id INTO v FROM email_thread t JOIN offer x ON x.id = t.offer_id
   WHERE x.org_id = o.org_id AND x.number = o.number AND t.mailbox_user_id IS NOT DISTINCT FROM p_mailbox
   ORDER BY (t.gmail_thread_id IS NOT NULL) DESC, t.last_message_at DESC NULLS LAST, t.created_at DESC LIMIT 1;
  IF v IS NULL THEN
    INSERT INTO email_thread (org_id, mailbox_user_id, deal_id, company_id, person_id, offer_id, subject, created_by)
    VALUES (o.org_id, p_mailbox, d.id, d.company_id, d.person_id, o.id, coalesce(p_subject, ''), p_by)
    RETURNING id INTO v;
  ELSE
    UPDATE email_thread SET offer_id = o.id WHERE id = v AND offer_id IS DISTINCT FROM o.id;
  END IF;
  RETURN v;
END;
$$;

-- ============================================================================
-- 7. Koncept e-mailu (obrazovka 37): predvyplnenie, uloženie, zmazanie
-- ============================================================================

-- Predvyplnený e-mail k ponuke: šablóna podľa druhu a jazyka, premenné z ponuky (zhrnutie variantov a oslovenie
-- obchodník upraví), adresát; «platnosť» doplní odoslanie, «odkaz na ponuku» a «podpis» kód pri odoslaní
CREATE FUNCTION email_compose_offer(p_offer uuid, p_code text DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  o    offer := offer_for_edit(p_offer);
  code text := coalesce(p_code, 'ponuka_' || o.kind);
  t    email_template_version;
  vars jsonb := email_offer_vars(p_offer);
BEGIN
  IF code NOT IN ('ponuka_dodavka', 'ponuka_vykup', 'ponuka_viwa', 'pripomienka_platnosti', 'volny') THEN
    RAISE EXCEPTION 'Neznámy druh e-mailu.' USING ERRCODE = 'check_violation';
  END IF;
  t := email_template_current(o.org_id, code, o.language);
  IF t.id IS NULL THEN
    RAISE EXCEPTION 'Šablóna e-mailu ešte nie je schválená – admin alebo Marketing ju zverejní v Nastaveniach → Šablóny e-mailov.'
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN jsonb_build_object(
    'template_version_id', t.id, 'code', code, 'language', t.language,
    'subject', email_fill(t.subject, vars), 'body', email_fill(t.body, vars),
    'to', email_offer_recipients(p_offer), 'vars', vars);
END;
$$;

-- Uloženie konceptu: nový (p_id NULL) alebo zmena vlastného konceptu. p: kind, offer_id | thread_id | deal_id |
-- company_id | person_id, template_version_id, to, cc, subject, body. Koncept je vždy v schránke autora.
CREATE FUNCTION email_draft_save(p_id uuid, p jsonb) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  me     uuid := crm_active_user_id();
  m      email_message;
  t      email_thread;
  o      offer;
  d      deal;
  v_kind text := coalesce(p->>'kind', 'volny');
  v_to   jsonb := coalesce(p->'to', '[]');
  v_cc   jsonb := coalesce(p->'cc', '[]');
  v_th   uuid;
BEGIN
  IF me IS NULL THEN
    RAISE EXCEPTION 'Prihláste sa.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF NOT email_addr_list_ok(v_to, 50) OR NOT email_addr_list_ok(v_cc, 50) THEN
    RAISE EXCEPTION 'Neplatná e-mailová adresa príjemcu.' USING ERRCODE = 'check_violation';
  END IF;
  IF length(coalesce(p->>'subject', '')) > 998 OR length(coalesce(p->>'body', '')) > 200000 THEN
    RAISE EXCEPTION 'Predmet alebo text e-mailu je príliš dlhý.' USING ERRCODE = 'check_violation';
  END IF;
  IF p_id IS NOT NULL THEN
    SELECT m2.* INTO m FROM email_message m2 WHERE m2.id = p_id FOR UPDATE;
    SELECT * INTO t FROM email_thread WHERE id = m.thread_id;
    IF m.id IS NULL OR m.status <> 'koncept'
       OR NOT (m.created_by = me OR (m.created_by IS NULL AND t.mailbox_user_id = me)) THEN
      RAISE EXCEPTION 'Koncept neexistuje alebo nie je váš.' USING ERRCODE = 'insufficient_privilege';
    END IF;
    UPDATE email_message SET to_addrs = v_to, cc_addrs = v_cc, subject = coalesce(p->>'subject', ''),
                             body_text = coalesce(p->>'body', ''), created_by = me, error = NULL
     WHERE id = m.id;
    RETURN m.id;
  END IF;

  IF v_kind NOT IN ('ponuka', 'volny', 'pripomienka_platnosti') THEN
    RAISE EXCEPTION 'Tento druh e-mailu pripravuje CRM samo.' USING ERRCODE = 'check_violation';
  END IF;
  IF p->>'template_version_id' IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM email_template_version WHERE id = (p->>'template_version_id')::uuid AND org_id = ANY (crm_user_orgs())) THEN
    RAISE EXCEPTION 'Neznáma šablóna e-mailu.' USING ERRCODE = 'check_violation';
  END IF;
  IF p->>'offer_id' IS NOT NULL THEN
    o := offer_for_edit((p->>'offer_id')::uuid);
    IF v_kind = 'ponuka' AND o.status <> 'pripravena' THEN
      RAISE EXCEPTION 'E-mailom sa dá odoslať iba pripravená ponuka.' USING ERRCODE = 'check_violation';
    END IF;
    v_th := email_thread_for_offer(o.id, me, p->>'subject', me);
  ELSIF v_kind = 'ponuka' THEN
    RAISE EXCEPTION 'Chýba ponuka.' USING ERRCODE = 'check_violation';
  ELSIF p->>'thread_id' IS NOT NULL THEN
    SELECT * INTO t FROM email_thread WHERE id = (p->>'thread_id')::uuid;
    IF t.id IS NULL OR NOT email_thread_visible(t.id) OR t.mailbox_user_id IS DISTINCT FROM me THEN
      RAISE EXCEPTION 'Odpovedať sa dá iba vo vlákne vlastnej schránky.' USING ERRCODE = 'insufficient_privilege';
    END IF;
    v_th := t.id;
  ELSIF p->>'deal_id' IS NOT NULL THEN
    SELECT * INTO d FROM deal WHERE id = (p->>'deal_id')::uuid;
    IF d.id IS NULL OR NOT (d.org_id = ANY (crm_user_orgs()) AND crm_deal_visible(d.company_id, d.person_id, d.owner_id)) THEN
      RAISE EXCEPTION 'Obchod neexistuje alebo ho nevidíte.' USING ERRCODE = 'insufficient_privilege';
    END IF;
    INSERT INTO email_thread (org_id, mailbox_user_id, deal_id, company_id, person_id, subject, created_by)
    VALUES (d.org_id, me, d.id, d.company_id, d.person_id, coalesce(p->>'subject', ''), me) RETURNING id INTO v_th;
  ELSIF p->>'company_id' IS NOT NULL THEN
    IF NOT crm_company_access((p->>'company_id')::uuid, 'view') THEN
      RAISE EXCEPTION 'Firma neexistuje alebo ju nevidíte.' USING ERRCODE = 'insufficient_privilege';
    END IF;
    INSERT INTO email_thread (org_id, mailbox_user_id, company_id, subject, created_by)
    SELECT c.org_id, me, c.id, coalesce(p->>'subject', ''), me FROM company c WHERE c.id = (p->>'company_id')::uuid
    RETURNING id INTO v_th;
  ELSIF p->>'person_id' IS NOT NULL THEN
    IF NOT crm_contact_access((p->>'person_id')::uuid, 'view') THEN
      RAISE EXCEPTION 'Kontakt neexistuje alebo ho nevidíte.' USING ERRCODE = 'insufficient_privilege';
    END IF;
    INSERT INTO email_thread (org_id, mailbox_user_id, person_id, subject, created_by)
    SELECT k.org_id, me, k.id, coalesce(p->>'subject', ''), me FROM contact k WHERE k.id = (p->>'person_id')::uuid
    RETURNING id INTO v_th;
  ELSE
    RAISE EXCEPTION 'E-mail musí patriť k obchodu, firme alebo kontaktu.' USING ERRCODE = 'check_violation';
  END IF;

  INSERT INTO email_message (org_id, thread_id, direction, status, kind, offer_id, template_version_id, to_addrs, cc_addrs,
                             subject, body_text, created_by)
  SELECT t2.org_id, t2.id, 'odchadzajuca', 'koncept', v_kind, o.id, (p->>'template_version_id')::uuid, v_to, v_cc,
         coalesce(p->>'subject', ''), coalesce(p->>'body', ''), me
    FROM email_thread t2 WHERE t2.id = v_th
  RETURNING id INTO v_th;
  RETURN v_th;
END;
$$;

CREATE FUNCTION email_draft_delete(p_id uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  m email_message;
  t email_thread;
BEGIN
  SELECT * INTO m FROM email_message WHERE id = p_id FOR UPDATE;
  SELECT * INTO t FROM email_thread WHERE id = m.thread_id;
  IF m.id IS NULL OR m.status <> 'koncept' OR crm_active_user_id() IS NULL
     OR NOT (m.created_by = crm_active_user_id() OR (m.created_by IS NULL AND t.mailbox_user_id = crm_active_user_id())) THEN
    RAISE EXCEPTION 'Koncept neexistuje alebo nie je váš.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF m.kind = 'pripomienka_platnosti' THEN
    -- pripomienka sa nepripraví znova (jedna na ponuku): koncept ostane ako vybavený
    UPDATE email_message SET status = 'chyba', error = 'zahodené obchodníkom' WHERE id = m.id;
    RETURN;
  END IF;
  DELETE FROM email_message WHERE id = m.id;
  IF NOT EXISTS (SELECT 1 FROM email_message WHERE thread_id = t.id) THEN
    DELETE FROM email_thread WHERE id = t.id;
  END IF;
END;
$$;

-- ============================================================================
-- 8. Odosielanie (odolné, odpoveď 8): odosiela sa (jednorazový kľúč) → Gmail → ID správy → Odoslaná.
--    Nedokončené dokončí ďalší beh podľa ID správy; bez ID správy sa nikdy neodošle znova (stav Chyba,
--    obchodník skontroluje Odoslané v Gmaile).
-- ============================================================================

CREATE FUNCTION crm_background_only() RETURNS void
LANGUAGE plpgsql STABLE AS $$
BEGIN
  IF crm_current_user_id() IS NOT NULL THEN
    RAISE EXCEPTION 'Iba pre beh na pozadí (bez prihláseného používateľa).' USING ERRCODE = 'insufficient_privilege';
  END IF;
END;
$$;

-- výsledok práce so schránkou (chyby za sebou; po 3 chybách upozornenie adminom, raz do ďalšieho úspechu)
CREATE FUNCTION gmail_mailbox_result(p_mailbox uuid, p_error text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  k text := coalesce(p_mailbox::text, 'crm');
  s gmail_mailbox_state;
BEGIN
  INSERT INTO gmail_mailbox_state (mailbox) VALUES (k) ON CONFLICT (mailbox) DO NOTHING;
  IF p_error IS NULL THEN
    UPDATE gmail_mailbox_state SET consecutive_errors = 0, last_ok_at = now(), alerted_at = NULL, updated_at = now() WHERE mailbox = k;
    RETURN;
  END IF;
  UPDATE gmail_mailbox_state SET consecutive_errors = consecutive_errors + 1, last_error = left(p_error, 500),
                                 last_error_at = now(), updated_at = now()
   WHERE mailbox = k RETURNING * INTO s;
  IF s.consecutive_errors >= 3 AND s.alerted_at IS NULL THEN
    PERFORM notification_add_deal(ARRAY(SELECT id FROM app_user WHERE is_admin AND status = 'aktivny'), 'gmail_chyba', NULL, NULL, NULL,
      'Gmail: schránka ' || coalesce((SELECT email FROM app_user WHERE id = p_mailbox), 'crm@greenlogy.com') || ' – 3 chyby za sebou');
    UPDATE gmail_mailbox_state SET alerted_at = now() WHERE mailbox = k;
  END IF;
END;
$$;

-- údaje na odoslanie (pre kód): schránka, adresy, text so značkami «odkaz na ponuku» a «podpis», vlákno, prílohy
CREATE FUNCTION email_send_payload(p_id uuid) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT jsonb_build_object(
           'id', m.id, 'status', m.status, 'kind', m.kind, 'send_key', m.send_key, 'offer_id', m.offer_id,
           'mailbox_user_id', t.mailbox_user_id, 'mailbox', coalesce(u.email, 'crm@greenlogy.com'),
           'from', m.from_addr, 'from_name', coalesce(u.name, 'Greenlogy'), 'signature_user_id', coalesce(t.mailbox_user_id, m.created_by, (SELECT owner_id FROM deal WHERE id = t.deal_id)),
           'reply_to', m.reply_to, 'to', m.to_addrs, 'cc', m.cc_addrs, 'subject', m.subject, 'body', m.body_text,
           'gmail_thread_id', t.gmail_thread_id, 'gmail_message_id', m.gmail_message_id,
           'references', coalesce((SELECT jsonb_agg(x.rfc_message_id ORDER BY coalesce(x.sent_at, x.received_at))
                                     FROM email_message x WHERE x.thread_id = t.id AND x.id <> m.id AND x.rfc_message_id IS NOT NULL
                                      AND x.status IN ('odoslany', 'prijaty')), '[]'),
           'attachments', m.attachments || CASE WHEN m.pending ? 'pdf_key'
                            THEN jsonb_build_array(jsonb_build_object('kind', 'ponuka', 'key', m.pending->>'pdf_key',
                                   'sha256', m.pending->>'pdf_sha256')) ELSE '[]' END)
    FROM email_message m
    JOIN email_thread t ON t.id = m.thread_id
    LEFT JOIN app_user u ON u.id = t.mailbox_user_id
   WHERE m.id = p_id
$$;

-- Krok 1 (používateľ): koncept → odosiela sa. Pri ponuke kontrola ako pri odoslaní a údaje, ktoré sa k ponuke
-- zapíšu až po odoslaní (PDF už uložené v R2, odtlačok odkazu). Opakované volanie s rovnakým kľúčom vráti stav
-- (fresh = false) – kód potom e-mail znova neodošle.
CREATE FUNCTION email_send_prepare(p_id uuid, p_send_key uuid, p_pdf_key text DEFAULT NULL, p_pdf_sha256 text DEFAULT NULL,
                                   p_link_hash text DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  me      uuid := crm_active_user_id();
  m       email_message;
  t       email_thread;
  u       app_user;
  o       offer;
  tpl     offer_template_version;
  v_until timestamptz;
  pend    jsonb;
BEGIN
  SELECT * INTO m FROM email_message WHERE id = p_id FOR UPDATE;
  SELECT * INTO t FROM email_thread WHERE id = m.thread_id;
  IF m.id IS NULL OR me IS NULL
     OR NOT (m.created_by = me OR (m.created_by IS NULL AND t.mailbox_user_id = me)) OR t.mailbox_user_id IS DISTINCT FROM me THEN
    RAISE EXCEPTION 'E-mail neexistuje alebo nie je váš.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF p_send_key IS NULL THEN
    RAISE EXCEPTION 'Chýba jednorazový kľúč odoslania.' USING ERRCODE = 'check_violation';
  END IF;
  IF m.send_key = p_send_key THEN
    RETURN email_send_payload(m.id) || jsonb_build_object('fresh', false);
  END IF;
  IF m.status <> 'koncept' THEN
    RAISE EXCEPTION 'E-mail už bol odoslaný alebo sa odosiela.' USING ERRCODE = 'check_violation';
  END IF;
  SELECT * INTO u FROM app_user WHERE id = me;
  IF NOT u.gmail_enabled THEN
    RAISE EXCEPTION 'Odosielanie z Gmailu ešte nemáte zapnuté (pilot) – požiadajte admina.' USING ERRCODE = 'check_violation';
  END IF;
  IF jsonb_array_length(m.to_addrs) = 0 THEN
    RAISE EXCEPTION 'Doplňte príjemcu.' USING ERRCODE = 'check_violation';
  END IF;
  IF btrim(m.subject) = '' THEN
    RAISE EXCEPTION 'Doplňte predmet.' USING ERRCODE = 'check_violation';
  END IF;
  IF m.kind = 'ponuka' THEN
    o := offer_for_edit(m.offer_id);
    PERFORM offer_send_check(o, now());
    tpl := offer_template_for(o.id);
    IF tpl.id IS NULL OR tpl.status = 'navrh' THEN
      RAISE EXCEPTION 'Šablóna ponuky (%, %) ešte nie je schválená – admin ju zverejní v Nastaveniach → Šablóny ponúk.',
        o.kind, upper(o.language::text) USING ERRCODE = 'check_violation';
    END IF;
    IF coalesce(p_pdf_key, '') !~ ('^ponuky/' || o.org_id || '/[0-9]{4}/' || o.number || '(-[0-9]+)?\.pdf$') OR coalesce(p_pdf_sha256, '') !~ '^[0-9a-f]{64}$'
       OR coalesce(p_link_hash, '') !~ '^[0-9a-f]{64}$' THEN
      RAISE EXCEPTION 'Chýba PDF ponuky alebo odkaz.' USING ERRCODE = 'check_violation';
    END IF;
    IF position('«odkaz na ponuku»' IN m.body_text) = 0 THEN
      RAISE EXCEPTION 'Text e-mailu musí obsahovať «odkaz na ponuku».' USING ERRCODE = 'check_violation';
    END IF;
    v_until := offer_default_valid_until(o.org_id, now(),
                 EXISTS (SELECT 1 FROM offer_variant x WHERE x.offer_id = o.id AND x.price_kind IN ('fix', 'kombinacia')));
    pend := jsonb_build_object('pdf_key', p_pdf_key, 'pdf_sha256', p_pdf_sha256, 'link_hash', p_link_hash);
  ELSIF m.offer_id IS NOT NULL THEN
    SELECT * INTO o FROM offer WHERE id = m.offer_id;
    v_until := o.valid_until;
  END IF;
  UPDATE email_message
     SET status = 'odosiela_sa', send_key = p_send_key, pending = pend, sending_started_at = now(), attempts = attempts + 1,
         error = NULL, created_by = me, from_addr = lower(u.email),
         subject = CASE WHEN v_until IS NULL THEN subject ELSE email_fill(subject, jsonb_build_object('platnosť', email_fmt_time(v_until, o.language))) END,
         body_text = CASE WHEN v_until IS NULL THEN body_text ELSE email_fill(body_text, jsonb_build_object('platnosť', email_fmt_time(v_until, o.language))) END
   WHERE id = m.id;
  RETURN email_send_payload(m.id) || jsonb_build_object('fresh', true);
END;
$$;

-- kto smie zapísať výsledok odoslania: autor (kód hneď po odoslaní) alebo beh na pozadí
CREATE FUNCTION email_send_caller_ok(m email_message) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT crm_current_user_id() IS NULL OR (m.created_by IS NOT NULL AND m.created_by = crm_active_user_id())
$$;

-- Krok 2: Gmail správu prijal – hneď zapísať ID (malá transakcia). Opakovanie s rovnakým ID nič nezmení.
CREATE FUNCTION email_send_recorded(p_id uuid, p_send_key uuid, p_gmail_message_id text, p_gmail_thread_id text,
                                    p_rfc_message_id text, p_sent_at timestamptz) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  m email_message;
  t email_thread;
  v uuid;
BEGIN
  SELECT * INTO m FROM email_message WHERE id = p_id FOR UPDATE;
  IF m.id IS NULL OR NOT email_send_caller_ok(m) OR m.send_key IS DISTINCT FROM p_send_key THEN
    RAISE EXCEPTION 'E-mail neexistuje alebo nesedí kľúč odoslania.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF m.gmail_message_id IS NOT NULL THEN
    IF m.gmail_message_id = p_gmail_message_id THEN
      RETURN;
    END IF;
    RAISE EXCEPTION 'E-mail už má iné ID správy z Gmailu.' USING ERRCODE = 'check_violation';
  END IF;
  IF m.status <> 'odosiela_sa' THEN
    RAISE EXCEPTION 'E-mail sa neodosiela.' USING ERRCODE = 'check_violation';
  END IF;
  IF coalesce(p_gmail_message_id, '') !~ '^[0-9a-f]{6,32}$' OR coalesce(p_gmail_thread_id, '') !~ '^[0-9a-f]{6,32}$' THEN
    RAISE EXCEPTION 'Neplatné ID správy alebo vlákna z Gmailu.' USING ERRCODE = 'check_violation';
  END IF;
  SELECT * INTO t FROM email_thread WHERE id = m.thread_id FOR UPDATE;
  IF t.gmail_thread_id IS NULL THEN
    UPDATE email_thread SET gmail_thread_id = p_gmail_thread_id WHERE id = t.id;
  ELSIF t.gmail_thread_id <> p_gmail_thread_id THEN
    -- Gmail správu zaradil do iného vlákna: nové vlákno s rovnakými väzbami (odpovede sa sledujú v ňom)
    SELECT id INTO v FROM email_thread
     WHERE mailbox_user_id IS NOT DISTINCT FROM t.mailbox_user_id AND gmail_thread_id = p_gmail_thread_id;
    IF v IS NULL THEN
      INSERT INTO email_thread (org_id, mailbox_user_id, gmail_thread_id, deal_id, company_id, person_id, offer_id, subject, created_by)
      VALUES (t.org_id, t.mailbox_user_id, p_gmail_thread_id, t.deal_id, t.company_id, t.person_id, t.offer_id, m.subject, m.created_by)
      RETURNING id INTO v;
    END IF;
    UPDATE email_message SET thread_id = v WHERE id = m.id;
  END IF;
  UPDATE email_message SET gmail_message_id = p_gmail_message_id, rfc_message_id = nullif(btrim(p_rfc_message_id), ''),
                           sent_at = least(coalesce(p_sent_at, now()), now())
   WHERE id = m.id;
END;
$$;

-- Krok 3: dokončenie – pri ponuke stav Odoslaná (kanál „crm“), PDF, šablóna a odkaz; e-mail Odoslaný; vlákno sa sleduje
-- 30 dní. Opakované volanie nič nezmení. Ak sa ponuka nedá dokončiť (napr. ju medzitým niekto zmenil), e-mail ostane
-- Odoslaný a autor aj admin dostanú upozornenie – e-mail sa nikdy neodošle znova.
CREATE FUNCTION email_send_complete(p_id uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  m     email_message;
  o     offer;
  tpl   offer_template_version;
  v_err text;
  v_prev text;
BEGIN
  SELECT * INTO m FROM email_message WHERE id = p_id FOR UPDATE;
  IF m.id IS NULL OR NOT email_send_caller_ok(m) THEN
    RAISE EXCEPTION 'E-mail neexistuje alebo nie je váš.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF m.status = 'odoslany' THEN
    RETURN jsonb_build_object('status', m.status, 'already', true, 'offer_error', m.error);
  END IF;
  IF m.status <> 'odosiela_sa' OR m.gmail_message_id IS NULL THEN
    RAISE EXCEPTION 'E-mail ešte nemá ID správy z Gmailu.' USING ERRCODE = 'check_violation';
  END IF;
  IF m.kind = 'ponuka' THEN
    BEGIN
      v_prev := set_config('crm.email_send', m.id::text, true);
      SELECT * INTO o FROM offer WHERE id = m.offer_id FOR UPDATE;
      PERFORM offer_mark_sent_apply(o, m.sent_at, 'crm', NULL, m.created_by);
      tpl := offer_template_for(o.id);
      UPDATE offer SET pdf_key = m.pending->>'pdf_key', pdf_sha256 = m.pending->>'pdf_sha256', pdf_generated_at = now(),
                       template_version_id = tpl.id,
                       link_hash = m.pending->>'link_hash', link_created_at = now(), link_created_by = m.created_by
       WHERE id = o.id;
      PERFORM set_config('crm.email_send', '', true);
    EXCEPTION WHEN OTHERS THEN
      v_err := 'E-mail odišiel, ponuku sa nepodarilo označiť ako odoslanú: ' || SQLERRM;
      PERFORM set_config('crm.email_send', '', true);
    END;
  END IF;
  UPDATE email_message SET status = 'odoslany', error = v_err WHERE id = m.id;
  UPDATE email_thread SET last_message_at = greatest(last_message_at, m.sent_at),
                          watch_until = greatest(watch_until, (m.sent_at AT TIME ZONE 'Europe/Bratislava')::date + 30)
   WHERE id = (SELECT thread_id FROM email_message WHERE id = m.id);
  PERFORM gmail_mailbox_result((SELECT mailbox_user_id FROM email_thread t JOIN email_message x ON x.thread_id = t.id WHERE x.id = m.id), NULL);
  IF v_err IS NOT NULL THEN
    PERFORM notification_add_deal(ARRAY(SELECT id FROM app_user WHERE (is_admin AND status = 'aktivny') OR id = m.created_by),
      'email_chyba', (SELECT deal_id FROM offer WHERE id = m.offer_id), NULL, NULL,
      'E-mail s ponukou ' || coalesce((SELECT offer_display_number(x) FROM offer x WHERE x.id = m.offer_id), '') ||
      ' odišiel, ponuka sa neoznačila ako odoslaná – skontrolujte ju');
  END IF;
  RETURN jsonb_build_object('status', 'odoslany', 'already', false, 'offer_error', v_err);
END;
$$;

-- Gmail e-mail odmietol (správa určite neodišla, nemá ID): koncept s chybou; z fronty ďalší pokus (najviac 3)
CREATE FUNCTION email_send_failed(p_id uuid, p_send_key uuid, p_error text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  m email_message;
BEGIN
  SELECT * INTO m FROM email_message WHERE id = p_id FOR UPDATE;
  IF m.id IS NULL OR NOT email_send_caller_ok(m) OR m.send_key IS DISTINCT FROM p_send_key THEN
    RAISE EXCEPTION 'E-mail neexistuje alebo nesedí kľúč odoslania.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF m.status <> 'odosiela_sa' OR m.gmail_message_id IS NOT NULL THEN
    RAISE EXCEPTION 'E-mail už odišiel alebo sa neodosiela.' USING ERRCODE = 'check_violation';
  END IF;
  UPDATE email_message
     SET status = CASE WHEN m.created_by IS NOT NULL THEN 'koncept'
                       WHEN m.attempts >= 3 THEN 'chyba' ELSE 'v_rade' END::email_status,
         send_key = NULL, pending = NULL, sending_started_at = NULL, error = left(coalesce(p_error, 'Gmail e-mail odmietol.'), 500)
   WHERE id = m.id;
  PERFORM gmail_mailbox_result((SELECT mailbox_user_id FROM email_thread WHERE id = m.thread_id), coalesce(p_error, 'odmietnuté'));
  IF m.created_by IS NULL AND m.attempts >= 3 THEN
    PERFORM notification_add_deal(ARRAY(SELECT id FROM app_user WHERE is_admin AND status = 'aktivny'), 'email_chyba',
      (SELECT deal_id FROM email_thread WHERE id = m.thread_id), NULL, NULL, 'E-mail z fronty sa nepodarilo odoslať (3 pokusy)');
  END IF;
END;
$$;

-- Po kontrole Odoslaných v Gmaile: e-mail v stave Chyba späť do konceptu (autor) alebo do fronty (admin)
CREATE FUNCTION email_retry(p_id uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  m email_message;
BEGIN
  SELECT * INTO m FROM email_message WHERE id = p_id FOR UPDATE;
  IF m.id IS NULL OR crm_active_user_id() IS NULL OR NOT email_message_visible(m.thread_id, m.status, m.created_by)
     OR NOT (m.created_by = crm_active_user_id() OR (m.created_by IS NULL AND crm_is_admin())) THEN
    RAISE EXCEPTION 'E-mail neexistuje alebo nie je váš.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF m.status <> 'chyba' OR m.gmail_message_id IS NOT NULL OR m.kind = 'pripomienka_platnosti' AND m.error = 'zahodené obchodníkom' THEN
    RAISE EXCEPTION 'Znova sa dá pripraviť iba e-mail v stave Chyba.' USING ERRCODE = 'check_violation';
  END IF;
  UPDATE email_message SET status = CASE WHEN m.created_by IS NULL THEN 'v_rade' ELSE 'koncept' END::email_status,
                           attempts = 0, send_key = NULL, pending = NULL, sending_started_at = NULL, error = NULL
   WHERE id = m.id;
END;
$$;

-- ============================================================================
-- 9. Beh na pozadí (Cron */5): fronta, dokončenie nedokončených, sledované vlákna, prijaté správy
-- ============================================================================

-- Nedokončené odoslania: s ID z Gmailu dokončí; bez ID po 15 minútach Chyba (nikdy neodošle znova)
CREATE FUNCTION email_pending_recover() RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  r       record;
  v_done  integer := 0;
  v_fail  integer := 0;
  v_out   integer := 0;
BEGIN
  PERFORM crm_background_only();
  FOR r IN SELECT id FROM email_message WHERE status = 'odosiela_sa' AND gmail_message_id IS NOT NULL ORDER BY sending_started_at LOOP
    PERFORM email_send_complete(r.id);
    v_done := v_done + 1;
  END LOOP;
  FOR r IN SELECT m.id, m.created_by, m.offer_id, t.deal_id FROM email_message m JOIN email_thread t ON t.id = m.thread_id
            WHERE m.status = 'odosiela_sa' AND m.gmail_message_id IS NULL AND m.sending_started_at < now() - interval '15 minutes'
            ORDER BY m.sending_started_at LOOP
    UPDATE email_message SET status = 'chyba', pending = NULL,
           error = 'Nie je isté, či e-mail odišiel – skontrolujte Odoslané v Gmaile; ak tam nie je, pripravte ho znova.'
     WHERE id = r.id;
    PERFORM notification_add_deal(CASE WHEN r.created_by IS NOT NULL THEN ARRAY[r.created_by]
                                       ELSE ARRAY(SELECT id FROM app_user WHERE is_admin AND status = 'aktivny') END,
      'email_chyba', r.deal_id, NULL, NULL, 'Nie je isté, či e-mail odišiel – skontrolujte Odoslané v Gmaile');
    v_fail := v_fail + 1;
  END LOOP;
  UPDATE email_outbox SET status = 'odoslany' WHERE status = 'odosiela_sa' AND gmail_message_id IS NOT NULL;
  UPDATE email_outbox SET status = 'chyba', error = 'Nie je isté, či e-mail odišiel (bez ID z Gmailu) – neodošle sa znova.'
   WHERE status = 'odosiela_sa' AND gmail_message_id IS NULL AND sending_started_at < now() - interval '15 minutes';
  GET DIAGNOSTICS v_out = ROW_COUNT;
  RETURN jsonb_build_object('dokoncene', v_done, 'neiste', v_fail, 'interne_neiste', v_out);
END;
$$;

-- E-maily z fronty (potvrdenie akceptácie zákazníkovi): prevzatie s jednorazovým kľúčom → payload na odoslanie
CREATE FUNCTION email_queue_claim(p_limit integer DEFAULT 10) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  r   record;
  res jsonb := '[]';
BEGIN
  PERFORM crm_background_only();
  FOR r IN SELECT m.id, m.acceptance_id, t.mailbox_user_id FROM email_message m JOIN email_thread t ON t.id = m.thread_id
            WHERE m.status = 'v_rade' ORDER BY m.created_at LIMIT greatest(least(p_limit, 50), 1)
            FOR UPDATE OF m SKIP LOCKED LOOP
    IF r.acceptance_id IS NOT NULL AND EXISTS (SELECT 1 FROM offer_acceptance a WHERE a.id = r.acceptance_id AND a.revoked_at IS NOT NULL) THEN
      UPDATE email_message SET status = 'chyba', error = 'Akceptácia bola zrušená – potvrdenie sa neodoslalo.' WHERE id = r.id;
      CONTINUE;
    END IF;
    IF r.mailbox_user_id IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM app_user u WHERE u.id = r.mailbox_user_id AND u.status = 'aktivny' AND u.gmail_enabled) THEN
      UPDATE email_message SET status = 'chyba', error = 'Schránka obchodníka nemá zapnutý Gmail – e-mail sa neodoslal.' WHERE id = r.id;
      PERFORM notification_add_deal(ARRAY(SELECT id FROM app_user WHERE is_admin AND status = 'aktivny'), 'email_chyba',
        (SELECT deal_id FROM email_thread t JOIN email_message x ON x.thread_id = t.id WHERE x.id = r.id), NULL, NULL,
        'E-mail z fronty: schránka obchodníka nemá zapnutý Gmail');
      CONTINUE;
    END IF;
    UPDATE email_message SET status = 'odosiela_sa', send_key = gen_random_uuid(), sending_started_at = now(), attempts = attempts + 1
     WHERE id = r.id;
    res := res || jsonb_build_array(email_send_payload(r.id));
  END LOOP;
  RETURN res;
END;
$$;

CREATE FUNCTION email_outbox_claim(p_limit integer DEFAULT 20) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  res jsonb;
BEGIN
  PERFORM crm_background_only();
  WITH c AS (
    SELECT id FROM email_outbox WHERE status = 'v_rade' ORDER BY created_at LIMIT greatest(least(p_limit, 50), 1) FOR UPDATE SKIP LOCKED
  ), u AS (
    UPDATE email_outbox x SET status = 'odosiela_sa', send_key = gen_random_uuid(), sending_started_at = now(), attempts = attempts + 1
      FROM c WHERE x.id = c.id RETURNING x.*
  )
  SELECT coalesce(jsonb_agg(jsonb_build_object('id', u.id, 'send_key', u.send_key, 'kind', u.kind, 'to', a.email, 'name', a.name,
                                               'deal_id', u.deal_id, 'approval_id', u.approval_id, 'detail', u.detail)
                            ORDER BY u.created_at), '[]')
    INTO res
    FROM u JOIN app_user a ON a.id = u.user_id;
  RETURN res;
END;
$$;

CREATE FUNCTION email_outbox_result(p_id uuid, p_send_key uuid, p_gmail_message_id text, p_error text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  x email_outbox;
BEGIN
  PERFORM crm_background_only();
  SELECT * INTO x FROM email_outbox WHERE id = p_id FOR UPDATE;
  IF x.id IS NULL OR x.send_key IS DISTINCT FROM p_send_key OR x.status <> 'odosiela_sa' THEN
    RETURN;
  END IF;
  IF p_gmail_message_id IS NOT NULL THEN
    IF p_gmail_message_id !~ '^[0-9a-f]{6,32}$' THEN
      RAISE EXCEPTION 'Neplatné ID správy z Gmailu.' USING ERRCODE = 'check_violation';
    END IF;
    UPDATE email_outbox SET status = 'odoslany', gmail_message_id = p_gmail_message_id, sent_at = now(), error = NULL WHERE id = x.id;
    PERFORM gmail_mailbox_result(NULL, NULL);
  ELSE
    UPDATE email_outbox SET status = CASE WHEN x.attempts >= 3 THEN 'chyba' ELSE 'v_rade' END, send_key = NULL,
                            sending_started_at = NULL, error = left(coalesce(p_error, 'Gmail e-mail odmietol.'), 500)
     WHERE id = x.id;
    PERFORM gmail_mailbox_result(NULL, coalesce(p_error, 'odmietnuté'));
  END IF;
END;
$$;

-- JEDINÁ kontrola pred čítaním Gmailu (gmailRead): iba threads.get / messages.get / attachments.get, iba vlákno CRM v danej
-- schránke; beh na pozadí iba threads.get sledovaného vlákna (aktivita za 30 dní), používateľ iba známu správu vo vlákne,
-- ktoré vidí (príloha). Každé povolené čítanie sa zapíše do denníka; schránka crm@ sa nečíta.
CREATE FUNCTION gmail_read_authorize(p_mailbox uuid, p_gmail_thread_id text, p_gmail_message_id text, p_method text) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  t email_thread;
BEGIN
  IF p_method IS NULL OR p_method NOT IN ('threads.get', 'messages.get', 'attachments.get') THEN
    RAISE EXCEPTION 'Gmail: povolené je iba threads.get, messages.get a attachments.get.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF p_mailbox IS NULL THEN
    RAISE EXCEPTION 'Schránka crm@greenlogy.com sa nečíta.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  SELECT * INTO t FROM email_thread WHERE mailbox_user_id = p_mailbox AND gmail_thread_id = p_gmail_thread_id;
  IF t.id IS NULL THEN
    RAISE EXCEPTION 'Vlákno nepatrí CRM alebo tejto schránke.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM app_user u WHERE u.id = p_mailbox AND u.status = 'aktivny' AND u.gmail_enabled) THEN
    RAISE EXCEPTION 'Schránka nemá zapnutý Gmail.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF crm_current_user_id() IS NULL THEN
    IF p_method <> 'threads.get' OR p_gmail_message_id IS NOT NULL OR coalesce(t.watch_until, '-infinity') < crm_today() THEN
      RAISE EXCEPTION 'Beh na pozadí číta iba sledované vlákna (threads.get).' USING ERRCODE = 'insufficient_privilege';
    END IF;
  ELSE
    IF p_method = 'threads.get' OR NOT email_thread_visible(t.id)
       OR NOT EXISTS (SELECT 1 FROM email_message m WHERE m.thread_id = t.id AND m.gmail_message_id = p_gmail_message_id) THEN
      RAISE EXCEPTION 'Správa nepatrí vláknu, ktoré vidíte.' USING ERRCODE = 'insufficient_privilege';
    END IF;
  END IF;
  INSERT INTO mailbox_access_log (user_id, mailbox_user_id, method, gmail_thread_id, gmail_message_id, thread_id)
  VALUES (crm_active_user_id(), p_mailbox, p_method, p_gmail_thread_id, p_gmail_message_id, t.id);
  RETURN t.id;
END;
$$;

-- Vlákna na kontrolu odpovedí: sledované (watch_until ≥ dnes), schránka so zapnutým Gmailom, najdlhšie nekontrolované
CREATE FUNCTION email_watch_threads(p_limit integer DEFAULT 50) RETURNS jsonb
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

-- Výsledok kontroly vlákna: ok / chyba (počíta sa do stavu schránky) / nenajdene (vlákno zmazané – prestane sa sledovať)
CREATE FUNCTION email_thread_checked(p_thread uuid, p_result text, p_error text DEFAULT NULL) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  t email_thread;
BEGIN
  PERFORM crm_background_only();
  IF p_result NOT IN ('ok', 'chyba', 'nenajdene') THEN
    RAISE EXCEPTION 'Neznámy výsledok kontroly.' USING ERRCODE = 'check_violation';
  END IF;
  UPDATE email_thread SET last_checked_at = now(), watch_until = CASE WHEN p_result = 'nenajdene' THEN NULL ELSE watch_until END
   WHERE id = p_thread RETURNING * INTO t;
  IF t.id IS NOT NULL AND p_result <> 'nenajdene' THEN
    PERFORM gmail_mailbox_result(t.mailbox_user_id, CASE WHEN p_result = 'chyba' THEN coalesce(p_error, 'chyba') END);
  END IF;
END;
$$;

-- Nová správa vo vlákne (zistená cez threads.get): uloží sa raz (podľa ID z Gmailu); prichádzajúca predĺži sledovanie
-- o 30 dní a upozorní vlastníka schránky. p: gmail_message_id, rfc_message_id, direction, from, from_name, to, cc,
-- subject, body_text, body_html (vyčistené kódom), attachments (iba zoznam), at.
CREATE FUNCTION email_message_received(p_thread uuid, p jsonb) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  t     email_thread;
  v     uuid;
  v_in  boolean := coalesce(p->>'direction', 'prichadzajuca') = 'prichadzajuca';
  v_at  timestamptz := least(coalesce((p->>'at')::timestamptz, now()), now());
BEGIN
  PERFORM crm_background_only();
  SELECT * INTO t FROM email_thread WHERE id = p_thread FOR UPDATE;
  IF t.id IS NULL OR t.gmail_thread_id IS NULL THEN
    RAISE EXCEPTION 'Neznáme vlákno.' USING ERRCODE = 'check_violation';
  END IF;
  SELECT id INTO v FROM email_message WHERE thread_id = t.id AND gmail_message_id = p->>'gmail_message_id';
  IF v IS NOT NULL THEN
    RETURN v;
  END IF;
  INSERT INTO email_message (org_id, thread_id, direction, status, kind, offer_id, from_addr, from_name, to_addrs, cc_addrs,
                             subject, body_text, body_html, attachments, gmail_message_id, rfc_message_id, sent_at, received_at)
  VALUES (t.org_id, t.id, CASE WHEN v_in THEN 'prichadzajuca' ELSE 'odchadzajuca' END,
          CASE WHEN v_in THEN 'prijaty' ELSE 'odoslany' END::email_status, CASE WHEN v_in THEN 'odpoved' ELSE 'volny' END,
          t.offer_id, lower(nullif(btrim(p->>'from'), '')), left(nullif(btrim(p->>'from_name'), ''), 200),
          coalesce(p->'to', '[]'), coalesce(p->'cc', '[]'), left(coalesce(p->>'subject', ''), 998),
          left(coalesce(p->>'body_text', ''), 200000), p->>'body_html', coalesce(p->'attachments', '[]'),
          p->>'gmail_message_id', left(nullif(btrim(p->>'rfc_message_id'), ''), 998),
          CASE WHEN NOT v_in THEN v_at END, CASE WHEN v_in THEN v_at END)
  RETURNING id INTO v;
  UPDATE email_thread SET last_message_at = greatest(last_message_at, v_at),
                          watch_until = CASE WHEN v_in THEN greatest(watch_until, (v_at AT TIME ZONE 'Europe/Bratislava')::date + 30)
                                             ELSE watch_until END
   WHERE id = t.id;
  IF v_in THEN
    PERFORM notification_add_deal(ARRAY[t.mailbox_user_id], 'ponuka_odpoved', t.deal_id, NULL, NULL,
      'Odpoveď na e-mail' || coalesce(' k ponuke ' || (SELECT offer_display_number(x) FROM offer x WHERE x.id = t.offer_id), ''));
  END IF;
  RETURN v;
END;
$$;

-- ============================================================================
-- 10. Potvrdenie akceptácie zákazníkovi (odpoveď 4): do fronty po uložení PDF potvrdenia – so zapnutým Gmailom
--     zo schránky obchodníka do vlákna ponuky, inak z crm@greenlogy.com s Reply-To na obchodníka
-- ============================================================================

CREATE FUNCTION email_confirmation_queue(p_acceptance uuid) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  a      offer_acceptance;
  o      offer;
  d      deal;
  u      app_user;
  tpl    email_template_version;
  vars   jsonb;
  v_to   jsonb;
  v_box  uuid;
  v_th   uuid;
  v      uuid;
BEGIN
  SELECT * INTO a FROM offer_acceptance WHERE id = p_acceptance;
  IF a.id IS NULL OR a.confirmation_pdf_key IS NULL OR a.revoked_at IS NOT NULL
     OR EXISTS (SELECT 1 FROM email_message WHERE acceptance_id = a.id AND kind = 'potvrdenie_akceptacie') THEN
    RETURN NULL;
  END IF;
  SELECT * INTO o FROM offer WHERE id = a.offer_id;
  SELECT * INTO d FROM deal WHERE id = o.deal_id;
  SELECT * INTO u FROM app_user WHERE id = d.owner_id;
  v_to := email_offer_recipients(o.id);
  tpl := email_template_current(o.org_id, 'potvrdenie_akceptacie', o.language);
  IF jsonb_array_length(v_to) = 0 OR tpl.id IS NULL THEN
    RETURN NULL;
  END IF;
  v_box := CASE WHEN u.status = 'aktivny' AND u.gmail_enabled THEN u.id END;
  vars := email_offer_vars(o.id) || jsonb_build_object(
            'variant', (SELECT name FROM offer_variant WHERE id = a.variant_id),
            'dátum akceptácie', email_fmt_time(a.accepted_at, o.language));
  v_th := email_thread_for_offer(o.id, v_box, email_fill(tpl.subject, vars), NULL);
  INSERT INTO email_message (org_id, thread_id, direction, status, kind, offer_id, acceptance_id, template_version_id,
                             from_addr, reply_to, to_addrs, subject, body_text, attachments)
  VALUES (o.org_id, v_th, 'odchadzajuca', 'v_rade', 'potvrdenie_akceptacie', o.id, a.id, tpl.id,
          CASE WHEN v_box IS NOT NULL THEN lower(u.email) ELSE 'crm@greenlogy.com' END,
          CASE WHEN v_box IS NULL AND u.status = 'aktivny' THEN lower(u.email) END,
          v_to, email_fill(tpl.subject, vars), email_fill(tpl.body, vars),
          jsonb_build_array(jsonb_build_object('kind', 'potvrdenie', 'key', a.confirmation_pdf_key, 'sha256', a.confirmation_pdf_sha256)))
  RETURNING id INTO v;
  RETURN v;
END;
$$;

CREATE FUNCTION offer_acceptance_email() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  PERFORM email_confirmation_queue(NEW.id);
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_email_confirmation AFTER INSERT OR UPDATE OF confirmation_pdf_key ON offer_acceptance FOR EACH ROW
  WHEN (NEW.confirmation_pdf_key IS NOT NULL) EXECUTE FUNCTION offer_acceptance_email();

-- ============================================================================
-- 11. Nočný beh obchodov: koncept pripomienky platnosti 2 pracovné dni pred koncom, iba SPOT a VIWA (odpoveď 3);
--     odošle ho obchodník jedným klikom. Raz na ponuku (dobieha, kým ponuka platí).
-- ============================================================================

CREATE FUNCTION email_reminder_draft(p_offer uuid) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  o    offer;
  d    deal;
  tpl  email_template_version;
  vars jsonb;
  v_th uuid;
  v    uuid;
BEGIN
  SELECT * INTO o FROM offer WHERE id = p_offer;
  SELECT * INTO d FROM deal WHERE id = o.deal_id;
  tpl := email_template_current(o.org_id, 'pripomienka_platnosti', o.language);
  IF tpl.id IS NULL OR EXISTS (SELECT 1 FROM email_message WHERE offer_id = o.id AND kind = 'pripomienka_platnosti') THEN
    RETURN NULL;
  END IF;
  vars := email_offer_vars(o.id) || jsonb_build_object('platnosť', email_fmt_time(o.valid_until, o.language));
  v_th := email_thread_for_offer(o.id, d.owner_id, email_fill(tpl.subject, vars), NULL);
  INSERT INTO email_message (org_id, thread_id, direction, status, kind, offer_id, template_version_id, to_addrs, subject, body_text)
  VALUES (o.org_id, v_th, 'odchadzajuca', 'koncept', 'pripomienka_platnosti', o.id, tpl.id, email_offer_recipients(o.id),
          email_fill(tpl.subject, vars), email_fill(tpl.body, vars))
  RETURNING id INTO v;
  PERFORM notification_add_deal(ARRAY[d.owner_id], 'ponuka_pripomienka', d.id, NULL, (o.valid_until AT TIME ZONE 'Europe/Bratislava')::date,
    'Pripomienka platnosti ponuky ' || offer_display_number(o) || ' – koncept e-mailu je pripravený');
  RETURN v;
END;
$$;

CREATE OR REPLACE FUNCTION deal_daily_run_at(p_today date) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_run  uuid;
  v_n    integer := 0;
  v_rem  integer := 0;
  v_prev text := crm_as_system(true);
  r      record;
BEGIN
  INSERT INTO job_run (job, run_date, test_date) VALUES ('obchody', p_today, p_today <> (now() AT TIME ZONE 'Europe/Bratislava')::date)
  RETURNING id INTO v_run;
  -- deň kroku (dobieha 7 dní, keby beh vypadol); raz pre každý dátum kroku
  FOR r IN
    SELECT d.id, d.owner_id, d.next_step_on FROM deal d
     WHERE d.closed_at IS NULL AND d.next_step_on BETWEEN p_today - 7 AND p_today
       AND d.next_step_notified_on IS DISTINCT FROM d.next_step_on
     ORDER BY d.id
  LOOP
    PERFORM notification_add_deal(ARRAY[r.owner_id], 'dalsi_krok', r.id, NULL, r.next_step_on, 'Ďalší krok obchodu');
    UPDATE deal SET next_step_notified_on = r.next_step_on WHERE id = r.id;
    v_n := v_n + 1;
  END LOOP;
  -- pripomienka platnosti: odoslaná / otvorená ponuka bez FIX (SPOT, VIWA), od 2. pracovného dňa pred koncom platnosti
  FOR r IN
    SELECT o.id FROM offer o
     WHERE o.status IN ('odoslana', 'otvorena') AND o.valid_until IS NOT NULL
       AND (o.valid_until AT TIME ZONE 'Europe/Bratislava')::date > p_today
       AND p_today >= working_days_before(o.org_id, (o.valid_until AT TIME ZONE 'Europe/Bratislava')::date, 2)
       AND NOT EXISTS (SELECT 1 FROM offer_variant x WHERE x.offer_id = o.id AND x.price_kind IN ('fix', 'kombinacia', 'cennik'))
       AND EXISTS (SELECT 1 FROM offer_variant x WHERE x.offer_id = o.id AND x.price_kind IN ('spot', 'viwa'))
       AND NOT EXISTS (SELECT 1 FROM email_message m WHERE m.offer_id = o.id AND m.kind = 'pripomienka_platnosti')
     ORDER BY o.id
  LOOP
    IF email_reminder_draft(r.id) IS NOT NULL THEN
      v_rem := v_rem + 1;
    END IF;
  END LOOP;
  UPDATE job_run SET finished_at = now(), result = jsonb_build_object('dalsi_krok', v_n, 'pripomienky', v_rem) WHERE id = v_run;
  PERFORM set_config('app.change_source', v_prev, true);
  RETURN jsonb_build_object('dalsi_krok', v_n, 'pripomienky', v_rem);
END;
$$;

-- ============================================================================
-- 12. Práva funkcií: interné nie sú pre PUBLIC ani aplikáciu (predvolené práva 0040); funkcie behu na pozadí aplikácia
--     smie volať, ale iba bez prihláseného používateľa (crm_background_only)
-- ============================================================================

REVOKE EXECUTE ON FUNCTION user_photo_guard(), email_template_guard(), email_message_guard(), mailbox_access_log_immutable(),
  notification_email_outbox(), offer_email_lock(), offer_acceptance_email(),
  offer_send_check(offer, timestamptz), offer_mark_sent_apply(offer, timestamptz, offer_send_channel, text, uuid),
  offer_variants_summary_text(uuid), email_offer_vars(uuid), email_template_current(uuid, text, offer_language),
  email_offer_recipients(uuid), email_thread_for_offer(uuid, uuid, text, uuid), gmail_mailbox_result(uuid, text),
  email_send_payload(uuid), email_send_caller_ok(email_message), email_confirmation_queue(uuid), email_reminder_draft(uuid)
  FROM PUBLIC;
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'crm_app') THEN
    REVOKE EXECUTE ON FUNCTION user_photo_guard(), email_template_guard(), email_message_guard(), mailbox_access_log_immutable(),
      notification_email_outbox(), offer_email_lock(), offer_acceptance_email(),
      offer_send_check(offer, timestamptz), offer_mark_sent_apply(offer, timestamptz, offer_send_channel, text, uuid),
      offer_variants_summary_text(uuid), email_offer_vars(uuid), email_template_current(uuid, text, offer_language),
      email_offer_recipients(uuid), email_thread_for_offer(uuid, uuid, text, uuid), gmail_mailbox_result(uuid, text),
      email_send_payload(uuid), email_send_caller_ok(email_message), email_confirmation_queue(uuid), email_reminder_draft(uuid)
      FROM crm_app;
  END IF;
END;
$$;

-- migrate:down

DROP TRIGGER trg_email_confirmation ON offer_acceptance;
DROP TRIGGER trg_email_lock ON offer;
DROP TRIGGER trg_email_lock ON offer_variant;
DROP TRIGGER trg_email_lock ON offer_item;
DROP TRIGGER trg_email_outbox ON notification;

CREATE OR REPLACE FUNCTION deal_daily_run_at(p_today date) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_run  uuid;
  v_n    integer := 0;
  v_prev text := crm_as_system(true);
  r      record;
BEGIN
  INSERT INTO job_run (job, run_date, test_date) VALUES ('obchody', p_today, p_today <> (now() AT TIME ZONE 'Europe/Bratislava')::date)
  RETURNING id INTO v_run;
  -- deň kroku (dobieha 7 dní, keby beh vypadol); raz pre každý dátum kroku
  FOR r IN
    SELECT d.id, d.owner_id, d.next_step_on FROM deal d
     WHERE d.closed_at IS NULL AND d.next_step_on BETWEEN p_today - 7 AND p_today
       AND d.next_step_notified_on IS DISTINCT FROM d.next_step_on
     ORDER BY d.id
  LOOP
    PERFORM notification_add_deal(ARRAY[r.owner_id], 'dalsi_krok', r.id, NULL, r.next_step_on, 'Ďalší krok obchodu');
    UPDATE deal SET next_step_notified_on = r.next_step_on WHERE id = r.id;
    v_n := v_n + 1;
  END LOOP;
  UPDATE job_run SET finished_at = now(), result = jsonb_build_object('dalsi_krok', v_n) WHERE id = v_run;
  PERFORM set_config('app.change_source', v_prev, true);
  RETURN jsonb_build_object('dalsi_krok', v_n);
END;
$$;

CREATE OR REPLACE FUNCTION offer_mark_sent(p_offer uuid, p_sent_at timestamptz, p_channel offer_send_channel, p_note text)
RETURNS timestamptz
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  o       offer := offer_for_edit(p_offer);
  c       jsonb;
  v_fix   boolean;
  v_until timestamptz;
  v_stage uuid;
BEGIN
  IF o.status <> 'pripravena' THEN
    RAISE EXCEPTION 'Odoslať sa dá iba pripravená ponuka (nie koncept ani ponuka čakajúca na schválenie).' USING ERRCODE = 'check_violation';
  END IF;
  IF p_sent_at IS NULL OR p_sent_at > now() + interval '5 minutes' OR p_sent_at < o.created_at - interval '1 minute' THEN
    RAISE EXCEPTION 'Čas odoslania musí byť medzi vytvorením verzie a teraz.' USING ERRCODE = 'check_violation';
  END IF;
  IF p_channel IS NULL THEN
    RAISE EXCEPTION 'Vyberte, ako bola ponuka odoslaná.' USING ERRCODE = 'check_violation';
  END IF;
  c := offer_check(o.id);
  IF jsonb_array_length(c->'errors') > 0 OR jsonb_array_length(c->'needs') > 0 OR (c->>'risk_needs_approval')::boolean THEN
    RAISE EXCEPTION 'Ponuka potrebuje opravu alebo schválenie – pripravte ju znova.' USING ERRCODE = 'check_violation';
  END IF;
  v_fix := EXISTS (SELECT 1 FROM offer_variant x WHERE x.offer_id = o.id AND x.price_kind IN ('fix', 'kombinacia'));
  IF v_fix AND o.priced_on < (p_sent_at AT TIME ZONE 'Europe/Bratislava')::date THEN
    RAISE EXCEPTION 'Ceny pre obchodníka sú z %. FIX ponuku prepočítajte na dnešné ceny.', to_char(o.priced_on, 'DD. MM. YYYY')
      USING ERRCODE = 'check_violation';
  END IF;
  v_until := offer_default_valid_until(o.org_id, p_sent_at, v_fix);
  UPDATE offer SET status = 'odoslana', sent_at = p_sent_at, sent_by = crm_current_user_id(), sent_channel = p_channel,
                   sent_note = nullif(btrim(p_note), ''), valid_until = v_until
   WHERE id = o.id;
  UPDATE offer SET status = 'nahradena', replaced_by_id = o.id
   WHERE org_id = o.org_id AND number = o.number AND id <> o.id AND status IN ('odoslana', 'otvorena', 'zamietnuta');
  -- obchod iba dopredu: z Príležitosti do Cenovej ponuky
  SELECT s2.id INTO v_stage
    FROM deal d JOIN pipeline_stage s ON s.id = d.stage_id
    JOIN pipeline_stage s2 ON s2.pipeline_id = d.pipeline_id AND s2.code = 'cenova_ponuka'
   WHERE d.id = o.deal_id AND s.code = 'prilezitost';
  IF v_stage IS NOT NULL THEN
    UPDATE deal SET stage_id = v_stage WHERE id = o.deal_id;
  END IF;
  IF v_stage IS NULL AND crm_setting_on('customer_status_auto') THEN
    PERFORM customer_refresh((SELECT company_id FROM deal WHERE id = o.deal_id), (SELECT person_id FROM deal WHERE id = o.deal_id));
  END IF;
  SELECT * INTO o FROM offer WHERE id = o.id;
  PERFORM deal_event_offer(o, 'ponuka_odoslana',
    jsonb_build_object('channel', p_channel, 'sent_at', p_sent_at, 'valid_until', v_until));
  RETURN v_until;
END;
$$;

DROP FUNCTION email_reminder_draft(uuid);
DROP FUNCTION offer_acceptance_email();
DROP FUNCTION email_confirmation_queue(uuid);
DROP FUNCTION email_message_received(uuid, jsonb);
DROP FUNCTION email_thread_checked(uuid, text, text);
DROP FUNCTION email_watch_threads(integer);
DROP FUNCTION gmail_read_authorize(uuid, text, text, text);
DROP FUNCTION email_outbox_result(uuid, uuid, text, text);
DROP FUNCTION email_outbox_claim(integer);
DROP FUNCTION email_queue_claim(integer);
DROP FUNCTION email_pending_recover();
DROP FUNCTION email_retry(uuid);
DROP FUNCTION email_send_failed(uuid, uuid, text);
DROP FUNCTION email_send_complete(uuid);
DROP FUNCTION email_send_recorded(uuid, uuid, text, text, text, timestamptz);
DROP FUNCTION email_send_caller_ok(email_message);
DROP FUNCTION email_send_prepare(uuid, uuid, text, text, text);
DROP FUNCTION email_send_payload(uuid);
DROP FUNCTION gmail_mailbox_result(uuid, text);
DROP FUNCTION crm_background_only();
DROP FUNCTION email_draft_delete(uuid);
DROP FUNCTION email_draft_save(uuid, jsonb);
DROP FUNCTION email_compose_offer(uuid, text);
DROP FUNCTION email_thread_for_offer(uuid, uuid, text, uuid);
DROP FUNCTION email_offer_recipients(uuid);
DROP FUNCTION email_template_current(uuid, text, offer_language);
DROP FUNCTION email_fill(text, jsonb);
DROP FUNCTION email_offer_vars(uuid);
DROP FUNCTION email_fmt_time(timestamptz, offer_language);
DROP FUNCTION offer_variants_summary_text(uuid);
DROP FUNCTION offer_email_lock();
DROP FUNCTION offer_mark_sent_apply(offer, timestamptz, offer_send_channel, text, uuid);
DROP FUNCTION offer_send_check(offer, timestamptz);
DROP FUNCTION notification_email_outbox();

DROP TABLE email_outbox;
DROP TABLE gmail_mailbox_state;
DROP TABLE mailbox_access_log;
DROP FUNCTION mailbox_access_log_immutable();
DROP TABLE email_message;
DROP FUNCTION email_message_guard();
DROP TABLE email_thread;
DROP FUNCTION email_message_visible(uuid, email_status, uuid);
DROP FUNCTION email_thread_visible(uuid);
DROP FUNCTION email_addr_list_ok(jsonb, integer);
DROP TYPE email_status;

DELETE FROM notification WHERE kind IN ('ponuka_odpoved', 'ponuka_pripomienka', 'gmail_chyba', 'email_chyba');
ALTER TABLE notification DROP CONSTRAINT notification_kind_check;
ALTER TABLE notification ADD CONSTRAINT notification_kind_check CHECK (kind IN (
  'konci_4_mesiace', 'sprolongovana', 'neprolongovana', 'pod_hranicou', 'vynimka_nova', 'vynimka_rozhodnutie',
  'nocny_beh_chyba', 'maly_podnik', 'objem_xm', 'dalsi_krok', 'schvalenie_nove', 'schvalenie_rozhodnutie',
  'pridelenie_firmy', 'ponuka_akceptovana', 'ponuka_zablokovana', 'akceptacia_zrusena'));

DROP FUNCTION email_template_publish(uuid);
DROP TABLE email_template_version;
DROP FUNCTION email_template_guard();
DROP FUNCTION crm_email_template_editor();
DROP FUNCTION email_template_check(text, text);
DROP FUNCTION email_template_variables();

DROP FUNCTION user_photo_get(uuid);
DROP FUNCTION email_signature(uuid);
DROP FUNCTION user_profile_set(uuid, text, text, text, text);
DROP TABLE user_photo;
DROP FUNCTION user_photo_guard();
ALTER TABLE contact DROP COLUMN salutation;
ALTER TABLE app_user DROP COLUMN gmail_enabled, DROP COLUMN mobile, DROP COLUMN linkedin_url;
