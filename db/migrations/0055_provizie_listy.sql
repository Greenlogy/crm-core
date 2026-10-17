-- migrate:up

-- 0055_provizie_listy – modul 5, F7 krok 2 (Peter 17. 10. 2026; návrh časť 37.3 a doplnky 1–3 ku kroku 2):
-- - provízny list: dokument pre PDF (commission_claim_document), PDF uložené v R2 (kľúč a odtlačok), PDF so zrušením;
--   po uložení PDF e-mail z crm@ obchodníkovi a príjemcom kópie (fronta email_outbox, príloha PDF);
--   nevykreslené PDF (výpadok prehliadača) dokončí beh na pozadí (commission_claim_pdf_pending);
-- - fronta prepočtov: obsadený obchod ostane vo fronte (ďalší beh), položka staršia ako 1 hodina → zápis do denníka behov
--   (job 'provizie') a upozornenie adminom raz (commission_queue_alert).

-- ============================================================================
-- 1. Fronta prepočtov: upozornenie na starú položku
-- ============================================================================

ALTER TABLE commission_queue ADD COLUMN alerted_at timestamptz;
ALTER TABLE job_run DROP CONSTRAINT job_run_job_check;
ALTER TABLE job_run ADD CONSTRAINT job_run_job_check CHECK (job = ANY (ARRAY['zmluvy', 'obchody', 'ceny', 'provizie']::text[]));
ALTER TABLE notification DROP CONSTRAINT notification_kind_check;
ALTER TABLE notification ADD CONSTRAINT notification_kind_check CHECK (kind = ANY (ARRAY['konci_4_mesiace', 'sprolongovana', 'neprolongovana', 'pod_hranicou', 'vynimka_nova', 'vynimka_rozhodnutie', 'nocny_beh_chyba', 'maly_podnik', 'objem_xm', 'dalsi_krok', 'schvalenie_nove', 'schvalenie_rozhodnutie', 'pridelenie_firmy', 'ponuka_akceptovana', 'ponuka_zablokovana', 'akceptacia_zrusena', 'ponuka_odpoved', 'ponuka_pripomienka', 'gmail_chyba', 'email_chyba', 'nesparovana_zmluva', 'cena_ina_ako_v_ponuke', 'obnova', 'chyba_oom_na_zmluve', 'pomoc_s_ponukou',
  'provizny_list', 'provizny_list_zruseny', 'provizia_vyrovnanie', 'provizia_duplicita', 'provizia_preradena', 'provizia_chyba_cena',
  'provizie_fronta']::text[]));

-- položky vo fronte staršie ako 1 hodina (beh na pozadí po spracovaní fronty): denník behov a upozornenie adminom raz –
-- každá stará položka sa ohlási iba raz (alerted_at); nová stará položka neskôr znova
CREATE FUNCTION commission_queue_alert() RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_n      integer;
  v_deals  integer;
  v_oldest timestamptz;
  v_run    uuid;
BEGIN
  PERFORM crm_background_only();
  SELECT count(*), count(DISTINCT deal_id), min(created_at) INTO v_n, v_deals, v_oldest
    FROM commission_queue WHERE alerted_at IS NULL AND created_at < now() - interval '1 hour';
  IF v_n = 0 THEN
    RETURN 0;
  END IF;
  UPDATE commission_queue SET alerted_at = now() WHERE alerted_at IS NULL AND created_at < now() - interval '1 hour';
  INSERT INTO job_run (job, run_date, finished_at, result, errors)
  VALUES ('provizie', crm_today(), now(), jsonb_build_object('fronta_stara', v_deals),
          jsonb_build_array(jsonb_build_object('krok', 'fronta', 'kod', 'stara_polozka',
            'text', format('Prepočet provízie %s obchodov čaká vo fronte od %s (obchod je obsadený inou transakciou).',
                           v_deals, to_char(v_oldest AT TIME ZONE 'Europe/Bratislava', 'DD.MM.YYYY HH24:MI')))))
  RETURNING id INTO v_run;
  INSERT INTO notification (user_id, kind, job_run_id, detail)
  SELECT u.id, 'provizie_fronta', v_run,
         format('Prepočet provízie %s obchodov čaká vo fronte dlhšie ako 1 hodinu – pozrite denník behov.', v_deals)
    FROM app_user u WHERE u.is_admin AND u.status = 'aktivny';
  RETURN v_deals;
