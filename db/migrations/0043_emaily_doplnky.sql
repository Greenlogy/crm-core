-- migrate:up

-- 0043_emaily_doplnky – modul 5, F4 (Peter 16. 10., body 1 a 4; 0042 už je na dev, preto nová migrácia):
-- 1. Čítanie Gmailu iba threads.get a messages.get vo formáte minimal / metadata / full – attachments.get a formát raw
--    (celý MIME s prílohami) nie sú povolené; prílohy z odpovedí sa neukladajú ani nečítajú. Formát sa zapisuje do denníka.
-- 4. Ručná akceptácia: voľba „Poslať zákazníkovi potvrdenie“ (predvolene zapnutá); vypnutie sa zapíše do časovej osi.

-- ============================================================================
-- 1. Povolené operácie Gmailu
-- ============================================================================

-- denník je iba na pridávanie (riadkové triggery bránia zmene); nový stĺpec s predvolenou hodnotou riadky nemení
ALTER TABLE mailbox_access_log DROP CONSTRAINT mailbox_access_log_method_check;
ALTER TABLE mailbox_access_log ADD COLUMN format text NOT NULL DEFAULT 'full' CHECK (format IN ('minimal', 'metadata', 'full'));
ALTER TABLE mailbox_access_log ALTER COLUMN format DROP DEFAULT;
ALTER TABLE mailbox_access_log ADD CONSTRAINT mailbox_access_log_method_check CHECK (method IN ('threads.get', 'messages.get'));

DROP FUNCTION gmail_read_authorize(uuid, text, text, text);

-- JEDINÁ kontrola pred čítaním Gmailu (gmailRead): iba threads.get a messages.get vo formáte minimal / metadata / full
-- (nie raw – celý MIME s prílohami; prílohy sa nečítajú, attachments.get nie je povolené – Peter 16. 10.), iba vlákno CRM
-- v danej schránke; beh na pozadí iba threads.get sledovaného vlákna (aktivita za 30 dní), používateľ iba messages.get
-- známej správy vo vlákne, ktoré vidí. Každé povolené čítanie sa zapíše do denníka; schránka crm@ sa nečíta.
CREATE FUNCTION gmail_read_authorize(p_mailbox uuid, p_gmail_thread_id text, p_gmail_message_id text, p_method text,
                                     p_format text) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  t email_thread;
BEGIN
  IF p_method IS NULL OR p_method NOT IN ('threads.get', 'messages.get') THEN
    RAISE EXCEPTION 'Gmail: povolené je iba threads.get a messages.get.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF p_format IS NULL OR p_format NOT IN ('minimal', 'metadata', 'full') THEN
    RAISE EXCEPTION 'Gmail: povolený formát je iba minimal, metadata alebo full (nie raw).' USING ERRCODE = 'insufficient_privilege';
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
    IF p_method <> 'messages.get' OR NOT email_thread_visible(t.id)
       OR NOT EXISTS (SELECT 1 FROM email_message m WHERE m.thread_id = t.id AND m.gmail_message_id = p_gmail_message_id) THEN
      RAISE EXCEPTION 'Správa nepatrí vláknu, ktoré vidíte.' USING ERRCODE = 'insufficient_privilege';
    END IF;
  END IF;
  INSERT INTO mailbox_access_log (user_id, mailbox_user_id, method, format, gmail_thread_id, gmail_message_id, thread_id)
  VALUES (crm_active_user_id(), p_mailbox, p_method, p_format, p_gmail_thread_id, p_gmail_message_id, t.id);
  RETURN t.id;
END;
$$;

-- ============================================================================
-- 4. Voľba poslania potvrdenia pri ručnej akceptácii
-- ============================================================================

