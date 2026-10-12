-- 0014_oom_stav_zakaznika.sql – modul Odberné miesta: stav zákazníka a pohľady
-- (docs/moduly/02-odberne-miesta-navrh-db.md v0.3, časti 3.2, 3.3, 4.4)
--
-- Prepínač app_setting.customer_status_auto (predvolene vypnutý): zapnutý = stav zákazníka, príznak
--   „bývalý“ a segment „výrobca“ sa prepočítajú pri každej zmene väzby OOM – zákazník a typu OOM.
--   Na dev sa zapne po migrácii (db/app-setting.sh), na main až s modulom Zmluvy (Peter 12. 10.).
-- Firma s OOM dostane označenie „zákazník“, osoba s OOM je domácnosť – vždy, bez ohľadu na prepínač.
-- Segment „výrobca“: OOM výroba v stave Aktívne, Pripravované alebo Odídené, alebo otvorený či vyhraný
--   deal v pipeline B2B výkup (Peter 12. 10., odpoveď 1).
-- Aktivácia Pripravovaných OOM (zmena dodávateľa potvrdená, začiatok dodávky nastal, povinné údaje):
--   hneď pri uložení a denne cez Cron (oom_activate_due); audit „Systém“.
-- Pohľady: customer_v (aktívne OOM z väzieb), contact_oom_v (kontaktné osoby pri OOM + osoby z dealov),
--   oom_v (zoznam OOM: zákazník, vlastník, PDS, objem, prechod sa zasekol, chýbajúce údaje, prepis od).

-- migrate:up

-- ============================================================================
-- Nastavenia systému
-- ============================================================================