END;
$$;

CREATE OR REPLACE FUNCTION commission_queue_run() RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  d      uuid;
  v_max  bigint;
  v_done integer := 0;
  v_skip integer := 0;
BEGIN
  PERFORM crm_background_only();
  FOR d IN SELECT DISTINCT deal_id FROM commission_queue ORDER BY deal_id LOOP
    -- obsadený obchod: položky ostanú vo fronte a spracuje ich ďalší beh (0055)
    IF NOT commission_lock_deal(d, false) THEN
      v_skip := v_skip + 1;
      CONTINUE;
    END IF;
    SELECT max(id) INTO v_max FROM commission_queue WHERE deal_id = d;
    PERFORM commission_sync(d, false);
    DELETE FROM commission_queue WHERE deal_id = d AND id <= v_max;
    v_done := v_done + 1;
  END LOOP;
  RETURN jsonb_build_object('fronta_spracovane', v_done, 'fronta_preskocene', v_skip, 'fronta_stara', commission_queue_alert());
END;
$$;

-- ============================================================================
-- 2. PDF provízneho listu
-- ============================================================================

ALTER TABLE commission_claim
  ADD COLUMN pdf_sha256      text CHECK (pdf_sha256 ~ '^[0-9a-f]{64}$'),
  ADD COLUMN void_pdf_sha256 text CHECK (void_pdf_sha256 ~ '^[0-9a-f]{64}$'),
  ADD COLUMN items_snapshot  jsonb NOT NULL DEFAULT '[]' CHECK (jsonb_typeof(items_snapshot) = 'array');
COMMENT ON COLUMN commission_claim.items_snapshot IS 'položky listu v čase uplatnenia (PDF listu aj PDF zrušenia – po zrušení sa položky vrátia na Čaká); 0055';

-- snímka položky pri uplatnení (zapíše sa, keď provízia dostane list)
CREATE FUNCTION commission_claim_snapshot() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  UPDATE commission_claim
     SET items_snapshot = items_snapshot || jsonb_build_array(jsonb_build_object(
           'commission_id', NEW.id,
           'deal_name', coalesce((SELECT d.name FROM deal d WHERE d.id = NEW.deal_id), NEW.legacy_deal_name),
           'customer_name', (SELECT coalesce(co.name, nullif(btrim(concat_ws(' ', ct.first_name, ct.last_name)), ''))
                               FROM deal d LEFT JOIN company co ON co.id = d.company_id LEFT JOIN contact ct ON ct.id = d.person_id
                              WHERE d.id = NEW.deal_id),
           'kind', NEW.kind, 'won_at', NEW.won_at, 'duration_years', NEW.duration_years, 'volume_mwh', NEW.volume_mwh,
           'base_eur', NEW.base_eur, 'pct', NEW.pct, 'amount_eur', NEW.amount_eur, 'source', NEW.source))
   WHERE id = NEW.claim_id;
  RETURN NULL;
END;
$$;
CREATE TRIGGER trg_claim_snapshot AFTER UPDATE OF claim_id ON commission FOR EACH ROW
  WHEN (NEW.claim_id IS NOT NULL AND OLD.claim_id IS DISTINCT FROM NEW.claim_id) EXECUTE FUNCTION commission_claim_snapshot();
-- existujúce listy (CRM): snímka z aktuálnych položiek
UPDATE commission_claim k
   SET items_snapshot = coalesce((
         SELECT jsonb_agg(jsonb_build_object(
                  'commission_id', c.id, 'deal_name', coalesce(d.name, c.legacy_deal_name),
                  'customer_name', coalesce(co.name, nullif(btrim(concat_ws(' ', ct.first_name, ct.last_name)), '')),
                  'kind', c.kind, 'won_at', c.won_at, 'duration_years', c.duration_years, 'volume_mwh', c.volume_mwh,
                  'base_eur', c.base_eur, 'pct', c.pct, 'amount_eur', c.amount_eur, 'source', c.source))
           FROM commission c LEFT JOIN deal d ON d.id = c.deal_id LEFT JOIN company co ON co.id = d.company_id
           LEFT JOIN contact ct ON ct.id = d.person_id
          WHERE c.claim_id = k.id), '[]')
 WHERE k.source = 'crm' AND k.voided_at IS NULL;

