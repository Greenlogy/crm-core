\restrict dbmate

-- Dumped from database version 17.11 (fcae950)
-- Dumped by pg_dump version 18.6 (Postgres.app)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: btree_gist; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS btree_gist WITH SCHEMA public;


--
-- Name: EXTENSION btree_gist; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION btree_gist IS 'support for indexing common datatypes in GiST';


--
-- Name: access_scope; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.access_scope AS ENUM (
    'nic',
    'iba_svoje',
    'vsetko'
);


--
-- Name: activity_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.activity_type AS ENUM (
    'email',
    'hovor',
    'chat',
    'fb',
    'poznamka',
    'uloha',
    'web',
    'kampan'
);


--
-- Name: audit_action; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.audit_action AS ENUM (
    'insert',
    'update',
    'delete'
);


--
-- Name: audit_source; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.audit_source AS ENUM (
    'aplikacia',
    'system',
    'synchronizacia'
);


--
-- Name: bank_account_purpose; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.bank_account_purpose AS ENUM (
    'faktury',
    'zalohy',
    'vykup'
);


--
-- Name: commission_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.commission_status AS ENUM (
    'vypocitana',
    'cakajuca',
    'uplatnena',
    'schvalena',
    'vyplatena',
    'zrusena'
);


--
-- Name: consent_purpose; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.consent_purpose AS ENUM (
    'marketing_greenlogy',
    'blog',
    'produkty_a_sluzby',
    'individualna_komunikacia',
    'zakaznicke_sluzby'
);


--
-- Name: consent_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.consent_status AS ENUM (
    'udeleny',
    'odvolany'
);


--
-- Name: contract_price_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.contract_price_status AS ENUM (
    'platna',
    'neplatna'
);


--
-- Name: contract_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.contract_status AS ENUM (
    'rozpracovana',
    'caka_na_podpis',
    'podpisana',
    'caka_na_zaradenie',
    'aktivna',
    'ukoncena',
    'vypoved_neakceptovana',
    'zmena_neuspesna'
);


--
-- Name: conversation_channel; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.conversation_channel AS ENUM (
    'email',
    'web_chat',
    'facebook',
    'telefon'
);


--
-- Name: country_code; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.country_code AS ENUM (
    'SK',
    'CZ',
    'HR'
);


--
-- Name: crm_entity; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.crm_entity AS ENUM (
    'firma',
    'osoba',
    'oom',
    'deal',
    'zmluva',
    'ponuka'
);


--
-- Name: crm_module; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.crm_module AS ENUM (
    'zakaznici',
    'odberne_miesta',
    'obchod',
    'zmluvy',
    'provizie',
    'servis',
    'marketing'
);


--
-- Name: custom_field_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.custom_field_type AS ENUM (
    'text',
    'dlhy_text',
    'cislo',
    'suma',
    'datum',
    'vyber',
    'vyber_viac',
    'ano_nie',
    'odkaz'
);


--
-- Name: customer_segment; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.customer_segment AS ENUM (
    'domacnost',
    'firma',
    'dodavatel'
);


--
-- Name: customer_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.customer_status AS ENUM (
    'marketingovy_kontakt',
    'zaujemca',
    'ponuka',
    'cakajuci_zakaznik',
    'zakaznik',
    'byvaly_zakaznik',
    'zruseny_zakaznik'
);


--
-- Name: day_off_kind; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.day_off_kind AS ENUM (
    'statny_sviatok',
    'firemne_volno'
);


--
-- Name: deal_kind; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.deal_kind AS ENUM (
    'b2c_dodavka',
    'b2b_dodavka',
    'b2b_vykup',
    'green_solar',
    'green_viwa',
    'efet'
);


--
-- Name: device_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.device_type AS ENUM (
    'striedac',
    'panely',
    'bateria',
    'tepelne_cerpadlo',
    'wallbox'
);


--
-- Name: field_edit_access; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.field_edit_access AS ENUM (
    'vsetky_timy',
    'vybrane_timy',
    'iba_admin'
);


--
-- Name: fve_program; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.fve_program AS ENUM (
    'eco',
    'standard',
    'premium'
);


--
-- Name: fve_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.fve_status AS ENUM (
    'ponuka_odoslana',
    'ponuka_akceptovana',
    'zaloha_uhradena',
    'dielo_prevzate',
    'dielo_uhradene'
);


--
-- Name: offer_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.offer_status AS ENUM (
    'koncept',
    'odoslana',
    'otvorena',
    'prijata',
    'zamietnuta'
);


--
-- Name: oom_contact_source; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.oom_contact_source AS ENUM (
    'rucne',
    'zmluva'
);


--
-- Name: oom_link_end_reason; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.oom_link_end_reason AS ENUM (
    'odchod',
    'zrusenie',
    'prepis'
);


--
-- Name: oom_source_category; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.oom_source_category AS ENUM (
    'maly_zdroj',
    'lokalny_zdroj',
    'vyrobny_zdroj'
);


--
-- Name: oom_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.oom_status AS ENUM (
    'aktivne',
    'pripravovane',
    'zrusene',
    'odidene',
    'prepisane'
);


--
-- Name: oom_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.oom_type AS ENUM (
    'spotreba',
    'vyroba',
    'sharing'
);


--
-- Name: org_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.org_status AS ENUM (
    'aktivna',
    'pripravuje_sa'
);


--
-- Name: payment_rating; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.payment_rating AS ENUM (
    'A',
    'B',
    'C',
    'D',
    'E',
    'X'
);


--
-- Name: price_direction; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.price_direction AS ENUM (
    'odber',
    'dodavka'
);


--
-- Name: pricing_model; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.pricing_model AS ENUM (
    'fix',
    'spot_aditiv',
    'index_spot'
);


--
-- Name: product_kind; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.product_kind AS ENUM (
    'dodavka',
    'vykup',
    'sluzba',
    'poplatok'
);


--
-- Name: product_unit; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.product_unit AS ENUM (
    'eur_mwh',
    'eur_mesiac'
);


--
-- Name: source_kind; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.source_kind AS ENUM (
    'fve',
    'voda',
    'bioplyn',
    'biomasa',
    'plyn',
    'vietor',
    'ostatne_oze'
);


--
-- Name: stage_outcome; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.stage_outcome AS ENUM (
    'otvoreny',
    'vyhrany',
    'prehrany'
);


--
-- Name: status_source; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.status_source AS ENUM (
    'hubspot',
    'vypocet'
);


--
-- Name: switch_message_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.switch_message_type AS ENUM (
    'xml433',
    'xml43d'
);


--
-- Name: switch_segment; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.switch_segment AS ENUM (
    'domacnost',
    'organizacia'
);


--
-- Name: user_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.user_status AS ENUM (
    'pozvany',
    'aktivny',
    'deaktivovany'
);


--
-- Name: voltage_level; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.voltage_level AS ENUM (
    'nn',
    'vn',
    'vvn'
);