CREATE TABLE app_setting (
  key          text PRIMARY KEY CHECK (key ~ '^[a-z][a-z0-9_]{1,62}$'),
  id           uuid NOT NULL UNIQUE DEFAULT gen_random_uuid(),   -- pre audit (record_id)
  value        jsonb NOT NULL,
  description  text NOT NULL,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE app_setting IS 'nastavenia systému podľa prostredia (Test / Ostré); mení ich iba vlastník databázy (db/app-setting.sh)';
INSERT INTO app_setting (key, value, description) VALUES
  ('customer_status_auto', 'false',
   'Priebežný prepočet stavu zákazníka pri zmene OOM. Na Ostrom vypnutý až do modulu Zmluvy.');

ALTER TABLE app_setting ENABLE ROW LEVEL SECURITY;
CREATE POLICY settings_read ON app_setting FOR SELECT USING ((SELECT crm_session_ok()));
CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON app_setting FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_audit AFTER INSERT OR UPDATE OR DELETE ON app_setting FOR EACH ROW EXECUTE FUNCTION audit_row();

CREATE FUNCTION crm_setting_on(p_key text) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT coalesce((SELECT value = 'true'::jsonb FROM app_setting WHERE key = p_key), false)
$$;

-- ============================================================================
-- Výpočet: segment „výrobca“, prepočet zákazníka
-- ============================================================================

CREATE FUNCTION customer_is_producer_calc(p_company_id uuid, p_person_id uuid) RETURNS boolean
LANGUAGE sql STABLE AS $$
  SELECT EXISTS (SELECT 1 FROM oom_customer l JOIN oom o ON o.id = l.oom_id
                  WHERE l.company_id IS NOT DISTINCT FROM p_company_id
                    AND l.person_id IS NOT DISTINCT FROM p_person_id
                    AND o.type = 'vyroba'
                    AND l.status IN ('aktivne', 'pripravovane', 'odidene'))
      OR EXISTS (SELECT 1 FROM deal d
                   JOIN pipeline pl ON pl.id = d.pipeline_id
                   JOIN pipeline_stage s ON s.id = d.stage_id AND s.pipeline_id = d.pipeline_id
                  WHERE d.company_id IS NOT DISTINCT FROM p_company_id
                    AND d.person_id IS NOT DISTINCT FROM p_person_id
                    AND pl.kind = 'b2b_vykup'
                    AND s.outcome IN ('otvoreny', 'vyhrany'))
$$;

-- Zmena vypočítaná systémom: audit so zdrojom „Systém“, potom pôvodný zdroj.
CREATE FUNCTION crm_as_system(p_on boolean) RETURNS text
LANGUAGE plpgsql AS $$
DECLARE
  v_prev text := current_setting('app.change_source', true);
BEGIN
  PERFORM set_config('app.change_source', CASE WHEN p_on THEN 'system' ELSE '' END, true);
  RETURN coalesce(v_prev, '');
END;
$$;

-- Prepočet jedného zákazníka (firma s označením zákazník, alebo domácnosť). true = niečo sa zmenilo.
-- Príznak „bývalý“ sa nikdy automaticky nezruší (zadanie Zákazníci čl. 3, 13).
CREATE FUNCTION customer_refresh(p_company_id uuid, p_person_id uuid) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_status   customer_status;
  v_former   boolean;
  v_producer boolean;
  v_prev     text;
  v_changed  boolean;
BEGIN
  IF num_nonnulls(p_company_id, p_person_id) <> 1 THEN
    RAISE EXCEPTION 'customer_refresh: zadaj práve jedno z company_id / person_id';
  END IF;
  v_status   := customer_status_calc(p_company_id, p_person_id);
  v_former   := customer_is_former_calc(p_company_id, p_person_id);
  v_producer := customer_is_producer_calc(p_company_id, p_person_id);
  v_prev     := crm_as_system(true);

  IF p_company_id IS NOT NULL THEN
    UPDATE company c
       SET status = v_status, status_source = 'vypocet',
           is_former_customer = c.is_former_customer OR v_former, is_producer = v_producer
     WHERE c.id = p_company_id AND c.is_customer
       AND (c.status, c.status_source, c.is_former_customer, c.is_producer)
           IS DISTINCT FROM (v_status, 'vypocet'::status_source, c.is_former_customer OR v_former, v_producer);
  ELSE
    UPDATE contact p
       SET status = v_status, status_source = 'vypocet',
           is_former_customer = p.is_former_customer OR v_former, is_producer = v_producer
     WHERE p.id = p_person_id AND p.is_household
       AND (p.status, p.status_source, p.is_former_customer, p.is_producer)
           IS DISTINCT FROM (v_status, 'vypocet'::status_source, p.is_former_customer OR v_former, v_producer);
  END IF;
  v_changed := FOUND;

  PERFORM set_config('app.change_source', v_prev, true);
  RETURN v_changed;
END;
$$;

-- Prepočet všetkých zákazníkov (pri zapnutí prepínača). Vráti počet zmenených.
-- Príklad: SELECT customer_refresh_all();
CREATE FUNCTION customer_refresh_all() RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_id uuid;
  v_n  integer := 0;
BEGIN
  FOR v_id IN SELECT id FROM company WHERE is_customer LOOP
    IF customer_refresh(v_id, NULL) THEN v_n := v_n + 1; END IF;
  END LOOP;
  FOR v_id IN SELECT id FROM contact WHERE is_household LOOP
    IF customer_refresh(NULL, v_id) THEN v_n := v_n + 1; END IF;
  END LOOP;
  RETURN v_n;
END;
$$;
REVOKE EXECUTE ON FUNCTION customer_refresh_all() FROM PUBLIC;

-- ============================================================================
-- Spúšťače: označenie zákazníka a prepočet pri zmene väzby a typu OOM
-- ============================================================================

-- Firma s OOM = zákazník, osoba s OOM = domácnosť (vždy, aj pri vypnutom prepínači).
CREATE FUNCTION oom_customer_mark() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_prev text := crm_as_system(true);
BEGIN
  UPDATE company SET is_customer = true WHERE id = NEW.company_id AND NOT is_customer;
  UPDATE contact SET is_household = true WHERE id = NEW.person_id AND NOT is_household;
  PERFORM set_config('app.change_source', v_prev, true);
  RETURN NULL;
END;
$$;
CREATE TRIGGER trg_customer_mark AFTER INSERT ON oom_customer
  FOR EACH ROW EXECUTE FUNCTION oom_customer_mark();

CREATE FUNCTION oom_customer_refresh() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT crm_setting_on('customer_status_auto') THEN
    RETURN NULL;
  END IF;
  IF TG_OP <> 'DELETE' THEN
    PERFORM customer_refresh(NEW.company_id, NEW.person_id);
  END IF;
  IF TG_OP <> 'INSERT' AND (TG_OP = 'DELETE' OR (OLD.company_id, OLD.person_id) IS DISTINCT FROM (NEW.company_id, NEW.person_id)) THEN
    PERFORM customer_refresh(OLD.company_id, OLD.person_id);
  END IF;
  RETURN NULL;
END;
$$;
CREATE TRIGGER trg_customer_refresh AFTER INSERT OR UPDATE OR DELETE ON oom_customer
  FOR EACH ROW EXECUTE FUNCTION oom_customer_refresh();

-- Zmena typu OOM (výroba ↔ spotreba) mení segment všetkých jeho zákazníkov.
CREATE FUNCTION oom_type_refresh() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_link record;
BEGIN
  IF crm_setting_on('customer_status_auto') THEN
    FOR v_link IN SELECT DISTINCT company_id, person_id FROM oom_customer WHERE oom_id = NEW.id LOOP
      PERFORM customer_refresh(v_link.company_id, v_link.person_id);
    END LOOP;
  END IF;
  RETURN NULL;
END;
$$;
CREATE TRIGGER trg_oom_type_refresh AFTER UPDATE OF type ON oom
  FOR EACH ROW WHEN (NEW.type IS DISTINCT FROM OLD.type) EXECUTE FUNCTION oom_type_refresh();

-- ============================================================================
-- Aktivácia Pripravovaných OOM (zadanie OOM čl. 4, 14; Peter 12. 10., odpovede 3 a 6)
-- ============================================================================

-- OOM je pripravené na aktiváciu: Pripravované, zmena dodávateľa potvrdená, začiatok dodávky nastal,
-- povinné údaje vyplnené.
CREATE FUNCTION oom_activation_ready(o oom, p_today date) RETURNS boolean
LANGUAGE sql STABLE AS $$
  SELECT o.status = 'pripravovane'
     AND o.switch_confirmed_on IS NOT NULL
     AND o.supply_from <= p_today
     AND cardinality(oom_active_required_missing(o)) = 0
$$;

-- Aktivuje všetky pripravené OOM k dátumu. Iba pre testy a údržbu (aplikácia nesmie zadať dátum).
CREATE FUNCTION oom_activate_due_at(p_today date) RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_id   uuid;
  v_n    integer := 0;
  v_prev text := crm_as_system(true);
BEGIN
  FOR v_id IN SELECT o.id FROM oom o WHERE oom_activation_ready(o, p_today) ORDER BY o.id LOOP
    PERFORM oom_set_status(v_id, 'aktivne');
    v_n := v_n + 1;
  END LOOP;
  PERFORM set_config('app.change_source', v_prev, true);
  RETURN v_n;
END;
$$;
REVOKE EXECUTE ON FUNCTION oom_activate_due_at(date) FROM PUBLIC;

-- Denná aktivácia (Cron na Workeri, dnešný dátum v Europe/Bratislava). Vráti počet aktivovaných OOM.
CREATE FUNCTION oom_activate_due() RETURNS integer
LANGUAGE sql SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT oom_activate_due_at(crm_today())
$$;

-- Okamžitá aktivácia pri uložení (Peter 12. 10., odpoveď 3). Názov spúšťača je zámerne až po
-- trg_oom_first_link (spúšťače AFTER idú podľa abecedy): pri založení už existuje väzba.
CREATE FUNCTION oom_activate_on_save() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_prev text;
BEGIN
  IF oom_activation_ready(NEW, crm_today()) THEN
    v_prev := crm_as_system(true);
    PERFORM oom_set_status(NEW.id, 'aktivne');
    PERFORM set_config('app.change_source', v_prev, true);
  END IF;
  RETURN NULL;
END;
$$;
CREATE TRIGGER trg_oom_prechod_aktivacia AFTER INSERT OR UPDATE ON oom
  FOR EACH ROW WHEN (NEW.status = 'pripravovane' AND NEW.switch_confirmed_on IS NOT NULL)
  EXECUTE FUNCTION oom_activate_on_save();

-- ============================================================================
-- Pohľady
-- ============================================================================

-- Zoznam Zákazníci: počet aktívnych OOM a ročný objem z otvorených väzieb (inak ako v 0008).
CREATE OR REPLACE VIEW customer_v WITH (security_invoker = true) AS
WITH oom_sum AS (
  SELECT l.company_id, l.person_id,
         count(*) AS active_oom_count,
         sum(coalesce(o.planned_consumption_vt_mwh, 0) + coalesce(o.planned_consumption_nt_mwh, 0)) AS annual_mwh
    FROM oom_customer l
    JOIN oom o ON o.id = l.oom_id
   WHERE l.valid_to IS NULL AND l.status = 'aktivne'
   GROUP BY l.company_id, l.person_id
), last_activity AS (
  SELECT a.company_id, a.contact_id, max(a.occurred_at) AS last_activity_at
    FROM activity a
   GROUP BY a.company_id, a.contact_id
)
SELECT c.id,
       'B2B'::text AS customer_type,
       c.id        AS company_id,
       NULL::uuid  AS person_id,
       c.name,
       c.ico,
       NULL::text  AS email,
       c.status,
       c.status_source,
       c.is_former_customer,
       c.is_producer,
       CASE WHEN c.is_producer THEN 'Firma · výrobca' ELSE 'Firma' END AS segment_label,
       c.owner_id,
       coalesce(s.active_oom_count, 0) AS active_oom_count,
       coalesce(s.annual_mwh, 0)       AS annual_mwh,
       (SELECT max(la.last_activity_at) FROM last_activity la WHERE la.company_id = c.id) AS last_activity_at,
       company_is_archived(c) AS archived,
       c.org_id,
       c.country
  FROM company c
  LEFT JOIN oom_sum s ON s.company_id = c.id
 WHERE c.is_customer
UNION ALL
SELECT p.id,
       'B2C'::text,
       NULL::uuid,
       p.id,
       concat_ws(' ', p.first_name, p.last_name),
       NULL::text,
       p.email,
       p.status,
       p.status_source,
       p.is_former_customer,
       p.is_producer,
       CASE WHEN p.is_producer THEN 'Domácnosť · výrobca' ELSE 'Domácnosť' END,
       p.owner_id,
       coalesce(s.active_oom_count, 0),
       coalesce(s.annual_mwh, 0),
       (SELECT max(la.last_activity_at) FROM last_activity la WHERE la.contact_id = p.id),
       p.status IS NOT DISTINCT FROM 'zruseny_zakaznik',
       p.org_id,
       NULL::country_code
  FROM contact p
  LEFT JOIN oom_sum s ON s.person_id = p.id
 WHERE p.is_household
   -- „iba svoje“ vidí domácnosť iba ako jej vlastník (nie osobu, ktorá je len kontaktom na jeho firme)
   AND ((SELECT crm_scope('zakaznici', 'view')) = 'vsetko' OR p.owner_id = (SELECT crm_active_user_id()));

-- Osoba ↔ OOM: kontaktné osoby pri OOM (ručne, neskôr zo zmluvy) a osoby na dealoch s OOM;
-- iba OOM v stave Aktívne alebo Pripravované (CLAUDE.md, doménové pravidlá).
CREATE OR REPLACE VIEW contact_oom_v WITH (security_invoker = true) AS
WITH links AS (
  SELECT oc.contact_id, oc.oom_id, NULL::uuid AS deal_id, oc.source::text AS source
    FROM oom_contact oc
  UNION ALL
  SELECT dc.contact_id, dom.oom_id, dc.deal_id, 'deal'
    FROM deal_contact dc
    JOIN deal_oom dom ON dom.deal_id = dc.deal_id
)
SELECT l.contact_id,
       l.oom_id,
       o.status AS oom_status,
       coalesce(array_agg(DISTINCT l.deal_id) FILTER (WHERE l.deal_id IS NOT NULL), '{}') AS deal_ids,
       coalesce(max(oc.roles), '{}') AS roles,
       array_agg(DISTINCT l.source ORDER BY l.source) AS sources
  FROM links l
  JOIN oom o ON o.id = l.oom_id
  LEFT JOIN oom_contact oc ON oc.oom_id = l.oom_id AND oc.contact_id = l.contact_id
 WHERE o.status IN ('aktivne', 'pripravovane')
 GROUP BY l.contact_id, l.oom_id, o.status;
COMMENT ON VIEW contact_oom_v IS 'osoba ↔ OOM: sources = rucne, zmluva (oom_contact) a deal (osoba na deale s OOM); iba Aktívne a Pripravované';

-- Zoznam OOM (obrazovka 17)
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
       -- prechod sa zasekol: výpoveď bez akceptácie / akceptácia bez potvrdenia zmeny dlhšie ako lehota spoločnosti
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
    -- predošlý zákazník pri prepise (meno iba tomu, kto ho smie vidieť)
    SELECT coalesce(pc.name, nullif(concat_ws(' ', pp.first_name, pp.last_name), '')) AS customer_name, l.valid_to
      FROM oom_customer l
      LEFT JOIN company pc ON pc.id = l.company_id
      LEFT JOIN contact pp ON pp.id = l.person_id
     WHERE l.oom_id = o.id AND l.end_reason = 'prepis'
     ORDER BY l.valid_to DESC
     LIMIT 1
  ) prev ON true;