-- dokument listu (PDF): spoločnosť s logom, obchodník, položky so zákazníkom, súčty podľa trvania; zrušenie.
-- Vidí ho, kto vidí list, alebo beh na pozadí (dokončenie PDF).
CREATE FUNCTION commission_claim_document(p_claim uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  k commission_claim;
BEGIN
  SELECT * INTO k FROM commission_claim WHERE id = p_claim;
  IF k.id IS NULL OR NOT (crm_current_user_id() IS NULL OR crm_commission_visible(k.org_id, k.user_id)) THEN   -- beh na pozadí = bez používateľa
    RETURN NULL;
  END IF;
  RETURN jsonb_build_object(
    'claim', jsonb_build_object('id', k.id, 'org_id', k.org_id, 'number', k.number, 'created_at', k.created_at, 'total_eur', k.total_eur,
                                'by_duration', k.by_duration, 'source', k.source,
                                'created_by', crm_user_name(k.created_by), 'voided_at', k.voided_at,
                                'voided_by', crm_user_name(k.voided_by), 'void_reason', k.void_reason),
    'seller', (SELECT jsonb_build_object('name', u.name, 'email', u.email, 'position', u.job_title) FROM app_user u WHERE u.id = k.user_id),
    'org', (SELECT jsonb_build_object('legal_name', o.legal_name, 'address', o.address, 'reg_no', o.reg_no, 'tax_no', o.tax_no,
                                      'vat_no', o.vat_no, 'email', o.email, 'web', o.web,
                                      'logo', (SELECT jsonb_build_object('mime', l.mime, 'data', encode(l.data, 'base64'))
                                                 FROM org_logo l WHERE l.org_id = o.id))
              FROM org o WHERE o.id = k.org_id),
    -- položky zo snímky pri uplatnení (aj pre zrušený list)
    'items', coalesce((SELECT jsonb_agg(i ORDER BY (i->>'duration_years')::int NULLS LAST, i->>'won_at', i->>'deal_name')
                         FROM jsonb_array_elements(k.items_snapshot) i), '[]'));
END;
$$;
COMMENT ON FUNCTION commission_claim_document(uuid) IS 'dokument provízneho listu pre PDF listu aj PDF zrušenia (0055); položky zo snímky pri uplatnení';

-- listy bez PDF (nové) a zrušené bez PDF zrušenia – dokončí beh na pozadí
CREATE FUNCTION commission_claim_pdf_pending(p_limit integer DEFAULT 10) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT coalesce(jsonb_agg(x ORDER BY x->>'created_at'), '[]')
    FROM (SELECT jsonb_build_object('id', k.id, 'kind', CASE WHEN k.pdf_key IS NULL THEN 'list' ELSE 'zrusenie' END,
                                    'org_id', k.org_id, 'number', k.number, 'pdf_key', k.pdf_key, 'created_at', k.created_at) AS x
            FROM commission_claim k
           WHERE crm_current_user_id() IS NULL AND k.source = 'crm'
             AND (k.pdf_key IS NULL OR (k.voided_at IS NOT NULL AND k.void_pdf_key IS NULL))
           ORDER BY k.created_at
           LIMIT greatest(least(p_limit, 50), 1)) s
$$;

-- uloženie PDF (list alebo zrušenie): kľúč R2 a odtlačok sa zapíšu raz; potom e-mail z crm@ obchodníkovi a príjemcom kópie
CREATE FUNCTION commission_claim_pdf_set(p_claim uuid, p_kind text, p_key text, p_sha256 text) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  k    commission_claim;
  v_cc uuid[];
  v_n  integer;
BEGIN
  SELECT * INTO k FROM commission_claim WHERE id = p_claim FOR UPDATE;
  IF k.id IS NULL OR NOT (crm_current_user_id() IS NULL OR crm_commission_visible(k.org_id, k.user_id)) THEN   -- beh na pozadí = bez používateľa
    RAISE EXCEPTION 'Provízny list neexistuje.' USING ERRCODE = 'no_data_found';
  END IF;
  IF p_kind NOT IN ('list', 'zrusenie') OR p_key !~ ('^provizie/' || k.org_id || '/[0-9]{4}/CMSN-[0-9]{4}-[0-9]{4,}(-zrusene)?\.pdf$') THEN
    RAISE EXCEPTION 'Neplatný kľúč PDF listu.' USING ERRCODE = 'check_violation';
  END IF;
  IF p_kind = 'list' THEN
    UPDATE commission_claim SET pdf_key = p_key, pdf_sha256 = p_sha256 WHERE id = k.id AND pdf_key IS NULL;
  ELSE
    IF k.voided_at IS NULL THEN
      RAISE EXCEPTION 'List nie je zrušený.' USING ERRCODE = 'check_violation';
    END IF;
    UPDATE commission_claim SET void_pdf_key = p_key, void_pdf_sha256 = p_sha256 WHERE id = k.id AND void_pdf_key IS NULL;
  END IF;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n = 0 THEN
    RETURN false;   -- PDF už bolo uložené (súbežné dokončenie) – e-mail sa nezaradí druhýkrát
  END IF;
  -- zrušený skôr, než sa stihlo uložiť PDF listu: posiela sa iba zrušenie
  IF p_kind = 'list' AND k.voided_at IS NOT NULL THEN
    RETURN true;
  END IF;
  SELECT coalesce(array_agg(x::uuid), '{}') INTO v_cc
    FROM jsonb_array_elements_text(coalesce((SELECT value FROM app_setting WHERE key = 'commission_claim_cc'), '[]')) x;
  INSERT INTO email_outbox (user_id, kind, commission_claim_id, detail)
  SELECT u.id, CASE p_kind WHEN 'list' THEN 'provizny_list' ELSE 'provizny_list_zruseny' END, k.id, k.number
    FROM app_user u
   WHERE u.status = 'aktivny' AND (u.id = k.user_id OR (u.id = ANY (v_cc) AND crm_user_sees_org(u.id, k.org_id)));
  RETURN true;
END;
$$;

-- ============================================================================
-- 3. E-mail listu z crm@ (fronta interných e-mailov, príloha PDF z R2)
-- ============================================================================

ALTER TABLE email_outbox ADD COLUMN commission_claim_id uuid REFERENCES commission_claim (id);
ALTER TABLE email_outbox DROP CONSTRAINT email_outbox_kind_check;
ALTER TABLE email_outbox ADD CONSTRAINT email_outbox_kind_check
  CHECK (kind = ANY (ARRAY['schvalenie_nove', 'schvalenie_rozhodnutie', 'ponuka_akceptovana', 'pomoc_s_ponukou',
                           'provizny_list', 'provizny_list_zruseny']::text[]));
ALTER TABLE email_outbox ADD CONSTRAINT email_outbox_claim_check
  CHECK ((kind IN ('provizny_list', 'provizny_list_zruseny')) = (commission_claim_id IS NOT NULL));

CREATE OR REPLACE FUNCTION email_outbox_claim(p_limit integer DEFAULT 20) RETURNS jsonb
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
                                               'deal_id', u.deal_id, 'approval_id', u.approval_id, 'detail', u.detail,
                                               -- 0055: provízny list – PDF z R2 ako príloha
                                               'commission_claim_id', u.commission_claim_id,
                                               'pdf_key', CASE u.kind WHEN 'provizny_list' THEN k.pdf_key WHEN 'provizny_list_zruseny' THEN k.void_pdf_key END)
                            ORDER BY u.created_at), '[]')
    INTO res
    FROM u JOIN app_user a ON a.id = u.user_id
    LEFT JOIN commission_claim k ON k.id = u.commission_claim_id;
  RETURN res;