--
-- Name: add_business_minutes(timestamp with time zone, integer, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.add_business_minutes(start timestamp with time zone, minutes integer, p_org_id uuid DEFAULT NULL::uuid) RETURNS timestamp with time zone
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
  v_org        uuid := coalesce(p_org_id, crm_default_org());
  v_tz         text := (SELECT o.timezone FROM org o WHERE o.id = coalesce(p_org_id, crm_default_org()));
  v_local      timestamp;
  v_remaining  numeric := minutes;
  v_from       timestamp;
  v_to         timestamp;
  v_available  numeric;
  r            record;
BEGIN
  IF minutes IS NULL OR minutes < 0 THEN
    RAISE EXCEPTION 'add_business_minutes: počet minút musí byť 0 alebo viac (zadané %)', minutes;
  END IF;
  v_local := start AT TIME ZONE v_tz;

  FOR r IN
    SELECT bc.date, bc.work_from, bc.work_to
      FROM business_calendar bc
     WHERE bc.org_id = v_org
       AND bc.date >= v_local::date
       AND bc.is_working_day
     ORDER BY bc.date
  LOOP
    v_from := greatest(v_local, r.date + r.work_from);
    v_to   := r.date + r.work_to;
    CONTINUE WHEN v_from >= v_to;

    v_available := extract(epoch FROM v_to - v_from) / 60;
    IF v_remaining <= v_available THEN
      RETURN (v_from + make_interval(mins => v_remaining::integer)) AT TIME ZONE v_tz;
    END IF;
    v_remaining := v_remaining - v_available;
  END LOOP;

  RAISE EXCEPTION 'add_business_minutes: business_calendar nepokrýva termín od % (+% min)', start, minutes;
END;
$$;


--
-- Name: app_user_deactivate(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.app_user_deactivate(p_user_id uuid, p_new_owner_id uuid) RETURNS TABLE(companies integer, contacts integer, open_deals integer)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_companies  integer;
  v_contacts   integer;
  v_deals      integer;
BEGIN
  IF NOT crm_settings_writer() THEN
    RAISE EXCEPTION 'Deaktivovať používateľa môže iba admin.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF p_user_id = crm_current_user_id() THEN
    RAISE EXCEPTION 'Sám seba deaktivovať nemožno.' USING ERRCODE = 'check_violation';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM app_user WHERE id = p_user_id AND status <> 'deaktivovany') THEN
    RAISE EXCEPTION 'Používateľ neexistuje alebo už je deaktivovaný.' USING ERRCODE = 'no_data_found';
  END IF;

  SELECT count(*) INTO v_companies FROM company WHERE owner_id = p_user_id;
  SELECT count(*) INTO v_contacts FROM contact WHERE owner_id = p_user_id;
  SELECT count(*) INTO v_deals FROM deal d JOIN pipeline_stage s ON s.id = d.stage_id
   WHERE d.owner_id = p_user_id AND NOT s.is_closed;

  IF v_companies + v_contacts + v_deals > 0 THEN
    IF p_new_owner_id IS NULL THEN
      RAISE EXCEPTION 'Používateľ vlastní % firiem, % osôb a % otvorených dealov. Vyber nového vlastníka.',
        v_companies, v_contacts, v_deals USING ERRCODE = 'check_violation';
    END IF;
    IF p_new_owner_id = p_user_id
       OR NOT EXISTS (SELECT 1 FROM app_user WHERE id = p_new_owner_id AND status = 'aktivny') THEN
      RAISE EXCEPTION 'Nový vlastník musí byť iný aktívny používateľ.' USING ERRCODE = 'check_violation';
    END IF;
    UPDATE company SET owner_id = p_new_owner_id WHERE owner_id = p_user_id;
    UPDATE contact SET owner_id = p_new_owner_id WHERE owner_id = p_user_id;
    UPDATE deal d SET owner_id = p_new_owner_id
      FROM pipeline_stage s
     WHERE s.id = d.stage_id AND d.owner_id = p_user_id AND NOT s.is_closed;
  END IF;

  UPDATE app_user SET status = 'deaktivovany', deactivated_at = now() WHERE id = p_user_id;
  RETURN QUERY SELECT v_companies, v_contacts, v_deals;
END;
$$;


--
-- Name: app_user_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.app_user_guard() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_external boolean;
BEGIN
  IF TG_OP IN ('INSERT', 'UPDATE') THEN
    SELECT t.is_external INTO v_external FROM team t WHERE t.id = NEW.team_id;
    IF v_external AND NEW.is_admin THEN
      RAISE EXCEPTION 'Člen externého tímu nemôže byť admin.' USING ERRCODE = 'check_violation';
    END IF;
    IF v_external AND NOT crm_external_ready()
       AND (TG_OP = 'INSERT' OR NEW.team_id IS DISTINCT FROM OLD.team_id) THEN
      RAISE EXCEPTION 'Do externého tímu zatiaľ nemožno priradiť používateľa: OOM, dealy, zmluvy a ponuky ešte nemajú obmedzenie „iba svoje“ v databáze.'
        USING ERRCODE = 'check_violation';
    END IF;
    IF NEW.status = 'deaktivovany' AND (TG_OP = 'INSERT' OR OLD.status <> 'deaktivovany')
       AND (EXISTS (SELECT 1 FROM company WHERE owner_id = NEW.id)
         OR EXISTS (SELECT 1 FROM contact WHERE owner_id = NEW.id)
         OR EXISTS (SELECT 1 FROM deal d JOIN pipeline_stage s ON s.id = d.stage_id
                     WHERE d.owner_id = NEW.id AND NOT s.is_closed)) THEN
      RAISE EXCEPTION 'Používateľ ešte vlastní zákazníkov alebo otvorené dealy. Deaktivuj ho cez odovzdanie novému vlastníkovi.'
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;

  -- posledný aktívny admin
  IF TG_OP = 'DELETE' OR NOT (NEW.is_admin AND NEW.status = 'aktivny') THEN
    IF TG_OP <> 'INSERT' AND OLD.is_admin AND OLD.status = 'aktivny'
       AND NOT EXISTS (SELECT 1 FROM app_user u
                        WHERE u.id <> OLD.id AND u.is_admin AND u.status = 'aktivny') THEN
      RAISE EXCEPTION 'CRM musí mať aspoň jedného aktívneho admina.' USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  RETURN coalesce(NEW, OLD);
END;
$$;


--
-- Name: app_user_login(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.app_user_login(p_email text) RETURNS TABLE(user_id uuid, status public.user_status)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_user app_user;
BEGIN
  SELECT * INTO v_user FROM app_user u WHERE lower(u.email) = lower(btrim(p_email));
  IF NOT FOUND THEN
    RETURN;
  END IF;
  IF v_user.status = 'deaktivovany' THEN
    RETURN QUERY SELECT NULL::uuid, v_user.status;
    RETURN;
  END IF;
  UPDATE app_user u
     SET status = 'aktivny', last_login_at = now()
   WHERE u.id = v_user.id;
  RETURN QUERY SELECT v_user.id, 'aktivny'::user_status;
END;
$$;


--
-- Name: audit_log_protect(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.audit_log_protect() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF current_user <> (SELECT r.rolname FROM pg_class c JOIN pg_roles r ON r.oid = c.relowner
                       WHERE c.oid = 'audit_log'::regclass) THEN
    RAISE EXCEPTION 'Audit sa nedá upraviť ani zmazať.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  RETURN coalesce(OLD, NEW);
END;
$$;


--
-- Name: audit_row(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.audit_row() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_old     jsonb;
  v_new     jsonb;
  v_diff    jsonb;
  v_id      uuid;
  v_user    uuid := nullif(current_setting('app.user_id', true), '')::uuid;
  v_source  audit_source;
BEGIN
  IF TG_OP = 'INSERT' THEN
    v_new  := to_jsonb(NEW);
    v_id   := NEW.id;
    v_diff := v_new;
  ELSIF TG_OP = 'DELETE' THEN
    v_old  := to_jsonb(OLD);
    v_id   := OLD.id;
    v_diff := v_old;
  ELSE
    v_old := to_jsonb(OLD);
    v_new := to_jsonb(NEW);
    v_id  := NEW.id;
    -- bežné stĺpce (bez updated_at a last_login_at) + vlastné polia po kľúčoch
    SELECT jsonb_object_agg(d.k, jsonb_build_object('old', d.o, 'new', d.n))
      INTO v_diff
      FROM (
        SELECT n.key AS k, v_old -> n.key AS o, n.value AS n
          FROM jsonb_each(v_new) AS n
         WHERE n.key NOT IN ('updated_at', 'last_login_at', 'custom')
           AND n.value IS DISTINCT FROM v_old -> n.key
        UNION ALL
        SELECT 'custom.' || ks.key, v_old -> 'custom' -> ks.key, v_new -> 'custom' -> ks.key
          FROM (SELECT jsonb_object_keys(CASE jsonb_typeof(v_new -> 'custom') WHEN 'object' THEN v_new -> 'custom' ELSE '{}' END)
                UNION
                SELECT jsonb_object_keys(CASE jsonb_typeof(v_old -> 'custom') WHEN 'object' THEN v_old -> 'custom' ELSE '{}' END)
               ) AS ks (key)
         WHERE v_new -> 'custom' -> ks.key IS DISTINCT FROM v_old -> 'custom' -> ks.key
      ) d;
    IF v_diff IS NULL THEN
      RETURN NEW;  -- nič sa nezmenilo (alebo iba čas prihlásenia)
    END IF;
  END IF;

  v_source := coalesce(
    nullif(current_setting('app.change_source', true), '')::audit_source,
    CASE WHEN current_user = 'crm_sync' THEN 'synchronizacia'
         WHEN v_user IS NOT NULL THEN 'aplikacia'
         ELSE 'system' END::audit_source);

  INSERT INTO audit_log (table_name, record_id, action, changed_by, diff, source)
  VALUES (TG_TABLE_NAME, v_id, lower(TG_OP)::audit_action, v_user, v_diff, v_source);

  RETURN coalesce(NEW, OLD);
END;
$$;


--
-- Name: business_calendar_rebuild(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.business_calendar_rebuild() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN
  DELETE FROM business_calendar;
  INSERT INTO business_calendar (org_id, date, is_working_day, work_from, work_to, note)
  SELECT r.org_id, d.date,
         h.org_id IS NOT NULL AND o.org_id IS NULL,
         CASE WHEN o.org_id IS NULL THEN h.work_from END,
         CASE WHEN o.org_id IS NULL THEN h.work_to END,
         o.name
    FROM (SELECT org_id,
                 make_date(extract(year FROM min(date))::int, 1, 1) AS date_from,
                 make_date(extract(year FROM max(date))::int, 12, 31) AS date_to
            FROM org_day_off WHERE kind = 'statny_sviatok'
           GROUP BY org_id) r
   CROSS JOIN LATERAL (SELECT g::date AS date FROM generate_series(r.date_from, r.date_to, interval '1 day') g) d
    LEFT JOIN org_work_hours h ON h.org_id = r.org_id AND h.weekday = extract(isodow FROM d.date)
    LEFT JOIN org_day_off o ON o.org_id = r.org_id AND o.date = d.date;
  RETURN NULL;
END;
$$;


--
-- Name: company_contact_check(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.company_contact_check() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_org uuid := (SELECT org_id FROM company WHERE id = NEW.company_id);
BEGIN
  IF v_org <> (SELECT org_id FROM contact WHERE id = NEW.contact_id) THEN
    RAISE EXCEPTION 'Osoba a firma patria rôznym spoločnostiam (osoba v inej spoločnosti = nový záznam).'
      USING ERRCODE = 'check_violation';
  END IF;
  PERFORM lookup_codes_check('rola_kontaktu', v_org, NEW.roles,
                             CASE WHEN TG_OP = 'UPDATE' THEN OLD.roles END);
  RETURN NEW;
END;
$$;


--
-- Name: company_country_default(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.company_country_default() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN
  IF NEW.country IS NULL THEN
    SELECT o.country INTO NEW.country FROM org o WHERE o.id = NEW.org_id;
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: company_ico_check(public.country_code, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.company_ico_check(p_country public.country_code, p_ico text) RETURNS TABLE(company_exists boolean, company_id uuid, owner_name text, org_name text)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT true,
         CASE WHEN crm_company_access(c.id, 'view') THEN c.id END,
         u.name,
         o.legal_name
    FROM company c
    JOIN org o ON o.id = c.org_id
    LEFT JOIN app_user u ON u.id = c.owner_id
   WHERE c.country = p_country
     AND c.ico = CASE WHEN p_country = 'HR' THEN regexp_replace(p_ico, '[^0-9]', '', 'g')
                      ELSE lpad(regexp_replace(p_ico, '[^0-9]', '', 'g'), 8, '0') END
$$;


--
-- Name: crm_default_org(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_default_org() RETURNS uuid
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT id FROM org WHERE is_default
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: company; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.company (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    ico text NOT NULL,
    dic text,
    ic_dph text,
    vat_payer boolean,
    legal_form text,
    registry_entry text,
    nace text,
    statutory text,
    address text,
    payment_rating public.payment_rating,
    debts_note text,
    insolvency_note text,
    finstat_url text,
    finstat_updated_at timestamp with time zone,
    owner_id uuid,
    hubspot_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    bank_account text,
    is_customer boolean DEFAULT true NOT NULL,
    is_partner boolean DEFAULT false NOT NULL,
    is_supplier boolean DEFAULT false NOT NULL,
    status public.customer_status,
    status_source public.status_source,
    status_changed_at timestamp with time zone,
    is_former_customer boolean DEFAULT false NOT NULL,
    is_producer boolean DEFAULT false NOT NULL,
    custom jsonb DEFAULT '{}'::jsonb NOT NULL,
    org_id uuid DEFAULT public.crm_default_org() NOT NULL,
    country public.country_code NOT NULL,
    CONSTRAINT company_ico_format_check CHECK ((((country = ANY (ARRAY['SK'::public.country_code, 'CZ'::public.country_code])) AND (ico ~ '^[0-9]{8}$'::text)) OR ((country = 'HR'::public.country_code) AND (ico ~ '^[0-9]{11}$'::text)))),
    CONSTRAINT company_kind_check CHECK ((is_customer OR is_partner OR is_supplier)),
    CONSTRAINT company_name_check CHECK ((btrim(name) <> ''::text)),
    CONSTRAINT company_status_source_check CHECK (((status IS NULL) = (status_source IS NULL)))
);


--
-- Name: COLUMN company.ico; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.company.ico IS 'identifikátor podľa krajiny: SK, CZ = IČO 8 číslic vrátane úvodných núl; HR = OIB 11 číslic';


--
-- Name: COLUMN company.bank_account; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.company.bank_account IS 'bankový účet firmy (zvyčajne IBAN), HubSpot bank_account';


--
-- Name: COLUMN company.is_customer; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.company.is_customer IS 'označenie zákazník (predvolené); firma môže mať viac označení';


--
-- Name: COLUMN company.is_partner; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.company.is_partner IS 'označenie partner; partner bez is_customer nie je v zozname Zákazníci';


--
-- Name: COLUMN company.is_supplier; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.company.is_supplier IS 'označenie dodávateľ; dodávateľ bez is_customer nie je v zozname Zákazníci';


--
-- Name: COLUMN company.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.company.status IS 'stav zákazníka (čl. 4 zadania); NULL, ak firma nie je zákazník';


--
-- Name: COLUMN company.is_former_customer; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.company.is_former_customer IS 'príznak „bývalý“: mal odídené OOM; automaticky sa nezruší';


--
-- Name: COLUMN company.is_producer; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.company.is_producer IS 'segment „+ výrobca“';


--
-- Name: COLUMN company.custom; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.company.custom IS 'vlastné polia z Nastavení: {kľúč poľa: hodnota}';


--
-- Name: COLUMN company.org_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.company.org_id IS 'spoločnosť skupiny, ktorej firma patrí (zákazník patrí práve jednej)';


--
-- Name: COLUMN company.country; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.company.country IS 'krajina firmy (predvolene krajina spoločnosti); určuje identifikátor v stĺpci ico';


--
-- Name: company_is_archived(public.company); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.company_is_archived(c public.company) RETURNS boolean
    LANGUAGE sql STABLE
    AS $$
  SELECT c.status IS NOT DISTINCT FROM 'zruseny_zakaznik' AND NOT c.is_partner AND NOT c.is_supplier
$$;


--
-- Name: contact_duplicate_check(text, text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.contact_duplicate_check(p_email text, p_phone text, p_org_id uuid DEFAULT NULL::uuid) RETURNS TABLE(match_on text, contact_id uuid, owner_name text)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT m.match_on,
         CASE WHEN crm_contact_access(p.id, 'view') THEN p.id END,
         u.name
    FROM (
      SELECT 'email'::text AS match_on, p.id
        FROM contact p
       WHERE nullif(btrim(p_email), '') IS NOT NULL
         AND lower(btrim(p.email)) = lower(btrim(p_email))
      UNION
      SELECT 'telefon', p.id
        FROM contact p
       WHERE normalize_phone(p_phone) IS NOT NULL
         AND normalize_phone(p_phone) IN (p.phone_norm, p.mobile_norm)
    ) m
    JOIN contact p ON p.id = m.id
    LEFT JOIN app_user u ON u.id = p.owner_id
   WHERE p.org_id = coalesce(p_org_id, crm_default_org())
   ORDER BY m.match_on, p.created_at
$$;


--
-- Name: contact_source_check(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.contact_source_check() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.source IS NOT NULL THEN
    PERFORM lookup_codes_check('zdroj_kontaktu', NEW.org_id, ARRAY[NEW.source],
                               CASE WHEN TG_OP = 'UPDATE' THEN ARRAY[OLD.source] END);
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: crm_active_user_id(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_active_user_id() RETURNS uuid
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT u.id FROM app_user u JOIN team t ON t.id = u.team_id
   WHERE u.id = crm_current_user_id() AND u.status = 'aktivny' AND t.archived_at IS NULL
$$;


--
-- Name: crm_as_system(boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_as_system(p_on boolean) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_prev text := current_setting('app.change_source', true);
BEGIN
  PERFORM set_config('app.change_source', CASE WHEN p_on THEN 'system' ELSE '' END, true);
  RETURN coalesce(v_prev, '');
END;
$$;


--
-- Name: crm_can_change_owner(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_can_change_owner() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT EXISTS (SELECT 1 FROM app_user u JOIN team t ON t.id = u.team_id
                  WHERE u.id = crm_active_user_id() AND (u.is_admin OR t.can_change_owner))
$$;


--
-- Name: custom_field; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.custom_field (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    entity public.crm_entity NOT NULL,
    key text NOT NULL,
    label text NOT NULL,
    field_type public.custom_field_type NOT NULL,
    ref_entity public.crm_entity,
    section_id uuid,
    sort_order integer DEFAULT 0 NOT NULL,
    is_required boolean DEFAULT false NOT NULL,
    show_in_list boolean DEFAULT false NOT NULL,
    filterable boolean DEFAULT false NOT NULL,
    edit_access public.field_edit_access DEFAULT 'vsetky_timy'::public.field_edit_access NOT NULL,
    org_id uuid,
    archived_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT custom_field_key_check CHECK ((key ~ '^[a-z][a-z0-9_]{1,62}$'::text)),
    CONSTRAINT custom_field_label_check CHECK ((btrim(label) <> ''::text)),
    CONSTRAINT custom_field_ref_check CHECK (((field_type = 'odkaz'::public.custom_field_type) = (ref_entity IS NOT NULL)))
);


--
-- Name: COLUMN custom_field.key; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.custom_field.key IS 'kľúč v stĺpci custom; vznikne z názvu, nikdy sa nemení';


--
-- Name: COLUMN custom_field.field_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.custom_field.field_type IS 'po prvej uloženej hodnote sa nemení';


--
-- Name: COLUMN custom_field.is_required; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.custom_field.is_required IS 'kontroluje API pri uložení formulára (nie databáza – staršie záznamy pole nemajú)';


--
-- Name: COLUMN custom_field.org_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.custom_field.org_id IS 'NULL = celá skupina';


--
-- Name: COLUMN custom_field.archived_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.custom_field.archived_at IS 'archivované pole: údaje ostávajú, nedajú sa meniť, pole sa dá obnoviť';


--
-- Name: crm_can_edit_field(public.custom_field); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_can_edit_field(p_field public.custom_field) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT crm_is_service()
      OR (crm_active_user_id() IS NOT NULL AND CASE p_field.edit_access
            WHEN 'vsetky_timy' THEN true
            WHEN 'iba_admin'   THEN crm_is_admin()
            ELSE EXISTS (SELECT 1 FROM custom_field_team ft JOIN app_user u ON u.team_id = ft.team_id
                          WHERE ft.field_id = p_field.id AND u.id = crm_active_user_id())
          END)
$$;


--
-- Name: crm_company_access(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_company_access(p_company_id uuid, p_action text) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT EXISTS (
    SELECT 1 FROM company c
     WHERE c.id = p_company_id
       AND c.org_id = ANY (crm_user_orgs())
       AND (crm_scope('zakaznici', p_action) = 'vsetko'
            OR (crm_scope('zakaznici', p_action) = 'iba_svoje' AND c.owner_id = crm_active_user_id())))
$$;


--
-- Name: crm_contact_access(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_contact_access(p_contact_id uuid, p_action text) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT EXISTS (
    SELECT 1 FROM contact p
     WHERE p.id = p_contact_id
       AND p.org_id = ANY (crm_user_orgs())
       AND (crm_scope('zakaznici', p_action) = 'vsetko'
            OR (crm_scope('zakaznici', p_action) = 'iba_svoje'
                AND (p.owner_id = crm_active_user_id() OR crm_contact_on_own_company(p.id)))))
$$;


--
-- Name: crm_contact_on_own_company(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_contact_on_own_company(p_contact_id uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT EXISTS (SELECT 1 FROM company_contact cc JOIN company c ON c.id = cc.company_id
                  WHERE cc.contact_id = p_contact_id
                    AND c.owner_id = crm_active_user_id()
                    AND c.org_id = ANY (crm_user_orgs()))
$$;


--
-- Name: crm_current_user_id(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_current_user_id() RETURNS uuid
    LANGUAGE sql STABLE
    AS $$
  SELECT nullif(current_setting('app.user_id', true), '')::uuid
$$;


--
-- Name: crm_entity_table(public.crm_entity); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_entity_table(p public.crm_entity) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT CASE p WHEN 'firma' THEN 'company' WHEN 'osoba' THEN 'contact' WHEN 'oom' THEN 'oom'
                WHEN 'deal' THEN 'deal' WHEN 'zmluva' THEN 'contract' WHEN 'ponuka' THEN 'offer' END
$$;


--
-- Name: crm_external_ready(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_external_ready() RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT false
$$;


--
-- Name: crm_is_admin(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_is_admin() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT EXISTS (SELECT 1 FROM app_user u WHERE u.id = crm_active_user_id() AND u.is_admin)
$$;


--
-- Name: crm_is_service(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_is_service() RETURNS boolean
    LANGUAGE sql STABLE
    AS $$
  SELECT crm_current_user_id() IS NULL AND NOT crm_require_user()
$$;


--
-- Name: crm_require_user(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_require_user() RETURNS boolean
    LANGUAGE sql STABLE
    AS $$
  SELECT current_user = 'crm_app' OR session_user = 'crm_app'
      OR coalesce(current_setting('app.require_user', true), '') = 'on'
$$;


--
-- Name: FUNCTION crm_require_user(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.crm_require_user() IS 'true = spojenie aplikácie: bez prihláseného používateľa nevidí nič (rola crm_app vždy, testy cez app.require_user)';


--
-- Name: crm_scope(public.crm_module, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_scope(p_module public.crm_module, p_action text) RETURNS public.access_scope
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_scope access_scope;
BEGIN
  IF p_action NOT IN ('view', 'edit') THEN
    RAISE EXCEPTION 'crm_scope: akcia musí byť view alebo edit (zadané %)', p_action;
  END IF;
  IF crm_is_service() THEN
    RETURN 'vsetko';
  END IF;
  SELECT CASE p_action WHEN 'view' THEN p.view_scope ELSE p.edit_scope END
    INTO v_scope
    FROM app_user u
    JOIN team_permission p ON p.team_id = u.team_id AND p.module = p_module
   WHERE u.id = crm_active_user_id();
  RETURN coalesce(v_scope, 'nic');
END;
$$;


--
-- Name: crm_session_ok(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_session_ok() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT crm_is_service() OR crm_active_user_id() IS NOT NULL
$$;


--
-- Name: crm_setting_on(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_setting_on(p_key text) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT coalesce((SELECT value = 'true'::jsonb FROM app_setting WHERE key = p_key), false)
$$;


--
-- Name: crm_settings_writer(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_settings_writer() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT crm_is_service() OR crm_is_admin()
$$;


--
-- Name: crm_slug(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_slug(p text) RETURNS text
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    AS $$
  SELECT nullif(btrim(regexp_replace(lower(translate(p,
           'áäčďéěíĺľňóôöŕřšťúůüýžÁÄČĎÉĚÍĹĽŇÓÔÖŔŘŠŤÚŮÜÝŽ',
           'aacdeeillnooorrstuuuyzAACDEEILLNOOORRSTUUUYZ')), '[^a-z0-9]+', '_', 'g'), '_'), '')
$$;


--
-- Name: crm_today(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_today() RETURNS date
    LANGUAGE sql STABLE
    AS $$
  SELECT (now() AT TIME ZONE 'Europe/Bratislava')::date
$$;


--
-- Name: crm_user_orgs(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_user_orgs() RETURNS uuid[]
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT CASE
           WHEN crm_is_service() THEN (SELECT coalesce(array_agg(o.id), '{}') FROM org o)
           WHEN EXISTS (SELECT 1 FROM app_user u JOIN team t ON t.id = u.team_id
                         WHERE u.id = crm_active_user_id() AND t.all_orgs)
             THEN (SELECT coalesce(array_agg(o.id), '{}') FROM org o)
           ELSE (SELECT coalesce(array_agg(uo.org_id), '{}') FROM app_user_org uo
                  WHERE uo.user_id = crm_active_user_id())
         END
$$;


--
-- Name: custom_field_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.custom_field_guard() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $_$
DECLARE
  v_used boolean;
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'Vlastné pole sa nemaže, iba archivuje.' USING ERRCODE = 'check_violation';
  END IF;
  IF TG_OP = 'INSERT' THEN
    NEW.key := coalesce(NEW.key, crm_slug(NEW.label));
    RETURN NEW;
  END IF;
  IF NEW.key <> OLD.key OR NEW.entity <> OLD.entity THEN
    RAISE EXCEPTION 'Kľúč a záznam vlastného poľa sa nemenia.' USING ERRCODE = 'check_violation';
  END IF;
  IF NEW.field_type <> OLD.field_type OR NEW.ref_entity IS DISTINCT FROM OLD.ref_entity THEN
    EXECUTE format('SELECT EXISTS (SELECT 1 FROM %I WHERE custom ? $1)', crm_entity_table(OLD.entity))
      INTO v_used USING OLD.key;
    IF v_used THEN
      RAISE EXCEPTION 'Typ poľa „%“ sa nedá zmeniť, pole už má uložené hodnoty.', OLD.label
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  RETURN NEW;
END;
$_$;


--
-- Name: custom_field_option_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.custom_field_option_guard() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  RAISE EXCEPTION 'Hodnota výberu sa nemaže, iba skryje.' USING ERRCODE = 'check_violation';
END;
$$;


--
-- Name: custom_values_check(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.custom_values_check() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
DECLARE
  v_entity   crm_entity := TG_ARGV[0]::crm_entity;
  v_new      jsonb := coalesce(NEW.custom, '{}');
  v_old      jsonb := CASE WHEN TG_OP = 'UPDATE' THEN coalesce(OLD.custom, '{}') ELSE '{}' END;
  v_org      uuid := (to_jsonb(NEW) ->> 'org_id')::uuid;
  v_org_old  uuid := CASE WHEN TG_OP = 'UPDATE' THEN (to_jsonb(OLD) ->> 'org_id')::uuid END;
  v_key      text;
  v_val      jsonb;
  v_f        custom_field;
  v_item     jsonb;
  v_ref_org  text;
  v_found    boolean;
BEGIN
  IF jsonb_typeof(v_new) <> 'object' THEN
    RAISE EXCEPTION 'Vlastné polia musia byť objekt JSON.' USING ERRCODE = 'check_violation';
  END IF;
  IF TG_OP = 'UPDATE' AND v_new = v_old AND v_org IS NOT DISTINCT FROM v_org_old THEN
    RETURN NEW;
  END IF;

  FOR v_key IN
    SELECT k FROM jsonb_object_keys(v_new) k
    UNION
    SELECT k FROM jsonb_object_keys(v_old) k
  LOOP
    v_val := v_new -> v_key;   -- NULL = kľúč odstránený
    CONTINUE WHEN v_val IS NOT DISTINCT FROM v_old -> v_key AND v_org IS NOT DISTINCT FROM v_org_old;

    SELECT * INTO v_f FROM custom_field WHERE entity = v_entity AND key = v_key;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Neznáme vlastné pole „%“ (%).', v_key, v_entity USING ERRCODE = 'check_violation';
    END IF;
    IF v_f.org_id IS NOT NULL AND v_org IS NOT NULL AND v_f.org_id <> v_org AND v_val IS NOT NULL
       AND v_val <> 'null' THEN
      RAISE EXCEPTION 'Pole „%“ platí pre inú spoločnosť.', v_f.label USING ERRCODE = 'check_violation';
    END IF;
    CONTINUE WHEN v_val IS NOT DISTINCT FROM v_old -> v_key;   -- zmenila sa iba spoločnosť
    IF v_f.archived_at IS NOT NULL THEN
      RAISE EXCEPTION 'Pole „%“ je archivované, nedá sa meniť.', v_f.label USING ERRCODE = 'check_violation';
    END IF;
    IF NOT crm_can_edit_field(v_f) THEN
      RAISE EXCEPTION 'Pole „%“ nemôžeš meniť (nastavenie tímov poľa).', v_f.label
        USING ERRCODE = 'insufficient_privilege';
    END IF;
    CONTINUE WHEN v_val IS NULL OR v_val = 'null';   -- vymazanie hodnoty

    CASE v_f.field_type
      WHEN 'text', 'dlhy_text' THEN
        IF jsonb_typeof(v_val) <> 'string' THEN
          RAISE EXCEPTION 'Pole „%“: očakávaný text.', v_f.label USING ERRCODE = 'check_violation';
        END IF;
      WHEN 'cislo', 'suma' THEN
        IF jsonb_typeof(v_val) <> 'number' THEN
          RAISE EXCEPTION 'Pole „%“: očakávané číslo.', v_f.label USING ERRCODE = 'check_violation';
        END IF;
      WHEN 'ano_nie' THEN
        IF jsonb_typeof(v_val) <> 'boolean' THEN
          RAISE EXCEPTION 'Pole „%“: očakávané áno/nie.', v_f.label USING ERRCODE = 'check_violation';
        END IF;
      WHEN 'datum' THEN
        IF jsonb_typeof(v_val) <> 'string' OR (v_val #>> '{}') !~ '^\d{4}-\d{2}-\d{2}$'
           OR pg_input_is_valid(v_val #>> '{}', 'date') IS NOT TRUE THEN
          RAISE EXCEPTION 'Pole „%“: očakávaný dátum RRRR-MM-DD.', v_f.label USING ERRCODE = 'check_violation';
        END IF;
      WHEN 'vyber', 'vyber_viac' THEN
        IF v_f.field_type = 'vyber' AND jsonb_typeof(v_val) <> 'string'
           OR v_f.field_type = 'vyber_viac' AND jsonb_typeof(v_val) <> 'array' THEN
          RAISE EXCEPTION 'Pole „%“: očakávaná hodnota výberu.', v_f.label USING ERRCODE = 'check_violation';
        END IF;
        FOR v_item IN
          SELECT x FROM jsonb_array_elements(CASE jsonb_typeof(v_val) WHEN 'array' THEN v_val
                                                                       ELSE jsonb_build_array(v_val) END) x
        LOOP
          IF jsonb_typeof(v_item) <> 'string' OR pg_input_is_valid(v_item #>> '{}', 'uuid') IS NOT TRUE
             OR NOT EXISTS (SELECT 1 FROM custom_field_option o
                             WHERE o.field_id = v_f.id AND o.id = (v_item #>> '{}')::uuid) THEN
            RAISE EXCEPTION 'Pole „%“: neznáma hodnota výberu.', v_f.label USING ERRCODE = 'check_violation';
          END IF;
          -- skrytú hodnotu možno ponechať, nie nanovo vybrať
          IF EXISTS (SELECT 1 FROM custom_field_option o
                      WHERE o.id = (v_item #>> '{}')::uuid AND o.hidden_at IS NOT NULL)
             AND NOT (coalesce(v_old -> v_key, 'null') = v_item
                      OR (jsonb_typeof(v_old -> v_key) = 'array' AND (v_old -> v_key) @> jsonb_build_array(v_item))) THEN
            RAISE EXCEPTION 'Pole „%“: hodnota je skrytá, nedá sa vybrať.', v_f.label USING ERRCODE = 'check_violation';
          END IF;
        END LOOP;
      WHEN 'odkaz' THEN
        IF jsonb_typeof(v_val) <> 'string' OR pg_input_is_valid(v_val #>> '{}', 'uuid') IS NOT TRUE THEN
          RAISE EXCEPTION 'Pole „%“: očakávaný odkaz na záznam.', v_f.label USING ERRCODE = 'check_violation';
        END IF;
        -- cieľ existuje (a prihlásený ho vidí) a patrí tej istej spoločnosti (Peter 12. 10.)
        EXECUTE format('SELECT true, to_jsonb(t) ->> ''org_id'' FROM %I t WHERE t.id = $1',
                       crm_entity_table(v_f.ref_entity))
          INTO v_found, v_ref_org USING (v_val #>> '{}')::uuid;
        IF v_found IS NOT TRUE THEN
          RAISE EXCEPTION 'Pole „%“: odkazovaný záznam neexistuje.', v_f.label USING ERRCODE = 'foreign_key_violation';
        END IF;
        IF v_org IS NOT NULL AND v_ref_org IS NOT NULL AND v_ref_org::uuid <> v_org THEN
          RAISE EXCEPTION 'Pole „%“: odkazovaný záznam patrí inej spoločnosti.', v_f.label
            USING ERRCODE = 'check_violation';
        END IF;
    END CASE;
  END LOOP;
  RETURN NEW;
END;
$_$;


--
-- Name: customer_delete(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.customer_delete(p_company_id uuid, p_person_id uuid) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_name   text;
  v_links  text[];
BEGIN
  IF num_nonnulls(p_company_id, p_person_id) <> 1 THEN
    RAISE EXCEPTION 'customer_delete: zadaj práve jedno z company_id / person_id';
  END IF;
  IF NOT crm_is_admin() THEN
    RAISE EXCEPTION 'Zmazať firmu alebo osobu môže iba admin.' USING ERRCODE = 'insufficient_privilege';
  END IF;

  IF p_company_id IS NOT NULL THEN
    IF NOT crm_company_access(p_company_id, 'view') THEN
      RAISE EXCEPTION 'Firma neexistuje.' USING ERRCODE = 'no_data_found';
    END IF;
    SELECT name INTO v_name FROM company WHERE id = p_company_id;
    v_links := array_remove(ARRAY[
      CASE WHEN EXISTS (SELECT 1 FROM company_contact WHERE company_id = p_company_id) THEN 'osoby vo firme' END,
      CASE WHEN EXISTS (SELECT 1 FROM oom WHERE company_id = p_company_id) THEN 'odberné miesta' END,
      CASE WHEN EXISTS (SELECT 1 FROM deal WHERE company_id = p_company_id) THEN 'dealy' END,
      CASE WHEN EXISTS (SELECT 1 FROM contract WHERE company_id = p_company_id) THEN 'zmluvy' END,
      CASE WHEN EXISTS (SELECT 1 FROM activity WHERE company_id = p_company_id) THEN 'aktivity' END,
      CASE WHEN EXISTS (SELECT 1 FROM conversation WHERE company_id = p_company_id) THEN 'konverzácie' END
    ], NULL);
  ELSE
    IF NOT crm_contact_access(p_person_id, 'view') THEN
      RAISE EXCEPTION 'Osoba neexistuje.' USING ERRCODE = 'no_data_found';
    END IF;
    SELECT concat_ws(' ', first_name, last_name) INTO v_name FROM contact WHERE id = p_person_id;
    v_links := array_remove(ARRAY[
      CASE WHEN EXISTS (SELECT 1 FROM company_contact WHERE contact_id = p_person_id) THEN 'firmy' END,
      CASE WHEN EXISTS (SELECT 1 FROM deal_contact WHERE contact_id = p_person_id)
             OR EXISTS (SELECT 1 FROM deal WHERE person_id = p_person_id) THEN 'dealy' END,
      CASE WHEN EXISTS (SELECT 1 FROM oom WHERE person_id = p_person_id) THEN 'odberné miesta' END,
      CASE WHEN EXISTS (SELECT 1 FROM contract WHERE person_id = p_person_id) THEN 'zmluvy' END,
      CASE WHEN EXISTS (SELECT 1 FROM activity WHERE contact_id = p_person_id) THEN 'aktivity' END,
      CASE WHEN EXISTS (SELECT 1 FROM conversation WHERE contact_id = p_person_id) THEN 'konverzácie' END,
      CASE WHEN EXISTS (SELECT 1 FROM consent WHERE contact_id = p_person_id) THEN 'súhlasy' END,
      CASE WHEN EXISTS (SELECT 1 FROM voucher WHERE contact_id = p_person_id)
             OR EXISTS (SELECT 1 FROM referral WHERE referrer_contact_id = p_person_id) THEN 'poukážky a odporúčania' END,
      CASE WHEN EXISTS (SELECT 1 FROM web_event WHERE contact_id = p_person_id) THEN 'udalosti z webu' END
    ], NULL);
  END IF;

  IF cardinality(v_links) > 0 THEN
    RAISE EXCEPTION 'Záznam má väzby (%), nedá sa zmazať – iba archivovať.', array_to_string(v_links, ', ')
      USING ERRCODE = 'check_violation';
  END IF;

  IF p_company_id IS NOT NULL THEN
    DELETE FROM company WHERE id = p_company_id;
  ELSE
    DELETE FROM contact WHERE id = p_person_id;
  END IF;
  RETURN v_name;
END;
$$;


--
-- Name: customer_is_former_calc(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.customer_is_former_calc(p_company_id uuid, p_person_id uuid) RETURNS boolean
    LANGUAGE sql STABLE
    AS $$
  SELECT EXISTS (SELECT 1 FROM oom_customer l
                  WHERE l.company_id IS NOT DISTINCT FROM p_company_id
                    AND l.person_id IS NOT DISTINCT FROM p_person_id
                    AND l.end_reason = 'odchod')
$$;


--
-- Name: customer_is_producer_calc(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.customer_is_producer_calc(p_company_id uuid, p_person_id uuid) RETURNS boolean
    LANGUAGE sql STABLE
    AS $$
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


--
-- Name: customer_org_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.customer_org_guard() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN
  IF NEW.org_id IS DISTINCT FROM OLD.org_id AND (
       (TG_TABLE_NAME = 'company' AND (
          EXISTS (SELECT 1 FROM company_contact WHERE company_id = OLD.id)
          OR EXISTS (SELECT 1 FROM oom_customer WHERE company_id = OLD.id)
          OR EXISTS (SELECT 1 FROM deal WHERE company_id = OLD.id)
          OR EXISTS (SELECT 1 FROM contract WHERE company_id = OLD.id)))
    OR (TG_TABLE_NAME = 'contact' AND (
          EXISTS (SELECT 1 FROM company_contact WHERE contact_id = OLD.id)
          OR EXISTS (SELECT 1 FROM deal_contact WHERE contact_id = OLD.id)
          OR EXISTS (SELECT 1 FROM oom_customer WHERE person_id = OLD.id)
          OR EXISTS (SELECT 1 FROM oom_contact WHERE contact_id = OLD.id)
          OR EXISTS (SELECT 1 FROM deal WHERE person_id = OLD.id)
          OR EXISTS (SELECT 1 FROM contract WHERE person_id = OLD.id)))) THEN
    RAISE EXCEPTION 'Spoločnosť sa nedá zmeniť, záznam má väzby (osoby, OOM, dealy, zmluvy).'
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: customer_refresh(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.customer_refresh(p_company_id uuid, p_person_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
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


--
-- Name: customer_refresh_all(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.customer_refresh_all() RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
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


--
-- Name: customer_status_calc(uuid, uuid, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.customer_status_calc(p_company_id uuid, p_person_id uuid, p_today date DEFAULT ((now() AT TIME ZONE 'Europe/Bratislava'::text))::date) RETURNS public.customer_status
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
  IF num_nonnulls(p_company_id, p_person_id) <> 1 THEN
    RAISE EXCEPTION 'customer_status_calc: zadaj práve jedno z company_id / person_id';
  END IF;

  -- 1. aspoň jedno OOM Aktívne
  IF EXISTS (SELECT 1 FROM oom_customer l
              WHERE l.company_id IS NOT DISTINCT FROM p_company_id
                AND l.person_id IS NOT DISTINCT FROM p_person_id
                AND l.status = 'aktivne') THEN
    RETURN 'zakaznik';
  END IF;

  -- 2. OOM Pripravované alebo podpísaná zmluva s budúcou účinnosťou (aj vracajúci sa zákazník)
  IF EXISTS (SELECT 1 FROM oom_customer l
              WHERE l.company_id IS NOT DISTINCT FROM p_company_id
                AND l.person_id IS NOT DISTINCT FROM p_person_id
                AND l.status = 'pripravovane')
     OR EXISTS (SELECT 1 FROM contract c
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
  IF EXISTS (SELECT 1 FROM oom_customer l
              WHERE l.company_id IS NOT DISTINCT FROM p_company_id
                AND l.person_id IS NOT DISTINCT FROM p_person_id
                AND l.status = 'odidene') THEN
    RETURN 'byvaly_zakaznik';
  END IF;

  -- 6. má OOM a všetky sú Zrušené alebo Prepísané
  IF EXISTS (SELECT 1 FROM oom_customer l
              WHERE l.company_id IS NOT DISTINCT FROM p_company_id
                AND l.person_id IS NOT DISTINCT FROM p_person_id) THEN
    RETURN 'zruseny_zakaznik';
  END IF;

  -- 7. inak (aj záujemca, ktorému deal prepadol a nikdy nebol zákazník)
  RETURN 'marketingovy_kontakt';
END;
$$;


--
-- Name: customer_status_track(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.customer_status_track() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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


--
-- Name: deal_contact_org_check(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.deal_contact_org_check() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN
  IF (SELECT org_id FROM deal WHERE id = NEW.deal_id) <> (SELECT org_id FROM contact WHERE id = NEW.contact_id) THEN
    RAISE EXCEPTION 'Osoba a deal patria rôznym spoločnostiam.' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: eic_is_valid(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.eic_is_valid(p text) RETURNS boolean
    LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE
    AS $_$
DECLARE
  v_chars constant text := '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ-';
  v_sum   integer := 0;
BEGIN
  IF p IS NULL OR p !~ '^[0-9A-Z-]{15}[0-9A-Z]$' THEN
    RETURN false;
  END IF;
  FOR i IN 1..15 LOOP
    v_sum := v_sum + (strpos(v_chars, substr(p, i, 1)) - 1) * (17 - i);
  END LOOP;
  RETURN substr(v_chars, 36 - (((v_sum - 1) % 37 + 37) % 37) + 1, 1) = substr(p, 16, 1);
END;
$_$;


--
-- Name: FUNCTION eic_is_valid(p text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.eic_is_valid(p text) IS 'formát a kontrolná číslica EIC podľa ENTSO-E';


--
-- Name: inherit_customer_segment(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inherit_customer_segment() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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


--
-- Name: lookup_codes_check(text, uuid, text[], text[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.lookup_codes_check(p_list text, p_org_id uuid, p_new text[], p_old text[] DEFAULT '{}'::text[]) RETURNS void
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_code  text;
  v_val   lookup_value;
BEGIN
  FOREACH v_code IN ARRAY coalesce(p_new, '{}') LOOP
    SELECT * INTO v_val FROM lookup_value
     WHERE list_code = p_list AND code = v_code AND (org_id IS NULL OR org_id = p_org_id);
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Hodnota „%“ nie je v číselníku %.', v_code, p_list USING ERRCODE = 'foreign_key_violation';
    END IF;
    IF v_val.hidden_at IS NOT NULL AND NOT v_code = ANY (coalesce(p_old, '{}')) THEN
      RAISE EXCEPTION 'Hodnota „%“ je skrytá, nedá sa vybrať.', v_val.label USING ERRCODE = 'check_violation';
    END IF;
  END LOOP;
END;
$$;


--
-- Name: lookup_value_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.lookup_value_guard() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_parent_list text;
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'Hodnota číselníka sa nemaže, iba skryje.' USING ERRCODE = 'check_violation';
  END IF;
  IF TG_OP = 'INSERT' THEN
    SELECT parent_list INTO v_parent_list FROM lookup_list WHERE code = NEW.list_code;
    IF (v_parent_list IS NULL) <> (NEW.parent_code IS NULL) THEN
      RAISE EXCEPTION 'Hodnota zoznamu % % nadradenú hodnotu.', NEW.list_code,
        CASE WHEN v_parent_list IS NULL THEN 'nemá' ELSE 'musí mať' END USING ERRCODE = 'check_violation';
    END IF;
    IF v_parent_list IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM lookup_value WHERE list_code = v_parent_list AND code = NEW.parent_code) THEN
      RAISE EXCEPTION 'Nadradená hodnota „%“ nie je v číselníku %.', NEW.parent_code, v_parent_list
        USING ERRCODE = 'foreign_key_violation';
    END IF;
    NEW.code := coalesce(NEW.code, crm_slug(concat_ws('_', NEW.parent_code, NEW.label)));
    RETURN NEW;
  END IF;
  IF NEW.code <> OLD.code OR NEW.list_code <> OLD.list_code OR NEW.is_system <> OLD.is_system
     OR NEW.parent_code IS DISTINCT FROM OLD.parent_code THEN
    RAISE EXCEPTION 'Kód, zoznam, nadradená hodnota a systémový príznak hodnoty číselníka sa nemenia.'
      USING ERRCODE = 'check_violation';
  END IF;
  IF OLD.is_system AND (NEW.label <> OLD.label OR NEW.hidden_at IS NOT NULL
                        OR NEW.org_id IS DISTINCT FROM OLD.org_id) THEN
    RAISE EXCEPTION 'Systémová hodnota „%“ sa nedá premenovať ani skryť.', OLD.label USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: mark_household(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.mark_household() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.person_id IS NOT NULL THEN
    UPDATE contact SET is_household = true WHERE id = NEW.person_id AND NOT is_household;
  END IF;
  RETURN NULL;
END;
$$;


--
-- Name: normalize_phone(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.normalize_phone(p text) RETURNS text
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    AS $$
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


--
-- Name: oom_activate_due(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_activate_due() RETURNS integer
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT oom_activate_due_at(crm_today())
$$;


--
-- Name: oom_activate_due_at(date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_activate_due_at(p_today date) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
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


--
-- Name: oom_activate_on_save(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_activate_on_save() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
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


--
-- Name: oom; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oom (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id uuid,
    person_id uuid,
    eic text NOT NULL,
    type public.oom_type NOT NULL,
    status public.oom_status NOT NULL,
    name text,
    address_street text,
    address_number_supisne text,
    address_number_orientacne text,
    address_city text,
    address_zip text,
    pds text,
    pds_point_id text,
    pds_tariff text,
    voltage_level public.voltage_level,
    metering_type text,
    phases smallint,
    breaker_a numeric(8,2),
    reserved_capacity_kw numeric(12,3),
    max_reserved_capacity_kw numeric(12,3),
    capacity_reservation_method text,
    price_regulation text,
    excise_tax text,
    billing_period text,
    advance_payment_method text,
    advance_payment_pct numeric(5,2),
    planned_consumption_vt_mwh numeric(12,3),
    planned_consumption_nt_mwh numeric(12,3),
    planned_feed_in_mwh numeric(12,3),
    source_power_kw numeric(12,3),
    source_kind public.source_kind,
    feed_in_contract_type text,
    inverter_power_kw numeric(12,3),
    panels_power_kw numeric(12,3),
    supply_from date,
    supply_to date,
    hubspot_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    custom jsonb DEFAULT '{}'::jsonb NOT NULL,
    org_id uuid NOT NULL,
    source_category public.oom_source_category,
    advance_payment_eur numeric(12,2),
    previous_supplier text,
    switch_notice_required boolean DEFAULT true NOT NULL,
    switch_notice_sent_on date,
    switch_notice_accepted_on date,
    switch_confirmed_on date,
    CONSTRAINT oom_advance_payment_eur_check CHECK ((advance_payment_eur >= (0)::numeric)),
    CONSTRAINT oom_advance_pct_check CHECK (((advance_payment_pct >= (0)::numeric) AND (advance_payment_pct <= (100)::numeric))),
    CONSTRAINT oom_customer_check CHECK ((num_nonnulls(company_id, person_id) = 1)),
    CONSTRAINT oom_eic_check CHECK (public.eic_is_valid(eic)),
    CONSTRAINT oom_phases_check CHECK ((phases = ANY (ARRAY[1, 3]))),
    CONSTRAINT oom_supply_period_check CHECK (((supply_to IS NULL) OR (supply_from IS NULL) OR (supply_to >= supply_from))),
    CONSTRAINT oom_switch_steps_check CHECK (((switch_notice_required OR ((switch_notice_sent_on IS NULL) AND (switch_notice_accepted_on IS NULL))) AND ((switch_notice_accepted_on IS NULL) OR ((switch_notice_sent_on IS NOT NULL) AND (switch_notice_accepted_on >= switch_notice_sent_on))) AND ((switch_confirmed_on IS NULL) OR (NOT switch_notice_required) OR ((switch_notice_accepted_on IS NOT NULL) AND (switch_confirmed_on >= switch_notice_accepted_on)))))
);


--
-- Name: COLUMN oom.company_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.oom.company_id IS 'zákazník poslednej väzby (oom_customer); mení sa iba cez väzbu';


--
-- Name: COLUMN oom.person_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.oom.person_id IS 'zákazník poslednej väzby (oom_customer); mení sa iba cez väzbu';


--
-- Name: COLUMN oom.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.oom.status IS 'stav poslednej väzby (oom_customer); mení sa iba cez väzbu';


--
-- Name: COLUMN oom.pds; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.oom.pds IS 'kód z číselníka pds';


--
-- Name: COLUMN oom.pds_tariff; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.oom.pds_tariff IS 'kód z číselníka sadzba_distribucie (sadzba zvoleného PDS)';


--
-- Name: COLUMN oom.metering_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.oom.metering_type IS 'kód z číselníka typ_merania';


--
-- Name: COLUMN oom.billing_period; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.oom.billing_period IS 'kód z číselníka fakturacne_obdobie';


--
-- Name: COLUMN oom.advance_payment_method; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.oom.advance_payment_method IS 'kód z číselníka sposob_zaloh';


--
-- Name: COLUMN oom.feed_in_contract_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.oom.feed_in_contract_type IS 'kód z číselníka typ_vykupnej_zmluvy';


--
-- Name: COLUMN oom.supply_to; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.oom.supply_to IS 'NULL = na neurčito';


--
-- Name: COLUMN oom.custom; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.oom.custom IS 'vlastné polia z Nastavení: {kľúč poľa: hodnota}';


--
-- Name: COLUMN oom.org_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.oom.org_id IS 'preberá sa od zákazníka';


--
-- Name: COLUMN oom.source_category; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.oom.source_category IS 'kategória zdroja podľa zákona (zadanie OOM čl. 7)';


--
-- Name: COLUMN oom.previous_supplier; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.oom.previous_supplier IS 'kód z číselníka predchadzajuci_dodavatel';


--
-- Name: COLUMN oom.switch_notice_required; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.oom.switch_notice_required IS 'false = výpoveď predošlému dodávateľovi sa nezasiela (napr. nová prípojka)';


--
-- Name: COLUMN oom.switch_notice_sent_on; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.oom.switch_notice_sent_on IS 'prechod, krok 1: výpoveď predošlému dodávateľovi odoslaná';


--
-- Name: COLUMN oom.switch_notice_accepted_on; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.oom.switch_notice_accepted_on IS 'prechod, krok 2: výpoveď akceptovaná';


--
-- Name: COLUMN oom.switch_confirmed_on; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.oom.switch_confirmed_on IS 'prechod, krok 3: zmena dodávateľa potvrdená; krok 4 = supply_from';


--
-- Name: oom_activation_ready(public.oom, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_activation_ready(o public.oom, p_today date) RETURNS boolean
    LANGUAGE sql STABLE
    AS $$
  SELECT o.status = 'pripravovane'
     AND o.switch_confirmed_on IS NOT NULL
     AND o.supply_from <= p_today
     AND cardinality(oom_active_required_missing(o)) = 0
$$;


--
-- Name: oom_active_required_check(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_active_required_check() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_missing text[];
BEGIN
  IF NEW.status = 'aktivne' AND (TG_OP = 'INSERT' OR OLD.status <> 'aktivne') AND current_user <> 'crm_sync' THEN
    v_missing := oom_active_required_missing(NEW);
    IF cardinality(v_missing) > 0 THEN
      RAISE EXCEPTION 'Odberné miesto nemôže byť Aktívne, chýba: %.', array_to_string(v_missing, ', ')
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: oom_active_required_missing(public.oom); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_active_required_missing(o public.oom) RETURNS text[]
    LANGUAGE sql STABLE
    AS $$
  SELECT array_remove(ARRAY[
    CASE WHEN nullif(btrim(o.address_street), '') IS NULL AND nullif(btrim(o.address_city), '') IS NULL
         THEN 'ulica alebo obec' END,
    CASE WHEN nullif(btrim(o.address_zip), '') IS NULL THEN 'PSČ' END,
    CASE WHEN o.pds IS NULL THEN 'PDS' END,
    CASE WHEN o.voltage_level IS NULL THEN 'napäťová úroveň' END,
    CASE WHEN o.pds_tariff IS NULL THEN 'sadzba distribúcie' END,
    CASE WHEN o.supply_from IS NULL THEN 'dodávka od' END,
    CASE WHEN o.type IN ('spotreba', 'sharing')
          AND o.planned_consumption_vt_mwh IS NULL AND o.planned_consumption_nt_mwh IS NULL
         THEN 'plánovaná spotreba' END,
    CASE WHEN o.type = 'vyroba' AND o.planned_feed_in_mwh IS NULL THEN 'plánovaný výkup' END
  ], NULL)
$$;


--
-- Name: FUNCTION oom_active_required_missing(o public.oom); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.oom_active_required_missing(o public.oom) IS 'chýbajúce povinné údaje pre stav Aktívne (prázdne pole = OK)';


--
-- Name: oom_contact_check(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_contact_check() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_oom oom;
BEGIN
  SELECT * INTO v_oom FROM oom WHERE id = NEW.oom_id;
  IF v_oom.company_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM company_contact WHERE company_id = v_oom.company_id AND contact_id = NEW.contact_id) THEN
      RAISE EXCEPTION 'Kontaktná osoba musí byť osobou vo firme zákazníka.' USING ERRCODE = 'check_violation';
    END IF;
  ELSIF (SELECT org_id FROM contact WHERE id = NEW.contact_id) <> v_oom.org_id THEN
    RAISE EXCEPTION 'Osoba a odberné miesto patria rôznym spoločnostiam.' USING ERRCODE = 'check_violation';
  END IF;
  PERFORM lookup_codes_check('rola_pri_oom', v_oom.org_id, NEW.roles,
                             CASE WHEN TG_OP = 'UPDATE' THEN OLD.roles END);
  RETURN NEW;
END;
$$;


--
-- Name: oom_customer_at(uuid, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_customer_at(p_oom_id uuid, p_date date) RETURNS TABLE(company_id uuid, person_id uuid, status public.oom_status, valid_from date, valid_to date)
    LANGUAGE sql STABLE
    AS $$
  SELECT l.company_id, l.person_id, l.status, l.valid_from, l.valid_to
    FROM oom_customer l
   WHERE l.oom_id = p_oom_id
     AND daterange(l.valid_from, l.valid_to, '[]') @> p_date
$$;


--
-- Name: oom_customer_check(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_customer_check() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_customer_org uuid;
BEGIN
  NEW.org_id := (SELECT org_id FROM oom WHERE id = NEW.oom_id);
  v_customer_org := coalesce((SELECT org_id FROM company WHERE id = NEW.company_id),
                             (SELECT org_id FROM contact WHERE id = NEW.person_id));
  IF v_customer_org IS DISTINCT FROM NEW.org_id THEN
    RAISE EXCEPTION 'Odberné miesto a zákazník patria rôznym spoločnostiam.' USING ERRCODE = 'check_violation';
  END IF;

  IF TG_OP = 'UPDATE' THEN
    IF NEW.oom_id <> OLD.oom_id OR NEW.company_id IS DISTINCT FROM OLD.company_id
       OR NEW.person_id IS DISTINCT FROM OLD.person_id THEN
      RAISE EXCEPTION 'Odberné miesto ani zákazník väzby sa nemenia (prepis = nová väzba).' USING ERRCODE = 'check_violation';
    END IF;
    IF OLD.valid_to IS NOT NULL AND current_user <> 'crm_sync' THEN
      RAISE EXCEPTION 'Uzavretá väzba sa nemení.' USING ERRCODE = 'check_violation';
    END IF;
    IF OLD.status = 'aktivne' AND NEW.status = 'pripravovane' THEN
      RAISE EXCEPTION 'Aktívne odberné miesto sa nevracia do stavu Pripravované.' USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: oom_customer_mark(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_customer_mark() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_prev text := crm_as_system(true);
BEGIN
  UPDATE company SET is_customer = true WHERE id = NEW.company_id AND NOT is_customer;
  UPDATE contact SET is_household = true WHERE id = NEW.person_id AND NOT is_household;
  PERFORM set_config('app.change_source', v_prev, true);
  RETURN NULL;
END;
$$;


--
-- Name: oom_customer_refresh(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_customer_refresh() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
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


--
-- Name: oom_eic_normalize(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_eic_normalize() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.eic := upper(regexp_replace(NEW.eic, '\s', '', 'g'));
  RETURN NEW;
END;
$$;


--
-- Name: oom_first_link(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_first_link() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  INSERT INTO oom_customer (oom_id, company_id, person_id, org_id, valid_from, status)
  VALUES (NEW.id, NEW.company_id, NEW.person_id, NEW.org_id, least(NEW.supply_from, crm_today()), NEW.status);
  RETURN NULL;
END;
$$;


--
-- Name: oom_link_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_link_guard() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.status NOT IN ('pripravovane', 'aktivne') THEN
      RAISE EXCEPTION 'Nové odberné miesto je Pripravované alebo Aktívne.' USING ERRCODE = 'check_violation';
    END IF;
  ELSIF pg_trigger_depth() < 2
        AND (NEW.company_id IS DISTINCT FROM OLD.company_id OR NEW.person_id IS DISTINCT FROM OLD.person_id
             OR NEW.status IS DISTINCT FROM OLD.status) THEN
    RAISE EXCEPTION 'Zákazník a stav odberného miesta sa menia iba zmenou stavu alebo prepisom.'
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: oom_link_sync(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_link_sync() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_oom_id uuid := coalesce(NEW.oom_id, OLD.oom_id);
  v_link   oom_customer;
BEGIN
  SELECT * INTO v_link FROM oom_customer WHERE oom_id = v_oom_id ORDER BY valid_from DESC LIMIT 1;
  IF FOUND THEN
    UPDATE oom
       SET company_id = v_link.company_id, person_id = v_link.person_id, status = v_link.status
     WHERE id = v_oom_id
       AND (company_id, person_id, status) IS DISTINCT FROM (v_link.company_id, v_link.person_id, v_link.status);
  END IF;
  RETURN NULL;
END;
$$;


--
-- Name: oom_lookup_check(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_lookup_check() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_old oom;   -- pri INSERT prázdne: každý kód je nový (skrytý sa nedá vybrať)
BEGIN
  IF TG_OP = 'UPDATE' THEN
    v_old := OLD;
  END IF;
  IF NEW.pds IS NOT NULL THEN
    PERFORM lookup_codes_check('pds', NEW.org_id, ARRAY[NEW.pds], array_remove(ARRAY[v_old.pds], NULL));
  END IF;
  IF NEW.pds_tariff IS NOT NULL THEN
    PERFORM lookup_codes_check('sadzba_distribucie', NEW.org_id, ARRAY[NEW.pds_tariff], array_remove(ARRAY[v_old.pds_tariff], NULL));
    IF NOT EXISTS (SELECT 1 FROM lookup_value
                    WHERE list_code = 'sadzba_distribucie' AND code = NEW.pds_tariff
                      AND parent_code = NEW.pds) THEN
      RAISE EXCEPTION 'Sadzba distribúcie nepatrí zvolenému PDS.' USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  IF NEW.metering_type IS NOT NULL THEN
    PERFORM lookup_codes_check('typ_merania', NEW.org_id, ARRAY[NEW.metering_type], array_remove(ARRAY[v_old.metering_type], NULL));
  END IF;
  IF NEW.billing_period IS NOT NULL THEN
    PERFORM lookup_codes_check('fakturacne_obdobie', NEW.org_id, ARRAY[NEW.billing_period], array_remove(ARRAY[v_old.billing_period], NULL));
  END IF;
  IF NEW.advance_payment_method IS NOT NULL THEN
    PERFORM lookup_codes_check('sposob_zaloh', NEW.org_id, ARRAY[NEW.advance_payment_method], array_remove(ARRAY[v_old.advance_payment_method], NULL));
  END IF;
  IF NEW.feed_in_contract_type IS NOT NULL THEN
    PERFORM lookup_codes_check('typ_vykupnej_zmluvy', NEW.org_id, ARRAY[NEW.feed_in_contract_type], array_remove(ARRAY[v_old.feed_in_contract_type], NULL));
  END IF;
  IF NEW.previous_supplier IS NOT NULL THEN
    PERFORM lookup_codes_check('predchadzajuci_dodavatel', NEW.org_id, ARRAY[NEW.previous_supplier], array_remove(ARRAY[v_old.previous_supplier], NULL));
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: oom_reconnect(uuid, uuid, uuid, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_reconnect(p_oom_id uuid, p_company_id uuid, p_person_id uuid, p_from date DEFAULT public.crm_today()) RETURNS uuid
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_last date;
  v_id   uuid;
BEGIN
  IF num_nonnulls(p_company_id, p_person_id) <> 1 THEN
    RAISE EXCEPTION 'oom_reconnect: zadaj práve jedno z company_id / person_id';
  END IF;
  IF EXISTS (SELECT 1 FROM oom_customer WHERE oom_id = p_oom_id AND valid_to IS NULL) THEN
    RAISE EXCEPTION 'Odberné miesto už je u nás (Pripravované alebo Aktívne).' USING ERRCODE = 'check_violation';
  END IF;
  SELECT max(valid_to) INTO v_last FROM oom_customer WHERE oom_id = p_oom_id;
  IF p_from <= v_last THEN
    RAISE EXCEPTION 'Nové obdobie musí začať po konci predošlého (%).', v_last USING ERRCODE = 'check_violation';
  END IF;

  UPDATE oom
     SET supply_from = NULL, supply_to = NULL, previous_supplier = NULL, switch_notice_required = true,
         switch_notice_sent_on = NULL, switch_notice_accepted_on = NULL, switch_confirmed_on = NULL
   WHERE id = p_oom_id;
  INSERT INTO oom_customer (oom_id, company_id, person_id, org_id, valid_from, status)
  VALUES (p_oom_id, p_company_id, p_person_id, (SELECT org_id FROM oom WHERE id = p_oom_id), p_from, 'pripravovane')
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;


--
-- Name: oom_set_status(uuid, public.oom_status, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_set_status(p_oom_id uuid, p_status public.oom_status, p_date date DEFAULT public.crm_today()) RETURNS void
    LANGUAGE plpgsql
    AS $$
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


--
-- Name: oom_transfer(uuid, uuid, uuid, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_transfer(p_oom_id uuid, p_company_id uuid, p_person_id uuid, p_date date) RETURNS uuid
    LANGUAGE plpgsql
    AS $$
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
  DELETE FROM oom_contact WHERE oom_id = p_oom_id;
  INSERT INTO oom_customer (oom_id, company_id, person_id, org_id, valid_from, status)
  VALUES (p_oom_id, p_company_id, p_person_id, v_link.org_id, p_date, v_link.status)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;


--
-- Name: oom_type_refresh(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_type_refresh() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
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


--
-- Name: org_bank_account_normalize(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.org_bank_account_normalize() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.iban := upper(regexp_replace(NEW.iban, '\s', '', 'g'));
  RETURN NEW;
END;
$$;


--
-- Name: owner_change_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.owner_change_guard() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.owner_id IS DISTINCT FROM OLD.owner_id AND current_user <> 'crm_sync'
     AND NOT crm_can_change_owner() THEN
    RAISE EXCEPTION 'Vlastníka (obchodníka) môže zmeniť iba vedenie (tím CEO) alebo admin.'
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: pipeline_no_delete(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.pipeline_no_delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  RAISE EXCEPTION 'Pipeline ani stage sa nemažú, iba archivujú.' USING ERRCODE = 'check_violation';
END;
$$;


--
-- Name: record_org_fill(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.record_org_fill() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_org  uuid;
  v_ref  uuid;
BEGIN
  IF TG_TABLE_NAME = 'offer' THEN
    SELECT org_id INTO v_org FROM deal WHERE id = NEW.deal_id;
  ELSIF NEW.company_id IS NOT NULL THEN
    SELECT org_id INTO v_org FROM company WHERE id = NEW.company_id;
  ELSIF NEW.person_id IS NOT NULL THEN
    SELECT org_id INTO v_org FROM contact WHERE id = NEW.person_id;
  END IF;

  -- bez zákazníka predvolená spoločnosť, aby zlyhala kontrola zákazníka (CHECK), nie NOT NULL
  NEW.org_id := coalesce(NEW.org_id, v_org, crm_default_org());
  IF v_org IS NOT NULL AND NEW.org_id <> v_org THEN
    RAISE EXCEPTION 'Záznam musí patriť tej istej spoločnosti ako jeho zákazník.' USING ERRCODE = 'check_violation';
  END IF;

  IF TG_TABLE_NAME = 'deal' THEN
    SELECT org_id INTO v_ref FROM pipeline WHERE id = NEW.pipeline_id;
    IF v_ref IS NOT NULL AND v_ref <> NEW.org_id THEN
      RAISE EXCEPTION 'Pipeline patrí inej spoločnosti ako deal.' USING ERRCODE = 'check_violation';
    END IF;
  ELSIF TG_TABLE_NAME = 'contract' THEN
    -- (NEW.deal_id iba vo vetve zmluvy: OOM stĺpec deal_id nemá)
    SELECT org_id INTO v_ref FROM deal WHERE id = NEW.deal_id;
    IF v_ref <> NEW.org_id THEN
      RAISE EXCEPTION 'Deal zmluvy patrí inej spoločnosti.' USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: set_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;


--
-- Name: team_external_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.team_external_guard() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_TABLE_NAME = 'team_permission' THEN
    IF (NEW.view_scope = 'vsetko' OR NEW.edit_scope = 'vsetko')
       AND EXISTS (SELECT 1 FROM team t WHERE t.id = NEW.team_id AND t.is_external) THEN
      RAISE EXCEPTION 'Externý tím nemôže vidieť ani upravovať „všetko“ (modul %).', NEW.module
        USING ERRCODE = 'check_violation';
    END IF;
  ELSIF NEW.is_external AND EXISTS (SELECT 1 FROM team_permission p
                                     WHERE p.team_id = NEW.id
                                       AND (p.view_scope = 'vsetko' OR p.edit_scope = 'vsetko')) THEN
    RAISE EXCEPTION 'Tím s právom „všetko“ nemôže byť externý.' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: team_permission_init(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.team_permission_init() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  INSERT INTO team_permission (team_id, module)
  SELECT NEW.id, m FROM unnest(enum_range(NULL::crm_module)) AS m;
  RETURN NULL;
END;
$$;


--
-- Name: activity; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.activity (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    type public.activity_type NOT NULL,
    direction text,
    company_id uuid,
    contact_id uuid,
    deal_id uuid,
    oom_id uuid,
    conversation_id uuid,
    user_id uuid,
    occurred_at timestamp with time zone NOT NULL,
    subject text,
    body_preview text,
    source text,
    source_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    body text,
    CONSTRAINT activity_note_check CHECK (((type <> 'poznamka'::public.activity_type) OR (source IS DISTINCT FROM 'crm'::text) OR ((btrim(body) <> ''::text) AND (user_id IS NOT NULL) AND (num_nonnulls(company_id, contact_id) >= 1))))
);


--
-- Name: COLUMN activity.body; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.activity.body IS 'celý text (poznámka z CRM); body_preview je náhľad z HubSpotu';


--
-- Name: app_setting; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.app_setting (
    key text NOT NULL,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    value jsonb NOT NULL,
    description text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT app_setting_key_check CHECK ((key ~ '^[a-z][a-z0-9_]{1,62}$'::text))
);


--
-- Name: TABLE app_setting; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.app_setting IS 'nastavenia systému podľa prostredia (Test / Ostré); mení ich iba vlastník databázy (db/app-setting.sh)';


--
-- Name: app_user; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.app_user (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    email text NOT NULL,
    name text NOT NULL,
    team_id uuid NOT NULL,
    hubspot_owner_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    status public.user_status DEFAULT 'pozvany'::public.user_status NOT NULL,
    is_admin boolean DEFAULT false NOT NULL,
    invited_at timestamp with time zone DEFAULT now() NOT NULL,
    last_login_at timestamp with time zone,
    deactivated_at timestamp with time zone,
    CONSTRAINT app_user_deactivated_check CHECK (((status = 'deaktivovany'::public.user_status) = (deactivated_at IS NOT NULL))),
    CONSTRAINT app_user_email_check CHECK ((email ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'::text)),
    CONSTRAINT app_user_name_check CHECK ((btrim(name) <> ''::text))
);


--
-- Name: COLUMN app_user.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.app_user.status IS 'pozvany → aktivny pri prvom prihlásení (app_user_login); deaktivovany iba cez app_user_deactivate';


--
-- Name: COLUMN app_user.is_admin; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.app_user.is_admin IS 'smie meniť Nastavenia; prihlásenie vyplýva z e-mailu (@greenlogy.com = Google, inak kód e-mailom)';


--
-- Name: COLUMN app_user.last_login_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.app_user.last_login_at IS 'posledné prihlásenie; nezapisuje sa do auditu';


--
-- Name: app_user_org; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.app_user_org (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    org_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE app_user_org; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.app_user_org IS 'prístup používateľa k spoločnostiam; tím s all_orgs vidí všetky bez ohľadu na túto tabuľku';


--
-- Name: audit_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_log (
    id bigint NOT NULL,
    table_name text NOT NULL,
    record_id uuid NOT NULL,
    action public.audit_action NOT NULL,
    changed_by uuid,
    changed_at timestamp with time zone DEFAULT now() NOT NULL,
    diff jsonb NOT NULL,
    source public.audit_source DEFAULT 'system'::public.audit_source NOT NULL
);


--
-- Name: COLUMN audit_log.changed_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.audit_log.changed_by IS 'app_user.id z current_setting(''app.user_id''); NULL pri synchronizácii a údržbe';


--
-- Name: COLUMN audit_log.diff; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.audit_log.diff IS 'insert: nový riadok; update: {stĺpec: {old, new}} iba zmenené stĺpce, vlastné polia ako custom.<kľúč>; delete: pôvodný riadok';


--
-- Name: COLUMN audit_log.source; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.audit_log.source IS 'aplikacia = prihlásený používateľ; system = údržba alebo výpočet CRM; synchronizacia = rola crm_sync. API môže prepísať cez SET LOCAL app.change_source';


--
-- Name: audit_log_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.audit_log ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.audit_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: business_calendar; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.business_calendar (
    date date NOT NULL,
    is_working_day boolean NOT NULL,
    work_from time without time zone,
    work_to time without time zone,
    note text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    org_id uuid NOT NULL,
    CONSTRAINT business_calendar_hours_check CHECK (((is_working_day AND (work_from IS NOT NULL) AND (work_to IS NOT NULL) AND (work_to > work_from)) OR ((NOT is_working_day) AND (work_from IS NULL) AND (work_to IS NULL))))
);


--
-- Name: TABLE business_calendar; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.business_calendar IS 'pracovné dni a čas pre výpočet SLA, podľa spoločnosti; prepočítava sa z org_work_hours a org_day_off';


--
-- Name: call; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.call (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    activity_id uuid NOT NULL,
    cloudtalk_call_id text,
    duration_s integer,
    recording_url text,
    transcript text,
    agent_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT call_duration_s_check CHECK ((duration_s >= 0))
);


--
-- Name: campaign; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.campaign (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    channel text,
    brevo_campaign_id text,
    sent_at timestamp with time zone,
    stats jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: commission; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.commission (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    deal_id uuid NOT NULL,
    user_id uuid NOT NULL,
    base_eur numeric(12,2),
    amount_eur numeric(12,2),
    period date,
    status public.commission_status DEFAULT 'vypocitana'::public.commission_status NOT NULL,
    pdf_url text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: COLUMN commission.period; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.commission.period IS 'prvý deň obdobia (mesiaca), za ktoré sa provízia vypláca';


--
-- Name: commission_rule; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.commission_rule (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    product_id uuid,
    pipeline_id uuid,
    segment text,
    rate_type text NOT NULL,
    rate_value numeric(12,4) NOT NULL,
    valid_from date NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT commission_rule_target_check CHECK ((num_nonnulls(product_id, pipeline_id) >= 1))
);


--
-- Name: company_contact; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.company_contact (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id uuid NOT NULL,
    contact_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    roles text[] DEFAULT '{}'::text[] NOT NULL,
    is_main_contact boolean DEFAULT false NOT NULL
);


--
-- Name: COLUMN company_contact.roles; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.company_contact.roles IS 'roly osoby vo firme, kódy z číselníka rola_kontaktu (aj viac naraz)';


--
-- Name: consent; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.consent (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    contact_id uuid NOT NULL,
    purpose public.consent_purpose NOT NULL,
    status public.consent_status NOT NULL,
    legal_basis text,
    source text,
    recorded_at timestamp with time zone NOT NULL,
    hubspot_subscription_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: contact; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contact (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    first_name text NOT NULL,
    last_name text NOT NULL,
    title text,
    email text,
    phone text,
    mobile text,
    "position" text,
    address text,
    source text,
    campaign text,
    owner_id uuid,
    hubspot_id text,
    posthog_distinct_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    phone_norm text GENERATED ALWAYS AS (public.normalize_phone(phone)) STORED,
    mobile_norm text GENERATED ALWAYS AS (public.normalize_phone(mobile)) STORED,
    is_household boolean NOT NULL,
    status public.customer_status,
    status_source public.status_source,
    status_changed_at timestamp with time zone,
    is_former_customer boolean DEFAULT false NOT NULL,
    is_producer boolean DEFAULT false NOT NULL,
    marketing_opt_out_at timestamp with time zone,
    marketing_opt_out_source text,
    custom jsonb DEFAULT '{}'::jsonb NOT NULL,
    org_id uuid DEFAULT public.crm_default_org() NOT NULL,
    CONSTRAINT contact_email_format_check CHECK ((email ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'::text)),
    CONSTRAINT contact_marketing_opt_out_check CHECK (((marketing_opt_out_at IS NULL) = (marketing_opt_out_source IS NULL))),
    CONSTRAINT contact_name_check CHECK (((btrim(first_name) <> ''::text) AND (btrim(last_name) <> ''::text))),
    CONSTRAINT contact_reachable_check CHECK ((num_nonnulls(NULLIF(btrim(email), ''::text), NULLIF(btrim(phone), ''::text), NULLIF(btrim(mobile), ''::text)) >= 1)),
    CONSTRAINT contact_status_source_check CHECK (((status IS NULL) = (status_source IS NULL)))
);


--
-- Name: COLUMN contact.source; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contact.source IS 'zdroj kontaktu, kód z číselníka zdroj_kontaktu';


--
-- Name: COLUMN contact.is_household; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contact.is_household IS 'osoba je zákazník za domácnosť (aj marketingový kontakt bez firmy); false = iba kontakt vo firme; automaticky sa nikdy nezruší';


--
-- Name: COLUMN contact.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contact.status IS 'stav zákazníka (čl. 4 zadania); NULL, ak osoba nie je domácnosť';


--
-- Name: COLUMN contact.marketing_opt_out_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contact.marketing_opt_out_at IS '„nechce marketing“ od (čl. 8); plné súhlasy prídu v module Marketing';


--
-- Name: COLUMN contact.marketing_opt_out_source; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contact.marketing_opt_out_source IS 'zdroj „nechce marketing“, napr. hubspot, brevo, telefon, email';


--
-- Name: COLUMN contact.custom; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contact.custom IS 'vlastné polia z Nastavení: {kľúč poľa: hodnota}';


--
-- Name: COLUMN contact.org_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contact.org_id IS 'spoločnosť skupiny; osoba vo dvoch spoločnostiach = dva záznamy (Peter 12. 10.)';


--
-- Name: deal_contact; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.deal_contact (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    deal_id uuid NOT NULL,
    contact_id uuid NOT NULL,
    role text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: deal_oom; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.deal_oom (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    deal_id uuid NOT NULL,
    oom_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: oom_contact; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oom_contact (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    oom_id uuid NOT NULL,
    contact_id uuid NOT NULL,
    roles text[] DEFAULT '{}'::text[] NOT NULL,
    source public.oom_contact_source DEFAULT 'rucne'::public.oom_contact_source NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE oom_contact; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.oom_contact IS 'kontaktné osoby pri OOM; rucne = pridal používateľ, zmluva = prenesené zo zmluvy (modul 4), ručné sa pri zmene zmluvy neodoberajú';


--
-- Name: COLUMN oom_contact.roles; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.oom_contact.roles IS 'kódy z číselníka rola_pri_oom (aj viac naraz)';


--
-- Name: contact_oom_v; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.contact_oom_v WITH (security_invoker='true') AS
 WITH links AS (
         SELECT oc_1.contact_id,
            oc_1.oom_id,
            NULL::uuid AS deal_id,
            (oc_1.source)::text AS source
           FROM public.oom_contact oc_1
        UNION ALL
         SELECT dc.contact_id,
            dom.oom_id,
            dc.deal_id,
            'deal'::text
           FROM (public.deal_contact dc
             JOIN public.deal_oom dom ON ((dom.deal_id = dc.deal_id)))
        )
 SELECT l.contact_id,
    l.oom_id,
    o.status AS oom_status,
    COALESCE(array_agg(DISTINCT l.deal_id) FILTER (WHERE (l.deal_id IS NOT NULL)), '{}'::uuid[]) AS deal_ids,
    COALESCE(max(oc.roles), '{}'::text[]) AS roles,
    array_agg(DISTINCT l.source ORDER BY l.source) AS sources
   FROM ((links l
     JOIN public.oom o ON ((o.id = l.oom_id)))
     LEFT JOIN public.oom_contact oc ON (((oc.oom_id = l.oom_id) AND (oc.contact_id = l.contact_id))))
  WHERE (o.status = ANY (ARRAY['aktivne'::public.oom_status, 'pripravovane'::public.oom_status]))
  GROUP BY l.contact_id, l.oom_id, o.status;


--
-- Name: VIEW contact_oom_v; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.contact_oom_v IS 'osoba ↔ OOM: sources = rucne, zmluva (oom_contact) a deal (osoba na deale s OOM); iba Aktívne a Pripravované';


--
-- Name: contact_v; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.contact_v WITH (security_invoker='true') AS
 SELECT p.id,
    p.first_name,
    p.last_name,
    p.title,
    p.email,
    p.phone,
    p.mobile,
    p."position",
    p.address,
    p.source,
    p.campaign,
    p.owner_id,
    p.hubspot_id,
    p.posthog_distinct_id,
    p.created_at,
    p.updated_at,
    p.phone_norm,
    p.mobile_norm,
    p.is_household,
    p.status,
    p.status_source,
    p.status_changed_at,
    p.is_former_customer,
    p.is_producer,
    p.marketing_opt_out_at,
    p.marketing_opt_out_source,
    p.custom,
    p.org_id,
    x.archived,
    ((NOT x.archived) AND (p.marketing_opt_out_at IS NULL)) AS marketing_allowed
   FROM (public.contact p
     CROSS JOIN LATERAL ( SELECT ((NOT (p.is_household AND (p.status IS DISTINCT FROM 'zruseny_zakaznik'::public.customer_status))) AND (NOT (EXISTS ( SELECT 1
                   FROM (public.company_contact cc
                     JOIN public.company c ON ((c.id = cc.company_id)))
                  WHERE ((cc.contact_id = p.id) AND (NOT public.company_is_archived(c.*)))))) AND (p.is_household OR (EXISTS ( SELECT 1
                   FROM public.company_contact cc
                  WHERE (cc.contact_id = p.id))))) AS archived) x);


--
-- Name: VIEW contact_v; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.contact_v IS 'zoznam Kontakty: archived = skryť z Kontaktov, vyhľadávania a marketingu (čl. 4, 13)';


--
-- Name: contract; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contract (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    deal_id uuid,
    company_id uuid,
    person_id uuid,
    number text,
    segment public.customer_segment,
    status public.contract_status DEFAULT 'rozpracovana'::public.contract_status NOT NULL,
    confirmed boolean DEFAULT false NOT NULL,
    auto_prolong boolean DEFAULT false NOT NULL,
    valid_from date,
    valid_to date,
    signed_at timestamp with time zone,
    payment_terms_days integer,
    consumption_tolerance numeric(5,2),
    advance_payment_pct numeric(5,2),
    hubspot_deal_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    custom jsonb DEFAULT '{}'::jsonb NOT NULL,
    org_id uuid NOT NULL,
    CONSTRAINT contract_customer_check CHECK ((num_nonnulls(company_id, person_id) = 1)),
    CONSTRAINT contract_payment_terms_days_check CHECK ((payment_terms_days >= 0)),
    CONSTRAINT contract_validity_check CHECK (((valid_to IS NULL) OR (valid_from IS NULL) OR (valid_to >= valid_from)))
);


--
-- Name: COLUMN contract.segment; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contract.segment IS 'preberá sa od zákazníka pri vzniku, ak nie je zadaný';


--
-- Name: COLUMN contract.valid_to; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contract.valid_to IS 'NULL = na neurčito';


--
-- Name: COLUMN contract.consumption_tolerance; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contract.consumption_tolerance IS 'tolerancia odberu v %';


--
-- Name: COLUMN contract.custom; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contract.custom IS 'vlastné polia z Nastavení: {kľúč poľa: hodnota}';


--
-- Name: COLUMN contract.org_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contract.org_id IS 'preberá sa od zákazníka';


--
-- Name: contract_price; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contract_price (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    contract_id uuid NOT NULL,
    oom_id uuid NOT NULL,
    product_id uuid,
    direction public.price_direction NOT NULL,
    price_vt_eur_mwh numeric(12,4),
    price_nt_eur_mwh numeric(12,4),
    additive_eur_mwh numeric(12,4),
    imbalance_price_eur_mwh numeric(12,4),
    additive_coefficient_pct numeric(7,4),
    fee_oom_eur_month numeric(12,2),
    fee_zem_eur_month numeric(12,2),
    fee_vbattery_eur_month numeric(12,2),
    fee_rk_eur_kw_month numeric(12,4),
    vbattery_program text,
    valid_from date,
    valid_to date,
    status public.contract_price_status DEFAULT 'platna'::public.contract_price_status NOT NULL,
    hubspot_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT contract_price_validity_check CHECK (((valid_to IS NULL) OR (valid_from IS NULL) OR (valid_to >= valid_from)))
);


--
-- Name: COLUMN contract_price.fee_rk_eur_kw_month; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contract_price.fee_rk_eur_kw_month IS 'Green VIWA poplatok za rezervovanú kapacitu, €/kW/mesiac (HubSpot green_viwa_poplatok_za_rk__pomocny_)';


--
-- Name: COLUMN contract_price.valid_to; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contract_price.valid_to IS 'NULL = na neurčito (HubSpot 31. 12. 2099)';


--
-- Name: contract_purchase; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contract_purchase (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    contract_id uuid NOT NULL,
    product_code text NOT NULL,
    delivery_year smallint NOT NULL,
    priced_on date NOT NULL,
    price_eur_mwh numeric(12,4) NOT NULL,
    cockpit_ref text,
    hubspot_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT contract_purchase_delivery_year_check CHECK (((delivery_year >= 2000) AND (delivery_year <= 2100)))
);


--
-- Name: COLUMN contract_purchase.product_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contract_purchase.product_code IS 'produkt nákupu, napr. SK BL CAL2027';


--
-- Name: COLUMN contract_purchase.priced_on; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contract_purchase.priced_on IS 'dátum nákupu (HubSpot: close date dealu / dátum nákupnej ceny)';


--
-- Name: COLUMN contract_purchase.cockpit_ref; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contract_purchase.cockpit_ref IS 'odkaz na nákupnú tranžu v Cockpite; môže sa opakovať pri viacerých zmluvách';


--
-- Name: COLUMN contract_purchase.hubspot_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contract_purchase.hubspot_id IS 'záznam Nákupné ceny 2-22997964; jeden záznam patrí viacerým zmluvám';


--
-- Name: conversation; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.conversation (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    chatwoot_conversation_id bigint,
    channel public.conversation_channel NOT NULL,
    contact_id uuid,
    company_id uuid,
    oom_id uuid,
    product text,
    quality_standard text,
    status text,
    opened_at timestamp with time zone NOT NULL,
    first_response_at timestamp with time zone,
    resolved_at timestamp with time zone,
    assignee_id uuid,
    rating smallint,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: COLUMN conversation.quality_standard; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.conversation.quality_standard IS 'regulačný štandard kvality';


--
-- Name: custom_field_option; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.custom_field_option (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    field_id uuid NOT NULL,
    label text NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    hidden_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT custom_field_option_label_check CHECK ((btrim(label) <> ''::text))
);


--
-- Name: TABLE custom_field_option; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.custom_field_option IS 'hodnoty výberu; v custom sa ukladá id (premenovanie nič nerozbije); nemaže sa, iba skryje';


--
-- Name: custom_field_section; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.custom_field_section (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    entity public.crm_entity NOT NULL,
    name text NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT custom_field_section_name_check CHECK ((btrim(name) <> ''::text))
);


--
-- Name: custom_field_team; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.custom_field_team (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    field_id uuid NOT NULL,
    team_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE custom_field_team; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.custom_field_team IS 'tímy, ktoré smú pole meniť (pri edit_access = vybrane_timy)';


--
-- Name: oom_customer; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oom_customer (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    oom_id uuid NOT NULL,
    company_id uuid,
    person_id uuid,
    org_id uuid NOT NULL,
    valid_from date NOT NULL,
    valid_to date,
    status public.oom_status NOT NULL,
    end_reason public.oom_link_end_reason,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT oom_customer_customer_check CHECK ((num_nonnulls(company_id, person_id) = 1)),
    CONSTRAINT oom_customer_period_check CHECK (((valid_to IS NULL) OR (valid_to >= valid_from))),
    CONSTRAINT oom_customer_status_check CHECK (
CASE
    WHEN (valid_to IS NULL) THEN ((end_reason IS NULL) AND (status = ANY (ARRAY['pripravovane'::public.oom_status, 'aktivne'::public.oom_status])))
    ELSE ((end_reason IS NOT NULL) AND (status =
    CASE end_reason
        WHEN 'odchod'::public.oom_link_end_reason THEN 'odidene'::public.oom_status
        WHEN 'zrusenie'::public.oom_link_end_reason THEN 'zrusene'::public.oom_status
        WHEN 'prepis'::public.oom_link_end_reason THEN 'prepisane'::public.oom_status
        ELSE NULL::public.oom_status
    END))
END)
);


--
-- Name: TABLE oom_customer; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.oom_customer IS 'komu OOM patrilo v ktorom období a v akom stave (zadanie OOM čl. 3–4); odchod, zrušenie a prepis väzbu uzavrú, prepis a návrat založia novú';


--
-- Name: COLUMN oom_customer.valid_to; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.oom_customer.valid_to IS 'NULL = väzba trvá (Pripravované alebo Aktívne)';


--
-- Name: COLUMN oom_customer.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.oom_customer.status IS 'stav OOM pre tohto zákazníka v tomto období';


--
-- Name: customer_v; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.customer_v WITH (security_invoker='true') AS
 WITH oom_sum AS (
         SELECT l.company_id,
            l.person_id,
            count(*) AS active_oom_count,
            sum((COALESCE(o.planned_consumption_vt_mwh, (0)::numeric) + COALESCE(o.planned_consumption_nt_mwh, (0)::numeric))) AS annual_mwh
           FROM (public.oom_customer l
             JOIN public.oom o ON ((o.id = l.oom_id)))
          WHERE ((l.valid_to IS NULL) AND (l.status = 'aktivne'::public.oom_status))
          GROUP BY l.company_id, l.person_id
        ), last_activity AS (
         SELECT a.company_id,
            a.contact_id,
            max(a.occurred_at) AS last_activity_at
           FROM public.activity a
          GROUP BY a.company_id, a.contact_id
        )
 SELECT c.id,
    'B2B'::text AS customer_type,
    c.id AS company_id,
    NULL::uuid AS person_id,
    c.name,
    c.ico,
    NULL::text AS email,
    c.status,
    c.status_source,
    c.is_former_customer,
    c.is_producer,
        CASE
            WHEN c.is_producer THEN 'Firma · výrobca'::text
            ELSE 'Firma'::text
        END AS segment_label,
    c.owner_id,
    COALESCE(s.active_oom_count, (0)::bigint) AS active_oom_count,
    COALESCE(s.annual_mwh, (0)::numeric) AS annual_mwh,
    ( SELECT max(la.last_activity_at) AS max
           FROM last_activity la
          WHERE (la.company_id = c.id)) AS last_activity_at,
    public.company_is_archived(c.*) AS archived,
    c.org_id,
    c.country
   FROM (public.company c
     LEFT JOIN oom_sum s ON ((s.company_id = c.id)))
  WHERE c.is_customer
UNION ALL
 SELECT p.id,
    'B2C'::text AS customer_type,
    NULL::uuid AS company_id,
    p.id AS person_id,
    concat_ws(' '::text, p.first_name, p.last_name) AS name,
    NULL::text AS ico,
    p.email,
    p.status,
    p.status_source,
    p.is_former_customer,
    p.is_producer,
        CASE
            WHEN p.is_producer THEN 'Domácnosť · výrobca'::text
            ELSE 'Domácnosť'::text
        END AS segment_label,
    p.owner_id,
    COALESCE(s.active_oom_count, (0)::bigint) AS active_oom_count,
    COALESCE(s.annual_mwh, (0)::numeric) AS annual_mwh,
    ( SELECT max(la.last_activity_at) AS max
           FROM last_activity la
          WHERE (la.contact_id = p.id)) AS last_activity_at,
    (NOT (p.status IS DISTINCT FROM 'zruseny_zakaznik'::public.customer_status)) AS archived,
    p.org_id,
    NULL::public.country_code AS country
   FROM (public.contact p
     LEFT JOIN oom_sum s ON ((s.person_id = p.id)))
  WHERE (p.is_household AND ((( SELECT public.crm_scope('zakaznici'::public.crm_module, 'view'::text) AS crm_scope) = 'vsetko'::public.access_scope) OR (p.owner_id = ( SELECT public.crm_active_user_id() AS crm_active_user_id))));


--
-- Name: VIEW customer_v; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.customer_v IS 'zoznam Zákazníci: firmy s is_customer a osoby s is_household; archived = zrušený zákazník';


--
-- Name: deal; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.deal (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id uuid,
    person_id uuid,
    pipeline_id uuid NOT NULL,
    stage_id uuid NOT NULL,
    name text NOT NULL,
    segment public.customer_segment,
    campaign text,
    source text,
    expected_close date,
    closed_at timestamp with time zone,
    lost_reason text,
    owner_id uuid,
    hubspot_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    custom jsonb DEFAULT '{}'::jsonb NOT NULL,
    org_id uuid NOT NULL,
    CONSTRAINT deal_customer_check CHECK ((num_nonnulls(company_id, person_id) = 1))
);


--
-- Name: COLUMN deal.segment; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.deal.segment IS 'preberá sa od zákazníka pri vzniku, ak nie je zadaný';


--
-- Name: COLUMN deal.closed_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.deal.closed_at IS 'skutočné uzavretie dealu (nie dátum nákupu)';


--
-- Name: COLUMN deal.custom; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.deal.custom IS 'vlastné polia z Nastavení: {kľúč poľa: hodnota}';


--
-- Name: COLUMN deal.org_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.deal.org_id IS 'preberá sa od zákazníka';


--
-- Name: export_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.export_log (
    id bigint NOT NULL,
    user_id uuid,
    module public.crm_module NOT NULL,
    filter jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_count integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT export_log_row_count_check CHECK ((row_count >= 0))
);


--
-- Name: TABLE export_log; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.export_log IS 'kto, kedy a čo exportoval (bez samotných údajov)';


--
-- Name: export_log_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.export_log ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.export_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: fve_project; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fve_project (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    deal_id uuid NOT NULL,
    program public.fve_program,
    price_with_vat numeric(12,2),
    vat_rate numeric(5,2),
    advance_eur numeric(12,2),
    status public.fve_status,
    partner_commission_pct numeric(5,2),
    partner_name text,
    discount_savings_eur numeric(12,2),
    nep_settlement_eur numeric(12,2),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: COLUMN fve_project.vat_rate; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.fve_project.vat_rate IS 'sadzba DPH v % (napr. 23.00)';


--
-- Name: COLUMN fve_project.partner_commission_pct; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.fve_project.partner_commission_pct IS 'provízia v % zo základu (HubSpot provizia_v__)';


--
-- Name: COLUMN fve_project.partner_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.fve_project.partner_name IS 'obchodník NEP; ak je vyplnený, Greenlogy má polovicu provízie (HubSpot obchodnik_nep)';


--
-- Name: COLUMN fve_project.discount_savings_eur; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.fve_project.discount_savings_eur IS 'úspora na zľave, max. 1 500 € s DPH (HubSpot uspora_na_zlave__max__1500_eur_)';


--
-- Name: COLUMN fve_project.nep_settlement_eur; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.fve_project.nep_settlement_eur IS 'doúčtovanie z NEPu (HubSpot douctovanie_z_nepu)';


--
-- Name: lookup_list; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lookup_list (
    code text NOT NULL,
    name text NOT NULL,
    used_on text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    parent_list text,
    CONSTRAINT lookup_list_code_check CHECK ((code ~ '^[a-z][a-z0-9_]{1,62}$'::text))
);


--
-- Name: TABLE lookup_list; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.lookup_list IS 'zoznamy číselníkov; zakladá ich iba migrácia (jadro)';


--
-- Name: COLUMN lookup_list.parent_list; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.lookup_list.parent_list IS 'zoznam nadradených hodnôt (napr. sadzby distribúcie → pds)';


--
-- Name: lookup_value; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lookup_value (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    list_code text NOT NULL,
    code text NOT NULL,
    label text NOT NULL,
    org_id uuid,
    sort_order integer DEFAULT 0 NOT NULL,
    is_system boolean DEFAULT false NOT NULL,
    hidden_at timestamp with time zone,
    hubspot_value text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    parent_code text,
    reg_no text,
    CONSTRAINT lookup_value_code_check CHECK ((code ~ '^[a-z0-9][a-z0-9_]{0,62}$'::text)),
    CONSTRAINT lookup_value_label_check CHECK ((btrim(label) <> ''::text)),
    CONSTRAINT lookup_value_reg_no_check CHECK ((reg_no ~ '^[0-9]{8}$'::text)),
    CONSTRAINT lookup_value_system_visible_check CHECK ((NOT (is_system AND (hidden_at IS NOT NULL))))
);


--
-- Name: COLUMN lookup_value.code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.lookup_value.code IS 'kľúč, ktorým odkazujú záznamy; vznikne z názvu, nikdy sa nemení';


--
-- Name: COLUMN lookup_value.org_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.lookup_value.org_id IS 'NULL = celá skupina';


--
-- Name: COLUMN lookup_value.is_system; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.lookup_value.is_system IS 'hodnota, na ktorej stojí logika: nedá sa skryť ani premenovať (zakladá iba migrácia)';


--
-- Name: COLUMN lookup_value.hidden_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.lookup_value.hidden_at IS 'skrytá hodnota sa nedá vybrať pri novom zadaní, staré záznamy ju zobrazujú ďalej';


--
-- Name: COLUMN lookup_value.parent_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.lookup_value.parent_code IS 'kód nadradenej hodnoty zo zoznamu lookup_list.parent_list; nemení sa';


--
-- Name: COLUMN lookup_value.reg_no; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.lookup_value.reg_no IS 'IČO (pri PDS – prevádzkovateľ distribučnej sústavy)';


--
-- Name: offer; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.offer (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    deal_id uuid NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    status public.offer_status DEFAULT 'koncept'::public.offer_status NOT NULL,
    valid_until date,
    total_eur numeric(12,2),
    pdf_url text,
    sent_at timestamp with time zone,
    opened_at timestamp with time zone,
    hubspot_quote_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    custom jsonb DEFAULT '{}'::jsonb NOT NULL,
    org_id uuid NOT NULL,
    CONSTRAINT offer_version_check CHECK ((version > 0))
);


--
-- Name: COLUMN offer.custom; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.offer.custom IS 'vlastné polia z Nastavení: {kľúč poľa: hodnota}';


--
-- Name: COLUMN offer.org_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.offer.org_id IS 'preberá sa od dealu';


--
-- Name: offer_item; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.offer_item (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    offer_id uuid NOT NULL,
    oom_id uuid,
    product_id uuid,
    price_eur_mwh numeric(12,4),
    volume_mwh numeric(12,3),
    fee_eur_month numeric(12,2),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: oom_device; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oom_device (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    oom_id uuid NOT NULL,
    device_type public.device_type NOT NULL,
    brand text,
    model text,
    power_kw numeric(12,3),
    capacity_kwh numeric(12,3),
    count integer DEFAULT 1 NOT NULL,
    details jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT oom_device_count_check CHECK ((count > 0))
);


--
-- Name: org; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.org (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code text NOT NULL,
    country public.country_code NOT NULL,
    currency character(3) NOT NULL,
    status public.org_status DEFAULT 'pripravuje_sa'::public.org_status NOT NULL,
    is_default boolean DEFAULT false NOT NULL,
    timezone text DEFAULT 'Europe/Bratislava'::text NOT NULL,
    legal_name text NOT NULL,
    reg_no text,
    tax_no text,
    vat_no text,
    address text,
    registry_entry text,
    statutory text,
    support_phone text,
    email text,
    web text,
    regulator_license text,
    logo_updated_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    oom_switch_accept_days smallint DEFAULT 14 NOT NULL,
    oom_switch_confirm_days smallint DEFAULT 14 NOT NULL,
    CONSTRAINT org_code_check CHECK ((code ~ '^[a-z][a-z0-9_]{1,40}$'::text)),
    CONSTRAINT org_currency_check CHECK ((currency ~ '^[A-Z]{3}$'::text)),
    CONSTRAINT org_legal_name_check CHECK ((btrim(legal_name) <> ''::text)),
    CONSTRAINT org_oom_switch_accept_days_check CHECK (((oom_switch_accept_days >= 1) AND (oom_switch_accept_days <= 365))),
    CONSTRAINT org_oom_switch_confirm_days_check CHECK (((oom_switch_confirm_days >= 1) AND (oom_switch_confirm_days <= 365)))
);


--
-- Name: TABLE org; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.org IS 'spoločnosti skupiny Greenlogy (nie firmy zákazníkov – tie sú v company)';


--
-- Name: COLUMN org.reg_no; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.org.reg_no IS 'IČO (SK, CZ) alebo OIB (HR) spoločnosti';


--
-- Name: COLUMN org.regulator_license; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.org.regulator_license IS 'číslo povolenia regulátora: SK ÚRSO, CZ ERÚ, HR HERA';


--
-- Name: COLUMN org.oom_switch_accept_days; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.org.oom_switch_accept_days IS 'prechod sa zasekol: dni od odoslania výpovede bez akceptácie';


--
-- Name: COLUMN org.oom_switch_confirm_days; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.org.oom_switch_confirm_days IS 'prechod sa zasekol: dni od akceptácie výpovede bez potvrdenia zmeny dodávateľa';


--
-- Name: oom_v; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.oom_v WITH (security_invoker='true') AS
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
        CASE
            WHEN (o.company_id IS NOT NULL) THEN 'B2B'::text
            ELSE 'B2C'::text
        END AS customer_type,
    COALESCE(c.name, NULLIF(concat_ws(' '::text, p.first_name, p.last_name), ''::text)) AS customer_name,
    COALESCE(c.owner_id, p.owner_id) AS owner_id,
    u.name AS owner_name,
    o.org_id,
    o.pds,
    pv.label AS pds_label,
    o.pds_tariff,
    tv.label AS pds_tariff_label,
    o.voltage_level,
        CASE
            WHEN (o.type = 'vyroba'::public.oom_type) THEN o.planned_feed_in_mwh
            WHEN ((o.planned_consumption_vt_mwh IS NULL) AND (o.planned_consumption_nt_mwh IS NULL)) THEN NULL::numeric
            ELSE (COALESCE(o.planned_consumption_vt_mwh, (0)::numeric) + COALESCE(o.planned_consumption_nt_mwh, (0)::numeric))
        END AS planned_mwh,
    o.supply_from,
    o.supply_to,
    o.switch_notice_required,
    o.switch_notice_sent_on,
    o.switch_notice_accepted_on,
    o.switch_confirmed_on,
    ((o.status = 'pripravovane'::public.oom_status) AND (((o.switch_notice_sent_on IS NOT NULL) AND (o.switch_notice_accepted_on IS NULL) AND ((o.switch_notice_sent_on + (g.oom_switch_accept_days)::integer) < public.crm_today())) OR ((o.switch_notice_accepted_on IS NOT NULL) AND (o.switch_confirmed_on IS NULL) AND ((o.switch_notice_accepted_on + (g.oom_switch_confirm_days)::integer) < public.crm_today())))) AS switch_stuck,
        CASE
            WHEN (o.status = 'pripravovane'::public.oom_status) THEN public.oom_active_required_missing(o.*)
            ELSE NULL::text[]
        END AS active_missing,
    prev.customer_name AS transferred_from_name,
    (prev.valid_to + 1) AS transferred_on,
    o.custom,
    o.created_at,
    o.updated_at
   FROM (((((((public.oom o
     JOIN public.org g ON ((g.id = o.org_id)))
     LEFT JOIN public.company c ON ((c.id = o.company_id)))
     LEFT JOIN public.contact p ON ((p.id = o.person_id)))
     LEFT JOIN public.app_user u ON ((u.id = COALESCE(c.owner_id, p.owner_id))))
     LEFT JOIN public.lookup_value pv ON (((pv.list_code = 'pds'::text) AND (pv.code = o.pds))))
     LEFT JOIN public.lookup_value tv ON (((tv.list_code = 'sadzba_distribucie'::text) AND (tv.code = o.pds_tariff))))
     LEFT JOIN LATERAL ( SELECT COALESCE(pc.name, NULLIF(concat_ws(' '::text, pp.first_name, pp.last_name), ''::text)) AS customer_name,
            l.valid_to
           FROM ((public.oom_customer l
             LEFT JOIN public.company pc ON ((pc.id = l.company_id)))
             LEFT JOIN public.contact pp ON ((pp.id = l.person_id)))
          WHERE ((l.oom_id = o.id) AND (l.end_reason = 'prepis'::public.oom_link_end_reason))
          ORDER BY l.valid_to DESC
         LIMIT 1) prev ON (true));


--
-- Name: VIEW oom_v; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.oom_v IS 'zoznam OOM (obrazovka 17): zákazník a vlastník poslednej väzby, prechod sa zasekol (lehoty spoločnosti), chýbajúce údaje pre Aktívne, prepis od';


--
-- Name: org_bank_account; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.org_bank_account (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    iban text NOT NULL,
    bic text,
    bank_name text,
    purposes public.bank_account_purpose[] DEFAULT '{}'::public.bank_account_purpose[] NOT NULL,
    is_primary boolean DEFAULT false NOT NULL,
    archived_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT org_bank_account_iban_check CHECK ((iban ~ '^[A-Z]{2}[0-9]{2}[A-Z0-9]{10,30}$'::text))
);


--
-- Name: COLUMN org_bank_account.iban; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.org_bank_account.iban IS 'IBAN bez medzier, veľkými písmenami (upraví spúšťač)';


--
-- Name: org_day_off; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.org_day_off (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    date date NOT NULL,
    kind public.day_off_kind NOT NULL,
    name text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT org_day_off_name_check CHECK ((btrim(name) <> ''::text))
);


--
-- Name: TABLE org_day_off; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.org_day_off IS 'štátne sviatky (iba migráciou, podľa zákona krajiny) a firemné voľno (admin)';


--
-- Name: org_logo; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.org_logo (
    org_id uuid NOT NULL,
    mime text NOT NULL,
    data bytea NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT org_logo_data_check CHECK ((octet_length(data) <= 524288)),
    CONSTRAINT org_logo_mime_check CHECK ((mime = ANY (ARRAY['image/svg+xml'::text, 'image/png'::text])))
);


--
-- Name: org_work_hours; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.org_work_hours (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    weekday smallint NOT NULL,
    work_from time without time zone NOT NULL,
    work_to time without time zone NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT org_work_hours_check CHECK ((work_to > work_from)),
    CONSTRAINT org_work_hours_weekday_check CHECK (((weekday >= 1) AND (weekday <= 7)))
);


--
-- Name: TABLE org_work_hours; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.org_work_hours IS 'týždenný pracovný čas spoločnosti; deň bez riadku = voľno; 1 = pondelok';


--
-- Name: pipeline; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pipeline (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    hubspot_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    org_id uuid,
    kind public.deal_kind NOT NULL,
    archived_at timestamp with time zone
);


--
-- Name: COLUMN pipeline.org_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.pipeline.org_id IS 'NULL = celá skupina';


--
-- Name: COLUMN pipeline.kind; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.pipeline.kind IS 'druh obchodu (jadro), názov pipeline sa meniť dá';


--
-- Name: pipeline_stage; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pipeline_stage (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    pipeline_id uuid NOT NULL,
    name text NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    probability numeric(3,2),
    hubspot_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    outcome public.stage_outcome DEFAULT 'otvoreny'::public.stage_outcome NOT NULL,
    archived_at timestamp with time zone,
    is_closed boolean GENERATED ALWAYS AS ((outcome <> 'otvoreny'::public.stage_outcome)) STORED,
    is_won boolean GENERATED ALWAYS AS ((outcome = 'vyhrany'::public.stage_outcome)) STORED,
    CONSTRAINT pipeline_stage_probability_check CHECK (((probability >= (0)::numeric) AND (probability <= (1)::numeric)))
);


--
-- Name: COLUMN pipeline_stage.outcome; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.pipeline_stage.outcome IS 'typ stage: otvorený / vyhraný / prehraný';


--
-- Name: COLUMN pipeline_stage.is_closed; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.pipeline_stage.is_closed IS 'vypočítané z outcome (pre staršie dopyty)';


--
-- Name: pipeline_stage_required_field; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pipeline_stage_required_field (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    stage_id uuid NOT NULL,
    core_field text,
    custom_field_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT pipeline_stage_required_field_core_field_check CHECK ((core_field ~ '^[a-z][a-z0-9_]{1,62}$'::text)),
    CONSTRAINT pipeline_stage_required_field_one_check CHECK (((core_field IS NULL) <> (custom_field_id IS NULL)))
);


--
-- Name: COLUMN pipeline_stage_required_field.core_field; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.pipeline_stage_required_field.core_field IS 'pole jadra dealu zo zoznamu v kóde (napr. lost_reason)';


--
-- Name: product; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.product (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    kind public.product_kind NOT NULL,
    pricing_model public.pricing_model,
    unit public.product_unit NOT NULL,
    list_price numeric(12,4),
    valid_from date,
    valid_to date,
    hubspot_product_id text,
    hubspot_contract_codes text[],
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT product_validity_check CHECK (((valid_to IS NULL) OR (valid_from IS NULL) OR (valid_to >= valid_from)))
);


--
-- Name: COLUMN product.pricing_model; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product.pricing_model IS 'pri SPOT produktoch je aditív v contract_price.additive_eur_mwh';


--
-- Name: COLUMN product.list_price; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product.list_price IS 'v jednotke podľa unit (€/MWh alebo €/mesiac)';


--
-- Name: referral; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.referral (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    referrer_contact_id uuid NOT NULL,
    deal_id uuid,
    discount_eur numeric(12,2),
    reward_eur numeric(12,2),
    reward_type text,
    status text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: segment; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.segment (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    definition jsonb,
    sync_to_brevo boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: sla_record; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sla_record (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    conversation_id uuid NOT NULL,
    first_response_due timestamp with time zone NOT NULL,
    first_response_at timestamp with time zone,
    resolution_due timestamp with time zone NOT NULL,
    resolved_at timestamp with time zone,
    first_response_met boolean,
    resolution_met boolean,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: supplier_switch; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_switch (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    oom_id uuid NOT NULL,
    deal_id uuid,
    message_type public.switch_message_type NOT NULL,
    segment public.switch_segment,
    message_date date,
    effective_date date,
    point_kind text,
    metering_type text,
    customer_notified_at timestamp with time zone,
    hubspot_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: sync_run; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sync_run (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    source text NOT NULL,
    started_at timestamp with time zone DEFAULT now() NOT NULL,
    finished_at timestamp with time zone,
    records_in integer,
    records_updated integer,
    errors jsonb
);


--
-- Name: team; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.team (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    hubspot_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    code text NOT NULL,
    description text,
    all_orgs boolean DEFAULT false NOT NULL,
    can_change_owner boolean DEFAULT false NOT NULL,
    is_external boolean DEFAULT false NOT NULL,
    archived_at timestamp with time zone,
    CONSTRAINT team_code_check CHECK ((code ~ '^[a-z][a-z0-9_]{1,40}$'::text)),
    CONSTRAINT team_external_check CHECK ((NOT (is_external AND (all_orgs OR can_change_owner))))
);


--
-- Name: COLUMN team.all_orgs; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.team.all_orgs IS 'tím vidí všetky spoločnosti skupiny (CEO, Nákup, Marketing)';


--
-- Name: COLUMN team.can_change_owner; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.team.can_change_owner IS 'členovia tímu menia vlastníka (obchodníka) záznamov; okrem nich iba admin';


--
-- Name: COLUMN team.is_external; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.team.is_external IS 'externý tím: nikdy nesmie dostať „všetko“ (poistka v databáze)';


--
-- Name: team_permission; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.team_permission (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    team_id uuid NOT NULL,
    module public.crm_module NOT NULL,
    view_scope public.access_scope DEFAULT 'nic'::public.access_scope NOT NULL,
    edit_scope public.access_scope DEFAULT 'nic'::public.access_scope NOT NULL,
    can_archive boolean DEFAULT false NOT NULL,
    can_export boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT team_permission_edit_le_view_check CHECK ((edit_scope <= view_scope))
);


--
-- Name: TABLE team_permission; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.team_permission IS 'práva tímu po moduloch; „iba svoje“ = záznamy, kde je používateľ vlastníkom';


--
-- Name: voucher; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.voucher (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    deal_id uuid,
    contact_id uuid,
    code text,
    value_eur numeric(12,2),
    sent_at timestamp with time zone,
    redeemed boolean DEFAULT false NOT NULL,
    status text,
    hubspot_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: web_event; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.web_event (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    contact_id uuid,
    posthog_distinct_id text,
    event text NOT NULL,
    url text,
    occurred_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: activity activity_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity
    ADD CONSTRAINT activity_pkey PRIMARY KEY (id);


--
-- Name: activity activity_source_source_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity
    ADD CONSTRAINT activity_source_source_id_key UNIQUE (source, source_id);


--
-- Name: app_setting app_setting_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_setting
    ADD CONSTRAINT app_setting_id_key UNIQUE (id);


--
-- Name: app_setting app_setting_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_setting
    ADD CONSTRAINT app_setting_pkey PRIMARY KEY (key);


--
-- Name: app_user app_user_hubspot_owner_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_user
    ADD CONSTRAINT app_user_hubspot_owner_id_key UNIQUE (hubspot_owner_id);


--
-- Name: app_user_org app_user_org_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_user_org
    ADD CONSTRAINT app_user_org_pkey PRIMARY KEY (id);


--
-- Name: app_user_org app_user_org_user_id_org_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_user_org
    ADD CONSTRAINT app_user_org_user_id_org_id_key UNIQUE (user_id, org_id);


--
-- Name: app_user app_user_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_user
    ADD CONSTRAINT app_user_pkey PRIMARY KEY (id);


--
-- Name: audit_log audit_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_log
    ADD CONSTRAINT audit_log_pkey PRIMARY KEY (id);


--
-- Name: business_calendar business_calendar_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.business_calendar
    ADD CONSTRAINT business_calendar_pkey PRIMARY KEY (org_id, date);


--
-- Name: call call_activity_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.call
    ADD CONSTRAINT call_activity_id_key UNIQUE (activity_id);


--
-- Name: call call_cloudtalk_call_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.call
    ADD CONSTRAINT call_cloudtalk_call_id_key UNIQUE (cloudtalk_call_id);


--
-- Name: call call_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.call
    ADD CONSTRAINT call_pkey PRIMARY KEY (id);


--
-- Name: campaign campaign_brevo_campaign_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campaign
    ADD CONSTRAINT campaign_brevo_campaign_id_key UNIQUE (brevo_campaign_id);


--
-- Name: campaign campaign_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campaign
    ADD CONSTRAINT campaign_pkey PRIMARY KEY (id);


--
-- Name: commission commission_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.commission
    ADD CONSTRAINT commission_pkey PRIMARY KEY (id);


--
-- Name: commission_rule commission_rule_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.commission_rule
    ADD CONSTRAINT commission_rule_pkey PRIMARY KEY (id);


--
-- Name: company_contact company_contact_company_id_contact_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_contact
    ADD CONSTRAINT company_contact_company_id_contact_id_key UNIQUE (company_id, contact_id);


--
-- Name: company_contact company_contact_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_contact
    ADD CONSTRAINT company_contact_pkey PRIMARY KEY (id);


--
-- Name: company company_hubspot_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company
    ADD CONSTRAINT company_hubspot_id_key UNIQUE (hubspot_id);


--
-- Name: company company_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company
    ADD CONSTRAINT company_pkey PRIMARY KEY (id);


--
-- Name: consent consent_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consent
    ADD CONSTRAINT consent_pkey PRIMARY KEY (id);


--
-- Name: contact contact_hubspot_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contact
    ADD CONSTRAINT contact_hubspot_id_key UNIQUE (hubspot_id);


--
-- Name: contact contact_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contact
    ADD CONSTRAINT contact_pkey PRIMARY KEY (id);


--
-- Name: contract contract_deal_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract
    ADD CONSTRAINT contract_deal_id_key UNIQUE (deal_id);


--
-- Name: contract contract_hubspot_deal_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract
    ADD CONSTRAINT contract_hubspot_deal_id_key UNIQUE (hubspot_deal_id);


--
-- Name: contract contract_number_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract
    ADD CONSTRAINT contract_number_key UNIQUE (number);


--
-- Name: contract contract_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract
    ADD CONSTRAINT contract_pkey PRIMARY KEY (id);


--
-- Name: contract_price contract_price_hubspot_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract_price
    ADD CONSTRAINT contract_price_hubspot_id_key UNIQUE (hubspot_id);


--
-- Name: contract_price contract_price_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract_price
    ADD CONSTRAINT contract_price_pkey PRIMARY KEY (id);


--
-- Name: contract_purchase contract_purchase_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract_purchase
    ADD CONSTRAINT contract_purchase_pkey PRIMARY KEY (id);


--
-- Name: conversation conversation_chatwoot_conversation_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversation
    ADD CONSTRAINT conversation_chatwoot_conversation_id_key UNIQUE (chatwoot_conversation_id);


--
-- Name: conversation conversation_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversation
    ADD CONSTRAINT conversation_pkey PRIMARY KEY (id);


--
-- Name: custom_field custom_field_entity_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.custom_field
    ADD CONSTRAINT custom_field_entity_key_key UNIQUE (entity, key);


--
-- Name: custom_field_option custom_field_option_field_id_label_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.custom_field_option
    ADD CONSTRAINT custom_field_option_field_id_label_key UNIQUE (field_id, label);


--
-- Name: custom_field_option custom_field_option_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.custom_field_option
    ADD CONSTRAINT custom_field_option_pkey PRIMARY KEY (id);


--
-- Name: custom_field custom_field_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.custom_field
    ADD CONSTRAINT custom_field_pkey PRIMARY KEY (id);


--
-- Name: custom_field_section custom_field_section_entity_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.custom_field_section
    ADD CONSTRAINT custom_field_section_entity_name_key UNIQUE (entity, name);


--
-- Name: custom_field_section custom_field_section_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.custom_field_section
    ADD CONSTRAINT custom_field_section_pkey PRIMARY KEY (id);


--
-- Name: custom_field_team custom_field_team_field_id_team_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.custom_field_team
    ADD CONSTRAINT custom_field_team_field_id_team_id_key UNIQUE (field_id, team_id);


--
-- Name: custom_field_team custom_field_team_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.custom_field_team
    ADD CONSTRAINT custom_field_team_pkey PRIMARY KEY (id);


--
-- Name: deal_contact deal_contact_deal_id_contact_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deal_contact
    ADD CONSTRAINT deal_contact_deal_id_contact_id_key UNIQUE (deal_id, contact_id);


--
-- Name: deal_contact deal_contact_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deal_contact
    ADD CONSTRAINT deal_contact_pkey PRIMARY KEY (id);


--
-- Name: deal deal_hubspot_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deal
    ADD CONSTRAINT deal_hubspot_id_key UNIQUE (hubspot_id);


--
-- Name: deal_oom deal_oom_deal_id_oom_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deal_oom
    ADD CONSTRAINT deal_oom_deal_id_oom_id_key UNIQUE (deal_id, oom_id);


--
-- Name: deal_oom deal_oom_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deal_oom
    ADD CONSTRAINT deal_oom_pkey PRIMARY KEY (id);


--
-- Name: deal deal_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deal
    ADD CONSTRAINT deal_pkey PRIMARY KEY (id);


--
-- Name: export_log export_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.export_log
    ADD CONSTRAINT export_log_pkey PRIMARY KEY (id);


--
-- Name: fve_project fve_project_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fve_project
    ADD CONSTRAINT fve_project_pkey PRIMARY KEY (id);


--
-- Name: lookup_list lookup_list_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lookup_list
    ADD CONSTRAINT lookup_list_pkey PRIMARY KEY (code);


--
-- Name: lookup_value lookup_value_list_code_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lookup_value
    ADD CONSTRAINT lookup_value_list_code_code_key UNIQUE (list_code, code);


--
-- Name: lookup_value lookup_value_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lookup_value
    ADD CONSTRAINT lookup_value_pkey PRIMARY KEY (id);


--
-- Name: offer offer_deal_id_version_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer
    ADD CONSTRAINT offer_deal_id_version_key UNIQUE (deal_id, version);


--
-- Name: offer offer_hubspot_quote_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer
    ADD CONSTRAINT offer_hubspot_quote_id_key UNIQUE (hubspot_quote_id);


--
-- Name: offer_item offer_item_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer_item
    ADD CONSTRAINT offer_item_pkey PRIMARY KEY (id);


--
-- Name: offer offer_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer
    ADD CONSTRAINT offer_pkey PRIMARY KEY (id);


--
-- Name: oom_contact oom_contact_oom_id_contact_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oom_contact
    ADD CONSTRAINT oom_contact_oom_id_contact_id_key UNIQUE (oom_id, contact_id);


--
-- Name: oom_contact oom_contact_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oom_contact
    ADD CONSTRAINT oom_contact_pkey PRIMARY KEY (id);


--
-- Name: oom_customer oom_customer_no_overlap; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oom_customer
    ADD CONSTRAINT oom_customer_no_overlap EXCLUDE USING gist (oom_id WITH =, daterange(valid_from, valid_to, '[]'::text) WITH &&);


--
-- Name: oom_customer oom_customer_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oom_customer
    ADD CONSTRAINT oom_customer_pkey PRIMARY KEY (id);


--
-- Name: oom_device oom_device_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oom_device
    ADD CONSTRAINT oom_device_pkey PRIMARY KEY (id);


--
-- Name: oom oom_eic_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oom
    ADD CONSTRAINT oom_eic_key UNIQUE (eic);


--
-- Name: oom oom_hubspot_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oom
    ADD CONSTRAINT oom_hubspot_id_key UNIQUE (hubspot_id);


--
-- Name: oom oom_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oom
    ADD CONSTRAINT oom_pkey PRIMARY KEY (id);


--
-- Name: org_bank_account org_bank_account_org_id_iban_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_bank_account
    ADD CONSTRAINT org_bank_account_org_id_iban_key UNIQUE (org_id, iban);


--
-- Name: org_bank_account org_bank_account_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_bank_account
    ADD CONSTRAINT org_bank_account_pkey PRIMARY KEY (id);


--
-- Name: org org_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org
    ADD CONSTRAINT org_code_key UNIQUE (code);


--
-- Name: org_day_off org_day_off_org_id_date_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_day_off
    ADD CONSTRAINT org_day_off_org_id_date_key UNIQUE (org_id, date);


--
-- Name: org_day_off org_day_off_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_day_off
    ADD CONSTRAINT org_day_off_pkey PRIMARY KEY (id);


--
-- Name: org_logo org_logo_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_logo
    ADD CONSTRAINT org_logo_pkey PRIMARY KEY (org_id);


--
-- Name: org org_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org
    ADD CONSTRAINT org_pkey PRIMARY KEY (id);


--
-- Name: org_work_hours org_work_hours_org_id_weekday_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_work_hours
    ADD CONSTRAINT org_work_hours_org_id_weekday_key UNIQUE (org_id, weekday);


--
-- Name: org_work_hours org_work_hours_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_work_hours
    ADD CONSTRAINT org_work_hours_pkey PRIMARY KEY (id);


--
-- Name: pipeline pipeline_hubspot_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pipeline
    ADD CONSTRAINT pipeline_hubspot_id_key UNIQUE (hubspot_id);


--
-- Name: pipeline pipeline_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pipeline
    ADD CONSTRAINT pipeline_pkey PRIMARY KEY (id);


--
-- Name: pipeline_stage pipeline_stage_hubspot_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pipeline_stage
    ADD CONSTRAINT pipeline_stage_hubspot_id_key UNIQUE (hubspot_id);


--
-- Name: pipeline_stage pipeline_stage_id_pipeline_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pipeline_stage
    ADD CONSTRAINT pipeline_stage_id_pipeline_id_key UNIQUE (id, pipeline_id);


--
-- Name: pipeline_stage pipeline_stage_pipeline_id_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pipeline_stage
    ADD CONSTRAINT pipeline_stage_pipeline_id_name_key UNIQUE (pipeline_id, name);


--
-- Name: pipeline_stage pipeline_stage_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pipeline_stage
    ADD CONSTRAINT pipeline_stage_pkey PRIMARY KEY (id);


--
-- Name: pipeline_stage_required_field pipeline_stage_required_field_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pipeline_stage_required_field
    ADD CONSTRAINT pipeline_stage_required_field_pkey PRIMARY KEY (id);


--
-- Name: pipeline_stage_required_field pipeline_stage_required_field_stage_id_core_field_custom_fi_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pipeline_stage_required_field
    ADD CONSTRAINT pipeline_stage_required_field_stage_id_core_field_custom_fi_key UNIQUE NULLS NOT DISTINCT (stage_id, core_field, custom_field_id);


--
-- Name: product product_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product
    ADD CONSTRAINT product_code_key UNIQUE (code);


--
-- Name: product product_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product
    ADD CONSTRAINT product_pkey PRIMARY KEY (id);


--
-- Name: referral referral_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.referral
    ADD CONSTRAINT referral_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: segment segment_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.segment
    ADD CONSTRAINT segment_name_key UNIQUE (name);


--
-- Name: segment segment_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.segment
    ADD CONSTRAINT segment_pkey PRIMARY KEY (id);


--
-- Name: sla_record sla_record_conversation_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sla_record
    ADD CONSTRAINT sla_record_conversation_id_key UNIQUE (conversation_id);


--
-- Name: sla_record sla_record_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sla_record
    ADD CONSTRAINT sla_record_pkey PRIMARY KEY (id);


--
-- Name: supplier_switch supplier_switch_hubspot_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_switch
    ADD CONSTRAINT supplier_switch_hubspot_id_key UNIQUE (hubspot_id);


--
-- Name: supplier_switch supplier_switch_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_switch
    ADD CONSTRAINT supplier_switch_pkey PRIMARY KEY (id);


--
-- Name: sync_run sync_run_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sync_run
    ADD CONSTRAINT sync_run_pkey PRIMARY KEY (id);


--
-- Name: team team_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team
    ADD CONSTRAINT team_code_key UNIQUE (code);


--
-- Name: team team_hubspot_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team
    ADD CONSTRAINT team_hubspot_id_key UNIQUE (hubspot_id);


--
-- Name: team team_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team
    ADD CONSTRAINT team_name_key UNIQUE (name);


--
-- Name: team_permission team_permission_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team_permission
    ADD CONSTRAINT team_permission_pkey PRIMARY KEY (id);


--
-- Name: team_permission team_permission_team_id_module_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team_permission
    ADD CONSTRAINT team_permission_team_id_module_key UNIQUE (team_id, module);


--
-- Name: team team_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team
    ADD CONSTRAINT team_pkey PRIMARY KEY (id);


--
-- Name: voucher voucher_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.voucher
    ADD CONSTRAINT voucher_code_key UNIQUE (code);


--
-- Name: voucher voucher_hubspot_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.voucher
    ADD CONSTRAINT voucher_hubspot_id_key UNIQUE (hubspot_id);


--
-- Name: voucher voucher_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.voucher
    ADD CONSTRAINT voucher_pkey PRIMARY KEY (id);


--
-- Name: web_event web_event_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.web_event
    ADD CONSTRAINT web_event_pkey PRIMARY KEY (id);


--
-- Name: activity_company_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX activity_company_id_idx ON public.activity USING btree (company_id, occurred_at);


--
-- Name: activity_contact_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX activity_contact_id_idx ON public.activity USING btree (contact_id, occurred_at);


--
-- Name: activity_conversation_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX activity_conversation_id_idx ON public.activity USING btree (conversation_id, occurred_at);


--
-- Name: activity_deal_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX activity_deal_id_idx ON public.activity USING btree (deal_id, occurred_at);


--
-- Name: activity_occurred_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX activity_occurred_at_idx ON public.activity USING btree (occurred_at);


--
-- Name: activity_oom_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX activity_oom_id_idx ON public.activity USING btree (oom_id, occurred_at);


--
-- Name: activity_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX activity_user_id_idx ON public.activity USING btree (user_id, occurred_at);


--
-- Name: app_user_email_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX app_user_email_key ON public.app_user USING btree (lower(email));


--
-- Name: app_user_org_org_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX app_user_org_org_id_idx ON public.app_user_org USING btree (org_id);


--
-- Name: app_user_team_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX app_user_team_id_idx ON public.app_user USING btree (team_id);


--
-- Name: audit_log_changed_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_log_changed_at_idx ON public.audit_log USING btree (changed_at);


--
-- Name: audit_log_changed_by_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_log_changed_by_idx ON public.audit_log USING btree (changed_by);


--
-- Name: audit_log_record_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_log_record_idx ON public.audit_log USING btree (table_name, record_id, changed_at);


--
-- Name: audit_log_table_changed_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_log_table_changed_at_idx ON public.audit_log USING btree (table_name, changed_at);


--
-- Name: call_agent_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX call_agent_id_idx ON public.call USING btree (agent_id);


--
-- Name: commission_deal_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX commission_deal_id_idx ON public.commission USING btree (deal_id);


--
-- Name: commission_rule_pipeline_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX commission_rule_pipeline_id_idx ON public.commission_rule USING btree (pipeline_id);


--
-- Name: commission_rule_product_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX commission_rule_product_id_idx ON public.commission_rule USING btree (product_id);


--
-- Name: commission_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX commission_user_id_idx ON public.commission USING btree (user_id);


--
-- Name: company_contact_contact_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX company_contact_contact_id_idx ON public.company_contact USING btree (contact_id);


--
-- Name: company_contact_one_main_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX company_contact_one_main_key ON public.company_contact USING btree (company_id) WHERE is_main_contact;


--
-- Name: company_country_ico_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX company_country_ico_key ON public.company USING btree (country, ico);


--
-- Name: company_custom_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX company_custom_idx ON public.company USING gin (custom jsonb_path_ops);


--
-- Name: company_org_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX company_org_id_idx ON public.company USING btree (org_id);


--
-- Name: company_owner_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX company_owner_id_idx ON public.company USING btree (owner_id);


--
-- Name: company_status_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX company_status_idx ON public.company USING btree (status) WHERE is_customer;


--
-- Name: consent_contact_purpose_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX consent_contact_purpose_idx ON public.consent USING btree (contact_id, purpose, recorded_at DESC);


--
-- Name: contact_custom_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX contact_custom_idx ON public.contact USING gin (custom jsonb_path_ops);


--
-- Name: contact_email_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX contact_email_idx ON public.contact USING btree (lower(btrim(email)));


--
-- Name: contact_mobile_norm_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX contact_mobile_norm_idx ON public.contact USING btree (mobile_norm);


--
-- Name: contact_org_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX contact_org_id_idx ON public.contact USING btree (org_id);


--
-- Name: contact_owner_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX contact_owner_id_idx ON public.contact USING btree (owner_id);


--
-- Name: contact_phone_norm_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX contact_phone_norm_idx ON public.contact USING btree (phone_norm);


--
-- Name: contact_posthog_distinct_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX contact_posthog_distinct_id_idx ON public.contact USING btree (posthog_distinct_id);


--
-- Name: contact_status_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX contact_status_idx ON public.contact USING btree (status) WHERE is_household;


--
-- Name: contract_company_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX contract_company_id_idx ON public.contract USING btree (company_id);


--
-- Name: contract_custom_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX contract_custom_idx ON public.contract USING gin (custom jsonb_path_ops);


--
-- Name: contract_org_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX contract_org_id_idx ON public.contract USING btree (org_id);


--
-- Name: contract_person_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX contract_person_id_idx ON public.contract USING btree (person_id);


--
-- Name: contract_price_contract_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX contract_price_contract_id_idx ON public.contract_price USING btree (contract_id);


--
-- Name: contract_price_one_valid_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX contract_price_one_valid_key ON public.contract_price USING btree (contract_id, oom_id) WHERE (status = 'platna'::public.contract_price_status);


--
-- Name: contract_price_oom_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX contract_price_oom_id_idx ON public.contract_price USING btree (oom_id);


--
-- Name: contract_price_product_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX contract_price_product_id_idx ON public.contract_price USING btree (product_id);


--
-- Name: contract_purchase_cockpit_ref_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX contract_purchase_cockpit_ref_idx ON public.contract_purchase USING btree (cockpit_ref);


--
-- Name: contract_purchase_contract_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX contract_purchase_contract_id_idx ON public.contract_purchase USING btree (contract_id);


--
-- Name: contract_purchase_hubspot_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX contract_purchase_hubspot_key ON public.contract_purchase USING btree (contract_id, hubspot_id) WHERE (hubspot_id IS NOT NULL);


--
-- Name: conversation_assignee_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX conversation_assignee_id_idx ON public.conversation USING btree (assignee_id);


--
-- Name: conversation_company_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX conversation_company_id_idx ON public.conversation USING btree (company_id);


--
-- Name: conversation_contact_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX conversation_contact_id_idx ON public.conversation USING btree (contact_id);


--
-- Name: conversation_oom_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX conversation_oom_id_idx ON public.conversation USING btree (oom_id);


--
-- Name: conversation_opened_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX conversation_opened_at_idx ON public.conversation USING btree (opened_at);


--
-- Name: deal_company_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX deal_company_id_idx ON public.deal USING btree (company_id);


--
-- Name: deal_contact_contact_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX deal_contact_contact_id_idx ON public.deal_contact USING btree (contact_id);


--
-- Name: deal_custom_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX deal_custom_idx ON public.deal USING gin (custom jsonb_path_ops);


--
-- Name: deal_oom_oom_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX deal_oom_oom_id_idx ON public.deal_oom USING btree (oom_id);


--
-- Name: deal_org_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX deal_org_id_idx ON public.deal USING btree (org_id);


--
-- Name: deal_owner_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX deal_owner_id_idx ON public.deal USING btree (owner_id);


--
-- Name: deal_person_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX deal_person_id_idx ON public.deal USING btree (person_id);


--
-- Name: deal_pipeline_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX deal_pipeline_id_idx ON public.deal USING btree (pipeline_id);


--
-- Name: deal_stage_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX deal_stage_id_idx ON public.deal USING btree (stage_id, pipeline_id);


--
-- Name: export_log_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX export_log_created_at_idx ON public.export_log USING btree (created_at);


--
-- Name: fve_project_deal_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX fve_project_deal_id_idx ON public.fve_project USING btree (deal_id);


--
-- Name: lookup_value_label_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX lookup_value_label_key ON public.lookup_value USING btree (list_code, org_id, parent_code, lower(label)) NULLS NOT DISTINCT;


--
-- Name: offer_custom_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX offer_custom_idx ON public.offer USING gin (custom jsonb_path_ops);


--
-- Name: offer_item_offer_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX offer_item_offer_id_idx ON public.offer_item USING btree (offer_id);


--
-- Name: offer_item_oom_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX offer_item_oom_id_idx ON public.offer_item USING btree (oom_id);


--
-- Name: offer_item_product_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX offer_item_product_id_idx ON public.offer_item USING btree (product_id);


--
-- Name: offer_org_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX offer_org_id_idx ON public.offer USING btree (org_id);


--
-- Name: oom_company_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oom_company_id_idx ON public.oom USING btree (company_id);


--
-- Name: oom_contact_contact_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oom_contact_contact_id_idx ON public.oom_contact USING btree (contact_id);


--
-- Name: oom_custom_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oom_custom_idx ON public.oom USING gin (custom jsonb_path_ops);


--
-- Name: oom_customer_company_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oom_customer_company_id_idx ON public.oom_customer USING btree (company_id);


--
-- Name: oom_customer_one_open_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX oom_customer_one_open_key ON public.oom_customer USING btree (oom_id) WHERE (valid_to IS NULL);


--
-- Name: oom_customer_org_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oom_customer_org_id_idx ON public.oom_customer USING btree (org_id);


--
-- Name: oom_customer_person_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oom_customer_person_id_idx ON public.oom_customer USING btree (person_id);


--
-- Name: oom_device_oom_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oom_device_oom_id_idx ON public.oom_device USING btree (oom_id);


--
-- Name: oom_org_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oom_org_id_idx ON public.oom USING btree (org_id);


--
-- Name: oom_person_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oom_person_id_idx ON public.oom USING btree (person_id);


--
-- Name: oom_status_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oom_status_idx ON public.oom USING btree (status);


--
-- Name: org_bank_account_one_primary_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX org_bank_account_one_primary_key ON public.org_bank_account USING btree (org_id) WHERE (is_primary AND (archived_at IS NULL));


--
-- Name: org_one_default_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX org_one_default_key ON public.org USING btree (is_default) WHERE is_default;


--
-- Name: pipeline_org_name_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX pipeline_org_name_key ON public.pipeline USING btree (org_id, name) NULLS NOT DISTINCT;


--
-- Name: product_hubspot_contract_codes_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_hubspot_contract_codes_idx ON public.product USING gin (hubspot_contract_codes);


--
-- Name: product_hubspot_product_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_hubspot_product_id_idx ON public.product USING btree (hubspot_product_id);


--
-- Name: referral_deal_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX referral_deal_id_idx ON public.referral USING btree (deal_id);


--
-- Name: referral_referrer_contact_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX referral_referrer_contact_id_idx ON public.referral USING btree (referrer_contact_id);


--
-- Name: supplier_switch_deal_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX supplier_switch_deal_id_idx ON public.supplier_switch USING btree (deal_id);


--
-- Name: supplier_switch_oom_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX supplier_switch_oom_id_idx ON public.supplier_switch USING btree (oom_id);


--
-- Name: sync_run_started_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sync_run_started_at_idx ON public.sync_run USING btree (source, started_at);


--
-- Name: voucher_contact_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX voucher_contact_id_idx ON public.voucher USING btree (contact_id);


--
-- Name: voucher_deal_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX voucher_deal_id_idx ON public.voucher USING btree (deal_id);


--
-- Name: web_event_contact_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX web_event_contact_id_idx ON public.web_event USING btree (contact_id, occurred_at);


--
-- Name: web_event_occurred_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX web_event_occurred_at_idx ON public.web_event USING btree (occurred_at);


--
-- Name: web_event_posthog_distinct_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX web_event_posthog_distinct_id_idx ON public.web_event USING btree (posthog_distinct_id);


--
-- Name: app_user trg_app_user_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_app_user_guard BEFORE INSERT OR DELETE OR UPDATE ON public.app_user FOR EACH ROW EXECUTE FUNCTION public.app_user_guard();


--
-- Name: activity trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.activity FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: app_setting trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.app_setting FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: app_user trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.app_user FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: app_user_org trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.app_user_org FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: call trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.call FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: campaign trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.campaign FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: commission trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.commission FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: commission_rule trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.commission_rule FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: company trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.company FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: company_contact trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.company_contact FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: consent trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.consent FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: contact trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.contact FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: contract trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.contract FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: contract_price trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.contract_price FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: contract_purchase trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.contract_purchase FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: conversation trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.conversation FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: custom_field trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.custom_field FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: custom_field_option trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.custom_field_option FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: custom_field_section trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.custom_field_section FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: custom_field_team trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.custom_field_team FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: deal trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.deal FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: deal_contact trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.deal_contact FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: deal_oom trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.deal_oom FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: fve_project trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.fve_project FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: lookup_value trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.lookup_value FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: offer trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.offer FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: offer_item trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.offer_item FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: oom trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.oom FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: oom_contact trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.oom_contact FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: oom_customer trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.oom_customer FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: oom_device trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.oom_device FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: org trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.org FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: org_bank_account trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.org_bank_account FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: org_day_off trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.org_day_off FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: org_work_hours trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.org_work_hours FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: pipeline trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.pipeline FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: pipeline_stage trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.pipeline_stage FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: pipeline_stage_required_field trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.pipeline_stage_required_field FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: product trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.product FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: referral trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.referral FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: segment trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.segment FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: sla_record trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.sla_record FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: supplier_switch trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.supplier_switch FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: team trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.team FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: team_permission trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.team_permission FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: voucher trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.voucher FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: org_day_off trg_business_calendar; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_business_calendar AFTER INSERT OR DELETE OR UPDATE ON public.org_day_off FOR EACH STATEMENT EXECUTE FUNCTION public.business_calendar_rebuild();


--
-- Name: org_work_hours trg_business_calendar; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_business_calendar AFTER INSERT OR DELETE OR UPDATE ON public.org_work_hours FOR EACH STATEMENT EXECUTE FUNCTION public.business_calendar_rebuild();


--
-- Name: company_contact trg_check; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_check BEFORE INSERT OR UPDATE ON public.company_contact FOR EACH ROW EXECUTE FUNCTION public.company_contact_check();


--
-- Name: oom_contact trg_check; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_check BEFORE INSERT OR UPDATE ON public.oom_contact FOR EACH ROW EXECUTE FUNCTION public.oom_contact_check();


--
-- Name: oom_customer trg_check; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_check BEFORE INSERT OR UPDATE ON public.oom_customer FOR EACH ROW EXECUTE FUNCTION public.oom_customer_check();


--
-- Name: company trg_country_default; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_country_default BEFORE INSERT ON public.company FOR EACH ROW EXECUTE FUNCTION public.company_country_default();


--
-- Name: company trg_custom_values; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_custom_values BEFORE INSERT OR UPDATE ON public.company FOR EACH ROW EXECUTE FUNCTION public.custom_values_check('firma');


--
-- Name: contact trg_custom_values; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_custom_values BEFORE INSERT OR UPDATE ON public.contact FOR EACH ROW EXECUTE FUNCTION public.custom_values_check('osoba');


--
-- Name: contract trg_custom_values; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_custom_values BEFORE INSERT OR UPDATE ON public.contract FOR EACH ROW EXECUTE FUNCTION public.custom_values_check('zmluva');


--
-- Name: deal trg_custom_values; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_custom_values BEFORE INSERT OR UPDATE ON public.deal FOR EACH ROW EXECUTE FUNCTION public.custom_values_check('deal');


--
-- Name: offer trg_custom_values; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_custom_values BEFORE INSERT OR UPDATE ON public.offer FOR EACH ROW EXECUTE FUNCTION public.custom_values_check('ponuka');


--
-- Name: oom trg_custom_values; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_custom_values BEFORE INSERT OR UPDATE ON public.oom FOR EACH ROW EXECUTE FUNCTION public.custom_values_check('oom');


--
-- Name: oom_customer trg_customer_mark; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_customer_mark AFTER INSERT ON public.oom_customer FOR EACH ROW EXECUTE FUNCTION public.oom_customer_mark();


--
-- Name: company trg_customer_org_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_customer_org_guard BEFORE UPDATE OF org_id ON public.company FOR EACH ROW EXECUTE FUNCTION public.customer_org_guard();


--
-- Name: contact trg_customer_org_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_customer_org_guard BEFORE UPDATE OF org_id ON public.contact FOR EACH ROW EXECUTE FUNCTION public.customer_org_guard();


--
-- Name: oom_customer trg_customer_refresh; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_customer_refresh AFTER INSERT OR DELETE OR UPDATE ON public.oom_customer FOR EACH ROW EXECUTE FUNCTION public.oom_customer_refresh();


--
-- Name: company trg_customer_status; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_customer_status BEFORE INSERT OR UPDATE ON public.company FOR EACH ROW EXECUTE FUNCTION public.customer_status_track();


--
-- Name: contact trg_customer_status; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_customer_status BEFORE INSERT OR UPDATE ON public.contact FOR EACH ROW EXECUTE FUNCTION public.customer_status_track();


--
-- Name: custom_field trg_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_guard BEFORE INSERT OR DELETE OR UPDATE ON public.custom_field FOR EACH ROW EXECUTE FUNCTION public.custom_field_guard();


--
-- Name: custom_field_option trg_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_guard BEFORE DELETE ON public.custom_field_option FOR EACH ROW EXECUTE FUNCTION public.custom_field_option_guard();


--
-- Name: lookup_value trg_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_guard BEFORE INSERT OR DELETE OR UPDATE ON public.lookup_value FOR EACH ROW EXECUTE FUNCTION public.lookup_value_guard();


--
-- Name: contract trg_inherit_segment; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_inherit_segment BEFORE INSERT ON public.contract FOR EACH ROW EXECUTE FUNCTION public.inherit_customer_segment();


--
-- Name: deal trg_inherit_segment; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_inherit_segment BEFORE INSERT ON public.deal FOR EACH ROW EXECUTE FUNCTION public.inherit_customer_segment();


--
-- Name: oom_customer trg_link_sync; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_link_sync AFTER INSERT OR DELETE OR UPDATE ON public.oom_customer FOR EACH ROW EXECUTE FUNCTION public.oom_link_sync();


--
-- Name: contract trg_mark_household; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_mark_household AFTER INSERT OR UPDATE OF person_id ON public.contract FOR EACH ROW EXECUTE FUNCTION public.mark_household();


--
-- Name: deal trg_mark_household; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_mark_household AFTER INSERT OR UPDATE OF person_id ON public.deal FOR EACH ROW EXECUTE FUNCTION public.mark_household();


--
-- Name: oom trg_mark_household; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_mark_household AFTER INSERT OR UPDATE OF person_id ON public.oom FOR EACH ROW EXECUTE FUNCTION public.mark_household();


--
-- Name: pipeline trg_no_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_no_delete BEFORE DELETE ON public.pipeline FOR EACH ROW WHEN ((CURRENT_USER <> 'crm_sync'::name)) EXECUTE FUNCTION public.pipeline_no_delete();


--
-- Name: pipeline_stage trg_no_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_no_delete BEFORE DELETE ON public.pipeline_stage FOR EACH ROW WHEN ((CURRENT_USER <> 'crm_sync'::name)) EXECUTE FUNCTION public.pipeline_no_delete();


--
-- Name: org_bank_account trg_normalize; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_normalize BEFORE INSERT OR UPDATE OF iban ON public.org_bank_account FOR EACH ROW EXECUTE FUNCTION public.org_bank_account_normalize();


--
-- Name: oom trg_oom_active_required; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_oom_active_required BEFORE INSERT OR UPDATE ON public.oom FOR EACH ROW EXECUTE FUNCTION public.oom_active_required_check();


--
-- Name: oom trg_oom_eic; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_oom_eic BEFORE INSERT OR UPDATE OF eic ON public.oom FOR EACH ROW EXECUTE FUNCTION public.oom_eic_normalize();


--
-- Name: oom trg_oom_first_link; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_oom_first_link AFTER INSERT ON public.oom FOR EACH ROW EXECUTE FUNCTION public.oom_first_link();


--
-- Name: oom trg_oom_link_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_oom_link_guard BEFORE INSERT OR UPDATE ON public.oom FOR EACH ROW EXECUTE FUNCTION public.oom_link_guard();


--
-- Name: oom trg_oom_lookup; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_oom_lookup BEFORE INSERT OR UPDATE ON public.oom FOR EACH ROW EXECUTE FUNCTION public.oom_lookup_check();


--
-- Name: oom trg_oom_prechod_aktivacia; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_oom_prechod_aktivacia AFTER INSERT OR UPDATE ON public.oom FOR EACH ROW WHEN (((new.status = 'pripravovane'::public.oom_status) AND (new.switch_confirmed_on IS NOT NULL))) EXECUTE FUNCTION public.oom_activate_on_save();


--
-- Name: oom trg_oom_type_refresh; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_oom_type_refresh AFTER UPDATE OF type ON public.oom FOR EACH ROW WHEN ((new.type IS DISTINCT FROM old.type)) EXECUTE FUNCTION public.oom_type_refresh();


--
-- Name: deal_contact trg_org_check; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_org_check BEFORE INSERT OR UPDATE ON public.deal_contact FOR EACH ROW EXECUTE FUNCTION public.deal_contact_org_check();


--
-- Name: company trg_owner_change_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_owner_change_guard BEFORE UPDATE OF owner_id ON public.company FOR EACH ROW EXECUTE FUNCTION public.owner_change_guard();


--
-- Name: contact trg_owner_change_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_owner_change_guard BEFORE UPDATE OF owner_id ON public.contact FOR EACH ROW EXECUTE FUNCTION public.owner_change_guard();


--
-- Name: audit_log trg_protect; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_protect BEFORE DELETE OR UPDATE ON public.audit_log FOR EACH ROW EXECUTE FUNCTION public.audit_log_protect();


--
-- Name: audit_log trg_protect_truncate; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_protect_truncate BEFORE TRUNCATE ON public.audit_log FOR EACH STATEMENT EXECUTE FUNCTION public.audit_log_protect();


--
-- Name: contract trg_record_org; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_record_org BEFORE INSERT OR UPDATE ON public.contract FOR EACH ROW EXECUTE FUNCTION public.record_org_fill();


--
-- Name: deal trg_record_org; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_record_org BEFORE INSERT OR UPDATE ON public.deal FOR EACH ROW EXECUTE FUNCTION public.record_org_fill();


--
-- Name: offer trg_record_org; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_record_org BEFORE INSERT OR UPDATE ON public.offer FOR EACH ROW EXECUTE FUNCTION public.record_org_fill();


--
-- Name: oom trg_record_org; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_record_org BEFORE INSERT OR UPDATE ON public.oom FOR EACH ROW EXECUTE FUNCTION public.record_org_fill();


--
-- Name: activity trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.activity FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: app_setting trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.app_setting FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: app_user trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.app_user FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: app_user_org trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.app_user_org FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: business_calendar trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.business_calendar FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: call trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.call FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: campaign trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.campaign FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: commission trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.commission FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: commission_rule trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.commission_rule FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: company trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.company FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: company_contact trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.company_contact FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: consent trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.consent FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: contact trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.contact FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: contract trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.contract FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: contract_price trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.contract_price FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: contract_purchase trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.contract_purchase FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: conversation trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.conversation FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: custom_field trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.custom_field FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: custom_field_option trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.custom_field_option FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: custom_field_section trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.custom_field_section FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: custom_field_team trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.custom_field_team FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: deal trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.deal FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: deal_contact trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.deal_contact FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: deal_oom trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.deal_oom FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: fve_project trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.fve_project FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: lookup_list trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.lookup_list FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: lookup_value trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.lookup_value FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: offer trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.offer FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: offer_item trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.offer_item FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: oom trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.oom FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: oom_contact trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.oom_contact FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: oom_customer trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.oom_customer FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: oom_device trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.oom_device FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: org trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.org FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: org_bank_account trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.org_bank_account FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: org_day_off trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.org_day_off FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: org_logo trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.org_logo FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: org_work_hours trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.org_work_hours FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: pipeline trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.pipeline FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: pipeline_stage trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.pipeline_stage FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: pipeline_stage_required_field trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.pipeline_stage_required_field FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: product trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.product FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: referral trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.referral FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: segment trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.segment FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: sla_record trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.sla_record FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: supplier_switch trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.supplier_switch FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: team trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.team FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: team_permission trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.team_permission FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: voucher trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.voucher FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: web_event trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.web_event FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: contact trg_source_check; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_source_check BEFORE INSERT OR UPDATE OF source, org_id ON public.contact FOR EACH ROW EXECUTE FUNCTION public.contact_source_check();


--
-- Name: team trg_team_external_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_team_external_guard BEFORE UPDATE OF is_external ON public.team FOR EACH ROW EXECUTE FUNCTION public.team_external_guard();


--
-- Name: team_permission trg_team_external_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_team_external_guard BEFORE INSERT OR UPDATE ON public.team_permission FOR EACH ROW EXECUTE FUNCTION public.team_external_guard();


--
-- Name: team trg_team_permission_init; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_team_permission_init AFTER INSERT ON public.team FOR EACH ROW EXECUTE FUNCTION public.team_permission_init();


--
-- Name: activity activity_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity
    ADD CONSTRAINT activity_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.company(id);


--
-- Name: activity activity_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity
    ADD CONSTRAINT activity_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES public.contact(id);


--
-- Name: activity activity_conversation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity
    ADD CONSTRAINT activity_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES public.conversation(id);


--
-- Name: activity activity_deal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity
    ADD CONSTRAINT activity_deal_id_fkey FOREIGN KEY (deal_id) REFERENCES public.deal(id);


--
-- Name: activity activity_oom_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity
    ADD CONSTRAINT activity_oom_id_fkey FOREIGN KEY (oom_id) REFERENCES public.oom(id);


--
-- Name: activity activity_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity
    ADD CONSTRAINT activity_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.app_user(id);


--
-- Name: app_user_org app_user_org_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_user_org
    ADD CONSTRAINT app_user_org_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.org(id);


--
-- Name: app_user_org app_user_org_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_user_org
    ADD CONSTRAINT app_user_org_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.app_user(id) ON DELETE CASCADE;


--
-- Name: app_user app_user_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_user
    ADD CONSTRAINT app_user_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.team(id);


--
-- Name: business_calendar business_calendar_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.business_calendar
    ADD CONSTRAINT business_calendar_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.org(id);


--
-- Name: call call_activity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.call
    ADD CONSTRAINT call_activity_id_fkey FOREIGN KEY (activity_id) REFERENCES public.activity(id) ON DELETE CASCADE;


--
-- Name: call call_agent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.call
    ADD CONSTRAINT call_agent_id_fkey FOREIGN KEY (agent_id) REFERENCES public.app_user(id);


--
-- Name: commission commission_deal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.commission
    ADD CONSTRAINT commission_deal_id_fkey FOREIGN KEY (deal_id) REFERENCES public.deal(id);


--
-- Name: commission_rule commission_rule_pipeline_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.commission_rule
    ADD CONSTRAINT commission_rule_pipeline_id_fkey FOREIGN KEY (pipeline_id) REFERENCES public.pipeline(id);


--
-- Name: commission_rule commission_rule_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.commission_rule
    ADD CONSTRAINT commission_rule_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.product(id);


--
-- Name: commission commission_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.commission
    ADD CONSTRAINT commission_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.app_user(id);


--
-- Name: company_contact company_contact_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_contact
    ADD CONSTRAINT company_contact_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.company(id) ON DELETE CASCADE;


--
-- Name: company_contact company_contact_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_contact
    ADD CONSTRAINT company_contact_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES public.contact(id) ON DELETE CASCADE;


--
-- Name: company company_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company
    ADD CONSTRAINT company_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.org(id);


--
-- Name: company company_owner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company
    ADD CONSTRAINT company_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.app_user(id);


--
-- Name: consent consent_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consent
    ADD CONSTRAINT consent_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES public.contact(id);


--
-- Name: contact contact_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contact
    ADD CONSTRAINT contact_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.org(id);


--
-- Name: contact contact_owner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contact
    ADD CONSTRAINT contact_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.app_user(id);


--
-- Name: contract contract_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract
    ADD CONSTRAINT contract_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.company(id);


--
-- Name: contract contract_deal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract
    ADD CONSTRAINT contract_deal_id_fkey FOREIGN KEY (deal_id) REFERENCES public.deal(id);


--
-- Name: contract contract_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract
    ADD CONSTRAINT contract_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.org(id);


--
-- Name: contract contract_person_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract
    ADD CONSTRAINT contract_person_id_fkey FOREIGN KEY (person_id) REFERENCES public.contact(id);


--
-- Name: contract_price contract_price_contract_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract_price
    ADD CONSTRAINT contract_price_contract_id_fkey FOREIGN KEY (contract_id) REFERENCES public.contract(id);


--
-- Name: contract_price contract_price_oom_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract_price
    ADD CONSTRAINT contract_price_oom_id_fkey FOREIGN KEY (oom_id) REFERENCES public.oom(id);


--
-- Name: contract_price contract_price_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract_price
    ADD CONSTRAINT contract_price_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.product(id);


--
-- Name: contract_purchase contract_purchase_contract_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract_purchase
    ADD CONSTRAINT contract_purchase_contract_id_fkey FOREIGN KEY (contract_id) REFERENCES public.contract(id);


--
-- Name: conversation conversation_assignee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversation
    ADD CONSTRAINT conversation_assignee_id_fkey FOREIGN KEY (assignee_id) REFERENCES public.app_user(id);


--
-- Name: conversation conversation_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversation
    ADD CONSTRAINT conversation_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.company(id);


--
-- Name: conversation conversation_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversation
    ADD CONSTRAINT conversation_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES public.contact(id);


--
-- Name: conversation conversation_oom_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversation
    ADD CONSTRAINT conversation_oom_id_fkey FOREIGN KEY (oom_id) REFERENCES public.oom(id);


--
-- Name: custom_field_option custom_field_option_field_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.custom_field_option
    ADD CONSTRAINT custom_field_option_field_id_fkey FOREIGN KEY (field_id) REFERENCES public.custom_field(id);


--
-- Name: custom_field custom_field_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.custom_field
    ADD CONSTRAINT custom_field_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.org(id);


--
-- Name: custom_field custom_field_section_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.custom_field
    ADD CONSTRAINT custom_field_section_id_fkey FOREIGN KEY (section_id) REFERENCES public.custom_field_section(id);


--
-- Name: custom_field_team custom_field_team_field_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.custom_field_team
    ADD CONSTRAINT custom_field_team_field_id_fkey FOREIGN KEY (field_id) REFERENCES public.custom_field(id) ON DELETE CASCADE;


--
-- Name: custom_field_team custom_field_team_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.custom_field_team
    ADD CONSTRAINT custom_field_team_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.team(id);


--
-- Name: deal deal_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deal
    ADD CONSTRAINT deal_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.company(id);


--
-- Name: deal_contact deal_contact_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deal_contact
    ADD CONSTRAINT deal_contact_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES public.contact(id) ON DELETE CASCADE;


--
-- Name: deal_contact deal_contact_deal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deal_contact
    ADD CONSTRAINT deal_contact_deal_id_fkey FOREIGN KEY (deal_id) REFERENCES public.deal(id) ON DELETE CASCADE;


--
-- Name: deal_oom deal_oom_deal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deal_oom
    ADD CONSTRAINT deal_oom_deal_id_fkey FOREIGN KEY (deal_id) REFERENCES public.deal(id) ON DELETE CASCADE;


--
-- Name: deal_oom deal_oom_oom_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deal_oom
    ADD CONSTRAINT deal_oom_oom_id_fkey FOREIGN KEY (oom_id) REFERENCES public.oom(id) ON DELETE CASCADE;


--
-- Name: deal deal_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deal
    ADD CONSTRAINT deal_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.org(id);


--
-- Name: deal deal_owner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deal
    ADD CONSTRAINT deal_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.app_user(id);


--
-- Name: deal deal_person_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deal
    ADD CONSTRAINT deal_person_id_fkey FOREIGN KEY (person_id) REFERENCES public.contact(id);


--
-- Name: deal deal_pipeline_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deal
    ADD CONSTRAINT deal_pipeline_id_fkey FOREIGN KEY (pipeline_id) REFERENCES public.pipeline(id);


--
-- Name: deal deal_stage_in_pipeline_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deal
    ADD CONSTRAINT deal_stage_in_pipeline_fkey FOREIGN KEY (stage_id, pipeline_id) REFERENCES public.pipeline_stage(id, pipeline_id);


--
-- Name: export_log export_log_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.export_log
    ADD CONSTRAINT export_log_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.app_user(id);


--
-- Name: fve_project fve_project_deal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fve_project
    ADD CONSTRAINT fve_project_deal_id_fkey FOREIGN KEY (deal_id) REFERENCES public.deal(id);


--
-- Name: lookup_list lookup_list_parent_list_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lookup_list
    ADD CONSTRAINT lookup_list_parent_list_fkey FOREIGN KEY (parent_list) REFERENCES public.lookup_list(code);


--
-- Name: lookup_value lookup_value_list_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lookup_value
    ADD CONSTRAINT lookup_value_list_code_fkey FOREIGN KEY (list_code) REFERENCES public.lookup_list(code);


--
-- Name: lookup_value lookup_value_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lookup_value
    ADD CONSTRAINT lookup_value_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.org(id);


--
-- Name: offer offer_deal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer
    ADD CONSTRAINT offer_deal_id_fkey FOREIGN KEY (deal_id) REFERENCES public.deal(id);


--
-- Name: offer_item offer_item_offer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer_item
    ADD CONSTRAINT offer_item_offer_id_fkey FOREIGN KEY (offer_id) REFERENCES public.offer(id) ON DELETE CASCADE;


--
-- Name: offer_item offer_item_oom_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer_item
    ADD CONSTRAINT offer_item_oom_id_fkey FOREIGN KEY (oom_id) REFERENCES public.oom(id);


--
-- Name: offer_item offer_item_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer_item
    ADD CONSTRAINT offer_item_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.product(id);


--
-- Name: offer offer_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer
    ADD CONSTRAINT offer_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.org(id);


--
-- Name: oom oom_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oom
    ADD CONSTRAINT oom_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.company(id);


--
-- Name: oom_contact oom_contact_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oom_contact
    ADD CONSTRAINT oom_contact_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES public.contact(id);


--
-- Name: oom_contact oom_contact_oom_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oom_contact
    ADD CONSTRAINT oom_contact_oom_id_fkey FOREIGN KEY (oom_id) REFERENCES public.oom(id) ON DELETE CASCADE;


--
-- Name: oom_customer oom_customer_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oom_customer
    ADD CONSTRAINT oom_customer_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.company(id);


--
-- Name: oom_customer oom_customer_oom_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oom_customer
    ADD CONSTRAINT oom_customer_oom_id_fkey FOREIGN KEY (oom_id) REFERENCES public.oom(id);


--
-- Name: oom_customer oom_customer_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oom_customer
    ADD CONSTRAINT oom_customer_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.org(id);


--
-- Name: oom_customer oom_customer_person_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oom_customer
    ADD CONSTRAINT oom_customer_person_id_fkey FOREIGN KEY (person_id) REFERENCES public.contact(id);


--
-- Name: oom_device oom_device_oom_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oom_device
    ADD CONSTRAINT oom_device_oom_id_fkey FOREIGN KEY (oom_id) REFERENCES public.oom(id) ON DELETE CASCADE;


--
-- Name: oom oom_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oom
    ADD CONSTRAINT oom_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.org(id);


--
-- Name: oom oom_person_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oom
    ADD CONSTRAINT oom_person_id_fkey FOREIGN KEY (person_id) REFERENCES public.contact(id);


--
-- Name: org_bank_account org_bank_account_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_bank_account
    ADD CONSTRAINT org_bank_account_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.org(id);


--
-- Name: org_day_off org_day_off_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_day_off
    ADD CONSTRAINT org_day_off_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.org(id);


--
-- Name: org_logo org_logo_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_logo
    ADD CONSTRAINT org_logo_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.org(id);


--
-- Name: org_work_hours org_work_hours_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_work_hours
    ADD CONSTRAINT org_work_hours_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.org(id);


--
-- Name: pipeline pipeline_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pipeline
    ADD CONSTRAINT pipeline_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.org(id);


--
-- Name: pipeline_stage pipeline_stage_pipeline_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pipeline_stage
    ADD CONSTRAINT pipeline_stage_pipeline_id_fkey FOREIGN KEY (pipeline_id) REFERENCES public.pipeline(id);


--
-- Name: pipeline_stage_required_field pipeline_stage_required_field_custom_field_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pipeline_stage_required_field
    ADD CONSTRAINT pipeline_stage_required_field_custom_field_id_fkey FOREIGN KEY (custom_field_id) REFERENCES public.custom_field(id);


--
-- Name: pipeline_stage_required_field pipeline_stage_required_field_stage_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pipeline_stage_required_field
    ADD CONSTRAINT pipeline_stage_required_field_stage_id_fkey FOREIGN KEY (stage_id) REFERENCES public.pipeline_stage(id) ON DELETE CASCADE;


--
-- Name: referral referral_deal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.referral
    ADD CONSTRAINT referral_deal_id_fkey FOREIGN KEY (deal_id) REFERENCES public.deal(id);


--
-- Name: referral referral_referrer_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.referral
    ADD CONSTRAINT referral_referrer_contact_id_fkey FOREIGN KEY (referrer_contact_id) REFERENCES public.contact(id);


--
-- Name: sla_record sla_record_conversation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sla_record
    ADD CONSTRAINT sla_record_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES public.conversation(id) ON DELETE CASCADE;


--
-- Name: supplier_switch supplier_switch_deal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_switch
    ADD CONSTRAINT supplier_switch_deal_id_fkey FOREIGN KEY (deal_id) REFERENCES public.deal(id);


--
-- Name: supplier_switch supplier_switch_oom_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_switch
    ADD CONSTRAINT supplier_switch_oom_id_fkey FOREIGN KEY (oom_id) REFERENCES public.oom(id);


--
-- Name: team_permission team_permission_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team_permission
    ADD CONSTRAINT team_permission_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.team(id) ON DELETE CASCADE;


--
-- Name: voucher voucher_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.voucher
    ADD CONSTRAINT voucher_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES public.contact(id);


--
-- Name: voucher voucher_deal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.voucher
    ADD CONSTRAINT voucher_deal_id_fkey FOREIGN KEY (deal_id) REFERENCES public.deal(id);


--
-- Name: web_event web_event_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.web_event
    ADD CONSTRAINT web_event_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES public.contact(id);


--
-- Name: app_setting; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.app_setting ENABLE ROW LEVEL SECURITY;

--
-- Name: app_user; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.app_user ENABLE ROW LEVEL SECURITY;

--
-- Name: app_user_org; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.app_user_org ENABLE ROW LEVEL SECURITY;

--
-- Name: company; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.company ENABLE ROW LEVEL SECURITY;

--
-- Name: company_contact; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.company_contact ENABLE ROW LEVEL SECURITY;

--
-- Name: contact; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.contact ENABLE ROW LEVEL SECURITY;

--
-- Name: custom_field; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.custom_field ENABLE ROW LEVEL SECURITY;

--
-- Name: custom_field_option; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.custom_field_option ENABLE ROW LEVEL SECURITY;

--
-- Name: custom_field_section; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.custom_field_section ENABLE ROW LEVEL SECURITY;

--
-- Name: custom_field_team; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.custom_field_team ENABLE ROW LEVEL SECURITY;

--
-- Name: company_contact customer_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY customer_delete ON public.company_contact FOR DELETE USING (public.crm_company_access(company_id, 'edit'::text));


--
-- Name: company customer_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY customer_insert ON public.company FOR INSERT WITH CHECK (((org_id = ANY (( SELECT public.crm_user_orgs() AS crm_user_orgs)::uuid[])) AND ((( SELECT public.crm_scope('zakaznici'::public.crm_module, 'edit'::text) AS crm_scope) = 'vsetko'::public.access_scope) OR ((( SELECT public.crm_scope('zakaznici'::public.crm_module, 'edit'::text) AS crm_scope) = 'iba_svoje'::public.access_scope) AND (owner_id = ( SELECT public.crm_active_user_id() AS crm_active_user_id))))));


--
-- Name: company_contact customer_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY customer_insert ON public.company_contact FOR INSERT WITH CHECK (public.crm_company_access(company_id, 'edit'::text));


--
-- Name: contact customer_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY customer_insert ON public.contact FOR INSERT WITH CHECK (((org_id = ANY (( SELECT public.crm_user_orgs() AS crm_user_orgs)::uuid[])) AND ((( SELECT public.crm_scope('zakaznici'::public.crm_module, 'edit'::text) AS crm_scope) = 'vsetko'::public.access_scope) OR ((( SELECT public.crm_scope('zakaznici'::public.crm_module, 'edit'::text) AS crm_scope) = 'iba_svoje'::public.access_scope) AND (owner_id = ( SELECT public.crm_active_user_id() AS crm_active_user_id))))));


--
-- Name: company customer_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY customer_select ON public.company FOR SELECT USING (((org_id = ANY (( SELECT public.crm_user_orgs() AS crm_user_orgs)::uuid[])) AND ((( SELECT public.crm_scope('zakaznici'::public.crm_module, 'view'::text) AS crm_scope) = 'vsetko'::public.access_scope) OR ((( SELECT public.crm_scope('zakaznici'::public.crm_module, 'view'::text) AS crm_scope) = 'iba_svoje'::public.access_scope) AND (owner_id = ( SELECT public.crm_active_user_id() AS crm_active_user_id))))));


--
-- Name: company_contact customer_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY customer_select ON public.company_contact FOR SELECT USING (public.crm_company_access(company_id, 'view'::text));


--
-- Name: contact customer_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY customer_select ON public.contact FOR SELECT USING (((org_id = ANY (( SELECT public.crm_user_orgs() AS crm_user_orgs)::uuid[])) AND ((( SELECT public.crm_scope('zakaznici'::public.crm_module, 'view'::text) AS crm_scope) = 'vsetko'::public.access_scope) OR ((( SELECT public.crm_scope('zakaznici'::public.crm_module, 'view'::text) AS crm_scope) = 'iba_svoje'::public.access_scope) AND ((owner_id = ( SELECT public.crm_active_user_id() AS crm_active_user_id)) OR public.crm_contact_on_own_company(id))))));


--
-- Name: company customer_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY customer_update ON public.company FOR UPDATE USING (((org_id = ANY (( SELECT public.crm_user_orgs() AS crm_user_orgs)::uuid[])) AND ((( SELECT public.crm_scope('zakaznici'::public.crm_module, 'edit'::text) AS crm_scope) = 'vsetko'::public.access_scope) OR ((( SELECT public.crm_scope('zakaznici'::public.crm_module, 'edit'::text) AS crm_scope) = 'iba_svoje'::public.access_scope) AND (owner_id = ( SELECT public.crm_active_user_id() AS crm_active_user_id)))))) WITH CHECK (((org_id = ANY (( SELECT public.crm_user_orgs() AS crm_user_orgs)::uuid[])) AND ((( SELECT public.crm_scope('zakaznici'::public.crm_module, 'edit'::text) AS crm_scope) = 'vsetko'::public.access_scope) OR ((( SELECT public.crm_scope('zakaznici'::public.crm_module, 'edit'::text) AS crm_scope) = 'iba_svoje'::public.access_scope) AND (owner_id = ( SELECT public.crm_active_user_id() AS crm_active_user_id))))));


--
-- Name: company_contact customer_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY customer_update ON public.company_contact FOR UPDATE USING (public.crm_company_access(company_id, 'edit'::text)) WITH CHECK (public.crm_company_access(company_id, 'edit'::text));


--
-- Name: contact customer_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY customer_update ON public.contact FOR UPDATE USING (((org_id = ANY (( SELECT public.crm_user_orgs() AS crm_user_orgs)::uuid[])) AND ((( SELECT public.crm_scope('zakaznici'::public.crm_module, 'edit'::text) AS crm_scope) = 'vsetko'::public.access_scope) OR ((( SELECT public.crm_scope('zakaznici'::public.crm_module, 'edit'::text) AS crm_scope) = 'iba_svoje'::public.access_scope) AND ((owner_id = ( SELECT public.crm_active_user_id() AS crm_active_user_id)) OR public.crm_contact_on_own_company(id)))))) WITH CHECK (((org_id = ANY (( SELECT public.crm_user_orgs() AS crm_user_orgs)::uuid[])) AND ((( SELECT public.crm_scope('zakaznici'::public.crm_module, 'edit'::text) AS crm_scope) = 'vsetko'::public.access_scope) OR ((( SELECT public.crm_scope('zakaznici'::public.crm_module, 'edit'::text) AS crm_scope) = 'iba_svoje'::public.access_scope) AND ((owner_id = ( SELECT public.crm_active_user_id() AS crm_active_user_id)) OR public.crm_contact_on_own_company(id))))));


--
-- Name: lookup_list; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.lookup_list ENABLE ROW LEVEL SECURITY;

--
-- Name: lookup_value; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.lookup_value ENABLE ROW LEVEL SECURITY;

--
-- Name: org; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.org ENABLE ROW LEVEL SECURITY;

--
-- Name: org_bank_account; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.org_bank_account ENABLE ROW LEVEL SECURITY;

--
-- Name: org_day_off; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.org_day_off ENABLE ROW LEVEL SECURITY;

--
-- Name: org_logo; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.org_logo ENABLE ROW LEVEL SECURITY;

--
-- Name: org_work_hours; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.org_work_hours ENABLE ROW LEVEL SECURITY;

--
-- Name: pipeline; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.pipeline ENABLE ROW LEVEL SECURITY;

--
-- Name: pipeline_stage; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.pipeline_stage ENABLE ROW LEVEL SECURITY;

--
-- Name: pipeline_stage_required_field; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.pipeline_stage_required_field ENABLE ROW LEVEL SECURITY;

--
-- Name: org_day_off settings_day_off_kind_del; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_day_off_kind_del ON public.org_day_off AS RESTRICTIVE FOR DELETE USING (((kind = 'firemne_volno'::public.day_off_kind) OR public.crm_is_service()));


--
-- Name: org_day_off settings_day_off_kind_ins; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_day_off_kind_ins ON public.org_day_off AS RESTRICTIVE FOR INSERT WITH CHECK (((kind = 'firemne_volno'::public.day_off_kind) OR public.crm_is_service()));


--
-- Name: org_day_off settings_day_off_kind_upd; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_day_off_kind_upd ON public.org_day_off AS RESTRICTIVE FOR UPDATE USING (((kind = 'firemne_volno'::public.day_off_kind) OR public.crm_is_service())) WITH CHECK (((kind = 'firemne_volno'::public.day_off_kind) OR public.crm_is_service()));


--
-- Name: app_user_org settings_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_delete ON public.app_user_org FOR DELETE USING (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: custom_field_section settings_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_delete ON public.custom_field_section FOR DELETE USING (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: custom_field_team settings_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_delete ON public.custom_field_team FOR DELETE USING (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: org_day_off settings_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_delete ON public.org_day_off FOR DELETE USING (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: org_logo settings_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_delete ON public.org_logo FOR DELETE USING (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: org_work_hours settings_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_delete ON public.org_work_hours FOR DELETE USING (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: pipeline_stage_required_field settings_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_delete ON public.pipeline_stage_required_field FOR DELETE USING (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: app_user settings_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_insert ON public.app_user FOR INSERT WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: app_user_org settings_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_insert ON public.app_user_org FOR INSERT WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: custom_field settings_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_insert ON public.custom_field FOR INSERT WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: custom_field_option settings_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_insert ON public.custom_field_option FOR INSERT WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: custom_field_section settings_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_insert ON public.custom_field_section FOR INSERT WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: custom_field_team settings_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_insert ON public.custom_field_team FOR INSERT WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: lookup_value settings_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_insert ON public.lookup_value FOR INSERT WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: org settings_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_insert ON public.org FOR INSERT WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: org_bank_account settings_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_insert ON public.org_bank_account FOR INSERT WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: org_day_off settings_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_insert ON public.org_day_off FOR INSERT WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: org_logo settings_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_insert ON public.org_logo FOR INSERT WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: org_work_hours settings_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_insert ON public.org_work_hours FOR INSERT WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: pipeline settings_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_insert ON public.pipeline FOR INSERT WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: pipeline_stage settings_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_insert ON public.pipeline_stage FOR INSERT WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: pipeline_stage_required_field settings_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_insert ON public.pipeline_stage_required_field FOR INSERT WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: team settings_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_insert ON public.team FOR INSERT WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: team_permission settings_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_insert ON public.team_permission FOR INSERT WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: lookup_value settings_no_system; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_no_system ON public.lookup_value AS RESTRICTIVE FOR INSERT WITH CHECK (((NOT is_system) OR public.crm_is_service()));


--
-- Name: app_setting settings_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_read ON public.app_setting FOR SELECT USING (( SELECT public.crm_session_ok() AS crm_session_ok));


--
-- Name: app_user settings_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_read ON public.app_user FOR SELECT USING (( SELECT public.crm_session_ok() AS crm_session_ok));


--
-- Name: app_user_org settings_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_read ON public.app_user_org FOR SELECT USING (( SELECT public.crm_session_ok() AS crm_session_ok));


--
-- Name: custom_field settings_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_read ON public.custom_field FOR SELECT USING (( SELECT public.crm_session_ok() AS crm_session_ok));


--
-- Name: custom_field_option settings_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_read ON public.custom_field_option FOR SELECT USING (( SELECT public.crm_session_ok() AS crm_session_ok));


--
-- Name: custom_field_section settings_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_read ON public.custom_field_section FOR SELECT USING (( SELECT public.crm_session_ok() AS crm_session_ok));


--
-- Name: custom_field_team settings_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_read ON public.custom_field_team FOR SELECT USING (( SELECT public.crm_session_ok() AS crm_session_ok));


--
-- Name: lookup_list settings_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_read ON public.lookup_list FOR SELECT USING (( SELECT public.crm_session_ok() AS crm_session_ok));


--
-- Name: lookup_value settings_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_read ON public.lookup_value FOR SELECT USING (( SELECT public.crm_session_ok() AS crm_session_ok));


--
-- Name: org settings_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_read ON public.org FOR SELECT USING (( SELECT public.crm_session_ok() AS crm_session_ok));


--
-- Name: org_bank_account settings_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_read ON public.org_bank_account FOR SELECT USING (( SELECT public.crm_session_ok() AS crm_session_ok));


--
-- Name: org_day_off settings_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_read ON public.org_day_off FOR SELECT USING (( SELECT public.crm_session_ok() AS crm_session_ok));


--
-- Name: org_logo settings_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_read ON public.org_logo FOR SELECT USING (( SELECT public.crm_session_ok() AS crm_session_ok));


--
-- Name: org_work_hours settings_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_read ON public.org_work_hours FOR SELECT USING (( SELECT public.crm_session_ok() AS crm_session_ok));


--
-- Name: pipeline settings_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_read ON public.pipeline FOR SELECT USING (( SELECT public.crm_session_ok() AS crm_session_ok));


--
-- Name: pipeline_stage settings_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_read ON public.pipeline_stage FOR SELECT USING (( SELECT public.crm_session_ok() AS crm_session_ok));


--
-- Name: pipeline_stage_required_field settings_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_read ON public.pipeline_stage_required_field FOR SELECT USING (( SELECT public.crm_session_ok() AS crm_session_ok));


--
-- Name: team settings_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_read ON public.team FOR SELECT USING (( SELECT public.crm_session_ok() AS crm_session_ok));


--
-- Name: team_permission settings_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_read ON public.team_permission FOR SELECT USING (( SELECT public.crm_session_ok() AS crm_session_ok));


--
-- Name: app_user settings_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_update ON public.app_user FOR UPDATE USING (( SELECT public.crm_settings_writer() AS crm_settings_writer)) WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: app_user_org settings_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_update ON public.app_user_org FOR UPDATE USING (( SELECT public.crm_settings_writer() AS crm_settings_writer)) WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: custom_field settings_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_update ON public.custom_field FOR UPDATE USING (( SELECT public.crm_settings_writer() AS crm_settings_writer)) WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: custom_field_option settings_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_update ON public.custom_field_option FOR UPDATE USING (( SELECT public.crm_settings_writer() AS crm_settings_writer)) WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: custom_field_section settings_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_update ON public.custom_field_section FOR UPDATE USING (( SELECT public.crm_settings_writer() AS crm_settings_writer)) WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: custom_field_team settings_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_update ON public.custom_field_team FOR UPDATE USING (( SELECT public.crm_settings_writer() AS crm_settings_writer)) WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: lookup_value settings_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_update ON public.lookup_value FOR UPDATE USING (( SELECT public.crm_settings_writer() AS crm_settings_writer)) WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: org settings_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_update ON public.org FOR UPDATE USING (( SELECT public.crm_settings_writer() AS crm_settings_writer)) WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: org_bank_account settings_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_update ON public.org_bank_account FOR UPDATE USING (( SELECT public.crm_settings_writer() AS crm_settings_writer)) WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: org_day_off settings_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_update ON public.org_day_off FOR UPDATE USING (( SELECT public.crm_settings_writer() AS crm_settings_writer)) WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: org_logo settings_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_update ON public.org_logo FOR UPDATE USING (( SELECT public.crm_settings_writer() AS crm_settings_writer)) WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: org_work_hours settings_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_update ON public.org_work_hours FOR UPDATE USING (( SELECT public.crm_settings_writer() AS crm_settings_writer)) WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: pipeline settings_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_update ON public.pipeline FOR UPDATE USING (( SELECT public.crm_settings_writer() AS crm_settings_writer)) WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: pipeline_stage settings_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_update ON public.pipeline_stage FOR UPDATE USING (( SELECT public.crm_settings_writer() AS crm_settings_writer)) WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: pipeline_stage_required_field settings_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_update ON public.pipeline_stage_required_field FOR UPDATE USING (( SELECT public.crm_settings_writer() AS crm_settings_writer)) WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: team settings_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_update ON public.team FOR UPDATE USING (( SELECT public.crm_settings_writer() AS crm_settings_writer)) WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: team_permission settings_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_update ON public.team_permission FOR UPDATE USING (( SELECT public.crm_settings_writer() AS crm_settings_writer)) WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: team; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.team ENABLE ROW LEVEL SECURITY;

--
-- Name: team_permission; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.team_permission ENABLE ROW LEVEL SECURITY;

--
-- PostgreSQL database dump complete
--

\unrestrict dbmate


--
-- Dbmate schema migrations
--

INSERT INTO public.schema_migrations (version) VALUES
    ('0001'),
    ('0002'),
    ('0003'),
    ('0004'),
    ('0005'),
    ('0006'),
    ('0007'),
    ('0008'),
    ('0009'),
    ('0010'),
    ('0011'),
    ('0012'),
    ('0013'),
    ('0014');