COMMENT ON VIEW oom_v IS 'zoznam OOM (obrazovka 17): zákazník a vlastník poslednej väzby, prechod sa zasekol (lehoty spoločnosti), chýbajúce údaje pre Aktívne, prepis od';

-- migrate:down

DROP VIEW IF EXISTS oom_v;

DROP VIEW IF EXISTS contact_oom_v;
CREATE VIEW contact_oom_v AS
SELECT dc.contact_id,
       dom.oom_id,
       o.status AS oom_status,
       array_agg(DISTINCT dc.deal_id) AS deal_ids
  FROM deal_contact dc
  JOIN deal_oom dom ON dom.deal_id = dc.deal_id
  JOIN oom o        ON o.id = dom.oom_id
 WHERE o.status IN ('aktivne', 'pripravovane')
 GROUP BY dc.contact_id, dom.oom_id, o.status;

CREATE OR REPLACE VIEW customer_v WITH (security_invoker = true) AS
WITH oom_sum AS (
  SELECT o.company_id, o.person_id,
         count(*) FILTER (WHERE o.status = 'aktivne') AS active_oom_count,
         sum(coalesce(o.planned_consumption_vt_mwh, 0) + coalesce(o.planned_consumption_nt_mwh, 0))
           FILTER (WHERE o.status = 'aktivne') AS annual_mwh
    FROM oom o
   GROUP BY o.company_id, o.person_id
), last_activity AS (
  SELECT a.company_id, a.contact_id, max(a.occurred_at) AS last_activity_at
    FROM activity a
   GROUP BY a.company_id, a.contact_id
)
SELECT c.id,
       'B2B'::text AS customer_type,
       c.id        AS company_id,
       NULL::uuid  AS person_id,
       c.name,
       c.ico,
       NULL::text  AS email,
       c.status,
       c.status_source,
       c.is_former_customer,
       c.is_producer,
       CASE WHEN c.is_producer THEN 'Firma · výrobca' ELSE 'Firma' END AS segment_label,
       c.owner_id,
       coalesce(s.active_oom_count, 0) AS active_oom_count,
       coalesce(s.annual_mwh, 0)       AS annual_mwh,
       (SELECT max(la.last_activity_at) FROM last_activity la WHERE la.company_id = c.id) AS last_activity_at,
       company_is_archived(c) AS archived,
       c.org_id,
       c.country
  FROM company c
  LEFT JOIN oom_sum s ON s.company_id = c.id
 WHERE c.is_customer