END;
$$;

-- ============================================================================
-- 4. Práva
-- ============================================================================

-- beh na pozadí beží ako crm_app bez používateľa: frontu smie spustiť (crm_background_only odmietne prihláseného),
-- upozornenie iba cez frontu; snímka iba spúšťač
REVOKE EXECUTE ON FUNCTION commission_queue_alert(), commission_claim_snapshot() FROM PUBLIC;
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'crm_app') THEN
    REVOKE EXECUTE ON FUNCTION commission_queue_alert(), commission_claim_snapshot() FROM crm_app;
    GRANT EXECUTE ON FUNCTION commission_queue_run() TO crm_app;
  END IF;
END;
$$;

-- migrate:down

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'crm_app') THEN
    REVOKE EXECUTE ON FUNCTION commission_queue_run() FROM crm_app;
  END IF;
END;
$$;
CREATE OR REPLACE FUNCTION email_outbox_claim(p_limit integer DEFAULT 20) RETURNS jsonb
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
DELETE FROM email_outbox WHERE kind IN ('provizny_list', 'provizny_list_zruseny');
ALTER TABLE email_outbox DROP CONSTRAINT email_outbox_claim_check;
ALTER TABLE email_outbox DROP CONSTRAINT email_outbox_kind_check;
ALTER TABLE email_outbox ADD CONSTRAINT email_outbox_kind_check
  CHECK (kind = ANY (ARRAY['schvalenie_nove'::text, 'schvalenie_rozhodnutie'::text, 'ponuka_akceptovana'::text, 'pomoc_s_ponukou'::text]));
