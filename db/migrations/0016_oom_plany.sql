-- 0016_oom_plany.sql – modul Odberné miesta: plánované zmeny a EIC v histórii (zadanie OOM čl. 15, F2a)
--
-- Plánovaná zmena (oom_planned_change): prepis, odchod alebo zrušenie k budúcemu dátumu (Peter 12. 10.).
--   Dátum: prepis = prvý deň nového odberateľa (vykoná sa v ten deň); odchod a zrušenie = posledný deň
--   dodávky (vykoná sa nasledujúci deň). Dovtedy sa stavy nemenia. Ak dátum už nastal, zmena sa vykoná hneď.
--   Plán možno zrušiť alebo zmeniť mu dátum. Aktívny plán blokuje iba zmenu stavu a prepis toho OOM
--   (odchod, zrušenie, prepis), nie úpravu údajov, zariadení či kontaktov.
--   Vykoná ho nočný beh (oom_daily_run, Cron); ak sa nedá vykonať, plán „zlyhal“ s dôvodom a stav sa nemení.
--   Audit: zadanie, zmena dátumu a zrušenie s menom; vykonanie „Systém“.
-- EIC v histórii: oom_brief() vráti EIC, názov a obec OOM aj tomu, kto vidí iba zákazníka väzby
--   (obchodník starého zákazníka po prepise, „iba svoje“).
-- oom_v: plánovaná zmena a „plán zlyhal“ (zoznam OOM).

-- migrate:up

CREATE TYPE oom_plan_kind AS ENUM ('prepis', 'odchod', 'zrusenie');
CREATE TYPE oom_plan_status AS ENUM ('planovana', 'vykonana', 'zrusena', 'zlyhala');

CREATE TABLE oom_planned_change (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  oom_id          uuid NOT NULL REFERENCES oom (id),
  org_id          uuid NOT NULL REFERENCES org (id),
  kind            oom_plan_kind NOT NULL,
  effective_date  date NOT NULL,
  company_id      uuid REFERENCES company (id),
  person_id       uuid REFERENCES contact (id),
  status          oom_plan_status NOT NULL DEFAULT 'planovana',
  error           text,
  created_by      uuid REFERENCES app_user (id),
  executed_at     timestamptz,
  cancelled_at    timestamptz,
  cancelled_by    uuid REFERENCES app_user (id),
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT oom_plan_customer_check CHECK (
    CASE WHEN kind = 'prepis' THEN num_nonnulls(company_id, person_id) = 1
         ELSE num_nonnulls(company_id, person_id) = 0 END),
  -- zlyhaný plán má dôvod; ostane zapísaný aj po zrušení („vyriešené“)
  CONSTRAINT oom_plan_error_check CHECK ((status <> 'zlyhala' OR error IS NOT NULL) AND (error IS NULL OR status IN ('zlyhala', 'zrusena')))
);
CREATE UNIQUE INDEX oom_planned_change_one_active_key ON oom_planned_change (oom_id) WHERE status = 'planovana';
CREATE INDEX oom_planned_change_due_idx ON oom_planned_change (effective_date) WHERE status = 'planovana';
COMMENT ON TABLE oom_planned_change IS 'plánovaný prepis, odchod alebo zrušenie OOM k budúcemu dátumu; vykoná nočný beh (oom_daily_run)';
COMMENT ON COLUMN oom_planned_change.effective_date IS 'prepis: prvý deň nového odberateľa; odchod a zrušenie: posledný deň dodávky';
COMMENT ON COLUMN oom_planned_change.error IS 'dôvod, prečo sa plán nedal vykonať (status zlyhala)';

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON oom_planned_change FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_audit AFTER INSERT OR UPDATE OR DELETE ON oom_planned_change FOR EACH ROW EXECUTE FUNCTION audit_row();