UNION ALL
SELECT p.id,
       'B2C'::text,
       NULL::uuid,
       p.id,
       concat_ws(' ', p.first_name, p.last_name),
       NULL::text,
       p.email,
       p.status,
       p.status_source,
       p.is_former_customer,
       p.is_producer,
       CASE WHEN p.is_producer THEN 'Domácnosť · výrobca' ELSE 'Domácnosť' END,
       p.owner_id,
       coalesce(s.active_oom_count, 0),
       coalesce(s.annual_mwh, 0),
       (SELECT max(la.last_activity_at) FROM last_activity la WHERE la.contact_id = p.id),
       p.status IS NOT DISTINCT FROM 'zruseny_zakaznik',
       p.org_id,
       NULL::country_code
  FROM contact p
  LEFT JOIN oom_sum s ON s.person_id = p.id
 WHERE p.is_household
   AND ((SELECT crm_scope('zakaznici', 'view')) = 'vsetko' OR p.owner_id = (SELECT crm_active_user_id()));

DROP TRIGGER IF EXISTS trg_oom_prechod_aktivacia ON oom;
DROP FUNCTION IF EXISTS oom_activate_on_save();
DROP FUNCTION IF EXISTS oom_activate_due();
DROP FUNCTION IF EXISTS oom_activate_due_at(date);
DROP FUNCTION IF EXISTS oom_activation_ready(oom, date);

DROP TRIGGER IF EXISTS trg_oom_type_refresh ON oom;
DROP FUNCTION IF EXISTS oom_type_refresh();
DROP TRIGGER IF EXISTS trg_customer_refresh ON oom_customer;
DROP FUNCTION IF EXISTS oom_customer_refresh();
DROP TRIGGER IF EXISTS trg_customer_mark ON oom_customer;
DROP FUNCTION IF EXISTS oom_customer_mark();

DROP FUNCTION IF EXISTS customer_refresh_all();
DROP FUNCTION IF EXISTS customer_refresh(uuid, uuid);
DROP FUNCTION IF EXISTS crm_as_system(boolean);
DROP FUNCTION IF EXISTS customer_is_producer_calc(uuid, uuid);

DROP FUNCTION IF EXISTS crm_setting_on(text);
DROP TABLE IF EXISTS app_setting;