-- Ručná akceptácia: voľba „Poslať zákazníkovi potvrdenie“ (predvolene zapnutá, Peter 16. 10.). Vypnutie zapíše obchodník
-- pri zázname akceptácie (pred uložením PDF potvrdenia, do 10 minút); zapíše sa do časovej osi obchodu.
ALTER TABLE offer_acceptance ADD COLUMN send_confirmation boolean NOT NULL DEFAULT true;
COMMENT ON COLUMN offer_acceptance.send_confirmation IS 'poslať zákazníkovi potvrdenie e-mailom (ručná akceptácia: voľba obchodníka) – 0042';
ALTER TABLE deal_event DROP CONSTRAINT deal_event_kind_check;
ALTER TABLE deal_event ADD CONSTRAINT deal_event_kind_check CHECK (kind IN (
  'zalozenie', 'stadium', 'vlastnik', 'znovuotvorenie', 'oom_pridane', 'oom_odobrane', 'oom_zrusene', 'oom_nezrusene',
  'kontakt_pridany', 'kontakt_odobrany', 'zakaznik_vlastnik', 'ponuka_nova', 'ponuka_verzia', 'ponuka_prepocitana',
  'ponuka_odoslana', 'ponuka_zamietnuta', 'ponuka_platnost', 'schvalenie_ziadost', 'schvalenie_rozhodnutie',
  'ponuka_akceptovana', 'ponuka_zablokovana', 'ponuka_otvorena', 'ponuka_odkaz', 'akceptacia_zrusena', 'ponuka_odblokovana',
  'potvrdenie_neodoslane'));

CREATE FUNCTION offer_acceptance_confirmation_off(p_id uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  a offer_acceptance;
  o offer;
BEGIN
  SELECT * INTO a FROM offer_acceptance WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Akceptácia neexistuje.' USING ERRCODE = 'no_data_found';
  END IF;
  o := offer_for_edit(a.offer_id);
  IF a.method <> 'rucne' OR a.created_at < now() - interval '10 minutes' OR a.confirmation_pdf_key IS NOT NULL OR a.revoked_at IS NOT NULL THEN
    RAISE EXCEPTION 'Poslanie potvrdenia sa vypína iba pri zázname ručnej akceptácie.' USING ERRCODE = 'check_violation';
  END IF;
  IF NOT a.send_confirmation THEN
    RETURN;
  END IF;
  UPDATE offer_acceptance SET send_confirmation = false WHERE id = a.id;
  PERFORM deal_event_offer(o, 'potvrdenie_neodoslane', jsonb_build_object('acceptance_id', a.id));
END;
$$;

CREATE OR REPLACE FUNCTION email_confirmation_queue(p_acceptance uuid) RETURNS uuid
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
  IF a.id IS NULL OR a.confirmation_pdf_key IS NULL OR a.revoked_at IS NOT NULL OR NOT a.send_confirmation
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

-- migrate:down

CREATE OR REPLACE FUNCTION email_confirmation_queue(p_acceptance uuid) RETURNS uuid
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

DROP FUNCTION offer_acceptance_confirmation_off(uuid);
DELETE FROM deal_event WHERE kind = 'potvrdenie_neodoslane';
ALTER TABLE deal_event DROP CONSTRAINT deal_event_kind_check;
ALTER TABLE deal_event ADD CONSTRAINT deal_event_kind_check CHECK (kind IN (
  'zalozenie', 'stadium', 'vlastnik', 'znovuotvorenie', 'oom_pridane', 'oom_odobrane', 'oom_zrusene', 'oom_nezrusene',
  'kontakt_pridany', 'kontakt_odobrany', 'zakaznik_vlastnik', 'ponuka_nova', 'ponuka_verzia', 'ponuka_prepocitana',
  'ponuka_odoslana', 'ponuka_zamietnuta', 'ponuka_platnost', 'schvalenie_ziadost', 'schvalenie_rozhodnutie',
  'ponuka_akceptovana', 'ponuka_zablokovana', 'ponuka_otvorena', 'ponuka_odkaz', 'akceptacia_zrusena', 'ponuka_odblokovana'));
ALTER TABLE offer_acceptance DROP COLUMN send_confirmation;

DROP FUNCTION gmail_read_authorize(uuid, text, text, text, text);

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

ALTER TABLE mailbox_access_log DROP CONSTRAINT mailbox_access_log_method_check;
ALTER TABLE mailbox_access_log ADD CONSTRAINT mailbox_access_log_method_check CHECK (method IN ('threads.get', 'messages.get', 'attachments.get'));
ALTER TABLE mailbox_access_log DROP COLUMN format;
