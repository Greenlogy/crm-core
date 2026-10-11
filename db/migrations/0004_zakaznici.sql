-- 0004_zakaznici.sql – modul Zákazníci (docs/moduly/01-zakaznici.md v0.3)
--
-- Firma: povinné IČO, označenia zákazník / partner / dodávateľ (aj viac naraz),
-- stav zákazníka s východiskovou hodnotou z HubSpotu, príznaky bývalý a výrobca.
-- Osoba: povinné meno a kontakt, normalizovaný telefón na kontrolu duplicít,
-- príznak domácnosti, stav, „nechce marketing“.
-- Firma – osoba: viac rolí naraz, jeden hlavný kontakt firmy.
-- Vlastníka mení iba vedenie (alebo rola synchronizácie crm_sync).
-- Výpočet stavu (customer_status_calc) je pripravený, ale ešte sa nevolá automaticky:
-- priebežný prepočet zapnú moduly OOM a Zmluvy (zadanie čl. 11.4).
-- RLS pre externého obchodníka je v 0005.
--
-- Predpoklad: tabuľky company, contact a company_contact sú prázdne
-- (na dev sa najprv zmaže vzorka prototypu, main je prázdny).

-- migrate:up

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM company) OR EXISTS (SELECT 1 FROM contact) THEN
    RAISE EXCEPTION 'Migrácia 0004 vyžaduje prázdne tabuľky company a contact (najprv zmazať vzorku prototypu).';
  END IF;
END;
$$;

-- customer_v z 0001 závisí od rušených stĺpcov; nový je na konci.
DROP VIEW customer_v;

-- ============================================================================
-- Enumy
-- ============================================================================

CREATE TYPE customer_status AS ENUM (
  'marketingovy_kontakt', 'zaujemca', 'ponuka', 'cakajuci_zakaznik',
  'zakaznik', 'byvaly_zakaznik', 'zruseny_zakaznik'
);
-- hubspot = východisková hodnota pri nahratí, vypocet = vypočítal CRM
CREATE TYPE status_source AS ENUM ('hubspot', 'vypocet');
CREATE TYPE company_role AS ENUM ('statutar', 'decision_maker', 'kontaktna_osoba', 'fakturacia', 'technik');
-- Politiky RLS s touto hodnotou sú v 0005 (novú hodnotu enumu nemožno použiť v tej istej transakcii).
ALTER TYPE app_user_role ADD VALUE 'externy_obchodnik';

-- ============================================================================
-- Pomocné funkcie
-- ============================================================================

-- Telefón na tvar +421…: '0905 123 456', '+421 905 123 456', '00421905123456' → '+421905123456'.
CREATE FUNCTION normalize_phone(p text) RETURNS text
LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
  SELECT CASE
           WHEN d IS NULL OR d = '' OR d = '+' THEN NULL
           WHEN d LIKE '+%'  THEN '+' || replace(substr(d, 2), '+', '')
           WHEN d LIKE '00%' THEN '+' || substr(d, 3)
           WHEN d LIKE '421%' AND length(d) = 12 THEN '+' || d
           WHEN d LIKE '0%'  THEN '+421' || substr(d, 2)
           WHEN length(d) = 9 THEN '+421' || d
           ELSE d
         END
    FROM (SELECT regexp_replace(p, '[^0-9+]', '', 'g') AS d) x
$$;

-- Kto je prihlásený: API nastaví v každej transakcii SET LOCAL app.user_id = '<uuid>'
-- (to isté používa audit). Rola aplikácie má navyše app.require_user = 'on' (pozri 0005).
CREATE FUNCTION crm_current_user_id() RETURNS uuid
LANGUAGE sql STABLE AS $$
  SELECT nullif(current_setting('app.user_id', true), '')::uuid
$$;