ALTER TABLE email_outbox DROP COLUMN commission_claim_id;
DROP FUNCTION commission_claim_pdf_set(uuid, text, text, text);
DROP FUNCTION commission_claim_pdf_pending(integer);
DROP FUNCTION commission_claim_document(uuid);
DROP TRIGGER trg_claim_snapshot ON commission;
DROP FUNCTION commission_claim_snapshot();
ALTER TABLE commission_claim DROP COLUMN items_snapshot, DROP COLUMN void_pdf_sha256, DROP COLUMN pdf_sha256;
CREATE OR REPLACE FUNCTION commission_queue_run() RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  d      uuid;
  v_max  bigint;
  v_done integer := 0;
  v_skip integer := 0;
BEGIN
  PERFORM crm_background_only();
  FOR d IN SELECT DISTINCT deal_id FROM commission_queue ORDER BY deal_id LOOP
    IF NOT commission_lock_deal(d, false) THEN
      v_skip := v_skip + 1;
      CONTINUE;
    END IF;
    SELECT max(id) INTO v_max FROM commission_queue WHERE deal_id = d;
    PERFORM commission_sync(d, false);
    DELETE FROM commission_queue WHERE deal_id = d AND id <= v_max;
    v_done := v_done + 1;
  END LOOP;
  RETURN jsonb_build_object('fronta_spracovane', v_done, 'fronta_preskocene', v_skip);
END;
$$;
DROP FUNCTION commission_queue_alert();
DELETE FROM notification WHERE kind = 'provizie_fronta';
ALTER TABLE notification DROP CONSTRAINT notification_kind_check;
ALTER TABLE notification ADD CONSTRAINT notification_kind_check CHECK (kind = ANY (ARRAY['konci_4_mesiace', 'sprolongovana', 'neprolongovana', 'pod_hranicou', 'vynimka_nova', 'vynimka_rozhodnutie', 'nocny_beh_chyba', 'maly_podnik', 'objem_xm', 'dalsi_krok', 'schvalenie_nove', 'schvalenie_rozhodnutie', 'pridelenie_firmy', 'ponuka_akceptovana', 'ponuka_zablokovana', 'akceptacia_zrusena', 'ponuka_odpoved', 'ponuka_pripomienka', 'gmail_chyba', 'email_chyba', 'nesparovana_zmluva', 'cena_ina_ako_v_ponuke', 'obnova', 'chyba_oom_na_zmluve', 'pomoc_s_ponukou',
  'provizny_list', 'provizny_list_zruseny', 'provizia_vyrovnanie', 'provizia_duplicita', 'provizia_preradena', 'provizia_chyba_cena']::text[]));
DELETE FROM job_run WHERE job = 'provizie';
ALTER TABLE job_run DROP CONSTRAINT job_run_job_check;
ALTER TABLE job_run ADD CONSTRAINT job_run_job_check CHECK (job = ANY (ARRAY['zmluvy'::text, 'obchody'::text, 'ceny'::text]));
ALTER TABLE commission_queue DROP COLUMN alerted_at;