-- Kto vidí OOM, vidí jeho plány; zakladá a mení, kto smie OOM upravovať. Mazanie nie (zrušenie = stav).
ALTER TABLE oom_planned_change ENABLE ROW LEVEL SECURITY;
CREATE POLICY oom_select ON oom_planned_change FOR SELECT USING (crm_oom_access(oom_id, 'view'));
CREATE POLICY oom_insert ON oom_planned_change FOR INSERT WITH CHECK (crm_oom_access(oom_id, 'edit'));
CREATE POLICY oom_update ON oom_planned_change FOR UPDATE
  USING (crm_oom_access(oom_id, 'edit')) WITH CHECK (crm_oom_access(oom_id, 'edit'));

-- Deň, keď sa plán vykoná: prepis v deň zmeny, odchod a zrušenie deň po poslednom dni dodávky.
CREATE FUNCTION oom_plan_due_on(p_kind oom_plan_kind, p_date date) RETURNS date
LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE WHEN p_kind = 'prepis' THEN p_date ELSE p_date + 1 END
$$;

-- ============================================================================
-- Aktívny plán blokuje zmenu stavu a prepis (okrem vykonania plánu a aktivácie)
-- ============================================================================

CREATE FUNCTION oom_plan_guard(p_oom_id uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF coalesce(current_setting('crm.oom_plan_run', true), '') <> 'on'
     AND EXISTS (SELECT 1 FROM oom_planned_change WHERE oom_id = p_oom_id AND status = 'planovana') THEN
    RAISE EXCEPTION 'Odberné miesto má plánovanú zmenu. Najprv ju zrušte alebo zmeňte jej dátum.'
      USING ERRCODE = 'check_violation';
  END IF;
END;
$$;

-- Ako v 0013, navyše kontrola plánu pri odchode a zrušení (aktivácia plán neblokuje).
CREATE OR REPLACE FUNCTION oom_set_status(p_oom_id uuid, p_status oom_status, p_date date DEFAULT crm_today())
RETURNS void
LANGUAGE plpgsql AS $$
DECLARE
  v_link oom_customer;
BEGIN
  IF p_status IN ('odidene', 'zrusene') THEN
    PERFORM oom_plan_guard(p_oom_id);
  END IF;
  SELECT * INTO v_link FROM oom_customer WHERE oom_id = p_oom_id AND valid_to IS NULL FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Odberné miesto nemá otvorenú väzbu (je Odídené, Zrušené alebo Prepísané).'
      USING ERRCODE = 'check_violation';
  END IF;
  CASE p_status
    WHEN 'aktivne' THEN
      UPDATE oom_customer SET status = 'aktivne' WHERE id = v_link.id;
    WHEN 'odidene' THEN
      UPDATE oom_customer SET valid_to = p_date, end_reason = 'odchod', status = 'odidene' WHERE id = v_link.id;
    WHEN 'zrusene' THEN
      UPDATE oom_customer SET valid_to = p_date, end_reason = 'zrusenie', status = 'zrusene' WHERE id = v_link.id;
    WHEN 'prepisane' THEN
      RAISE EXCEPTION 'Prepis na iného odberateľa: oom_transfer.' USING ERRCODE = 'check_violation';
    ELSE
      RAISE EXCEPTION 'Stav % sa takto nenastavuje.', p_status USING ERRCODE = 'check_violation';
  END CASE;
END;
$$;

-- Ako v 0015, navyše kontrola plánu.
CREATE OR REPLACE FUNCTION oom_transfer(p_oom_id uuid, p_company_id uuid, p_person_id uuid, p_date date)
RETURNS uuid
LANGUAGE plpgsql AS $$
DECLARE
  v_link oom_customer;
  v_id   uuid;
BEGIN
  IF num_nonnulls(p_company_id, p_person_id) <> 1 THEN
    RAISE EXCEPTION 'oom_transfer: zadaj práve jedno z company_id / person_id';
  END IF;
  PERFORM oom_plan_guard(p_oom_id);
  SELECT * INTO v_link FROM oom_customer WHERE oom_id = p_oom_id AND valid_to IS NULL FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Prepísať sa dá iba Pripravované alebo Aktívne odberné miesto.' USING ERRCODE = 'check_violation';
  END IF;
  IF (v_link.company_id, v_link.person_id) IS NOT DISTINCT FROM (p_company_id, p_person_id) THEN
    RAISE EXCEPTION 'Nový odberateľ je ten istý zákazník.' USING ERRCODE = 'check_violation';
  END IF;
  IF p_date <= v_link.valid_from THEN
    RAISE EXCEPTION 'Dátum prepisu musí byť po začiatku väzby (%).', v_link.valid_from USING ERRCODE = 'check_violation';
  END IF;

  UPDATE oom_customer SET valid_to = p_date - 1, end_reason = 'prepis', status = 'prepisane' WHERE id = v_link.id;
  PERFORM set_config('crm.oom_system', 'on', true);
  DELETE FROM oom_contact WHERE oom_id = p_oom_id;
  PERFORM set_config('crm.oom_system', '', true);
  INSERT INTO oom_customer (oom_id, company_id, person_id, org_id, valid_from, status)
  VALUES (p_oom_id, p_company_id, p_person_id, v_link.org_id, p_date, v_link.status)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

-- ============================================================================
-- Plánovanie, zmena dátumu, zrušenie, vykonanie
-- ============================================================================

-- Vykonanie jedného plánu (nočný beh alebo dátum, ktorý už nastal). Ak zlyhá, plán „zlyhal“ s dôvodom
-- a nič iné sa nezmení. Audit „Systém“. true = vykonaný.
CREATE FUNCTION oom_plan_execute(p_plan_id uuid) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_plan oom_planned_change;
  v_prev text := crm_as_system(true);
  v_ok   boolean := true;
BEGIN
  SELECT * INTO v_plan FROM oom_planned_change WHERE id = p_plan_id AND status = 'planovana' FOR UPDATE;
  IF NOT FOUND THEN
    PERFORM set_config('app.change_source', v_prev, true);
    RETURN false;
  END IF;
  PERFORM set_config('crm.oom_plan_run', 'on', true);
  BEGIN
    CASE v_plan.kind
      WHEN 'prepis'   THEN PERFORM oom_transfer(v_plan.oom_id, v_plan.company_id, v_plan.person_id, v_plan.effective_date);
      WHEN 'odchod'   THEN PERFORM oom_set_status(v_plan.oom_id, 'odidene', v_plan.effective_date);
      WHEN 'zrusenie' THEN PERFORM oom_set_status(v_plan.oom_id, 'zrusene', v_plan.effective_date);
    END CASE;
    UPDATE oom_planned_change SET status = 'vykonana', executed_at = now() WHERE id = p_plan_id;
  EXCEPTION WHEN OTHERS THEN
    UPDATE oom_planned_change SET status = 'zlyhala', error = SQLERRM, executed_at = now() WHERE id = p_plan_id;
    v_ok := false;
  END;
  PERFORM set_config('crm.oom_plan_run', '', true);
  PERFORM set_config('app.change_source', v_prev, true);
  RETURN v_ok;
END;
$$;
REVOKE EXECUTE ON FUNCTION oom_plan_execute(uuid) FROM PUBLIC;

-- Zadanie prepisu, odchodu alebo zrušenia. Ak deň vykonania už nastal, zmena sa urobí hneď (NULL);
-- inak sa uloží plán (vráti jeho id). Práva ako pri okamžitej zmene: upravovať OOM, pri prepise
-- s rozsahom „iba svoje“ iba na vlastného zákazníka.
-- Príklad: SELECT oom_plan_change('<oom>', 'odchod', '2026-12-31');
--          SELECT oom_plan_change('<oom>', 'prepis', '2026-11-01', NULL, '<osoba>');
CREATE FUNCTION oom_plan_change(p_oom_id uuid, p_kind oom_plan_kind, p_date date,
                                p_company_id uuid DEFAULT NULL, p_person_id uuid DEFAULT NULL)
RETURNS uuid
LANGUAGE plpgsql AS $$
DECLARE
  v_link oom_customer;
  v_org  uuid;
  v_id   uuid;
BEGIN
  IF p_date IS NULL THEN
    RAISE EXCEPTION 'Chýba dátum.' USING ERRCODE = 'check_violation';
  END IF;
  IF (p_kind = 'prepis') <> (num_nonnulls(p_company_id, p_person_id) = 1) OR num_nonnulls(p_company_id, p_person_id) > 1 THEN
    RAISE EXCEPTION 'Pri prepise zadajte práve jedného nového odberateľa (firmu alebo domácnosť); pri odchode a zrušení žiadneho.'
      USING ERRCODE = 'check_violation';
  END IF;
  IF NOT crm_oom_access(p_oom_id, 'edit') THEN
    RAISE EXCEPTION 'Toto odberné miesto nemôžete meniť.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  PERFORM oom_plan_guard(p_oom_id);
  SELECT * INTO v_link FROM oom_customer WHERE oom_id = p_oom_id AND valid_to IS NULL;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Odberné miesto nemá otvorenú väzbu (je Odídené, Zrušené alebo Prepísané).'
      USING ERRCODE = 'check_violation';
  END IF;

  IF p_kind = 'prepis' THEN
    IF (v_link.company_id, v_link.person_id) IS NOT DISTINCT FROM (p_company_id, p_person_id) THEN
      RAISE EXCEPTION 'Nový odberateľ je ten istý zákazník.' USING ERRCODE = 'check_violation';
    END IF;
    IF p_date <= v_link.valid_from THEN
      RAISE EXCEPTION 'Dátum prepisu musí byť po začiatku väzby (%).', v_link.valid_from USING ERRCODE = 'check_violation';
    END IF;
    IF NOT (crm_company_access(p_company_id, 'view') OR crm_contact_access(p_person_id, 'view')) THEN
      RAISE EXCEPTION 'Nový odberateľ neexistuje.' USING ERRCODE = 'no_data_found';
    END IF;
    IF crm_scope('odberne_miesta', 'edit') = 'iba_svoje' AND NOT crm_customer_owned(p_company_id, p_person_id) THEN
      RAISE EXCEPTION 'Prepísať môžete iba na vlastného zákazníka.' USING ERRCODE = 'insufficient_privilege';
    END IF;
    v_org := coalesce((SELECT org_id FROM company WHERE id = p_company_id), (SELECT org_id FROM contact WHERE id = p_person_id));
    IF v_org <> v_link.org_id THEN
      RAISE EXCEPTION 'Nový odberateľ patrí inej spoločnosti skupiny.' USING ERRCODE = 'check_violation';
    END IF;
  ELSIF p_date < v_link.valid_from THEN
    RAISE EXCEPTION 'Posledný deň dodávky nemôže byť pred začiatkom väzby (%).', v_link.valid_from USING ERRCODE = 'check_violation';
  END IF;

  IF oom_plan_due_on(p_kind, p_date) <= crm_today() THEN
    CASE p_kind
      WHEN 'prepis'   THEN PERFORM oom_transfer(p_oom_id, p_company_id, p_person_id, p_date);
      WHEN 'odchod'   THEN PERFORM oom_set_status(p_oom_id, 'odidene', p_date);
      WHEN 'zrusenie' THEN PERFORM oom_set_status(p_oom_id, 'zrusene', p_date);
    END CASE;
    RETURN NULL;
  END IF;

  INSERT INTO oom_planned_change (oom_id, org_id, kind, effective_date, company_id, person_id, created_by)
  VALUES (p_oom_id, v_link.org_id, p_kind, p_date, p_company_id, p_person_id, crm_active_user_id())
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

-- Zmena dátumu plánu. Ak nový deň vykonania už nastal, vykoná sa hneď (NULL); inak vráti id plánu.
CREATE FUNCTION oom_plan_reschedule(p_plan_id uuid, p_date date) RETURNS uuid
LANGUAGE plpgsql AS $$
DECLARE
  v_plan oom_planned_change;
  v_from date;
BEGIN
  SELECT * INTO v_plan FROM oom_planned_change WHERE id = p_plan_id AND status = 'planovana' FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Plánovaná zmena neexistuje alebo už nie je aktívna.' USING ERRCODE = 'no_data_found';
  END IF;
  v_from := (SELECT valid_from FROM oom_customer WHERE oom_id = v_plan.oom_id AND valid_to IS NULL);
  IF p_date IS NULL OR (v_plan.kind = 'prepis' AND p_date <= v_from) OR (v_plan.kind <> 'prepis' AND p_date < v_from) THEN
    RAISE EXCEPTION 'Dátum musí byť po začiatku väzby (%).', v_from USING ERRCODE = 'check_violation';
  END IF;
  UPDATE oom_planned_change SET effective_date = p_date WHERE id = p_plan_id;
  IF oom_plan_due_on(v_plan.kind, p_date) <= crm_today() THEN
    -- deň už nastal: zmena hneď, s právami používateľa (ako pri zadaní s dátumom v minulosti)
    PERFORM set_config('crm.oom_plan_run', 'on', true);
    CASE v_plan.kind
      WHEN 'prepis'   THEN PERFORM oom_transfer(v_plan.oom_id, v_plan.company_id, v_plan.person_id, p_date);
      WHEN 'odchod'   THEN PERFORM oom_set_status(v_plan.oom_id, 'odidene', p_date);
      WHEN 'zrusenie' THEN PERFORM oom_set_status(v_plan.oom_id, 'zrusene', p_date);
    END CASE;
    PERFORM set_config('crm.oom_plan_run', '', true);
    UPDATE oom_planned_change SET status = 'vykonana', executed_at = now() WHERE id = p_plan_id;
    RETURN NULL;
  END IF;
  RETURN p_plan_id;
END;
$$;

-- Zrušenie plánu (aj zlyhaného – „vyriešené“).
CREATE FUNCTION oom_plan_cancel(p_plan_id uuid) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  UPDATE oom_planned_change SET status = 'zrusena', cancelled_at = now(), cancelled_by = crm_active_user_id()
   WHERE id = p_plan_id AND status IN ('planovana', 'zlyhala');
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Plánovaná zmena neexistuje alebo sa už nedá zrušiť.' USING ERRCODE = 'no_data_found';
  END IF;
END;
$$;

-- Plán sa mení iba funkciami (druh, OOM a odberateľ nikdy; dátum a stav iba z aktívneho / zlyhaného).
CREATE FUNCTION oom_plan_row_guard() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.oom_id <> OLD.oom_id OR NEW.kind <> OLD.kind
     OR NEW.company_id IS DISTINCT FROM OLD.company_id OR NEW.person_id IS DISTINCT FROM OLD.person_id THEN
    RAISE EXCEPTION 'Druh, odberné miesto a odberateľ plánu sa nemenia (zrušte plán a zadajte nový).'
      USING ERRCODE = 'check_violation';
  END IF;
  IF OLD.status IN ('vykonana', 'zrusena') THEN
    RAISE EXCEPTION 'Vykonaný alebo zrušený plán sa nemení.' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_row_guard BEFORE UPDATE ON oom_planned_change
  FOR EACH ROW EXECUTE FUNCTION oom_plan_row_guard();

-- ============================================================================
-- Nočný beh: splatné plány, potom aktivácia Pripravovaných OOM
-- ============================================================================

-- K dátumu: iba testy a údržba (aplikácia nesmie zadať dátum). Vráti počty.
CREATE FUNCTION oom_daily_run_at(p_today date) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_id     uuid;
  v_done   integer := 0;
  v_failed integer := 0;
BEGIN
  FOR v_id IN SELECT id FROM oom_planned_change
               WHERE status = 'planovana' AND oom_plan_due_on(kind, effective_date) <= p_today
               ORDER BY effective_date, created_at LOOP
    IF oom_plan_execute(v_id) THEN v_done := v_done + 1; ELSE v_failed := v_failed + 1; END IF;
  END LOOP;
  RETURN jsonb_build_object('plany_vykonane', v_done, 'plany_zlyhali', v_failed,
                            'aktivovane', oom_activate_due_at(p_today));
END;
$$;
REVOKE EXECUTE ON FUNCTION oom_daily_run_at(date) FROM PUBLIC;

-- Denný beh (Cron na Workeri) k dnešku v Europe/Bratislava.
CREATE FUNCTION oom_daily_run() RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT oom_daily_run_at(crm_today())
$$;

-- ============================================================================
-- EIC v histórii väzieb (Peter 12. 10., odpoveď 2)
-- ============================================================================

-- EIC, názov a obec OOM pre toho, kto vidí OOM alebo zákazníka niektorej jeho väzby.
CREATE FUNCTION oom_brief(p_oom_id uuid) RETURNS TABLE (eic text, name text, address_city text, type oom_type)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT o.eic, o.name, o.address_city, o.type
    FROM oom o
   WHERE o.id = p_oom_id
     AND (crm_oom_access(o.id, 'view')
          OR EXISTS (SELECT 1 FROM oom_customer l
                      WHERE l.oom_id = o.id
                        AND (crm_company_access(l.company_id, 'view') OR crm_contact_access(l.person_id, 'view'))))
$$;

-- ============================================================================
-- Zoznam OOM: plánovaná zmena a zlyhaný plán
-- ============================================================================

CREATE OR REPLACE VIEW oom_v WITH (security_invoker = true) AS
SELECT o.id,
       o.eic,
       o.name,
       o.address_street,
       o.address_number_supisne,
       o.address_number_orientacne,
       o.address_city,
       o.address_zip,
       o.type,
       o.status,
       o.company_id,
       o.person_id,
       CASE WHEN o.company_id IS NOT NULL THEN 'B2B' ELSE 'B2C' END AS customer_type,
       coalesce(c.name, nullif(concat_ws(' ', p.first_name, p.last_name), '')) AS customer_name,
       coalesce(c.owner_id, p.owner_id) AS owner_id,
       u.name AS owner_name,
       o.org_id,
       o.pds,
       pv.label AS pds_label,
       o.pds_tariff,
       tv.label AS pds_tariff_label,
       o.voltage_level,
       CASE WHEN o.type = 'vyroba' THEN o.planned_feed_in_mwh
            WHEN o.planned_consumption_vt_mwh IS NULL AND o.planned_consumption_nt_mwh IS NULL THEN NULL
            ELSE coalesce(o.planned_consumption_vt_mwh, 0) + coalesce(o.planned_consumption_nt_mwh, 0)
       END AS planned_mwh,
       o.supply_from,
       o.supply_to,
       o.switch_notice_required,
       o.switch_notice_sent_on,
       o.switch_notice_accepted_on,
       o.switch_confirmed_on,
       (o.status = 'pripravovane' AND (
            (o.switch_notice_sent_on IS NOT NULL AND o.switch_notice_accepted_on IS NULL
             AND o.switch_notice_sent_on + g.oom_switch_accept_days < crm_today())
         OR (o.switch_notice_accepted_on IS NOT NULL AND o.switch_confirmed_on IS NULL
             AND o.switch_notice_accepted_on + g.oom_switch_confirm_days < crm_today()))) AS switch_stuck,
       CASE WHEN o.status = 'pripravovane' THEN oom_active_required_missing(o) END AS active_missing,
       prev.customer_name AS transferred_from_name,
       prev.valid_to + 1  AS transferred_on,
       o.custom,
       o.created_at,
       o.updated_at,
       -- 0016: aktívny plán a posledný zlyhaný plán
       pl.kind           AS plan_kind,
       pl.effective_date AS plan_date,
       pl.id             AS plan_id,
       EXISTS (SELECT 1 FROM oom_planned_change f WHERE f.oom_id = o.id AND f.status = 'zlyhala') AS plan_failed
  FROM oom o
  JOIN org g ON g.id = o.org_id
  LEFT JOIN company c ON c.id = o.company_id
  LEFT JOIN contact p ON p.id = o.person_id
  LEFT JOIN app_user u ON u.id = coalesce(c.owner_id, p.owner_id)
  LEFT JOIN lookup_value pv ON pv.list_code = 'pds' AND pv.code = o.pds
  LEFT JOIN lookup_value tv ON tv.list_code = 'sadzba_distribucie' AND tv.code = o.pds_tariff
  LEFT JOIN LATERAL (
    SELECT coalesce(pc.name, nullif(concat_ws(' ', pp.first_name, pp.last_name), '')) AS customer_name, l.valid_to
      FROM oom_customer l
      LEFT JOIN company pc ON pc.id = l.company_id
      LEFT JOIN contact pp ON pp.id = l.person_id
     WHERE l.oom_id = o.id AND l.end_reason = 'prepis'
     ORDER BY l.valid_to DESC
     LIMIT 1
  ) prev ON true
  LEFT JOIN oom_planned_change pl ON pl.oom_id = o.id AND pl.status = 'planovana';

-- migrate:down

-- oom_v ako v 0014 (bez stĺpcov plánu): stĺpce na konci sa CREATE OR REPLACE nedajú odobrať
DROP VIEW oom_v;
CREATE VIEW oom_v WITH (security_invoker = true) AS
SELECT o.id,
       o.eic,
       o.name,
       o.address_street,
       o.address_number_supisne,
       o.address_number_orientacne,
       o.address_city,
       o.address_zip,
       o.type,
       o.status,
       o.company_id,
       o.person_id,
       CASE WHEN o.company_id IS NOT NULL THEN 'B2B' ELSE 'B2C' END AS customer_type,
       coalesce(c.name, nullif(concat_ws(' ', p.first_name, p.last_name), '')) AS customer_name,
       coalesce(c.owner_id, p.owner_id) AS owner_id,
       u.name AS owner_name,
       o.org_id,
       o.pds,
       pv.label AS pds_label,
       o.pds_tariff,
       tv.label AS pds_tariff_label,
       o.voltage_level,
       CASE WHEN o.type = 'vyroba' THEN o.planned_feed_in_mwh
            WHEN o.planned_consumption_vt_mwh IS NULL AND o.planned_consumption_nt_mwh IS NULL THEN NULL
            ELSE coalesce(o.planned_consumption_vt_mwh, 0) + coalesce(o.planned_consumption_nt_mwh, 0)
       END AS planned_mwh,
       o.supply_from,
       o.supply_to,
       o.switch_notice_required,
       o.switch_notice_sent_on,
       o.switch_notice_accepted_on,
       o.switch_confirmed_on,
       (o.status = 'pripravovane' AND (
            (o.switch_notice_sent_on IS NOT NULL AND o.switch_notice_accepted_on IS NULL
             AND o.switch_notice_sent_on + g.oom_switch_accept_days < crm_today())
         OR (o.switch_notice_accepted_on IS NOT NULL AND o.switch_confirmed_on IS NULL
             AND o.switch_notice_accepted_on + g.oom_switch_confirm_days < crm_today()))) AS switch_stuck,
       CASE WHEN o.status = 'pripravovane' THEN oom_active_required_missing(o) END AS active_missing,
       prev.customer_name AS transferred_from_name,
       prev.valid_to + 1  AS transferred_on,
       o.custom,
       o.created_at,
       o.updated_at
  FROM oom o
  JOIN org g ON g.id = o.org_id
  LEFT JOIN company c ON c.id = o.company_id
  LEFT JOIN contact p ON p.id = o.person_id
  LEFT JOIN app_user u ON u.id = coalesce(c.owner_id, p.owner_id)
  LEFT JOIN lookup_value pv ON pv.list_code = 'pds' AND pv.code = o.pds
  LEFT JOIN lookup_value tv ON tv.list_code = 'sadzba_distribucie' AND tv.code = o.pds_tariff
  LEFT JOIN LATERAL (
    SELECT coalesce(pc.name, nullif(concat_ws(' ', pp.first_name, pp.last_name), '')) AS customer_name, l.valid_to
      FROM oom_customer l
      LEFT JOIN company pc ON pc.id = l.company_id
      LEFT JOIN contact pp ON pp.id = l.person_id
     WHERE l.oom_id = o.id AND l.end_reason = 'prepis'
     ORDER BY l.valid_to DESC
     LIMIT 1
  ) prev ON true;
COMMENT ON VIEW oom_v IS 'zoznam OOM (obrazovka 17): zákazník a vlastník poslednej väzby, prechod sa zasekol (lehoty spoločnosti), chýbajúce údaje pre Aktívne, prepis od';

DROP FUNCTION IF EXISTS oom_brief(uuid);
DROP FUNCTION IF EXISTS oom_daily_run();
DROP FUNCTION IF EXISTS oom_daily_run_at(date);
DROP FUNCTION IF EXISTS oom_plan_cancel(uuid);
DROP FUNCTION IF EXISTS oom_plan_reschedule(uuid, date);
DROP FUNCTION IF EXISTS oom_plan_change(uuid, oom_plan_kind, date, uuid, uuid);
DROP FUNCTION IF EXISTS oom_plan_execute(uuid);

-- oom_transfer ako v 0015, oom_set_status ako v 0013 (bez kontroly plánu)
CREATE OR REPLACE FUNCTION oom_transfer(p_oom_id uuid, p_company_id uuid, p_person_id uuid, p_date date)
RETURNS uuid
LANGUAGE plpgsql AS $$
DECLARE
  v_link oom_customer;
  v_id   uuid;
BEGIN
  IF num_nonnulls(p_company_id, p_person_id) <> 1 THEN
    RAISE EXCEPTION 'oom_transfer: zadaj práve jedno z company_id / person_id';
  END IF;
  SELECT * INTO v_link FROM oom_customer WHERE oom_id = p_oom_id AND valid_to IS NULL FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Prepísať sa dá iba Pripravované alebo Aktívne odberné miesto.' USING ERRCODE = 'check_violation';
  END IF;
  IF (v_link.company_id, v_link.person_id) IS NOT DISTINCT FROM (p_company_id, p_person_id) THEN
    RAISE EXCEPTION 'Nový odberateľ je ten istý zákazník.' USING ERRCODE = 'check_violation';
  END IF;
  IF p_date <= v_link.valid_from THEN
    RAISE EXCEPTION 'Dátum prepisu musí byť po začiatku väzby (%).', v_link.valid_from USING ERRCODE = 'check_violation';
  END IF;

  UPDATE oom_customer SET valid_to = p_date - 1, end_reason = 'prepis', status = 'prepisane' WHERE id = v_link.id;
  PERFORM set_config('crm.oom_system', 'on', true);
  DELETE FROM oom_contact WHERE oom_id = p_oom_id;
  PERFORM set_config('crm.oom_system', '', true);
  INSERT INTO oom_customer (oom_id, company_id, person_id, org_id, valid_from, status)
  VALUES (p_oom_id, p_company_id, p_person_id, v_link.org_id, p_date, v_link.status)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION oom_set_status(p_oom_id uuid, p_status oom_status, p_date date DEFAULT crm_today())
RETURNS void
LANGUAGE plpgsql AS $$
DECLARE
  v_link oom_customer;
BEGIN
  SELECT * INTO v_link FROM oom_customer WHERE oom_id = p_oom_id AND valid_to IS NULL FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Odberné miesto nemá otvorenú väzbu (je Odídené, Zrušené alebo Prepísané).'
      USING ERRCODE = 'check_violation';
  END IF;
  CASE p_status
    WHEN 'aktivne' THEN
      UPDATE oom_customer SET status = 'aktivne' WHERE id = v_link.id;
    WHEN 'odidene' THEN
      UPDATE oom_customer SET valid_to = p_date, end_reason = 'odchod', status = 'odidene' WHERE id = v_link.id;
    WHEN 'zrusene' THEN
      UPDATE oom_customer SET valid_to = p_date, end_reason = 'zrusenie', status = 'zrusene' WHERE id = v_link.id;
    WHEN 'prepisane' THEN
      RAISE EXCEPTION 'Prepis na iného odberateľa: oom_transfer.' USING ERRCODE = 'check_violation';
    ELSE
      RAISE EXCEPTION 'Stav % sa takto nenastavuje.', p_status USING ERRCODE = 'check_violation';
  END CASE;
END;
$$;

DROP FUNCTION IF EXISTS oom_plan_guard(uuid);
DROP TABLE IF EXISTS oom_planned_change;
DROP FUNCTION IF EXISTS oom_plan_row_guard();
DROP FUNCTION IF EXISTS oom_plan_due_on(oom_plan_kind, date);
DROP TYPE IF EXISTS oom_plan_status;
DROP TYPE IF EXISTS oom_plan_kind;