-- true = vidí všetko (interný používateľ, alebo rola bez povinného používateľa)
CREATE FUNCTION crm_sees_all() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT CASE
           WHEN crm_current_user_id() IS NULL
             THEN coalesce(current_setting('app.require_user', true), '') <> 'on'
           ELSE EXISTS (SELECT 1 FROM app_user u
                         WHERE u.id = crm_current_user_id()
                           AND u.active
                           AND u.role::text <> 'externy_obchodnik')
         END
$$;

-- id prihláseného externého obchodníka, inak NULL
CREATE FUNCTION crm_external_user_id() RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT u.id FROM app_user u
   WHERE u.id = crm_current_user_id()
     AND u.active
     AND u.role::text = 'externy_obchodnik'
$$;

-- ============================================================================
-- Firma
-- ============================================================================

ALTER TABLE company
  DROP CONSTRAINT company_segment_check,
  DROP COLUMN segment,
  DROP COLUMN lifecycle_stage,
  ALTER COLUMN ico SET NOT NULL,
  ADD COLUMN is_customer         boolean NOT NULL DEFAULT true,
  ADD COLUMN is_partner          boolean NOT NULL DEFAULT false,
  ADD COLUMN is_supplier         boolean NOT NULL DEFAULT false,
  ADD COLUMN status              customer_status,
  ADD COLUMN status_source       status_source,
  ADD COLUMN status_changed_at   timestamptz,
  ADD COLUMN is_former_customer  boolean NOT NULL DEFAULT false,
  ADD COLUMN is_producer         boolean NOT NULL DEFAULT false,
  ADD CONSTRAINT company_name_check CHECK (btrim(name) <> ''),
  ADD CONSTRAINT company_kind_check CHECK (is_customer OR is_partner OR is_supplier),
  ADD CONSTRAINT company_status_source_check CHECK ((status IS NULL) = (status_source IS NULL));

DROP INDEX company_ico_key;
CREATE UNIQUE INDEX company_ico_key ON company (ico);
CREATE INDEX company_status_idx ON company (status) WHERE is_customer;

COMMENT ON COLUMN company.is_customer IS 'označenie zákazník (predvolené); firma môže mať viac označení';
COMMENT ON COLUMN company.is_partner IS 'označenie partner; partner bez is_customer nie je v zozname Zákazníci';
COMMENT ON COLUMN company.is_supplier IS 'označenie dodávateľ; dodávateľ bez is_customer nie je v zozname Zákazníci';
COMMENT ON COLUMN company.status IS 'stav zákazníka (čl. 4 zadania); NULL, ak firma nie je zákazník';
COMMENT ON COLUMN company.is_former_customer IS 'príznak „bývalý“: mal odídené OOM; automaticky sa nezruší';
COMMENT ON COLUMN company.is_producer IS 'segment „+ výrobca“';

-- ============================================================================
-- Osoba
-- ============================================================================

ALTER TABLE contact
  DROP COLUMN segment,
  DROP COLUMN lifecycle_stage,
  ADD COLUMN phone_norm                text GENERATED ALWAYS AS (normalize_phone(phone)) STORED,
  ADD COLUMN mobile_norm               text GENERATED ALWAYS AS (normalize_phone(mobile)) STORED,
  ADD COLUMN is_household              boolean NOT NULL,
  ADD COLUMN status                    customer_status,
  ADD COLUMN status_source             status_source,
  ADD COLUMN status_changed_at         timestamptz,
  ADD COLUMN is_former_customer        boolean NOT NULL DEFAULT false,
  ADD COLUMN is_producer               boolean NOT NULL DEFAULT false,
  ADD COLUMN marketing_opt_out_at      timestamptz,
  ADD COLUMN marketing_opt_out_source  text,
  ADD CONSTRAINT contact_name_check
    CHECK (btrim(first_name) <> '' AND btrim(last_name) <> ''),
  ADD CONSTRAINT contact_reachable_check
    CHECK (num_nonnulls(nullif(btrim(email), ''), nullif(btrim(phone), ''), nullif(btrim(mobile), '')) >= 1),
  ADD CONSTRAINT contact_email_format_check
    CHECK (email ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'),
  ADD CONSTRAINT contact_status_source_check CHECK ((status IS NULL) = (status_source IS NULL)),
  ADD CONSTRAINT contact_marketing_opt_out_check
    CHECK ((marketing_opt_out_at IS NULL) = (marketing_opt_out_source IS NULL));

-- meno a priezvisko povinné (CHECK pustí NULL)
ALTER TABLE contact
  ALTER COLUMN first_name SET NOT NULL,
  ALTER COLUMN last_name SET NOT NULL;

-- Kontrola duplicít (čl. 7): CRM upozorní, unikátnosť sa nevynucuje.
DROP INDEX contact_email_idx;
CREATE INDEX contact_email_idx ON contact (lower(btrim(email)));
CREATE INDEX contact_phone_norm_idx ON contact (phone_norm);
CREATE INDEX contact_mobile_norm_idx ON contact (mobile_norm);
CREATE INDEX contact_status_idx ON contact (status) WHERE is_household;

COMMENT ON COLUMN contact.is_household IS 'osoba je zákazník za domácnosť (aj marketingový kontakt bez firmy); false = iba kontakt vo firme; automaticky sa nikdy nezruší';
COMMENT ON COLUMN contact.status IS 'stav zákazníka (čl. 4 zadania); NULL, ak osoba nie je domácnosť';
COMMENT ON COLUMN contact.marketing_opt_out_at IS '„nechce marketing“ od (čl. 8); plné súhlasy prídu v module Marketing';
COMMENT ON COLUMN contact.marketing_opt_out_source IS 'zdroj „nechce marketing“, napr. hubspot, brevo, telefon, email';

-- ============================================================================
-- Firma – osoba
-- ============================================================================

DROP INDEX company_contact_one_primary_key;
ALTER TABLE company_contact
  DROP COLUMN is_primary,
  DROP COLUMN role,
  ADD COLUMN roles            company_role[] NOT NULL DEFAULT '{}',
  ADD COLUMN is_main_contact  boolean NOT NULL DEFAULT false;
DROP TYPE company_contact_role;

-- Firma má najviac jeden hlavný kontakt; „aspoň jeden“ hlási CRM ako upozornenie.
CREATE UNIQUE INDEX company_contact_one_main_key ON company_contact (company_id) WHERE is_main_contact;
COMMENT ON COLUMN company_contact.roles IS 'roly osoby vo firme, aj viac naraz';

-- ============================================================================
-- Stav: predvolená hodnota, čas zmeny, príznak „bývalý“
-- ============================================================================

-- Zákazník (firma s is_customer, osoba s is_household) bez stavu dostane marketingovy_kontakt.
-- Pri každej zmene stavu sa zapíše status_changed_at (pri nahratí z HubSpotu sa môže zadať).
-- Stav byvaly_zakaznik nastaví príznak is_former_customer.
CREATE FUNCTION customer_status_track() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  v_is_customer boolean := CASE TG_TABLE_NAME
                             WHEN 'company' THEN (to_jsonb(NEW) ->> 'is_customer')::boolean
                             ELSE (to_jsonb(NEW) ->> 'is_household')::boolean
                           END;
BEGIN
  IF v_is_customer AND NEW.status IS NULL THEN
    NEW.status := 'marketingovy_kontakt';
    NEW.status_source := 'vypocet';
  END IF;

  IF TG_OP = 'INSERT' THEN
    IF NEW.status IS NOT NULL AND NEW.status_changed_at IS NULL THEN
      NEW.status_changed_at := now();
    END IF;
  ELSIF NEW.status IS DISTINCT FROM OLD.status THEN
    NEW.status_changed_at := now();
  END IF;

  IF NEW.status = 'byvaly_zakaznik' THEN
    NEW.is_former_customer := true;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_customer_status BEFORE INSERT OR UPDATE ON company
  FOR EACH ROW EXECUTE FUNCTION customer_status_track();
CREATE TRIGGER trg_customer_status BEFORE INSERT OR UPDATE ON contact
  FOR EACH ROW EXECUTE FUNCTION customer_status_track();

-- Osoba, ktorá sa stane zákazníkom na deale, OOM alebo zmluve, je domácnosť (čl. 3).
CREATE FUNCTION mark_household() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.person_id IS NOT NULL THEN
    UPDATE contact SET is_household = true WHERE id = NEW.person_id AND NOT is_household;
  END IF;
  RETURN NULL;
END;
$$;

CREATE TRIGGER trg_mark_household AFTER INSERT OR UPDATE OF person_id ON deal
  FOR EACH ROW EXECUTE FUNCTION mark_household();
CREATE TRIGGER trg_mark_household AFTER INSERT OR UPDATE OF person_id ON oom
  FOR EACH ROW EXECUTE FUNCTION mark_household();
CREATE TRIGGER trg_mark_household AFTER INSERT OR UPDATE OF person_id ON contract
  FOR EACH ROW EXECUTE FUNCTION mark_household();

-- ============================================================================
-- Výpočet stavu (čl. 4, 12, 13) – zatiaľ sa nevolá automaticky
-- ============================================================================

-- Zákazník = práve jedno z p_company_id / p_person_id. Poradie pri súbehu:
-- Zákazník > Čakajúci > Ponuka > Záujemca > Bývalý > Zrušený > Marketingový kontakt.
CREATE FUNCTION customer_status_calc(
  p_company_id uuid,
  p_person_id  uuid,
  p_today      date DEFAULT (now() AT TIME ZONE 'Europe/Bratislava')::date
) RETURNS customer_status
LANGUAGE plpgsql STABLE AS $$
BEGIN
  IF num_nonnulls(p_company_id, p_person_id) <> 1 THEN
    RAISE EXCEPTION 'customer_status_calc: zadaj práve jedno z company_id / person_id';
  END IF;

  -- 1. aspoň jedno OOM Aktívne alebo Neaktívne
  IF EXISTS (SELECT 1 FROM oom o
              WHERE o.company_id IS NOT DISTINCT FROM p_company_id
                AND o.person_id IS NOT DISTINCT FROM p_person_id
                AND o.status IN ('aktivne', 'neaktivne')) THEN
    RETURN 'zakaznik';
  END IF;

  -- 2. podpísaná zmluva s budúcou účinnosťou (aj vracajúci sa zákazník)
  IF EXISTS (SELECT 1 FROM contract c
              WHERE c.company_id IS NOT DISTINCT FROM p_company_id
                AND c.person_id IS NOT DISTINCT FROM p_person_id
                AND c.status IN ('podpisana', 'caka_na_zaradenie', 'aktivna')
                AND c.valid_from > p_today) THEN
    RETURN 'cakajuci_zakaznik';
  END IF;

  -- 3. a 4. otvorený deal s odoslanou ponukou / bez nej
  IF EXISTS (SELECT 1 FROM deal d
               JOIN pipeline_stage s ON s.id = d.stage_id AND s.pipeline_id = d.pipeline_id
               JOIN offer f ON f.deal_id = d.id
              WHERE d.company_id IS NOT DISTINCT FROM p_company_id
                AND d.person_id IS NOT DISTINCT FROM p_person_id
                AND NOT s.is_closed
                AND (f.sent_at IS NOT NULL OR f.status <> 'koncept')) THEN
    RETURN 'ponuka';
  END IF;
  IF EXISTS (SELECT 1 FROM deal d
               JOIN pipeline_stage s ON s.id = d.stage_id AND s.pipeline_id = d.pipeline_id
              WHERE d.company_id IS NOT DISTINCT FROM p_company_id
                AND d.person_id IS NOT DISTINCT FROM p_person_id
                AND NOT s.is_closed) THEN
    RETURN 'zaujemca';
  END IF;

  -- 5. aspoň jedno OOM Odídené
  IF EXISTS (SELECT 1 FROM oom o
              WHERE o.company_id IS NOT DISTINCT FROM p_company_id
                AND o.person_id IS NOT DISTINCT FROM p_person_id
                AND o.status = 'odidene') THEN
    RETURN 'byvaly_zakaznik';
  END IF;

  -- 6. má OOM a všetky sú Zrušené alebo Prepísané
  IF EXISTS (SELECT 1 FROM oom o
              WHERE o.company_id IS NOT DISTINCT FROM p_company_id
                AND o.person_id IS NOT DISTINCT FROM p_person_id) THEN
    RETURN 'zruseny_zakaznik';
  END IF;

  -- 7. inak (aj záujemca, ktorému deal prepadol a nikdy nebol zákazník)
  RETURN 'marketingovy_kontakt';
END;
$$;

-- Príznak „bývalý“: mal niekedy odídené OOM (aj keď je dnes Ponuka alebo Čakajúci).
CREATE FUNCTION customer_is_former_calc(p_company_id uuid, p_person_id uuid) RETURNS boolean
LANGUAGE sql STABLE AS $$
  SELECT EXISTS (SELECT 1 FROM oom o
                  WHERE o.company_id IS NOT DISTINCT FROM p_company_id
                    AND o.person_id IS NOT DISTINCT FROM p_person_id
                    AND o.status = 'odidene')
$$;

-- ============================================================================
-- Vlastník: mení iba vedenie (čl. 6, 13)
-- ============================================================================

-- Výnimku má iba rola synchronizácie crm_sync (vytvorí sa samostatne, mimo migrácií).
CREATE FUNCTION owner_change_guard() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  v_role text;
BEGIN
  IF NEW.owner_id IS DISTINCT FROM OLD.owner_id AND current_user <> 'crm_sync' THEN
    SELECT u.role::text INTO v_role
      FROM app_user u
     WHERE u.id = nullif(current_setting('app.user_id', true), '')::uuid
       AND u.active;
    IF v_role IS NULL OR v_role NOT IN ('vedenie', 'admin') THEN
      RAISE EXCEPTION 'Vlastníka (obchodníka) môže zmeniť iba vedenie.'
        USING ERRCODE = 'insufficient_privilege';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_owner_change_guard BEFORE UPDATE OF owner_id ON company
  FOR EACH ROW EXECUTE FUNCTION owner_change_guard();
CREATE TRIGGER trg_owner_change_guard BEFORE UPDATE OF owner_id ON contact
  FOR EACH ROW EXECUTE FUNCTION owner_change_guard();

-- ============================================================================
-- Segment dealu a zmluvy: odvodený od druhu zákazníka
-- ============================================================================

CREATE OR REPLACE FUNCTION inherit_customer_segment() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.segment IS NULL THEN
    IF NEW.company_id IS NOT NULL THEN
      SELECT CASE WHEN c.is_supplier AND NOT c.is_customer THEN 'dodavatel' ELSE 'firma' END::customer_segment
        INTO NEW.segment FROM company c WHERE c.id = NEW.company_id;
    ELSE
      NEW.segment := 'domacnost';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

-- ============================================================================
-- Pohľady
-- ============================================================================

-- Archivovaná firma: zrušený zákazník, ktorý nie je partner ani dodávateľ.
CREATE FUNCTION company_is_archived(c company) RETURNS boolean
LANGUAGE sql STABLE AS $$
  SELECT c.status IS NOT DISTINCT FROM 'zruseny_zakaznik' AND NOT c.is_partner AND NOT c.is_supplier
$$;

-- Zákazníci (čl. 3, 9): firmy s označením zákazník + osoby-domácnosti.
CREATE VIEW customer_v AS
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
       company_is_archived(c) AS archived
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
       p.status IS NOT DISTINCT FROM 'zruseny_zakaznik'
  FROM contact p
  LEFT JOIN oom_sum s ON s.person_id = p.id
 WHERE p.is_household
   -- externý vidí domácnosť iba ako jej vlastník (nie osobu, ktorá je len kontaktom na jeho firme)
   AND ((SELECT crm_sees_all()) OR p.owner_id = (SELECT crm_external_user_id()));

COMMENT ON VIEW customer_v IS 'zoznam Zákazníci: firmy s is_customer a osoby s is_household; archived = zrušený zákazník';

-- Kontakty (čl. 9, 13): všetky osoby; archived = osoba sa skryje z Kontaktov aj marketingu.
-- Skrytá je osoba, ktorá nie je aktívna domácnosť, nemá žiadnu nearchivovanú firmu
-- a je domácnosťou alebo kontaktom aspoň jednej firmy.
CREATE VIEW contact_v AS
SELECT p.*,
       x.archived,
       (NOT x.archived AND p.marketing_opt_out_at IS NULL) AS marketing_allowed
  FROM contact p
  CROSS JOIN LATERAL (
    SELECT NOT (p.is_household AND p.status IS DISTINCT FROM 'zruseny_zakaznik')
           AND NOT EXISTS (SELECT 1 FROM company_contact cc JOIN company c ON c.id = cc.company_id
                            WHERE cc.contact_id = p.id AND NOT company_is_archived(c))
           AND (p.is_household OR EXISTS (SELECT 1 FROM company_contact cc WHERE cc.contact_id = p.id))
           AS archived
  ) x;

COMMENT ON VIEW contact_v IS 'zoznam Kontakty: archived = skryť z Kontaktov, vyhľadávania a marketingu (čl. 4, 13)';

-- migrate:down

DROP VIEW IF EXISTS contact_v;
DROP VIEW IF EXISTS customer_v;
DROP FUNCTION IF EXISTS company_is_archived(company);

-- pôvodný customer_v z 0001 (po obnovení stĺpca segment nižšie)

CREATE OR REPLACE FUNCTION inherit_customer_segment() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.segment IS NULL THEN
    IF NEW.company_id IS NOT NULL THEN
      SELECT c.segment INTO NEW.segment FROM company c WHERE c.id = NEW.company_id;
    ELSE
      SELECT p.segment INTO NEW.segment FROM contact p WHERE p.id = NEW.person_id;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_owner_change_guard ON contact;
DROP TRIGGER IF EXISTS trg_owner_change_guard ON company;
DROP FUNCTION IF EXISTS owner_change_guard();

DROP FUNCTION IF EXISTS customer_is_former_calc(uuid, uuid);
DROP FUNCTION IF EXISTS customer_status_calc(uuid, uuid, date);

DROP TRIGGER IF EXISTS trg_mark_household ON contract;
DROP TRIGGER IF EXISTS trg_mark_household ON oom;
DROP TRIGGER IF EXISTS trg_mark_household ON deal;
DROP FUNCTION IF EXISTS mark_household();

DROP TRIGGER IF EXISTS trg_customer_status ON contact;
DROP TRIGGER IF EXISTS trg_customer_status ON company;
DROP FUNCTION IF EXISTS customer_status_track();

-- Firma – osoba
CREATE TYPE company_contact_role AS ENUM ('statutar', 'kontaktna_osoba', 'fakturacia', 'ine');
DROP INDEX IF EXISTS company_contact_one_main_key;
ALTER TABLE company_contact
  DROP COLUMN is_main_contact,
  DROP COLUMN roles,
  ADD COLUMN is_primary boolean NOT NULL DEFAULT false,
  ADD COLUMN role company_contact_role;
CREATE UNIQUE INDEX company_contact_one_primary_key ON company_contact (contact_id) WHERE is_primary;

-- Osoba
DROP INDEX IF EXISTS contact_status_idx;
DROP INDEX IF EXISTS contact_mobile_norm_idx;
DROP INDEX IF EXISTS contact_phone_norm_idx;
DROP INDEX IF EXISTS contact_email_idx;
CREATE INDEX contact_email_idx ON contact (lower(email));
ALTER TABLE contact
  ALTER COLUMN first_name DROP NOT NULL,
  ALTER COLUMN last_name DROP NOT NULL,
  DROP CONSTRAINT contact_marketing_opt_out_check,
  DROP CONSTRAINT contact_status_source_check,
  DROP CONSTRAINT contact_email_format_check,
  DROP CONSTRAINT contact_reachable_check,
  DROP CONSTRAINT contact_name_check,
  DROP COLUMN marketing_opt_out_source,
  DROP COLUMN marketing_opt_out_at,
  DROP COLUMN is_producer,
  DROP COLUMN is_former_customer,
  DROP COLUMN status_changed_at,
  DROP COLUMN status_source,
  DROP COLUMN status,
  DROP COLUMN is_household,
  DROP COLUMN mobile_norm,
  DROP COLUMN phone_norm,
  ADD COLUMN segment customer_segment,
  ADD COLUMN lifecycle_stage text;

-- Firma
DROP INDEX IF EXISTS company_status_idx;
DROP INDEX IF EXISTS company_ico_key;
CREATE UNIQUE INDEX company_ico_key ON company (ico) WHERE ico IS NOT NULL;
ALTER TABLE company
  DROP CONSTRAINT company_status_source_check,
  DROP CONSTRAINT company_kind_check,
  DROP CONSTRAINT company_name_check,
  DROP COLUMN is_producer,
  DROP COLUMN is_former_customer,
  DROP COLUMN status_changed_at,
  DROP COLUMN status_source,
  DROP COLUMN status,
  DROP COLUMN is_supplier,
  DROP COLUMN is_partner,
  DROP COLUMN is_customer,
  ALTER COLUMN ico DROP NOT NULL,
  ADD COLUMN segment customer_segment,
  ADD COLUMN lifecycle_stage text,
  ADD CONSTRAINT company_segment_check CHECK (segment <> 'domacnost');

CREATE VIEW customer_v AS
SELECT c.id,
       'B2B'::text AS customer_type,
       c.id        AS company_id,
       NULL::uuid  AS person_id,
       c.name,
       c.ico,
       NULL::text  AS email,
       c.segment,
       c.owner_id
  FROM company c
UNION ALL
SELECT p.id,
       'B2C'::text,
       NULL::uuid,
       p.id,
       concat_ws(' ', p.first_name, p.last_name),
       NULL::text,
       p.email,
       p.segment,
       p.owner_id
  FROM contact p
 WHERE NOT EXISTS (SELECT 1 FROM company_contact cc WHERE cc.contact_id = p.id);

DROP FUNCTION IF EXISTS normalize_phone(text);
DROP FUNCTION IF EXISTS crm_external_user_id();
DROP FUNCTION IF EXISTS crm_sees_all();
DROP FUNCTION IF EXISTS crm_current_user_id();

-- Hodnotu enumu nemožno odstrániť; app_user_role sa vymení za pôvodný (iba ak ju nikto nemá).
ALTER TYPE app_user_role RENAME TO app_user_role_0004;
CREATE TYPE app_user_role AS ENUM ('admin', 'vedenie', 'obchodnik', 'servis', 'marketing');
ALTER TABLE app_user ALTER COLUMN role TYPE app_user_role USING role::text::app_user_role;
DROP TYPE app_user_role_0004;

DROP TYPE IF EXISTS company_role;
DROP TYPE IF EXISTS status_source;
DROP TYPE IF EXISTS customer_status;
